program DokumanTest;

{ Asama 7t: uDokuman (veritabani dokumani HTML) testi (komut satiri).

  Gecici bir veritabani acilir (varsayilan: gomulu Firebird); icine domain, iki tablo (PK, FK, CHECK, UNIQUE, index,
  COMMENT ON), view, prosedur, tetikleyici, generator ve exception konur. Dokuman uretilir ve icerigi kontrol edilir.
  Ortam degiskenleri: FBTEST_SUNUCU (bos = gomulu), FBTEST_PORT, FBTEST_KLASOR, FBTEST_KULLANICI, FBTEST_SIFRE,
  FBTEST_CIKTI (sonuc dosyasi). Gomulu kipte biten veritabani ve HTML dosyasi _arsiv klasorune tasinir (silinmez).
  Cikis kodu: hata sayisi (0 = hepsi gecti). }

{$APPTYPE CONSOLE}

uses
  Winapi.Windows,
  System.SysUtils, System.Classes, System.StrUtils, System.IOUtils, Data.DB,
  FireDAC.Stan.Error, FireDAC.Comp.Client, FireDAC.Phys.FB,
  uDil, uBaglanti, uSorgu, uDokuman;

var
  Cikti: TStringList;
  Hatalar, KontrolSayisi: Integer;
  Bag: TAcikBaglanti;
  Klasor, HtmlKlasoru, HtmlDosyasi: string;
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

procedure NesneleriKur;
begin
  Komut('CREATE DOMAIN D_YUZDE AS INTEGER DEFAULT 0 CHECK (VALUE BETWEEN 0 AND 100)');
  Komut('CREATE TABLE T_MUSTERI (ID INTEGER NOT NULL, AD VARCHAR(50) NOT NULL, ORAN D_YUZDE, ' +
    'KOD CHAR(5), CONSTRAINT PK_MUSTERI PRIMARY KEY (ID), CONSTRAINT UQ_KOD UNIQUE (KOD))');
  Komut('CREATE TABLE T_SIPARIS (ID INTEGER NOT NULL PRIMARY KEY, MUSTERI_ID INTEGER, TUTAR NUMERIC(12,2) DEFAULT 0, ' +
    'CONSTRAINT CK_TUTAR CHECK (TUTAR >= 0), CONSTRAINT FK_SIPARIS_MUSTERI FOREIGN KEY (MUSTERI_ID) REFERENCES T_MUSTERI (ID) ' +
    'ON DELETE CASCADE)');
  Komut('CREATE INDEX IX_SIPARIS_TUTAR ON T_SIPARIS (TUTAR)');
  Komut('CREATE VIEW V_BUYUK AS SELECT ID, TUTAR FROM T_SIPARIS WHERE TUTAR > 100');
  Komut('CREATE GENERATOR GEN_SIPARIS');
  Komut('CREATE EXCEPTION E_HATA ''Bir <hata> olustu''');
  Komut('CREATE PROCEDURE P_ARA (A INTEGER) RETURNS (B INTEGER) AS BEGIN B = A + 1; SUSPEND; END');
  Komut('CREATE TRIGGER TR_SIPARIS_BI FOR T_SIPARIS ACTIVE BEFORE INSERT POSITION 0 AS BEGIN ' +
    'IF (NEW.ID IS NULL) THEN NEW.ID = GEN_ID(GEN_SIPARIS, 1); END');
  Komut('COMMENT ON TABLE T_MUSTERI IS ''M' + #$00FC + #$015F + 'teri <kay' + #$0131 + 'tlar' + #$0131 + '> & "notlar"''');
  Komut('COMMENT ON COLUMN T_MUSTERI.AD IS ''Ad soyad''');
end;

procedure DilAnahtarTesti;
const
  ANAHTARLAR: array[0..37] of string = ('DOK_ILERLEME_BASLIK', 'DOK_HAZIRLIK', 'DOK_ADIM', 'DOK_IPTAL_NOTU', 'MSG_DOKUMAN_IPTAL', 'BTN_DOKUMAN', 'DOK_DOSYA_FILTRE', 'MSG_DOKUMAN_YAZILDI', 'ERR_DOKUMAN_YAPILAMADI',
    'DOK_BASLIK', 'DOK_ALT_BILGI', 'DOK_ICINDEKILER', 'DOK_TABLOLAR', 'DOK_VIEWLAR', 'DOK_PROSEDURLER', 'DOK_TETIKLEYICILER',
    'DOK_GENERATORLER', 'DOK_ISTISNALAR', 'DOK_DOMAINLER', 'DOK_KOLON', 'DOK_TIP', 'DOK_BOS_OLABILIR', 'DOK_VARSAYILAN',
    'DOK_ACIKLAMA', 'DOK_KISITLAR', 'DOK_INDEKSLER', 'DOK_TUR', 'DOK_AD', 'DOK_AYRINTI', 'DOK_BENZERSIZ', 'DOK_PASIF',
    'DOK_GIRDILER', 'DOK_CIKTILAR', 'DOK_KAYNAK', 'DOK_DEGER', 'DOK_MESAJ', 'DOK_EVET', 'DOK_HAYIR');
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
    Kontrol('dil ' + Dil + ': tum dokuman anahtarlari var' + IfThen(Eksik <> '', ' (eksik:' + Eksik + ')', ''), Eksik = '');
  end;
  DilYukle('tr');
end;

function Var_(const Metin, Aranan: string): Boolean;
begin
  Result := Pos(Aranan, Metin) > 0;
end;

procedure DokumanTesti;
var
  Yazici: TStringWriter;
  Ozet: TDokumanOzeti;
  Html, VarsayilanAd: string;
  Bayt: TBytes;
begin
  Yazici := TStringWriter.Create;
  try
    Ozet := DokumanUret(Bag, Yazici);
    Html := Yazici.ToString;
  finally
    Yazici.Free;
  end;
  Kontrol('ozet: 2 tablo, 1 view, 1 prosedur, 1 tetikleyici',
    (Ozet.Tablo = 2) and (Ozet.View = 1) and (Ozet.Prosedur = 1) and (Ozet.Tetikleyici = 1));
  Kontrol('html: baslangic ve bitis', StartsText('<!DOCTYPE html>', Html) and Var_(Html, '</body></html>'));
  Kontrol('html: utf-8 bildirimi', Var_(Html, '<meta charset="utf-8">'));
  Kontrol('html: javascript yok', not Var_(Html, '<script'));
  Kontrol('tablo bolumleri', Var_(Html, '<h3 id="t_T_MUSTERI">T_MUSTERI</h3>') and Var_(Html, '<h3 id="t_T_SIPARIS">T_SIPARIS</h3>'));
  Kontrol('icindekiler baglantisi', Var_(Html, '<a href="#t_T_MUSTERI">T_MUSTERI</a>'));
  Kontrol('aciklama kacirilmis (<, >, &, ")',
    Var_(Html, 'M' + #$00FC + #$015F + 'teri &lt;kay' + #$0131 + 'tlar' + #$0131 + '&gt; &amp; &quot;notlar&quot;'));
  Kontrol('kolon aciklamasi', Var_(Html, '<td>Ad soyad</td>'));
  Kontrol('PK isareti', Var_(Html, '<td>ID <span class="pk">PK</span></td>'));
  Kontrol('domain kolon tipi', Var_(Html, '<td>D_YUZDE</td>'));
  Kontrol('bos olamaz (AD): Hayir', Var_(Html, '<td>AD</td><td>VARCHAR(50)') and Var_(Html, '<td>Hay' + #$0131 + 'r</td>'));
  Kontrol('varsayilan deger', Var_(Html, 'DEFAULT 0'));
  Kontrol('kisit: PRIMARY KEY, UNIQUE, CHECK, FOREIGN KEY',
    Var_(Html, '<td>PRIMARY KEY</td><td>PK_MUSTERI</td>') and Var_(Html, '<td>UNIQUE</td><td>UQ_KOD</td>') and
    Var_(Html, '<td>CHECK</td><td>CK_TUTAR</td>') and Var_(Html, '<td>FOREIGN KEY</td><td>FK_SIPARIS_MUSTERI</td>'));
  Kontrol('yabanci anahtar hedefi ve silme kurali', Var_(Html, '&rarr; T_MUSTERI (ID) ON DELETE CASCADE'));
  Kontrol('index satiri', Var_(Html, '<tr><td>IX_SIPARIS_TUTAR</td><td>TUTAR</td>'));
  Kontrol('tablonun tetikleyici listesi baglantili', Var_(Html, '<a href="#g_TR_SIPARIS_BI">TR_SIPARIS_BI</a>'));
  Kontrol('view bolumu ve kaynak', Var_(Html, '<h3 id="v_V_BUYUK">V_BUYUK</h3>') and Var_(Html, 'TUTAR &gt; 100'));
  Kontrol('prosedur: girdi, cikti, kaynak',
    Var_(Html, '<h3 id="p_P_ARA">P_ARA</h3>') and Var_(Html, '<td>A</td><td>INTEGER</td>') and
    Var_(Html, '<td>B</td><td>INTEGER</td>') and Var_(Html, 'B = A + 1'));
  Kontrol('tetikleyici bolumu: tablo baglantisi ve kaynak',
    Var_(Html, '<h3 id="g_TR_SIPARIS_BI">TR_SIPARIS_BI</h3>') and Var_(Html, 'href="#t_T_SIPARIS"') and
    Var_(Html, 'GEN_ID(GEN_SIPARIS, 1)'));
  Kontrol('generator ve degeri', Var_(Html, '<tr><td>GEN_SIPARIS</td><td>0</td>'));
  Kontrol('exception mesaji kacirilmis', Var_(Html, '<td>E_HATA</td><td>Bir &lt;hata&gt; olustu</td>'));
  Kontrol('domain: ad, tip, check', Var_(Html, '<td>D_YUZDE</td><td>INTEGER</td>') and
    Var_(Html, 'CHECK (VALUE BETWEEN 0 AND 100)'));

  { Dosya: imsiz UTF-8, ayni icerik }
  VarsayilanAd := VarsayilanDokumanAdi(Bag);
  Kontrol('varsayilan ad .html ile biter ve gecerli', EndsText('.html', VarsayilanAd) and (Pos(':', VarsayilanAd) = 0));
  Ozet := DokumanDosyasiYaz(Bag, HtmlDosyasi);
  Bayt := TFile.ReadAllBytes(HtmlDosyasi);
  Kontrol('dosya: BOM yok', not ((Length(Bayt) >= 3) and (Bayt[0] = $EF) and (Bayt[1] = $BB) and (Bayt[2] = $BF)));
  Kontrol('dosya: ozet ayni, Turkce karakter bozulmadan',
    (Ozet.Tablo = 2) and Var_(TFile.ReadAllText(HtmlDosyasi, TEncoding.UTF8), 'M' + #$00FC + #$015F + 'teri'));
end;

procedure IlerlemeTesti;
var
  Yazici: TStringWriter;
  Ozet: TDokumanOzeti;
  Adimlar: TStringList;
  Html: string;
begin
  { 1. Ilerleme bildirimi: her tablo, view, prosedur ve tetikleyici icin bir adim }
  Adimlar := TStringList.Create;
  Yazici := TStringWriter.Create;
  try
    Ozet := DokumanUret(Bag, Yazici,
      procedure(const Adim: string; var Iptal: Boolean)
      begin
        Adimlar.Add(Adim);
      end);
    Kontrol('ilerleme: hazirlik + 2 tablo + 1 view + 1 prosedur + 1 tetikleyici = 6 adim', Adimlar.Count = 6);
    Kontrol('ilerleme: adim yazisi (Tablolar 1/2: T_MUSTERI)', (Adimlar.Count > 1) and (Adimlar[1] = 'Tablolar 1/2: T_MUSTERI'));
    Kontrol('ilerleme: iptal edilmedi', not Ozet.Iptal);
  finally
    Yazici.Free;
  end;
  { 2. Iptal: ikinci tabloda durur; dokuman kapanir ve eksik oldugunu yazar }
  Adimlar.Clear;
  Yazici := TStringWriter.Create;
  try
    Ozet := DokumanUret(Bag, Yazici,
      procedure(const Adim: string; var Iptal: Boolean)
      begin
        Adimlar.Add(Adim);
        if Pos('Tablolar 2/2', Adim) = 1 then
          Iptal := True;
      end);
    Html := Yazici.ToString;
  finally
    Yazici.Free;
    Adimlar.Free;
  end;
  Kontrol('iptal: ozet iptal, yalniz 1 tablo yazildi, view/prosedur/tetikleyici yok',
    Ozet.Iptal and (Ozet.Tablo = 1) and (Ozet.View = 0) and (Ozet.Prosedur = 0) and (Ozet.Tetikleyici = 0));
  Kontrol('iptal: dokumanda eksik notu var ve html kapandi', Var_(Html, T('DOK_IPTAL_NOTU')) and Var_(Html, '</body></html>'));
  Kontrol('iptal: ikinci tablo yazilmadi', not Var_(Html, '<h3 id="t_T_SIPARIS">'));
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
      Klasor := Ortam('FBTEST_KLASOR', TPath.Combine(GetEnvironmentVariable('TEMP'), 'dokumantest'));
      HtmlKlasoru := TPath.Combine(GetEnvironmentVariable('TEMP'), 'dokumantest');
      ForceDirectories(HtmlKlasoru);
      if Ortam('FBTEST_SUNUCU', '') = '' then
        ForceDirectories(Klasor);
      HtmlDosyasi := TPath.Combine(HtmlKlasoru, 'dokuman_' + FormatDateTime('yyyymmdd_hhnnss', Now) + '.html');
      Tanim := Default(TBaglantiTanimi);
      Tanim.Ad := 'dokumantest';
      Tanim.Sunucu := Ortam('FBTEST_SUNUCU', '');
      Tanim.Port := StrToInt(Ortam('FBTEST_PORT', '3050'));
      Tanim.VeritabaniYolu := IncludeTrailingPathDelimiter(Klasor) + 'dokumantest_' +
        FormatDateTime('yyyymmdd_hhnnss', Now) + '.fdb';
      Tanim.Kullanici := Ortam('FBTEST_KULLANICI', 'SYSDBA');
      Tanim.Sifre := Ortam('FBTEST_SIFRE', '');
      Tanim.KarakterSeti := VARSAYILAN_KARAKTER_SETI;
      GeciciVeritabaniOlustur(Tanim);
      Bag := FbBaglan(Tanim);
      Cikti.Add('--- Surum ' + Bag.Surum + ' ---');
      DilAnahtarTesti;
      NesneleriKur;
      DokumanTesti;
      IlerlemeTesti;
      FbBaglantiyiKes(Bag);
      Bag := nil;
      if Tanim.Sunucu = '' then
        ArsiveTasi(Tanim.VeritabaniYolu);
      ArsiveTasi(HtmlDosyasi);
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
