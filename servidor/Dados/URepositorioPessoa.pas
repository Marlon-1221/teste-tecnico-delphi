unit URepositorioPessoa;

interface

uses
  System.Generics.Collections,
  Data.DB,
  FireDAC.Comp.Client,
  UPessoa,
  URepositorioBase;

type
  IRepositorioPessoa = interface
    ['{5E8B2A71-C3D4-4F96-8A1B-2C3D4E5F6A70}']
    function BuscarPorId(AId: Int64): TPessoa;
    procedure Listar(ADeslocamento, ALimite: Integer; ADestino: TList<TPessoa>; const ABusca: string = '');
    function Contar(const ABusca: string = ''): Int64;
    procedure Inserir(APessoa: TPessoa);
    function Atualizar(APessoa: TPessoa): Boolean;
    function Excluir(AId: Int64): Boolean;
    procedure InserirLote(APessoas: TList<TPessoa>);
    function DocumentosCadastrados(const ADocumentos: TArray<string>; AIgnorarId: Int64 = 0): TDictionary<string, Int64>;
  end;

  TRepositorioPessoa = class(TRepositorioBase, IRepositorioPessoa)
  private const
    SQL_SELECT = 'select p.idpessoa, p.flnatureza, p.dsdocumento, p.nmprimeiro, p.nmsegundo, p.dtregistro from pessoa p';
    TAMANHO_DOCUMENTO = 20;
    TAMANHO_NOME = 100;
  private
    function CriarPessoa(ADados: TDataSet): TPessoa;
    class function MontarFiltro(const ABusca: string; out ATexto, ADigitos: string): string; static;
    class procedure AplicarFiltro(AQuery: TFDQuery; const ATexto, ADigitos: string); static;
  public
    function BuscarPorId(AId: Int64): TPessoa;
    procedure Listar(ADeslocamento, ALimite: Integer; ADestino: TList<TPessoa>; const ABusca: string = '');
    function Contar(const ABusca: string = ''): Int64;
    procedure Inserir(APessoa: TPessoa);
    function Atualizar(APessoa: TPessoa): Boolean;
    function Excluir(AId: Int64): Boolean;
    procedure InserirLote(APessoas: TList<TPessoa>);
    function DocumentosCadastrados(const ADocumentos: TArray<string>; AIgnorarId: Int64 = 0): TDictionary<string, Int64>;
  end;

implementation

uses
  System.SysUtils,
  System.RegularExpressions,
  FireDAC.Stan.Param,
  LibTexto;

function TRepositorioPessoa.CriarPessoa(ADados: TDataSet): TPessoa;
begin
  Result := TPessoa.Create;
  try
    Result.Id := ADados.FieldByName('idpessoa').AsLargeInt;
    Result.Natureza := TNaturezaPessoa.DeInteiro(ADados.FieldByName('flnatureza').AsInteger);
    Result.Documento := ADados.FieldByName('dsdocumento').AsString;
    Result.PrimeiroNome := ADados.FieldByName('nmprimeiro').AsString;
    Result.SegundoNome := ADados.FieldByName('nmsegundo').AsString;
    if not ADados.FieldByName('dtregistro').IsNull then
      Result.DataRegistro := ADados.FieldByName('dtregistro').AsDateTime;
  except
    Result.Free;
    raise;
  end;
end;

function TRepositorioPessoa.BuscarPorId(AId: Int64): TPessoa;
var
  LQuery: TFDQuery;
begin
  Result := nil;
  LQuery := CriarQuery(SQL_SELECT + ' where p.idpessoa = :idpessoa');
  try
    LQuery.ParamByName('idpessoa').AsLargeInt := AId;
    LQuery.Open;
    if not LQuery.IsEmpty then
      Result := CriarPessoa(LQuery);
  finally
    LQuery.Free;
  end;
end;

class function TRepositorioPessoa.MontarFiltro(const ABusca: string; out ATexto, ADigitos: string): string;
var
  LBusca: string;
begin
  ATexto := '';
  ADigitos := '';
  Result := '';
  LBusca := Trim(ABusca);
  if LBusca = '' then
    Exit;

  if TRegEx.IsMatch(LBusca, '^[\d\.\-/\s]+$') then
  begin
    ADigitos := TTexto.SomenteDigitos(LBusca) + '%';
    Result := ' where (p.dsdocumento like :digitos or exists (select 1 from endereco e ' +
      'where e.idpessoa = p.idpessoa and e.dscep like :digitos))';
  end
  else
  begin
    ATexto := '%' + LBusca.Replace('\', '\\').Replace('%', '\%').Replace('_', '\_') + '%';
    Result := ' where (p.nmprimeiro ilike :texto or p.nmsegundo ilike :texto or exists (select 1 from endereco e ' +
      'join endereco_integracao i on i.idendereco = e.idendereco ' +
      'where e.idpessoa = p.idpessoa and i.nmcidade ilike :texto))';
  end;
end;

class procedure TRepositorioPessoa.AplicarFiltro(AQuery: TFDQuery; const ATexto, ADigitos: string);
begin
  if ATexto <> '' then
    AQuery.ParamByName('texto').AsWideString := ATexto;
  if ADigitos <> '' then
    AQuery.ParamByName('digitos').AsWideString := ADigitos;
end;

procedure TRepositorioPessoa.Listar(ADeslocamento, ALimite: Integer; ADestino: TList<TPessoa>; const ABusca: string);
var
  LQuery: TFDQuery;
  LFiltro, LTexto, LDigitos: string;
begin
  LFiltro := MontarFiltro(ABusca, LTexto, LDigitos);
  LQuery := CriarQuery(SQL_SELECT + LFiltro + ' order by p.idpessoa limit :limite offset :deslocamento');
  try
    AplicarFiltro(LQuery, LTexto, LDigitos);
    LQuery.ParamByName('limite').AsInteger := ALimite;
    LQuery.ParamByName('deslocamento').AsInteger := ADeslocamento;
    LQuery.Open;
    while not LQuery.Eof do
    begin
      ADestino.Add(CriarPessoa(LQuery));
      LQuery.Next;
    end;
  finally
    LQuery.Free;
  end;
end;

function TRepositorioPessoa.Contar(const ABusca: string): Int64;
var
  LQuery: TFDQuery;
  LFiltro, LTexto, LDigitos: string;
begin
  LFiltro := MontarFiltro(ABusca, LTexto, LDigitos);
  LQuery := CriarQuery('select count(*) from pessoa p' + LFiltro);
  try
    AplicarFiltro(LQuery, LTexto, LDigitos);
    LQuery.Open;
    Result := LQuery.Fields[0].AsLargeInt;
  finally
    LQuery.Free;
  end;
end;

procedure TRepositorioPessoa.Inserir(APessoa: TPessoa);
var
  LQuery: TFDQuery;
begin
  LQuery := CriarQuery(
    'insert into pessoa (flnatureza, dsdocumento, nmprimeiro, nmsegundo, dtregistro) ' +
    'values (:flnatureza, :dsdocumento, :nmprimeiro, :nmsegundo, :dtregistro) ' +
    'returning idpessoa');
  try
    LQuery.ParamByName('flnatureza').AsSmallInt := APessoa.Natureza.ParaInteiro;
    LQuery.ParamByName('dsdocumento').AsWideString := APessoa.Documento;
    LQuery.ParamByName('nmprimeiro').AsWideString := APessoa.PrimeiroNome;
    LQuery.ParamByName('nmsegundo').AsWideString := APessoa.SegundoNome;
    LQuery.ParamByName('dtregistro').DataType := ftDate;
    if APessoa.PossuiDataRegistro then
      LQuery.ParamByName('dtregistro').AsDate := APessoa.DataRegistro
    else
      LQuery.ParamByName('dtregistro').Clear;
    LQuery.Open;
    APessoa.Id := LQuery.Fields[0].AsLargeInt;
  finally
    LQuery.Free;
  end;
end;

function TRepositorioPessoa.Atualizar(APessoa: TPessoa): Boolean;
var
  LQuery: TFDQuery;
begin
  LQuery := CriarQuery(
    'update pessoa set flnatureza = :flnatureza, dsdocumento = :dsdocumento, ' +
    'nmprimeiro = :nmprimeiro, nmsegundo = :nmsegundo ' +
    'where idpessoa = :idpessoa');
  try
    LQuery.ParamByName('flnatureza').AsSmallInt := APessoa.Natureza.ParaInteiro;
    LQuery.ParamByName('dsdocumento').AsWideString := APessoa.Documento;
    LQuery.ParamByName('nmprimeiro').AsWideString := APessoa.PrimeiroNome;
    LQuery.ParamByName('nmsegundo').AsWideString := APessoa.SegundoNome;
    LQuery.ParamByName('idpessoa').AsLargeInt := APessoa.Id;
    LQuery.ExecSQL;
    Result := LQuery.RowsAffected > 0;
  finally
    LQuery.Free;
  end;
end;

function TRepositorioPessoa.Excluir(AId: Int64): Boolean;
var
  LQuery: TFDQuery;
begin
  LQuery := CriarQuery('delete from pessoa where idpessoa = :idpessoa');
  try
    LQuery.ParamByName('idpessoa').AsLargeInt := AId;
    LQuery.ExecSQL;
    Result := LQuery.RowsAffected > 0;
  finally
    LQuery.Free;
  end;
end;

procedure TRepositorioPessoa.InserirLote(APessoas: TList<TPessoa>);
var
  LIds: TArray<Int64>;
  I: Integer;
begin
  LIds := ReservarIds('pessoa', 'idpessoa', APessoas.Count);
  for I := 0 to APessoas.Count - 1 do
    APessoas[I].Id := LIds[I];

  ExecutarEmLote<TPessoa>(
    'insert into pessoa (idpessoa, flnatureza, dsdocumento, nmprimeiro, nmsegundo, dtregistro) ' +
    'values (:idpessoa, :flnatureza, :dsdocumento, :nmprimeiro, :nmsegundo, :dtregistro)',
    APessoas,
    procedure(AParametros: TFDParams)
    begin
      AParametros.ParamByName('idpessoa').DataType := ftLargeint;
      AParametros.ParamByName('flnatureza').DataType := ftSmallint;
      DefinirParametroTexto(AParametros, 'dsdocumento', TAMANHO_DOCUMENTO);
      DefinirParametroTexto(AParametros, 'nmprimeiro', TAMANHO_NOME);
      DefinirParametroTexto(AParametros, 'nmsegundo', TAMANHO_NOME);
      AParametros.ParamByName('dtregistro').DataType := ftDate;
    end,
    procedure(AParametros: TFDParams; AIndice: Integer; APessoa: TPessoa)
    begin
      AParametros.ParamByName('idpessoa').AsLargeInts[AIndice] := APessoa.Id;
      AParametros.ParamByName('flnatureza').AsSmallInts[AIndice] := APessoa.Natureza.ParaInteiro;
      AParametros.ParamByName('dsdocumento').AsWideStrings[AIndice] := APessoa.Documento;
      AParametros.ParamByName('nmprimeiro').AsWideStrings[AIndice] := APessoa.PrimeiroNome;
      AParametros.ParamByName('nmsegundo').AsWideStrings[AIndice] := APessoa.SegundoNome;
      AParametros.ParamByName('dtregistro').AsDates[AIndice] := APessoa.DataRegistro;
    end);
end;

function TRepositorioPessoa.DocumentosCadastrados(const ADocumentos: TArray<string>;
  AIgnorarId: Int64): TDictionary<string, Int64>;
var
  LQuery: TFDQuery;
begin
  Result := TDictionary<string, Int64>.Create;
  try
    if Length(ADocumentos) = 0 then
      Exit;
    LQuery := CriarQuery(
      'select p.dsdocumento, min(p.idpessoa) as idpessoa ' +
      'from pessoa p ' +
      'join unnest(cast(string_to_array(:documentos, '','') as varchar[])) as d(documento) ' +
      '  on d.documento = p.dsdocumento ' +
      'where p.idpessoa <> :ignorar ' +
      'group by p.dsdocumento');
    try
      LQuery.ParamByName('documentos').DataType := ftWideMemo;
      LQuery.ParamByName('documentos').AsWideMemo := string.Join(',', ADocumentos);
      LQuery.ParamByName('ignorar').AsLargeInt := AIgnorarId;
      LQuery.Open;
      while not LQuery.Eof do
      begin
        Result.AddOrSetValue(LQuery.FieldByName('dsdocumento').AsString, LQuery.FieldByName('idpessoa').AsLargeInt);
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
