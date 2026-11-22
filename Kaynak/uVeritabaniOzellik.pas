{ uVeritabaniOzellik.pas - Veritabani ozellikleri: gosterme ve uc ayari degistirme (7y).

  Hedeflenen Firebird surumleri: 2.5, 3.0, 4.0, 5.0
  Denenen Firebird surumleri: 3.0.14, 4.0.7 (testler)

  Okuma: MON$DATABASE (+ RDB$DATABASE karakter seti). Degerler HER ZAMAN gecici yeni bir baglantiyla okunur: acik
  baglanti bu ayarlari baglandigi andaki haliyle tutabilir, degisiklikten sonra eski deger gorunurdu.
  Degistirme: gfix ile (sunucuyu kapatmak ya da baska baglantilari koparmak GEREKMEZ, 3.0.14'te olculdu):
    - sweep araligi        gfix -h N          (0 = otomatik sweep kapali)
    - yazma kipi           gfix -w sync|async (sync = forced writes acik, guvenli)
    - yer ayirma           gfix -use reserve|full
  Bilerek yok: salt okunur kip, dialect, sayfa boyutu (yalniz yedek / geri yukleme ile degisir), kapatma kipleri.
  Sifre komut satirina yazilmaz (yalniz ISC_PASSWORD, uYedek.AltIslemCalistir). }
unit uVeritabaniOzellik;

interface

uses
  System.SysUtils, uBaglanti;

type
  TVeritabaniOzellikleri = record
    Yol: string;
    Surum: string;
    Ods: string;
    SayfaBoyutu: Integer;
    SayfaSayisi: Int64;
    Dialect: Integer;
    KarakterSeti: string;
    SweepAraligi: Integer;
    { True = yazmalar hemen diske (forced writes acik, onerilen) }
    ZorlaYaz: Boolean;
    { True = her sayfada eski kayit surumleri icin yer ayrilir (varsayilan) }
    YerAyir: Boolean;
    SaltOkunur: Boolean;
    { MON$DATABASE okunamadi (cok eski surum ya da yetki): alanlar bos / 0 }
    Okunamadi: Boolean;
  end;

  TOzellikSonucu = record
    Basarili: Boolean;
    { Basarisizsa anlasilir cumle }
    Cumle: string;
    { Calisan komut (sifresiz), mesaj alani icin }
    Komut: string;
    { Aracin ham ciktisi }
    Ham: string;
  end;

{ gfix.exe istemci klasorunde var mi? }
function GfixVarMi: Boolean;

{ Ozellikleri gecici baglantiyla okur. Hata istisna olarak gelmez, Okunamadi True olur. }
function OzellikleriOku(Bag: TAcikBaglanti): TVeritabaniOzellikleri;

{ Sweep araligi (0 = kapali) }
function SweepAraliginiAyarla(Bag: TAcikBaglanti; Aralik: Integer): TOzellikSonucu;
{ Forced writes: True = acik (senkron), False = kapali (asenkron) }
function ZorlaYaziAyarla(Bag: TAcikBaglanti; Acik: Boolean): TOzellikSonucu;
{ Yer ayirma: True = ayir (reserve), False = sayfalari doldur (full) }
function YerAyirmayiAyarla(Bag: TAcikBaglanti; Ayir: Boolean): TOzellikSonucu;

implementation

uses
  System.Classes, System.IOUtils, System.StrUtils, System.Variants, Data.DB,
  FireDAC.Comp.Client, uDil, uPaket, uYedek;

function GfixYolu: string;
begin
  Result := TPath.Combine(PaketKlasoru, 'istemci\gfix.exe');
end;

function GfixVarMi: Boolean;
begin
  Result := TFile.Exists(GfixYolu);
end;

{ ---------- Okuma ---------- }

function OzellikleriOku(Bag: TAcikBaglanti): TVeritabaniOzellikleri;
var
  Gecici: TAcikBaglanti;
  Sorgu: TFDQuery;
begin
  Result := Default(TVeritabaniOzellikleri);
  Result.Yol := Bag.Tanim.VeritabaniYolu;
  Result.Surum := Bag.Surum;
  Result.Okunamadi := True;
  try
    Gecici := FbGeciciBaglan(Bag.Tanim);
    try
      Sorgu := TFDQuery.Create(nil);
      try
        Sorgu.Connection := Gecici.Baglanti;
        Sorgu.SQL.Text := 'select mon$page_size, mon$ods_major, mon$ods_minor, mon$sql_dialect, mon$sweep_interval, ' +
          'mon$forced_writes, mon$reserve_space, mon$read_only, mon$pages from mon$database';
        Sorgu.Open;
        Result.SayfaBoyutu := Sorgu.Fields[0].AsInteger;
        Result.Ods := Sorgu.Fields[1].AsString + '.' + Sorgu.Fields[2].AsString;
        Result.Dialect := Sorgu.Fields[3].AsInteger;
        Result.SweepAraligi := Sorgu.Fields[4].AsInteger;
        Result.ZorlaYaz := Sorgu.Fields[5].AsInteger <> 0;
        Result.YerAyir := Sorgu.Fields[6].AsInteger <> 0;
        Result.SaltOkunur := Sorgu.Fields[7].AsInteger <> 0;
        Result.SayfaSayisi := Sorgu.Fields[8].AsLargeInt;
        Result.Okunamadi := False;
        Sorgu.Close;
        Sorgu.SQL.Text := 'select rdb$character_set_name from rdb$database';
        Sorgu.Open;
        Result.KarakterSeti := Trim(Sorgu.Fields[0].AsString);
      finally
        Sorgu.Free;
      end;
    finally
      Gecici.Free;
    end;
  except
    { MON$ okunamazsa pencere "okunamadi" yazar, program durmaz }
  end;
end;

{ ---------- Degistirme ---------- }

function AracHatasiCumlesi(const Ham: string): string;
begin
  if ContainsText(Ham, 'user name and password') or ContainsText(Ham, 'authentication error') or
    ContainsText(Ham, 'error occurred during login') or ContainsText(Ham, 'incorrect user name') then
    Result := T('ERR_SIFRE')
  else if ContainsText(Ham, 'network request') or ContainsText(Ham, 'connection refused') or
    ContainsText(Ham, 'failed to establish a connection') or ContainsText(Ham, 'unavailable database') then
    Result := T('ERR_SUNUCU')
  else if ContainsText(Ham, 'connection lost') or ContainsText(Ham, 'error reading data from the connection') then
    Result := T('ERR_KOPTU')
  else if ContainsText(Ham, 'no permission') or ContainsText(Ham, 'owner') or ContainsText(Ham, 'sysdba') or
    ContainsText(Ham, 'privilege') then
    Result := T('ERR_OZELLIK_YETKI')
  else
    Result := T('ERR_OZELLIK_GENEL');
end;

{ gfix'i calistirir. Anahtar: "-h 30000" gibi; komut mesaj alani icin "gfix -h 30000" olur. }
function GfixCalistir(Bag: TAcikBaglanti; const Anahtar: string): TOzellikSonucu;
var
  Arguman, Ham: string;
  Kod: Cardinal;
begin
  Result := Default(TOzellikSonucu);
  Result.Komut := 'gfix ' + Anahtar;
  if not GfixVarMi then
  begin
    Result.Cumle := T('ERR_OZELLIK_ARAC_YOK');
    Exit;
  end;
  Arguman := Anahtar;
  if Bag.Tanim.Kullanici <> '' then
    Arguman := Arguman + ' -user "' + Bag.Tanim.Kullanici + '"';
  Arguman := Arguman + ' "' + GbakBaglantiMetni(Bag.Tanim, Bag.Tanim.VeritabaniYolu) + '"';
  try
    if AltIslemCalistir(GfixYolu, Arguman, Bag.Tanim.Sifre, nil, Ham, Kod) and (Kod = 0) then
      Result.Basarili := True
    else
      Result.Cumle := AracHatasiCumlesi(Ham);
    Result.Ham := Ham;
  except
    on E: Exception do
    begin
      Result.Cumle := E.Message;
      Result.Ham := E.Message;
    end;
  end;
end;

function SweepAraliginiAyarla(Bag: TAcikBaglanti; Aralik: Integer): TOzellikSonucu;
begin
  if Aralik < 0 then
  begin
    Result := Default(TOzellikSonucu);
    Result.Cumle := T('ERR_OZELLIK_SWEEP_DEGER');
    Exit;
  end;
  Result := GfixCalistir(Bag, '-h ' + IntToStr(Aralik));
end;

function ZorlaYaziAyarla(Bag: TAcikBaglanti; Acik: Boolean): TOzellikSonucu;
begin
  if Acik then
    Result := GfixCalistir(Bag, '-w sync')
  else
    Result := GfixCalistir(Bag, '-w async');
end;

function YerAyirmayiAyarla(Bag: TAcikBaglanti; Ayir: Boolean): TOzellikSonucu;
begin
  if Ayir then
    Result := GfixCalistir(Bag, '-use reserve')
  else
    Result := GfixCalistir(Bag, '-use full');
end;

end.
