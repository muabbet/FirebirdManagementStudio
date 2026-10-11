object SorguSekme: TSorguSekme
  Left = 0
  Top = 0
  Width = 720
  Height = 480
  TabOrder = 0
  object pnlEditor: TPanel
    Left = 0
    Top = 0
    Width = 720
    Height = 220
    Align = alTop
    BevelOuter = bvNone
    TabOrder = 0
  end
  object Bolucu: TSplitter
    Left = 0
    Top = 220
    Width = 720
    Height = 5
    Cursor = crVSplit
    Align = alTop
  end
  object pnlSonuc: TPanel
    Left = 0
    Top = 225
    Width = 720
    Height = 255
    Align = alClient
    BevelOuter = bvNone
    TabOrder = 1
    object lblSonuc: TLabel
      AlignWithMargins = True
      Left = 8
      Top = 4
      Width = 704
      Height = 17
      Margins.Left = 8
      Margins.Top = 4
      Margins.Right = 8
      Margins.Bottom = 2
      Align = alTop
      Font.Style = [fsBold]
      ParentFont = False
    end
    object memMesaj: TMemo
      Left = 0
      Top = 175
      Width = 720
      Height = 80
      Align = alBottom
      ReadOnly = True
      ScrollBars = ssVertical
      TabOrder = 1
    end
    object gridSonuc: TDBGrid
      Left = 0
      Top = 25
      Width = 720
      Height = 150
      Align = alClient
      DataSource = dsSonuc
      Options = [dgTitles, dgIndicator, dgColumnResize, dgColLines, dgRowLines, dgTabs, dgCancelOnExit]
      ReadOnly = True
      TabOrder = 0
    end
  end
  object dsSonuc: TDataSource
    OnDataChange = dsSonucDataChange
    Left = 40
    Top = 300
  end
end
