unit UPagina;

interface

uses
  System.Generics.Collections;

type
  TPagina<T: class> = class
  private
    FItens: TObjectList<T>;
    FNumero: Integer;
    FTamanho: Integer;
    FTotalRegistros: Int64;
  public
    constructor Create(ANumero, ATamanho: Integer);
    destructor Destroy; override;
    function TotalPaginas: Integer;
    property Itens: TObjectList<T> read FItens;
    property Numero: Integer read FNumero;
    property Tamanho: Integer read FTamanho;
    property TotalRegistros: Int64 read FTotalRegistros write FTotalRegistros;
  end;

implementation

constructor TPagina<T>.Create(ANumero, ATamanho: Integer);
begin
  inherited Create;
  FItens := TObjectList<T>.Create(True);
  FNumero := ANumero;
  FTamanho := ATamanho;
end;

destructor TPagina<T>.Destroy;
begin
  FItens.Free;
  inherited;
end;

function TPagina<T>.TotalPaginas: Integer;
begin
  if FTamanho <= 0 then
    Exit(0);
  Result := Integer((FTotalRegistros + FTamanho - 1) div FTamanho);
end;

end.
