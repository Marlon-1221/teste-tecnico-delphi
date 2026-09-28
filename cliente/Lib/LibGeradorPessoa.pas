unit LibGeradorPessoa;

interface

uses
  System.SysUtils,
  System.Generics.Collections,
  UPessoa,
  UrotValidacaoDocumento;

type
  TConsultaDocumentos = reference to function(const ADocumentos: TArray<string>): TArray<string>;

  TGeradorPessoas = class
  private const
    PERCENTUAL_PESSOA_FISICA = 80;
    MAXIMO_TENTATIVAS = 5;
  private
    FValidadorCpf: IValidadorDocumento;
    FValidadorCnpj: IValidadorDocumento;
    FDocumentosUsados: TDictionary<string, Boolean>;
    class function Sortear(const AOpcoes: array of string): string; static;
    class function DigitosAleatorios(AQuantidade: Integer): string; static;
    function NovoDocumento(ANatureza: TNaturezaPessoa): string;
    function CriarPessoaFisica: TPessoa;
    function CriarPessoaJuridica: TPessoa;
    procedure SubstituirDocumentosCadastrados(APessoas: TObjectList<TPessoa>;
      const AConsultarCadastrados: TConsultaDocumentos);
  public
    constructor Create;
    destructor Destroy; override;
    function Gerar(AQuantidade: Integer; const AConsultarCadastrados: TConsultaDocumentos): TObjectList<TPessoa>;
  end;

implementation

uses
  UExcecoes;

const
  NOMES: array[0..11] of string = ('Ana', 'Bruno', 'Carla', 'Diego', 'Elisa', 'Fábio', 'Gabriela', 'Heitor',
    'Íris', 'João', 'Larissa', 'Márcio');
  SOBRENOMES: array[0..9] of string = ('Silva', 'Souza', 'Oliveira', 'Conceição', 'Araújo', 'Lima', 'Pereira',
    'Gonçalves', 'Ribeiro', 'Almeida');
  ATIVIDADES: array[0..5] of string = ('Comércio', 'Transportes', 'Tecnologia', 'Alimentos', 'Construções',
    'Serviços');
  CEPS: array[0..19] of string = ('01001000', '20040020', '30130010', '40026010', '80010000', '88010001',
    '90010000', '70040010', '60060000', '50030000', '69005000', '66010000', '64000020', '57020000',
    '49010000', '58010000', '59010000', '78005000', '79002000', '74003010');
  BASE_CPF = 9;
  RAIZ_CNPJ = 8;
  FILIAL_MATRIZ = '0001';

constructor TGeradorPessoas.Create;
begin
  inherited Create;
  FValidadorCpf := TFabricaValidadorDocumento.Criar(npFisica);
  FValidadorCnpj := TFabricaValidadorDocumento.Criar(npJuridica);
  FDocumentosUsados := TDictionary<string, Boolean>.Create;
end;

destructor TGeradorPessoas.Destroy;
begin
  FDocumentosUsados.Free;
  inherited;
end;

class function TGeradorPessoas.Sortear(const AOpcoes: array of string): string;
begin
  Result := AOpcoes[Random(Length(AOpcoes))];
end;

class function TGeradorPessoas.DigitosAleatorios(AQuantidade: Integer): string;
var
  I: Integer;
begin
  SetLength(Result, AQuantidade);
  for I := 1 to AQuantidade do
    Result[I] := Char(Ord('0') + Random(10));
end;

function TGeradorPessoas.NovoDocumento(ANatureza: TNaturezaPessoa): string;
begin
  repeat
    if ANatureza = npFisica then
      Result := FValidadorCpf.CompletarDigitosVerificadores(DigitosAleatorios(BASE_CPF))
    else
      Result := FValidadorCnpj.CompletarDigitosVerificadores(DigitosAleatorios(RAIZ_CNPJ) + FILIAL_MATRIZ);
  until not FDocumentosUsados.ContainsKey(Result);
  FDocumentosUsados.Add(Result, True);
end;

function TGeradorPessoas.CriarPessoaFisica: TPessoa;
begin
  Result := TPessoa.Create;
  Result.Natureza := npFisica;
  Result.Documento := NovoDocumento(npFisica);
  Result.PrimeiroNome := Sortear(NOMES);
  Result.SegundoNome := Sortear(SOBRENOMES) + ' ' + Sortear(SOBRENOMES);
end;

function TGeradorPessoas.CriarPessoaJuridica: TPessoa;
var
  LSobrenome, LAtividade: string;
begin
  LSobrenome := Sortear(SOBRENOMES);
  LAtividade := Sortear(ATIVIDADES);
  Result := TPessoa.Create;
  Result.Natureza := npJuridica;
  Result.Documento := NovoDocumento(npJuridica);
  Result.PrimeiroNome := Format('%s %s Ltda', [LSobrenome, LAtividade]);
  Result.SegundoNome := Format('%s %s', [LAtividade, LSobrenome]);
end;

procedure TGeradorPessoas.SubstituirDocumentosCadastrados(APessoas: TObjectList<TPessoa>;
  const AConsultarCadastrados: TConsultaDocumentos);
var
  LAConferir: TList<TPessoa>;
  LCadastrados: TDictionary<string, Boolean>;
  LDocumentos: TArray<string>;
  LDocumento: string;
  LPessoa: TPessoa;
  LTentativa, I: Integer;
begin
  LAConferir := TList<TPessoa>.Create;
  LCadastrados := TDictionary<string, Boolean>.Create;
  try
    LAConferir.AddRange(APessoas);
    for LTentativa := 1 to MAXIMO_TENTATIVAS do
    begin
      SetLength(LDocumentos, LAConferir.Count);
      for I := 0 to LAConferir.Count - 1 do
        LDocumentos[I] := LAConferir[I].Documento;

      LCadastrados.Clear;
      for LDocumento in AConsultarCadastrados(LDocumentos) do
        LCadastrados.AddOrSetValue(LDocumento, True);
      if LCadastrados.Count = 0 then
        Exit;

      for I := LAConferir.Count - 1 downto 0 do
      begin
        LPessoa := LAConferir[I];
        if LCadastrados.ContainsKey(LPessoa.Documento) then
          LPessoa.Documento := NovoDocumento(LPessoa.Natureza)
        else
          LAConferir.Delete(I);
      end;
    end;
    raise EAplicacao.Create('Não foi possível gerar documentos que ainda não estejam cadastrados.');
  finally
    LCadastrados.Free;
    LAConferir.Free;
  end;
end;

function TGeradorPessoas.Gerar(AQuantidade: Integer;
  const AConsultarCadastrados: TConsultaDocumentos): TObjectList<TPessoa>;
var
  LPessoa: TPessoa;
  I: Integer;
begin
  FDocumentosUsados.Clear;
  Result := TObjectList<TPessoa>.Create(True);
  try
    Result.Capacity := AQuantidade;
    for I := 1 to AQuantidade do
    begin
      if Random(100) < PERCENTUAL_PESSOA_FISICA then
        LPessoa := CriarPessoaFisica
      else
        LPessoa := CriarPessoaJuridica;
      Result.Add(LPessoa);
      LPessoa.AdicionarEndereco(Sortear(CEPS));
    end;
    SubstituirDocumentosCadastrados(Result, AConsultarCadastrados);
  except
    Result.Free;
    raise;
  end;
end;

end.
