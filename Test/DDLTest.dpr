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
  System.SysUtils, System.Classes, System.StrUtils, System.Math, System.Generics.Collections, System.IOUtils, System.Diagnostics, Data.DB,
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
  BagA, BagB, BagC, BagD: TAcikBaglanti;
  SurumNo: Integer;
  ScriptKlasoru: string;
  { Script dosyalarinin kodlamasi (uDDL.ScriptKodlamasiOlustur; BagA ile kurulur) }
  GKodlama: TEncoding;

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
    { Sunucu doluysa veritabani SUNUCUDA olusur (FbBaglan ile ayni parametreler); bos ise gomulu motor. }
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
    TFile.WriteAllText(TPath.Combine(ScriptKlasoru, Dosya), Metin, GKodlama);
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

{ ---------- Adim 2: Metadata cikar ---------- }

type
  { Ilerleme geri cagrisi: SayiIptal kadar cagridan sonra iptal ister (0 = hic iptal etmez). }
  TOlcum = class
    Cagri: Integer;
    SayiIptal: Integer;
    SonAciklama: string;
    procedure Ilerle(const Aciklama: string; var Iptal: Boolean);
  end;

procedure TOlcum.Ilerle(const Aciklama: string; var Iptal: Boolean);
begin
  Inc(Cagri);
  SonAciklama := Aciklama;
  if (SayiIptal > 0) and (Cagri >= SayiIptal) then
    Iptal := True;
end;

(* Metindeki {u} {s} {c} {g} {i} {I} {o} {S} yer tutucularini Turkce harflere cevirir (kaynak dosya ASCII kalsin diye). *)
function Turkce(const Metin: string): string;
begin
  Result := Metin;
  Result := StringReplace(Result, '{u}', #$00FC, [rfReplaceAll]);
  Result := StringReplace(Result, '{s}', #$015F, [rfReplaceAll]);
  Result := StringReplace(Result, '{c}', #$00E7, [rfReplaceAll]);
  Result := StringReplace(Result, '{g}', #$011F, [rfReplaceAll]);
  Result := StringReplace(Result, '{i}', #$0131, [rfReplaceAll]);
  Result := StringReplace(Result, '{I}', #$0130, [rfReplaceAll]);
  Result := StringReplace(Result, '{o}', #$00F6, [rfReplaceAll]);
  Result := StringReplace(Result, '{S}', #$015E, [rfReplaceAll]);
end;

function Say(const Metin, Parca: string): Integer;
var
  Sira: Integer;
begin
  Result := 0;
  Sira := Pos(Parca, Metin);
  while Sira > 0 do
  begin
    Inc(Result);
    Sira := PosEx(Parca, Metin, Sira + Length(Parca));
  end;
end;

procedure KarmasikYapiyiKur(Bag: TAcikBaglanti);
begin
  Kontrol('C: roller, exception, generator, domain', BetigiCalistir(Bag, 'temel', Turkce('''
    CREATE ROLE ROL_YONETICI;
    CREATE ROLE ROL_OKUR;
    CREATE EXCEPTION E_STOK 'Stok yetersiz';
    CREATE EXCEPTION E_TR 'Kay{i}t bulunamad{i} ''x'' ({c}{g}{s}{o}{u})';
    CREATE SEQUENCE GEN_A;
    SET GENERATOR GEN_A TO 100;
    CREATE SEQUENCE GEN_B;
    CREATE DOMAIN D_AD AS VARCHAR(40) CHARACTER SET UTF8 NOT NULL;
    CREATE DOMAIN D_TUTAR AS NUMERIC(12,2) DEFAULT 0 CHECK (VALUE >= 0);
    CREATE DOMAIN D_DURUM AS CHAR(1) DEFAULT 'A' CHECK (VALUE IN ('A', 'P'))
    ''')) = 0);
  Kontrol('C: tablolar (FK zinciri, bilesik PK/FK)', BetigiCalistir(Bag, 'tablolar', Turkce('''
    CREATE TABLE ULKE (ID INTEGER NOT NULL PRIMARY KEY, AD D_AD);
    CREATE TABLE SEHIR (
      ULKE_ID INTEGER NOT NULL, SEHIR_ID INTEGER NOT NULL, AD D_AD,
      CONSTRAINT PK_SEHIR PRIMARY KEY (ULKE_ID, SEHIR_ID),
      CONSTRAINT FK_SEHIR_ULKE FOREIGN KEY (ULKE_ID) REFERENCES ULKE (ID) ON DELETE CASCADE
    );
    CREATE TABLE MUSTERI (
      ID INTEGER NOT NULL, ULKE_ID INTEGER, SEHIR_ID INTEGER, AD D_AD, DURUM D_DURUM, BAKIYE D_TUTAR,
      NOTU BLOB SUB_TYPE TEXT,
      CONSTRAINT PK_MUSTERI PRIMARY KEY (ID),
      CONSTRAINT FK_MUSTERI_SEHIR FOREIGN KEY (ULKE_ID, SEHIR_ID) REFERENCES SEHIR (ULKE_ID, SEHIR_ID),
      CONSTRAINT UQ_MUSTERI_AD UNIQUE (AD),
      CHECK (ID > 0)
    );
    CREATE TABLE "K{u}{c}{u}k Tablo" ("{S}ehir Ad{i}" VARCHAR(20), "{I}l{c}e" INTEGER);
    CREATE INDEX IX_MUSTERI_BAKIYE ON MUSTERI (BAKIYE);
    CREATE INDEX IX_MUSTERI_ADUST ON MUSTERI COMPUTED BY (UPPER(AD))
    ''')) = 0);
  Kontrol('C: view zinciri (alfabetik sira bagimlilik sirasinin tersi)', BetigiCalistir(Bag, 'viewlar', '''
    CREATE VIEW V_Z (ID, AD) AS SELECT ID, AD FROM MUSTERI;
    CREATE VIEW V_Y (ID, AD) AS SELECT ID, AD FROM V_Z WHERE ID > 10;
    CREATE VIEW V_X (ID) AS SELECT ID FROM V_Y
    ''') = 0);
  Kontrol('C: birbirini cagiran prosedurler, view ve exception kullanan govde', BetigiCalistir(Bag, 'prosedurler', '''
    SET TERM ^ ;
    CREATE PROCEDURE P_ILK (A INTEGER) RETURNS (B INTEGER) AS
    BEGIN
      B = A + 1;
      SUSPEND;
    END^
    CREATE PROCEDURE P_IKINCI (A INTEGER) RETURNS (B INTEGER) AS
    BEGIN
      FOR SELECT B FROM P_ILK(:A) INTO :B DO
        SUSPEND;
    END^
    CREATE PROCEDURE P_UCUNCU RETURNS (X INTEGER) AS
    BEGIN
      FOR SELECT ID FROM V_Z INTO :X DO
      BEGIN
        IF (X < 0) THEN
          EXCEPTION E_STOK;
        SUSPEND;
      END
    END^
    CREATE PROCEDURE P_BOS AS
    BEGIN
      EXECUTE STATEMENT 'select 1 from rdb$database';
    END^
    SET TERM ; ^
    ''') = 0);
  Kontrol('C: procedure cagiran view', BetigiCalistir(Bag, 'proc view', '''
    CREATE VIEW V_PROC (DEGER) AS SELECT B FROM P_ILK(5)
    ''') = 0);
  Kontrol('C: tetikleyiciler (tablo, view, veritabani)', BetigiCalistir(Bag, 'tetikleyiciler', '''
    SET TERM ^ ;
    CREATE TRIGGER TR_MUSTERI_BI FOR MUSTERI ACTIVE BEFORE INSERT POSITION 0 AS
    BEGIN
      IF (NEW.ID IS NULL) THEN
        NEW.ID = GEN_ID(GEN_A, 1);
    END^
    CREATE TRIGGER TR_V_Z_BU FOR V_Z ACTIVE BEFORE UPDATE POSITION 0 AS
    BEGIN
      UPDATE MUSTERI SET AD = NEW.AD WHERE ID = OLD.ID;
    END^
    CREATE TRIGGER TR_BAGLAN INACTIVE ON CONNECT POSITION 3 AS
    BEGIN
      EXIT;
    END^
    SET TERM ; ^
    ''') = 0);
  if SurumNo >= 3 then
    Kontrol('C: gecici tablo, kimlik kolonu', BetigiCalistir(Bag, 'surum3', '''
      CREATE GLOBAL TEMPORARY TABLE GECICI (A INTEGER, B VARCHAR(10)) ON COMMIT PRESERVE ROWS;
      CREATE GLOBAL TEMPORARY TABLE GECICI2 (A INTEGER) ON COMMIT DELETE ROWS;
      CREATE TABLE KIMLIK2 (ID INTEGER GENERATED BY DEFAULT AS IDENTITY, AD VARCHAR(5))
      ''') = 0);
  Kontrol('C: yetkiler', BetigiCalistir(Bag, 'yetkiler', '''
    GRANT SELECT, INSERT ON MUSTERI TO USER ALI WITH GRANT OPTION;
    GRANT UPDATE (AD, DURUM) ON MUSTERI TO PUBLIC;
    GRANT SELECT ON V_Z TO ROLE ROL_OKUR;
    GRANT EXECUTE ON PROCEDURE P_ILK TO USER ALI;
    GRANT SELECT ON MUSTERI TO PROCEDURE P_UCUNCU;
    GRANT ROL_OKUR TO USER VELI WITH ADMIN OPTION
    ''') = 0);
  if SurumNo >= 3 then
    Kontrol('C: USAGE yetkileri (3.0+)', BetigiCalistir(Bag, 'usage', '''
      GRANT USAGE ON EXCEPTION E_STOK TO USER ALI;
      GRANT USAGE ON SEQUENCE GEN_A TO USER ALI
      ''') = 0);
  Kontrol('C: aciklamalar', BetigiCalistir(Bag, 'aciklamalar', Turkce('''
    COMMENT ON DATABASE IS 'Deneme veritabani';
    COMMENT ON TABLE MUSTERI IS 'M{u}{s}teri tablosu ({o}rnek ''tirnakli'')';
    COMMENT ON VIEW V_Z IS 'z view';
    COMMENT ON PROCEDURE P_ILK IS 'Bir artirir';
    COMMENT ON PARAMETER P_ILK.A IS 'girdi';
    COMMENT ON TRIGGER TR_MUSTERI_BI IS 'ID doldurur';
    COMMENT ON DOMAIN D_AD IS 'Ad alani';
    COMMENT ON EXCEPTION E_STOK IS 'Stok hatasi';
    COMMENT ON ROLE ROL_OKUR IS 'Okuyucu rol';
    COMMENT ON INDEX IX_MUSTERI_BAKIYE IS 'bakiye indeksi'
    ''')) = 0);
  Kontrol('C: coklu satirli aciklama', BetigiCalistir(Bag, 'coklu', 'COMMENT ON COLUMN MUSTERI.AD IS ''Ad ve soyad' +
    sLineBreak + 'ikinci satir''') = 0);
  if SurumNo >= 3 then
    Kontrol('C: generator aciklamasi', BetigiCalistir(Bag, 'gen aciklama', '''
      COMMENT ON SEQUENCE GEN_A IS 'A sayaci'
      ''') = 0)
  else
    Kontrol('C: generator aciklamasi', BetigiCalistir(Bag, 'gen aciklama', '''
      COMMENT ON GENERATOR GEN_A IS 'A sayaci'
      ''') = 0);
end;

{ Metadata'yi (TStringWriter ile) cikarir; Iptal edilirse False. }
function MetinCikar(Bag: TAcikBaglanti; const Sec: TCikarSecenekleri; Uyarilar: TStrings; Olcum: TOlcum;
  out Metin: string): Boolean;
var
  Yazici: TStringWriter;
begin
  Yazici := TStringWriter.Create;
  try
    Result := MetadataCikar(Bag, Sec, Yazici, Uyarilar, Olcum.Ilerle);
    Metin := Yazici.ToString;
  finally
    Yazici.Free;
  end;
end;

procedure SatirFarki(const Ad, Ilk, Ikinci: string);
var
  A, B: TStringList;
  i, Say: Integer;
begin
  A := TStringList.Create;
  B := TStringList.Create;
  try
    A.Text := Ilk;
    B.Text := Ikinci;
    Say := 0;
    for i := 0 to Max(A.Count, B.Count) - 1 do
      if ((i < A.Count) and (i < B.Count) and (A[i] <> B[i])) or (i >= A.Count) or (i >= B.Count) then
      begin
        Inc(Say);
        if Say <= 15 then
        begin
          if i < A.Count then
            Cikti.Add('      ' + Ad + ' satir ' + IntToStr(i + 1) + ' ilk : ' + A[i]);
          if i < B.Count then
            Cikti.Add('      ' + Ad + ' satir ' + IntToStr(i + 1) + ' ikinci: ' + B[i]);
        end;
      end;
    Cikti.Add('      ' + Ad + ': ' + IntToStr(Say) + ' satir farkli (ilk ' + IntToStr(A.Count) + ', ikinci ' +
      IntToStr(B.Count) + ' satir)');
  finally
    B.Free;
    A.Free;
  end;
end;

procedure TumVeritabaniTesti(BagC, BagD: TAcikBaglanti);
var
  Olcum: TOlcum;
  Uyarilar: TStringList;
  Sec, SecAcik: TCikarSecenekleri;
  Ilk, Ikinci, Sifreli, Yarim: string;
  Sifre: string;
  ZV, ZY, ZX: Integer;
  Dosya: string;
  Baytlar: TBytes;
  Kodlama: TEncoding;
  Yazici: TStreamWriter;
begin
  Cikti.Add('--- Adim 2: Metadata cikar (surum ' + BagC.Surum + ') ---');
  KarmasikYapiyiKur(BagC);
  Olcum := TOlcum.Create;
  Uyarilar := TStringList.Create;
  try
    Sec := Default(TCikarSecenekleri);
    Kontrol('cikarma tamamlandi (iptal yok)', MetinCikar(BagC, Sec, Uyarilar, Olcum, Ilk));
    Kontrol('ilerleme bildirimi geldi', Olcum.Cagri > 0);
    Kontrol('uyari yok', Uyarilar.Count = 0);
    if Uyarilar.Count > 0 then
      Cikti.Add('      uyari: ' + Uyarilar.Text);
    Cikti.Add('      cikti uzunlugu: ' + IntToStr(Length(Ilk)) + ' karakter, ' + IntToStr(Say(Ilk, sLineBreak)) + ' satir');

    { Sira }
    Kontrol('SET NAMES veritabaninin karakter seti (WIN1254) ilk satir', Pos('SET NAMES WIN1254;', Ilk) = 1);
    Kontrol('script karakter seti WIN1254, kod sayfasi 1254', (ScriptKarakterSeti(BagC) = 'WIN1254') and
      (GKodlama.CodePage = 1254));
    Kontrol('sira: rol < exception < generator < domain < tablo',
      (Pos('CREATE ROLE', Ilk) < Pos('CREATE EXCEPTION', Ilk)) and
      (Pos('CREATE EXCEPTION', Ilk) < Pos('CREATE SEQUENCE', Ilk)) and
      (Pos('CREATE SEQUENCE', Ilk) < Pos('CREATE DOMAIN', Ilk)) and
      (Pos('CREATE DOMAIN', Ilk) < Pos('CREATE TABLE', Ilk)));
    Kontrol('sira: tablo < prosedur basligi < view',
      (Pos('CREATE TABLE', Ilk) < Pos('CREATE PROCEDURE', Ilk)) and (Pos('CREATE PROCEDURE', Ilk) < Pos('CREATE VIEW', Ilk)));
    ZV := Pos('CREATE VIEW V_Z', Ilk);
    ZY := Pos('CREATE VIEW V_Y', Ilk);
    ZX := Pos('CREATE VIEW V_X', Ilk);
    Kontrol('view bagimlilik sirasi: V_Z < V_Y < V_X', (ZV > 0) and (ZV < ZY) and (ZY < ZX));
    Kontrol('sira: view < PK/UNIQUE < FK < CHECK < indeks < tetikleyici < govde < yetki < aciklama',
      (ZX < Pos('PRIMARY KEY', Ilk)) and (Pos('PRIMARY KEY', Ilk) < Pos('FOREIGN KEY', Ilk)) and
      (Pos('FOREIGN KEY', Ilk) < Pos('ALTER TABLE MUSTERI ADD CHECK', Ilk)) and
      (Pos('ALTER TABLE MUSTERI ADD CHECK', Ilk) < Pos('CREATE INDEX', Ilk)) and
      (Pos('CREATE INDEX', Ilk) < Pos('CREATE TRIGGER', Ilk)) and
      (Pos('CREATE TRIGGER', Ilk) < Pos('ALTER PROCEDURE', Ilk)) and
      (Pos('ALTER PROCEDURE', Ilk) < Pos('GRANT', Ilk)) and (Pos('GRANT', Ilk) < Pos('COMMENT ON', Ilk)));
    Kontrol('tablolar yalniz kolonlu (CREATE TABLE icinde PRIMARY KEY yok)',
      Pos('PRIMARY KEY', Ilk) > Pos('CREATE VIEW V_X', Ilk));
    Kontrol('prosedur iskeleti: cikis parametreli SUSPEND, parametresiz EXIT',
      (Pos('AS' + sLineBreak + 'BEGIN' + sLineBreak + '  SUSPEND;' + sLineBreak + 'END^', Ilk) > 0) and
      (Pos('AS' + sLineBreak + 'BEGIN' + sLineBreak + '  EXIT;' + sLineBreak + 'END^', Ilk) > 0));
    Kontrol('SET TERM sarmalayicilari dengeli', Say(Ilk, 'SET TERM ^ ;') = Say(Ilk, 'SET TERM ; ^'));
    Kontrol('veritabani tetikleyicisi', Pos('INACTIVE' + sLineBreak + 'ON CONNECT POSITION 3', Ilk) > 0);
    Kontrol('Turkce tablo ve kolon adlari bozulmadi', Pos(Turkce('"K{u}{c}{u}k Tablo"'), Ilk) > 0);
    Kontrol('Turkce kolon adi', Pos(Turkce('"{S}ehir Ad{i}"'), Ilk) > 0);
    Kontrol('Turkce exception mesaji ve tirnak', Pos(Turkce('''Kay{i}t bulunamad{i} ''''x'''' ({c}{g}{s}{o}{u})'''), Ilk) > 0);
    Kontrol('Turkce aciklama', Pos(Turkce('M{u}{s}teri tablosu'), Ilk) > 0);
    Kontrol('coklu satirli aciklama', Pos('Ad ve soyad' + sLineBreak + 'ikinci satir', Ilk) > 0);
    Kontrol('yetki: gruplanmis SELECT, INSERT + GRANT OPTION',
      Pos('GRANT INSERT, SELECT ON MUSTERI TO USER ALI WITH GRANT OPTION;', Ilk) > 0);
    Kontrol('yetki: kolon bazli UPDATE, PUBLIC', Pos('GRANT UPDATE (AD, DURUM) ON MUSTERI TO PUBLIC;', Ilk) > 0);
    Kontrol('yetki: rol', Pos('GRANT SELECT ON V_Z TO ROLE ROL_OKUR;', Ilk) > 0);
    Kontrol('yetki: EXECUTE', Pos('GRANT EXECUTE ON PROCEDURE P_ILK TO USER ALI;', Ilk) > 0);
    Kontrol('yetki: prosedure verilen', Pos('GRANT SELECT ON MUSTERI TO PROCEDURE P_UCUNCU;', Ilk) > 0);
    Kontrol('yetki: rol uyeligi + ADMIN OPTION', Pos('GRANT ROL_OKUR TO USER VELI WITH ADMIN OPTION;', Ilk) > 0);
    Kontrol('sistem adli kisit (INTEG_) yazilmadi', Pos('INTEG_', Ilk) = 0);
    Kontrol('sahip yetkileri (SYSDBA) yazilmadi', Pos('TO USER SYSDBA', Ilk) = 0);
    Kontrol('sistem tablosu yetkisi yazilmadi', Pos('RDB$', Ilk) = 0);
    if SurumNo >= 3 then
    begin
      Kontrol('gecici tablo (PRESERVE)', Pos('ON COMMIT PRESERVE ROWS;', Ilk) > 0);
      Kontrol('gecici tablo (DELETE)', Pos('ON COMMIT DELETE ROWS;', Ilk) > 0);
      Kontrol('kimlik kolonu', Pos('GENERATED BY DEFAULT AS IDENTITY', Ilk) > 0);
      Kontrol('USAGE yetkileri', (Pos('GRANT USAGE ON EXCEPTION E_STOK TO USER ALI;', Ilk) > 0) and
        (Pos('GRANT USAGE ON SEQUENCE GEN_A TO USER ALI;', Ilk) > 0));
    end;

    { Sifre kutusu kapaliyken sifre hic gecmemeli }
    Sifre := BagC.Tanim.Sifre;
    SecAcik := Default(TCikarSecenekleri);
    SecAcik.VeritabaniOlustur := True;
    SecAcik.BaglantiYaz := True;
    Kontrol('CREATE DATABASE kapaliyken yazilmadi', (Pos('CREATE DATABASE', Ilk) = 0) and (Pos('CONNECT ''', Ilk) = 0));
    Kontrol('sifre kapaliyken PASSWORD sozcugu yok', Pos('PASSWORD', Ilk) = 0);
    if Sifre <> '' then
      Kontrol('sifre kapaliyken sifre metni hic gecmiyor', Pos(Sifre, Ilk) = 0)
    else
      Cikti.Add('ATLANDI  sifre bos oldugu icin metin aramasi yapilamadi');
    Kontrol('CREATE DATABASE + CONNECT acikken sifresiz uretilir', MetinCikar(BagC, SecAcik, Uyarilar, Olcum, Ikinci));
    ScriptYaz('tumveritabani_CREATEDB.sql', Ikinci);
    Kontrol('CREATE DATABASE satiri var', Pos('CREATE DATABASE ''' , Ikinci) > 0);
    Kontrol('CONNECT satiri var', Pos('CONNECT ''', Ikinci) > 0);
    Kontrol('PAGE_SIZE ve DEFAULT CHARACTER SET yazildi',
      (Pos(' PAGE_SIZE ', Ikinci) > 0) and (Pos(' DEFAULT CHARACTER SET WIN1254;', Ikinci) > 0));
    Kontrol('sifre kutusu kapaliyken acik secenekte de PASSWORD yok', Pos('PASSWORD', Ikinci) = 0);
    SecAcik.SifreYaz := True;
    MetinCikar(BagC, SecAcik, Uyarilar, Olcum, Sifreli);
    if Sifre <> '' then
      Kontrol('sifre kutusu acikken iki yerde sifre', Say(Sifreli, ' PASSWORD ''' + Sifre + '''') = 2)
    else
      Kontrol('sifre kutusu acikken iki yerde PASSWORD', Say(Sifreli, ' PASSWORD ''''') = 2);
    SecAcik.VeritabaniOlustur := False;
    SecAcik.BaglantiYaz := False;
    MetinCikar(BagC, SecAcik, Uyarilar, Olcum, Sifreli);
    Kontrol('CREATE DATABASE ve CONNECT kapaliyken sifre kutusu bir sey yazmaz', Pos('PASSWORD', Sifreli) = 0);

    { Iptal }
    Olcum.Cagri := 0;
    Olcum.SayiIptal := 8;
    Sec := Default(TCikarSecenekleri);
    Kontrol('iptal: False doner', not MetinCikar(BagC, Sec, Uyarilar, Olcum, Yarim));
    Kontrol('iptal: yazilan kisim duruyor ve yarim', (Length(Yarim) > 0) and (Length(Yarim) < Length(Ilk)));
    Kontrol('iptal: sona ulasmadi', Pos('COMMENT ON', Yarim) = 0);
    Olcum.SayiIptal := 0;

    { Dosyaya akis: UTF-8, BOM yok, icerik ayni }
    Dosya := TPath.Combine(TPath.GetTempPath, 'ddltest_cikti.sql');
    Kodlama := ScriptKodlamasiOlustur(BagC);
    try
      Yazici := TStreamWriter.Create(Dosya, False, Kodlama);
      try
        Kontrol('dosyaya akis: tamamlandi', MetadataCikar(BagC, Sec, Yazici, Uyarilar, Olcum.Ilerle));
      finally
        Yazici.Free;
      end;
    finally
      Kodlama.Free;
    end;
    Baytlar := TFile.ReadAllBytes(Dosya);
    Kontrol('dosya BOM''suz', (Length(Baytlar) > 3) and not ((Baytlar[0] = $EF) and (Baytlar[1] = $BB) and (Baytlar[2] = $BF)));
    Kontrol('dosya Turkce harfleri tek baytla yazdi (WIN1254: i-noktasiz = 0xFD)', Say(TEncoding.GetEncoding(1254).GetString(Baytlar), #$0131) > 0);
    Kontrol('dosya icerigi metinle ayni (Turkce karakterler WIN1254 gidis-donus)',
      TFile.ReadAllText(Dosya, TEncoding.GetEncoding(1254)) = Ilk);
    { Gidis-donus: cikan script bos veritabaninda calismali ve ayni yapi yeniden cikarilabilmeli }
    Kontrol('D (bos): cikan script hatasiz calisti', BetigiCalistir(BagD, 'cikan script', Ilk) = 0);
    Kontrol('D: ayni yapi tekrar cikarildi', MetinCikar(BagD, Sec, Uyarilar, Olcum, Ikinci));
    Kontrol('gidis-donus: iki cikti satir satir ayni', Ilk = Ikinci);
    if Ilk <> Ikinci then
      SatirFarki('gidis-donus', Ilk, Ikinci);
    ScriptYaz('tumveritabani_C.sql', Ilk);
    ScriptYaz('tumveritabani_D.sql', Ikinci);
  finally
    Uyarilar.Free;
    Olcum.Free;
  end;
end;

{ Gercek bir veritabaninin KOPYASI uzerinde (FBTEST_KOPYA, gomulu kip): sadece metadata cikarir ve dosyaya yazar;
  uyarilari ve suresini bildirir. Kopya dosyaya yalnizca okuma yapilir. Script'in bos veritabaninda calismasi
  isql ile ayrica denenir (hata sayisi icin). }
procedure KopyaTesti(const Yol: string);
var
  Tanim: TBaglantiTanimi;
  Bag: TAcikBaglanti;
  Sec: TCikarSecenekleri;
  Olcum: TOlcum;
  Uyarilar: TStringList;
  Metin: string;
  Saat: TStopwatch;
  Uyari: string;
begin
  Tanim := Default(TBaglantiTanimi);
  Tanim.Ad := 'ddltest_kopya';
  Tanim.VeritabaniYolu := Yol;
  Tanim.Kullanici := 'SYSDBA';
  Tanim.KarakterSeti := VARSAYILAN_KARAKTER_SETI;
  Bag := FbBaglan(Tanim);
  Olcum := TOlcum.Create;
  Uyarilar := TStringList.Create;
  try
    Cikti.Add('--- Gercek veritabani kopyasi: ' + Yol + ' (surum ' + Bag.Surum + ') ---');
    Sec := Default(TCikarSecenekleri);
    Sec.VeritabaniOlustur := True;
    Saat := TStopwatch.StartNew;
    Kontrol('kopya: metadata cikarildi', MetinCikar(Bag, Sec, Uyarilar, Olcum, Metin));
    Cikti.Add('      sure: ' + IntToStr(Saat.ElapsedMilliseconds) + ' ms, ' + IntToStr(Length(Metin)) + ' karakter, ' +
      IntToStr(Say(Metin, sLineBreak)) + ' satir, ilerleme cagrisi ' + IntToStr(Olcum.Cagri));
    Cikti.Add('      uyari sayisi: ' + IntToStr(Uyarilar.Count));
    for Uyari in Uyarilar do
      Cikti.Add('      uyari: ' + Uyari);
    ScriptYaz('kopya.sql', Metin);
  finally
    Uyarilar.Free;
    Olcum.Free;
    FbBaglantiyiKes(Bag);
  end;
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
  TanimA, TanimB, TanimC, TanimD: TBaglantiTanimi;
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
      GKodlama := ScriptKodlamasiOlustur(BagA);
      BagB := FbBaglan(TanimB);
      SurumNo := StrToIntDef(Copy(BagA.Surum, 1, Pos('.', BagA.Surum) - 1), 0);
      Cikti.Add('--- Surum ' + BagA.Surum + ', A: ' + TanimA.VeritabaniYolu + ', B: ' + TanimB.VeritabaniYolu + ' ---');
      KaynakYapiyiKur;
      GidisDonusTesti;
      KarsilastirmaVeHataTestleri;
      { Adim 2: karmasik yapi (C) ve bos veritabani (D). Sifre, 'sifre kapaliyken metinde gecmiyor' denetimi icin dolu olur. }
      TanimC := TanimA;
      TanimC.Ad := 'ddltest_c';
      TanimC.VeritabaniYolu := IncludeTrailingPathDelimiter(Klasor) + 'ddltest_c_' + Damga + '.fdb';
      if (TanimC.Sifre = '') and Gomulu then
        TanimC.Sifre := 'GizliSifre123';
      TanimD := TanimC;
      TanimD.Ad := 'ddltest_d';
      TanimD.VeritabaniYolu := IncludeTrailingPathDelimiter(Klasor) + 'ddltest_d_' + Damga + '.fdb';
      GeciciVeritabaniOlustur(TanimC);
      GeciciVeritabaniOlustur(TanimD);
      BagC := FbBaglan(TanimC);
      BagD := FbBaglan(TanimD);
      TumVeritabaniTesti(BagC, BagD);
      if Ortam('FBTEST_KOPYA', '') <> '' then
        KopyaTesti(Ortam('FBTEST_KOPYA', ''));
      FbBaglantiyiKes(BagA);
      FbBaglantiyiKes(BagB);
      FbBaglantiyiKes(BagC);
      FbBaglantiyiKes(BagD);
      BagA := nil;
      BagB := nil;
      BagC := nil;
      BagD := nil;
      if Gomulu then
        DosyalariArsiveTasi(Klasor, [TanimA.VeritabaniYolu, TanimB.VeritabaniYolu, TanimC.VeritabaniYolu,
          TanimD.VeritabaniYolu]);
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
