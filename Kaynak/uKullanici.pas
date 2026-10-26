{ uKullanici.pas - Sunucu kullanicilarini yonetme (yazma): ekle, sil, sifre, ad/soyad, yonetici, aktif/pasif.

  Hedeflenen Firebird surumleri: 2.5, 3.0, 4.0, 5.0
  Denenen Firebird surumleri: 2.5.9, 3.0.14, 4.0.7, 5.0.4 yalniz OKUMA olcumu yapildi (bkz. ASAMA3D_OLCUM_RAPORU.md).
  Yazma (bu unit) henuz yalniz gomulu kipte "yonetim yok" davranisi icin denendi; sunucu testi sahibi tarafindan yapilacak.

  Kullanicilar veritabanina degil sunucuya aittir. Hepsi SQL ile yapilir (CREATE/ALTER/DROP USER); 2.5 dahil.
  Services API (TFDIBSecurity) yalniz 2.5 LISTELEME icin kullanilir ve uMetadata'dadir; yazmada kullanilmaz.
  Liste okuma ve surum yetenekleri uMetadata'dadir, bu unit sadece yazar.

  Kurallar (arayuz atlatilsa bile gecerli):
    - Kullanici adi: yalniz A-Z a-z 0-9 _ $, en cok 31 karakter, buyuk harfe cevrilir.
    - SYSDBA yalniz sifresi degistirilebilir (silinemez, pasif yapilamaz, yonetici/ad degistirilemez).
    - Baglanti kullanicisi kendini silemez veya pasif yapamaz.
    - Sifre hicbir zaman log'a, hata metnine veya onizlemeye duz yazilmaz (***).
    - Gomulu baglantida kullanici yonetimi yoktur. }
unit uKullanici;

interface

uses
  System.SysUtils, System.Classes, Data.DB,
  FireDAC.Stan.Intf, FireDAC.Stan.Option, FireDAC.Comp.Client,
  uDil, uBaglanti, uMetadata;

type
  { Kural ihlali (SYSDBA, gecersiz ad, sifre bos vb.): mesaj kullaniciya oldugu gibi gosterilir. }
  EKullaniciKurali = class(Exception);
  { Kullanici eklendi ama yonetici yapilamadi: kullanici var, pencere kapanip liste yenilenmeli. }
  EKullaniciYarim = class(Exception);

const
  SYSDBA_ADI = 'SYSDBA';
  KULLANICI_AD_EN_UZUN = 31;
  ISIM_EN_UZUN = 32;

{ Kural kontrolleri }
function KullaniciAdiniDogrula(const Ad: string): string;
function SysdbaMi(const Ad: string): Boolean;
function KendiKullanicisiMi(Bag: TAcikBaglanti; const Ad: string): Boolean;
{ Sifre cok uzunsa (Firebird sifrenin yalniz bir kismini kullanir) uyari metni, degilse bos. Engellemez. }
function SifreUyarisi(Bag: TAcikBaglanti; const Sifre: string): string;

{ Komut metinleri. Gizle = True ise sifre yerine *** yazilir (onizleme/log icin). }
function EkleKomutu(const Ad, Sifre, Isim, Soyad: string; Gizle: Boolean): string;
function SifreKomutu(Bag: TAcikBaglanti; const Ad, Sifre: string; Gizle: Boolean): string;
{ Metni SQL dizgesi icinde guvenle tasir: ' isareti iki katina cikar (tek yer). }
function SqlMetni(const Metin: string): string;
{ Komutu calistirmak icin hazirlanmis sorgu: ':ad', '&makro', '!makro' ve suslu parantez kacislari yorumlanmaz. Sahibi cagiran. }
function KomutHazirla(Bag: TAcikBaglanti; const Sql: string): TFDQuery;

{ Yazma islemleri. Hata verirse istisna firlatir; sifre hata metninde *** olur. }
procedure KullaniciEkle(Bag: TAcikBaglanti; const Ad, Sifre, SifreTekrar, Isim, Soyad: string; Yonetici: Boolean);
procedure KullaniciSil(Bag: TAcikBaglanti; const Ad: string);
procedure SifreDegistir(Bag: TAcikBaglanti; const Ad, Sifre, SifreTekrar: string);
procedure AdSoyadDegistir(Bag: TAcikBaglanti; const Ad, Isim, Soyad: string);
procedure YoneticiAyarla(Bag: TAcikBaglanti; const Ad: string; Yonetici: Boolean);
procedure AktifAyarla(Bag: TAcikBaglanti; const Ad: string; Aktif: Boolean);

{ Kayitli baglanti sifresi: baglantinin kendi kullanicisinin sifresi degistirildiyse guncellenebilir. }
function KayitliSifreSaklaniyorMu(Bag: TAcikBaglanti): Boolean;
procedure KayitliSifreyiGuncelle(Bag: TAcikBaglanti; const YeniSifre: string);

{ Izgara icin bellek tablosu. Dil degisince veya yenilenince ayni listeyle tekrar doldurulabilir. }
function KullaniciTablosuOlustur(Sahip: TComponent): TFDMemTable;
procedure KullaniciTablosunuDoldur(Tablo: TFDMemTable; const Liste: TArray<TKullaniciBilgisi>;
  const Yetenek: TKullaniciYetenekleri);

implementation

{ ---------- Kural kontrolleri ---------- }

function SysdbaMi(const Ad: string): Boolean;
begin
  Result := SameText(Trim(Ad), SYSDBA_ADI);
end;

function KendiKullanicisiMi(Bag: TAcikBaglanti; const Ad: string): Boolean;
begin
  Result := SameText(Trim(Ad), Trim(Bag.Tanim.Kullanici));
end;

function KullaniciAdiniDogrula(const Ad: string): string;
var
  Harf: Char;
begin
  Result := UpperCase(Trim(Ad));
  if Result = '' then
    raise EKullaniciKurali.Create(T('ERR_KULLANICI_AD_BOS'));
  if Length(Result) > KULLANICI_AD_EN_UZUN then
    raise EKullaniciKurali.Create(T('ERR_KULLANICI_AD_GECERSIZ'));
  for Harf in Result do
    if not CharInSet(Harf, ['A'..'Z', '0'..'9', '_', '$']) then
      raise EKullaniciKurali.Create(T('ERR_KULLANICI_AD_GECERSIZ'));
end;

procedure YonetimVarMi(Bag: TAcikBaglanti);
begin
  if not KullaniciYetenekleri(Bag).YonetimVar then
    raise EKullaniciKurali.Create(T('ERR_KULLANICI_GOMULU'));
end;

procedure SifreyiDogrula(const Sifre, SifreTekrar: string);
var
  Harf: Char;
begin
  if Sifre = '' then
    raise EKullaniciKurali.Create(T('ERR_SIFRE_BOS'));
  if Sifre <> SifreTekrar then
    raise EKullaniciKurali.Create(T('ERR_SIFRE_FARKLI'));
  { Olcum (3.0.14, 4.0.7): Turkce harfli sifre ayarlanir ama o sifreyle baglanilamaz (karakter seti uyumsuzlugu).
    En sade cozum: ASCII disi karakter reddedilir. }
  for Harf in Sifre do
    if Ord(Harf) > 127 then
      raise EKullaniciKurali.Create(T('ERR_SIFRE_ASCII'));
end;

procedure IsimiDogrula(Bag: TAcikBaglanti; const Isim, Soyad: string);
var
  Harf: Char;
begin
  { Olcum (2.5.9): Turkce harfli ad/soyad 2.5'te Services listesinde farkli gorunuyor (karakter seti uyumsuzlugu;
    yazma mi okuma mi tarafinda oldugu sunucu sifresi olmadan ayrilamadi). En sade cozum: 2.5'te ASCII disi reddedilir. }
  if not KullaniciYetenekleri(Bag).ListeSql then
    for Harf in Isim + Soyad do
      if Ord(Harf) > 127 then
        raise EKullaniciKurali.Create(T('ERR_ISIM_ASCII_ESKI'));
  if (Length(Isim) > ISIM_EN_UZUN) or (Length(Soyad) > ISIM_EN_UZUN) then
    raise EKullaniciKurali.Create(TF('ERR_KULLANICI_ISIM_UZUN', [ISIM_EN_UZUN]));
end;

function SifreUyarisi(Bag: TAcikBaglanti; const Sifre: string): string;
var
  Sinir: Integer;
begin
  { 3.0 ve ustu (Srp): ilk 20 bayt; 2.5 (Legacy_Auth): ilk 8 karakter }
  if KullaniciYetenekleri(Bag).ListeSql then
    Sinir := 20
  else
    Sinir := 8;
  if TEncoding.UTF8.GetByteCount(Sifre) > Sinir then
    Result := TF('UYARI_SIFRE_UZUN', [Sinir])
  else
    Result := '';
end;

{ ---------- Komut metinleri ---------- }

function SqlMetni(const Metin: string): string;
begin
  Result := '''' + StringReplace(Metin, '''', '''''', [rfReplaceAll]) + '''';
end;

function SifreMetni(const Sifre: string; Gizle: Boolean): string;
begin
  if Gizle then
    Result := '''***'''
  else
    Result := SqlMetni(Sifre);
end;

function EkleKomutu(const Ad, Sifre, Isim, Soyad: string; Gizle: Boolean): string;
begin
  Result := 'CREATE USER ' + Ad + ' PASSWORD ' + SifreMetni(Sifre, Gizle);
  if Isim <> '' then
    Result := Result + ' FIRSTNAME ' + SqlMetni(Isim);
  if Soyad <> '' then
    Result := Result + ' LASTNAME ' + SqlMetni(Soyad);
end;

function SifreKomutu(Bag: TAcikBaglanti; const Ad, Sifre: string; Gizle: Boolean): string;
begin
  if KendiKullanicisiMi(Bag, Ad) and (KullaniciYetenekleri(Bag).KendiSifreKomutu = skAlterCurrentUser) then
    Result := 'ALTER CURRENT USER SET PASSWORD ' + SifreMetni(Sifre, Gizle)
  else
    Result := 'ALTER USER ' + Ad + ' PASSWORD ' + SifreMetni(Sifre, Gizle);
end;

{ Sorgunun SQL metni oldugu gibi gitsin: parametre/makro olusturma ve suslu parantez kacislari kapali. }
function KomutHazirla(Bag: TAcikBaglanti; const Sql: string): TFDQuery;
begin
  Result := TFDQuery.Create(nil);
  try
    Result.Connection := Bag.Baglanti;
    Result.ResourceOptions.ParamCreate := False;
    Result.ResourceOptions.MacroCreate := False;
    Result.ResourceOptions.ParamExpand := False;
    Result.ResourceOptions.MacroExpand := False;
    Result.ResourceOptions.EscapeExpand := False;
    Result.SQL.Text := Sql;
  except
    Result.Free;
    raise;
  end;
end;

{ Komutu calistirir. Hata metninde sifre geciyorsa *** ile degistirilir (hata sinifi ve kodu korunur). }
procedure Calistir(Bag: TAcikBaglanti; const Sql, Sifre: string);
var
  Komut: TFDQuery;
begin
  Komut := KomutHazirla(Bag, Sql);
  try
    try
      Komut.ExecSQL;
    except
      on E: Exception do
      begin
        if Sifre <> '' then
          E.Message := StringReplace(E.Message, Sifre, '***', [rfReplaceAll]);
        raise;
      end;
    end;
  finally
    Komut.Free;
  end;
end;

{ Listeyi okuyabiliyorsak kullanici var mi diye bakar; okuyamazsak (yetki yok vb.) "bilinmiyor" sayilir,
  sunucu kendi hatasini verir. }
function KullaniciVarMi(Bag: TAcikBaglanti; const Ad: string): Boolean;
var
  Liste: TArray<TKullaniciBilgisi>;
  Kullanici: TKullaniciBilgisi;
begin
  Result := False;
  try
    Liste := KullaniciListesiOku(Bag);
  except
    Exit;
  end;
  for Kullanici in Liste do
    if SameText(Kullanici.Ad, Ad) then
      Exit(True);
end;

{ ---------- Yazma islemleri ---------- }

procedure KullaniciEkle(Bag: TAcikBaglanti; const Ad, Sifre, SifreTekrar, Isim, Soyad: string; Yonetici: Boolean);
var
  Kullanici: string;
begin
  YonetimVarMi(Bag);
  Kullanici := KullaniciAdiniDogrula(Ad);
  SifreyiDogrula(Sifre, SifreTekrar);
  IsimiDogrula(Bag, Trim(Isim), Trim(Soyad));
  if Yonetici and not KullaniciYetenekleri(Bag).YoneticiAyarlanir then
    raise EKullaniciKurali.Create(T('ERR_KULLANICI_OZELLIK_YOK'));
  if KullaniciVarMi(Bag, Kullanici) then
    raise EKullaniciKurali.Create(TF('ERR_KULLANICI_VAR', [Kullanici]));
  Calistir(Bag, EkleKomutu(Kullanici, Sifre, Trim(Isim), Trim(Soyad), False), Sifre);
  { Yonetici yetkisi ayri komutla verilir (olcumde dogrulanan yol); basarisiz olursa kullanici yine de eklenmistir. }
  if Yonetici then
    try
      Calistir(Bag, 'ALTER USER ' + Kullanici + ' GRANT ADMIN ROLE', '');
    except
      on E: Exception do
        raise EKullaniciYarim.Create(TF('ERR_KULLANICI_YONETICI_OLMADI', [Kullanici, HataMetniniCevir(E)]) +
          #13#10 + T('AYRINTI') + ': ' + E.Message);
    end;
end;

procedure KullaniciSil(Bag: TAcikBaglanti; const Ad: string);
var
  Kullanici: string;
begin
  YonetimVarMi(Bag);
  Kullanici := KullaniciAdiniDogrula(Ad);
  if SysdbaMi(Kullanici) then
    raise EKullaniciKurali.Create(T('ERR_KULLANICI_SYSDBA'));
  if KendiKullanicisiMi(Bag, Kullanici) then
    raise EKullaniciKurali.Create(T('ERR_KULLANICI_KENDINI'));
  Calistir(Bag, 'DROP USER ' + Kullanici, '');
end;

procedure SifreDegistir(Bag: TAcikBaglanti; const Ad, Sifre, SifreTekrar: string);
var
  Kullanici: string;
begin
  YonetimVarMi(Bag);
  Kullanici := KullaniciAdiniDogrula(Ad);
  SifreyiDogrula(Sifre, SifreTekrar);
  Calistir(Bag, SifreKomutu(Bag, Kullanici, Sifre, False), Sifre);
  { Acik baglanti etkilenmez; ama bu baglantinin bellekteki sifresi (yedek penceresi vb. icin) guncellenir. }
  if KendiKullanicisiMi(Bag, Kullanici) then
    Bag.Tanim.Sifre := Sifre;
end;

procedure AdSoyadDegistir(Bag: TAcikBaglanti; const Ad, Isim, Soyad: string);
var
  Kullanici: string;
begin
  YonetimVarMi(Bag);
  Kullanici := KullaniciAdiniDogrula(Ad);
  if SysdbaMi(Kullanici) then
    raise EKullaniciKurali.Create(T('ERR_KULLANICI_SYSDBA'));
  IsimiDogrula(Bag, Trim(Isim), Trim(Soyad));
  Calistir(Bag, 'ALTER USER ' + Kullanici + ' FIRSTNAME ' + SqlMetni(Trim(Isim)) +
    ' LASTNAME ' + SqlMetni(Trim(Soyad)), '');
end;

procedure YoneticiAyarla(Bag: TAcikBaglanti; const Ad: string; Yonetici: Boolean);
var
  Kullanici: string;
begin
  YonetimVarMi(Bag);
  Kullanici := KullaniciAdiniDogrula(Ad);
  if SysdbaMi(Kullanici) then
    raise EKullaniciKurali.Create(T('ERR_KULLANICI_SYSDBA'));
  if not KullaniciYetenekleri(Bag).YoneticiAyarlanir then
    raise EKullaniciKurali.Create(T('ERR_KULLANICI_OZELLIK_YOK'));
  if Yonetici then
    Calistir(Bag, 'ALTER USER ' + Kullanici + ' GRANT ADMIN ROLE', '')
  else
    Calistir(Bag, 'ALTER USER ' + Kullanici + ' REVOKE ADMIN ROLE', '');
end;

procedure AktifAyarla(Bag: TAcikBaglanti; const Ad: string; Aktif: Boolean);
var
  Kullanici: string;
begin
  YonetimVarMi(Bag);
  Kullanici := KullaniciAdiniDogrula(Ad);
  if SysdbaMi(Kullanici) then
    raise EKullaniciKurali.Create(T('ERR_KULLANICI_SYSDBA'));
  if not KullaniciYetenekleri(Bag).AktifPasif then
    raise EKullaniciKurali.Create(T('ERR_KULLANICI_OZELLIK_YOK'));
  if (not Aktif) and KendiKullanicisiMi(Bag, Kullanici) then
    raise EKullaniciKurali.Create(T('ERR_KULLANICI_KENDINI'));
  if Aktif then
    Calistir(Bag, 'ALTER USER ' + Kullanici + ' ACTIVE', '')
  else
    Calistir(Bag, 'ALTER USER ' + Kullanici + ' INACTIVE', '');
end;

{ ---------- Kayitli baglanti sifresi ---------- }

{ Kayitli baglantida bu kullanicinin sifresi saklaniyorsa True. }
function KayitliSifreSaklaniyorMu(Bag: TAcikBaglanti): Boolean;
var
  Kayit: TBaglantiTanimi;
begin
  Result := KayitliBaglantiBul(Bag.Tanim.Ad, Kayit) and Kayit.SifreyiKaydet and
    SameText(Kayit.Kullanici, Bag.Tanim.Kullanici);
end;

procedure KayitliSifreyiGuncelle(Bag: TAcikBaglanti; const YeniSifre: string);
var
  Kayit: TBaglantiTanimi;
begin
  if not KayitliBaglantiBul(Bag.Tanim.Ad, Kayit) then
    Exit;
  Kayit.Sifre := YeniSifre;
  BaglantiKaydet(Kayit);
end;

{ ---------- Izgara icin bellek tablosu ---------- }

function KullaniciTablosuOlustur(Sahip: TComponent): TFDMemTable;
begin
  Result := TFDMemTable.Create(Sahip);
  Result.FieldDefs.Add('KULLANICI', ftString, 64);
  Result.FieldDefs.Add('ISIM', ftString, 64);
  Result.FieldDefs.Add('SOYAD', ftString, 64);
  Result.FieldDefs.Add('YONETICI', ftString, 8);
  Result.FieldDefs.Add('AKTIF', ftString, 8);
  Result.FieldDefs.Add('YONETICI_MI', ftBoolean);
  Result.FieldDefs.Add('AKTIF_MI', ftBoolean);
  Result.CreateDataSet;
  Result.FieldByName('KULLANICI').DisplayWidth := 24;
  Result.FieldByName('ISIM').DisplayWidth := 20;
  Result.FieldByName('SOYAD').DisplayWidth := 20;
  Result.FieldByName('YONETICI').DisplayWidth := 10;
  Result.FieldByName('AKTIF').DisplayWidth := 10;
  Result.FieldByName('YONETICI_MI').Visible := False;
  Result.FieldByName('AKTIF_MI').Visible := False;
  { Yonetici/Aktif kolonlari yalniz bilgi okunabiliyorsa gorunur; Doldur'da ayarlanir. }
end;

function EvetHayir(Deger: Boolean): string;
begin
  if Deger then
    Result := T('EVET')
  else
    Result := T('HAYIR');
end;

procedure KullaniciTablosunuDoldur(Tablo: TFDMemTable; const Liste: TArray<TKullaniciBilgisi>;
  const Yetenek: TKullaniciYetenekleri);
var
  Kullanici: TKullaniciBilgisi;
begin
  Tablo.DisableControls;
  try
    Tablo.EmptyDataSet;
    for Kullanici in Liste do
    begin
      Tablo.Append;
      Tablo.FieldByName('KULLANICI').AsString := Kullanici.Ad;
      Tablo.FieldByName('ISIM').AsString := Kullanici.Isim;
      Tablo.FieldByName('SOYAD').AsString := Kullanici.Soyad;
      Tablo.FieldByName('YONETICI_MI').AsBoolean := Kullanici.Yonetici;
      Tablo.FieldByName('AKTIF_MI').AsBoolean := Kullanici.Aktif;
      Tablo.FieldByName('YONETICI').AsString := EvetHayir(Kullanici.Yonetici);
      Tablo.FieldByName('AKTIF').AsString := EvetHayir(Kullanici.Aktif);
      Tablo.Post;
    end;
    Tablo.FieldByName('YONETICI').Visible := Yetenek.YoneticiOkunur;
    Tablo.FieldByName('AKTIF').Visible := Yetenek.AktifPasif;
    Tablo.First;
  finally
    Tablo.EnableControls;
  end;
end;

end.
