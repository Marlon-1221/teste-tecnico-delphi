unit UConexao;

interface

uses
  FireDAC.Comp.Client,
  FireDAC.Phys.PG,
  UConfiguracao;

type
  IFabricaConexao = interface
    ['{3F7A1C2E-5B64-4E0B-A1D7-9C2F8E4B6D10}']
    function CriarConexao: TFDConnection;
  end;

  TFabricaConexao = class(TInterfacedObject, IFabricaConexao)
  private const
    NOME_DEFINICAO = 'TesteTecnicoPG';
    DRIVER_POSTGRESQL = 'PG';
  private
    FDriverLink: TFDPhysPgDriverLink;
    procedure RegistrarDefinicao(const AConfiguracao: TConfiguracaoBanco);
  public
    constructor Create(const AConfiguracao: TConfiguracaoBanco);
    destructor Destroy; override;
    function CriarConexao: TFDConnection;
  end;

implementation

uses
  System.SysUtils,
  System.Classes,
  FireDAC.Stan.Intf,
  FireDAC.Stan.Option,
  FireDAC.Stan.Def,
  FireDAC.Stan.Pool,
  FireDAC.Stan.Async,
  FireDAC.Phys,
  FireDAC.DApt,
  FireDAC.ConsoleUI.Wait;

constructor TFabricaConexao.Create(const AConfiguracao: TConfiguracaoBanco);
begin
  inherited Create;
  FDriverLink := TFDPhysPgDriverLink.Create(nil);
  if AConfiguracao.BibliotecaCliente <> '' then
    FDriverLink.VendorLib := AConfiguracao.BibliotecaCliente;
  RegistrarDefinicao(AConfiguracao);
end;

destructor TFabricaConexao.Destroy;
begin
  FDManager.CloseConnectionDef(NOME_DEFINICAO);
  FDManager.DeleteConnectionDef(NOME_DEFINICAO);
  FDriverLink.Free;
  inherited;
end;

procedure TFabricaConexao.RegistrarDefinicao(const AConfiguracao: TConfiguracaoBanco);
var
  LParametros: TStringList;
begin
  LParametros := TStringList.Create;
  try
    LParametros.Values['Server'] := AConfiguracao.Servidor;
    LParametros.Values['Port'] := IntToStr(AConfiguracao.Porta);
    LParametros.Values['Database'] := AConfiguracao.Banco;
    LParametros.Values['User_Name'] := AConfiguracao.Usuario;
    LParametros.Values['Password'] := AConfiguracao.Senha;
    LParametros.Values['CharacterSet'] := 'UTF8';
    LParametros.Values['ApplicationName'] := 'TesteTecnico.Servidor';
    LParametros.Values['Pooled'] := 'True';
    LParametros.Values['POOL_MaximumItems'] := IntToStr(AConfiguracao.MaximoConexoes);
    FDManager.AddConnectionDef(NOME_DEFINICAO, DRIVER_POSTGRESQL, LParametros);
  finally
    LParametros.Free;
  end;
end;

function TFabricaConexao.CriarConexao: TFDConnection;
begin
  Result := TFDConnection.Create(nil);
  try
    Result.ConnectionDefName := NOME_DEFINICAO;
    Result.LoginPrompt := False;
    Result.ResourceOptions.SilentMode := True;
    Result.Connected := True;
  except
    Result.Free;
    raise;
  end;
end;

end.
