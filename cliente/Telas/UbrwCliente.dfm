object frmBrwCliente: TfrmBrwCliente
  Left = 0
  Top = 0
  Caption = 'Clientes'
  ClientHeight = 600
  ClientWidth = 1200
  Color = clBtnFace
  Constraints.MinHeight = 400
  Constraints.MinWidth = 800
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  Position = poOwnerFormCenter
  OnCreate = FormCreate
  OnDestroy = FormDestroy
  TextHeight = 15
  object pnlAcoes: TPanel
    Left = 0
    Top = 0
    Width = 1200
    Height = 49
    Align = alTop
    BevelOuter = bvNone
    TabOrder = 0
    object btnNovo: TButton
      Left = 12
      Top = 10
      Width = 80
      Height = 30
      Caption = 'Novo'
      TabOrder = 0
      OnClick = btnNovoClick
    end
    object btnEditar: TButton
      Left = 98
      Top = 10
      Width = 80
      Height = 30
      Caption = 'Editar'
      TabOrder = 1
      OnClick = btnEditarClick
    end
    object btnExcluir: TButton
      Left = 184
      Top = 10
      Width = 80
      Height = 30
      Caption = 'Excluir'
      TabOrder = 2
      OnClick = btnExcluirClick
    end
    object btnRecarregar: TButton
      Left = 270
      Top = 10
      Width = 90
      Height = 30
      Caption = 'Recarregar'
      TabOrder = 3
      OnClick = btnRecarregarClick
    end
    object lblBusca: TLabel
      Left = 384
      Top = 17
      Width = 37
      Height = 15
      Caption = 'Buscar'
    end
    object edtBusca: TEdit
      Left = 428
      Top = 13
      Width = 420
      Height = 23
      TabOrder = 4
      TextHint = 'Nome, raz'#227'o social, CPF/CNPJ, CEP ou cidade'
      OnChange = edtBuscaChange
      OnKeyPress = edtBuscaKeyPress
    end
    object btnLimparBusca: TButton
      Left = 856
      Top = 10
      Width = 80
      Height = 30
      Caption = 'Limpar'
      TabOrder = 5
      OnClick = btnLimparBuscaClick
    end
  end
  object tmrBusca: TTimer
    Enabled = False
    Interval = 500
    OnTimer = tmrBuscaTimer
    Left = 1120
    Top = 96
  end
  object lvClientes: TListView
    Left = 0
    Top = 49
    Width = 1200
    Height = 532
    Align = alClient
    Columns = <
      item
        Caption = 'ID'
        Width = 70
      end
      item
        Caption = 'Natureza'
        Width = 70
      end
      item
        Caption = 'CPF / CNPJ'
        Width = 130
      end
      item
        Caption = 'Nome / Raz'#227'o social'
        Width = 190
      end
      item
        Caption = 'Sobrenome / Fantasia'
        Width = 170
      end
      item
        Caption = 'Registro'
        Width = 80
      end
      item
        Caption = 'CEP'
        Width = 90
      end
      item
        Caption = 'Logradouro'
        Width = 190
      end
      item
        Caption = 'Bairro'
        Width = 90
      end
      item
        Caption = 'Cidade/UF'
        Width = 130
      end>
    GridLines = True
    HideSelection = False
    OwnerData = True
    ReadOnly = True
    RowSelect = True
    TabOrder = 1
    ViewStyle = vsReport
    OnData = lvClientesData
    OnDblClick = lvClientesDblClick
  end
  object stbStatus: TStatusBar
    Left = 0
    Top = 581
    Width = 1200
    Height = 19
    Panels = <>
    SimplePanel = True
  end
end
