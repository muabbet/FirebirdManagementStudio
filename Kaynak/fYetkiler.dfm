object frmYetkiler: TfrmYetkiler
  Left = 0
  Top = 0
  BorderStyle = bsDialog
  ClientHeight = 420
  ClientWidth = 640
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -13
  Font.Name = 'Segoe UI'
  Font.Style = []
  Position = poOwnerFormCenter
  OnShow = FormShow
  object lblBilgi: TLabel
    AlignWithMargins = True
    Left = 12
    Top = 12
    Width = 616
    Height = 17
    Margins.Left = 12
    Margins.Top = 12
    Margins.Right = 12
    Margins.Bottom = 6
    Align = alTop
    WordWrap = True
  end
  object pnlAlt: TPanel
    Left = 0
    Top = 368
    Width = 640
    Height = 52
    Align = alBottom
    BevelOuter = bvNone
    TabOrder = 1
    object btnKapat: TButton
      AlignWithMargins = True
      Left = 552
      Top = 8
      Width = 80
      Height = 34
      Margins.Left = 4
      Margins.Top = 8
      Margins.Right = 8
      Margins.Bottom = 10
      Align = alRight
      Cancel = True
      Constraints.MinWidth = 80
      ModalResult = 2
      TabOrder = 3
    end
    object btnHepsi: TButton
      AlignWithMargins = True
      Left = 4
      Top = 8
      Width = 120
      Height = 34
      Margins.Left = 12
      Margins.Top = 8
      Margins.Right = 4
      Margins.Bottom = 10
      Align = alLeft
      Constraints.MinWidth = 120
      TabOrder = 2
      OnClick = btnHepsiClick
    end
    object btnAl: TButton
      AlignWithMargins = True
      Left = 130
      Top = 8
      Width = 120
      Height = 34
      Margins.Left = 4
      Margins.Top = 8
      Margins.Right = 4
      Margins.Bottom = 10
      Align = alLeft
      Constraints.MinWidth = 120
      TabOrder = 1
      OnClick = btnAlClick
    end
    object btnVer: TButton
      AlignWithMargins = True
      Left = 256
      Top = 8
      Width = 120
      Height = 34
      Margins.Left = 12
      Margins.Top = 8
      Margins.Right = 4
      Margins.Bottom = 10
      Align = alLeft
      Constraints.MinWidth = 120
      TabOrder = 0
      OnClick = btnVerClick
    end
  end
  object lvYetki: TListView
    AlignWithMargins = True
    Left = 12
    Top = 41
    Width = 616
    Height = 321
    Margins.Left = 12
    Margins.Right = 12
    Margins.Bottom = 4
    Align = alClient
    Columns = <
      item
        Width = 170
      end
      item
        Width = 110
      end
      item
        Width = 240
      end
      item
        Width = 90
      end>
    ReadOnly = True
    RowSelect = True
    TabOrder = 0
    ViewStyle = vsReport
  end
end