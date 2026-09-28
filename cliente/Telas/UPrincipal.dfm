object frmPrincipal: TfrmPrincipal
  Left = 0
  Top = 0
  Caption = 'Cadastro de Clientes'
  ClientHeight = 460
  ClientWidth = 900
  Color = clBtnFace
  Constraints.MinHeight = 400
  Constraints.MinWidth = 760
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  Menu = mnuPrincipal
  Position = poScreenCenter
  ShowHint = True
  OnCreate = FormCreate
  TextHeight = 15
  object pnlCentro: TPanel
    Left = 0
    Top = 0
    Width = 900
    Height = 441
    Align = alClient
    BevelOuter = bvNone
    TabOrder = 0
    object lblTitulo: TLabel
      Left = 32
      Top = 40
      Width = 320
      Height = 37
      Caption = 'Cadastro de Clientes'
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clWindowText
      Font.Height = -27
      Font.Name = 'Segoe UI'
      Font.Style = [fsBold]
      ParentFont = False
    end
    object lblSubtitulo: TLabel
      Left = 32
      Top = 88
      Width = 520
      Height = 17
      Caption =
        'Teste t'#233'cnico Delphi  |  3 camadas, REST/JSON, FireDAC e Threads' +
        '. Use o menu para acessar as telas e os processos.'
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clGrayText
      Font.Height = -13
      Font.Name = 'Segoe UI'
      Font.Style = []
      ParentFont = False
    end
    object grpProcessos: TGroupBox
      Left = 32
      Top = 300
      Width = 836
      Height = 116
      Anchors = [akLeft, akRight, akBottom]
      Caption = ' Processos '
      TabOrder = 0
      object lblLote: TLabel
        Left = 16
        Top = 28
        Width = 804
        Height = 15
        Anchors = [akLeft, akTop, akRight]
        AutoSize = False
        Caption = 'Inclus'#227'o em lote: nenhuma execu'#231#227'o nesta sess'#227'o.'
      end
      object lblCep: TLabel
        Left = 16
        Top = 56
        Width = 804
        Height = 15
        Anchors = [akLeft, akTop, akRight]
        AutoSize = False
        Caption = 'Atualiza'#231#227'o de endere'#231'os: consultando andamento'
      end
      object pbCep: TProgressBar
        Left = 16
        Top = 80
        Width = 804
        Height = 17
        Anchors = [akLeft, akTop, akRight]
        TabOrder = 0
      end
    end
  end
  object stbRodape: TStatusBar
    Left = 0
    Top = 441
    Width = 900
    Height = 19
    Panels = <
      item
        Width = 560
      end
      item
        Alignment = taCenter
        Width = 110
      end
      item
        Width = 200
      end>
  end
  object mnuPrincipal: TMainMenu
    Left = 776
    Top = 32
    object mniCadastros: TMenuItem
      Caption = 'Cadastros'
      object mniClientes: TMenuItem
        Caption = 'Clientes'
        OnClick = mniClientesClick
      end
    end
    object mniProcessos: TMenuItem
      Caption = 'Processos'
      object mniInclusaoLote: TMenuItem
        Caption = 'Inclus'#227'o de clientes em lote'
        OnClick = mniInclusaoLoteClick
      end
      object mniAtualizarCeps: TMenuItem
        Caption = 'Atualizar endere'#231'os pelo CEP (ViaCEP)'
        OnClick = mniAtualizarCepsClick
      end
    end
    object mniSair: TMenuItem
      Caption = 'Sair'
      OnClick = mniSairClick
    end
  end
  object tmrStatusCep: TTimer
    Enabled = False
    OnTimer = tmrStatusCepTimer
    Left = 776
    Top = 96
  end
end
