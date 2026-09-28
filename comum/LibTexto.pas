unit LibTexto;

interface

type
  TTexto = class abstract
  public
    class function SomenteDigitos(const AValor: string): string; static;
    class function Limitar(const AValor: string; ATamanho: Integer): string; static;
    class function FormatarDocumento(const ADocumento: string): string; static;
    class function FormatarCep(const ACep: string): string; static;
  end;

implementation

uses
  System.SysUtils;

class function TTexto.SomenteDigitos(const AValor: string): string;
var
  LCaractere: Char;
  LBuilder: TStringBuilder;
begin
  LBuilder := TStringBuilder.Create(Length(AValor));
  try
    for LCaractere in AValor do
      if CharInSet(LCaractere, ['0'..'9']) then
        LBuilder.Append(LCaractere);
    Result := LBuilder.ToString;
  finally
    LBuilder.Free;
  end;
end;

class function TTexto.Limitar(const AValor: string; ATamanho: Integer): string;
begin
  Result := Copy(Trim(AValor), 1, ATamanho);
end;

class function TTexto.FormatarDocumento(const ADocumento: string): string;
begin
  case Length(ADocumento) of
    11:
      Result := Format('%s.%s.%s-%s', [Copy(ADocumento, 1, 3), Copy(ADocumento, 4, 3),
        Copy(ADocumento, 7, 3), Copy(ADocumento, 10, 2)]);
    14:
      Result := Format('%s.%s.%s/%s-%s', [Copy(ADocumento, 1, 2), Copy(ADocumento, 3, 3),
        Copy(ADocumento, 6, 3), Copy(ADocumento, 9, 4), Copy(ADocumento, 13, 2)]);
  else
    Result := ADocumento;
  end;
end;

class function TTexto.FormatarCep(const ACep: string): string;
begin
  if Length(ACep) = 8 then
    Result := Copy(ACep, 1, 5) + '-' + Copy(ACep, 6, 3)
  else
    Result := ACep;
end;

end.
