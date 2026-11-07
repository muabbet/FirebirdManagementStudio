object frmYedek: TfrmYedek
  Left = 0
  Top = 0
  BorderStyle = bsDialog
  ClientHeight = 500
  ClientWidth = 640
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -13
  Font.Name = 'Segoe UI'
  Font.Style = []
  Position = poOwnerFormCenter
  OnCloseQuery = FormCloseQuery
  object lblKaynak: TLabel
    Left = 12
    Top = 70
    Width = 616
    Height = 17
    AutoSize = False
  end
  object lblHedef: TLabel
    Left = 12
    Top = 132
    Width = 616
    Height = 17
    AutoSize = False
  end
  object pbYedek: TProgressBar
    Left = 12
    Top = 374
    Width = 616
    Height = 16
    MarqueeInterval = 30
    Style = pbstMarquee
    TabOrder = 7
    Visible = False
  end
  object lblDurum: TLabel
    Left = 12
    Top = 396
    Width = 616
    Height = 48
    AutoSize = False
    WordWrap = True
  end
  object rgIslem: TRadioGroup
    Left = 12
    Top = 8
    Width = 616
    Height = 50
    Columns = 2
    TabOrder = 0
    OnClick = rgIslemClick
  end
  object edtKaynak: TEdit
    Left = 12
    Top = 94
    Width = 500
    Height = 25
    TabOrder = 1
  end
  object btnKaynakSec: TButton
    Left = 520
    Top = 92
    Width = 108
    Height = 29
    Constraints.MinWidth = 108
    TabOrder = 2
    OnClick = btnKaynakSecClick
  end
  object edtHedef: TEdit
    Left = 12
    Top = 156
    Width = 500
    Height = 25
    TabOrder = 3
  end
  object btnHedefSec: TButton
    Left = 520
    Top = 154
    Width = 108
    Height = 29
    Constraints.MinWidth = 108
    TabOrder = 4
    OnClick = btnHedefSecClick
  end
  object memCikti: TMemo
    Left = 12
    Top = 196
    Width = 616
    Height = 170
    Font.Charset = DEFAULT_CHARSET
    Font.Color = clWindowText
    Font.Height = -12
    Font.Name = 'Consolas'
    Font.Style = []
    ParentFont = False
    ReadOnly = True
    ScrollBars = ssBoth
    TabOrder = 5
    WordWrap = False
  end
  object pnlAlt: TPanel
    Left = 0
    Top = 448
    Width = 640
    Height = 52
    Align = alBottom
    BevelOuter = bvNone
    TabOrder = 6
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
      TabOrder = 1
      OnClick = btnKapatClick
    end
    object btnBaslat: TButton
      AlignWithMargins = True
      Left = 468
      Top = 8
      Width = 80
      Height = 34
      Margins.Left = 4
      Margins.Top = 8
      Margins.Right = 4
      Margins.Bottom = 10
      Align = alRight
      Constraints.MinWidth = 80
      Default = True
      TabOrder = 0
      OnClick = btnBaslatClick
    end
  end
  object dlgAc: TOpenDialog
    DefaultExt = 'fbk'
    Left = 580
    Top = 200
  end
  object dlgKaydet: TSaveDialog
    Left = 580
    Top = 240
  end
  object dlgGbak: TOpenDialog
    Left = 580
    Top = 280
  end
end
