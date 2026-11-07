object frmBakim: TfrmBakim
  Left = 0
  Top = 0
  BorderStyle = bsSizeable
  ClientHeight = 560
  ClientWidth = 980
  Color = clBtnFace
  Constraints.MinHeight = 380
  Constraints.MinWidth = 700
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -13
  Font.Name = 'Segoe UI'
  Font.Style = []
  Position = poOwnerFormCenter
  OnCloseQuery = FormCloseQuery
  object pnlUst: TPanel
    Left = 0
    Top = 0
    Width = 980
    Height = 48
    Align = alTop
    BevelOuter = bvNone
    TabOrder = 0
    object btnRapor: TButton
      AlignWithMargins = True
      Left = 12
      Top = 8
      Width = 120
      Height = 32
      Margins.Left = 12
      Margins.Top = 8
      Margins.Right = 8
      Margins.Bottom = 8
      Align = alLeft
      Constraints.MinWidth = 120
      TabOrder = 0
      OnClick = btnRaporClick
    end
    object chkTarama: TCheckBox
      AlignWithMargins = True
      Left = 144
      Top = 8
      Width = 820
      Height = 32
      Margins.Top = 8
      Margins.Bottom = 8
      Align = alClient
      Checked = True
      State = cbChecked
      TabOrder = 1
    end
  end
  object pgSekmeler: TPageControl
    AlignWithMargins = True
    Left = 12
    Top = 48
    Width = 956
    Height = 440
    Margins.Left = 12
    Margins.Top = 0
    Margins.Right = 12
    Margins.Bottom = 4
    ActivePage = tsOzet
    Align = alClient
    TabOrder = 1
    object tsOzet: TTabSheet
      object memOzet: TMemo
        Left = 0
        Top = 0
        Width = 948
        Height = 410
        Align = alClient
        ReadOnly = True
        ScrollBars = ssVertical
        TabOrder = 0
      end
    end
    object tsTablolar: TTabSheet
      object lvTablolar: TListView
        Left = 0
        Top = 0
        Width = 948
        Height = 410
        Align = alClient
        Columns = <
          item
            Width = 200
          end
          item
            Alignment = taRightJustify
            Width = 100
          end
          item
            Alignment = taRightJustify
            Width = 160
          end
          item
            Alignment = taRightJustify
            Width = 110
          end
          item
            Alignment = taRightJustify
            Width = 120
          end
          item
            Width = 170
          end>
        ReadOnly = True
        RowSelect = True
        TabOrder = 0
        ViewStyle = vsReport
      end
    end
    object tsIndeksler: TTabSheet
      object lvIndeksler: TListView
        Left = 0
        Top = 0
        Width = 948
        Height = 410
        Align = alClient
        Columns = <
          item
            Width = 200
          end
          item
            Width = 150
          end
          item
            Width = 110
          end
          item
            Alignment = taRightJustify
            Width = 80
          end
          item
            Alignment = taRightJustify
            Width = 100
          end
          item
            Alignment = taRightJustify
            Width = 90
          end
          item
            Alignment = taRightJustify
            Width = 110
          end
          item
            Width = 220
          end>
        ReadOnly = True
        RowSelect = True
        TabOrder = 0
        ViewStyle = vsReport
      end
    end
    object tsIsler: TTabSheet
      object memIsler: TMemo
        Left = 0
        Top = 0
        Width = 948
        Height = 410
        Align = alClient
        ReadOnly = True
        ScrollBars = ssVertical
        TabOrder = 0
      end
    end
  end
  object pnlAlt: TPanel
    Left = 0
    Top = 492
    Width = 980
    Height = 68
    Align = alBottom
    BevelOuter = bvNone
    TabOrder = 2
    object lblDurum: TLabel
      AlignWithMargins = True
      Left = 12
      Top = 3
      Width = 956
      Height = 18
      Margins.Left = 12
      Margins.Right = 12
      Align = alTop
      AutoSize = False
    end
    object btnBaslat: TButton
      AlignWithMargins = True
      Left = 12
      Top = 24
      Width = 140
      Height = 34
      Margins.Left = 12
      Margins.Top = 4
      Margins.Right = 4
      Margins.Bottom = 10
      Align = alLeft
      Constraints.MinWidth = 140
      TabOrder = 0
      OnClick = btnBaslatClick
    end
    object btnIptal: TButton
      AlignWithMargins = True
      Left = 160
      Top = 24
      Width = 80
      Height = 34
      Margins.Left = 4
      Margins.Top = 4
      Margins.Right = 4
      Margins.Bottom = 10
      Align = alLeft
      Constraints.MinWidth = 80
      TabOrder = 1
      OnClick = btnIptalClick
    end
    object btnKapat: TButton
      AlignWithMargins = True
      Left = 892
      Top = 24
      Width = 80
      Height = 34
      Margins.Left = 4
      Margins.Top = 4
      Margins.Right = 8
      Margins.Bottom = 10
      Align = alRight
      Cancel = True
      Constraints.MinWidth = 80
      ModalResult = 2
      TabOrder = 2
    end
  end
end
