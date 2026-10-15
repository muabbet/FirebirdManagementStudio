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
    object pnlSonucBaslik: TPanel
      Left = 0
      Top = 0
      Width = 720
      Height = 29
      Align = alTop
      BevelOuter = bvNone
      TabOrder = 2
      object lblSonuc: TLabel
        AlignWithMargins = True
        Left = 8
        Top = 0
        Width = 600
        Height = 29
        Margins.Left = 8
        Margins.Top = 0
        Margins.Right = 8
        Margins.Bottom = 0
        Align = alClient
        AutoSize = False
        Font.Style = [fsBold]
        ParentFont = False
        Layout = tlCenter
      end
      object btnDisaAktar: TButton
        AlignWithMargins = True
        Left = 620
        Top = 2
        Width = 92
        Height = 25
        Margins.Top = 2
        Margins.Right = 8
        Margins.Bottom = 2
        Align = alRight
        Constraints.MinWidth = 92
        Enabled = False
        TabOrder = 0
        OnClick = btnDisaAktarClick
      end
    end
    object BolucuMesaj: TSplitter
      Left = 0
      Top = 135
      Width = 720
      Height = 5
      Cursor = crVSplit
      Align = alBottom
    end
    object memMesaj: TMemo
      Left = 0
      Top = 140
      Width = 720
      Height = 115
      Align = alBottom
      ReadOnly = True
      ScrollBars = ssVertical
      TabOrder = 1
    end
    object gridSonuc: TDBGrid
      Left = 0
      Top = 25
      Width = 720
      Height = 110
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
