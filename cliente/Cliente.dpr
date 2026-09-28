program Cliente;

uses
  Vcl.Forms,
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
  UConfiguracaoCliente in 'UConfiguracaoCliente.pas',
  LibAssincrono in 'Lib\LibAssincrono.pas',
  LibMensagem in 'Lib\LibMensagem.pas',
  LibPessoa in 'Lib\LibPessoa.pas',
  LibGeradorPessoa in 'Lib\LibGeradorPessoa.pas',
  LibPlanilhaClientes in 'Lib\LibPlanilhaClientes.pas',
  UcaCliente in 'Telas\UcaCliente.pas' {frmCaCliente},
  UbrwCliente in 'Telas\UbrwCliente.pas' {frmBrwCliente},
  UcaLote in 'Telas\UcaLote.pas' {frmCaLote},
  UPrincipal in 'Telas\UPrincipal.pas' {frmPrincipal};

begin
  {$IFDEF DEBUG}
  ReportMemoryLeaksOnShutdown := True;
  {$ENDIF}
  Randomize;
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.Title := 'Cadastro de Clientes';
  Application.CreateForm(TfrmPrincipal, frmPrincipal);
  Application.Run;
end.
