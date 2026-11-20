object frmVeriFark: TfrmVeriFark
  Left = 0
  Top = 0
  BorderStyle = bsDialog
  ClientHeight = 336
  ClientWidth = 580
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -13
  Font.Name = 'Segoe UI'
  Font.Style = []
  Position = poOwnerFormCenter
  object lblKaynak: TLabel
    Left = 12
    Top = 12
    Width = 556
    Height = 17
    AutoSize = False
    Font.Style = [fsBold]
    ParentFont = False
  end
  object cmbKaynakDb: TComboBox
    Left = 12
    Top = 34
    Width = 270
    Height = 25
    Style = csDropDownList
    TabOrder = 0
    OnChange = KaynakDbDegisti
  end
  object cmbKaynakTablo: TComboBox
    Left = 298
    Top = 34
    Width = 270
    Height = 25
    Style = csDropDownList
    TabOrder = 1
    OnChange = SecimDegisti
  end
  object lblHedef: TLabel
    Left = 12
    Top = 74
    Width = 556
    Height = 17
    AutoSize = False
    Font.Style = [fsBold]
    ParentFont = False
  end
  object cmbHedefDb: TComboBox
    Left = 12
    Top = 96
    Width = 270
    Height = 25
    Style = csDropDownList
    TabOrder = 2
    OnChange = HedefDbDegisti
  end
  object cmbHedefTablo: TComboBox
    Left = 298
    Top = 96
    Width = 270
    Height = 25
    Style = csDropDownList
    TabOrder = 3
    OnChange = SecimDegisti
  end
  object chkSil: TCheckBox
    Left = 12
    Top = 134
    Width = 556
    Height = 21
    TabOrder = 4
    OnClick = SecimDegisti
  end
  object memSonuc: TMemo
    Left = 12
    Top = 166
    Width = 556
    Height = 108
    ReadOnly = True
    ScrollBars = ssVertical
    TabOrder = 5
  end
  object pnlAlt: TPanel
    Left = 0
    Top = 284
    Width = 580
    Height = 52
    Align = alBottom
    BevelOuter = bvNone
    TabOrder = 6
    object btnKapat: TButton
      AlignWithMargins = True
      Left = 492
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
      TabOrder = 2
      OnClick = btnKapatClick
    end
    object btnScript: TButton
      AlignWithMargins = True
      Left = 408
      Top = 8
      Width = 80
      Height = 34
      Margins.Left = 4
      Margins.Top = 8
      Margins.Right = 4
      Margins.Bottom = 10
      Align = alRight
      Constraints.MinWidth = 80
      TabOrder = 1
      OnClick = btnScriptClick
    end
    object btnKarsilastir: TButton
      AlignWithMargins = True
      Left = 324
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
      OnClick = btnKarsilastirClick
    end
  end
end
