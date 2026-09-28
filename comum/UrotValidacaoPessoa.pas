unit UrotValidacaoPessoa;

interface

uses
  System.Generics.Collections,
  UPessoa;

type
  TPessoaValidador = class abstract
  private const
    TAMANHO_MAXIMO_NOME = 100;
    TAMANHO_CEP = 8;
    MAXIMO_INCONSISTENCIAS_LOTE = 50;
  private
    class procedure ValidarNome(AInconsistencias: TList<string>; const ANome, ADescricao: string); static;
    class procedure ValidarEnderecos(AInconsistencias: TList<string>; APessoa: TPessoa); static;
  public
    class procedure Normalizar(APessoa: TPessoa); static;
    class function Inconsistencias(APessoa: TPessoa): TArray<string>; static;
    class procedure Validar(APessoa: TPessoa); static;
    class procedure ValidarLote(APessoas: TList<TPessoa>); static;
  end;

implementation

uses
  System.SysUtils,
  UExcecoes,
  LibTexto,
  UrotValidacaoDocumento;

class procedure TPessoaValidador.Normalizar(APessoa: TPessoa);
var
  LEndereco: TEndereco;
begin
  APessoa.Documento := TTexto.SomenteDigitos(APessoa.Documento);
  APessoa.PrimeiroNome := Trim(APessoa.PrimeiroNome);
  APessoa.SegundoNome := Trim(APessoa.SegundoNome);
  for LEndereco in APessoa.Enderecos do
    LEndereco.Cep := TTexto.SomenteDigitos(LEndereco.Cep);
end;

class procedure TPessoaValidador.ValidarNome(AInconsistencias: TList<string>; const ANome, ADescricao: string);
begin
  if Trim(ANome) = '' then
    AInconsistencias.Add(Format('%s é obrigatório.', [ADescricao]))
  else if Length(ANome) > TAMANHO_MAXIMO_NOME then
    AInconsistencias.Add(Format('%s deve ter no máximo %d caracteres.', [ADescricao, TAMANHO_MAXIMO_NOME]));
end;

class procedure TPessoaValidador.ValidarEnderecos(AInconsistencias: TList<string>; APessoa: TPessoa);
var
  LEndereco: TEndereco;
begin
  if APessoa.Enderecos.Count = 0 then
  begin
    AInconsistencias.Add('A pessoa deve possuir ao menos um endereço.');
    Exit;
  end;

  for LEndereco in APessoa.Enderecos do
    if Length(TTexto.SomenteDigitos(LEndereco.Cep)) <> TAMANHO_CEP then
      AInconsistencias.Add(Format('CEP inválido: "%s". Informe %d dígitos.', [LEndereco.Cep, TAMANHO_CEP]));
end;

class function TPessoaValidador.Inconsistencias(APessoa: TPessoa): TArray<string>;
var
  LInconsistencias: TList<string>;
  LValidadorDocumento: IValidadorDocumento;
begin
  LInconsistencias := TList<string>.Create;
  try
    LValidadorDocumento := TFabricaValidadorDocumento.Criar(APessoa.Natureza);
    if not LValidadorDocumento.EhValido(APessoa.Documento) then
      LInconsistencias.Add(Format('%s inválido: "%s".', [LValidadorDocumento.NomeDocumento, APessoa.Documento]));

    ValidarNome(LInconsistencias, APessoa.PrimeiroNome, 'Primeiro nome');
    ValidarNome(LInconsistencias, APessoa.SegundoNome, 'Segundo nome');
    ValidarEnderecos(LInconsistencias, APessoa);

    Result := LInconsistencias.ToArray;
  finally
    LInconsistencias.Free;
  end;
end;

class procedure TPessoaValidador.Validar(APessoa: TPessoa);
var
  LInconsistencias: TArray<string>;
begin
  LInconsistencias := Inconsistencias(APessoa);
  if Length(LInconsistencias) > 0 then
    raise EValidacao.Create('Cadastro de pessoa inválido.', LInconsistencias);
end;

class procedure TPessoaValidador.ValidarLote(APessoas: TList<TPessoa>);
var
  LDetalhes: TList<string>;
  LInconsistenciasRegistro: TArray<string>;
  LInconsistencia: string;
  LQuantidadeInvalidos, I: Integer;
begin
  LDetalhes := TList<string>.Create;
  try
    LQuantidadeInvalidos := 0;
    for I := 0 to APessoas.Count - 1 do
    begin
      LInconsistenciasRegistro := Inconsistencias(APessoas[I]);
      if Length(LInconsistenciasRegistro) = 0 then
        Continue;

      Inc(LQuantidadeInvalidos);
      for LInconsistencia in LInconsistenciasRegistro do
        if LDetalhes.Count < MAXIMO_INCONSISTENCIAS_LOTE then
          LDetalhes.Add(Format('Registro %d: %s', [I + 1, LInconsistencia]));
    end;

    if LQuantidadeInvalidos > 0 then
      raise EValidacao.Create(Format('%d registro(s) inválido(s) no lote. Nenhum registro foi gravado.',
        [LQuantidadeInvalidos]), LDetalhes.ToArray);
  finally
    LDetalhes.Free;
  end;
end;

end.
