object Kullanicilar: TKullanicilar
  Left = 0
  Top = 0
  Width = 720
  Height = 420
  TabOrder = 0
  object pnlUst: TPanel
    Left = 0
    Top = 0
    Width = 720
    Height = 40
    Align = alTop
    BevelOuter = bvNone
    TabOrder = 0
    object lblBilgi: TLabel
      AlignWithMargins = True
      Left = 8
      Top = 0
      Width = 600
      Height = 40
      Margins.Left = 8
      Margins.Top = 0
      Margins.Right = 8
      Margins.Bottom = 0
      Align = alClient
      AutoSize = False
      Layout = tlCenter
      WordWrap = True
    end
    object btnYetki: TButton
      AlignWithMargins = True
      Left = 520
      Top = 6
      Width = 92
      Height = 28
      Margins.Top = 6
      Margins.Right = 4
      Margins.Bottom = 6
      Align = alRight
      Constraints.MinWidth = 92
      TabOrder = 1
      OnClick = btnYetkiClick
    end
    object btnYeni: TButton
      AlignWithMargins = True
      Left = 620
      Top = 6
      Width = 92
      Height = 28
      Margins.Top = 6
      Margins.Right = 8
      Margins.Bottom = 6
      Align = alRight
      Constraints.MinWidth = 92
      TabOrder = 0
      OnClick = btnYeniClick
    end
  end
  object gridKullanicilar: TDBGrid
    Left = 0
    Top = 40
    Width = 720
    Height = 380
    Align = alClient
    DataSource = dsKullanicilar
    Options = [dgTitles, dgIndicator, dgColumnResize, dgColLines, dgRowLines, dgTabs, dgRowSelect, dgCancelOnExit]
    PopupMenu = pmKullanici
    ReadOnly = True
    TabOrder = 1
    OnMouseDown = gridKullanicilarMouseDown
  end
  object dsKullanicilar: TDataSource
    Left = 40
    Top = 120
  end
  object pmKullanici: TPopupMenu
    OnPopup = pmKullaniciPopup
    Left = 120
    Top = 120
    object miSifre: TMenuItem
      OnClick = miSifreClick
    end
    object miAdSoyad: TMenuItem
      OnClick = miAdSoyadClick
    end
    object miYonetici: TMenuItem
      OnClick = miYoneticiClick
    end
    object miAktif: TMenuItem
      OnClick = miAktifClick
    end
    object miYenile: TMenuItem
      OnClick = miYenileClick
    end
    object miSil: TMenuItem
      OnClick = miSilClick
    end
  end
end
