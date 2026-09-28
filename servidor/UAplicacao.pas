unit UAplicacao;

interface

uses
  System.Generics.Collections,
  UConfiguracao,
  ULog,
  UConexao,
  UUnidadeTrabalho,
  URoteador,
  UServidorHttp;

type
  TAplicacaoServidor = class
  private
    FConfiguracao: TConfiguracaoServidor;
    FLog: ILog;
    FFabricaConexao: IFabricaConexao;
    FFabricaUnidadeTrabalho: IFabricaUnidadeTrabalho;
    FRoteador: TRoteador;
    FControles: TList<IControle>;
    FServidorHttp: TServidorHttp;
    procedure RegistrarControles;
    procedure VerificarBancoDados;
  public
    constructor Create(const AArquivoConfiguracao: string);
    destructor Destroy; override;
    class function LocalizarConfiguracao: string; static;
    procedure Iniciar;
    procedure Parar;
  end;

implementation

uses
  System.SysUtils,
  FireDAC.Comp.Client,
  UrotPessoa,
  UViaCep,
  UrotAtualizacaoCep,
  UrotSistema,
  UControlePessoa,
  UControleCep,
  UControleSistema;

constructor TAplicacaoServidor.Create(const AArquivoConfiguracao: string);
begin
  inherited Create;
  FConfiguracao := TConfiguracaoServidor.Create(AArquivoConfiguracao);
  FLog := TLogConsole.Create;
  FFabricaConexao := TFabricaConexao.Create(FConfiguracao.Banco);
  FFabricaUnidadeTrabalho := TFabricaUnidadeTrabalho.Create(FFabricaConexao);

  FRoteador := TRoteador.Create;
  FRoteador.AoErroInterno :=
    procedure(AMensagem: string)
    begin
      FLog.Erro(AMensagem);
    end;
  FControles := TList<IControle>.Create;
  RegistrarControles;

  FServidorHttp := TServidorHttp.Create(FConfiguracao.PortaHttp, FRoteador, FLog);
end;

destructor TAplicacaoServidor.Destroy;
begin
  FServidorHttp.Free;
  FRoteador.Free;
  FControles.Free;
  FFabricaUnidadeTrabalho := nil;
  FFabricaConexao := nil;
  FLog := nil;
  FConfiguracao.Free;
  inherited;
end;

class function TAplicacaoServidor.LocalizarConfiguracao: string;
const
  CANDIDATOS: array[0..1] of string = ('Servidor.ini', '..\..\Servidor.ini');
var
  LCandidato: string;
begin
  for LCandidato in CANDIDATOS do
  begin
    Result := ExpandFileName(ExtractFilePath(ParamStr(0)) + LCandidato);
    if FileExists(Result) then
      Exit;
  end;
  Result := ExtractFilePath(ParamStr(0)) + CANDIDATOS[0];
end;

procedure TAplicacaoServidor.RegistrarControles;
var
  LControle: IControle;
  LIntegracaoCep: TConfiguracaoIntegracaoCep;
  LFabricaConsultaCep: TFabricaConsultaCep;
begin
  LIntegracaoCep := FConfiguracao.IntegracaoCep;
  LFabricaConsultaCep :=
    function: IConsultaCep
    begin
      Result := TConsultaViaCep.Create(LIntegracaoCep.UrlModelo, LIntegracaoCep.TimeoutMs);
    end;

  FControles.Add(TControlePessoa.Create(TRegraPessoa.Create(FFabricaUnidadeTrabalho)));
  FControles.Add(TControleSistema.Create(TRegraSistema.Create(FFabricaUnidadeTrabalho,
    FConfiguracao.Banco.Servidor, FConfiguracao.Banco.Porta)));
  FControles.Add(TControleCep.Create(TRegraAtualizacaoCep.Create(FFabricaUnidadeTrabalho,
    LFabricaConsultaCep, LIntegracaoCep.QuantidadeThreads)));

  for LControle in FControles do
    LControle.RegistrarRotas(FRoteador);
end;

procedure TAplicacaoServidor.VerificarBancoDados;
var
  LConexao: TFDConnection;
begin
  LConexao := FFabricaConexao.CriarConexao;
  try
    FLog.Informar(Format('Conectado ao PostgreSQL %s:%d/%s',
      [FConfiguracao.Banco.Servidor, FConfiguracao.Banco.Porta, FConfiguracao.Banco.Banco]));
  finally
    LConexao.Free;
  end;
end;

procedure TAplicacaoServidor.Iniciar;
begin
  VerificarBancoDados;
  FServidorHttp.Iniciar;
  FLog.Informar(Format('Servidor REST ouvindo em http://localhost:%d', [FConfiguracao.PortaHttp]));
end;

procedure TAplicacaoServidor.Parar;
begin
  FServidorHttp.Parar;
  FLog.Informar('Servidor parado.');
end;

end.
