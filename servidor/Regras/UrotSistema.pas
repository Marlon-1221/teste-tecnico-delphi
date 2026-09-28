unit UrotSistema;

interface

uses
  USistema,
  UUnidadeTrabalho;

type
  IRegraSistema = interface
    ['{4A6C8E0F-2B3D-4F5A-8C7E-9D1B3F5A7C9E}']
    function InformacoesBanco: TInformacoesBanco;
  end;

  TRegraSistema = class(TInterfacedObject, IRegraSistema)
  private
    FFabricaUnidadeTrabalho: IFabricaUnidadeTrabalho;
    FServidorBanco: string;
    FPortaBanco: Integer;
  public
    constructor Create(const AFabricaUnidadeTrabalho: IFabricaUnidadeTrabalho; const AServidorBanco: string;
      APortaBanco: Integer);
    function InformacoesBanco: TInformacoesBanco;
  end;

implementation

constructor TRegraSistema.Create(const AFabricaUnidadeTrabalho: IFabricaUnidadeTrabalho;
  const AServidorBanco: string; APortaBanco: Integer);
begin
  inherited Create;
  FFabricaUnidadeTrabalho := AFabricaUnidadeTrabalho;
  FServidorBanco := AServidorBanco;
  FPortaBanco := APortaBanco;
end;

function TRegraSistema.InformacoesBanco: TInformacoesBanco;
var
  LUnidade: IUnidadeTrabalho;
begin
  LUnidade := FFabricaUnidadeTrabalho.Criar;
  Result := LUnidade.Sistema.InformacoesBanco;
  Result.Servidor := FServidorBanco;
  Result.Porta := FPortaBanco;
end;

end.
