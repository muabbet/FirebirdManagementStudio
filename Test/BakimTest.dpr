program BakimTest;

{ Asama 7d: uBakim (veritabani bakimi: rapor + bakim) testi (komut satiri).
  Gecici veritabani acilir; gercek veriye dokunulmaz. gstat/gfix sunucu uzerinden calisir, bu yuzden SUNUCU gerekir
  (gomulu kip gfix ile cakisir).
  Ortam degiskenleri: FBTEST_SUNUCU, FBTEST_PORT, FBTEST_KLASOR (sunucudaki klasor), FBTEST_KULLANICI, FBTEST_SIFRE, FBTEST_CIKTI.
  Cikis kodu: hata sayisi (0 = hepsi gecti). }

{$APPTYPE CONSOLE}

uses
  System.SysUtils, System.Classes, System.StrUtils, System.IOUtils, System.RegularExpressions, Data.DB,
  FireDAC.Stan.Intf, FireDAC.Stan.Option, FireDAC.Stan.Error, FireDAC.Comp.Client, FireDAC.Phys.FB,
  FireDAC.ConsoleUI.Wait,
  uDil, uBaglanti, uSorgu, uBakim;

type
  TIzleyici = class
    procedure Satir(const Metin: string; var Iptal: Boolean);
  end;

var
  Cikti: TStringList;
  Hatalar, KontrolSayisi: Integer;
  A: TAcikBaglanti;

procedure TIzleyici.Satir(const Metin: string; var Iptal: Boolean);
begin
  Iptal := False;
end;

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

function Oku(Bag: TAcikBaglanti; const Sql: string): string;
var
  Q: TFDQuery;
begin
  Q := TFDQuery.Create(nil);
  try
    Q.Connection := Bag.Baglanti;
    Q.SQL.Text := Sql;
    Q.Open;
    Result := Q.Fields[0].AsString;
  finally
    Q.Free;
  end;
end;

procedure Komut(Bag: TAcikBaglanti; const Sql: string);
begin
  SorguCalistir(Bag, Sql).Free;
end;

function TanimYap(const Ad, Yol: string): TBaglantiTanimi;
begin
  Result := Default(TBaglantiTanimi);
  Result.Ad := Ad;
  Result.Sunucu := Ortam('FBTEST_SUNUCU', 'localhost');
  Result.Port := StrToInt(Ortam('FBTEST_PORT', '3050'));
  Result.VeritabaniYolu := Yol;
  Result.Kullanici := Ortam('FBTEST_KULLANICI', 'SYSDBA');
  Result.Sifre := Ortam('FBTEST_SIFRE', 'masterkey');
  Result.KarakterSeti := VARSAYILAN_KARAKTER_SETI;
end;

function EskiToplam(const R: TBakimRaporu): Int64;
var
  i: Integer;
begin
  Result := 0;
  for i := 0 to High(R.Tablolar) do
    Inc(Result, R.Tablolar[i].EskiSurum);
end;

function TabloBul(const R: TBakimRaporu; const Ad: string): Integer;
var
  i: Integer;
begin
  Result := -1;
  for i := 0 to High(R.Tablolar) do
    if SameText(R.Tablolar[i].Ad, Ad) then
      Exit(i);
end;

function IsVar(const R: TBakimRaporu; Tur: TBakimIsTuru): Boolean;
var
  i: Integer;
begin
  Result := False;
  for i := 0 to High(R.Isler) do
    if R.Isler[i].Tur = Tur then
      Exit(True);
end;

procedure VeriKur;
var
  i: Integer;
begin
  Komut(A, 'CREATE TABLE T_BUYUK (ID INTEGER NOT NULL PRIMARY KEY, AD VARCHAR(40), SAYI INTEGER)');
  Komut(A, 'CREATE INDEX IX_BUYUK_AD ON T_BUYUK (AD)');
  Komut(A, 'CREATE INDEX IX_BUYUK_SAYI ON T_BUYUK (SAYI)');
  Komut(A, 'CREATE TABLE T_KUCUK (ID INTEGER NOT NULL PRIMARY KEY, NOTU VARCHAR(20))');
  Komut(A, 'INSERT INTO T_KUCUK VALUES (1, ''a'')');
  for i := 0 to 19 do
    Komut(A, 'EXECUTE BLOCK AS DECLARE I INTEGER = ' + IntToStr(i * 1000 + 1) + '; BEGIN WHILE (I <= ' + IntToStr(i * 1000 + 1000) +
      ') DO BEGIN INSERT INTO T_BUYUK VALUES (:I, ''AD'' || :I, MOD(:I, 7)); I = I + 1; END END');
  { Cop uret: silme + guncelleme }
  Komut(A, 'DELETE FROM T_BUYUK WHERE ID > 5000');
  Komut(A, 'UPDATE T_BUYUK SET SAYI = SAYI + 1 WHERE ID <= 3000');
end;

procedure ParserTesti;
const
  ORNEK =
    'Database "x.fdb"' + #13#10 +
    'Database header page information:' + #13#10 +
    #13#10 +
    'Analyzing database pages ...' + #13#10 +
    'T_ORNEK (128)' + #13#10 +
    '    Primary pointer page: 200, Index root page: 201' + #13#10 +
    '    Total formats: 1, used formats: 1' + #13#10 +
    '    Average record length: 30.00, total records: 1000' + #13#10 +
    '    Average version length: 20.00, total versions: 400, max versions: 3' + #13#10 +
    '    Data pages: 50, data page slots: 50, average fill: 40%' + #13#10 +
    '    Fill distribution:' + #13#10 +
    '         0 - 19% = 0' + #13#10 +
    '        20 - 39% = 5' + #13#10 +
    '        40 - 59% = 40' + #13#10 +
    '        60 - 79% = 5' + #13#10 +
    '        80 - 99% = 0' + #13#10 +
    #13#10 +
    '    Index IX_ORNEK (1)' + #13#10 +
    '    Root page: 300, depth: 5, leaf buckets: 100, nodes: 1000' + #13#10 +
    '    Average data length: 5.00, total dup: 10, max dup: 2' + #13#10 +
    '    Fill distribution:' + #13#10 +
    '         0 - 19% = 10' + #13#10 +
    '        20 - 39% = 40' + #13#10 +
    '        40 - 59% = 30' + #13#10 +
    '        60 - 79% = 10' + #13#10 +
    '        80 - 99% = 10' + #13#10;
var
  T: TArray<TBakimTablosu>;
  I: TArray<TBakimIndeksi>;
begin
  Cikti.Add('--- gstat ayristirma ---');
  Kontrol('ornek metin ayristirildi', GstatAyristir(ORNEK, T, I));
  Kontrol('1 tablo', Length(T) = 1);
  if Length(T) = 1 then
  begin
    Kontrol('tablo adi', T[0].Ad = 'T_ORNEK');
    Kontrol('kayit 1000', T[0].Kayit = 1000);
    Kontrol('eski surum 400', T[0].EskiSurum = 400);
    Kontrol('veri sayfasi 50', T[0].VeriSayfasi = 50);
    Kontrol('doluluk 40', T[0].Doluluk = 40);
  end;
  Kontrol('1 index', Length(I) = 1);
  if Length(I) = 1 then
  begin
    Kontrol('index adi', I[0].Ad = 'IX_ORNEK');
    Kontrol('derinlik 5', I[0].Derinlik = 5);
    Kontrol('yaprak 100', I[0].Yaprak = 100);
    Kontrol('dugum 1000', I[0].Dugum = 1000);
    Kontrol('seyrek yuzde 50 (ilk iki kutu)', I[0].SeyrekYuzde = 50);
  end;
end;

procedure BakimTesti;
var
  R1, R2: TBakimRaporu;
  S: TBakimSonucu;
  Izle: TIzleyici;
  i: Integer;
  Metin: string;
begin
  Izle := TIzleyici.Create;
  try
    Cikti.Add('--- Arac var mi ---');
    Kontrol('gstat ve gfix bulundu', BakimAraclariVar);

    Cikti.Add('--- Rapor (bakimdan once) ---');
    R1 := BakimRaporuHazirla(A, True, Izle.Satir);
    if R1.Cumle <> '' then
      Cikti.Add('      ' + R1.Cumle + ' | ' + R1.Ayrinti);
    Kontrol('rapor hazir (hata yok)', R1.Cumle = '');
    Kontrol('surum okundu', R1.Durum.Surum <> '');
    Kontrol('sayfa boyutu okundu', R1.Durum.SayfaBoyutu > 0);
    Kontrol('tablolar bulundu (en az 2)', Length(R1.Tablolar) >= 2);
    Kontrol('T_BUYUK var', TabloBul(R1, 'T_BUYUK') >= 0);
    Kontrol('indexler bulundu (en az 3)', Length(R1.Indeksler) >= 3);
    Kontrol('bozuk kayit taramasi temiz', R1.Tarama = tdTemiz);
    Cikti.Add('      tarama durumu: ' + IntToStr(Ord(R1.Tarama)) + ' | ' + R1.TaramaCikti);
    Cikti.Add('      eski surum toplami: ' + IntToStr(EskiToplam(R1)) + ', is sayisi: ' + IntToStr(Length(R1.Isler)));
    for i := 0 to High(R1.Isler) do
      Cikti.Add('      is: ' + R1.Isler[i].Aciklama);
    Kontrol('onay metni dolu', BakimOnayMetni(R1) <> '');
    Kontrol('ozet metni dolu', BakimOzetMetni(R1) <> '');

    if EskiToplam(R1) > 0 then
    begin
      Kontrol('cop varsa sweep planda', IsVar(R1, bisSweep));
      Kontrol('cop varsa T_BUYUK temizlenecek', R1.Tablolar[TabloBul(R1, 'T_BUYUK')].Temizlenecek);
    end
    else
      Cikti.Add('      (not) sunucu copu kendiliginden toplamis; sweep plani beklenmiyor');

    Cikti.Add('--- Bakim ---');
    S := BakimiYap(A, R1, Izle.Satir);
    for i := 0 to High(S.Satirlar) do
      Cikti.Add('      ' + S.Satirlar[i]);
    for i := 0 to High(S.Komutlar) do
      Cikti.Add('      sql: ' + S.Komutlar[i]);
    Kontrol('bakim basarili', S.Basarili);
    Kontrol('hata yok', S.Hatali = 0);
    Kontrol('sonuc satirlari var', Length(S.Satirlar) > 0);
    Metin := '';
    for i := 0 to High(S.Komutlar) do
      Metin := Metin + S.Komutlar[i] + #10;
    Kontrol('SQL komutlari kaydedildi', Metin <> '');

    Cikti.Add('--- Rapor (bakimdan sonra) ---');
    R2 := BakimRaporuHazirla(A, True, Izle.Satir);
    Kontrol('ikinci rapor hazir', R2.Cumle = '');
    Cikti.Add('      eski surum toplami: ' + IntToStr(EskiToplam(R2)));
    Kontrol('eski surum azaldi ya da sifir', EskiToplam(R2) <= EskiToplam(R1));
    Kontrol('sweep artik planda degil', not IsVar(R2, bisSweep));
    Kontrol('veri duruyor: 5000 satir', Oku(A, 'select count(*) from t_buyuk') = '5000');
  finally
    Izle.Free;
  end;
end;

procedure DilAnahtarTesti;
var
  Kaynak, Yol, Dil: string;
  Eslesme: TMatch;
  Anahtarlar: TStringList;
  Dosya: TStringList;
  Ham: string;
  Eksik: string;
  i: Integer;
begin
  Cikti.Add('--- Dil anahtarlari ---');
  Yol := TPath.Combine(ExtractFilePath(ParamStr(0)), '..\..\..\Kaynak\uBakim.pas');
  if not FileExists(Yol) then
    Yol := 'C:\Baris\Kodlar\FirebirdYonetici\Kaynak\uBakim.pas';
  Kaynak := TFile.ReadAllText(Yol);
  Anahtarlar := TStringList.Create;
  Dosya := TStringList.Create;
  try
    Anahtarlar.Sorted := True;
    Anahtarlar.Duplicates := dupIgnore;
    for Eslesme in TRegEx.Matches(Kaynak, 'TF?\(''([A-Z0-9_]+)''') do
      if not EndsText('_', Eslesme.Groups[1].Value) then
        Anahtarlar.Add(Eslesme.Groups[1].Value);
    Kontrol('kodda anahtar bulundu', Anahtarlar.Count > 10);
    for Dil in ['tr', 'en', 'de'] do
    begin
      Ham := TFile.ReadAllText(TPath.Combine(TPath.Combine(ExtractFilePath(ParamStr(0)), 'Diller'), Dil + '.json'), TEncoding.UTF8);
      Eksik := '';
      for i := 0 to Anahtarlar.Count - 1 do
        if Pos('"' + Anahtarlar[i] + '"', Ham) = 0 then
          Eksik := Eksik + Anahtarlar[i] + ' ';
      if Eksik <> '' then
        Cikti.Add('      ' + Dil + ' eksik: ' + Eksik);
      Kontrol(Dil + ': uBakim anahtarlari tamam', Eksik = '');
    end;
  finally
    Dosya.Free;
    Anahtarlar.Free;
  end;
end;

var
  Tanim: TBaglantiTanimi;
  Yol: string;

begin
  Cikti := TStringList.Create;
  try
    try
      DilYukle('tr');
      ParserTesti;
      Yol := IncludeTrailingPathDelimiter(Ortam('FBTEST_KLASOR', 'C:\Temp\bakimtest')) + 'bakim_' +
        FormatDateTime('yyyymmdd_hhnnss', Now) + '.fdb';
      ForceDirectories(ExtractFilePath(Yol));
      Tanim := TanimYap('bakim', Yol);
      FbVeritabaniOlustur(Tanim);
      A := FbBaglan(Tanim);
      Cikti.Add('--- Surum ' + A.Surum + ' ---');
      VeriKur;
      BakimTesti;
      DilAnahtarTesti;
      FbBaglantiyiKes(A);
      A := nil;
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
