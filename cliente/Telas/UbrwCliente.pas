unit UbrwCliente;

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
  Vcl.ExtCtrls,
  Vcl.ComCtrls,
  UPessoa,
  UPagina,
  LibPessoa;

type
  TfrmBrwCliente = class(TForm)
    pnlAcoes: TPanel;
    btnNovo: TButton;
    btnEditar: TButton;
    btnExcluir: TButton;
    btnRecarregar: TButton;
    lblBusca: TLabel;
    edtBusca: TEdit;
    btnLimparBusca: TButton;
    tmrBusca: TTimer;
    lvClientes: TListView;
    stbStatus: TStatusBar;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure btnNovoClick(Sender: TObject);
    procedure btnEditarClick(Sender: TObject);
    procedure btnExcluirClick(Sender: TObject);
    procedure btnRecarregarClick(Sender: TObject);
    procedure lvClientesData(Sender: TObject; Item: TListItem);
    procedure lvClientesDblClick(Sender: TObject);
    procedure edtBuscaChange(Sender: TObject);
    procedure edtBuscaKeyPress(Sender: TObject; var Key: Char);
    procedure btnLimparBuscaClick(Sender: TObject);
    procedure tmrBuscaTimer(Sender: TObject);
  private const
    TAMANHO_BLOCO = 500;
    TEXTO_CARREGANDO = 'carregando';
  private
    FServidor: IAcessoServidor;
    FBlocos: TObjectDictionary<Integer, TPagina<TPessoa>>;
    FBlocosSolicitados: TDictionary<Integer, Boolean>;
    FGeracao: Integer;
    FTotalRegistros: Int64;
    FBusca: string;
    procedure AplicarBusca;
    procedure SolicitarBloco(ABloco: Integer);
    procedure ReceberBloco(ABloco: Integer; APagina: TPagina<TPessoa>);
    procedure DefinirTotal(ATotal: Int64);
    procedure PreencherItem(AItem: TListItem; APessoa: TPessoa);
    function PessoaDoIndice(AIndice: Integer): TPessoa;
    function IdSelecionado: Int64;
    procedure EditarCliente(AId: Int64);
    procedure AposSalvar;
    procedure ExibirFalha(const AMensagem: string);
  public
    procedure Abrir(const AServidor: IAcessoServidor);
    procedure Recarregar;
  end;

implementation

uses
  LibTexto,
  LibAssincrono,
  LibMensagem,
  UcaCliente;

{$R *.dfm}

procedure TfrmBrwCliente.FormCreate(Sender: TObject);
begin
  FBlocos := TObjectDictionary<Integer, TPagina<TPessoa>>.Create([doOwnsValues]);
  FBlocosSolicitados := TDictionary<Integer, Boolean>.Create;
end;

procedure TfrmBrwCliente.FormDestroy(Sender: TObject);
begin
  FBlocosSolicitados.Free;
  FBlocos.Free;
end;

procedure TfrmBrwCliente.Abrir(const AServidor: IAcessoServidor);
var
  LPrimeiraVez: Boolean;
begin
  LPrimeiraVez := FServidor = nil;
  FServidor := AServidor;
  Show;
  BringToFront;
  if LPrimeiraVez then
    Recarregar;
end;

procedure TfrmBrwCliente.Recarregar;
begin
  if FServidor = nil then
    Exit;
  Inc(FGeracao);
  FBlocos.Clear;
  FBlocosSolicitados.Clear;
  stbStatus.SimpleText := 'Carregando clientes';
  SolicitarBloco(0);
  lvClientes.Invalidate;
end;

procedure TfrmBrwCliente.SolicitarBloco(ABloco: Integer);
var
  LGeracao: Integer;
  LBusca: string;
begin
  if FBlocos.ContainsKey(ABloco) or FBlocosSolicitados.ContainsKey(ABloco) then
    Exit;
  FBlocosSolicitados.Add(ABloco, True);
  LGeracao := FGeracao;
  LBusca := FBusca;

  TAssincrono.Executar<TPagina<TPessoa>>(
    function: TPagina<TPessoa>
    begin
      Result := FServidor.Listar(ABloco + 1, TAMANHO_BLOCO, LBusca);
    end,
    procedure(APagina: TPagina<TPessoa>)
    begin
      if LGeracao <> FGeracao then
      begin
        APagina.Free;
        Exit;
      end;
      ReceberBloco(ABloco, APagina);
    end,
    procedure(const AMensagem: string)
    begin
      if LGeracao <> FGeracao then
        Exit;
      FBlocosSolicitados.Remove(ABloco);
      ExibirFalha(AMensagem);
    end);
end;

procedure TfrmBrwCliente.ReceberBloco(ABloco: Integer; APagina: TPagina<TPessoa>);
begin
  FBlocosSolicitados.Remove(ABloco);
  FBlocos.AddOrSetValue(ABloco, APagina);
  DefinirTotal(APagina.TotalRegistros);
  lvClientes.Invalidate;
end;

procedure TfrmBrwCliente.DefinirTotal(ATotal: Int64);
begin
  if ATotal <> FTotalRegistros then
  begin
    FTotalRegistros := ATotal;
    lvClientes.Items.Count := Integer(ATotal);
  end;
  if FBusca = '' then
    stbStatus.SimpleText := Format('%s clientes  |  role a lista para ver todos (carregados em blocos de %d)',
      [FormatFloat('#,##0', FTotalRegistros), TAMANHO_BLOCO])
  else if FTotalRegistros = 0 then
    stbStatus.SimpleText := Format('Nenhum cliente encontrado para "%s"', [FBusca])
  else
    stbStatus.SimpleText := Format('%s clientes encontrados para "%s"', [FormatFloat('#,##0', FTotalRegistros), FBusca]);
end;

procedure TfrmBrwCliente.AplicarBusca;
begin
  tmrBusca.Enabled := False;
  if Trim(edtBusca.Text) = FBusca then
    Exit;
  FBusca := Trim(edtBusca.Text);
  FTotalRegistros := 0;
  lvClientes.Items.Count := 0;
  Recarregar;
end;

procedure TfrmBrwCliente.edtBuscaChange(Sender: TObject);
begin
  tmrBusca.Enabled := False;
  tmrBusca.Enabled := True;
end;

procedure TfrmBrwCliente.edtBuscaKeyPress(Sender: TObject; var Key: Char);
begin
  if Key = #13 then
  begin
    Key := #0;
    AplicarBusca;
  end;
end;

procedure TfrmBrwCliente.tmrBuscaTimer(Sender: TObject);
begin
  AplicarBusca;
end;

procedure TfrmBrwCliente.btnLimparBuscaClick(Sender: TObject);
begin
  edtBusca.Clear;
  AplicarBusca;
  edtBusca.SetFocus;
end;

function TfrmBrwCliente.PessoaDoIndice(AIndice: Integer): TPessoa;
var
  LPagina: TPagina<TPessoa>;
  LPosicao: Integer;
begin
  Result := nil;
  if (AIndice < 0) or not FBlocos.TryGetValue(AIndice div TAMANHO_BLOCO, LPagina) then
    Exit;
  LPosicao := AIndice mod TAMANHO_BLOCO;
  if LPosicao < LPagina.Itens.Count then
    Result := LPagina.Itens[LPosicao];
end;

procedure TfrmBrwCliente.lvClientesData(Sender: TObject; Item: TListItem);
var
  LPessoa: TPessoa;
begin
  LPessoa := PessoaDoIndice(Item.Index);
  if LPessoa <> nil then
    PreencherItem(Item, LPessoa)
  else
  begin
    Item.Caption := '';
    Item.SubItems.Add(TEXTO_CARREGANDO);
    SolicitarBloco(Item.Index div TAMANHO_BLOCO);
  end;
end;

procedure TfrmBrwCliente.PreencherItem(AItem: TListItem; APessoa: TPessoa);
var
  LEndereco: TEndereco;
  LCep: string;
begin
  AItem.Caption := IntToStr(APessoa.Id);
  AItem.SubItems.Add(APessoa.Natureza.Descricao);
  AItem.SubItems.Add(TTexto.FormatarDocumento(APessoa.Documento));
  AItem.SubItems.Add(APessoa.PrimeiroNome);
  AItem.SubItems.Add(APessoa.SegundoNome);
  if APessoa.PossuiDataRegistro then
    AItem.SubItems.Add(FormatDateTime('dd/mm/yyyy', APessoa.DataRegistro))
  else
    AItem.SubItems.Add('');

  if APessoa.Enderecos.Count = 0 then
    Exit;

  LEndereco := APessoa.Enderecos.First;
  LCep := TTexto.FormatarCep(LEndereco.Cep);
  if APessoa.Enderecos.Count > 1 then
    LCep := Format('%s (+%d)', [LCep, APessoa.Enderecos.Count - 1]);
  AItem.SubItems.Add(LCep);
  if LEndereco.PossuiIntegracao then
  begin
    AItem.SubItems.Add(LEndereco.Integracao.Logradouro);
    AItem.SubItems.Add(LEndereco.Integracao.Bairro);
    AItem.SubItems.Add(Format('%s/%s', [LEndereco.Integracao.Cidade, LEndereco.Integracao.Uf]));
  end;
end;

function TfrmBrwCliente.IdSelecionado: Int64;
var
  LPessoa: TPessoa;
begin
  LPessoa := PessoaDoIndice(lvClientes.ItemIndex);
  if LPessoa = nil then
    Result := 0
  else
    Result := LPessoa.Id;
end;

procedure TfrmBrwCliente.ExibirFalha(const AMensagem: string);
begin
  stbStatus.SimpleText := 'Falha na última operação.';
  TMensagem.Erro(AMensagem);
end;

procedure TfrmBrwCliente.btnRecarregarClick(Sender: TObject);
begin
  Recarregar;
end;

procedure TfrmBrwCliente.btnNovoClick(Sender: TObject);
var
  LPessoa: TPessoa;
begin
  LPessoa := TPessoa.Create;
  try
    if TfrmCaCliente.Editar(LPessoa, FServidor) then
      AposSalvar;
  finally
    LPessoa.Free;
  end;
end;

procedure TfrmBrwCliente.btnEditarClick(Sender: TObject);
begin
  if IdSelecionado = 0 then
  begin
    TMensagem.Informar('Selecione um cliente na lista.');
    Exit;
  end;
  EditarCliente(IdSelecionado);
end;

procedure TfrmBrwCliente.lvClientesDblClick(Sender: TObject);
begin
  if IdSelecionado > 0 then
    EditarCliente(IdSelecionado);
end;

procedure TfrmBrwCliente.EditarCliente(AId: Int64);
begin
  stbStatus.SimpleText := Format('Carregando cliente %d', [AId]);
  TAssincrono.Executar<TPessoa>(
    function: TPessoa
    begin
      Result := FServidor.Obter(AId);
    end,
    procedure(APessoa: TPessoa)
    begin
      try
        if TfrmCaCliente.Editar(APessoa, FServidor) then
          AposSalvar;
      finally
        APessoa.Free;
      end;
    end,
    ExibirFalha);
end;

procedure TfrmBrwCliente.AposSalvar;
begin
  Recarregar;
  stbStatus.SimpleText := 'Cliente salvo com sucesso.';
end;

procedure TfrmBrwCliente.btnExcluirClick(Sender: TObject);
var
  LId: Int64;
begin
  LId := IdSelecionado;
  if LId = 0 then
  begin
    TMensagem.Informar('Selecione um cliente na lista.');
    Exit;
  end;
  if not TMensagem.Confirmar(Format('Excluir o cliente %d e todos os seus endereços?', [LId])) then
    Exit;

  stbStatus.SimpleText := Format('Excluindo cliente %d', [LId]);
  TAssincrono.ExecutarAcao(
    procedure
    begin
      FServidor.Excluir(LId);
    end,
    procedure
    begin
      Recarregar;
      stbStatus.SimpleText := Format('Cliente %d excluído.', [LId]);
    end,
    ExibirFalha);
end;

end.
