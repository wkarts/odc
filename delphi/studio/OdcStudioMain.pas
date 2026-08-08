unit OdcStudioMain;

interface

uses
  Winapi.Windows, System.SysUtils, System.Classes, System.JSON, System.IOUtils,
  Vcl.Forms, Vcl.Controls, Vcl.StdCtrls, Vcl.ComCtrls, Vcl.Dialogs,
  OdcContainer;

type
  TOdcStudioForm = class(TForm)
  private
    Tabs: TPageControl;
    CreateSource, CreateDest, CreateMeta: TEdit;
    InfoPath: TEdit; InfoMemo: TMemo;
    ExtractPath, ExtractDest: TEdit;
    MetaPath: TEdit; MetaMemo: TMemo;
    function AddTab(const Caption: string): TTabSheet;
    function AddEdit(P: TWinControl; Top: Integer; const Caption: string): TEdit;
    function AddButton(P: TWinControl; Top, Left: Integer; const Caption: string; Handler: TNotifyEvent): TButton;
    function PickOpen(const Filter: string): string;
    function PickSave(const Filter: string): string;
    procedure BuildCreate; procedure BuildInfo; procedure BuildExtract; procedure BuildMeta;
    procedure PickCreateSource(Sender: TObject); procedure PickCreateDest(Sender: TObject); procedure DoCreate(Sender: TObject);
    procedure PickInfo(Sender: TObject); procedure DoVerify(Sender: TObject);
    procedure PickExtract(Sender: TObject); procedure PickExtractDest(Sender: TObject); procedure DoExtract(Sender: TObject);
    procedure PickMeta(Sender: TObject); procedure DoSaveMeta(Sender: TObject); procedure DoRemoveMeta(Sender: TObject);
  public
    constructor Create(AOwner: TComponent); override;
  end;

var OdcStudioForm: TOdcStudioForm;

implementation

constructor TOdcStudioForm.Create(AOwner: TComponent);
begin
  inherited;
  Caption := 'ODC Studio Delphi 1.0'; Width := 960; Height := 700; Position := poScreenCenter;
  Tabs := TPageControl.Create(Self); Tabs.Parent := Self; Tabs.Align := alClient;
  BuildCreate; BuildInfo; BuildExtract; BuildMeta;
end;

function TOdcStudioForm.AddTab(const Caption: string): TTabSheet;
begin Result:=TTabSheet.Create(Self); Result.PageControl:=Tabs; Result.Caption:=Caption; end;
function TOdcStudioForm.AddEdit(P:TWinControl;Top:Integer;const Caption:string):TEdit;
var L:TLabel; begin L:=TLabel.Create(Self);L.Parent:=P;L.Caption:=Caption;L.Left:=16;L.Top:=Top+4;Result:=TEdit.Create(Self);Result.Parent:=P;Result.Left:=140;Result.Top:=Top;Result.Width:=650;end;
function TOdcStudioForm.AddButton(P:TWinControl;Top,Left:Integer;const Caption:string;Handler:TNotifyEvent):TButton;
begin Result:=TButton.Create(Self);Result.Parent:=P;Result.Caption:=Caption;Result.Left:=Left;Result.Top:=Top;Result.Width:=120;Result.OnClick:=Handler;end;
function TOdcStudioForm.PickOpen(const Filter:string):string; var D:TOpenDialog; begin Result:='';D:=TOpenDialog.Create(nil);try D.Filter:=Filter;if D.Execute then Result:=D.FileName;finally D.Free;end;end;
function TOdcStudioForm.PickSave(const Filter:string):string; var D:TSaveDialog; begin Result:='';D:=TSaveDialog.Create(nil);try D.Filter:=Filter;if D.Execute then Result:=D.FileName;finally D.Free;end;end;

procedure TOdcStudioForm.BuildCreate;
var P:TTabSheet; B:TButton; L:TLabel;
begin P:=AddTab('Criar');CreateSource:=AddEdit(P,20,'Origem');AddButton(P,18,805,'Selecionar',PickCreateSource);CreateDest:=AddEdit(P,60,'Destino ODC');AddButton(P,58,805,'Destino',PickCreateDest);L:=TLabel.Create(Self);L.Parent:=P;L.Caption:='Metadata JSON';L.Left:=16;L.Top:=110;CreateMeta:=TEdit.Create(Self);CreateMeta.Parent:=P;CreateMeta.Left:=140;CreateMeta.Top:=105;CreateMeta.Width:=650;B:=AddButton(P,150,140,'Criar ODC',DoCreate);end;
procedure TOdcStudioForm.BuildInfo;
var P:TTabSheet;begin P:=AddTab('Informações');InfoPath:=AddEdit(P,20,'Arquivo ODC');AddButton(P,18,805,'Abrir',PickInfo);AddButton(P,55,805,'Validar',DoVerify);InfoMemo:=TMemo.Create(Self);InfoMemo.Parent:=P;InfoMemo.Left:=16;InfoMemo.Top:=100;InfoMemo.Width:=900;InfoMemo.Height:=500;InfoMemo.ScrollBars:=ssBoth;end;
procedure TOdcStudioForm.BuildExtract;
var P:TTabSheet;begin P:=AddTab('Extrair');ExtractPath:=AddEdit(P,20,'Arquivo ODC');AddButton(P,18,805,'Abrir',PickExtract);ExtractDest:=AddEdit(P,60,'Destino');AddButton(P,58,805,'Destino',PickExtractDest);AddButton(P,105,140,'Extrair',DoExtract);end;
procedure TOdcStudioForm.BuildMeta;
var P:TTabSheet;begin P:=AddTab('Editar Metadata');MetaPath:=AddEdit(P,20,'Arquivo ODC');AddButton(P,18,805,'Abrir',PickMeta);MetaMemo:=TMemo.Create(Self);MetaMemo.Parent:=P;MetaMemo.Left:=16;MetaMemo.Top:=75;MetaMemo.Width:=900;MetaMemo.Height:=450;MetaMemo.ScrollBars:=ssBoth;AddButton(P,540,16,'Salvar',DoSaveMeta);AddButton(P,540,150,'Remover',DoRemoveMeta);end;

procedure TOdcStudioForm.PickCreateSource(Sender:TObject);var S:string;begin S:=PickOpen('Todos|*.*');if S<>'' then CreateSource.Text:=S;end;
procedure TOdcStudioForm.PickCreateDest(Sender:TObject);var S:string;begin S:=PickSave('ODC|*.odc');if S<>'' then CreateDest.Text:=S;end;
procedure TOdcStudioForm.DoCreate(Sender:TObject);begin try TOdc.CreateFromFile(CreateSource.Text,CreateDest.Text,CreateMeta.Text,True);ShowMessage('ODC criado.');except on E:Exception do ShowMessage(E.Message);end;end;
procedure TOdcStudioForm.PickInfo(Sender:TObject);var S:string;I:TOdcInfo;begin S:=PickOpen('ODC|*.odc');if S='' then Exit;InfoPath.Text:=S;try I:=TOdc.Info(S);InfoMemo.Lines.Text:=Format('Arquivo: %s'#13#10'MIME: %s'#13#10'Original: %d'#13#10'Payload: %d'#13#10'Compressão: %d'#13#10'SHA256: %s'#13#10'Metadata: %s',[I.FileName,I.MimeType,I.OriginalSize,I.StoredPayloadSize,I.Compression,I.SHA256Hex,I.MetadataJson]);except on E:Exception do ShowMessage(E.Message);end;end;
procedure TOdcStudioForm.DoVerify(Sender:TObject);begin if TOdc.Verify(InfoPath.Text) then ShowMessage('Arquivo íntegro.') else ShowMessage('Arquivo inválido.');end;
procedure TOdcStudioForm.PickExtract(Sender:TObject);var S:string;begin S:=PickOpen('ODC|*.odc');if S<>'' then ExtractPath.Text:=S;end;
procedure TOdcStudioForm.PickExtractDest(Sender:TObject);var S:string;begin S:=PickSave('Todos|*.*');if S<>'' then ExtractDest.Text:=S;end;
procedure TOdcStudioForm.DoExtract(Sender:TObject);begin try TOdc.Extract(ExtractPath.Text,ExtractDest.Text);ShowMessage('Extraído.');except on E:Exception do ShowMessage(E.Message);end;end;
procedure TOdcStudioForm.PickMeta(Sender:TObject);var S:string;I:TOdcInfo;begin S:=PickOpen('ODC|*.odc');if S='' then Exit;MetaPath.Text:=S;try I:=TOdc.Info(S);MetaMemo.Text:=I.MetadataJson;except on E:Exception do ShowMessage(E.Message);end;end;
procedure TOdcStudioForm.DoSaveMeta(Sender:TObject);begin try TOdc.SetMetadata(MetaPath.Text,MetaMemo.Text);ShowMessage('Metadata atualizada.');except on E:Exception do ShowMessage(E.Message);end;end;
procedure TOdcStudioForm.DoRemoveMeta(Sender:TObject);begin try TOdc.RemoveMetadata(MetaPath.Text);MetaMemo.Clear;ShowMessage('Metadata removida.');except on E:Exception do ShowMessage(E.Message);end;end;

end.
