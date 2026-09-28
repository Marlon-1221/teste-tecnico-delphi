unit UControlePessoa;

interface

uses
  URoteador,
  UrotPessoa;

type
  TControlePessoa = class(TInterfacedObject, IControle)
  private const
    STATUS_OK = 200;
    STATUS_CRIADO = 201;
  private
    FServico: IRegraPessoa;
    procedure Listar(ARequisicao: TRequisicao; AResposta: TResposta);
    procedure Obter(ARequisicao: TRequisicao; AResposta: TResposta);
    procedure Inserir(ARequisicao: TRequisicao; AResposta: TResposta);
    procedure InserirLote(ARequisicao: TRequisicao; AResposta: TResposta);
    procedure Atualizar(ARequisicao: TRequisicao; AResposta: TResposta);
    procedure Excluir(ARequisicao: TRequisicao; AResposta: TResposta);
    procedure DocumentosCadastrados(ARequisicao: TRequisicao; AResposta: TResposta);
    procedure ResponderPessoa(AId: Int64; AStatus: Integer; AResposta: TResposta);
  public
    constructor Create(const AServico: IRegraPessoa);
    procedure RegistrarRotas(ARoteador: TRoteador);
  end;

implementation

uses
  System.SysUtils,
  System.JSON,
  System.Diagnostics,
  System.Generics.Collections,
  UPessoa,
  UPagina,
  UConversorJson;

constructor TControlePessoa.Create(const AServico: IRegraPessoa);
begin
  inherited Create;
  FServico := AServico;
end;

procedure TControlePessoa.RegistrarRotas(ARoteador: TRoteador);
begin
  ARoteador.Registrar(mhPost, '/pessoas/lote', InserirLote);
  ARoteador.Registrar(mhPost, '/pessoas/documentos', DocumentosCadastrados);
  ARoteador.Registrar(mhGet, '/pessoas', Listar);
  ARoteador.Registrar(mhPost, '/pessoas', Inserir);
  ARoteador.Registrar(mhGet, '/pessoas/:id', Obter);
  ARoteador.Registrar(mhPut, '/pessoas/:id', Atualizar);
  ARoteador.Registrar(mhDelete, '/pessoas/:id', Excluir);
end;

procedure TControlePessoa.ResponderPessoa(AId: Int64; AStatus: Integer; AResposta: TResposta);
var
  LPessoa: TPessoa;
begin
  LPessoa := FServico.Obter(AId);
  try
    AResposta.EnviarJson(AStatus, TPessoaJson.ParaJson(LPessoa));
  finally
    LPessoa.Free;
  end;
end;

procedure TControlePessoa.Listar(ARequisicao: TRequisicao; AResposta: TResposta);
var
  LPagina: TPagina<TPessoa>;
begin
  LPagina := FServico.Listar(ARequisicao.QueryInteiro('pagina', 1), ARequisicao.QueryInteiro('tamanho', 0),
    ARequisicao.QueryTexto('busca'));
  try
    AResposta.EnviarJson(STATUS_OK, TPessoaJson.PaginaParaJson(LPagina));
  finally
    LPagina.Free;
  end;
end;

procedure TControlePessoa.Obter(ARequisicao: TRequisicao; AResposta: TResposta);
begin
  ResponderPessoa(ARequisicao.ParametroRotaInt64('id'), STATUS_OK, AResposta);
end;

procedure TControlePessoa.Inserir(ARequisicao: TRequisicao; AResposta: TResposta);
var
  LPessoa: TPessoa;
begin
  LPessoa := TPessoaJson.DeJson(ARequisicao.CorpoComoObjeto);
  try
    FServico.Inserir(LPessoa);
    AResposta.EnviarJson(STATUS_CRIADO, TPessoaJson.ParaJson(LPessoa));
  finally
    LPessoa.Free;
  end;
end;

procedure TControlePessoa.InserirLote(ARequisicao: TRequisicao; AResposta: TResposta);
var
  LPessoas: TObjectList<TPessoa>;
  LCronometro: TStopwatch;
  LResultado: TJSONObject;
  LInseridos: Integer;
begin
  LCronometro := TStopwatch.StartNew;
  LPessoas := TPessoaJson.ListaDeJson(ARequisicao.CorpoComoLista);
  try
    LInseridos := FServico.InserirLote(LPessoas);
  finally
    LPessoas.Free;
  end;

  LResultado := TJSONObject.Create;
  LResultado.AddPair('inseridos', TJSONNumber.Create(LInseridos));
  LResultado.AddPair('tempoMs', TJSONNumber.Create(LCronometro.ElapsedMilliseconds));
  AResposta.EnviarJson(STATUS_CRIADO, LResultado);
end;

procedure TControlePessoa.Atualizar(ARequisicao: TRequisicao; AResposta: TResposta);
var
  LPessoa: TPessoa;
begin
  LPessoa := TPessoaJson.DeJson(ARequisicao.CorpoComoObjeto);
  try
    LPessoa.Id := ARequisicao.ParametroRotaInt64('id');
    FServico.Atualizar(LPessoa);
  finally
    LPessoa.Free;
  end;
  ResponderPessoa(ARequisicao.ParametroRotaInt64('id'), STATUS_OK, AResposta);
end;

procedure TControlePessoa.Excluir(ARequisicao: TRequisicao; AResposta: TResposta);
begin
  FServico.Excluir(ARequisicao.ParametroRotaInt64('id'));
  AResposta.EnviarSemConteudo;
end;

procedure TControlePessoa.DocumentosCadastrados(ARequisicao: TRequisicao; AResposta: TResposta);
var
  LEntrada: TJSONArray;
  LDocumentos: TArray<string>;
  LSaida: TJSONArray;
  LDocumento: string;
  I: Integer;
begin
  LEntrada := ARequisicao.CorpoComoLista;
  SetLength(LDocumentos, LEntrada.Count);
  for I := 0 to LEntrada.Count - 1 do
    LDocumentos[I] := LEntrada.Items[I].Value;

  LSaida := TJSONArray.Create;
  try
    for LDocumento in FServico.DocumentosCadastrados(LDocumentos) do
      LSaida.Add(LDocumento);
  except
    LSaida.Free;
    raise;
  end;
  AResposta.EnviarJson(STATUS_OK, LSaida);
end;

end.
