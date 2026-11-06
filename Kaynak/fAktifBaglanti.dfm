object frmAktifBaglanti: TfrmAktifBaglanti
  Left = 0
  Top = 0
  BorderStyle = bsSizeable
  ClientHeight = 480
  ClientWidth = 960
  Color = clBtnFace
  Constraints.MinHeight = 320
  Constraints.MinWidth = 640
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -13
  Font.Name = 'Segoe UI'
  Font.Style = []
  Position = poOwnerFormCenter
  object pnlUst: TPanel
    Left = 0
    Top = 0
    Width = 960
    Height = 56
    Align = alTop
    BevelOuter = bvNone
    TabOrder = 0
    object lblBilgi: TLabel
      Left = 12
      Top = 8
      Width = 936
      Height = 20
      AutoSize = False
      Font.Style = [fsBold]
      ParentFont = False
    end
    object lblYetki: TLabel
      Left = 12
      Top = 30
      Width = 936
      Height = 20
      AutoSize = False
    end
  end
  object gridBaglanti: TDBGrid
    AlignWithMargins = True
    Left = 12
    Top = 56
    Width = 936
    Height = 360
    Margins.Left = 12
    Margins.Top = 0
    Margins.Right = 12
    Margins.Bottom = 4
    Align = alClient
    DataSource = dsBaglanti
    TabOrder = 1
  end
  object pnlAlt: TPanel
    Left = 0
    Top = 428
    Width = 960
    Height = 52
    Align = alBottom
    BevelOuter = bvNone
    TabOrder = 2
    object btnYenile: TButton
      AlignWithMargins = True
      Left = 12
      Top = 8
      Width = 80
      Height = 34
      Margins.Left = 12
      Margins.Top = 8
      Margins.Right = 4
      Margins.Bottom = 10
      Align = alLeft
      Constraints.MinWidth = 80
      TabOrder = 0
      OnClick = btnYenileClick
    end
    object btnKopar: TButton
      AlignWithMargins = True
      Left = 100
      Top = 8
      Width = 80
      Height = 34
      Margins.Left = 4
      Margins.Top = 8
      Margins.Right = 4
      Margins.Bottom = 10
      Align = alLeft
      Constraints.MinWidth = 80
      TabOrder = 1
      OnClick = btnKoparClick
    end
    object btnKapat: TButton
      AlignWithMargins = True
      Left = 872
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
      TabOrder = 2
    end
  end
  object dsBaglanti: TDataSource
    Left = 40
    Top = 140
  end
end
