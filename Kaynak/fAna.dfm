object frmAna: TfrmAna
  Left = 0
  Top = 0
  ClientHeight = 700
  ClientWidth = 1100
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -13
  Font.Name = 'Segoe UI'
  Font.Style = []
  KeyPreview = True
  Position = poScreenCenter
  OnCreate = FormCreate
  OnKeyDown = FormKeyDown
  OnDestroy = FormDestroy
  object pnlUst: TPanel
    Left = 0
    Top = 0
    Width = 1100
    Height = 104
    Align = alTop
    BevelOuter = bvNone
    TabOrder = 0
    object pnlDil: TPanel
      Left = 910
      Top = 0
      Width = 190
      Height = 104
      Align = alRight
      BevelOuter = bvNone
      TabOrder = 1
      object cmbDil: TComboBox
        AlignWithMargins = True
        Left = 8
        Top = 8
        Width = 174
        Height = 25
        Margins.Left = 8
        Margins.Top = 8
        Margins.Right = 8
        Margins.Bottom = 8
        Align = alTop
        Style = csDropDownList
        ShowHint = True
        TabOrder = 0
        OnChange = cmbDilChange
      end
    end
  end
  object stbDurum: TStatusBar
    Left = 0
    Top = 681
    Width = 1100
    Height = 19
    Panels = <
      item
        Width = 420
      end
      item
        Width = 160
      end
      item
        Width = 240
      end>
  end
  object tvNesneler: TTreeView
    Left = 0
    Top = 104
    Width = 270
    Height = 577
    Align = alLeft
    HideSelection = False
    Images = vilIkonlar
    Indent = 19
    PopupMenu = pmNesne
    ReadOnly = True
    RightClickSelect = True
    TabOrder = 1
    OnChange = tvNesnelerChange
    OnCustomDrawItem = tvNesnelerCustomDrawItem
    OnDblClick = tvNesnelerDblClick
    OnDragDrop = tvNesnelerDragDrop
    OnDragOver = tvNesnelerDragOver
    OnMouseDown = tvNesnelerMouseDown
  end
  object bolSol: TSplitter
    Left = 270
    Top = 104
    Width = 5
    Height = 577
  end
  object pnlSag: TPanel
    Left = 275
    Top = 104
    Width = 825
    Height = 577
    Align = alClient
    BevelOuter = bvNone
    TabOrder = 2
    object pcCalisma: TPageControl
      Left = 0
      Top = 0
      Width = 825
      Height = 482
      Align = alClient
      Images = vilIkonlar
      PopupMenu = pmSekme
      TabOrder = 0
      OnChange = pcCalismaChange
    end
    object bolAlt: TSplitter
      Left = 0
      Top = 482
      Width = 825
      Height = 5
      Cursor = crVSplit
      Align = alBottom
    end
    object memSonuc: TMemo
      Left = 0
      Top = 487
      Width = 825
      Height = 150
      Align = alBottom
      ReadOnly = True
      ScrollBars = ssVertical
      TabOrder = 1
    end
  end
  object icIkonlar: TImageCollection
    Left = 40
    Top = 560
  end
  object vilIkonlar: TVirtualImageList
    AutoFill = True
    ImageCollection = icIkonlar
    Width = 20
    Height = 20
    Left = 100
    Top = 560
  end
  object pmNesne: TPopupMenu
    OnPopup = pmNesnePopup
    Left = 160
    Top = 560
    object miAc: TMenuItem
      OnClick = miAcClick
    end
    object miScriptUret: TMenuItem
      OnClick = miScriptUretClick
    end
    object miNesneDuzenle: TMenuItem
      OnClick = miNesneDuzenleClick
    end
    object miYeniNesne: TMenuItem
      OnClick = miYeniNesneClick
    end
    object miDomVarsayilan: TMenuItem
      OnClick = miDomVarsayilanClick
    end
    object miDomKontrol: TMenuItem
      OnClick = miDomKontrolClick
    end
    object miDomAd: TMenuItem
      OnClick = miDomAdClick
    end
    object miBaglan: TMenuItem
      OnClick = miBaglanClick
    end
    object miKes: TMenuItem
      OnClick = miKesClick
    end
    object miYenile: TMenuItem
      OnClick = miYenileClick
    end
    object miNesneSil: TMenuItem
      OnClick = miNesneSilClick
    end
    object miMetadataCikar: TMenuItem
      OnClick = miMetadataCikarClick
    end
    object miYedek: TMenuItem
      OnClick = miYedekClick
    end
    object miDuzenle: TMenuItem
      OnClick = miDuzenleClick
    end
    object miKaldir: TMenuItem
      OnClick = miKaldirClick
    end
    object miKlasorAdi: TMenuItem
      OnClick = miKlasorAdiClick
    end
    object miKlasorKaldir: TMenuItem
      OnClick = miKlasorKaldirClick
    end
    object miYeniKlasor: TMenuItem
      OnClick = miYeniKlasorClick
    end
  end
  object pmSekme: TPopupMenu
    Left = 220
    Top = 560
    object miSekmeKapat: TMenuItem
      OnClick = miSekmeKapatClick
    end
  end
end
