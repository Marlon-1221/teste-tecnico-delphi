unit LibPessoa;

interface

uses
  System.JSON,
  System.Generics.Collections,
  UExcecoes,
  UPessoa,
  UPagina,
  UStatusCep,
  USistema;

type
  EErroServidor = class(EAplicacao)
  private
    FStatusHttp: Integer;
  public
    constructor Create(AStatusHttp: Integer; const AMensagem: string);
    property StatusHttp: Integer read FStatusHttp;
  end;

  TResultadoLote = record
    Inseridos: Integer;
    TempoServidorMs: Int64;
    TempoTotalMs: Int64;
  end;

  IAcessoServidor = interface
    ['{E1F3A5B7-C9D1-4E3F-9A5B-7C9D1E3F5A7B}']
    function Listar(ANumeroPagina, ATamanhoPagina: Integer; const ABusca: string = ''): TPagina<TPessoa>;
    function Obter(AId: Int64): TPessoa;
    function Inserir(APessoa: TPessoa): Int64;
    procedure Atualizar(APessoa: TPessoa);
    procedure Excluir(AId: Int64);
    function InserirLote(APessoas: TList<TPessoa>): TResultadoLote;
    function IniciarAtualizacaoCep(ASomentePendentes: Boolean): TStatusAtualizacaoCep;
    function ObterStatusAtualizacaoCep: TStatusAtualizacaoCep;
    function InformacoesBanco: TInformacoesBanco;
    function DocumentosCadastrados(const ADocumentos: TArray<string>): TArray<string>;
  end;

  TAcessoServidor = class(TInterfacedObject, IAcessoServidor)
  private const
    TIMEOUT_MS = 300000;
    RECURSO_PESSOAS = '/pessoas';
    RECURSO_ATUALIZACAO_CEP = '/enderecos/atualizacao-cep';
    RECURSO_SISTEMA = '/sistema';
  private
    FUrlBase: string;
    function Requisitar(const AMetodo, ARecurso: string; const ACorpo: string = ''): string;
    function RequisitarJson(const AMetodo, ARecurso: string; AConteudo: TJSONValue = nil): TJSONValue;
    function RequisitarObjeto(const AMetodo, ARecurso: string; AConteudo: TJSONValue = nil): TJSONObject;
    class function ExtrairMensagemErro(const ACorpo, APadrao: string): string; static;
  public
    constructor Create(const AUrlBase: string);
    function Listar(ANumeroPagina, ATamanhoPagina: Integer; const ABusca: string = ''): TPagina<TPessoa>;
    function Obter(AId: Int64): TPessoa;
    function Inserir(APessoa: TPessoa): Int64;
    procedure Atualizar(APessoa: TPessoa);
    procedure Excluir(AId: Int64);
    function InserirLote(APessoas: TList<TPessoa>): TResultadoLote;
    function IniciarAtualizacaoCep(ASomentePendentes: Boolean): TStatusAtualizacaoCep;
    function ObterStatusAtualizacaoCep: TStatusAtualizacaoCep;
    function InformacoesBanco: TInformacoesBanco;
    function DocumentosCadastrados(const ADocumentos: TArray<string>): TArray<string>;
  end;

implementation

uses
  System.SysUtils,
  System.Classes,
  System.Net.HttpClient,
  System.NetConsts,
  System.NetEncoding,
  UConversorJson;

const
  STATUS_PRIMEIRO_ERRO = 400;

constructor EErroServidor.Create(AStatusHttp: Integer; const AMensagem: string);
begin
  inherited Create(AMensagem);
  FStatusHttp := AStatusHttp;
end;

constructor TAcessoServidor.Create(const AUrlBase: string);
begin
  inherited Create;
  FUrlBase := AUrlBase;
end;

class function TAcessoServidor.ExtrairMensagemErro(const ACorpo, APadrao: string): string;
var
  LJson: TJSONValue;
  LDetalhes: TJSONArray;
  I: Integer;
begin
  Result := APadrao;
  LJson := TJSONObject.ParseJSONValue(ACorpo);
  try
    if not (LJson is TJSONObject) then
      Exit;
    Result := TJsonLeitor.Texto(TJSONObject(LJson), 'erro', APadrao);
    LDetalhes := TJsonLeitor.Lista(TJSONObject(LJson), 'detalhes');
    if LDetalhes <> nil then
      for I := 0 to LDetalhes.Count - 1 do
        Result := Result + sLineBreak + '- ' + LDetalhes.Items[I].Value;
  finally
    LJson.Free;
  end;
end;

function TAcessoServidor.Requisitar(const AMetodo, ARecurso, ACorpo: string): string;
var
  LCliente: THTTPClient;
  LCorpo: TStringStream;
  LUrl: string;
  LResposta: IHTTPResponse;
begin
  LCliente := THTTPClient.Create;
  LCorpo := TStringStream.Create(ACorpo, TEncoding.UTF8);
  try
    LCliente.ConnectionTimeout := TIMEOUT_MS;
    LCliente.ResponseTimeout := TIMEOUT_MS;
    LCliente.Accept := 'application/json';
    LCliente.ContentType := 'application/json; charset=utf-8';
    LUrl := FUrlBase + ARecurso;

    try
      if AMetodo = 'GET' then
        LResposta := LCliente.Get(LUrl)
      else if AMetodo = 'POST' then
        LResposta := LCliente.Post(LUrl, LCorpo)
      else if AMetodo = 'PUT' then
        LResposta := LCliente.Put(LUrl, LCorpo)
      else if AMetodo = 'DELETE' then
        LResposta := LCliente.Delete(LUrl)
      else
        raise EArgumentException.CreateFmt('Método HTTP não suportado: %s', [AMetodo]);
    except
      on E: ENetHTTPClientException do
        raise EErroServidor.Create(0, Format('Não foi possível comunicar com o servidor em %s.' + sLineBreak +
          'Verifique se o Servidor está em execução.' + sLineBreak + sLineBreak + '%s', [FUrlBase, E.Message]));
    end;

    Result := LResposta.ContentAsString(TEncoding.UTF8);
    if LResposta.StatusCode >= STATUS_PRIMEIRO_ERRO then
      raise EErroServidor.Create(LResposta.StatusCode, ExtrairMensagemErro(Result,
        Format('Erro HTTP %d: %s', [LResposta.StatusCode, LResposta.StatusText])));
  finally
    LResposta := nil;
    LCorpo.Free;
    LCliente.Free;
  end;
end;

function TAcessoServidor.RequisitarJson(const AMetodo, ARecurso: string; AConteudo: TJSONValue): TJSONValue;
var
  LCorpo, LResposta: string;
begin
  try
    if AConteudo <> nil then
      LCorpo := AConteudo.ToJSON;
  finally
    AConteudo.Free;
  end;

  LResposta := Requisitar(AMetodo, ARecurso, LCorpo);
  if LResposta = '' then
    Exit(nil);
  Result := TJSONObject.ParseJSONValue(LResposta);
  if Result = nil then
    raise EErroServidor.Create(0, 'O servidor retornou uma resposta que não é JSON válido.');
end;

function TAcessoServidor.RequisitarObjeto(const AMetodo, ARecurso: string; AConteudo: TJSONValue): TJSONObject;
var
  LJson: TJSONValue;
begin
  LJson := RequisitarJson(AMetodo, ARecurso, AConteudo);
  if not (LJson is TJSONObject) then
  begin
    LJson.Free;
    raise EErroServidor.Create(0, 'O servidor retornou uma resposta inesperada.');
  end;
  Result := TJSONObject(LJson);
end;

function TAcessoServidor.Listar(ANumeroPagina, ATamanhoPagina: Integer; const ABusca: string): TPagina<TPessoa>;
var
  LJson: TJSONObject;
begin
  LJson := RequisitarObjeto('GET', Format('%s?pagina=%d&tamanho=%d&busca=%s',
    [RECURSO_PESSOAS, ANumeroPagina, ATamanhoPagina, TNetEncoding.URL.Encode(Trim(ABusca))]));
  try
    Result := TPessoaJson.PaginaDeJson(LJson);
  finally
    LJson.Free;
  end;
end;

function TAcessoServidor.Obter(AId: Int64): TPessoa;
var
  LJson: TJSONObject;
begin
  LJson := RequisitarObjeto('GET', Format('%s/%d', [RECURSO_PESSOAS, AId]));
  try
    Result := TPessoaJson.DeJson(LJson);
  finally
    LJson.Free;
  end;
end;

function TAcessoServidor.Inserir(APessoa: TPessoa): Int64;
var
  LJson: TJSONObject;
begin
  LJson := RequisitarObjeto('POST', RECURSO_PESSOAS, TPessoaJson.ParaJson(APessoa));
  try
    Result := TJsonLeitor.Inteiro64(LJson, 'id');
    APessoa.Id := Result;
  finally
    LJson.Free;
  end;
end;

procedure TAcessoServidor.Atualizar(APessoa: TPessoa);
begin
  RequisitarJson('PUT', Format('%s/%d', [RECURSO_PESSOAS, APessoa.Id]), TPessoaJson.ParaJson(APessoa)).Free;
end;

procedure TAcessoServidor.Excluir(AId: Int64);
begin
  Requisitar('DELETE', Format('%s/%d', [RECURSO_PESSOAS, AId]));
end;

function TAcessoServidor.InserirLote(APessoas: TList<TPessoa>): TResultadoLote;
var
  LJson: TJSONObject;
begin
  LJson := RequisitarObjeto('POST', RECURSO_PESSOAS + '/lote', TPessoaJson.ListaParaJson(APessoas));
  try
    Result.Inseridos := TJsonLeitor.Inteiro(LJson, 'inseridos');
    Result.TempoServidorMs := TJsonLeitor.Inteiro64(LJson, 'tempoMs');
    Result.TempoTotalMs := 0;
  finally
    LJson.Free;
  end;
end;

function TAcessoServidor.IniciarAtualizacaoCep(ASomentePendentes: Boolean): TStatusAtualizacaoCep;
var
  LJson: TJSONObject;
begin
  LJson := RequisitarObjeto('POST', Format('%s?somentePendentes=%s',
    [RECURSO_ATUALIZACAO_CEP, BoolToStr(ASomentePendentes, True).ToLower]));
  try
    Result := TStatusAtualizacaoCepJson.DeJson(LJson);
  finally
    LJson.Free;
  end;
end;

function TAcessoServidor.ObterStatusAtualizacaoCep: TStatusAtualizacaoCep;
var
  LJson: TJSONObject;
begin
  LJson := RequisitarObjeto('GET', RECURSO_ATUALIZACAO_CEP);
  try
    Result := TStatusAtualizacaoCepJson.DeJson(LJson);
  finally
    LJson.Free;
  end;
end;

function TAcessoServidor.InformacoesBanco: TInformacoesBanco;
var
  LJson: TJSONObject;
begin
  LJson := RequisitarObjeto('GET', RECURSO_SISTEMA);
  try
    Result := TInformacoesBancoJson.DeJson(LJson);
  finally
    LJson.Free;
  end;
end;

function TAcessoServidor.DocumentosCadastrados(const ADocumentos: TArray<string>): TArray<string>;
var
  LEntrada: TJSONArray;
  LResposta: TJSONValue;
  LDocumento: string;
  I: Integer;
begin
  LEntrada := TJSONArray.Create;
  for LDocumento in ADocumentos do
    LEntrada.Add(LDocumento);
  LResposta := RequisitarJson('POST', RECURSO_PESSOAS + '/documentos', LEntrada);
  try
    if not (LResposta is TJSONArray) then
      raise EErroServidor.Create(0, 'O servidor retornou uma resposta inesperada.');
    SetLength(Result, TJSONArray(LResposta).Count);
    for I := 0 to TJSONArray(LResposta).Count - 1 do
      Result[I] := TJSONArray(LResposta).Items[I].Value;
  finally
    LResposta.Free;
  end;
end;

end.
