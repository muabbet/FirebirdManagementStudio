object frmIceAktar: TfrmIceAktar
  Left = 0
  Top = 0
  BorderStyle = bsDialog
  ClientHeight = 600
  ClientWidth = 720
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -13
  Font.Name = 'Segoe UI'
  Font.Style = []
  Position = poOwnerFormCenter
  OnCloseQuery = FormCloseQuery
  object lblDosya: TLabel
    Left = 12
    Top = 12
    Width = 300
    Height = 17
    AutoSize = False
  end
  object edtDosya: TEdit
    Left = 12
    Top = 32
    Width = 590
    Height = 25
    ReadOnly = True
    TabOrder = 0
  end
  object btnSec: TButton
    Left = 610
    Top = 31
    Width = 98
    Height = 27
    Constraints.MinWidth = 98
    TabOrder = 1
    OnClick = btnSecClick
  end
  object lblAyrac: TLabel
    Left = 12
    Top = 70
    Width = 110
    Height = 17
    AutoSize = False
  end
  object cmbAyrac: TComboBox
    Left = 12
    Top = 90
    Width = 110
    Height = 25
    Style = csDropDownList
    TabOrder = 2
    OnChange = SecenekDegisti
  end
  object lblKodlama: TLabel
    Left = 134
    Top = 70
    Width = 140
    Height = 17
    AutoSize = False
  end
  object cmbKodlama: TComboBox
    Left = 134
    Top = 90
    Width = 140
    Height = 25
    Style = csDropDownList
    TabOrder = 3
    OnChange = SecenekDegisti
  end
  object lblOndalik: TLabel
    Left = 286
    Top = 70
    Width = 120
    Height = 17
    AutoSize = False
  end
  object cmbOndalik: TComboBox
    Left = 286
    Top = 90
    Width = 110
    Height = 25
    Style = csDropDownList
    TabOrder = 4
    OnChange = SecenekDegisti
  end
  object chkBaslik: TCheckBox
    Left = 412
    Top = 92
    Width = 296
    Height = 21
    Checked = True
    State = cbChecked
    TabOrder = 5
    OnClick = SecenekDegisti
  end
  object lblOnizleme: TLabel
    Left = 12
    Top = 128
    Width = 696
    Height = 17
    AutoSize = False
  end
  object gridOnizleme: TStringGrid
    Left = 12
    Top = 148
    Width = 696
    Height = 150
    ColCount = 2
    DefaultRowHeight = 22
    FixedCols = 0
    RowCount = 2
    Options = [goFixedVertLine, goFixedHorzLine, goVertLine, goHorzLine, goColSizing, goThumbTracking]
    TabOrder = 6
  end
  object lblEsleme: TLabel
    Left = 12
    Top = 308
    Width = 696
    Height = 17
    AutoSize = False
  end
  object sbxEsleme: TScrollBox
    Left = 12
    Top = 328
    Width = 696
    Height = 190
    BevelKind = bkFlat
    BorderStyle = bsNone
    TabOrder = 7
  end
  object lblDurum: TLabel
    Left = 12
    Top = 526
    Width = 696
    Height = 17
    AutoSize = False
  end
  object pnlAlt: TPanel
    Left = 0
    Top = 548
    Width = 720
    Height = 52
    Align = alBottom
    BevelOuter = bvNone
    TabOrder = 8
    object btnKapat: TButton
      AlignWithMargins = True
      Left = 632
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
      Left = 548
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
  object dlgAc: TOpenDialog
    Left = 660
    Top = 130
  end
end
