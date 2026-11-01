object SemaFarkSekme: TSemaFarkSekme
  Left = 0
  Top = 0
  Width = 820
  Height = 520
  TabOrder = 0
  object pnlUst: TPanel
    Left = 0
    Top = 0
    Width = 820
    Height = 70
    Align = alTop
    BevelOuter = bvNone
    TabOrder = 0
    object lblKaynak: TLabel
      Left = 8
      Top = 10
      Width = 70
      Height = 17
      AutoSize = False
    end
    object lblHedef: TLabel
      Left = 8
      Top = 40
      Width = 70
      Height = 17
      AutoSize = False
    end
    object cmbKaynak: TComboBox
      Left = 84
      Top = 6
      Width = 300
      Height = 25
      Style = csDropDownList
      TabOrder = 0
    end
    object cmbHedef: TComboBox
      Left = 84
      Top = 36
      Width = 300
      Height = 25
      Style = csDropDownList
      TabOrder = 1
    end
    object btnKarsilastir: TButton
      Left = 400
      Top = 6
      Width = 110
      Height = 55
      Constraints.MinWidth = 110
      TabOrder = 2
      OnClick = btnKarsilastirClick
    end
  end
  object lblOzet: TLabel
    AlignWithMargins = True
    Left = 8
    Top = 72
    Width = 804
    Height = 17
    Margins.Left = 8
    Margins.Top = 2
    Margins.Right = 8
    Margins.Bottom = 4
    Align = alTop
    Font.Style = [fsBold]
    ParentFont = False
  end
  object lvFark: TListView
    AlignWithMargins = True
    Left = 8
    Top = 93
    Width = 804
    Height = 240
    Margins.Left = 8
    Margins.Right = 8
    Margins.Bottom = 2
    Align = alTop
    Columns = <
      item
        Width = 110
      end
      item
        Width = 360
      end
      item
        Width = 200
      end>
    ReadOnly = True
    RowSelect = True
    TabOrder = 1
    ViewStyle = vsReport
    OnSelectItem = lvFarkSelectItem
  end
  object Bolucu: TSplitter
    Left = 0
    Top = 335
    Width = 820
    Height = 5
    Cursor = crVSplit
    Align = alTop
  end
  object memAyrinti: TMemo
    AlignWithMargins = True
    Left = 8
    Top = 342
    Width = 804
    Height = 170
    Margins.Left = 8
    Margins.Right = 8
    Margins.Bottom = 8
    Align = alClient
    Font.Charset = DEFAULT_CHARSET
    Font.Color = clWindowText
    Font.Height = -13
    Font.Name = 'Consolas'
    Font.Style = []
    ParentFont = False
    ReadOnly = True
    ScrollBars = ssBoth
    TabOrder = 2
    WordWrap = False
  end
end
