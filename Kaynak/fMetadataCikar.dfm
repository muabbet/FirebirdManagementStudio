object frmMetadataCikar: TfrmMetadataCikar
  Left = 0
  Top = 0
  BorderStyle = bsDialog
  ClientHeight = 392
  ClientWidth = 560
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -13
  Font.Name = 'Segoe UI'
  Font.Style = []
  Position = poOwnerFormCenter
  OnCloseQuery = FormCloseQuery
  object gbHedef: TGroupBox
    Left = 12
    Top = 12
    Width = 536
    Height = 112
    TabOrder = 0
    object rbDosya: TRadioButton
      Left = 16
      Top = 26
      Width = 500
      Height = 21
      Checked = True
      TabOrder = 0
      TabStop = True
      OnClick = HedefDegisti
    end
    object edtDosya: TEdit
      Left = 36
      Top = 52
      Width = 340
      Height = 25
      TabOrder = 1
    end
    object btnGozat: TButton
      Left = 384
      Top = 50
      Width = 92
      Height = 29
      Constraints.MinWidth = 92
      TabOrder = 2
      OnClick = btnGozatClick
    end
    object rbPano: TRadioButton
      Left = 16
      Top = 84
      Width = 500
      Height = 21
      TabOrder = 3
      OnClick = HedefDegisti
    end
  end
  object gbSecenekler: TGroupBox
    Left = 12
    Top = 132
    Width = 536
    Height = 158
    TabOrder = 1
    object chkCreateDb: TCheckBox
      Left = 16
      Top = 26
      Width = 500
      Height = 21
      TabOrder = 0
      OnClick = SecenekDegisti
    end
    object chkConnect: TCheckBox
      Left = 16
      Top = 52
      Width = 500
      Height = 21
      TabOrder = 1
      OnClick = SecenekDegisti
    end
    object chkSifre: TCheckBox
      Left = 36
      Top = 78
      Width = 480
      Height = 21
      TabOrder = 2
      OnClick = SecenekDegisti
    end
    object lblUyari: TLabel
      Left = 36
      Top = 104
      Width = 480
      Height = 44
      AutoSize = False
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clRed
      Font.Height = -13
      Font.Name = 'Segoe UI'
      Font.Style = [fsBold]
      ParentFont = False
      Visible = False
      WordWrap = True
    end
  end
  object lblDurum: TLabel
    Left = 12
    Top = 298
    Width = 536
    Height = 36
    AutoSize = False
    WordWrap = True
  end
  object pnlAlt: TPanel
    Left = 0
    Top = 340
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
    object btnCikar: TButton
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
      OnClick = btnCikarClick
    end
  end
  object dlgKaydet: TSaveDialog
    DefaultExt = 'sql'
    Left = 500
    Top = 296
  end
end
