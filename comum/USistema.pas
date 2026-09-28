unit USistema;

interface

type
  TInformacoesBanco = record
    Versao: string;
    Servidor: string;
    Porta: Integer;
    Banco: string;
    function Descricao: string;
  end;

implementation

uses
  System.SysUtils;

function TInformacoesBanco.Descricao: string;
begin
  Result := Format('PostgreSQL %s  |  %s:%d/%s', [Versao, Servidor, Porta, Banco]);
end;

end.
