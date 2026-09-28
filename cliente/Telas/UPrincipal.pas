unit UPrincipal;

interface

uses
  Winapi.Windows,
  Winapi.Messages,
  System.SysUtils,
  System.Classes,
  Vcl.Graphics,
  Vcl.Controls,
  Vcl.Forms,
  Vcl.Dialogs,
  Vcl.StdCtrls,
  Vcl.ExtCtrls,
  Vcl.ComCtrls,
  Vcl.Menus,
  UStatusCep,
  LibPessoa,
  UbrwCliente;

type
  TfrmPrincipal = class(TForm)
    mnuPrincipal: TMainMenu;
    mniCadastros: TMenuItem;
    mniClientes: TMenuItem;
    mniProcessos: TMenuItem;
    mniInclusaoLote: TMenuItem;
    mniAtualizarCeps: TMenuItem;
    mniSair: TMenuItem;
    pnlCentro: TPanel;
    lblTitulo: TLabel;
    lblSubtitulo: TLabel;
    grpProcessos: TGroupBox;
    lblLote: TLabel;
    lblCep: TLabel;
    pbCep: TProgressBar;
    stbRodape: TStatusBar;
    tmrStatusCep: TTimer;
    procedure FormCreate(Sender: TObject);
    procedure mniClientesClick(Sender: TObject);
    procedure mniInclusaoLoteClick(Sender: TObject);
    procedure mniAtualizarCepsClick(Sender: TObject);
    procedure mniSairClick(Sender: TObject);
    procedure tmrStatusCepTimer(Sender: TObject);
  private const
    PAINEL_BANCO = 0;
    PAINEL_DATA = 1;
    PAINEL_USUARIO = 2;
    USUARIO = 'Marlon Stolf';
  private
    FServidor: IAcessoServidor;
    FBrwCliente: TfrmBrwCliente;
    FRodapeCarregado: Boolean;
    FAcompanhandoCep: Boolean;
    procedure CarregarRodape;
    procedure ConsultarStatusCep;
    procedure ExibirStatusCep(AStatus: TStatusAtualizacaoCep);
    procedure AtualizarClientes;
  end;

var
  frmPrincipal: TfrmPrincipal;

implementation

uses
  USistema,
  LibAssincrono,
  LibMensagem,
  UcaLote,
  UConfiguracaoCliente;

{$R *.dfm}

procedure TfrmPrincipal.FormCreate(Sender: TObject);
begin
  FServidor := TAcessoServidor.Create(TConfiguracaoCliente.UrlServidor);
  stbRodape.Panels[PAINEL_DATA].Text := FormatDateTime('dd/mm/yyyy', Date);
  stbRodape.Panels[PAINEL_USUARIO].Text := USUARIO;
  CarregarRodape;
  ConsultarStatusCep;
end;

procedure TfrmPrincipal.CarregarRodape;
begin
  stbRodape.Panels[PAINEL_BANCO].Text := 'Banco: consultando';
  TAssincrono.Executar<TInformacoesBanco>(
    function: TInformacoesBanco
    begin
      Result := FServidor.InformacoesBanco;
    end,
    procedure(AInformacoes: TInformacoesBanco)
    begin
      FRodapeCarregado := True;
      stbRodape.Panels[PAINEL_BANCO].Text := 'Banco: ' + AInformacoes.Descricao;
    end,
    procedure(const AMensagem: string)
    begin
      stbRodape.Panels[PAINEL_BANCO].Text := 'Banco: servidor indisponível em ' + TConfiguracaoCliente.UrlServidor;
    end);
end;

procedure TfrmPrincipal.AtualizarClientes;
begin
  if FBrwCliente <> nil then
    FBrwCliente.Recarregar;
end;

procedure TfrmPrincipal.mniClientesClick(Sender: TObject);
begin
  if not FRodapeCarregado then
    CarregarRodape;
  if FBrwCliente = nil then
    FBrwCliente := TfrmBrwCliente.Create(Self);
  FBrwCliente.Abrir(FServidor);
end;

procedure TfrmPrincipal.mniSairClick(Sender: TObject);
begin
  Close;
end;

procedure TfrmPrincipal.mniInclusaoLoteClick(Sender: TObject);
var
  LResumo: string;
begin
  if TfrmCaLote.Executar(FServidor, LResumo) then
  begin
    lblLote.Caption := LResumo;
    AtualizarClientes;
  end;
end;

procedure TfrmPrincipal.mniAtualizarCepsClick(Sender: TObject);
var
  LSomentePendentes: Boolean;
begin
  case TMensagem.Perguntar('Atualizar somente os endereços que ainda não têm dados do ViaCEP?' + sLineBreak +
    sLineBreak + 'Sim: somente os pendentes' + sLineBreak + 'Não: reprocessar todos os endereços') of
    rsSim:
      LSomentePendentes := True;
    rsNao:
      LSomentePendentes := False;
  else
    Exit;
  end;

  mniAtualizarCeps.Enabled := False;
  TAssincrono.Executar<TStatusAtualizacaoCep>(
    function: TStatusAtualizacaoCep
    begin
      Result := FServidor.IniciarAtualizacaoCep(LSomentePendentes);
    end,
    procedure(AStatus: TStatusAtualizacaoCep)
    begin
      try
        FAcompanhandoCep := True;
        ExibirStatusCep(AStatus);
      finally
        AStatus.Free;
      end;
      tmrStatusCep.Enabled := True;
    end,
    procedure(const AMensagem: string)
    begin
      mniAtualizarCeps.Enabled := True;
      TMensagem.Erro(AMensagem);
    end);
end;

procedure TfrmPrincipal.tmrStatusCepTimer(Sender: TObject);
begin
  tmrStatusCep.Enabled := False;
  ConsultarStatusCep;
end;

procedure TfrmPrincipal.ConsultarStatusCep;
begin
  TAssincrono.Executar<TStatusAtualizacaoCep>(
    function: TStatusAtualizacaoCep
    begin
      Result := FServidor.ObterStatusAtualizacaoCep;
    end,
    procedure(AStatus: TStatusAtualizacaoCep)
    var
      LEmExecucao, LConcluiu: Boolean;
    begin
      try
        ExibirStatusCep(AStatus);
        LEmExecucao := AStatus.EmExecucao;
        LConcluiu := FAcompanhandoCep and not LEmExecucao;
        FAcompanhandoCep := LEmExecucao;
      finally
        AStatus.Free;
      end;
      mniAtualizarCeps.Enabled := not LEmExecucao;
      tmrStatusCep.Enabled := LEmExecucao;
      if LConcluiu then
        AtualizarClientes;
    end,
    procedure(const AMensagem: string)
    begin
      tmrStatusCep.Enabled := False;
      mniAtualizarCeps.Enabled := True;
      lblCep.Caption := 'Atualização de endereços: não foi possível consultar o andamento.';
    end);
end;

procedure TfrmPrincipal.ExibirStatusCep(AStatus: TStatusAtualizacaoCep);
begin
  pbCep.Position := AStatus.PercentualConcluido;
  if AStatus.EmExecucao then
    lblCep.Caption := Format('Atualização de endereços em andamento: %d de %d CEPs  |  %s endereços atualizados',
      [AStatus.CepsProcessados, AStatus.TotalCeps, FormatFloat('#,##0', AStatus.EnderecosAtualizados)])
  else if AStatus.Fim > 0 then
    lblCep.Caption := Format('Última atualização de endereços (%s): %s atualizados  |  %d CEPs não encontrados  |  %d falhas',
      [FormatDateTime('dd/mm hh:nn', AStatus.Fim), FormatFloat('#,##0', AStatus.EnderecosAtualizados),
       AStatus.CepsNaoEncontrados, AStatus.Falhas])
  else
    lblCep.Caption := 'Atualização de endereços: nenhuma execução desde que o servidor foi iniciado.';

  if AStatus.UltimoErro <> '' then
    lblCep.Hint := 'Último erro: ' + AStatus.UltimoErro
  else
    lblCep.Hint := '';
end;

end.
