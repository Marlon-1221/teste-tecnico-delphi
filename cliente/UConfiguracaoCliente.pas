unit UConfiguracaoCliente;

interface

type
  TConfiguracaoCliente = class abstract
  private
    class function LocalizarArquivo: string; static;
  public
    class function UrlServidor: string; static;
  end;

implementation

uses
  System.SysUtils,
  System.IniFiles;

const
  URL_PADRAO = 'http://localhost:9000';

class function TConfiguracaoCliente.LocalizarArquivo: string;
const
  CANDIDATOS: array[0..1] of string = ('Cliente.ini', '..\..\Cliente.ini');
var
  LCandidato: string;
begin
  for LCandidato in CANDIDATOS do
  begin
    Result := ExpandFileName(ExtractFilePath(ParamStr(0)) + LCandidato);
    if FileExists(Result) then
      Exit;
  end;
  Result := '';
end;

class function TConfiguracaoCliente.UrlServidor: string;
var
  LArquivo: string;
  LIni: TMemIniFile;
begin
  LArquivo := LocalizarArquivo;
  if LArquivo = '' then
    Exit(URL_PADRAO);

  LIni := TMemIniFile.Create(LArquivo, TEncoding.UTF8);
  try
    Result := LIni.ReadString('Servidor', 'Url', URL_PADRAO).TrimRight(['/']);
  finally
    LIni.Free;
  end;
end;

end.
