object frmVeritabaniOzellik: TfrmVeritabaniOzellik
  Left = 0
  Top = 0
  BorderStyle = bsDialog
  ClientHeight = 520
  ClientWidth = 560
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -13
  Font.Name = 'Segoe UI'
  Font.Style = []
  Position = poOwnerFormCenter
  object lblNot: TLabel
    Left = 12
    Top = 256
    Width = 536
    Height = 34
    AutoSize = False
    WordWrap = True
  end
  object lvOzellik: TListView
    Left = 12
    Top = 12
    Width = 536
    Height = 238
    Columns = <
      item
        Width = 190
      end
      item
        Width = 320
      end>
    ReadOnly = True
    RowSelect = True
    TabOrder = 0
    ViewStyle = vsReport
  end
  object grpAyar: TGroupBox
    Left = 12
    Top = 296
    Width = 536
    Height = 160
    TabOrder = 1
    object lblSweep: TLabel
      Left = 16
      Top = 28
      Width = 500
      Height = 17
      AutoSize = False
    end
    object lblSweepIpucu: TLabel
      Left = 150
      Top = 54
      Width = 370
      Height = 34
      AutoSize = False
      WordWrap = True
    end
    object spnSweep: TSpinEdit
      Left = 16
      Top = 50
      Width = 120
      Height = 27
      MaxValue = 2147483647
      MinValue = 0
      TabOrder = 0
      Value = 0
    end
    object chkZorla: TCheckBox
      Left = 16
      Top = 94
      Width = 504
      Height = 21
      TabOrder = 1
    end
    object chkYer: TCheckBox
      Left = 16
      Top = 122
      Width = 504
      Height = 21
      TabOrder = 2
    end
  end
  object pnlAlt: TPanel
    Left = 0
    Top = 468
    Width = 560
    Height = 52
    Align = alBottom
    BevelOuter = bvNone
    TabOrder = 2
    object btnKapat: TButton
      AlignWithMargins = True
      Left = 472
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
    object btnYenile: TButton
      AlignWithMargins = True
      Left = 388
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
      OnClick = btnYenileClick
    end
    object btnUygula: TButton
      AlignWithMargins = True
      Left = 304
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
      OnClick = btnUygulaClick
    end
  end
end
