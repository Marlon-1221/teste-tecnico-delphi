unit URepositorioIntegracao;

interface

uses
  UPessoa,
  URepositorioBase;

type
  IRepositorioIntegracao = interface
    ['{C4E6A8B0-2D4F-4618-9A3C-5E7F9B1D3F52}']
    procedure Salvar(const AIdsEnderecos: TArray<Int64>; AIntegracao: TEnderecoIntegracao);
  end;

  TRepositorioIntegracao = class(TRepositorioBase, IRepositorioIntegracao)
  private const
    TAMANHO_UF = 50;
    TAMANHO_CIDADE = 100;
    TAMANHO_BAIRRO = 50;
    TAMANHO_LOGRADOURO = 100;
    TAMANHO_COMPLEMENTO = 100;
  public
    procedure Salvar(const AIdsEnderecos: TArray<Int64>; AIntegracao: TEnderecoIntegracao);
  end;

implementation

uses
  System.SysUtils,
  System.Generics.Collections,
  Data.DB,
  FireDAC.Stan.Param,
  LibTexto;

procedure TRepositorioIntegracao.Salvar(const AIdsEnderecos: TArray<Int64>;
  AIntegracao: TEnderecoIntegracao);
var
  LIds: TList<Int64>;
  LUf, LCidade, LBairro, LLogradouro, LComplemento: string;
begin
  LUf := TTexto.Limitar(AIntegracao.Uf, TAMANHO_UF);
  LCidade := TTexto.Limitar(AIntegracao.Cidade, TAMANHO_CIDADE);
  LBairro := TTexto.Limitar(AIntegracao.Bairro, TAMANHO_BAIRRO);
  LLogradouro := TTexto.Limitar(AIntegracao.Logradouro, TAMANHO_LOGRADOURO);
  LComplemento := TTexto.Limitar(AIntegracao.Complemento, TAMANHO_COMPLEMENTO);

  LIds := TList<Int64>.Create;
  try
    LIds.AddRange(AIdsEnderecos);
    ExecutarEmLote<Int64>(
      'insert into endereco_integracao (idendereco, dsuf, nmcidade, nmbairro, nmlogradouro, dscomplemento) ' +
      'select e.idendereco, :dsuf, :nmcidade, :nmbairro, :nmlogradouro, :dscomplemento ' +
      'from endereco e where e.idendereco = :idendereco ' +
      'on conflict (idendereco) do update set ' +
      '  dsuf = excluded.dsuf, nmcidade = excluded.nmcidade, nmbairro = excluded.nmbairro, ' +
      '  nmlogradouro = excluded.nmlogradouro, dscomplemento = excluded.dscomplemento',
      LIds,
      procedure(AParametros: TFDParams)
      begin
        AParametros.ParamByName('idendereco').DataType := ftLargeint;
        DefinirParametroTexto(AParametros, 'dsuf', TAMANHO_UF);
        DefinirParametroTexto(AParametros, 'nmcidade', TAMANHO_CIDADE);
        DefinirParametroTexto(AParametros, 'nmbairro', TAMANHO_BAIRRO);
        DefinirParametroTexto(AParametros, 'nmlogradouro', TAMANHO_LOGRADOURO);
        DefinirParametroTexto(AParametros, 'dscomplemento', TAMANHO_COMPLEMENTO);
      end,
      procedure(AParametros: TFDParams; AIndice: Integer; AIdEndereco: Int64)
      begin
        AParametros.ParamByName('idendereco').AsLargeInts[AIndice] := AIdEndereco;
        AParametros.ParamByName('dsuf').AsWideStrings[AIndice] := LUf;
        AParametros.ParamByName('nmcidade').AsWideStrings[AIndice] := LCidade;
        AParametros.ParamByName('nmbairro').AsWideStrings[AIndice] := LBairro;
        AParametros.ParamByName('nmlogradouro').AsWideStrings[AIndice] := LLogradouro;
        AParametros.ParamByName('dscomplemento').AsWideStrings[AIndice] := LComplemento;
      end);
  finally
    LIds.Free;
  end;
end;

end.
