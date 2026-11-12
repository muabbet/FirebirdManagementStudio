program IliskiTest;

{ Iliskili kayitlara git testi (uIliski, uMetadata.KisitaBagliYabanciKolonlar, uSorgu.KayitSayisi) ve kolon ozeti (uSorgu.KolonOzeti).
  Gercek veriye dokunulmaz: kendi gecici veritabanini kurar (musteri, siparis, kalem, ...), dosya silinmez.
  Ortam degiskenleri: FBTEST_SUNUCU (bos = yerel), FBTEST_PORT, FBTEST_KLASOR, FBTEST_KULLANICI, FBTEST_SIFRE,
  FBTEST_CIKTI. Cikis kodu: hata sayisi (0 = hepsi gecti). }

{$APPTYPE CONSOLE}

uses
  System.SysUtils, System.Classes, System.IOUtils, Data.DB,
  FireDAC.Stan.Intf, FireDAC.Stan.Option, FireDAC.Stan.Error, FireDAC.Comp.Client, FireDAC.Phys.FB,
  FireDAC.ConsoleUI.Wait,
  uDil, uBaglanti, uSorgu, uMetadata, uIliski, uDDL, uAra, uCokluSorgu;

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
  { Arama testi icin view, exception, prosedur ve trigger }
  Calistir('CREATE VIEW V_SIPARIS_OZET AS SELECT MUSTERI_ID, COUNT(*) AS ADET FROM SIPARIS GROUP BY MUSTERI_ID');
  Calistir('CREATE EXCEPTION E_MUSTERI_YOK ''Musteri yok''');
  Calistir('CREATE PROCEDURE P_MUSTERI_SIL AS BEGIN DELETE FROM MUSTERI WHERE ID = 999; END');
  Calistir('CREATE TRIGGER TR_SIPARIS_BI FOR SIPARIS ACTIVE BEFORE INSERT POSITION 0 AS BEGIN IF (NEW.ID IS NULL) THEN NEW.ID = 1; END');
end;

{ Sonucta bu tur, ad ve yerde bir kayit var mi (Ayrinti bos degilse onu da icermeli). }
function Var_(const Liste: TArray<TAramaSonucu>; Tur: TNesneTuru; const Ad: string; Yer: TAramaYeri; const Ayrinti: string = ''): Boolean;
var
  S: TAramaSonucu;
begin
  Result := False;
  for S in Liste do
    if (S.Tur = Tur) and SameText(S.Ad, Ad) and (S.Yer = Yer) and ((Ayrinti = '') or (Pos(UpperCase(Ayrinti), UpperCase(S.Ayrinti)) > 0)) then
      Exit(True);
end;


{ Tablo icin ornek SELECT / INSERT / UPDATE / DELETE (7p). Uretilen komutlar gercekten calisir; UPDATE ve DELETE
  doldurulmadan hicbir satira dokunmaz. }
procedure ScriptDene;
var
  S: string;
  Komutlar: TArray<string>;
  Sonuc: TSorguSonucu;
  Once, Sonra: Int64;
begin
  Calistir('CREATE TABLE T_HESAPLI (A INTEGER NOT NULL PRIMARY KEY, B INTEGER, C COMPUTED BY (A + B))');
  Calistir('CREATE TABLE T_ANAHTARSIZ (X INTEGER, Y VARCHAR(10))');
  Calistir('INSERT INTO T_HESAPLI (A, B) VALUES (1, 2)');
  Calistir('INSERT INTO T_ANAHTARSIZ VALUES (1, ''a'')');

  S := TabloKomutScripti(Bag, 'MUSTERI', tkSelect);
  Cikti.Add('--- SELECT ---' + sLineBreak + S);
  Kontrol('Script SELECT: tum kolonlar ve FROM', (Pos('    ID,', S) > 0) and (Pos('    AD' + sLineBreak, S) > 0) and (Pos('FROM MUSTERI;', S) > 0));
  S := TabloKomutScripti(Bag, 'MUSTERI', tkInsert);
  Cikti.Add('--- INSERT ---' + sLineBreak + S);
  Kontrol('Script INSERT: kolon listesi ve NULL degerler', (Pos('INSERT INTO MUSTERI (', S) > 0) and (Pos('NULL, -- ID (NOT NULL)', S) > 0) and
    (Pos('NULL -- AD', S) > 0));
  S := TabloKomutScripti(Bag, 'MUSTERI', tkUpdate);
  Cikti.Add('--- UPDATE ---' + sLineBreak + S);
  Kontrol('Script UPDATE: SET yalniz anahtar olmayan kolon, WHERE anahtardan', (Pos('UPDATE MUSTERI SET', S) > 0) and
    (Pos('    AD = NULL', S) > 0) and (Pos('ID = NULL' + sLineBreak, S) = 0) and (Pos('WHERE ID = NULL', S) > 0));
  S := TabloKomutScripti(Bag, 'KALEM', tkDelete);
  Cikti.Add('--- DELETE (birlesik anahtar) ---' + sLineBreak + S);
  Kontrol('Script DELETE: birlesik anahtarda iki kosul AND ile', (Pos('DELETE FROM KALEM', S) > 0) and
    (Pos('WHERE SIPARIS_ID = NULL', S) > 0) and (Pos('AND SATIR_NO = NULL', S) > 0));
  S := TabloKomutScripti(Bag, 'T_HESAPLI', tkInsert);
  Kontrol('Script INSERT: hesaplanan kolon girmez', (Pos(' C,', S) = 0) and (Pos('-- C', S) = 0) and (Pos('-- B', S) > 0));
  S := TabloKomutScripti(Bag, 'T_HESAPLI', tkSelect);
  Kontrol('Script SELECT: hesaplanan kolon da okunur', Pos('    C' + sLineBreak, S) > 0);
  S := TabloKomutScripti(Bag, 'T_ANAHTARSIZ', tkDelete);
  Cikti.Add('--- DELETE (anahtarsiz) ---' + sLineBreak + S);
  Kontrol('Script DELETE: anahtar yoksa WHERE 1 = 0', Pos('WHERE 1 = 0', S) > 0);
  S := TabloKomutScripti(Bag, 'T_ANAHTARSIZ', tkUpdate);
  Kontrol('Script UPDATE: anahtar yoksa tum kolonlar SET, WHERE 1 = 0', (Pos('    X = NULL,', S) > 0) and (Pos('    Y = NULL' + sLineBreak, S) > 0) and
    (Pos('WHERE 1 = 0', S) > 0));

  { Uretilen komutlar editorle ayni yoldan (KomutlaraBol) calisir ve hicbir satira dokunmaz. }
  Once := KayitSayisi(Bag, 'T_HESAPLI', '');
  for S in [TabloKomutScripti(Bag, 'T_HESAPLI', tkSelect), TabloKomutScripti(Bag, 'T_HESAPLI', tkUpdate),
    TabloKomutScripti(Bag, 'T_HESAPLI', tkDelete), TabloKomutScripti(Bag, 'T_ANAHTARSIZ', tkUpdate),
    TabloKomutScripti(Bag, 'T_ANAHTARSIZ', tkDelete)] do
  begin
    Komutlar := KomutlaraBol(S);
    Sonuc := SorguCalistir(Bag, Komutlar[0]);
    Sonuc.Free;
  end;
  Sonra := KayitSayisi(Bag, 'T_HESAPLI', '');
  Kontrol('Script: SELECT/UPDATE/DELETE komutlari gecerli SQL ve doldurulmadan satira dokunmaz',
    (Once = 1) and (Sonra = 1) and (KayitSayisi(Bag, 'T_ANAHTARSIZ', '') = 1));
end;

{ Veritabaninda arama (7l): ad, kolon ve kaynak metni. }
procedure AraDene;
var
  S: TArray<TAramaSonucu>;
  Kesildi: Boolean;
  K: TAramaSonucu;
  KaynakVar: Boolean;
begin
  S := MetadataAra(Bag, 'musteri', False, Kesildi);
  Kontrol('Ara ad: tablo MUSTERI bulunur', Var_(S, ntTablo, 'MUSTERI', ayAd));
  Kontrol('Ara ad: exception bulunur', Var_(S, ntIstisna, 'E_MUSTERI_YOK', ayAd));
  Kontrol('Ara ad: prosedur bulunur', Var_(S, ntProsedur, 'P_MUSTERI_SIL', ayAd));
  Kontrol('Ara kolon: SIPARIS.MUSTERI_ID tablo kolonu', Var_(S, ntTablo, 'SIPARIS', ayKolon, 'MUSTERI_ID'));
  Kontrol('Ara kolon: view kolonu view olarak gelir', Var_(S, ntView, 'V_SIPARIS_OZET', ayKolon, 'MUSTERI_ID'));
  KaynakVar := False;
  for K in S do
    if K.Yer = ayKaynak then
      KaynakVar := True;
  Kontrol('Ara: kaynak aramasi kapaliyken kaynak sonucu yok', not KaynakVar);
  Kontrol('Ara: kesilmedi', not Kesildi);

  S := MetadataAra(Bag, 'MuSteRi', False, Kesildi);
  Kontrol('Ara: buyuk kucuk harf fark etmez', Var_(S, ntTablo, 'MUSTERI', ayAd));

  S := MetadataAra(Bag, 'm', False, Kesildi);
  Kontrol('Ara: cok kisa yazi aranmaz', Length(S) = 0);

  S := MetadataAra(Bag, 'musteri', True, Kesildi);
  Kontrol('Ara kaynak: prosedur govdesi (DELETE FROM MUSTERI satiri)', Var_(S, ntProsedur, 'P_MUSTERI_SIL', ayKaynak, 'DELETE FROM MUSTERI'));
  Kontrol('Ara kaynak: view kaynagi', Var_(S, ntView, 'V_SIPARIS_OZET', ayKaynak, 'MUSTERI_ID'));
  S := MetadataAra(Bag, 'new.id', True, Kesildi);
  Kontrol('Ara kaynak: trigger govdesi', Var_(S, ntTetikleyici, 'TR_SIPARIS_BI', ayKaynak, 'NEW.ID'));

  S := MetadataAra(Bag, 'siparis_bi', False, Kesildi);
  Kontrol('Ara ad: trigger adi bulunur', Var_(S, ntTetikleyici, 'TR_SIPARIS_BI', ayAd));

  S := MetadataAra(Bag, 'zzzyok', True, Kesildi);
  Kontrol('Ara: olmayan yazi bos doner', Length(S) = 0);
  S := MetadataAra(Bag, 'rdb$', True, Kesildi);
  Kontrol('Ara: sistem nesneleri aranmaz', Length(S) = 0);
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

{ Kolon ozeti (7k): sayi, yazi ve bos degerli kolonlar, filtreli ve filtresiz. }
procedure OzetDene;
var
  O: TKolonOzeti;
begin
  { SIPARIS: ID 10, 11, 12; MUSTERI_ID 1, 1, NULL }
  O := KolonOzeti(Bag, 'SIPARIS', 'ID', okSayisal, '');
  Kontrol('Ozet sayi: 3 kayit, 3 dolu', (O.Kayit = 3) and (O.Dolu = 3));
  Kontrol('Ozet sayi: toplam 33', O.Toplam = '33');
  Kontrol('Ozet sayi: ortalama 11', O.Ortalama = '11');
  Kontrol('Ozet sayi: en kucuk 10, en buyuk 12', (O.EnKucuk = '10') and (O.EnBuyuk = '12'));
  O := KolonOzeti(Bag, 'SIPARIS', 'MUSTERI_ID', okSayisal, '');
  Kontrol('Ozet bos deger: 3 kayit, 2 dolu', (O.Kayit = 3) and (O.Dolu = 2));
  Kontrol('Ozet bos deger: toplam 2, ortalama 1', (O.Toplam = '2') and (O.Ortalama = '1'));
  O := KolonOzeti(Bag, 'SIPARIS', 'ID', okSayisal, '"ID" > 10');
  Kontrol('Ozet filtreli: 2 kayit, toplam 23, ortalama 11,5',
    (O.Kayit = 2) and (O.Toplam = '23') and (O.Ortalama = FormatFloat('0.####', 11.5)));
  O := KolonOzeti(Bag, 'SIPARIS', 'ID', okSayisal, '"ID" > 1000');
  Kontrol('Ozet filtre hic kayit getirmez: 0 kayit, toplam bos', (O.Kayit = 0) and (O.Toplam = '') and (O.EnKucuk = ''));
  O := KolonOzeti(Bag, 'MUSTERI', 'AD', okAralik, '');
  Kontrol('Ozet yazi: en kucuk Ali, en buyuk Veli', (O.EnKucuk = 'Ali') and (O.EnBuyuk = 'Veli') and (O.Toplam = ''));
  O := KolonOzeti(Bag, 'MUSTERI', 'AD', okSade, '');
  Kontrol('Ozet sade: yalniz sayim', (O.Kayit = 3) and (O.Dolu = 3) and (O.EnKucuk = ''));
  Kontrol('Ozet SQL: filtre WHERE olarak girer',
    Pos('WHERE ("ID" > 10', KolonOzetiSql('SIPARIS', 'ID', okSayisal, '"ID" > 10')) > 0);
  Kontrol('Ozet SQL: sade ozette SUM yok', Pos('SUM(', KolonOzetiSql('SIPARIS', 'ID', okSade, '')) = 0);
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
      OzetDene;
      AraDene;
      ScriptDene;
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
