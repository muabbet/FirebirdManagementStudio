object frmKullaniciDuzenle: TfrmKullaniciDuzenle
  Left = 0
  Top = 0
  BorderStyle = bsDialog
  ClientHeight = 400
  ClientWidth = 440
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -13
  Font.Name = 'Segoe UI'
  Font.Style = []
  Position = poOwnerFormCenter
  object pnlAd: TPanel
    Left = 0
    Top = 0
    Width = 440
    Height = 54
    Align = alTop
    BevelOuter = bvNone
    TabOrder = 0
    object lblAd: TLabel
      Left = 12
      Top = 6
      Width = 3
      Height = 17
    end
    object edtAd: TEdit
      Left = 12
      Top = 24
      Width = 416
      Height = 25
      TabOrder = 0
    end
  end
  object pnlSifre: TPanel
    Left = 0
    Top = 54
    Width = 440
    Height = 54
    Align = alTop
    BevelOuter = bvNone
    TabOrder = 1
    object lblSifre: TLabel
      Left = 12
      Top = 6
      Width = 3
      Height = 17
    end
    object edtSifre: TEdit
      Left = 12
      Top = 24
      Width = 416
      Height = 25
      PasswordChar = '*'
      TabOrder = 0
    end
  end
  object pnlSifre2: TPanel
    Left = 0
    Top = 108
    Width = 440
    Height = 54
    Align = alTop
    BevelOuter = bvNone
    TabOrder = 2
    object lblSifre2: TLabel
      Left = 12
      Top = 6
      Width = 3
      Height = 17
    end
    object edtSifre2: TEdit
      Left = 12
      Top = 24
      Width = 416
      Height = 25
      PasswordChar = '*'
      TabOrder = 0
    end
  end
  object pnlIsim: TPanel
    Left = 0
    Top = 162
    Width = 440
    Height = 54
    Align = alTop
    BevelOuter = bvNone
    TabOrder = 3
    object lblIsim: TLabel
      Left = 12
      Top = 6
      Width = 3
      Height = 17
    end
    object edtIsim: TEdit
      Left = 12
      Top = 24
      Width = 416
      Height = 25
      TabOrder = 0
    end
  end
  object pnlSoyad: TPanel
    Left = 0
    Top = 216
    Width = 440
    Height = 54
    Align = alTop
    BevelOuter = bvNone
    TabOrder = 4
    object lblSoyad: TLabel
      Left = 12
      Top = 6
      Width = 3
      Height = 17
    end
    object edtSoyad: TEdit
      Left = 12
      Top = 24
      Width = 416
      Height = 25
      TabOrder = 0
    end
  end
  object pnlYonetici: TPanel
    Left = 0
    Top = 270
    Width = 440
    Height = 44
    Align = alTop
    BevelOuter = bvNone
    TabOrder = 5
    object chkYonetici: TCheckBox
      Left = 12
      Top = 6
      Width = 416
      Height = 34
      TabOrder = 0
      WordWrap = True
    end
  end
  object pnlAlt: TPanel
    Left = 0
    Top = 348
    Width = 440
    Height = 52
    Align = alBottom
    BevelOuter = bvNone
    TabOrder = 7
    object btnIptal: TButton
      AlignWithMargins = True
      Left = 352
      Top = 8
      Width = 80
      Height = 34
      Margins.Left = 4
      Margins.Top = 8
      Margins.Right = 8
      Margins.Bottom = 10
      Align = alRight
      Cancel = True
      Constraints.MinWidth = 80
      ModalResult = 2
      TabOrder = 1
    end
    object btnTamam: TButton
      AlignWithMargins = True
      Left = 268
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
      TabOrder = 0
      OnClick = btnTamamClick
    end
  end
  object pnlHata: TPanel
    Left = 0
    Top = 208
    Width = 440
    Height = 140
    Align = alBottom
    BevelOuter = bvNone
    TabOrder = 6
    Visible = False
    object lblHata: TLabel
      AlignWithMargins = True
      Left = 12
      Top = 4
      Width = 416
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
      Width = 416
      Height = 70
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
end
