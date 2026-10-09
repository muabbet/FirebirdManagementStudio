{ uOnay.pas - Evet/Hayir onay penceresi ve Tamam uyari penceresi.
  Dugme yazilari secili dilden gelir. Tehlikeli islemler OnayIste'yi kullanir. }
unit uOnay;

interface

uses
  System.SysUtils, System.Classes, Vcl.Controls, Vcl.Forms, Vcl.StdCtrls,
  Vcl.Dialogs,
  uDil;

function OnayIste(const Soru: string): Boolean;
procedure UyariGoster(const Metin: string);

implementation

procedure DugmeYazilariniYaz(Pencere: TForm);
var
  i: Integer;
  Dugme: TButton;
begin
  for i := 0 to Pencere.ComponentCount - 1 do
    if Pencere.Components[i] is TButton then
    begin
      Dugme := TButton(Pencere.Components[i]);
      if Dugme.ModalResult = mrYes then
        Dugme.Caption := T('BTN_EVET')
      else if Dugme.ModalResult = mrNo then
        Dugme.Caption := T('BTN_HAYIR')
      else if Dugme.ModalResult = mrOk then
        Dugme.Caption := T('BTN_TAMAM');
    end;
end;

function OnayIste(const Soru: string): Boolean;
var
  Pencere: TForm;
begin
  Pencere := CreateMessageDialog(Soru, mtConfirmation, [mbYes, mbNo], mbNo);
  try
    Pencere.Caption := T('ONAY_BASLIK');
    DugmeYazilariniYaz(Pencere);
    Result := Pencere.ShowModal = mrYes;
  finally
    Pencere.Free;
  end;
end;

procedure UyariGoster(const Metin: string);
var
  Pencere: TForm;
begin
  Pencere := CreateMessageDialog(Metin, mtWarning, [mbOK], mbOK);
  try
    Pencere.Caption := T('UYARI_BASLIK');
    DugmeYazilariniYaz(Pencere);
    Pencere.ShowModal;
  finally
    Pencere.Free;
  end;
end;

end.
