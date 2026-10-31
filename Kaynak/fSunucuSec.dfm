object frmSunucuSec: TfrmSunucuSec
  Left = 0
  Top = 0
  BorderStyle = bsDialog
  ClientHeight = 300
  ClientWidth = 480
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -13
  Font.Name = 'Segoe UI'
  Font.Style = []
  Position = poOwnerFormCenter
  OnShow = FormShow
  object lblBilgi: TLabel
    AlignWithMargins = True
    Left = 12
    Top = 12
    Width = 456
    Height = 17
    Margins.Left = 12
    Margins.Top = 12
    Margins.Right = 12
    Margins.Bottom = 6
    Align = alTop
    WordWrap = True
  end
  object pnlAlt: TPanel
    Left = 0
    Top = 248
    Width = 480
    Height = 52
    Align = alBottom
    BevelOuter = bvNone
    TabOrder = 1
    object btnKapat: TButton
      AlignWithMargins = True
      Left = 392
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
    object btnSec: TButton
      AlignWithMargins = True
      Left = 308
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
      OnClick = btnSecClick
    end
  end
  object lvSunucu: TListView
    AlignWithMargins = True
    Left = 12
    Top = 41
    Width = 456
    Height = 201
    Margins.Left = 12
    Margins.Right = 12
    Margins.Bottom = 4
    Align = alClient
    Columns = <
      item
        Width = 170
      end
      item
        Width = 70
      end
      item
        Width = 180
      end>
    ReadOnly = True
    RowSelect = True
    TabOrder = 0
    ViewStyle = vsReport
    OnDblClick = btnSecClick
  end
end
