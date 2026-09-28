unit URepositorioBase;

interface

uses
  System.SysUtils,
  System.Generics.Collections,
  FireDAC.Stan.Param,
  FireDAC.Comp.Client;

type
  TPreenchimentoLote<T> = reference to procedure(AParametros: TFDParams; AIndice: Integer; AItem: T);

  TRepositorioBase = class abstract(TInterfacedObject)
  private const
    TAMANHO_BLOCO_LOTE = 5000;
  private
    FConexao: TFDConnection;
  protected
    function CriarQuery(const ASql: string): TFDQuery;
    function ReservarIds(const ATabela, AColuna: string; AQuantidade: Integer): TArray<Int64>;
    procedure ExecutarEmLote<T>(const ASql: string; AItens: TList<T>; const AConfigurar: TProc<TFDParams>;
      const APreencher: TPreenchimentoLote<T>);
    class procedure DefinirParametroTexto(AParametros: TFDParams; const ANome: string; ATamanho: Integer); static;
    property Conexao: TFDConnection read FConexao;
  public
    constructor Create(AConexao: TFDConnection);
  end;

implementation

uses
  System.Math,
  Data.DB,
  FireDAC.Stan.Option;

constructor TRepositorioBase.Create(AConexao: TFDConnection);
begin
  inherited Create;
  FConexao := AConexao;
end;

function TRepositorioBase.CriarQuery(const ASql: string): TFDQuery;
begin
  Result := TFDQuery.Create(nil);
  try
    Result.Connection := FConexao;
    Result.SQL.Text := ASql;
  except
    Result.Free;
    raise;
  end;
end;

function TRepositorioBase.ReservarIds(const ATabela, AColuna: string; AQuantidade: Integer): TArray<Int64>;
var
  LQuery: TFDQuery;
  I: Integer;
begin
  SetLength(Result, AQuantidade);
  if AQuantidade = 0 then
    Exit;

  LQuery := CriarQuery(
    'select nextval(pg_get_serial_sequence(:tabela, :coluna)) as id ' +
    'from generate_series(1, :quantidade)');
  try
    LQuery.FetchOptions.Unidirectional := True;
    LQuery.FetchOptions.RowsetSize := TAMANHO_BLOCO_LOTE;
    LQuery.ParamByName('tabela').AsWideString := ATabela;
    LQuery.ParamByName('coluna').AsWideString := AColuna;
    LQuery.ParamByName('quantidade').AsInteger := AQuantidade;
    LQuery.Open;
    I := 0;
    while not LQuery.Eof do
    begin
      Result[I] := LQuery.Fields[0].AsLargeInt;
      Inc(I);
      LQuery.Next;
    end;
  finally
    LQuery.Free;
  end;
end;

procedure TRepositorioBase.ExecutarEmLote<T>(const ASql: string; AItens: TList<T>;
  const AConfigurar: TProc<TFDParams>; const APreencher: TPreenchimentoLote<T>);
var
  LQuery: TFDQuery;
  LInicio, LQuantidade, I: Integer;
begin
  if AItens.Count = 0 then
    Exit;

  LQuery := CriarQuery(ASql);
  try
    if Assigned(AConfigurar) then
      AConfigurar(LQuery.Params);
    LQuery.Params.ArraySize := Min(TAMANHO_BLOCO_LOTE, AItens.Count);

    LInicio := 0;
    while LInicio < AItens.Count do
    begin
      LQuantidade := Min(LQuery.Params.ArraySize, AItens.Count - LInicio);
      for I := 0 to LQuantidade - 1 do
        APreencher(LQuery.Params, I, AItens[LInicio + I]);
      LQuery.Execute(LQuantidade, 0);
      Inc(LInicio, LQuantidade);
    end;
  finally
    LQuery.Free;
  end;
end;

class procedure TRepositorioBase.DefinirParametroTexto(AParametros: TFDParams; const ANome: string;
  ATamanho: Integer);
var
  LParametro: TFDParam;
begin
  LParametro := AParametros.ParamByName(ANome);
  LParametro.DataType := ftWideString;
  LParametro.Size := ATamanho;
end;

end.
