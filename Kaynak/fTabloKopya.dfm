object frmTabloKopya: TfrmTabloKopya
  Left = 0
  Top = 0
  BorderStyle = bsDialog
  ClientHeight = 300
  ClientWidth = 580
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -13
  Font.Name = 'Segoe UI'
  Font.Style = []
  Position = poOwnerFormCenter
  OnCloseQuery = FormCloseQuery
  object lblKaynak: TLabel
    Left = 12
    Top = 14
    Width = 556
    Height = 34
    AutoSize = False
    Font.Style = [fsBold]
    ParentFont = False
    WordWrap = True
  end
  object lblHedefDb: TLabel
    Left = 12
    Top = 58
    Width = 556
    Height = 17
    AutoSize = False
  end
  object cmbHedef: TComboBox
    Left = 12
    Top = 78
    Width = 556
    Height = 25
    Style = csDropDownList
    TabOrder = 0
    OnChange = HedefDegisti
  end
  object lblHedefAd: TLabel
    Left = 12
    Top = 114
    Width = 556
    Height = 17
    AutoSize = False
  end
  object edtHedefAd: TEdit
    Left = 12
    Top = 134
    Width = 300
    Height = 25
    TabOrder = 1
    OnChange = HedefDegisti
  end
  object chkVeri: TCheckBox
    Left = 12
    Top = 172
    Width = 556
    Height = 21
    Checked = True
    State = cbChecked
    TabOrder = 2
  end
  object lblDurum: TLabel
    Left = 12
    Top = 204
    Width = 556
    Height = 40
    AutoSize = False
    WordWrap = True
  end
  object pnlAlt: TPanel
    Left = 0
    Top = 248
    Width = 580
    Height = 52
    Align = alBottom
    BevelOuter = bvNone
    TabOrder = 3
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
      TabOrder = 1
      OnClick = btnKapatClick
    end
    object btnBaslat: TButton
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
      TabOrder = 0
      OnClick = btnBaslatClick
    end
  end
end
