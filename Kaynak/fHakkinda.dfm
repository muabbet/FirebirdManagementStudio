object frmHakkinda: TfrmHakkinda
  Left = 0
  Top = 0
  BorderStyle = bsDialog
  Caption = 'frmHakkinda'
  ClientHeight = 330
  ClientWidth = 560
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -13
  Font.Name = 'Segoe UI'
  Font.Style = []
  Position = poOwnerFormCenter
  object lblAd: TLabel
    Left = 24
    Top = 20
    Width = 512
    Height = 32
    AutoSize = False
    Font.Charset = DEFAULT_CHARSET
    Font.Color = clWindowText
    Font.Height = -24
    Font.Name = 'Segoe UI Semibold'
    Font.Style = []
    ParentFont = False
  end
  object lblSurumBaslik: TLabel
    Left = 24
    Top = 70
    Width = 300
    Height = 24
    AutoSize = False
    Font.Charset = DEFAULT_CHARSET
    Font.Color = clWindowText
    Font.Height = -17
    Font.Name = 'Segoe UI Semibold'
    Font.Style = []
    ParentFont = False
  end
  object lblSurumEtiket: TLabel
    Left = 24
    Top = 104
    Width = 90
    Height = 17
    AutoSize = False
  end
  object lblSurumDeger: TLabel
    Left = 120
    Top = 104
    Width = 200
    Height = 17
    AutoSize = False
  end
  object lblPlatformEtiket: TLabel
    Left = 24
    Top = 128
    Width = 90
    Height = 17
    AutoSize = False
  end
  object lblPlatformDeger: TLabel
    Left = 120
    Top = 128
    Width = 200
    Height = 17
    AutoSize = False
  end
  object lblYetkiEtiket: TLabel
    Left = 24
    Top = 152
    Width = 90
    Height = 17
    AutoSize = False
  end
  object lblYetkiDeger: TLabel
    Left = 120
    Top = 152
    Width = 200
    Height = 17
    AutoSize = False
  end
  object btnKopyala: TButton
    Left = 380
    Top = 100
    Width = 156
    Height = 30
    TabOrder = 0
    OnClick = btnKopyalaClick
  end
  object lblLisansBaslik: TLabel
    Left = 24
    Top = 190
    Width = 300
    Height = 24
    AutoSize = False
    Font.Charset = DEFAULT_CHARSET
    Font.Color = clWindowText
    Font.Height = -17
    Font.Name = 'Segoe UI Semibold'
    Font.Style = []
    ParentFont = False
  end
  object lblLisans: TLabel
    Left = 24
    Top = 222
    Width = 512
    Height = 60
    AutoSize = False
    WordWrap = True
  end
  object pnlAlt: TPanel
    Left = 0
    Top = 286
    Width = 560
    Height = 44
    Align = alBottom
    BevelOuter = bvNone
    TabOrder = 1
    object btnTamam: TButton
      AlignWithMargins = True
      Left = 452
      Top = 6
      Width = 100
      Height = 32
      Margins.Left = 4
      Margins.Top = 6
      Margins.Right = 8
      Margins.Bottom = 6
      Align = alRight
      Cancel = True
      Constraints.MinWidth = 80
      Default = True
      ModalResult = 1
      TabOrder = 0
    end
  end
end
