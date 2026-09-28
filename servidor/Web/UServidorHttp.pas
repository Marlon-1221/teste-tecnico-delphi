unit UServidorHttp;

interface

uses
  System.Classes,
  IdContext,
  IdCustomHTTPServer,
  IdHTTPServer,
  ULog,
  URoteador;

type
  TServidorHttp = class
  private
    FIndy: TIdHTTPServer;
    FRoteador: TRoteador;
    FLog: ILog;
    procedure AoReceberRequisicao(AContext: TIdContext; ARequestInfo: TIdHTTPRequestInfo;
      AResponseInfo: TIdHTTPResponseInfo);
    class function LerCorpo(ARequestInfo: TIdHTTPRequestInfo): string; static;
    class function LerParametros(ARequestInfo: TIdHTTPRequestInfo): TStringList; static;
    class procedure Responder(AResponseInfo: TIdHTTPResponseInfo; AResposta: TResposta); static;
  public
    constructor Create(APorta: Integer; ARoteador: TRoteador; const ALog: ILog);
    destructor Destroy; override;
    procedure Iniciar;
    procedure Parar;
  end;

implementation

uses
  System.SysUtils,
  System.Diagnostics,
  System.NetEncoding;

const
  STATUS_METODO_NAO_PERMITIDO = 405;

function Decodificar(const ATexto: string): string;
begin
  try
    Result := TNetEncoding.URL.Decode(ATexto.Replace('+', ' '));
  except
    Result := ATexto;
  end;
end;

constructor TServidorHttp.Create(APorta: Integer; ARoteador: TRoteador; const ALog: ILog);
begin
  inherited Create;
  FRoteador := ARoteador;
  FLog := ALog;
  FIndy := TIdHTTPServer.Create(nil);
  FIndy.DefaultPort := APorta;
  FIndy.KeepAlive := True;
  FIndy.ParseParams := True;
  FIndy.OnCommandGet := AoReceberRequisicao;
  FIndy.OnCommandOther := AoReceberRequisicao;
end;

destructor TServidorHttp.Destroy;
begin
  Parar;
  FIndy.Free;
  inherited;
end;

procedure TServidorHttp.Iniciar;
begin
  FIndy.Active := True;
end;

procedure TServidorHttp.Parar;
begin
  FIndy.Active := False;
end;

class function TServidorHttp.LerCorpo(ARequestInfo: TIdHTTPRequestInfo): string;
var
  LConteudo: TStringStream;
begin
  if (ARequestInfo.PostStream = nil) or (ARequestInfo.PostStream.Size = 0) then
    Exit('');

  LConteudo := TStringStream.Create('', TEncoding.UTF8);
  try
    LConteudo.CopyFrom(ARequestInfo.PostStream, 0);
    Result := LConteudo.DataString;
  finally
    LConteudo.Free;
  end;
end;

class function TServidorHttp.LerParametros(ARequestInfo: TIdHTTPRequestInfo): TStringList;
var
  LPar: string;
  LSeparador: Integer;
begin
  Result := TStringList.Create;
  for LPar in ARequestInfo.QueryParams.Split(['&'], TStringSplitOptions.ExcludeEmpty) do
  begin
    LSeparador := Pos('=', LPar);
    if LSeparador = 0 then
      Result.Add(Decodificar(LPar) + '=')
    else
      Result.Add(Decodificar(Copy(LPar, 1, LSeparador - 1)) + '=' + Decodificar(Copy(LPar, LSeparador + 1, MaxInt)));
  end;
end;

class procedure TServidorHttp.Responder(AResponseInfo: TIdHTTPResponseInfo; AResposta: TResposta);
begin
  AResponseInfo.ResponseNo := AResposta.Status;
  AResponseInfo.ContentType := 'application/json';
  AResponseInfo.CharSet := 'utf-8';
  if AResposta.Corpo <> '' then
    AResponseInfo.ContentStream := TStringStream.Create(AResposta.Corpo, TEncoding.UTF8);
end;

procedure TServidorHttp.AoReceberRequisicao(AContext: TIdContext; ARequestInfo: TIdHTTPRequestInfo;
  AResponseInfo: TIdHTTPResponseInfo);
var
  LCronometro: TStopwatch;
  LMetodo: TMetodoHttp;
  LRequisicao: TRequisicao;
  LParametros: TStringList;
  LResposta: TResposta;
begin
  LCronometro := TStopwatch.StartNew;
  LResposta := TResposta.Create;
  try
    if TMetodoHttp.TentarConverter(ARequestInfo.Command, LMetodo) then
    begin
      LParametros := LerParametros(ARequestInfo);
      try
        LRequisicao := TRequisicao.Create(LMetodo, ARequestInfo.Document, LerCorpo(ARequestInfo), LParametros);
        try
          FRoteador.Despachar(LRequisicao, LResposta);
        finally
          LRequisicao.Free;
        end;
      finally
        LParametros.Free;
      end;
    end
    else
      LResposta.EnviarErro(STATUS_METODO_NAO_PERMITIDO, 'Método HTTP não suportado: ' + ARequestInfo.Command);

    Responder(AResponseInfo, LResposta);
    FLog.Informar(Format('%-6s %s -> %d (%d ms)', [ARequestInfo.Command, ARequestInfo.Document,
      LResposta.Status, LCronometro.ElapsedMilliseconds]));
  finally
    LResposta.Free;
  end;
end;

end.
