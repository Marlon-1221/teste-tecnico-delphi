unit UcaCliente;

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
  LibPessoa;

type
  TfrmCaCliente = class(TForm)
    lblNatureza: TLabel;
    cbxNatureza: TComboBox;
    lblDocumento: TLabel;
    edtDocumento: TEdit;
    lblPrimeiroNome: TLabel;
    edtPrimeiroNome: TEdit;
    lblSegundoNome: TLabel;
    edtSegundoNome: TEdit;
    grpEnderecos: TGroupBox;
    lblCep: TLabel;
    edtCep: TEdit;
    btnNovoEndereco: TButton;
    btnRemoverEndereco: TButton;
    lstEnderecos: TListBox;
    btnSalvar: TButton;
    btnCancelar: TButton;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure FormCloseQuery(Sender: TObject; var CanClose: Boolean);
    procedure cbxNaturezaChange(Sender: TObject);
    procedure edtCepChange(Sender: TObject);
    procedure edtCepKeyPress(Sender: TObject; var Key: Char);
    procedure btnNovoEnderecoClick(Sender: TObject);
    procedure btnRemoverEnderecoClick(Sender: TObject);
    procedure lstEnderecosClick(Sender: TObject);
    procedure btnSalvarClick(Sender: TObject);
  private
    FServidor: IAcessoServidor;
    FIdPessoa: Int64;
    FEnderecos: TObjectList<TEndereco>;
    FAtualizandoTela: Boolean;
    FSalvando: Boolean;
    function NaturezaSelecionada: TNaturezaPessoa;
    function DescreverEndereco(AEndereco: TEndereco): string;
    procedure AtualizarRotulos;
    procedure AtualizarListaEnderecos(AIndiceSelecionado: Integer);
    procedure SelecionarEndereco(AIndice: Integer);
    procedure AdicionarEnderecoEmBranco;
    procedure DefinirSalvando(ASalvando: Boolean);
    procedure CarregarDe(APessoa: TPessoa);
    procedure GravarEm(APessoa: TPessoa);
  public
    class function Editar(APessoa: TPessoa; const AServidor: IAcessoServidor): Boolean;
  end;

implementation

uses
  System.Math,
  LibTexto,
  LibAssincrono,
  LibMensagem,
  UrotValidacaoPessoa;

{$R *.dfm}

class function TfrmCaCliente.Editar(APessoa: TPessoa; const AServidor: IAcessoServidor): Boolean;
var
  LFormulario: TfrmCaCliente;
begin
  LFormulario := TfrmCaCliente.Create(nil);
  try
    LFormulario.FServidor := AServidor;
    LFormulario.CarregarDe(APessoa);
    Result := LFormulario.ShowModal = mrOk;
  finally
    LFormulario.Free;
  end;
end;

procedure TfrmCaCliente.FormCreate(Sender: TObject);
begin
  FEnderecos := TObjectList<TEndereco>.Create(True);
end;

procedure TfrmCaCliente.FormDestroy(Sender: TObject);
begin
  FEnderecos.Free;
end;

procedure TfrmCaCliente.FormCloseQuery(Sender: TObject; var CanClose: Boolean);
begin
  CanClose := not FSalvando;
end;

function TfrmCaCliente.NaturezaSelecionada: TNaturezaPessoa;
begin
  if cbxNatureza.ItemIndex = 1 then
    Result := npJuridica
  else
    Result := npFisica;
end;

procedure TfrmCaCliente.AtualizarRotulos;
begin
  case NaturezaSelecionada of
    npFisica:
      begin
        lblDocumento.Caption := 'CPF';
        lblPrimeiroNome.Caption := 'Nome';
        lblSegundoNome.Caption := 'Sobrenome';
      end;
    npJuridica:
      begin
        lblDocumento.Caption := 'CNPJ';
        lblPrimeiroNome.Caption := 'Razão social';
        lblSegundoNome.Caption := 'Nome fantasia';
      end;
  end;
end;

function TfrmCaCliente.DescreverEndereco(AEndereco: TEndereco): string;
begin
  if AEndereco.Cep = '' then
    Exit('(digite o CEP)');

  Result := TTexto.FormatarCep(AEndereco.Cep);
  if AEndereco.PossuiIntegracao then
    Result := Format('%s  -  %s, %s - %s/%s', [Result, AEndereco.Integracao.Logradouro,
      AEndereco.Integracao.Bairro, AEndereco.Integracao.Cidade, AEndereco.Integracao.Uf])
  else if not AEndereco.EhNova then
    Result := Result + '  -  (aguardando atualização pelo ViaCEP)';
end;

procedure TfrmCaCliente.AtualizarListaEnderecos(AIndiceSelecionado: Integer);
var
  LEndereco: TEndereco;
begin
  lstEnderecos.Items.BeginUpdate;
  try
    lstEnderecos.Items.Clear;
    for LEndereco in FEnderecos do
      lstEnderecos.Items.Add(DescreverEndereco(LEndereco));
  finally
    lstEnderecos.Items.EndUpdate;
  end;
  SelecionarEndereco(AIndiceSelecionado);
end;

procedure TfrmCaCliente.SelecionarEndereco(AIndice: Integer);
begin
  if (AIndice < 0) or (AIndice >= FEnderecos.Count) then
    AIndice := -1;

  FAtualizandoTela := True;
  try
    lstEnderecos.ItemIndex := AIndice;
    if AIndice >= 0 then
      edtCep.Text := TTexto.FormatarCep(FEnderecos[AIndice].Cep)
    else
      edtCep.Clear;
  finally
    FAtualizandoTela := False;
  end;
  edtCep.Enabled := AIndice >= 0;
  btnRemoverEndereco.Enabled := AIndice >= 0;
end;

procedure TfrmCaCliente.AdicionarEnderecoEmBranco;
begin
  FEnderecos.Add(TEndereco.Create);
  AtualizarListaEnderecos(FEnderecos.Count - 1);
end;

procedure TfrmCaCliente.CarregarDe(APessoa: TPessoa);
var
  LOrigem, LCopia: TEndereco;
begin
  FIdPessoa := APessoa.Id;
  if APessoa.EhNova then
    Caption := 'Novo cliente'
  else
    Caption := Format('Editar cliente %d', [APessoa.Id]);

  cbxNatureza.ItemIndex := Ord(APessoa.Natureza = npJuridica);
  edtDocumento.Text := TTexto.FormatarDocumento(APessoa.Documento);
  edtPrimeiroNome.Text := APessoa.PrimeiroNome;
  edtSegundoNome.Text := APessoa.SegundoNome;

  FEnderecos.Clear;
  for LOrigem in APessoa.Enderecos do
  begin
    LCopia := TEndereco.Create;
    FEnderecos.Add(LCopia);
    LCopia.Id := LOrigem.Id;
    LCopia.Cep := LOrigem.Cep;
    if LOrigem.PossuiIntegracao then
    begin
      LCopia.Integracao := TEnderecoIntegracao.Create;
      LCopia.Integracao.CopiarDe(LOrigem.Integracao);
    end;
  end;

  AtualizarRotulos;
  if FEnderecos.Count = 0 then
    AdicionarEnderecoEmBranco
  else
    AtualizarListaEnderecos(0);

  if APessoa.EhNova then
    ActiveControl := cbxNatureza
  else
    ActiveControl := edtCep;
end;

procedure TfrmCaCliente.GravarEm(APessoa: TPessoa);
var
  LEndereco: TEndereco;
begin
  APessoa.Id := FIdPessoa;
  APessoa.Natureza := NaturezaSelecionada;
  APessoa.Documento := edtDocumento.Text;
  APessoa.PrimeiroNome := edtPrimeiroNome.Text;
  APessoa.SegundoNome := edtSegundoNome.Text;
  APessoa.Enderecos.Clear;
  for LEndereco in FEnderecos do
    APessoa.AdicionarEndereco(LEndereco.Cep, LEndereco.Id);
end;

procedure TfrmCaCliente.cbxNaturezaChange(Sender: TObject);
begin
  AtualizarRotulos;
end;

procedure TfrmCaCliente.edtCepChange(Sender: TObject);
var
  LIndice: Integer;
  LEndereco: TEndereco;
  LCep: string;
begin
  if FAtualizandoTela then
    Exit;
  LIndice := lstEnderecos.ItemIndex;
  if LIndice < 0 then
    Exit;

  LEndereco := FEnderecos[LIndice];
  LCep := TTexto.SomenteDigitos(edtCep.Text);
  if LCep = LEndereco.Cep then
    Exit;

  LEndereco.Cep := LCep;
  LEndereco.Integracao := nil;
  FAtualizandoTela := True;
  try
    lstEnderecos.Items[LIndice] := DescreverEndereco(LEndereco);
    lstEnderecos.ItemIndex := LIndice;
  finally
    FAtualizandoTela := False;
  end;
end;

procedure TfrmCaCliente.edtCepKeyPress(Sender: TObject; var Key: Char);
begin
  if Key = #13 then
  begin
    Key := #0;
    btnSalvarClick(Sender);
  end;
end;

procedure TfrmCaCliente.btnNovoEnderecoClick(Sender: TObject);
begin
  AdicionarEnderecoEmBranco;
  edtCep.SetFocus;
end;

procedure TfrmCaCliente.btnRemoverEnderecoClick(Sender: TObject);
var
  LIndice: Integer;
begin
  LIndice := lstEnderecos.ItemIndex;
  if LIndice < 0 then
    Exit;
  FEnderecos.Delete(LIndice);
  AtualizarListaEnderecos(Min(LIndice, FEnderecos.Count - 1));
end;

procedure TfrmCaCliente.lstEnderecosClick(Sender: TObject);
begin
  if not FAtualizandoTela then
    SelecionarEndereco(lstEnderecos.ItemIndex);
end;

procedure TfrmCaCliente.DefinirSalvando(ASalvando: Boolean);
begin
  FSalvando := ASalvando;
  btnSalvar.Enabled := not ASalvando;
  btnCancelar.Enabled := not ASalvando;
  grpEnderecos.Enabled := not ASalvando;
  if ASalvando then
  begin
    btnSalvar.Caption := 'Salvando';
    Screen.Cursor := crAppStart;
  end
  else
  begin
    btnSalvar.Caption := 'Salvar';
    Screen.Cursor := crDefault;
  end;
end;

procedure TfrmCaCliente.btnSalvarClick(Sender: TObject);
var
  LPessoa: TPessoa;
  LInconsistencias: TArray<string>;
begin
  if FSalvando then
    Exit;

  LPessoa := TPessoa.Create;
  try
    GravarEm(LPessoa);
    TPessoaValidador.Normalizar(LPessoa);
    LInconsistencias := TPessoaValidador.Inconsistencias(LPessoa);
  except
    LPessoa.Free;
    raise;
  end;
  if Length(LInconsistencias) > 0 then
  begin
    LPessoa.Free;
    TMensagem.Avisar('Corrija os dados antes de salvar:' + sLineBreak + sLineBreak + '- ' +
      string.Join(sLineBreak + '- ', LInconsistencias));
    Exit;
  end;

  DefinirSalvando(True);
  TAssincrono.ExecutarAcao(
    procedure
    begin
      try
        if LPessoa.EhNova then
          FServidor.Inserir(LPessoa)
        else
          FServidor.Atualizar(LPessoa);
      finally
        LPessoa.Free;
      end;
    end,
    procedure
    begin
      DefinirSalvando(False);
      ModalResult := mrOk;
    end,
    procedure(const AMensagem: string)
    begin
      DefinirSalvando(False);
      TMensagem.Avisar(AMensagem);
    end);
end;

end.
