object frmAcilis: TfrmAcilis
  Left = 0
  Top = 0
  BorderStyle = bsNone
  Caption = 'Firebird Management Studio'
  ClientHeight = 300
  ClientWidth = 560
  Color = 16579320
  Font.Charset = DEFAULT_CHARSET
  Font.Color = 3548447
  Font.Height = -13
  Font.Name = 'Segoe UI'
  Font.Style = []
  Position = poScreenCenter
  StyleElements = []
  object pnlCerceve: TPanel
    Left = 0
    Top = 0
    Width = 560
    Height = 300
    Align = alClient
    BevelOuter = bvNone
    Color = 15260125
    Padding.Left = 1
    Padding.Top = 1
    Padding.Right = 1
    Padding.Bottom = 1
    ParentBackground = False
    StyleElements = []
    TabOrder = 0
    object pnlIc: TPanel
      Left = 1
      Top = 1
      Width = 558
      Height = 298
      Align = alClient
      BevelOuter = bvNone
      Color = 16579320
      ParentBackground = False
      StyleElements = []
      TabOrder = 0
      object shpSerit: TShape
        Left = 0
        Top = 0
        Width = 558
        Height = 6
        Align = alTop
        Brush.Color = 14187835
        Pen.Style = psClear
      end
      object imgLogo: TImage
        Left = 44
        Top = 72
        Width = 80
        Height = 80
        Proportional = True
        Stretch = True
        Transparent = True
      end
      object lblAd: TLabel
        Left = 132
        Top = 84
        Width = 394
        Height = 41
        AutoSize = False
        Font.Charset = DEFAULT_CHARSET
        Font.Color = 3548447
        Font.Height = -29
        Font.Name = 'Segoe UI Semibold'
        Font.Style = []
        ParentFont = False
        StyleElements = []
      end
      object lblAlt: TLabel
        Left = 134
        Top = 128
        Width = 392
        Height = 20
        AutoSize = False
        Font.Charset = DEFAULT_CHARSET
        Font.Color = 8421504
        Font.Height = -15
        Font.Name = 'Segoe UI'
        Font.Style = []
        ParentFont = False
        StyleElements = []
      end
      object lblSurum: TLabel
        Left = 48
        Top = 252
        Width = 200
        Height = 17
        AutoSize = False
        Font.Charset = DEFAULT_CHARSET
        Font.Color = 8421504
        Font.Height = -13
        Font.Name = 'Segoe UI'
        Font.Style = []
        ParentFont = False
        StyleElements = []
      end
      object lblDurum: TLabel
        Left = 310
        Top = 252
        Width = 200
        Height = 17
        Alignment = taRightJustify
        AutoSize = False
        Font.Charset = DEFAULT_CHARSET
        Font.Color = 8421504
        Font.Height = -13
        Font.Name = 'Segoe UI'
        Font.Style = []
        ParentFont = False
        StyleElements = []
      end
      object barBekle: TProgressBar
        Left = 48
        Top = 232
        Width = 462
        Height = 6
        Style = pbstMarquee
        TabOrder = 0
      end
    end
  end
end
