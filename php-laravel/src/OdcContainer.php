<?php

declare(strict_types=1);

namespace Odc;

use JsonException;
use Throwable;

final class OdcContainer
{
    public const MAGIC = 'ODC1';
    public const VERSION_MAJOR = 1;
    public const VERSION_MINOR = 0;
    public const FIXED_HEADER_SIZE = 24;
    public const CHUNK_HEADER_SIZE = 12;

    public const CHUNK_FILE_NAME = 0x0001;
    public const CHUNK_MIME_TYPE = 0x0002;
    public const CHUNK_METADATA_JSON = 0x0003;
    public const CHUNK_ORIGINAL_SIZE = 0x0004;
    public const CHUNK_COMPRESSION = 0x0010;
    public const CHUNK_SHA256 = 0x0020;
    public const CHUNK_PAYLOAD = 0x0100;

    public const COMPRESSION_NONE = 0;
    public const COMPRESSION_GZIP = 1;

    private const BUFFER_SIZE = 1048576;

    public static function createFromFile(
        string $sourcePath,
        string $odcPath,
        array $metadata = [],
        bool $compressWhenUseful = true
    ): void {
        if (!is_file($sourcePath) || !is_readable($sourcePath)) {
            throw new OdcException("Arquivo inexistente ou ilegível: {$sourcePath}");
        }

        $sourceSize = filesize($sourcePath);
        if ($sourceSize === false) {
            throw new OdcException('Não foi possível obter o tamanho do arquivo.');
        }

        $fileName = basename($sourcePath);
        $mimeType = self::detectMimeType($sourcePath);
        $sha256 = hash_file('sha256', $sourcePath, true);
        if ($sha256 === false) {
            throw new OdcException('Falha ao calcular SHA-256.');
        }

        $payloadPath = $sourcePath;
        $compression = self::COMPRESSION_NONE;
        $tempCompressed = null;

        try {
            if ($compressWhenUseful && self::shouldTryGzip($mimeType, $sourceSize)) {
                $tempCompressed = self::gzipToTempFile($sourcePath);
                $compressedSize = filesize($tempCompressed);
                if ($compressedSize !== false && $compressedSize + 64 < $sourceSize) {
                    $payloadPath = $tempCompressed;
                    $compression = self::COMPRESSION_GZIP;
                }
            }

            $payloadSize = filesize($payloadPath);
            if ($payloadSize === false) {
                throw new OdcException('Falha ao obter tamanho do payload.');
            }

            $chunkCount = 6 + ($metadata !== [] ? 1 : 0);
            $flags = $compression === self::COMPRESSION_GZIP ? 0x0001 : 0;

            self::atomicWrite($odcPath, function ($out) use (
                $chunkCount, $flags, $fileName, $mimeType, $metadata, $sourceSize,
                $compression, $sha256, $payloadPath, $payloadSize
            ): void {
                self::writeFixedHeader($out, $flags, $chunkCount);
                self::writeChunkBytes($out, self::CHUNK_FILE_NAME, $fileName);
                self::writeChunkBytes($out, self::CHUNK_MIME_TYPE, $mimeType);

                if ($metadata !== []) {
                    $json = json_encode(
                        $metadata,
                        JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES | JSON_THROW_ON_ERROR
                    );
                    self::writeChunkBytes($out, self::CHUNK_METADATA_JSON, $json);
                }

                self::writeChunkBytes($out, self::CHUNK_ORIGINAL_SIZE, self::packU64LE($sourceSize));
                self::writeChunkBytes($out, self::CHUNK_COMPRESSION, chr($compression));
                self::writeChunkBytes($out, self::CHUNK_SHA256, $sha256);
                self::writeChunkFromFile($out, self::CHUNK_PAYLOAD, $payloadPath, $payloadSize);
            });
        } finally {
            if ($tempCompressed !== null && is_file($tempCompressed)) {
                @unlink($tempCompressed);
            }
        }
    }

    public static function info(string $odcPath): array
    {
        [$header, $chunks] = self::scan($odcPath);
        $index = self::indexChunks($chunks);

        $fileName = self::readSmallChunk($odcPath, $index, self::CHUNK_FILE_NAME, 1048576);
        $mime = self::readSmallChunk($odcPath, $index, self::CHUNK_MIME_TYPE, 1048576);
        $sizeBytes = self::readSmallChunk($odcPath, $index, self::CHUNK_ORIGINAL_SIZE, 8);
        $compressionBytes = self::readSmallChunk($odcPath, $index, self::CHUNK_COMPRESSION, 1);
        $sha = self::readSmallChunk($odcPath, $index, self::CHUNK_SHA256, 32);
        $metadataBytes = self::readSmallChunk(
            $odcPath, $index, self::CHUNK_METADATA_JSON, 16 * 1024 * 1024, false
        );
        $payload = $index[self::CHUNK_PAYLOAD][0] ?? null;
        if ($payload === null) {
            throw new OdcException('PAYLOAD ausente.');
        }

        $metadata = null;
        if ($metadataBytes !== null) {
            $metadata = json_decode($metadataBytes, true, 512, JSON_THROW_ON_ERROR);
        }

        return [
            'magic' => $header['magic'],
            'version' => $header['version_major'] . '.' . $header['version_minor'],
            'flags' => $header['flags'],
            'chunk_count' => $header['chunk_count'],
            'file_name' => $fileName,
            'mime_type' => $mime,
            'original_size' => self::unpackU64LE($sizeBytes),
            'stored_payload_size' => $payload['length'],
            'compression' => ord($compressionBytes) === self::COMPRESSION_GZIP ? 'gzip' : 'none',
            'sha256' => bin2hex($sha),
            'metadata' => $metadata,
            'chunks' => array_map(static fn (array $c): array => [
                'type' => sprintf('0x%04X', $c['type']),
                'name' => self::chunkName($c['type']),
                'flags' => $c['flags'],
                'length' => $c['length'],
                'offset' => $c['data_offset'],
            ], $chunks),
        ];
    }

    public static function extract(string $odcPath, string $destinationPath): void
    {
        [, $chunks] = self::scan($odcPath);
        $index = self::indexChunks($chunks);
        $payload = $index[self::CHUNK_PAYLOAD][0] ?? null;
        if ($payload === null) {
            throw new OdcException('PAYLOAD ausente.');
        }

        $compression = ord(self::readSmallChunk($odcPath, $index, self::CHUNK_COMPRESSION, 1));
        $expectedHash = self::readSmallChunk($odcPath, $index, self::CHUNK_SHA256, 32);
        $expectedSize = self::unpackU64LE(
            self::readSmallChunk($odcPath, $index, self::CHUNK_ORIGINAL_SIZE, 8)
        );

        self::atomicWrite($destinationPath, function ($out) use (
            $odcPath, $payload, $compression, $expectedHash, $expectedSize
        ): void {
            $in = fopen($odcPath, 'rb');
            if ($in === false) {
                throw new OdcException('Falha ao abrir ODC.');
            }

            try {
                if (fseek($in, $payload['data_offset']) !== 0) {
                    throw new OdcException('Falha ao posicionar no PAYLOAD.');
                }
                $remaining = $payload['length'];
                $hash = hash_init('sha256');
                $written = 0;

                if ($compression === self::COMPRESSION_NONE) {
                    while ($remaining > 0) {
                        $buffer = fread($in, min(self::BUFFER_SIZE, $remaining));
                        if ($buffer === false || $buffer === '') {
                            throw new OdcException('Payload truncado.');
                        }
                        $remaining -= strlen($buffer);
                        self::writeAll($out, $buffer);
                        hash_update($hash, $buffer);
                        $written += strlen($buffer);
                    }
                } elseif ($compression === self::COMPRESSION_GZIP) {
                    $inflate = inflate_init(ZLIB_ENCODING_GZIP);
                    if ($inflate === false) {
                        throw new OdcException('Falha ao iniciar gzip.');
                    }
                    while ($remaining > 0) {
                        $buffer = fread($in, min(self::BUFFER_SIZE, $remaining));
                        if ($buffer === false || $buffer === '') {
                            throw new OdcException('Payload gzip truncado.');
                        }
                        $remaining -= strlen($buffer);
                        $decoded = inflate_add($inflate, $buffer, $remaining === 0 ? ZLIB_FINISH : ZLIB_NO_FLUSH);
                        if ($decoded === false) {
                            throw new OdcException('Falha na descompressão gzip.');
                        }
                        if ($decoded !== '') {
                            self::writeAll($out, $decoded);
                            hash_update($hash, $decoded);
                            $written += strlen($decoded);
                        }
                    }
                } else {
                    throw new OdcException("Compressão não suportada: {$compression}");
                }

                $actualHash = hash_final($hash, true);
                if (!hash_equals($expectedHash, $actualHash)) {
                    throw new OdcException('SHA-256 inválido.');
                }
                if ($written !== $expectedSize) {
                    throw new OdcException('Tamanho reconstruído divergente.');
                }
            } finally {
                fclose($in);
            }
        });
    }

    public static function verify(string $odcPath): bool
    {
        $temp = tempnam(sys_get_temp_dir(), 'odc_verify_');
        if ($temp === false) {
            throw new OdcException('Falha ao criar temporário.');
        }
        try {
            self::extract($odcPath, $temp);
            return true;
        } catch (Throwable) {
            return false;
        } finally {
            @unlink($temp);
        }
    }

    public static function setMetadata(string $odcPath, array $metadata): void
    {
        $json = json_encode(
            $metadata,
            JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES | JSON_THROW_ON_ERROR
        );
        self::rewriteMetadata($odcPath, $json);
    }

    public static function removeMetadata(string $odcPath): void
    {
        self::rewriteMetadata($odcPath, null);
    }

    private static function rewriteMetadata(string $odcPath, ?string $json): void
    {
        [$header, $chunks] = self::scan($odcPath);
        $preserved = array_values(array_filter(
            $chunks,
            static fn (array $c): bool => $c['type'] !== self::CHUNK_METADATA_JSON
        ));

        $newCount = count($preserved) + ($json !== null ? 1 : 0);
        $tmp = $odcPath . '.edit-' . bin2hex(random_bytes(8));
        $in = fopen($odcPath, 'rb');
        if ($in === false) {
            throw new OdcException('Falha ao abrir ODC para edição.');
        }

        try {
            self::atomicWrite($tmp, function ($out) use ($in, $header, $preserved, $newCount, $json): void {
                self::writeFixedHeader($out, $header['flags'], $newCount);
                $metadataInserted = false;
                foreach ($preserved as $chunk) {
                    if (!$metadataInserted && $json !== null && $chunk['type'] === self::CHUNK_ORIGINAL_SIZE) {
                        self::writeChunkBytes($out, self::CHUNK_METADATA_JSON, $json);
                        $metadataInserted = true;
                    }
                    if (fseek($in, $chunk['header_offset']) !== 0) {
                        throw new OdcException('Falha ao reposicionar chunk.');
                    }
                    self::copyExact($in, $out, self::CHUNK_HEADER_SIZE + $chunk['length']);
                }
                if (!$metadataInserted && $json !== null) {
                    self::writeChunkBytes($out, self::CHUNK_METADATA_JSON, $json);
                }
            });
        } finally {
            fclose($in);
        }

        self::replaceFile($tmp, $odcPath);
    }

    private static function scan(string $odcPath): array
    {
        $fp = fopen($odcPath, 'rb');
        if ($fp === false) {
            throw new OdcException("Não foi possível abrir {$odcPath}");
        }
        $physicalSize = filesize($odcPath);
        if ($physicalSize === false || $physicalSize < self::FIXED_HEADER_SIZE) {
            fclose($fp);
            throw new OdcException('Arquivo ODC truncado.');
        }

        try {
            $raw = self::readExact($fp, self::FIXED_HEADER_SIZE);
            $magic = substr($raw, 0, 4);
            if ($magic !== self::MAGIC) {
                throw new OdcException('Magic ODC inválido.');
            }
            $d = unpack('vmajor/vminor/Vflags/VheaderSize/VchunkCount/Vreserved', substr($raw, 4));
            if ($d === false || $d['headerSize'] !== self::FIXED_HEADER_SIZE || $d['major'] !== 1) {
                throw new OdcException('Header/versão ODC não suportado.');
            }
            if ($d['chunkCount'] > 1000000) {
                throw new OdcException('Quantidade de chunks fora do limite.');
            }

            $header = [
                'magic' => $magic,
                'version_major' => $d['major'],
                'version_minor' => $d['minor'],
                'flags' => $d['flags'],
                'chunk_count' => $d['chunkCount'],
            ];
            $chunks = [];

            for ($i = 0; $i < $d['chunkCount']; $i++) {
                $headerOffset = ftell($fp);
                if ($headerOffset === false || $headerOffset + self::CHUNK_HEADER_SIZE > $physicalSize) {
                    throw new OdcException('Header de chunk truncado.');
                }
                $chunkRaw = self::readExact($fp, self::CHUNK_HEADER_SIZE);
                $c = unpack('vtype/vflags/Vlow/Vhigh', $chunkRaw);
                if ($c === false) {
                    throw new OdcException('Chunk inválido.');
                }
                $length = self::u64FromParts($c['low'], $c['high']);
                $dataOffset = ftell($fp);
                if ($dataOffset === false || $length < 0 || $dataOffset + $length > $physicalSize) {
                    throw new OdcException('Comprimento de chunk inválido/truncado.');
                }
                $chunks[] = [
                    'type' => $c['type'],
                    'flags' => $c['flags'],
                    'length' => $length,
                    'header_offset' => $headerOffset,
                    'data_offset' => $dataOffset,
                ];
                if (fseek($fp, $length, SEEK_CUR) !== 0) {
                    throw new OdcException('Falha ao pular chunk.');
                }
            }
            return [$header, $chunks];
        } finally {
            fclose($fp);
        }
    }

    private static function writeFixedHeader($fp, int $flags, int $chunkCount): void
    {
        self::writeAll(
            $fp,
            self::MAGIC
            . pack('v', self::VERSION_MAJOR)
            . pack('v', self::VERSION_MINOR)
            . pack('V', $flags)
            . pack('V', self::FIXED_HEADER_SIZE)
            . pack('V', $chunkCount)
            . pack('V', 0)
        );
    }

    private static function writeChunkBytes($fp, int $type, string $data, int $flags = 0): void
    {
        self::writeChunkHeader($fp, $type, $flags, strlen($data));
        self::writeAll($fp, $data);
    }

    private static function writeChunkHeader($fp, int $type, int $flags, int $length): void
    {
        [$low, $high] = self::u64ToParts($length);
        self::writeAll($fp, pack('vvVV', $type, $flags, $low, $high));
    }

    private static function writeChunkFromFile($fp, int $type, string $sourcePath, int $length): void
    {
        self::writeChunkHeader($fp, $type, 0, $length);
        $in = fopen($sourcePath, 'rb');
        if ($in === false) {
            throw new OdcException('Falha ao abrir payload.');
        }
        try {
            self::copyExact($in, $fp, $length);
        } finally {
            fclose($in);
        }
    }

    private static function readExact($fp, int $length): string
    {
        $data = '';
        while (strlen($data) < $length) {
            $part = fread($fp, $length - strlen($data));
            if ($part === false || $part === '') {
                throw new OdcException('Fim inesperado do arquivo.');
            }
            $data .= $part;
        }
        return $data;
    }

    private static function writeAll($fp, string $data): void
    {
        $offset = 0;
        $length = strlen($data);
        while ($offset < $length) {
            $written = fwrite($fp, substr($data, $offset));
            if ($written === false || $written === 0) {
                throw new OdcException('Falha de escrita.');
            }
            $offset += $written;
        }
    }

    private static function copyExact($in, $out, int $length): void
    {
        $remaining = $length;
        while ($remaining > 0) {
            $buffer = fread($in, min(self::BUFFER_SIZE, $remaining));
            if ($buffer === false || $buffer === '') {
                throw new OdcException('Fonte truncada.');
            }
            self::writeAll($out, $buffer);
            $remaining -= strlen($buffer);
        }
    }

    private static function packU64LE(int $value): string
    {
        [$low, $high] = self::u64ToParts($value);
        return pack('VV', $low, $high);
    }

    private static function unpackU64LE(string $bytes): int
    {
        if (strlen($bytes) !== 8) {
            throw new OdcException('uint64 inválido.');
        }
        $v = unpack('Vlow/Vhigh', $bytes);
        if ($v === false) {
            throw new OdcException('uint64 inválido.');
        }
        return self::u64FromParts($v['low'], $v['high']);
    }

    private static function u64ToParts(int $value): array
    {
        if ($value < 0) {
            throw new OdcException('ODC não aceita tamanho negativo.');
        }
        $high = intdiv($value, 4294967296);
        $low = $value - ($high * 4294967296);
        return [$low, $high];
    }

    private static function u64FromParts(int $low, int $high): int
    {
        return ($high * 4294967296) + $low;
    }

    private static function detectMimeType(string $path): string
    {
        $finfo = finfo_open(FILEINFO_MIME_TYPE);
        if ($finfo === false) {
            return 'application/octet-stream';
        }
        try {
            return finfo_file($finfo, $path) ?: 'application/octet-stream';
        } finally {
            finfo_close($finfo);
        }
    }

    private static function shouldTryGzip(string $mime, int $size): bool
    {
        if ($size < 768) {
            return false;
        }
        $mime = strtolower(trim(explode(';', $mime, 2)[0]));
        if (str_starts_with($mime, 'text/')) {
            return true;
        }
        return in_array($mime, [
            'application/json', 'application/xml', 'application/xhtml+xml',
            'application/javascript', 'application/sql', 'image/svg+xml'
        ], true) || str_ends_with($mime, '+json') || str_ends_with($mime, '+xml');
    }

    private static function gzipToTempFile(string $sourcePath): string
    {
        $tmp = tempnam(sys_get_temp_dir(), 'odc_gzip_');
        if ($tmp === false) {
            throw new OdcException('Falha ao criar temporário gzip.');
        }
        $in = fopen($sourcePath, 'rb');
        $out = gzopen($tmp, 'wb6');
        if ($in === false || $out === false) {
            if (is_resource($in)) fclose($in);
            if (is_resource($out)) gzclose($out);
            @unlink($tmp);
            throw new OdcException('Falha ao iniciar gzip.');
        }
        try {
            while (!feof($in)) {
                $buffer = fread($in, self::BUFFER_SIZE);
                if ($buffer === false) {
                    throw new OdcException('Erro lendo origem.');
                }
                if ($buffer !== '' && gzwrite($out, $buffer) === false) {
                    throw new OdcException('Erro comprimindo.');
                }
            }
        } finally {
            fclose($in);
            gzclose($out);
        }
        return $tmp;
    }

    private static function indexChunks(array $chunks): array
    {
        $index = [];
        foreach ($chunks as $chunk) {
            $index[$chunk['type']][] = $chunk;
        }
        return $index;
    }

    private static function readSmallChunk(
        string $odcPath,
        array $index,
        int $type,
        int $maxBytes,
        bool $required = true
    ): ?string {
        $chunk = $index[$type][0] ?? null;
        if ($chunk === null) {
            if ($required) {
                throw new OdcException('Chunk obrigatório ausente: ' . self::chunkName($type));
            }
            return null;
        }
        if ($chunk['length'] > $maxBytes) {
            throw new OdcException('Chunk excedeu limite seguro: ' . self::chunkName($type));
        }
        $fp = fopen($odcPath, 'rb');
        if ($fp === false) {
            throw new OdcException('Falha ao abrir ODC.');
        }
        try {
            if (fseek($fp, $chunk['data_offset']) !== 0) {
                throw new OdcException('Falha ao posicionar chunk.');
            }
            return self::readExact($fp, $chunk['length']);
        } finally {
            fclose($fp);
        }
    }

    private static function atomicWrite(string $destination, callable $writer): void
    {
        $directory = dirname($destination);
        if (!is_dir($directory) && !mkdir($directory, 0775, true) && !is_dir($directory)) {
            throw new OdcException("Não foi possível criar diretório: {$directory}");
        }
        $tmp = $destination . '.tmp-' . bin2hex(random_bytes(8));
        $fp = fopen($tmp, 'wb');
        if ($fp === false) {
            throw new OdcException('Falha ao criar temporário.');
        }
        try {
            $writer($fp);
            fflush($fp);
            fclose($fp);
            $fp = null;
            self::replaceFile($tmp, $destination);
        } catch (Throwable $e) {
            if (is_resource($fp)) fclose($fp);
            @unlink($tmp);
            throw $e;
        }
    }

    private static function replaceFile(string $source, string $destination): void
    {
        if (PHP_OS_FAMILY === 'Windows' && file_exists($destination)) {
            if (!unlink($destination)) {
                throw new OdcException('Falha ao substituir arquivo de destino.');
            }
        }
        if (!rename($source, $destination)) {
            @unlink($source);
            throw new OdcException('Falha ao finalizar arquivo ODC.');
        }
    }

    public static function chunkName(int $type): string
    {
        return match ($type) {
            self::CHUNK_FILE_NAME => 'FILE_NAME',
            self::CHUNK_MIME_TYPE => 'MIME_TYPE',
            self::CHUNK_METADATA_JSON => 'METADATA_JSON',
            self::CHUNK_ORIGINAL_SIZE => 'ORIGINAL_SIZE',
            self::CHUNK_COMPRESSION => 'COMPRESSION',
            self::CHUNK_SHA256 => 'SHA256',
            self::CHUNK_PAYLOAD => 'PAYLOAD',
            default => 'UNKNOWN',
        };
    }
}
