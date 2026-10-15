object frmCsvAktar: TfrmCsvAktar
  Left = 0
  Top = 0
  BorderStyle = bsDialog
  ClientHeight = 168
  ClientWidth = 560
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -13
  Font.Name = 'Segoe UI'
  Font.Style = []
  Position = poOwnerFormCenter
  OnCloseQuery = FormCloseQuery
  object lblDosya: TLabel
    Left = 12
    Top = 16
    Width = 536
    Height = 17
    AutoSize = False
  end
  object lblDurum: TLabel
    Left = 12
    Top = 90
    Width = 536
    Height = 36
    AutoSize = False
    WordWrap = True
  end
  object edtDosya: TEdit
    Left = 12
    Top = 40
    Width = 420
    Height = 25
    TabOrder = 0
  end
  object btnSec: TButton
    Left = 440
    Top = 38
    Width = 108
    Height = 29
    Constraints.MinWidth = 108
    TabOrder = 1
    OnClick = btnSecClick
  end
  object pnlAlt: TPanel
    Left = 0
    Top = 116
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
      TabOrder = 1
      OnClick = btnKapatClick
    end
    object btnBaslat: TButton
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
      Default = True
      TabOrder = 0
      OnClick = btnBaslatClick
    end
  end
  object dlgKaydet: TSaveDialog
    DefaultExt = 'csv'
    Left = 500
    Top = 80
  end
end
