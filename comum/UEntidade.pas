unit UEntidade;

interface

type
  TEntidade = class abstract
  private
    FId: Int64;
  public
    function EhNova: Boolean;
    property Id: Int64 read FId write FId;
  end;

implementation

function TEntidade.EhNova: Boolean;
begin
  Result := FId <= 0;
end;

end.
