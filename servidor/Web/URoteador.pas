unit URoteador;

interface

uses
  System.SysUtils,
  System.Classes,
  System.JSON,
  System.Generics.Collections;

type
  TMetodoHttp = (mhGet, mhPost, mhPut, mhDelete);

  TMetodoHttpAuxiliar = record helper for TMetodoHttp
  public
    class function TentarConverter(const ATexto: string; out AMetodo: TMetodoHttp): Boolean; static;
  end;

  TRequisicao = class
  private
    FMetodo: TMetodoHttp;
    FCaminho: string;
    FCorpo: string;
    FQuery: TStringList;
    FParametrosRota: TDictionary<string, string>;
    FCorpoJson: TJSONValue;
    function CorpoJson: TJSONValue;
  public
    constructor Create(AMetodo: TMetodoHttp; const ACaminho, ACorpo: string; AQuery: TStrings);
    destructor Destroy; override;
    function ParametroRotaInt64(const ANome: string): Int64;
    function QueryTexto(const ANome: string): string;
    function QueryInteiro(const ANome: string; APadrao: Integer): Integer;
    function QueryBooleano(const ANome: string; APadrao: Boolean): Boolean;
    function CorpoComoObjeto: TJSONObject;
    function CorpoComoLista: TJSONArray;
    property Metodo: TMetodoHttp read FMetodo;
    property Caminho: string read FCaminho;
    property ParametrosRota: TDictionary<string, string> read FParametrosRota;
  end;

  TResposta = class
  private const
    STATUS_SEM_CONTEUDO = 204;
  private
    FStatus: Integer;
    FCorpo: string;
  public
    constructor Create;
    procedure EnviarJson(AStatus: Integer; AConteudo: TJSONValue);
    procedure EnviarErro(AStatus: Integer; const AMensagem: string; const ADetalhes: TArray<string> = nil);
    procedure EnviarSemConteudo;
    property Status: Integer read FStatus;
    property Corpo: string read FCorpo;
  end;

  TManipuladorRota = reference to procedure(ARequisicao: TRequisicao; AResposta: TResposta);

  TRota = class
  private
    FMetodo: TMetodoHttp;
    FSegmentos: TArray<string>;
    FManipulador: TManipuladorRota;
  public
    constructor Create(AMetodo: TMetodoHttp; const APadrao: string; const AManipulador: TManipuladorRota);
    function Corresponde(const ASegmentos: TArray<string>; AParametros: TDictionary<string, string>): Boolean;
    property Metodo: TMetodoHttp read FMetodo;
    property Manipulador: TManipuladorRota read FManipulador;
  end;

  TRoteador = class
  private
    FRotas: TObjectList<TRota>;
    FAoErroInterno: TProc<string>;
    procedure TratarExcecao(E: Exception; AResposta: TResposta);
  public
    constructor Create;
    destructor Destroy; override;
    class function Segmentar(const ACaminho: string): TArray<string>; static;
    procedure Registrar(AMetodo: TMetodoHttp; const APadrao: string; const AManipulador: TManipuladorRota);
    procedure Despachar(ARequisicao: TRequisicao; AResposta: TResposta);
    property AoErroInterno: TProc<string> write FAoErroInterno;
  end;

  IControle = interface
    ['{A1B3C5D7-E9F1-4A3B-8C5D-7E9F1A3B5C7D}']
    procedure RegistrarRotas(ARoteador: TRoteador);
  end;

implementation

uses
  UExcecoes;

const
  STATUS_REQUISICAO_INVALIDA = 400;
  STATUS_NAO_ENCONTRADO = 404;
  STATUS_METODO_NAO_PERMITIDO = 405;
  STATUS_CONFLITO = 409;
  STATUS_ERRO_INTERNO = 500;

class function TMetodoHttpAuxiliar.TentarConverter(const ATexto: string; out AMetodo: TMetodoHttp): Boolean;
begin
  Result := True;
  if SameText(ATexto, 'GET') then
    AMetodo := mhGet
  else if SameText(ATexto, 'POST') then
    AMetodo := mhPost
  else if SameText(ATexto, 'PUT') then
    AMetodo := mhPut
  else if SameText(ATexto, 'DELETE') then
    AMetodo := mhDelete
  else
    Result := False;
end;

constructor TRequisicao.Create(AMetodo: TMetodoHttp; const ACaminho, ACorpo: string; AQuery: TStrings);
begin
  inherited Create;
  FMetodo := AMetodo;
  FCaminho := ACaminho;
  FCorpo := ACorpo;
  FQuery := TStringList.Create;
  if AQuery <> nil then
    FQuery.Assign(AQuery);
  FParametrosRota := TDictionary<string, string>.Create;
end;

destructor TRequisicao.Destroy;
begin
  FCorpoJson.Free;
  FParametrosRota.Free;
  FQuery.Free;
  inherited;
end;

function TRequisicao.CorpoJson: TJSONValue;
begin
  if FCorpoJson = nil then
  begin
    if Trim(FCorpo) = '' then
      raise EValidacao.Create('O corpo da requisição é obrigatório.');
    try
      FCorpoJson := TJSONObject.ParseJSONValue(FCorpo);
    except
      FCorpoJson := nil;
    end;
    if FCorpoJson = nil then
      raise EValidacao.Create('O corpo da requisição não é um JSON válido.');
  end;
  Result := FCorpoJson;
end;

function TRequisicao.CorpoComoObjeto: TJSONObject;
begin
  if not (CorpoJson is TJSONObject) then
    raise EValidacao.Create('O corpo da requisição deve ser um objeto JSON.');
  Result := TJSONObject(CorpoJson);
end;

function TRequisicao.CorpoComoLista: TJSONArray;
begin
  if not (CorpoJson is TJSONArray) then
    raise EValidacao.Create('O corpo da requisição deve ser uma lista JSON.');
  Result := TJSONArray(CorpoJson);
end;

function TRequisicao.ParametroRotaInt64(const ANome: string): Int64;
var
  LValor: string;
begin
  if not FParametrosRota.TryGetValue(ANome, LValor) or not TryStrToInt64(LValor, Result) then
    raise EValidacao.CreateFmt('Parâmetro "%s" inválido: "%s".', [ANome, LValor]);
end;

function TRequisicao.QueryTexto(const ANome: string): string;
begin
  Result := FQuery.Values[ANome];
end;

function TRequisicao.QueryInteiro(const ANome: string; APadrao: Integer): Integer;
begin
  Result := StrToIntDef(FQuery.Values[ANome], APadrao);
end;

function TRequisicao.QueryBooleano(const ANome: string; APadrao: Boolean): Boolean;
var
  LValor: string;
begin
  LValor := FQuery.Values[ANome];
  if LValor = '' then
    Result := APadrao
  else
    Result := SameText(LValor, 'true') or (LValor = '1');
end;

constructor TResposta.Create;
begin
  inherited Create;
  FStatus := STATUS_SEM_CONTEUDO;
end;

procedure TResposta.EnviarJson(AStatus: Integer; AConteudo: TJSONValue);
begin
  try
    FStatus := AStatus;
    FCorpo := AConteudo.ToJSON;
  finally
    AConteudo.Free;
  end;
end;

procedure TResposta.EnviarErro(AStatus: Integer; const AMensagem: string; const ADetalhes: TArray<string>);
var
  LJson: TJSONObject;
  LDetalhes: TJSONArray;
  LDetalhe: string;
begin
  LJson := TJSONObject.Create;
  LJson.AddPair('erro', AMensagem);
  if Length(ADetalhes) > 0 then
  begin
    LDetalhes := TJSONArray.Create;
    LJson.AddPair('detalhes', LDetalhes);
    for LDetalhe in ADetalhes do
      LDetalhes.Add(LDetalhe);
  end;
  EnviarJson(AStatus, LJson);
end;

procedure TResposta.EnviarSemConteudo;
begin
  FStatus := STATUS_SEM_CONTEUDO;
  FCorpo := '';
end;

constructor TRota.Create(AMetodo: TMetodoHttp; const APadrao: string; const AManipulador: TManipuladorRota);
begin
  inherited Create;
  FMetodo := AMetodo;
  FSegmentos := TRoteador.Segmentar(APadrao);
  FManipulador := AManipulador;
end;

function TRota.Corresponde(const ASegmentos: TArray<string>; AParametros: TDictionary<string, string>): Boolean;
var
  I: Integer;
begin
  AParametros.Clear;
  if Length(ASegmentos) <> Length(FSegmentos) then
    Exit(False);

  for I := 0 to High(FSegmentos) do
  begin
    if FSegmentos[I].StartsWith(':') then
      AParametros.AddOrSetValue(FSegmentos[I].Substring(1), ASegmentos[I])
    else if not SameText(FSegmentos[I], ASegmentos[I]) then
      Exit(False);
  end;
  Result := True;
end;

constructor TRoteador.Create;
begin
  inherited Create;
  FRotas := TObjectList<TRota>.Create(True);
end;

destructor TRoteador.Destroy;
begin
  FRotas.Free;
  inherited;
end;

class function TRoteador.Segmentar(const ACaminho: string): TArray<string>;
begin
  Result := ACaminho.Split(['/'], TStringSplitOptions.ExcludeEmpty);
end;

procedure TRoteador.Registrar(AMetodo: TMetodoHttp; const APadrao: string; const AManipulador: TManipuladorRota);
begin
  FRotas.Add(TRota.Create(AMetodo, APadrao, AManipulador));
end;

procedure TRoteador.Despachar(ARequisicao: TRequisicao; AResposta: TResposta);
var
  LSegmentos: TArray<string>;
  LRota: TRota;
  LCaminhoExiste: Boolean;
begin
  try
    LSegmentos := Segmentar(ARequisicao.Caminho);
    LCaminhoExiste := False;
    for LRota in FRotas do
    begin
      if not LRota.Corresponde(LSegmentos, ARequisicao.ParametrosRota) then
        Continue;
      LCaminhoExiste := True;
      if LRota.Metodo = ARequisicao.Metodo then
      begin
        LRota.Manipulador(ARequisicao, AResposta);
        Exit;
      end;
    end;

    if LCaminhoExiste then
      AResposta.EnviarErro(STATUS_METODO_NAO_PERMITIDO, 'Método não permitido para este recurso.')
    else
      AResposta.EnviarErro(STATUS_NAO_ENCONTRADO, 'Recurso não encontrado: ' + ARequisicao.Caminho);
  except
    on E: Exception do
      TratarExcecao(E, AResposta);
  end;
end;

procedure TRoteador.TratarExcecao(E: Exception; AResposta: TResposta);
begin
  if E is EValidacao then
    AResposta.EnviarErro(STATUS_REQUISICAO_INVALIDA, E.Message, EValidacao(E).Detalhes)
  else if E is ERegistroNaoEncontrado then
    AResposta.EnviarErro(STATUS_NAO_ENCONTRADO, E.Message)
  else if E is EOperacaoEmAndamento then
    AResposta.EnviarErro(STATUS_CONFLITO, E.Message)
  else
  begin
    if Assigned(FAoErroInterno) then
      FAoErroInterno(Format('%s: %s', [E.ClassName, E.Message]));
    AResposta.EnviarErro(STATUS_ERRO_INTERNO, 'Erro interno no servidor: ' + E.Message);
  end;
end;

end.
