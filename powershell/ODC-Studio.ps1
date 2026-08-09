$ErrorActionPreference = 'Stop'

try {
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing
    . "$PSScriptRoot\Odc.Core.ps1"

    # O Core ativa StrictMode para o codec. A interface WinForms não deve
    # herdar esse modo para variáveis capturadas pelos handlers de eventos.
    Set-StrictMode -Off

    [Windows.Forms.Application]::EnableVisualStyles()
    [Windows.Forms.Application]::SetCompatibleTextRenderingDefault($false)

    $nav = [Drawing.Color]::FromArgb(16,24,39)
    $blue = [Drawing.Color]::FromArgb(37,99,235)
    $canvas = [Drawing.Color]::FromArgb(241,245,249)
    $text = [Drawing.Color]::FromArgb(24,34,55)
    $muted = [Drawing.Color]::FromArgb(100,116,139)

    $form = New-Object Windows.Forms.Form
    $form.Text = 'ODC Studio PowerShell'
    $form.Width = 1120
    $form.Height = 760
    $form.MinimumSize = New-Object Drawing.Size -ArgumentList 980,680
    $form.StartPosition = 'CenterScreen'
    $form.BackColor = $canvas
    $form.Font = New-Object Drawing.Font -ArgumentList 'Segoe UI',9

    $top = New-Object Windows.Forms.Panel
    $top.Dock = 'Top'; $top.Height = 76; $top.BackColor = [Drawing.Color]::White
    $form.Controls.Add($top)
    $title = New-Object Windows.Forms.Label
    $title.Text = 'ODC Studio'; $title.Left = 28; $title.Top = 24; $title.AutoSize = $true; $title.Font = New-Object Drawing.Font -ArgumentList 'Segoe UI',16,[Drawing.FontStyle]::Bold; $title.ForeColor = $text
    $top.Controls.Add($title)
    $sub = New-Object Windows.Forms.Label
    $sub.Text = 'PowerShell / Windows Forms'; $sub.Left = 155; $sub.Top = 31; $sub.AutoSize = $true; $sub.ForeColor = $muted
    $top.Controls.Add($sub)
    $chip = New-Object Windows.Forms.Label
    $chip.Text = 'ODC1'; $chip.Width = 62; $chip.Height = 28; $chip.Top = 24; $chip.Left = 1000; $chip.Anchor = 'Top,Right'; $chip.TextAlign='MiddleCenter'; $chip.BackColor=[Drawing.Color]::FromArgb(239,246,255); $chip.ForeColor=[Drawing.Color]::FromArgb(29,78,216); $chip.Font=New-Object Drawing.Font -ArgumentList 'Segoe UI',8,[Drawing.FontStyle]::Bold
    $top.Controls.Add($chip)

    $status = New-Object Windows.Forms.StatusStrip
    $status.SizingGrip = $false
    $statusLabel = New-Object Windows.Forms.ToolStripStatusLabel
    $statusLabel.Text = 'Pronto'
    $statusLabel.Spring = $true
    $statusLabel.TextAlign = 'MiddleLeft'
    [void]$status.Items.Add($statusLabel)
    $verLabel = New-Object Windows.Forms.ToolStripStatusLabel
    $verLabel.Text = 'ODC Studio PowerShell · SDK 1.1.1'
    [void]$status.Items.Add($verLabel)
    $form.Controls.Add($status)

    $tabs = New-Object Windows.Forms.TabControl
    $tabs.Dock = 'Fill'; $tabs.Padding = New-Object Drawing.Point -ArgumentList 18,8; $tabs.Font = New-Object Drawing.Font -ArgumentList 'Segoe UI',9,[Drawing.FontStyle]::Bold
    $form.Controls.Add($tabs)
    $tabs.BringToFront(); $status.BringToFront(); $top.BringToFront()

    function Add-Tab([string]$name){$t=New-Object Windows.Forms.TabPage;$t.Text=$name;$t.BackColor=$canvas;$t.Padding=New-Object Windows.Forms.Padding -ArgumentList 18;$null=$tabs.TabPages.Add($t);return $t}
    function Pick-Open([string]$filter='Todos os arquivos|*.*'){$d=New-Object Windows.Forms.OpenFileDialog;$d.Filter=$filter;try{if($d.ShowDialog()-eq'OK'){return $d.FileName}}finally{$d.Dispose()};return $null}
    function Pick-Save([string]$filter='Todos os arquivos|*.*'){$d=New-Object Windows.Forms.SaveFileDialog;$d.Filter=$filter;try{if($d.ShowDialog()-eq'OK'){return $d.FileName}}finally{$d.Dispose()};return $null}
    function Card($p,[int]$x,[int]$y,[int]$w,[int]$h,[string]$title,[string]$subtitle=''){$g=New-Object Windows.Forms.GroupBox;$g.Text=$title;$g.Left=$x;$g.Top=$y;$g.Width=$w;$g.Height=$h;$g.Anchor='Top,Left,Right';$g.BackColor=[Drawing.Color]::White;$g.ForeColor=$text;$g.Font=New-Object Drawing.Font -ArgumentList 'Segoe UI',9,[Drawing.FontStyle]::Bold;$p.Controls.Add($g);if($subtitle){$l=New-Object Windows.Forms.Label;$l.Text=$subtitle;$l.Left=16;$l.Top=28;$l.Width=$w-32;$l.Height=20;$l.ForeColor=$muted;$l.Font=New-Object Drawing.Font -ArgumentList 'Segoe UI',8;$g.Controls.Add($l)};return $g}
    function Lbl($p,$labelText,$x,$y){$l=New-Object Windows.Forms.Label;$l.Text=$labelText;$l.Left=$x;$l.Top=$y;$l.AutoSize=$true;$l.ForeColor=$muted;$l.Font=New-Object Drawing.Font -ArgumentList 'Segoe UI',8,[Drawing.FontStyle]::Bold;$p.Controls.Add($l);return $l}
    function Txt($p,$x,$y,$w=650){$t=New-Object Windows.Forms.TextBox;$t.Left=$x;$t.Top=$y;$t.Width=$w;$t.Height=28;$t.BorderStyle='FixedSingle';$t.BackColor=[Drawing.Color]::FromArgb(251,252,254);$p.Controls.Add($t);return $t}
    function Multi($p,$x,$y,$w,$h){$t=New-Object Windows.Forms.TextBox;$t.Left=$x;$t.Top=$y;$t.Width=$w;$t.Height=$h;$t.Multiline=$true;$t.ScrollBars='Both';$t.AcceptsTab=$true;$t.Font=New-Object Drawing.Font -ArgumentList 'Consolas',9;$t.BorderStyle='FixedSingle';$t.BackColor=[Drawing.Color]::FromArgb(251,252,254);$p.Controls.Add($t);return $t}
    function Btn($p,$buttonText,$x,$y,$handler,[bool]$primary=$false){$b=New-Object Windows.Forms.Button;$b.Text=$buttonText;$b.Left=$x;$b.Top=$y;$b.Height=34;$b.AutoSize=$true;$b.FlatStyle='Flat';$b.Font=New-Object Drawing.Font -ArgumentList 'Segoe UI',8,[Drawing.FontStyle]::Bold;if($primary){$b.BackColor=$blue;$b.ForeColor=[Drawing.Color]::White;$b.FlatAppearance.BorderColor=$blue}else{$b.BackColor=[Drawing.Color]::White;$b.ForeColor=$text;$b.FlatAppearance.BorderColor=[Drawing.Color]::FromArgb(203,213,225)};$b.Add_Click($handler);$p.Controls.Add($b);return $b}
    function Msg([string]$message,[string]$caption='ODC Studio'){[Windows.Forms.MessageBox]::Show($message,$caption,[Windows.Forms.MessageBoxButtons]::OK,[Windows.Forms.MessageBoxIcon]::Information)|Out-Null}
    function Fail($e){$statusLabel.Text='Falha na operação';$message=if($e -is [System.Management.Automation.ErrorRecord]){$e.Exception.Message}else{[string]$e};[Windows.Forms.MessageBox]::Show($message,'ODC Studio',[Windows.Forms.MessageBoxButtons]::OK,[Windows.Forms.MessageBoxIcon]::Error)|Out-Null}

    # Criar
    $t=Add-Tab 'Criar container'
    $c=Card $t 18 18 1010 560 'Novo container ODC' 'Selecione a origem, destino e metadata opcional.'
    Lbl $c 'ARQUIVO DE ORIGEM' 18 62|Out-Null;$src=Txt $c 18 84 820;Btn $c 'Selecionar' 850 81 {$p=Pick-Open;if($p){$src.Text=$p;if(-not $dst.Text){$dst.Text=[IO.Path]::ChangeExtension($p,'.odc')}}}|Out-Null
    Lbl $c 'DESTINO .ODC' 18 126|Out-Null;$dst=Txt $c 18 148 820;Btn $c 'Destino' 850 145 {$p=Pick-Save 'ODC (*.odc)|*.odc';if($p){$dst.Text=$p}}|Out-Null
    Lbl $c 'METADATA JSON' 18 192|Out-Null;$meta=Multi $c 18 214 950 230;$meta.Text="{`r`n  `"origem`": `"ODC Studio PowerShell`"`r`n}"
    $compress=New-Object Windows.Forms.CheckBox;$compress.Text='Compressão adaptativa';$compress.Checked=$true;$compress.Left=18;$compress.Top=462;$compress.AutoSize=$true;$compress.ForeColor=$text;$c.Controls.Add($compress)
    Btn $c 'Criar ODC' 18 500 {try{if(-not(Test-Path -LiteralPath $src.Text -PathType Leaf)){throw 'Selecione um arquivo de origem válido.'};if([string]::IsNullOrWhiteSpace($dst.Text)){throw 'Informe o destino do arquivo ODC.'};$m=@{};if($meta.Text.Trim()){$o=$meta.Text|ConvertFrom-Json;$o.psobject.Properties|ForEach-Object{$m[$_.Name]=$_.Value}};New-OdcFile $src.Text $dst.Text $m $compress.Checked;$statusLabel.Text="Container criado: $($dst.Text)";Msg 'Container ODC criado com sucesso.'}catch{Fail $_}} $true|Out-Null

    # Inspecionar
    $t=Add-Tab 'Inspecionar'
    $c=Card $t 18 18 1010 120 'Inspeção e validação' 'Leia estrutura, metadata e SHA-256 do container.'
    Lbl $c 'ARQUIVO ODC' 18 54|Out-Null;$open=Txt $c 18 76 740
    Btn $c 'Abrir' 770 73 {$p=Pick-Open 'ODC (*.odc)|*.odc';if($p){$open.Text=$p;try{$i=Get-OdcInfo $p;$info.Text=$i|ConvertTo-Json -Depth 20;$ed.Text=$p;$edMeta.Text=$(if($i.Metadata){$i.Metadata|ConvertTo-Json -Depth 20}else{'{}'});$statusLabel.Text="ODC carregado: $($i.FileName)"}catch{Fail $_}}}|Out-Null
    Btn $c 'Validar SHA-256' 850 73 {try{if(Test-OdcFile $open.Text){$statusLabel.Text='SHA-256 válido';Msg 'Arquivo íntegro.'}else{throw 'Arquivo inválido ou corrompido.'}}catch{Fail $_}} $true|Out-Null
    $c2=Card $t 18 152 1010 425 'Informações do container'
    $info=Multi $c2 18 42 950 350;$info.ReadOnly=$true;$info.BackColor=[Drawing.Color]::FromArgb(13,22,39);$info.ForeColor=[Drawing.Color]::FromArgb(217,228,244)

    # Extrair
    $t=Add-Tab 'Extrair payload'
    $c=Card $t 18 18 1010 260 'Extrair arquivo original' 'O payload é validado antes da gravação final.'
    Lbl $c 'ARQUIVO ODC' 18 62|Out-Null;$extIn=Txt $c 18 84 820;Btn $c 'Abrir' 850 81 {$p=Pick-Open 'ODC (*.odc)|*.odc';if($p){$extIn.Text=$p}}|Out-Null
    Lbl $c 'DESTINO DO ORIGINAL' 18 126|Out-Null;$extOut=Txt $c 18 148 820;Btn $c 'Destino' 850 145 {$p=Pick-Save;if($p){$extOut.Text=$p}}|Out-Null
    Btn $c 'Extrair original' 18 196 {try{Expand-OdcFile $extIn.Text $extOut.Text;$statusLabel.Text="Payload extraído: $($extOut.Text)";Msg 'Extração concluída.'}catch{Fail $_}} $true|Out-Null

    # Metadata
    $t=Add-Tab 'Metadata'
    $c=Card $t 18 18 1010 560 'Editor de metadata' 'Abra um ODC e edite somente os dados auxiliares.'
    Lbl $c 'ARQUIVO ODC' 18 58|Out-Null;$ed=Txt $c 18 80 820;Btn $c 'Abrir' 850 77 {$p=Pick-Open 'ODC (*.odc)|*.odc';if($p){$ed.Text=$p;try{$i=Get-OdcInfo $p;$edMeta.Text=$(if($i.Metadata){$i.Metadata|ConvertTo-Json -Depth 20}else{'{}'})}catch{Fail $_}}}|Out-Null
    Lbl $c 'METADATA JSON' 18 124|Out-Null;$edMeta=Multi $c 18 146 950 315;$edMeta.Text='{}'
    Btn $c 'Salvar metadata' 18 480 {try{$h=@{};$o=$edMeta.Text|ConvertFrom-Json;$o.psobject.Properties|ForEach-Object{$h[$_.Name]=$_.Value};Set-OdcMetadata $ed.Text $h;$statusLabel.Text='Metadata atualizada';Msg 'Metadata atualizada.'}catch{Fail $_}} $true|Out-Null
    Btn $c 'Remover metadata' 160 480 {try{Remove-OdcMetadata $ed.Text;$edMeta.Text='{}';$statusLabel.Text='Metadata removida';Msg 'Metadata removida.'}catch{Fail $_}}|Out-Null

    # Self-test de startup: constrói toda a UI, confirma que o Core foi carregado
    # e sai sem abrir a janela. O launcher/CI usam este caminho.
    if($env:ODC_STUDIO_SELF_TEST -eq '1'){
        foreach($cmdName in @('New-OdcFile','Get-OdcInfo','Expand-OdcFile','Test-OdcFile','Set-OdcMetadata','Remove-OdcMetadata')){
            if(-not(Get-Command $cmdName -ErrorAction SilentlyContinue)){throw "Comando obrigatório não carregado: $cmdName"}
        }
        [Console]::Out.WriteLine('ODC_STUDIO_SELF_TEST_OK')
        $form.Dispose()
        exit 0
    }

    [void]$form.ShowDialog()
}
catch {
    [Console]::Error.WriteLine(($_ | Out-String))
    exit 1
}
