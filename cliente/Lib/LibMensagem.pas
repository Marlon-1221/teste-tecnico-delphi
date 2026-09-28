unit LibMensagem;

interface

uses
  System.UITypes;

type
  TResposta = (rsSim, rsNao, rsCancelar);

  TMensagem = class abstract
  private
    class function Exibir(const ATexto: string; ATipo: TMsgDlgType; ABotoes: TMsgDlgButtons;
      APadrao: TMsgDlgBtn): Integer; static;
  public
    class procedure Informar(const ATexto: string); static;
    class procedure Avisar(const ATexto: string); static;
    class procedure Erro(const ATexto: string); static;
    class function Confirmar(const ATexto: string): Boolean; static;
    class function Perguntar(const ATexto: string): TResposta; static;
    class function LerNumero(const ATitulo, ARotulo: string; var AValor: string): Boolean; static;
  end;

implementation

uses
  System.SysUtils,
  System.Classes,
  Vcl.Controls,
  Vcl.Forms,
  Vcl.StdCtrls,
  Vcl.Dialogs;

const
  TITULOS: array[TMsgDlgType] of string = ('Atenção', 'Erro', 'Informação', 'Confirmação', 'Cadastro de Clientes');
  BOTOES_ORIGINAIS: array[0..3] of string = ('Yes', 'No', 'OK', 'Cancel');
  BOTOES_TRADUZIDOS: array[0..3] of string = ('Sim', 'Não', 'OK', 'Cancelar');

class function TMensagem.Exibir(const ATexto: string; ATipo: TMsgDlgType; ABotoes: TMsgDlgButtons;
  APadrao: TMsgDlgBtn): Integer;
var
  LFormulario: TForm;
  LComponente: TComponent;
  I: Integer;
begin
  LFormulario := CreateMessageDialog(ATexto, ATipo, ABotoes, APadrao);
  try
    LFormulario.Caption := TITULOS[ATipo];
    for I := Low(BOTOES_ORIGINAIS) to High(BOTOES_ORIGINAIS) do
    begin
      LComponente := LFormulario.FindComponent(BOTOES_ORIGINAIS[I]);
      if LComponente is TButton then
        TButton(LComponente).Caption := BOTOES_TRADUZIDOS[I];
    end;
    Result := LFormulario.ShowModal;
  finally
    LFormulario.Free;
  end;
end;

class procedure TMensagem.Informar(const ATexto: string);
begin
  Exibir(ATexto, mtInformation, [mbOK], mbOK);
end;

class procedure TMensagem.Avisar(const ATexto: string);
begin
  Exibir(ATexto, mtWarning, [mbOK], mbOK);
end;

class procedure TMensagem.Erro(const ATexto: string);
begin
  Exibir(ATexto, mtError, [mbOK], mbOK);
end;

class function TMensagem.Confirmar(const ATexto: string): Boolean;
begin
  Result := Exibir(ATexto, mtConfirmation, [mbYes, mbNo], mbNo) = mrYes;
end;

class function TMensagem.Perguntar(const ATexto: string): TResposta;
begin
  case Exibir(ATexto, mtConfirmation, [mbYes, mbNo, mbCancel], mbYes) of
    mrYes:
      Result := rsSim;
    mrNo:
      Result := rsNao;
  else
    Result := rsCancelar;
  end;
end;

class function TMensagem.LerNumero(const ATitulo, ARotulo: string; var AValor: string): Boolean;
var
  LFormulario: TForm;
  LRotulo: TLabel;
  LCampo: TEdit;
  LConfirmar, LCancelar: TButton;
begin
  LFormulario := TForm.CreateNew(nil);
  try
    LFormulario.Caption := ATitulo;
    LFormulario.BorderStyle := bsDialog;
    LFormulario.Position := poScreenCenter;
    LFormulario.Font.Name := 'Segoe UI';
    LFormulario.Font.Height := -12;
    LFormulario.ClientWidth := 340;
    LFormulario.ClientHeight := 124;

    LRotulo := TLabel.Create(LFormulario);
    LRotulo.Parent := LFormulario;
    LRotulo.SetBounds(16, 16, 308, 15);
    LRotulo.Caption := ARotulo;

    LCampo := TEdit.Create(LFormulario);
    LCampo.Parent := LFormulario;
    LCampo.SetBounds(16, 38, 308, 23);
    LCampo.NumbersOnly := True;
    LCampo.Text := AValor;

    LConfirmar := TButton.Create(LFormulario);
    LConfirmar.Parent := LFormulario;
    LConfirmar.SetBounds(148, 80, 85, 30);
    LConfirmar.Caption := 'Confirmar';
    LConfirmar.Default := True;
    LConfirmar.ModalResult := mrOk;

    LCancelar := TButton.Create(LFormulario);
    LCancelar.Parent := LFormulario;
    LCancelar.SetBounds(239, 80, 85, 30);
    LCancelar.Caption := 'Cancelar';
    LCancelar.Cancel := True;
    LCancelar.ModalResult := mrCancel;

    LFormulario.ActiveControl := LCampo;
    Result := LFormulario.ShowModal = mrOk;
    if Result then
      AValor := LCampo.Text;
  finally
    LFormulario.Free;
  end;
end;

end.
