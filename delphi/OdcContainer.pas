unit OdcContainer;

interface

uses
  System.SysUtils, System.Classes, System.JSON, System.Hash, System.ZLib,
  System.Generics.Collections, System.IOUtils;

type
  EOdcError = class(Exception);

  TOdcChunk = record
    ChunkType: Word;
    Flags: Word;
    Length: UInt64;
    HeaderOffset: Int64;
    DataOffset: Int64;
  end;

  TOdcInfo = record
    FileName: string;
    MimeType: string;
    OriginalSize: UInt64;
    StoredPayloadSize: UInt64;
    Compression: Byte;
    SHA256Hex: string;
    MetadataJson: string;
    Chunks: TArray<TOdcChunk>;
  end;

  TOdc = class sealed
  private const
    MAGIC: AnsiString = 'ODC1';
    HEADER_SIZE = 24;
    CHUNK_HEADER_SIZE = 12;
    C_FILE_NAME = $0001;
    C_MIME = $0002;
    C_META = $0003;
    C_ORIGINAL_SIZE = $0004;
    C_COMPRESSION = $0010;
    C_SHA256 = $0020;
    C_PAYLOAD = $0100;
    COMP_NONE = 0;
    COMP_GZIP = 1;
  private
    class procedure WriteU16LE(S: TStream; V: Word); static;
    class procedure WriteU32LE(S: TStream; V: Cardinal); static;
    class procedure WriteU64LE(S: TStream; V: UInt64); static;
    class function ReadU16LE(S: TStream): Word; static;
    class function ReadU32LE(S: TStream): Cardinal; static;
    class function ReadU64LE(S: TStream): UInt64; static;
    class procedure WriteBytes(S: TStream; const B: TBytes); static;
    class function ReadBytes(S: TStream; Count: Integer): TBytes; static;
    class procedure WriteChunk(S: TStream; ChunkType: Word; const Data: TBytes); static;
    class procedure WriteChunkFromStream(S: TStream; ChunkType: Word; Source: TStream); static;
    class function Scan(const FileName: string; out Flags: Cardinal): TArray<TOdcChunk>; static;
    class function ReadChunkBytes(const FileName: string; const Chunks: TArray<TOdcChunk>; ChunkType: Word; MaxBytes: UInt64; Required: Boolean = True): TBytes; static;
    class function FindChunk(const Chunks: TArray<TOdcChunk>; ChunkType: Word; out C: TOdcChunk): Boolean; static;
    class function DetectMime(const FileName: string): string; static;
    class function ShouldGzip(const Mime: string; Size: Int64): Boolean; static;
    class function BytesToHex(const B: TBytes): string; static;
    class procedure ReplaceFile(const TempFile, DestFile: string); static;
  public
    class procedure CreateFromFile(const SourceFile, OdcFile: string; const MetadataJson: string = ''; CompressWhenUseful: Boolean = True); static;
    class function Info(const OdcFile: string): TOdcInfo; static;
    class procedure Extract(const OdcFile, DestFile: string); static;
    class function Verify(const OdcFile: string): Boolean; static;
    class procedure SetMetadata(const OdcFile, MetadataJson: string); static;
    class procedure RemoveMetadata(const OdcFile: string); static;
  end;

implementation

class procedure TOdc.WriteU16LE(S: TStream; V: Word);
var B: array[0..1] of Byte;
begin B[0] := Byte(V); B[1] := Byte(V shr 8); S.WriteBuffer(B, 2); end;
class procedure TOdc.WriteU32LE(S: TStream; V: Cardinal);
var B: array[0..3] of Byte;
begin B[0]:=Byte(V); B[1]:=Byte(V shr 8); B[2]:=Byte(V shr 16); B[3]:=Byte(V shr 24); S.WriteBuffer(B,4); end;
class procedure TOdc.WriteU64LE(S: TStream; V: UInt64);
var B: array[0..7] of Byte; I: Integer;
begin for I:=0 to 7 do B[I]:=Byte(V shr (I*8)); S.WriteBuffer(B,8); end;
class function TOdc.ReadU16LE(S:TStream):Word; var B:array[0..1] of Byte;
begin S.ReadBuffer(B,2); Result:=Word(B[0]) or (Word(B[1]) shl 8); end;
class function TOdc.ReadU32LE(S:TStream):Cardinal; var B:array[0..3] of Byte;
begin S.ReadBuffer(B,4); Result:=Cardinal(B[0]) or (Cardinal(B[1]) shl 8) or (Cardinal(B[2]) shl 16) or (Cardinal(B[3]) shl 24); end;
class function TOdc.ReadU64LE(S:TStream):UInt64; var B:array[0..7] of Byte; I:Integer;
begin S.ReadBuffer(B,8); Result:=0; for I:=0 to 7 do Result:=Result or (UInt64(B[I]) shl (I*8)); end;
class procedure TOdc.WriteBytes(S:TStream; const B:TBytes); begin if Length(B)>0 then S.WriteBuffer(B[0],Length(B)); end;
class function TOdc.ReadBytes(S:TStream; Count:Integer):TBytes; begin SetLength(Result,Count); if Count>0 then S.ReadBuffer(Result[0],Count); end;

class procedure TOdc.WriteChunk(S:TStream; ChunkType:Word; const Data:TBytes);
begin WriteU16LE(S,ChunkType); WriteU16LE(S,0); WriteU64LE(S,Length(Data)); WriteBytes(S,Data); end;
class procedure TOdc.WriteChunkFromStream(S:TStream; ChunkType:Word; Source:TStream);
begin WriteU16LE(S,ChunkType); WriteU16LE(S,0); WriteU64LE(S,Source.Size); Source.Position:=0; S.CopyFrom(Source,Source.Size); end;

class function TOdc.DetectMime(const FileName:string):string;
var E:string;
begin
  E:=LowerCase(TPath.GetExtension(FileName));
  if (E='.txt') then Exit('text/plain'); if E='.json' then Exit('application/json');
  if E='.xml' then Exit('application/xml'); if E='.csv' then Exit('text/csv');
  if (E='.jpg') or (E='.jpeg') then Exit('image/jpeg'); if E='.png' then Exit('image/png');
  if E='.webp' then Exit('image/webp'); if E='.pdf' then Exit('application/pdf'); if E='.zip' then Exit('application/zip');
  Result:='application/octet-stream';
end;

class function TOdc.ShouldGzip(const Mime:string; Size:Int64):Boolean;
var M:string;
begin
  if Size<768 then Exit(False); M:=LowerCase(Mime);
  Result:=M.StartsWith('text/') or (M='application/json') or (M='application/xml') or M.EndsWith('+json') or M.EndsWith('+xml');
end;

class function TOdc.BytesToHex(const B:TBytes):string;
var I:Integer;
begin Result:=''; for I:=0 to High(B) do Result:=Result+IntToHex(B[I],2); Result:=LowerCase(Result); end;

class procedure TOdc.ReplaceFile(const TempFile,DestFile:string);
begin
  if TFile.Exists(DestFile) then TFile.Delete(DestFile);
  TFile.Move(TempFile,DestFile);
end;

class function TOdc.Scan(const FileName:string; out Flags:Cardinal):TArray<TOdcChunk>;
var S:TFileStream; MagicBytes:TBytes; Major,Minor:Word; HeaderSize,Count,Reserved:Cardinal; I:Cardinal; C:TOdcChunk;
begin
  S:=TFileStream.Create(FileName,fmOpenRead or fmShareDenyNone);
  try
    if S.Size<HEADER_SIZE then raise EOdcError.Create('ODC truncado');
    MagicBytes:=ReadBytes(S,4); if TEncoding.ASCII.GetString(MagicBytes)<>'ODC1' then raise EOdcError.Create('Magic inválido');
    Major:=ReadU16LE(S); Minor:=ReadU16LE(S); Flags:=ReadU32LE(S); HeaderSize:=ReadU32LE(S); Count:=ReadU32LE(S); Reserved:=ReadU32LE(S);
    if (Major<>1) or (HeaderSize<>HEADER_SIZE) or (Count>1000000) then raise EOdcError.Create('Header/versão não suportado');
    SetLength(Result,Count);
    for I:=0 to Count-1 do begin
      if S.Position+CHUNK_HEADER_SIZE>S.Size then raise EOdcError.Create('Chunk truncado');
      C.HeaderOffset:=S.Position; C.ChunkType:=ReadU16LE(S); C.Flags:=ReadU16LE(S); C.Length:=ReadU64LE(S); C.DataOffset:=S.Position;
      if (C.Length>UInt64(S.Size-C.DataOffset)) then raise EOdcError.Create('Comprimento de chunk inválido');
      Result[I]:=C; S.Position:=S.Position+Int64(C.Length);
    end;
  finally S.Free; end;
end;

class function TOdc.FindChunk(const Chunks:TArray<TOdcChunk>; ChunkType:Word; out C:TOdcChunk):Boolean;
var X:TOdcChunk;
begin for X in Chunks do if X.ChunkType=ChunkType then begin C:=X; Exit(True); end; Result:=False; end;

class function TOdc.ReadChunkBytes(const FileName:string; const Chunks:TArray<TOdcChunk>; ChunkType:Word; MaxBytes:UInt64; Required:Boolean):TBytes;
var C:TOdcChunk; S:TFileStream;
begin
  if not FindChunk(Chunks,ChunkType,C) then begin if Required then raise EOdcError.CreateFmt('Chunk %x ausente',[ChunkType]); Exit(nil); end;
  if C.Length>MaxBytes then raise EOdcError.Create('Chunk excedeu limite seguro');
  S:=TFileStream.Create(FileName,fmOpenRead or fmShareDenyNone); try S.Position:=C.DataOffset; Result:=ReadBytes(S,Integer(C.Length)); finally S.Free; end;
end;

class procedure TOdc.CreateFromFile(const SourceFile,OdcFile,MetadataJson:string; CompressWhenUseful:Boolean);
var Src,Payload,OutS,TempGz:TFileStream; TempName,TempOut,Mime:string; Hash:TBytes; Gz:TZCompressionStream; UseGzip:Boolean; Count,Flags:Cardinal; B:TBytes; Sz:UInt64;
begin
  if not TFile.Exists(SourceFile) then raise EOdcError.Create('Arquivo origem inexistente');
  Src:=TFileStream.Create(SourceFile,fmOpenRead or fmShareDenyNone);
  TempName:=''; TempOut:=OdcFile+'.tmp-'+TGUID.NewGuid.ToString.Replace('{','').Replace('}','');
  try
    Hash:=THashSHA2.GetHashBytes(Src,THashSHA2.TSHA2Version.SHA256); Src.Position:=0; Mime:=DetectMime(SourceFile); UseGzip:=False; Payload:=Src;
    if CompressWhenUseful and ShouldGzip(Mime,Src.Size) then begin
      TempName:=TPath.GetTempFileName; TempGz:=TFileStream.Create(TempName,fmCreate);
      try Gz:=TZCompressionStream.Create(TempGz,zcDefault,31); try Gz.CopyFrom(Src,Src.Size); finally Gz.Free; end; finally TempGz.Free; end;
      TempGz:=TFileStream.Create(TempName,fmOpenRead or fmShareDenyNone);
      try
        if TempGz.Size+64<Src.Size then begin Payload:=TFileStream.Create(TempName,fmOpenRead or fmShareDenyNone); UseGzip:=True; end else Src.Position:=0;
      finally TempGz.Free; end;
    end;
    Count:=6; if MetadataJson<>'' then Inc(Count); Flags:=0; if UseGzip then Flags:=1;
    OutS:=TFileStream.Create(TempOut,fmCreate); try
      WriteBytes(OutS,TEncoding.ASCII.GetBytes('ODC1')); WriteU16LE(OutS,1); WriteU16LE(OutS,0); WriteU32LE(OutS,Flags); WriteU32LE(OutS,HEADER_SIZE); WriteU32LE(OutS,Count); WriteU32LE(OutS,0);
      WriteChunk(OutS,C_FILE_NAME,TEncoding.UTF8.GetBytes(TPath.GetFileName(SourceFile)));
      WriteChunk(OutS,C_MIME,TEncoding.UTF8.GetBytes(Mime));
      if MetadataJson<>'' then WriteChunk(OutS,C_META,TEncoding.UTF8.GetBytes(MetadataJson));
      Sz:=UInt64(Src.Size); SetLength(B,8); B[0]:=Byte(Sz); B[1]:=Byte(Sz shr 8); B[2]:=Byte(Sz shr 16); B[3]:=Byte(Sz shr 24); B[4]:=Byte(Sz shr 32); B[5]:=Byte(Sz shr 40); B[6]:=Byte(Sz shr 48); B[7]:=Byte(Sz shr 56); WriteChunk(OutS,C_ORIGINAL_SIZE,B);
      SetLength(B,1); if UseGzip then B[0]:=1 else B[0]:=0; WriteChunk(OutS,C_COMPRESSION,B); WriteChunk(OutS,C_SHA256,Hash); Payload.Position:=0; WriteChunkFromStream(OutS,C_PAYLOAD,Payload);
    finally OutS.Free; end;
    if Payload<>Src then Payload.Free; ReplaceFile(TempOut,OdcFile);
  finally Src.Free; if (TempName<>'') and TFile.Exists(TempName) then TFile.Delete(TempName); if TFile.Exists(TempOut) then TFile.Delete(TempOut); end;
end;

class function TOdc.Info(const OdcFile:string):TOdcInfo;
var Flags:Cardinal; Ch:TArray<TOdcChunk>; B:TBytes; C:TOdcChunk;
begin
  Ch:=Scan(OdcFile,Flags); Result.Chunks:=Ch; Result.FileName:=TEncoding.UTF8.GetString(ReadChunkBytes(OdcFile,Ch,C_FILE_NAME,1024*1024)); Result.MimeType:=TEncoding.UTF8.GetString(ReadChunkBytes(OdcFile,Ch,C_MIME,1024*1024));
  B:=ReadChunkBytes(OdcFile,Ch,C_ORIGINAL_SIZE,8); if Length(B)<>8 then raise EOdcError.Create('ORIGINAL_SIZE inválido'); Result.OriginalSize:=UInt64(B[0]) or (UInt64(B[1]) shl 8) or (UInt64(B[2]) shl 16) or (UInt64(B[3]) shl 24) or (UInt64(B[4]) shl 32) or (UInt64(B[5]) shl 40) or (UInt64(B[6]) shl 48) or (UInt64(B[7]) shl 56);
  B:=ReadChunkBytes(OdcFile,Ch,C_COMPRESSION,1); Result.Compression:=B[0]; B:=ReadChunkBytes(OdcFile,Ch,C_SHA256,32); Result.SHA256Hex:=BytesToHex(B); B:=ReadChunkBytes(OdcFile,Ch,C_META,16*1024*1024,False); if Length(B)>0 then Result.MetadataJson:=TEncoding.UTF8.GetString(B) else Result.MetadataJson:=''; if not FindChunk(Ch,C_PAYLOAD,C) then raise EOdcError.Create('PAYLOAD ausente'); Result.StoredPayloadSize:=C.Length;
end;

class procedure TOdc.Extract(const OdcFile,DestFile:string);
var Flags:Cardinal; Ch:TArray<TOdcChunk>; C:TOdcChunk; InS,OutS:TFileStream; Packed:TMemoryStream; Dec:TZDecompressionStream; B,Expected,Actual:TBytes; Comp:Byte; TempOut:string;
begin
  Ch:=Scan(OdcFile,Flags);
  if not FindChunk(Ch,C_PAYLOAD,C) then raise EOdcError.Create('PAYLOAD ausente');
  B:=ReadChunkBytes(OdcFile,Ch,C_COMPRESSION,1); Comp:=B[0];
  Expected:=ReadChunkBytes(OdcFile,Ch,C_SHA256,32);
  TempOut:=DestFile+'.tmp-'+TGUID.NewGuid.ToString.Replace('{','').Replace('}','');
  InS:=TFileStream.Create(OdcFile,fmOpenRead or fmShareDenyNone);
  OutS:=TFileStream.Create(TempOut,fmCreate);
  try
    InS.Position:=C.DataOffset;
    if Comp=COMP_NONE then
      OutS.CopyFrom(InS,C.Length)
    else if Comp=COMP_GZIP then begin
      Packed:=TMemoryStream.Create;
      try
        Packed.CopyFrom(InS,C.Length);
        Packed.Position:=0;
        Dec:=TZDecompressionStream.Create(Packed,31,False);
        try OutS.CopyFrom(Dec,0); finally Dec.Free; end;
      finally Packed.Free; end;
    end else
      raise EOdcError.Create('Compressão não suportada');
  finally
    OutS.Free;
    InS.Free;
  end;
  OutS:=TFileStream.Create(TempOut,fmOpenRead or fmShareDenyNone);
  try Actual:=THashSHA2.GetHashBytes(OutS,THashSHA2.TSHA2Version.SHA256); finally OutS.Free; end;
  if (Length(Expected)<>Length(Actual)) or ((Length(Expected)>0) and not CompareMem(@Expected[0],@Actual[0],Length(Expected))) then begin
    TFile.Delete(TempOut);
    raise EOdcError.Create('SHA-256 inválido');
  end;
  ReplaceFile(TempOut,DestFile);
end;

class function TOdc.Verify(const OdcFile:string):Boolean;
var Tmp:string;
begin Tmp:=TPath.GetTempFileName; try try Extract(OdcFile,Tmp); Result:=True; except Result:=False; end; finally if TFile.Exists(Tmp) then TFile.Delete(Tmp); end; end;

class procedure TOdc.SetMetadata(const OdcFile,MetadataJson:string);
var InfoRec:TOdcInfo; TempOriginal:string;
begin
  InfoRec:=Info(OdcFile);
  TempOriginal:=TPath.Combine(TPath.GetTempPath, TGUID.NewGuid.ToString.Replace('{','').Replace('}','') + TPath.GetExtension(InfoRec.FileName));
  try
    Extract(OdcFile,TempOriginal);
    CreateFromFile(TempOriginal,OdcFile,MetadataJson,InfoRec.Compression=COMP_GZIP);
  finally
    if TFile.Exists(TempOriginal) then TFile.Delete(TempOriginal);
  end;
end;

class procedure TOdc.RemoveMetadata(const OdcFile:string);
begin SetMetadata(OdcFile,''); end;

end.
