object frmIndeksOner: TfrmIndeksOner
  Left = 0
  Top = 0
  BorderStyle = bsSizeable
  ClientHeight = 560
  ClientWidth = 900
  Color = clBtnFace
  Constraints.MinHeight = 420
  Constraints.MinWidth = 640
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -13
  Font.Name = 'Segoe UI'
  Font.Style = []
  Position = poOwnerFormCenter
  object lblPlan: TLabel
    Left = 12
    Top = 10
    Width = 876
    Height = 17
    Anchors = [akLeft, akTop, akRight]
    AutoSize = False
    Font.Charset = DEFAULT_CHARSET
    Font.Color = clWindowText
    Font.Height = -13
    Font.Name = 'Segoe UI'
    Font.Style = [fsBold]
    ParentFont = False
  end
  object memPlan: TMemo
    Left = 12
    Top = 30
    Width = 876
    Height = 170
    Anchors = [akLeft, akTop, akRight]
    Font.Charset = DEFAULT_CHARSET
    Font.Color = clWindowText
    Font.Height = -12
    Font.Name = 'Consolas'
    Font.Style = []
    ParentFont = False
    ReadOnly = True
    ScrollBars = ssBoth
    TabOrder = 0
  end
  object lvOneriler: TListView
    Left = 12
    Top = 210
    Width = 876
    Height = 150
    Anchors = [akLeft, akTop, akRight]
    Checkboxes = True
    Columns = <
      item
        Width = 140
      end
      item
        Width = 200
      end
      item
        Width = 220
      end
      item
        Width = 600
      end>
    ReadOnly = True
    RowSelect = True
    TabOrder = 1
    ViewStyle = vsReport
  end
  object memNot: TMemo
    Left = 12
    Top = 370
    Width = 876
    Height = 120
    Anchors = [akLeft, akTop, akRight, akBottom]
    ReadOnly = True
    ScrollBars = ssVertical
    TabOrder = 2
  end
  object pnlAlt: TPanel
    Left = 0
    Top = 500
    Width = 900
    Height = 60
    Align = alBottom
    BevelOuter = bvNone
    TabOrder = 3
    object btnOlustur: TButton
      AlignWithMargins = True
      Left = 12
      Top = 8
      Width = 160
      Height = 34
      Margins.Left = 12
      Margins.Top = 8
      Margins.Right = 4
      Margins.Bottom = 12
      Align = alLeft
      Constraints.MinWidth = 160
      TabOrder = 0
      OnClick = btnOlusturClick
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
      TabOrder = 1
    end
  end
end
