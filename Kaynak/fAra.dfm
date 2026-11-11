object frmAra: TfrmAra
  Left = 0
  Top = 0
  BorderStyle = bsSizeable
  ClientHeight = 440
  ClientWidth = 720
  Color = clBtnFace
  Constraints.MinHeight = 320
  Constraints.MinWidth = 560
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -13
  Font.Name = 'Segoe UI'
  Font.Style = []
  Position = poOwnerFormCenter
  object pnlUst: TPanel
    Left = 0
    Top = 0
    Width = 720
    Height = 76
    Align = alTop
    BevelOuter = bvNone
    TabOrder = 0
    object lblYazi: TLabel
      Left = 12
      Top = 12
      Width = 4
      Height = 17
    end
    object btnAra: TButton
      AlignWithMargins = True
      Left = 628
      Top = 33
      Width = 80
      Height = 27
      Margins.Left = 4
      Margins.Top = 33
      Margins.Right = 12
      Margins.Bottom = 16
      Align = alRight
      Constraints.MinWidth = 80
      Default = True
      TabOrder = 1
      OnClick = btnAraClick
    end
    object edtYazi: TEdit
      AlignWithMargins = True
      Left = 12
      Top = 33
      Width = 608
      Height = 25
      Margins.Left = 12
      Margins.Top = 33
      Margins.Right = 0
      Margins.Bottom = 18
      Align = alClient
      TabOrder = 0
    end
    object chkKaynak: TCheckBox
      Left = 12
      Top = 58
      Width = 600
      Height = 17
      TabOrder = 2
    end
  end
  object pnlAlt: TPanel
    Left = 0
    Top = 388
    Width = 720
    Height = 52
    Align = alBottom
    BevelOuter = bvNone
    TabOrder = 2
    object lblSayi: TLabel
      AlignWithMargins = True
      Left = 12
      Top = 8
      Width = 4
      Height = 34
      Margins.Left = 12
      Margins.Top = 8
      Margins.Bottom = 10
      Align = alClient
      Layout = tlCenter
    end
    object btnKapat: TButton
      AlignWithMargins = True
      Left = 632
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
      TabOrder = 1
    end
    object btnAc: TButton
      AlignWithMargins = True
      Left = 548
      Top = 8
      Width = 80
      Height = 34
      Margins.Left = 4
      Margins.Top = 8
      Margins.Right = 4
      Margins.Bottom = 10
      Align = alRight
      Constraints.MinWidth = 80
      TabOrder = 0
      OnClick = btnAcClick
    end
  end
  object lvSonuc: TListView
    AlignWithMargins = True
    Left = 12
    Top = 76
    Width = 696
    Height = 306
    Margins.Left = 12
    Margins.Top = 0
    Margins.Right = 12
    Margins.Bottom = 6
    Align = alClient
    Columns = <
      item
        Width = 100
      end
      item
        Width = 200
      end
      item
        Width = 80
      end
      item
        Width = 290
      end>
    ReadOnly = True
    RowSelect = True
    TabOrder = 1
    ViewStyle = vsReport
    OnDblClick = lvSonucDblClick
  end
end
