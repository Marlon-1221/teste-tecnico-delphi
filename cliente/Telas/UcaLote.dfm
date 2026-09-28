object frmCaLote: TfrmCaLote
  Left = 0
  Top = 0
  BorderStyle = bsDialog
  Caption = 'Inclus'#227'o de clientes em lote'
  ClientHeight = 520
  ClientWidth = 640
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  Position = poOwnerFormCenter
  OnCloseQuery = FormCloseQuery
  TextHeight = 15
  object lblResultado: TLabel
    Left = 16
    Top = 264
    Width = 57
    Height = 15
    Caption = 'Resultado'
  end
  object grpGerar: TGroupBox
    Left = 16
    Top = 12
    Width = 608
    Height = 76
    Caption = ' Gerar clientes de teste '
    TabOrder = 0
    object lblQuantidade: TLabel
      Left = 16
      Top = 34
      Width = 65
      Height = 15
      Caption = 'Quantidade:'
    end
    object edtQuantidade: TEdit
      Left = 92
      Top = 30
      Width = 90
      Height = 23
      NumbersOnly = True
      TabOrder = 0
      Text = '50000'
    end
    object btnGerar: TButton
      Left = 196
      Top = 27
      Width = 130
      Height = 30
      Caption = 'Gerar e enviar'
      TabOrder = 1
      OnClick = btnGerarClick
    end
  end
  object grpPlanilha: TGroupBox
    Left = 16
    Top = 100
    Width = 608
    Height = 148
    Caption = ' Importar planilha Excel (.xlsx) '
    TabOrder = 1
    object lblArquivo: TLabel
      Left = 16
      Top = 26
      Width = 43
      Height = 15
      Caption = 'Arquivo'
    end
    object lblModelo: TLabel
      Left = 16
      Top = 110
      Width = 576
      Height = 30
      AutoSize = False
      Caption =
        'Modelo: modelos\clientes_modelo.xlsx (colunas Natureza, CPF/CNPJ, ' +
        'Nome / Raz'#227'o social, Sobrenome / Nome fantasia e CEP; v'#225'rios CEP' +
        's separados por ponto e v'#237'rgula).'
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clGrayText
      Font.Height = -12
      Font.Name = 'Segoe UI'
      Font.Style = []
      ParentFont = False
      WordWrap = True
    end
    object edtArquivo: TEdit
      Left = 16
      Top = 44
      Width = 440
      Height = 23
      ReadOnly = True
      TabOrder = 0
    end
    object btnSelecionar: TButton
      Left = 462
      Top = 41
      Width = 130
      Height = 30
      Caption = 'Selecionar arquivo'
      TabOrder = 1
      OnClick = btnSelecionarClick
    end
    object btnImportar: TButton
      Left = 462
      Top = 76
      Width = 130
      Height = 30
      Caption = 'Importar'
      TabOrder = 2
      OnClick = btnImportarClick
    end
  end
  object mmoResultado: TMemo
    Left = 16
    Top = 284
    Width = 608
    Height = 184
    ReadOnly = True
    ScrollBars = ssVertical
    TabOrder = 2
  end
  object btnFechar: TButton
    Left = 534
    Top = 478
    Width = 90
    Height = 30
    Cancel = True
    Caption = 'Fechar'
    ModalResult = 2
    TabOrder = 3
  end
  object dlgArquivo: TOpenDialog
    DefaultExt = 'xlsx'
    Filter = 'Planilha Excel (*.xlsx)|*.xlsx'
    Options = [ofHideReadOnly, ofFileMustExist, ofEnableSizing]
    Title = 'Selecionar planilha de clientes'
    Left = 560
    Top = 264
  end
end
