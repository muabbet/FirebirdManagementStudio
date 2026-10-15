{ uOnay.pas - Evet/Hayir onay penceresi ve Tamam uyari penceresi.
  Dugme yazilari secili dilden gelir. Tehlikeli islemler OnayIste'yi kullanir. }
unit uOnay;

interface

uses
  System.SysUtils, System.Classes, Vcl.Controls, Vcl.Forms, Vcl.StdCtrls,
  Vcl.Dialogs, Vcl.Graphics,
  uDil;

function OnayIste(const Soru: string): Boolean;
procedure UyariGoster(const Metin: string);

{ Dugme genisligi yaziya gore uzar (Almanca yazilar kesilmesin); en az Constraints.MinWidth. }
procedure DugmeyiYaziyaUydur(Dugme: TButton);

implementation

procedure DugmeyiYaziyaUydur(Dugme: TButton);
var
  Tuval: TControlCanvas;
begin
  Tuval := TControlCanvas.Create;
  try
    Tuval.Control := Dugme;
    Tuval.Font.Assign(Dugme.Font);
    Dugme.Width := Dugme.Constraints.MinWidth;
    if Tuval.TextWidth(Dugme.Caption) + 32 > Dugme.Width then
      Dugme.Width := Tuval.TextWidth(Dugme.Caption) + 32;
  finally
    Tuval.Free;
  end;
end;

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
