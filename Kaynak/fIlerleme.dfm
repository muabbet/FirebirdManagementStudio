object frmIlerleme: TfrmIlerleme
  Left = 0
  Top = 0
  BorderIcons = []
  BorderStyle = bsDialog
  ClientHeight = 186
  ClientWidth = 540
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -13
  Font.Name = 'Segoe UI'
  Font.Style = []
  Position = poMainFormCenter
  OnCloseQuery = FormCloseQuery
  object lblBaslik: TLabel
    Left = 16
    Top = 14
    Width = 508
    Height = 20
    AutoSize = False
    Font.Charset = DEFAULT_CHARSET
    Font.Color = clWindowText
    Font.Height = -15
    Font.Name = 'Segoe UI'
    Font.Style = [fsBold]
    ParentFont = False
  end
  object lblDetay: TLabel
    Left = 16
    Top = 40
    Width = 508
    Height = 66
    AutoSize = False
    WordWrap = True
  end
  object lblSure: TLabel
    Left = 16
    Top = 144
    Width = 340
    Height = 17
    AutoSize = False
  end
  object pbIlerleme: TProgressBar
    Left = 16
    Top = 114
    Width = 508
    Height = 18
    MarqueeInterval = 30
    Style = pbstMarquee
    TabOrder = 0
  end
  object btnIptal: TButton
    Left = 424
    Top = 140
    Width = 100
    Height = 30
    Constraints.MinWidth = 100
    TabOrder = 1
    OnClick = btnIptalClick
  end
end
