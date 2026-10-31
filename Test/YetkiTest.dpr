program YetkiTest;

{ Asama 3d-2 / 3d-3: yetkileri gorme, yetki verme ve geri alma (uYetki) testi (komut satiri).
  TabloYapiTest ile ayni kalip: GOMULU kipte kendi gecici veritabanini acar; SUNUCU kipte yazma YALNIZCA yerel sunucuda
  3052, 3053, 3054 portlarinda ve FBTEST_YAZMA=1 ile calisir (3050/3051'e kod yazmaz).
  Yetki verilen kullanici ve rol adlari veritabaninda olmak zorunda degildir (Firebird GRANT'ta denetlemez).
  Ortam degiskenleri: FBTEST_SUNUCU, FBTEST_PORT, FBTEST_YOL, FBTEST_KULLANICI, FBTEST_SIFRE, FBTEST_CIKTI, FBTEST_YAZMA.
  Cikis kodu: hata sayisi (0 = hepsi gecti). }

{$APPTYPE CONSOLE}

uses
  System.SysUtils, System.Classes, System.StrUtils, System.IOUtils, Data.DB,
  FireDAC.Stan.Intf, FireDAC.Stan.Option, FireDAC.Stan.Error, FireDAC.Comp.Client, FireDAC.Phys.FB,
  FireDAC.ConsoleUI.Wait,
  Vcl.Forms, Vcl.Controls,
  uDil, uBaglanti, uMetadata, uKullanici, uProsedur, uYetki, fYetkiVer, fYetkiler;

const
  TB = 'FBY_TEST_YTB';
  VW = 'FBY_TEST_YVW';
  PR = 'FBY_TEST_YPR';
  ROL = 'FBY_TEST_YROL';
  U1 = 'FBY_TEST_U1';
  U2 = 'FBY_TEST_U2';

var
  Cikti: TStringList;
  Hatalar, KontrolSayisi: Integer;
  Tanim: TBaglantiTanimi;
  Bag: TAcikBaglanti;
  Gomulu: Boolean;

function Ortam(const Ad, Varsayilan: string): string;
begin
  Result := GetEnvironmentVariable(Ad);
  if Result = '' then
    Result := Varsayilan;
end;

function TekSatirMetin(const Metin: string): string;
begin
  Result := Copy(StringReplace(StringReplace(Metin, #13, '', [rfReplaceAll]), #10, ' | ', [rfReplaceAll]), 1, 300);
end;

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

procedure GeciciVeritabaniOlustur(const T: TBaglantiTanimi);
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

procedure Yurut(const Sql: string);
var
  Sorgu: TFDQuery;
begin
  Sorgu := KomutHazirla(Bag, Sql);
  try
    Sorgu.ExecSQL;
  finally
    Sorgu.Free;
  end;
end;

procedure Dene(const Sql: string);
begin
  try
    Yurut(Sql);
  except
  end;
end;

procedure Temizle;
begin
  Dene('drop procedure ' + PR);
  Dene('drop view ' + VW);
  Dene('drop table ' + TB);
  Dene('drop role ' + ROL);
end;

{ Nesne penceresindeki satiri ada gore bulur; yoksa Bulundu False. }
function NesneSatiri(const Nesne: string; Tur: TYetkiNesnesi; const Ad: string; Hedef: TYetkiHedefi;
  out Satir: TNesneYetkisi): Boolean;
var
  Aday: TNesneYetkisi;
begin
  Result := False;
  Satir := Default(TNesneYetkisi);
  for Aday in NesneYetkileriOku(Bag, Nesne, Tur) do
    if SameText(Aday.Ad, Ad) and (Aday.Hedef = Hedef) then
    begin
      Satir := Aday;
      Exit(True);
    end;
end;

function KullaniciSatiri(const Ad: string; Hedef: TYetkiHedefi; const Nesne: string; out Satir: TKullaniciYetkisi): Boolean;
var
  Aday: TKullaniciYetkisi;
begin
  Result := False;
  Satir := Default(TKullaniciYetkisi);
  for Aday in KullaniciYetkileriOku(Bag, Ad, Hedef) do
    if Aday.Nesne = Nesne then
    begin
      Satir := Aday;
      Exit(True);
    end;
end;

function G(const Nesne: string; Tur: TYetkiNesnesi; Hedef: TYetkiHedefi; const Ad, Harfler: string;
  Verebilir: Boolean = False): TYetkiGirdisi;
begin
  Result := Default(TYetkiGirdisi);
  Result.Nesne := Nesne;
  Result.NesneTuru := Tur;
  Result.Hedef := Hedef;
  Result.Ad := Ad;
  Result.Harfler := Harfler;
  Result.Verebilir := Verebilir;
end;

procedure KurallarBolumu;
var
  Dil, Anahtar, Eksik: string;
  Anahtarlar: TArray<string>;
begin
  Cikti.Add('');
  Cikti.Add('=== A) Dil anahtarlari ===');
  Anahtarlar := ['ERR_YETKI_AD_BOS', 'ERR_YETKI_SECIM_BOS', 'ERR_YETKI_YOK_ALINACAK', 'YETKI_HERKES', 'ONAY_YETKI_VER',
    'ONAY_YETKI_AL', 'ONAY_YETKI_HERKES', 'ONAY_YETKI_SECENEK', 'MENU_YETKILER', 'KUL_YETKILER', 'YETKI_BASLIK_NESNE',
    'YETKI_BASLIK_KULLANICI', 'YETKI_BILGI_NESNE', 'YETKI_BILGI_KULLANICI', 'YETKI_SUTUN_YETKILI', 'YETKI_SUTUN_NESNE',
    'YETKI_SUTUN_TUR', 'YETKI_SUTUN_YETKILER', 'YETKI_SUTUN_VEREBILIR', 'YETKI_TUR_KULLANICI', 'YETKI_TUR_ROL',
    'YETKI_TUR_HERKES', 'YETKI_TUR_TABLO', 'YETKI_TUR_PROSEDUR', 'YETKI_TUR_ROL_UYELIK', 'YETKI_TUR_DIGER', 'BTN_YETKI_VER',
    'BTN_YETKI_AL', 'BTN_YETKI_HEPSI', 'YETKI_VER_BASLIK', 'YETKI_AL_BASLIK', 'YETKI_ETIKET_TUR', 'YETKI_ETIKET_AD',
    'YETKI_ETIKET_YETKILER', 'YETKI_ETIKET_SECENEK', 'ONAY_YETKI_HEPSI', 'MSG_YETKI_VAZGECILDI', 'MSG_YETKI_VERILDI',
    'MSG_YETKI_ALINDI', 'ERR_YETKI_VERILEMEDI', 'ERR_YETKI_ALINAMADI', 'MSG_YETKI_GERI_ALINDI'];
  for Dil in ['tr', 'en', 'de'] do
  begin
    DilYukle(Dil);
    Eksik := '';
    for Anahtar in Anahtarlar do
      if T(Anahtar) = Anahtar then
        Eksik := Eksik + ' ' + Anahtar;
    Kontrol('Dil ' + Dil + ': tum 3d-2/3d-3 anahtarlari tanimli', Eksik = '');
    if Eksik <> '' then
      Cikti.Add('      eksik:' + Eksik);
  end;
  DilYukle('tr');
end;

procedure YetkiBolumu;
var
  Sonuc: TProsedurSonucu;
  NS: TNesneYetkisi;
  KS: TKullaniciYetkisi;
  Komutlar: string;
begin
  Cikti.Add('');
  Cikti.Add('=== B) Yetki goruntule, ver, geri al (' + Bag.Surum + ') ===');
  { Arayuz duman testi: pencerelerin .dfm'leri hatasiz yuklenir (gosterilmez) }
  with TfrmYetkiVer.Create(nil) do
    Free;
  with TfrmYetkiler.Create(nil) do
    Free;
  Kontrol('Duman: yetki pencereleri olusuyor (dfm hatasi yok)', True);
  Temizle;
  Yurut('create table ' + TB + ' (ID integer not null primary key, AD varchar(30))');
  Yurut('create view ' + VW + ' as select ID, AD from ' + TB);
  Yurut('create procedure ' + PR + ' as begin end');
  Yurut('create role ' + ROL);

  { Dogrulama ve komutlar }
  Kontrol('Dogrula: harf secilmemis', YetkiDogrula(G(TB, ynTablo, yhKullanici, U1, '')) = T('ERR_YETKI_SECIM_BOS'));
  Kontrol('Dogrula: ad bos', YetkiDogrula(G(TB, ynTablo, yhKullanici, '', 'S')) = T('ERR_YETKI_AD_BOS'));
  Kontrol('Dogrula: PUBLIC icin ad gerekmez', YetkiDogrula(G(TB, ynTablo, yhHerkes, '', 'S')) = '');
  Kontrol('Komut: GRANT kullanici (harfler S I U D R sirasinda)',
    YetkiKomutu(Bag, yiVer, G(TB, ynTablo, yhKullanici, U1, 'IS')) = 'GRANT SELECT, INSERT ON ' + TB + ' TO USER ' + U1);
  Kontrol('Komut: GRANT rol ve WITH GRANT OPTION',
    YetkiKomutu(Bag, yiVer, G(TB, ynTablo, yhRol, ROL, 'S', True)) = 'GRANT SELECT ON ' + TB + ' TO ROLE ' + ROL +
    ' WITH GRANT OPTION');
  Kontrol('Komut: GRANT PUBLIC', YetkiKomutu(Bag, yiVer, G(TB, ynTablo, yhHerkes, '', 'S')) =
    'GRANT SELECT ON ' + TB + ' TO PUBLIC');
  Kontrol('Komut: REVOKE', YetkiKomutu(Bag, yiAl, G(TB, ynTablo, yhKullanici, U1, 'D')) =
    'REVOKE DELETE ON ' + TB + ' FROM USER ' + U1);
  Kontrol('Komut: prosedur EXECUTE', YetkiKomutu(Bag, yiVer, G(PR, ynProsedur, yhKullanici, U1, 'X')) =
    'GRANT EXECUTE ON PROCEDURE ' + PR + ' TO USER ' + U1);
  Kontrol('Onay: PUBLIC uyarisi var', Pos(T('ONAY_YETKI_HERKES'), YetkiOnayMetni(yiVer,
    G(TB, ynTablo, yhHerkes, '', 'S'), 'x')) > 0);
  Kontrol('Onay: GRANT OPTION uyarisi var', Pos(T('ONAY_YETKI_SECENEK'), YetkiOnayMetni(yiVer,
    G(TB, ynTablo, yhKullanici, U1, 'S', True), 'x')) > 0);

  { Ver: kullanici }
  Sonuc := YetkiUygula(Bag, yiVer, G(TB, ynTablo, yhKullanici, U1, 'SI'));
  Kontrol('Ver: kullaniciya SELECT, INSERT verildi', Sonuc.Basarili);
  if not Sonuc.Basarili then
    Cikti.Add('      ' + Sonuc.Cumle + ' | ' + TekSatirMetin(Sonuc.Ayrinti));
  Kontrol('Ver: SQL karsiligi donuyor', (Length(Sonuc.Komutlar) > 0) and (Pos('GRANT', UpperCase(Sonuc.Komutlar[0])) > 0));
  Kontrol('Oku: nesne penceresinde kullanici satiri', NesneSatiri(TB, ynTablo, U1, yhKullanici, NS));
  Kontrol('Oku: yetkiler "SELECT, INSERT"', NS.Yetkiler = 'SELECT, INSERT');
  Kontrol('Oku: harfler "SI", GRANT OPTION yok', (NS.Harfler = 'SI') and not NS.Verebilir);

  { Ver: rol, PUBLIC, grant option }
  Kontrol('Ver: role UPDATE', YetkiUygula(Bag, yiVer, G(TB, ynTablo, yhRol, ROL, 'U')).Basarili);
  Kontrol('Oku: rol satiri hedefi rol', NesneSatiri(TB, ynTablo, ROL, yhRol, NS) and (NS.Yetkiler = 'UPDATE'));
  Kontrol('Ver: PUBLIC SELECT', YetkiUygula(Bag, yiVer, G(TB, ynTablo, yhHerkes, '', 'S')).Basarili);
  Kontrol('Oku: PUBLIC satiri hedefi herkes', NesneSatiri(TB, ynTablo, 'PUBLIC', yhHerkes, NS) and (NS.Yetkiler = 'SELECT'));
  Kontrol('Ver: WITH GRANT OPTION', YetkiUygula(Bag, yiVer, G(TB, ynTablo, yhKullanici, U2, 'S', True)).Basarili);
  Kontrol('Oku: GRANT OPTION isaretli', NesneSatiri(TB, ynTablo, U2, yhKullanici, NS) and NS.Verebilir);

  { Kolon duzeyi yetki (elle verilir, pencere yalniz tablo duzeyini yonetir) goruntulenir }
  Yurut('grant update (AD) on ' + TB + ' to ' + U1);
  Kontrol('Oku: kolon yetkisi "UPDATE (AD)" olarak gorunur', NesneSatiri(TB, ynTablo, U1, yhKullanici, NS) and
    (Pos('UPDATE (AD)', NS.Yetkiler) > 0) and (NS.Harfler = 'SI'));

  { View ve prosedur }
  Kontrol('Ver: view SELECT', YetkiUygula(Bag, yiVer, G(VW, ynTablo, yhKullanici, U1, 'S')).Basarili);
  Kontrol('Oku: view yetkisi', NesneSatiri(VW, ynTablo, U1, yhKullanici, NS) and (NS.Yetkiler = 'SELECT'));
  Kontrol('Ver: prosedur EXECUTE', YetkiUygula(Bag, yiVer, G(PR, ynProsedur, yhKullanici, U1, 'X')).Basarili);
  Kontrol('Oku: prosedur EXECUTE', NesneSatiri(PR, ynProsedur, U1, yhKullanici, NS) and (NS.Yetkiler = 'EXECUTE'));

  { Kullanici penceresi }
  Kontrol('Kullanici: U1 tabloda SELECT, INSERT ve kolon UPDATE', KullaniciSatiri(U1, yhKullanici, TB, KS) and
    (Pos('SELECT, INSERT', KS.Yetkiler) = 1));
  Kontrol('Kullanici: U1 view ve prosedurde de', KullaniciSatiri(U1, yhKullanici, VW, KS) and
    KullaniciSatiri(U1, yhKullanici, PR, KS) and (KS.NesneTuru = OBJE_PROSEDUR));
  Kontrol('Kullanici: baska kullanicinin (U2) yetkisi karismaz', not KullaniciSatiri(U2, yhKullanici, PR, KS));
  Kontrol('Kullanici: rol yetkileri rol olarak okunur', KullaniciSatiri(ROL, yhRol, TB, KS) and (KS.Yetkiler = 'UPDATE'));

  { Geri al }
  Kontrol('Al: INSERT geri alindi', YetkiUygula(Bag, yiAl, G(TB, ynTablo, yhKullanici, U1, 'I')).Basarili);
  Kontrol('Oku: INSERT gitti, SELECT kaldi', NesneSatiri(TB, ynTablo, U1, yhKullanici, NS) and (NS.Harfler = 'S'));
  Sonuc := YetkiUygula(Bag, yiAl, G(TB, ynTablo, yhKullanici, U1, 'D'));
  Cikti.Add('      verilmemis yetkiyi alma: basarili=' + BoolToStr(Sonuc.Basarili, True) + ' cumle=' + TekSatirMetin(Sonuc.Cumle) +
    ' ayrinti=' + TekSatirMetin(Sonuc.Ayrinti));
  Kontrol('Al: verilmemis yetkiyi alma hata cumlesi anlasilir ya da sessizce gecer',
    Sonuc.Basarili or ((Sonuc.Cumle <> '') and (Sonuc.Cumle <> T('ERR_GENEL'))));

  { Hepsini geri al: rol uyeligi kalir }
  Yurut('grant ' + ROL + ' to ' + U1);
  Komutlar := HepsiniAlKomutlari(Bag, U1, yhKullanici);
  Kontrol('Hepsini al: komutlar tablo, view, prosedur icin',
    (Pos('REVOKE ALL ON ' + TB, Komutlar) > 0) and (Pos('REVOKE ALL ON ' + VW, Komutlar) > 0) and
    (Pos('REVOKE EXECUTE ON PROCEDURE ' + PR, Komutlar) > 0));
  Kontrol('Hepsini al: rol uyeligine dokunmaz', Pos(ROL, Komutlar) = 0);
  Sonuc := HepsiniAlUygula(Bag, U1, yhKullanici);
  if not Sonuc.Basarili then
    Cikti.Add('      ' + Sonuc.Cumle + ' | ' + TekSatirMetin(Sonuc.Ayrinti));
  Kontrol('Hepsini al: uygulandi', Sonuc.Basarili);
  Kontrol('Hepsini al: U1 artik tablo, view, prosedurde yetkisiz', not KullaniciSatiri(U1, yhKullanici, TB, KS) and
    not KullaniciSatiri(U1, yhKullanici, VW, KS) and not KullaniciSatiri(U1, yhKullanici, PR, KS));
  Kontrol('Hepsini al: rol uyeligi (ROL) duruyor', KullaniciSatiri(U1, yhKullanici, ROL, KS) and (KS.NesneTuru = OBJE_ROL));
  Kontrol('Hepsini al: U2 ve PUBLIC yetkisi etkilenmedi', NesneSatiri(TB, ynTablo, U2, yhKullanici, NS) and
    NesneSatiri(TB, ynTablo, 'PUBLIC', yhHerkes, NS));
  Sonuc := HepsiniAlUygula(Bag, 'FBY_TEST_YOKTUR', yhKullanici);
  Kontrol('Hepsini al: yetkisi olmayan kullanicida anlasilir cumle, veritabanina dokunulmaz',
    (not Sonuc.Basarili) and (Sonuc.Cumle = T('ERR_YETKI_YOK_ALINACAK')) and (Length(Sonuc.Komutlar) = 0));

  { Hata cumlesi: nesne yok }
  Sonuc := YetkiUygula(Bag, yiVer, G('FBY_TEST_OLMAYAN_NESNE', ynTablo, yhKullanici, U1, 'S'));
  Cikti.Add('      olmayan nesne cumlesi: ' + TekSatirMetin(Sonuc.Cumle) + ' | ' + TekSatirMetin(Sonuc.Ayrinti));
  Kontrol('Hata: olmayan nesneye yetki verilemez, anlasilir cumle (ERR_GENEL degil)',
    (not Sonuc.Basarili) and (Sonuc.Cumle <> '') and (Sonuc.Cumle <> T('ERR_GENEL')));
end;

var
  YazmaIstendi, YazmaIzni, KendiVeritabanim: Boolean;
  Neden, Klasor: string;
begin
  Cikti := TStringList.Create;
  Bag := nil;
  KendiVeritabanim := False;
  try
    try
      DilYukle('tr');
      Tanim.Ad := 'yetki_test';
      Tanim.Sunucu := Ortam('FBTEST_SUNUCU', '');
      Tanim.Port := StrToInt(Ortam('FBTEST_PORT', '3050'));
      Tanim.VeritabaniYolu := Ortam('FBTEST_YOL', '');
      Tanim.Kullanici := Ortam('FBTEST_KULLANICI', 'SYSDBA');
      Tanim.Sifre := Ortam('FBTEST_SIFRE', '');
      if (Tanim.Sunucu = '') and (Tanim.Sifre = '') then
        Tanim.Sifre := 'masterkey';
      Tanim.KarakterSeti := VARSAYILAN_KARAKTER_SETI;
      Gomulu := Tanim.Sunucu = '';
      YazmaIstendi := Ortam('FBTEST_YAZMA', '') = '1';
      if Gomulu and (Tanim.VeritabaniYolu = '') then
      begin
        Klasor := TPath.Combine(GetEnvironmentVariable('TEMP'), 'yetkitest');
        ForceDirectories(Klasor);
        Tanim.VeritabaniYolu := TPath.Combine(Klasor, 'test_' + FormatDateTime('yyyymmdd_hhnnss', Now) + '.fdb');
        GeciciVeritabaniOlustur(Tanim);
        KendiVeritabanim := True;
      end;
      if Tanim.VeritabaniYolu = '' then
        raise Exception.Create('FBTEST_YOL bos: sunucudaki var olan bir veritabani yolu verin.');
      YazmaIzni := False;
      Neden := '';
      if Gomulu then
        YazmaIzni := KendiVeritabanim
      else if not YazmaIstendi then
        Neden := 'FBTEST_YAZMA=1 verilmedi'
      else if not YerelSunucuMu(Tanim.Sunucu) then
        Neden := 'yazma yalniz yerel test sunucusunda serbest'
      else if (Tanim.Port = 3052) or (Tanim.Port = 3053) or (Tanim.Port = 3054) then
        YazmaIzni := True
      else
        Neden := 'port ' + IntToStr(Tanim.Port) + ': yazma YALNIZ 3052, 3053 ve 3054 portunda serbest';
      Cikti.Add('YetkiTest  ' + FormatDateTime('yyyy-mm-dd hh:nn:ss', Now));
      Cikti.Add('Sunucu: ' + IfThen(Gomulu, '(gomulu)', Tanim.Sunucu + ':' + IntToStr(Tanim.Port)));
      Cikti.Add('Yazma bolumu: ' + IfThen(YazmaIzni, 'ACIK', 'KAPALI - ' + Neden));
      KurallarBolumu;
      if YazmaIzni then
      begin
        Bag := FbBaglan(Tanim);
        try
          YetkiBolumu;
        finally
          Temizle;
        end;
      end;
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
    Cikti.SaveToFile(Ortam('FBTEST_CIKTI', 'yetkitest.txt'), TEncoding.UTF8);
  finally
    Cikti.Free;
  end;
  ExitCode := Hatalar;
end.
