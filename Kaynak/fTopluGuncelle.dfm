object TopluGuncelleSekme: TTopluGuncelleSekme
  Left = 0
  Top = 0
  Width = 820
  Height = 520
  TabOrder = 0
  object pnlSol: TPanel
    Left = 0
    Top = 0
    Width = 230
    Height = 520
    Align = alLeft
    BevelOuter = bvNone
    TabOrder = 0
    object lblVeritabanlari: TLabel
      AlignWithMargins = True
      Left = 8
      Top = 8
      Width = 214
      Height = 17
      Margins.Left = 8
      Margins.Top = 8
      Margins.Right = 8
      Margins.Bottom = 4
      Align = alTop
      Font.Style = [fsBold]
      ParentFont = False
    end
    object pnlSolDugme: TPanel
      Left = 0
      Top = 486
      Width = 230
      Height = 34
      Align = alBottom
      BevelOuter = bvNone
      TabOrder = 1
      object btnHepsi: TButton
        AlignWithMargins = True
        Left = 8
        Top = 3
        Width = 90
        Height = 28
        Margins.Left = 8
        Margins.Top = 3
        Margins.Right = 0
        Margins.Bottom = 3
        Align = alLeft
        Constraints.MinWidth = 90
        TabOrder = 0
        OnClick = btnHepsiClick
      end
      object btnHicbiri: TButton
        AlignWithMargins = True
        Left = 102
        Top = 3
        Width = 90
        Height = 28
        Margins.Left = 4
        Margins.Top = 3
        Margins.Right = 0
        Margins.Bottom = 3
        Align = alLeft
        Constraints.MinWidth = 90
        TabOrder = 1
        OnClick = btnHicbiriClick
      end
    end
    object clbVeritabani: TCheckListBox
      AlignWithMargins = True
      Left = 8
      Top = 32
      Width = 214
      Height = 450
      Margins.Left = 8
      Margins.Right = 8
      Margins.Bottom = 4
      Align = alClient
      ItemHeight = 17
      TabOrder = 0
    end
  end
  object BolucuSol: TSplitter
    Left = 230
    Top = 0
    Width = 5
    Height = 520
  end
  object pnlSag: TPanel
    Left = 235
    Top = 0
    Width = 585
    Height = 520
    Align = alClient
    BevelOuter = bvNone
    TabOrder = 1
    object pnlEditor: TPanel
      Left = 0
      Top = 0
      Width = 585
      Height = 160
      Align = alTop
      BevelOuter = bvNone
      TabOrder = 0
    end
    object Bolucu: TSplitter
      Left = 0
      Top = 160
      Width = 585
      Height = 5
      Cursor = crVSplit
      Align = alTop
    end
    object pnlSonuc: TPanel
      Left = 0
      Top = 165
      Width = 585
      Height = 355
      Align = alClient
      BevelOuter = bvNone
      TabOrder = 1
      object pnlDugme: TPanel
        Left = 0
        Top = 0
        Width = 585
        Height = 40
        Align = alTop
        BevelOuter = bvNone
        TabOrder = 0
        object btnOnizle: TButton
          AlignWithMargins = True
          Left = 8
          Top = 6
          Width = 110
          Height = 30
          Margins.Left = 8
          Margins.Top = 6
          Margins.Right = 0
          Margins.Bottom = 4
          Align = alLeft
          Constraints.MinWidth = 110
          TabOrder = 0
          OnClick = btnOnizleClick
        end
        object btnUygula: TButton
          AlignWithMargins = True
          Left = 122
          Top = 6
          Width = 110
          Height = 30
          Margins.Left = 4
          Margins.Top = 6
          Margins.Right = 0
          Margins.Bottom = 4
          Align = alLeft
          Constraints.MinWidth = 110
          TabOrder = 1
          OnClick = btnUygulaClick
        end
      end
      object lblOzet: TLabel
        AlignWithMargins = True
        Left = 8
        Top = 42
        Width = 569
        Height = 17
        Margins.Left = 8
        Margins.Top = 2
        Margins.Right = 8
        Margins.Bottom = 2
        Align = alTop
        Font.Style = [fsBold]
        ParentFont = False
      end
      object lvDurum: TListView
        AlignWithMargins = True
        Left = 8
        Top = 63
        Width = 569
        Height = 284
        Margins.Left = 8
        Margins.Right = 8
        Margins.Bottom = 8
        Align = alClient
        Columns = <
          item
            Width = 150
          end
          item
            Width = 80
          end
          item
            Width = 80
          end
          item
            Width = 70
          end
          item
            Width = 300
          end>
        ReadOnly = True
        RowSelect = True
        TabOrder = 1
        ViewStyle = vsReport
        OnCustomDrawItem = lvDurumCustomDrawItem
      end
    end
  end
end
