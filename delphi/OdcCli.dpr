program OdcCli;
{$APPTYPE CONSOLE}
uses System.SysUtils, System.JSON, System.IOUtils, OdcContainer in 'OdcContainer.pas';
var Cmd, Meta:string; I:TOdcInfo;
begin
  try
    if ParamCount<2 then begin Writeln('Uso: odc info|verify|extract|create ...'); Halt(2); end;
    Cmd:=LowerCase(ParamStr(1));
    if Cmd='info' then begin I:=TOdc.Info(ParamStr(2)); Writeln('Nome: ',I.FileName); Writeln('MIME: ',I.MimeType); Writeln('Original: ',I.OriginalSize); Writeln('Payload: ',I.StoredPayloadSize); Writeln('SHA256: ',I.SHA256Hex); Writeln('Metadata: ',I.MetadataJson); end
    else if Cmd='verify' then begin if TOdc.Verify(ParamStr(2)) then Writeln('OK') else begin Writeln('INVALIDO'); Halt(1); end; end
    else if Cmd='extract' then begin TOdc.Extract(ParamStr(2),ParamStr(3)); Writeln('Extraido.'); end
    else if Cmd='create' then begin if ParamCount>=4 then Meta:=TFile.ReadAllText(ParamStr(4),TEncoding.UTF8) else Meta:=''; TOdc.CreateFromFile(ParamStr(2),ParamStr(3),Meta,True); Writeln('Criado.'); end
    else if Cmd='set-meta' then begin Meta:=TFile.ReadAllText(ParamStr(3),TEncoding.UTF8); TOdc.SetMetadata(ParamStr(2),Meta); end
    else if Cmd='remove-meta' then TOdc.RemoveMetadata(ParamStr(2))
    else Halt(2);
  except on E:Exception do begin Writeln(ErrOutput,'ERRO: ',E.Message); Halt(1); end; end;
end.
