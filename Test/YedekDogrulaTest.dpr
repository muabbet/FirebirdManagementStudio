program YedekDogrulaTest;

{ Yedegi dogrulama testi (uYedekDogrula): gercek bir gecici veritabaninda yedek alinir, en yeni yedek yeni ve benzersiz bir
  dosyaya geri yuklenir, nesne ve kayit sayilari okunur, canliyla karsilastirilir (fark = bilgi); ikinci dogrulama onceki
  dosyayi ezmez; bozuk (kesik) yedek GECERSIZ cikar ve canli veritabanina dokunulmaz; yedek yok / uzak sunucu / sifresiz
  baglanti anlasilir cumle verir; iptal; gunluge DOGRULAMA-OK / DOGRULAMA-HATA yazilir ve acilis uyarisi bunlardan etkilenmez.
  Gercek veriye dokunulmaz: kendi gecici veritabanini kurar, veri klasoru gecici klasore alinir, dosya silinmez.
  Ortam: FBTEST_SUNUCU (bos = yerel), FBTEST_PORT, FBTEST_KLASOR (sunucunun yazabildigi klasor), FBTEST_KULLANICI,
  FBTEST_SIFRE, FBTEST_CIKTI. Cikis kodu: hata sayisi. }

{$APPTYPE CONSOLE}

uses
  System.SysUtils, System.Classes, System.IOUtils, Data.DB,
  FireDAC.Stan.Intf, FireDAC.Stan.Option, FireDAC.Stan.Error, FireDAC.Comp.Client, FireDAC.Phys.FB,
  FireDAC.ConsoleUI.Wait,
  uDil, uBaglanti, uSorgu, uMetadata, uYedek, uYedekPlan, uYedekDogrula;

type
  { Ilerleme geri cagrisi: kac kez cagrildi, istenirse hemen iptal ister }
  TSayac = class
    Sayi: Integer;
    IptalIste: Boolean;
    procedure Gel(const Satir: string; var Iptal: Boolean);
  end;

var
  Cikti: TStringList;
  Hatalar: Integer;

procedure TSayac.Gel(const Satir: string; var Iptal: Boolean);
begin
  Inc(Sayi);
  if IptalIste then
    Iptal := True;
end;

function Ortam(const Ad, Varsayilan: string): string;
begin
  Result := GetEnvironmentVariable(Ad);
  if Result = '' then
    Result := Varsayilan;
end;

procedure Kontrol(const Ad: string; Sonuc: Boolean);
begin
  if Sonuc then
    Cikti.Add('OK    ' + Ad)
  else
  begin
    Cikti.Add('HATA  ' + Ad);
    Inc(Hatalar);
  end;
end;

function SayiDosya(const Klasor, Maske: string): Integer;
begin
  if TDirectory.Exists(Klasor) then
    Result := Length(TDirectory.GetFiles(Klasor, Maske))
  else
    Result := 0;
end;

function SonSatir(const Ad: string): string;
var
  Satirlar: TArray<string>;
begin
  Satirlar := YedekGunlugu(Ad, 1);
  if Length(Satirlar) = 0 then
    Result := ''
  else
    Result := Satirlar[0];
end;

function MusteriSayisi(Bag: TAcikBaglanti): Int64;
begin
  Result := TabloSatirSayisi(Bag, 'MUSTERI');
end;

{ Yedek dosyasinin ilk yarisini yeni bir dosyaya yazar (bozuk yedek) }
procedure DosyayiKes(const Kaynak, Hedef: string);
var
  Bayt: TBytes;
begin
  Bayt := TFile.ReadAllBytes(Kaynak);
  SetLength(Bayt, Length(Bayt) div 2);
  TFile.WriteAllBytes(Hedef, Bayt);
end;

procedure Dene;
var
  Tanim, T2: TBaglantiTanimi;
  Plan: TYedekPlani;
  Sonuc: TYedekSonucu;
  H, H2, H3: TDogrulamaHazirligi;
  D, D2: TDogrulamaSonucu;
  Bag: TAcikBaglanti;
  Sayac: TSayac;
  Cumle, Klasor, Yol, Onek, Ornek, KesikYol, Satir, GunlukHepsi: string;
  Boyut1: Int64;
  Uyarilar, Gunluk: TArray<string>;
  i: Integer;
begin
  Klasor := TPath.Combine(Ortam('FBTEST_KLASOR', GetEnvironmentVariable('TEMP')), 'dg_' + FormatDateTime('yyyymmdd_hhnnss', Now));
  Yol := Klasor + '.fdb';
  if Ortam('FBTEST_SUNUCU', '') = '' then
    ForceDirectories(ExtractFilePath(Yol));
  ForceDirectories(Klasor);

  Tanim := Default(TBaglantiTanimi);
  Tanim.Ad := 'dgtest';
  Tanim.Sunucu := Ortam('FBTEST_SUNUCU', '');
  Tanim.Port := StrToInt(Ortam('FBTEST_PORT', '3050'));
  Tanim.VeritabaniYolu := Yol;
  Tanim.Kullanici := Ortam('FBTEST_KULLANICI', 'SYSDBA');
  Tanim.Sifre := Ortam('FBTEST_SIFRE', '');
  Tanim.KarakterSeti := VARSAYILAN_KARAKTER_SETI;
  FbVeritabaniOlustur(Tanim);
  Bag := FbBaglan(Tanim);
  Cikti.Add('Gecici veritabani: ' + Yol);
  Cikti.Add('Plan klasoru: ' + Klasor);

  SorguCalistir(Bag, 'CREATE TABLE MUSTERI (ID INTEGER NOT NULL PRIMARY KEY, AD VARCHAR(30))').Free;
  SorguCalistir(Bag, 'CREATE TABLE SIPARIS (ID INTEGER NOT NULL PRIMARY KEY, MUSTERI_ID INTEGER, TUTAR NUMERIC(10,2))').Free;
  SorguCalistir(Bag, 'CREATE GENERATOR G_DG').Free;
  SorguCalistir(Bag, 'CREATE VIEW V_MUSTERI AS SELECT ID, AD FROM MUSTERI').Free;
  SorguCalistir(Bag, 'CREATE TRIGGER TR_MUSTERI_BI FOR MUSTERI BEFORE INSERT AS BEGIN IF (NEW.ID IS NULL) THEN NEW.ID = GEN_ID(G_DG, 1); END').Free;
  SorguCalistir(Bag, 'CREATE PROCEDURE P_BIR RETURNS (N INTEGER) AS BEGIN N = 1; SUSPEND; END').Free;
  for i := 1 to 3 do
    SorguCalistir(Bag, 'INSERT INTO MUSTERI (ID, AD) VALUES (' + IntToStr(i) + ', ''musteri ' + IntToStr(i) + ''')').Free;
  for i := 1 to 5 do
    SorguCalistir(Bag, 'INSERT INTO SIPARIS (ID, MUSTERI_ID, TUTAR) VALUES (' + IntToStr(i) + ', 1, ' + IntToStr(i * 10) + ')').Free;

  Ornek := VarsayilanYedekAdi(Yol);
  Onek := Copy(Ornek, 1, Length(Ornek) - Length('_yyyymmdd_hhnnss.fbk'));

  { ---- Hazirlik: plan yok / sifresiz / yedek yok / uzak sunucu ---- }
  Kontrol('Plansiz baglantida hazirlik basarisiz, cumle dolu', (not DogrulamaHazirla('dgtest', H, Cumle)) and (Cumle <> ''));
  Plan := Default(TYedekPlani);
  Plan.BaglantiAd := 'dgtest';
  Plan.Klasor := TPath.Combine(Klasor, 'yedekler');
  Plan.Saat := '02:00';
  Plan.Sakla := 3;
  YedekPlaniKaydet(Plan);
  Tanim.SifreyiKaydet := False;
  BaglantiKaydet(Tanim);
  Kontrol('Sifresi kayitli olmayan baglantida anlasilir cumle', (not DogrulamaHazirla('dgtest', H, Cumle)) and
    (Cumle = T('ERR_YEDEKPLAN_SIFRE')));
  Tanim.SifreyiKaydet := True;
  BaglantiKaydet(Tanim);
  Kontrol('Klasorde yedek yoksa anlasilir cumle (klasor adi icinde)', (not DogrulamaHazirla('dgtest', H, Cumle)) and
    (Cumle = TF('ERR_DOGRULA_YEDEK_YOK', [Plan.Klasor])));

  T2 := Tanim;
  T2.Ad := 'dguzak';
  T2.Sunucu := '10.255.255.1';
  BaglantiKaydet(T2);
  Plan.BaglantiAd := 'dguzak';
  YedekPlaniKaydet(Plan);
  Kontrol('Uzak sunucuda anlasilir cumle, hicbir sey yapilmaz', (not DogrulamaHazirla('dguzak', H2, Cumle)) and
    (Cumle = T('ERR_DOGRULA_UZAK')));
  YedekPlaniSil('dguzak');
  Plan.BaglantiAd := 'dgtest';

  { ---- Yedek al, dogrula ---- }
  Kontrol('Yedek alindi (plan calistirildi)', YedekPlaniCalistir('dgtest', nil, Sonuc));
  Kontrol('Hazirlik basarili', DogrulamaHazirla('dgtest', H, Cumle));
  Cikti.Add('Cumle: ' + Cumle);
  Kontrol('Dogrulanacak yedek en yeni .fbk', (ExtractFileName(H.YedekDosyasi) = ExtractFileName(Sonuc.Dosya)) and (H.YedekBoyutu > 0));
  Kontrol('Hedef Dogrulama klasorunde, yeni ve .fdb', (Pos('Dogrulama', H.HedefDosya) > 0) and (Pos('_dogrulama_', H.HedefDosya) > 0) and
    SameText(ExtractFileExt(H.HedefDosya), '.fdb') and not TFile.Exists(H.HedefDosya));
  Kontrol('Onay metni yedegi ve hedefi yaziyor', (Pos(H.YedekDosyasi, DogrulamaOnayMetni(H)) > 0) and (Pos(H.HedefDosya, DogrulamaOnayMetni(H)) > 0));
  Cikti.Add(DogrulamaOnayMetni(H));

  Sayac := TSayac.Create;
  try
    Kontrol('Dogrulama gecerli', YedegiDogrula(H, Sayac.Gel, D));
    Cikti.Add('--- Rapor 1 ---');
    Cikti.Add(D.Rapor);
    Cikti.Add('Ayrinti: ' + D.Ayrinti);
    Kontrol('Ilerleme geri cagrisi calisti', Sayac.Sayi > 0);
  finally
    Sayac.Free;
  end;
  Kontrol('Sonuc gecerli, iptal degil, 2 tablo', D.Gecerli and not D.Iptal and (D.TabloSayisi = 2));
  Kontrol('Ozet "gecerli" cumlesi', D.Ozet = TF('DOGRULA_OZET_GECERLI', [2]));
  Kontrol('Geri yuklenen dosya var ve silinmedi', TFile.Exists(H.HedefDosya) and (D.GeriYuklenen = H.HedefDosya));
  Boyut1 := TFile.GetSize(H.HedefDosya);
  Kontrol('Rapor: yapi sayilari (2 tablo, 1 view, 1 prosedur, 1 trigger, 1 generator)',
    (Pos(TF('DOGRULA_YAPI_SATIR', [T('DOGRULA_TUR_TABLO'), 2, 2]), D.Rapor) > 0) and
    (Pos(TF('DOGRULA_YAPI_SATIR', [T('DOGRULA_TUR_VIEW'), 1, 1]), D.Rapor) > 0) and
    (Pos(TF('DOGRULA_YAPI_SATIR', [T('DOGRULA_TUR_PROSEDUR'), 1, 1]), D.Rapor) > 0) and
    (Pos(TF('DOGRULA_YAPI_SATIR', [T('DOGRULA_TUR_TETIKLEYICI'), 1, 1]), D.Rapor) > 0) and
    (Pos(TF('DOGRULA_YAPI_SATIR', [T('DOGRULA_TUR_GENERATOR'), 1, 1]), D.Rapor) > 0));
  Kontrol('Rapor: kayit sayilari yedekte / canlida ayni (MUSTERI 3 / 3, SIPARIS 5 / 5)',
    (Pos(TF('DOGRULA_KAYIT_SATIR', ['MUSTERI', '3', '3']), D.Rapor) > 0) and
    (Pos(TF('DOGRULA_KAYIT_SATIR', ['SIPARIS', '5', '5']), D.Rapor) > 0));
  Kontrol('Fark yokken "degismis olabilir" notu yok', Pos(T('DOGRULA_FARK_BILGI'), D.Rapor) = 0);
  Kontrol('Rapor geri yuklenen dosyayi yaziyor', Pos(H.HedefDosya, D.Rapor) > 0);
  Satir := SonSatir('dgtest');
  Kontrol('Gunluge DOGRULAMA-OK satiri yazildi', Pos(' | DOGRULAMA-OK | ', Satir) > 0);
  Kontrol('Gunluk satirinda yedek ve geri yuklenen dosya var', (Pos(ExtractFileName(H.YedekDosyasi), Satir) > 0) and (Pos(H.HedefDosya, Satir) > 0));
  Kontrol('Canli veritabani dokunulmadi (3 musteri)', MusteriSayisi(Bag) = 3);

  { ---- Yedekten sonra canli degisir: fark bilgi, yine gecerli; ikinci dosya birincinin yerine gecmez ---- }
  SorguCalistir(Bag, 'INSERT INTO MUSTERI (ID, AD) VALUES (10, ''yeni musteri'')').Free;
  SorguCalistir(Bag, 'CREATE TABLE YENI_TABLO (ID INTEGER)').Free;
  Sleep(1200);
  Kontrol('Ikinci hazirlik basarili', DogrulamaHazirla('dgtest', H2, Cumle));
  Kontrol('Ikinci hedef birincisinden farkli', H2.HedefDosya <> H.HedefDosya);
  Kontrol('Ikinci dogrulama gecerli (fark hata degil)', YedegiDogrula(H2, nil, D2));
  Cikti.Add('--- Rapor 2 ---');
  Cikti.Add(D2.Rapor);
  Kontrol('Rapor: MUSTERI yedekte 3 / canlida 4, fark bilgisi var', (Pos(TF('DOGRULA_KAYIT_SATIR', ['MUSTERI', '3', '4']), D2.Rapor) > 0) and
    (Pos(T('DOGRULA_FARK_BILGI'), D2.Rapor) > 0) and (Pos(TF('DOGRULA_FARK_OZET', [1]), D2.Rapor) > 0));
  Kontrol('Rapor: yapi sayisi farki (yedekte 2 tablo / canlida 3) bilgi olarak yazili',
    Pos(TF('DOGRULA_YAPI_SATIR', [T('DOGRULA_TUR_TABLO'), 2, 3]), D2.Rapor) > 0);
  Kontrol('Iki ayri geri yuklenen dosya var, birincisi degismedi', (SayiDosya(ExtractFilePath(H.HedefDosya), '*.fdb') = 2) and
    TFile.Exists(H.HedefDosya) and (TFile.GetSize(H.HedefDosya) = Boyut1) and TFile.Exists(H2.HedefDosya));

  { Ayni adda dosya zaten varsa yeni hedef baska ad alir (ezilmez) }
  Kontrol('Uc.n hazirlik', DogrulamaHazirla('dgtest', H, Cumle));
  TFile.WriteAllText(H.HedefDosya, 'x');
  Kontrol('Hedef adi benzersiz: var olan dosyayla cakismaz', DogrulamaHazirla('dgtest', H3, Cumle) and (H3.HedefDosya <> H.HedefDosya) and
    not TFile.Exists(H3.HedefDosya));
  H := H3;

  { ---- Iptal ---- }
  Sayac := TSayac.Create;
  try
    Sayac.IptalIste := True;
    Kontrol('Iptal edilen dogrulama gecerli sayilmaz', (not YedegiDogrula(H, Sayac.Gel, D)) and D.Iptal and not D.Gecerli);
    Cikti.Add('Iptal ozeti: ' + D.Ozet);
    Kontrol('Iptal ozeti iptal cumlesi', D.Ozet = T('DOGRULA_OZET_IPTAL'));
  finally
    Sayac.Free;
  end;
  Kontrol('Iptalde gunluge DOGRULAMA-HATA yazildi', Pos(' | DOGRULAMA-HATA | ', SonSatir('dgtest')) > 0);

  { ---- Bozuk (kesik) yedek ---- }
  KesikYol := TPath.Combine(Plan.Klasor, Onek + '_20991231_235959.fbk');
  DosyayiKes(H2.YedekDosyasi, KesikYol);
  Kontrol('Hazirlik en yeni (kesik) yedegi secti', DogrulamaHazirla('dgtest', H, Cumle) and (H.YedekDosyasi = KesikYol));
  Kontrol('Kesik yedek GECERSIZ', (not YedegiDogrula(H, nil, D)) and not D.Gecerli and not D.Iptal);
  Cikti.Add('--- Kesik yedek ---');
  Cikti.Add('Ozet: ' + D.Ozet);
  Cikti.Add('Ayrinti: ' + D.Ayrinti);
  Kontrol('Ozet anlasilir GECERSIZ cumlesi ve ham metin Ayrinti alaninda', (Pos(Trim(TF('DOGRULA_OZET_GECERSIZ', [''])), D.Ozet) = 1) and
    (D.Ayrinti <> ''));
  Kontrol('Rapor yedek dosyasini yaziyor', Pos(KesikYol, D.Rapor) > 0);
  Kontrol('Gunluge DOGRULAMA-HATA yazildi', Pos(' | DOGRULAMA-HATA | ', SonSatir('dgtest')) > 0);
  Kontrol('Canli veritabani dokunulmadi (4 musteri, baglanti calisiyor)', MusteriSayisi(Bag) = 4);
  Kontrol('Kesik yedek dosyasi silinmedi', TFile.Exists(KesikYol));

  { ---- Gunluk ve acilis uyarisi ---- }
  Kontrol('Son yedek satiri DOGRULAMA satirlarini atlar (OK satiri)', Pos(' | OK | ', SonYedekSatiri('dgtest')) > 0);
  Kontrol('Dogrulama hatasi "son yedek basarisiz" uyarisi cikarmaz', YedekGunlukUyarisi('dgtest', SonYedekSatiri('dgtest'), Now) = '');
  Kontrol('DOGRULAMA-HATA satiri tek basina uyari uretmez',
    YedekGunlukUyarisi('x', FormatDateTime('yyyy-mm-dd hh:nn:ss', Now) + ' | x | DOGRULAMA-HATA | boom', Now) = '');
  Kontrol('DOGRULAMA-OK satiri (eski tarihli) tek basina uyari uretmez',
    YedekGunlukUyarisi('x', '2020-01-01 02:00:00 | x | DOGRULAMA-OK | tamam', Now) = '');
  Kontrol('Yine de gercek HATA satiri uyari uretir',
    Pos('boom', YedekGunlukUyarisi('x', FormatDateTime('yyyy-mm-dd hh:nn:ss', Now) + ' | x | HATA | boom', Now)) > 0);
  Gunluk := YedekGunlugu('dgtest', 50);
  GunlukHepsi := '';
  for i := 0 to High(Gunluk) do
    GunlukHepsi := GunlukHepsi + Gunluk[i] + #10;
  Cikti.Add('--- Gunluk ---');
  Cikti.Add(GunlukHepsi);
  Kontrol('Gunlukte yedek OK ve dogrulama satirlari birlikte gorunur', (Pos(' | OK | ', GunlukHepsi) > 0) and
    (Pos(' | DOGRULAMA-OK | ', GunlukHepsi) > 0) and (Pos(' | DOGRULAMA-HATA | ', GunlukHepsi) > 0));
  { Eski bir yedek + taze dogrulama OK'si: "son basarili yedek" yerine gecmez, eski uyarisi surer }
  TFile.AppendAllText(TPath.Combine(UygulamaVeriKlasoru, 'yedekgunlugu.txt'), '2026-01-01 02:00:00 | eskiplan | OK | eski yedek' + sLineBreak,
    TEncoding.UTF8);
  GunlukSatiriYaz('eskiplan', 'DOGRULAMA-OK', 'taze dogrulama');
  Kontrol('Taze dogrulama OK satiri son basarili yedegin yerine gecmez', Pos('2026-01-01', SonYedekSatiri('eskiplan')) = 1);
  Plan.BaglantiAd := 'eskiplan';
  YedekPlaniKaydet(Plan);
  Uyarilar := YedekPlanlariniDenetle;
  for i := 0 to High(Uyarilar) do
    Cikti.Add('Acilis uyarisi: ' + Uyarilar[i]);
  Satir := '';
  for i := 0 to High(Uyarilar) do
    if (Pos('eskiplan', Uyarilar[i]) > 0) and (Pos('01.01.2026', Uyarilar[i]) > 0) then
      Satir := Satir + Uyarilar[i];
  Kontrol('Acilis denetimi eskiplan icin 01.01.2026 tarihli ESKI uyarisi verir', Satir <> '');
  Satir := '';
  for i := 0 to High(Uyarilar) do
    if (Pos('dgtest', Uyarilar[i]) > 0) and (Uyarilar[i] <> TF('YEDEKPLAN_UYARI_GOREV', ['dgtest'])) then
      Satir := Satir + Uyarilar[i];
  Kontrol('Acilis denetimi dgtest icin gorev uyarisi disinda (basarisiz/eski) uyari vermez', Satir = '');
  YedekPlaniSil('eskiplan');
  YedekPlaniSil('dgtest');
  FbBaglantiyiKes(Bag);
end;

var
  Kok, CiktiYolu: string;
begin
  Cikti := TStringList.Create;
  Hatalar := 0;
  try
    try
      DilYukle('tr');
      Kok := TPath.Combine(GetEnvironmentVariable('TEMP'), 'dgtest_' + FormatDateTime('yyyymmdd_hhnnss', Now));
      ForceDirectories(Kok);
      VeriKlasoruAyarla(TPath.Combine(Kok, 'veri'));
      Cikti.Add('Gecici veri klasoru: ' + Kok);
      Dene;
    except
      on E: Exception do
      begin
        Cikti.Add('BEKLENMEYEN HATA: ' + E.Message);
        Inc(Hatalar);
      end;
    end;
  finally
    Cikti.Add('Hata sayisi: ' + IntToStr(Hatalar));
    CiktiYolu := Ortam('FBTEST_CIKTI', '');
    if CiktiYolu <> '' then
      Cikti.SaveToFile(CiktiYolu, TEncoding.UTF8)
    else
      Writeln(Cikti.Text);
    Cikti.Free;
  end;
  ExitCode := Hatalar;
end.
