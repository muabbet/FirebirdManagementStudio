program TopluGuncelleTest;

{ Asama 4c: toplu guncelleme (uTopluGuncelle) testi (komut satiri).
  GOMULU kipte kendi gecici veritabanlarini acar (yalniz kendi olusturdugu dosyalara yazar); kayitli baglanti dosyasi
  da gecici klasorde tutulur (VeriKlasoruAyarla), gercek baglantilar.json'a dokunulmaz.
  Cikis kodu: hata sayisi (0 = hepsi gecti). Sonuc FBTEST_CIKTI dosyasina yazilir. }

{$APPTYPE CONSOLE}

uses
  System.SysUtils, System.Classes, System.IOUtils, System.StrUtils, System.Variants,
  FireDAC.Stan.Intf, FireDAC.Stan.Option, FireDAC.Stan.Error, FireDAC.Comp.Client, FireDAC.Phys.FB,
  FireDAC.ConsoleUI.Wait, Vcl.Forms, Vcl.Controls,
  uDil, uBaglanti, uKullanici, uCokluSorgu, uTopluGuncelle, fTopluGuncelle;

var
  Cikti: TStringList;
  Hatalar, KontrolSayisi: Integer;
  Klasor: string;

procedure Kontrol(const Ad: string; Sonuc: Boolean);
begin
  Inc(KontrolSayisi);
  if Sonuc then
    Cikti.Add('OK    ' + Ad)
  else
  begin
    Cikti.Add('HATA  ' + Ad);
    Inc(Hatalar);
  end;
end;

function YeniTanim(const Ad: string; SifreKayitli: Boolean): TBaglantiTanimi;
begin
  Result := Default(TBaglantiTanimi);
  Result.Ad := Ad;
  Result.Sunucu := '';
  Result.Port := 3050;
  Result.VeritabaniYolu := TPath.Combine(Klasor, Ad + '_' + FormatDateTime('hhnnsszzz', Now) + '.fdb');
  Result.Kullanici := 'SYSDBA';
  Result.Sifre := 'masterkey';
  Result.KarakterSeti := VARSAYILAN_KARAKTER_SETI;
  Result.SifreyiKaydet := SifreKayitli;
end;

procedure VeritabaniOlustur(const T: TBaglantiTanimi);
var
  Surucu: TFDPhysFBDriverLink;
  Baglanti: TFDConnection;
begin
  Surucu := TFDPhysFBDriverLink.Create(nil);
  Baglanti := TFDConnection.Create(nil);
  try
    Surucu.VendorLib := ExtractFilePath(ParamStr(0)) + 'istemci\fbclient.dll';
    Baglanti.DriverName := 'FB';
    Baglanti.LoginPrompt := False;
    Baglanti.Params.Values['Database'] := T.VeritabaniYolu;
    Baglanti.Params.Values['User_Name'] := T.Kullanici;
    Baglanti.Params.Values['Password'] := T.Sifre;
    Baglanti.Params.Values['OpenMode'] := 'Create';
    Baglanti.Params.Values['CharacterSet'] := T.KarakterSeti;
    Baglanti.Open;
    Baglanti.Close;
  finally
    Baglanti.Free;
    Surucu.Free;
  end;
end;

{ Kayitli baglanti olarak yazar, veritabanini olusturur ve komutlari calistirir (her komut ayri). }
procedure Hazirla(const T: TBaglantiTanimi; const Komutlar: array of string);
var
  Bag: TAcikBaglanti;
  Komut: string;
  Sorgu: TFDQuery;
begin
  VeritabaniOlustur(T);
  BaglantiKaydet(T);
  Bag := FbGeciciBaglan(T);
  try
    for Komut in Komutlar do
    begin
      Sorgu := KomutHazirla(Bag, Komut);
      try
        Sorgu.ExecSQL;
      finally
        Sorgu.Free;
      end;
    end;
  finally
    Bag.Free;
  end;
end;

{ Kayitli baglantiya gecici baglanip tek bir sayi okur. }
function Say(const Ad, Sql: string): Integer;
var
  Tanim: TBaglantiTanimi;
  Bag: TAcikBaglanti;
begin
  KayitliBaglantiBul(Ad, Tanim);
  Bag := FbGeciciBaglan(Tanim);
  try
    Result := Bag.Baglanti.ExecSQLScalar(Sql);
  finally
    Bag.Free;
  end;
end;

function Bul(const Kayitlar: TArray<TTopluKayit>; const Ad: string; out Kayit: TTopluKayit): Boolean;
var
  K: TTopluKayit;
begin
  Result := False;
  for K in Kayitlar do
    if K.Ad = Ad then
    begin
      Kayit := K;
      Exit(True);
    end;
end;

procedure KuralBolumu;
begin
  Cikti.Add('');
  Cikti.Add('=== A) Komut denetimi ===');
  Kontrol('Kontrol: UPDATE kabul', TopluKontrol('update t set a = 1 where b = 2') = '');
  Kontrol('Kontrol: yorumla baslayan UPDATE kabul', TopluKontrol('-- not' + sLineBreak + 'update t set a = 1') = '');
  Kontrol('Kontrol: SELECT reddedilir', TopluKontrol('select * from t') = T('ERR_TOPLU_SADECE_UPDATE'));
  Kontrol('Kontrol: DELETE ve DROP reddedilir', (TopluKontrol('delete from t') <> '') and (TopluKontrol('drop table t') <> ''));
  Kontrol('Kontrol: iki komut reddedilir', TopluKontrol('update t set a = 1; update t set a = 2') = T('ERR_TOPLU_TEK_KOMUT'));
  Kontrol('Kontrol: bos metin reddedilir', TopluKontrol('  ') <> '');
  Kontrol('WHERE: var', TopluWhereVar('update t set a = 1 where b = 2'));
  Kontrol('WHERE: yok', not TopluWhereVar('update t set a = 1'));
  Kontrol('WHERE: yazinin icinde gecen sayilmaz', not TopluWhereVar('update t set a = ''where b = 2'''));
  Kontrol('WHERE: yorumda gecen sayilmaz', not TopluWhereVar('-- where' + sLineBreak + 'update t set a = 1 /* where */'));
  Kontrol('WHERE: kucuk harf ve satir sonu', TopluWhereVar('update t set a = 1' + sLineBreak + 'wHeRe b = 2'));
  { Arayuz duman testi: sekmenin .dfm'i hatasiz yuklenir (gosterilmez) }
  with TTopluGuncelleSekme.Create(nil) do
    Free;
  Kontrol('Duman: toplu guncelleme sekmesi olusuyor (dfm hatasi yok)', True);
end;

procedure TopluBolumu;
var
  Kayitlar: TArray<TTopluKayit>;
  K: TTopluKayit;
  Toplam: Integer;
  Sql: string;
begin
  Cikti.Add('');
  Cikti.Add('=== B) Onizle ve uygula ===');
  Hazirla(YeniTanim('top_a', True), ['create table FBY_T (ID integer not null, DURUM varchar(10), SAYI integer)',
    'insert into FBY_T values (1, ''A'', 1)', 'insert into FBY_T values (2, ''A'', 2)', 'insert into FBY_T values (3, ''A'', 3)']);
  Hazirla(YeniTanim('top_b', True), ['create table FBY_T (ID integer not null, DURUM varchar(10), SAYI integer)',
    'insert into FBY_T values (4, ''B'', 10)', 'insert into FBY_T values (5, ''B'', 20)']);
  Hazirla(YeniTanim('top_tablosuz', True), ['create table BASKA (X integer)']);
  Hazirla(YeniTanim('top_sifresiz', False), ['create table FBY_T (ID integer not null, DURUM varchar(10), SAYI integer)']);

  Sql := 'update FBY_T set DURUM = ''X'' where SAYI > 1';

  { Onizleme: sayilar dogru, veri DEGISMEZ }
  Kayitlar := TopluOnizle(['top_a', 'top_b'], Sql, nil);
  Kontrol('Onizleme: iki veritabani da tamam', (Length(Kayitlar) = 2) and (Kayitlar[0].Durum = tdTamam) and (Kayitlar[1].Durum = tdTamam));
  Kontrol('Onizleme: top_a 2 satir', Bul(Kayitlar, 'top_a', K) and (K.Satir = 2));
  Kontrol('Onizleme: top_b 2 satir', Bul(Kayitlar, 'top_b', K) and (K.Satir = 2));
  Kontrol('Onizleme: veri degismedi (top_a)', Say('top_a', 'select count(*) from FBY_T where DURUM = ''X''') = 0);
  Kontrol('Onizleme: veri degismedi (top_b)', Say('top_b', 'select count(*) from FBY_T where DURUM = ''X''') = 0);

  { Hata ve atlanan: digerleri etkilenmez }
  Kayitlar := TopluOnizle(['top_a', 'top_tablosuz', 'top_sifresiz'], Sql, nil);
  Kontrol('Onizleme: tablosu olmayan hata verir', Bul(Kayitlar, 'top_tablosuz', K) and (K.Durum = tdHata));
  Kontrol('Onizleme: hata cumlesi anlasilir (ERR_GENEL degil), ayrinti dolu',
    Bul(Kayitlar, 'top_tablosuz', K) and (K.Cumle <> '') and (K.Cumle <> T('ERR_GENEL')) and (K.Ayrinti <> ''));
  Kontrol('Onizleme: sifresi kayitli olmayan atlanir', Bul(Kayitlar, 'top_sifresiz', K) and (K.Durum = tdAtlandi));
  Kontrol('Onizleme: hatali olsa da top_a sonucu var', Bul(Kayitlar, 'top_a', K) and (K.Durum = tdTamam) and (K.Satir = 2));

  { Uygula: veri degisir, sayilar onizlemeyle ayni }
  Kayitlar := TopluUygula(['top_a', 'top_b'], Sql, nil);
  Toplam := 0;
  for K in Kayitlar do
    Inc(Toplam, K.Satir);
  Kontrol('Uygula: toplam 4 satir degisti', (Length(Kayitlar) = 2) and (Toplam = 4));
  Kontrol('Uygula: top_a veride degisti (2 satir X)', Say('top_a', 'select count(*) from FBY_T where DURUM = ''X''') = 2);
  Kontrol('Uygula: top_a degismemesi gereken satir ayni', Say('top_a', 'select count(*) from FBY_T where DURUM = ''A''') = 1);
  Kontrol('Uygula: top_b veride degisti (2 satir X)', Say('top_b', 'select count(*) from FBY_T where DURUM = ''X''') = 2);

  { Bir veritabani hata verirse digeri yine uygulanir ve onaylanir }
  Kayitlar := TopluUygula(['top_tablosuz', 'top_a'], 'update FBY_T set SAYI = SAYI + 100 where ID = 1', nil);
  Kontrol('Uygula: hatali veritabani hata kaydi', Bul(Kayitlar, 'top_tablosuz', K) and (K.Durum = tdHata));
  Kontrol('Uygula: digeri etkilenmeden uygulandi', Bul(Kayitlar, 'top_a', K) and (K.Durum = tdTamam) and (K.Satir = 1) and
    (Say('top_a', 'select SAYI from FBY_T where ID = 1') = 101));

  { WHERE'siz: tum satirlar }
  Kayitlar := TopluOnizle(['top_b'], 'update FBY_T set SAYI = 0', nil);
  Kontrol('WHERE yoksa tum satirlar sayilir', Bul(Kayitlar, 'top_b', K) and (K.Satir = 2));
  Kontrol('WHERE yoksa onizleme yine de veriyi degistirmez', Say('top_b', 'select count(*) from FBY_T where SAYI = 0') = 0);

  { Baglanti ve ilerleme bildirimi }
  Toplam := 0;
  TopluOnizle(['top_a', 'top_b'], Sql,
    procedure(Ad: string)
    begin
      Inc(Toplam);
    end);
  Kontrol('Ilerleme: her veritabani icin bildirim geldi', Toplam = 2);
end;

procedure DilBolumu;
const
  Anahtarlar: array[0..14] of string = ('ERR_TOPLU_TEK_KOMUT', 'ERR_TOPLU_SADECE_UPDATE', 'BTN_ONIZLE', 'BTN_UYGULA',
    'TOPLU_SUTUN_SATIR', 'TOPLU_IPUCU', 'TOPLU_SQL', 'TOPLU_ONIZLEME_OZET', 'TOPLU_UYGULANDI_OZET', 'TOPLU_ONCE_ONIZLE',
    'TOPLU_ONIZLEME_HATALI', 'TOPLU_ONAY', 'TOPLU_ONAY_WHERE_YOK', 'BTN_TOPLU_GUNCELLE', 'TOPLU_SEKME');
var
  Dil, Anahtar, Eksik: string;
begin
  Cikti.Add('');
  Cikti.Add('=== C) Dil anahtarlari ===');
  for Dil in ['tr', 'en', 'de'] do
  begin
    DilYukle(Dil);
    Eksik := '';
    for Anahtar in Anahtarlar do
      if T(Anahtar) = Anahtar then
        Eksik := Eksik + ' ' + Anahtar;
    Kontrol('Dil ' + Dil + ': 4c anahtarlari tanimli', Eksik = '');
    if Eksik <> '' then
      Cikti.Add('      eksik:' + Eksik);
    Kontrol('Dil ' + Dil + ': onay metni bicimlenebiliyor',
      TF('TOPLU_ONAY', ['update x', 'a: 1', 2, 3]) <> T('TOPLU_ONAY'));
  end;
  DilYukle('tr');
end;

begin
  Cikti := TStringList.Create;
  try
    try
      DilYukle('tr');
      Klasor := TPath.Combine(GetEnvironmentVariable('TEMP'), 'toplutest');
      ForceDirectories(Klasor);
      VeriKlasoruAyarla(TPath.Combine(Klasor, 'veri'));
      Cikti.Add('TopluGuncelleTest  ' + FormatDateTime('yyyy-mm-dd hh:nn:ss', Now));
      DilBolumu;
      KuralBolumu;
      TopluBolumu;
    except
      on E: Exception do
      begin
        Cikti.Add('');
        Cikti.Add('HATA (beklenmeyen): ' + E.ClassName + ': ' + E.Message);
        Inc(Hatalar);
      end;
    end;
    Cikti.Add('');
    Cikti.Add('Kontrol: ' + IntToStr(KontrolSayisi) + '  Hata: ' + IntToStr(Hatalar));
    Cikti.SaveToFile(GetEnvironmentVariable('FBTEST_CIKTI'), TEncoding.UTF8);
  finally
    Cikti.Free;
  end;
  ExitCode := Hatalar;
end.
