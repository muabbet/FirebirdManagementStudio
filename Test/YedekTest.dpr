program YedekTest;

{ Asama 3c: uYedek (gbak ile yedek alma / yeni dosyaya geri yukleme) testi (komut satiri).

  Gecici veritabanlari acilir (varsayilan: gomulu Firebird). Gercek veriye dokunulmaz; sadece bu testin kendi
  gecici veritabani ve .fbk dosyalari kullanilir. gbak.exe, istemci\ klasorundekidir.

  Ortam degiskenleri: FBTEST_SUNUCU (bos = gomulu), FBTEST_PORT, FBTEST_KLASOR (gecici veritabanlarinin
  konacagi klasor; sunucu verilirse SUNUCUDAKI klasor olmali; .fbk dosyalari yine bu bilgisayarda
  %TEMP%\yedektest altina yazilir), FBTEST_KULLANICI, FBTEST_SIFRE, FBTEST_CIKTI (sonuc dosyasi),
  YEDEK_SATIR (iptal testindeki buyuk tablonun satir sayisi, varsayilan 1000000).
  Gomulu kipte biten veritabanlari ve .fbk dosyalari klasorun _arsiv alt klasorune tasinir (silinmez).
  Cikis kodu: hata sayisi (0 = hepsi gecti). }

{$APPTYPE CONSOLE}

uses
  Winapi.Windows,
  System.SysUtils, System.Classes, System.StrUtils, System.Math, System.Generics.Collections, System.IOUtils,
  System.Diagnostics, System.Hash, Data.DB,
  FireDAC.Stan.Intf, FireDAC.Stan.Param, FireDAC.Stan.Error, FireDAC.Comp.Client, FireDAC.Phys.FB,
  uDil, uBaglanti, uSorgu, uMetadata, uDDL, uYedek;

const
  { c g i(noktasiz) o s u I(noktali) }
  TURKCE = #$00E7#$011F#$0131#$00F6#$015F#$00FC#$0130;
  { "Turkce Klasor ..." Turkce karakterli ve bosluklu klasor adi }
  KLASOR_ADI = 'T'#$00FC'rk'#$00E7'e Klas'#$00F6'r '#$011F#$015F#$0131#$0130;
  GIZLI_SIFRE = 'GizliSifre!123';

type
  { Gbak ciktisini sayar; IptalMs > 0 ise o kadar ms sonra iptal ister. }
  TIzleyici = class
    Satir: Integer;
    IptalMs: Int64;
    Saat: TStopwatch;
    constructor Create(AIptalMs: Int64 = 0);
    procedure Cikti(const Metin: string; var Iptal: Boolean);
  end;

var
  Cikti: TStringList;
  Hatalar, KontrolSayisi: Integer;
  Bag: TAcikBaglanti;
  Klasor, YedekKlasoru: string;
  Damga: string;
  Uretilen: TStringList;
  Tanim: TBaglantiTanimi;

constructor TIzleyici.Create(AIptalMs: Int64);
begin
  inherited Create;
  IptalMs := AIptalMs;
  Saat := TStopwatch.StartNew;
end;

procedure TIzleyici.Cikti(const Metin: string; var Iptal: Boolean);
begin
  if Metin <> '' then
    Inc(Satir);
  if (IptalMs > 0) and (Saat.ElapsedMilliseconds >= IptalMs) then
    Iptal := True;
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

procedure Not_(const Metin: string);
begin
  Cikti.Add('      ' + Metin);
end;

function Kisalt(const Metin: string; Uzunluk: Integer = 400): string;
begin
  Result := Copy(StringReplace(StringReplace(Metin, #13, '', [rfReplaceAll]), #10, ' | ', [rfReplaceAll]), 1, Uzunluk);
end;

function MB(Bayt: Int64): string;
begin
  Result := Format('%.1f MB', [Bayt / (1024 * 1024)]);
end;

function DosyaBoyutu(const Dosya: string): Int64;
begin
  if TFile.Exists(Dosya) then
    Result := TFile.GetSize(Dosya)
  else
    Result := -1;
end;

function DosyaOzeti(const Dosya: string): string;
begin
  Result := THashMD5.GetHashStringFromFile(Dosya);
end;

function BaskaProgramKilidi(const Dosya: string): THandle;
begin
  { Baska program aciyormus gibi: paylasimsiz acar }
  Result := CreateFile(PChar(Dosya), GENERIC_READ, 0, nil, OPEN_EXISTING, 0, 0);
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
    if T.Sunucu <> '' then
    begin
      Baglanti.Params.Values['Server'] := T.Sunucu;
      Baglanti.Params.Values['Port'] := IntToStr(T.Port);
      Baglanti.Params.Values['Protocol'] := 'TCPIP';
    end;
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

procedure Komut(K: TAcikBaglanti; const Sql: string);
begin
  SorguCalistir(K, Sql).Free;
end;

function Skaler(K: TAcikBaglanti; const Sql: string): string;
var
  Q: TFDQuery;
begin
  Q := TFDQuery.Create(nil);
  try
    Q.Connection := K.Baglanti;
    Q.Open(Sql);
    Result := Q.Fields[0].AsString;
  finally
    Q.Free;
  end;
end;

{ Sorgunun tum satirlari ve kolonlarinin ozeti: "satir sayisi:md5". }
function TabloOzeti(K: TAcikBaglanti; const Sql: string): string;
var
  Q: TFDQuery;
  MD5: THashMD5;
  i, Sayi: Integer;
  Satir: string;
begin
  Q := TFDQuery.Create(nil);
  try
    Q.Connection := K.Baglanti;
    Q.Open(Sql);
    MD5 := THashMD5.Create;
    Sayi := 0;
    while not Q.Eof do
    begin
      Satir := '';
      for i := 0 to Q.FieldCount - 1 do
        Satir := Satir + Q.Fields[i].AsString + '|';
      MD5.Update(Satir);
      Inc(Sayi);
      Q.Next;
    end;
    Result := IntToStr(Sayi) + ':' + MD5.HashAsString;
  finally
    Q.Free;
  end;
end;

function BlobBaytlari(K: TAcikBaglanti; const Sql: string): TBytes;
var
  Q: TFDQuery;
begin
  Q := TFDQuery.Create(nil);
  try
    Q.Connection := K.Baglanti;
    Q.Open(Sql);
    Result := Q.Fields[0].AsBytes;
  finally
    Q.Free;
  end;
end;

function IkiliVeri: TBytes;
var
  i: Integer;
begin
  SetLength(Result, 70000);
  for i := 0 to High(Result) do
    Result[i] := (i * 7 + i div 256) mod 256;
end;

function UzunMetin: string;
var
  i: Integer;
begin
  Result := '';
  for i := 1 to 400 do
    Result := Result + 'Satir ' + IntToStr(i) + ' ' + TURKCE + #13#10;
end;

{ ---------- Test veritabani ---------- }

procedure SemaKur(K: TAcikBaglanti);
var
  Q: TFDQuery;
  Akis: TMemoryStream;
  Bayt: TBytes;
begin
  Komut(K, 'CREATE TABLE MUSTERI (ID INTEGER NOT NULL PRIMARY KEY, AD VARCHAR(60) CHARACTER SET UTF8, ' +
    'SEHIR VARCHAR(30), BAKIYE NUMERIC(15,2), KAYIT TIMESTAMP, NOT_METNI BLOB SUB_TYPE TEXT, ' +
    'RESIM BLOB SUB_TYPE BINARY)');
  Komut(K, 'CREATE GENERATOR GEN_MUSTERI');
  Komut(K, 'SET GENERATOR GEN_MUSTERI TO 4242');
  Komut(K, 'CREATE TRIGGER MUSTERI_BI FOR MUSTERI ACTIVE BEFORE INSERT POSITION 0 AS BEGIN ' +
    'IF (NEW.ID IS NULL) THEN NEW.ID = GEN_ID(GEN_MUSTERI, 1); END');
  Komut(K, 'CREATE TABLE SIPARIS (ID INTEGER NOT NULL PRIMARY KEY, MUSTERI_ID INTEGER NOT NULL, ' +
    'TUTAR NUMERIC(18,4) NOT NULL, CONSTRAINT FK_SIP_MUS FOREIGN KEY (MUSTERI_ID) REFERENCES MUSTERI (ID), ' +
    'CONSTRAINT CK_TUTAR CHECK (TUTAR >= 0))');
  Komut(K, 'CREATE DESCENDING INDEX IX_SIP_TUTAR ON SIPARIS (TUTAR)');
  { Birinci satir: Turkce metin, uzun metin BLOB'u ve 70.000 baytlik ikili BLOB (parametreyle) }
  Q := TFDQuery.Create(nil);
  Akis := TMemoryStream.Create;
  try
    Q.Connection := K.Baglanti;
    Q.SQL.Text := 'INSERT INTO MUSTERI (ID, AD, SEHIR, NOT_METNI, RESIM) VALUES (:ID, :AD, :SEHIR, :NOT_METNI, :RESIM)';
    Q.ParamByName('ID').AsInteger := 1;
    Q.ParamByName('AD').DataType := ftWideString;
    Q.ParamByName('AD').AsWideString := 'Ali ' + TURKCE;
    Q.ParamByName('SEHIR').DataType := ftWideString;
    Q.ParamByName('SEHIR').AsWideString := #$0130'zmir '#$015E#$00FC'k'#$00FC;
    Q.ParamByName('NOT_METNI').DataType := ftWideMemo;
    Q.ParamByName('NOT_METNI').AsWideString := UzunMetin;
    Bayt := IkiliVeri;
    Akis.WriteBuffer(Bayt[0], Length(Bayt));
    Akis.Position := 0;
    Q.ParamByName('RESIM').LoadFromStream(Akis, ftBlob);
    Q.ExecSQL;
  finally
    Akis.Free;
    Q.Free;
  end;
  Komut(K, 'UPDATE MUSTERI SET BAKIYE = 1234567890123.45, KAYIT = ''2026-10-17 13:14:15.1234'' WHERE ID = 1');
  Komut(K, 'EXECUTE BLOCK AS DECLARE VARIABLE I INTEGER; BEGIN I = 2; WHILE (I <= 200) DO BEGIN ' +
    'INSERT INTO MUSTERI (ID, AD, SEHIR, BAKIYE, KAYIT) VALUES (:I, ''M'' || :I || '' ' + TURKCE + ''', ''Sehir '' || MOD(:I, 7), ' +
    ':I * 1.25, DATEADD(:I SECOND TO TIMESTAMP ''2020-01-01 00:00:00'')); I = I + 1; END END');
  { Uretecli satir: kimlik tetikleyiciden gelir (4243) }
  Komut(K, 'INSERT INTO MUSTERI (AD) VALUES (''Uretecten gelen'')');
  Komut(K, 'EXECUTE BLOCK AS DECLARE VARIABLE I INTEGER; BEGIN I = 1; WHILE (I <= 500) DO BEGIN ' +
    'INSERT INTO SIPARIS VALUES (:I, 1 + MOD(:I, 199), :I * 3.1416); I = I + 1; END END');
  Komut(K, 'CREATE VIEW V_OZET AS SELECT M.ID, M.AD, (SELECT COUNT(*) FROM SIPARIS S WHERE S.MUSTERI_ID = M.ID) AS ADET ' +
    'FROM MUSTERI M');
  Komut(K, 'CREATE PROCEDURE P_TOPLAM (MID INTEGER) RETURNS (TOPLAM NUMERIC(18,4)) AS BEGIN ' +
    'SELECT COALESCE(SUM(TUTAR), 0) FROM SIPARIS WHERE MUSTERI_ID = :MID INTO :TOPLAM; SUSPEND; END');
end;

procedure BuyukTabloKur(K: TAcikBaglanti; N: Integer);
var
  Saat: TStopwatch;
begin
  Saat := TStopwatch.StartNew;
  Komut(K, 'CREATE TABLE T_BUYUK (ID INTEGER NOT NULL PRIMARY KEY, AD VARCHAR(50), ACIKLAMA VARCHAR(200))');
  Komut(K, 'EXECUTE BLOCK AS DECLARE VARIABLE I INTEGER; BEGIN I = 1; WHILE (I <= ' + IntToStr(N) + ') DO BEGIN ' +
    'INSERT INTO T_BUYUK VALUES (:I, ''Kayit '' || :I, LPAD(:I, 150, ''x'')); I = I + 1; END END');
  Not_('T_BUYUK ' + IntToStr(N) + ' satir olusturuldu: ' + IntToStr(Saat.ElapsedMilliseconds) + ' ms');
end;

function MetadataMetni(K: TAcikBaglanti): string;
var
  Yazici: TStringWriter;
  Uyarilar: TStringList;
  Secenek: TCikarSecenekleri;
begin
  Secenek := Default(TCikarSecenekleri);
  Yazici := TStringWriter.Create;
  Uyarilar := TStringList.Create;
  try
    MetadataCikar(K, Secenek, Yazici, Uyarilar, nil);
    Result := Yazici.ToString;
  finally
    Uyarilar.Free;
    Yazici.Free;
  end;
end;

function Birlestir(const Adlar: TArray<string>): string;
var
  Ad: string;
begin
  Result := '';
  for Ad in Adlar do
    Result := Result + Ad + ',';
end;

function AdListeleri(K: TAcikBaglanti): string;
var
  Liste: TStringList;
begin
  Liste := TStringList.Create;
  try
    TablolariGetir(K, Liste);
    Result := 'T:' + Liste.CommaText;
    Liste.Clear;
    ViewlariGetir(K, Liste);
    Result := Result + ' V:' + Liste.CommaText;
    Liste.Clear;
    ProsedurleriGetir(K, Liste);
    Result := Result + ' P:' + Liste.CommaText;
    Liste.Clear;
    GeneratorleriGetir(K, Liste);
    Result := Result + ' G:' + Liste.CommaText;
  finally
    Liste.Free;
  end;
end;

{ Gomulu kipte veritabani dosyasi bu surece aittir (baska surec, gbak da, acamaz: "dosya baska bir islem
  tarafindan kullaniliyor"). Bu yuzden gbak'tan once kaynak baglanti kapatilir. Sunucu kipinde dokunulmaz. }
procedure KaynakKapat;
begin
  if (Tanim.Sunucu = '') and (Bag <> nil) then
  begin
    FbBaglantiyiKes(Bag);
    Bag := nil;
  end;
end;

procedure KaynakAc;
begin
  if Bag = nil then
    Bag := FbBaglan(Tanim);
end;

{ ---------- 1. Tam tur ---------- }

procedure TamTurTesti(const YedekDosya, GeriYol: string);
var
  Sonuc: TYedekSonucu;
  Izle: TIzleyici;
  Geri: TBaglantiTanimi;
  K2: TAcikBaglanti;
  Ok: Boolean;
  Eski, Yeni: TBytes;
  Tablo: string;
begin
  KaynakKapat;
  Izle := TIzleyici.Create;
  try
    Ok := YedekAl(Tanim, YedekDosya, Izle.Cikti, Sonuc);
    Not_('yedek: ' + IntToStr(Sonuc.Sure) + ' ms, ' + IntToStr(Izle.Satir) + ' cikti satiri, dosya ' +
      MB(DosyaBoyutu(YedekDosya)));
    Not_('ayrinti: ' + Kisalt(Sonuc.Ayrinti));
    if not Ok then
      Not_('ham cikti: ' + Kisalt(Sonuc.HamCikti, 800));
  finally
    Izle.Free;
  end;
  Kontrol('tam tur: YedekAl basarili', Ok and Sonuc.Basarili);
  Kontrol('tam tur: .fbk olustu, boyut > 0 (' + IntToStr(DosyaBoyutu(YedekDosya)) + ' bayt)', DosyaBoyutu(YedekDosya) > 0);
  Kontrol('tam tur: .yarim dosyasi kalmadi', not TFile.Exists(YedekDosya + '.yarim'));
  Kontrol('tam tur: ham cikti bos degil (-v calisiyor)', Trim(Sonuc.HamCikti) <> '');
  Kontrol('tam tur: Sonuc.Dosya = hedef', Sonuc.Dosya = YedekDosya);
  Uretilen.Add(YedekDosya);

  Geri := Tanim;
  Geri.Ad := 'geri';
  Geri.VeritabaniYolu := GeriYol;
  Izle := TIzleyici.Create;
  try
    Ok := GeriYukle(Geri, YedekDosya, GeriYol, Izle.Cikti, Sonuc);
    Not_('geri yukleme: ' + IntToStr(Sonuc.Sure) + ' ms, ' + IntToStr(Izle.Satir) + ' cikti satiri');
    if not Ok then
      Not_('ham cikti: ' + Kisalt(Sonuc.HamCikti, 800) + ' cumle: ' + Sonuc.Cumle);
  finally
    Izle.Free;
  end;
  Kontrol('tam tur: GeriYukle basarili', Ok and Sonuc.Basarili);
  if not Ok then
    Exit;
  Uretilen.Add(GeriYol);
  KaynakAc;
  K2 := FbBaglan(Geri);
  try
    Kontrol('tam tur: geri yuklenen veritabanina baglanildi (Firebird ' + K2.Surum + ')', K2 <> nil);
    Kontrol('tam tur: nesne adlari ayni: ' + AdListeleri(Bag), AdListeleri(Bag) = AdListeleri(K2));
    for Tablo in ['SELECT * FROM MUSTERI ORDER BY ID', 'SELECT * FROM SIPARIS ORDER BY ID',
      'SELECT * FROM V_OZET ORDER BY ID'] do
      Kontrol('tam tur: satirlar ayni (' + Tablo + ') ' + TabloOzeti(Bag, Tablo),
        TabloOzeti(Bag, Tablo) = TabloOzeti(K2, Tablo));
    Kontrol('tam tur: MUSTERI satir sayisi 201',
      (Skaler(K2, 'SELECT COUNT(*) FROM MUSTERI') = '201') and (Skaler(Bag, 'SELECT COUNT(*) FROM MUSTERI') = '201'));
    Kontrol('tam tur: SIPARIS satir sayisi 500', Skaler(K2, 'SELECT COUNT(*) FROM SIPARIS') = '500');
    Eski := BlobBaytlari(Bag, 'SELECT RESIM FROM MUSTERI WHERE ID = 1');
    Yeni := BlobBaytlari(K2, 'SELECT RESIM FROM MUSTERI WHERE ID = 1');
    Kontrol('tam tur: ikili BLOB bayt bayt ayni (' + IntToStr(Length(Yeni)) + ' bayt)',
      (Length(Yeni) = 70000) and CompareMem(@Eski[0], @Yeni[0], Length(Eski)));
    Kontrol('tam tur: metin BLOB ayni (Turkce karakterli, ' + Skaler(K2, 'SELECT CHAR_LENGTH(NOT_METNI) FROM MUSTERI WHERE ID = 1') + ' karakter)',
      Skaler(K2, 'SELECT NOT_METNI FROM MUSTERI WHERE ID = 1') = Skaler(Bag, 'SELECT NOT_METNI FROM MUSTERI WHERE ID = 1'));
    Kontrol('tam tur: Turkce ad ayni', Skaler(K2, 'SELECT AD FROM MUSTERI WHERE ID = 1') = 'Ali ' + TURKCE);
    Kontrol('tam tur: NUMERIC(15,2) ayni (' + Skaler(K2, 'SELECT BAKIYE FROM MUSTERI WHERE ID = 1') + ')',
      Skaler(K2, 'SELECT BAKIYE FROM MUSTERI WHERE ID = 1') = Skaler(Bag, 'SELECT BAKIYE FROM MUSTERI WHERE ID = 1'));
    Kontrol('tam tur: TIMESTAMP ayni (' + Skaler(K2, 'SELECT KAYIT FROM MUSTERI WHERE ID = 1') + ')',
      Skaler(K2, 'SELECT KAYIT FROM MUSTERI WHERE ID = 1') = Skaler(Bag, 'SELECT KAYIT FROM MUSTERI WHERE ID = 1'));
    Kontrol('tam tur: generator degeri yedekte korundu (' + Skaler(K2, 'SELECT GEN_ID(GEN_MUSTERI, 0) FROM RDB$DATABASE') + ')',
      (Skaler(K2, 'SELECT GEN_ID(GEN_MUSTERI, 0) FROM RDB$DATABASE') = '4243') and
      (Skaler(Bag, 'SELECT GEN_ID(GEN_MUSTERI, 0) FROM RDB$DATABASE') = '4243'));
    Kontrol('tam tur: uretecli satir (tetikleyici) ID 4243',
      Skaler(K2, 'SELECT ID FROM MUSTERI WHERE AD = ''Uretecten gelen''') = '4243');
    Kontrol('tam tur: prosedur ayni sonucu verir',
      Skaler(K2, 'SELECT TOPLAM FROM P_TOPLAM(1)') = Skaler(Bag, 'SELECT TOPLAM FROM P_TOPLAM(1)'));
    Kontrol('tam tur: kisitlar yerinde (CHECK negatif tutari reddeder)',
      Skaler(K2, 'SELECT COUNT(*) FROM RDB$RELATION_CONSTRAINTS WHERE RDB$CONSTRAINT_TYPE IN (''FOREIGN KEY'', ''CHECK'', ''PRIMARY KEY'')') =
      Skaler(Bag, 'SELECT COUNT(*) FROM RDB$RELATION_CONSTRAINTS WHERE RDB$CONSTRAINT_TYPE IN (''FOREIGN KEY'', ''CHECK'', ''PRIMARY KEY'')'));
    Kontrol('tam tur: metadata (MetadataCikar ciktisi) birebir ayni (' + IntToStr(Length(MetadataMetni(K2))) + ' karakter)',
      MetadataMetni(Bag) = MetadataMetni(K2));
  finally
    FbBaglantiyiKes(K2);
    KaynakKapat;
  end;
end;

{ ---------- 2. Hedef var ---------- }

{ Iki dosya arasindaki farkli bayt sayisi ve en son farkli baytin yeri (boyutlar ayni olmali). }
function BaytFarki(const A, B: string; out SonYer: Int64): Int64;
var
  X, Y: TBytes;
  i: Integer;
begin
  X := TFile.ReadAllBytes(A);
  Y := TFile.ReadAllBytes(B);
  Result := 0;
  SonYer := -1;
  for i := 0 to Min(Length(X), Length(Y)) - 1 do
    if X[i] <> Y[i] then
    begin
      Inc(Result);
      SonYer := i;
    end;
end;

{ OLCUM: gbak'i (uYedek'i degil) var olan bir veritabani dosyasinin kopyasina -c ile calistirir. Hata verir ama
  dosyanin baslik sayfasi birkac bayt degisir; cunku gbak once var mi diye veritabanina baglanir. Salt baglanip
  kesmek de ayni baytlari degistirir. Bu yuzden uYedek.GeriYukle, yerel hedef varsa gbak'i hic calistirmaz. }
procedure GbakKendiOlcumu(const YedekDosya, VarOlanYol: string);
var
  Kopya1, Kopya2, Ham: string;
  Kod: Cardinal;
  Fark1, Fark2, Yer1, Yer2: Int64;
  K: TAcikBaglanti;
  Tanim2: TBaglantiTanimi;
begin
  Kopya1 := ChangeFileExt(VarOlanYol, '') + '_kopya1.fdb';
  Kopya2 := ChangeFileExt(VarOlanYol, '') + '_kopya2.fdb';
  TFile.Copy(VarOlanYol, Kopya1, True);
  TFile.Copy(VarOlanYol, Kopya2, True);
  Uretilen.Add(Kopya1);
  Uretilen.Add(Kopya2);
  AltIslemCalistir(GbakYolu, '-c -user "' + Tanim.Kullanici + '" "' + YedekDosya + '" "' + Kopya1 + '"', Tanim.Sifre,
    nil, Ham, Kod);
  Yer1 := 0;
  Fark1 := BaytFarki(VarOlanYol, Kopya1, Yer1);
  Not_('olcum: ham gbak -c var olan dosyaya: cikis kodu ' + IntToStr(Kod) + ', degisen bayt ' + IntToStr(Fark1) +
    ', son degisen bayt yeri ' + IntToStr(Yer1));
  Kontrol('olcum: ham gbak -c var olan dosyada hata verdi ve metni HEDEF_VAR cumlesine cevriliyor',
    (Kod <> 0) and (GbakHatasiniCevir(Ham) = T('ERR_YEDEK_HEDEF_VAR')));
  Kontrol('olcum: ham gbak -c yalniz baslik sayfasini (ilk 8192 bayt) degistirdi, veri sayfalarina dokunmadi',
    Yer1 < 8192);
  { Yalnizca baglanip kesmek }
  Tanim2 := Tanim;
  Tanim2.Ad := 'kopya2';
  Tanim2.VeritabaniYolu := Kopya2;
  K := FbBaglan(Tanim2);
  FbBaglantiyiKes(K);
  Fark2 := BaytFarki(VarOlanYol, Kopya2, Yer2);
  Not_('olcum: yalnizca baglanip kesmek: degisen bayt ' + IntToStr(Fark2) + ', son degisen bayt yeri ' + IntToStr(Yer2));
  Not_('olcum: baglanip kesmek de dosyayi degistirir (baslik sayfasi disinda, islem sayfalarinda); bu yuzden "bayt bayt ayni" kosulu yalniz gbak hic calismazsa saglanabilir.');
end;

procedure HedefVarTesti(const YedekDosya, VarOlanYol: string);
var
  Sonuc: TYedekSonucu;
  Geri: TBaglantiTanimi;
  Once, Sonra: string;
  OnceBoyut: Int64;
  Ok: Boolean;
begin
  if Tanim.Sunucu <> '' then
  begin
    Not_('hedef var: sunucuda dosya bayti karsilastirilamaz, atlandi (yalniz cumle denenir)');
  end;
  Geri := Tanim;
  Geri.Ad := 'geri2';
  Geri.VeritabaniYolu := VarOlanYol;
  OnceBoyut := 0;
  if Tanim.Sunucu = '' then
  begin
    Once := DosyaOzeti(VarOlanYol);
    OnceBoyut := DosyaBoyutu(VarOlanYol);
  end;
  Ok := GeriYukle(Geri, YedekDosya, VarOlanYol, nil, Sonuc);
  Not_('ham cikti: ' + Kisalt(Sonuc.HamCikti));
  Not_('cumle: ' + Sonuc.Cumle);
  Kontrol('hedef var: geri yukleme BASARISIZ (var olan dosyanin uzerine yazilmaz)', (not Ok) and (not Sonuc.Basarili));
  Kontrol('hedef var: cumle ERR_YEDEK_HEDEF_VAR', Sonuc.Cumle = T('ERR_YEDEK_HEDEF_VAR'));
  if Tanim.Sunucu = '' then
  begin
    Sonra := DosyaOzeti(VarOlanYol);
    Kontrol('hedef var: dosya boyutu degismedi (' + IntToStr(OnceBoyut) + ')', DosyaBoyutu(VarOlanYol) = OnceBoyut);
    Kontrol('hedef var: dosya iceriginin MD5 ozeti degismedi (bayt bayt ayni)', Once = Sonra);
    Kontrol('hedef var: yarim dosya iddiasi yok (YarimDosya bos)', Sonuc.YarimDosya = '');
  end;
  { acik baglantinin yoluyla ayni hedef: gbak calistirilmaz }
  if Tanim.Sunucu = '' then
    GbakKendiOlcumu(YedekDosya, VarOlanYol);
  KaynakAc;
  Ok := GeriYukle(Tanim, YedekDosya, Tanim.VeritabaniYolu, nil, Sonuc);
  Kontrol('hedef acik baglantiyla ayni: reddedildi, gbak calistirilmadi (ham cikti bos)',
    (not Ok) and (Sonuc.HamCikti = '') and (Sonuc.Cumle = TF('ERR_YEDEK_HEDEF_ACIK', [Tanim.Ad])));
  KaynakKapat;
end;

{ ---------- 3. Yedek hedefi var (.yarim yontemi) ve 6. Iptal ---------- }

procedure YarimYontemiTesti(const KucukTanim, BuyukTanim: TBaglantiTanimi; const Hedef: string; TamSure: Int64);
var
  Sonuc: TYedekSonucu;
  Izle: TIzleyici;
  Once, Sonra, Yarim: string;
  Ok: Boolean;
  Kilit: THandle;
  Boyut1, Boyut2: Int64;
  Yanina: TArray<string>;
  Yok: TBaglantiTanimi;
begin
  Yarim := Hedef + '.yarim';

  { a) Basarili yedek mevcut hedefin yerine gecer }
  TFile.WriteAllText(Hedef, 'ESKI GECERLI YEDEK (deneme icerigi)');
  Once := DosyaOzeti(Hedef);
  Ok := YedekAl(KucukTanim, Hedef, nil, Sonuc);
  Sonra := DosyaOzeti(Hedef);
  Kontrol('yarim a: basarili yedek mevcut hedefin yerine gecti', Ok and (Once <> Sonra) and (DosyaBoyutu(Hedef) > 1000));
  Kontrol('yarim a: .yarim dosyasi kalmadi (yer degistirdi)', not TFile.Exists(Yarim));

  { b) Onceki bir .yarim silinmez, tarihli adla yanina tasinir }
  TFile.WriteAllText(Yarim, 'ESKI YARIM DOSYA');
  Ok := YedekAl(KucukTanim, Hedef, nil, Sonuc);
  Yanina := TDirectory.GetFiles(ExtractFilePath(Hedef), ExtractFileName(Hedef) + '.yarim-*');
  Kontrol('yarim b: onceki .yarim silinmedi, tarihli adla yanina tasindi (' + IntToStr(Length(Yanina)) + ' dosya)',
    Ok and (Length(Yanina) = 1) and (TFile.ReadAllText(Yanina[0]) = 'ESKI YARIM DOSYA'));
  Kontrol('yarim b: yeni .yarim hedefin yerine gecti', not TFile.Exists(Yarim));
  if Length(Yanina) > 0 then
    Uretilen.Add(Yanina[0]);

  { c) Hata (olmayan kaynak): eski yedek dokunulmadan kalir }
  Yok := KucukTanim;
  Yok.VeritabaniYolu := ChangeFileExt(KucukTanim.VeritabaniYolu, '') + '_yok.fdb';
  Once := DosyaOzeti(Hedef);
  Ok := YedekAl(Yok, Hedef, nil, Sonuc);
  Not_('c ham cikti: ' + Kisalt(Sonuc.HamCikti, 500));
  Not_('c cumle: ' + Sonuc.Cumle + ' | yarim dosya: "' + Sonuc.YarimDosya + '"');
  Kontrol('yarim c: olmayan kaynak -> basarisiz', (not Ok) and (not Sonuc.Basarili));
  Kontrol('yarim c: eski yedek DOKUNULMADAN kaldi (MD5 ayni)', DosyaOzeti(Hedef) = Once);
  Kontrol('yarim c: cumle ERR_YEDEK_KAYNAK_YOK', Sonuc.Cumle = T('ERR_YEDEK_KAYNAK_YOK'));
  Kontrol('yarim c: gbak bir .yarim biraktiysa silinmedi (var: ' + BoolToStr(TFile.Exists(Yarim), True) + ')',
    (Sonuc.YarimDosya = '') = (not TFile.Exists(Yarim)));
  if TFile.Exists(Yarim) then
    Uretilen.Add(Yarim);

  { d) Iptal: alt islem durur, False doner, eski yedek bozulmaz, .yarim silinmez }
  if TFile.Exists(Yarim) then
    TFile.Move(Yarim, Yarim + '-c');
  Once := DosyaOzeti(Hedef);
  Izle := TIzleyici.Create(Max(150, TamSure div 3));
  try
    Ok := YedekAl(BuyukTanim, Hedef, Izle.Cikti, Sonuc);
    Not_('iptal: tam yedek ' + IntToStr(TamSure) + ' ms surmustu; iptal ' + IntToStr(Izle.IptalMs) + ' ms sonra istendi, ' +
      'YedekAl ' + IntToStr(Sonuc.Sure) + ' ms sonra dondu');
  finally
    Izle.Free;
  end;
  Kontrol('iptal: YedekAl False doner', not Ok);
  Kontrol('iptal: Sonuc.Iptal = True, Basarili = False', Sonuc.Iptal and (not Sonuc.Basarili));
  Kontrol('iptal: iptal tam surenin altinda bitti (' + IntToStr(Sonuc.Sure) + ' < ' + IntToStr(TamSure) + ' ms)',
    Sonuc.Sure < TamSure);
  Kontrol('iptal: eski yedek DOKUNULMADAN kaldi (MD5 ayni)', DosyaOzeti(Hedef) = Once);
  Kontrol('iptal: .yarim dosyasi SILINMEDI ve Sonuc.YarimDosya onu gosteriyor',
    TFile.Exists(Yarim) and (Sonuc.YarimDosya = Yarim));
  Boyut1 := DosyaBoyutu(Yarim);
  Sleep(800);
  Boyut2 := DosyaBoyutu(Yarim);
  Kontrol('iptal: alt islem durdu, yarim dosya artik buyumuyor (' + IntToStr(Boyut1) + ' = ' + IntToStr(Boyut2) + ')',
    Boyut1 = Boyut2);
  Not_('iptalde yarim dosya boyutu: ' + MB(Boyut1));
  Uretilen.Add(Yarim);
  if TFile.Exists(Yarim + '-c') then
    Uretilen.Add(Yarim + '-c');

  { e) Hedef baska programda acik: yedek alinir ama yer degistirilemez; .yarim silinmez }
  TFile.Move(Yarim, Yarim + '-iptal');
  Uretilen.Add(Yarim + '-iptal');
  Kilit := BaskaProgramKilidi(Hedef);
  try
    Ok := YedekAl(KucukTanim, Hedef, nil, Sonuc);
  finally
    CloseHandle(Kilit);
  end;
  Not_('e cumle: ' + Sonuc.Cumle);
  Kontrol('yarim e: hedef baska programda acik -> basarisiz', (not Ok) and (not Sonuc.Basarili));
  Kontrol('yarim e: cumle "yerine konamadi" cumlesi',
    StartsText(Copy(T('ERR_YEDEK_YERINE_KONAMADI'), 1, 20), Sonuc.Cumle));
  Kontrol('yarim e: tam yedek .yarim olarak duruyor (silinmedi, ' + IntToStr(DosyaBoyutu(Yarim)) + ' bayt)',
    (DosyaBoyutu(Yarim) > 1000) and (Sonuc.YarimDosya = Yarim));
  Uretilen.Add(Yarim);
  Uretilen.Add(Hedef);
end;

{ ---------- 4. Sifre guvenligi ---------- }

procedure SifreTesti(const YedekDosya: string);
var
  Sonuc: TYedekSonucu;
  Gizli: TBaglantiTanimi;
  Ham, Kabuk: string;
  Kod: Cardinal;
begin
  Kabuk := Ortam('ComSpec', 'C:\Windows\System32\cmd.exe');
  Kontrol('sifre: kendi ortamimizda ISC_PASSWORD bos (once)', GetEnvironmentVariable('ISC_PASSWORD') = '');
  Gizli := Tanim;
  Gizli.Sifre := GIZLI_SIFRE;
  YedekAl(Gizli, YedekDosya, nil, Sonuc);
  Kontrol('sifre: komut satiri metni (Ayrinti) sifreyi ICERMEZ', Pos(GIZLI_SIFRE, Sonuc.Ayrinti) = 0);
  Kontrol('sifre: gbak ham ciktisi sifreyi icermez', Pos(GIZLI_SIFRE, Sonuc.HamCikti) = 0);
  Kontrol('sifre: komut satirinda -password anahtari yok', Pos('-pas', LowerCase(Sonuc.Ayrinti)) = 0);
  Not_('komut satiri (ayrinti): ' + Kisalt(Sonuc.Ayrinti));
  Uretilen.Add(YedekDosya);
  { alt islemin ortaminda ISC_PASSWORD var }
  AltIslemCalistir(Kabuk, '/c echo SIFRE=%ISC_PASSWORD%', GIZLI_SIFRE, nil, Ham, Kod);
  Kontrol('sifre: alt islemin ortaminda ISC_PASSWORD var', Pos('SIFRE=' + GIZLI_SIFRE, Ham) > 0);
  AltIslemCalistir(Kabuk, '/c echo SIFRE=%ISC_PASSWORD%', '', nil, Ham, Kod);
  Kontrol('sifre: sifre verilmezse alt islemde ISC_PASSWORD yok', Pos('SIFRE=%ISC_PASSWORD%', Ham) > 0);
  Kontrol('sifre: kendi ortamimizda ISC_PASSWORD hala bos (sonra)', GetEnvironmentVariable('ISC_PASSWORD') = '');
  { kendi ortamimizda baska bir ISC_PASSWORD varsa alt islem onu miras almaz, biz de onu degistirmeyiz }
  SetEnvironmentVariable('ISC_PASSWORD', 'DIS_ESKI_DEGER');
  try
    AltIslemCalistir(Kabuk, '/c echo SIFRE=%ISC_PASSWORD%', '', nil, Ham, Kod);
    Kontrol('sifre: kendi ortamimizdaki eski deger alt isleme sizmaz', Pos('DIS_ESKI_DEGER', Ham) = 0);
    AltIslemCalistir(Kabuk, '/c echo SIFRE=%ISC_PASSWORD%', GIZLI_SIFRE, nil, Ham, Kod);
    Kontrol('sifre: verilen sifre eskinin yerine gecer', (Pos('SIFRE=' + GIZLI_SIFRE, Ham) > 0) and (Pos('DIS_ESKI_DEGER', Ham) = 0));
    Kontrol('sifre: kendi ortamimiz DEGISMEDI (eski deger duruyor)', GetEnvironmentVariable('ISC_PASSWORD') = 'DIS_ESKI_DEGER');
  finally
    SetEnvironmentVariable('ISC_PASSWORD', nil);
  end;
  Kontrol('sifre: kendi ortamimizda ISC_PASSWORD bos (en son)', GetEnvironmentVariable('ISC_PASSWORD') = '');
end;

{ ---------- 5. Hatalar ---------- }

procedure HataKontrol(const Ad: string; Ok: Boolean; const Sonuc: TYedekSonucu; const Anahtar: string);
begin
  Not_(Ad + ' | ham: ' + Kisalt(Sonuc.HamCikti, 500));
  Not_(Ad + ' | cumle: ' + Sonuc.Cumle);
  Kontrol('hata: ' + Ad + ' -> basarisiz', (not Ok) and (not Sonuc.Basarili));
  Kontrol('hata: ' + Ad + ' -> anlasilir cumle (' + Anahtar + '), ham metin degil', Sonuc.Cumle = T(Anahtar));
  Kontrol('hata: ' + Ad + ' -> Ayrinti komut ve cikis kodunu tasiyor', (Pos('gbak', Sonuc.Ayrinti) > 0) and
    (Pos(IntToStr(1), Sonuc.Ayrinti) > 0));
end;

procedure HataTestleri(const KucukTanim: TBaglantiTanimi; const KucukFbk: string);
var
  Sonuc: TYedekSonucu;
  Ok: Boolean;
  Yok, Yanlis: TBaglantiTanimi;
  Bozuk, YokKlasor, Kilitli, GeriYol: string;
  Kilit: THandle;
  Istisna: string;
begin
  YokKlasor := TPath.Combine(YedekKlasoru, 'olmayan klasor');
  { olmayan kaynak veritabani }
  Yok := KucukTanim;
  Yok.VeritabaniYolu := ChangeFileExt(KucukTanim.VeritabaniYolu, '') + '_yok.fdb';
  Ok := YedekAl(Yok, TPath.Combine(YedekKlasoru, 'kaynaksiz.fbk'), nil, Sonuc);
  HataKontrol('olmayan kaynak veritabani', Ok, Sonuc, 'ERR_YEDEK_KAYNAK_YOK');
  { kodlama: isletim sistemi hata metni Turkce karakterlerle dogru okunuyor mu (Windows Turkce ise) }
  Not_('kodlama: ACP=' + IntToStr(GetACP) + ' OEM=' + IntToStr(GetOEMCP) +
    ' | ham metinde "' + #$0131 + '" harfi var mi: ' + BoolToStr(Pos(#$0131, Sonuc.HamCikti) > 0, True));
  if TFile.Exists(TPath.Combine(YedekKlasoru, 'kaynaksiz.fbk.yarim')) then
    Uretilen.Add(TPath.Combine(YedekKlasoru, 'kaynaksiz.fbk.yarim'));
  { olmayan klasore yedek }
  Ok := YedekAl(KucukTanim, TPath.Combine(YokKlasor, 'x.fbk'), nil, Sonuc);
  HataKontrol('olmayan klasore yedek', Ok, Sonuc, 'ERR_YEDEK_DOSYA');
  { bozuk (rastgele metin) yedek dosyasi }
  Bozuk := TPath.Combine(YedekKlasoru, 'bozuk.fbk');
  TFile.WriteAllText(Bozuk, 'Bu bir Firebird yedegi degil, rastgele bir metin dosyasi.' + sLineBreak);
  Uretilen.Add(Bozuk);
  GeriYol := IncludeTrailingPathDelimiter(Klasor) + 'bozuktan_' + Damga + '.fdb';
  Ok := GeriYukle(KucukTanim, Bozuk, GeriYol, nil, Sonuc);
  HataKontrol('bozuk .fbk', Ok, Sonuc, 'ERR_YEDEK_BOZUK');
  if Tanim.Sunucu = '' then
  begin
    Kontrol('hata: bozuk .fbk -> hedef dosya olusmadi', not TFile.Exists(GeriYol));
    if TFile.Exists(GeriYol) then
      Uretilen.Add(GeriYol);
  end;
  { olmayan .fbk }
  Ok := GeriYukle(KucukTanim, TPath.Combine(YedekKlasoru, 'yoktur.fbk'), GeriYol, nil, Sonuc);
  HataKontrol('olmayan .fbk', Ok, Sonuc, 'ERR_YEDEK_DOSYA');
  { baska programda acik (kilitli) .fbk }
  Kilitli := TPath.Combine(YedekKlasoru, 'kilitli.fbk');
  TFile.Copy(KucukFbk, Kilitli, True);
  Uretilen.Add(Kilitli);
  Kilit := BaskaProgramKilidi(Kilitli);
  try
    Ok := GeriYukle(KucukTanim, Kilitli, GeriYol, nil, Sonuc);
  finally
    CloseHandle(Kilit);
  end;
  HataKontrol('baska programda acik .fbk', Ok, Sonuc, 'ERR_YEDEK_DOSYA');
  { olmayan klasore geri yukleme }
  Ok := GeriYukle(KucukTanim, KucukFbk, IncludeTrailingPathDelimiter(Klasor) + 'olmayan klasor\geri.fdb', nil, Sonuc);
  HataKontrol('olmayan klasore geri yukleme', Ok, Sonuc, 'ERR_YEDEK_HEDEF_YAZILAMADI');
  { yanlis kullanici / sifre }
  Yanlis := KucukTanim;
  Yanlis.Kullanici := 'YOKKULLANICI';
  Yanlis.Sifre := 'yanlis';
  Ok := YedekAl(Yanlis, TPath.Combine(YedekKlasoru, 'yanlis.fbk'), nil, Sonuc);
  if Ok then
  begin
    Not_('DENENMEDI: gomulu ortamda kimlik dogrulama yok, yanlis kullanici ile de yedek alindi. ' +
      'Yanlis sifre cumlesi sunucu testlerine (3050/3051) birakildi.');
    Uretilen.Add(TPath.Combine(YedekKlasoru, 'yanlis.fbk'));
  end
  else
    HataKontrol('yanlis kullanici/sifre', Ok, Sonuc, IfThen(Tanim.Sunucu = '', 'ERR_YEDEK_YETKI', 'ERR_SIFRE'));
  { gbak.exe yok }
  GbakYoluAyarla('C:\yok\gbak.exe');
  Istisna := '';
  try
    YedekAl(KucukTanim, TPath.Combine(YedekKlasoru, 'gbaksiz.fbk'), nil, Sonuc);
  except
    on E: Exception do
      Istisna := E.Message;
  end;
  Kontrol('hata: gbak.exe yoksa GbakVarMi False', not GbakVarMi);
  Kontrol('hata: gbak.exe yoksa anlasilir istisna ("' + Kisalt(Istisna, 100) + '")',
    StartsText(Copy(T('ERR_YEDEK_BASLATILAMADI'), 1, 14), Istisna));
  GbakYoluAyarla('');
  Kontrol('hata: ayar geri alininca GbakVarMi True', GbakVarMi);
end;

{ Ham gbak metni -> cumle eslemesi (birim duzeyi). Ilk uc ornek bu makinede OLCULDU, digerleri Firebird
  belgelerinden/bellekten ornek metinlerdir (gercek sunucuda sahibi dener). }
procedure EslemeTesti;
type
  TOrnek = record
    Ham, Anahtar, Kaynak: string;
  end;
const
  ORNEKLER: array[0..19] of TOrnek = (
    (Ham: 'gbak: ERROR:cannot open backup file C:\x\y.fbk' + #13#10 + 'gbak:Exiting before completion due to errors'; Anahtar: 'ERR_YEDEK_DOSYA'; Kaynak: 'olculdu'),
    (Ham: 'gbak: ERROR:expected backup description record' + #13#10 + 'gbak:Exiting before completion due to errors'; Anahtar: 'ERR_YEDEK_BOZUK'; Kaynak: 'olculdu'),
    (Ham: 'gbak: ERROR:I/O error during "CreateFile (open)" operation for file "C:\X\K.FDB"'; Anahtar: 'ERR_YEDEK_KAYNAK_YOK'; Kaynak: 'olculdu'),
    (Ham: 'gbak: ERROR:I/O error during "CreateFile (create)" operation for file "C:\X\K.FDB"'; Anahtar: 'ERR_YEDEK_HEDEF_YAZILAMADI'; Kaynak: 'olculdu'),
    (Ham: 'gbak: ERROR:database C:\X\K.FDB already exists.  To replace it, use the -REP switch'; Anahtar: 'ERR_YEDEK_HEDEF_VAR'; Kaynak: 'belge'),
    (Ham: 'gbak: ERROR:Your user name and password are not defined. Ask your database administrator to set up a Firebird login.'; Anahtar: 'ERR_SIFRE'; Kaynak: 'belge'),
    (Ham: 'gbak: ERROR:Incorrect user name or password'; Anahtar: 'ERR_SIFRE'; Kaynak: 'bellek'),
    (Ham: 'gbak: ERROR:Error occurred during login, please check server firebird.log for details'; Anahtar: 'ERR_SIFRE'; Kaynak: 'belge'),
    (Ham: 'gbak: ERROR:Unable to complete network request to host "sunucu".' + #13#10 + 'gbak: ERROR:-Failed to establish a connection.'; Anahtar: 'ERR_SUNUCU'; Kaynak: 'belge'),
    (Ham: 'gbak: ERROR:Unable to complete network request to host "sunucu".'; Anahtar: 'ERR_SUNUCU'; Kaynak: 'belge'),
    (Ham: 'gbak: ERROR:Error reading data from the connection.'; Anahtar: 'ERR_KOPTU'; Kaynak: 'belge'),
    (Ham: 'gbak: ERROR:Error writing data to the connection.'; Anahtar: 'ERR_KOPTU'; Kaynak: 'belge'),
    (Ham: 'gbak: ERROR:expected backup version 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11 or 12.  Found 13'; Anahtar: 'ERR_YEDEK_SURUM'; Kaynak: 'belge'),
    (Ham: 'gbak: ERROR:unsupported on-disk structure for file C:\X.FDB; found 13.0, support 11.2'; Anahtar: 'ERR_YEDEK_SURUM'; Kaynak: 'belge'),
    (Ham: 'gbak: ERROR:unexpected end of file on backup file'; Anahtar: 'ERR_YEDEK_BOZUK'; Kaynak: 'belge'),
    (Ham: 'gbak: ERROR:I/O error during "WriteFile" operation for file "C:\X\Y.FBK"'; Anahtar: 'ERR_YEDEK_DISK'; Kaynak: 'bellek'),
    (Ham: 'gbak: ERROR:Unable to perform operation' + #13#10 + 'gbak: ERROR:    System privilege USE_GBAK_UTILITY is missing'; Anahtar: 'ERR_YEDEK_YETKI'; Kaynak: 'olculdu'),
    (Ham: 'gbak: ERROR:no permission for read/select access to TABLE MUSTERI'; Anahtar: 'ERR_YEDEK_YETKI'; Kaynak: 'belge'),
    (Ham: 'gbak: ERROR:bilinmeyen baska bir hata'; Anahtar: 'ERR_YEDEK_GENEL'; Kaynak: 'uydurma'),
    (Ham: ''; Anahtar: 'ERR_YEDEK_GENEL'; Kaynak: 'bos cikti'));
var
  Dil: string;
  Ornek: TOrnek;
  Yanlis: string;
begin
  for Dil in ['tr', 'en', 'de'] do
  begin
    DilYukle(Dil);
    Yanlis := '';
    for Ornek in ORNEKLER do
      if GbakHatasiniCevir(Ornek.Ham) <> T(Ornek.Anahtar) then
        Yanlis := Yanlis + ' [' + Ornek.Anahtar + ' <- ' + Kisalt(Ornek.Ham, 40) + ']';
    Kontrol('esleme (' + Dil + '): ' + IntToStr(Length(ORNEKLER)) + ' ornek metin dogru cumleye cevrildi' +
      IfThen(Yanlis <> '', ' YANLIS:' + Yanlis, ''), Yanlis = '');
  end;
  DilYukle('tr');
  Kontrol('esleme: cumleler ham Ingilizce metin degil ve uc dilde farkli',
    (T('ERR_YEDEK_BOZUK') <> 'ERR_YEDEK_BOZUK') and (Pos('gbak', LowerCase(T('ERR_YEDEK_BOZUK'))) = 0));
end;

{ ---------- 7. Dil anahtarlari ---------- }

procedure DilAnahtarTesti;
const
  ANAHTARLAR: array[0..39] of string = ('MENU_YEDEK', 'YEDEK_BASLIK', 'YEDEK_ISLEM_YEDEK', 'YEDEK_ISLEM_GERI',
    'YEDEK_KAYNAK_VT', 'YEDEK_HEDEF_FBK', 'YEDEK_KAYNAK_FBK', 'YEDEK_HEDEF_VT', 'YEDEK_SEC', 'YEDEK_BASLAT',
    'YEDEK_FBK_FILTRE', 'YEDEK_FDB_FILTRE', 'YEDEK_GBAK_SEC', 'YEDEK_GBAK_FILTRE', 'YEDEK_SURUYOR',
    'ONAY_YEDEK_UZERINE_YAZ', 'YEDEK_BITTI_YEDEK', 'YEDEK_BITTI_GERI', 'YEDEK_IPTAL', 'YEDEK_YARIM', 'YEDEK_UYARI',
    'YEDEK_AYRINTI_KOMUT', 'YEDEK_AYRINTI_GBAK', 'YEDEK_AYRINTI_CIKIS', 'ERR_YEDEK_YAPILAMADI', 'ERR_YEDEK_GBAK_YOK',
    'ERR_YEDEK_KAYNAK_BOS', 'ERR_YEDEK_HEDEF_BOS', 'ERR_YEDEK_HEDEF_ACIK', 'ERR_YEDEK_HEDEF_VAR', 'ERR_YEDEK_DOSYA',
    'ERR_YEDEK_KAYNAK_YOK', 'ERR_YEDEK_HEDEF_YAZILAMADI', 'ERR_YEDEK_BOZUK', 'ERR_YEDEK_SURUM', 'ERR_YEDEK_DISK',
    'ERR_YEDEK_GENEL', 'ERR_YEDEK_BASLATILAMADI', 'ERR_YEDEK_YERINE_KONAMADI', 'ERR_YEDEK_YETKI');
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
    Kontrol('dil ' + Dil + ': ' + IntToStr(Length(ANAHTARLAR)) + ' yedek anahtari var' +
      IfThen(Eksik <> '', ' (eksik:' + Eksik + ')', ''), Eksik = '');
  end;
  DilYukle('tr');
end;

procedure DosyalariArsiveTasi(const KlasorYolu: string; const Dosyalar: array of string);
var
  Dosya, Arsiv: string;
begin
  Arsiv := TPath.Combine(KlasorYolu, '_arsiv');
  ForceDirectories(Arsiv);
  for Dosya in Dosyalar do
    if FileExists(Dosya) then
      TFile.Move(Dosya, TPath.Combine(Arsiv, ChangeFileExt(ExtractFileName(Dosya), '') + '_' + FormatDateTime('hhnnsszzz', Now) + ExtractFileExt(Dosya)));
end;

var
  KucukTanim, BuyukTanim: TBaglantiTanimi;
  YedekDosya, GeriYol, Hedef, BuyukFbk, Satirlar: string;
  Gomulu: Boolean;
  Dosya: string;
  BuyukBag: TAcikBaglanti;
  N: Integer;
  Sonuc: TYedekSonucu;
  Saat: TStopwatch;
  TamSure: Int64;
begin
  Cikti := TStringList.Create;
  Uretilen := TStringList.Create;
  Bag := nil;
  try
    try
      DilYukle('tr');
      Gomulu := Ortam('FBTEST_SUNUCU', '') = '';
      YedekKlasoru := TPath.Combine(TPath.Combine(GetEnvironmentVariable('TEMP'), 'yedektest'), KLASOR_ADI);
      ForceDirectories(YedekKlasoru);
      if Gomulu then
      begin
        Klasor := YedekKlasoru;
        Damga := FormatDateTime('yyyymmdd_hhnnss', Now);
      end
      else
      begin
        Klasor := Ortam('FBTEST_KLASOR', 'C:\Temp');
        Damga := FormatDateTime('yyyymmdd_hhnnss', Now);
      end;
      Tanim := Default(TBaglantiTanimi);
      Tanim.Ad := 'yedektest';
      Tanim.Sunucu := Ortam('FBTEST_SUNUCU', '');
      Tanim.Port := StrToInt(Ortam('FBTEST_PORT', '3050'));
      Tanim.VeritabaniYolu := IncludeTrailingPathDelimiter(Klasor) + 'kaynak ' + IfThen(Gomulu, TURKCE + ' ', '') + Damga + '.fdb';
      Tanim.Kullanici := Ortam('FBTEST_KULLANICI', 'SYSDBA');
      Tanim.Sifre := Ortam('FBTEST_SIFRE', '');
      Tanim.KarakterSeti := VARSAYILAN_KARAKTER_SETI;
      GeciciVeritabaniOlustur(Tanim);
      Bag := FbBaglan(Tanim);
      Cikti.Add('--- Surum ' + Bag.Surum + ', veritabani: ' + Tanim.VeritabaniYolu + ' ---');
      Cikti.Add('--- gbak: ' + GbakYolu + ' | ' + GbakSurumu + ' | ACP=' + IntToStr(GetACP) + ' OEM=' + IntToStr(GetOEMCP) + ' ---');
      Kontrol('gbak.exe istemci klasorunde var', GbakVarMi);
      Kontrol('gbak -z surum metni dolu (' + GbakSurumu + ')', GbakSurumu <> '');

      Cikti.Add('--- Veritabani kuruluyor ---');
      SemaKur(Bag);
      KucukTanim := Tanim;

      Cikti.Add('--- 1. Tam tur ---');
      YedekDosya := TPath.Combine(YedekKlasoru, 'yedek ' + TURKCE + '.fbk');
      GeriYol := IncludeTrailingPathDelimiter(Klasor) + 'geri ' + IfThen(Gomulu, TURKCE + ' ', '') + Damga + '.fdb';
      TamTurTesti(YedekDosya, GeriYol);

      Cikti.Add('--- 2. Hedef veritabani zaten var ---');
      HedefVarTesti(YedekDosya, GeriYol);

      Cikti.Add('--- 3. Buyuk veritabani, .yarim yontemi ve iptal ---');
      N := StrToIntDef(Ortam('YEDEK_SATIR', '1000000'), 1000000);
      BuyukTanim := Tanim;
      BuyukTanim.Ad := 'buyuk';
      BuyukTanim.VeritabaniYolu := IncludeTrailingPathDelimiter(Klasor) + 'buyuk_' + Damga + '.fdb';
      GeciciVeritabaniOlustur(BuyukTanim);
      BuyukBag := FbBaglan(BuyukTanim);
      BuyukTabloKur(BuyukBag, N);
      FbBaglantiyiKes(BuyukBag);
      Uretilen.Add(BuyukTanim.VeritabaniYolu);
      BuyukFbk := TPath.Combine(YedekKlasoru, 'buyuk_' + Damga + '.fbk');
      Saat := TStopwatch.StartNew;
      Kontrol('buyuk: tam yedek basarili', YedekAl(BuyukTanim, BuyukFbk, nil, Sonuc));
      TamSure := Saat.ElapsedMilliseconds;
      Not_('buyuk veritabani: ' + MB(DosyaBoyutu(BuyukTanim.VeritabaniYolu)) + ' (sunucuda ise 0 gorunur), tam yedek ' +
        IntToStr(TamSure) + ' ms, .fbk ' + MB(DosyaBoyutu(BuyukFbk)));
      Uretilen.Add(BuyukFbk);
      Hedef := TPath.Combine(YedekKlasoru, 'hedef_' + Damga + '.fbk');
      YarimYontemiTesti(KucukTanim, BuyukTanim, Hedef, TamSure);

      Cikti.Add('--- 4. Sifre guvenligi ---');
      SifreTesti(TPath.Combine(YedekKlasoru, 'sifreli_' + Damga + '.fbk'));

      Cikti.Add('--- 5. Hatalar ---');
      HataTestleri(KucukTanim, YedekDosya);

      Cikti.Add('--- 5b. gbak metni -> cumle eslemesi ---');
      EslemeTesti;

      Cikti.Add('--- 7. Dil anahtarlari ---');
      DilAnahtarTesti;

      if Bag <> nil then
        FbBaglantiyiKes(Bag);
      Bag := nil;
      { Gomulu kipte veritabanlari ve .fbk dosyalari silinmez, _arsiv'e tasinir. }
      if Gomulu then
      begin
        DosyalariArsiveTasi(Klasor, [Tanim.VeritabaniYolu]);
        for Dosya in Uretilen do
          if FileExists(Dosya) then
            DosyalariArsiveTasi(ExtractFilePath(Dosya), [Dosya]);
      end
      else
        for Dosya in Uretilen do
          if FileExists(Dosya) then
            DosyalariArsiveTasi(YedekKlasoru, [Dosya]);
    except
      on E: Exception do
      begin
        Cikti.Add('HATA  beklenmeyen istisna: ' + E.ClassName + ': ' + E.Message);
        Inc(Hatalar);
      end;
    end;
    Cikti.Add('');
    Cikti.Add('Kontrol sayisi: ' + IntToStr(KontrolSayisi) + ', Hata sayisi: ' + IntToStr(Hatalar));
    Satirlar := Ortam('FBTEST_CIKTI', '');
    if Satirlar <> '' then
      Cikti.SaveToFile(Satirlar, TEncoding.UTF8)
    else
      Writeln(Cikti.Text);
  finally
    Uretilen.Free;
    Cikti.Free;
  end;
  ExitCode := Hatalar;
end.
