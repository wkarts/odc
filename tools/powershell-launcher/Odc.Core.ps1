Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:ODC = @{
    Header = 24; ChunkHeader = 12
    FileName = 0x0001; Mime = 0x0002; Meta = 0x0003; OriginalSize = 0x0004
    Compression = 0x0010; Sha256 = 0x0020; Payload = 0x0100
}
function Get-OdcMime([string]$Path) {
    switch ([IO.Path]::GetExtension($Path).ToLowerInvariant()) {
        '.txt' {'text/plain'} '.json' {'application/json'} '.xml' {'application/xml'} '.csv' {'text/csv'}
        '.jpg' {'image/jpeg'} '.jpeg' {'image/jpeg'} '.png' {'image/png'} '.webp' {'image/webp'}
        '.pdf' {'application/pdf'} '.zip' {'application/zip'} default {'application/octet-stream'}
    }
}
function Test-OdcShouldGzip([string]$Mime,[long]$Size) {
    if ($Size -lt 768) { return $false }
    return $Mime.StartsWith('text/') -or @('application/json','application/xml','application/javascript','application/sql') -contains $Mime -or $Mime.EndsWith('+json') -or $Mime.EndsWith('+xml')
}
function Write-OdcChunk([IO.BinaryWriter]$W,[UInt16]$Type,[byte[]]$Data) {
    $W.Write($Type); $W.Write([UInt16]0); $W.Write([UInt64]$Data.LongLength); $W.Write($Data)
}
function Read-OdcScan([string]$Path) {
    $fs=[IO.File]::OpenRead($Path); $br=[IO.BinaryReader]::new($fs,[Text.Encoding]::UTF8,$true)
    try {
        if($fs.Length -lt 24){throw 'ODC truncado'}
        $magic=[Text.Encoding]::ASCII.GetString($br.ReadBytes(4)); if($magic -ne 'ODC1'){throw 'Magic ODC inválido'}
        $major=$br.ReadUInt16();$minor=$br.ReadUInt16();$flags=$br.ReadUInt32();$hs=$br.ReadUInt32();$count=$br.ReadUInt32();$null=$br.ReadUInt32()
        if($major-ne 1 -or $hs-ne 24 -or $count-gt 1000000){throw 'Header/versão não suportado'}
        $chunks=@(); for($i=0;$i-lt$count;$i++){ $ho=$fs.Position;if($ho+12-gt$fs.Length){throw 'Chunk truncado'};$t=$br.ReadUInt16();$fl=$br.ReadUInt16();$len=$br.ReadUInt64();$d=$fs.Position;if($len -gt [UInt64]($fs.Length-$d)){throw 'Comprimento inválido'};$chunks += [pscustomobject]@{Type=$t;Flags=$fl;Length=$len;HeaderOffset=$ho;DataOffset=$d};$fs.Position=$d+[long]$len }
        [pscustomobject]@{Major=$major;Minor=$minor;Flags=$flags;Count=$count;Chunks=$chunks}
    } finally {$br.Dispose();$fs.Dispose()}
}
function Read-OdcSmall([string]$Path,$Scan,[int]$Type,[long]$Max,[bool]$Required=$true) {
    $c=$Scan.Chunks|Where-Object Type -eq $Type|Select-Object -First 1
    if(-not$c){if($Required){throw ('Chunk ausente 0x{0:X4}' -f $Type)}return $null}
    if($c.Length-gt$Max){throw 'Chunk acima do limite seguro'}
    $fs=[IO.File]::OpenRead($Path);try{$fs.Position=$c.DataOffset;$b=New-Object byte[] ([int]$c.Length);$off=0;while($off-lt$b.Length){$n=$fs.Read($b,$off,$b.Length-$off);if($n-le0){throw 'Chunk truncado'};$off+=$n};return ,$b}finally{$fs.Dispose()}
}
function New-OdcFile([string]$Input,[string]$Output,[hashtable]$Metadata=@{},[bool]$Compress=$true) {
    $raw=[IO.File]::ReadAllBytes($Input);$mime=Get-OdcMime $Input;$payload=$raw;$comp=[byte]0
    if($Compress -and (Test-OdcShouldGzip $mime $raw.LongLength)){$ms=[IO.MemoryStream]::new();$gz=[IO.Compression.GZipStream]::new($ms,[IO.Compression.CompressionLevel]::Optimal,$true);try{$gz.Write($raw,0,$raw.Length)}finally{$gz.Dispose()};$z=$ms.ToArray();$ms.Dispose();if($z.Length+64-lt$raw.Length){$payload=$z;$comp=1}}
    $sha=[Security.Cryptography.SHA256]::Create();try{$hash=$sha.ComputeHash($raw)}finally{$sha.Dispose()}
    $dir=[IO.Path]::GetDirectoryName([IO.Path]::GetFullPath($Output));[IO.Directory]::CreateDirectory($dir)|Out-Null;$tmp="$Output.tmp-$([Guid]::NewGuid().ToString('N'))"
    $fs=[IO.File]::Create($tmp);$bw=[IO.BinaryWriter]::new($fs,[Text.Encoding]::UTF8,$true)
    try{$bw.Write([Text.Encoding]::ASCII.GetBytes('ODC1'));$bw.Write([UInt16]1);$bw.Write([UInt16]0);$bw.Write([UInt32]($(if($comp-eq1){1}else{0})));$bw.Write([UInt32]24);$bw.Write([UInt32](6+$(if($Metadata.Count){1}else{0})));$bw.Write([UInt32]0);Write-OdcChunk $bw $script:ODC.FileName ([Text.Encoding]::UTF8.GetBytes([IO.Path]::GetFileName($Input)));Write-OdcChunk $bw $script:ODC.Mime ([Text.Encoding]::UTF8.GetBytes($mime));if($Metadata.Count){Write-OdcChunk $bw $script:ODC.Meta ([Text.Encoding]::UTF8.GetBytes(($Metadata|ConvertTo-Json -Compress -Depth 32)))};Write-OdcChunk $bw $script:ODC.OriginalSize ([BitConverter]::GetBytes([UInt64]$raw.LongLength));Write-OdcChunk $bw $script:ODC.Compression ([byte[]]@($comp));Write-OdcChunk $bw $script:ODC.Sha256 $hash;Write-OdcChunk $bw $script:ODC.Payload $payload}finally{$bw.Dispose();$fs.Dispose()}
    if([IO.File]::Exists($Output)){[IO.File]::Delete($Output)};[IO.File]::Move($tmp,$Output)
}
function Get-OdcInfo([string]$Path) {
    $s=Read-OdcScan $Path;$fn=[Text.Encoding]::UTF8.GetString((Read-OdcSmall $Path $s $script:ODC.FileName 1MB));$mime=[Text.Encoding]::UTF8.GetString((Read-OdcSmall $Path $s $script:ODC.Mime 1MB));$size=[BitConverter]::ToUInt64((Read-OdcSmall $Path $s $script:ODC.OriginalSize 8),0);$cp=(Read-OdcSmall $Path $s $script:ODC.Compression 1)[0];$sha=(Read-OdcSmall $Path $s $script:ODC.Sha256 32);$meta=Read-OdcSmall $Path $s $script:ODC.Meta 16MB $false;$p=$s.Chunks|Where-Object Type -eq $script:ODC.Payload|Select-Object -First 1;if(-not$p){throw 'PAYLOAD ausente'}
    [pscustomobject]@{Magic='ODC1';Version="$($s.Major).$($s.Minor)";Flags=$s.Flags;ChunkCount=$s.Count;FileName=$fn;MimeType=$mime;OriginalSize=$size;StoredPayloadSize=$p.Length;Compression=$(if($cp-eq1){'gzip'}else{'none'});SHA256=([BitConverter]::ToString($sha).Replace('-','').ToLowerInvariant());Metadata=$(if($meta){([Text.Encoding]::UTF8.GetString($meta)|ConvertFrom-Json)}else{$null});Chunks=$s.Chunks}
}
function Expand-OdcFile([string]$Path,[string]$Output) {
    $s=Read-OdcScan $Path;$p=$s.Chunks|Where-Object Type -eq $script:ODC.Payload|Select-Object -First 1;if(-not$p){throw 'PAYLOAD ausente'};$cp=(Read-OdcSmall $Path $s $script:ODC.Compression 1)[0];$fs=[IO.File]::OpenRead($Path);try{$fs.Position=$p.DataOffset;$packed=New-Object byte[] ([int]$p.Length);$off=0;while($off-lt$packed.Length){$n=$fs.Read($packed,$off,$packed.Length-$off);if($n-le0){throw 'PAYLOAD truncado'};$off+=$n}}finally{$fs.Dispose()}
    if($cp-eq1){$ms=[IO.MemoryStream]::new($packed);$gz=[IO.Compression.GZipStream]::new($ms,[IO.Compression.CompressionMode]::Decompress);$out=[IO.MemoryStream]::new();try{$gz.CopyTo($out);$raw=$out.ToArray()}finally{$gz.Dispose();$ms.Dispose();$out.Dispose()}}elseif($cp-eq0){$raw=$packed}else{throw 'Compressão não suportada'}
    $size=[BitConverter]::ToUInt64((Read-OdcSmall $Path $s $script:ODC.OriginalSize 8),0);if($raw.LongLength-ne$size){throw 'Tamanho divergente'};$sha=[Security.Cryptography.SHA256]::Create();try{$actual=$sha.ComputeHash($raw)}finally{$sha.Dispose()};$expected=Read-OdcSmall $Path $s $script:ODC.Sha256 32;$actualHex=[BitConverter]::ToString($actual);$expectedHex=[BitConverter]::ToString($expected);if($actualHex -ne $expectedHex){throw 'SHA-256 inválido'};[IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName([IO.Path]::GetFullPath($Output)))|Out-Null;[IO.File]::WriteAllBytes($Output,$raw)
}
function Test-OdcFile([string]$Path){$t=[IO.Path]::GetTempFileName();try{Expand-OdcFile $Path $t;return $true}catch{return $false}finally{Remove-Item $t -Force -ErrorAction SilentlyContinue}}
function Set-OdcMetadata([string]$Path,[hashtable]$Metadata){$i=Get-OdcInfo $Path;$tmp=Join-Path ([IO.Path]::GetTempPath()) (([Guid]::NewGuid().ToString('N'))+[IO.Path]::GetExtension($i.FileName));try{Expand-OdcFile $Path $tmp;New-OdcFile $tmp $Path $Metadata ($i.Compression-eq'gzip')}finally{Remove-Item $tmp -Force -ErrorAction SilentlyContinue}}
function Remove-OdcMetadata([string]$Path){Set-OdcMetadata $Path @{}}
