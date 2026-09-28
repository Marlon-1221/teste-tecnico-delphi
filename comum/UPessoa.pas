unit UPessoa;

interface

uses
  System.Generics.Collections,
  UEntidade;

type
  TNaturezaPessoa = (npFisica = 1, npJuridica = 2);

  TNaturezaPessoaAuxiliar = record helper for TNaturezaPessoa
  public
    class function DeInteiro(AValor: Integer): TNaturezaPessoa; static;
    function ParaInteiro: Integer;
    function Descricao: string;
  end;

  TEnderecoIntegracao = class
  private
    FUf: string;
    FCidade: string;
    FBairro: string;
    FLogradouro: string;
    FComplemento: string;
  public
    procedure CopiarDe(AOrigem: TEnderecoIntegracao);
    property Uf: string read FUf write FUf;
    property Cidade: string read FCidade write FCidade;
    property Bairro: string read FBairro write FBairro;
    property Logradouro: string read FLogradouro write FLogradouro;
    property Complemento: string read FComplemento write FComplemento;
  end;

  TEndereco = class(TEntidade)
  private
    FIdPessoa: Int64;
    FCep: string;
    FIntegracao: TEnderecoIntegracao;
    procedure SetIntegracao(const AValor: TEnderecoIntegracao);
  public
    destructor Destroy; override;
    function PossuiIntegracao: Boolean;
    property IdPessoa: Int64 read FIdPessoa write FIdPessoa;
    property Cep: string read FCep write FCep;
    property Integracao: TEnderecoIntegracao read FIntegracao write SetIntegracao;
  end;

  TPessoa = class(TEntidade)
  private
    FNatureza: TNaturezaPessoa;
    FDocumento: string;
    FPrimeiroNome: string;
    FSegundoNome: string;
    FDataRegistro: TDate;
    FEnderecos: TObjectList<TEndereco>;
  public
    constructor Create;
    destructor Destroy; override;
    function AdicionarEndereco(const ACep: string; AId: Int64 = 0): TEndereco;
    function PossuiDataRegistro: Boolean;
    property Natureza: TNaturezaPessoa read FNatureza write FNatureza;
    property Documento: string read FDocumento write FDocumento;
    property PrimeiroNome: string read FPrimeiroNome write FPrimeiroNome;
    property SegundoNome: string read FSegundoNome write FSegundoNome;
    property DataRegistro: TDate read FDataRegistro write FDataRegistro;
    property Enderecos: TObjectList<TEndereco> read FEnderecos;
  end;

implementation

uses
  UExcecoes;

class function TNaturezaPessoaAuxiliar.DeInteiro(AValor: Integer): TNaturezaPessoa;
begin
  case AValor of
    Ord(npFisica):
      Result := npFisica;
    Ord(npJuridica):
      Result := npJuridica;
  else
    raise EValidacao.CreateFmt('Natureza inválida: %d. Utilize 1 (Física) ou 2 (Jurídica).', [AValor]);
  end;
end;

function TNaturezaPessoaAuxiliar.ParaInteiro: Integer;
begin
  Result := Ord(Self);
end;

function TNaturezaPessoaAuxiliar.Descricao: string;
begin
  case Self of
    npFisica:
      Result := 'Física';
    npJuridica:
      Result := 'Jurídica';
  else
    Result := '';
  end;
end;

procedure TEnderecoIntegracao.CopiarDe(AOrigem: TEnderecoIntegracao);
begin
  FUf := AOrigem.Uf;
  FCidade := AOrigem.Cidade;
  FBairro := AOrigem.Bairro;
  FLogradouro := AOrigem.Logradouro;
  FComplemento := AOrigem.Complemento;
end;

destructor TEndereco.Destroy;
begin
  FIntegracao.Free;
  inherited;
end;

function TEndereco.PossuiIntegracao: Boolean;
begin
  Result := FIntegracao <> nil;
end;

procedure TEndereco.SetIntegracao(const AValor: TEnderecoIntegracao);
begin
  if FIntegracao = AValor then
    Exit;
  FIntegracao.Free;
  FIntegracao := AValor;
end;

constructor TPessoa.Create;
begin
  inherited Create;
  FNatureza := npFisica;
  FEnderecos := TObjectList<TEndereco>.Create(True);
end;

destructor TPessoa.Destroy;
begin
  FEnderecos.Free;
  inherited;
end;

function TPessoa.AdicionarEndereco(const ACep: string; AId: Int64): TEndereco;
begin
  Result := TEndereco.Create;
  Result.Id := AId;
  Result.IdPessoa := Id;
  Result.Cep := ACep;
  FEnderecos.Add(Result);
end;

function TPessoa.PossuiDataRegistro: Boolean;
begin
  Result := FDataRegistro > 0;
end;

end.
