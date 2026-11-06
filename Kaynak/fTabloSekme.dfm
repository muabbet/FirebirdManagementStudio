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
    Height = 200
    Align = alTop
    BevelOuter = bvNone
    TabOrder = 0
    object pcYapi: TPageControl
      Left = 0
      Top = 0
      Width = 720
      Height = 200
      ActivePage = tsKolonlar
      Align = alClient
      TabOrder = 0
      object tsKolonlar: TTabSheet
        object pnlKolonDugme: TPanel
          Left = 0
          Top = 0
          Width = 712
          Height = 34
          Align = alTop
          BevelOuter = bvNone
          TabOrder = 1
          object btnKolonEkle: TButton
            AlignWithMargins = True
            Left = 4
            Top = 3
            Width = 90
            Height = 28
            Margins.Left = 4
            Margins.Top = 3
            Margins.Right = 0
            Margins.Bottom = 3
            Align = alLeft
            Constraints.MinWidth = 90
            TabOrder = 0
            OnClick = btnKolonEkleClick
          end
          object btnKolonAd: TButton
            AlignWithMargins = True
            Left = 98
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
            OnClick = btnKolonAdClick
          end
          object btnKolonDegistir: TButton
            AlignWithMargins = True
            Left = 192
            Top = 3
            Width = 90
            Height = 28
            Margins.Left = 4
            Margins.Top = 3
            Margins.Right = 0
            Margins.Bottom = 3
            Align = alLeft
            Constraints.MinWidth = 90
            TabOrder = 2
            OnClick = btnKolonDegistirClick
          end
          object btnKolonSil: TButton
            AlignWithMargins = True
            Left = 286
            Top = 3
            Width = 90
            Height = 28
            Margins.Left = 4
            Margins.Top = 3
            Margins.Right = 0
            Margins.Bottom = 3
            Align = alLeft
            Constraints.MinWidth = 90
            TabOrder = 3
            OnClick = btnKolonSilClick
          end
        end
        object gridKolonlar: TDBGrid
          Left = 0
          Top = 0
          Width = 712
          Height = 170
          Align = alClient
          DataSource = dsKolonlar
          Options = [dgTitles, dgIndicator, dgColumnResize, dgColLines, dgRowLines, dgTabs, dgRowSelect, dgCancelOnExit]
          ReadOnly = True
          TabOrder = 0
        end
      end
      object tsIndeksler: TTabSheet
        ImageIndex = 1
        object pnlIndeksDugme: TPanel
          Left = 0
          Top = 0
          Width = 712
          Height = 34
          Align = alTop
          BevelOuter = bvNone
          TabOrder = 1
          object btnIndeksOlustur: TButton
            AlignWithMargins = True
            Left = 4
            Top = 3
            Width = 90
            Height = 28
            Margins.Left = 4
            Margins.Top = 3
            Margins.Right = 0
            Margins.Bottom = 3
            Align = alLeft
            Constraints.MinWidth = 90
            TabOrder = 0
            OnClick = btnIndeksOlusturClick
          end
          object btnIndeksSil: TButton
            AlignWithMargins = True
            Left = 98
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
            OnClick = btnIndeksSilClick
          end
          object btnIndeksDurum: TButton
            AlignWithMargins = True
            Left = 192
            Top = 3
            Width = 90
            Height = 28
            Margins.Left = 4
            Margins.Top = 3
            Margins.Right = 0
            Margins.Bottom = 3
            Align = alLeft
            Constraints.MinWidth = 90
            TabOrder = 2
            OnClick = btnIndeksDurumClick
          end
        end
        object gridIndeksler: TDBGrid
          Left = 0
          Top = 0
          Width = 712
          Height = 170
          Align = alClient
          DataSource = dsIndeksler
          Options = [dgTitles, dgIndicator, dgColumnResize, dgColLines, dgRowLines, dgTabs, dgRowSelect, dgCancelOnExit]
          ReadOnly = True
          TabOrder = 0
        end
      end
      object tsKisitlar: TTabSheet
        ImageIndex = 2
        object pnlKisitDugme: TPanel
          Left = 0
          Top = 0
          Width = 712
          Height = 34
          Align = alTop
          BevelOuter = bvNone
          TabOrder = 1
          object btnKisitEkle: TButton
            AlignWithMargins = True
            Left = 4
            Top = 3
            Width = 90
            Height = 28
            Margins.Left = 4
            Margins.Top = 3
            Margins.Right = 0
            Margins.Bottom = 3
            Align = alLeft
            Constraints.MinWidth = 90
            TabOrder = 0
            OnClick = btnKisitEkleClick
          end
          object btnKisitSil: TButton
            AlignWithMargins = True
            Left = 98
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
            OnClick = btnKisitSilClick
          end
        end
        object gridKisitlar: TDBGrid
          Left = 0
          Top = 0
          Width = 712
          Height = 170
          Align = alClient
          DataSource = dsKisitlar
          Options = [dgTitles, dgIndicator, dgColumnResize, dgColLines, dgRowLines, dgTabs, dgRowSelect, dgCancelOnExit]
          ReadOnly = True
          TabOrder = 0
        end
      end
      object tsBagimliliklar: TTabSheet
        ImageIndex = 3
        object gridBagimliliklar: TDBGrid
          Left = 0
          Top = 0
          Width = 712
          Height = 170
          Align = alClient
          DataSource = dsBagimliliklar
          Options = [dgTitles, dgIndicator, dgColumnResize, dgColLines, dgRowLines, dgTabs, dgRowSelect, dgCancelOnExit]
          ReadOnly = True
          TabOrder = 0
        end
      end
    end
  end
  object Bolucu: TSplitter
    Left = 0
    Top = 200
    Width = 720
    Height = 5
    Cursor = crVSplit
    Align = alTop
  end
  object pnlVeri: TPanel
    Left = 0
    Top = 205
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
        ShowHint = True
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
      object btnDuzenle: TButton
        AlignWithMargins = True
        Left = 520
        Top = 2
        Width = 92
        Height = 25
        Margins.Top = 2
        Margins.Right = 4
        Margins.Bottom = 2
        Align = alRight
        Constraints.MinWidth = 92
        Enabled = False
        TabOrder = 1
        OnClick = btnDuzenleClick
      end
      object btnYeniKayit: TButton
        AlignWithMargins = True
        Left = 220
        Top = 2
        Width = 92
        Height = 25
        Margins.Top = 2
        Margins.Right = 4
        Margins.Bottom = 2
        Align = alRight
        Constraints.MinWidth = 92
        TabOrder = 4
        Visible = False
        OnClick = btnYeniKayitClick
      end
      object btnKaydet: TButton
        AlignWithMargins = True
        Left = 320
        Top = 2
        Width = 92
        Height = 25
        Margins.Top = 2
        Margins.Right = 4
        Margins.Bottom = 2
        Align = alRight
        Constraints.MinWidth = 92
        TabOrder = 2
        Visible = False
        OnClick = btnKaydetClick
      end
      object btnGeriAl: TButton
        AlignWithMargins = True
        Left = 420
        Top = 2
        Width = 92
        Height = 25
        Margins.Top = 2
        Margins.Right = 4
        Margins.Bottom = 2
        Align = alRight
        Constraints.MinWidth = 92
        TabOrder = 3
        Visible = False
        OnClick = btnGeriAlClick
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
  object dsIndeksler: TDataSource
    Left = 120
    Top = 80
  end
  object dsKisitlar: TDataSource
    Left = 200
    Top = 80
  end
  object dsBagimliliklar: TDataSource
    Left = 280
    Top = 80
  end
end
