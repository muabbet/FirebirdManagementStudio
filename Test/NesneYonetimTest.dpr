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
  uDil, uBaglanti, uMetadata, uSorgu, uDDL, uKullanici, uProsedur, uNesneYonet, uEditor, fProsedurSekme;

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
var
  i: Integer;
begin
  for i := 1 to 12 do
    Dene(Bag, 'drop procedure FBY_TEST_PX' + Format('%.2d', [i]));
  Dene(Bag, 'drop view ' + VW2);
  Dene(Bag, 'drop view ' + VW);
  Dene(Bag, 'drop procedure ' + PR);
  Dene(Bag, 'drop trigger ' + TR);
  Dene(Bag, 'drop table ' + TB);
  Dene(Bag, 'drop table ' + TB + '_D');
  Dene(Bag, 'drop exception ' + EX);
  Dene(Bag, 'drop exception ' + EX + '_B');
  Dene(Bag, 'drop domain ' + DM);
  Dene(Bag, 'drop domain ' + DM + '_B');
  Dene(Bag, 'drop domain ' + DM + '_C');
  Dene(Bag, 'drop domain ' + DM + '_X');
  Dene(Bag, 'drop domain FBY_TEST_DM_X');
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

{ "Yeni" sekmesi duman testi: sablon editorde, baslik/bilgi dilden, Kaydet dugmesi bagli, olusturma olayi atanabilir. }
procedure YeniSekmeDene(Tur: TNesneTuru; const SekmeAnahtari, BilgiAnahtari, SablonAdi: string);
var
  Form: TForm;
  Okunan: string;
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
    Sekme.YeniHazirla(Bag);
    Kontrol(SekmeAnahtari + ': Yeni sekmesi, NesneAdi bos', Sekme.Yeni and (Sekme.NesneAdi = ''));
    Kontrol(SekmeAnahtari + ': baslik', Sekme.Baslik = TF(SekmeAnahtari, [Bag.Tanim.Ad]));
    Kontrol(SekmeAnahtari + ': bilgi satiri', Sekme.lblBilgi.Caption = T(BilgiAnahtari));
    Kontrol(SekmeAnahtari + ': Kaydet dugmesi yazisi dilden ve OnClick bagli', (Sekme.btnKaydet.Caption = T('PRS_KAYDET')) and Assigned(Sekme.btnKaydet.OnClick));
    Sekme.F5Ipucu;
    Kontrol(SekmeAnahtari + ': F5 yalniz ipucu', (Satirlar.Count = 1) and (Satirlar[0] = T('MSG_PRS_F5_IPUCU')));
    Sekme.BaglantiAd := 'yok_boyle_baglanti';
    Sekme.Kaydet;
    Kontrol(SekmeAnahtari + ': baglanti yoksa Kaydet mesaj yazar, olusturmaz', (Satirlar.Count = 2) and (Pos('yok_boyle_baglanti', Satirlar[1]) > 0));
  finally
    Form.Free;
    Satirlar.Free;
  end;
  Kontrol(SekmeAnahtari + ': sablon adi gecerli (' + SablonAdi + ')', (YeniNesneAdiniDogrula(Tur, YeniNesneSablonu(Tur), Okunan) = '') and (Okunan = SablonAdi));
end;

procedure SekmeBolumu;
begin
  Cikti.Add('');
  Cikti.Add('=== B9) Arayuz duman testi: duzenleme sekmeleri ===');
  ViewKur;
  SekmeDene(ntView, VW, 'VIEW_SEKME', 'VIEW_BILGI');
  Yurut(Bag, 'create exception ' + EX + ' ''m''');
  SekmeDene(ntIstisna, EX, 'EXC_SEKME', 'EXC_BILGI');
  YeniSekmeDene(ntIstisna, 'EXC_YENI_SEKME', 'EXC_YENI_BILGI', 'YENI_EXCEPTION');
  YeniSekmeDene(ntDomain, 'DOM_YENI_SEKME', 'DOM_YENI_BILGI', 'YENI_DOMAIN');
end;

{ Gercek hata kodlari ve cumleleri (ceviri tablosu bu ciktidan kuruldu); Not_ satirlari, kontrol degil. }
procedure HataKesfiBolumu;
begin
  Cikti.Add('');
  Cikti.Add('=== B0) Gercek hata kodlari (surum ' + Bag.Surum + ') ===');
  Temizle;
  Yurut(Bag, 'create domain ' + DM + ' as integer check (value > 0)');
  Yurut(Bag, 'create domain ' + DM + '_B as integer');
  Yurut(Bag, 'create exception ' + EX + ' ''m''');
  Yurut(Bag, 'create sequence ' + GN);
  Yurut(Bag, 'create table ' + TB + ' (ID integer, ADI ' + DM + ')');
  Yurut(Bag, 'create view ' + VW + ' as select ID from ' + TB);
  Yurut(Bag, 'create view ' + VW2 + ' as select ID from ' + VW);
  Yurut(Bag, 'create procedure ' + PR + ' as declare variable I integer; begin I = gen_id(' + GN + ', 1); exception ' + EX + '; end');
  KodDene('create exception var olan', Bag, 'create exception ' + EX + ' ''x''');
  KodDene('create domain var olan', Bag, 'create domain ' + DM + ' as integer');
  KodDene('create sequence var olan', Bag, 'create sequence ' + GN);
  KodDene('create view var olan', Bag, 'create view ' + VW + ' as select ID from ' + TB);
  KodDene('drop exception kullanilan', Bag, 'drop exception ' + EX);
  KodDene('drop domain kullanilan (tablo kolonu)', Bag, 'drop domain ' + DM);
  KodDene('drop sequence kullanilan (prosedur)', Bag, 'drop sequence ' + GN);
  KodDene('drop view bagimli', Bag, 'drop view ' + VW);
  KodDene('drop exception olmayan', Bag, 'drop exception FBY_YOK');
  KodDene('drop domain olmayan', Bag, 'drop domain FBY_YOK');
  KodDene('drop sequence olmayan', Bag, 'drop sequence FBY_YOK');
  KodDene('drop view olmayan', Bag, 'drop view FBY_YOK');
  KodDene('alter domain TO mevcut ad', Bag, 'alter domain ' + DM + ' to ' + DM + '_B');
  KodDene('alter domain drop constraint (check yok)', Bag, 'alter domain ' + DM + '_B drop constraint');
  KodDene('alter domain set default gecersiz', Bag, 'alter domain ' + DM + ' set default ''abc''');
  KodDene('alter domain add check hatali', Bag, 'alter domain ' + DM + '_B add check (value > ''x'')');
  KodDene('alter domain add check ikinci (zaten var)', Bag, 'alter domain ' + DM + ' add check (value < 100)');
  KodDene('alter domain olmayan', Bag, 'alter domain FBY_YOK set default 1');
  KodDene('set generator olmayan', Bag, 'set generator FBY_YOK to 5');
  KodDene('alter sequence restart (3.0+)', Bag, 'alter sequence ' + GN + ' restart with 7');
  KodDene('set generator (tum surumler)', Bag, 'set generator ' + GN + ' to 9');
  KodDene('create or alter exception', Bag, 'create or alter exception ' + EX + ' ''y''');
  KodDene('create or alter exception yeni ad', Bag, 'create or alter exception ' + EX + '_B ''y''');
  KodDene('drop sequence DROP GENERATOR sozdizimi', Bag, 'drop generator FBY_YOK');
  Not_('generator degeri: ' + Skaler(Bag, 'select gen_id(' + GN + ', 0) from rdb$database'));
end;

{ Yedek dosyasinin metni (kodlama: WIN1254 yazilir); yoksa ''. }
function YedekMetni(const Dosya: string): string;
begin
  if FileExists(Dosya) then
    Result := TFile.ReadAllText(Dosya, TEncoding.GetEncoding(1254))
  else
    Result := '';
end;

function IstisnaMesaji(const Ad: string): string;
begin
  Result := Skaler(Bag, 'select rdb$message from rdb$exceptions where rdb$exception_name = ''' + Ad + '''');
end;

{ ---------- 3f-3: Exception ---------- }

procedure IstisnaBolumu;
var
  Metin, Ad, Hata: string;
  Sonuc: TProsedurSonucu;
begin
  Cikti.Add('');
  Cikti.Add('=== B4) Exception: yeni, duzenle, kaydet (surum ' + Bag.Surum + ') ===');
  Temizle;
  Kontrol('Yeni ad dogrula: CREATE EXCEPTION kabul, ad okunur',
    (YeniNesneAdiniDogrula(ntIstisna, YeniNesneSablonu(ntIstisna), Ad) = '') and (Ad = 'YENI_EXCEPTION'));
  Kontrol('Yeni ad dogrula: CREATE OR ALTER EXCEPTION reddedilir (varolan sessizce ezilmesin)',
    YeniNesneAdiniDogrula(ntIstisna, 'CREATE OR ALTER EXCEPTION X ''m'';', Ad) = T('ERR_EXC_YENI_BASLIK_YOK'));
  Kontrol('Yeni ad dogrula: DOMAIN basligi exception sekmesinde reddedilir',
    YeniNesneAdiniDogrula(ntIstisna, 'CREATE DOMAIN X AS INTEGER;', Ad) <> '');
  Kontrol('Yeni ad dogrula: domain sablonu kabul', (YeniNesneAdiniDogrula(ntDomain, YeniNesneSablonu(ntDomain), Ad) = '') and (Ad = 'YENI_DOMAIN'));
  Kontrol('Yeni ad dogrula: tirnakli ad', (YeniNesneAdiniDogrula(ntIstisna, 'CREATE EXCEPTION "Kucuk Ad" ''m'';', Ad) = '') and (Ad = 'Kucuk Ad'));

  Sonuc := YeniNesneKaydet(Bag, ntIstisna, 'CREATE EXCEPTION ' + EX + ' ''ilk mesaj'';');
  if not Sonuc.Basarili then
    Not_('hata: ' + Sonuc.Cumle + ' / ' + Sonuc.Ayrinti);
  Kontrol('Yeni exception olusturuldu, sonuc adi dogru, tek komut, yedek yok',
    Sonuc.Basarili and (Sonuc.Ad = EX) and (Length(Sonuc.Komutlar) = 1) and (Sonuc.YedekDosyasi = '') and (IstisnaMesaji(EX) = 'ilk mesaj'));
  Sonuc := YeniNesneKaydet(Bag, ntIstisna, 'CREATE EXCEPTION ' + EX + ' ''baska'';');
  Not_('ad cakismasi: cumle=' + TekSatir(Sonuc.Cumle) + ' ayrinti=' + TekSatir(Sonuc.Ayrinti));
  Kontrol('Ad cakismasi: reddedildi, cumle ERR_NESNE_VAR, Ayrinti dolu, eski mesaj duruyor',
    (not Sonuc.Basarili) and (Sonuc.Cumle = T('ERR_NESNE_VAR')) and (Sonuc.Ayrinti <> '') and (IstisnaMesaji(EX) = 'ilk mesaj'));

  { Duzenle: CREATE OR ALTER EXCEPTION }
  Metin := IstisnaDuzenleScripti(Bag, EX);
  Kontrol('Duzenleme metni CREATE OR ALTER EXCEPTION ad ''mesaj'';, ad dogrulamasindan geciyor',
    (Pos('CREATE OR ALTER EXCEPTION ' + EX + ' ''ilk mesaj'';', Metin) = 1) and (NesneAdiniDogrula(ntIstisna, Metin, EX) = ''));
  Kontrol('NesneDuzenleMetni(ntIstisna) ayni metin', NesneDuzenleMetni(Bag, ntIstisna, EX) = Metin);
  Yurut(Bag, 'create procedure ' + PR + ' as begin exception ' + EX + '; end');
  Sonuc := NesneKaydet(Bag, ntIstisna, EX, StringReplace(Metin, 'ilk mesaj', 'ikinci mesaj', []));
  if not Sonuc.Basarili then
    Not_('hata: ' + Sonuc.Cumle + ' / ' + Sonuc.Ayrinti);
  Kontrol('Exception kaydedildi (mesaj degisti), tek komut', Sonuc.Basarili and (IstisnaMesaji(EX) = 'ikinci mesaj') and (Length(Sonuc.Komutlar) = 1));
  Hata := '';
  try
    Yurut(Bag, 'execute procedure ' + PR);
  except
    on E: Exception do
      Hata := E.Message;
  end;
  Kontrol('Prosedur exception''i yeni mesajla firlatiyor', Pos('ikinci mesaj', Hata) > 0);
  Kontrol('Yedek exception_ADI_...sql, eski mesaji iceriyor (CREATE OR ALTER EXCEPTION)',
    FileExists(Sonuc.YedekDosyasi) and StartsText('exception_' + EX + '_', ExtractFileName(Sonuc.YedekDosyasi)) and
    (Pos('ilk mesaj', YedekMetni(Sonuc.YedekDosyasi)) > 0) and (Pos('ikinci', YedekMetni(Sonuc.YedekDosyasi)) = 0));

  { Kurallar }
  Sonuc := NesneKaydet(Bag, ntIstisna, EX, 'CREATE OR ALTER EXCEPTION FBY_TEST_EX9 ''x'';');
  Kontrol('Ad degisikligi reddedildi (ERR_EXC_AD_DEGISTI), yeni exception olusmadi',
    (not Sonuc.Basarili) and (Sonuc.Cumle = TF('ERR_EXC_AD_DEGISTI', [EX, 'FBY_TEST_EX9'])) and (Length(Sonuc.Komutlar) = 0) and
    (Skaler(Bag, 'select count(*) from rdb$exceptions where rdb$exception_name = ''FBY_TEST_EX9''') = '0'));
  Sonuc := NesneKaydet(Bag, ntIstisna, EX, 'CREATE EXCEPTION ' + EX + ' ''x'';');
  Kontrol('Basliksiz (CREATE EXCEPTION) metin reddedildi', (not Sonuc.Basarili) and (Sonuc.Cumle = TF('ERR_EXC_BASLIK_YOK', [EX, EX])));
  Sonuc := NesneKaydet(Bag, ntIstisna, EX, 'CREATE OR ALTER EXCEPTION ' + EX + ' ''x'';');
  Sonuc := NesneKaydet(Bag, ntIstisna, EX, 'CREATE OR ALTER EXCEPTION ' + EX + ' ''x'' ZZ YY;');
  Kontrol('Sozdizimi hatasi: anlasilir cumle, eski mesaj duruyor (once ''x'' kaydedildi)',
    (not Sonuc.Basarili) and (Sonuc.Cumle = T('ERR_SQL_SOZDIZIMI')) and (IstisnaMesaji(EX) = 'x'));
  Sonuc := YedeksizKaydet(ntIstisna, EX, 'CREATE OR ALTER EXCEPTION ' + EX + ' ''z'';');
  Kontrol('Yedek yazilamadi: kaydetme durdu, exception degismedi',
    (not Sonuc.Basarili) and (Sonuc.Cumle = T('ERR_PRS_YEDEK_YAZILAMADI')) and (Length(Sonuc.Komutlar) = 0) and (IstisnaMesaji(EX) = 'x'));

  { Yeni domain }
  Sonuc := YeniNesneKaydet(Bag, ntDomain, 'CREATE DOMAIN ' + DM + ' AS VARCHAR(10);');
  Kontrol('Yeni domain olusturuldu', Sonuc.Basarili and (Sonuc.Ad = DM) and (Skaler(Bag, 'select count(*) from rdb$fields where rdb$field_name = ''' + DM + '''') = '1'));
  Sonuc := YeniNesneKaydet(Bag, ntDomain, 'CREATE DOMAIN ' + DM + ' AS INTEGER;');
  Not_('domain ad cakismasi: cumle=' + TekSatir(Sonuc.Cumle) + ' ayrinti=' + TekSatir(Sonuc.Ayrinti));
  Kontrol('Domain ad cakismasi: ERR_NESNE_VAR', (not Sonuc.Basarili) and (Sonuc.Cumle = T('ERR_NESNE_VAR')));
  Sonuc := YeniNesneKaydet(Bag, ntDomain, 'CREATE DOMAIN FBY_TEST_DM_X AS NOTATYPE;');
  Kontrol('Gecersiz domain tipi: anlasilir cumle, domain olusmadi',
    (not Sonuc.Basarili) and (Sonuc.Cumle <> '') and (Pos('ERR_', Sonuc.Cumle) = 0) and
    (Skaler(Bag, 'select count(*) from rdb$fields where rdb$field_name = ''FBY_TEST_DM_X''') = '0'));
  Not_('gecersiz tip: ' + TekSatir(Sonuc.Cumle) + ' | ' + TekSatir(Sonuc.Ayrinti));
end;

{ ---------- 3f-3: Silme ---------- }

procedure SilmeBolumu;
var
  Sonuc: TProsedurSonucu;
  Onay, Dosya, Dil: string;
  i, Once: Integer;
  Liste: TStringList;
begin
  Cikti.Add('');
  Cikti.Add('=== B5) Silme: bagimlilik listesi, onay metni, yedek, DROP (surum ' + Bag.Surum + ') ===');
  ViewKur;
  Yurut(Bag, 'create exception ' + EX + ' ''m''');
  Yurut(Bag, 'create domain ' + DM + ' as integer');
  Yurut(Bag, 'create sequence ' + GN);
  Yurut(Bag, 'create table ' + TB + '_D (ID integer, ADI ' + DM + ')');
  Yurut(Bag, 'create procedure ' + PR + ' as declare variable I integer; begin I = gen_id(' + GN + ', 1); exception ' + EX + '; end');

  Kontrol('Bagimlilik view: VW2 listede (tur view)',
    (Length(BagimliNesneler(Bag, bhView, VW)) = 1) and (BagimliNesneler(Bag, bhView, VW)[0].Ad = VW2) and (BagimliNesneler(Bag, bhView, VW)[0].Tur = 1));
  Kontrol('Bagimlilik exception: prosedur listede (tur 5)',
    (Length(BagimliNesneler(Bag, bhIstisna, EX)) = 1) and (BagimliNesneler(Bag, bhIstisna, EX)[0].Ad = PR) and (BagimliNesneler(Bag, bhIstisna, EX)[0].Tur = 5));
  Kontrol('Bagimlilik generator: prosedur listede', (Length(BagimliNesneler(Bag, bhGenerator, GN)) = 1) and (BagimliNesneler(Bag, bhGenerator, GN)[0].Ad = PR));
  Kontrol('Bagimlilik domain: tablo kolonu listede (TABLO.KOLON)',
    (Length(BagimliNesneler(Bag, bhDomain, DM)) = 1) and (BagimliNesneler(Bag, bhDomain, DM)[0].Ad = TB + '_D.ADI') and (BagimliNesneler(Bag, bhDomain, DM)[0].Tur = BAG_KOLON));
  Kontrol('Bagimlisi olmayan nesne: bos liste', Length(BagimliNesneler(Bag, bhView, VW2)) = 0);

  Onay := SilmeOnayMetni(Bag, ntView, VW);
  Not_('view onay metni: ' + TekSatir(Onay, 600));
  Kontrol('Onay metni: tur, ad, geri alinamaz+yedek blogu, kullananlar (VW2), soru',
    (Pos(TF('ONAY_SIL', [T('TUR_VIEW'), VW]), Onay) = 1) and (Pos(T('ONAY_SIL_BAGIMLI'), Onay) > 0) and (Pos(VW2, Onay) > 0) and
    (Pos(T('ONAY_SIL_SORU'), Onay) > 0) and (Pos('_arsiv', Onay) > 0));
  Kontrol('Onay metni: bagimlisiz nesnede "bulunamadi" cumlesi', Pos(T('ONAY_SIL_BAGIMLI_YOK'), SilmeOnayMetni(Bag, ntView, VW2)) > 0);

  { 13 prosedur ayni exception'i kullaniyor (PR dahil): en cok 10 satir + "ve 3 tane daha". }
  for i := 1 to 12 do
    Yurut(Bag, 'create procedure FBY_TEST_PX' + Format('%.2d', [i]) + ' as begin exception ' + EX + '; end');
  Onay := SilmeOnayMetni(Bag, ntIstisna, EX);
  Kontrol('13 kullanan: onay metninde 10 satir + "ve 3 tane daha"',
    (Pos(TF('ONAY_SIL_DAHA_FAZLA', [3]), Onay) > 0) and (Pos('FBY_TEST_PX', Onay) > 0));
  Liste := TStringList.Create;
  try
    Liste.Text := BagimlilikMetni(BagimliNesneler(Bag, bhIstisna, EX));
    Kontrol('Bagimlilik metni: tam 11 satir (10 madde + "daha")', Liste.Count = 11);
  finally
    Liste.Free;
  end;
  for i := 1 to 12 do
    Yurut(Bag, 'drop procedure FBY_TEST_PX' + Format('%.2d', [i]));

  { Kullanilan nesneler silinemez: anlasilir cumle, rollback, nesne duruyor. }
  Sonuc := NesneSil(Bag, ntIstisna, EX);
  Not_('kullanilan exception: cumle=' + TekSatir(Sonuc.Cumle) + ' ayrinti=' + TekSatir(Sonuc.Ayrinti));
  Kontrol('Kullanilan exception silinemez: ERR_NESNE_BAGIMLI, Ayrinti dolu, denenen SQL gorunur, exception duruyor',
    (not Sonuc.Basarili) and (Sonuc.Cumle = T('ERR_NESNE_BAGIMLI')) and (Sonuc.Ayrinti <> '') and (Length(Sonuc.Komutlar) = 1) and
    (Sonuc.Komutlar[0] = 'DROP EXCEPTION ' + EX) and (IstisnaMesaji(EX) = 'm'));
  Sonuc := NesneSil(Bag, ntGenerator, GN);
  Kontrol('Kullanilan generator silinemez: ERR_NESNE_BAGIMLI', (not Sonuc.Basarili) and (Sonuc.Cumle = T('ERR_NESNE_BAGIMLI')));
  Sonuc := NesneSil(Bag, ntDomain, DM);
  Not_('kullanilan domain: cumle=' + TekSatir(Sonuc.Cumle) + ' ayrinti=' + TekSatir(Sonuc.Ayrinti));
  Kontrol('Kolonda kullanilan domain silinemez: ERR_DOMAIN_KULLANILIYOR',
    (not Sonuc.Basarili) and (Sonuc.Cumle = T('ERR_DOMAIN_KULLANILIYOR')) and (Skaler(Bag, 'select count(*) from rdb$fields where rdb$field_name = ''' + DM + '''') = '1'));
  Sonuc := NesneSil(Bag, ntView, VW);
  Kontrol('Bagimlisi olan view silinemez: ERR_NESNE_BAGIMLI, view duruyor',
    (not Sonuc.Basarili) and (Sonuc.Cumle = T('ERR_NESNE_BAGIMLI')) and (ViewKolonlari(VW) = 'ID,AD'));
  Kontrol('Basarisiz silmede de eski tanim yedeklenmis (yedek dosyasi var)', FileExists(Sonuc.YedekDosyasi));

  { Basarili silme: once bagimlilar kalkar. }
  Yurut(Bag, 'drop procedure ' + PR);
  Once := YedekSayisi;
  Sonuc := NesneSil(Bag, ntIstisna, EX);
  Kontrol('Exception silindi (kullananlar kalkinca), SQL "DROP EXCEPTION ad"',
    Sonuc.Basarili and (Skaler(Bag, 'select count(*) from rdb$exceptions where rdb$exception_name = ''' + EX + '''') = '0') and
    (Length(Sonuc.Komutlar) = 1) and (Sonuc.Komutlar[0] = 'DROP EXCEPTION ' + EX));
  Dosya := Sonuc.YedekDosyasi;
  Kontrol('Silme yedegi: exception_ADI_...sql, tam CREATE EXCEPTION iceriyor',
    FileExists(Dosya) and StartsText('exception_' + EX + '_', ExtractFileName(Dosya)) and (Pos('CREATE EXCEPTION ' + EX + ' ''m'';', YedekMetni(Dosya)) > 0) and
    (YedekSayisi = Once + 1));
  Sonuc := NesneSil(Bag, ntGenerator, GN);
  Kontrol('Generator silindi, yedekte CREATE SEQUENCE',
    Sonuc.Basarili and (Skaler(Bag, 'select count(*) from rdb$generators where rdb$generator_name = ''' + GN + '''') = '0') and
    (Pos('CREATE SEQUENCE ' + GN, YedekMetni(Sonuc.YedekDosyasi)) > 0) and StartsText('generator_' + GN + '_', ExtractFileName(Sonuc.YedekDosyasi)));
  Sonuc := NesneSil(Bag, ntView, VW2);
  Kontrol('Bagimlisiz view silindi, yedekte tam CREATE VIEW', Sonuc.Basarili and (Pos('CREATE VIEW ' + VW2, YedekMetni(Sonuc.YedekDosyasi)) > 0));
  Sonuc := NesneSil(Bag, ntView, VW);
  Kontrol('Ustteki view de silindi (artik bagimlisi yok)', Sonuc.Basarili);
  Yurut(Bag, 'drop table ' + TB + '_D');
  Sonuc := NesneSil(Bag, ntDomain, DM);
  Kontrol('Domain kullanilmayinca silindi, yedekte CREATE DOMAIN',
    Sonuc.Basarili and (Pos('CREATE DOMAIN ' + DM + ' AS INTEGER', YedekMetni(Sonuc.YedekDosyasi)) > 0));

  { Olmayan nesne ve yedek yazilamiyor }
  Sonuc := NesneSil(Bag, ntView, 'FBY_YOK_BOYLE');
  Kontrol('Olmayan nesne: islem baslamaz, cumle "bulunamadi" (yedek hatasi DEGIL)', (not Sonuc.Basarili) and (Sonuc.Cumle <> '') and (Sonuc.Cumle <> T('ERR_PRS_YEDEK_YAZILAMADI')) and (Length(Sonuc.Komutlar) = 0));
  Not_('olmayan view silme: ' + TekSatir(Sonuc.Cumle) + ' | ' + TekSatir(Sonuc.Ayrinti));
  Yurut(Bag, 'create exception ' + EX + ' ''m''');
  Dosya := TPath.Combine(TPath.GetTempPath, 'nesnetest_yedeksiz');
  TDirectory.CreateDirectory(Dosya);
  TFile.WriteAllText(TPath.Combine(Dosya, '_arsiv'), 'engel');
  VeriKlasoruAyarla(Dosya);
  try
    Sonuc := NesneSil(Bag, ntIstisna, EX);
  finally
    VeriKlasoruAyarla(VeriKlasoru);
  end;
  TFile.Delete(TPath.Combine(Dosya, '_arsiv'));
  Kontrol('Yedek yazilamadi: silme baslamadi, exception duruyor',
    (not Sonuc.Basarili) and (Sonuc.Cumle = T('ERR_PRS_YEDEK_YAZILAMADI')) and (Length(Sonuc.Komutlar) = 0) and (IstisnaMesaji(EX) = 'm'));

  { Uc dilde yeni cumleler }
  for Dil in ['tr', 'en', 'de'] do
  begin
    DilYukle(Dil);
    Not_(Dil + ' ERR_NESNE_VAR: ' + TekSatir(T('ERR_NESNE_VAR')));
    Not_(Dil + ' ERR_DOMAIN_KULLANILIYOR: ' + TekSatir(T('ERR_DOMAIN_KULLANILIYOR')));
    Not_(Dil + ' ONAY_SIL: ' + TekSatir(TF('ONAY_SIL', [T('TUR_VIEW'), 'ORNEK'])));
    Kontrol('Dil ' + Dil + ': silme ve hata anahtarlari tanimli',
      (T('ERR_NESNE_VAR') <> 'ERR_NESNE_VAR') and (T('ERR_DOMAIN_KULLANILIYOR') <> 'ERR_DOMAIN_KULLANILIYOR') and
      (T('ONAY_SIL') <> 'ONAY_SIL') and (T('ONAY_SIL_BAGIMLI') <> 'ONAY_SIL_BAGIMLI') and (T('ONAY_SIL_DAHA_FAZLA') <> 'ONAY_SIL_DAHA_FAZLA'));
  end;
  DilYukle('tr');
end;

{ ---------- 3f-3: Domain degistirme ---------- }

function DomainBilgi(const Ad: string): TDomainBilgisi;
begin
  Result := DomainBilgisiOku(Bag, Ad);
end;

procedure DomainBolumu;
var
  Sonuc: TProsedurSonucu;
  Hata: string;
begin
  Cikti.Add('');
  Cikti.Add('=== B6) Domain: varsayilan, CHECK, ad degistirme (surum ' + Bag.Surum + ') ===');
  Temizle;
  Yurut(Bag, 'create domain ' + DM + ' as integer');
  Yurut(Bag, 'create table ' + TB + ' (ID integer, ADI ' + DM + ')');

  Kontrol('Komut metni: varsayilan SET DEFAULT', DomainKomutlari(Bag, DM, diVarsayilan, '5') = 'ALTER DOMAIN ' + DM + ' SET DEFAULT 5');
  Kontrol('Komut metni: "DEFAULT 5" yazilsa da ayni', DomainKomutlari(Bag, DM, diVarsayilan, 'default 5') = 'ALTER DOMAIN ' + DM + ' SET DEFAULT 5');
  Kontrol('Komut metni: bos varsayilan DROP DEFAULT', DomainKomutlari(Bag, DM, diVarsayilan, '  ') = 'ALTER DOMAIN ' + DM + ' DROP DEFAULT');
  Kontrol('Komut metni: CHECK once DROP CONSTRAINT sonra ADD CHECK (parantez eklenir)',
    DomainKomutlari(Bag, DM, diKontrol, 'VALUE > 0') = 'ALTER DOMAIN ' + DM + ' DROP CONSTRAINT;' + sLineBreak + 'ALTER DOMAIN ' + DM + ' ADD CHECK (VALUE > 0)');
  Kontrol('Komut metni: bos CHECK yalniz DROP CONSTRAINT', DomainKomutlari(Bag, DM, diKontrol, '') = 'ALTER DOMAIN ' + DM + ' DROP CONSTRAINT');
  Kontrol('Komut metni: ad TO yeniad', DomainKomutlari(Bag, DM, diAd, ' ' + DM + '_B ') = 'ALTER DOMAIN ' + DM + ' TO ' + DM + '_B');
  Kontrol('Mevcut deger: ad', DomainMevcutDeger(Bag, DM, diAd) = DM);
  Kontrol('Mevcut deger: varsayilan/CHECK yokken bos', (DomainMevcutDeger(Bag, DM, diVarsayilan) = '') and (DomainMevcutDeger(Bag, DM, diKontrol) = ''));

  { Varsayilan }
  Sonuc := DomainDegistir(Bag, DM, diVarsayilan, '7');
  if not Sonuc.Basarili then
    Not_('hata: ' + Sonuc.Cumle + ' / ' + Sonuc.Ayrinti);
  Kontrol('Varsayilan 7 atandi: domain bilgisinde, tek komut SQL',
    Sonuc.Basarili and ContainsText(DomainBilgi(DM).Varsayilan, '7') and (Length(Sonuc.Komutlar) = 1) and (Sonuc.Komutlar[0] = 'ALTER DOMAIN ' + DM + ' SET DEFAULT 7'));
  Yurut(Bag, 'insert into ' + TB + ' (ID) values (1)');
  Kontrol('Yeni satirin kolonu domain varsayilani 7', Skaler(Bag, 'select ADI from ' + TB + ' where ID = 1') = '7');
  Kontrol('Mevcut deger kutusu: "7"', DomainMevcutDeger(Bag, DM, diVarsayilan) = '7');
  Kontrol('Yedek domain_ADI_...sql ESKI hali (varsayilansiz) iceriyor',
    FileExists(Sonuc.YedekDosyasi) and StartsText('domain_' + DM + '_', ExtractFileName(Sonuc.YedekDosyasi)) and
    (Pos('CREATE DOMAIN ' + DM + ' AS INTEGER;', YedekMetni(Sonuc.YedekDosyasi)) > 0));
  Sonuc := DomainDegistir(Bag, DM, diVarsayilan, '');
  Kontrol('Varsayilan kaldirildi', Sonuc.Basarili and (DomainBilgi(DM).Varsayilan = ''));

  { CHECK }
  Sonuc := DomainDegistir(Bag, DM, diKontrol, 'VALUE > 0');
  if not Sonuc.Basarili then
    Not_('hata: ' + Sonuc.Cumle + ' / ' + Sonuc.Ayrinti);
  Kontrol('CHECK eklendi (iki komut: DROP CONSTRAINT, ADD CHECK)', Sonuc.Basarili and (Length(Sonuc.Komutlar) = 2) and ContainsText(DomainBilgi(DM).Kontrol, 'VALUE > 0'));
  Hata := '';
  try
    Yurut(Bag, 'insert into ' + TB + ' (ID, ADI) values (2, -5)');
  except
    on E: Exception do
      Hata := E.Message;
  end;
  Kontrol('CHECK calisiyor: -5 reddedilir', Hata <> '');
  Kontrol('Mevcut deger kutusu: CHECK ifadesi', ContainsText(DomainMevcutDeger(Bag, DM, diKontrol), 'VALUE > 0'));
  Sonuc := DomainDegistir(Bag, DM, diKontrol, 'CHECK (VALUE < 100)');
  Kontrol('CHECK degistirildi (eski kalkti, yenisi geldi)',
    Sonuc.Basarili and ContainsText(DomainBilgi(DM).Kontrol, 'VALUE < 100') and not ContainsText(DomainBilgi(DM).Kontrol, 'VALUE > 0'));
  { Hatali ifade: ikinci komut hata verir; ilk komut (DROP CONSTRAINT) da geri alinmali. }
  Sonuc := DomainDegistir(Bag, DM, diKontrol, '(VALUE >');
  Not_('hatali CHECK: cumle=' + TekSatir(Sonuc.Cumle) + ' ayrinti=' + TekSatir(Sonuc.Ayrinti));
  Kontrol('Hatali CHECK: reddedildi, anlasilir cumle, ESKI CHECK duruyor (tek islem, rollback)',
    (not Sonuc.Basarili) and (Sonuc.Cumle <> '') and (Pos('ERR_', Sonuc.Cumle) = 0) and ContainsText(DomainBilgi(DM).Kontrol, 'VALUE < 100'));
  Sonuc := DomainDegistir(Bag, DM, diKontrol, '');
  Kontrol('CHECK kaldirildi', Sonuc.Basarili and (DomainBilgi(DM).Kontrol = ''));

  { Ad }
  Yurut(Bag, 'create domain ' + DM + '_C as integer');
  Sonuc := DomainDegistir(Bag, DM, diAd, DM + '_C');
  Not_('var olan ada tasima: cumle=' + TekSatir(Sonuc.Cumle) + ' ayrinti=' + TekSatir(Sonuc.Ayrinti));
  Kontrol('Var olan ada tasima reddedildi: ERR_NESNE_VAR', (not Sonuc.Basarili) and (Sonuc.Cumle = T('ERR_NESNE_VAR')));
  Sonuc := DomainDegistir(Bag, DM, diAd, '   ');
  Kontrol('Bos yeni ad: ERR_DOM_AD_BOS, veritabanina dokunulmadi', (not Sonuc.Basarili) and (Sonuc.Cumle = T('ERR_DOM_AD_BOS')) and (Length(Sonuc.Komutlar) = 0));
  Sonuc := DomainDegistir(Bag, DM, diAd, DM + '_B');
  if not Sonuc.Basarili then
    Not_('hata: ' + Sonuc.Cumle + ' / ' + Sonuc.Ayrinti);
  Kontrol('Domain yeniden adlandirildi (sonuc adi yeni), eski ad yok, tablo kolonu yeni domain adini kullaniyor',
    Sonuc.Basarili and (Sonuc.Ad = DM + '_B') and (Skaler(Bag, 'select count(*) from rdb$fields where rdb$field_name = ''' + DM + '''') = '0') and
    (Skaler(Bag, 'select trim(rdb$field_source) from rdb$relation_fields where rdb$relation_name = ''' + TB + ''' and rdb$field_name = ''ADI''') = DM + '_B'));
  Sonuc := DomainDegistir(Bag, 'FBY_YOK_BOYLE', diVarsayilan, '1');
  Kontrol('Olmayan domain: anlasilir cumle, komut calismadi (yedek icin tanim okunamaz)', (not Sonuc.Basarili) and (Sonuc.Cumle <> '') and (Length(Sonuc.Komutlar) = 0));
  Kontrol('Onay metni: SQL komutu ve kullananlar (tablo kolonu) gorunuyor',
    (Pos('ALTER DOMAIN', DomainOnayMetni(Bag, DM + '_B', DomainKomutlari(Bag, DM + '_B', diVarsayilan, '3'))) > 0) and
    (Pos(TB + '.ADI', DomainOnayMetni(Bag, DM + '_B', 'x')) > 0));
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
          HataKesfiBolumu;
          ListeBolumu;
          ViewBolumu;
          IstisnaBolumu;
          SilmeBolumu;
          DomainBolumu;
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
