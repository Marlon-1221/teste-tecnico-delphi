unit UViaCep;

interface

uses
  System.SysUtils,
  System.JSON,
  System.Net.HttpClient,
  UExcecoes,
  UPessoa;

type
  EIntegracaoCep = class(EAplicacao);

  IConsultaCep = interface
    ['{B5C7D9E1-F3A5-4B7C-9D1E-3F5A7B9C1D3E}']
    function Consultar(const ACep: string): TEnderecoIntegracao;
  end;

  TFabricaConsultaCep = reference to function: IConsultaCep;

  TConsultaViaCep = class(TInterfacedObject, IConsultaCep)
  private const
    TENTATIVAS = 3;
    INTERVALO_BASE_TENTATIVA_MS = 1000;
    STATUS_OK = 200;
    STATUS_REQUISICAO_INVALIDA = 400;
    STATUS_MUITAS_REQUISICOES = 429;
    STATUS_ERRO_SERVIDOR = 500;
  private
    FHttp: THTTPClient;
    FUrlModelo: string;
    function Requisitar(const AUrl: string): IHTTPResponse;
    class function DeveRepetir(AStatus: Integer): Boolean; static;
    class function Converter(AJson: TJSONObject): TEnderecoIntegracao; static;
  public
    constructor Create(const AUrlModelo: string; ATimeoutMs: Integer);
    destructor Destroy; override;
    function Consultar(const ACep: string): TEnderecoIntegracao;
  end;

implementation

uses
  System.Net.URLClient,
  System.NetConsts,
  UConversorJson;

constructor TConsultaViaCep.Create(const AUrlModelo: string; ATimeoutMs: Integer);
begin
  inherited Create;
  FUrlModelo := AUrlModelo;
  FHttp := THTTPClient.Create;
  FHttp.ConnectionTimeout := ATimeoutMs;
  FHttp.ResponseTimeout := ATimeoutMs;
  FHttp.Accept := 'application/json';
end;

destructor TConsultaViaCep.Destroy;
begin
  FHttp.Free;
  inherited;
end;

class function TConsultaViaCep.DeveRepetir(AStatus: Integer): Boolean;
begin
  Result := (AStatus = STATUS_MUITAS_REQUISICOES) or (AStatus >= STATUS_ERRO_SERVIDOR);
end;

function TConsultaViaCep.Requisitar(const AUrl: string): IHTTPResponse;
var
  LTentativa: Integer;
begin
  Result := nil;
  for LTentativa := 1 to TENTATIVAS do
  begin
    try
      Result := FHttp.Get(AUrl);
      if not DeveRepetir(Result.StatusCode) then
        Exit;
    except
      on E: ENetHTTPClientException do
        if LTentativa = TENTATIVAS then
          raise EIntegracaoCep.CreateFmt('Falha de comunicação com o ViaCEP: %s', [E.Message]);
    end;
    if LTentativa < TENTATIVAS then
      Sleep(LTentativa * INTERVALO_BASE_TENTATIVA_MS);
  end;
end;

class function TConsultaViaCep.Converter(AJson: TJSONObject): TEnderecoIntegracao;
begin
  Result := TEnderecoIntegracao.Create;
  Result.Uf := TJsonLeitor.Texto(AJson, 'uf');
  Result.Cidade := TJsonLeitor.Texto(AJson, 'localidade');
  Result.Bairro := TJsonLeitor.Texto(AJson, 'bairro');
  Result.Logradouro := TJsonLeitor.Texto(AJson, 'logradouro');
  Result.Complemento := TJsonLeitor.Texto(AJson, 'complemento');
end;

function TConsultaViaCep.Consultar(const ACep: string): TEnderecoIntegracao;
var
  LResposta: IHTTPResponse;
  LJson: TJSONValue;
begin
  LResposta := Requisitar(Format(FUrlModelo, [ACep]));
  if LResposta.StatusCode = STATUS_REQUISICAO_INVALIDA then
    Exit(nil);
  if LResposta.StatusCode <> STATUS_OK then
    raise EIntegracaoCep.CreateFmt('ViaCEP respondeu HTTP %d para o CEP %s.', [LResposta.StatusCode, ACep]);

  LJson := TJSONObject.ParseJSONValue(LResposta.ContentAsString(TEncoding.UTF8));
  try
    if not (LJson is TJSONObject) then
      raise EIntegracaoCep.CreateFmt('Resposta inválida do ViaCEP para o CEP %s.', [ACep]);
    if TJsonLeitor.Booleano(TJSONObject(LJson), 'erro') then
      Exit(nil);
    Result := Converter(TJSONObject(LJson));
  finally
    LJson.Free;
  end;
end;

end.
