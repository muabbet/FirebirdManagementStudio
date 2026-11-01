object TabloListeSekme: TTabloListeSekme
  Left = 0
  Top = 0
  Width = 820
  Height = 520
  TabOrder = 0
  object lvTablolar: TListView
    AlignWithMargins = True
    Left = 8
    Top = 8
    Width = 804
    Height = 290
    Margins.Left = 8
    Margins.Top = 8
    Margins.Right = 8
    Margins.Bottom = 0
    Align = alClient
    Columns = <
      item
        Width = 260
      end
      item
        Alignment = taRightJustify
        Width = 110
      end
      item
        Width = 400
      end>
    HideSelection = False
    ReadOnly = True
    RowSelect = True
    TabOrder = 0
    ViewStyle = vsReport
    OnColumnClick = lvTablolarColumnClick
    OnCompare = lvTablolarCompare
    OnDblClick = lvTablolarDblClick
    OnSelectItem = lvTablolarSelectItem
  end
  object Bolucu: TSplitter
    Left = 0
    Top = 303
    Width = 820
    Height = 5
    Cursor = crVSplit
    Align = alBottom
  end
  object pnlAyrinti: TPanel
    Left = 0
    Top = 308
    Width = 820
    Height = 212
    Align = alBottom
    BevelOuter = bvNone
    TabOrder = 1
    object lblAyrinti: TLabel
      AlignWithMargins = True
      Left = 8
      Top = 4
      Width = 804
      Height = 17
      Margins.Left = 8
      Margins.Top = 4
      Margins.Right = 8
      Margins.Bottom = 2
      Align = alTop
      Font.Style = [fsBold]
      ParentFont = False
    end
    object lvAlanlar: TListView
      AlignWithMargins = True
      Left = 8
      Top = 25
      Width = 804
      Height = 179
      Margins.Left = 8
      Margins.Right = 8
      Margins.Bottom = 8
      Align = alClient
      Columns = <
        item
          Width = 220
        end
        item
          Width = 220
        end
        item
          Width = 110
        end
        item
          Width = 220
        end>
      ReadOnly = True
      RowSelect = True
      TabOrder = 0
      ViewStyle = vsReport
      OnColumnClick = lvAlanlarColumnClick
      OnCompare = lvAlanlarCompare
    end
  end
end
