program VeriFarkTest;

{ Asama 7u: uVeriFark (iki tablonun verisini birincil anahtarla karsilastirma) testi (komut satiri).

  Gecici bir veritabani acilir (varsayilan: gomulu Firebird); K (kaynak) ve H (hedef) tablolari konur. Beklenen fark:
  yalniz kaynakta 1 satir, farkli 2 satir, yalniz hedefte 1 satir, ayni 2 satir. Uretilen script hedefte calistirilir ve
  tekrar karsilastirilir: fark kalmamali. Ayrica anahtarsiz tablo, farkli anahtar ve cok buyuk tablo hatalari denenir.
  Ortam degiskenleri: FBTEST_SUNUCU (bos = gomulu), FBTEST_PORT, FBTEST_KLASOR, FBTEST_KULLANICI, FBTEST_SIFRE,
  FBTEST_CIKTI (sonuc dosyasi). Gomulu kipte biten veritabani _arsiv klasorune tasinir (silinmez).
  Cikis kodu: hata sayisi (0 = hepsi gecti). }

{$APPTYPE CONSOLE}

uses
  Winapi.Windows,
  System.SysUtils, System.Classes, System.StrUtils, System.IOUtils, Data.DB,
  FireDAC.Stan.Error, FireDAC.Comp.Client, FireDAC.Phys.FB,
  uDil, uBaglanti, uSorgu, uVeriFark;

var
  Cikti: TStringList;
  Hatalar, KontrolSayisi: Integer;
  Bag: TAcikBaglanti;
  Klasor: string;
  Tanim: TBaglantiTanimi;

function Ortam(const Ad, Varsayilan: string): string;
begin
  Result := GetEnvironmentVariable(Ad);
  if Result = '' then
    Result := Varsayilan;
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

procedure GeciciVeritabaniOlustur(const Tanim: TBaglantiTanimi);
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
    if Tanim.Sunucu <> '' then
    begin
      Baglanti.Params.Values['Server'] := Tanim.Sunucu;
      Baglanti.Params.Values['Port'] := IntToStr(Tanim.Port);
      Baglanti.Params.Values['Protocol'] := 'TCPIP';
    end;
    Baglanti.Params.Values['Database'] := Tanim.VeritabaniYolu;
    Baglanti.Params.Values['User_Name'] := Tanim.Kullanici;
    Baglanti.Params.Values['Password'] := Tanim.Sifre;
    Baglanti.Params.Values['OpenMode'] := 'Create';
    Baglanti.Params.Values['CharacterSet'] := Tanim.KarakterSeti;
    Baglanti.Open;
    Baglanti.Close;
  finally
    Baglanti.Free;
    Surucu.Free;
  end;
end;

procedure Komut(const Sql: string);
begin
  SorguCalistir(Bag, Sql).Free;
end;

function Var_(const Metin, Aranan: string): Boolean;
begin
  Result := Pos(Aranan, Metin) > 0;
end;

procedure TablolariKur;
begin
  Komut('CREATE TABLE K (ID INTEGER NOT NULL PRIMARY KEY, AD VARCHAR(30), TUTAR NUMERIC(10,2), TAR DATE, ' +
    'NOTM BLOB SUB_TYPE TEXT, IKILI BLOB SUB_TYPE BINARY, ZAMAN TIMESTAMP, EKSTRA INTEGER)');
  Komut('CREATE TABLE H (ID INTEGER NOT NULL PRIMARY KEY, AD VARCHAR(30), TUTAR NUMERIC(10,2), TAR DATE, ' +
    'NOTM BLOB SUB_TYPE TEXT, IKILI BLOB SUB_TYPE BINARY, ZAMAN TIMESTAMP, ESKI VARCHAR(5))');
  { Ayni: 1 ve 5 }
  Komut('INSERT INTO K VALUES (1, ''ayni'', 10.50, ''2026-01-01'', ''not'', ''x'', ''2026-01-01 10:00:00'', 1)');
  Komut('INSERT INTO H VALUES (1, ''ayni'', 10.5, ''2026-01-01'', ''not'', ''y'', ''2026-01-01 10:00:00'', ''e'')');
  Komut('INSERT INTO K (ID) VALUES (5)');
  Komut('INSERT INTO H (ID) VALUES (5)');
  { Farkli: 2 (yalniz AD), 4 (TUTAR NULL'dan degere) }
  Komut('INSERT INTO K (ID, AD, TUTAR) VALUES (2, ''yeni'', 5)');
  Komut('INSERT INTO H (ID, AD, TUTAR) VALUES (2, ''eski'', 5)');
  Komut('INSERT INTO K (ID, AD, TUTAR) VALUES (4, ''d'', 7.25)');
  Komut('INSERT INTO H (ID, AD) VALUES (4, ''d'')');
  { Yalniz kaynakta: 3 (kesme isareti, Turkce karakter, kesirli saniye) }
  Komut('INSERT INTO K (ID, AD, ZAMAN) VALUES (3, ''O''''Brien ' + #$015F + ''', ''2026-03-03 03:03:03.5000'')');
  { Yalniz hedefte: 6 }
  Komut('INSERT INTO H (ID, AD) VALUES (6, ''fazla'')');
  { Hatalar icin: anahtarsiz tablo, farkli anahtar, cok buyuk tablo }
  Komut('CREATE TABLE ANAHTARSIZ (ID INTEGER, AD VARCHAR(30))');
  Komut('CREATE TABLE FARKLI_PK (AD VARCHAR(30) NOT NULL PRIMARY KEY, ID INTEGER)');
  Komut('CREATE TABLE BUYUK (ID INTEGER NOT NULL PRIMARY KEY, AD VARCHAR(30))');
  Komut('EXECUTE BLOCK AS DECLARE VARIABLE I INTEGER; BEGIN I = 1; WHILE (I <= ' + IntToStr(VERI_FARK_SATIR_SINIRI + 1) +
    ') DO BEGIN INSERT INTO BUYUK VALUES (:I, ''x''); I = I + 1; END END');
end;

procedure DilAnahtarTesti;
const
  ANAHTARLAR: array[0..26] of string = ('BTN_VERI_FARKI', 'VF_BASLIK', 'VF_KAYNAK', 'VF_HEDEF', 'VF_SIL', 'VF_KARSILASTIR',
    'VF_SCRIPT_AC', 'VF_CALISIYOR', 'VF_SONUC', 'VF_DELETE_YAZILDI', 'VF_DELETE_YAZILMADI', 'VF_AYNI_TABLO', 'VF_KOMUT_YOK',
    'VF_BITTI', 'ERR_VF_SECIM', 'ERR_VF_AYNI', 'ERR_VF_YAPILAMADI', 'ERR_VF_ANAHTAR_YOK', 'ERR_VF_ANAHTAR_FARKLI',
    'ERR_VF_COK_BUYUK', 'VF_UYARI_IKILI', 'VF_UYARI_KOMUT_SINIRI', 'VF_SCRIPT_BASLIK', 'VF_SCRIPT_OZET',
    'VF_SCRIPT_CALISTIRMA', 'VF_SCRIPT_SILME_YOK', 'BTN_KAPAT');
var
  Dil, Anahtar, Eksik: string;
begin
  for Dil in ['tr', 'en', 'de'] do
  begin
    DilYukle(Dil);
    Eksik := '';
    for Anahtar in ANAHTARLAR do
      if T(Anahtar) = Anahtar then
        Eksik := Eksik + ' ' + Anahtar;
    Kontrol('dil ' + Dil + ': tum veri farki anahtarlari var' + IfThen(Eksik <> '', ' (eksik:' + Eksik + ')', ''), Eksik = '');
  end;
  DilYukle('tr');
end;

{ Script'teki her satiri (yorum ve bos satirlar disinda) calistirir; calistirilan komut sayisini verir.
  Test verisinde satir sonu olmadigi icin her komut tek satirdir. }
function ScriptiCalistir(const Script: string): Integer;
var
  Satir: string;
  Satirlar: TStringList;
begin
  Result := 0;
  Satirlar := TStringList.Create;
  try
    Satirlar.Text := Script;
    for Satir in Satirlar do
      if (Trim(Satir) <> '') and not StartsStr('--', Trim(Satir)) then
      begin
        Komut(Copy(Trim(Satir), 1, Length(Trim(Satir)) - 1));
        Inc(Result);
      end;
  finally
    Satirlar.Free;
  end;
end;

procedure KarsilastirmaTesti;
var
  S, Ikinci: TVeriFarkSonucu;
  Silmesiz: TVeriFarkSonucu;
begin
  { 1. Silme yazilmadan }
  Silmesiz := VeriFarkiBul(Bag, 'K', Bag, 'H', False);
  Kontrol('silmesiz: basarili', Silmesiz.Basarili);
  Kontrol('silmesiz: sayilar (kaynakta 1, farkli 2, hedefte 1, ayni 2)',
    (Silmesiz.SadeceKaynakta = 1) and (Silmesiz.Farkli = 2) and (Silmesiz.SadeceHedefte = 1) and (Silmesiz.Ayni = 2));
  Kontrol('silmesiz: DELETE yok ve bunun notu var', not Var_(Silmesiz.Script, 'DELETE FROM') and Var_(Silmesiz.Script, '-- ') and
    Var_(Silmesiz.Script, T('VF_SCRIPT_SILME_YOK')));
  Kontrol('silmesiz: INSERT (kesme isareti, Turkce, kesirli saniye)',
    Var_(Silmesiz.Script, 'INSERT INTO "H" ("ID", "AD", "TUTAR", "TAR", "NOTM", "ZAMAN") VALUES (3, ''O''''Brien ' + #$015F +
      ''', NULL, NULL, NULL, ''2026-03-03 03:03:03.500'');'));
  Kontrol('silmesiz: UPDATE yalniz farkli kolonu atar (AD)', Var_(Silmesiz.Script, 'UPDATE "H" SET "AD" = ''yeni'' WHERE "ID" = 2;'));
  Kontrol('silmesiz: UPDATE NULL olan kolona deger (TUTAR)', Var_(Silmesiz.Script, 'UPDATE "H" SET "TUTAR" = 7.25 WHERE "ID" = 4;'));
  Kontrol('silmesiz: ikili kolon uyarisi (IKILI)', (Length(Silmesiz.Uyarilar) = 1) and Var_(Silmesiz.Uyarilar[0], 'IKILI'));
  Kontrol('silmesiz: kaynakta olmayan kolon (EKSTRA, ESKI) yazilmadi', not Var_(Silmesiz.Script, 'EKSTRA') and not Var_(Silmesiz.Script, 'ESKI'));

  { 2. Silme yazilarak, script'i hedefte calistirip yeniden karsilastir }
  S := VeriFarkiBul(Bag, 'K', Bag, 'H', True);
  Kontrol('silmeli: DELETE yazildi', Var_(S.Script, 'DELETE FROM "H" WHERE "ID" = 6;') and not Var_(S.Script, T('VF_SCRIPT_SILME_YOK')));
  Kontrol('silmeli: 4 komut calisti (1 INSERT, 2 UPDATE, 1 DELETE)', ScriptiCalistir(S.Script) = 4);
  Ikinci := VeriFarkiBul(Bag, 'K', Bag, 'H', True);
  Kontrol('script sonrasi: fark kalmadi (kaynakta 0, farkli 0, hedefte 0, ayni 5), script bos',
    Ikinci.Basarili and (Ikinci.SadeceKaynakta = 0) and (Ikinci.Farkli = 0) and (Ikinci.SadeceHedefte = 0) and
    (Ikinci.Ayni = 5) and (Ikinci.Script = ''));

  { 3. Hatalar }
  S := VeriFarkiBul(Bag, 'ANAHTARSIZ', Bag, 'H', False);
  Kontrol('anahtarsiz tablo: anlasilir cumle', (not S.Basarili) and (S.Cumle = T('ERR_VF_ANAHTAR_YOK')));
  S := VeriFarkiBul(Bag, 'K', Bag, 'FARKLI_PK', False);
  Kontrol('farkli anahtar: anlasilir cumle', (not S.Basarili) and (S.Cumle = T('ERR_VF_ANAHTAR_FARKLI')));
  S := VeriFarkiBul(Bag, 'K', Bag, 'BUYUK', False);
  Kontrol('cok buyuk hedef: hicbir sey yapilmadi, cumle', (not S.Basarili) and (S.Cumle = TF('ERR_VF_COK_BUYUK', ['BUYUK', VERI_FARK_SATIR_SINIRI])));
  S := VeriFarkiBul(Bag, 'BUYUK', Bag, 'K', False);
  Kontrol('cok buyuk kaynak: hicbir sey yapilmadi, cumle', (not S.Basarili) and Var_(S.Cumle, IntToStr(VERI_FARK_SATIR_SINIRI)));
  S := VeriFarkiBul(Bag, 'OLMAYAN_TABLO', Bag, 'H', False);
  Kontrol('olmayan tablo: anlasilir cumle (istisna disari cikmaz)', (not S.Basarili) and (S.Cumle <> ''));
end;

procedure ArsiveTasi(const Dosya: string);
var
  Arsiv: string;
begin
  if not FileExists(Dosya) then
    Exit;
  Arsiv := TPath.Combine(ExtractFilePath(Dosya), '_arsiv');
  ForceDirectories(Arsiv);
  TFile.Move(Dosya, TPath.Combine(Arsiv, ExtractFileName(Dosya)));
end;

begin
  Cikti := TStringList.Create;
  Bag := nil;
  try
    try
      DilYukle('tr');
      Klasor := Ortam('FBTEST_KLASOR', TPath.Combine(GetEnvironmentVariable('TEMP'), 'verifarktest'));
      if Ortam('FBTEST_SUNUCU', '') = '' then
        ForceDirectories(Klasor);
      Tanim := Default(TBaglantiTanimi);
      Tanim.Ad := 'verifarktest';
      Tanim.Sunucu := Ortam('FBTEST_SUNUCU', '');
      Tanim.Port := StrToInt(Ortam('FBTEST_PORT', '3050'));
      Tanim.VeritabaniYolu := IncludeTrailingPathDelimiter(Klasor) + 'verifarktest_' +
        FormatDateTime('yyyymmdd_hhnnss', Now) + '.fdb';
      Tanim.Kullanici := Ortam('FBTEST_KULLANICI', 'SYSDBA');
      Tanim.Sifre := Ortam('FBTEST_SIFRE', '');
      Tanim.KarakterSeti := VARSAYILAN_KARAKTER_SETI;
      GeciciVeritabaniOlustur(Tanim);
      Bag := FbBaglan(Tanim);
      Cikti.Add('--- Surum ' + Bag.Surum + ' ---');
      DilAnahtarTesti;
      TablolariKur;
      KarsilastirmaTesti;
      FbBaglantiyiKes(Bag);
      Bag := nil;
      if Tanim.Sunucu = '' then
        ArsiveTasi(Tanim.VeritabaniYolu);
    except
      on E: Exception do
      begin
        Cikti.Add('HATA  beklenmeyen istisna: ' + E.ClassName + ': ' + E.Message);
        Inc(Hatalar);
      end;
    end;
    Cikti.Add('');
    Cikti.Add('Kontrol sayisi: ' + IntToStr(KontrolSayisi) + ', Hata sayisi: ' + IntToStr(Hatalar));
    if Ortam('FBTEST_CIKTI', '') <> '' then
      Cikti.SaveToFile(Ortam('FBTEST_CIKTI', ''), TEncoding.UTF8)
    else
      Writeln(Cikti.Text);
  finally
    Cikti.Free;
  end;
  ExitCode := Hatalar;
end.
