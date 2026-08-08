unit OdcStudioMain;

interface

uses
  Winapi.Windows, System.SysUtils, System.Classes, System.JSON, System.IOUtils,
  Vcl.Forms, Vcl.Controls, Vcl.StdCtrls, Vcl.ComCtrls, Vcl.Dialogs,
  Vcl.ExtCtrls, Vcl.Graphics,
  OdcContainer;

type
  TOdcStudioForm = class(TForm)
  private
    Header: TPanel;
    Tabs: TPageControl;
    Status: TStatusBar;
    CreateSource, CreateDest: TEdit;
    CreateMeta: TMemo;
    CreateCompress: TCheckBox;
    InfoPath: TEdit;
    InfoMemo: TMemo;
    ExtractPath, ExtractDest: TEdit;
    MetaPath: TEdit;
    MetaMemo: TMemo;
    function AddTab(const ACaption: string): TTabSheet;
    function AddCard(P: TWinControl; ATop, AHeight: Integer; const ACaption: string): TGroupBox;
    function AddEdit(P: TWinControl; ATop: Integer; const ACaption: string): TEdit;
    function AddButton(P: TWinControl; ATop, ALeft: Integer; const ACaption: string; Handler: TNotifyEvent): TButton;
    function PickOpen(const AFilter: string): string;
    function PickSave(const AFilter: string): string;
    procedure SetStatus(const S: string);
    procedure BuildHeader;
    procedure BuildCreate;
    procedure BuildInfo;
    procedure BuildExtract;
    procedure BuildMeta;
    procedure PickCreateSource(Sender: TObject);
    procedure PickCreateDest(Sender: TObject);
    procedure DoCreate(Sender: TObject);
    procedure PickInfo(Sender: TObject);
    procedure DoVerify(Sender: TObject);
    procedure PickExtract(Sender: TObject);
    procedure PickExtractDest(Sender: TObject);
    procedure DoExtract(Sender: TObject);
    procedure PickMeta(Sender: TObject);
    procedure DoSaveMeta(Sender: TObject);
    procedure DoRemoveMeta(Sender: TObject);
  public
    constructor Create(AOwner: TComponent); override;
  end;

var
  OdcStudioForm: TOdcStudioForm;

implementation

const
  CCanvas = TColor($00F7F5F1);
  CNav = TColor($00271810);
  CBlue = TColor($00EB6325);
  CText = TColor($00372218);
  CMuted = TColor($008B7464);

constructor TOdcStudioForm.Create(AOwner: TComponent);
begin
  inherited;
  Caption := 'ODC Studio Delphi';
  Width := 1120;
  Height := 760;
  Constraints.MinWidth := 980;
  Constraints.MinHeight := 680;
  Position := poScreenCenter;
  Color := CCanvas;
  Font.Name := 'Segoe UI';
  Font.Size := 9;

  BuildHeader;

  Status := TStatusBar.Create(Self);
  Status.Parent := Self;
  Status.Align := alBottom;
  Status.SimplePanel := True;
  Status.SimpleText := 'Pronto · ODC1 · SDK 1.1.0';

  Tabs := TPageControl.Create(Self);
  Tabs.Parent := Self;
  Tabs.Align := alClient;
  Tabs.TabHeight := 34;
  Tabs.Font.Name := 'Segoe UI';
  Tabs.Font.Size := 9;

  BuildCreate;
  BuildInfo;
  BuildExtract;
  BuildMeta;
end;

procedure TOdcStudioForm.BuildHeader;
var
  Brand, SubTitle, Badge: TLabel;
begin
  Header := TPanel.Create(Self);
  Header.Parent := Self;
  Header.Align := alTop;
  Header.Height := 78;
  Header.BevelOuter := bvNone;
  Header.Color := CNav;

  Brand := TLabel.Create(Self);
  Brand.Parent := Header;
  Brand.Left := 24;
  Brand.Top := 17;
  Brand.Caption := 'ODC Studio';
  Brand.Font.Name := 'Segoe UI';
  Brand.Font.Size := 16;
  Brand.Font.Style := [fsBold];
  Brand.Font.Color := clWhite;

  SubTitle := TLabel.Create(Self);
  SubTitle.Parent := Header;
  SubTitle.Left := 25;
  SubTitle.Top := 48;
  SubTitle.Caption := 'Optical Data Container · Delphi / VCL';
  SubTitle.Font.Name := 'Segoe UI';
  SubTitle.Font.Size := 8;
  SubTitle.Font.Color := TColor($00C3A896);

  Badge := TLabel.Create(Self);
  Badge.Parent := Header;
  Badge.Align := alRight;
  Badge.Width := 95;
  Badge.Alignment := taCenter;
  Badge.Layout := tlCenter;
  Badge.Caption := 'ODC1';
  Badge.Font.Name := 'Segoe UI';
  Badge.Font.Size := 10;
  Badge.Font.Style := [fsBold];
  Badge.Font.Color := clWhite;
  Badge.Color := CBlue;
  Badge.Transparent := False;
end;

function TOdcStudioForm.AddTab(const ACaption: string): TTabSheet;
begin
  Result := TTabSheet.Create(Self);
  Result.PageControl := Tabs;
  Result.Caption := ACaption;
  Result.Color := CCanvas;
end;

function TOdcStudioForm.AddCard(P: TWinControl; ATop, AHeight: Integer; const ACaption: string): TGroupBox;
begin
  Result := TGroupBox.Create(Self);
  Result.Parent := P;
  Result.Caption := ACaption;
  Result.Left := 20;
  Result.Top := ATop;
  Result.Width := 1040;
  Result.Height := AHeight;
  Result.Anchors := [akLeft, akTop, akRight];
  Result.Font.Name := 'Segoe UI';
  Result.Font.Size := 9;
  Result.Font.Style := [fsBold];
  Result.Color := clWhite;
end;

function TOdcStudioForm.AddEdit(P: TWinControl; ATop: Integer; const ACaption: string): TEdit;
var
  L: TLabel;
begin
  L := TLabel.Create(Self);
  L.Parent := P;
  L.Caption := UpperCase(ACaption);
  L.Left := 18;
  L.Top := ATop;
  L.Font.Name := 'Segoe UI';
  L.Font.Size := 8;
  L.Font.Style := [fsBold];
  L.Font.Color := CMuted;

  Result := TEdit.Create(Self);
  Result.Parent := P;
  Result.Left := 18;
  Result.Top := ATop + 22;
  Result.Width := 840;
  Result.Height := 28;
  Result.Anchors := [akLeft, akTop, akRight];
  Result.Font.Name := 'Segoe UI';
  Result.Font.Size := 9;
end;

function TOdcStudioForm.AddButton(P: TWinControl; ATop, ALeft: Integer; const ACaption: string; Handler: TNotifyEvent): TButton;
begin
  Result := TButton.Create(Self);
  Result.Parent := P;
  Result.Caption := ACaption;
  Result.Left := ALeft;
  Result.Top := ATop;
  Result.Height := 34;
  Result.Width := 132;
  Result.OnClick := Handler;
  Result.Font.Name := 'Segoe UI';
  Result.Font.Size := 8;
  Result.Font.Style := [fsBold];
end;

function TOdcStudioForm.PickOpen(const AFilter: string): string;
var
  D: TOpenDialog;
begin
  Result := '';
  D := TOpenDialog.Create(nil);
  try
    D.Filter := AFilter;
    if D.Execute then
      Result := D.FileName;
  finally
    D.Free;
  end;
end;

function TOdcStudioForm.PickSave(const AFilter: string): string;
var
  D: TSaveDialog;
begin
  Result := '';
  D := TSaveDialog.Create(nil);
  try
    D.Filter := AFilter;
    if D.Execute then
      Result := D.FileName;
  finally
    D.Free;
  end;
end;

procedure TOdcStudioForm.SetStatus(const S: string);
begin
  Status.SimpleText := S;
end;

procedure TOdcStudioForm.BuildCreate;
var
  P: TTabSheet;
  Card: TGroupBox;
  L: TLabel;
begin
  P := AddTab('Criar container');
  Card := AddCard(P, 18, 550, 'Novo container ODC');
  CreateSource := AddEdit(Card, 48, 'Arquivo de origem');
  AddButton(Card, 68, 875, 'Selecionar', PickCreateSource);
  CreateDest := AddEdit(Card, 118, 'Destino ODC');
  AddButton(Card, 138, 875, 'Destino', PickCreateDest);

  L := TLabel.Create(Self);
  L.Parent := Card;
  L.Caption := 'METADATA JSON';
  L.Left := 18;
  L.Top := 190;
  L.Font.Name := 'Segoe UI';
  L.Font.Size := 8;
  L.Font.Style := [fsBold];
  L.Font.Color := CMuted;

  CreateMeta := TMemo.Create(Self);
  CreateMeta.Parent := Card;
  CreateMeta.Left := 18;
  CreateMeta.Top := 214;
  CreateMeta.Width := 990;
  CreateMeta.Height := 220;
  CreateMeta.Anchors := [akLeft, akTop, akRight];
  CreateMeta.ScrollBars := ssBoth;
  CreateMeta.WordWrap := False;
  CreateMeta.Font.Name := 'Consolas';
  CreateMeta.Font.Size := 9;
  CreateMeta.Lines.Text := '{'#13#10'  "origem": "ODC Studio Delphi"'#13#10'}';

  CreateCompress := TCheckBox.Create(Self);
  CreateCompress.Parent := Card;
  CreateCompress.Left := 18;
  CreateCompress.Top := 452;
  CreateCompress.Caption := 'Compressão adaptativa';
  CreateCompress.Checked := True;

  AddButton(Card, 486, 18, 'Criar ODC', DoCreate);
end;

procedure TOdcStudioForm.BuildInfo;
var
  P: TTabSheet;
  Card, DataCard: TGroupBox;
begin
  P := AddTab('Inspecionar');
  Card := AddCard(P, 18, 130, 'Inspeção e validação');
  InfoPath := AddEdit(Card, 42, 'Arquivo ODC');
  AddButton(Card, 62, 875, 'Abrir', PickInfo);
  AddButton(Card, 96, 18, 'Validar SHA-256', DoVerify);

  DataCard := AddCard(P, 162, 410, 'Informações do container');
  InfoMemo := TMemo.Create(Self);
  InfoMemo.Parent := DataCard;
  InfoMemo.Left := 18;
  InfoMemo.Top := 34;
  InfoMemo.Width := 990;
  InfoMemo.Height := 345;
  InfoMemo.Anchors := [akLeft, akTop, akRight, akBottom];
  InfoMemo.ScrollBars := ssBoth;
  InfoMemo.WordWrap := False;
  InfoMemo.ReadOnly := True;
  InfoMemo.Font.Name := 'Consolas';
  InfoMemo.Font.Size := 9;
  InfoMemo.Color := TColor($0027160D);
  InfoMemo.Font.Color := TColor($00F4E4D9);
end;

procedure TOdcStudioForm.BuildExtract;
var
  P: TTabSheet;
  Card: TGroupBox;
begin
  P := AddTab('Extrair payload');
  Card := AddCard(P, 18, 280, 'Extrair arquivo original');
  ExtractPath := AddEdit(Card, 48, 'Arquivo ODC');
  AddButton(Card, 68, 875, 'Abrir', PickExtract);
  ExtractDest := AddEdit(Card, 118, 'Destino do original');
  AddButton(Card, 138, 875, 'Destino', PickExtractDest);
  AddButton(Card, 198, 18, 'Extrair original', DoExtract);
end;

procedure TOdcStudioForm.BuildMeta;
var
  P: TTabSheet;
  Card: TGroupBox;
  L: TLabel;
begin
  P := AddTab('Metadata');
  Card := AddCard(P, 18, 550, 'Editor de metadata');
  MetaPath := AddEdit(Card, 42, 'Arquivo ODC');
  AddButton(Card, 62, 875, 'Abrir', PickMeta);

  L := TLabel.Create(Self);
  L.Parent := Card;
  L.Caption := 'METADATA JSON';
  L.Left := 18;
  L.Top := 118;
  L.Font.Style := [fsBold];
  L.Font.Size := 8;
  L.Font.Color := CMuted;

  MetaMemo := TMemo.Create(Self);
  MetaMemo.Parent := Card;
  MetaMemo.Left := 18;
  MetaMemo.Top := 142;
  MetaMemo.Width := 990;
  MetaMemo.Height := 315;
  MetaMemo.Anchors := [akLeft, akTop, akRight, akBottom];
  MetaMemo.ScrollBars := ssBoth;
  MetaMemo.WordWrap := False;
  MetaMemo.Font.Name := 'Consolas';
  MetaMemo.Font.Size := 9;

  AddButton(Card, 478, 18, 'Salvar metadata', DoSaveMeta);
  AddButton(Card, 478, 164, 'Remover metadata', DoRemoveMeta);
end;

procedure TOdcStudioForm.PickCreateSource(Sender: TObject);
var S: string;
begin S := PickOpen('Todos os arquivos|*.*'); if S <> '' then CreateSource.Text := S; end;

procedure TOdcStudioForm.PickCreateDest(Sender: TObject);
var S: string;
begin S := PickSave('ODC (*.odc)|*.odc'); if S <> '' then CreateDest.Text := S; end;

procedure TOdcStudioForm.DoCreate(Sender: TObject);
begin
  try
    TOdc.CreateFromFile(CreateSource.Text, CreateDest.Text, CreateMeta.Text, CreateCompress.Checked);
    SetStatus('Container criado: ' + CreateDest.Text);
    MessageDlg('Container ODC criado com sucesso.', mtInformation, [mbOK], 0);
  except on E: Exception do begin SetStatus('Falha ao criar container.'); MessageDlg(E.Message, mtError, [mbOK], 0); end; end;
end;

procedure TOdcStudioForm.PickInfo(Sender: TObject);
var S: string; I: TOdcInfo;
begin
  S := PickOpen('ODC (*.odc)|*.odc'); if S = '' then Exit;
  InfoPath.Text := S;
  try
    I := TOdc.Info(S);
    InfoMemo.Lines.Text := Format('Arquivo: %s'#13#10'MIME: %s'#13#10'Original: %d bytes'#13#10'Payload: %d bytes'#13#10'Compressão: %d'#13#10'SHA256: %s'#13#10#13#10'Metadata:'#13#10'%s', [I.FileName, I.MimeType, I.OriginalSize, I.StoredPayloadSize, I.Compression, I.SHA256Hex, I.MetadataJson]);
    MetaPath.Text := S;
    MetaMemo.Text := I.MetadataJson;
    SetStatus('ODC carregado: ' + I.FileName);
  except on E: Exception do MessageDlg(E.Message, mtError, [mbOK], 0); end;
end;

procedure TOdcStudioForm.DoVerify(Sender: TObject);
begin
  try
    if TOdc.Verify(InfoPath.Text) then begin SetStatus('SHA-256 válido.'); MessageDlg('Arquivo íntegro.', mtInformation, [mbOK], 0); end
    else begin SetStatus('Falha de integridade.'); MessageDlg('Arquivo inválido.', mtWarning, [mbOK], 0); end;
  except on E: Exception do MessageDlg(E.Message, mtError, [mbOK], 0); end;
end;

procedure TOdcStudioForm.PickExtract(Sender: TObject);
var S: string;
begin S := PickOpen('ODC (*.odc)|*.odc'); if S <> '' then ExtractPath.Text := S; end;

procedure TOdcStudioForm.PickExtractDest(Sender: TObject);
var S: string;
begin S := PickSave('Todos os arquivos|*.*'); if S <> '' then ExtractDest.Text := S; end;

procedure TOdcStudioForm.DoExtract(Sender: TObject);
begin
  try
    TOdc.Extract(ExtractPath.Text, ExtractDest.Text);
    SetStatus('Payload extraído: ' + ExtractDest.Text);
    MessageDlg('Extração concluída.', mtInformation, [mbOK], 0);
  except on E: Exception do MessageDlg(E.Message, mtError, [mbOK], 0); end;
end;

procedure TOdcStudioForm.PickMeta(Sender: TObject);
var S: string; I: TOdcInfo;
begin
  S := PickOpen('ODC (*.odc)|*.odc'); if S = '' then Exit;
  MetaPath.Text := S;
  try I := TOdc.Info(S); MetaMemo.Text := I.MetadataJson; SetStatus('Metadata carregada: ' + I.FileName); except on E: Exception do MessageDlg(E.Message, mtError, [mbOK], 0); end;
end;

procedure TOdcStudioForm.DoSaveMeta(Sender: TObject);
begin
  try TOdc.SetMetadata(MetaPath.Text, MetaMemo.Text); SetStatus('Metadata atualizada.'); MessageDlg('Metadata atualizada.', mtInformation, [mbOK], 0); except on E: Exception do MessageDlg(E.Message, mtError, [mbOK], 0); end;
end;

procedure TOdcStudioForm.DoRemoveMeta(Sender: TObject);
begin
  try TOdc.RemoveMetadata(MetaPath.Text); MetaMemo.Clear; SetStatus('Metadata removida.'); MessageDlg('Metadata removida.', mtInformation, [mbOK], 0); except on E: Exception do MessageDlg(E.Message, mtError, [mbOK], 0); end;
end;

end.
