object frmBaglanti: TfrmBaglanti
  Left = 0
  Top = 0
  BorderStyle = bsDialog
  ClientHeight = 540
  ClientWidth = 480
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -13
  Font.Name = 'Segoe UI'
  Font.Style = []
  Position = poOwnerFormCenter
  OnCreate = FormCreate
  object pnlAlt: TPanel
    Left = 0
    Top = 488
    Width = 480
    Height = 52
    Align = alBottom
    BevelOuter = bvNone
    TabOrder = 2
    object btnKapat: TButton
      AlignWithMargins = True
      Left = 392
      Top = 8
      Width = 80
      Height = 34
      Margins.Left = 4
      Margins.Top = 8
      Margins.Right = 8
      Margins.Bottom = 10
      Align = alRight
      Constraints.MinWidth = 80
      TabOrder = 2
      OnClick = btnKapatClick
    end
    object btnBaglan: TButton
      AlignWithMargins = True
      Left = 308
      Top = 8
      Width = 80
      Height = 34
      Margins.Left = 4
      Margins.Top = 8
      Margins.Right = 4
      Margins.Bottom = 10
      Align = alRight
      Constraints.MinWidth = 80
      Default = True
      TabOrder = 1
      OnClick = btnBaglanClick
    end
    object btnKaydet: TButton
      AlignWithMargins = True
      Left = 224
      Top = 8
      Width = 80
      Height = 34
      Margins.Left = 4
      Margins.Top = 8
      Margins.Right = 4
      Margins.Bottom = 10
      Align = alRight
      Constraints.MinWidth = 80
      TabOrder = 0
      OnClick = btnKaydetClick
    end
  end
  object pnlHata: TPanel
    Left = 0
    Top = 338
    Width = 480
    Height = 150
    Align = alBottom
    BevelOuter = bvNone
    TabOrder = 2
    Visible = False
    object lblHata: TLabel
      AlignWithMargins = True
      Left = 12
      Top = 4
      Width = 456
      Height = 17
      Margins.Left = 12
      Margins.Top = 4
      Margins.Right = 12
      Margins.Bottom = 4
      Align = alTop
      Font.Color = clMaroon
      ParentFont = False
      WordWrap = True
    end
    object btnAyrinti: TButton
      AlignWithMargins = True
      Left = 12
      Top = 28
      Width = 90
      Height = 28
      Constraints.MinWidth = 90
      TabOrder = 0
      OnClick = btnAyrintiClick
    end
    object memAyrinti: TMemo
      AlignWithMargins = True
      Left = 12
      Top = 64
      Width = 456
      Height = 80
      Margins.Left = 12
      Margins.Right = 12
      Margins.Bottom = 6
      Align = alBottom
      ReadOnly = True
      ScrollBars = ssVertical
      TabOrder = 1
      Visible = False
    end
  end
  object pnlSag: TPanel
    Left = 0
    Top = 0
    Width = 480
    Height = 338
    Align = alClient
    BevelOuter = bvNone
    TabOrder = 1
    object lblAd: TLabel
      Left = 12
      Top = 12
      Width = 3
      Height = 17
    end
    object edtAd: TEdit
      Left = 12
      Top = 31
      Width = 456
      Height = 25
      TabOrder = 0
    end
    object lblSunucu: TLabel
      Left = 12
      Top = 66
      Width = 3
      Height = 17
    end
    object edtSunucu: TEdit
      Left = 12
      Top = 85
      Width = 340
      Height = 25
      TabOrder = 1
    end
    object lblPort: TLabel
      Left = 364
      Top = 66
      Width = 3
      Height = 17
    end
    object edtPort: TEdit
      Left = 364
      Top = 85
      Width = 104
      Height = 25
      NumbersOnly = True
      TabOrder = 2
    end
    object lblYol: TLabel
      Left = 12
      Top = 120
      Width = 3
      Height = 17
    end
    object edtYol: TEdit
      Left = 12
      Top = 139
      Width = 416
      Height = 25
      TabOrder = 3
    end
    object btnGozat: TButton
      Left = 436
      Top = 138
      Width = 32
      Height = 27
      Caption = '...'
      TabOrder = 4
      OnClick = btnGozatClick
    end
    object lblKullanici: TLabel
      Left = 12
      Top = 174
      Width = 3
      Height = 17
    end
    object edtKullanici: TEdit
      Left = 12
      Top = 193
      Width = 220
      Height = 25
      TabOrder = 5
    end
    object lblSifre: TLabel
      Left = 248
      Top = 174
      Width = 3
      Height = 17
    end
    object edtSifre: TEdit
      Left = 248
      Top = 193
      Width = 220
      Height = 25
      PasswordChar = '*'
      TabOrder = 6
    end
    object lblKarakter: TLabel
      Left = 12
      Top = 228
      Width = 3
      Height = 17
    end
    object cmbKarakter: TComboBox
      Left = 12
      Top = 247
      Width = 220
      Height = 25
      TabOrder = 7
      Items.Strings = (
        'WIN1254'
        'UTF8'
        'NONE'
        'WIN1252'
        'ISO8859_9')
    end
    object chkSifreKaydet: TCheckBox
      Left = 12
      Top = 288
      Width = 456
      Height = 21
      TabOrder = 8
    end
  end
  object dlgAc: TOpenDialog
    Left = 400
    Top = 20
  end
end
