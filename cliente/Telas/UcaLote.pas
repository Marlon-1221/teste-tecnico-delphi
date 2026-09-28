unit UcaLote;

interface

uses
  Winapi.Windows,
  Winapi.Messages,
  System.SysUtils,
  System.Classes,
  System.Generics.Collections,
  Vcl.Graphics,
  Vcl.Controls,
  Vcl.Forms,
  Vcl.Dialogs,
  Vcl.StdCtrls,
  UPessoa,
  LibPessoa,
  LibPlanilhaClientes;

type
  TfrmCaLote = class(TForm)
    grpGerar: TGroupBox;
    lblQuantidade: TLabel;
    edtQuantidade: TEdit;
    btnGerar: TButton;
    grpPlanilha: TGroupBox;
    lblArquivo: TLabel;
    edtArquivo: TEdit;
    btnSelecionar: TButton;
    btnImportar: TButton;
    lblModelo: TLabel;
    lblResultado: TLabel;
    mmoResultado: TMemo;
    btnFechar: TButton;
    dlgArquivo: TOpenDialog;
    procedure FormCloseQuery(Sender: TObject; var CanClose: Boolean);
    procedure btnGerarClick(Sender: TObject);
    procedure btnSelecionarClick(Sender: TObject);
    procedure btnImportarClick(Sender: TObject);
  private const
    MAXIMO_LINHAS_EXIBIDAS = 200;
  private
    FServidor: IAcessoServidor;
    FProcessando: Boolean;
    FIncluiu: Boolean;
    FResumo: string;
    procedure DefinirProcessando(AProcessando: Boolean; const AMensagem: string);
    procedure Registrar(const ATexto: string);
    procedure RegistrarLista(const ATitulo: string; ALinhas: TList<string>);
    procedure EnviarImportacao(AImportacao: TImportacaoPlanilha);
    procedure ConcluirInclusao(const AOrigem: string; const AResultado: TResultadoLote);
    class function TraduzirRegistrosParaLinhas(const AMensagem: string; AImportacao: TImportacaoPlanilha): string; static;
    function PastaModelos: string;
  public
    class function Executar(const AServidor: IAcessoServidor; out AResumo: string): Boolean;
  end;

implementation

uses
  System.Diagnostics,
  System.RegularExpressions,
  LibTexto,
  LibAssincrono,
  LibMensagem,
  LibGeradorPessoa;

{$R *.dfm}

class function TfrmCaLote.Executar(const AServidor: IAcessoServidor; out AResumo: string): Boolean;
var
  LFormulario: TfrmCaLote;
begin
  LFormulario := TfrmCaLote.Create(nil);
  try
    LFormulario.FServidor := AServidor;
    LFormulario.dlgArquivo.InitialDir := LFormulario.PastaModelos;
    LFormulario.ShowModal;
    Result := LFormulario.FIncluiu;
    AResumo := LFormulario.FResumo;
  finally
    LFormulario.Free;
  end;
end;

function TfrmCaLote.PastaModelos: string;
const
  CANDIDATOS: array[0..1] of string = ('modelos', '..\..\..\modelos');
var
  LCandidato: string;
begin
  for LCandidato in CANDIDATOS do
  begin
    Result := ExpandFileName(ExtractFilePath(ParamStr(0)) + LCandidato);
    if DirectoryExists(Result) then
      Exit;
  end;
  Result := ExtractFilePath(ParamStr(0));
end;

procedure TfrmCaLote.FormCloseQuery(Sender: TObject; var CanClose: Boolean);
begin
  CanClose := not FProcessando;
end;

procedure TfrmCaLote.DefinirProcessando(AProcessando: Boolean; const AMensagem: string);
begin
  FProcessando := AProcessando;
  grpGerar.Enabled := not AProcessando;
  grpPlanilha.Enabled := not AProcessando;
  btnFechar.Enabled := not AProcessando;
  if AProcessando then
    Screen.Cursor := crAppStart
  else
    Screen.Cursor := crDefault;
  if AMensagem <> '' then
    Registrar(AMensagem);
end;

procedure TfrmCaLote.Registrar(const ATexto: string);
begin
  mmoResultado.Lines.Add(ATexto);
end;

procedure TfrmCaLote.RegistrarLista(const ATitulo: string; ALinhas: TList<string>);
var
  I: Integer;
begin
  mmoResultado.Lines.BeginUpdate;
  try
    Registrar(ATitulo);
    for I := 0 to ALinhas.Count - 1 do
    begin
      if I = MAXIMO_LINHAS_EXIBIDAS then
      begin
        Registrar(Format('  e mais %d problema(s)', [ALinhas.Count - MAXIMO_LINHAS_EXIBIDAS]));
        Break;
      end;
      Registrar('  ' + ALinhas[I]);
    end;
  finally
    mmoResultado.Lines.EndUpdate;
  end;
end;

procedure TfrmCaLote.ConcluirInclusao(const AOrigem: string; const AResultado: TResultadoLote);
begin
  FIncluiu := True;
  FResumo := Format('Última inclusão em lote (%s): %s clientes  |  gravação no servidor: %d ms  |  total: %d ms',
    [AOrigem, FormatFloat('#,##0', AResultado.Inseridos), AResultado.TempoServidorMs, AResultado.TempoTotalMs]);
  DefinirProcessando(False, Format('%s clientes incluídos. Gravação no servidor: %d ms. Total: %d ms.',
    [FormatFloat('#,##0', AResultado.Inseridos), AResultado.TempoServidorMs, AResultado.TempoTotalMs]));
  TMensagem.Informar(Format('%s clientes incluídos em lote.' + sLineBreak +
    'Tempo de gravação no servidor: %d ms' + sLineBreak + 'Tempo total: %d ms',
    [FormatFloat('#,##0', AResultado.Inseridos), AResultado.TempoServidorMs, AResultado.TempoTotalMs]));
end;

procedure TfrmCaLote.btnGerarClick(Sender: TObject);
var
  LQuantidade: Integer;
begin
  LQuantidade := StrToIntDef(TTexto.SomenteDigitos(edtQuantidade.Text), 0);
  if LQuantidade <= 0 then
  begin
    TMensagem.Avisar('Informe uma quantidade maior que zero.');
    Exit;
  end;

  DefinirProcessando(True, Format('Gerando %s clientes de teste, conferindo CPF/CNPJ já cadastrados e enviando',
    [FormatFloat('#,##0', LQuantidade)]));
  TAssincrono.Executar<TResultadoLote>(
    function: TResultadoLote
    var
      LCronometro: TStopwatch;
      LGerador: TGeradorPessoas;
      LPessoas: TObjectList<TPessoa>;
    begin
      LCronometro := TStopwatch.StartNew;
      LGerador := TGeradorPessoas.Create;
      try
        LPessoas := LGerador.Gerar(LQuantidade,
          function(const ADocumentos: TArray<string>): TArray<string>
          begin
            Result := FServidor.DocumentosCadastrados(ADocumentos);
          end);
      finally
        LGerador.Free;
      end;
      try
        Result := FServidor.InserirLote(LPessoas);
      finally
        LPessoas.Free;
      end;
      Result.TempoTotalMs := LCronometro.ElapsedMilliseconds;
    end,
    procedure(AResultado: TResultadoLote)
    begin
      ConcluirInclusao('clientes de teste', AResultado);
    end,
    procedure(const AMensagem: string)
    begin
      DefinirProcessando(False, 'A inclusão falhou: ' + AMensagem);
      TMensagem.Erro(AMensagem);
    end);
end;

procedure TfrmCaLote.btnSelecionarClick(Sender: TObject);
begin
  if dlgArquivo.Execute then
    edtArquivo.Text := dlgArquivo.FileName;
end;

procedure TfrmCaLote.btnImportarClick(Sender: TObject);
var
  LArquivo: string;
begin
  LArquivo := Trim(edtArquivo.Text);
  if (LArquivo = '') or not FileExists(LArquivo) then
  begin
    TMensagem.Avisar('Selecione a planilha Excel (.xlsx) a importar.');
    Exit;
  end;

  DefinirProcessando(True, 'Lendo a planilha ' + ExtractFileName(LArquivo));
  TAssincrono.Executar<TImportacaoPlanilha>(
    function: TImportacaoPlanilha
    begin
      Result := TLeitorPlanilhaClientes.Ler(LArquivo);
    end,
    procedure(AImportacao: TImportacaoPlanilha)
    begin
      if AImportacao.Inconsistencias.Count > 0 then
      begin
        try
          DefinirProcessando(False, '');
          RegistrarLista(Format('A planilha tem %d problema(s). Nenhum cliente foi enviado; corrija as linhas abaixo:',
            [AImportacao.Inconsistencias.Count]), AImportacao.Inconsistencias);
          TMensagem.Avisar(Format('A planilha tem %d problema(s). Nenhum cliente foi enviado.' + sLineBreak +
            'Veja a lista de linhas a corrigir na tela.', [AImportacao.Inconsistencias.Count]));
        finally
          AImportacao.Free;
        end;
        Exit;
      end;
      EnviarImportacao(AImportacao);
    end,
    procedure(const AMensagem: string)
    begin
      DefinirProcessando(False, 'Não foi possível ler a planilha: ' + AMensagem);
      TMensagem.Erro(AMensagem);
    end);
end;

procedure TfrmCaLote.EnviarImportacao(AImportacao: TImportacaoPlanilha);
begin
  Registrar(Format('Planilha válida: %s clientes. Enviando ao servidor',
    [FormatFloat('#,##0', AImportacao.Pessoas.Count)]));
  TAssincrono.Executar<TResultadoLote>(
    function: TResultadoLote
    var
      LCronometro: TStopwatch;
    begin
      LCronometro := TStopwatch.StartNew;
      Result := FServidor.InserirLote(AImportacao.Pessoas);
      Result.TempoTotalMs := LCronometro.ElapsedMilliseconds;
    end,
    procedure(AResultado: TResultadoLote)
    begin
      AImportacao.Free;
      ConcluirInclusao('planilha', AResultado);
    end,
    procedure(const AMensagem: string)
    var
      LMensagem: string;
    begin
      LMensagem := TraduzirRegistrosParaLinhas(AMensagem, AImportacao);
      AImportacao.Free;
      DefinirProcessando(False, 'O servidor recusou a planilha:');
      Registrar(LMensagem);
      TMensagem.Avisar(LMensagem);
    end);
end;

class function TfrmCaLote.TraduzirRegistrosParaLinhas(const AMensagem: string;
  AImportacao: TImportacaoPlanilha): string;
var
  LCorrespondencia: TMatch;
  LPosicao: Integer;
begin
  Result := '';
  LPosicao := 1;
  for LCorrespondencia in TRegEx.Matches(AMensagem, 'Registro (\d+)') do
  begin
    Result := Result + Copy(AMensagem, LPosicao, LCorrespondencia.Index - LPosicao) +
      Format('Linha %d', [AImportacao.LinhaDoRegistro(StrToInt(LCorrespondencia.Groups[1].Value))]);
    LPosicao := LCorrespondencia.Index + LCorrespondencia.Length;
  end;
  Result := Result + Copy(AMensagem, LPosicao, MaxInt);
end;

end.
