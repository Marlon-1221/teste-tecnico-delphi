program Servidor;

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  UExcecoes in '..\comum\UExcecoes.pas',
  LibTexto in '..\comum\LibTexto.pas',
  UEntidade in '..\comum\UEntidade.pas',
  UPessoa in '..\comum\UPessoa.pas',
  UPagina in '..\comum\UPagina.pas',
  UStatusCep in '..\comum\UStatusCep.pas',
  USistema in '..\comum\USistema.pas',
  UConversorJson in '..\comum\UConversorJson.pas',
  UrotValidacaoDocumento in '..\comum\UrotValidacaoDocumento.pas',
  UrotValidacaoPessoa in '..\comum\UrotValidacaoPessoa.pas',
  UConfiguracao in 'Infra\UConfiguracao.pas',
  UConexao in 'Infra\UConexao.pas',
  ULog in 'Infra\ULog.pas',
  URepositorioBase in 'Dados\URepositorioBase.pas',
  URepositorioPessoa in 'Dados\URepositorioPessoa.pas',
  URepositorioEndereco in 'Dados\URepositorioEndereco.pas',
  URepositorioIntegracao in 'Dados\URepositorioIntegracao.pas',
  URepositorioSistema in 'Dados\URepositorioSistema.pas',
  UUnidadeTrabalho in 'Dados\UUnidadeTrabalho.pas',
  UrotPessoa in 'Regras\UrotPessoa.pas',
  UrotSistema in 'Regras\UrotSistema.pas',
  UViaCep in 'Integracao\UViaCep.pas',
  UrotAtualizacaoCep in 'Regras\UrotAtualizacaoCep.pas',
  URoteador in 'Web\URoteador.pas',
  UServidorHttp in 'Web\UServidorHttp.pas',
  UControlePessoa in 'Controle\UControlePessoa.pas',
  UControleCep in 'Controle\UControleCep.pas',
  UControleSistema in 'Controle\UControleSistema.pas',
  UAplicacao in 'UAplicacao.pas';

var
  LAplicacao: TAplicacaoServidor;

begin
  {$IFDEF DEBUG}
  ReportMemoryLeaksOnShutdown := True;
  {$ENDIF}
  try
    LAplicacao := TAplicacaoServidor.Create(TAplicacaoServidor.LocalizarConfiguracao);
    try
      LAplicacao.Iniciar;
      Writeln('Pressione ENTER para encerrar o servidor.');
      Readln;
      LAplicacao.Parar;
    finally
      LAplicacao.Free;
    end;
  except
    on E: Exception do
    begin
      Writeln('Falha ao executar o servidor: ', E.ClassName, ': ', E.Message);
      Writeln('Pressione ENTER para sair.');
      Readln;
      ExitCode := 1;
    end;
  end;
end.
