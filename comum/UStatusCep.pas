unit UStatusCep;

interface

type
  TStatusAtualizacaoCep = class
  private
    FEmExecucao: Boolean;
    FSomentePendentes: Boolean;
    FTotalEnderecos: Integer;
    FTotalCeps: Integer;
    FCepsProcessados: Integer;
    FEnderecosAtualizados: Integer;
    FCepsNaoEncontrados: Integer;
    FFalhas: Integer;
    FInicio: TDateTime;
    FFim: TDateTime;
    FUltimoErro: string;
  public
    procedure CopiarDe(AOrigem: TStatusAtualizacaoCep);
    function PercentualConcluido: Integer;
    property EmExecucao: Boolean read FEmExecucao write FEmExecucao;
    property SomentePendentes: Boolean read FSomentePendentes write FSomentePendentes;
    property TotalEnderecos: Integer read FTotalEnderecos write FTotalEnderecos;
    property TotalCeps: Integer read FTotalCeps write FTotalCeps;
    property CepsProcessados: Integer read FCepsProcessados write FCepsProcessados;
    property EnderecosAtualizados: Integer read FEnderecosAtualizados write FEnderecosAtualizados;
    property CepsNaoEncontrados: Integer read FCepsNaoEncontrados write FCepsNaoEncontrados;
    property Falhas: Integer read FFalhas write FFalhas;
    property Inicio: TDateTime read FInicio write FInicio;
    property Fim: TDateTime read FFim write FFim;
    property UltimoErro: string read FUltimoErro write FUltimoErro;
  end;

implementation

procedure TStatusAtualizacaoCep.CopiarDe(AOrigem: TStatusAtualizacaoCep);
begin
  FEmExecucao := AOrigem.EmExecucao;
  FSomentePendentes := AOrigem.SomentePendentes;
  FTotalEnderecos := AOrigem.TotalEnderecos;
  FTotalCeps := AOrigem.TotalCeps;
  FCepsProcessados := AOrigem.CepsProcessados;
  FEnderecosAtualizados := AOrigem.EnderecosAtualizados;
  FCepsNaoEncontrados := AOrigem.CepsNaoEncontrados;
  FFalhas := AOrigem.Falhas;
  FInicio := AOrigem.Inicio;
  FFim := AOrigem.Fim;
  FUltimoErro := AOrigem.UltimoErro;
end;

function TStatusAtualizacaoCep.PercentualConcluido: Integer;
begin
  if FTotalCeps > 0 then
    Result := Round(FCepsProcessados * 100 / FTotalCeps)
  else if (not FEmExecucao) and (FFim > 0) then
    Result := 100
  else
    Result := 0;
end;

end.
