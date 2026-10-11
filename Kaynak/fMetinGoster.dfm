object frmMetinGoster: TfrmMetinGoster
  Left = 0
  Top = 0
  Caption = 'frmMetinGoster'
  ClientHeight = 420
  ClientWidth = 640
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -13
  Font.Name = 'Segoe UI'
  Font.Style = []
  Position = poOwnerFormCenter
  object memMetin: TMemo
    AlignWithMargins = True
    Left = 8
    Top = 8
    Width = 624
    Height = 352
    Margins.Left = 8
    Margins.Top = 8
    Margins.Right = 8
    Margins.Bottom = 0
    Align = alClient
    ReadOnly = True
    ScrollBars = ssBoth
    TabOrder = 0
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
      Default = True
      ModalResult = 1
      TabOrder = 0
    end
  end
end
