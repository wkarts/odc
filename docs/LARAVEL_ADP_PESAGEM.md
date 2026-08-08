# Laravel — uso no fluxo ADP/Pesagem

A regra é: Base64 pode existir durante transporte; após a captura ser decodificada, o conteúdo persistente passa a ser o caminho `.odc`.

```php
use Odc\OdcContainer;
use Illuminate\Support\Str;

$raw = $request->string('image_data_url')->toString();
$raw = preg_replace('#^data:image/[^;]+;base64,#i', '', $raw);
$binary = base64_decode($raw, true);

if ($binary === false) {
    throw new RuntimeException('Imagem Base64 inválida.');
}

$tmp = storage_path('app/tmp/' . Str::uuid() . '.jpg');
@mkdir(dirname($tmp), 0775, true);
file_put_contents($tmp, $binary);

$relative = sprintf(
    'pesagens/empresa-%d/filial-%d/ticket-%d/%s.odc',
    $empresaId,
    $filialId,
    $ticket->id,
    Str::uuid()
);

$odcPath = storage_path('app/' . $relative);

OdcContainer::createFromFile($tmp, $odcPath, [
    'empresa_id' => $empresaId,
    'filial_id' => $filialId,
    'ticket_id' => $ticket->id,
    'camera_uuid' => $cameraUuid,
    'origem' => 'ADP',
]);

@unlink($tmp);
unset($binary, $raw);

// Persistir no Model somente a referência.
$imagem->arquivo_path = $relative;
$imagem->metadata_json = [
    'arquivo_path' => $relative,
    'container' => 'ODC1',
    'camera_uuid' => $cameraUuid,
];
$imagem->save();
```

O logger passa a enxergar apenas uma string de caminho, nunca o Base64.
