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
    object btnOlustur: TButton
      AlignWithMargins = True
      Left = 8
      Top = 8
      Width = 80
      Height = 34
      Margins.Left = 8
      Margins.Top = 8
      Margins.Right = 4
      Margins.Bottom = 10
      Align = alLeft
      Constraints.MinWidth = 80
      TabOrder = 3
      OnClick = btnOlusturClick
    end
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
      Width = 226
      Height = 25
      TabOrder = 1
    end
    object btnSunucular: TButton
      Left = 244
      Top = 84
      Width = 108
      Height = 27
      Constraints.MinWidth = 108
      TabOrder = 9
      OnClick = btnSunucularClick
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
      DropDownCount = 16
      TabOrder = 7
      Items.Strings = (
        'WIN1254'
        'UTF8'
        'NONE'
        'WIN1252'
        'ISO8859_9'
        'WIN1250'
        'WIN1251'
        'WIN1253'
        'WIN1255'
        'WIN1256'
        'WIN1257'
        'WIN1258'
        'ISO8859_1'
        'ISO8859_2'
        'ISO8859_3'
        'ISO8859_4'
        'ISO8859_5'
        'ISO8859_6'
        'ISO8859_7'
        'ISO8859_8'
        'ISO8859_13'
        'ASCII'
        'OCTETS'
        'UNICODE_FSS'
        'DOS437'
        'DOS737'
        'DOS775'
        'DOS850'
        'DOS852'
        'DOS857'
        'DOS858'
        'DOS860'
        'DOS861'
        'DOS862'
        'DOS863'
        'DOS864'
        'DOS865'
        'DOS866'
        'DOS869'
        'KOI8R'
        'KOI8U'
        'CYRL'
        'TIS620'
        'BIG_5'
        'GB_2312'
        'GBK'
        'GB18030'
        'EUCJ_0208'
        'SJIS_0208'
        'KSC_5601'
        'NEXT')
    end
    object btnAlgila: TButton
      Left = 244
      Top = 246
      Width = 100
      Height = 27
      Constraints.MinWidth = 100
      TabOrder = 8
      OnClick = btnAlgilaClick
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
