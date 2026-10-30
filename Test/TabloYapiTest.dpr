program TabloYapiTest;

{ Asama 3g-1: tablo yapi sekmesinin okuma yordamlari (index, kisit, bagimlilik; uMetadata) testi (komut satiri).
  NesneYonetimTest ile ayni kalip: GOMULU kipte kendi gecici veritabanini acar; SUNUCU kipte yazma YALNIZCA yerel
  sunucuda 3052, 3053, 3054 portlarinda ve FBTEST_YAZMA=1 ile calisir (3050/3051'e kod yazmaz).
  Ortam degiskenleri: FBTEST_SUNUCU, FBTEST_PORT, FBTEST_YOL, FBTEST_KULLANICI, FBTEST_SIFRE, FBTEST_CIKTI, FBTEST_YAZMA.
  Cikis kodu: hata sayisi (0 = hepsi gecti). }

{$APPTYPE CONSOLE}

uses
  System.SysUtils, System.Classes, System.StrUtils, System.IOUtils, Data.DB,
  FireDAC.Stan.Intf, FireDAC.Stan.Option, FireDAC.Stan.Error, FireDAC.Comp.Client, FireDAC.Phys.FB,
  FireDAC.ConsoleUI.Wait,
  uDil, uBaglanti, uMetadata, uKullanici, uDDL, uProsedur, uNesneYonet, uKolon;

const
  ANA = 'FBY_TEST_ANA';
  ALT = 'FBY_TEST_ALT';
  VW = 'FBY_TEST_VWA';
  TRG = 'FBY_TEST_TRGA';

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
  Dene('drop trigger ' + TRG);
  Dene('drop view ' + VW);
  Dene('drop table ' + ALT);
  Dene('drop table ' + ANA);
end;

{ Bellek tablosunda Alan = Deger olan satir var mi. }
function SatirVar(Tablo: TDataSet; const Alan, Deger: string): Boolean;
begin
  Result := False;
  Tablo.First;
  while not Tablo.Eof do
  begin
    if Tablo.FieldByName(Alan).AsString = Deger then
      Exit(True);
    Tablo.Next;
  end;
end;

function Birlesik(Tablo: TDataSet; const Alan: string): string;
begin
  Result := '';
  Tablo.First;
  while not Tablo.Eof do
  begin
    Result := Result + Tablo.FieldByName(Alan).AsString + '|';
    Tablo.Next;
  end;
end;

procedure KurallarBolumu;
var
  Dil, Anahtar, Eksik: string;
  Anahtarlar: TArray<string>;
begin
  Cikti.Add('');
  Cikti.Add('=== A) Dil anahtarlari ===');
  Anahtarlar := ['LBL_INDEKSLER', 'LBL_KISITLAR', 'LBL_BAGIMLILIKLAR', 'YAPI_AD', 'YAPI_TUR', 'YAPI_KOLONLAR',
    'YAPI_BENZERSIZ', 'YAPI_YON', 'YAPI_DURUM', 'YAPI_DETAY', 'INDEKS_AKTIF', 'INDEKS_PASIF', 'KISIT_PK',
    'KISIT_UNIQUE', 'KISIT_FK', 'KISIT_CHECK', 'BAG_TUR_FK_KULLANAN', 'BAG_TUR_FK_HEDEF', 'MENU_BAGIMLILIKLAR',
    'BTN_KOLON_EKLE', 'BTN_KOLON_AD', 'BTN_KOLON_DEGISTIR', 'BTN_KOLON_SIL', 'KOLON_BASLIK_EKLE', 'KOLON_BASLIK_AD',
    'KOLON_BASLIK_DEGISTIR', 'KOLON_BASLIK_SIL', 'KOLON_ETIKET_AD', 'KOLON_ETIKET_TIP', 'KOLON_ETIKET_VARSAYILAN',
    'KOLON_ETIKET_BOS_OLMAZ', 'KOLON_ETIKET_KOMUT', 'KOLON_SIL_NOT', 'KOLON_NULL_YOK_25', 'ERR_KOLON_HESAPLANAN',
    'ERR_KOLON_AD_BOS', 'ERR_KOLON_TIP_BOS', 'ERR_KOLON_DEGISIKLIK_YOK', 'ONAY_KOLON', 'ONAY_KOLON_VERI_RISKI',
    'ONAY_KOLON_KULLANANLAR', 'ONAY_KOLON_YEDEK', 'MSG_KOLON_VAZGECILDI', 'MSG_KOLON_TAMAM', 'ERR_KOLON_UYGULANAMADI',
    'MSG_KOLON_GERI_ALINDI', 'BAG_TUR_KISIT', 'BAG_TUR_INDEKS', 'TBL_YEDEK_BASLIK'];
  for Dil in ['tr', 'en', 'de'] do
  begin
    DilYukle(Dil);
    Eksik := '';
    for Anahtar in Anahtarlar do
      if T(Anahtar) = Anahtar then
        Eksik := Eksik + ' ' + Anahtar;
    Kontrol('Dil ' + Dil + ': tum 3g-1 anahtarlari tanimli', Eksik = '');
    if Eksik <> '' then
      Cikti.Add('      eksik:' + Eksik);
  end;
  DilYukle('tr');
end;

procedure YapiBolumu;
var
  Sahip: TComponent;
  Indeks, Kisit, Bagim: TDataSet;
begin
  Cikti.Add('');
  Cikti.Add('=== B) Yapi okuma (' + Bag.Surum + ') ===');
  Temizle;
  Yurut('create table ' + ANA + ' (ID integer not null primary key, AD varchar(30), KOD varchar(10) not null, ' +
    'constraint FBY_TEST_UQ unique (KOD), check (ID > 0))');
  Yurut('create table ' + ALT + ' (ID integer not null primary key, ANA_ID integer, ' +
    'foreign key (ANA_ID) references ' + ANA + ' (ID) on delete cascade)');
  Yurut('create index FBY_TEST_IDX_AD on ' + ANA + ' (AD)');
  Yurut('create descending index FBY_TEST_IDX_KOD_D on ' + ANA + ' (KOD)');
  Yurut('create view ' + VW + ' as select ID, AD from ' + ANA);
  Sahip := TComponent.Create(nil);
  try
    Indeks := IndeksTablosuOlustur(Bag, ANA, Sahip);
    Kontrol('Index: yalniz kisit disi 2 index gelir (PK ve UNIQUE indexi yok)', Indeks.RecordCount = 2);
    Kontrol('Index: ad var', SatirVar(Indeks, 'AD', 'FBY_TEST_IDX_AD'));
    Indeks.Locate('AD', 'FBY_TEST_IDX_KOD_D', []);
    Kontrol('Index: DESC yonu', Indeks.FieldByName('YON').AsString = 'DESC');
    Kontrol('Index: kolon adi', Indeks.FieldByName('KOLONLAR').AsString = 'KOD');
    Kontrol('Index: aktif', Indeks.FieldByName('DURUM').AsString = T('INDEKS_AKTIF'));
    Yurut('alter index FBY_TEST_IDX_AD inactive');
    Indeks := IndeksTablosuOlustur(Bag, ANA, Sahip);
    Indeks.Locate('AD', 'FBY_TEST_IDX_AD', []);
    Kontrol('Index: pasif yapilinca Durum pasif', Indeks.FieldByName('DURUM').AsString = T('INDEKS_PASIF'));

    Kisit := KisitTablosuOlustur(Bag, ANA, Sahip);
    Kontrol('Kisit (ANA): PK + UNIQUE + CHECK = 3 satir', Kisit.RecordCount = 3);
    Kontrol('Kisit (ANA): UNIQUE adi', SatirVar(Kisit, 'AD', 'FBY_TEST_UQ'));
    Kontrol('Kisit (ANA): PK sistem adi (gercek ad) gorunur', Pos('INTEG_', Birlesik(Kisit, 'AD')) > 0);
    Kontrol('Kisit (ANA): CHECK metni', Pos('ID > 0', Birlesik(Kisit, 'DETAY')) > 0);
    Kisit := KisitTablosuOlustur(Bag, ALT, Sahip);
    Kisit.Locate('TUR', T('KISIT_FK'), []);
    Kontrol('Kisit (ALT): FK hedefi', Pos(ANA + ' (ID)', Kisit.FieldByName('DETAY').AsString) > 0);
    Kontrol('Kisit (ALT): FK ON DELETE CASCADE', Pos('ON DELETE CASCADE', Kisit.FieldByName('DETAY').AsString) > 0);
    Kontrol('Kisit (ALT): FK kolonu', Kisit.FieldByName('KOLONLAR').AsString = 'ANA_ID');

    Bagim := BagimlilikTablosuOlustur(Bag, ANA, Sahip);
    Kontrol('Bagimlilik (ANA): view var', SatirVar(Bagim, 'AD', VW));
    Kontrol('Bagimlilik (ANA): FK ile bagli tablo ALT', Pos(ALT + ' (', Birlesik(Bagim, 'AD')) > 0);
    Bagim := BagimlilikTablosuOlustur(Bag, ALT, Sahip);
    Kontrol('Bagimlilik (ALT): FK hedefi ANA', Pos(ANA + ' (', Birlesik(Bagim, 'AD')) > 0);
    Kontrol('Bagimlilik (ALT): turu yazisi', Pos(T('BAG_TUR_FK_HEDEF'), Birlesik(Bagim, 'TUR')) > 0);
  finally
    Sahip.Free;
  end;
end;

{ Kolon islemini uKolon ile uygular (pencere ve onay yok). Eski, mevcut kolondan okunur. }
function KolonUygula_(Islem: TKolonIslemi; const Kolon, YeniAd, Tip, Varsayilan: string; BosOlmaz: Boolean;
  out Eski, Yeni: TKolonGirdisi): TProsedurSonucu;
begin
  if Islem = kiEkle then
  begin
    Eski := Default(TKolonGirdisi);
    Eski.Islem := kiEkle;
    Eski.Tablo := ANA;
  end
  else
    Eski := KolonGirdisiOku(Bag, ANA, Kolon, Islem);
  Yeni := Eski;
  if Islem in [kiEkle, kiAd] then
    Yeni.YeniAd := YeniAd;
  if Islem in [kiEkle, kiDegistir] then
  begin
    Yeni.Tip := Tip;
    Yeni.Varsayilan := Varsayilan;
    Yeni.BosOlmaz := BosOlmaz;
  end;
  Result := KolonUygula(Bag, Eski, Yeni);
end;

function KolonVarMi(const Kolon: string): Boolean;
var
  Bilgi: TKolonBilgisi;
begin
  Result := False;
  for Bilgi in KolonlariOku(Bag, ANA) do
    if Bilgi.Ad = Kolon then
      Exit(True);
end;

function YedekIcerigi: string;
var
  Dosyalar: TArray<string>;
begin
  Result := '';
  Dosyalar := TDirectory.GetFiles(ProsedurYedekKlasoru(Tanim.Ad), 'tablo_' + ANA + '_*.sql');
  if Length(Dosyalar) > 0 then
    Result := TFile.ReadAllText(Dosyalar[High(Dosyalar)], TEncoding.Default);
end;

procedure KolonBolumu;
var
  Eski, Yeni: TKolonGirdisi;
  Sonuc: TProsedurSonucu;
  Komutlar, Metin: string;
begin
  Cikti.Add('');
  Cikti.Add('=== C) Kolon islemleri (' + Bag.Surum + ') ===');
  Temizle;
  Yurut('create table ' + ANA + ' (ID integer not null primary key, AD varchar(30), KOD varchar(10) not null, ' +
    'constraint FBY_TEST_UQ unique (KOD))');
  Yurut('insert into ' + ANA + ' (ID, AD, KOD) values (1, ''a'', ''k1'')');
  Yurut('insert into ' + ANA + ' (ID, AD, KOD) values (2, ''b'', ''k2'')');
  Yurut('insert into ' + ANA + ' (ID, AD, KOD) values (3, ''c'', ''k3'')');
  Yurut('create view ' + VW + ' as select ID, AD from ' + ANA);

  { Dogrulama ve "degisiklik yok" }
  Eski := Default(TKolonGirdisi);
  Eski.Islem := kiEkle;
  Eski.Tablo := ANA;
  Kontrol('Dogrula: bos kolon adi reddedilir', KolonGirdisiniDogrula(Eski) = T('ERR_KOLON_AD_BOS'));
  Eski.YeniAd := 'x';
  Kontrol('Dogrula: bos tip reddedilir', KolonGirdisiniDogrula(Eski) = T('ERR_KOLON_TIP_BOS'));
  Eski := KolonGirdisiOku(Bag, ANA, 'AD', kiDegistir);
  Kontrol('Oku: tip dolu (VARCHAR)', Pos('VARCHAR', UpperCase(Eski.Tip)) > 0);
  Sonuc := KolonUygula(Bag, Eski, Eski);
  Kontrol('Degisiklik yok: komut yok cumlesi, veritabanina dokunulmaz', (not Sonuc.Basarili) and
    (Sonuc.Cumle = T('ERR_KOLON_DEGISIKLIK_YOK')) and (Length(Sonuc.Komutlar) = 0));

  { Ekle }
  Sonuc := KolonUygula_(kiEkle, '', 'ZZ1', 'INTEGER', 'DEFAULT 5', True, Eski, Yeni);
  Kontrol('Ekle: NOT NULL DEFAULT kolon eklendi', Sonuc.Basarili);
  if not Sonuc.Basarili then
    Cikti.Add('      ' + Sonuc.Cumle + ' | ' + TekSatirMetin(Sonuc.Ayrinti));
  Kontrol('Ekle: kolon var', KolonVarMi('ZZ1'));
  Kontrol('Ekle: yedek dosyasi yazildi, CREATE TABLE ve veri-yedeklenmedi notu var',
    (Pos('CREATE TABLE', UpperCase(YedekIcerigi)) > 0) and (Pos(T('TBL_YEDEK_BASLIK'), YedekIcerigi) > 0));
  Sonuc := KolonUygula_(kiEkle, '', 'ZZ2', 'VARCHAR(20)', '', False, Eski, Yeni);
  Kontrol('Ekle: bos olabilen kolon eklendi', Sonuc.Basarili and KolonVarMi('ZZ2'));

  { Ad }
  Sonuc := KolonUygula_(kiAd, 'ZZ2', 'ZZ3', '', '', False, Eski, Yeni);
  Kontrol('Ad: ZZ2 -> ZZ3', Sonuc.Basarili and KolonVarMi('ZZ3') and not KolonVarMi('ZZ2'));

  { Degistir: tip + varsayilan (+ NOT NULL, yalniz 3.0+) }
  Yurut('update ' + ANA + ' set ZZ3 = ''x''');
  Sonuc := KolonUygula_(kiDegistir, 'ZZ3', '', 'VARCHAR(40)', 'DEFAULT ''abc''', False, Eski, Yeni);
  Kontrol('Degistir: tip VARCHAR(40) ve varsayilan', Sonuc.Basarili);
  if not Sonuc.Basarili then
    Cikti.Add('      ' + Sonuc.Cumle + ' | ' + TekSatirMetin(Sonuc.Ayrinti));
  Eski := KolonGirdisiOku(Bag, ANA, 'ZZ3', kiDegistir);
  Kontrol('Degistir: yeni tip okunur', Pos('40', Eski.Tip) > 0);
  Kontrol('Degistir: varsayilan okunur', Pos('abc', Eski.Varsayilan) > 0);
  Yeni := Eski;
  Yeni.BosOlmaz := True;
  Komutlar := KolonKomutlari(Bag, Eski, Yeni);
  if KolonNullDegistirilebilir(Bag) then
  begin
    Kontrol('NOT NULL (3.0+): komutta SET NOT NULL', Pos('SET NOT NULL', Komutlar) > 0);
    Sonuc := KolonUygula(Bag, Eski, Yeni);
    Kontrol('NOT NULL (3.0+): uygulandi', Sonuc.Basarili);
    Kontrol('NOT NULL (3.0+): kolon NOT NULL oldu', KolonGirdisiOku(Bag, ANA, 'ZZ3', kiDegistir).BosOlmaz);
  end
  else
    Kontrol('NOT NULL (2.5): komut uretilmez (surum kurali)', Komutlar = '');
  Eski := KolonGirdisiOku(Bag, ANA, 'ZZ3', kiDegistir);
  Yeni := Eski;
  Yeni.Varsayilan := '';
  Kontrol('Varsayilan kaldirma: DROP DEFAULT komutu', Pos('DROP DEFAULT', KolonKomutlari(Bag, Eski, Yeni)) > 0);

  { Hesaplanan kolon }
  Yurut('alter table ' + ANA + ' add ZZH computed by (ID * 2)');
  try
    KolonGirdisiOku(Bag, ANA, 'ZZH', kiDegistir);
    Kontrol('Hesaplanan kolon: degistirme reddedilir', False);
  except
    on E: EMetadataHatasi do
      Kontrol('Hesaplanan kolon: degistirme reddedilir (' + E.Message + ')', E.Message = T('ERR_KOLON_HESAPLANAN'));
  end;

  { Veri riski ve bagimlilik onayi }
  Eski := KolonGirdisiOku(Bag, ANA, 'AD', kiSil);
  Yeni := Eski;
  Metin := KolonOnayMetni(Bag, Eski, Yeni, KolonKomutlari(Bag, Eski, Yeni));
  Kontrol('Onay (sil): satir sayisi yazili', Pos(TF('ONAY_KOLON_VERI_RISKI', [3]), Metin) > 0);
  Kontrol('Onay (sil): kolonu kullanan view listelenir', Pos(VW, Metin) > 0);
  Kontrol('Onay (sil): yedek bilgisi', Pos(T('ONAY_KOLON_YEDEK'), Metin) > 0);

  { Bagimli view yuzunden silinemez: rollback, kolon yerinde }
  Sonuc := KolonUygula(Bag, Eski, Yeni);
  Kontrol('Sil (bagimli view var): reddedilir, anlasilir cumle, komut gorunur',
    (not Sonuc.Basarili) and (Sonuc.Cumle <> '') and (Length(Sonuc.Komutlar) > 0) and KolonVarMi('AD'));
  Cikti.Add('      cumle: ' + TekSatirMetin(Sonuc.Cumle));
  Cikti.Add('      ayrinti: ' + TekSatirMetin(Sonuc.Ayrinti));
  Kontrol('Sil (bagimli view var): cumle bagimlilik cumlesi', Sonuc.Cumle = T('ERR_NESNE_BAGIMLI'));

  { Bagimsiz kolon silinir }
  Sonuc := KolonUygula_(kiSil, 'ZZ1', '', '', '', False, Eski, Yeni);
  Kontrol('Sil: ZZ1 silindi', Sonuc.Basarili and not KolonVarMi('ZZ1'));
  Kontrol('Sil: SQL karsiligi ALTER TABLE ... DROP', (Length(Sonuc.Komutlar) > 0) and (Pos('DROP', UpperCase(Sonuc.Komutlar[0])) > 0));
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
      Tanim.Ad := 'yapi_test';
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
        Klasor := TPath.Combine(GetEnvironmentVariable('TEMP'), 'yapitest');
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
      Cikti.Add('TabloYapiTest  ' + FormatDateTime('yyyy-mm-dd hh:nn:ss', Now));
      Cikti.Add('Sunucu: ' + IfThen(Gomulu, '(gomulu)', Tanim.Sunucu + ':' + IntToStr(Tanim.Port)));
      Cikti.Add('Yazma bolumu: ' + IfThen(YazmaIzni, 'ACIK', 'KAPALI - ' + Neden));
      if TDirectory.Exists(TPath.Combine(GetEnvironmentVariable('TEMP'), 'yapitest_veri')) then
        TDirectory.Delete(TPath.Combine(GetEnvironmentVariable('TEMP'), 'yapitest_veri'), True);
      VeriKlasoruAyarla(TPath.Combine(GetEnvironmentVariable('TEMP'), 'yapitest_veri'));
      KurallarBolumu;
      if YazmaIzni then
      begin
        Bag := FbBaglan(Tanim);
        try
          YapiBolumu;
          KolonBolumu;
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
    Cikti.SaveToFile(Ortam('FBTEST_CIKTI', 'yapitest.txt'), TEncoding.UTF8);
  finally
    Cikti.Free;
  end;
  ExitCode := Hatalar;
end.
