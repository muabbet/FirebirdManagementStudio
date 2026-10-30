{ uIndeksKisit.pas - Index ve kisit islemleri (Asama 3g-3).
    Index: olustur (UNIQUE, DESC), sil, aktif/pasif yap.
    Kisit: ekle (PRIMARY KEY, UNIQUE, FOREIGN KEY, CHECK), sil.

  Hedeflenen Firebird surumleri: 2.5, 3.0, 4.0, 5.0 (sozdizimi dortunde ayni, olculdu: bkz. ASAMA3G_RAPOR.md)

  Her islem uKolon ile ayni adimlarla calisir (uProsedur'un ortak parcalari):
    1. Tablonun tam CREATE script'i <veri klasoru>\_arsiv\<baglanti adi>\tablo_ADI_... olarak yedeklenir.
       Yazilamazsa islem DURUR, veritabanina dokunulmaz.
    2. Komut tek ACIK islemde calisir: basariliysa commit, hata verirse rollback.
  Hata istisna olarak firlamaz, TProsedurSonucu'na yazilir; form gosterir. }
unit uIndeksKisit;

interface

uses
  System.SysUtils, System.Classes, System.StrUtils,
  uDil, uBaglanti, uMetadata, uDDL, uProsedur, uNesneYonet;

type
  TYapiIslemi = (yiOlustur, yiSil, yiDurum);

  { Kolonlar: virgulle ayrilmis yazi ("A, B"). Pasif: mevcut durum (yiDurum bunun tersini yapar). }
  TIndeksGirdisi = record
    Tablo: string;
    Ad: string;
    Kolonlar: string;
    Benzersiz: Boolean;
    Azalan: Boolean;
    Pasif: Boolean;
  end;

  { Ad bos ise Firebird adi verir. SilKurali / GuncelleKurali: '' (varsayilan), CASCADE, SET NULL, SET DEFAULT, NO ACTION.
    Ifade: CHECK icin 'ID > 0' ('CHECK' sozcugu yazilmis olabilir). }
  TKisitGirdisi = record
    Tablo: string;
    Ad: string;
    Tur: TKisitTuru;
    Kolonlar: string;
    HedefTablo: string;
    HedefKolonlar: string;
    SilKurali: string;
    GuncelleKurali: string;
    Ifade: string;
  end;

{ Mevcut index / kisitin degerleri (sil ve durum islemleri icin). Yoksa EMetadataHatasi. }
function IndeksGirdisiOku(Bag: TAcikBaglanti; const Tablo, Ad: string): TIndeksGirdisi;
function KisitGirdisiOku(Bag: TAcikBaglanti; const Tablo, Ad: string): TKisitGirdisi;

{ Eksik girdide anlasilir cumle, tamamsa bos (yalniz olusturma / ekleme icin). }
function IndeksDogrula(const G: TIndeksGirdisi): string;
function KisitDogrula(const G: TKisitGirdisi): string;

{ Calisacak komut (pencerenin SQL onizlemesi ve onay metni). Girdi eksikse bos olabilir. }
function IndeksKomutu(Bag: TAcikBaglanti; Islem: TYapiIslemi; const G: TIndeksGirdisi): string;
function KisitKomutu(Bag: TAcikBaglanti; Islem: TYapiIslemi; const G: TKisitGirdisi): string;

{ Onay penceresinin metni: komut, (kisit silmede) baglanan yabanci anahtarlar, yedek bilgisi. }
function IndeksOnayMetni(const G: TIndeksGirdisi; const Komut: string): string;
function KisitOnayMetni(Bag: TAcikBaglanti; Islem: TYapiIslemi; const G: TKisitGirdisi; const Komut: string): string;

function IndeksUygula(Bag: TAcikBaglanti; Islem: TYapiIslemi; const G: TIndeksGirdisi): TProsedurSonucu;
function KisitUygula(Bag: TAcikBaglanti; Islem: TYapiIslemi; const G: TKisitGirdisi): TProsedurSonucu;

implementation

{ "A, b" -> ("A", "B" gibi adlar AdHazirla ile BUYUK harfe cevrilir, gerekirse tirnaga alinir) }
function KolonListesi(Bag: TAcikBaglanti; const Metin: string): string;
var
  Parcalar: TArray<string>;
  Parca: string;
begin
  Result := '';
  Parcalar := Metin.Split([',']);
  for Parca in Parcalar do
    if Trim(Parca) <> '' then
    begin
      if Result <> '' then
        Result := Result + ', ';
      Result := Result + AdiYaz(Bag, AdHazirla(Parca));
    end;
end;

{ Bos olmayan kolon adi sayisi ("A, , B" -> 2). }
function KolonSayisi(const Metin: string): Integer;
var
  Parca: string;
begin
  Result := 0;
  for Parca in Metin.Split([',']) do
    if Trim(Parca) <> '' then
      Inc(Result);
end;

function VirgulluMetin(const Parcalar: TArray<string>): string;
var
  i: Integer;
begin
  Result := '';
  for i := 0 to High(Parcalar) do
  begin
    if i > 0 then
      Result := Result + ', ';
    Result := Result + Parcalar[i];
  end;
end;

function IndeksGirdisiOku(Bag: TAcikBaglanti; const Tablo, Ad: string): TIndeksGirdisi;
var
  Bilgi: TIndeksBilgisi;
begin
  Result := Default(TIndeksGirdisi);
  Result.Tablo := Tablo;
  for Bilgi in IndeksleriOku(Bag, Tablo) do
    if Bilgi.Ad = Ad then
    begin
      Result.Ad := Ad;
      if Bilgi.Ifade <> '' then
        Result.Kolonlar := Bilgi.Ifade
      else
        Result.Kolonlar := VirgulluMetin(Bilgi.Kolonlar);
      Result.Benzersiz := Bilgi.Benzersiz;
      Result.Azalan := Bilgi.Azalan;
      Result.Pasif := Bilgi.Pasif;
      Exit;
    end;
  raise EMetadataHatasi.Create(TF('ERR_DDL_NESNE_YOK', [Ad]));
end;

function KisitGirdisiOku(Bag: TAcikBaglanti; const Tablo, Ad: string): TKisitGirdisi;
var
  Bilgi: TKisitBilgisi;
begin
  Result := Default(TKisitGirdisi);
  Result.Tablo := Tablo;
  for Bilgi in KisitlariOku(Bag, Tablo) do
    if Bilgi.GercekAd = Ad then
    begin
      Result.Ad := Ad;
      Result.Tur := Bilgi.Tur;
      Result.Kolonlar := VirgulluMetin(Bilgi.Kolonlar);
      Result.HedefTablo := Bilgi.HedefTablo;
      Result.HedefKolonlar := VirgulluMetin(Bilgi.HedefKolonlar);
      Result.SilKurali := Bilgi.SilKurali;
      Result.GuncelleKurali := Bilgi.GuncelleKurali;
      Result.Ifade := SozcuguAt(Bilgi.CheckMetni, 'CHECK');
      Exit;
    end;
  raise EMetadataHatasi.Create(TF('ERR_DDL_NESNE_YOK', [Ad]));
end;

function IndeksDogrula(const G: TIndeksGirdisi): string;
begin
  Result := '';
  if AdHazirla(G.Ad) = '' then
    Exit(T('ERR_INDEKS_AD_BOS'));
  if KolonSayisi(G.Kolonlar) = 0 then
    Exit(T('ERR_YAPI_KOLON_BOS'));
end;

function KisitDogrula(const G: TKisitGirdisi): string;
begin
  Result := '';
  if G.Tur = ktCheck then
  begin
    if SozcuguAt(G.Ifade, 'CHECK') = '' then
      Exit(T('ERR_KISIT_IFADE_BOS'));
    Exit;
  end;
  if KolonSayisi(G.Kolonlar) = 0 then
    Exit(T('ERR_YAPI_KOLON_BOS'));
  if (G.Tur = ktYabanci) and (Trim(G.HedefTablo) = '') then
    Exit(T('ERR_KISIT_HEDEF_BOS'));
end;

function IndeksKomutu(Bag: TAcikBaglanti; Islem: TYapiIslemi; const G: TIndeksGirdisi): string;
begin
  case Islem of
    yiOlustur:
      begin
        if (AdHazirla(G.Ad) = '') or (KolonListesi(Bag, G.Kolonlar) = '') then
          Exit('');
        Result := 'CREATE ';
        if G.Benzersiz then
          Result := Result + 'UNIQUE ';
        if G.Azalan then
          Result := Result + 'DESCENDING ';
        Result := Result + 'INDEX ' + AdiYaz(Bag, AdHazirla(G.Ad)) + ' ON ' + AdiYaz(Bag, G.Tablo) + ' (' +
          KolonListesi(Bag, G.Kolonlar) + ')';
      end;
    yiSil:
      Result := 'DROP INDEX ' + AdiYaz(Bag, G.Ad);
  else
    if G.Pasif then
      Result := 'ALTER INDEX ' + AdiYaz(Bag, G.Ad) + ' ACTIVE'
    else
      Result := 'ALTER INDEX ' + AdiYaz(Bag, G.Ad) + ' INACTIVE';
  end;
end;

function KisitKomutu(Bag: TAcikBaglanti; Islem: TYapiIslemi; const G: TKisitGirdisi): string;
var
  On, Ifade: string;
begin
  On := 'ALTER TABLE ' + AdiYaz(Bag, G.Tablo);
  if Islem = yiSil then
    Exit(On + ' DROP CONSTRAINT ' + AdiYaz(Bag, G.Ad));
  if KisitDogrula(G) <> '' then
    Exit('');
  Result := On + ' ADD ';
  if AdHazirla(G.Ad) <> '' then
    Result := Result + 'CONSTRAINT ' + AdiYaz(Bag, AdHazirla(G.Ad)) + ' ';
  case G.Tur of
    ktBirincil: Result := Result + 'PRIMARY KEY (' + KolonListesi(Bag, G.Kolonlar) + ')';
    ktBenzersiz: Result := Result + 'UNIQUE (' + KolonListesi(Bag, G.Kolonlar) + ')';
    ktYabanci:
      begin
        Result := Result + 'FOREIGN KEY (' + KolonListesi(Bag, G.Kolonlar) + ') REFERENCES ' +
          AdiYaz(Bag, AdHazirla(G.HedefTablo));
        if KolonListesi(Bag, G.HedefKolonlar) <> '' then
          Result := Result + ' (' + KolonListesi(Bag, G.HedefKolonlar) + ')';
        if G.SilKurali <> '' then
          Result := Result + ' ON DELETE ' + G.SilKurali;
        if G.GuncelleKurali <> '' then
          Result := Result + ' ON UPDATE ' + G.GuncelleKurali;
      end;
  else
    Ifade := SozcuguAt(G.Ifade, 'CHECK');
    if Ifade[1] <> '(' then
      Ifade := '(' + Ifade + ')';
    Result := Result + 'CHECK ' + Ifade;
  end;
end;

function IndeksOnayMetni(const G: TIndeksGirdisi; const Komut: string): string;
begin
  Result := TF('ONAY_KOLON', [G.Tablo, Komut]) + sLineBreak + sLineBreak + T('ONAY_KOLON_YEDEK') + sLineBreak +
    sLineBreak + T('ONAY_DOM_SORU');
end;

function KisitOnayMetni(Bag: TAcikBaglanti; Islem: TYapiIslemi; const G: TKisitGirdisi; const Komut: string): string;
var
  Baglilar: TArray<TBagimlilik>;
begin
  Result := TF('ONAY_KOLON', [G.Tablo, Komut]);
  { Firebird CHECK'i eklerken mevcut kayitlari denetlemez (olculdu); kullanici bilsin. }
  if (Islem = yiOlustur) and (G.Tur = ktCheck) then
    Result := Result + sLineBreak + sLineBreak + T('ONAY_KISIT_CHECK_NOT');
  { Silinen PRIMARY KEY / UNIQUE'e baska tablolarin yabanci anahtarlari bagliysa Firebird silmeyi reddeder. }
  if (Islem = yiSil) and (G.Tur in [ktBirincil, ktBenzersiz]) then
  begin
    Baglilar := KisitaBagliYabanciAnahtarlar(Bag, G.Ad);
    if Length(Baglilar) > 0 then
      Result := Result + sLineBreak + sLineBreak + T('ONAY_KISIT_FK_KULLANANLAR') + sLineBreak + BagimlilikMetni(Baglilar);
  end;
  Result := Result + sLineBreak + sLineBreak + T('ONAY_KOLON_YEDEK') + sLineBreak + sLineBreak + T('ONAY_DOM_SORU');
end;

{ Olusturma / eklemede Firebird'in genel "tekrar eden deger" ve "yabanci anahtar" cumleleri, MEVCUT veriyle ilgili olan
  durumda daha acik bir cumleyle degistirilir (yeni kayit yazilmiyor, tabloda zaten sorunlu veri var). }
procedure MevcutVeriCumlesi(Islem: TYapiIslemi; var Sonuc: TProsedurSonucu);
begin
  if Sonuc.Basarili or (Islem <> yiOlustur) then
    Exit;
  if Sonuc.Cumle = T('ERR_SQL_BENZERSIZ') then
    Sonuc.Cumle := T('ERR_YAPI_TEKRAR')
  else if Sonuc.Cumle = T('ERR_SQL_YABANCI_ANAHTAR') then
    Sonuc.Cumle := T('ERR_YAPI_YETIM');
end;

function IndeksUygula(Bag: TAcikBaglanti; Islem: TYapiIslemi; const G: TIndeksGirdisi): TProsedurSonucu;
begin
  Result := Default(TProsedurSonucu);
  if Islem = yiOlustur then
  begin
    Result.Cumle := IndeksDogrula(G);
    if Result.Cumle <> '' then
      Exit;
  end;
  if not TabloYapisiniYedekle(Bag, G.Tablo, Result) then
    Exit;
  Result.Ad := AdHazirla(G.Ad);
  MetniCalistir(Bag, IndeksKomutu(Bag, Islem, G), Result);
  MevcutVeriCumlesi(Islem, Result);
end;

function KisitUygula(Bag: TAcikBaglanti; Islem: TYapiIslemi; const G: TKisitGirdisi): TProsedurSonucu;
begin
  Result := Default(TProsedurSonucu);
  if Islem = yiOlustur then
  begin
    Result.Cumle := KisitDogrula(G);
    if Result.Cumle <> '' then
      Exit;
  end;
  if not TabloYapisiniYedekle(Bag, G.Tablo, Result) then
    Exit;
  Result.Ad := AdHazirla(G.Ad);
  MetniCalistir(Bag, KisitKomutu(Bag, Islem, G), Result);
  MevcutVeriCumlesi(Islem, Result);
end;

end.
