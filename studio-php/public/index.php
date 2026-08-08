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
<meta name="theme-color" content="#0f172a">
<title><?= STUDIO_NAME ?></title>
<link rel="icon" type="image/png" href="assets/icon.png">
<link rel="stylesheet" href="assets/app.css">
</head>
<body>
<div class="app-shell">
  <aside class="sidebar">
    <div class="brand"><img src="assets/icon.png" alt="ODC"><div><strong>ODC Studio</strong><span>PHP <?= htmlspecialchars(PHP_VERSION) ?></span></div></div>
    <nav class="nav-stack">
      <button data-tab="create" class="nav-item active"><span class="nav-icon">＋</span><span><b>Criar container</b><small>Arquivo → ODC</small></span></button>
      <button data-tab="open" class="nav-item"><span class="nav-icon">⌁</span><span><b>Inspecionar</b><small>Header, chunks e hash</small></span></button>
      <button data-tab="preview" class="nav-item"><span class="nav-icon">◫</span><span><b>Preview</b><small>Conteúdo reconstruído</small></span></button>
      <button data-tab="metadata" class="nav-item"><span class="nav-icon">{ }</span><span><b>Metadata</b><small>Editar dados auxiliares</small></span></button>
      <button data-tab="about" class="nav-item"><span class="nav-icon">i</span><span><b>Sobre</b><small>Runtime e formato</small></span></button>
    </nav>
    <div class="sidebar-card"><span class="status-dot"></span><div><b>Processamento temporário</b><small>Sem banco de dados. Uploads são processados apenas durante a requisição.</small></div></div>
    <div class="sidebar-footer"><span>ODC1</span><span><?= (int)(maxUploadBytes()/1024/1024) ?> MB</span></div>
  </aside>

  <div class="workspace">
    <header class="topbar"><div><p class="eyebrow">Optical Data Container</p><h1 id="pageTitle">Criar container</h1></div><div class="topbar-actions"><span class="chip">PHP <?= htmlspecialchars(PHP_MAJOR_VERSION.'.'.PHP_MINOR_VERSION) ?></span><span class="chip chip-strong">ODC1</span></div></header>
    <main class="content">
      <div id="notice" class="notice" hidden></div>

      <section id="tab-create" class="tab active">
        <div class="intro-card"><div><h2>Novo container ODC</h2><p>Empacote qualquer arquivo com metadata, integridade SHA-256 e compressão adaptativa.</p></div><div class="intro-badge">Limite: <b><?= (int)(maxUploadBytes()/1024/1024) ?> MB</b></div></div>
        <div class="grid-two">
          <article class="card"><div class="card-head"><div><span class="step">01</span><h3>Arquivo de origem</h3></div><span class="muted">qualquer formato</span></div><label class="drop-zone" for="sourceFile"><span class="drop-symbol">⇧</span><b>Selecione o arquivo</b><small>Será usado somente nesta operação.</small><input id="sourceFile" type="file"></label><div id="sourceName" class="file-state">Nenhum arquivo selecionado.</div></article>
          <article class="card"><div class="card-head"><div><span class="step">02</span><h3>Metadata e compactação</h3></div><span class="muted">opcional</span></div><label class="field-label">Metadata JSON</label><textarea id="createMeta" rows="12" spellcheck="false">{
  "origem": "ODC Studio PHP"
}</textarea><label class="toggle-row"><input id="compress" type="checkbox" checked><span><b>Compressão adaptativa</b><small>Gzip somente quando houver redução real.</small></span></label><button id="createBtn" class="btn primary wide">Criar e baixar ODC</button></article>
        </div>
      </section>

      <section id="tab-open" class="tab">
        <div class="intro-card"><div><h2>Inspeção técnica</h2><p>Analise a estrutura do container, chunks, tamanhos e integridade sem persistência adicional.</p></div><div class="intro-badge">Header + Chunks</div></div>
        <article class="card"><div class="toolbar-grid"><label class="compact-file"><span>Arquivo ODC</span><input id="odcFile" type="file" accept=".odc,application/octet-stream"></label><div class="button-group"><button id="inspectBtn" class="btn primary">Inspecionar</button><button id="verifyBtn" class="btn">Validar SHA-256</button><button id="extractBtn" class="btn">Extrair original</button></div></div><div class="summary" id="summary"><div class="stat empty"><b>—</b><span>Versão</span></div><div class="stat empty"><b>—</b><span>Original</span></div><div class="stat empty"><b>—</b><span>Armazenado</span></div><div class="stat empty"><b>—</b><span>Compressão</span></div></div></article>
        <div class="grid-two inspect-grid"><article class="card"><div class="card-head"><h3>Informações</h3><span class="muted">JSON normalizado</span></div><pre id="info" class="code-panel">Selecione um arquivo ODC.</pre></article><article class="card"><div class="card-head"><h3>Mapa de chunks</h3><span class="muted">offset e tamanho</span></div><div class="table-wrap"><table><thead><tr><th>Tipo</th><th>Nome</th><th>Tamanho</th><th>Offset</th></tr></thead><tbody id="chunks"><tr><td colspan="4" class="empty-row">Nenhum container carregado.</td></tr></tbody></table></div></article></div>
      </section>

      <section id="tab-preview" class="tab"><div class="intro-card"><div><h2>Preview do conteúdo</h2><p>Reconstrói o payload temporariamente e o apresenta no navegador quando o MIME for compatível.</p></div><button id="previewBtn" class="btn primary">Gerar preview</button></div><article class="card preview-card"><div id="previewArea" class="preview-area"><div class="preview-empty"><span>◫</span><b>Nenhum preview</b><small>Selecione um ODC na aba de inspeção.</small></div></div></article></section>

      <section id="tab-metadata" class="tab"><div class="intro-card"><div><h2>Editor de metadata</h2><p>Reescreva os metadados preservando o payload e gere um novo ODC.</p></div><span class="intro-badge">JSON</span></div><article class="card"><label class="field-label">Metadata JSON</label><textarea id="editMeta" class="editor-large" rows="22" spellcheck="false">{}</textarea><div class="button-group align-end"><button id="saveMetaBtn" class="btn primary">Salvar metadata e baixar</button><button id="removeMetaBtn" class="btn danger">Remover metadata</button></div></article></section>

      <section id="tab-about" class="tab"><div class="intro-card"><div><h2>ODC Studio PHP</h2><p>Interface operacional para o formato ODC1 usando a implementação oficial PHP/Laravel.</p></div><span class="intro-badge">SDK 1.1.0</span></div><div class="grid-two"><article class="card"><h3>Operações</h3><ul class="clean-list"><li>Criar containers de qualquer arquivo</li><li>Inspecionar header e chunks</li><li>Validar SHA-256</li><li>Extrair payload original</li><li>Editar ou remover metadata</li></ul></article><article class="card"><h3>Privacidade</h3><ul class="clean-list"><li>Sem banco de dados obrigatório</li><li>Payload binário literal, sem Base64</li><li>Arquivos temporários descartados ao fim da operação</li><li>Cache HTTP desabilitado nas respostas de API</li></ul></article></div></section>
    </main>
    <footer class="statusbar"><span>ODC Studio PHP</span><span>ODC1 · SHA-256 · compactação adaptativa</span></footer>
  </div>
</div>
<script src="assets/app.js"></script>
</body></html>
