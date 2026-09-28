unit UConfiguracao;

interface

type
  TConfiguracaoBanco = record
    Servidor: string;
    Porta: Integer;
    Banco: string;
    Usuario: string;
    Senha: string;
    BibliotecaCliente: string;
    MaximoConexoes: Integer;
  end;

  TConfiguracaoIntegracaoCep = record
    UrlModelo: string;
    QuantidadeThreads: Integer;
    TimeoutMs: Integer;
  end;

  TConfiguracaoServidor = class
  private const
    SECAO_SERVIDOR = 'Servidor';
    SECAO_BANCO = 'BancoDados';
    SECAO_INTEGRACAO_CEP = 'IntegracaoCep';
  private
    FPortaHttp: Integer;
    FBanco: TConfiguracaoBanco;
    FIntegracaoCep: TConfiguracaoIntegracaoCep;
  public
    constructor Create(const AArquivoIni: string);
    property PortaHttp: Integer read FPortaHttp;
    property Banco: TConfiguracaoBanco read FBanco;
    property IntegracaoCep: TConfiguracaoIntegracaoCep read FIntegracaoCep;
  end;

implementation

uses
  System.SysUtils,
  System.IniFiles;

constructor TConfiguracaoServidor.Create(const AArquivoIni: string);
var
  LIni: TMemIniFile;
begin
  inherited Create;
  LIni := TMemIniFile.Create(AArquivoIni, TEncoding.UTF8);
  try
    FPortaHttp := LIni.ReadInteger(SECAO_SERVIDOR, 'PortaHttp', 9000);

    FBanco.Servidor := LIni.ReadString(SECAO_BANCO, 'Servidor', 'localhost');
    FBanco.Porta := LIni.ReadInteger(SECAO_BANCO, 'Porta', 5432);
    FBanco.Banco := LIni.ReadString(SECAO_BANCO, 'Banco', 'teste_tecnico');
    FBanco.Usuario := LIni.ReadString(SECAO_BANCO, 'Usuario', 'postgres');
    FBanco.Senha := LIni.ReadString(SECAO_BANCO, 'Senha', '');
    FBanco.BibliotecaCliente := LIni.ReadString(SECAO_BANCO, 'BibliotecaCliente', '');
    FBanco.MaximoConexoes := LIni.ReadInteger(SECAO_BANCO, 'MaximoConexoes', 50);

    FIntegracaoCep.UrlModelo := LIni.ReadString(SECAO_INTEGRACAO_CEP, 'Url', 'https://viacep.com.br/ws/%s/json/');
    FIntegracaoCep.QuantidadeThreads := LIni.ReadInteger(SECAO_INTEGRACAO_CEP, 'Threads', 4);
    FIntegracaoCep.TimeoutMs := LIni.ReadInteger(SECAO_INTEGRACAO_CEP, 'TimeoutMs', 10000);
  finally
    LIni.Free;
  end;
end;

end.
