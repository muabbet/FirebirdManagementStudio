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
  Vcl.Forms, Vcl.Controls,
  uDil, uBaglanti, uMetadata, uKullanici, uDDL, uProsedur, uNesneYonet, uKolon, uIndeksKisit, fProsedurSekme;

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
    'MSG_KOLON_GERI_ALINDI', 'BAG_TUR_KISIT', 'BAG_TUR_INDEKS', 'TBL_YEDEK_BASLIK', 'BTN_INDEKS_OLUSTUR', 'BTN_INDEKS_SIL',
    'BTN_INDEKS_DURUM', 'BTN_KISIT_EKLE', 'BTN_KISIT_SIL', 'YAPI_BASLIK_INDEKS', 'YAPI_BASLIK_KISIT', 'YAPI_ETIKET_TUR',
    'YAPI_ETIKET_AD_INDEKS', 'YAPI_ETIKET_AD_KISIT', 'YAPI_ETIKET_KOLONLAR', 'YAPI_ETIKET_HEDEF', 'YAPI_ETIKET_HEDEF_KOLON',
    'YAPI_ETIKET_SIL', 'YAPI_ETIKET_GUNCELLE', 'YAPI_ETIKET_IFADE', 'YAPI_ETIKET_BENZERSIZ', 'YAPI_ETIKET_AZALAN',
    'YAPI_KURAL_VARSAYILAN', 'ERR_INDEKS_AD_BOS', 'ERR_YAPI_KOLON_BOS', 'ERR_KISIT_HEDEF_BOS', 'ERR_KISIT_IFADE_BOS',
    'ONAY_KISIT_FK_KULLANANLAR', 'ERR_YAPI_TEKRAR', 'ERR_YAPI_YETIM', 'ERR_PK_VAR', 'ERR_KISIT_FK_BAGLI',
    'ONAY_KISIT_CHECK_NOT', 'MENU_YENI_TABLO', 'TUR_TABLO', 'TBL_YENI_SEKME', 'TBL_YENI_BILGI', 'ONAY_TBL_YENI',
    'ERR_TBL_YENI_BASLIK_YOK', 'MSG_TBL_YENI_ACILDI', 'MSG_TBL_OLUSTURULDU', 'ERR_TBL_OLUSTURULAMADI', 'ONAY_SIL_TABLO_VERI',
    'SIL_TABLO_AD_BASLIK', 'SIL_TABLO_AD_ETIKET', 'ERR_SIL_TABLO_AD_UYMADI', 'ERR_TABLO_FK_BAGLI'];
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

const
  ALT2 = 'FBY_TEST_ALT2';

function KisitVarMi(Tablo, Ad: string): Boolean;
var
  Bilgi: TKisitBilgisi;
begin
  Result := False;
  for Bilgi in KisitlariOku(Bag, Tablo) do
    if Bilgi.GercekAd = Ad then
      Exit(True);
end;

function IndeksVarMi(Ad: string): Boolean;
var
  Bilgi: TIndeksBilgisi;
begin
  Result := False;
  for Bilgi in IndeksleriOku(Bag, ANA) do
    if Bilgi.Ad = Ad then
      Exit(True);
end;

function IndeksG(const Ad, Kolonlar: string; Benzersiz, Azalan: Boolean): TIndeksGirdisi;
begin
  Result := Default(TIndeksGirdisi);
  Result.Tablo := ANA;
  Result.Ad := Ad;
  Result.Kolonlar := Kolonlar;
  Result.Benzersiz := Benzersiz;
  Result.Azalan := Azalan;
end;

function KisitG(Tur: TKisitTuru; const Ad, Kolonlar: string): TKisitGirdisi;
begin
  Result := Default(TKisitGirdisi);
  Result.Tablo := ANA;
  Result.Tur := Tur;
  Result.Ad := Ad;
  Result.Kolonlar := Kolonlar;
end;

{ Reddedilmesi beklenen islem: basarisiz, genel hata cumlesi DEGIL, rollback (komut gorunur). Cumle ve ayrinti rapora yazilir. }
procedure Reddedilir(const Ad: string; const Sonuc: TProsedurSonucu);
begin
  Cikti.Add('      [' + Ad + '] cumle: ' + TekSatirMetin(Sonuc.Cumle));
  Cikti.Add('      [' + Ad + '] ayrinti: ' + TekSatirMetin(Sonuc.Ayrinti));
  Kontrol(Ad + ': reddedildi, anlasilir cumle (ERR_GENEL degil)',
    (not Sonuc.Basarili) and (Sonuc.Cumle <> '') and (Sonuc.Cumle <> T('ERR_GENEL')) and (Length(Sonuc.Komutlar) > 0));
end;

procedure IndeksKisitBolumu;
var
  Sonuc: TProsedurSonucu;
  G: TKisitGirdisi;
  Bilgi: TKisitBilgisi;
  PkAd: string;
begin
  Cikti.Add('');
  Cikti.Add('=== D) Index ve kisit islemleri (' + Bag.Surum + ') ===');
  Dene('drop table ' + ALT2);
  Temizle;
  Yurut('create table ' + ANA + ' (ID integer not null primary key, AD varchar(30), KOD varchar(10) not null)');
  Yurut('insert into ' + ANA + ' (ID, AD, KOD) values (1, ''a'', ''k1'')');
  Yurut('insert into ' + ANA + ' (ID, AD, KOD) values (2, ''a'', ''k2'')');
  Yurut('insert into ' + ANA + ' (ID, AD, KOD) values (3, null, ''k3'')');
  Yurut('create table ' + ALT + ' (ID integer not null primary key, ANA_ID integer)');
  Yurut('insert into ' + ALT + ' (ID, ANA_ID) values (1, 99)');

  { Dogrulama }
  Kontrol('Index dogrula: bos ad', IndeksDogrula(IndeksG('', 'AD', False, False)) = T('ERR_INDEKS_AD_BOS'));
  Kontrol('Index dogrula: bos kolon', IndeksDogrula(IndeksG('X', ' , ', False, False)) = T('ERR_YAPI_KOLON_BOS'));
  Kontrol('Kisit dogrula: FK hedefsiz', KisitDogrula(KisitG(ktYabanci, '', 'AD')) = T('ERR_KISIT_HEDEF_BOS'));
  Kontrol('Kisit dogrula: CHECK ifadesiz', KisitDogrula(KisitG(ktCheck, '', '')) = T('ERR_KISIT_IFADE_BOS'));

  { Index }
  Kontrol('Index komutu: UNIQUE DESC', Pos('CREATE UNIQUE DESCENDING INDEX FBY_TEST_I1 ON FBY_TEST_ANA (AD, KOD)',
    IndeksKomutu(Bag, yiOlustur, IndeksG('fby_test_i1', 'ad, kod', True, True))) = 1);
  Sonuc := IndeksUygula(Bag, yiOlustur, IndeksG('FBY_TEST_I1', 'AD', False, False));
  Kontrol('Index: olusturuldu', Sonuc.Basarili and IndeksVarMi('FBY_TEST_I1'));
  Kontrol('Index: yedek yazildi', Sonuc.YedekDosyasi <> '');
  Sonuc := IndeksUygula(Bag, yiOlustur, IndeksG('FBY_TEST_I1', 'AD', False, False));
  Reddedilir('Index: ayni ad', Sonuc);
  Sonuc := IndeksUygula(Bag, yiOlustur, IndeksG('FBY_TEST_I2', 'AD', True, False));
  Reddedilir('Index: UNIQUE ama tekrarli veri', Sonuc);
  Sonuc := IndeksUygula(Bag, yiOlustur, IndeksG('FBY_TEST_I3', 'OLMAYAN', False, False));
  Reddedilir('Index: olmayan kolon', Sonuc);
  Sonuc := IndeksUygula(Bag, yiDurum, IndeksGirdisiOku(Bag, ANA, 'FBY_TEST_I1'));
  Kontrol('Index: pasif yapildi', Sonuc.Basarili and IndeksGirdisiOku(Bag, ANA, 'FBY_TEST_I1').Pasif);
  Sonuc := IndeksUygula(Bag, yiDurum, IndeksGirdisiOku(Bag, ANA, 'FBY_TEST_I1'));
  Kontrol('Index: tekrar aktif yapildi', Sonuc.Basarili and not IndeksGirdisiOku(Bag, ANA, 'FBY_TEST_I1').Pasif);
  Sonuc := IndeksUygula(Bag, yiSil, IndeksGirdisiOku(Bag, ANA, 'FBY_TEST_I1'));
  Kontrol('Index: silindi', Sonuc.Basarili and not IndeksVarMi('FBY_TEST_I1'));

  { Kisit komutlari }
  Kontrol('Kisit komutu: UNIQUE', KisitKomutu(Bag, yiOlustur, KisitG(ktBenzersiz, 'uq1', 'kod')) =
    'ALTER TABLE FBY_TEST_ANA ADD CONSTRAINT UQ1 UNIQUE (KOD)');
  Kontrol('Kisit komutu: CHECK parantez eklenir', KisitKomutu(Bag, yiOlustur, KisitG(ktCheck, '', '')) = '');
  G := KisitG(ktCheck, 'ck1', '');
  G.Ifade := 'CHECK ID > 0';
  Kontrol('Kisit komutu: CHECK sozcugu ve parantez', KisitKomutu(Bag, yiOlustur, G) =
    'ALTER TABLE FBY_TEST_ANA ADD CONSTRAINT CK1 CHECK (ID > 0)');
  G := KisitG(ktYabanci, 'fk1', 'ana_id');
  G.Tablo := ALT;
  G.HedefTablo := ANA;
  G.SilKurali := 'CASCADE';
  Kontrol('Kisit komutu: FK ON DELETE', KisitKomutu(Bag, yiOlustur, G) =
    'ALTER TABLE FBY_TEST_ALT ADD CONSTRAINT FK1 FOREIGN KEY (ANA_ID) REFERENCES FBY_TEST_ANA ON DELETE CASCADE');

  { Kisit ekle: basarili ve reddedilenler }
  Sonuc := KisitUygula(Bag, yiOlustur, KisitG(ktBenzersiz, 'FBY_TEST_UQ1', 'KOD'));
  Kontrol('Kisit: UNIQUE eklendi', Sonuc.Basarili and KisitVarMi(ANA, 'FBY_TEST_UQ1'));
  Sonuc := KisitUygula(Bag, yiOlustur, KisitG(ktBenzersiz, 'FBY_TEST_UQ1', 'KOD'));
  Reddedilir('Kisit: ayni ad', Sonuc);
  Sonuc := KisitUygula(Bag, yiOlustur, KisitG(ktBenzersiz, 'FBY_TEST_UQ2', 'AD'));
  Reddedilir('Kisit: UNIQUE ama tekrarli veri', Sonuc);
  Sonuc := KisitUygula(Bag, yiOlustur, KisitG(ktBirincil, '', 'KOD'));
  Reddedilir('Kisit: ikinci PRIMARY KEY', Sonuc);
  G := KisitG(ktCheck, 'FBY_TEST_CK1', '');
  G.Ifade := 'ID > 2';
  Sonuc := KisitUygula(Bag, yiOlustur, G);
  Kontrol('Kisit: CHECK mevcut kayitlari denetlemez (Firebird), mevcut veri uymasa da eklenir',
    Sonuc.Basarili and KisitVarMi(ANA, 'FBY_TEST_CK1'));
  Kontrol('Kisit: CHECK onayinda mevcut-veri notu var',
    Pos(T('ONAY_KISIT_CHECK_NOT'), KisitOnayMetni(Bag, yiOlustur, G, 'x')) > 0);
  Sonuc := KisitUygula(Bag, yiSil, KisitGirdisiOku(Bag, ANA, 'FBY_TEST_CK1'));
  Kontrol('Kisit: CHECK geri silindi', Sonuc.Basarili and not KisitVarMi(ANA, 'FBY_TEST_CK1'));
  G.Ifade := 'ID > 0';
  Sonuc := KisitUygula(Bag, yiOlustur, G);
  Kontrol('Kisit: CHECK eklendi', Sonuc.Basarili and KisitVarMi(ANA, 'FBY_TEST_CK1'));
  Sonuc := KisitUygula(Bag, yiOlustur, KisitG(ktBenzersiz, 'FBY_TEST_UQ3', 'OLMAYAN'));
  Reddedilir('Kisit: olmayan kolon', Sonuc);

  G := KisitG(ktYabanci, 'FBY_TEST_FK1', 'ANA_ID');
  G.Tablo := ALT;
  G.HedefTablo := ANA;
  G.SilKurali := 'CASCADE';
  Sonuc := KisitUygula(Bag, yiOlustur, G);
  Reddedilir('Kisit: FK ama yetim kayit var', Sonuc);
  Yurut('update ' + ALT + ' set ANA_ID = 1');
  Sonuc := KisitUygula(Bag, yiOlustur, G);
  Kontrol('Kisit: FK eklendi', Sonuc.Basarili and KisitVarMi(ALT, 'FBY_TEST_FK1'));
  Kontrol('Kisit: FK ON DELETE CASCADE okunur',
    KisitGirdisiOku(Bag, ALT, 'FBY_TEST_FK1').SilKurali = 'CASCADE');


  { Kisit sil: UNIQUE ve CHECK serbest; birincil anahtara bagli FK varken once FK'nin kalkmasi gerekir }
  Sonuc := KisitUygula(Bag, yiSil, KisitGirdisiOku(Bag, ANA, 'FBY_TEST_UQ1'));
  Kontrol('Kisit sil: UNIQUE silindi', Sonuc.Basarili and not KisitVarMi(ANA, 'FBY_TEST_UQ1'));
  Sonuc := KisitUygula(Bag, yiSil, KisitGirdisiOku(Bag, ANA, 'FBY_TEST_CK1'));
  Kontrol('Kisit sil: CHECK silindi', Sonuc.Basarili and not KisitVarMi(ANA, 'FBY_TEST_CK1'));
  for Bilgi in KisitlariOku(Bag, ANA) do
    if Bilgi.Tur = ktBirincil then
      PkAd := Bilgi.GercekAd;
  Kontrol('Kisit sil: birincil anahtarin sistem adi okunur (INTEG_ ...)', PkAd <> '');
  G := KisitGirdisiOku(Bag, ANA, PkAd);
  Kontrol('Kisit sil: PK onay metni baglanan FK''yi listeler (ALT)',
    Pos(ALT, KisitOnayMetni(Bag, yiSil, G, KisitKomutu(Bag, yiSil, G))) > 0);
  Sonuc := KisitUygula(Bag, yiSil, G);
  Reddedilir('Kisit sil: PK''ya bagli FK var', Sonuc);
  Kontrol('Kisit sil: PK reddedilince yerinde', KisitVarMi(ANA, PkAd));
  Sonuc := KisitUygula(Bag, yiSil, KisitGirdisiOku(Bag, ALT, 'FBY_TEST_FK1'));
  Kontrol('Kisit sil: FK silindi', Sonuc.Basarili and not KisitVarMi(ALT, 'FBY_TEST_FK1'));
  Sonuc := KisitUygula(Bag, yiSil, G);
  Kontrol('Kisit sil: FK kalkinca PK silindi', Sonuc.Basarili and not KisitVarMi(ANA, PkAd));
  Kontrol('Kisit sil: SQL karsiligi DROP CONSTRAINT',
    (Length(Sonuc.Komutlar) > 0) and (Pos('DROP CONSTRAINT', UpperCase(Sonuc.Komutlar[0])) > 0));
end;


function TabloVarMi(const Ad: string): Boolean;
var
  Yok: string;
begin
  for Yok in TabloAdlari(Bag) do
    if Yok = Ad then
      Exit(True);
  Result := False;
end;

procedure YeniTabloSilBolumu;
const
  YENI = 'FBY_TEST_YENI';
var
  Sonuc: TProsedurSonucu;
  Ad, Metin, Yedek: string;
  Form: TForm;
  Sekme: TProsedurSekme;
begin
  Cikti.Add('');
  Cikti.Add('=== E) Yeni tablo ve tablo sil (' + Bag.Surum + ') ===');
  Dene('drop view ' + VW);
  Dene('drop table ' + ALT2);
  Dene('drop table ' + YENI);
  Temizle;

  { Yeni tablo }
  Metin := YeniNesneSablonu(ntTablo);
  Kontrol('Yeni tablo: sablon CREATE TABLE ile baslar', Pos('CREATE TABLE', Metin) = 1);
  Kontrol('Yeni tablo: sablonun adi okunur', (YeniNesneAdiniDogrula(ntTablo, Metin, Ad) = '') and (Ad = 'YENI_TABLO'));
  Kontrol('Yeni tablo: CREATE OR ALTER reddedilir', YeniNesneAdiniDogrula(ntTablo, 'CREATE OR ALTER TABLE X (ID INTEGER);', Ad) =
    T('ERR_TBL_YENI_BASLIK_YOK'));
  Metin := 'CREATE TABLE ' + YENI + ' (ID INTEGER NOT NULL PRIMARY KEY, AD VARCHAR(20));';
  Sonuc := YeniNesneKaydet(Bag, ntTablo, Metin);
  Kontrol('Yeni tablo: olusturuldu', Sonuc.Basarili and (Sonuc.Ad = YENI) and TabloVarMi(YENI));
  Sonuc := YeniNesneKaydet(Bag, ntTablo, Metin);
  Cikti.Add('      [ayni ad] cumle: ' + TekSatirMetin(Sonuc.Cumle));
  Kontrol('Yeni tablo: ayni ad -> "zaten var" cumlesi', (not Sonuc.Basarili) and (Sonuc.Cumle = T('ERR_NESNE_VAR')));
  Yurut('insert into ' + YENI + ' (ID, AD) values (1, ''gizli veri'')');

  { Sekme: varsayilan tur prosedur, Yeni tablo basligi }
  Form := TForm.CreateNew(nil);
  try
    Sekme := TProsedurSekme.Create(Form);
    Kontrol('Sekme: varsayilan tur ntProsedur (ntTablo yalniz Yeni tablo)', Sekme.Tur = ntProsedur);
    Sekme.Parent := Form;
    Sekme.Tur := ntTablo;
    Sekme.AnaSonuc := TStringList.Create;
    Sekme.YeniHazirla(Bag);
    Kontrol('Sekme: Yeni tablo basligi', Sekme.Baslik = TF('TBL_YENI_SEKME', [Bag.Tanim.Ad]));
    Sekme.AnaSonuc.Free;
  finally
    Form.Free;
  end;

  { Tablo sil: onay metni }
  Yurut('create table ' + ALT2 + ' (ID integer not null primary key, YENI_ID integer references ' + YENI + ' (ID))');
  Yurut('create view ' + VW + ' as select ID from ' + YENI);
  Metin := SilmeOnayMetni(Bag, ntTablo, YENI);
  Kontrol('Onay: tablo adi ve "geri alinamaz"', (Pos(YENI, Metin) > 0) and (Pos(TF('ONAY_SIL', [T('TUR_TABLO'), YENI]), Metin) = 1));
  Kontrol('Onay: satir sayisi (1) ve veri yedeklenmez uyarisi', Pos(TF('ONAY_SIL_TABLO_VERI', [1]), Metin) > 0);
  Kontrol('Onay: kullanan view listelenir', Pos(VW, Metin) > 0);
  Kontrol('Onay: FK ile bagli tablo listelenir', Pos(ALT2, Metin) > 0);

  { Tablo sil: engellenir }
  Sonuc := NesneSil(Bag, ntTablo, YENI);
  Cikti.Add('      [engelli sil] cumle: ' + TekSatirMetin(Sonuc.Cumle));
  Cikti.Add('      [engelli sil] ayrinti: ' + TekSatirMetin(Sonuc.Ayrinti));
  Kontrol('Sil: view ve FK varken reddedilir, anlasilir cumle, tablo yerinde',
    (not Sonuc.Basarili) and (Sonuc.Cumle <> '') and (Sonuc.Cumle <> T('ERR_GENEL')) and TabloVarMi(YENI));
  Kontrol('Sil: reddedilse de yapi yedegi yazildi', Sonuc.YedekDosyasi <> '');
  Dene('drop view ' + VW);
  Sonuc := NesneSil(Bag, ntTablo, YENI);
  Cikti.Add('      [FK ile engelli sil] cumle: ' + TekSatirMetin(Sonuc.Cumle));
  Cikti.Add('      [FK ile engelli sil] ayrinti: ' + TekSatirMetin(Sonuc.Ayrinti));
  Kontrol('Sil: yalniz FK kaldiysa yine reddedilir, tabloya ozel cumle',
    (not Sonuc.Basarili) and (Sonuc.Cumle = T('ERR_TABLO_FK_BAGLI')) and TabloVarMi(YENI));

  { Yalniz view bagli olan tablo }
  Dene('drop table ' + ALT2);
  Yurut('create view ' + VW + ' as select ID from ' + YENI);
  Sonuc := NesneSil(Bag, ntTablo, YENI);
  Cikti.Add('      [view ile engelli sil] cumle: ' + TekSatirMetin(Sonuc.Cumle));
  Cikti.Add('      [view ile engelli sil] ayrinti: ' + TekSatirMetin(Sonuc.Ayrinti));
  Kontrol('Sil: yalniz view bagliyken reddedilir, bagimlilik cumlesi, tablo yerinde',
    (not Sonuc.Basarili) and (Sonuc.Cumle = T('ERR_NESNE_BAGIMLI')) and TabloVarMi(YENI));
  Dene('drop view ' + VW);

  { Tablo sil: serbest }
  Sonuc := NesneSil(Bag, ntTablo, YENI);
  Kontrol('Sil: bagimlisiz tablo silindi', Sonuc.Basarili and not TabloVarMi(YENI));
  Kontrol('Sil: SQL karsiligi DROP TABLE', (Length(Sonuc.Komutlar) > 0) and (Pos('DROP TABLE', UpperCase(Sonuc.Komutlar[0])) > 0));
  Yedek := '';
  if Sonuc.YedekDosyasi <> '' then
    Yedek := TFile.ReadAllText(Sonuc.YedekDosyasi, TEncoding.Default);
  Kontrol('Sil: yedek dosyasi CREATE TABLE icerir', Pos('CREATE TABLE', UpperCase(Yedek)) > 0);
  Kontrol('Sil: yedek dosyasi tablonun VERISINI icermez', Pos('gizli veri', Yedek) = 0);
  Kontrol('Sil: yedek dosyasi adi tablo_ ile baslar', Pos('tablo_', ExtractFileName(Sonuc.YedekDosyasi)) = 1);
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
          IndeksKisitBolumu;
          YeniTabloSilBolumu;
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
