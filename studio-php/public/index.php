<?php

declare(strict_types=1);

use Odc\OdcContainer;
use Odc\OdcException;

require_once __DIR__ . '/../../php-laravel/src/OdcException.php';
require_once __DIR__ . '/../../php-laravel/src/OdcContainer.php';

const STUDIO_NAME = 'ODC Studio PHP';

function maxUploadBytes(): int
{
    $mb = (int) (getenv('ODC_STUDIO_MAX_UPLOAD_MB') ?: 256);
    return max(1, $mb) * 1024 * 1024;
}

function jsonResponse(array $payload, int $status = 200): never
{
    http_response_code($status);
    header('Content-Type: application/json; charset=utf-8');
    header('Cache-Control: no-store');
    echo json_encode($payload, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES | JSON_THROW_ON_ERROR);
    exit;
}

function fail(string $message, int $status = 400): never
{
    jsonResponse(['ok' => false, 'error' => $message], $status);
}

function uploadPath(string $field): string
{
    if (!isset($_FILES[$field]) || !is_array($_FILES[$field])) {
        fail("Arquivo '{$field}' não enviado.");
    }
    $f = $_FILES[$field];
    if (($f['error'] ?? UPLOAD_ERR_NO_FILE) !== UPLOAD_ERR_OK) {
        fail('Falha no upload: código ' . ($f['error'] ?? -1));
    }
    $size = (int) ($f['size'] ?? 0);
    if ($size <= 0 || $size > maxUploadBytes()) {
        fail('Arquivo vazio ou acima do limite configurado.');
    }
    $tmp = (string) ($f['tmp_name'] ?? '');
    if (!is_uploaded_file($tmp)) {
        fail('Upload inválido.');
    }
    return $tmp;
}

function safeDownloadName(string $name, string $fallback): string
{
    $name = basename(str_replace(["\0", "\r", "\n"], '', $name));
    return $name !== '' && $name !== '.' && $name !== '..' ? $name : $fallback;
}

function metadataFromRequest(): array
{
    $raw = trim((string) ($_POST['metadata'] ?? ''));
    if ($raw === '') {
        return [];
    }
    $value = json_decode($raw, true, 512, JSON_THROW_ON_ERROR);
    if (!is_array($value)) {
        fail('Metadata precisa ser um objeto/array JSON.');
    }
    return $value;
}

function tempFile(string $prefix, string $suffix = ''): string
{
    $path = tempnam(sys_get_temp_dir(), $prefix);
    if ($path === false) {
        throw new RuntimeException('Falha ao criar arquivo temporário.');
    }
    if ($suffix !== '') {
        $dest = $path . $suffix;
        if (!rename($path, $dest)) {
            @unlink($path);
            throw new RuntimeException('Falha ao preparar temporário.');
        }
        return $dest;
    }
    return $path;
}

function sendFile(string $path, string $name, string $mime = 'application/octet-stream'): never
{
    if (!is_file($path)) {
        fail('Arquivo de saída não encontrado.', 500);
    }
    header('Content-Type: ' . $mime);
    header('Content-Length: ' . filesize($path));
    header('Content-Disposition: attachment; filename="' . rawurlencode(safeDownloadName($name, 'arquivo.bin')) . '"');
    header('Cache-Control: no-store');
    readfile($path);
    @unlink($path);
    exit;
}

if (isset($_GET['api'])) {
    try {
        $action = (string) $_GET['api'];
        if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
            fail('Use POST.', 405);
        }

        switch ($action) {
            case 'create': {
                $source = uploadPath('source');
                $name = safeDownloadName((string) ($_FILES['source']['name'] ?? 'arquivo.bin'), 'arquivo.bin');
                $metadata = metadataFromRequest();
                $compress = filter_var($_POST['compress'] ?? '1', FILTER_VALIDATE_BOOL);
                $sourceDir = sys_get_temp_dir() . DIRECTORY_SEPARATOR . 'odc-studio-' . bin2hex(random_bytes(8));
                if (!mkdir($sourceDir, 0700, true) && !is_dir($sourceDir)) {
                    throw new RuntimeException('Falha ao criar área temporária.');
                }
                $copy = $sourceDir . DIRECTORY_SEPARATOR . $name;
                if (!copy($source, $copy)) {
                    @rmdir($sourceDir);
                    throw new RuntimeException('Falha ao preparar arquivo fonte.');
                }
                $out = tempFile('odc_out_', '.odc');
                try {
                    OdcContainer::createFromFile($copy, $out, $metadata, $compress);
                } finally {
                    @unlink($copy);
                    @rmdir($sourceDir);
                }
                sendFile($out, $name . '.odc');
            }
            case 'info': {
                $odc = uploadPath('odc');
                jsonResponse(['ok' => true, 'info' => OdcContainer::info($odc)]);
            }
            case 'verify': {
                $odc = uploadPath('odc');
                jsonResponse(['ok' => true, 'valid' => OdcContainer::verify($odc)]);
            }
            case 'extract': {
                $odc = uploadPath('odc');
                $info = OdcContainer::info($odc);
                $out = tempFile('odc_extract_');
                OdcContainer::extract($odc, $out);
                sendFile($out, (string) $info['file_name'], (string) $info['mime_type']);
            }
            case 'set-meta':
            case 'remove-meta': {
                $odc = uploadPath('odc');
                $name = safeDownloadName((string) ($_FILES['odc']['name'] ?? 'arquivo.odc'), 'arquivo.odc');
                $out = tempFile('odc_edit_', '.odc');
                if (!copy($odc, $out)) {
                    throw new RuntimeException('Falha ao preparar ODC para edição.');
                }
                if ($action === 'set-meta') {
                    OdcContainer::setMetadata($out, metadataFromRequest());
                } else {
                    OdcContainer::removeMetadata($out);
                }
                sendFile($out, $name);
            }
            default:
                fail('Ação desconhecida.', 404);
        }
    } catch (JsonException $e) {
        fail('JSON inválido: ' . $e->getMessage());
    } catch (OdcException|Throwable $e) {
        fail($e->getMessage(), 500);
    }
}
?><!doctype html>
<html lang="pt-BR">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title><?= STUDIO_NAME ?></title>
<link rel="stylesheet" href="assets/app.css">
</head>
<body>
<header class="topbar"><div><strong>ODC Studio PHP</strong><span>Optical Data Container</span></div><div class="badge">ODC1 · PHP <?= htmlspecialchars(PHP_VERSION) ?></div></header>
<main class="shell">
<section class="hero"><div><h1>Crie, inspecione, valide e edite containers ODC</h1><p>Interface local PHP. Nenhum banco de dados é necessário. O conteúdo é processado apenas durante a requisição.</p></div><div class="hero-stat"><b><?= (int)(maxUploadBytes()/1024/1024) ?> MB</b><span>limite local</span></div></section>
<div id="notice" class="notice" hidden></div>
<nav class="tabs"><button data-tab="create" class="active">Criar ODC</button><button data-tab="open">Abrir / Inspecionar</button><button data-tab="metadata">Metadata</button><button data-tab="about">Sobre</button></nav>
<section id="tab-create" class="panel tab active">
  <h2>Criar container</h2>
  <div class="grid two"><label class="drop"><span>Arquivo de origem</span><input id="sourceFile" type="file"><small>Qualquer tipo de arquivo.</small></label><div><label>Metadata JSON<textarea id="createMeta" rows="9">{\n  "origem": "ODC Studio PHP"\n}</textarea></label><label class="check"><input id="compress" type="checkbox" checked> Compressão adaptativa quando houver ganho real</label><button id="createBtn" class="primary">Criar e baixar .odc</button></div></div>
</section>
<section id="tab-open" class="panel tab">
  <h2>Abrir container</h2>
  <label class="drop"><span>Arquivo .odc</span><input id="odcFile" type="file" accept=".odc,application/octet-stream"><small>O arquivo permanece apenas na sessão da página e é reenviado ao PHP para cada operação.</small></label>
  <div class="actions"><button id="inspectBtn" class="primary">Inspecionar</button><button id="verifyBtn">Validar SHA-256</button><button id="extractBtn">Extrair original</button></div>
  <div class="cards" id="summary"></div>
  <div class="split"><div><h3>Informações</h3><pre id="info">Selecione um ODC.</pre></div><div><h3>Chunks</h3><div class="table-wrap"><table><thead><tr><th>Tipo</th><th>Nome</th><th>Tamanho</th><th>Offset</th></tr></thead><tbody id="chunks"></tbody></table></div></div></div>
</section>
<section id="tab-metadata" class="panel tab">
  <h2>Editar metadata</h2><p class="muted">Use o mesmo ODC selecionado na aba “Abrir / Inspecionar”. A operação reescreve o container de forma segura e devolve um novo arquivo para download.</p>
  <textarea id="editMeta" rows="16">{}</textarea><div class="actions"><button id="saveMetaBtn" class="primary">Salvar metadata e baixar</button><button id="removeMetaBtn" class="danger">Remover metadata e baixar</button></div>
</section>
<section id="tab-about" class="panel tab"><h2>ODC Studio PHP</h2><p>Operações suportadas: <code>create</code>, <code>info</code>, <code>verify</code>, <code>extract</code>, <code>set-meta</code> e <code>remove-meta</code>.</p><p>O payload permanece binário. Base64 não é usado pelo formato ODC.</p></section>
</main>
<footer>ODC Studio PHP · formato ODC1 · execução local/rede privada conforme sua implantação</footer>
<script src="assets/app.js"></script>
</body></html>
