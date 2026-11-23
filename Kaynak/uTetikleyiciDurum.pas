{ uTetikleyiciDurum.pas - Tetikleyiciyi aktif / pasif yapma (ALTER TRIGGER ad ACTIVE | INACTIVE).

  Hedeflenen Firebird surumleri: 2.5, 3.0, 4.0, 5.0
  Test edilen Firebird surumleri: 3.0.14, 4.0.7 (bkz. Test\TetikleyiciDurumTest.dpr)

  Tablo, veritabani ve DDL tetikleyicisinde ayni komut calisir. Komut tek ACIK islemde calisir (commit / hatada rollback).
  Tetikleyicinin tanimi degismedigi icin yedek alinmaz. Hata istisna olarak firlamaz, TProsedurSonucu'na yazilir. }
unit uTetikleyiciDurum;

interface

uses
  System.SysUtils,
  uDil, uBaglanti, uMetadata, uDDL, uProsedur;

{ Tetikleyici veritabaninda varsa True; Aktif'e simdiki durumu yazar. }
function TetikleyiciDurumuOku(Bag: TAcikBaglanti; const Ad: string; out Aktif: Boolean): Boolean;
{ Calisacak komut: ALTER TRIGGER "AD" ACTIVE | INACTIVE (sonunda ; yok). }
function TetikleyiciDurumKomutu(Bag: TAcikBaglanti; const Ad: string; Aktif: Boolean): string;
{ Onay penceresinin metni: ne olacak, pasifken ne olur, calisacak komut. }
function TetikleyiciDurumOnayMetni(Bag: TAcikBaglanti; const Ad: string; Aktif: Boolean): string;
{ Durumu ayarlar. Tetikleyici yoksa Basarili = False ve anlasilir cumle; Komutlar bos kalir (veritabanina dokunulmadi). }
function TetikleyiciDurumAyarla(Bag: TAcikBaglanti; const Ad: string; Aktif: Boolean): TProsedurSonucu;

implementation

function TetikleyiciDurumuOku(Bag: TAcikBaglanti; const Ad: string; out Aktif: Boolean): Boolean;
var
  Tetik: TTetikleyiciBilgisi;
begin
  { Agacin kullandigi liste (govde metni olmadan, hizli); sistem tetikleyicileri gelmez. }
  Result := False;
  Aktif := True;
  for Tetik in TetikleyicileriListele(Bag) do
    if Tetik.Ad = Ad then
    begin
      Aktif := Tetik.Aktif;
      Exit(True);
    end;
end;

function TetikleyiciDurumKomutu(Bag: TAcikBaglanti; const Ad: string; Aktif: Boolean): string;
begin
  Result := 'ALTER TRIGGER ' + AdiYaz(Bag, Ad);
  if Aktif then
    Result := Result + ' ACTIVE'
  else
    Result := Result + ' INACTIVE';
end;

function TetikleyiciDurumOnayMetni(Bag: TAcikBaglanti; const Ad: string; Aktif: Boolean): string;
var
  Komut: string;
begin
  Komut := TetikleyiciDurumKomutu(Bag, Ad, Aktif) + ';';
  if Aktif then
    Result := TF('TETIK_ONAY_AKTIF', [Ad, Komut])
  else
    Result := TF('TETIK_ONAY_PASIF', [Ad, Komut]);
end;

function TetikleyiciDurumAyarla(Bag: TAcikBaglanti; const Ad: string; Aktif: Boolean): TProsedurSonucu;
var
  Simdiki: Boolean;
begin
  Result := Default(TProsedurSonucu);
  try
    if not TetikleyiciDurumuOku(Bag, Ad, Simdiki) then
    begin
      Result.Cumle := TF('TETIK_ERR_YOK', [Ad]);
      Exit;
    end;
  except
    on E: Exception do
    begin
      Result.Cumle := HataMetniniCevir(E);
      Result.Ayrinti := E.Message;
      Exit;
    end;
  end;
  MetniCalistir(Bag, TetikleyiciDurumKomutu(Bag, Ad, Aktif), Result);
end;

end.
