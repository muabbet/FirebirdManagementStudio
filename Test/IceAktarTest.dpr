program IceAktarTest;

{ Asama 7b: uIceAktar (CSV -> tablo) testi (komut satiri).
  Gecici bir veritabani acilir (varsayilan: gomulu Firebird); gercek veriye dokunulmaz. CSV dosyalari %TEMP%\icetest'e
  yazilir. Ortam degiskenleri: FBTEST_SUNUCU (bos = yerel), FBTEST_PORT, FBTEST_KLASOR, FBTEST_KULLANICI, FBTEST_SIFRE,
  FBTEST_CIKTI. Cikis kodu: hata sayisi (0 = hepsi gecti). }

{$APPTYPE CONSOLE}

uses
  Winapi.Windows, System.SysUtils, System.Classes, System.StrUtils, System.IOUtils, System.Variants, Data.DB,
  FireDAC.Stan.Intf, FireDAC.Stan.Option, FireDAC.Stan.Error, FireDAC.Comp.Client, FireDAC.Phys.FB,
  FireDAC.ConsoleUI.Wait,
  uDil, uBaglanti, uSorgu, uAktar, uIceAktar;

const
  { c g i(noktasiz) o s u }
  TURKCE = #$00E7#$011F#$0131#$00F6#$015F#$00FC;

type
  TIptalci = class
    procedure Ilerleme(SatirSayisi: Int64; var Iptal: Boolean);
  end;

var
  Cikti: TStringList;
  Hatalar, KontrolSayisi: Integer;
  Bag: TAcikBaglanti;
  CsvKlasoru: string;
  IptalSayisi: Int64;

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
begin
  FbVeritabaniOlustur(Tanim);
end;

procedure Komut(const Sql: string);
begin
  SorguCalistir(Bag, Sql).Free;
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

function Dosya(const Ad: string): string;
begin
  Result := TPath.Combine(CsvKlasoru, Ad);
end;

procedure Yaz(const Ad, Metin: string; Kodlama: TEncoding);
begin
  TFile.WriteAllText(Dosya(Ad), Metin, Kodlama);
end;

function Sec(Ayrac: Char; Ondalik: Char; Kodlama: TIceKodlama; Baslik: Boolean): TIceSecenek;
begin
  Result.Ayrac := Ayrac;
  Result.Ondalik := Ondalik;
  Result.Kodlama := Kodlama;
  Result.BaslikVar := Baslik;
end;

{ Tum kolonlari adla eslestirip aktarir. }
function Aktar(const Tablo, Ad: string; const S: TIceSecenek; out Sonuc: TIceSonuc): Boolean;
var
  Kolonlar: TArray<TIceKolon>;
  Onizleme: TCsvOnizleme;
  Esleme: TArray<Integer>;
begin
  Kolonlar := IceAktarKolonlari(Bag, Tablo);
  Onizleme := CsvOnizle(Dosya(Ad), S, 20);
  Esleme := OtomatikEsleme(Kolonlar, Onizleme, S.BaslikVar);
  Sonuc := IceAktar(Bag, Tablo, Dosya(Ad), S, Kolonlar, Esleme, nil);
  Result := Sonuc.Basarili;
end;

procedure TIptalci.Ilerleme(SatirSayisi: Int64; var Iptal: Boolean);
begin
  IptalSayisi := SatirSayisi;
  Iptal := SatirSayisi >= 200;
end;

procedure TabloKur(Boolean3: Boolean);
var
  Mantik: string;
begin
  Mantik := '';
  if Boolean3 then
    Mantik := ', AKTIF BOOLEAN';
  Komut('CREATE TABLE T_ICE (ID INTEGER NOT NULL PRIMARY KEY, AD VARCHAR(60), SAYI NUMERIC(9,2), KAYAN DOUBLE PRECISION, ' +
    'TARIH DATE, ZAMAN TIMESTAMP, SAAT TIME, NOTU BLOB SUB_TYPE TEXT, IKILI BLOB SUB_TYPE BINARY, ' +
    'HES COMPUTED BY (COALESCE(AD, ''-'') || ''!''), VARSAYILAN VARCHAR(5) DEFAULT ''V''' + Mantik + ')');
  Komut('CREATE TABLE T_ICE2 (ID INTEGER NOT NULL PRIMARY KEY, AD VARCHAR(60), SAYI NUMERIC(9,2), KAYAN DOUBLE PRECISION, ' +
    'TARIH DATE, ZAMAN TIMESTAMP, SAAT TIME, NOTU BLOB SUB_TYPE TEXT)');
end;

procedure TahminTesti;
var
  S: TIceSecenek;
begin
  Yaz('bom_nk.csv', 'ID;AD' + #13#10 + '1;' + TURKCE + #13#10, TEncoding.UTF8);
  S := IceAktarVarsayilan(Dosya('bom_nk.csv'));
  Kontrol('UTF-8 BOM: kodlama UTF-8, ayrac ;', (S.Kodlama = ikUtf8) and (S.Ayrac = ';'));
  Yaz('bomsuz_virgul.csv', 'ID,AD' + #13#10 + '1,' + TURKCE + #13#10, TUTF8Encoding.Create(False));
  S := IceAktarVarsayilan(Dosya('bomsuz_virgul.csv'));
  Kontrol('BOM''suz gecerli UTF-8: UTF-8, ayrac ,', (S.Kodlama = ikUtf8) and (S.Ayrac = ','));
  Yaz('ansi_sekme.csv', 'ID' + #9 + 'AD' + #13#10 + '1' + #9 + TURKCE + #13#10, TEncoding.GetEncoding(1254));
  S := IceAktarVarsayilan(Dosya('ansi_sekme.csv'));
  Kontrol('ANSI Turkce dosya: kodlama ANSI, ayrac sekme', (S.Kodlama = ikAnsi) and (S.Ayrac = #9));
  Yaz('tirnakli.csv', '"A;B";"C"' + #13#10 + '1;2' + #13#10, TEncoding.UTF8);
  S := IceAktarVarsayilan(Dosya('tirnakli.csv'));
  Kontrol('tirnak icindeki ; ayrac sayilmaz (1 ; var)', S.Ayrac = ';');
end;

procedure OkumaTesti;
var
  O: TCsvOnizleme;
begin
  { tirnakli alan icinde ayrac, satir sonu ve "" ; bos satir atlanir }
  Yaz('zor.csv', 'ID;AD;NOT' + #13#10 + '1;"a;b";"satir1' + #13#10 + 'satir2 ""x"""' + #13#10 + #13#10 + '2;c;' + #13#10,
    TEncoding.UTF8);
  O := CsvOnizle(Dosya('zor.csv'), Sec(';', ',', ikUtf8, True), 10);
  Kontrol('baslik 3 kolon', Length(O.Baslik) = 3);
  Kontrol('2 veri satiri (bos satir atlandi)', Length(O.Satirlar) = 2);
  if Length(O.Satirlar) = 2 then
  begin
    Kontrol('tirnak icinde ayrac korundu', O.Satirlar[0][1] = 'a;b');
    Kontrol('tirnak icinde satir sonu ve "" korundu', O.Satirlar[0][2] = 'satir1' + #13#10 + 'satir2 "x"');
    Kontrol('son bos alan ''''', (Length(O.Satirlar[1]) = 3) and (O.Satirlar[1][2] = ''));
  end;
  Kontrol('CsvVeriSatiriSayisi = 2', CsvVeriSatiriSayisi(Dosya('zor.csv'), Sec(';', ',', ikUtf8, True)) = 2);
end;

procedure AktarmaTesti;
var
  S: TIceSonuc;
  K: TArray<TIceKolon>;
  Ad: string;
  Bulundu: Boolean;
  i: Integer;
begin
  K := IceAktarKolonlari(Bag, 'T_ICE');
  Bulundu := False;
  for i := 0 to High(K) do
    if SameText(K[i].Ad, 'IKILI') or SameText(K[i].Ad, 'HES') then
      Bulundu := True;
  Kontrol('ikili BLOB ve hesaplanan kolon aktarilabilir listede yok', not Bulundu);

  { 1. UTF-8 BOM, ; ayrac, ondalik virgul, bos hucre = NULL, farkli tarih bicimleri, kucuk harf baslik }
  Ad := 'tamam.csv';
  Yaz(Ad, 'id;ad;sayi;kayan;tarih;zaman;saat;notu' + #13#10 +
    '1;' + TURKCE + ';1234,56;0,5;2024-01-31;2024-01-31 13:45:10;08:30;"uzun' + #13#10 + 'not"' + #13#10 +
    '2;ikinci;;2,25;31.12.2023;31.12.2023T01:02:03.5;23:59:59;' + #13#10 +
    '3;;-7,1;;29/02/2024;;;' + #13#10, TEncoding.UTF8);
  Kontrol('aktarma basarili', Aktar('T_ICE', Ad, Sec(';', ',', ikUtf8, True), S));
  if not S.Basarili then
    Cikti.Add('      ' + S.Cumle + ' | ' + S.Ayrinti);
  Kontrol('3 satir eklendi', (S.Eklenen = 3) and (Oku('select count(*) from t_ice') = '3'));
  Kontrol('Turkce metin', Oku('select ad from t_ice where id = 1') = TURKCE);
  Kontrol('sayi 1234,56 -> 1234.56', StringReplace(Oku('select sayi from t_ice where id = 1'), ',', '.', []) = '1234.56');
  Kontrol('kayan 0,5', StringReplace(Oku('select kayan from t_ice where id = 1'), ',', '.', []) = '0.5');
  Kontrol('tarih yyyy-mm-dd', Oku('select extract(year from tarih) || ''-'' || extract(month from tarih) || ''-'' || extract(day from tarih) from t_ice where id = 1') = '2024-1-31');
  Kontrol('tarih dd.mm.yyyy', Oku('select extract(day from tarih) || ''.'' || extract(month from tarih) from t_ice where id = 2') = '31.12');
  Kontrol('tarih dd/mm/yyyy (artik yil 29 Subat)', Oku('select extract(day from tarih) || ''/'' || extract(month from tarih) from t_ice where id = 3') = '29/2');
  Kontrol('zaman saat dakika saniye', Oku('select extract(hour from zaman) || '':'' || extract(minute from zaman) || '':'' || cast(extract(second from zaman) as integer) from t_ice where id = 1') = '13:45:10');
  Kontrol('zaman T ayiracli', Oku('select extract(hour from zaman) from t_ice where id = 2') = '1');
  Kontrol('saat 08:30', Oku('select extract(hour from saat) || '':'' || extract(minute from saat) from t_ice where id = 1') = '8:30');
  Kontrol('bos hucre NULL (sayi)', Oku('select sayi from t_ice where id = 2') = '<NULL>');
  Kontrol('bos hucre NULL (metin)', Oku('select ad from t_ice where id = 3') = '<NULL>');
  Kontrol('negatif sayi (-7,1)', Oku('select cast(sayi * 100 as integer) from t_ice where id = 3') = '-710');
  Kontrol('tirnakli alan icinde satir sonu (memo)', Oku('select notu from t_ice where id = 1') = 'uzun' + #13#10 + 'not');
  Kontrol('eslenmeyen kolon DEFAULT aldi', Oku('select varsayilan from t_ice where id = 1') = 'V');

  { 2. ANSI, virgul ayrac, nokta ondalik, baslik yok (sirayla esleme) }
  if GetACP = 1254 then
  begin
    Ad := 'ansi.csv';
    Yaz(Ad, '10,' + TURKCE + ',5.5' + #13#10 + '11,x,6.25' + #13#10, TEncoding.GetEncoding(1254));
    Kontrol('ANSI aktarma (baslik yok, sirayla)', Aktar('T_ICE', Ad, Sec(',', '.', ikAnsi, False), S));
    Kontrol('ANSI Turkce harfler dogru', Oku('select ad from t_ice where id = 10') = TURKCE);
    Kontrol('ondalik nokta', StringReplace(Oku('select sayi from t_ice where id = 11'), ',', '.', []) = '6.25');
  end;
end;

procedure HataTesti;
var
  S: TIceSonuc;
  Once: string;
begin
  Once := Oku('select count(*) from t_ice');
  { Satir 3 (baslik = satir 1): gecersiz tarih. Satir 2 gecerli ama geri alinmali. }
  Yaz('hatali_tarih.csv', 'ID;TARIH' + #13#10 + '20;2024-01-01' + #13#10 + '21;31.02.2026' + #13#10, TEncoding.UTF8);
  Kontrol('gecersiz tarih: aktarma basarisiz', not Aktar('T_ICE', 'hatali_tarih.csv', Sec(';', ',', ikUtf8, True), S));
  Cikti.Add('      ' + S.Cumle);
  Kontrol('hata satir numarasini, kolonu ve degeri soyluyor',
    (Pos('3', S.Cumle) > 0) and (Pos('TARIH', S.Cumle) > 0) and (Pos('31.02.2026', S.Cumle) > 0));
  Kontrol('onceki gecerli satir da geri alindi', Oku('select count(*) from t_ice') = Once);

  Yaz('hatali_sayi.csv', 'ID;SAYI' + #13#10 + '22;1.234,5' + #13#10, TEncoding.UTF8);
  Kontrol('binlik ayracli sayi reddedildi', not Aktar('T_ICE', 'hatali_sayi.csv', Sec(';', ',', ikUtf8, True), S));
  Kontrol('hata ondalik ayraci hatirlatiyor', Pos(',', S.Cumle) > 0);
  Cikti.Add('      ' + S.Cumle);

  { Ayni anahtar (PRIMARY KEY ihlali) }
  Yaz('cift_anahtar.csv', 'ID;AD' + #13#10 + '30;a' + #13#10 + '30;b' + #13#10, TEncoding.UTF8);
  Kontrol('cift anahtar: basarisiz', not Aktar('T_ICE', 'cift_anahtar.csv', Sec(';', ',', ikUtf8, True), S));
  Kontrol('cift anahtar: hicbiri eklenmedi', Oku('select count(*) from t_ice where id = 30') = '0');
  Kontrol('cift anahtar: satir numarasi var', Pos('3', S.Cumle) > 0);
  Cikti.Add('      ' + S.Cumle);

  { Var olan anahtar }
  Yaz('var_olan.csv', 'ID;AD' + #13#10 + '1;yeni' + #13#10, TEncoding.UTF8);
  Kontrol('var olan anahtar: basarisiz', not Aktar('T_ICE', 'var_olan.csv', Sec(';', ',', ikUtf8, True), S));
  Kontrol('var olan kayit degismedi', Oku('select ad from t_ice where id = 1') = TURKCE);

  { Eslenmeyen zorunlu kolon (ID NOT NULL) bos birakilirsa Firebird reddeder }
  Yaz('idsiz.csv', 'AD' + #13#10 + 'x' + #13#10, TEncoding.UTF8);
  Kontrol('zorunlu kolon (ID) eslenmedi: basarisiz', not Aktar('T_ICE', 'idsiz.csv', Sec(';', ',', ikUtf8, True), S));
end;

procedure IptalTesti;
var
  Kolonlar: TArray<TIceKolon>;
  Onizleme: TCsvOnizleme;
  Esleme: TArray<Integer>;
  S: TIceSonuc;
  Metin: string;
  i: Integer;
  Once: string;
  Iptalci: TIptalci;
begin
  Once := Oku('select count(*) from t_ice');
  Metin := 'ID;AD' + #13#10;
  for i := 1000 to 1499 do
    Metin := Metin + IntToStr(i) + ';satir' + IntToStr(i) + #13#10;
  Yaz('buyuk.csv', Metin, TEncoding.UTF8);
  Kolonlar := IceAktarKolonlari(Bag, 'T_ICE');
  Onizleme := CsvOnizle(Dosya('buyuk.csv'), Sec(';', ',', ikUtf8, True), 5);
  Esleme := OtomatikEsleme(Kolonlar, Onizleme, True);
  IptalSayisi := 0;
  Iptalci := TIptalci.Create;
  try
    S := IceAktar(Bag, 'T_ICE', Dosya('buyuk.csv'), Sec(';', ',', ikUtf8, True), Kolonlar, Esleme, Iptalci.Ilerleme);
  finally
    Iptalci.Free;
  end;
  Kontrol('iptal: Sonuc.Iptal', S.Iptal and not S.Basarili);
  Kontrol('iptal: ilerleme bildirildi (200 satirda durdu)', IptalSayisi = 200);
  Kontrol('iptal: hicbir satir eklenmedi', Oku('select count(*) from t_ice') = Once);
  { Iptal etmeden tamami }
  S := IceAktar(Bag, 'T_ICE', Dosya('buyuk.csv'), Sec(';', ',', ikUtf8, True), Kolonlar, Esleme, nil);
  Kontrol('500 satir eklendi', S.Basarili and (S.Eklenen = 500));
  Kontrol('veritabaninda 500 yeni satir', Oku('select count(*) from t_ice where id >= 1000') = '500');
end;

{ Disa aktarilan dosya (uAktar) aynen geri okunur. }
procedure GidisDonusTesti;
var
  Yazici: TStreamWriter;
  Secenek: TCsvSecenekleri;
  Uyari: TStringList;
  Adet: Int64;
  S: TIceSonuc;
  Dosya1: string;
  O: TIceSecenek;
begin
  Dosya1 := Dosya('disa_aktarilan.csv');
  Secenek := WindowsCsvSecenekleri;
  Uyari := TStringList.Create;
  Yazici := TStreamWriter.Create(Dosya1, False, TEncoding.UTF8);
  try
    CsvAktar(Bag, 'SELECT ID, AD, SAYI, KAYAN, TARIH, ZAMAN, NOTU FROM T_ICE WHERE ID <= 3 ORDER BY ID', Yazici, Secenek,
      Uyari, nil, Adet);
  finally
    Yazici.Free;
    Uyari.Free;
  end;
  O := IceAktarVarsayilan(Dosya1);
  Kontrol('disa aktarilan dosya: UTF-8 ve Windows ayraci tahmin edildi', (O.Kodlama = ikUtf8) and (O.Ayrac = Secenek.Ayrac));
  Kontrol('disa aktarilan dosya aktarildi', Aktar('T_ICE2', 'disa_aktarilan.csv', O, S));
  if not S.Basarili then
    Cikti.Add('      ' + S.Cumle + ' | ' + S.Ayrinti);
  Kontrol('gidis-donus: 3 satir', Oku('select count(*) from t_ice2') = '3');
  Kontrol('gidis-donus: metin ayni', Oku('select ad from t_ice2 where id = 1') = TURKCE);
  Kontrol('gidis-donus: sayi ayni', Oku('select sayi from t_ice2 where id = 1') = Oku('select sayi from t_ice where id = 1'));
  Kontrol('gidis-donus: kayan ayni', Oku('select kayan from t_ice2 where id = 1') = Oku('select kayan from t_ice where id = 1'));
  Kontrol('gidis-donus: zaman ayni', Oku('select zaman from t_ice2 where id = 1') = Oku('select zaman from t_ice where id = 1'));
  Kontrol('gidis-donus: NULL NULL kaldi', Oku('select sayi from t_ice2 where id = 2') = '<NULL>');
  Kontrol('gidis-donus: memo (satir sonu) ayni', Oku('select notu from t_ice2 where id = 1') = Oku('select notu from t_ice where id = 1'));
end;

procedure DilAnahtarTesti;
const
  Anahtarlar: array[0..26] of string = ('BTN_ICE_AKTAR', 'ICE_BASLIK', 'ICE_DOSYA', 'ICE_SEC', 'ICE_AYRAC', 'ICE_AYRAC_SEKME',
    'ICE_KODLAMA', 'ICE_KODLAMA_ANSI', 'ICE_ONDALIK', 'ICE_BASLIK_VAR', 'ICE_ONIZLEME', 'ICE_ESLEME', 'ICE_BOS_BIRAK',
    'ICE_BASLAT', 'ICE_FILTRE', 'ICE_ONAY', 'ICE_ESLENMEDI', 'ICE_BOS_DOSYA', 'ICE_DOSYA_OKUNAMADI', 'ICE_CALISIYOR',
    'ICE_TUR_TAMSAYI', 'ICE_TUR_TARIH', 'ERR_ICE_DEGER', 'ERR_ICE_ONDALIK', 'ERR_ICE_SATIR', 'MSG_ICE_TAMAM',
    'ERR_ICE_UYGULANAMADI');
var
  Dil, Anahtar, Eksik: string;
begin
  for Dil in ['tr', 'en', 'de'] do
  begin
    DilYukle(Dil);
    Eksik := '';
    for Anahtar in Anahtarlar do
      if T(Anahtar) = Anahtar then
        Eksik := Eksik + ' ' + Anahtar;
    Kontrol('dil ' + Dil + ': 7b anahtarlari tam' + IfThen(Eksik <> '', ' (eksik:' + Eksik + ')'), Eksik = '');
    { Parametre sirasi: onay ve tamam mesajlari bicim hatasi vermemeli }
    try
      Kontrol('dil ' + Dil + ': ICE_ONAY ve MSG_ICE_TAMAM bicimi gecerli',
        (Pos('T_X', TF('ICE_ONAY', ['T_X', 5, 2, 'INSERT'])) > 0) and (Pos('INSERT', TF('ICE_ONAY', ['T_X', 5, 2, 'INSERT'])) > 0) and
        (Pos('T_X', TF('MSG_ICE_TAMAM', ['T_X', 5])) > 0));
    except
      Kontrol('dil ' + Dil + ': ICE_ONAY / MSG_ICE_TAMAM bicim hatasi', False);
    end;
  end;
  DilYukle('tr');
end;

var
  Tanim: TBaglantiTanimi;
  Klasor, Yol: string;
  Gomulu: Boolean;
begin
  Cikti := TStringList.Create;
  Bag := nil;
  try
    try
      DilYukle('tr');
      Gomulu := Ortam('FBTEST_SUNUCU', '') = '';
      Klasor := Ortam('FBTEST_KLASOR', TPath.Combine(GetEnvironmentVariable('TEMP'), 'icetest'));
      CsvKlasoru := TPath.Combine(GetEnvironmentVariable('TEMP'), 'icetest');
      ForceDirectories(CsvKlasoru);
      if Gomulu then
        ForceDirectories(Klasor);
      Yol := IncludeTrailingPathDelimiter(Klasor) + 'icetest_' + FormatDateTime('yyyymmdd_hhnnss', Now) + '.fdb';
      Tanim := Default(TBaglantiTanimi);
      Tanim.Ad := 'icetest';
      Tanim.Sunucu := Ortam('FBTEST_SUNUCU', '');
      Tanim.Port := StrToInt(Ortam('FBTEST_PORT', '3050'));
      Tanim.VeritabaniYolu := Yol;
      Tanim.Kullanici := Ortam('FBTEST_KULLANICI', 'SYSDBA');
      Tanim.Sifre := Ortam('FBTEST_SIFRE', '');
      Tanim.KarakterSeti := VARSAYILAN_KARAKTER_SETI;
      GeciciVeritabaniOlustur(Tanim);
      Bag := FbBaglan(Tanim);
      Cikti.Add('--- Surum ' + Bag.Surum + ', veritabani: ' + Yol + ' ---');
      TabloKur(StrToIntDef(Copy(Bag.Surum, 1, 1), 0) >= 3);
      Cikti.Add('--- Bicim tahmini ---');
      TahminTesti;
      Cikti.Add('--- Okuma ---');
      OkumaTesti;
      Cikti.Add('--- Aktarma ---');
      AktarmaTesti;
      Cikti.Add('--- Hatalar ---');
      HataTesti;
      Cikti.Add('--- Iptal ve buyuk dosya ---');
      IptalTesti;
      Cikti.Add('--- Disa aktar, ice aktar ---');
      GidisDonusTesti;
      Cikti.Add('--- Dil anahtarlari ---');
      DilAnahtarTesti;
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
