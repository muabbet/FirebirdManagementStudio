object ProsedurSekme: TProsedurSekme
  Left = 0
  Top = 0
  Width = 720
  Height = 480
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
    object btnKaydet: TButton
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
      OnClick = btnKaydetClick
    end
  end
  object pnlEditor: TPanel
    Left = 0
    Top = 40
    Width = 720
    Height = 440
    Align = alClient
    BevelOuter = bvNone
    TabOrder = 1
  end
end
