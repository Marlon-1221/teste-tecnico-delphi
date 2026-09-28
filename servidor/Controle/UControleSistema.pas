unit UControleSistema;

interface

uses
  URoteador,
  UrotSistema;

type
  TControleSistema = class(TInterfacedObject, IControle)
  private const
    STATUS_OK = 200;
  private
    FRegra: IRegraSistema;
    procedure ObterInformacoes(ARequisicao: TRequisicao; AResposta: TResposta);
  public
    constructor Create(const ARegra: IRegraSistema);
    procedure RegistrarRotas(ARoteador: TRoteador);
  end;

implementation

uses
  UConversorJson;

constructor TControleSistema.Create(const ARegra: IRegraSistema);
begin
  inherited Create;
  FRegra := ARegra;
end;

procedure TControleSistema.RegistrarRotas(ARoteador: TRoteador);
begin
  ARoteador.Registrar(mhGet, '/sistema', ObterInformacoes);
end;

procedure TControleSistema.ObterInformacoes(ARequisicao: TRequisicao; AResposta: TResposta);
begin
  AResposta.EnviarJson(STATUS_OK, TInformacoesBancoJson.ParaJson(FRegra.InformacoesBanco));
end;

end.
