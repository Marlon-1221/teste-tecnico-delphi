unit URepositorioSistema;

interface

uses
  URepositorioBase,
  USistema;

type
  IRepositorioSistema = interface
    ['{2E4A6C8D-0F1B-4D3E-9A5C-7B9D1F3A5C7E}']
    function InformacoesBanco: TInformacoesBanco;
  end;

  TRepositorioSistema = class(TRepositorioBase, IRepositorioSistema)
  public
    function InformacoesBanco: TInformacoesBanco;
  end;

implementation

uses
  FireDAC.Comp.Client;

function TRepositorioSistema.InformacoesBanco: TInformacoesBanco;
var
  LQuery: TFDQuery;
begin
  LQuery := CriarQuery('select current_setting(''server_version'') as versao, current_database() as banco');
  try
    LQuery.Open;
    Result.Versao := LQuery.FieldByName('versao').AsString;
    Result.Banco := LQuery.FieldByName('banco').AsString;
  finally
    LQuery.Free;
  end;
end;

end.
