unit UrotPessoa;

interface

uses
  System.Generics.Collections,
  UPessoa,
  UPagina,
  UUnidadeTrabalho;

type
  IRegraPessoa = interface
    ['{F0A2C4E6-8B05-4E7F-A1B3-C5D7E9F1A3B5}']
    function Listar(ANumeroPagina, ATamanhoPagina: Integer; const ABusca: string = ''): TPagina<TPessoa>;
    function Obter(AId: Int64): TPessoa;
    procedure Inserir(APessoa: TPessoa);
    procedure Atualizar(APessoa: TPessoa);
    procedure Excluir(AId: Int64);
    function InserirLote(APessoas: TList<TPessoa>): Integer;
    function DocumentosCadastrados(const ADocumentos: TArray<string>): TArray<string>;
  end;

  TRegraPessoa = class(TInterfacedObject, IRegraPessoa)
  private const
    TAMANHO_PAGINA_PADRAO = 100;
    TAMANHO_PAGINA_MAXIMO = 1000;
    LIMITE_REGISTROS_LOTE = 100000;
    MAXIMO_DETALHES_LOTE = 50;
  private
    FFabricaUnidadeTrabalho: IFabricaUnidadeTrabalho;
    procedure PrepararParaGravacao(APessoa: TPessoa);
    procedure ValidarId(AId: Int64);
    class function DescreverDocumento(APessoa: TPessoa): string; static;
    procedure ValidarDocumentoUnico(const AUnidade: IUnidadeTrabalho; APessoa: TPessoa);
    procedure ValidarDocumentosUnicosLote(const AUnidade: IUnidadeTrabalho; APessoas: TList<TPessoa>);
  public
    constructor Create(const AFabricaUnidadeTrabalho: IFabricaUnidadeTrabalho);
    function Listar(ANumeroPagina, ATamanhoPagina: Integer; const ABusca: string = ''): TPagina<TPessoa>;
    function Obter(AId: Int64): TPessoa;
    procedure Inserir(APessoa: TPessoa);
    procedure Atualizar(APessoa: TPessoa);
    procedure Excluir(AId: Int64);
    function InserirLote(APessoas: TList<TPessoa>): Integer;
    function DocumentosCadastrados(const ADocumentos: TArray<string>): TArray<string>;
  end;

implementation

uses
  System.SysUtils,
  System.Math,
  UExcecoes,
  LibTexto,
  UrotValidacaoDocumento,
  UrotValidacaoPessoa;

constructor TRegraPessoa.Create(const AFabricaUnidadeTrabalho: IFabricaUnidadeTrabalho);
begin
  inherited Create;
  FFabricaUnidadeTrabalho := AFabricaUnidadeTrabalho;
end;

procedure TRegraPessoa.PrepararParaGravacao(APessoa: TPessoa);
begin
  TPessoaValidador.Normalizar(APessoa);
  TPessoaValidador.Validar(APessoa);
end;

procedure TRegraPessoa.ValidarId(AId: Int64);
begin
  if AId <= 0 then
    raise EValidacao.CreateFmt('Identificador de pessoa inválido: %d.', [AId]);
end;

function TRegraPessoa.Listar(ANumeroPagina, ATamanhoPagina: Integer; const ABusca: string): TPagina<TPessoa>;
var
  LNumero, LTamanho: Integer;
  LUnidade: IUnidadeTrabalho;
begin
  LNumero := Max(ANumeroPagina, 1);
  if ATamanhoPagina <= 0 then
    LTamanho := TAMANHO_PAGINA_PADRAO
  else
    LTamanho := Min(ATamanhoPagina, TAMANHO_PAGINA_MAXIMO);

  Result := TPagina<TPessoa>.Create(LNumero, LTamanho);
  try
    LUnidade := FFabricaUnidadeTrabalho.Criar;
    Result.TotalRegistros := LUnidade.Pessoas.Contar(ABusca);
    LUnidade.Pessoas.Listar((LNumero - 1) * LTamanho, LTamanho, Result.Itens, ABusca);
    LUnidade.Enderecos.CarregarDasPessoas(Result.Itens.ToArray);
  except
    Result.Free;
    raise;
  end;
end;

function TRegraPessoa.Obter(AId: Int64): TPessoa;
var
  LUnidade: IUnidadeTrabalho;
begin
  ValidarId(AId);
  LUnidade := FFabricaUnidadeTrabalho.Criar;
  Result := LUnidade.Pessoas.BuscarPorId(AId);
  if Result = nil then
    raise ERegistroNaoEncontrado.CreateFmt('Pessoa %d não encontrada.', [AId]);
  try
    LUnidade.Enderecos.CarregarDasPessoas([Result]);
  except
    Result.Free;
    raise;
  end;
end;

procedure TRegraPessoa.Inserir(APessoa: TPessoa);
var
  LUnidade: IUnidadeTrabalho;
begin
  PrepararParaGravacao(APessoa);
  APessoa.Id := 0;
  if not APessoa.PossuiDataRegistro then
    APessoa.DataRegistro := Date;

  LUnidade := FFabricaUnidadeTrabalho.Criar;
  LUnidade.ExecutarEmTransacao(
    procedure(AUnidade: IUnidadeTrabalho)
    begin
      ValidarDocumentoUnico(AUnidade, APessoa);
      AUnidade.Pessoas.Inserir(APessoa);
      AUnidade.Enderecos.InserirDaPessoa(APessoa);
    end);
end;

procedure TRegraPessoa.Atualizar(APessoa: TPessoa);
var
  LUnidade: IUnidadeTrabalho;
begin
  ValidarId(APessoa.Id);
  PrepararParaGravacao(APessoa);

  LUnidade := FFabricaUnidadeTrabalho.Criar;
  LUnidade.ExecutarEmTransacao(
    procedure(AUnidade: IUnidadeTrabalho)
    begin
      ValidarDocumentoUnico(AUnidade, APessoa);
      if not AUnidade.Pessoas.Atualizar(APessoa) then
        raise ERegistroNaoEncontrado.CreateFmt('Pessoa %d não encontrada.', [APessoa.Id]);
      AUnidade.Enderecos.SincronizarDaPessoa(APessoa);
    end);
end;

procedure TRegraPessoa.Excluir(AId: Int64);
var
  LUnidade: IUnidadeTrabalho;
begin
  ValidarId(AId);
  LUnidade := FFabricaUnidadeTrabalho.Criar;
  if not LUnidade.Pessoas.Excluir(AId) then
    raise ERegistroNaoEncontrado.CreateFmt('Pessoa %d não encontrada.', [AId]);
end;

function TRegraPessoa.InserirLote(APessoas: TList<TPessoa>): Integer;
var
  LPessoa: TPessoa;
  LUnidade: IUnidadeTrabalho;
begin
  if APessoas.Count = 0 then
    raise EValidacao.Create('O lote não possui registros.');
  if APessoas.Count > LIMITE_REGISTROS_LOTE then
    raise EValidacao.CreateFmt('O lote possui %d registros; o limite é %d.', [APessoas.Count, LIMITE_REGISTROS_LOTE]);

  for LPessoa in APessoas do
  begin
    TPessoaValidador.Normalizar(LPessoa);
    LPessoa.Id := 0;
    if not LPessoa.PossuiDataRegistro then
      LPessoa.DataRegistro := Date;
  end;
  TPessoaValidador.ValidarLote(APessoas);

  LUnidade := FFabricaUnidadeTrabalho.Criar;
  ValidarDocumentosUnicosLote(LUnidade, APessoas);
  LUnidade.ExecutarEmTransacao(
    procedure(AUnidade: IUnidadeTrabalho)
    begin
      AUnidade.Pessoas.InserirLote(APessoas);
      AUnidade.Enderecos.InserirLote(APessoas);
    end);
  Result := APessoas.Count;
end;

class function TRegraPessoa.DescreverDocumento(APessoa: TPessoa): string;
begin
  Result := TFabricaValidadorDocumento.Criar(APessoa.Natureza).NomeDocumento + ' ' +
    TTexto.FormatarDocumento(APessoa.Documento);
end;

procedure TRegraPessoa.ValidarDocumentoUnico(const AUnidade: IUnidadeTrabalho; APessoa: TPessoa);
var
  LCadastrados: TDictionary<string, Int64>;
  LIdExistente: Int64;
begin
  LCadastrados := AUnidade.Pessoas.DocumentosCadastrados([APessoa.Documento], APessoa.Id);
  try
    if LCadastrados.TryGetValue(APessoa.Documento, LIdExistente) then
      raise EValidacao.Create('Cadastro de cliente inválido.',
        [Format('%s já cadastrado para o cliente %d.', [DescreverDocumento(APessoa), LIdExistente])]);
  finally
    LCadastrados.Free;
  end;
end;

procedure TRegraPessoa.ValidarDocumentosUnicosLote(const AUnidade: IUnidadeTrabalho; APessoas: TList<TPessoa>);
var
  LPrimeiroRegistro: TDictionary<string, Integer>;
  LCadastrados: TDictionary<string, Int64>;
  LDetalhes: TList<string>;
  LRegistroAnterior, LQuantidade, I: Integer;
  LIdExistente: Int64;
  LMensagem: string;
begin
  LPrimeiroRegistro := TDictionary<string, Integer>.Create;
  LDetalhes := TList<string>.Create;
  try
    for I := 0 to APessoas.Count - 1 do
      if not LPrimeiroRegistro.ContainsKey(APessoas[I].Documento) then
        LPrimeiroRegistro.Add(APessoas[I].Documento, I);

    LCadastrados := AUnidade.Pessoas.DocumentosCadastrados(LPrimeiroRegistro.Keys.ToArray);
    try
      LQuantidade := 0;
      for I := 0 to APessoas.Count - 1 do
      begin
        LRegistroAnterior := LPrimeiroRegistro[APessoas[I].Documento];
        if LCadastrados.TryGetValue(APessoas[I].Documento, LIdExistente) then
          LMensagem := Format('Registro %d: %s já cadastrado para o cliente %d.',
            [I + 1, DescreverDocumento(APessoas[I]), LIdExistente])
        else if LRegistroAnterior <> I then
          LMensagem := Format('Registro %d: %s repetido no lote (igual ao registro %d).',
            [I + 1, DescreverDocumento(APessoas[I]), LRegistroAnterior + 1])
        else
          Continue;

        Inc(LQuantidade);
        if LDetalhes.Count < MAXIMO_DETALHES_LOTE then
          LDetalhes.Add(LMensagem);
      end;
    finally
      LCadastrados.Free;
    end;

    if LQuantidade > 0 then
      raise EValidacao.Create(Format('%d registro(s) com CPF/CNPJ duplicado. Nenhum registro foi gravado.',
        [LQuantidade]), LDetalhes.ToArray);
  finally
    LDetalhes.Free;
    LPrimeiroRegistro.Free;
  end;
end;

function TRegraPessoa.DocumentosCadastrados(const ADocumentos: TArray<string>): TArray<string>;
var
  LNormalizados: TList<string>;
  LDocumento: string;
  LUnidade: IUnidadeTrabalho;
  LCadastrados: TDictionary<string, Int64>;
begin
  LNormalizados := TList<string>.Create;
  try
    for LDocumento in ADocumentos do
      if TTexto.SomenteDigitos(LDocumento) <> '' then
        LNormalizados.Add(TTexto.SomenteDigitos(LDocumento));
    LUnidade := FFabricaUnidadeTrabalho.Criar;
    LCadastrados := LUnidade.Pessoas.DocumentosCadastrados(LNormalizados.ToArray);
    try
      Result := LCadastrados.Keys.ToArray;
    finally
      LCadastrados.Free;
    end;
  finally
    LNormalizados.Free;
  end;
end;

end.
