Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
. "$PSScriptRoot\Odc.Core.ps1"
[Windows.Forms.Application]::EnableVisualStyles()
$form=New-Object Windows.Forms.Form;$form.Text='ODC Studio 1.0';$form.Width=900;$form.Height=650;$form.StartPosition='CenterScreen'
$tabs=New-Object Windows.Forms.TabControl;$tabs.Dock='Fill';$form.Controls.Add($tabs)
function Add-Tab($name){$t=New-Object Windows.Forms.TabPage;$t.Text=$name;$tabs.TabPages.Add($t)|Out-Null;return $t}
function Pick-Open($filter='Todos|*.*'){$d=New-Object Windows.Forms.OpenFileDialog;$d.Filter=$filter;if($d.ShowDialog()-eq'OK'){return $d.FileName}return $null}
function Pick-Save($filter='Todos|*.*'){$d=New-Object Windows.Forms.SaveFileDialog;$d.Filter=$filter;if($d.ShowDialog()-eq'OK'){return $d.FileName}return $null}
function Lbl($p,$text,$x,$y){$l=New-Object Windows.Forms.Label;$l.Text=$text;$l.Left=$x;$l.Top=$y;$l.AutoSize=$true;$p.Controls.Add($l);$l}
function Txt($p,$x,$y,$w=650){$t=New-Object Windows.Forms.TextBox;$t.Left=$x;$t.Top=$y;$t.Width=$w;$p.Controls.Add($t);$t}
function Btn($p,$text,$x,$y,$handler){$b=New-Object Windows.Forms.Button;$b.Text=$text;$b.Left=$x;$b.Top=$y;$b.Width=120;$b.Add_Click($handler);$p.Controls.Add($b);$b}

# Criar
$t=Add-Tab 'Criar';Lbl $t 'Arquivo origem' 20 25;$src=Txt $t 20 48;Btn $t 'Selecionar' 690 46 {$p=Pick-Open;if($p){$src.Text=$p}}|Out-Null;Lbl $t 'Arquivo ODC' 20 85;$dst=Txt $t 20 108;Btn $t 'Destino' 690 106 {$p=Pick-Save 'ODC|*.odc';if($p){$dst.Text=$p}}|Out-Null;Lbl $t 'Metadata JSON (opcional)' 20 145;$meta=New-Object Windows.Forms.TextBox;$meta.Left=20;$meta.Top=168;$meta.Width=790;$meta.Height=250;$meta.Multiline=$true;$meta.ScrollBars='Both';$t.Controls.Add($meta);$compress=New-Object Windows.Forms.CheckBox;$compress.Text='Compressão adaptativa';$compress.Checked=$true;$compress.Left=20;$compress.Top=435;$t.Controls.Add($compress);Btn $t 'Criar ODC' 20 475 {try{$m=@{};if($meta.Text.Trim()){$o=$meta.Text|ConvertFrom-Json;$o.psobject.Properties|%{$m[$_.Name]=$_.Value}};New-OdcFile $src.Text $dst.Text $m $compress.Checked;[Windows.Forms.MessageBox]::Show('ODC criado com sucesso.')}catch{[Windows.Forms.MessageBox]::Show($_.Exception.Message,'Erro')}}|Out-Null

# Abrir/Info
$t=Add-Tab 'Abrir / Informações';$open=Txt $t 20 25;Btn $t 'Abrir ODC' 690 23 {$p=Pick-Open 'ODC|*.odc';if($p){$open.Text=$p;try{$i=Get-OdcInfo $p;$info.Text=$i|ConvertTo-Json -Depth 10}catch{$info.Text=$_.Exception.Message}}}|Out-Null;$info=New-Object Windows.Forms.TextBox;$info.Left=20;$info.Top=65;$info.Width=790;$info.Height=450;$info.Multiline=$true;$info.ScrollBars='Both';$info.Font=New-Object Drawing.Font('Consolas',10);$t.Controls.Add($info);Btn $t 'Validar' 20 530 {try{if(Test-OdcFile $open.Text){[Windows.Forms.MessageBox]::Show('Arquivo íntegro.')}else{[Windows.Forms.MessageBox]::Show('Arquivo inválido.')}}catch{[Windows.Forms.MessageBox]::Show($_.Exception.Message)}}|Out-Null

# Extrair
$t=Add-Tab 'Extrair';$extIn=Txt $t 20 35;Btn $t 'Abrir ODC' 690 33 {$p=Pick-Open 'ODC|*.odc';if($p){$extIn.Text=$p}}|Out-Null;$extOut=Txt $t 20 85;Btn $t 'Destino' 690 83 {$p=Pick-Save;if($p){$extOut.Text=$p}}|Out-Null;Btn $t 'Extrair' 20 130 {try{Expand-OdcFile $extIn.Text $extOut.Text;[Windows.Forms.MessageBox]::Show('Extração concluída.')}catch{[Windows.Forms.MessageBox]::Show($_.Exception.Message)}}|Out-Null

# Metadata
$t=Add-Tab 'Editar Metadata';$ed=Txt $t 20 25;$edMeta=New-Object Windows.Forms.TextBox;$edMeta.Left=20;$edMeta.Top=65;$edMeta.Width=790;$edMeta.Height=390;$edMeta.Multiline=$true;$edMeta.ScrollBars='Both';$t.Controls.Add($edMeta);Btn $t 'Abrir ODC' 690 23 {$p=Pick-Open 'ODC|*.odc';if($p){$ed.Text=$p;try{$i=Get-OdcInfo $p;$edMeta.Text=$(if($i.Metadata){$i.Metadata|ConvertTo-Json -Depth 20}else{'{}'})}catch{$edMeta.Text=$_.Exception.Message}}}|Out-Null;Btn $t 'Salvar Metadata' 20 475 {try{$h=@{};$o=$edMeta.Text|ConvertFrom-Json;$o.psobject.Properties|%{$h[$_.Name]=$_.Value};Set-OdcMetadata $ed.Text $h;[Windows.Forms.MessageBox]::Show('Metadata atualizada.')}catch{[Windows.Forms.MessageBox]::Show($_.Exception.Message)}}|Out-Null;Btn $t 'Remover Metadata' 160 475 {try{Remove-OdcMetadata $ed.Text;$edMeta.Text='{}';[Windows.Forms.MessageBox]::Show('Metadata removida.')}catch{[Windows.Forms.MessageBox]::Show($_.Exception.Message)}}|Out-Null

[void]$form.ShowDialog()
