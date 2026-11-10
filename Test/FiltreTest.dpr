program FiltreTest;

{ Tablo sekmesi filtre kutusu testi (uSorgu.FiltreKosulu ve TabloVerisiSorgusu'nun Filtre parametresi).
  A bolumu saf kurallar (veritabani gerekmez). B bolumu FBTEST_YOL verilirse gercek sunucuda
  yalniz OKUMA yapar (sistem tablosu RDB$RELATIONS), hicbir sey yazmaz.
  Ortam: FBTEST_SUNUCU, FBTEST_PORT, FBTEST_YOL, FBTEST_KULLANICI, FBTEST_SIFRE, FBTEST_CIKTI.
  Cikis kodu: hata sayisi. }

{$APPTYPE CONSOLE}

uses
  System.SysUtils, System.Classes, System.IOUtils, Data.DB, FireDAC.Comp.Client,
  uDil, uBaglanti, uSorgu, uFiltre;

var
  Cikti: TStringList;
  Hatalar: Integer;

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

function Ortam(const Ad, Varsayilan: string): string;
begin
  Result := GetEnvironmentVariable(Ad);
  if Result = '' then
    Result := Varsayilan;
end;

{ Filtreli sorgunun satir adlarini "A,B" gibi tek yaziya cevirir. }
function Adlar(Sorgu: TFDQuery): string;
begin
  Result := '';
  while not Sorgu.Eof do
  begin
    if Result <> '' then
      Result := Result + ',';
    Result := Result + Trim(Sorgu.FieldByName('RDB$RELATION_NAME').AsString);
    Sorgu.Next;
  end;
end;

{ Sag tik hucre filtresi: bellekte kucuk bir tablo kurup uretilen kosullara bakar. }
procedure HucreTestleri;
var
  Tablo: TFDMemTable;
  Id, Ad, Tutar, Tarih: TField;
begin
  Tablo := TFDMemTable.Create(nil);
  try
    Tablo.FieldDefs.Add('ID', ftInteger);
    Tablo.FieldDefs.Add('AD', ftString, 30);
    Tablo.FieldDefs.Add('TUTAR', ftFloat);
    Tablo.FieldDefs.Add('TARIH', ftDate);
    Tablo.CreateDataSet;
    Tablo.AppendRecord([2, 'O''Neil', 12.5, EncodeDate(2026, 11, 9)]);
    Tablo.Append;
    Tablo.FieldByName('ID').AsInteger := 3;
    Tablo.Post;
    Id := Tablo.FieldByName('ID');
    Ad := Tablo.FieldByName('AD');
    Tutar := Tablo.FieldByName('TUTAR');
    Tarih := Tablo.FieldByName('TARIH');

    Tablo.First;
    Kontrol('Hucre: sayi esit', HucreFiltresi(Id, hiEsit) = '"ID" = 2');
    Kontrol('Hucre: sayi buyuk', HucreFiltresi(Id, hiBuyuk) = '"ID" > 2');
    Kontrol('Hucre: sayi kucuk', HucreFiltresi(Id, hiKucuk) = '"ID" < 2');
    Kontrol('Hucre: sayi farkli', HucreFiltresi(Id, hiFarkli) = '"ID" <> 2');
    Kontrol('Hucre: ondalik nokta ile', Pos('.', HucreFiltresi(Tutar, hiEsit)) > 0);
    Kontrol('Hucre: ondalik virgul yok', Pos(',', HucreFiltresi(Tutar, hiEsit)) = 0);
    Kontrol('Hucre: tirnak ikilenir', HucreFiltresi(Ad, hiEsit) = '"AD" = ''O''''Neil''');
    Kontrol('Hucre: iceren', HucreFiltresi(Ad, hiIceren) = '"AD" CONTAINING ''O''''Neil''');
    Kontrol('Hucre: tarih ISO ve tirnakli', HucreFiltresi(Tarih, hiBuyuk) = '"TARIH" > ''2026-11-09''');
    Kontrol('Hucre: bos olanlar', HucreFiltresi(Id, hiBos) = '"ID" IS NULL');
    Kontrol('Hucre: bos olmayanlar', HucreFiltresi(Id, hiBosDegil) = '"ID" IS NOT NULL');
    Kontrol('Menu: sayi alani siralanabilir', SiralanabilirMi(Id) and not MetinAlaniMi(Id));
    Kontrol('Menu: yazi alani iceren', MetinAlaniMi(Ad) and not SiralanabilirMi(Ad));
    Tablo.Next;
    Kontrol('Bos hucrede esit isteyince IS NULL', HucreFiltresi(Ad, hiEsit) = '"AD" IS NULL');
  finally
    Tablo.Free;
  end;
  Kontrol('Birlestir: eski yoksa yeni', FiltreBirlestir('', 'A = 1') = 'A = 1');
  Kontrol('Birlestir: eski ve yeni VE ile', FiltreBirlestir('A = 1', 'B = 2') = '(A = 1) AND B = 2');
  Kontrol('Birlestir: eski yorumlu ise parantez alt satirda', Pos(sLineBreak + ') AND', FiltreBirlestir('A = 1 -- x', 'B = 2')) > 0);
end;

{ Kolon altindaki filtre kutusu: yazilan yazinin kosula cevrilmesi (uFiltre.SatirFiltresi). }
procedure SatirTestleri;
var
  Hata: string;

  function S(const Ad: string; Tur: TFieldType; const Yazi: string): string;
  begin
    Result := SatirFiltresi(Ad, Tur, Yazi, Hata);
  end;

begin
  Kontrol('Satir: bos yazi bos kosul', (S('AD', ftString, '') = '') and (Hata = ''));
  Kontrol('Satir: yazi varsayilan iceren', S('AD', ftString, 'ali') = '"AD" CONTAINING ''ali''');
  Kontrol('Satir: ad* ile baslar (buyuk kucuk harf fark etmez)', S('AD', ftString, 'ali*') = 'UPPER("AD") STARTING WITH UPPER(''ali'')');
  Kontrol('Satir: *ad iceren', S('AD', ftString, '*ali') = '"AD" CONTAINING ''ali''');
  Kontrol('Satir: =ad tam esit', S('AD', ftString, '=ali') = '"AD" = ''ali''');
  Kontrol('Satir: tirnak ikilenir', S('AD', ftString, 'O''Neil') = '"AD" CONTAINING ''O''''Neil''');
  Kontrol('Satir: tire bos olanlar', S('AD', ftString, '-') = '"AD" IS NULL');
  Kontrol('Satir: unlem tire bos olmayanlar', S('AD', ftString, '!-') = '"AD" IS NOT NULL');
  Kontrol('Satir: sayi varsayilan esit', S('ID', ftInteger, '5') = '"ID" = 5');
  Kontrol('Satir: sayi buyuk', S('ID', ftInteger, '>5') = '"ID" > 5');
  Kontrol('Satir: sayi buyuk esit, bosluklu', S('ID', ftInteger, '>= 5') = '"ID" >= 5');
  Kontrol('Satir: sayi kucuk esit', S('ID', ftInteger, '<=5') = '"ID" <= 5');
  Kontrol('Satir: sayi farkli (<>)', S('ID', ftInteger, '<>5') = '"ID" <> 5');
  Kontrol('Satir: sayi farkli (!=)', S('ID', ftInteger, '!=5') = '"ID" <> 5');
  Kontrol('Satir: sayi arasi', S('ID', ftInteger, '1..5') = '"ID" BETWEEN 1 AND 5');
  Kontrol('Satir: virgul ondalik nokta olur', S('TUTAR', ftFloat, '>1,5') = '"TUTAR" > 1.5');
  Kontrol('Satir: ondalik arasi', S('TUTAR', ftFloat, '1.5..2.5') = '"TUTAR" BETWEEN 1.5 AND 2.5');
  Kontrol('Satir: yalniz islem yazildi: henuz filtre yok, hata yok', (S('ID', ftInteger, '>') = '') and (Hata = ''));
  Kontrol('Satir: gecersiz sayi hata verir', (S('ID', ftInteger, 'abc') = '') and (Hata <> ''));
  Kontrol('Satir: sayi ve harf karisik hata verir', (S('ID', ftInteger, '5abc') = '') and (Hata <> ''));
  Kontrol('Satir: sayiya SQL parcasi sokulamaz', (S('ID', ftInteger, '1 OR 1=1') = '') and (Hata <> ''));
  Kontrol('Satir: tarih ISO', S('TARIH', ftDate, '2026-11-09') = '"TARIH" = ''2026-11-09''');
  Kontrol('Satir: tarih buyuk', S('TARIH', ftDate, '>2026-11-09') = '"TARIH" > ''2026-11-09''');
  Kontrol('Satir: tarih arasi', S('TARIH', ftDate, '2026-11-01..2026-11-09') = '"TARIH" BETWEEN ''2026-11-01'' AND ''2026-11-09''');
  Kontrol('Satir: tarih olmayan hata', (S('TARIH', ftDate, '5') = '') and (Hata <> ''));
  Kontrol('Satir: zaman damgasi saatsiz tarih tum gun', S('ZAMAN', ftTimeStamp, '2026-11-09') =
    '("ZAMAN" >= ''2026-11-09 00:00:00'' AND "ZAMAN" < ''2026-11-10 00:00:00'')');
  Kontrol('Satir: zaman damgasi saatli esit', S('ZAMAN', ftTimeStamp, '2026-11-09 10:30') = '"ZAMAN" = ''2026-11-09 10:30:00''');
  Kontrol('Satir: saat', S('SAAT', ftTime, '14:30') = '"SAAT" = ''14:30:00''');
  Kontrol('Satir: mantik evet', S('AKTIF', ftBoolean, 'evet') = '"AKTIF" = TRUE');
  Kontrol('Satir: mantik 0', S('AKTIF', ftBoolean, '0') = '"AKTIF" = FALSE');
  Kontrol('Satir: mantik gecersiz hata', (S('AKTIF', ftBoolean, 'belki') = '') and (Hata <> ''));
  Kontrol('Satir: birlestir yeni bos ise eski', FiltreBirlestir('A = 1', '') = 'A = 1');
end;

var
  Tanim: TBaglantiTanimi;
  Bag: TAcikBaglanti;
  Sorgu: TFDQuery;
  Hata, CiktiYolu: string;
  Oneri: TArray<string>;
begin
  Cikti := TStringList.Create;
  Hatalar := 0;
  try
    { A: saf kurallar }
    Kontrol('Bos filtre: bos', FiltreKosulu('') = '');
    Kontrol('Yalniz bosluk: bos', FiltreKosulu('   ') = '');
    Kontrol('Kosul parantez icinde', Pos('WHERE (TUTAR > 100', Trim(FiltreKosulu('TUTAR > 100'))) = 1);
    Kontrol('Basindaki WHERE atilir', Pos('WHERE (TUTAR > 100', Trim(FiltreKosulu('where TUTAR > 100'))) = 1);
    Kontrol('WHERE yazisi iki kez yok', Pos('WHERE WHERE', UpperCase(FiltreKosulu('WHERE TUTAR > 100'))) = 0);
    Kontrol('Sondaki ; atilir', Pos(';', FiltreKosulu('TUTAR > 100;')) = 0);
    Kontrol('Sondaki ; ve bosluklar atilir', Pos(';', FiltreKosulu('TUTAR > 100 ; ;  ')) = 0);
    Kontrol('Yalniz WHERE yazilirsa filtre yok', FiltreKosulu('where ') = ''); Kontrol('Yalniz WHERE (bosluksuz): filtre yok', FiltreKosulu('WHERE') = '');
    Kontrol('Yorum satiri parantezi yutmaz (satir sonu)', Pos(sLineBreak + ')', FiltreKosulu('A = 1 -- yorum')) > 0);

    HucreTestleri;
    SatirTestleri;
    Kontrol('Disa aktar: filtresiz ve siralamasiz hepsi', TabloTumSatirlarSorgusu('T') = 'SELECT * FROM "T"');
    Kontrol('Disa aktar: filtre WHERE olarak girer', Pos('WHERE (A = 1', TabloTumSatirlarSorgusu('T', 'A = 1')) > 0);
    Kontrol('Disa aktar: siralama azalan', Pos(' ORDER BY "X" DESC', TabloTumSatirlarSorgusu('T', '', 'X', True)) > 0);
    Kontrol('Veri SQL: ilk satirlar, filtre ve siralama', TabloVerisiSql('T', 100, 'X', True, 'A = 1') = 'SELECT FIRST 100 * FROM "T" WHERE (A = 1' + sLineBreak + ') ORDER BY "X" DESC');
    Kontrol('Veri SQL: filtresiz', TabloVerisiSql('T', 100, '', False, '') = 'SELECT FIRST 100 * FROM "T"');
    Kontrol('Disa aktar: filtre ve siralama birlikte, filtre once',
      Pos('WHERE', TabloTumSatirlarSorgusu('T', 'A = 1', 'X')) < Pos('ORDER BY', TabloTumSatirlarSorgusu('T', 'A = 1', 'X')));

    { B: gercek sunucu (yalniz okuma) }
    if Ortam('FBTEST_YOL', '') = '' then
      Cikti.Add('B bolumu atlandi (FBTEST_YOL yok)')
    else
    begin
      DilYukle('tr');
      Tanim.Ad := 'test';
      Tanim.Sunucu := Ortam('FBTEST_SUNUCU', 'localhost');
      Tanim.Port := StrToInt(Ortam('FBTEST_PORT', '3050'));
      Tanim.VeritabaniYolu := Ortam('FBTEST_YOL', '');
      Tanim.Kullanici := Ortam('FBTEST_KULLANICI', 'SYSDBA');
      Tanim.Sifre := Ortam('FBTEST_SIFRE', '');
      Tanim.KarakterSeti := VARSAYILAN_KARAKTER_SETI;
      Bag := FbBaglan(Tanim);
      Cikti.Add('Baglandi. Surum: ' + Bag.Surum);

      Sorgu := TabloVerisiSorgusu(Bag, 'RDB$RELATIONS', 100, nil, '', False, '');
      Kontrol('Filtresiz: 2den cok satir', Sorgu.RecordCount > 2);
      Sorgu.Free;

      Sorgu := TabloVerisiSorgusu(Bag, 'RDB$RELATIONS', 100, nil, '', False,
        'RDB$RELATION_NAME = ''RDB$RELATIONS'' OR RDB$RELATION_NAME = ''RDB$FIELDS''');
      Kontrol('OR kosulu: tam 2 satir', Sorgu.RecordCount = 2);
      Sorgu.Free;

      Sorgu := TabloVerisiSorgusu(Bag, 'RDB$RELATIONS', 100, nil, 'RDB$RELATION_NAME', False,
        'WHERE RDB$RELATION_NAME = ''RDB$RELATIONS'' OR RDB$RELATION_NAME = ''RDB$FIELDS'';');
      Kontrol('WHERE yazili ve ; sonlu filtre calisir, siralama korunur', Adlar(Sorgu) = 'RDB$FIELDS,RDB$RELATIONS');
      Sorgu.Free;

      Sorgu := TabloVerisiSorgusu(Bag, 'RDB$RELATIONS', 100, nil, 'RDB$RELATION_NAME', True,
        'RDB$RELATION_NAME = ''RDB$RELATIONS'' OR RDB$RELATION_NAME = ''RDB$FIELDS''');
      Kontrol('Azalan siralama filtreyle birlikte', Adlar(Sorgu) = 'RDB$RELATIONS,RDB$FIELDS');
      Sorgu.Free;

      Sorgu := TabloVerisiSorgusu(Bag, 'RDB$RELATIONS', 100, nil, '', False, 'RDB$RELATION_NAME = ''YOK_BOYLE_TABLO''');
      Kontrol('Hicbir satira uymayan filtre: 0 satir', Sorgu.RecordCount = 0);
      Sorgu.Free;

      Sorgu := TabloVerisiSorgusu(Bag, 'RDB$RELATIONS', 1, nil, '', False, 'RDB$RELATION_NAME STARTING WITH ''RDB$''');
      Kontrol('Satir siniri filtreyle birlikte (1 satir)', Sorgu.RecordCount = 1);
      Sorgu.Free;

      { Gercek veriden hucre filtresi: ilk satirin adi (CHAR, bosluk dolgulu) ile esit / iceren aranir. }
      Sorgu := TabloVerisiSorgusu(Bag, 'RDB$RELATIONS', 1, nil, 'RDB$RELATION_NAME', False, 'RDB$SYSTEM_FLAG = 1');
      Hata := HucreFiltresi(Sorgu.FieldByName('RDB$RELATION_NAME'), hiEsit);
      Sorgu.Free;
      Sorgu := TabloVerisiSorgusu(Bag, 'RDB$RELATIONS', 100, nil, '', False, Hata);
      Kontrol('Hucre filtresi gercek sunucuda: esit en az 1 satir', Sorgu.RecordCount >= 1);
      Sorgu.Free;
      Sorgu := TabloVerisiSorgusu(Bag, 'RDB$RELATIONS', 1, nil, 'RDB$RELATION_NAME', False, 'RDB$SYSTEM_FLAG = 1');
      Hata := FiltreBirlestir('RDB$SYSTEM_FLAG = 1', HucreFiltresi(Sorgu.FieldByName('RDB$RELATION_NAME'), hiIceren));
      Sorgu.Free;
      Sorgu := TabloVerisiSorgusu(Bag, 'RDB$RELATIONS', 100, nil, '', False, Hata);
      Kontrol('Birlesik filtre (VE) gercek sunucuda calisir', Sorgu.RecordCount >= 1);
      Sorgu.Free;

      { Yazarken oneri listesi (uSorgu.AlanDegerleri). }
      Oneri := AlanDegerleri(Bag, 'RDB$RELATIONS', 'RDB$RELATION_NAME', 'rdb$fiel', '', 10);
      Kontrol('Oneri: kucuk harfle yazilan buyuk harfli degeri bulur', (Length(Oneri) >= 1) and (Oneri[0] = 'RDB$FIELDS'));
      Oneri := AlanDegerleri(Bag, 'RDB$RELATIONS', 'RDB$RELATION_NAME', 'rdb$', '', 3);
      Kontrol('Oneri: en cok istenen adet gelir (3)', Length(Oneri) = 3);
      Oneri := AlanDegerleri(Bag, 'RDB$RELATIONS', 'RDB$RELATION_NAME', 'rdb$', '', 10);
      Kontrol('Oneri: alfabetik sirali, bosluk dolgusuz', (Length(Oneri) = 10) and (Oneri[0] <= Oneri[1]) and (Oneri[0] = Trim(Oneri[0])));
      Oneri := AlanDegerleri(Bag, 'RDB$RELATIONS', 'RDB$RELATION_NAME', 'rdb$', 'RDB$SYSTEM_FLAG = 0', 10);
      Kontrol('Oneri: diger filtre (kullanici tablolari) sistem tablolarini eler', Length(Oneri) = 0);
      Oneri := AlanDegerleri(Bag, 'RDB$RELATIONS', 'RDB$RELATION_NAME', 'o''neil', '', 10);
      Kontrol('Oneri: tirnakli yazi hata vermez, sonuc yok', Length(Oneri) = 0);

      { Kolon altindaki filtre kutusunun urettigi kosullar gercek sunucuda calisir (yalniz okuma). }
      Sorgu := TabloVerisiSorgusu(Bag, 'RDB$RELATIONS', 100, nil, '', False,
        SatirFiltresi('RDB$RELATION_NAME', ftString, 'rdb$rel*', Hata));
      Kontrol('Satir filtresi: ad* ile baslar', Sorgu.RecordCount >= 1);
      Sorgu.Free;
      Sorgu := TabloVerisiSorgusu(Bag, 'RDB$RELATIONS', 100, nil, '', False,
        FiltreBirlestir(SatirFiltresi('RDB$RELATION_NAME', ftString, 'rdb$fields', Hata),
        SatirFiltresi('RDB$SYSTEM_FLAG', ftSmallint, '1', Hata)));
      Kontrol('Satir filtresi: iceren ve sayi VE ile birlesir, tam 1 satir', Sorgu.RecordCount = 1);
      Sorgu.Free;
      Sorgu := TabloVerisiSorgusu(Bag, 'RDB$RELATIONS', 100, nil, '', False,
        SatirFiltresi('RDB$RELATION_ID', ftSmallint, '1..3', Hata));
      Kontrol('Satir filtresi: sayi arasi calisir', Sorgu.RecordCount >= 1);
      Sorgu.Free;
      Sorgu := TabloVerisiSorgusu(Bag, 'RDB$RELATIONS', 100, nil, '', False,
        SatirFiltresi('RDB$DESCRIPTION', ftString, '-', Hata));
      Kontrol('Satir filtresi: bos olanlar calisir', Sorgu.RecordCount >= 1);
      Sorgu.Free;

      Hata := '';
      try
        Sorgu := TabloVerisiSorgusu(Bag, 'RDB$RELATIONS', 100, nil, '', False, 'YOK_BOYLE_KOLON = 1');
        Sorgu.Free;
      except
        on E: Exception do
          Hata := E.Message;
      end;
      Kontrol('Hatali kosul: istisna firlar (arayuz anlasilir mesaj gosterir)', Hata <> '');
      FbBaglantiyiKes(Bag);
    end;
  except
    on E: Exception do
    begin
      Cikti.Add('BEKLENMEYEN HATA: ' + E.Message);
      Inc(Hatalar);
    end;
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
