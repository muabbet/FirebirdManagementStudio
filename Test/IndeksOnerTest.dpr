program IndeksOnerTest;

{ Asama 7d (2. adim): uIndeksOner (sorgu icin index onerisi) testi (komut satiri). Saf ayristirma testleri + gecici veritabaninda
  canli test (plan once / sonra). Ortam: FBTEST_SUNUCU, FBTEST_PORT, FBTEST_SIFRE, FBTEST_KLASOR, FBTEST_CIKTI. Cikis kodu: hata sayisi. }

{$APPTYPE CONSOLE}

uses
  System.SysUtils, System.Classes, System.StrUtils, System.IOUtils, System.RegularExpressions, Data.DB,
  FireDAC.Stan.Intf, FireDAC.Stan.Option, FireDAC.Comp.Client, FireDAC.Phys.FB, FireDAC.ConsoleUI.Wait,
  uDil, uBaglanti, uSorgu, uProsedur, uIndeksOner;

var
  Cikti: TStringList;
  Hatalar, KontrolSayisi: Integer;
  A: TAcikBaglanti;

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

procedure Komut(Bag: TAcikBaglanti; const Sql: string);
begin
  SorguCalistir(Bag, Sql).Free;
end;

function KolonYazisi(const O: TIndeksOnerisi): string;
var
  K: string;
begin
  Result := '';
  for K in O.Kolonlar do
    Result := Result + IfThen(Result <> '', ',', '') + K;
end;

function KosulYazisi(const Kosullar: TArray<TKosulKolonu>): string;
var
  K: TKosulKolonu;
begin
  Result := '';
  for K in Kosullar do
    Result := Result + IfThen(Result <> '', ' ', '') + IfThen(K.On <> '', K.On + '.', '') + K.Kolon + IfThen(K.Tur = ktEsit, '=', IfThen(K.Tur = ktBaglanti, '#', '~'));
end;

function TabloYazisi(const Tablolar: TArray<TSqlTablosu>): string;
var
  T: TSqlTablosu;
begin
  Result := '';
  for T in Tablolar do
    Result := Result + IfThen(Result <> '', ' ', '') + T.Tablo + IfThen(T.Takma <> '', ':' + T.Takma, '');
end;

procedure AyristirmaTesti;
var
  Tablolar: TArray<TSqlTablosu>;
  Kosullar: TArray<TKosulKolonu>;
  Adlar: TArray<string>;
begin
  Cikti.Add('--- SQL ayristirma ---');
  SqlKosullariniOku('SELECT * FROM T_SATIS S JOIN T_MUSTERI M ON M.ID = S.MUSTERI_ID WHERE S.TARIH >= ''2026-01-01'' AND S.DURUM = ''A''',
    Tablolar, Kosullar);
  Kontrol('tablolar ve takma adlar: ' + TabloYazisi(Tablolar), TabloYazisi(Tablolar) = 'T_SATIS:S T_MUSTERI:M');
  Kontrol('kosullar: ' + KosulYazisi(Kosullar), KosulYazisi(Kosullar) = 'M.ID# S.MUSTERI_ID# S.TARIH~ S.DURUM=');

  SqlKosullariniOku('select * from satis where upper(ad) = ''X'' and tutar + 1 > 5 and kod like ''%A'' and no like ''12%'' and x <> 3 and y is null',
    Tablolar, Kosullar);
  Kontrol('fonksiyon, ifade, LIKE %x, <>, IS NULL atlanir; LIKE ''12%'' alinir: ' + KosulYazisi(Kosullar), KosulYazisi(Kosullar) = 'NO~');

  SqlKosullariniOku('SELECT a.x FROM A, B b WHERE a.id IN (SELECT id FROM C WHERE c.k = 5) AND 7 = b.z',
    Tablolar, Kosullar);
  Kontrol('virgullu tablo listesi ve alt sorgu tablosu: ' + TabloYazisi(Tablolar), TabloYazisi(Tablolar) = 'A B:B C');
  Kontrol('IN, alt sorgu kosulu ve DEGER=sabit: ' + KosulYazisi(Kosullar), KosulYazisi(Kosullar) = 'A.ID= C.K= B.Z=');

  SqlKosullariniOku('UPDATE T_STOK SET MIKTAR = 0 WHERE DEPO_ID = 3', Tablolar, Kosullar);
  Kontrol('UPDATE tablosu: ' + TabloYazisi(Tablolar), TabloYazisi(Tablolar) = 'T_STOK');
  Kontrol('UPDATE kosulu: ' + KosulYazisi(Kosullar), KosulYazisi(Kosullar) = 'DEPO_ID=');

  Cikti.Add('--- plan ayristirma ---');
  Adlar := PlandaTaramaAdlari('PLAN JOIN (S NATURAL, M INDEX (PK_MUSTERI))');
  Kontrol('kisa plan: yalniz S taranir', (Length(Adlar) = 1) and (Adlar[0] = 'S'));
  Adlar := PlandaTaramaAdlari('Select Expression' + sLineBreak + '    -> Nested Loop Join (inner)' + sLineBreak +
    '        -> Filter' + sLineBreak + '            -> Table "T_SATIS" as "S" Full Scan' + sLineBreak +
    '        -> Filter' + sLineBreak + '            -> Table "T_MUSTERI" as "M" Access By ID');
  Kontrol('ayrintili plan: takma ad S taranir', (Length(Adlar) = 1) and (Adlar[0] = 'S'));
  Adlar := PlandaTaramaAdlari('PLAN (T_X INDEX (IX_X))');
  Kontrol('index kullanan plan: tarama yok', Length(Adlar) = 0);
end;

procedure CanliTest;
var
  i: Integer;
  R: TIndeksRaporu;
  O: TIndeksOnerisi;
  S: TProsedurSonucu;
  PlanSonra, Sql: string;
  N: string;
begin
  Cikti.Add('--- Canli: ' + A.Surum + ' ---');
  Komut(A, 'CREATE TABLE T_MUSTERI (ID INTEGER NOT NULL PRIMARY KEY, AD VARCHAR(40))');
  Komut(A, 'CREATE TABLE T_SATIS (ID INTEGER NOT NULL PRIMARY KEY, MUSTERI_ID INTEGER, TARIH DATE, DURUM CHAR(1), TUTAR NUMERIC(9,2))');
  Komut(A, 'CREATE TABLE T_KUCUK (ID INTEGER NOT NULL PRIMARY KEY, KOD VARCHAR(10))');
  for i := 1 to 20 do
    Komut(A, 'INSERT INTO T_KUCUK VALUES (' + IntToStr(i) + ', ''K' + IntToStr(i) + ''')');
  for i := 0 to 9 do
  begin
    Komut(A, 'EXECUTE BLOCK AS DECLARE I INTEGER = ' + IntToStr(i * 1000 + 1) + '; BEGIN WHILE (I <= ' + IntToStr(i * 1000 + 1000) +
      ') DO BEGIN INSERT INTO T_MUSTERI VALUES (:I, ''AD'' || :I); I = I + 1; END END');
    Komut(A, 'EXECUTE BLOCK AS DECLARE I INTEGER = ' + IntToStr(i * 1000 + 1) + '; BEGIN WHILE (I <= ' + IntToStr(i * 1000 + 1000) +
      ') DO BEGIN INSERT INTO T_SATIS VALUES (:I, MOD(:I, 500), DATEADD(MOD(:I, 300) DAY TO DATE ''2026-01-01''), ' +
      'IIF(MOD(:I, 10) = 0, ''A'', ''B''), :I); I = I + 1; END END');
  end;

  { 1. kucuk tablo: oneri yok, not var }
  R := IndeksOnerisiHazirla(A, 'SELECT * FROM T_KUCUK WHERE KOD = ''K5''');
  Kontrol('kucuk tablo: rapor hazir', R.Basarili);
  Kontrol('kucuk tablo: oneri yok', Length(R.Oneriler) = 0);
  Kontrol('kucuk tablo: not yazildi', Length(R.Notlar) > 0);

  { 2. index kullanan sorgu: tarama yok }
  R := IndeksOnerisiHazirla(A, 'SELECT * FROM T_MUSTERI WHERE ID = 5');
  Kontrol('PK ile sorgu: oneri yok', R.Basarili and (Length(R.Oneriler) = 0));

  { 3. index'siz buyuk tablo }
  Sql := 'SELECT * FROM T_SATIS S JOIN T_MUSTERI M ON M.ID = S.MUSTERI_ID WHERE S.DURUM = ''A'' AND S.TARIH >= ''2026-06-01''';
  R := IndeksOnerisiHazirla(A, Sql);
  if not R.Basarili then
    Cikti.Add('      ' + R.Cumle + ' | ' + R.Ayrinti);
  Cikti.Add('      plan: ' + StringReplace(R.Plan, sLineBreak, ' / ', [rfReplaceAll]));
  for N in R.Notlar do
    Cikti.Add('      not: ' + N);
  Kontrol('buyuk tablo: rapor hazir', R.Basarili);
  Kontrol('buyuk tablo: 1 oneri', Length(R.Oneriler) = 1);
  if Length(R.Oneriler) = 1 then
  begin
    O := R.Oneriler[0];
    Cikti.Add('      oneri: ' + O.Sql);
    Kontrol('oneri T_SATIS icin', O.Tablo = 'T_SATIS');
    Kontrol('oneri filtre kolonlari (DURUM, TARIH), JOIN kolonu degil: ' + KolonYazisi(O), KolonYazisi(O) = 'DURUM,TARIH');
    Kontrol('oneri SQL CREATE INDEX', StartsText('CREATE INDEX ', O.Sql));
    Kontrol('veritabani degismedi (index henuz yok)', StrToInt(A.Baglanti.ExecSQLScalar(
      'SELECT COUNT(*) FROM RDB$INDICES WHERE RDB$RELATION_NAME = ''T_SATIS'' AND RDB$INDEX_NAME NOT LIKE ''RDB$%''')) = 0);
    S := IndeksOlustur(A, O);
    if not S.Basarili then
      Cikti.Add('      ' + S.Cumle + ' | ' + S.Ayrinti);
    Kontrol('index olusturuldu', S.Basarili);
    Kontrol('index var', StrToInt(A.Baglanti.ExecSQLScalar('SELECT COUNT(*) FROM RDB$INDICES WHERE RDB$INDEX_NAME = ''' + O.Ad + '''')) = 1);
    PlanSonra := SorguPlaniAl(A, Sql);
    Cikti.Add('      plan sonra: ' + StringReplace(PlanSonra, sLineBreak, ' / ', [rfReplaceAll]));
    Kontrol('plan artik index kullaniyor (S icin tarama yok)', Length(PlandaTaramaAdlari(PlanSonra)) = 0);
    { ikinci kez: oneri gelmemeli }
    R := IndeksOnerisiHazirla(A, Sql);
    Kontrol('ikinci kez: yeni oneri yok', R.Basarili and (Length(R.Oneriler) = 0));
  end;

  { 3b. yalniz JOIN kolonu: ic taraftaki tablo MUSTERI_ID ile taranir }
  Sql := 'SELECT * FROM T_MUSTERI M JOIN T_SATIS S ON S.MUSTERI_ID = M.ID WHERE M.ID = 5';
  R := IndeksOnerisiHazirla(A, Sql);
  Cikti.Add('      plan 3b: ' + StringReplace(R.Plan, sLineBreak, ' / ', [rfReplaceAll]));
  for N in R.Notlar do
    Cikti.Add('      not: ' + N);
  Kontrol('JOIN: 1 oneri', R.Basarili and (Length(R.Oneriler) = 1));
  if Length(R.Oneriler) = 1 then
  begin
    Cikti.Add('      oneri: ' + R.Oneriler[0].Sql);
    Kontrol('JOIN onerisi MUSTERI_ID', KolonYazisi(R.Oneriler[0]) = 'MUSTERI_ID');
    S := IndeksOlustur(A, R.Oneriler[0]);
    Kontrol('JOIN index olusturuldu', S.Basarili);
    Kontrol('JOIN: plan artik taramiyor', Length(PlandaTaramaAdlari(SorguPlaniAl(A, Sql))) = 0);
  end;

  { 4. view/ifade: kosul bulunamaz }
  R := IndeksOnerisiHazirla(A, 'SELECT * FROM T_SATIS WHERE UPPER(DURUM) = ''A'' AND TUTAR + 1 > 5');
  Kontrol('ifadeli kosul: oneri yok', R.Basarili and (Length(R.Oneriler) = 0));
  Kontrol('ifadeli kosul: aciklayici not', Length(R.Notlar) > 0);

  { 5. hatali sorgu }
  R := IndeksOnerisiHazirla(A, 'SELECT * FROM YOK_TABLO WHERE X = 1');
  Kontrol('olmayan tablo: anlasilir hata cumlesi', (not R.Basarili) and (R.Cumle <> ''));
end;

procedure DilAnahtarTesti;
var
  Dil, Ham, Kaynak, Anahtar, Yol: string;
  Eslesme: TMatch;
  Anahtarlar: TStringList;
begin
  Cikti.Add('--- Dil anahtarlari ---');
  Yol := 'C:\Baris\Kodlar\FirebirdYonetici\Kaynak\uIndeksOner.pas';
  Kaynak := TFile.ReadAllText(Yol);
  Anahtarlar := TStringList.Create;
  try
    Anahtarlar.Sorted := True;
    Anahtarlar.Duplicates := dupIgnore;
    for Eslesme in TRegEx.Matches(Kaynak, 'TF?\(''([A-Z0-9_]+)''') do
      Anahtarlar.Add(Eslesme.Groups[1].Value);
    Anahtarlar.Add('BTN_INDEKS_ONER');
    Anahtarlar.Add('INDEKS_BASLIK');
    Anahtarlar.Add('INDEKS_ONAY_BASLIK');
    Anahtarlar.Add('MSG_INDEKS_OLUSTU');
    for Dil in ['tr', 'en', 'de'] do
    begin
      Ham := TFile.ReadAllText(TPath.Combine(TPath.Combine(ExtractFilePath(ParamStr(0)), 'Diller'), Dil + '.json'), TEncoding.UTF8);
      for Anahtar in Anahtarlar do
        if Pos('"' + Anahtar + '"', Ham) = 0 then
          Kontrol(Dil + ': ' + Anahtar, False);
      Kontrol(Dil + ': anahtarlar tamam (' + IntToStr(Anahtarlar.Count) + ')', True);
    end;
  finally
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
      AyristirmaTesti;
      Tanim := Default(TBaglantiTanimi);
      Tanim.Ad := 'indeksoner';
      Tanim.Sunucu := Ortam('FBTEST_SUNUCU', 'localhost');
      Tanim.Port := StrToInt(Ortam('FBTEST_PORT', '3050'));
      Tanim.Kullanici := 'SYSDBA';
      Tanim.Sifre := Ortam('FBTEST_SIFRE', '');
      Tanim.KarakterSeti := VARSAYILAN_KARAKTER_SETI;
      Yol := IncludeTrailingPathDelimiter(Ortam('FBTEST_KLASOR', 'C:\Temp\bakimtest')) + 'indeks_' + FormatDateTime('hhnnss', Now) + '.fdb';
      Tanim.VeritabaniYolu := Yol;
      FbVeritabaniOlustur(Tanim);
      A := FbBaglan(Tanim);
      CanliTest;
      DilAnahtarTesti;
      FbBaglantiyiKes(A);
    except
      on E: Exception do
      begin
        Cikti.Add('HATA  beklenmeyen istisna: ' + E.ClassName + ': ' + E.Message);
        Inc(Hatalar);
      end;
    end;
    Cikti.Add('');
    Cikti.Add('Kontrol sayisi: ' + IntToStr(KontrolSayisi) + ', Hata sayisi: ' + IntToStr(Hatalar));
    Writeln(Cikti.Text);
  finally
    Cikti.Free;
  end;
  ExitCode := Hatalar;
end.
