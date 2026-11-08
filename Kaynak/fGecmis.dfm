object frmGecmis: TfrmGecmis
  Left = 0
  Top = 0
  BorderStyle = bsSizeable
  ClientHeight = 560
  ClientWidth = 900
  Color = clBtnFace
  Constraints.MinHeight = 420
  Constraints.MinWidth = 700
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -13
  Font.Name = 'Segoe UI'
  Font.Style = []
  Position = poOwnerFormCenter
  object lblNot: TLabel
    Left = 12
    Top = 8
    Width = 876
    Height = 17
    Anchors = [akLeft, akTop, akRight]
    AutoSize = False
    Font.Charset = DEFAULT_CHARSET
    Font.Color = clGrayText
    Font.Height = -12
    Font.Name = 'Segoe UI'
    Font.Style = []
    ParentFont = False
  end
  object pgSekmeler: TPageControl
    Left = 12
    Top = 30
    Width = 876
    Height = 330
    ActivePage = tsGecmis
    Anchors = [akLeft, akTop, akRight, akBottom]
    TabOrder = 0
    OnChange = pgSekmelerChange
    object tsGecmis: TTabSheet
      object lvGecmis: TListView
        Left = 0
        Top = 0
        Width = 868
        Height = 300
        Align = alClient
        Columns = <
          item
            Width = 140
          end
          item
            Width = 160
          end
          item
            Width = 540
          end>
        ReadOnly = True
        RowSelect = True
        TabOrder = 0
        ViewStyle = vsReport
        OnDblClick = lvDblClick
        OnSelectItem = lvGecmisSelectItem
      end
    end
    object tsSik: TTabSheet
      object lvSik: TListView
        Left = 0
        Top = 0
        Width = 868
        Height = 300
        Align = alClient
        Columns = <
          item
            Width = 220
          end
          item
            Width = 620
          end>
        ReadOnly = True
        RowSelect = True
        TabOrder = 0
        ViewStyle = vsReport
        OnDblClick = lvDblClick
        OnSelectItem = lvSikSelectItem
      end
    end
  end
  object memSql: TMemo
    Left = 12
    Top = 370
    Width = 876
    Height = 120
    Anchors = [akLeft, akRight, akBottom]
    Font.Charset = DEFAULT_CHARSET
    Font.Color = clWindowText
    Font.Height = -12
    Font.Name = 'Consolas'
    Font.Style = []
    ParentFont = False
    ReadOnly = True
    ScrollBars = ssBoth
    TabOrder = 1
  end
  object pnlAlt: TPanel
    Left = 0
    Top = 500
    Width = 900
    Height = 60
    Align = alBottom
    BevelOuter = bvNone
    TabOrder = 2
    object btnEditore: TButton
      AlignWithMargins = True
      Left = 12
      Top = 8
      Width = 120
      Height = 34
      Margins.Left = 12
      Margins.Top = 8
      Margins.Right = 4
      Margins.Bottom = 12
      Align = alLeft
      Constraints.MinWidth = 120
      TabOrder = 0
      OnClick = btnEditoreClick
    end
    object btnSikEkle: TButton
      AlignWithMargins = True
      Left = 140
      Top = 8
      Width = 120
      Height = 34
      Margins.Left = 4
      Margins.Top = 8
      Margins.Right = 4
      Margins.Bottom = 12
      Align = alLeft
      Constraints.MinWidth = 120
      TabOrder = 1
      OnClick = btnSikEkleClick
    end
    object btnEditordekiniEkle: TButton
      AlignWithMargins = True
      Left = 268
      Top = 8
      Width = 120
      Height = 34
      Margins.Left = 4
      Margins.Top = 8
      Margins.Right = 4
      Margins.Bottom = 12
      Align = alLeft
      Constraints.MinWidth = 120
      TabOrder = 2
      OnClick = btnEditordekiniEkleClick
    end
    object btnSil: TButton
      AlignWithMargins = True
      Left = 396
      Top = 8
      Width = 100
      Height = 34
      Margins.Left = 4
      Margins.Top = 8
      Margins.Right = 4
      Margins.Bottom = 12
      Align = alLeft
      Constraints.MinWidth = 100
      TabOrder = 3
      OnClick = btnSilClick
    end
    object btnTemizle: TButton
      AlignWithMargins = True
      Left = 504
      Top = 8
      Width = 120
      Height = 34
      Margins.Left = 4
      Margins.Top = 8
      Margins.Right = 4
      Margins.Bottom = 12
      Align = alLeft
      Constraints.MinWidth = 120
      TabOrder = 4
      OnClick = btnTemizleClick
    end
    object btnKapat: TButton
      AlignWithMargins = True
      Left = 812
      Top = 8
      Width = 80
      Height = 34
      Margins.Left = 4
      Margins.Top = 8
      Margins.Right = 8
      Margins.Bottom = 12
      Align = alRight
      Cancel = True
      Constraints.MinWidth = 80
      ModalResult = 2
      TabOrder = 5
    end
  end
end
