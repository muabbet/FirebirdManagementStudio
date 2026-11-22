object frmYedekPlan: TfrmYedekPlan
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
  object lblBaglanti: TLabel
    Left = 12
    Top = 12
    Width = 616
    Height = 17
    AutoSize = False
  end
  object lblKlasor: TLabel
    Left = 12
    Top = 40
    Width = 616
    Height = 17
    AutoSize = False
  end
  object lblSaat: TLabel
    Left = 12
    Top = 100
    Width = 200
    Height = 17
    AutoSize = False
  end
  object lblSakla: TLabel
    Left = 240
    Top = 100
    Width = 388
    Height = 17
    AutoSize = False
  end
  object lblNot: TLabel
    Left = 12
    Top = 156
    Width = 616
    Height = 92
    AutoSize = False
    WordWrap = True
  end
  object lblDurum: TLabel
    Left = 12
    Top = 252
    Width = 616
    Height = 34
    AutoSize = False
    WordWrap = True
  end
  object lblGunluk: TLabel
    Left = 12
    Top = 290
    Width = 616
    Height = 17
    AutoSize = False
  end
  object pbYedek: TProgressBar
    Left = 12
    Top = 424
    Width = 616
    Height = 16
    MarqueeInterval = 30
    Style = pbstMarquee
    TabOrder = 8
    Visible = False
  end
  object edtKlasor: TEdit
    Left = 12
    Top = 64
    Width = 500
    Height = 25
    TabOrder = 0
  end
  object btnKlasorSec: TButton
    Left = 520
    Top = 62
    Width = 108
    Height = 29
    Constraints.MinWidth = 108
    TabOrder = 1
    OnClick = btnKlasorSecClick
  end
  object dtpSaat: TDateTimePicker
    Left = 12
    Top = 122
    Width = 100
    Height = 25
    Date = 46000.083333333330000000
    Format = 'HH:mm'
    Time = 46000.083333333330000000
    Kind = dtkTime
    TabOrder = 2
  end
  object spnSakla: TSpinEdit
    Left = 240
    Top = 122
    Width = 80
    Height = 27
    MaxValue = 365
    MinValue = 1
    TabOrder = 3
    Value = 7
  end
  object memGunluk: TMemo
    Left = 12
    Top = 312
    Width = 616
    Height = 104
    Font.Charset = DEFAULT_CHARSET
    Font.Color = clWindowText
    Font.Height = -12
    Font.Name = 'Consolas'
    Font.Style = []
    ParentFont = False
    ReadOnly = True
    ScrollBars = ssBoth
    TabOrder = 4
    WordWrap = False
  end
  object pnlAlt: TPanel
    Left = 0
    Top = 448
    Width = 640
    Height = 52
    Align = alBottom
    BevelOuter = bvNone
    TabOrder = 5
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
      TabOrder = 3
      OnClick = btnKapatClick
    end
    object btnSimdi: TButton
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
      TabOrder = 2
      OnClick = btnSimdiClick
    end
    object btnKaldir: TButton
      AlignWithMargins = True
      Left = 384
      Top = 8
      Width = 80
      Height = 34
      Margins.Left = 4
      Margins.Top = 8
      Margins.Right = 4
      Margins.Bottom = 10
      Align = alRight
      Constraints.MinWidth = 80
      TabOrder = 1
      OnClick = btnKaldirClick
    end
    object btnPlanla: TButton
      AlignWithMargins = True
      Left = 300
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
      OnClick = btnPlanlaClick
    end
  end
  object dlgKlasor: TFileOpenDialog
    FavoriteLinks = <>
    FileTypes = <>
    Options = [fdoPickFolders]
    Left = 580
    Top = 340
  end
end
