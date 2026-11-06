object frmTabloTasarim: TfrmTabloTasarim
  Left = 0
  Top = 0
  BorderStyle = bsSizeable
  ClientHeight = 640
  ClientWidth = 900
  Color = clBtnFace
  Constraints.MinHeight = 560
  Constraints.MinWidth = 760
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -13
  Font.Name = 'Segoe UI'
  Font.Style = []
  Position = poOwnerFormCenter
  object lblTablo: TLabel
    Left = 12
    Top = 12
    Width = 320
    Height = 17
    AutoSize = False
  end
  object edtTablo: TEdit
    Left = 12
    Top = 32
    Width = 320
    Height = 25
    TabOrder = 0
    OnChange = TabloAdiDegisti
  end
  object lblIpucu: TLabel
    Left = 348
    Top = 12
    Width = 540
    Height = 62
    AutoSize = False
    Font.Color = clGrayText
    ParentFont = False
    WordWrap = True
  end
  object gridKolon: TStringGrid
    Left = 12
    Top = 84
    Width = 876
    Height = 220
    ColCount = 7
    DefaultRowHeight = 24
    FixedCols = 0
    RowCount = 2
    Options = [goFixedVertLine, goFixedHorzLine, goVertLine, goHorzLine, goColSizing, goTabs, goEditing, goThumbTracking]
    TabOrder = 1
    OnKeyDown = gridKolonKeyDown
    OnSelectCell = gridKolonSelectCell
    OnSetEditText = gridKolonSetEditText
    OnTopLeftChanged = gridKolonTopLeftChanged
    object cmbHucre: TComboBox
      Left = 0
      Top = 0
      Width = 120
      Height = 25
      Style = csDropDownList
      TabOrder = 0
      Visible = False
      OnChange = HucreSecildi
    end
  end
  object pnlDugme: TPanel
    Left = 12
    Top = 310
    Width = 876
    Height = 34
    BevelOuter = bvNone
    TabOrder = 2
    object btnEkle: TButton
      Left = 0
      Top = 0
      Width = 110
      Height = 30
      Align = alLeft
      Constraints.MinWidth = 110
      TabOrder = 0
      OnClick = btnEkleClick
    end
    object btnCikar: TButton
      Left = 110
      Top = 0
      Width = 110
      Height = 30
      Align = alLeft
      Constraints.MinWidth = 110
      TabOrder = 1
      OnClick = btnCikarClick
    end
    object btnYukari: TButton
      Left = 220
      Top = 0
      Width = 110
      Height = 30
      Align = alLeft
      Constraints.MinWidth = 110
      TabOrder = 2
      OnClick = btnYukariClick
    end
    object btnAsagi: TButton
      Left = 330
      Top = 0
      Width = 110
      Height = 30
      Align = alLeft
      Constraints.MinWidth = 110
      TabOrder = 3
      OnClick = btnAsagiClick
    end
  end
  object lblSql: TLabel
    Left = 12
    Top = 354
    Width = 876
    Height = 17
    AutoSize = False
  end
  object memSql: TMemo
    Left = 12
    Top = 374
    Width = 876
    Height = 150
    Font.Charset = DEFAULT_CHARSET
    Font.Color = clWindowText
    Font.Height = -13
    Font.Name = 'Consolas'
    Font.Style = []
    ParentFont = False
    ReadOnly = True
    ScrollBars = ssBoth
    TabOrder = 3
    WordWrap = False
  end
  object lblDurum: TLabel
    Left = 12
    Top = 532
    Width = 876
    Height = 40
    AutoSize = False
    Font.Color = clMaroon
    ParentFont = False
    WordWrap = True
  end
  object pnlAlt: TPanel
    Left = 0
    Top = 588
    Width = 900
    Height = 52
    Align = alBottom
    BevelOuter = bvNone
    TabOrder = 4
    object btnKapat: TButton
      AlignWithMargins = True
      Left = 812
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
    object btnOlustur: TButton
      AlignWithMargins = True
      Left = 728
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
      OnClick = btnOlusturClick
    end
  end
end
