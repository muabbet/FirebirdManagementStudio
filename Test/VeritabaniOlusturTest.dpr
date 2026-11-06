program VeritabaniOlusturTest;

{ Yeni veritabani olusturma (uBaglanti.FbVeritabaniOlustur) ve WIN1251 veritabaninda 4d ile Turkce harf yazma testi
  (komut satiri). Gercek veriye dokunulmaz; kendi gecici veritabanlarini kurar, biten dosyalar _arsiv'e tasinir.
  Ortam degiskenleri: FBTEST_SUNUCU (bos = yerel), FBTEST_PORT, FBTEST_KLASOR, FBTEST_KULLANICI, FBTEST_SIFRE,
  FBTEST_CIKTI. Cikis kodu: hata sayisi (0 = hepsi gecti). }

{$APPTYPE CONSOLE}

uses
  System.SysUtils, System.Classes, System.StrUtils, System.IOUtils, System.Variants, Data.DB,
  FireDAC.Stan.Intf, FireDAC.Stan.Option, FireDAC.Stan.Error, FireDAC.Comp.Client, FireDAC.Phys.FB,
  FireDAC.ConsoleUI.Wait,
  uDil, uBaglanti, uSorgu, uCokluSorgu, uKayitDuzelt;

const
  { c g i(noktasiz) o s u bosluk C G I(noktali) O S U }
  TURKCE = #$00E7#$011F#$0131#$00F6#$015F#$00FC' '#$00C7#$011E#$0130#$00D6#$015E#$00DC;

var
  Cikti: TStringList;
  Hatalar, KontrolSayisi: Integer;
  Bag: TAcikBaglanti;

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

function TekSatir(const Metin: string): string;
begin
  Result := StringReplace(StringReplace(Metin, #13, '', [rfReplaceAll]), #10, ' | ', [rfReplaceAll]);
end;

function Oku(const Sql: string): string;
var
  Q: TFDQuery;
begin
  Q := TFDQuery.Create(nil);
  try
    Q.Connection := Bag.Baglanti;
    Q.SQL.Text := Sql;
    Q.Open;
    if Q.Fields[0].IsNull then
      Result := '<NULL>'
    else
      Result := Q.Fields[0].AsString;
  finally
    Q.Free;
  end;
end;

function KodNoktalari(const S: string): string;
var
  C: Char;
begin
  Result := '';
  for C in S do
    Result := Result + IntToHex(Ord(C), 4) + ' ';
end;

function TanimYap(const Ad, Yol, KarakterSeti: string): TBaglantiTanimi;
begin
  Result := Default(TBaglantiTanimi);
  Result.Ad := Ad;
  Result.Sunucu := Ortam('FBTEST_SUNUCU', '');
  Result.Port := StrToInt(Ortam('FBTEST_PORT', '3050'));
  Result.VeritabaniYolu := Yol;
  Result.Kullanici := Ortam('FBTEST_KULLANICI', 'SYSDBA');
  Result.Sifre := Ortam('FBTEST_SIFRE', '');
  Result.KarakterSeti := KarakterSeti;
end;

var
  Klasor, Yol, Yol2, Damga, Mesaj: string;
  Tanim: TBaglantiTanimi;
  Boyut1, Boyut2: Int64;
  Gomulu: Boolean;
  Veri: TFDQuery;
  D: TKayitDuzelt;
  Sonuc: TDuzeltSonucu;
begin
  Cikti := TStringList.Create;
  Bag := nil;
  try
    try
      DilYukle('tr');
      Gomulu := Ortam('FBTEST_SUNUCU', '') = '';
      Klasor := Ortam('FBTEST_KLASOR', TPath.Combine(GetEnvironmentVariable('TEMP'), 'olusturtest'));
      if Gomulu then
        ForceDirectories(Klasor);
      Damga := FormatDateTime('yyyymmdd_hhnnss', Now);
      Yol := IncludeTrailingPathDelimiter(Klasor) + 'win1251_' + Damga + '.fdb';

      Cikti.Add('--- 1. WIN1251 veritabani olustur ---');
      Tanim := TanimYap('olusturtest', Yol, 'WIN1251');
      FbVeritabaniOlustur(Tanim);
      Kontrol('dosya olustu', (not Gomulu) or FileExists(Yol));
      Kontrol('varsayilan karakter seti WIN1251', KarakterSetiAlgila(Tanim) = 'WIN1251');
      Boyut1 := 0;
      if Gomulu then
        Boyut1 := TFile.GetSize(Yol);

      Cikti.Add('--- 1b. Onay metni ve dil anahtarlari ---');
      Kontrol('CREATE DATABASE metni (sifre gizli)', Pos('PASSWORD ''***'' PAGE_SIZE 8192 DEFAULT CHARACTER SET WIN1251;', VeritabaniOlusturSql(Tanim)) > 0);
      for Mesaj in ['tr', 'en', 'de'] do
      begin
        DilYukle(Mesaj);
        Kontrol('dil ' + Mesaj + ': 3 yeni anahtar tam', (T('BTN_VT_OLUSTUR') <> 'BTN_VT_OLUSTUR') and
          (T('ONAY_VT_OLUSTUR') <> 'ONAY_VT_OLUSTUR') and (T('ERR_VT_OLUSTURULAMADI') <> 'ERR_VT_OLUSTURULAMADI'));
      end;
      DilYukle('tr');
      Kontrol('YapiKomutuMu: CREATE/ALTER/DROP/RECREATE ve yorumla baslayan evet; SELECT/INSERT/UPDATE hayir',
        YapiKomutuMu('create table a (id integer)') and YapiKomutuMu('  ALTER TABLE a ADD b INTEGER') and
        YapiKomutuMu('DROP TABLE a') and YapiKomutuMu('recreate view v as select 1 from rdb$database') and
        YapiKomutuMu('-- not' + #13#10 + 'CREATE TABLE b (id integer)') and not YapiKomutuMu('select * from a') and
        not YapiKomutuMu('insert into a values (1)') and not YapiKomutuMu('update a set b = 1'));
      Cikti.Add('--- 2. Ayni yola tekrar olustur: reddedilmeli, dosya ezilmemeli ---');
      Mesaj := '';
      try
        FbVeritabaniOlustur(Tanim);
      except
        on E: Exception do
          Mesaj := E.Message;
      end;
      Cikti.Add('      ham mesaj: ' + TekSatir(Mesaj));
      Kontrol('ikinci olusturma hata verdi', Mesaj <> '');
      if Gomulu then
      begin
        Boyut2 := TFile.GetSize(Yol);
        Kontrol('dosya boyutu ayni (ezilmedi)', Boyut1 = Boyut2);
      end;
      Kontrol('hala WIN1251 ve acilabiliyor', KarakterSetiAlgila(Tanim) = 'WIN1251');

      Cikti.Add('--- 3. Olmayan klasore olustur ---');
      Yol2 := IncludeTrailingPathDelimiter(Klasor) + 'yok_klasor_' + Damga + '\x.fdb';
      Mesaj := '';
      try
        FbVeritabaniOlustur(TanimYap('olusturtest2', Yol2, 'WIN1251'));
      except
        on E: Exception do
          Mesaj := E.Message;
      end;
      Cikti.Add('      ham mesaj: ' + TekSatir(Mesaj));
      Kontrol('olmayan klasorde hata verdi', Mesaj <> '');

      Cikti.Add('--- 4. WIN1251 veritabaninda 4d ile Turkce harf yaz ve geri oku ---');
      Bag := FbBaglan(Tanim);
      SorguCalistir(Bag, 'CREATE TABLE T_TURKCE_TEST (ID INTEGER NOT NULL PRIMARY KEY, AD VARCHAR(60))').Free;
      SorguCalistir(Bag, 'INSERT INTO T_TURKCE_TEST VALUES (1, ''x'')').Free;
      Veri := DuzeltilebilirVeriSorgusu(Bag, 'T_TURKCE_TEST', 100, nil);
      D := TKayitDuzelt.Create(Bag, 'T_TURKCE_TEST', Veri, nil);
      try
        D.Ac;
        Veri.Locate('ID', 1, []);
        Veri.Edit;
        Veri.FieldByName('AD').AsString := TURKCE;
        Veri.Post;
        D.YeniKayit;
        Veri.FieldByName('ID').AsInteger := 2;
        Veri.FieldByName('AD').AsString := TURKCE + ' yeni';
        Veri.Post;
        Sonuc := D.Kaydet;
        Kontrol('Kaydet basarili', Sonuc.Basarili);
        if not Sonuc.Basarili then
          Cikti.Add('      ' + Sonuc.Cumle + ' | ' + Sonuc.Ayrinti);
      finally
        D.Free;
        Veri.Free;
      end;
      Kontrol('duzenlenen kayit geri okununca ayni', Oku('select ad from t_turkce_test where id = 1') = TURKCE);
      Kontrol('yeni kayit geri okununca ayni', Oku('select ad from t_turkce_test where id = 2') = TURKCE + ' yeni');
      Kontrol('CHAR_LENGTH 13 (harf sayisi, bozulma yok)',
        Oku('select char_length(ad) from t_turkce_test where id = 1') = '13');
      Kontrol('OCTET_LENGTH 13 (WIN1251 tek bayt)',
        Oku('select octet_length(ad) from t_turkce_test where id = 1') = '13');
      FbBaglantiyiKes(Bag);
      Bag := nil;
      Tanim.KarakterSeti := 'UTF8';
      Tanim.Ad := 'olusturtest_utf8';
      Bag := FbBaglan(Tanim);
      Cikti.Add('      ham baytlar (hex): ' + Oku('select hex_encode(cast(ad as varbinary(60))) from t_turkce_test where id = 1'));
      Cikti.Add('      UTF8 ile okunan (kod noktalari): ' + KodNoktalari(Oku('select ad from t_turkce_test where id = 1')));
      { BILINEN SINIR (bkz. ASAMA4A_RAPOR.md): FireDAC WIN1251 baglantisini WIN1254 gibi isler. Turkce harfler WIN1251 DB'ye
        WIN1254 baytlariyla yazilir (okuma ayni yoldan geri cevirir, bu yuzden bizde dogru gorunur). Gercek WIN1251 okuyucu
        (UTF8 baglanti) ayni baytlari Kiril harf diye gorur. Asagidaki kontrol bu davranisi KAYDEDER (degisirse haber versin). }
      Kontrol('WIN1251 veritabanina Turkce harfler WIN1254 baytlariyla yazildi (bilinen sinir)',
        Oku('select hex_encode(cast(ad as varbinary(60))) from t_turkce_test where id = 1') = 'E7F0FDF6FEFC20C7D0DDD6DEDC');
      Kontrol('UTF8 baglantiyla okununca Turkce ayni DEGIL (Kiril gorunur; bilinen sinir)',
        Oku('select ad from t_turkce_test where id = 1') <> TURKCE);
      FbBaglantiyiKes(Bag);
      Bag := nil;

      if Gomulu then
      begin
        ForceDirectories(TPath.Combine(Klasor, '_arsiv'));
        TFile.Move(Yol, TPath.Combine(TPath.Combine(Klasor, '_arsiv'), ExtractFileName(Yol)));
      end;
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
      Cikti.SaveToFile(Ortam('FBTEST_CIKTI', ''), TEncoding.UTF8);
    Writeln(Cikti.Text);
  finally
    Cikti.Free;
  end;
  ExitCode := Hatalar;
end.
