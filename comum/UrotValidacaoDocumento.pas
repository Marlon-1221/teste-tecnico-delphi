unit UrotValidacaoDocumento;

interface

uses
  UPessoa;

type
  IValidadorDocumento = interface
    ['{7C1E2A53-7F0B-4D8B-9D55-3B7B4C4A61E1}']
    function EhValido(const ADocumento: string): Boolean;
    function CompletarDigitosVerificadores(const ABase: string): string;
    function NomeDocumento: string;
    function Tamanho: Integer;
  end;

  TValidadorDocumentoModulo11 = class abstract(TInterfacedObject, IValidadorDocumento)
  private
    class function CalcularDigito(const ADigitos: string; const APesos: TArray<Integer>): Integer; static;
    class function TodosDigitosIguais(const ADigitos: string): Boolean; static;
  protected
    function PesosPrimeiroDigito: TArray<Integer>; virtual; abstract;
    function PesosSegundoDigito: TArray<Integer>; virtual; abstract;
  public
    function EhValido(const ADocumento: string): Boolean;
    function CompletarDigitosVerificadores(const ABase: string): string;
    function NomeDocumento: string; virtual; abstract;
    function Tamanho: Integer; virtual; abstract;
  end;

  TValidadorCpf = class(TValidadorDocumentoModulo11)
  protected
    function PesosPrimeiroDigito: TArray<Integer>; override;
    function PesosSegundoDigito: TArray<Integer>; override;
  public
    function NomeDocumento: string; override;
    function Tamanho: Integer; override;
  end;

  TValidadorCnpj = class(TValidadorDocumentoModulo11)
  protected
    function PesosPrimeiroDigito: TArray<Integer>; override;
    function PesosSegundoDigito: TArray<Integer>; override;
  public
    function NomeDocumento: string; override;
    function Tamanho: Integer; override;
  end;

  TFabricaValidadorDocumento = class abstract
  public
    class function Criar(ANatureza: TNaturezaPessoa): IValidadorDocumento; static;
  end;

implementation

uses
  System.SysUtils,
  LibTexto;

const
  QUANTIDADE_DIGITOS_VERIFICADORES = 2;

class function TValidadorDocumentoModulo11.CalcularDigito(const ADigitos: string;
  const APesos: TArray<Integer>): Integer;
var
  I, LSoma, LResto: Integer;
begin
  LSoma := 0;
  for I := 0 to High(APesos) do
    Inc(LSoma, (Ord(ADigitos[I + 1]) - Ord('0')) * APesos[I]);
  LResto := LSoma mod 11;
  if LResto < 2 then
    Result := 0
  else
    Result := 11 - LResto;
end;

class function TValidadorDocumentoModulo11.TodosDigitosIguais(const ADigitos: string): Boolean;
begin
  Result := ADigitos = StringOfChar(ADigitos[1], Length(ADigitos));
end;

function TValidadorDocumentoModulo11.CompletarDigitosVerificadores(const ABase: string): string;
begin
  Result := ABase;
  Result := Result + IntToStr(CalcularDigito(Result, PesosPrimeiroDigito));
  Result := Result + IntToStr(CalcularDigito(Result, PesosSegundoDigito));
end;

function TValidadorDocumentoModulo11.EhValido(const ADocumento: string): Boolean;
var
  LDigitos: string;
begin
  LDigitos := TTexto.SomenteDigitos(ADocumento);
  if (Length(LDigitos) <> Tamanho) or TodosDigitosIguais(LDigitos) then
    Exit(False);
  Result := CompletarDigitosVerificadores(Copy(LDigitos, 1, Tamanho - QUANTIDADE_DIGITOS_VERIFICADORES)) = LDigitos;
end;

function TValidadorCpf.NomeDocumento: string;
begin
  Result := 'CPF';
end;

function TValidadorCpf.Tamanho: Integer;
begin
  Result := 11;
end;

function TValidadorCpf.PesosPrimeiroDigito: TArray<Integer>;
begin
  Result := TArray<Integer>.Create(10, 9, 8, 7, 6, 5, 4, 3, 2);
end;

function TValidadorCpf.PesosSegundoDigito: TArray<Integer>;
begin
  Result := TArray<Integer>.Create(11, 10, 9, 8, 7, 6, 5, 4, 3, 2);
end;

function TValidadorCnpj.NomeDocumento: string;
begin
  Result := 'CNPJ';
end;

function TValidadorCnpj.Tamanho: Integer;
begin
  Result := 14;
end;

function TValidadorCnpj.PesosPrimeiroDigito: TArray<Integer>;
begin
  Result := TArray<Integer>.Create(5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2);
end;

function TValidadorCnpj.PesosSegundoDigito: TArray<Integer>;
begin
  Result := TArray<Integer>.Create(6, 5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2);
end;

class function TFabricaValidadorDocumento.Criar(ANatureza: TNaturezaPessoa): IValidadorDocumento;
begin
  case ANatureza of
    npFisica:
      Result := TValidadorCpf.Create;
    npJuridica:
      Result := TValidadorCnpj.Create;
  else
    raise EArgumentException.Create('Natureza de pessoa sem validador de documento.');
  end;
end;

end.
