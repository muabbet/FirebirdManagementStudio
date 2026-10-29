program NesneYonetimTest;

{ Asama 3f: view duzenleme, domain / exception / generator yonetimi ve silme (uProsedur, uNesneYonet) testi (komut satiri).
  TriggerDuzenleTest ile ayni kalip.

  A) HER KIPTE: saf kurallar (ad dogrulama, dil anahtarlari). Veritabani gerekmez.
  B) GOMULU kip (FBTEST_SUNUCU bos): program kendi gecici veritabanini olusturur ve yazma testlerini orada yapar.
  C) SUNUCU kip: yazma testleri YALNIZCA yerel sunucuda 3052, 3053 ve 3054 portlarinda ve FBTEST_YAZMA=1 verilmisse
     calisir; baska portta (3050 ve 3051 dahil) kod seviyesinde REDDEDILIR. Testler FBY_TEST_ ile baslayan nesneler
     olusturur, sonunda siler.

  Ortam degiskenleri: FBTEST_SUNUCU, FBTEST_PORT, FBTEST_YOL, FBTEST_KULLANICI, FBTEST_SIFRE, FBTEST_CIKTI, FBTEST_YAZMA.
  Yedekler %TEMP%\nesnetest_veri altina yazilir. Cikis kodu: hata sayisi (0 = hepsi gecti). }

{$APPTYPE CONSOLE}

uses
  System.SysUtils, System.Classes, System.StrUtils, System.IOUtils, Data.DB,
  FireDAC.Stan.Intf, FireDAC.Stan.Option, FireDAC.Stan.Error, FireDAC.Comp.Client, FireDAC.Phys.FB,
  FireDAC.ConsoleUI.Wait,
  Vcl.Forms, Vcl.Controls, Vcl.ExtCtrls,
  uDil, uBaglanti, uMetadata, uSorgu, uDDL, uKullanici, uProsedur, uEditor, fProsedurSekme;

const
  TB = 'FBY_TEST_TB';
  VW = 'FBY_TEST_VW';
  VW2 = 'FBY_TEST_VW2';
  EX = 'FBY_TEST_EX';
  DM = 'FBY_TEST_DM';
  GN = 'FBY_TEST_GN';
  TR = 'FBY_TEST_TRG';
  PR = 'FBY_TEST_PRS';

var
  Cikti: TStringList;
  Hatalar, KontrolSayisi, Sayac: Integer;
  Tanim: TBaglantiTanimi;
  Bag: TAcikBaglanti;
  Gomulu: Boolean;
  VeriKlasoru: string;

function Ortam(const Ad, Varsayilan: string): string;
begin
  Result := GetEnvironmentVariable(Ad);
  if Result = '' then
    Result := Varsayilan;
end;

function TekSatir(const Metin: string; Uzunluk: Integer = 300): string;
begin
  Result := Copy(StringReplace(StringReplace(Metin, #13, '', [rfReplaceAll]), #10, ' | ', [rfReplaceAll]), 1, Uzunluk);
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

procedure Not_(const Metin: string);
begin
  Cikti.Add('      ' + Metin);
end;

{ Hata: sinif, ham mesaj ve Firebird kodlari }
function HataKodlari(E: Exception): string;
var
  I: Integer;
begin
  Result := E.ClassName + ': ' + TekSatir(E.Message);
  if E is EFDDBEngineException then
    for I := 0 to EFDDBEngineException(E).ErrorCount - 1 do
      Result := Result + ' [kod=' + IntToStr(EFDDBEngineException(E).Errors[I].ErrorCode) + ']';
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

{ Tek komutu calistirir (kendi otomatik onayli islemiyle). Hata olursa istisna firlar. }
procedure Yurut(B: TAcikBaglanti; const Sql: string);
var
  Sorgu: TFDQuery;
begin
  Sorgu := KomutHazirla(B, Sql);
  try
    Sorgu.ExecSQL;
  finally
    Sorgu.Free;
  end;
end;

{ Hata verirse sessizce gecer (temizlik). }
procedure Dene(B: TAcikBaglanti; const Sql: string);
begin
  try
    Yurut(B, Sql);
  except
  end;
end;

{ Komutu dener, hatanin Firebird kodlarini ve bizim cumlemizi yazar (ceviri tablosunu gercek koddan kurmak icin). }
procedure KodDene(const Ad: string; B: TAcikBaglanti; const Sql: string);
begin
  try
    Yurut(B, Sql);
    Not_(Ad + ': hata YOK (komut basarili oldu)');
  except
    on E: Exception do
      Not_(Ad + ': ' + HataKodlari(E) + '  => ' + TekSatir(HataMetniniCevir(E)));
  end;
end;

function Skaler(B: TAcikBaglanti; const Sql: string): string;
var
  Sorgu: TFDQuery;
begin
  Sorgu := KomutHazirla(B, Sql);
  try
    Sorgu.Open;
    if Sorgu.Eof then
      Result := '<satir yok>'
    else
      Result := Sorgu.Fields[0].AsString;
  finally
    Sorgu.Free;
  end;
end;

{ Listede adi bulunuyor mu (agac dallarinin dolduruldugu ayni fonksiyonlarla). }
function Listede(Liste: TStrings; const Ad: string): Boolean;
begin
  Result := Liste.IndexOf(Ad) >= 0;
end;

{ ---------- A) Kurallar ---------- }

procedure KurallarBolumu;
var
  Hepsi, Anahtar, Dil: string;
  Anahtarlar: TArray<string>;
begin
  Cikti.Add('');
  Cikti.Add('=== A) Kurallar (veritabani gerekmez) ===');
  Anahtarlar := ['AGAC_DOMAINLER', 'AGAC_ISTISNALAR'];
  for Dil in ['tr', 'en', 'de'] do
  begin
    DilYukle(Dil);
    Hepsi := '';
    for Anahtar in Anahtarlar do
      if T(Anahtar) = Anahtar then
        Hepsi := Hepsi + ' ' + Anahtar;
    Kontrol('Dil ' + Dil + ': tum 3f anahtarlari tanimli', Hepsi = '');
    if Hepsi <> '' then
      Not_('eksik:' + Hepsi);
  end;
  DilYukle('tr');
end;

{ ---------- B) Veritabani ---------- }

procedure Temizle;
begin
  Dene(Bag, 'drop view ' + VW2);
  Dene(Bag, 'drop view ' + VW);
  Dene(Bag, 'drop procedure ' + PR);
  Dene(Bag, 'drop trigger ' + TR);
  Dene(Bag, 'drop table ' + TB);
  Dene(Bag, 'drop exception ' + EX);
  Dene(Bag, 'drop exception ' + EX + '_B');
  Dene(Bag, 'drop domain ' + DM);
  Dene(Bag, 'drop domain ' + DM + '_B');
  Dene(Bag, 'drop sequence ' + GN);
  Dene(Bag, 'drop sequence ' + GN + '_B');
end;

{ 3f-1: listeler (agacin kullandigi fonksiyonlar), sistem nesnesi cikmaz, script uretimi. }
procedure ListeBolumu;
var
  Liste: TStringList;
  Metin, Ad: string;
  Sistem: Boolean;
begin
  Cikti.Add('');
  Cikti.Add('=== B1) Domain / exception listesi ve script (surum ' + Bag.Surum + ') ===');
  Temizle;
  Yurut(Bag, 'create domain ' + DM + ' as varchar(20) default ''X'' not null check (value <> ''Y'')');
  Yurut(Bag, 'create exception ' + EX + ' ''bir mesaj''''li''');
  Yurut(Bag, 'create table ' + TB + ' (ID integer, ADI ' + DM + ', B varchar(10))');
  Liste := TStringList.Create;
  try
    DomainleriGetir(Bag, Liste);
    Kontrol('Domain listesinde test domaini var', Listede(Liste, DM));
    Sistem := False;
    for Ad in Liste do
      if StartsText('RDB$', Ad) or StartsText('SEC$', Ad) or StartsText('MON$', Ad) then
        Sistem := True;
    Kontrol('Domain listesinde sistem (RDB$..) domain yok', not Sistem);
    Not_('domain sayisi: ' + IntToStr(Liste.Count));
    IstisnalariGetir(Bag, Liste);
    Kontrol('Exception listesinde test exception var', Listede(Liste, EX));
    Sistem := False;
    for Ad in Liste do
      if StartsText('RDB$', Ad) then
        Sistem := True;
    Kontrol('Exception listesinde sistem exception yok', not Sistem);
  finally
    Liste.Free;
  end;
  Metin := ScriptUret(Bag, ntDomain, DM);
  Not_('domain script: ' + TekSatir(Metin));
  Kontrol('Domain script: CREATE DOMAIN ... NOT NULL, DEFAULT, CHECK',
    (Pos('CREATE DOMAIN ' + DM + ' AS VARCHAR(20)', Metin) = 1) and ContainsText(Metin, 'DEFAULT ''X''') and (Pos('NOT NULL', Metin) > 0) and
    ContainsText(Metin, 'CHECK'));
  Metin := ScriptUret(Bag, ntIstisna, EX);
  Not_('exception script: ' + TekSatir(Metin));
  Kontrol('Exception script: CREATE EXCEPTION ad ''mesaj''''li'';', Pos('CREATE EXCEPTION ' + EX + ' ''bir mesaj''''li'';', Metin) = 1);
  Metin := IstisnaDuzenleScripti(Bag, EX);
  Kontrol('Exception duzenleme metni CREATE OR ALTER EXCEPTION ile basliyor', Pos('CREATE OR ALTER EXCEPTION ' + EX + ' ', Metin) = 1);
  { Uretilen script, metadata cikarimiyla ayni uretici: tablo kolonu domain'i adiyla kullanmali. }
  Kontrol('Tablo scriptinde kolon domain adiyla', Pos(DM, ScriptUret(Bag, ntTablo, TB)) > 0);
  Metin := '';
  try
    ScriptUret(Bag, ntDomain, 'FBY_YOK_BOYLE');
  except
    on E: EMetadataHatasi do
      Metin := E.Message;
  end;
  Kontrol('Olmayan domain: anlasilir EMetadataHatasi', Metin <> '');
end;

{ ---------- 3f-2: View duzenleme ---------- }

function ViewKaynagi(const Ad: string): string;
begin
  Result := Skaler(Bag, 'select rdb$view_source from rdb$relations where rdb$relation_name = ''' + Ad + '''');
end;

function ViewKolonlari(const Ad: string): string;
begin
  Result := Skaler(Bag, 'select list(trim(rdb$field_name), '','') from (select rdb$field_name from rdb$relation_fields ' +
    'where rdb$relation_name = ''' + Ad + ''' order by rdb$field_position)');
end;

function YedekSayisi: Integer;
begin
  ForceDirectories(ProsedurYedekKlasoru(Bag.Tanim.Ad));
  Result := Length(TDirectory.GetFiles(ProsedurYedekKlasoru(Bag.Tanim.Ad), '*.sql'));
end;

{ Yedek klasoru yerine dosya konur (yazilamaz); kaydetme denenir, sonra eski haline donulur. }
function YedeksizKaydet(Tur: TNesneTuru; const Ad, Metin: string): TProsedurSonucu;
var
  Klasor, Dosya: string;
begin
  Klasor := TPath.Combine(TPath.GetTempPath, 'nesnetest_yedeksiz');
  TDirectory.CreateDirectory(Klasor);
  Dosya := TPath.Combine(Klasor, '_arsiv');
  TFile.WriteAllText(Dosya, 'engel');
  VeriKlasoruAyarla(Klasor);
  try
    Result := NesneKaydet(Bag, Tur, Ad, Metin);
  finally
    VeriKlasoruAyarla(VeriKlasoru);
  end;
  TFile.Delete(Dosya);
end;

procedure ViewKur;
begin
  Temizle;
  Yurut(Bag, 'create table ' + TB + ' (ID integer, AD varchar(30), X integer)');
  Yurut(Bag, 'create view ' + VW + ' (ID, AD) as select ID, AD from ' + TB);
  Yurut(Bag, 'create view ' + VW2 + ' (ID) as select ID from ' + VW);
end;

procedure ViewBolumu;
var
  Metin, Yedek, YedekMetni: string;
  Sonuc: TProsedurSonucu;
  Once: Integer;
begin
  Cikti.Add('');
  Cikti.Add('=== B3) View duzenleme (surum ' + Bag.Surum + ') ===');
  ViewKur;
  Metin := ViewDuzenleScripti(Bag, VW);
  Not_('view duzenleme metni: ' + TekSatir(Metin, 300));
  Kontrol('View metni CREATE OR ALTER VIEW ad (kolonlar) AS ile basliyor',
    (Pos('CREATE OR ALTER VIEW ' + VW + ' (ID, AD) AS', Metin) = 1) and (Pos('SET TERM', Metin) = 0));
  Kontrol('View metni TEK komut ve ad dogrulamasindan geciyor',
    (Length(KomutlaraBol(Metin)) = 1) and (NesneAdiniDogrula(ntView, Metin, VW) = ''));
  Kontrol('NesneDuzenleMetni(ntView) ayni metni veriyor', NesneDuzenleMetni(Bag, ntView, VW) = Metin);
  Kontrol('ScriptUret(ntView) CREATE VIEW uretiyor', Pos('CREATE VIEW ' + VW, ScriptUret(Bag, ntView, VW)) > 0);

  { Bagimlisiz degisiklik: WHERE ekle. Bagimli VW2 var ama kullandigi ID kolonu duruyor. }
  Once := YedekSayisi;
  Sonuc := NesneKaydet(Bag, ntView, VW, StringReplace(Metin, 'from ' + TB, 'from ' + TB + ' where ID > 0', [rfIgnoreCase]));
  if not Sonuc.Basarili then
    Not_('hata: ' + Sonuc.Cumle + ' / ' + Sonuc.Ayrinti);
  Kontrol('Bagimlisi olan view kaydedildi (kullanilan kolon duruyor)', Sonuc.Basarili);
  Kontrol('View yeni tanimda (WHERE var)', ContainsText(ViewKaynagi(VW), 'ID > 0'));
  Kontrol('Sonuc: tek komut, CREATE OR ALTER VIEW ile basliyor',
    (Length(Sonuc.Komutlar) = 1) and (Pos('CREATE OR ALTER VIEW', Sonuc.Komutlar[0]) = 1));
  Yedek := Sonuc.YedekDosyasi;
  Kontrol('Yedek dosyasi view_ADI_...sql, _arsiv\<baglanti> altinda',
    FileExists(Yedek) and (Pos(ProsedurYedekKlasoru(Bag.Tanim.Ad), Yedek) = 1) and StartsText('view_' + VW + '_', ExtractFileName(Yedek)) and
    EndsText('.sql', Yedek) and (YedekSayisi = Once + 1));
  Not_('yedek: ' + Yedek);
  if FileExists(Yedek) then
  begin
    YedekMetni := TFile.ReadAllText(Yedek, TEncoding.GetEncoding(1254));
    Kontrol('Yedek ESKI tanimi iceriyor (WHERE yok), CREATE OR ALTER VIEW ve SET NAMES var',
      (Pos('CREATE OR ALTER VIEW ' + VW, YedekMetni) > 0) and (Pos('SET NAMES ', YedekMetni) > 0) and (Pos('ID > 0', YedekMetni) = 0));
    Sonuc := NesneKaydet(Bag, ntView, VW, StringReplace(YedekMetni, 'SET NAMES ', '-- SET NAMES ', []));
    Kontrol('Yedek metniyle geri kaydetme basarili, WHERE gitti', Sonuc.Basarili and not ContainsText(ViewKaynagi(VW), 'ID > 0'));
  end;

  { Bagimliyi bozan degisiklik: VW2'nin kullandigi ID kolonu cikarilir. }
  Sonuc := NesneKaydet(Bag, ntView, VW, 'CREATE OR ALTER VIEW ' + VW + ' (AD) AS select AD from ' + TB + ';');
  Not_('bagimli kolon cikarma: basarili=' + BoolToStr(Sonuc.Basarili, True) + ' cumle=' + TekSatir(Sonuc.Cumle) + ' ayrinti=' + TekSatir(Sonuc.Ayrinti));
  Kontrol('Bagimlinin kullandigi kolon cikarilamaz: reddedildi, cumle ERR_NESNE_BAGIMLI, Ayrinti dolu',
    (not Sonuc.Basarili) and (Sonuc.Cumle = T('ERR_NESNE_BAGIMLI')) and (Sonuc.Ayrinti <> ''));
  Kontrol('Reddedilince view eski halinde (ID, AD kolonlari duruyor)', ViewKolonlari(VW) = 'ID,AD');
  { Bagimlinin kullanmadigi kolon cikarilabilir. }
  Sonuc := NesneKaydet(Bag, ntView, VW, 'CREATE OR ALTER VIEW ' + VW + ' (ID) AS select ID from ' + TB + ';');
  Kontrol('Bagimlinin kullanmadigi kolon (AD) cikarilabilir', Sonuc.Basarili and (ViewKolonlari(VW) = 'ID'));

  { Hatalar: sozdizimi, olmayan tablo; eski view bozulmaz. }
  Sonuc := NesneKaydet(Bag, ntView, VW, 'CREATE OR ALTER VIEW ' + VW + ' (ID) AS selec ID from ' + TB + ';');
  Not_('sozdizimi: cumle=' + TekSatir(Sonuc.Cumle) + ' ayrinti=' + TekSatir(Sonuc.Ayrinti) + ' satir=' + IntToStr(Sonuc.Satir));
  Kontrol('Sozdizimi hatasi: anlasilir cumle, Ayrinti dolu, view bozulmadi',
    (not Sonuc.Basarili) and (Sonuc.Cumle = T('ERR_SQL_SOZDIZIMI')) and (Sonuc.Ayrinti <> '') and (ViewKolonlari(VW) = 'ID'));
  Sonuc := NesneKaydet(Bag, ntView, VW, 'CREATE OR ALTER VIEW ' + VW + ' (ID) AS select ID from FBY_TEST_YOKTABLO;');
  Not_('olmayan tablo: cumle=' + TekSatir(Sonuc.Cumle) + ' ayrinti=' + TekSatir(Sonuc.Ayrinti));
  Kontrol('Olmayan tablo: anlasilir cumle, view bozulmadi',
    (not Sonuc.Basarili) and (Sonuc.Cumle = T('ERR_SQL_NESNE_YOK')) and (ViewKolonlari(VW) = 'ID'));

  { Kurallar: ad degisikligi ve basliksiz metin veritabanina dokunmadan reddedilir. }
  Sonuc := NesneKaydet(Bag, ntView, VW, 'CREATE OR ALTER VIEW FBY_TEST_VW9 (ID) AS select ID from ' + TB + ';');
  Kontrol('Ad degisikligi reddedildi (ERR_VIEW_AD_DEGISTI), yeni view olusmadi',
    (not Sonuc.Basarili) and (Sonuc.Cumle = TF('ERR_VIEW_AD_DEGISTI', [VW, 'FBY_TEST_VW9'])) and (Length(Sonuc.Komutlar) = 0) and
    (Skaler(Bag, 'select count(*) from rdb$relations where rdb$relation_name = ''FBY_TEST_VW9''') = '0'));
  Sonuc := NesneKaydet(Bag, ntView, VW, 'CREATE VIEW ' + VW + ' (ID) AS select ID from ' + TB + ';');
  Kontrol('Basliksiz (CREATE VIEW, OR ALTER yok) metin reddedildi', (not Sonuc.Basarili) and (Sonuc.Cumle = TF('ERR_VIEW_BASLIK_YOK', [VW, VW])));
  Kontrol('PROCEDURE basligi view sekmesinde reddedilir', NesneAdiniDogrula(ntView, 'CREATE OR ALTER PROCEDURE ' + VW + ' AS begin end', VW) <> '');

  { Yedek yazilamazsa durur. }
  Sonuc := YedeksizKaydet(ntView, VW, ViewDuzenleScripti(Bag, VW));
  Kontrol('Yedek yazilamadi: kaydetme durdu (ERR_PRS_YEDEK_YAZILAMADI), veritabanina dokunulmadi',
    (not Sonuc.Basarili) and (Sonuc.Cumle = T('ERR_PRS_YEDEK_YAZILAMADI')) and (Length(Sonuc.Komutlar) = 0));
end;

{ Duzenleme sekmesi duman testi: sekme acilir, baslik/bilgi/Kaydet dugmesi dilden, F5 yalniz ipucu, Kaydet baglanti yoksa mesaj. }
procedure SekmeDene(Tur: TNesneTuru; const Ad, SekmeAnahtari, BilgiAnahtari: string);
var
  Form: TForm;
  Sekme: TProsedurSekme;
  Satirlar: TStringList;
begin
  Satirlar := TStringList.Create;
  Form := TForm.CreateNew(nil);
  try
    Sekme := TProsedurSekme.Create(Form);
    Sekme.Parent := Form;
    Sekme.Align := alClient;
    Sekme.AnaSonuc := Satirlar;
    Sekme.Tur := Tur;
    Sekme.Yukle(Bag, Ad);
    Kontrol(SekmeAnahtari + ': sekme basligi', Sekme.Baslik = TF(SekmeAnahtari, [Ad, Bag.Tanim.Ad]));
    Kontrol(SekmeAnahtari + ': Kaydet dugmesi yazisi dilden ve OnClick bagli',
      (Sekme.btnKaydet.Caption = T('PRS_KAYDET')) and Assigned(Sekme.btnKaydet.OnClick));
    Kontrol(SekmeAnahtari + ': bilgi satiri', Sekme.lblBilgi.Caption = TF(BilgiAnahtari, [Ad]));
    Sekme.F5Ipucu;
    Kontrol(SekmeAnahtari + ': F5 yalniz ipucu yazar', (Satirlar.Count = 1) and (Satirlar[0] = T('MSG_PRS_F5_IPUCU')));
    Sekme.BaglantiAd := 'yok_boyle_baglanti';
    Sekme.Kaydet;
    Kontrol(SekmeAnahtari + ': baglanti yoksa Kaydet mesaj yazar', (Satirlar.Count = 2) and (Pos('yok_boyle_baglanti', Satirlar[1]) > 0));
  finally
    Form.Free;
    Satirlar.Free;
  end;
end;

procedure SekmeBolumu;
begin
  Cikti.Add('');
  Cikti.Add('=== B9) Arayuz duman testi: duzenleme sekmeleri ===');
  ViewKur;
  SekmeDene(ntView, VW, 'VIEW_SEKME', 'VIEW_BILGI');
end;

{ EKLEME NOKTASI: yeni bolumler buraya }

{ ---------- Ana akis ---------- }

var
  YazmaIstendi, YazmaIzni, KendiVeritabanim: Boolean;
  Neden, Klasor: string;
begin
  Cikti := TStringList.Create;
  Bag := nil;
  KendiVeritabanim := False;
  VeriKlasoru := TPath.Combine(GetEnvironmentVariable('TEMP'), 'nesnetest_veri');
  try
    try
      DilYukle('tr');
      Tanim.Ad := 'nesne_test';
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
        Klasor := TPath.Combine(GetEnvironmentVariable('TEMP'), 'nesnetest');
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
        Neden := 'FBTEST_YAZMA=1 verilmedi (varsayilan: yazma yok)'
      else if not YerelSunucuMu(Tanim.Sunucu) then
        Neden := 'yazma yalniz yerel (127.0.0.1/localhost) test sunucusunda serbest'
      else if (Tanim.Port = 3052) or (Tanim.Port = 3053) or (Tanim.Port = 3054) then
        YazmaIzni := True
      else
        Neden := 'port ' + IntToStr(Tanim.Port) + ': yazma YALNIZ 3052, 3053 ve 3054 portunda serbest (3050/3051 gercek veri icerir)';

      Cikti.Add('NesneYonetimTest  ' + FormatDateTime('yyyy-mm-dd hh:nn:ss', Now));
      Cikti.Add('Sunucu: ' + IfThen(Gomulu, '(gomulu)', Tanim.Sunucu + ':' + IntToStr(Tanim.Port)));
      Cikti.Add('Veritabani: ' + Tanim.VeritabaniYolu + IfThen(KendiVeritabanim, '  (gecici, program acti)', ''));
      Cikti.Add('Kullanici: ' + Tanim.Kullanici + '  (sifre yazilmaz)');
      Cikti.Add('Yazma bolumu: ' + IfThen(YazmaIzni, 'ACIK', 'KAPALI - ' + Neden));

      if TDirectory.Exists(VeriKlasoru) then
        TDirectory.Delete(VeriKlasoru, True);
      KurallarBolumu;
      VeriKlasoruAyarla(VeriKlasoru);

      if YazmaIzni then
      begin
        Bag := FbBaglan(Tanim);
        Cikti.Add('Surum: ' + Bag.Surum);
        try
          ListeBolumu;
          ViewBolumu;
          SekmeBolumu;
        finally
          Temizle;
        end;
      end;
    except
      on E: Exception do
      begin
        Cikti.Add('');
        Cikti.Add('HATA (beklenmeyen): ' + HataKodlari(E));
        Inc(Hatalar);
      end;
    end;
    Cikti.Add('');
    Cikti.Add('Kontrol: ' + IntToStr(KontrolSayisi) + '  Hata: ' + IntToStr(Hatalar));
    Cikti.SaveToFile(Ortam('FBTEST_CIKTI', 'nesnetest.txt'), TEncoding.UTF8);
  finally
    Cikti.Free;
  end;
  ExitCode := Hatalar;
end.
