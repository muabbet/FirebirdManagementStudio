program DDLTest;

{ Asama 3a Adim 1: uDDL.ScriptUret testi (komut satiri).

  Gecici iki veritabani acilir: A (kaynak yapi kurulur) ve B (bos). Her nesne icin A'dan script
  uretilir, B'de uygulamanin kendi calistiricisiyle (KomutlaraBol + BetikCalistir) calistirilir,
  sonra B'den ayni nesne icin tekrar script uretilir ve iki cikti AYNI olmali (gidis-donus testi).
  Gercek veriye dokunulmaz; sadece bu testin kendi gecici veritabanlari kullanilir.

  Ortam degiskenleri: FBTEST_SUNUCU (bos = gomulu), FBTEST_PORT, FBTEST_KLASOR (gecici veritabanlarinin
  konacagi SUNUCUDAKI klasor; bos ise %TEMP%\ddltest), FBTEST_KULLANICI, FBTEST_SIFRE, FBTEST_CIKTI
  (sonuc dosyasi), FBTEST_SCRIPTLER (verilirse uretilen script'ler buraya yazilir).
  Gomulu kipte biten veritabanlari klasorun _arsiv alt klasorune tasinir (silinmez).
  Cikis kodu: hata sayisi (0 = hepsi gecti). }

{$APPTYPE CONSOLE}

uses
  System.SysUtils, System.Classes, System.Generics.Collections, System.IOUtils, Data.DB,
  FireDAC.Stan.Error, FireDAC.Comp.Client, FireDAC.Phys.FB,
  uDil, uBaglanti, uSorgu, uMetadata, uDDL;

type
  TNesne = record
    Tur: TNesneTuru;
    Ad: string;
  end;

var
  Cikti: TStringList;
  Hatalar: Integer;
  BagA, BagB: TAcikBaglanti;
  SurumNo: Integer;
  ScriptKlasoru: string;

function Ortam(const Ad, Varsayilan: string): string;
begin
  Result := GetEnvironmentVariable(Ad);
  if Result = '' then
    Result := Varsayilan;
end;

procedure Kontrol(const Ad: string; Sonuc: Boolean);
begin
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

{ Betigi uygulamanin kendi calistiricisiyle calistirir; basarisiz komut sayisini verir. }
function BetigiCalistir(Bag: TAcikBaglanti; const Ad, Betik: string): Integer;
var
  Kayitlar: TList<TKomutKaydi>;
  S: TSorguSonucu;
  Kayit: TKomutKaydi;
  Komutlar: TArray<string>;
begin
  Result := 0;
  Komutlar := KomutlaraBol(Betik);
  Kayitlar := TList<TKomutKaydi>.Create;
  try
    S := BetikCalistir(Bag, Komutlar, Kayitlar);
    S.Free;
    for Kayit in Kayitlar do
      if Kayit.Durum = kdHata then
      begin
        Inc(Result);
        Cikti.Add('      komut hatasi (' + Ad + '): ' + Kayit.Komut);
        Cikti.Add('      ' + Kayit.Hata + ' / ' + Kayit.Ayrinti);
      end;
    if Kayitlar.Count <> Length(Komutlar) then
    begin
      Inc(Result);
      Cikti.Add('      ' + Ad + ': ' + IntToStr(Length(Komutlar)) + ' komuttan ' + IntToStr(Kayitlar.Count) + ' tanesi calisti');
    end;
  finally
    Kayitlar.Free;
  end;
end;

procedure KaynakYapiyiKur;
begin
  Kontrol('A: domainler', BetigiCalistir(BagA, 'domain', '''
    CREATE DOMAIN D_TUTAR AS NUMERIC(12,2) DEFAULT 0 NOT NULL CHECK (VALUE >= 0);
    CREATE DOMAIN D_AD AS VARCHAR(40) CHARACTER SET UTF8;
    CREATE DOMAIN D_KOD AS CHAR(5) CHARACTER SET WIN1254 DEFAULT 'X'
    ''') = 0);
  Kontrol('A: generatorler', BetigiCalistir(BagA, 'generator', '''
    CREATE SEQUENCE GEN_SIPARIS;
    SET GENERATOR GEN_SIPARIS TO 41;
    CREATE SEQUENCE "gen kucuk"
    ''') = 0);
  if SurumNo >= 3 then
    Kontrol('A: artisli generator', BetigiCalistir(BagA, 'generator3', '''
      CREATE SEQUENCE GEN_ADIM INCREMENT BY 5
      ''') = 0);
  Kontrol('A: prosedurler', BetigiCalistir(BagA, 'prosedur', '''
    SET TERM ^ ;
    CREATE PROCEDURE P_TOPLAM (A INTEGER, B INTEGER) RETURNS (S INTEGER) AS
    BEGIN
      S = A + B;
      SUSPEND;
    END^
    CREATE PROCEDURE P_CAGIR (X INTEGER, ETIKET D_AD) RETURNS (Y INTEGER, YAZI VARCHAR(20) CHARACTER SET UTF8) AS
    DECLARE VARIABLE T INTEGER;
    BEGIN
      SELECT S FROM P_TOPLAM(:X, 10) INTO :T;
      Y = T * 2;
      YAZI = 'a;b';
      SUSPEND;
    END^
    CREATE PROCEDURE P_BOS AS
    BEGIN
      EXIT;
    END^
    CREATE PROCEDURE "p kucuk" (GIRIS NUMERIC(9,2)) RETURNS (CIKIS NUMERIC(9,2)) AS
    BEGIN
      CIKIS = GIRIS * 2; -- son yorum
      SUSPEND;
    END^
    SET TERM ; ^
    ''') = 0);
  Kontrol('A: MUSTERI', BetigiCalistir(BagA, 'MUSTERI', '''
    CREATE TABLE MUSTERI (
      ID INTEGER NOT NULL,
      AD D_AD NOT NULL,
      KOD D_KOD,
      ADRES VARCHAR(100) CHARACTER SET UTF8 COLLATE UNICODE_CI,
      NOT_ALANI BLOB SUB_TYPE TEXT CHARACTER SET UTF8,
      RESIM BLOB SUB_TYPE 0,
      "ORDER" INTEGER,
      "kucuk ad" VARCHAR(10),
      CONSTRAINT PK_MUSTERI PRIMARY KEY (ID),
      CONSTRAINT UQ_MUSTERI_AD UNIQUE (AD)
    );
    CREATE INDEX IX_MUSTERI_ADRES ON MUSTERI (ADRES)
    ''') = 0);
  Kontrol('A: SIPARIS', BetigiCalistir(BagA, 'SIPARIS', '''
    CREATE TABLE SIPARIS (
      SIPARIS_NO INTEGER NOT NULL,
      SATIR_NO INTEGER NOT NULL,
      MUSTERI_ID INTEGER NOT NULL,
      TUTAR D_TUTAR,
      MIKTAR INTEGER DEFAULT 1 NOT NULL,
      BIRIM CHAR(3) DEFAULT 'ADT',
      TARIH DATE DEFAULT CURRENT_DATE,
      KAYIT TIMESTAMP DEFAULT 'NOW',
      KULLANICI VARCHAR(31) DEFAULT CURRENT_USER,
      TOPLAM COMPUTED BY (MIKTAR * 2),
      DURUM SMALLINT DEFAULT -1,
      CONSTRAINT PK_SIPARIS PRIMARY KEY (SIPARIS_NO, SATIR_NO),
      CONSTRAINT FK_SIPARIS_MUSTERI FOREIGN KEY (MUSTERI_ID) REFERENCES MUSTERI (ID)
        ON DELETE CASCADE ON UPDATE CASCADE,
      CONSTRAINT CK_SIPARIS_TUTAR CHECK (TUTAR < 1000000),
      CHECK (MIKTAR > 0)
    );
    CREATE UNIQUE DESCENDING INDEX IX_SIPARIS_MUSTERI ON SIPARIS (MUSTERI_ID, TARIH);
    CREATE INDEX IX_SIPARIS_BIRIM ON SIPARIS COMPUTED BY (UPPER(BIRIM));
    CREATE INDEX IX_SIPARIS_PASIF ON SIPARIS (KAYIT);
    ALTER INDEX IX_SIPARIS_PASIF INACTIVE
    ''') = 0);
  Kontrol('A: SIPARIS tetikleyicileri', BetigiCalistir(BagA, 'tetikleyici', '''
    SET TERM ^ ;
    CREATE TRIGGER TR_SIPARIS_BI FOR SIPARIS ACTIVE BEFORE INSERT POSITION 0 AS
    BEGIN
      IF (NEW.SIPARIS_NO IS NULL) THEN
        NEW.SIPARIS_NO = GEN_ID(GEN_SIPARIS, 1);
    END^
    CREATE TRIGGER TR_SIPARIS_BIU FOR SIPARIS ACTIVE BEFORE INSERT OR UPDATE POSITION 5 AS
    DECLARE VARIABLE X INTEGER;
    BEGIN
      X = 1;
      NEW.KAYIT = CURRENT_TIMESTAMP;
    END^
    CREATE TRIGGER TR_SIPARIS_AIUD FOR SIPARIS INACTIVE AFTER INSERT OR UPDATE OR DELETE POSITION 10 AS
    BEGIN
      /* denetim burada yapilacak */
      EXIT;
    END^
    SET TERM ; ^
    ''') = 0);
  Kontrol('A: V_SIPARIS_OZET', BetigiCalistir(BagA, 'view', '''
    CREATE VIEW V_SIPARIS_OZET (MUSTERI_AD, TOPLAM_TUTAR) AS
    SELECT M.AD, SUM(S.TUTAR) FROM MUSTERI M JOIN SIPARIS S ON S.MUSTERI_ID = M.ID GROUP BY M.AD
    ''') = 0);
  Kontrol('A: TIPLER', BetigiCalistir(BagA, 'TIPLER', '''
    CREATE TABLE TIPLER (
      T1 SMALLINT, T2 INTEGER, T3 BIGINT, T4 FLOAT, T5 DOUBLE PRECISION,
      T6 DECIMAL(9,2), T7 NUMERIC(4,0), T8 NUMERIC(15,3), T9 DATE, T10 TIME, T11 TIMESTAMP,
      T12 CHAR(10), T13 VARCHAR(10), T14 BLOB SUB_TYPE 1 SEGMENT SIZE 200, T15 BLOB SUB_TYPE 0,
      T16 CHAR(8) CHARACTER SET OCTETS
    )
    ''') = 0);
  if SurumNo >= 3 then
  begin
    Kontrol('A: KIMLIKLI (identity, boolean)', BetigiCalistir(BagA, 'KIMLIKLI', '''
      CREATE TABLE KIMLIKLI (
        ID INTEGER GENERATED BY DEFAULT AS IDENTITY,
        B BIGINT GENERATED ALWAYS AS IDENTITY (START WITH 10 INCREMENT BY 5),
        AD VARCHAR(10),
        AKTIF BOOLEAN DEFAULT TRUE NOT NULL
      )
      ''') = 0);
  end;
  if SurumNo >= 4 then
    Kontrol('A: TIPLER4 (INT128, DECFLOAT, TZ)', BetigiCalistir(BagA, 'TIPLER4', '''
      CREATE TABLE TIPLER4 (
        Q1 INT128, Q2 NUMERIC(30,5), Q3 DECFLOAT(16), Q4 DECFLOAT(34),
        Q5 TIME WITH TIME ZONE, Q6 TIMESTAMP WITH TIME ZONE
      )
      ''') = 0);
end;

function NesneListesi: TArray<TNesne>;
var
  Liste: TList<TNesne>;

  procedure Ekle(Tur: TNesneTuru; const Ad: string);
  var
    N: TNesne;
  begin
    N.Tur := Tur;
    N.Ad := Ad;
    Liste.Add(N);
  end;

begin
  Liste := TList<TNesne>.Create;
  try
    Ekle(ntGenerator, 'GEN_SIPARIS');
    Ekle(ntGenerator, 'gen kucuk');
    if SurumNo >= 3 then
      Ekle(ntGenerator, 'GEN_ADIM');
    Ekle(ntProsedur, 'P_TOPLAM');
    Ekle(ntProsedur, 'P_CAGIR');
    Ekle(ntProsedur, 'P_BOS');
    Ekle(ntProsedur, 'p kucuk');
    Ekle(ntTablo, 'MUSTERI');
    Ekle(ntTablo, 'SIPARIS');
    Ekle(ntTablo, 'TIPLER');
    if SurumNo >= 3 then
      Ekle(ntTablo, 'KIMLIKLI');
    if SurumNo >= 4 then
      Ekle(ntTablo, 'TIPLER4');
    Ekle(ntView, 'V_SIPARIS_OZET');
    Result := Liste.ToArray;
  finally
    Liste.Free;
  end;
end;

function TurAdi(Tur: TNesneTuru): string;
begin
  case Tur of
    ntTablo: Result := 'tablo';
    ntView: Result := 'view';
    ntProsedur: Result := 'prosedur';
  else
    Result := 'generator';
  end;
end;

procedure ScriptYaz(const Dosya, Metin: string);
begin
  if ScriptKlasoru <> '' then
    TFile.WriteAllText(TPath.Combine(ScriptKlasoru, Dosya), Metin, TEncoding.UTF8);
end;

function Icerir(const Metin, Parca: string): Boolean;
begin
  Result := Pos(Parca, Metin) > 0;
end;

procedure GidisDonusTesti;
var
  Nesneler: TArray<TNesne>;
  Nesne: TNesne;
  Ilk, Ikinci: TArray<string>;
  i: Integer;
begin
  Nesneler := NesneListesi;
  SetLength(Ilk, Length(Nesneler));
  SetLength(Ikinci, Length(Nesneler));
  { B'ye domainler elle konur (Adim 1'de domain script'i yok); gerisi uretilen script'lerle kurulur. }
  Kontrol('B: domainler', BetigiCalistir(BagB, 'domain', '''
    CREATE DOMAIN D_TUTAR AS NUMERIC(12,2) DEFAULT 0 NOT NULL CHECK (VALUE >= 0);
    CREATE DOMAIN D_AD AS VARCHAR(40) CHARACTER SET UTF8;
    CREATE DOMAIN D_KOD AS CHAR(5) CHARACTER SET WIN1254 DEFAULT 'X'
    ''') = 0);
  for i := 0 to High(Nesneler) do
  begin
    Nesne := Nesneler[i];
    Ilk[i] := ScriptUret(BagA, Nesne.Tur, Nesne.Ad);
    ScriptYaz(TurAdi(Nesne.Tur) + '_' + StringReplace(Nesne.Ad, ' ', '_', [rfReplaceAll]) + '_A.sql', Ilk[i]);
    Kontrol('script uretildi: ' + TurAdi(Nesne.Tur) + ' ' + Nesne.Ad, Ilk[i] <> '');
    Kontrol('B''de calisti: ' + TurAdi(Nesne.Tur) + ' ' + Nesne.Ad, BetigiCalistir(BagB, Nesne.Ad, Ilk[i]) = 0);
  end;
  for i := 0 to High(Nesneler) do
  begin
    Nesne := Nesneler[i];
    Ikinci[i] := ScriptUret(BagB, Nesne.Tur, Nesne.Ad);
    ScriptYaz(TurAdi(Nesne.Tur) + '_' + StringReplace(Nesne.Ad, ' ', '_', [rfReplaceAll]) + '_B.sql', Ikinci[i]);
    Kontrol('gidis-donus ayni: ' + TurAdi(Nesne.Tur) + ' ' + Nesne.Ad, Ilk[i] = Ikinci[i]);
    if Ilk[i] <> Ikinci[i] then
    begin
      Cikti.Add('----- A (ilk) -----');
      Cikti.Add(Ilk[i]);
      Cikti.Add('----- B (gidis-donus) -----');
      Cikti.Add(Ikinci[i]);
      Cikti.Add('-----');
    end;
  end;
  Cikti.Add('--- Uretilen script''ler (A) ---');
  for i := 0 to High(Nesneler) do
  begin
    Cikti.Add('=== ' + TurAdi(Nesneler[i].Tur) + ' ' + Nesneler[i].Ad + ' ===');
    Cikti.Add(Ilk[i]);
  end;

  { Icerik kontrolleri: istenen her ozellik script'te gercekten var mi? }
  for i := 0 to High(Nesneler) do
    if Nesneler[i].Ad = 'SIPARIS' then
    begin
      Kontrol('SIPARIS: bilesik PK', Icerir(Ilk[i], 'PRIMARY KEY (SIPARIS_NO, SATIR_NO)'));
      Kontrol('SIPARIS: FK ON DELETE CASCADE', Icerir(Ilk[i], 'ON DELETE CASCADE'));
      Kontrol('SIPARIS: FK ON UPDATE CASCADE', Icerir(Ilk[i], 'ON UPDATE CASCADE'));
      Kontrol('SIPARIS: domain kolon', Icerir(Ilk[i], 'TUTAR D_TUTAR'));
      Kontrol('SIPARIS: computed kolon', Icerir(Ilk[i], 'COMPUTED BY (MIKTAR * 2)'));
      Kontrol('SIPARIS: default sayi', Icerir(Ilk[i], 'DEFAULT 1 NOT NULL'));
      Kontrol('SIPARIS: default metin', Icerir(Ilk[i], 'DEFAULT ''ADT'''));
      Kontrol('SIPARIS: default negatif sayi', Icerir(Ilk[i], 'DEFAULT -1'));
      Kontrol('SIPARIS: adli CHECK', Icerir(Ilk[i], 'CONSTRAINT CK_SIPARIS_TUTAR CHECK'));
      Kontrol('SIPARIS: adsiz CHECK', Icerir(Ilk[i], ' CHECK (MIKTAR > 0)'));
      Kontrol('SIPARIS: benzersiz azalan indeks', Icerir(Ilk[i], 'CREATE UNIQUE DESCENDING INDEX IX_SIPARIS_MUSTERI'));
      Kontrol('SIPARIS: ifade indeksi', Icerir(Ilk[i], 'COMPUTED BY (UPPER(BIRIM))'));
      Kontrol('SIPARIS: pasif indeks', Icerir(Ilk[i], 'ALTER INDEX IX_SIPARIS_PASIF INACTIVE'));
      Kontrol('SIPARIS: BEFORE INSERT trigger', Icerir(Ilk[i], 'BEFORE INSERT POSITION 0'));
      Kontrol('SIPARIS: BEFORE INSERT OR UPDATE trigger', Icerir(Ilk[i], 'BEFORE INSERT OR UPDATE POSITION 5'));
      Kontrol('SIPARIS: AFTER INSERT OR UPDATE OR DELETE trigger, pasif',
        Icerir(Ilk[i], 'INACTIVE' + sLineBreak + 'AFTER INSERT OR UPDATE OR DELETE POSITION 10'));
      Kontrol('SIPARIS: SET TERM sarmalayicisi', Icerir(Ilk[i], 'SET TERM ^ ;') and Icerir(Ilk[i], 'SET TERM ; ^'));
      Kontrol('SIPARIS: sistem adli kisit (INTEG_) yazilmadi', not Icerir(Ilk[i], 'INTEG_'));
    end
    else if Nesneler[i].Ad = 'MUSTERI' then
    begin
      Kontrol('MUSTERI: COLLATE', Icerir(Ilk[i], 'COLLATE UNICODE_CI'));
      Kontrol('MUSTERI: kucuk harfli ad tirnaklandi', Icerir(Ilk[i], '"kucuk ad"'));
      Kontrol('MUSTERI: anahtar kelime ad tirnaklandi', Icerir(Ilk[i], '"ORDER"'));
      Kontrol('MUSTERI: normal ad tirnaksiz', Icerir(Ilk[i], 'CONSTRAINT PK_MUSTERI PRIMARY KEY (ID)'));
      Kontrol('MUSTERI: domain', Icerir(Ilk[i], 'AD D_AD NOT NULL'));
      Kontrol('MUSTERI: UNIQUE', Icerir(Ilk[i], 'CONSTRAINT UQ_MUSTERI_AD UNIQUE (AD)'));
    end
    else if Nesneler[i].Ad = 'P_CAGIR' then
    begin
      Kontrol('P_CAGIR: SET TERM', Icerir(Ilk[i], 'SET TERM ^ ;') and Icerir(Ilk[i], 'END^'));
      Kontrol('P_CAGIR: giris ve cikis parametreleri', Icerir(Ilk[i], 'ETIKET D_AD') and Icerir(Ilk[i], 'RETURNS ('));
    end
    else if Nesneler[i].Ad = 'p kucuk' then
      Kontrol('p kucuk: son satir yorumu bitiriciyi yutmaz', Icerir(Ilk[i], '-- son yorum' + sLineBreak + 'END^') or
        Icerir(Ilk[i], 'END^'));
end;

procedure KarsilastirmaVeHataTestleri;
var
  Mesaj: string;
begin
  Mesaj := '';
  try
    ScriptUret(BagA, ntTablo, 'YOK_BOYLE_TABLO');
  except
    on E: EMetadataHatasi do
      Mesaj := E.Message;
  end;
  Kontrol('olmayan tablo: anlasilir hata cumlesi', Mesaj <> '');
  Cikti.Add('      mesaj: ' + Mesaj);
  Mesaj := '';
  try
    ScriptUret(BagA, ntView, 'MUSTERI');
  except
    on E: EMetadataHatasi do
      Mesaj := E.Message;
  end;
  Kontrol('tablo adi view olarak istenince hata cumlesi', Mesaj <> '');
  Mesaj := '';
  try
    ScriptUret(BagA, ntProsedur, 'YOK_PROSEDUR');
  except
    on E: EMetadataHatasi do
      Mesaj := E.Message;
  end;
  Kontrol('olmayan prosedur: hata cumlesi', Mesaj <> '');
  Mesaj := '';
  try
    ScriptUret(BagA, ntGenerator, 'YOK_GEN');
  except
    on E: EMetadataHatasi do
      Mesaj := E.Message;
  end;
  Kontrol('olmayan generator: hata cumlesi', Mesaj <> '');
  { Generator degeri gidis-donusle korunur }
  Kontrol('generator degeri: B''de de 41', Pos('SET GENERATOR GEN_SIPARIS TO 41', ScriptUret(BagB, ntGenerator, 'GEN_SIPARIS')) > 0);
end;

procedure DosyalariArsiveTasi(const Klasor: string; const Dosyalar: array of string);
var
  Dosya, Arsiv: string;
begin
  Arsiv := TPath.Combine(Klasor, '_arsiv');
  ForceDirectories(Arsiv);
  for Dosya in Dosyalar do
    if FileExists(Dosya) then
      TFile.Move(Dosya, TPath.Combine(Arsiv, ExtractFileName(Dosya)));
end;

var
  TanimA, TanimB: TBaglantiTanimi;
  Klasor, Damga, Dosya: string;
  Gomulu: Boolean;
begin
  Cikti := TStringList.Create;
  BagA := nil;
  BagB := nil;
  try
    try
      DilYukle('tr');
      Gomulu := Ortam('FBTEST_SUNUCU', '') = '';
      Klasor := Ortam('FBTEST_KLASOR', TPath.Combine(GetEnvironmentVariable('TEMP'), 'ddltest'));
      if Gomulu then
        ForceDirectories(Klasor);
      ScriptKlasoru := Ortam('FBTEST_SCRIPTLER', '');
      if ScriptKlasoru <> '' then
        ForceDirectories(ScriptKlasoru);
      Damga := FormatDateTime('yyyymmdd_hhnnss', Now);
      TanimA.Ad := 'ddltest_a';
      TanimA.Sunucu := Ortam('FBTEST_SUNUCU', '');
      TanimA.Port := StrToInt(Ortam('FBTEST_PORT', '3050'));
      TanimA.VeritabaniYolu := IncludeTrailingPathDelimiter(Klasor) + 'ddltest_a_' + Damga + '.fdb';
      TanimA.Kullanici := Ortam('FBTEST_KULLANICI', 'SYSDBA');
      TanimA.Sifre := Ortam('FBTEST_SIFRE', '');
      TanimA.KarakterSeti := VARSAYILAN_KARAKTER_SETI;
      TanimB := TanimA;
      TanimB.Ad := 'ddltest_b';
      TanimB.VeritabaniYolu := IncludeTrailingPathDelimiter(Klasor) + 'ddltest_b_' + Damga + '.fdb';
      GeciciVeritabaniOlustur(TanimA);
      GeciciVeritabaniOlustur(TanimB);
      BagA := FbBaglan(TanimA);
      BagB := FbBaglan(TanimB);
      SurumNo := StrToIntDef(Copy(BagA.Surum, 1, Pos('.', BagA.Surum) - 1), 0);
      Cikti.Add('--- Surum ' + BagA.Surum + ', A: ' + TanimA.VeritabaniYolu + ', B: ' + TanimB.VeritabaniYolu + ' ---');
      KaynakYapiyiKur;
      GidisDonusTesti;
      KarsilastirmaVeHataTestleri;
      FbBaglantiyiKes(BagA);
      FbBaglantiyiKes(BagB);
      BagA := nil;
      BagB := nil;
      if Gomulu then
        DosyalariArsiveTasi(Klasor, [TanimA.VeritabaniYolu, TanimB.VeritabaniYolu]);
    except
      on E: Exception do
      begin
        Cikti.Add('HATA  beklenmeyen istisna: ' + E.ClassName + ': ' + E.Message);
        Inc(Hatalar);
      end;
    end;
    Cikti.Add('');
    Cikti.Add('Hata sayisi: ' + IntToStr(Hatalar));
    Dosya := Ortam('FBTEST_CIKTI', '');
    if Dosya <> '' then
      Cikti.SaveToFile(Dosya, TEncoding.UTF8)
    else
      Writeln(Cikti.Text);
  finally
    Cikti.Free;
  end;
  ExitCode := Hatalar;
end.
