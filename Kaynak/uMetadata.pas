{ uMetadata.pas - Tablo, view, prosedur, generator listeleri ve kolon bilgisi.

  Hedeflenen Firebird surumleri: 2.5, 3.0, 4.0, 5.0
  Denenen Firebird surumleri: 2.5.9, 5.0.4 (3.0 ve 4.0 henuz denenmedi)
  Surume bagli her sey bu unit'te toplanir. Once FireDAC TFDMetaInfoQuery
  kullanilir, yetmezse RDB$ sistem tablolarina dogrudan sorgu yazilir. }
unit uMetadata;

interface

uses
  System.SysUtils, System.Classes, System.StrUtils, System.Variants, System.Generics.Collections, Data.DB,
  FireDAC.Stan.Intf, FireDAC.Stan.Option, FireDAC.Stan.Param, FireDAC.Stan.Error,
  FireDAC.DatS, FireDAC.Phys.Intf, FireDAC.DApt.Intf, FireDAC.Comp.DataSet,
  FireDAC.Comp.Client, FireDAC.Phys.IBBase, FireDAC.Phys.IBWrapper,
  uDil, uBaglanti;

type
  { Nesne bulunamadi veya kaynak metni kayitli degil: mesaj kullaniciya oldugu gibi gosterilir. }
  EMetadataHatasi = class(Exception);

  { Script uretmek icin okunan sade kayitlar. Sistem tablolarini (RDB$) sadece bu unit bilir;
    uDDL bu kayitlardan metin uretir. }
  TKolonBilgisi = record
    Ad: string;
    { Domain kullaniyorsa domain adi, degilse bos }
    Domain: string;
    { 'VARCHAR(50) CHARACTER SET UTF8' gibi. Domain veya hesaplanan kolonda bos. }
    Tip: string;
    { Hesaplanan kolonda '(A + B)' gibi ifade, degilse bos }
    Hesaplanan: string;
    { 'DEFAULT 0' gibi, yoksa bos }
    Varsayilan: string;
    Collate: string;
    BosOlmaz: Boolean;
    { Kimlik (IDENTITY) kolonu: yalniz Firebird 3.0 ve ustu }
    Kimlik: Boolean;
    KimlikHep: Boolean;
    KimlikBaslangic: Int64;
    KimlikArtis: Int64;
  end;

  TKisitTuru = (ktBirincil, ktBenzersiz, ktYabanci, ktCheck);

  TKisitBilgisi = record
    { Sistem verdiyse (INTEG_n) bos }
    Ad: string;
    Tur: TKisitTuru;
    Kolonlar: TArray<string>;
    { Kullanici adli ozel indeks kullaniyorsa adi, degilse bos }
    IndeksAdi: string;
    HedefTablo: string;
    HedefKolonlar: TArray<string>;
    { 'CASCADE', 'SET NULL', 'SET DEFAULT'; varsayilan ise bos }
    GuncelleKurali: string;
    SilKurali: string;
    { 'CHECK (...)' }
    CheckMetni: string;
  end;

  TIndeksBilgisi = record
    Ad: string;
    Benzersiz: Boolean;
    Azalan: Boolean;
    Pasif: Boolean;
    Kolonlar: TArray<string>;
    { Ifade indeksinde '(UPPER(AD))' gibi, degilse bos }
    Ifade: string;
    { Kismi indeks kosulu (Firebird 5.0), yoksa bos }
    Kosul: string;
  end;

  TTetikleyiciBilgisi = record
    Ad: string;
    { Bagli oldugu tablo/view; veritabani tetikleyicisinde (ON CONNECT gibi) bos }
    Tablo: string;
    { 'BEFORE' veya 'AFTER'; veritabani tetikleyicisinde bos }
    Zaman: string;
    { 'INSERT OR UPDATE' gibi; veritabani tetikleyicisinde 'ON CONNECT' gibi }
    Olaylar: string;
    { DDL tetikleyicisi gibi desteklenmeyen tur: script uretilmez }
    Desteklenmiyor: Boolean;
    Sira: Integer;
    Aktif: Boolean;
    { Veritabaninda kayitli metin (genelde 'AS' ile baslar) }
    Kaynak: string;
  end;

  TTabloBilgisi = record
    { Gecici tablo (3.0+): 0 degil, 1 = ON COMMIT PRESERVE ROWS, 2 = ON COMMIT DELETE ROWS }
    GeciciTur: Integer;
    { Dis tablo ise dosya yolu, degilse bos }
    DisDosya: string;
    Kolonlar: TArray<TKolonBilgisi>;
    Kisitlar: TArray<TKisitBilgisi>;
    Indeksler: TArray<TIndeksBilgisi>;
    Tetikleyiciler: TArray<TTetikleyiciBilgisi>;
  end;

  TViewBilgisi = record
    Kolonlar: TArray<string>;
    Kaynak: string;
    Tetikleyiciler: TArray<TTetikleyiciBilgisi>;
  end;

  TParametreBilgisi = record
    Ad: string;
    Domain: string;
    Tip: string;
    Varsayilan: string;
    BosOlmaz: Boolean;
  end;

  TProsedurBilgisi = record
    Girdiler: TArray<TParametreBilgisi>;
    Ciktilar: TArray<TParametreBilgisi>;
    { 'AS'tan sonraki govde (DECLARE ... BEGIN ... END) }
    Kaynak: string;
  end;

  TGeneratorBilgisi = record
    Deger: Int64;
    { Firebird 3.0 ve ustunde ayarlanabilir; oncesinde hep 1 }
    Artis: Int64;
  end;

  TIstisnaBilgisi = record
    Ad: string;
    Mesaj: string;
  end;

  TDomainBilgisi = record
    Ad: string;
    Tip: string;
    Varsayilan: string;
    BosOlmaz: Boolean;
    { 'CHECK (VALUE > 0)' gibi, yoksa bos }
    Kontrol: string;
    Collate: string;
  end;

  { Bir yetki satiri. Yetki: S select, I insert, D delete, U update, R references, X execute,
    M rol uyeligi, G usage. KullaniciTuru: 8 kullanici, 13 rol, 5 prosedur, 2 tetikleyici, 1 view.
    NesneTuru: 0 tablo/view, 5 prosedur, 13 rol, 7 exception, 14 generator.
    SecenekVar: 0 yok, 1 GRANT OPTION, 2 ADMIN OPTION. }
  TYetkiBilgisi = record
    Kullanici: string;
    KullaniciTuru: Integer;
    Yetki: string;
    SecenekVar: Integer;
    Nesne: string;
    NesneTuru: Integer;
    Alan: string;
  end;

  { Bir nesnenin aciklamasi (COMMENT ON). Tur: 'TABLE', 'VIEW', 'COLUMN', 'PROCEDURE', 'PROCEDURE PARAMETER',
    'TRIGGER', 'SEQUENCE' (2.5'te 'GENERATOR'), 'EXCEPTION', 'DOMAIN', 'INDEX', 'ROLE', 'DATABASE'.
    Ad1: nesne adi; Ad2: kolon/parametre adi (yoksa bos). }
  TAciklamaBilgisi = record
    Tur: string;
    Ad1: string;
    Ad2: string;
    Metin: string;
  end;

  { Sunucunun bir kullanicisi (kullanicilar veritabanina degil sunucuya aittir). BilgiVar: Yonetici ve Aktif
    degerleri okunabildi mi (2.5 Services listesinde yoktur; orada False, iki alan da anlamsiz). }
  TKullaniciBilgisi = record
    Ad: string;
    Isim: string;
    OrtaAd: string;
    Soyad: string;
    Yonetici: Boolean;
    Aktif: Boolean;
    BilgiVar: Boolean;
  end;

  TKendiSifreKomutu = (skAlterUser, skAlterCurrentUser);

  { Kullanici yonetiminde sunucu surumune gore ne var: form yalniz bunlara bakar, surum numarasi bilmez. }
  TKullaniciYetenekleri = record
    { False: gomulu baglanti, sunucu yok, kullanici yonetimi yok }
    YonetimVar: Boolean;
    { Liste SQL ile (SEC$USERS) mi, yoksa Services API ile mi (2.5) alinir }
    ListeSql: Boolean;
    { Listede yonetici ve aktif bilgisi gelir mi }
    YoneticiOkunur: Boolean;
    YoneticiAyarlanir: Boolean;
    AktifPasif: Boolean;
    KendiSifreKomutu: TKendiSifreKomutu;
  end;

type
  { Bir nesneyi (view, exception, domain, generator) kullananlar. Tur: Firebird'in RDB$DEPENDENT_TYPE kodu
    (1 view, 2 tetikleyici, 3 hesaplanan kolon, 5 prosedur); domain'in tablo kolonlarinda kullanimi icin
    Tur = BAG_KOLON ve Ad = 'TABLO.KOLON'. }
  TBagimlilik = record
    Ad: string;
    Tur: Integer;
  end;

  TBagimlilikHedefi = (bhView, bhIstisna, bhDomain, bhGenerator);

const
  BAG_KOLON = -1;

function KullaniciYetenekleri(Bag: TAcikBaglanti): TKullaniciYetenekleri;
function KullaniciListesiOku(Bag: TAcikBaglanti): TArray<TKullaniciBilgisi>;

procedure TablolariGetir(Bag: TAcikBaglanti; Hedef: TStrings);
procedure ViewlariGetir(Bag: TAcikBaglanti; Hedef: TStrings);
procedure ProsedurleriGetir(Bag: TAcikBaglanti; Hedef: TStrings);
procedure GeneratorleriGetir(Bag: TAcikBaglanti; Hedef: TStrings);
{ Agac listeleri (Asama 3f): kullanici domain'leri ve exception'lari, yalniz adlar. Sistem nesneleri gelmez. }
procedure DomainleriGetir(Bag: TAcikBaglanti; Hedef: TStrings);
procedure IstisnalariGetir(Bag: TAcikBaglanti; Hedef: TStrings);
function KolonTablosuOlustur(Bag: TAcikBaglanti; const Tablo: string; Sahip: TComponent): TFDMemTable;
procedure KolonTablosuYazilariniYenile(Tablo: TDataSet);

{ Script uretimi icin okuma. Nesne yoksa veya govde metni kayitli degilse EMetadataHatasi verir. }
function TabloBilgisiOku(Bag: TAcikBaglanti; const Ad: string): TTabloBilgisi;
procedure TabloOzellikleriniOku(Bag: TAcikBaglanti; const Ad: string; var Bilgi: TTabloBilgisi);
function ViewBilgisiOku(Bag: TAcikBaglanti; const Ad: string): TViewBilgisi;
function ProsedurBilgisiOku(Bag: TAcikBaglanti; const Ad: string): TProsedurBilgisi;
function GeneratorBilgisiOku(Bag: TAcikBaglanti; const Ad: string): TGeneratorBilgisi;
{ Nesneyi kullananlar (RDB$DEPENDENCIES; domain'de ayrica tablo kolonlari). Silmeden ve degistirmeden once gosterilir.
  Kendisi listeye girmez; bagimli yoksa bos dizi. }
function BagimliNesneler(Bag: TAcikBaglanti; Hedef: TBagimlilikHedefi; const Ad: string): TArray<TBagimlilik>;
{ Tek domain / exception. Yoksa EMetadataHatasi. }
function DomainBilgisiOku(Bag: TAcikBaglanti; const Ad: string): TDomainBilgisi;
function IstisnaBilgisiOku(Bag: TAcikBaglanti; const Ad: string): TIstisnaBilgisi;
{ Tek tablonun parcalari (TabloBilgisiOku bunlari birlestirir). }
function KolonlariOku(Bag: TAcikBaglanti; const Tablo: string): TArray<TKolonBilgisi>;
function KisitlariOku(Bag: TAcikBaglanti; const Tablo: string): TArray<TKisitBilgisi>;
function IndeksleriOku(Bag: TAcikBaglanti; const Tablo: string): TArray<TIndeksBilgisi>;
{ Tablo bos ise veritabanindaki TUM kullanici tetikleyicileri (veritabani tetikleyicileri dahil). }
function TetikleyicileriOku(Bag: TAcikBaglanti; const Tablo: string): TArray<TTetikleyiciBilgisi>;
{ Agac listesi icin: tum kullanici tetikleyicileri, govde metni OLMADAN (hizli). DDL tetikleyicisinde Olaylar = 'DDL'. }
function TetikleyicileriListele(Bag: TAcikBaglanti): TArray<TTetikleyiciBilgisi>;
{ Tek tetikleyici (govdesiyle). Yoksa veya govde metni kayitli degilse EMetadataHatasi. }
function TetikleyiciBilgisiOku(Bag: TAcikBaglanti; const Ad: string): TTetikleyiciBilgisi;
{ Tum veritabani icin (Metadata cikar). Sistem nesneleri gelmez. }
function RolAdlari(Bag: TAcikBaglanti): TArray<string>;
function IstisnalariOku(Bag: TAcikBaglanti): TArray<TIstisnaBilgisi>;
function GeneratorAdlari(Bag: TAcikBaglanti): TArray<string>;
function DomainleriOku(Bag: TAcikBaglanti): TArray<TDomainBilgisi>;
function TabloAdlari(Bag: TAcikBaglanti): TArray<string>;
function ProsedurAdlari(Bag: TAcikBaglanti): TArray<string>;
{ View adlari, birbirine bagimliligina gore (once bagimlilik olmayanlar). Sirada cozulemeyenler
  (dongu) sona eklenir ve Dongu'ye de yazilir. }
function ViewAdlariSirali(Bag: TAcikBaglanti; out Dongu: TArray<string>): TArray<string>;
function YetkileriOku(Bag: TAcikBaglanti): TArray<TYetkiBilgisi>;
function AciklamalariOku(Bag: TAcikBaglanti): TArray<TAciklamaBilgisi>;
{ Bu surumde script'i uretilmeyen nesnelerin sayisi: fonksiyon (UDF ve PSQL), paket, kullanici collation'i, blob filtresi. }
function DesteklenmeyenNesneSayisi(Bag: TAcikBaglanti): Integer;
{ CREATE DATABASE icin: sayfa boyutu ve varsayilan karakter seti ('' = NONE). }
function VeritabaniSayfaBoyutu(Bag: TAcikBaglanti): Integer;
function VeritabaniVarsayilanKarakterSeti(Bag: TAcikBaglanti): string;
{ anahtar_kelimeler.txt dosyasindan, Surum ("5.0.4") icin gecerli kelimeleri okur. }
procedure AnahtarKelimeleriOku(const Dosya, Surum: string; Hedef: TStrings);

implementation

procedure ListeyiDoldur(Sorgu: TFDMetaInfoQuery; const AdAlani: string; Hedef: TStrings);
begin
  Sorgu.Open;
  Hedef.BeginUpdate;
  try
    Hedef.Clear;
    while not Sorgu.Eof do
    begin
      Hedef.Add(Trim(Sorgu.FieldByName(AdAlani).AsString));
      Sorgu.Next;
    end;
  finally
    Hedef.EndUpdate;
  end;
end;

procedure TablolariGetir(Bag: TAcikBaglanti; Hedef: TStrings);
var
  Sorgu: TFDMetaInfoQuery;
begin
  Sorgu := TFDMetaInfoQuery.Create(nil);
  try
    Sorgu.Connection := Bag.Baglanti;
    Sorgu.MetaInfoKind := mkTables;
    Sorgu.TableKinds := [tkTable];
    Sorgu.ObjectScopes := [osMy];
    ListeyiDoldur(Sorgu, 'TABLE_NAME', Hedef);
  finally
    Sorgu.Free;
  end;
end;

procedure ViewlariGetir(Bag: TAcikBaglanti; Hedef: TStrings);
var
  Sorgu: TFDMetaInfoQuery;
begin
  Sorgu := TFDMetaInfoQuery.Create(nil);
  try
    Sorgu.Connection := Bag.Baglanti;
    Sorgu.MetaInfoKind := mkTables;
    Sorgu.TableKinds := [tkView];
    Sorgu.ObjectScopes := [osMy];
    ListeyiDoldur(Sorgu, 'TABLE_NAME', Hedef);
  finally
    Sorgu.Free;
  end;
end;

procedure ProsedurleriGetir(Bag: TAcikBaglanti; Hedef: TStrings);
var
  Sorgu: TFDMetaInfoQuery;
begin
  Sorgu := TFDMetaInfoQuery.Create(nil);
  try
    Sorgu.Connection := Bag.Baglanti;
    Sorgu.MetaInfoKind := mkProcs;
    Sorgu.ObjectScopes := [osMy];
    ListeyiDoldur(Sorgu, 'PROC_NAME', Hedef);
  finally
    Sorgu.Free;
  end;
end;

procedure GeneratorleriGetir(Bag: TAcikBaglanti; Hedef: TStrings);
var
  Sorgu: TFDMetaInfoQuery;
begin
  Sorgu := TFDMetaInfoQuery.Create(nil);
  try
    Sorgu.Connection := Bag.Baglanti;
    Sorgu.MetaInfoKind := mkGenerators;
    Sorgu.ObjectScopes := [osMy];
    ListeyiDoldur(Sorgu, 'GENERATOR_NAME', Hedef);
  finally
    Sorgu.Free;
  end;
end;

function EvetHayir(Deger: Boolean): string;
begin
  if Deger then
    Result := T('EVET')
  else
    Result := T('HAYIR');
end;

function TipMetni(Sorgu: TFDMetaInfoQuery): string;
var
  Ad: string;
  Uzunluk, Hassasiyet, Olcek: Integer;
begin
  Ad := Trim(Sorgu.FieldByName('COLUMN_TYPENAME').AsString);
  Uzunluk := Sorgu.FieldByName('COLUMN_LENGTH').AsInteger;
  Hassasiyet := Sorgu.FieldByName('COLUMN_PRECISION').AsInteger;
  Olcek := Sorgu.FieldByName('COLUMN_SCALE').AsInteger;
  Result := Ad;
  if (Pos('CHAR', UpperCase(Ad)) > 0) and (Uzunluk > 0) then
    Result := Ad + '(' + IntToStr(Uzunluk) + ')'
  else if ((Pos('NUMERIC', UpperCase(Ad)) > 0) or (Pos('DECIMAL', UpperCase(Ad)) > 0)) and (Hassasiyet > 0) then
    Result := Ad + '(' + IntToStr(Hassasiyet) + ',' + IntToStr(Olcek) + ')';
end;

{ Kolon bilgisini kucuk bir bellek tablosuna koyar. Tablo, Sahip ile birlikte yok olur. }
function KolonTablosuOlustur(Bag: TAcikBaglanti; const Tablo: string; Sahip: TComponent): TFDMemTable;
var
  Sorgu: TFDMetaInfoQuery;
  BosOlur: Boolean;
begin
  Result := TFDMemTable.Create(Sahip);
  Result.FieldDefs.Add('AD', ftString, 128);
  Result.FieldDefs.Add('TIP', ftString, 64);
  Result.FieldDefs.Add('BOS_OLUR', ftString, 8);
  Result.FieldDefs.Add('BOS_OLUR_MI', ftBoolean);
  Result.CreateDataSet;
  Result.FieldByName('AD').DisplayWidth := 30;
  Result.FieldByName('TIP').DisplayWidth := 22;
  Result.FieldByName('BOS_OLUR').DisplayWidth := 14;
  Result.FieldByName('BOS_OLUR_MI').Visible := False;
  Sorgu := TFDMetaInfoQuery.Create(nil);
  try
    Sorgu.Connection := Bag.Baglanti;
    Sorgu.MetaInfoKind := mkTableFields;
    { Buyuk/kucuk harf ve ozel karakterler korunsun diye tirnakli verilir. }
    Sorgu.ObjectName := '"' + StringReplace(Tablo, '"', '""', [rfReplaceAll]) + '"';
    Sorgu.Open;
    while not Sorgu.Eof do
    begin
      BosOlur := (Sorgu.FieldByName('COLUMN_ATTRIBUTES').AsInteger and
        (1 shl Ord(caAllowNull))) <> 0;
      Result.Append;
      Result.FieldByName('AD').AsString := Trim(Sorgu.FieldByName('COLUMN_NAME').AsString);
      Result.FieldByName('TIP').AsString := TipMetni(Sorgu);
      Result.FieldByName('BOS_OLUR_MI').AsBoolean := BosOlur;
      Result.FieldByName('BOS_OLUR').AsString := EvetHayir(BosOlur);
      Result.Post;
      Sorgu.Next;
    end;
  finally
    Sorgu.Free;
  end;
  Result.First;
end;


{ Dil degisince "Evet/Hayir" yazilarini yeniden yazar. }
procedure KolonTablosuYazilariniYenile(Tablo: TDataSet);
begin
  Tablo.DisableControls;
  try
    Tablo.First;
    while not Tablo.Eof do
    begin
      Tablo.Edit;
      Tablo.FieldByName('BOS_OLUR').AsString := EvetHayir(Tablo.FieldByName('BOS_OLUR_MI').AsBoolean);
      Tablo.Post;
      Tablo.Next;
    end;
    Tablo.First;
  finally
    Tablo.EnableControls;
  end;
end;

{ ---------- Script uretimi icin okuma (RDB$ sistem tablolari) ---------- }

function HamTirnak(const Ad: string): string;
begin
  Result := '"' + StringReplace(Ad, '"', '""', [rfReplaceAll]) + '"';
end;

{ Firebird ana surum numarasi: "5.0.4" icin 5. }
function SurumNo(Bag: TAcikBaglanti): Integer;
begin
  Result := StrToIntDef(Copy(Bag.Surum, 1, Pos('.', Bag.Surum) - 1), 0);
end;

{ Sorguyu acar (tum satirlar cekilir). Tek ':' parametresi varsa Parametre ona yazilir. }
function SorguAc(Bag: TAcikBaglanti; const Sql, Parametre: string): TFDQuery;
begin
  Result := TFDQuery.Create(nil);
  try
    Result.Connection := Bag.Baglanti;
    Result.FetchOptions.Mode := fmAll;
    Result.SQL.Text := Sql;
    if Parametre <> '' then
      Result.Params[0].AsString := Parametre;
    Result.Open;
  except
    Result.Free;
    raise;
  end;
end;

{ Ilk kolonun ilk satiri; satir yoksa veya bos ise ''. }
function TekDeger(Bag: TAcikBaglanti; const Sql, Parametre: string): string;
var
  Sorgu: TFDQuery;
begin
  Sorgu := SorguAc(Bag, Sql, Parametre);
  try
    if Sorgu.Eof then
      Result := ''
    else
      Result := Trim(Sorgu.Fields[0].AsString);
  finally
    Sorgu.Free;
  end;
end;

{ Ilk kolonun tum satirlari }
function SutunListesi(Bag: TAcikBaglanti; const Sql, Parametre: string): TArray<string>;
var
  Sorgu: TFDQuery;
  Liste: TList<string>;
begin
  Liste := TList<string>.Create;
  Sorgu := SorguAc(Bag, Sql, Parametre);
  try
    while not Sorgu.Eof do
    begin
      Liste.Add(Trim(Sorgu.Fields[0].AsString));
      Sorgu.Next;
    end;
    Result := Liste.ToArray;
  finally
    Sorgu.Free;
    Liste.Free;
  end;
end;

procedure NesneVarMi(Bag: TAcikBaglanti; const Sql, Ad: string);
begin
  if TekDeger(Bag, Sql, Ad) = '' then
    raise EMetadataHatasi.Create(TF('ERR_DDL_NESNE_YOK', [Ad]));
end;

{ Domain adlari: kullanici domain'leri (RDB$ ile baslayan, sunucunun kolonlar icin urettigi adlar ve sistem domain'leri haric). }
procedure DomainleriGetir(Bag: TAcikBaglanti; Hedef: TStrings);
begin
  Hedef.Clear;
  Hedef.AddStrings(SutunListesi(Bag, 'select rdb$field_name from rdb$fields ' +
    'where rdb$field_name not starting with ''RDB$'' and coalesce(rdb$system_flag, 0) = 0 ' +
    'order by rdb$field_name', ''));
end;

procedure IstisnalariGetir(Bag: TAcikBaglanti; Hedef: TStrings);
begin
  Hedef.Clear;
  Hedef.AddStrings(SutunListesi(Bag, 'select rdb$exception_name from rdb$exceptions ' +
    'where coalesce(rdb$system_flag, 0) = 0 order by rdb$exception_name', ''));
end;

function SayiTipi(const Ad: string; VarsayilanHassasiyet, AltTip, Hassasiyet, Olcek: Integer): string;
begin
  if (AltTip = 0) and (Olcek = 0) then
    Exit(Ad);
  if Hassasiyet = 0 then
    Hassasiyet := VarsayilanHassasiyet;
  if AltTip = 2 then
    Result := 'DECIMAL'
  else
    Result := 'NUMERIC';
  Result := Result + '(' + IntToStr(Hassasiyet) + ', ' + IntToStr(Olcek) + ')';
end;

{ Sorgudaki TIP, ALT_TIP, UZUNLUK, OLCEK, HASSASIYET, KARAKTER_UZ, BLOB_PARCA, CS_ADI alanlarindan
  tip yazisini uretir. Karakter seti sadece veritabaninin varsayilanindan farkliysa yazilir (isql -x gibi). }
function TipMetniUret(Sorgu: TFDQuery; const VarsayilanCS: string; Dialect: Integer): string;
var
  Tip, AltTip, Hassasiyet, Olcek, Boy, Parca: Integer;
  CS: string;
begin
  Tip := Sorgu.FieldByName('TIP').AsInteger;
  AltTip := Sorgu.FieldByName('ALT_TIP').AsInteger;
  Hassasiyet := Sorgu.FieldByName('HASSASIYET').AsInteger;
  Olcek := -Sorgu.FieldByName('OLCEK').AsInteger;
  CS := Trim(Sorgu.FieldByName('CS_ADI').AsString);
  if (CS <> '') and (CS <> VarsayilanCS) then
    CS := ' CHARACTER SET ' + CS
  else
    CS := '';
  case Tip of
    7: Result := SayiTipi('SMALLINT', 4, AltTip, Hassasiyet, Olcek);
    8: Result := SayiTipi('INTEGER', 9, AltTip, Hassasiyet, Olcek);
    16: Result := SayiTipi('BIGINT', 18, AltTip, Hassasiyet, Olcek);
    26: Result := SayiTipi('INT128', 38, AltTip, Hassasiyet, Olcek);
    10: Result := 'FLOAT';
    { Dialect 1 veritabaninda NUMERIC/DECIMAL sayilar DOUBLE olarak saklanir (olcekli); araclar NUMERIC(p, s) yazar. }
    27: if Dialect = 1 then
          Result := SayiTipi('DOUBLE PRECISION', 15, AltTip, Hassasiyet, Olcek)
        else
          Result := 'DOUBLE PRECISION';
    12: Result := 'DATE';
    13: Result := 'TIME';
    { Dialect 1'de DATE tipi tarih+saat tutar ve DATE diye yazilir (TIMESTAMP degil). }
    35: if Dialect = 1 then
          Result := 'DATE'
        else
          Result := 'TIMESTAMP';
    23: Result := 'BOOLEAN';
    24: Result := 'DECFLOAT(16)';
    25: Result := 'DECFLOAT(34)';
    28: Result := 'TIME WITH TIME ZONE';
    29: Result := 'TIMESTAMP WITH TIME ZONE';
    14, 37:
      begin
        Boy := Sorgu.FieldByName('KARAKTER_UZ').AsInteger;
        if Boy = 0 then
          Boy := Sorgu.FieldByName('UZUNLUK').AsInteger;
        if Tip = 14 then
          Result := 'CHAR'
        else
          Result := 'VARCHAR';
        Result := Result + '(' + IntToStr(Boy) + ')' + CS;
      end;
    261:
      begin
        Parca := Sorgu.FieldByName('BLOB_PARCA').AsInteger;
        Result := 'BLOB SUB_TYPE ' + IntToStr(AltTip);
        if (Parca <> 0) and (Parca <> 80) then
          Result := Result + ' SEGMENT SIZE ' + IntToStr(Parca);
        if AltTip = 1 then
          Result := Result + CS;
      end;
  else
    raise EMetadataHatasi.Create(TF('ERR_DDL_TIP_BILINMIYOR', [Tip]));
  end;
end;

function VarsayilanMetni(const Ham: string): string;
var
  Metin: string;
begin
  Metin := Trim(Ham);
  if Metin = '' then
    Result := ''
  else if Metin[1] = '=' then
    Result := 'DEFAULT ' + Trim(Copy(Metin, 2, MaxInt))
  else if StartsText('DEFAULT', Metin) then
    Result := Metin
  else
    Result := 'DEFAULT ' + Metin;
end;

{ Hesaplanan kolon / ifade indeksi kaynagi: her zaman parantezle baslayan ifade olarak verilir. }
function IfadeMetni(const Ham: string): string;
var
  Metin: string;
begin
  Metin := Trim(Ham);
  if StartsText('COMPUTED', Metin) and (Pos('(', Metin) > 0) then
    Metin := Copy(Metin, Pos('(', Metin), MaxInt);
  if (Metin <> '') and (Metin[1] <> '(') then
    Metin := '(' + Metin + ')';
  Result := Metin;
end;

function VeritabaniKarakterSeti(Bag: TAcikBaglanti): string;
begin
  Result := TekDeger(Bag, 'select rdb$character_set_name from rdb$database', '');
  if Result = '' then
    Result := 'NONE';
end;

function KolonlariOku(Bag: TAcikBaglanti; const Tablo: string): TArray<TKolonBilgisi>;
var
  Sorgu: TFDQuery;
  Liste: TList<TKolonBilgisi>;
  Kolon: TKolonBilgisi;
  Sql, KimlikAlanlari, KimlikBaglantisi, VarsayilanCS, Kaynak: string;
  RfSira, FSira: Integer;
begin
  VarsayilanCS := VeritabaniKarakterSeti(Bag);
  KimlikAlanlari := '';
  KimlikBaglantisi := '';
  if SurumNo(Bag) >= 3 then
  begin
    KimlikAlanlari := ', rf.rdb$identity_type as KIMLIK, g.rdb$initial_value as KIMLIK_BASLANGIC, ' +
      'g.rdb$generator_increment as KIMLIK_ARTIS';
    KimlikBaglantisi := 'left join rdb$generators g on g.rdb$generator_name = rf.rdb$generator_name ';
  end;
  Sql := 'select rf.rdb$field_name as AD, rf.rdb$field_source as KAYNAK, rf.rdb$null_flag as RF_BOS_OLMAZ, ' +
    'rf.rdb$default_source as RF_VARSAYILAN, rf.rdb$collation_id as RF_COLL, f.rdb$collation_id as F_COLL, ' +
    'f.rdb$field_type as TIP, f.rdb$field_sub_type as ALT_TIP, f.rdb$field_length as UZUNLUK, ' +
    'f.rdb$field_scale as OLCEK, f.rdb$field_precision as HASSASIYET, f.rdb$character_length as KARAKTER_UZ, ' +
    'f.rdb$segment_length as BLOB_PARCA, f.rdb$computed_source as HESAPLANAN, ' +
    'cs.rdb$character_set_name as CS_ADI, co.rdb$collation_name as COLL_ADI' + KimlikAlanlari + ' ' +
    'from rdb$relation_fields rf ' +
    'join rdb$fields f on f.rdb$field_name = rf.rdb$field_source ' +
    'left join rdb$character_sets cs on cs.rdb$character_set_id = f.rdb$character_set_id ' +
    'left join rdb$collations co on co.rdb$character_set_id = f.rdb$character_set_id ' +
    'and co.rdb$collation_id = coalesce(rf.rdb$collation_id, f.rdb$collation_id) ' + KimlikBaglantisi +
    'where rf.rdb$relation_name = :T order by rf.rdb$field_position';
  Liste := TList<TKolonBilgisi>.Create;
  Sorgu := SorguAc(Bag, Sql, Tablo);
  try
    while not Sorgu.Eof do
    begin
      Kolon := Default(TKolonBilgisi);
      Kolon.Ad := Trim(Sorgu.FieldByName('AD').AsString);
      Kaynak := Trim(Sorgu.FieldByName('KAYNAK').AsString);
      Kolon.BosOlmaz := Sorgu.FieldByName('RF_BOS_OLMAZ').AsInteger = 1;
      Kolon.Varsayilan := VarsayilanMetni(Sorgu.FieldByName('RF_VARSAYILAN').AsString);
      RfSira := Sorgu.FieldByName('RF_COLL').AsInteger;
      FSira := Sorgu.FieldByName('F_COLL').AsInteger;
      if Trim(Sorgu.FieldByName('HESAPLANAN').AsString) <> '' then
        Kolon.Hesaplanan := IfadeMetni(Sorgu.FieldByName('HESAPLANAN').AsString)
      else if not StartsText('RDB$', Kaynak) then
      begin
        Kolon.Domain := Kaynak;
        { Domainin kendi collation'indan farkli bir collation sadece kolonda verilmisse yazilir. }
        if (not Sorgu.FieldByName('RF_COLL').IsNull) and (RfSira <> FSira) then
          Kolon.Collate := Trim(Sorgu.FieldByName('COLL_ADI').AsString);
      end
      else
      begin
        Kolon.Tip := TipMetniUret(Sorgu, VarsayilanCS, Bag.Dialect);
        if Sorgu.FieldByName('RF_COLL').IsNull then
          RfSira := FSira;
        if RfSira > 0 then
          Kolon.Collate := Trim(Sorgu.FieldByName('COLL_ADI').AsString);
      end;
      if (Sorgu.FindField('KIMLIK') <> nil) and (not Sorgu.FieldByName('KIMLIK').IsNull) then
      begin
        Kolon.Kimlik := True;
        Kolon.KimlikHep := Sorgu.FieldByName('KIMLIK').AsInteger = 0;
        Kolon.KimlikBaslangic := Sorgu.FieldByName('KIMLIK_BASLANGIC').AsLargeInt;
        Kolon.KimlikArtis := Sorgu.FieldByName('KIMLIK_ARTIS').AsLargeInt;
      end;
      Liste.Add(Kolon);
      Sorgu.Next;
    end;
    Result := Liste.ToArray;
  finally
    Sorgu.Free;
    Liste.Free;
  end;
end;

function IndeksKolonlari(Bag: TAcikBaglanti; const Indeks: string): TArray<string>;
begin
  Result := SutunListesi(Bag, 'select rdb$field_name from rdb$index_segments ' +
    'where rdb$index_name = :I order by rdb$field_position', Indeks);
end;

function KisitlariOku(Bag: TAcikBaglanti; const Tablo: string): TArray<TKisitBilgisi>;
var
  Sorgu: TFDQuery;
  Liste: TList<TKisitBilgisi>;
  Kisit: TKisitBilgisi;
  Ad, Tur, Indeks, Hedef, HedefIndeks: string;
begin
  Liste := TList<TKisitBilgisi>.Create;
  Sorgu := SorguAc(Bag, 'select rc.rdb$constraint_name as AD, rc.rdb$constraint_type as TUR, ' +
    'rc.rdb$index_name as INDEKS, rf.rdb$const_name_uq as HEDEF, rf.rdb$update_rule as GUNCELLE, ' +
    'rf.rdb$delete_rule as SIL ' +
    'from rdb$relation_constraints rc ' +
    'left join rdb$ref_constraints rf on rf.rdb$constraint_name = rc.rdb$constraint_name ' +
    'where rc.rdb$relation_name = :T ' +
    'and rc.rdb$constraint_type in (''PRIMARY KEY'', ''UNIQUE'', ''FOREIGN KEY'', ''CHECK'') ' +
    'order by case rc.rdb$constraint_type when ''PRIMARY KEY'' then 0 when ''UNIQUE'' then 1 ' +
    'when ''FOREIGN KEY'' then 2 else 3 end, rc.rdb$constraint_name', Tablo);
  try
    while not Sorgu.Eof do
    begin
      Kisit := Default(TKisitBilgisi);
      Ad := Trim(Sorgu.FieldByName('AD').AsString);
      Tur := Trim(Sorgu.FieldByName('TUR').AsString);
      Indeks := Trim(Sorgu.FieldByName('INDEKS').AsString);
      if not StartsText('INTEG_', Ad) then
        Kisit.Ad := Ad;
      if (Indeks <> '') and (Indeks <> Ad) and not StartsText('RDB$', Indeks) then
        Kisit.IndeksAdi := Indeks;
      if Tur = 'CHECK' then
      begin
        Kisit.Tur := ktCheck;
        Kisit.CheckMetni := TekDeger(Bag, 'select first 1 t.rdb$trigger_source from rdb$check_constraints cc ' +
          'join rdb$triggers t on t.rdb$trigger_name = cc.rdb$trigger_name ' +
          'where cc.rdb$constraint_name = :C', Ad);
        if not StartsText('CHECK', Kisit.CheckMetni) then
          Kisit.CheckMetni := 'CHECK ' + Kisit.CheckMetni;
      end
      else
      begin
        Kisit.Kolonlar := IndeksKolonlari(Bag, Indeks);
        if Tur = 'PRIMARY KEY' then
          Kisit.Tur := ktBirincil
        else if Tur = 'UNIQUE' then
          Kisit.Tur := ktBenzersiz
        else
        begin
          Kisit.Tur := ktYabanci;
          Hedef := Trim(Sorgu.FieldByName('HEDEF').AsString);
          Kisit.HedefTablo := TekDeger(Bag, 'select rdb$relation_name from rdb$relation_constraints ' +
            'where rdb$constraint_name = :C', Hedef);
          HedefIndeks := TekDeger(Bag, 'select rdb$index_name from rdb$relation_constraints ' +
            'where rdb$constraint_name = :C', Hedef);
          Kisit.HedefKolonlar := IndeksKolonlari(Bag, HedefIndeks);
          Kisit.GuncelleKurali := Trim(Sorgu.FieldByName('GUNCELLE').AsString);
          Kisit.SilKurali := Trim(Sorgu.FieldByName('SIL').AsString);
          if (Kisit.GuncelleKurali = 'RESTRICT') or (Kisit.GuncelleKurali = 'NO ACTION') then
            Kisit.GuncelleKurali := '';
          if (Kisit.SilKurali = 'RESTRICT') or (Kisit.SilKurali = 'NO ACTION') then
            Kisit.SilKurali := '';
        end;
      end;
      Liste.Add(Kisit);
      Sorgu.Next;
    end;
    Result := Liste.ToArray;
  finally
    Sorgu.Free;
    Liste.Free;
  end;
end;

{ Kisit (PK, UNIQUE, FK) indeksleri atlanir; onlar kisitla birlikte kurulur. }
function IndeksleriOku(Bag: TAcikBaglanti; const Tablo: string): TArray<TIndeksBilgisi>;
var
  Sorgu: TFDQuery;
  Liste: TList<TIndeksBilgisi>;
  Indeks: TIndeksBilgisi;
  KosulAlani: string;
begin
  KosulAlani := '';
  if SurumNo(Bag) >= 5 then
    KosulAlani := ', i.rdb$condition_source as KOSUL';
  Liste := TList<TIndeksBilgisi>.Create;
  Sorgu := SorguAc(Bag, 'select i.rdb$index_name as AD, i.rdb$unique_flag as BENZERSIZ, ' +
    'i.rdb$index_type as TUR, i.rdb$index_inactive as PASIF, i.rdb$expression_source as IFADE' +
    KosulAlani + ' from rdb$indices i where i.rdb$relation_name = :T ' +
    'and not exists (select 1 from rdb$relation_constraints rc where rc.rdb$index_name = i.rdb$index_name) ' +
    'order by i.rdb$index_name', Tablo);
  try
    while not Sorgu.Eof do
    begin
      Indeks := Default(TIndeksBilgisi);
      Indeks.Ad := Trim(Sorgu.FieldByName('AD').AsString);
      Indeks.Benzersiz := Sorgu.FieldByName('BENZERSIZ').AsInteger = 1;
      Indeks.Azalan := Sorgu.FieldByName('TUR').AsInteger = 1;
      Indeks.Pasif := Sorgu.FieldByName('PASIF').AsInteger = 1;
      if Trim(Sorgu.FieldByName('IFADE').AsString) <> '' then
        Indeks.Ifade := IfadeMetni(Sorgu.FieldByName('IFADE').AsString)
      else
        Indeks.Kolonlar := IndeksKolonlari(Bag, Indeks.Ad);
      if (Sorgu.FindField('KOSUL') <> nil) and (Trim(Sorgu.FieldByName('KOSUL').AsString) <> '') then
      begin
        Indeks.Kosul := Trim(Sorgu.FieldByName('KOSUL').AsString);
        if not StartsText('WHERE', Indeks.Kosul) then
          Indeks.Kosul := 'WHERE ' + Indeks.Kosul;
      end;
      Liste.Add(Indeks);
      Sorgu.Next;
    end;
    Result := Liste.ToArray;
  finally
    Sorgu.Free;
    Liste.Free;
  end;
end;

{ Kullanici tetikleyicileri (CHECK tetikleyicileri sistem bayrakli oldugu icin gelmez).
  Filtre bos degilse yalniz o tablo/view'unkiler (Ad=False) ya da yalniz o adli tetikleyici (Ad=True).
  KaynakDahil False ise govde metni okunmaz (agac listesi hizli gelsin). }
function TetikleyicileriOkuIc(Bag: TAcikBaglanti; const Filtre: string; Ad, KaynakDahil: Boolean):
  TArray<TTetikleyiciBilgisi>;
var
  Sorgu: TFDQuery;
  Liste: TList<TTetikleyiciBilgisi>;
  Tetik: TTetikleyiciBilgisi;
  Tip, Olay, i: Integer;
  Sart, KaynakAlani: string;
begin
  Sart := '';
  if Filtre <> '' then
    if Ad then
      Sart := ' and rdb$trigger_name = :T'
    else
      Sart := ' and rdb$relation_name = :T';
  KaynakAlani := 'cast(null as varchar(1))';
  if KaynakDahil then
    KaynakAlani := 'rdb$trigger_source';
  Liste := TList<TTetikleyiciBilgisi>.Create;
  Sorgu := SorguAc(Bag, 'select rdb$trigger_name as AD, rdb$relation_name as TABLO, rdb$trigger_type as TUR, ' +
    'rdb$trigger_sequence as SIRA, rdb$trigger_inactive as PASIF, ' + KaynakAlani + ' as KAYNAK ' +
    'from rdb$triggers where coalesce(rdb$system_flag, 0) = 0' + Sart + ' ' +
    'order by rdb$relation_name, rdb$trigger_sequence, rdb$trigger_name', Filtre);
  try
    while not Sorgu.Eof do
    begin
      Tetik := Default(TTetikleyiciBilgisi);
      Tetik.Ad := Trim(Sorgu.FieldByName('AD').AsString);
      Tetik.Tablo := Trim(Sorgu.FieldByName('TABLO').AsString);
      Tetik.Sira := Sorgu.FieldByName('SIRA').AsInteger;
      Tetik.Aktif := Sorgu.FieldByName('PASIF').AsInteger <> 1;
      Tetik.Kaynak := Sorgu.FieldByName('KAYNAK').AsString;
      if KaynakDahil and (Filtre <> '') and (Trim(Tetik.Kaynak) = '') then
        raise EMetadataHatasi.Create(TF('ERR_DDL_KAYNAK_YOK', [Tetik.Ad]));
      Tip := Sorgu.FieldByName('TUR').AsInteger;
      if (Tip and 16384) <> 0 then
      begin
        { DDL tetikleyicisi: bu surumde script uretilmez. Olaylar yalniz agac listesinde tur olarak gorunur. }
        Tetik.Desteklenmiyor := True;
        Tetik.Olaylar := 'DDL';
      end
      else if (Tip and 8192) <> 0 then
      begin
        { Veritabani tetikleyicisi: 8192 + 0 CONNECT, 1 DISCONNECT, 2 TRANSACTION START, 3 COMMIT, 4 ROLLBACK }
        case Tip - 8192 of
          0: Tetik.Olaylar := 'ON CONNECT';
          1: Tetik.Olaylar := 'ON DISCONNECT';
          2: Tetik.Olaylar := 'ON TRANSACTION START';
          3: Tetik.Olaylar := 'ON TRANSACTION COMMIT';
          4: Tetik.Olaylar := 'ON TRANSACTION ROLLBACK';
        else
          Tetik.Desteklenmiyor := True;
        end;
      end
      else
      begin
        { Tablo tetikleyicisi. Tip: tek sayi, 1 = BEFORE INSERT, 2 = AFTER INSERT, 3 = BEFORE UPDATE ...
          Birden cok olayda ((Tip + 1) sagdan ikiser bit) en fazla uc olay tutar: 1 INSERT, 2 UPDATE, 3 DELETE. }
        if Odd(Tip) then
          Tetik.Zaman := 'BEFORE'
        else
          Tetik.Zaman := 'AFTER';
        for i := 0 to 2 do
        begin
          Olay := ((Tip + 1) shr (1 + i * 2)) and 3;
          if Olay = 0 then
            Continue;
          if Tetik.Olaylar <> '' then
            Tetik.Olaylar := Tetik.Olaylar + ' OR ';
          case Olay of
            1: Tetik.Olaylar := Tetik.Olaylar + 'INSERT';
            2: Tetik.Olaylar := Tetik.Olaylar + 'UPDATE';
          else
            Tetik.Olaylar := Tetik.Olaylar + 'DELETE';
          end;
        end;
      end;
      Liste.Add(Tetik);
      Sorgu.Next;
    end;
    Result := Liste.ToArray;
  finally
    Sorgu.Free;
    Liste.Free;
  end;
end;

function TetikleyicileriOku(Bag: TAcikBaglanti; const Tablo: string): TArray<TTetikleyiciBilgisi>;
begin
  Result := TetikleyicileriOkuIc(Bag, Tablo, False, True);
end;

function TetikleyicileriListele(Bag: TAcikBaglanti): TArray<TTetikleyiciBilgisi>;
begin
  Result := TetikleyicileriOkuIc(Bag, '', False, False);
end;

function TetikleyiciBilgisiOku(Bag: TAcikBaglanti; const Ad: string): TTetikleyiciBilgisi;
var
  Liste: TArray<TTetikleyiciBilgisi>;
begin
  Liste := TetikleyicileriOkuIc(Bag, Ad, True, True);
  if Length(Liste) = 0 then
    raise EMetadataHatasi.Create(TF('ERR_DDL_NESNE_YOK', [Ad]));
  Result := Liste[0];
end;

{ Tablonun gecici/dis tablo ozelliklerini Bilgi'ye yazar (kolon ve kisitlara dokunmaz). }
procedure TabloOzellikleriniOku(Bag: TAcikBaglanti; const Ad: string; var Bilgi: TTabloBilgisi);
begin
  Bilgi.GeciciTur := 0;
  if SurumNo(Bag) >= 3 then
    case StrToIntDef(TekDeger(Bag, 'select rdb$relation_type from rdb$relations where rdb$relation_name = :N', Ad), 0) of
      4: Bilgi.GeciciTur := 1;
      5: Bilgi.GeciciTur := 2;
    end;
  Bilgi.DisDosya := TekDeger(Bag, 'select rdb$external_file from rdb$relations where rdb$relation_name = :N', Ad);
end;

function TabloBilgisiOku(Bag: TAcikBaglanti; const Ad: string): TTabloBilgisi;
begin
  NesneVarMi(Bag, 'select rdb$relation_name from rdb$relations where rdb$relation_name = :N ' +
    'and rdb$view_blr is null', Ad);
  TabloOzellikleriniOku(Bag, Ad, Result);
  Result.Kolonlar := KolonlariOku(Bag, Ad);
  Result.Kisitlar := KisitlariOku(Bag, Ad);
  Result.Indeksler := IndeksleriOku(Bag, Ad);
  Result.Tetikleyiciler := TetikleyicileriOku(Bag, Ad);
end;

function ViewBilgisiOku(Bag: TAcikBaglanti; const Ad: string): TViewBilgisi;
begin
  NesneVarMi(Bag, 'select rdb$relation_name from rdb$relations where rdb$relation_name = :N ' +
    'and rdb$view_blr is not null', Ad);
  Result.Kaynak := TekDeger(Bag, 'select rdb$view_source from rdb$relations where rdb$relation_name = :N', Ad);
  if Result.Kaynak = '' then
    raise EMetadataHatasi.Create(TF('ERR_DDL_KAYNAK_YOK', [Ad]));
  Result.Kolonlar := SutunListesi(Bag, 'select rdb$field_name from rdb$relation_fields ' +
    'where rdb$relation_name = :N order by rdb$field_position', Ad);
  Result.Tetikleyiciler := TetikleyicileriOku(Bag, Ad);
end;

function ParametreleriOku(Bag: TAcikBaglanti; const Prosedur: string; Girdi: Boolean): TArray<TParametreBilgisi>;
var
  Sorgu: TFDQuery;
  Liste: TList<TParametreBilgisi>;
  Param: TParametreBilgisi;
  Sql, Kaynak, VarsayilanCS, ParcaAlani, PaketSarti: string;
  Surum: Integer;
begin
  Surum := SurumNo(Bag);
  VarsayilanCS := VeritabaniKarakterSeti(Bag);
  ParcaAlani := '';
  PaketSarti := '';
  if Surum >= 3 then
  begin
    ParcaAlani := ', p.rdb$null_flag as BOS_OLMAZ, p.rdb$default_source as VARSAYILAN';
    PaketSarti := ' and p.rdb$package_name is null';
  end;
  Sql := 'select p.rdb$parameter_name as AD, p.rdb$field_source as KAYNAK' + ParcaAlani + ', ' +
    'f.rdb$field_type as TIP, f.rdb$field_sub_type as ALT_TIP, f.rdb$field_length as UZUNLUK, ' +
    'f.rdb$field_scale as OLCEK, f.rdb$field_precision as HASSASIYET, f.rdb$character_length as KARAKTER_UZ, ' +
    'f.rdb$segment_length as BLOB_PARCA, cs.rdb$character_set_name as CS_ADI ' +
    'from rdb$procedure_parameters p ' +
    'join rdb$fields f on f.rdb$field_name = p.rdb$field_source ' +
    'left join rdb$character_sets cs on cs.rdb$character_set_id = f.rdb$character_set_id ' +
    'where p.rdb$procedure_name = :P and p.rdb$parameter_type = ' + IfThen(Girdi, '0', '1') + PaketSarti +
    ' order by p.rdb$parameter_number';
  Liste := TList<TParametreBilgisi>.Create;
  Sorgu := SorguAc(Bag, Sql, Prosedur);
  try
    while not Sorgu.Eof do
    begin
      Param := Default(TParametreBilgisi);
      Param.Ad := Trim(Sorgu.FieldByName('AD').AsString);
      Kaynak := Trim(Sorgu.FieldByName('KAYNAK').AsString);
      if StartsText('RDB$', Kaynak) then
        Param.Tip := TipMetniUret(Sorgu, VarsayilanCS, Bag.Dialect)
      else
        Param.Domain := Kaynak;
      if Sorgu.FindField('BOS_OLMAZ') <> nil then
      begin
        Param.BosOlmaz := Sorgu.FieldByName('BOS_OLMAZ').AsInteger = 1;
        Param.Varsayilan := VarsayilanMetni(Sorgu.FieldByName('VARSAYILAN').AsString);
      end;
      Liste.Add(Param);
      Sorgu.Next;
    end;
    Result := Liste.ToArray;
  finally
    Sorgu.Free;
    Liste.Free;
  end;
end;

function ProsedurBilgisiOku(Bag: TAcikBaglanti; const Ad: string): TProsedurBilgisi;
var
  PaketSarti: string;
begin
  PaketSarti := '';
  if SurumNo(Bag) >= 3 then
    PaketSarti := ' and rdb$package_name is null';
  NesneVarMi(Bag, 'select rdb$procedure_name from rdb$procedures where rdb$procedure_name = :N' + PaketSarti, Ad);
  Result.Kaynak := TekDeger(Bag, 'select rdb$procedure_source from rdb$procedures ' +
    'where rdb$procedure_name = :N' + PaketSarti, Ad);
  if Result.Kaynak = '' then
    raise EMetadataHatasi.Create(TF('ERR_DDL_KAYNAK_YOK', [Ad]));
  Result.Girdiler := ParametreleriOku(Bag, Ad, True);
  Result.Ciktilar := ParametreleriOku(Bag, Ad, False);
end;

function GeneratorBilgisiOku(Bag: TAcikBaglanti; const Ad: string): TGeneratorBilgisi;
begin
  NesneVarMi(Bag, 'select rdb$generator_name from rdb$generators where rdb$generator_name = :N', Ad);
  Result.Deger := StrToInt64Def(TekDeger(Bag, 'select gen_id(' + HamTirnak(Ad) + ', 0) from rdb$database', ''), 0);
  Result.Artis := 1;
  if SurumNo(Bag) >= 3 then
    Result.Artis := StrToInt64Def(TekDeger(Bag, 'select rdb$generator_increment from rdb$generators ' +
      'where rdb$generator_name = :N', Ad), 1);
end;

{ Satir basina bir kelime. '#FB3' gibi baslik, sonraki kelimelerin o surumde ve sonrasinda
  gecerli oldugunu gosterir; diger '#' satirlari yorumdur. }
procedure AnahtarKelimeleriOku(const Dosya, Surum: string; Hedef: TStrings);
var
  Satirlar: TStringList;
  Satir: string;
  Sunucu, Bolum: Integer;
begin
  Hedef.Clear;
  if not FileExists(Dosya) then
    Exit;
  Sunucu := StrToIntDef(Copy(Surum, 1, Pos('.', Surum) - 1), 99);
  Bolum := 0;
  Satirlar := TStringList.Create;
  try
    Satirlar.LoadFromFile(Dosya, TEncoding.UTF8);
    for Satir in Satirlar do
    begin
      if (Length(Trim(Satir)) = 4) and (Copy(Trim(Satir), 1, 3) = '#FB') then
        Bolum := StrToIntDef(Copy(Trim(Satir), 4, 1), Bolum)
      else if (Trim(Satir) <> '') and (Trim(Satir)[1] <> '#') and (Bolum <= Sunucu) then
        Hedef.Add(Trim(Satir));
    end;
  finally
    Satirlar.Free;
  end;
end;

{ ---------- Tum veritabani icin okuma (Metadata cikar) ---------- }

function VeritabaniSayfaBoyutu(Bag: TAcikBaglanti): Integer;
begin
  Result := StrToIntDef(TekDeger(Bag, 'select mon$page_size from mon$database', ''), 0);
end;

function VeritabaniVarsayilanKarakterSeti(Bag: TAcikBaglanti): string;
begin
  Result := VeritabaniKarakterSeti(Bag);
  if Result = 'NONE' then
    Result := '';
end;

function RolAdlari(Bag: TAcikBaglanti): TArray<string>;
begin
  Result := SutunListesi(Bag, 'select rdb$role_name from rdb$roles where coalesce(rdb$system_flag, 0) = 0 ' +
    'order by rdb$role_name', '');
end;

function IstisnalariOku(Bag: TAcikBaglanti): TArray<TIstisnaBilgisi>;
var
  Sorgu: TFDQuery;
  Liste: TList<TIstisnaBilgisi>;
  Istisna: TIstisnaBilgisi;
begin
  Liste := TList<TIstisnaBilgisi>.Create;
  Sorgu := SorguAc(Bag, 'select rdb$exception_name as AD, rdb$message as MESAJ from rdb$exceptions ' +
    'where coalesce(rdb$system_flag, 0) = 0 order by rdb$exception_name', '');
  try
    while not Sorgu.Eof do
    begin
      Istisna.Ad := Trim(Sorgu.FieldByName('AD').AsString);
      Istisna.Mesaj := Sorgu.FieldByName('MESAJ').AsString;
      Liste.Add(Istisna);
      Sorgu.Next;
    end;
    Result := Liste.ToArray;
  finally
    Sorgu.Free;
    Liste.Free;
  end;
end;

function GeneratorAdlari(Bag: TAcikBaglanti): TArray<string>;
begin
  Result := SutunListesi(Bag, 'select rdb$generator_name from rdb$generators ' +
    'where coalesce(rdb$system_flag, 0) = 0 order by rdb$generator_name', '');
end;

function DomainleriOku(Bag: TAcikBaglanti): TArray<TDomainBilgisi>;
var
  Sorgu: TFDQuery;
  Liste: TList<TDomainBilgisi>;
  Alan: TDomainBilgisi;
  VarsayilanCS: string;
begin
  VarsayilanCS := VeritabaniKarakterSeti(Bag);
  Liste := TList<TDomainBilgisi>.Create;
  Sorgu := SorguAc(Bag, 'select f.rdb$field_name as AD, f.rdb$null_flag as BOS_OLMAZ, ' +
    'f.rdb$default_source as VARSAYILAN, f.rdb$validation_source as KONTROL, ' +
    'f.rdb$field_type as TIP, f.rdb$field_sub_type as ALT_TIP, f.rdb$field_length as UZUNLUK, ' +
    'f.rdb$field_scale as OLCEK, f.rdb$field_precision as HASSASIYET, f.rdb$character_length as KARAKTER_UZ, ' +
    'f.rdb$segment_length as BLOB_PARCA, f.rdb$collation_id as F_COLL, ' +
    'cs.rdb$character_set_name as CS_ADI, co.rdb$collation_name as COLL_ADI ' +
    'from rdb$fields f ' +
    'left join rdb$character_sets cs on cs.rdb$character_set_id = f.rdb$character_set_id ' +
    'left join rdb$collations co on co.rdb$character_set_id = f.rdb$character_set_id ' +
    'and co.rdb$collation_id = f.rdb$collation_id ' +
    'where f.rdb$field_name not starting with ''RDB$'' and coalesce(f.rdb$system_flag, 0) = 0 ' +
    'order by f.rdb$field_name', '');
  try
    while not Sorgu.Eof do
    begin
      Alan := Default(TDomainBilgisi);
      Alan.Ad := Trim(Sorgu.FieldByName('AD').AsString);
      Alan.Tip := TipMetniUret(Sorgu, VarsayilanCS, Bag.Dialect);
      Alan.Varsayilan := VarsayilanMetni(Sorgu.FieldByName('VARSAYILAN').AsString);
      Alan.BosOlmaz := Sorgu.FieldByName('BOS_OLMAZ').AsInteger = 1;
      Alan.Kontrol := Trim(Sorgu.FieldByName('KONTROL').AsString);
      if (Alan.Kontrol <> '') and not StartsText('CHECK', Alan.Kontrol) then
        Alan.Kontrol := 'CHECK ' + Alan.Kontrol;
      if Sorgu.FieldByName('F_COLL').AsInteger > 0 then
        Alan.Collate := Trim(Sorgu.FieldByName('COLL_ADI').AsString);
      Liste.Add(Alan);
      Sorgu.Next;
    end;
    Result := Liste.ToArray;
  finally
    Sorgu.Free;
    Liste.Free;
  end;
end;

function DomainBilgisiOku(Bag: TAcikBaglanti; const Ad: string): TDomainBilgisi;
var
  Alan: TDomainBilgisi;
begin
  for Alan in DomainleriOku(Bag) do
    if Alan.Ad = Ad then
      Exit(Alan);
  raise EMetadataHatasi.Create(TF('ERR_DDL_NESNE_YOK', [Ad]));
end;

function IstisnaBilgisiOku(Bag: TAcikBaglanti; const Ad: string): TIstisnaBilgisi;
var
  Istisna: TIstisnaBilgisi;
begin
  for Istisna in IstisnalariOku(Bag) do
    if Istisna.Ad = Ad then
      Exit(Istisna);
  raise EMetadataHatasi.Create(TF('ERR_DDL_NESNE_YOK', [Ad]));
end;

function BagimliNesneler(Bag: TAcikBaglanti; Hedef: TBagimlilikHedefi; const Ad: string): TArray<TBagimlilik>;
var
  Sorgu: TFDQuery;
  Liste: TList<TBagimlilik>;
  Satir: TBagimlilik;
  TurSarti: string;
begin
  { RDB$DEPENDED_ON_TYPE: 0 tablo, 1 view, 7 exception, 9 domain, 14 generator (olculdu, 2.5.9 ve 4.0.7). }
  case Hedef of
    bhView: TurSarti := 'in (0, 1)';
    bhIstisna: TurSarti := '= 7';
    bhDomain: TurSarti := '= 9';
  else
    TurSarti := '= 14';
  end;
  Liste := TList<TBagimlilik>.Create;
  try
    Sorgu := SorguAc(Bag, 'select distinct rdb$dependent_name, rdb$dependent_type from rdb$dependencies ' +
      'where rdb$depended_on_name = :N and rdb$depended_on_type ' + TurSarti +
      ' and rdb$dependent_name <> rdb$depended_on_name order by 2, 1', Ad);
    try
      while not Sorgu.Eof do
      begin
        Satir.Ad := Trim(Sorgu.Fields[0].AsString);
        Satir.Tur := Sorgu.Fields[1].AsInteger;
        Liste.Add(Satir);
        Sorgu.Next;
      end;
    finally
      Sorgu.Free;
    end;
    { Domain'i kullanan tablo kolonlari RDB$DEPENDENCIES'te degil, RDB$RELATION_FIELDS'tedir. }
    if Hedef = bhDomain then
    begin
      Sorgu := SorguAc(Bag, 'select trim(rdb$relation_name) || ''.'' || trim(rdb$field_name) from rdb$relation_fields ' +
        'where rdb$field_source = :N order by 1', Ad);
      try
        while not Sorgu.Eof do
        begin
          Satir.Ad := Trim(Sorgu.Fields[0].AsString);
          Satir.Tur := BAG_KOLON;
          Liste.Add(Satir);
          Sorgu.Next;
        end;
      finally
        Sorgu.Free;
      end;
    end;
    Result := Liste.ToArray;
  finally
    Liste.Free;
  end;
end;

function TabloAdlari(Bag: TAcikBaglanti): TArray<string>;
begin
  Result := SutunListesi(Bag, 'select rdb$relation_name from rdb$relations ' +
    'where rdb$view_blr is null and coalesce(rdb$system_flag, 0) = 0 order by rdb$relation_name', '');
end;

function ProsedurAdlari(Bag: TAcikBaglanti): TArray<string>;
var
  PaketSarti: string;
begin
  PaketSarti := '';
  if SurumNo(Bag) >= 3 then
    PaketSarti := ' and rdb$package_name is null';
  Result := SutunListesi(Bag, 'select rdb$procedure_name from rdb$procedures ' +
    'where coalesce(rdb$system_flag, 0) = 0' + PaketSarti + ' order by rdb$procedure_name', '');
end;

function ViewAdlariSirali(Bag: TAcikBaglanti; out Dongu: TArray<string>): TArray<string>;
var
  Adlar: TArray<string>;
  Bagimlilar: TDictionary<string, TList<string>>;
  Bitenler: TDictionary<string, Boolean>;
  Kalan, Sirali, Sonraki: TList<string>;
  Sorgu: TFDQuery;
  Ad, Bagimli, Hedef: string;
  Hazir, Ilerledi: Boolean;
begin
  Adlar := SutunListesi(Bag, 'select rdb$relation_name from rdb$relations ' +
    'where rdb$view_blr is not null and coalesce(rdb$system_flag, 0) = 0 order by rdb$relation_name', '');
  Bagimlilar := TObjectDictionary<string, TList<string>>.Create([doOwnsValues]);
  Bitenler := TDictionary<string, Boolean>.Create;
  Kalan := TList<string>.Create;
  Sirali := TList<string>.Create;
  Sonraki := TList<string>.Create;
  try
    for Ad in Adlar do
    begin
      Bagimlilar.Add(Ad, TList<string>.Create);
      Kalan.Add(Ad);
    end;
    { Sadece view'in baska bir VIEW'a bagimliligi onemli; tablo ve prosedurler once kurulur. }
    Sorgu := SorguAc(Bag, 'select distinct rdb$dependent_name as AD, rdb$depended_on_name as HEDEF ' +
      'from rdb$dependencies where rdb$dependent_type = 1 and rdb$depended_on_type in (0, 1)', '');
    try
      while not Sorgu.Eof do
      begin
        Ad := Trim(Sorgu.FieldByName('AD').AsString);
        Hedef := Trim(Sorgu.FieldByName('HEDEF').AsString);
        if Bagimlilar.ContainsKey(Ad) and Bagimlilar.ContainsKey(Hedef) and (Ad <> Hedef) then
          Bagimlilar[Ad].Add(Hedef);
        Sorgu.Next;
      end;
    finally
      Sorgu.Free;
    end;
    repeat
      Ilerledi := False;
      Sonraki.Clear;
      for Ad in Kalan do
      begin
        Hazir := True;
        for Bagimli in Bagimlilar[Ad] do
          if not Bitenler.ContainsKey(Bagimli) then
            Hazir := False;
        if Hazir then
        begin
          Sirali.Add(Ad);
          Bitenler.Add(Ad, True);
          Ilerledi := True;
        end
        else
          Sonraki.Add(Ad);
      end;
      Kalan.Clear;
      Kalan.AddRange(Sonraki);
    until (not Ilerledi) or (Kalan.Count = 0);
    Dongu := Kalan.ToArray;
    Sirali.AddRange(Kalan);
    Result := Sirali.ToArray;
  finally
    Sonraki.Free;
    Sirali.Free;
    Kalan.Free;
    Bitenler.Free;
    Bagimlilar.Free;
  end;
end;

function YetkileriOku(Bag: TAcikBaglanti): TArray<TYetkiBilgisi>;
var
  Sorgu: TFDQuery;
  Liste: TList<TYetkiBilgisi>;
  Yetki: TYetkiBilgisi;
begin
  Liste := TList<TYetkiBilgisi>.Create;
  { Nesne sahibinin kendi (otomatik) yetkileri (kullanici = veren) ve sistem nesneleri atlanir. }
  Sorgu := SorguAc(Bag, 'select rdb$user as KULLANICI, rdb$user_type as KULLANICI_TURU, rdb$privilege as YETKI, ' +
    'rdb$grant_option as SECENEK, rdb$relation_name as NESNE, rdb$object_type as NESNE_TURU, rdb$field_name as ALAN ' +
    'from rdb$user_privileges ' +
    'where rdb$grantor is not null and rdb$user <> rdb$grantor and rdb$object_type in (0, 5, 7, 13, 14) ' +
    'and rdb$relation_name not starting with ''RDB$'' and rdb$relation_name not starting with ''MON$'' ' +
    'and rdb$relation_name not starting with ''SEC$'' ' +
    'order by rdb$relation_name, rdb$object_type, rdb$user_type, rdb$user, rdb$grant_option, ' +
    'rdb$privilege, rdb$field_name', '');
  try
    while not Sorgu.Eof do
    begin
      Yetki.Kullanici := Trim(Sorgu.FieldByName('KULLANICI').AsString);
      Yetki.KullaniciTuru := Sorgu.FieldByName('KULLANICI_TURU').AsInteger;
      Yetki.Yetki := Trim(Sorgu.FieldByName('YETKI').AsString);
      Yetki.SecenekVar := Sorgu.FieldByName('SECENEK').AsInteger;
      Yetki.Nesne := Trim(Sorgu.FieldByName('NESNE').AsString);
      Yetki.NesneTuru := Sorgu.FieldByName('NESNE_TURU').AsInteger;
      Yetki.Alan := Trim(Sorgu.FieldByName('ALAN').AsString);
      Liste.Add(Yetki);
      Sorgu.Next;
    end;
    Result := Liste.ToArray;
  finally
    Sorgu.Free;
    Liste.Free;
  end;
end;

function DesteklenmeyenNesneSayisi(Bag: TAcikBaglanti): Integer;
begin
  Result := StrToIntDef(TekDeger(Bag, 'select count(*) from rdb$functions where coalesce(rdb$system_flag, 0) = 0', ''), 0) +
    StrToIntDef(TekDeger(Bag, 'select count(*) from rdb$filters', ''), 0) +
    StrToIntDef(TekDeger(Bag, 'select count(*) from rdb$collations where coalesce(rdb$system_flag, 0) = 0', ''), 0);
  if SurumNo(Bag) >= 3 then
    Result := Result + StrToIntDef(TekDeger(Bag, 'select count(*) from rdb$packages where coalesce(rdb$system_flag, 0) = 0', ''), 0);
end;

function AciklamalariOku(Bag: TAcikBaglanti): TArray<TAciklamaBilgisi>;
var
  Liste: TList<TAciklamaBilgisi>;

  { Sorgu AD1 (ve varsa AD2) ile METIN alanlarini vermeli. }
  procedure Topla(const Tur, Sql: string);
  var
    Sorgu: TFDQuery;
    Kayit: TAciklamaBilgisi;
  begin
    Sorgu := SorguAc(Bag, Sql, '');
    try
      while not Sorgu.Eof do
      begin
        Kayit := Default(TAciklamaBilgisi);
        Kayit.Tur := Tur;
        if Sorgu.FindField('AD1') <> nil then
          Kayit.Ad1 := Trim(Sorgu.FieldByName('AD1').AsString);
        if Sorgu.FindField('AD2') <> nil then
          Kayit.Ad2 := Trim(Sorgu.FieldByName('AD2').AsString);
        Kayit.Metin := Sorgu.FieldByName('METIN').AsString;
        if Kayit.Metin <> '' then
          Liste.Add(Kayit);
        Sorgu.Next;
      end;
    finally
      Sorgu.Free;
    end;
  end;

var
  PaketSarti, GeneratorTuru: string;
begin
  PaketSarti := '';
  GeneratorTuru := 'GENERATOR';
  if SurumNo(Bag) >= 3 then
  begin
    PaketSarti := ' and rdb$package_name is null';
    GeneratorTuru := 'SEQUENCE';
  end;
  Liste := TList<TAciklamaBilgisi>.Create;
  try
    Topla('DATABASE', 'select rdb$description as METIN from rdb$database where rdb$description is not null');
    Topla('ROLE', 'select rdb$role_name as AD1, rdb$description as METIN from rdb$roles ' +
      'where coalesce(rdb$system_flag, 0) = 0 and rdb$description is not null order by 1');
    Topla('EXCEPTION', 'select rdb$exception_name as AD1, rdb$description as METIN from rdb$exceptions ' +
      'where coalesce(rdb$system_flag, 0) = 0 and rdb$description is not null order by 1');
    Topla(GeneratorTuru, 'select rdb$generator_name as AD1, rdb$description as METIN from rdb$generators ' +
      'where coalesce(rdb$system_flag, 0) = 0 and rdb$description is not null order by 1');
    Topla('DOMAIN', 'select rdb$field_name as AD1, rdb$description as METIN from rdb$fields ' +
      'where rdb$field_name not starting with ''RDB$'' and coalesce(rdb$system_flag, 0) = 0 ' +
      'and rdb$description is not null order by 1');
    Topla('TABLE', 'select rdb$relation_name as AD1, rdb$description as METIN from rdb$relations ' +
      'where rdb$view_blr is null and coalesce(rdb$system_flag, 0) = 0 and rdb$description is not null order by 1');
    Topla('VIEW', 'select rdb$relation_name as AD1, rdb$description as METIN from rdb$relations ' +
      'where rdb$view_blr is not null and coalesce(rdb$system_flag, 0) = 0 and rdb$description is not null order by 1');
    Topla('COLUMN', 'select rf.rdb$relation_name as AD1, rf.rdb$field_name as AD2, rf.rdb$description as METIN ' +
      'from rdb$relation_fields rf join rdb$relations r on r.rdb$relation_name = rf.rdb$relation_name ' +
      'where coalesce(r.rdb$system_flag, 0) = 0 and rf.rdb$description is not null ' +
      'order by rf.rdb$relation_name, rf.rdb$field_position');
    Topla('INDEX', 'select rdb$index_name as AD1, rdb$description as METIN from rdb$indices ' +
      'where rdb$index_name not starting with ''RDB$'' and coalesce(rdb$system_flag, 0) = 0 ' +
      'and rdb$description is not null order by 1');
    Topla('PROCEDURE', 'select rdb$procedure_name as AD1, rdb$description as METIN from rdb$procedures ' +
      'where coalesce(rdb$system_flag, 0) = 0' + PaketSarti + ' and rdb$description is not null order by 1');
    Topla('PROCEDURE PARAMETER', 'select rdb$procedure_name as AD1, rdb$parameter_name as AD2, rdb$description as METIN ' +
      'from rdb$procedure_parameters where rdb$description is not null' + PaketSarti +
      ' order by rdb$procedure_name, rdb$parameter_type, rdb$parameter_number');
    Topla('TRIGGER', 'select rdb$trigger_name as AD1, rdb$description as METIN from rdb$triggers ' +
      'where coalesce(rdb$system_flag, 0) = 0 and rdb$description is not null order by 1');
    Result := Liste.ToArray;
  finally
    Liste.Free;
  end;
end;

{ ---------- Sunucu kullanicilari (salt okuma) ---------- }

function KullaniciYetenekleri(Bag: TAcikBaglanti): TKullaniciYetenekleri;
begin
  Result.YonetimVar := Bag.Tanim.Sunucu <> '';
  Result.ListeSql := SurumNo(Bag) >= 3;
  Result.YoneticiOkunur := Result.ListeSql;
  Result.YoneticiAyarlanir := Result.ListeSql;
  Result.AktifPasif := Result.ListeSql;
  if Result.ListeSql then
    Result.KendiSifreKomutu := skAlterCurrentUser
  else
    Result.KendiSifreKomutu := skAlterUser;
end;

{ 3.0 ve ustu: SEC$USERS. Yonetici olmayan kullanici yalniz kendi satirini gorur. }
function KullanicilariSqlOku(Bag: TAcikBaglanti): TArray<TKullaniciBilgisi>;
var
  Sorgu: TFDQuery;
  Liste: TList<TKullaniciBilgisi>;
  Kullanici: TKullaniciBilgisi;
begin
  Liste := TList<TKullaniciBilgisi>.Create;
  Sorgu := SorguAc(Bag, 'select SEC$USER_NAME, SEC$FIRST_NAME, SEC$MIDDLE_NAME, SEC$LAST_NAME, SEC$ACTIVE, SEC$ADMIN ' +
    'from SEC$USERS order by SEC$USER_NAME', '');
  try
    while not Sorgu.Eof do
    begin
      Kullanici.Ad := Trim(Sorgu.FieldByName('SEC$USER_NAME').AsString);
      Kullanici.Isim := Trim(Sorgu.FieldByName('SEC$FIRST_NAME').AsString);
      Kullanici.OrtaAd := Trim(Sorgu.FieldByName('SEC$MIDDLE_NAME').AsString);
      Kullanici.Soyad := Trim(Sorgu.FieldByName('SEC$LAST_NAME').AsString);
      Kullanici.Aktif := Sorgu.FieldByName('SEC$ACTIVE').AsBoolean;
      Kullanici.Yonetici := Sorgu.FieldByName('SEC$ADMIN').AsBoolean;
      Kullanici.BilgiVar := True;
      Liste.Add(Kullanici);
      Sorgu.Next;
    end;
    Result := Liste.ToArray;
  finally
    Sorgu.Free;
    Liste.Free;
  end;
end;

{ 2.5: SQL ile listeleme yok, yalniz Services API (gsec'in yolu). Ayni surucu baglantisi kullanilir. }
function KullanicilariServisOku(Bag: TAcikBaglanti): TArray<TKullaniciBilgisi>;
var
  Guvenlik: TFDIBSecurity;
  Liste: TList<TKullaniciBilgisi>;
  Kullanici: TKullaniciBilgisi;
  I: Integer;
begin
  Liste := TList<TKullaniciBilgisi>.Create;
  Guvenlik := TFDIBSecurity.Create(nil);
  try
    Guvenlik.DriverLink := FbSurucu;
    Guvenlik.Protocol := ipTCPIP;
    Guvenlik.Host := Bag.Tanim.Sunucu;
    Guvenlik.Port := Bag.Tanim.Port;
    Guvenlik.UserName := Bag.Tanim.Kullanici;
    Guvenlik.Password := Bag.Tanim.Sifre;
    Guvenlik.DisplayUsers;
    { Kolonlar (olcum): 0 kullanici, 2 ad, 3 orta ad, 4 soyad }
    for I := 0 to Guvenlik.Users.Rows.Count - 1 do
    begin
      Kullanici := Default(TKullaniciBilgisi);
      Kullanici.Ad := Trim(VarToStr(Guvenlik.Users.Rows[I].GetData(0)));
      Kullanici.Isim := Trim(VarToStr(Guvenlik.Users.Rows[I].GetData(2)));
      Kullanici.OrtaAd := Trim(VarToStr(Guvenlik.Users.Rows[I].GetData(3)));
      Kullanici.Soyad := Trim(VarToStr(Guvenlik.Users.Rows[I].GetData(4)));
      Liste.Add(Kullanici);
    end;
    Result := Liste.ToArray;
  finally
    Guvenlik.Free;
    Liste.Free;
  end;
end;

function KullaniciListesiOku(Bag: TAcikBaglanti): TArray<TKullaniciBilgisi>;
begin
  if Bag.Tanim.Sunucu = '' then
    raise EMetadataHatasi.Create(T('ERR_KULLANICI_GOMULU'));
  if KullaniciYetenekleri(Bag).ListeSql then
    Result := KullanicilariSqlOku(Bag)
  else
    Result := KullanicilariServisOku(Bag);
end;

end.