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
{ Degisiklik kaydedilsin mi? mrYes = kaydet, mrNo = kaydetme, mrCancel = vazgec. }
function KaydetSor(const Soru: string): TModalResult;

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

{ Kaydet / Kaydetme / Iptal sorusu. Dugme yazilari uzun olabilir (Almanca); dugmeler yaziya gore genisletilip
  sagdan sola dizilir, pencere gerekirse genisler. Sonuc: mrYes (kaydet), mrNo (kaydetme), mrCancel. }
function KaydetSor(const Soru: string): TModalResult;
var
  Pencere: TForm;
  Dugmeler: TArray<TButton>;
  Dugme: TButton;
  i, Sag, Genislik, Bosluk: Integer;
  Tuval: TControlCanvas;
begin
  Pencere := CreateMessageDialog(Soru, mtConfirmation, [mbYes, mbNo, mbCancel], mbYes);
  try
    Pencere.Caption := T('ONAY_BASLIK');
    for i := 0 to Pencere.ComponentCount - 1 do
      if Pencere.Components[i] is TButton then
      begin
        Dugme := TButton(Pencere.Components[i]);
        if Dugme.ModalResult = mrYes then
          Dugme.Caption := T('BTN_SQL_KAYDET')
        else if Dugme.ModalResult = mrNo then
          Dugme.Caption := T('BTN_KAYDETME')
        else if Dugme.ModalResult = mrCancel then
          Dugme.Caption := T('BTN_IPTAL');
        Dugmeler := Dugmeler + [Dugme];
      end;
    Tuval := TControlCanvas.Create;
    try
      Bosluk := 8;
      Genislik := 0;
      for Dugme in Dugmeler do
      begin
        Tuval.Control := Dugme;
        Tuval.Font.Assign(Dugme.Font);
        Dugme.Width := Tuval.TextWidth(Dugme.Caption) + 32;
        if Dugme.Width < 77 then
          Dugme.Width := 77;
        Genislik := Genislik + Dugme.Width + Bosluk;
      end;
    finally
      Tuval.Free;
    end;
    if Genislik + 16 > Pencere.ClientWidth then
      Pencere.ClientWidth := Genislik + 16;
    { Dugmeler yan yana: mrYes, mrNo, mrCancel sirasi soldan saga. }
    Sag := Pencere.ClientWidth - 8;
    for i := Length(Dugmeler) - 1 downto 0 do
    begin
      Dugmeler[i].Left := Sag - Dugmeler[i].Width;
      Sag := Dugmeler[i].Left - Bosluk;
    end;
    Result := Pencere.ShowModal;
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
