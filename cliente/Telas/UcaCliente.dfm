object frmCaCliente: TfrmCaCliente
  Left = 0
  Top = 0
  BorderStyle = bsDialog
  Caption = 'Cliente'
  ClientHeight = 436
  ClientWidth = 520
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  Position = poOwnerFormCenter
  ShowHint = True
  OnCloseQuery = FormCloseQuery
  OnCreate = FormCreate
  OnDestroy = FormDestroy
  TextHeight = 15
  object lblNatureza: TLabel
    Left = 16
    Top = 16
    Width = 50
    Height = 15
    Caption = 'Natureza'
  end
  object lblDocumento: TLabel
    Left = 180
    Top = 16
    Width = 21
    Height = 15
    Caption = 'CPF'
  end
  object lblPrimeiroNome: TLabel
    Left = 16
    Top = 68
    Width = 33
    Height = 15
    Caption = 'Nome'
  end
  object lblSegundoNome: TLabel
    Left = 16
    Top = 120
    Width = 60
    Height = 15
    Caption = 'Sobrenome'
  end
  object cbxNatureza: TComboBox
    Left = 16
    Top = 34
    Width = 150
    Height = 23
    Style = csDropDownList
    TabOrder = 0
    OnChange = cbxNaturezaChange
    Items.Strings = (
      'F'#237'sica'
      'Jur'#237'dica')
  end
  object edtDocumento: TEdit
    Left = 180
    Top = 34
    Width = 324
    Height = 23
    MaxLength = 18
    TabOrder = 1
  end
  object edtPrimeiroNome: TEdit
    Left = 16
    Top = 86
    Width = 488
    Height = 23
    MaxLength = 100
    TabOrder = 2
  end
  object edtSegundoNome: TEdit
    Left = 16
    Top = 138
    Width = 488
    Height = 23
    MaxLength = 100
    TabOrder = 3
  end
  object grpEnderecos: TGroupBox
    Left = 16
    Top = 176
    Width = 488
    Height = 204
    Caption = ' Endere'#231'os (ao menos um) '
    TabOrder = 4
    object lblCep: TLabel
      Left = 12
      Top = 24
      Width = 172
      Height = 15
      Caption = 'CEP do endere'#231'o selecionado'
    end
    object edtCep: TEdit
      Left = 12
      Top = 42
      Width = 120
      Height = 23
      Hint = 'Digite o CEP; ele '#233' aplicado ao endere'#231'o selecionado na lista'
      MaxLength = 9
      TabOrder = 0
      OnChange = edtCepChange
      OnKeyPress = edtCepKeyPress
    end
    object btnNovoEndereco: TButton
      Left = 140
      Top = 40
      Width = 120
      Height = 27
      Caption = 'Novo endere'#231'o'
      TabOrder = 1
      OnClick = btnNovoEnderecoClick
    end
    object btnRemoverEndereco: TButton
      Left = 266
      Top = 40
      Width = 120
      Height = 27
      Caption = 'Remover endere'#231'o'
      Enabled = False
      TabOrder = 2
      OnClick = btnRemoverEnderecoClick
    end
    object lstEnderecos: TListBox
      Left = 12
      Top = 78
      Width = 464
      Height = 114
      ItemHeight = 15
      TabOrder = 3
      OnClick = lstEnderecosClick
    end
  end
  object btnSalvar: TButton
    Left = 318
    Top = 394
    Width = 90
    Height = 30
    Caption = 'Salvar'
    TabOrder = 5
    OnClick = btnSalvarClick
  end
  object btnCancelar: TButton
    Left = 414
    Top = 394
    Width = 90
    Height = 30
    Cancel = True
    Caption = 'Cancelar'
    ModalResult = 2
    TabOrder = 6
  end
end
