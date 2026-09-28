unit URepositorioEndereco;

interface

uses
  System.Generics.Collections,
  UPessoa,
  URepositorioBase;

type
  IRepositorioEndereco = interface
    ['{8A1C3E5F-7B9D-4F02-A4C6-E8F0A2B4C6D8}']
    procedure InserirDaPessoa(APessoa: TPessoa);
    procedure SincronizarDaPessoa(APessoa: TPessoa);
    procedure InserirLote(APessoas: TList<TPessoa>);
    procedure CarregarDasPessoas(const APessoas: TArray<TPessoa>);
    function ListarParaIntegracao(ASomentePendentes: Boolean): TObjectList<TEndereco>;
  end;

  TRepositorioEndereco = class(TRepositorioBase, IRepositorioEndereco)
  private const
    TAMANHO_CEP = 15;
  private
    procedure Inserir(AEndereco: TEndereco);
    procedure AtualizarCep(AEndereco: TEndereco);
    procedure Excluir(AIdEndereco: Int64);
    function CepsAtuais(AIdPessoa: Int64): TDictionary<Int64, string>;
  public
    procedure InserirDaPessoa(APessoa: TPessoa);
    procedure SincronizarDaPessoa(APessoa: TPessoa);
    procedure InserirLote(APessoas: TList<TPessoa>);
    procedure CarregarDasPessoas(const APessoas: TArray<TPessoa>);
    function ListarParaIntegracao(ASomentePendentes: Boolean): TObjectList<TEndereco>;
  end;

implementation

uses
  System.SysUtils,
  Data.DB,
  FireDAC.Stan.Param,
  FireDAC.Comp.Client,
  UExcecoes;

procedure TRepositorioEndereco.Inserir(AEndereco: TEndereco);
var
  LQuery: TFDQuery;
begin
  LQuery := CriarQuery('insert into endereco (idpessoa, dscep) values (:idpessoa, :dscep) returning idendereco');
  try
    LQuery.ParamByName('idpessoa').AsLargeInt := AEndereco.IdPessoa;
    LQuery.ParamByName('dscep').AsWideString := AEndereco.Cep;
    LQuery.Open;
    AEndereco.Id := LQuery.Fields[0].AsLargeInt;
  finally
    LQuery.Free;
  end;
end;

procedure TRepositorioEndereco.AtualizarCep(AEndereco: TEndereco);
var
  LQuery: TFDQuery;
begin
  LQuery := CriarQuery('update endereco set dscep = :dscep where idendereco = :idendereco');
  try
    LQuery.ParamByName('dscep').AsWideString := AEndereco.Cep;
    LQuery.ParamByName('idendereco').AsLargeInt := AEndereco.Id;
    LQuery.ExecSQL;
  finally
    LQuery.Free;
  end;

  LQuery := CriarQuery('delete from endereco_integracao where idendereco = :idendereco');
  try
    LQuery.ParamByName('idendereco').AsLargeInt := AEndereco.Id;
    LQuery.ExecSQL;
  finally
    LQuery.Free;
  end;
end;

procedure TRepositorioEndereco.Excluir(AIdEndereco: Int64);
var
  LQuery: TFDQuery;
begin
  LQuery := CriarQuery('delete from endereco where idendereco = :idendereco');
  try
    LQuery.ParamByName('idendereco').AsLargeInt := AIdEndereco;
    LQuery.ExecSQL;
  finally
    LQuery.Free;
  end;
end;

function TRepositorioEndereco.CepsAtuais(AIdPessoa: Int64): TDictionary<Int64, string>;
var
  LQuery: TFDQuery;
begin
  Result := TDictionary<Int64, string>.Create;
  try
    LQuery := CriarQuery('select idendereco, dscep from endereco where idpessoa = :idpessoa');
    try
      LQuery.ParamByName('idpessoa').AsLargeInt := AIdPessoa;
      LQuery.Open;
      while not LQuery.Eof do
      begin
        Result.Add(LQuery.Fields[0].AsLargeInt, LQuery.Fields[1].AsString);
        LQuery.Next;
      end;
    finally
      LQuery.Free;
    end;
  except
    Result.Free;
    raise;
  end;
end;

procedure TRepositorioEndereco.InserirDaPessoa(APessoa: TPessoa);
var
  LEndereco: TEndereco;
begin
  for LEndereco in APessoa.Enderecos do
  begin
    LEndereco.IdPessoa := APessoa.Id;
    Inserir(LEndereco);
  end;
end;

procedure TRepositorioEndereco.SincronizarDaPessoa(APessoa: TPessoa);
var
  LCepsAtuais: TDictionary<Int64, string>;
  LCepAtual: string;
  LEndereco: TEndereco;
  LIdRemovido: Int64;
begin
  LCepsAtuais := CepsAtuais(APessoa.Id);
  try
    for LEndereco in APessoa.Enderecos do
    begin
      LEndereco.IdPessoa := APessoa.Id;
      if LEndereco.EhNova then
      begin
        Inserir(LEndereco);
        Continue;
      end;

      if not LCepsAtuais.TryGetValue(LEndereco.Id, LCepAtual) then
        raise EValidacao.CreateFmt('O endereço %d não pertence à pessoa %d.', [LEndereco.Id, APessoa.Id]);
      if LCepAtual <> LEndereco.Cep then
        AtualizarCep(LEndereco);
      LCepsAtuais.Remove(LEndereco.Id);
    end;

    for LIdRemovido in LCepsAtuais.Keys do
      Excluir(LIdRemovido);
  finally
    LCepsAtuais.Free;
  end;
end;

procedure TRepositorioEndereco.InserirLote(APessoas: TList<TPessoa>);
var
  LEnderecos: TList<TEndereco>;
  LPessoa: TPessoa;
  LEndereco: TEndereco;
  LIds: TArray<Int64>;
  I: Integer;
begin
  LEnderecos := TList<TEndereco>.Create;
  try
    for LPessoa in APessoas do
      for LEndereco in LPessoa.Enderecos do
      begin
        LEndereco.IdPessoa := LPessoa.Id;
        LEnderecos.Add(LEndereco);
      end;

    LIds := ReservarIds('endereco', 'idendereco', LEnderecos.Count);
    for I := 0 to LEnderecos.Count - 1 do
      LEnderecos[I].Id := LIds[I];

    ExecutarEmLote<TEndereco>(
      'insert into endereco (idendereco, idpessoa, dscep) values (:idendereco, :idpessoa, :dscep)',
      LEnderecos,
      procedure(AParametros: TFDParams)
      begin
        AParametros.ParamByName('idendereco').DataType := ftLargeint;
        AParametros.ParamByName('idpessoa').DataType := ftLargeint;
        DefinirParametroTexto(AParametros, 'dscep', TAMANHO_CEP);
      end,
      procedure(AParametros: TFDParams; AIndice: Integer; AEndereco: TEndereco)
      begin
        AParametros.ParamByName('idendereco').AsLargeInts[AIndice] := AEndereco.Id;
        AParametros.ParamByName('idpessoa').AsLargeInts[AIndice] := AEndereco.IdPessoa;
        AParametros.ParamByName('dscep').AsWideStrings[AIndice] := AEndereco.Cep;
      end);
  finally
    LEnderecos.Free;
  end;
end;

procedure TRepositorioEndereco.CarregarDasPessoas(const APessoas: TArray<TPessoa>);
var
  LPessoasPorId: TDictionary<Int64, TPessoa>;
  LIds: TStringBuilder;
  LPessoa: TPessoa;
  LEndereco: TEndereco;
  LIntegracao: TEnderecoIntegracao;
  LQuery: TFDQuery;
begin
  if Length(APessoas) = 0 then
    Exit;

  LPessoasPorId := TDictionary<Int64, TPessoa>.Create;
  LIds := TStringBuilder.Create;
  try
    for LPessoa in APessoas do
    begin
      LPessoa.Enderecos.Clear;
      LPessoasPorId.AddOrSetValue(LPessoa.Id, LPessoa);
      if LIds.Length > 0 then
        LIds.Append(',');
      LIds.Append(LPessoa.Id);
    end;

    LQuery := CriarQuery(
      'select e.idendereco, e.idpessoa, e.dscep, i.idendereco as idintegracao, ' +
      '       i.dsuf, i.nmcidade, i.nmbairro, i.nmlogradouro, i.dscomplemento ' +
      'from endereco e ' +
      'left join endereco_integracao i on i.idendereco = e.idendereco ' +
      'where e.idpessoa = any(cast(string_to_array(:ids, '','') as bigint[])) ' +
      'order by e.idpessoa, e.idendereco');
    try
      LQuery.ParamByName('ids').DataType := ftWideMemo;
      LQuery.ParamByName('ids').AsWideMemo := LIds.ToString;
      LQuery.Open;
      while not LQuery.Eof do
      begin
        LPessoa := LPessoasPorId[LQuery.FieldByName('idpessoa').AsLargeInt];
        LEndereco := LPessoa.AdicionarEndereco(LQuery.FieldByName('dscep').AsString,
          LQuery.FieldByName('idendereco').AsLargeInt);
        if not LQuery.FieldByName('idintegracao').IsNull then
        begin
          LIntegracao := TEnderecoIntegracao.Create;
          LIntegracao.Uf := LQuery.FieldByName('dsuf').AsString;
          LIntegracao.Cidade := LQuery.FieldByName('nmcidade').AsString;
          LIntegracao.Bairro := LQuery.FieldByName('nmbairro').AsString;
          LIntegracao.Logradouro := LQuery.FieldByName('nmlogradouro').AsString;
          LIntegracao.Complemento := LQuery.FieldByName('dscomplemento').AsString;
          LEndereco.Integracao := LIntegracao;
        end;
        LQuery.Next;
      end;
    finally
      LQuery.Free;
    end;
  finally
    LIds.Free;
    LPessoasPorId.Free;
  end;
end;

function TRepositorioEndereco.ListarParaIntegracao(ASomentePendentes: Boolean): TObjectList<TEndereco>;
const
  SQL_BASE = 'select e.idendereco, e.idpessoa, e.dscep from endereco e where coalesce(e.dscep, '''') <> ''''';
  FILTRO_PENDENTES = ' and not exists (select 1 from endereco_integracao i where i.idendereco = e.idendereco)';
var
  LQuery: TFDQuery;
  LEndereco: TEndereco;
  LSql: string;
begin
  LSql := SQL_BASE;
  if ASomentePendentes then
    LSql := LSql + FILTRO_PENDENTES;

  Result := TObjectList<TEndereco>.Create(True);
  try
    LQuery := CriarQuery(LSql + ' order by e.dscep');
    try
      LQuery.FetchOptions.Unidirectional := True;
      LQuery.Open;
      while not LQuery.Eof do
      begin
        LEndereco := TEndereco.Create;
        Result.Add(LEndereco);
        LEndereco.Id := LQuery.Fields[0].AsLargeInt;
        LEndereco.IdPessoa := LQuery.Fields[1].AsLargeInt;
        LEndereco.Cep := LQuery.Fields[2].AsString;
        LQuery.Next;
      end;
    finally
      LQuery.Free;
    end;
  except
    Result.Free;
    raise;
  end;
end;

end.
