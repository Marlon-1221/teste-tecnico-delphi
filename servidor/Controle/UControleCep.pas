unit UControleCep;

interface

uses
  URoteador,
  UrotAtualizacaoCep;

type
  TControleCep = class(TInterfacedObject, IControle)
  private const
    STATUS_OK = 200;
    STATUS_ACEITO = 202;
  private
    FServico: IRegraAtualizacaoCep;
    procedure Iniciar(ARequisicao: TRequisicao; AResposta: TResposta);
    procedure ObterStatus(ARequisicao: TRequisicao; AResposta: TResposta);
    procedure ResponderStatus(AStatusHttp: Integer; AResposta: TResposta);
  public
    constructor Create(const AServico: IRegraAtualizacaoCep);
    procedure RegistrarRotas(ARoteador: TRoteador);
  end;

implementation

uses
  UStatusCep,
  UConversorJson;

constructor TControleCep.Create(const AServico: IRegraAtualizacaoCep);
begin
  inherited Create;
  FServico := AServico;
end;

procedure TControleCep.RegistrarRotas(ARoteador: TRoteador);
begin
  ARoteador.Registrar(mhPost, '/enderecos/atualizacao-cep', Iniciar);
  ARoteador.Registrar(mhGet, '/enderecos/atualizacao-cep', ObterStatus);
end;

procedure TControleCep.ResponderStatus(AStatusHttp: Integer; AResposta: TResposta);
var
  LStatus: TStatusAtualizacaoCep;
begin
  LStatus := FServico.ObterStatus;
  try
    AResposta.EnviarJson(AStatusHttp, TStatusAtualizacaoCepJson.ParaJson(LStatus));
  finally
    LStatus.Free;
  end;
end;

procedure TControleCep.Iniciar(ARequisicao: TRequisicao; AResposta: TResposta);
begin
  FServico.Iniciar(ARequisicao.QueryBooleano('somentePendentes', True));
  ResponderStatus(STATUS_ACEITO, AResposta);
end;

procedure TControleCep.ObterStatus(ARequisicao: TRequisicao; AResposta: TResposta);
begin
  ResponderStatus(STATUS_OK, AResposta);
end;

end.
