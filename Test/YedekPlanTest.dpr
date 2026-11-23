program YedekPlanTest;

{ Zamanlanmis yedek testi (uYedekPlan): plan dosyasi, denetim, gorev XML'i, Windows Gorev Zamanlayici'ya gercek bir gecici
  gorev kurup kaldirma, eski yedekleri "Eski" klasorune tasima (silmeden), gunluk, ve gercek bir gecici veritabaninda
  plani calistirma (yedek dosyasi olusur, sayi sinirini asanlar tasinir, sifresiz baglantida anlasilir hata).
  Gercek veriye dokunulmaz: veri klasoru gecici bir klasore alinir, dosya silinmez.
  Ortam: FBTEST_SUNUCU (bos = yerel), FBTEST_PORT, FBTEST_KLASOR, FBTEST_KULLANICI, FBTEST_SIFRE, FBTEST_CIKTI.
  Cikis kodu: hata sayisi. }

{$APPTYPE CONSOLE}

uses
  System.SysUtils, System.Classes, System.IOUtils,
  FireDAC.Stan.Intf, FireDAC.Stan.Option, FireDAC.Stan.Error, FireDAC.Comp.Client, FireDAC.Phys.FB,
  FireDAC.ConsoleUI.Wait,
  uDil, uBaglanti, uYedek, uYedekPlan;

var
  Cikti: TStringList;
  Hatalar: Integer;

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

procedure DosyaYaz(const Yol: string);
begin
  TFile.WriteAllText(Yol, 'x');
end;

{ ---------- Plan dosyasi, denetim, XML ---------- }

procedure PlanDene;
var
  P, Q: TYedekPlani;
begin
  P := Default(TYedekPlani);
  P.BaglantiAd := 'Muhasebe & Stok';
  P.Klasor := 'D:\Yedek\Muhasebe';
  P.Saat := '02:30';
  P.Sakla := 5;
  Kontrol('Baslangicta plan yok', not YedekPlaniOku(P.BaglantiAd, Q));
  YedekPlaniKaydet(P);
  Kontrol('Plan okunur, alanlar ayni', YedekPlaniOku(P.BaglantiAd, Q) and (Q.Klasor = P.Klasor) and (Q.Saat = '02:30') and
    (Q.Sakla = 5) and (Q.BaglantiAd = P.BaglantiAd));
  P.Saat := '23:05';
  P.Sakla := 9;
  YedekPlaniKaydet(P);
  Kontrol('Ayni baglantiya ikinci kayit eskinin yerine gecer', YedekPlaniOku(P.BaglantiAd, Q) and (Q.Saat = '23:05') and (Q.Sakla = 9));
  Q := P;
  Q.BaglantiAd := 'Baska';
  YedekPlaniKaydet(Q);
  YedekPlaniSil('Baska');
  Kontrol('Baska planin silinmesi ilkine dokunmaz', YedekPlaniOku(P.BaglantiAd, Q) and not YedekPlaniOku('Baska', Q));
  YedekPlaniSil(P.BaglantiAd);
  Kontrol('Plan silinince okunmaz', not YedekPlaniOku(P.BaglantiAd, Q));
  YedekPlaniSil('hic_olmayan');

  P.Klasor := '';
  Kontrol('Bos klasor reddedilir', YedekPlaniDenetle(P) <> '');
  P.Klasor := 'C:\Y';
  P.Saat := '25:00';
  Kontrol('Gecersiz saat reddedilir', YedekPlaniDenetle(P) <> '');
  P.Saat := '2:00';
  Kontrol('Eksik saat bicimi reddedilir', YedekPlaniDenetle(P) <> '');
  P.Saat := '02:00';
  P.Sakla := 0;
  Kontrol('Sifir yedek reddedilir', YedekPlaniDenetle(P) <> '');
  P.Sakla := 3;
  Kontrol('Gecerli plan kabul edilir', YedekPlaniDenetle(P) = '');
  P.BaglantiAd := 'Ad"li';
  Kontrol('Cift tirnakli baglanti adi reddedilir', YedekPlaniDenetle(P) <> '');

  P.BaglantiAd := 'A & B <x>';
  P.Saat := '04:15';
  Kontrol('Gorev XML: saat, kacirilan calisir, ozel karakterler kacisli',
    (Pos('T04:15:00</StartBoundary>', YedekGorevXml(P)) > 0) and (Pos('<StartWhenAvailable>true', YedekGorevXml(P)) > 0) and
    (Pos('A &amp; B &lt;x&gt;', YedekGorevXml(P)) > 0) and (Pos('/yedek &quot;', YedekGorevXml(P)) > 0));
  Kontrol('Varsayilan klasor baglanti adini icerir', Pos('Muh', VarsayilanYedekKlasoru('Muh:asebe')) > 0);
  Kontrol('Varsayilan klasorde yasak karakter yok', Pos(':', Copy(VarsayilanYedekKlasoru('Muh:asebe'), 4, 200)) = 0);
end;

{ ---------- Windows Gorev Zamanlayici (gercek gorev, hemen kaldirilir) ---------- }

procedure GorevDene;
var
  P: TYedekPlani;
  Cumle, Ham: string;
begin
  P := Default(TYedekPlani);
  P.BaglantiAd := 'FMSTEST ' + FormatDateTime('yyyymmddhhnnss', Now) + ' & ozel';
  P.Klasor := TPath.Combine(GetEnvironmentVariable('TEMP'), 'yptest_yedek');
  P.Saat := '03:00';
  P.Sakla := 3;
  Kontrol('Gorev baslangicta yok', not YedekGorevVarMi(P.BaglantiAd));
  Kontrol('Gorev kurulur', YedekGoreviKur(P, Cumle, Ham));
  Cikti.Add('Kur: cumle=' + Cumle + ' ham=' + Trim(Ham));
  Kontrol('Gorev var', YedekGorevVarMi(P.BaglantiAd));
  Kontrol('Ayni gorev ikinci kez kurulunca yerine gecer', YedekGoreviKur(P, Cumle, Ham));
  Kontrol('Gorev kaldirilir', YedekGoreviKaldir(P.BaglantiAd, Cumle, Ham));
  Cikti.Add('Kaldir: cumle=' + Cumle + ' ham=' + Trim(Ham));
  Kontrol('Gorev artik yok', not YedekGorevVarMi(P.BaglantiAd));
  Kontrol('Olmayan gorevi kaldirmak anlasilir cumle verir', (not YedekGoreviKaldir(P.BaglantiAd, Cumle, Ham)) and (Cumle <> ''));
  P.Saat := '99:99';
  Kontrol('Gecersiz planda gorev kurulmaz', (not YedekGoreviKur(P, Cumle, Ham)) and (Cumle <> '') and
    not YedekGorevVarMi(P.BaglantiAd));
end;

{ ---------- Eski yedekleri tasima ---------- }

procedure EskiDene(const Kok: string);
var
  Klasor: string;
  i: Integer;
begin
  Klasor := TPath.Combine(Kok, 'eski_deneme');
  ForceDirectories(Klasor);
  for i := 1 to 5 do
    DosyaYaz(TPath.Combine(Klasor, 'T_2026010' + IntToStr(i) + '_000000.fbk'));
  DosyaYaz(TPath.Combine(Klasor, 'T_notlar.fbk'));
  DosyaYaz(TPath.Combine(Klasor, 'BASKA_20260101_000000.fbk'));
  DosyaYaz(TPath.Combine(Klasor, 'T_20260101_000000.txt'));
  Kontrol('Eski tasima: 5 yedekten 3 kalirsa 2 tasinir', EskiYedekleriTasi(Klasor, 'C:\Veri\T.fdb', 3) = 2);
  Kontrol('Klasorde 3 yedek kaldi', SayiDosya(Klasor, 'T_????????_??????.fbk') = 3);
  Kontrol('En eskiler Eski klasorune gitti (silinmedi)', TFile.Exists(TPath.Combine(Klasor, 'Eski\T_20260101_000000.fbk')) and
    TFile.Exists(TPath.Combine(Klasor, 'Eski\T_20260102_000000.fbk')));
  Kontrol('En yeni uc yedek yerinde', TFile.Exists(TPath.Combine(Klasor, 'T_20260105_000000.fbk')) and
    TFile.Exists(TPath.Combine(Klasor, 'T_20260103_000000.fbk')));
  Kontrol('Baska adli yedege ve yabanci dosyalara dokunulmadi', TFile.Exists(TPath.Combine(Klasor, 'T_notlar.fbk')) and
    TFile.Exists(TPath.Combine(Klasor, 'BASKA_20260101_000000.fbk')) and TFile.Exists(TPath.Combine(Klasor, 'T_20260101_000000.txt')));
  Kontrol('Ikinci calistirmada tasinacak yok', EskiYedekleriTasi(Klasor, 'C:\Veri\T.fdb', 3) = 0);
  Kontrol('Sakla buyukse hicbiri tasinmaz', EskiYedekleriTasi(Klasor, 'C:\Veri\T.fdb', 10) = 0);
  { Eski klasorde ayni ad varsa ezilmez }
  DosyaYaz(TPath.Combine(Klasor, 'T_20260101_000000.fbk'));
  Kontrol('Eski klasorde ayni adli dosya varsa ezilmez', (EskiYedekleriTasi(Klasor, 'C:\Veri\T.fdb', 3) = 1) and
    (SayiDosya(TPath.Combine(Klasor, 'Eski'), 'T_20260101_000000.fbk*') = 2));
  Kontrol('Klasor yoksa hata vermez', EskiYedekleriTasi(TPath.Combine(Kok, 'hic_olmayan_klasor'), 'C:\Veri\T.fdb', 3) = 0);
end;

{ ---------- Acilista uyari ---------- }

procedure UyariDene;
var
  Simdi: TDateTime;
  P: TYedekPlani;
  Uyarilar: TArray<string>;
  Dun, UcGunOnce: string;
begin
  Simdi := EncodeDate(2026, 11, 23) + EncodeTime(10, 0, 0, 0);
  Dun := '2026-11-22 02:00:00 | Muh | OK | Yedek alindi';
  UcGunOnce := '2026-11-20 02:00:00 | Muh | OK | Yedek alindi';
  Kontrol('Uyari: gunluk bos ise uyari yok', YedekGunlukUyarisi('Muh', '', Simdi) = '');
  Kontrol('Uyari: dunku basarili yedek uyari vermez', YedekGunlukUyarisi('Muh', Dun, Simdi) = '');
  Kontrol('Uyari: 3 gun onceki basarili yedek uyari verir (ad ve tarih icinde)',
    (Pos('Muh', YedekGunlukUyarisi('Muh', UcGunOnce, Simdi)) > 0) and (Pos('20.11.2026 02:00', YedekGunlukUyarisi('Muh', UcGunOnce, Simdi)) > 0));
  Kontrol('Uyari: son satir HATA ise uyari verir ve hata metni icinde',
    (Pos('disk dolu', YedekGunlukUyarisi('Muh', '2026-11-23 02:00:00 | Muh | HATA | Islem yapilamadi. disk dolu', Simdi)) > 0));
  Kontrol('Uyari: bozuk satir sessiz gecilir', YedekGunlukUyarisi('Muh', 'bozuk satir', Simdi) = '');
  Kontrol('Uyari: gecersiz tarih sessiz gecilir', YedekGunlukUyarisi('Muh', '2026-13-45 99:00:00 | Muh | OK | x', Simdi) = '');

  { Plan kayitli ama Windows gorevi yok: tek uyari }
  P := Default(TYedekPlani);
  P.BaglantiAd := 'gorevsiz_plan';
  P.Klasor := 'C:Y';
  P.Saat := '02:00';
  P.Sakla := 3;
  YedekPlaniKaydet(P);
  Uyarilar := YedekPlanlariniDenetle;
  Kontrol('Gorevi olmayan plan icin uyari var', (Length(Uyarilar) = 1) and (Pos('gorevsiz_plan', Uyarilar[0]) > 0));
  YedekPlaniSil(P.BaglantiAd);
  Kontrol('Plan yoksa uyari da yok', Length(YedekPlanlariniDenetle) = 0);
end;

{ ---------- Plani calistirma ---------- }

procedure CalistirDene(const Kok: string);
var
  Tanim: TBaglantiTanimi;
  Plan: TYedekPlani;
  Sonuc: TYedekSonucu;
  Klasor, Yol: string;
  Satirlar: TArray<string>;
  Bag: TAcikBaglanti;
  i: Integer;
  Hepsi: string;
begin
  { Plansiz baglanti }
  Kontrol('Plansiz baglantida calistirma basarisiz, cumle dolu', (not YedekPlaniCalistir('plani_yok', nil, Sonuc)) and (Sonuc.Cumle <> ''));
  Satirlar := YedekGunlugu('plani_yok', 10);
  Kontrol('Basarisizlik gunluge HATA olarak yazildi', (Length(Satirlar) = 1) and (Pos(' | HATA | ', Satirlar[0]) > 0));

  Klasor := TPath.Combine(Kok, 'yedekler');
  Yol := TPath.Combine(Ortam('FBTEST_KLASOR', TPath.Combine(GetEnvironmentVariable('TEMP'), 'yptest')),
    'yp_' + FormatDateTime('yyyymmdd_hhnnss', Now) + '.fdb');
  if Ortam('FBTEST_SUNUCU', '') = '' then
    ForceDirectories(ExtractFilePath(Yol));
  Tanim := Default(TBaglantiTanimi);
  Tanim.Ad := 'yptest';
  Tanim.Sunucu := Ortam('FBTEST_SUNUCU', '');
  Tanim.Port := StrToInt(Ortam('FBTEST_PORT', '3050'));
  Tanim.VeritabaniYolu := Yol;
  Tanim.Kullanici := Ortam('FBTEST_KULLANICI', 'SYSDBA');
  Tanim.Sifre := Ortam('FBTEST_SIFRE', '');
  Tanim.KarakterSeti := VARSAYILAN_KARAKTER_SETI;
  FbVeritabaniOlustur(Tanim);
  Bag := FbBaglan(Tanim);
  FbBaglantiyiKes(Bag);
  Cikti.Add('Gecici veritabani: ' + Yol);

  Plan := Default(TYedekPlani);
  Plan.BaglantiAd := Tanim.Ad;
  Plan.Klasor := Klasor;
  Plan.Saat := '02:00';
  Plan.Sakla := 2;
  YedekPlaniKaydet(Plan);

  { Sifresi kayitli degil }
  Tanim.SifreyiKaydet := False;
  BaglantiKaydet(Tanim);
  Kontrol('Sifresi kayitli olmayan baglantida anlasilir hata', (not YedekPlaniCalistir(Tanim.Ad, nil, Sonuc)) and
    (Sonuc.Cumle = T('ERR_YEDEKPLAN_SIFRE')));

  { Sifre kayitli: uc yedek, sakla=2 }
  Tanim.SifreyiKaydet := True;
  BaglantiKaydet(Tanim);
  for i := 1 to 3 do
  begin
    Kontrol('Plan ' + IntToStr(i) + '. kez calisti', YedekPlaniCalistir(Tanim.Ad, nil, Sonuc));
    Cikti.Add('  sonuc: ' + Sonuc.Dosya + ' | ' + Sonuc.Cumle);
    if i < 3 then
      Sleep(1200);
  end;
  Kontrol('Klasorde en cok 2 yedek var', SayiDosya(Klasor, '*.fbk') = 2);
  Kontrol('Fazla yedek Eski klasorune gitti', SayiDosya(TPath.Combine(Klasor, 'Eski'), '*.fbk') = 1);
  Kontrol('Yarim dosya kalmadi', SayiDosya(Klasor, '*.yarim*') = 0);
  Satirlar := YedekGunlugu(Tanim.Ad, 10);
  Hepsi := '';
  for i := 0 to High(Satirlar) do
    Hepsi := Hepsi + Satirlar[i] + #10;
  Kontrol('Gunlukte 1 HATA (sifresiz deneme) ve 3 OK satiri var', (Length(Satirlar) = 4) and (Pos(' | HATA | ', Satirlar[0]) > 0));
  Kontrol('Gunluk satirlari OK ve dosya adini iceriyor', (Pos(' | OK | ', Satirlar[3]) > 0) and (Pos('.fbk', Satirlar[3]) > 0));
  Kontrol('Gunlukte sifre yok', (Tanim.Sifre = '') or (Pos(Tanim.Sifre, Hepsi) = 0));
  Kontrol('YedekGunlugu son 2 satiri verir', Length(YedekGunlugu(Tanim.Ad, 2)) = 2);
  Kontrol('Gunluk baska baglantinin satirini karistirmaz', Length(YedekGunlugu('plani_yok', 10)) = 1);

  { Yanlis sifre: hata, gunluge HATA, mevcut yedekler bozulmaz }
  Tanim.Sifre := 'yanlis_sifre_xyz';
  BaglantiKaydet(Tanim);
  Kontrol('Yanlis sifrede basarisiz, anlasilir cumle', (not YedekPlaniCalistir(Tanim.Ad, nil, Sonuc)) and (Sonuc.Cumle <> ''));
  Cikti.Add('  yanlis sifre cumlesi: ' + Sonuc.Cumle);
  Kontrol('Basarisizlikta mevcut yedekler yerinde', SayiDosya(Klasor, '*.fbk') = 2);
  Satirlar := YedekGunlugu(Tanim.Ad, 10);
  Kontrol('Gunlukte son satir HATA', (Length(Satirlar) = 5) and (Pos(' | HATA | ', Satirlar[4]) > 0));
end;

var
  Kok, CiktiYolu: string;
begin
  Cikti := TStringList.Create;
  Hatalar := 0;
  try
    try
      DilYukle('tr');
      Kok := TPath.Combine(GetEnvironmentVariable('TEMP'), 'yptest_' + FormatDateTime('yyyymmdd_hhnnss', Now));
      ForceDirectories(Kok);
      VeriKlasoruAyarla(TPath.Combine(Kok, 'veri'));
      Cikti.Add('Gecici klasor: ' + Kok);
      PlanDene;
      GorevDene;
      EskiDene(Kok);
      UyariDene;
      CalistirDene(Kok);
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
