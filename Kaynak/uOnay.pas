{ uOnay.pas - Evet/Hayir onay penceresi.
  Dugme yazilari secili dilden gelir. Tehlikeli islemler bu pencereyi kullanir. }
unit uOnay;

interface

uses
  System.SysUtils, System.Classes, Vcl.Controls, Vcl.Forms, Vcl.StdCtrls,
  Vcl.Dialogs,
  uDil;

function OnayIste(const Soru: string): Boolean;

implementation

function OnayIste(const Soru: string): Boolean;
var
  Pencere: TForm;
  i: Integer;
  Dugme: TButton;
begin
  Pencere := CreateMessageDialog(Soru, mtConfirmation, [mbYes, mbNo], mbNo);
  try
    Pencere.Caption := T('ONAY_BASLIK');
    for i := 0 to Pencere.ComponentCount - 1 do
      if Pencere.Components[i] is TButton then
      begin
        Dugme := TButton(Pencere.Components[i]);
        if Dugme.ModalResult = mrYes then
          Dugme.Caption := T('BTN_EVET')
        else if Dugme.ModalResult = mrNo then
          Dugme.Caption := T('BTN_HAYIR');
      end;
    Result := Pencere.ShowModal = mrYes;
  finally
    Pencere.Free;
  end;
end;

end.
