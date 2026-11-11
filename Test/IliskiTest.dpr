program IliskiTest;

{ Iliskili kayitlara git testi (uIliski, uMetadata.KisitaBagliYabanciKolonlar, uSorgu.KayitSayisi).
  Gercek veriye dokunulmaz: kendi gecici veritabanini kurar (musteri, siparis, kalem, ...), dosya silinmez.
  Ortam degiskenleri: FBTEST_SUNUCU (bos = yerel), FBTEST_PORT, FBTEST_KLASOR, FBTEST_KULLANICI, FBTEST_SIFRE,
  FBTEST_CIKTI. Cikis kodu: hata sayisi (0 = hepsi gecti). }

{$APPTYPE CONSOLE}

uses
  System.SysUtils, System.Classes, System.IOUtils, Data.DB,
  FireDAC.Stan.Intf, FireDAC.Stan.Option, FireDAC.Stan.Error, FireDAC.Comp.Client, FireDAC.Phys.FB,
  FireDAC.ConsoleUI.Wait,
  uDil, uBaglanti, uSorgu, uMetadata, uIliski;

var
  Cikti: TStringList;
  Hatalar: Integer;
  Bag: TAcikBaglanti;

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

procedure Calistir(const Sql: string);
begin
  SorguCalistir(Bag, Sql).Free;
end;

{ Tablonun belirtilen satirini (ID kolonu = Id) acik veri seti olarak verir. }
function Satir(const Tablo, Kolon: string; Deger: Integer): TFDQuery;
begin
  Result := TabloVerisiSorgusu(Bag, Tablo, 100, nil, '', False, TirnakliAd(Kolon) + ' = ' + IntToStr(Deger));
end;

procedure Kur;
begin
  Calistir('CREATE TABLE MUSTERI (ID INTEGER NOT NULL PRIMARY KEY, AD VARCHAR(30))');
  Calistir('CREATE TABLE SIPARIS (ID INTEGER NOT NULL PRIMARY KEY, MUSTERI_ID INTEGER, ' +
    'CONSTRAINT FK_SIPARIS_MUSTERI FOREIGN KEY (MUSTERI_ID) REFERENCES MUSTERI (ID))');
  Calistir('CREATE TABLE KALEM (SIPARIS_ID INTEGER NOT NULL, SATIR_NO INTEGER NOT NULL, ' +
    'PRIMARY KEY (SIPARIS_ID, SATIR_NO), FOREIGN KEY (SIPARIS_ID) REFERENCES SIPARIS (ID))');
  Calistir('CREATE TABLE KALEM_NOT (ID INTEGER NOT NULL PRIMARY KEY, SIPARIS_ID INTEGER, SATIR_NO INTEGER, ' +
    'FOREIGN KEY (SIPARIS_ID, SATIR_NO) REFERENCES KALEM (SIPARIS_ID, SATIR_NO))');
  Calistir('CREATE TABLE KOD (K VARCHAR(10) NOT NULL PRIMARY KEY)');
  Calistir('CREATE TABLE URUN (ID INTEGER NOT NULL PRIMARY KEY, KOD VARCHAR(10), ' +
    'FOREIGN KEY (KOD) REFERENCES KOD (K))');
  Calistir('INSERT INTO MUSTERI VALUES (1, ''Ali'')');
  Calistir('INSERT INTO MUSTERI VALUES (2, ''Veli'')');
  Calistir('INSERT INTO MUSTERI VALUES (3, ''Kimse'')');
  Calistir('INSERT INTO SIPARIS VALUES (10, 1)');
  Calistir('INSERT INTO SIPARIS VALUES (11, 1)');
  Calistir('INSERT INTO SIPARIS VALUES (12, NULL)');
  Calistir('INSERT INTO KALEM VALUES (10, 1)');
  Calistir('INSERT INTO KALEM VALUES (10, 2)');
  Calistir('INSERT INTO KALEM_NOT VALUES (1, 10, 2)');
  Calistir('INSERT INTO KOD VALUES (''O''''K'')');
  Calistir('INSERT INTO URUN VALUES (1, ''O''''K'')');
end;

procedure Dene;
var
  V: TFDQuery;
  Kayit: TIliskiliKayit;
  Liste: TArray<TIliskiliKayit>;
  Kisitlar: TArray<TKisitBilgisi>;
  Gelen: TArray<TYabanciKolonlar>;
  Kisit: TKisitBilgisi;
  Birincil: string;
begin
  { Giden: yabanci anahtar hucresinden ana kayda }
  V := Satir('SIPARIS', 'ID', 10);
  Kisitlar := KisitlariOku(Bag, 'SIPARIS');
  Kontrol('Giden: FK kolonunda bagli kayit bulunur', BagliKayitBul(Kisitlar, 'MUSTERI_ID', V, Kayit));
  Kontrol('Giden: hedef tablo MUSTERI', Kayit.Tablo = 'MUSTERI');
  Kontrol('Giden: kosul "ID" = 1', Kayit.Filtre = '"ID" = 1');
  Kontrol('Giden: kolon adi buyuk kucuk fark etmez', BagliKayitBul(Kisitlar, 'musteri_id', V, Kayit));
  Kontrol('Giden: FK olmayan kolonda yok', not BagliKayitBul(Kisitlar, 'ID', V, Kayit));
  Kontrol('Giden: bagli kayit gercekten acilir (1 kayit)', KayitSayisi(Bag, 'MUSTERI', '"ID" = 1') = 1);
  V.Free;

  V := Satir('SIPARIS', 'ID', 12);
  Kontrol('Giden: FK degeri NULL ise yok', not BagliKayitBul(Kisitlar, 'MUSTERI_ID', V, Kayit));
  V.Free;

  { Birlesik anahtar }
  V := Satir('KALEM_NOT', 'ID', 1);
  Kisitlar := KisitlariOku(Bag, 'KALEM_NOT');
  Kontrol('Giden birlesik: bulunur', BagliKayitBul(Kisitlar, 'SATIR_NO', V, Kayit));
  Kontrol('Giden birlesik: tablo KALEM', Kayit.Tablo = 'KALEM');
  Kontrol('Giden birlesik: iki kosul VE ile', Kayit.Filtre = '"SIPARIS_ID" = 10 AND "SATIR_NO" = 2');
  Kontrol('Giden birlesik: tek kayit', KayitSayisi(Bag, Kayit.Tablo, Kayit.Filtre) = 1);
  V.Free;

  { Tirnakli yazi degeri }
  V := TabloVerisiSorgusu(Bag, 'URUN', 100, nil, '', False, '"ID" = 1');
  Kisitlar := KisitlariOku(Bag, 'URUN');
  Kontrol('Giden yazi: bulunur', BagliKayitBul(Kisitlar, 'KOD', V, Kayit));
  Kontrol('Giden yazi: tirnak ikilenir', Kayit.Filtre = '"K" = ''O''''K''');
  Kontrol('Giden yazi: kayit sayisi 1', KayitSayisi(Bag, 'KOD', Kayit.Filtre) = 1);
  V.Free;

  { Gelen: bu kaydi kullananlar }
  V := Satir('MUSTERI', 'ID', 1);
  Kisitlar := KisitlariOku(Bag, 'MUSTERI');
  Liste := KullananKayitlariBul(Bag, Kisitlar, V);
  Kontrol('Gelen: musteri 1 icin tek tablo (SIPARIS)', (Length(Liste) = 1) and (Liste[0].Tablo = 'SIPARIS'));
  Kontrol('Gelen: SIPARIS 2 kayit', (Length(Liste) = 1) and (Liste[0].Adet = 2));
  Kontrol('Gelen: kosul "MUSTERI_ID" = 1', (Length(Liste) = 1) and (Liste[0].Filtre = '"MUSTERI_ID" = 1'));
  V.Free;

  V := Satir('MUSTERI', 'ID', 3);
  Liste := KullananKayitlariBul(Bag, Kisitlar, V);
  Kontrol('Gelen: kullanilmayan musteri icin bos liste', Length(Liste) = 0);
  V.Free;

  V := Satir('SIPARIS', 'ID', 10);
  Kisitlar := KisitlariOku(Bag, 'SIPARIS');
  Liste := KullananKayitlariBul(Bag, Kisitlar, V);
  Kontrol('Gelen: siparis 10 kalemlerde 2 kayit', (Length(Liste) = 1) and (Liste[0].Tablo = 'KALEM') and (Liste[0].Adet = 2));
  V.Free;

  { Gelen birlesik anahtar: KALEM (10,2) KALEM_NOT'ta }
  V := TabloVerisiSorgusu(Bag, 'KALEM', 100, nil, '', False, '"SIPARIS_ID" = 10 AND "SATIR_NO" = 2');
  Kisitlar := KisitlariOku(Bag, 'KALEM');
  Liste := KullananKayitlariBul(Bag, Kisitlar, V);
  Kontrol('Gelen birlesik: KALEM_NOT 1 kayit', (Length(Liste) = 1) and (Liste[0].Tablo = 'KALEM_NOT') and (Liste[0].Adet = 1));
  Kontrol('Gelen birlesik: kolon adlari gosterimde', (Length(Liste) = 1) and (Liste[0].Kolonlar = 'SIPARIS_ID, SATIR_NO'));
  V.Free;
  V := TabloVerisiSorgusu(Bag, 'KALEM', 100, nil, '', False, '"SIPARIS_ID" = 10 AND "SATIR_NO" = 1');
  Liste := KullananKayitlariBul(Bag, Kisitlar, V);
  Kontrol('Gelen birlesik: baska kalem kullanilmiyor', Length(Liste) = 0);
  V.Free;

  { Metadata: kisita bagli yabanci kolonlar }
  Birincil := '';
  for Kisit in KisitlariOku(Bag, 'MUSTERI') do
    if Kisit.Tur = ktBirincil then
      Birincil := Kisit.GercekAd;
  Gelen := KisitaBagliYabanciKolonlar(Bag, Birincil);
  Kontrol('Metadata: MUSTERI anahtarini SIPARIS.MUSTERI_ID kullanir',
    (Length(Gelen) = 1) and (Gelen[0].Tablo = 'SIPARIS') and (Length(Gelen[0].Kolonlar) = 1) and (Gelen[0].Kolonlar[0] = 'MUSTERI_ID'));
  Kontrol('KayitSayisi: filtresiz tum tablo', KayitSayisi(Bag, 'SIPARIS', '') = 3);
  Kontrol('KayitSayisi: filtreli', KayitSayisi(Bag, 'SIPARIS', '"MUSTERI_ID" = 1') = 2);
end;

var
  Tanim: TBaglantiTanimi;
  Klasor, Yol, CiktiYolu: string;
  Gomulu: Boolean;
begin
  Cikti := TStringList.Create;
  Hatalar := 0;
  Bag := nil;
  try
    try
      DilYukle('tr');
      Gomulu := Ortam('FBTEST_SUNUCU', '') = '';
      Klasor := Ortam('FBTEST_KLASOR', TPath.Combine(GetEnvironmentVariable('TEMP'), 'iliskitest'));
      if Gomulu then
        ForceDirectories(Klasor);
      Yol := IncludeTrailingPathDelimiter(Klasor) + 'iliski_' + FormatDateTime('yyyymmdd_hhnnss', Now) + '.fdb';
      Tanim := Default(TBaglantiTanimi);
      Tanim.Ad := 'iliskitest';
      Tanim.Sunucu := Ortam('FBTEST_SUNUCU', '');
      Tanim.Port := StrToInt(Ortam('FBTEST_PORT', '3050'));
      Tanim.VeritabaniYolu := Yol;
      Tanim.Kullanici := Ortam('FBTEST_KULLANICI', 'SYSDBA');
      Tanim.Sifre := Ortam('FBTEST_SIFRE', '');
      Tanim.KarakterSeti := VARSAYILAN_KARAKTER_SETI;
      FbVeritabaniOlustur(Tanim);
      Cikti.Add('Gecici veritabani: ' + Yol);
      Bag := FbBaglan(Tanim);
      Cikti.Add('Baglandi. Surum: ' + Bag.Surum);
      Kur;
      Dene;
    except
      on E: Exception do
      begin
        Cikti.Add('BEKLENMEYEN HATA: ' + E.Message);
        Inc(Hatalar);
      end;
    end;
  finally
    if Bag <> nil then
      FbBaglantiyiKes(Bag);
  end;
  Cikti.Add('Hata sayisi: ' + IntToStr(Hatalar));
  CiktiYolu := Ortam('FBTEST_CIKTI', '');
  if CiktiYolu <> '' then
    Cikti.SaveToFile(CiktiYolu, TEncoding.UTF8)
  else
    Writeln(Cikti.Text);
  Cikti.Free;
  ExitCode := Hatalar;
end.
