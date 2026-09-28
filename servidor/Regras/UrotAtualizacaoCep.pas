unit UrotAtualizacaoCep;

interface

uses
  System.SysUtils,
  System.Classes,
  System.SyncObjs,
  System.Generics.Collections,
  UStatusCep,
  UUnidadeTrabalho,
  UViaCep;

type
  IRegraAtualizacaoCep = interface
    ['{C7D9E1F3-A5B7-4C9D-8E1F-5A7B9C1D3E5F}']
    procedure Iniciar(ASomentePendentes: Boolean);
    function ObterStatus: TStatusAtualizacaoCep;
  end;

  TProgressoAtualizacaoCep = class
  private
    FStatus: TStatusAtualizacaoCep;
    FCancelado: Boolean;
    FTrava: TCriticalSection;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Reiniciar(ASomentePendentes: Boolean);
    procedure DefinirTotais(ATotalEnderecos, ATotalCeps: Integer);
    procedure RegistrarSucesso(AQuantidadeEnderecos: Integer);
    procedure RegistrarCepNaoEncontrado;
    procedure RegistrarFalha(const AMensagem: string);
    procedure Finalizar;
    procedure Cancelar;
    function Cancelado: Boolean;
    function EmExecucao: Boolean;
    function Fotografia: TStatusAtualizacaoCep;
  end;

  TItemAtualizacaoCep = record
    Cep: string;
    IdsEnderecos: TArray<Int64>;
    function EhSentinela: Boolean;
    class function Sentinela: TItemAtualizacaoCep; static;
  end;

  TFilaAtualizacaoCep = TThreadedQueue<TItemAtualizacaoCep>;

  TTrabalhadorCep = class(TThread)
  private
    FFila: TFilaAtualizacaoCep;
    FFabricaUnidadeTrabalho: IFabricaUnidadeTrabalho;
    FConsultaCep: IConsultaCep;
    FProgresso: TProgressoAtualizacaoCep;
    procedure Processar(const AUnidade: IUnidadeTrabalho; const AItem: TItemAtualizacaoCep);
  protected
    procedure Execute; override;
  public
    constructor Create(AFila: TFilaAtualizacaoCep; const AFabricaUnidadeTrabalho: IFabricaUnidadeTrabalho;
      const AConsultaCep: IConsultaCep; AProgresso: TProgressoAtualizacaoCep);
  end;

  TCoordenadorAtualizacaoCep = class(TThread)
  private const
    TAMANHO_CEP = 8;
  private
    FFabricaUnidadeTrabalho: IFabricaUnidadeTrabalho;
    FFabricaConsultaCep: TFabricaConsultaCep;
    FQuantidadeTrabalhadores: Integer;
    FSomentePendentes: Boolean;
    FProgresso: TProgressoAtualizacaoCep;
    function CarregarItens: TArray<TItemAtualizacaoCep>;
    procedure DistribuirTrabalho(const AItens: TArray<TItemAtualizacaoCep>);
  protected
    procedure Execute; override;
  public
    constructor Create(const AFabricaUnidadeTrabalho: IFabricaUnidadeTrabalho;
      const AFabricaConsultaCep: TFabricaConsultaCep; AQuantidadeTrabalhadores: Integer;
      ASomentePendentes: Boolean; AProgresso: TProgressoAtualizacaoCep);
  end;

  TRegraAtualizacaoCep = class(TInterfacedObject, IRegraAtualizacaoCep)
  private
    FFabricaUnidadeTrabalho: IFabricaUnidadeTrabalho;
    FFabricaConsultaCep: TFabricaConsultaCep;
    FQuantidadeTrabalhadores: Integer;
    FProgresso: TProgressoAtualizacaoCep;
    FCoordenador: TCoordenadorAtualizacaoCep;
    FTrava: TCriticalSection;
    procedure LiberarCoordenador;
  public
    constructor Create(const AFabricaUnidadeTrabalho: IFabricaUnidadeTrabalho;
      const AFabricaConsultaCep: TFabricaConsultaCep; AQuantidadeTrabalhadores: Integer);
    destructor Destroy; override;
    procedure Iniciar(ASomentePendentes: Boolean);
    function ObterStatus: TStatusAtualizacaoCep;
  end;

implementation

uses
  System.Math,
  UExcecoes,
  UPessoa,
  LibTexto;

constructor TProgressoAtualizacaoCep.Create;
begin
  inherited Create;
  FTrava := TCriticalSection.Create;
  FStatus := TStatusAtualizacaoCep.Create;
end;

destructor TProgressoAtualizacaoCep.Destroy;
begin
  FStatus.Free;
  FTrava.Free;
  inherited;
end;

procedure TProgressoAtualizacaoCep.Reiniciar(ASomentePendentes: Boolean);
begin
  FTrava.Enter;
  try
    FStatus.Free;
    FStatus := TStatusAtualizacaoCep.Create;
    FStatus.EmExecucao := True;
    FStatus.SomentePendentes := ASomentePendentes;
    FStatus.Inicio := Now;
    FCancelado := False;
  finally
    FTrava.Leave;
  end;
end;

procedure TProgressoAtualizacaoCep.DefinirTotais(ATotalEnderecos, ATotalCeps: Integer);
begin
  FTrava.Enter;
  try
    FStatus.TotalEnderecos := ATotalEnderecos;
    FStatus.TotalCeps := ATotalCeps;
  finally
    FTrava.Leave;
  end;
end;

procedure TProgressoAtualizacaoCep.RegistrarSucesso(AQuantidadeEnderecos: Integer);
begin
  FTrava.Enter;
  try
    FStatus.CepsProcessados := FStatus.CepsProcessados + 1;
    FStatus.EnderecosAtualizados := FStatus.EnderecosAtualizados + AQuantidadeEnderecos;
  finally
    FTrava.Leave;
  end;
end;

procedure TProgressoAtualizacaoCep.RegistrarCepNaoEncontrado;
begin
  FTrava.Enter;
  try
    FStatus.CepsProcessados := FStatus.CepsProcessados + 1;
    FStatus.CepsNaoEncontrados := FStatus.CepsNaoEncontrados + 1;
  finally
    FTrava.Leave;
  end;
end;

procedure TProgressoAtualizacaoCep.RegistrarFalha(const AMensagem: string);
begin
  FTrava.Enter;
  try
    FStatus.CepsProcessados := FStatus.CepsProcessados + 1;
    FStatus.Falhas := FStatus.Falhas + 1;
    FStatus.UltimoErro := AMensagem;
  finally
    FTrava.Leave;
  end;
end;

procedure TProgressoAtualizacaoCep.Finalizar;
begin
  FTrava.Enter;
  try
    FStatus.EmExecucao := False;
    FStatus.Fim := Now;
  finally
    FTrava.Leave;
  end;
end;

procedure TProgressoAtualizacaoCep.Cancelar;
begin
  FTrava.Enter;
  try
    FCancelado := True;
  finally
    FTrava.Leave;
  end;
end;

function TProgressoAtualizacaoCep.Cancelado: Boolean;
begin
  FTrava.Enter;
  try
    Result := FCancelado;
  finally
    FTrava.Leave;
  end;
end;

function TProgressoAtualizacaoCep.EmExecucao: Boolean;
begin
  FTrava.Enter;
  try
    Result := FStatus.EmExecucao;
  finally
    FTrava.Leave;
  end;
end;

function TProgressoAtualizacaoCep.Fotografia: TStatusAtualizacaoCep;
begin
  Result := TStatusAtualizacaoCep.Create;
  FTrava.Enter;
  try
    Result.CopiarDe(FStatus);
  finally
    FTrava.Leave;
  end;
end;

function TItemAtualizacaoCep.EhSentinela: Boolean;
begin
  Result := Cep = '';
end;

class function TItemAtualizacaoCep.Sentinela: TItemAtualizacaoCep;
begin
  Result.Cep := '';
  Result.IdsEnderecos := nil;
end;

constructor TTrabalhadorCep.Create(AFila: TFilaAtualizacaoCep; const AFabricaUnidadeTrabalho: IFabricaUnidadeTrabalho;
  const AConsultaCep: IConsultaCep; AProgresso: TProgressoAtualizacaoCep);
begin
  FFila := AFila;
  FFabricaUnidadeTrabalho := AFabricaUnidadeTrabalho;
  FConsultaCep := AConsultaCep;
  FProgresso := AProgresso;
  FreeOnTerminate := False;
  inherited Create(False);
end;

procedure TTrabalhadorCep.Execute;
var
  LUnidade: IUnidadeTrabalho;
  LItem: TItemAtualizacaoCep;
begin
  try
    LUnidade := FFabricaUnidadeTrabalho.Criar;
  except
    on E: Exception do
    begin
      FProgresso.RegistrarFalha('Trabalhador sem conexão com o banco: ' + E.Message);
      Exit;
    end;
  end;

  while FFila.PopItem(LItem) = wrSignaled do
  begin
    if LItem.EhSentinela then
      Break;
    if not FProgresso.Cancelado then
      Processar(LUnidade, LItem);
  end;
end;

procedure TTrabalhadorCep.Processar(const AUnidade: IUnidadeTrabalho; const AItem: TItemAtualizacaoCep);
var
  LIntegracao: TEnderecoIntegracao;
begin
  try
    LIntegracao := FConsultaCep.Consultar(AItem.Cep);
    if LIntegracao = nil then
    begin
      FProgresso.RegistrarCepNaoEncontrado;
      Exit;
    end;

    try
      AUnidade.ExecutarEmTransacao(
        procedure(AUnidadeTransacao: IUnidadeTrabalho)
        begin
          AUnidadeTransacao.Integracoes.Salvar(AItem.IdsEnderecos, LIntegracao);
        end);
      FProgresso.RegistrarSucesso(Length(AItem.IdsEnderecos));
    finally
      LIntegracao.Free;
    end;
  except
    on E: Exception do
      FProgresso.RegistrarFalha(Format('CEP %s: %s', [AItem.Cep, E.Message]));
  end;
end;

constructor TCoordenadorAtualizacaoCep.Create(const AFabricaUnidadeTrabalho: IFabricaUnidadeTrabalho;
  const AFabricaConsultaCep: TFabricaConsultaCep; AQuantidadeTrabalhadores: Integer;
  ASomentePendentes: Boolean; AProgresso: TProgressoAtualizacaoCep);
begin
  FFabricaUnidadeTrabalho := AFabricaUnidadeTrabalho;
  FFabricaConsultaCep := AFabricaConsultaCep;
  FQuantidadeTrabalhadores := Max(AQuantidadeTrabalhadores, 1);
  FSomentePendentes := ASomentePendentes;
  FProgresso := AProgresso;
  FreeOnTerminate := False;
  inherited Create(False);
end;

function TCoordenadorAtualizacaoCep.CarregarItens: TArray<TItemAtualizacaoCep>;
var
  LUnidade: IUnidadeTrabalho;
  LEnderecos: TObjectList<TEndereco>;
  LGrupos: TObjectDictionary<string, TList<Int64>>;
  LEndereco: TEndereco;
  LCep: string;
  LIds: TList<Int64>;
  LGrupo: TPair<string, TList<Int64>>;
  LQuantidadeEnderecos, I: Integer;
begin
  LUnidade := FFabricaUnidadeTrabalho.Criar;
  LEnderecos := LUnidade.Enderecos.ListarParaIntegracao(FSomentePendentes);
  LGrupos := TObjectDictionary<string, TList<Int64>>.Create([doOwnsValues]);
  try
    LQuantidadeEnderecos := 0;
    for LEndereco in LEnderecos do
    begin
      LCep := TTexto.SomenteDigitos(LEndereco.Cep);
      if Length(LCep) <> TAMANHO_CEP then
        Continue;
      if not LGrupos.TryGetValue(LCep, LIds) then
      begin
        LIds := TList<Int64>.Create;
        LGrupos.Add(LCep, LIds);
      end;
      LIds.Add(LEndereco.Id);
      Inc(LQuantidadeEnderecos);
    end;

    SetLength(Result, LGrupos.Count);
    I := 0;
    for LGrupo in LGrupos do
    begin
      Result[I].Cep := LGrupo.Key;
      Result[I].IdsEnderecos := LGrupo.Value.ToArray;
      Inc(I);
    end;
    FProgresso.DefinirTotais(LQuantidadeEnderecos, LGrupos.Count);
  finally
    LGrupos.Free;
    LEnderecos.Free;
  end;
end;

procedure TCoordenadorAtualizacaoCep.DistribuirTrabalho(const AItens: TArray<TItemAtualizacaoCep>);
var
  LFila: TFilaAtualizacaoCep;
  LTrabalhadores: TObjectList<TTrabalhadorCep>;
  LTrabalhador: TTrabalhadorCep;
  LItem: TItemAtualizacaoCep;
  I: Integer;
begin
  LFila := TFilaAtualizacaoCep.Create(Length(AItens) + FQuantidadeTrabalhadores);
  LTrabalhadores := TObjectList<TTrabalhadorCep>.Create(True);
  try
    for I := 1 to Min(FQuantidadeTrabalhadores, Length(AItens)) do
      LTrabalhadores.Add(TTrabalhadorCep.Create(LFila, FFabricaUnidadeTrabalho, FFabricaConsultaCep(), FProgresso));

    for LItem in AItens do
    begin
      if FProgresso.Cancelado then
        Break;
      LFila.PushItem(LItem);
    end;
    for I := 1 to LTrabalhadores.Count do
      LFila.PushItem(TItemAtualizacaoCep.Sentinela);

    for LTrabalhador in LTrabalhadores do
      LTrabalhador.WaitFor;
  finally
    LTrabalhadores.Free;
    LFila.Free;
  end;
end;

procedure TCoordenadorAtualizacaoCep.Execute;
begin
  try
    DistribuirTrabalho(CarregarItens);
  except
    on E: Exception do
      FProgresso.RegistrarFalha('Falha geral na atualização: ' + E.Message);
  end;
  FProgresso.Finalizar;
end;

constructor TRegraAtualizacaoCep.Create(const AFabricaUnidadeTrabalho: IFabricaUnidadeTrabalho;
  const AFabricaConsultaCep: TFabricaConsultaCep; AQuantidadeTrabalhadores: Integer);
begin
  inherited Create;
  FFabricaUnidadeTrabalho := AFabricaUnidadeTrabalho;
  FFabricaConsultaCep := AFabricaConsultaCep;
  FQuantidadeTrabalhadores := AQuantidadeTrabalhadores;
  FProgresso := TProgressoAtualizacaoCep.Create;
  FTrava := TCriticalSection.Create;
end;

destructor TRegraAtualizacaoCep.Destroy;
begin
  FProgresso.Cancelar;
  LiberarCoordenador;
  FTrava.Free;
  FProgresso.Free;
  inherited;
end;

procedure TRegraAtualizacaoCep.LiberarCoordenador;
begin
  if FCoordenador = nil then
    Exit;
  FCoordenador.WaitFor;
  FreeAndNil(FCoordenador);
end;

procedure TRegraAtualizacaoCep.Iniciar(ASomentePendentes: Boolean);
begin
  FTrava.Enter;
  try
    if FProgresso.EmExecucao then
      raise EOperacaoEmAndamento.Create('Já existe uma atualização de endereços em andamento.');

    LiberarCoordenador;
    FProgresso.Reiniciar(ASomentePendentes);
    FCoordenador := TCoordenadorAtualizacaoCep.Create(FFabricaUnidadeTrabalho, FFabricaConsultaCep,
      FQuantidadeTrabalhadores, ASomentePendentes, FProgresso);
  finally
    FTrava.Leave;
  end;
end;

function TRegraAtualizacaoCep.ObterStatus: TStatusAtualizacaoCep;
begin
  Result := FProgresso.Fotografia;
end;

end.
