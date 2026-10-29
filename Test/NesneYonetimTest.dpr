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
