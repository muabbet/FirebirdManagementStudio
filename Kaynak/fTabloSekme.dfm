object TabloSekme: TTabloSekme
  Left = 0
  Top = 0
  Width = 720
  Height = 420
  TabOrder = 0
  object pnlKolonlar: TPanel
    Left = 0
    Top = 0
    Width = 720
    Height = 170
    Align = alTop
    BevelOuter = bvNone
    TabOrder = 0
    object lblKolonlar: TLabel
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
    object gridKolonlar: TDBGrid
      Left = 0
      Top = 25
      Width = 720
      Height = 145
      Align = alClient
      DataSource = dsKolonlar
      Options = [dgTitles, dgIndicator, dgColumnResize, dgColLines, dgRowLines, dgTabs, dgRowSelect, dgCancelOnExit]
      ReadOnly = True
      TabOrder = 0
    end
  end
  object Bolucu: TSplitter
    Left = 0
    Top = 170
    Width = 720
    Height = 5
    Cursor = crVSplit
    Align = alTop
  end
  object pnlVeri: TPanel
    Left = 0
    Top = 175
    Width = 720
    Height = 245
    Align = alClient
    BevelOuter = bvNone
    TabOrder = 1
    object pnlVeriBaslik: TPanel
      Left = 0
      Top = 0
      Width = 720
      Height = 29
      Align = alTop
      BevelOuter = bvNone
      TabOrder = 1
      object lblVeri: TLabel
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
    object gridVeri: TDBGrid
      Left = 0
      Top = 25
      Width = 720
      Height = 220
      Align = alClient
      DataSource = dsVeri
      Options = [dgTitles, dgIndicator, dgColumnResize, dgColLines, dgRowLines, dgTabs, dgCancelOnExit]
      ReadOnly = True
      TabOrder = 0
    end
  end
  object dsKolonlar: TDataSource
    Left = 40
    Top = 80
  end
  object dsVeri: TDataSource
    Left = 40
    Top = 250
  end
end
