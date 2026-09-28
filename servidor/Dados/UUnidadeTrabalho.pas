unit UUnidadeTrabalho;

interface

uses
  FireDAC.Comp.Client,
  UConexao,
  URepositorioPessoa,
  URepositorioEndereco,
  URepositorioIntegracao,
  URepositorioSistema;

type
  IUnidadeTrabalho = interface;

  TOperacaoTransacional = reference to procedure(AUnidade: IUnidadeTrabalho);

  IUnidadeTrabalho = interface
    ['{D6F8A0C2-4E61-4A3B-8C5D-7F9B1D3F5A74}']
    function Pessoas: IRepositorioPessoa;
    function Enderecos: IRepositorioEndereco;
    function Integracoes: IRepositorioIntegracao;
    function Sistema: IRepositorioSistema;
    procedure ExecutarEmTransacao(const AOperacao: TOperacaoTransacional);
  end;

  IFabricaUnidadeTrabalho = interface
    ['{E8A0C2E4-6A83-4C5D-9E7F-9B1D3F5A7C96}']
    function Criar: IUnidadeTrabalho;
  end;

  TUnidadeTrabalho = class(TInterfacedObject, IUnidadeTrabalho)
  private
    FConexao: TFDConnection;
    FPessoas: IRepositorioPessoa;
    FEnderecos: IRepositorioEndereco;
    FIntegracoes: IRepositorioIntegracao;
    FSistema: IRepositorioSistema;
  public
    constructor Create(AConexao: TFDConnection);
    destructor Destroy; override;
    function Pessoas: IRepositorioPessoa;
    function Enderecos: IRepositorioEndereco;
    function Integracoes: IRepositorioIntegracao;
    function Sistema: IRepositorioSistema;
    procedure ExecutarEmTransacao(const AOperacao: TOperacaoTransacional);
  end;

  TFabricaUnidadeTrabalho = class(TInterfacedObject, IFabricaUnidadeTrabalho)
  private
    FFabricaConexao: IFabricaConexao;
  public
    constructor Create(const AFabricaConexao: IFabricaConexao);
    function Criar: IUnidadeTrabalho;
  end;

implementation

constructor TUnidadeTrabalho.Create(AConexao: TFDConnection);
begin
  inherited Create;
  FConexao := AConexao;
end;

destructor TUnidadeTrabalho.Destroy;
begin
  FPessoas := nil;
  FEnderecos := nil;
  FIntegracoes := nil;
  FSistema := nil;
  FConexao.Free;
  inherited;
end;

function TUnidadeTrabalho.Pessoas: IRepositorioPessoa;
begin
  if FPessoas = nil then
    FPessoas := TRepositorioPessoa.Create(FConexao);
  Result := FPessoas;
end;

function TUnidadeTrabalho.Enderecos: IRepositorioEndereco;
begin
  if FEnderecos = nil then
    FEnderecos := TRepositorioEndereco.Create(FConexao);
  Result := FEnderecos;
end;

function TUnidadeTrabalho.Integracoes: IRepositorioIntegracao;
begin
  if FIntegracoes = nil then
    FIntegracoes := TRepositorioIntegracao.Create(FConexao);
  Result := FIntegracoes;
end;

function TUnidadeTrabalho.Sistema: IRepositorioSistema;
begin
  if FSistema = nil then
    FSistema := TRepositorioSistema.Create(FConexao);
  Result := FSistema;
end;

procedure TUnidadeTrabalho.ExecutarEmTransacao(const AOperacao: TOperacaoTransacional);
begin
  FConexao.StartTransaction;
  try
    AOperacao(Self);
    FConexao.Commit;
  except
    FConexao.Rollback;
    raise;
  end;
end;

constructor TFabricaUnidadeTrabalho.Create(const AFabricaConexao: IFabricaConexao);
begin
  inherited Create;
  FFabricaConexao := AFabricaConexao;
end;

function TFabricaUnidadeTrabalho.Criar: IUnidadeTrabalho;
begin
  Result := TUnidadeTrabalho.Create(FFabricaConexao.CriarConexao);
end;

end.
