{ uDDL.pas - Nesnelerden CREATE script'i uretme (Asama 3a).

  Hedeflenen Firebird surumleri: 2.5, 3.0, 4.0, 5.0
  Denenen Firebird surumleri: 5.0.4 (2.5.9 sunucuda sahibi deneyecek; 3.0 ve 4.0 henuz denenmedi)

  Bu unit sadece METIN uretir. Sistem tablolarini (RDB$) bilmez; nesne bilgisini uMetadata'dan
  sade kayitlar olarak alir. Cikti isql -x'e benzer ama birebir ayni degildir (farklar
  ASAMA3A_RAPOR.md'de). Kural: ad yalniz gerektiginde "..." icine alinir. }
unit uDDL;

interface

uses
  System.SysUtils, System.Classes, uBaglanti;

type
  TNesneTuru = (ntTablo, ntView, ntProsedur, ntGenerator, ntTetikleyici, ntDomain, ntIstisna);

  { Metadata cikar: CREATE DATABASE / CONNECT ifadeleri ve sifre. Uc secenek de varsayilan KAPALI. }
  TCikarSecenekleri = record
    VeritabaniOlustur: Boolean;
    BaglantiYaz: Boolean;
    SifreYaz: Boolean;
  end;

  { Uzun surerken sik sik cagrilir: Aciklama "Tablolar: 12 / 117" gibi. Iptal True yapilirsa cikarma durur. }
  TCikarIlerlemesi = procedure(const Aciklama: string; var Iptal: Boolean) of object;

{ Script'in basina SET NAMES ile yazilan karakter seti: veritabaninin varsayilani (ornek WIN1254), o NONE ise
  baglantinin karakter seti; kod sayfasi bilinmiyorsa UTF8. Dosya da bu karakter setinin kodlamasiyla yazilir
  (IBExpert gibi), boylece script ayni karakter setli veritabanina uygulanirken metin ve exception mesajlari
  ayni baytlarla kalir. }
function ScriptKarakterSeti(Bag: TAcikBaglanti): string;

{ Script dosyasi/akisi icin kodlama (BOM'suz). Cagiran Free eder. }
function ScriptKodlamasiOlustur(Bag: TAcikBaglanti): TEncoding;

{ Nesnenin CREATE script'ini verir. Nesne yoksa veya govde metni kayitli degilse
  EMetadataHatasi (uMetadata) verir; mesaji kullaniciya gosterilir. }
function ScriptUret(Bag: TAcikBaglanti; Tur: TNesneTuru; const Ad: string): string;

{ Tabloyu BASKA bir ada (ve baska veritabanina) kopyalamak icin CREATE TABLE: kolonlar, PRIMARY KEY / UNIQUE / CHECK ve indexler.
  Yabanci anahtarlar, tetikleyiciler, yetkiler ve dis dosya baglantisi KOPYALANMAZ. Kisit ve index adlari cakismasin diye
  kisitlar adsiz, indexler yeni adla yazilir. Domain kullanan kolonlar domain adiyla kalir (hedefte domain olmali). }
function TabloYapiScripti(Bag: TAcikBaglanti; const Ad, YeniAd: string): string;

{ Prosedurun duzenlenebilir tanimi: ScriptUret ile ayni metin, yalniz baslik CREATE OR ALTER PROCEDURE
  (Firebird 2.5-5.0). Ayni metin hem duzenleme sekmesinde acilir hem de eski tanim yedegi olarak yazilir. }
function ProsedurDuzenleScripti(Bag: TAcikBaglanti; const Ad: string): string;

{ Tetikleyicinin duzenlenebilir tanimi: ScriptUret(ntTetikleyici) ile ayni metin, yalniz baslik CREATE OR ALTER TRIGGER
  (Firebird 2.5-5.0). Tablo, olay, POSITION ve ACTIVE/INACTIVE mevcut halinden gelir. DDL tetikleyicisinde
  (script uretilmeyen tur) EMetadataHatasi. }
function TetikleyiciDuzenleScripti(Bag: TAcikBaglanti; const Ad: string): string;

{ Ad yalniz gerektiginde "..." icine alinarak yazilir (komut metni kurmak icin: DROP, ALTER DOMAIN ...). }
function AdiYaz(Bag: TAcikBaglanti; const Ad: string): string;

{ Generator'in degerini ayarlayan komut: SET GENERATOR ad TO n, TUM surumlerde (2.5, 3.0, 4.0, 5.0) sonrasinda GEN_ID(ad, 0) = n olur.
  Gorev "3.0+ icin ALTER SEQUENCE ad RESTART WITH n" diyordu; olcum (ASAMA3F_RAPOR.md): RESTART WITH 2.5.9 ve 3.0.14'te
  GEN_ID(ad,0) = n yapar, ama 4.0.7 ve 5.0.4'te "SONRAKI deger n olsun" anlamina gelir (GEN_ID(ad,0) = n - artis).
  Ekranda "deger n" yazip gercekte n-1 gostermemek icin her surumde ayni anlamli SET GENERATOR kullanilir. Surum farki
  gerekirse yalniz bu yordam degisir. }
function GeneratorDegerKomutu(Bag: TAcikBaglanti; const Ad: string; Deger: Int64): string;

{ View'un duzenlenebilir tanimi: CREATE OR ALTER VIEW ad (kolonlar) AS select ...; (Firebird 2.5-5.0, olculdu).
  View'a bagli tetikleyiciler metne dahil degildir. }
function ViewDuzenleScripti(Bag: TAcikBaglanti; const Ad: string): string;

{ Exception'in duzenlenebilir tanimi: CREATE OR ALTER EXCEPTION ad 'mesaj'; }
function IstisnaDuzenleScripti(Bag: TAcikBaglanti; const Ad: string): string;

{ Tum veritabaninin yapisini (veri yok) Yazici'ya yazar; bos veritabaninda hatasiz calisacak sirada.
  Atlanan/sorunlu seyler Uyarilar'a (kullaniciya gosterilecek cumleler) yazilir. Iptal edilirse False
  doner; o ana kadar yazilan kisim Yazici'da kalir (yarimdir). }
function MetadataCikar(Bag: TAcikBaglanti; const Secenekler: TCikarSecenekleri; Yazici: TTextWriter;
  Uyarilar: TStrings; Ilerleme: TCikarIlerlemesi): Boolean;

implementation

uses
  System.StrUtils, System.Generics.Collections, uDil, uMetadata, uPaket;

var
  { Script uretirken kurulur: tirnak gerektiren (anahtar kelime) adlari bilmek icin. }
  GAnahtarKelimeler: TStringList;

const
  { Metadata okunurken kullanilan baglanti karakter seti (nesne adlari ve metinler bozulmasin). }
  OKUMA_KARAKTER_SETI = 'UTF8';

{ Firebird karakter seti adindan Windows kod sayfasi; UTF8 ve bilinmeyenler icin 0. }
function KodSayfasi(const Ad: string): Integer;
var
  No: Integer;
begin
  Result := 0;
  if (Length(Ad) = 7) and SameText(Copy(Ad, 1, 3), 'WIN') then
  begin
    No := StrToIntDef(Copy(Ad, 4, 4), 0);
    if (No >= 1250) and (No <= 1258) then
      Result := No;
  end
  else if SameText(Copy(Ad, 1, 7), 'ISO8859') then
  begin
    No := StrToIntDef(Copy(Ad, 9, 2), 0);
    if (No >= 1) and (No <= 9) then
      Result := 28590 + No
    else if No = 13 then
      Result := 28603;
  end
  else if SameText(Ad, 'DOS437') then
    Result := 437
  else if SameText(Ad, 'DOS850') then
    Result := 850
  else if SameText(Ad, 'DOS852') then
    Result := 852
  else if SameText(Ad, 'DOS857') then
    Result := 857
  else if SameText(Ad, 'DOS866') then
    Result := 866;
end;

function ScriptKarakterSeti(Bag: TAcikBaglanti): string;
begin
  Result := UpperCase(VeritabaniVarsayilanKarakterSeti(Bag));
  if Result = '' then
    Result := UpperCase(Bag.Tanim.KarakterSeti);
  if KodSayfasi(Result) = 0 then
    Result := 'UTF8';
end;

function ScriptKodlamasiOlustur(Bag: TAcikBaglanti): TEncoding;
var
  KodSayfasiNo: Integer;
begin
  KodSayfasiNo := KodSayfasi(ScriptKarakterSeti(Bag));
  if KodSayfasiNo = 0 then
    Result := TUTF8Encoding.Create(False)
  else
    Result := TEncoding.GetEncoding(KodSayfasiNo);
end;

procedure AnahtarKelimeleriKur(const Surum: string);
begin
  GAnahtarKelimeler := TStringList.Create;
  GAnahtarKelimeler.Sorted := True;
  GAnahtarKelimeler.Duplicates := dupIgnore;
  AnahtarKelimeleriOku(PaketKlasoru + '\anahtar_kelimeler.txt', Surum, GAnahtarKelimeler);
end;

procedure AnahtarKelimeleriBirak;
begin
  GAnahtarKelimeler.Free;
  GAnahtarKelimeler := nil;
end;

{ Ad sadece BUYUK harf, rakam, _ ve $ iceriyor, harfle basliyor ve anahtar kelime degilse oldugu gibi yazilir. }
function AdYaz(const Ad: string): string;
var
  i, Sira: Integer;
  Basit: Boolean;
begin
  Basit := (Ad <> '') and CharInSet(Ad[1], ['A'..'Z']);
  for i := 2 to Length(Ad) do
    if not CharInSet(Ad[i], ['A'..'Z', '0'..'9', '_', '$']) then
      Basit := False;
  if Basit and GAnahtarKelimeler.Find(Ad, Sira) then
    Basit := False;
  if Basit then
    Result := Ad
  else
    Result := '"' + StringReplace(Ad, '"', '""', [rfReplaceAll]) + '"';
end;

function AdListesi(const Adlar: TArray<string>): string;
var
  Ad: string;
begin
  Result := '';
  for Ad in Adlar do
  begin
    if Result <> '' then
      Result := Result + ', ';
    Result := Result + AdYaz(Ad);
  end;
end;

{ Komutu bitirir. Son satirda '--' yorumu varsa bitirici yorumun icinde kalmasin diye yeni satira konur. }
function Bitir(const Komut, Son: string): string;
var
  Metin, SonSatir: string;
begin
  Metin := TrimRight(Komut);
  SonSatir := Copy(Metin, LastDelimiter(#10, Metin) + 1, MaxInt);
  if Pos('--', SonSatir) > 0 then
    Result := Metin + sLineBreak + Son
  else
    Result := Metin + Son;
end;

{ SET TERM sarmalayicisi: icindeki komutlar '^' ile biter. }
function TerimBlogu(Komutlar: TStrings): string;
var
  i: Integer;
begin
  Result := 'SET TERM ^ ;' + sLineBreak;
  for i := 0 to Komutlar.Count - 1 do
    Result := Result + sLineBreak + Bitir(Komutlar[i], '^') + sLineBreak;
  Result := Result + sLineBreak + 'SET TERM ; ^';
end;

{ Govde veritabaninda 'AS' ile basliyorsa oldugu gibi, degilse basina 'AS' konur. }
function GovdeYaz(const Kaynak: string): string;
var
  Metin: string;
begin
  Metin := Trim(Kaynak);
  if StartsText('AS', Metin) and ((Length(Metin) = 2) or CharInSet(Metin[3], [' ', #9, #10, #13])) then
    Result := Metin
  else
    Result := 'AS' + sLineBreak + Metin;
end;

{ ---------- Tablo ---------- }

function KimlikMetni(const Kolon: TKolonBilgisi): string;
var
  Secenekler: string;
begin
  if Kolon.KimlikHep then
    Result := 'GENERATED ALWAYS AS IDENTITY'
  else
    Result := 'GENERATED BY DEFAULT AS IDENTITY';
  Secenekler := '';
  if Kolon.KimlikBaslangic <> 1 then
    Secenekler := 'START WITH ' + IntToStr(Kolon.KimlikBaslangic);
  if Kolon.KimlikArtis <> 1 then
    Secenekler := Trim(Secenekler + ' INCREMENT BY ' + IntToStr(Kolon.KimlikArtis));
  if Secenekler <> '' then
    Result := Result + ' (' + Secenekler + ')';
end;

function KolonSatiri(const Kolon: TKolonBilgisi): string;
begin
  Result := AdYaz(Kolon.Ad);
  if Kolon.Hesaplanan <> '' then
    Exit(Result + ' COMPUTED BY ' + Kolon.Hesaplanan);
  if Kolon.Domain <> '' then
    Result := Result + ' ' + AdYaz(Kolon.Domain)
  else
    Result := Result + ' ' + Kolon.Tip;
  if Kolon.Kimlik then
    Result := Result + ' ' + KimlikMetni(Kolon)
  else
  begin
    if Kolon.Varsayilan <> '' then
      Result := Result + ' ' + Kolon.Varsayilan;
    if Kolon.BosOlmaz then
      Result := Result + ' NOT NULL';
  end;
  if Kolon.Collate <> '' then
    Result := Result + ' COLLATE ' + AdYaz(Kolon.Collate);
end;

function KisitMetni(const Kisit: TKisitBilgisi): string;
var
  Indeks: string;
begin
  Result := '';
  if Kisit.Ad <> '' then
    Result := 'CONSTRAINT ' + AdYaz(Kisit.Ad) + ' ';
  Indeks := '';
  if Kisit.IndeksAdi <> '' then
    Indeks := ' USING INDEX ' + AdYaz(Kisit.IndeksAdi);
  case Kisit.Tur of
    ktBirincil:
      Result := Result + 'PRIMARY KEY (' + AdListesi(Kisit.Kolonlar) + ')' + Indeks;
    ktBenzersiz:
      Result := Result + 'UNIQUE (' + AdListesi(Kisit.Kolonlar) + ')' + Indeks;
    ktYabanci:
      begin
        Result := Result + 'FOREIGN KEY (' + AdListesi(Kisit.Kolonlar) + ') REFERENCES ' +
          AdYaz(Kisit.HedefTablo) + ' (' + AdListesi(Kisit.HedefKolonlar) + ')';
        if Kisit.SilKurali <> '' then
          Result := Result + ' ON DELETE ' + Kisit.SilKurali;
        if Kisit.GuncelleKurali <> '' then
          Result := Result + ' ON UPDATE ' + Kisit.GuncelleKurali;
        Result := Result + Indeks;
      end;
  else
    Result := Result + Kisit.CheckMetni;
  end;
end;

function IndeksMetni(const Tablo: string; const Indeks: TIndeksBilgisi): string;
begin
  Result := 'CREATE ';
  if Indeks.Benzersiz then
    Result := Result + 'UNIQUE ';
  if Indeks.Azalan then
    Result := Result + 'DESCENDING ';
  Result := Result + 'INDEX ' + AdYaz(Indeks.Ad) + ' ON ' + AdYaz(Tablo);
  if Indeks.Ifade <> '' then
    Result := Result + ' COMPUTED BY ' + Indeks.Ifade
  else
    Result := Result + ' (' + AdListesi(Indeks.Kolonlar) + ')';
  if Indeks.Kosul <> '' then
    Result := Result + ' ' + Indeks.Kosul;
  Result := Result + ';';
  if Indeks.Pasif then
    Result := Result + sLineBreak + 'ALTER INDEX ' + AdYaz(Indeks.Ad) + ' INACTIVE;';
end;

{ Tablo tetikleyicisi: CREATE TRIGGER ad FOR tablo ...; veritabani tetikleyicisi (Tablo bos): ... ON CONNECT. }
function TetikleyiciMetniFiil(const Tetik: TTetikleyiciBilgisi; const Fiil: string): string;
begin
  Result := Fiil + ' TRIGGER ' + AdYaz(Tetik.Ad);
  if Tetik.Tablo <> '' then
    Result := Result + ' FOR ' + AdYaz(Tetik.Tablo);
  Result := Result + ' ' + IfThen(Tetik.Aktif, 'ACTIVE', 'INACTIVE') + sLineBreak +
    Trim(Tetik.Zaman + ' ' + Tetik.Olaylar) + ' POSITION ' + IntToStr(Tetik.Sira) + sLineBreak +
    GovdeYaz(Tetik.Kaynak);
end;

function TetikleyiciMetni(const Tetik: TTetikleyiciBilgisi): string;
begin
  Result := TetikleyiciMetniFiil(Tetik, 'CREATE');
end;

{ Tetikleyiciler tek SET TERM blogunda, bos ise hicbir sey eklenmez. }
function TetikleyiciBlogu(const Tetikleyiciler: TArray<TTetikleyiciBilgisi>): string;
var
  Komutlar: TStringList;
  Tetik: TTetikleyiciBilgisi;
begin
  Result := '';
  if Length(Tetikleyiciler) = 0 then
    Exit;
  Komutlar := TStringList.Create;
  try
    for Tetik in Tetikleyiciler do
      Komutlar.Add(TetikleyiciMetni(Tetik));
    Result := TerimBlogu(Komutlar);
  finally
    Komutlar.Free;
  end;
end;

{ CREATE TABLE. SadeceKolon True ise yalniz kolonlar (kisitlar sonra ALTER TABLE ile gelir, Metadata cikar);
  False ise PK/UNIQUE/CHECK tablonun icinde. Yabanci anahtarlar her durumda disarida kalir. }
function TabloOlusturMetni(const Ad: string; const Bilgi: TTabloBilgisi; SadeceKolon: Boolean): string;
var
  Ogeler: TStringList;
  Kisit: TKisitBilgisi;
  Kolon: TKolonBilgisi;
  i: Integer;
begin
  Ogeler := TStringList.Create;
  try
    for Kolon in Bilgi.Kolonlar do
      Ogeler.Add(KolonSatiri(Kolon));
    if not SadeceKolon then
      for Kisit in Bilgi.Kisitlar do
        if Kisit.Tur <> ktYabanci then
          Ogeler.Add(KisitMetni(Kisit));
    if Bilgi.GeciciTur <> 0 then
      Result := 'CREATE GLOBAL TEMPORARY TABLE ' + AdYaz(Ad)
    else
      Result := 'CREATE TABLE ' + AdYaz(Ad);
    if Bilgi.DisDosya <> '' then
      Result := Result + ' EXTERNAL FILE ''' + StringReplace(Bilgi.DisDosya, '''', '''''', [rfReplaceAll]) + '''';
    Result := Result + ' (' + sLineBreak;
    for i := 0 to Ogeler.Count - 1 do
      Result := Result + '    ' + Ogeler[i] + IfThen(i < Ogeler.Count - 1, ',', '') + sLineBreak;
    Result := Result + ')';
    case Bilgi.GeciciTur of
      1: Result := Result + ' ON COMMIT PRESERVE ROWS';
      2: Result := Result + ' ON COMMIT DELETE ROWS';
    end;
    Result := Result + ';' + sLineBreak;
  finally
    Ogeler.Free;
  end;
end;

{ Sira: CREATE TABLE (kolonlar, PK/UNIQUE/CHECK), yabanci anahtarlar (ALTER TABLE), indeksler, tetikleyiciler. }
function TabloScripti(Bag: TAcikBaglanti; const Ad: string): string;
var
  Bilgi: TTabloBilgisi;
  Kisit: TKisitBilgisi;
  Indeks: TIndeksBilgisi;
  Blok: string;
begin
  Bilgi := TabloBilgisiOku(Bag, Ad);
  Result := TabloOlusturMetni(Ad, Bilgi, False);
  for Kisit in Bilgi.Kisitlar do
    if Kisit.Tur = ktYabanci then
      Result := Result + sLineBreak + 'ALTER TABLE ' + AdYaz(Ad) + ' ADD ' + KisitMetni(Kisit) + ';' + sLineBreak;
  for Indeks in Bilgi.Indeksler do
    Result := Result + sLineBreak + IndeksMetni(Ad, Indeks) + sLineBreak;
  Blok := TetikleyiciBlogu(Bilgi.Tetikleyiciler);
  if Blok <> '' then
    Result := Result + sLineBreak + Blok + sLineBreak;
end;

function TabloYapiScripti(Bag: TAcikBaglanti; const Ad, YeniAd: string): string;
var
  Bilgi: TTabloBilgisi;
  i: Integer;
begin
  Bilgi := TabloBilgisiOku(Bag, Ad);
  Bilgi.GeciciTur := 0;
  Bilgi.DisDosya := '';
  for i := 0 to High(Bilgi.Kisitlar) do
  begin
    Bilgi.Kisitlar[i].Ad := '';
    Bilgi.Kisitlar[i].IndeksAdi := '';
  end;
  { Adlarin tirnak gerekip gerekmedigini anlamak icin anahtar kelimeler kurulur (ScriptUret ile ayni). }
  AnahtarKelimeleriKur(Bag.Surum);
  try
    Result := TabloOlusturMetni(YeniAd, Bilgi, False);
    for i := 0 to High(Bilgi.Indeksler) do
    begin
      Bilgi.Indeksler[i].Ad := Copy('IX_' + YeniAd + '_' + IntToStr(i + 1), 1, 31);
      Result := Result + sLineBreak + IndeksMetni(YeniAd, Bilgi.Indeksler[i]) + sLineBreak;
    end;
  finally
    AnahtarKelimeleriBirak;
  end;
end;

{ ---------- View ---------- }

{ View'a bagli (guncellenebilir view icin yazilmis) tetikleyiciler de sona eklenir. }
function ViewOlusturMetni(const Ad: string; const Bilgi: TViewBilgisi): string;
begin
  Result := 'CREATE VIEW ' + AdYaz(Ad) + ' (' + AdListesi(Bilgi.Kolonlar) + ') AS' + sLineBreak +
    Bitir(Trim(Bilgi.Kaynak), ';') + sLineBreak;
end;

function ViewScripti(Bag: TAcikBaglanti; const Ad: string): string;
var
  Bilgi: TViewBilgisi;
  Blok: string;
begin
  Bilgi := ViewBilgisiOku(Bag, Ad);
  Result := ViewOlusturMetni(Ad, Bilgi);
  Blok := TetikleyiciBlogu(Bilgi.Tetikleyiciler);
  if Blok <> '' then
    Result := Result + sLineBreak + Blok + sLineBreak;
end;

{ ---------- Prosedur ---------- }

function ParametreSatiri(const Param: TParametreBilgisi): string;
begin
  Result := AdYaz(Param.Ad) + ' ';
  if Param.Domain <> '' then
    Result := Result + AdYaz(Param.Domain)
  else
    Result := Result + Param.Tip;
  if Param.BosOlmaz then
    Result := Result + ' NOT NULL';
  if Param.Varsayilan <> '' then
    Result := Result + ' ' + Param.Varsayilan;
end;

function ParametreListesi(const Parametreler: TArray<TParametreBilgisi>): string;
var
  i: Integer;
begin
  Result := '';
  for i := 0 to High(Parametreler) do
    Result := Result + '    ' + ParametreSatiri(Parametreler[i]) + IfThen(i < High(Parametreler), ',' + sLineBreak, '');
end;

{ 'CREATE PROCEDURE ad (girdiler) RETURNS (ciktilar)' (Fiil: CREATE veya ALTER); 'AS' ve govde ayri eklenir. }
function ProsedurBasligi(const Fiil, Ad: string; const Bilgi: TProsedurBilgisi): string;
begin
  Result := Fiil + ' PROCEDURE ' + AdYaz(Ad);
  if Length(Bilgi.Girdiler) > 0 then
    Result := Result + ' (' + sLineBreak + ParametreListesi(Bilgi.Girdiler) + ')';
  if Length(Bilgi.Ciktilar) > 0 then
    Result := Result + sLineBreak + 'RETURNS (' + sLineBreak + ParametreListesi(Bilgi.Ciktilar) + ')';
end;

function ProsedurScripti(Bag: TAcikBaglanti; const Ad, Fiil: string): string;
var
  Bilgi: TProsedurBilgisi;
  Komutlar: TStringList;
begin
  Bilgi := ProsedurBilgisiOku(Bag, Ad);
  Komutlar := TStringList.Create;
  try
    Komutlar.Add(ProsedurBasligi(Fiil, Ad, Bilgi) + sLineBreak + 'AS' + sLineBreak + Trim(Bilgi.Kaynak));
    Result := TerimBlogu(Komutlar) + sLineBreak;
  finally
    Komutlar.Free;
  end;
end;

{ ---------- Tetikleyici (tek) ---------- }

{ Fiil: CREATE veya CREATE OR ALTER. Tablo tetikleyicisi, veritabani tetikleyicisi (ON CONNECT vb.) ve tablo
  tetikleyicisi icin TetikleyiciMetniFiil ne uretiyorsa o; DDL tetikleyicisi desteklenmez. }
function TetikleyiciScripti(Bag: TAcikBaglanti; const Ad, Fiil: string): string;
var
  Bilgi: TTetikleyiciBilgisi;
  Komutlar: TStringList;
begin
  Bilgi := TetikleyiciBilgisiOku(Bag, Ad);
  if Bilgi.Desteklenmiyor then
    raise EMetadataHatasi.Create(TF('MD_UYARI_TETIK_DESTEK', [Ad]));
  Komutlar := TStringList.Create;
  try
    Komutlar.Add(TetikleyiciMetniFiil(Bilgi, Fiil));
    Result := TerimBlogu(Komutlar) + sLineBreak;
  finally
    Komutlar.Free;
  end;
end;

{ ---------- Generator ---------- }

{ Firebird 2.5'te de calisan CREATE SEQUENCE + SET GENERATOR kullanilir (surume gore degismez). }
function GeneratorScripti(Bag: TAcikBaglanti; const Ad: string): string;
var
  Bilgi: TGeneratorBilgisi;
begin
  Bilgi := GeneratorBilgisiOku(Bag, Ad);
  Result := 'CREATE SEQUENCE ' + AdYaz(Ad);
  if Bilgi.Artis <> 1 then
    Result := Result + ' INCREMENT BY ' + IntToStr(Bilgi.Artis);
  Result := Result + ';' + sLineBreak;
  if Bilgi.Deger <> 0 then
    Result := Result + 'SET GENERATOR ' + AdYaz(Ad) + ' TO ' + IntToStr(Bilgi.Deger) + ';' + sLineBreak;
end;

{ ---------- Domain ve exception ---------- }

function YaziSabiti(const Metin: string): string;
begin
  Result := '''' + StringReplace(Metin, '''', '''''', [rfReplaceAll]) + '''';
end;

{ CREATE DOMAIN ad AS tip [DEFAULT ..] [NOT NULL] [CHECK ..] [COLLATE ..]; (sonunda ';' ile) }
function DomainMetni(const Alan: TDomainBilgisi): string;
begin
  Result := 'CREATE DOMAIN ' + AdYaz(Alan.Ad) + ' AS ' + Alan.Tip;
  if Alan.Varsayilan <> '' then
    Result := Result + ' ' + Alan.Varsayilan;
  if Alan.BosOlmaz then
    Result := Result + ' NOT NULL';
  if Alan.Kontrol <> '' then
    Result := Result + ' ' + Alan.Kontrol;
  if Alan.Collate <> '' then
    Result := Result + ' COLLATE ' + AdYaz(Alan.Collate);
  Result := Result + ';';
end;

function DomainScripti(Bag: TAcikBaglanti; const Ad: string): string;
begin
  Result := DomainMetni(DomainBilgisiOku(Bag, Ad)) + sLineBreak;
end;

{ Fiil: CREATE veya CREATE OR ALTER (2.5-5.0'da ikisi de var, olculdu). }
function IstisnaScripti(Bag: TAcikBaglanti; const Ad, Fiil: string): string;
begin
  Result := Fiil + ' EXCEPTION ' + AdYaz(Ad) + ' ' + YaziSabiti(IstisnaBilgisiOku(Bag, Ad).Mesaj) + ';' + sLineBreak;
end;

{ ---------- View duzenleme ---------- }

{ CREATE OR ALTER VIEW 2.5, 3.0, 4.0 ve 5.0'da vardir (olculdu, ASAMA3F_RAPOR.md). Bagimli nesne varsa ve
  kullandigi kolon degismiyorsa calisir; RECREATE VIEW ise bagimli varken her zaman basarisiz olur, bu yuzden
  kullanilmaz. View'a bagli tetikleyiciler bu metne dahil degildir (CREATE OR ALTER onlara dokunmaz). }
function ViewDuzenleMetniUret(Bag: TAcikBaglanti; const Ad: string): string;
var
  Bilgi: TViewBilgisi;
begin
  Bilgi := ViewBilgisiOku(Bag, Ad);
  Result := 'CREATE OR ALTER VIEW ' + AdYaz(Ad) + ' (' + AdListesi(Bilgi.Kolonlar) + ') AS' + sLineBreak +
    Bitir(Trim(Bilgi.Kaynak), ';') + sLineBreak;
end;

{ ---------- Disariya acik ---------- }

function ScriptUret(Bag: TAcikBaglanti; Tur: TNesneTuru; const Ad: string): string;
begin
  AnahtarKelimeleriKur(Bag.Surum);
  try
    case Tur of
      ntTablo: Result := TabloScripti(Bag, Ad);
      ntView: Result := ViewScripti(Bag, Ad);
      ntProsedur: Result := ProsedurScripti(Bag, Ad, 'CREATE');
      ntTetikleyici: Result := TetikleyiciScripti(Bag, Ad, 'CREATE');
      ntDomain: Result := DomainScripti(Bag, Ad);
      ntIstisna: Result := IstisnaScripti(Bag, Ad, 'CREATE');
    else
      Result := GeneratorScripti(Bag, Ad);
    end;
  finally
    AnahtarKelimeleriBirak;
  end;
end;

function AdiYaz(Bag: TAcikBaglanti; const Ad: string): string;
begin
  AnahtarKelimeleriKur(Bag.Surum);
  try
    Result := AdYaz(Ad);
  finally
    AnahtarKelimeleriBirak;
  end;
end;

function GeneratorDegerKomutu(Bag: TAcikBaglanti; const Ad: string; Deger: Int64): string;
begin
  Result := 'SET GENERATOR ' + AdiYaz(Bag, Ad) + ' TO ' + IntToStr(Deger);
end;

function ViewDuzenleScripti(Bag: TAcikBaglanti; const Ad: string): string;
begin
  AnahtarKelimeleriKur(Bag.Surum);
  try
    Result := ViewDuzenleMetniUret(Bag, Ad);
  finally
    AnahtarKelimeleriBirak;
  end;
end;

function IstisnaDuzenleScripti(Bag: TAcikBaglanti; const Ad: string): string;
begin
  AnahtarKelimeleriKur(Bag.Surum);
  try
    Result := IstisnaScripti(Bag, Ad, 'CREATE OR ALTER');
  finally
    AnahtarKelimeleriBirak;
  end;
end;

function ProsedurDuzenleScripti(Bag: TAcikBaglanti; const Ad: string): string;
begin
  AnahtarKelimeleriKur(Bag.Surum);
  try
    Result := ProsedurScripti(Bag, Ad, 'CREATE OR ALTER');
  finally
    AnahtarKelimeleriBirak;
  end;
end;

function TetikleyiciDuzenleScripti(Bag: TAcikBaglanti; const Ad: string): string;
begin
  AnahtarKelimeleriKur(Bag.Surum);
  try
    Result := TetikleyiciScripti(Bag, Ad, 'CREATE OR ALTER');
  finally
    AnahtarKelimeleriBirak;
  end;
end;

{ ---------- Tum veritabani (Metadata cikar) ---------- }

type
  TTabloKisiti = record
    Tablo: string;
    Kisit: TKisitBilgisi;
  end;

  { Cikis sirasi (bos veritabaninda hatasiz calissin diye): roller, exception, generator, domain, tablolar
    (yalniz kolonlar), prosedur iskeletleri (bos govde), view'lar (bagimlilik sirasiyla), PK/UNIQUE, FK, CHECK,
    indeksler, tetikleyiciler, prosedur govdeleri (ALTER), yetkiler, aciklamalar. }
  TCikarici = class
  private
    FBag: TAcikBaglanti;
    FYazici: TTextWriter;
    FUyarilar: TStrings;
    FIlerleme: TCikarIlerlemesi;
    FIptal: Boolean;
    FTerimAcik: Boolean;
    FTablolar: TArray<string>;
    FProsedurAdlari: TArray<string>;
    FProsedurler: TDictionary<string, TProsedurBilgisi>;
    FKisitlar: TList<TTabloKisiti>;
    procedure Haber(const Asama: string; Sira, Toplam: Integer);
    procedure Uyar(const Metin: string);
    procedure Satir(const Metin: string);
    procedure TerimKomutu(const Komut: string);
    procedure TerimKapat;
    procedure Roller;
    procedure Istisnalar;
    procedure Generatorler;
    procedure Domainler;
    procedure Tablolar;
    procedure ProsedurIskeletleri;
    procedure Viewlar;
    procedure KisitlariYaz(Tur: TKisitTuru);
    procedure Kisitlar;
    procedure Indeksler;
    procedure Tetikleyiciler;
    procedure ProsedurGovdeleri;
    procedure YetkiGrubuYaz(const Liste: TArray<TYetkiBilgisi>; Bas, Son: Integer);
    procedure Yetkiler;
    procedure Aciklamalar;
  public
    constructor Create(Okuyucu: TAcikBaglanti; Yazici: TTextWriter; Uyarilar: TStrings;
      Ilerleme: TCikarIlerlemesi);
    destructor Destroy; override;
    function Calistir: Boolean;
  end;

constructor TCikarici.Create(Okuyucu: TAcikBaglanti; Yazici: TTextWriter; Uyarilar: TStrings;
  Ilerleme: TCikarIlerlemesi);
begin
  inherited Create;
  FBag := Okuyucu;
  FYazici := Yazici;
  FUyarilar := Uyarilar;
  FIlerleme := Ilerleme;
  FProsedurler := TDictionary<string, TProsedurBilgisi>.Create;
  FKisitlar := TList<TTabloKisiti>.Create;
end;

destructor TCikarici.Destroy;
begin
  FKisitlar.Free;
  FProsedurler.Free;
  inherited;
end;

procedure TCikarici.Haber(const Asama: string; Sira, Toplam: Integer);
begin
  if Assigned(FIlerleme) then
    FIlerleme(TF('MD_ILERLEME', [Asama, Sira, Toplam]), FIptal);
end;

procedure TCikarici.Uyar(const Metin: string);
begin
  FUyarilar.Add(Metin);
end;

procedure TCikarici.Satir(const Metin: string);
begin
  FYazici.WriteLine(Metin);
end;

{ Komutu SET TERM ^ blogunun icine yazar; blok ilk komutla acilir, TerimKapat ile kapanir. }
procedure TCikarici.TerimKomutu(const Komut: string);
begin
  if not FTerimAcik then
  begin
    Satir('SET TERM ^ ;');
    Satir('');
    FTerimAcik := True;
  end;
  Satir(Bitir(Komut, '^'));
  Satir('');
end;

procedure TCikarici.TerimKapat;
begin
  if FTerimAcik then
  begin
    Satir('SET TERM ; ^');
    Satir('');
    FTerimAcik := False;
  end;
end;

procedure TCikarici.Roller;
var
  Adlar: TArray<string>;
  i: Integer;
begin
  Adlar := RolAdlari(FBag);
  if Length(Adlar) > 0 then
    Satir('/* Roles */');
  for i := 0 to High(Adlar) do
  begin
    Haber(T('MD_ASAMA_ROLLER'), i + 1, Length(Adlar));
    if FIptal then
      Exit;
    Satir('CREATE ROLE ' + AdYaz(Adlar[i]) + ';');
  end;
  if Length(Adlar) > 0 then
    Satir('');
end;

procedure TCikarici.Istisnalar;
var
  Liste: TArray<TIstisnaBilgisi>;
  i: Integer;
begin
  Liste := IstisnalariOku(FBag);
  if Length(Liste) > 0 then
    Satir('/* Exceptions */');
  for i := 0 to High(Liste) do
  begin
    Haber(T('MD_ASAMA_ISTISNALAR'), i + 1, Length(Liste));
    if FIptal then
      Exit;
    Satir('CREATE EXCEPTION ' + AdYaz(Liste[i].Ad) + ' ' + YaziSabiti(Liste[i].Mesaj) + ';');
  end;
  if Length(Liste) > 0 then
    Satir('');
end;

procedure TCikarici.Generatorler;
var
  Adlar: TArray<string>;
  i: Integer;
begin
  Adlar := GeneratorAdlari(FBag);
  if Length(Adlar) > 0 then
    Satir('/* Generators */');
  for i := 0 to High(Adlar) do
  begin
    Haber(T('MD_ASAMA_GENERATORLER'), i + 1, Length(Adlar));
    if FIptal then
      Exit;
    Satir(TrimRight(GeneratorScripti(FBag, Adlar[i])));
  end;
  if Length(Adlar) > 0 then
    Satir('');
end;

procedure TCikarici.Domainler;
var
  Liste: TArray<TDomainBilgisi>;
  Komut: string;
  i: Integer;
begin
  Liste := DomainleriOku(FBag);
  if Length(Liste) > 0 then
    Satir('/* Domains */');
  for i := 0 to High(Liste) do
  begin
    Haber(T('MD_ASAMA_DOMAINLER'), i + 1, Length(Liste));
    if FIptal then
      Exit;
    Komut := DomainMetni(Liste[i]);
    Satir(Komut);
  end;
  if Length(Liste) > 0 then
    Satir('');
end;

{ Tablolar sadece kolonlariyla; kisitlar ve indeksler sonra gelir. }
procedure TCikarici.Tablolar;
var
  Bilgi: TTabloBilgisi;
  i: Integer;
begin
  FTablolar := TabloAdlari(FBag);
  if Length(FTablolar) > 0 then
    Satir('/* Tables */');
  for i := 0 to High(FTablolar) do
  begin
    Haber(T('MD_ASAMA_TABLOLAR'), i + 1, Length(FTablolar));
    if FIptal then
      Exit;
    Bilgi := Default(TTabloBilgisi);
    Bilgi.Kolonlar := KolonlariOku(FBag, FTablolar[i]);
    TabloOzellikleriniOku(FBag, FTablolar[i], Bilgi);
    Satir(TabloOlusturMetni(FTablolar[i], Bilgi, True));
  end;
end;

{ Prosedurler birbirini ve view'lari cagirabilir; bu yuzden once parametreli ama bos govdeli kurulur. }
procedure TCikarici.ProsedurIskeletleri;
var
  Bilgi: TProsedurBilgisi;
  i: Integer;
begin
  FProsedurAdlari := ProsedurAdlari(FBag);
  if Length(FProsedurAdlari) > 0 then
    Satir('/* Stored procedures (headers) */');
  for i := 0 to High(FProsedurAdlari) do
  begin
    Haber(T('MD_ASAMA_PROSEDURLER'), i + 1, Length(FProsedurAdlari));
    if FIptal then
      Exit;
    try
      Bilgi := ProsedurBilgisiOku(FBag, FProsedurAdlari[i]);
      FProsedurler.Add(FProsedurAdlari[i], Bilgi);
      { Select edilebilir (cikis parametreli) prosedurlerin govdesinde SUSPEND olmali; yoksa view ve
        diger prosedurler bu prosedure bagli kurulamaz (isql -x de boyle yapar). }
      TerimKomutu(ProsedurBasligi('CREATE', FProsedurAdlari[i], Bilgi) + sLineBreak + 'AS' + sLineBreak +
        'BEGIN' + sLineBreak + IfThen(Length(Bilgi.Ciktilar) > 0, '  SUSPEND;', '  EXIT;') + sLineBreak + 'END');
    except
      on E: EMetadataHatasi do
        Uyar(E.Message);
    end;
  end;
  TerimKapat;
end;

procedure TCikarici.Viewlar;
var
  Adlar, Dongu: TArray<string>;
  Bilgi: TViewBilgisi;
  Ad: string;
  i: Integer;
begin
  Adlar := ViewAdlariSirali(FBag, Dongu);
  if Length(Dongu) > 0 then
  begin
    Ad := '';
    for i := 0 to High(Dongu) do
      Ad := Ad + IfThen(i > 0, ', ', '') + Dongu[i];
    Uyar(TF('MD_UYARI_VIEW_DONGU', [Ad]));
  end;
  if Length(Adlar) > 0 then
    Satir('/* Views */');
  for i := 0 to High(Adlar) do
  begin
    Haber(T('MD_ASAMA_VIEWLAR'), i + 1, Length(Adlar));
    if FIptal then
      Exit;
    try
      Bilgi := ViewBilgisiOku(FBag, Adlar[i]);
      Satir(ViewOlusturMetni(Adlar[i], Bilgi));
    except
      on E: EMetadataHatasi do
        Uyar(E.Message);
    end;
  end;
end;

{ PRIMARY KEY ve UNIQUE ayni turde (ktBirincil) yazilir; once hepsi okunur (Kisitlar), sonra tur tur yazilir. }
procedure TCikarici.KisitlariYaz(Tur: TKisitTuru);
var
  Kayit: TTabloKisiti;
  Uygun: Boolean;
begin
  for Kayit in FKisitlar do
  begin
    if Tur = ktBirincil then
      Uygun := Kayit.Kisit.Tur in [ktBirincil, ktBenzersiz]
    else
      Uygun := Kayit.Kisit.Tur = Tur;
    if Uygun then
      Satir('ALTER TABLE ' + AdYaz(Kayit.Tablo) + ' ADD ' + KisitMetni(Kayit.Kisit) + ';');
  end;
end;

{ Sira: PRIMARY KEY ve UNIQUE, sonra FOREIGN KEY, sonra CHECK. }
procedure TCikarici.Kisitlar;
var
  Kisit: TKisitBilgisi;
  Kayit: TTabloKisiti;
  i: Integer;
begin
  for i := 0 to High(FTablolar) do
  begin
    Haber(T('MD_ASAMA_KISITLAR'), i + 1, Length(FTablolar));
    if FIptal then
      Exit;
    for Kisit in KisitlariOku(FBag, FTablolar[i]) do
    begin
      Kayit.Tablo := FTablolar[i];
      Kayit.Kisit := Kisit;
      FKisitlar.Add(Kayit);
    end;
  end;
  if FKisitlar.Count > 0 then
    Satir('/* Constraints */');
  KisitlariYaz(ktBirincil);
  KisitlariYaz(ktYabanci);
  KisitlariYaz(ktCheck);
  if FKisitlar.Count > 0 then
    Satir('');
end;

procedure TCikarici.Indeksler;
var
  Indeks: TIndeksBilgisi;
  Yazildi: Boolean;
  i: Integer;
begin
  Yazildi := False;
  for i := 0 to High(FTablolar) do
  begin
    Haber(T('MD_ASAMA_INDEKSLER'), i + 1, Length(FTablolar));
    if FIptal then
      Exit;
    for Indeks in IndeksleriOku(FBag, FTablolar[i]) do
    begin
      if not Yazildi then
        Satir('/* Indices */');
      Yazildi := True;
      Satir(IndeksMetni(FTablolar[i], Indeks));
    end;
  end;
  if Yazildi then
    Satir('');
end;

procedure TCikarici.Tetikleyiciler;
var
  Liste: TArray<TTetikleyiciBilgisi>;
  i: Integer;
begin
  Liste := TetikleyicileriOku(FBag, '');
  if Length(Liste) > 0 then
    Satir('/* Triggers */');
  for i := 0 to High(Liste) do
  begin
    Haber(T('MD_ASAMA_TETIKLEYICILER'), i + 1, Length(Liste));
    if FIptal then
      Exit;
    if Liste[i].Desteklenmiyor then
      Uyar(TF('MD_UYARI_TETIK_DESTEK', [Liste[i].Ad]))
    else if Trim(Liste[i].Kaynak) = '' then
      Uyar(TF('ERR_DDL_KAYNAK_YOK', [Liste[i].Ad]))
    else
      TerimKomutu(TetikleyiciMetni(Liste[i]));
  end;
  TerimKapat;
end;

procedure TCikarici.ProsedurGovdeleri;
var
  Bilgi: TProsedurBilgisi;
  i: Integer;
begin
  if FProsedurler.Count > 0 then
    Satir('/* Stored procedures (bodies) */');
  for i := 0 to High(FProsedurAdlari) do
  begin
    Haber(T('MD_ASAMA_GOVDELER'), i + 1, Length(FProsedurAdlari));
    if FIptal then
      Exit;
    if FProsedurler.TryGetValue(FProsedurAdlari[i], Bilgi) then
      TerimKomutu(ProsedurBasligi('ALTER', FProsedurAdlari[i], Bilgi) + sLineBreak + 'AS' + sLineBreak +
        Trim(Bilgi.Kaynak));
  end;
  TerimKapat;
end;

{ Ayni nesne ve ayni kisiye verilen yetkiler (Bas..Son) tek GRANT'te birlesir. }
procedure TCikarici.YetkiGrubuYaz(const Liste: TArray<TYetkiBilgisi>; Bas, Son: Integer);
var
  Genel, GuncelleKolonlari, ReferansKolonlari: TStringList;
  Y: TYetkiBilgisi;
  Kime, Secenek, Nesne: string;
  k: Integer;
begin
  Y := Liste[Bas];
  case Y.KullaniciTuru of
    8: Kime := IfThen(SameText(Y.Kullanici, 'PUBLIC'), 'PUBLIC', 'USER ' + AdYaz(Y.Kullanici));
    13: Kime := 'ROLE ' + AdYaz(Y.Kullanici);
    5: Kime := 'PROCEDURE ' + AdYaz(Y.Kullanici);
    2: Kime := 'TRIGGER ' + AdYaz(Y.Kullanici);
    1: Kime := 'VIEW ' + AdYaz(Y.Kullanici);
  else
    Uyar(TF('MD_UYARI_YETKI_ATLANDI', [Y.Nesne]));
    Exit;
  end;
  Nesne := AdYaz(Y.Nesne);
  Secenek := '';
  if Y.SecenekVar = 1 then
    Secenek := ' WITH GRANT OPTION';
  Genel := TStringList.Create;
  GuncelleKolonlari := TStringList.Create;
  ReferansKolonlari := TStringList.Create;
  try
    Genel.Delimiter := ',';
    Genel.StrictDelimiter := True;
    GuncelleKolonlari.Delimiter := ',';
    GuncelleKolonlari.StrictDelimiter := True;
    ReferansKolonlari.Delimiter := ',';
    ReferansKolonlari.StrictDelimiter := True;
    for k := Bas to Son do
      case Liste[k].Yetki[1] of
        'S': Genel.Add('SELECT');
        'I': Genel.Add('INSERT');
        'D': Genel.Add('DELETE');
        'U':
          if Liste[k].Alan = '' then
            Genel.Add('UPDATE')
          else
            GuncelleKolonlari.Add(AdYaz(Liste[k].Alan));
        'R':
          if Liste[k].Alan = '' then
            Genel.Add('REFERENCES')
          else
            ReferansKolonlari.Add(AdYaz(Liste[k].Alan));
        'X':
          Satir('GRANT EXECUTE ON PROCEDURE ' + Nesne + ' TO ' + Kime + Secenek + ';');
        'M':
          Satir('GRANT ' + Nesne + ' TO ' + Kime + IfThen(Y.SecenekVar = 2, ' WITH ADMIN OPTION', '') + ';');
        'G':
          if Y.NesneTuru = 7 then
            Satir('GRANT USAGE ON EXCEPTION ' + Nesne + ' TO ' + Kime + Secenek + ';')
          else
            Satir('GRANT USAGE ON SEQUENCE ' + Nesne + ' TO ' + Kime + Secenek + ';');
      end;
    if Genel.Count > 0 then
      Satir('GRANT ' + StringReplace(Genel.DelimitedText, ',', ', ', [rfReplaceAll]) + ' ON ' + Nesne + ' TO ' +
        Kime + Secenek + ';');
    if GuncelleKolonlari.Count > 0 then
      Satir('GRANT UPDATE (' + StringReplace(GuncelleKolonlari.DelimitedText, ',', ', ', [rfReplaceAll]) +
        ') ON ' + Nesne + ' TO ' + Kime + Secenek + ';');
    if ReferansKolonlari.Count > 0 then
      Satir('GRANT REFERENCES (' + StringReplace(ReferansKolonlari.DelimitedText, ',', ', ', [rfReplaceAll]) +
        ') ON ' + Nesne + ' TO ' + Kime + Secenek + ';');
  finally
    ReferansKolonlari.Free;
    GuncelleKolonlari.Free;
    Genel.Free;
  end;
end;

procedure TCikarici.Yetkiler;
var
  Liste: TArray<TYetkiBilgisi>;
  i, j: Integer;
begin
  Liste := YetkileriOku(FBag);
  if Length(Liste) > 0 then
    Satir('/* Grants */');
  i := 0;
  while i < Length(Liste) do
  begin
    Haber(T('MD_ASAMA_YETKILER'), i + 1, Length(Liste));
    if FIptal then
      Exit;
    j := i;
    while (j < Length(Liste)) and (Liste[j].Nesne = Liste[i].Nesne) and (Liste[j].NesneTuru = Liste[i].NesneTuru) and
      (Liste[j].KullaniciTuru = Liste[i].KullaniciTuru) and (Liste[j].Kullanici = Liste[i].Kullanici) and
      (Liste[j].SecenekVar = Liste[i].SecenekVar) do
      Inc(j);
    YetkiGrubuYaz(Liste, i, j - 1);
    i := j;
  end;
  if Length(Liste) > 0 then
    Satir('');
end;

procedure TCikarici.Aciklamalar;
var
  Liste: TArray<TAciklamaBilgisi>;
  Hedef: string;
  i: Integer;
begin
  Liste := AciklamalariOku(FBag);
  if Length(Liste) > 0 then
    Satir('/* Comments */');
  for i := 0 to High(Liste) do
  begin
    Haber(T('MD_ASAMA_ACIKLAMALAR'), i + 1, Length(Liste));
    if FIptal then
      Exit;
    Hedef := Liste[i].Tur;
    { Firebird 2.5 'PROCEDURE PARAMETER' bilmez; 'PARAMETER' 2.5, 3.0, 4.0 ve 5.0'in hepsinde gecerli. }
    if Hedef = 'PROCEDURE PARAMETER' then
      Hedef := 'PARAMETER';
    if Liste[i].Ad1 <> '' then
      Hedef := Hedef + ' ' + AdYaz(Liste[i].Ad1);
    if Liste[i].Ad2 <> '' then
      Hedef := Hedef + '.' + AdYaz(Liste[i].Ad2);
    Satir('COMMENT ON ' + Hedef + ' IS ' + YaziSabiti(Liste[i].Metin) + ';');
  end;
end;

function TCikarici.Calistir: Boolean;
var
  Atlanan: Integer;
begin
  FIptal := False;
  Atlanan := DesteklenmeyenNesneSayisi(FBag);
  if Atlanan > 0 then
    Uyar(TF('MD_UYARI_ATLANAN', [Atlanan]));
  Roller;
  if not FIptal then Istisnalar;
  if not FIptal then Generatorler;
  if not FIptal then Domainler;
  if not FIptal then Tablolar;
  if not FIptal then ProsedurIskeletleri;
  if not FIptal then Viewlar;
  if not FIptal then Kisitlar;
  if not FIptal then Indeksler;
  if not FIptal then Tetikleyiciler;
  if not FIptal then ProsedurGovdeleri;
  if not FIptal then Yetkiler;
  if not FIptal then Aciklamalar;
  TerimKapat;
  Result := not FIptal;
end;

{ Veritabani yolu: sunucu varsa 'sunucu/port:yol', yoksa yol. }
function VeritabaniAdresi(Bag: TAcikBaglanti): string;
begin
  Result := Bag.Tanim.VeritabaniYolu;
  if Bag.Tanim.Sunucu <> '' then
    Result := Bag.Tanim.Sunucu + '/' + IntToStr(Bag.Tanim.Port) + ':' + Result;
end;

{ SET NAMES, CREATE DATABASE, CONNECT. Sifre yalniz SifreYaz isaretliyse yazilir. }
procedure BaslikYaz(Bag: TAcikBaglanti; const Sec: TCikarSecenekleri; Yazici: TTextWriter);
var
  Kimlik, Komut, KarakterSeti: string;
  Sayfa: Integer;
begin
  Yazici.WriteLine('SET NAMES ' + ScriptKarakterSeti(Bag) + ';');
  { Dialect 1 veritabaninda DATE ve NUMERIC dialect 3'tekinden farkli anlam tasir; isql komutu olarak yazilir. }
  if Bag.Dialect <> 3 then
    Yazici.WriteLine('SET SQL DIALECT ' + IntToStr(Bag.Dialect) + ';');
  Yazici.WriteLine('');
  Kimlik := ' USER ' + YaziSabiti(Bag.Tanim.Kullanici);
  if Sec.SifreYaz then
    Kimlik := Kimlik + ' PASSWORD ' + YaziSabiti(Bag.Tanim.Sifre);
  if Sec.VeritabaniOlustur then
  begin
    Komut := 'CREATE DATABASE ' + YaziSabiti(VeritabaniAdresi(Bag)) + Kimlik;
    Sayfa := VeritabaniSayfaBoyutu(Bag);
    if Sayfa > 0 then
      Komut := Komut + ' PAGE_SIZE ' + IntToStr(Sayfa);
    KarakterSeti := VeritabaniVarsayilanKarakterSeti(Bag);
    if KarakterSeti <> '' then
      Komut := Komut + ' DEFAULT CHARACTER SET ' + KarakterSeti;
    Yazici.WriteLine(Komut + ';');
    Yazici.WriteLine('');
  end;
  if Sec.BaglantiYaz then
  begin
    Yazici.WriteLine('CONNECT ' + YaziSabiti(VeritabaniAdresi(Bag)) + Kimlik + ';');
    Yazici.WriteLine('');
  end;
end;

{ Metni bozmadan okumak icin UTF8 karakter setli ayri bir baglanti acilir; acilamazsa verilen baglanti
  kullanilir. Kendi: yeni baglanti acildi mi (isi bitince kapatilmali). }
function OkumaBaglantisiAc(Bag: TAcikBaglanti; out Kendi: Boolean): TAcikBaglanti;
var
  Tanim: TBaglantiTanimi;
begin
  Kendi := False;
  Result := Bag;
  if SameText(Bag.Tanim.KarakterSeti, OKUMA_KARAKTER_SETI) then
    Exit;
  Tanim := Bag.Tanim;
  Tanim.Ad := Bag.Tanim.Ad + ' (metadata)';
  Tanim.KarakterSeti := OKUMA_KARAKTER_SETI;
  try
    Result := FbBaglan(Tanim);
    Kendi := True;
  except
    Result := Bag;
  end;
end;

function MetadataCikar(Bag: TAcikBaglanti; const Secenekler: TCikarSecenekleri; Yazici: TTextWriter;
  Uyarilar: TStrings; Ilerleme: TCikarIlerlemesi): Boolean;
var
  Okuyucu: TAcikBaglanti;
  Kendi: Boolean;
  Cikarici: TCikarici;
begin
  Okuyucu := OkumaBaglantisiAc(Bag, Kendi);
  AnahtarKelimeleriKur(Bag.Surum);
  try
    BaslikYaz(Bag, Secenekler, Yazici);
    Cikarici := TCikarici.Create(Okuyucu, Yazici, Uyarilar, Ilerleme);
    try
      Result := Cikarici.Calistir;
    finally
      Cikarici.Free;
    end;
  finally
    AnahtarKelimeleriBirak;
    if Kendi then
      FbBaglantiyiKes(Okuyucu);
  end;
end;

end.
