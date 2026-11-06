program KayitDuzeltTest;

{ Asama 4d: uKayitDuzelt (gridden kayit duzeltme) testi (komut satiri).

  Gecici bir veritabani acilir (varsayilan: gomulu Firebird). Gercek veriye dokunulmaz.
  Ortam degiskenleri: FBTEST_SUNUCU (bos = gomulu), FBTEST_PORT, FBTEST_KLASOR, FBTEST_KULLANICI, FBTEST_SIFRE,
  FBTEST_CIKTI (sonuc dosyasi). Gomulu kipte biten veritabani klasorun _arsiv alt klasorune tasinir (silinmez).
  Cikis kodu: hata sayisi (0 = hepsi gecti). }

{$APPTYPE CONSOLE}

uses
  System.SysUtils, System.Classes, System.StrUtils, System.IOUtils, System.Variants, Data.DB,
  FireDAC.Stan.Intf, FireDAC.Stan.Option, FireDAC.Stan.Error, FireDAC.Comp.Client, FireDAC.Phys.FB,
  FireDAC.ConsoleUI.Wait,
  uDil, uBaglanti, uSorgu, uKayitDuzelt;

const
  { c g i(noktasiz) o s u I(noktali) }
  TURKCE = #$00E7#$011F#$0131#$00F6#$015F#$00FC#$0130;

var
  Cikti: TStringList;
  Hatalar, KontrolSayisi: Integer;
  Bag: TAcikBaglanti;
  Klasor: string;

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

{ Veritabanindan bagimsiz okuma: tek deger yazi olarak (NULL icin '<NULL>'). }
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

procedure TabloKur;
begin
  Komut('CREATE TABLE T_PK (ID INTEGER NOT NULL PRIMARY KEY, AD VARCHAR(40), SAYI NUMERIC(9,2), ' +
    'TARIH DATE, NOTU BLOB SUB_TYPE TEXT, HES COMPUTED BY (COALESCE(AD, ''-'') || ''!''), ' +
    'KOD VARCHAR(5) CHECK (KOD <> ''YASAK''))');
  Komut('CREATE TABLE T_BILESIK (A INTEGER NOT NULL, B INTEGER NOT NULL, AD VARCHAR(20), PRIMARY KEY (A, B))');
  Komut('CREATE TABLE T_PKSIZ (ID INTEGER, AD VARCHAR(20))');
  Komut('INSERT INTO T_PK (ID, AD, SAYI, TARIH, NOTU, KOD) VALUES (1, ''bir'', 1.5, ''2024-01-31'', ''not1'', ''A'')');
  Komut('INSERT INTO T_PK (ID, AD, SAYI, TARIH, NOTU, KOD) VALUES (2, ''iki'', 2.5, ''2024-02-29'', ''not2'', ''B'')');
  Komut('INSERT INTO T_PK (ID, AD, SAYI, TARIH, NOTU, KOD) VALUES (3, ''uc'', 3.5, NULL, NULL, ''C'')');
  Komut('INSERT INTO T_BILESIK VALUES (1, 1, ''a11'')');
  Komut('INSERT INTO T_BILESIK VALUES (1, 2, ''a12'')');
  Komut('INSERT INTO T_PKSIZ VALUES (1, ''x'')');
end;

procedure AnahtarTesti;
var
  Veri: TFDQuery;
  D: TKayitDuzelt;
begin
  Veri := DuzeltilebilirVeriSorgusu(Bag, 'T_PKSIZ', 100, nil);
  D := TKayitDuzelt.Create(Bag, 'T_PKSIZ', Veri, nil);
  try
    Kontrol('birincil anahtari olmayan tabloda AnahtarVar = False', not D.AnahtarVar);
  finally
    D.Free;
    Veri.Free;
  end;
  Veri := DuzeltilebilirVeriSorgusu(Bag, 'T_PK', 100, nil);
  D := TKayitDuzelt.Create(Bag, 'T_PK', Veri, nil);
  try
    Kontrol('birincil anahtarli tabloda AnahtarVar = True', D.AnahtarVar);
  finally
    D.Free;
    Veri.Free;
  end;
end;

procedure DegistirVeKaydetTesti;
var
  Veri: TFDQuery;
  D: TKayitDuzelt;
  Komutlar: TArray<string>;
  Sonuc: TDuzeltSonucu;
  DegisimSayisi: Integer;
begin
  Veri := DuzeltilebilirVeriSorgusu(Bag, 'T_PK', 100, nil);
  D := TKayitDuzelt.Create(Bag, 'T_PK', Veri, procedure begin Inc(DegisimSayisi); end);
  try
    DegisimSayisi := 0;
    D.Ac;
    Kontrol('anahtar kolonu (ID) kilitli', Veri.FieldByName('ID').ReadOnly);
    Kontrol('BLOB kolonu (NOTU) kilitli', Veri.FieldByName('NOTU').ReadOnly);
    Kontrol('hesaplanan kolon (HES) kilitli', Veri.FieldByName('HES').ReadOnly);
    Kontrol('normal kolon (AD) acik', not Veri.FieldByName('AD').ReadOnly);
    Kontrol('basta bekleyen yok', D.BekleyenSayisi = 0);

    { Ekleme ve silme engellenir. }
    try
      Veri.Insert;
      Kontrol('Insert engellenmeli', False);
    except
      on EAbort do Kontrol('Insert engellendi', True);
    end;
    try
      Veri.Delete;
      Kontrol('Delete engellenmeli', False);
    except
      on EAbort do Kontrol('Delete engellendi', True);
    end;
    Kontrol('ekleme/silme sonrasi hala 3 satir', Veri.RecordCount = 3);

    { Satir 2: metin (Turkce), sayi, NULL'a cevirme. }
    Veri.Locate('ID', 2, []);
    Veri.Edit;
    Veri.FieldByName('AD').AsString := 'yeni ' + TURKCE;
    Veri.FieldByName('SAYI').AsFloat := 99.25;
    Veri.FieldByName('TARIH').Clear;
    Veri.Post;
    Kontrol('Post sonrasi degisim bildirimi geldi', DegisimSayisi > 0);
    Kontrol('1 bekleyen satir', D.BekleyenSayisi = 1);
    Kontrol('veritabani henuz degismedi (AD)', Oku('select ad from t_pk where id = 2') = 'iki');

    Komutlar := D.OnayKomutlari;
    Kontrol('onay metni 1 komut', Length(Komutlar) = 1);
    if Length(Komutlar) = 1 then
    begin
      Cikti.Add('      ' + Komutlar[0]);
      Kontrol('onay metni UPDATE ... WHERE "ID" = 2', StartsText('UPDATE "T_PK" SET', Komutlar[0]) and
        (Pos('WHERE "ID" = 2;', Komutlar[0]) > 0));
      Kontrol('onay metni sayiyi noktayla yazar', Pos('"SAYI" = 99.25', Komutlar[0]) > 0);
      Kontrol('onay metni NULL yazar', Pos('"TARIH" = NULL', Komutlar[0]) > 0);
      Kontrol('onay metni degismeyen kolonu yazmaz', Pos('"KOD"', Komutlar[0]) = 0);
    end;

    Sonuc := D.Kaydet;
    Kontrol('Kaydet basarili', Sonuc.Basarili);
    if not Sonuc.Basarili then
      Cikti.Add('      ' + Sonuc.Cumle + ' | ' + Sonuc.Ayrinti);
    Kontrol('AD yazildi (Turkce harfler dahil)', Oku('select ad from t_pk where id = 2') = 'yeni ' + TURKCE);
    Kontrol('SAYI yazildi', StringReplace(Oku('select sayi from t_pk where id = 2'), ',', '.', []) = '99.25');
    Kontrol('TARIH NULL oldu', Oku('select tarih from t_pk where id = 2') = '<NULL>');
    Kontrol('baska satir degismedi', Oku('select ad from t_pk where id = 1') = 'bir');
    Kontrol('BLOB degismedi', Oku('select notu from t_pk where id = 2') = 'not2');
  finally
    D.Free;
    Veri.Free;
  end;
end;

procedure GeriAlTesti;
var
  Veri: TFDQuery;
  D: TKayitDuzelt;
begin
  Veri := DuzeltilebilirVeriSorgusu(Bag, 'T_PK', 100, nil);
  D := TKayitDuzelt.Create(Bag, 'T_PK', Veri, nil);
  try
    D.Ac;
    Veri.Locate('ID', 1, []);
    Veri.Edit;
    Veri.FieldByName('AD').AsString := 'degisti';
    { Post edilmemis satir da bitirilir. }
    D.SatiriBitir;
    Kontrol('GeriAl oncesi 1 bekleyen', D.BekleyenSayisi = 1);
    D.GeriAl;
    Kontrol('GeriAl sonrasi 0 bekleyen', D.BekleyenSayisi = 0);
    Kontrol('GeriAl sonrasi gridde eski deger', Veri.FieldByName('AD').AsString = 'bir');
    Kontrol('GeriAl veritabanina dokunmadi', Oku('select ad from t_pk where id = 1') = 'bir');
  finally
    D.Free;
    Veri.Free;
  end;
end;

{ Iki satirdan ikincisi CHECK'e takilir: ikisi de geri alinmali (tek islem). }
procedure HataGeriAlmaTesti;
var
  Veri: TFDQuery;
  D: TKayitDuzelt;
  Sonuc: TDuzeltSonucu;
begin
  Veri := DuzeltilebilirVeriSorgusu(Bag, 'T_PK', 100, nil);
  D := TKayitDuzelt.Create(Bag, 'T_PK', Veri, nil);
  try
    D.Ac;
    Veri.Locate('ID', 1, []);
    Veri.Edit;
    Veri.FieldByName('AD').AsString := 'ILK_YAZILMAMALI';
    Veri.Post;
    Veri.Locate('ID', 3, []);
    Veri.Edit;
    Veri.FieldByName('KOD').AsString := 'YASAK';
    Veri.Post;
    Sonuc := D.Kaydet;
    Kontrol('CHECK hatasinda Kaydet basarisiz', not Sonuc.Basarili);
    Kontrol('hata cumlesi var', Sonuc.Cumle <> '');
    Kontrol('ilk satir da geri alindi (tek islem)', Oku('select ad from t_pk where id = 1') = 'bir');
    Kontrol('degisiklikler gridde bekliyor', D.BekleyenSayisi = 2);
  finally
    D.Free;
    Veri.Free;
  end;
end;

{ Kayit baska biri tarafindan silinmisse 0 satir etkilenir: hicbir sey kaydedilmemeli. }
procedure SilinmisKayitTesti;
var
  Veri: TFDQuery;
  D: TKayitDuzelt;
  Sonuc: TDuzeltSonucu;
begin
  Veri := DuzeltilebilirVeriSorgusu(Bag, 'T_PK', 100, nil);
  D := TKayitDuzelt.Create(Bag, 'T_PK', Veri, nil);
  try
    D.Ac;
    Veri.Locate('ID', 3, []);
    Veri.Edit;
    Veri.FieldByName('AD').AsString := 'silinmis';
    Veri.Post;
    Veri.Locate('ID', 1, []);
    Veri.Edit;
    Veri.FieldByName('AD').AsString := 'bir_yeni';
    Veri.Post;
    Komut('DELETE FROM T_PK WHERE ID = 3');
    Sonuc := D.Kaydet;
    Kontrol('silinmis kayitta Kaydet basarisiz', not Sonuc.Basarili);
    Kontrol('satir sayisi hatasi aciklayici', Pos('1', Sonuc.Cumle) > 0);
    Kontrol('digeri de yazilmadi', Oku('select ad from t_pk where id = 1') = 'bir');
  finally
    D.Free;
    Veri.Free;
  end;
end;

procedure BilesikAnahtarTesti;
var
  Veri: TFDQuery;
  D: TKayitDuzelt;
  Sonuc: TDuzeltSonucu;
begin
  Veri := DuzeltilebilirVeriSorgusu(Bag, 'T_BILESIK', 100, nil);
  D := TKayitDuzelt.Create(Bag, 'T_BILESIK', Veri, nil);
  try
    D.Ac;
    Kontrol('bilesik anahtarin iki kolonu da kilitli',
      Veri.FieldByName('A').ReadOnly and Veri.FieldByName('B').ReadOnly);
    Veri.Locate('A;B', VarArrayOf([1, 2]), []);
    Veri.Edit;
    Veri.FieldByName('AD').AsString := 'yeni12';
    Veri.Post;
    Sonuc := D.Kaydet;
    Kontrol('bilesik anahtar Kaydet basarili', Sonuc.Basarili);
    Kontrol('yalniz (1,2) degisti', Oku('select ad from t_bilesik where a = 1 and b = 2') = 'yeni12');
    Kontrol('(1,1) degismedi', Oku('select ad from t_bilesik where a = 1 and b = 1') = 'a11');
  finally
    D.Free;
    Veri.Free;
  end;
end;

{ Yeni kayit: dugmeyle eklenir, bos kolonlar INSERT'e girmez (DEFAULT), anahtar yeni kayitta yazilabilir. }
procedure EklemeTesti;
var
  Veri: TFDQuery;
  D: TKayitDuzelt;
  Komutlar: TArray<string>;
  Sonuc: TDuzeltSonucu;
begin
  Komut('CREATE TABLE T_EKLE (ID INTEGER NOT NULL PRIMARY KEY, AD VARCHAR(20), DURUM VARCHAR(5) DEFAULT ''YENI'', ' +
    'KOD VARCHAR(5) NOT NULL)');
  Komut('INSERT INTO T_EKLE (ID, AD, KOD) VALUES (1, ''bir'', ''K1'')');
  Veri := DuzeltilebilirVeriSorgusu(Bag, 'T_EKLE', 100, nil);
  D := TKayitDuzelt.Create(Bag, 'T_EKLE', Veri, nil);
  try
    D.Ac;
    D.YeniKayit;
    Kontrol('yeni kayitta anahtar yazilabilir', not Veri.FieldByName('ID').ReadOnly);
    Veri.FieldByName('ID').AsInteger := 10;
    Veri.FieldByName('AD').AsString := 'yeni ' + TURKCE;
    Veri.FieldByName('KOD').AsString := 'K2';
    Veri.Post;
    Kontrol('yeni kayit 1 bekleyen', D.BekleyenSayisi = 1);
    Veri.Locate('ID', 1, []);
    Kontrol('mevcut kayitta anahtar yine kilitli', Veri.FieldByName('ID').ReadOnly);
    Komutlar := D.OnayKomutlari;
    Kontrol('onay metni 1 INSERT', (Length(Komutlar) = 1) and StartsText('INSERT INTO "T_EKLE" ("ID", "AD", "KOD")', Komutlar[0]));
    if Length(Komutlar) = 1 then
      Kontrol('INSERT bos DURUM kolonunu yazmaz', Pos('"DURUM"', Komutlar[0]) = 0);
    Sonuc := D.Kaydet;
    Kontrol('INSERT Kaydet basarili', Sonuc.Basarili);
    if not Sonuc.Basarili then
      Cikti.Add('      ' + Sonuc.Cumle + ' | ' + Sonuc.Ayrinti);
    Kontrol('yeni kayit yazildi', Oku('select ad from t_ekle where id = 10') = 'yeni ' + TURKCE);
    Kontrol('DEFAULT calisti', Oku('select durum from t_ekle where id = 10') = 'YENI');
    Kontrol('toplam 2 kayit', Oku('select count(*) from t_ekle') = '2');
  finally
    D.Free;
    Veri.Free;
  end;
  { Zorunlu kolon (KOD) bos: Firebird reddeder, hicbir sey eklenmez. }
  Veri := DuzeltilebilirVeriSorgusu(Bag, 'T_EKLE', 100, nil);
  D := TKayitDuzelt.Create(Bag, 'T_EKLE', Veri, nil);
  try
    D.Ac;
    D.YeniKayit;
    Veri.FieldByName('ID').AsInteger := 11;
    Veri.Post;
    Sonuc := D.Kaydet;
    Kontrol('NOT NULL kolon bos: Kaydet basarisiz', not Sonuc.Basarili);
    Kontrol('hicbir sey eklenmedi', Oku('select count(*) from t_ekle') = '2');
    D.GeriAl;
    Kontrol('GeriAl yeni satiri atar', (D.BekleyenSayisi = 0) and (Veri.RecordCount = 2));
  finally
    D.Free;
    Veri.Free;
  end;
end;

{ Birden cok ekleme + duzenleme bellekte birikir; veritabani Kaydet'e kadar degismez, sonra hepsi tek islemde yazilir. }
procedure CokluTesti;
var
  Veri: TFDQuery;
  D: TKayitDuzelt;
  Sonuc: TDuzeltSonucu;
begin
  Komut('CREATE TABLE T_COKLU (ID INTEGER NOT NULL PRIMARY KEY, AD VARCHAR(20))');
  Komut('INSERT INTO T_COKLU VALUES (1, ''bir'')');
  Komut('INSERT INTO T_COKLU VALUES (2, ''iki'')');
  Veri := DuzeltilebilirVeriSorgusu(Bag, 'T_COKLU', 100, nil);
  D := TKayitDuzelt.Create(Bag, 'T_COKLU', Veri, nil);
  try
    D.Ac;
    D.YeniKayit;
    Veri.FieldByName('ID').AsInteger := 10;
    Veri.FieldByName('AD').AsString := 'on';
    Veri.Post;
    Kontrol('1. ekleme sonrasi veritabaninda hala 2 kayit', Oku('select count(*) from t_coklu') = '2');
    D.YeniKayit;
    Veri.FieldByName('ID').AsInteger := 11;
    Veri.FieldByName('AD').AsString := 'onbir';
    Veri.Post;
    Kontrol('2. ekleme sonrasi veritabaninda hala 2 kayit', Oku('select count(*) from t_coklu') = '2');
    Veri.Locate('ID', 1, []);
    Veri.Edit;
    Veri.FieldByName('AD').AsString := 'bir_yeni';
    Veri.Post;
    Kontrol('duzenleme sonrasi veritabani hala eski', Oku('select ad from t_coklu where id = 1') = 'bir');
    Kontrol('3 bekleyen (2 ekleme + 1 duzenleme)', D.BekleyenSayisi = 3);
    Kontrol('onay metni 3 komut', Length(D.OnayKomutlari) = 3);
    Sonuc := D.Kaydet;
    Kontrol('toplu Kaydet basarili', Sonuc.Basarili);
    if not Sonuc.Basarili then
      Cikti.Add('      ' + Sonuc.Cumle + ' | ' + Sonuc.Ayrinti);
    Kontrol('hepsi yazildi: 4 kayit', Oku('select count(*) from t_coklu') = '4');
    Kontrol('duzenleme yazildi', Oku('select ad from t_coklu where id = 1') = 'bir_yeni');
  finally
    D.Free;
    Veri.Free;
  end;
end;

procedure DilAnahtarTesti;
const
  Anahtarlar: array[0..14] of string = ('BTN_YENI_KAYIT', 'BTN_DUZENLE', 'BTN_DUZ_BITIR', 'BTN_GERI_AL', 'LBL_DUZ_DURUM',
    'ONAY_DUZ_ATIL', 'ONAY_DUZ_KAYDET', 'MSG_DUZ_DAHA_FAZLA', 'MSG_DUZ_DEGISIKLIK_YOK', 'MSG_DUZ_VAZGECILDI',
    'MSG_DUZ_TAMAM', 'ERR_DUZ_UYGULANAMADI', 'MSG_DUZ_GERI_ALINDI', 'ERR_DUZ_ANAHTAR_YOK', 'ERR_DUZ_SATIR_SAYISI');
var
  Dil, Anahtar: string;
  Eksik: string;
begin
  for Dil in ['tr', 'en', 'de'] do
  begin
    DilYukle(Dil);
    Eksik := '';
    for Anahtar in Anahtarlar do
      if T(Anahtar) = Anahtar then
        Eksik := Eksik + ' ' + Anahtar;
    Kontrol('dil ' + Dil + ': 4d anahtarlari tam' + IfThen(Eksik <> '', ' (eksik:' + Eksik + ')'), Eksik = '');
  end;
  DilYukle('tr');
  Kontrol('KomutOzeti 12 komutu keser',
    Pos('2', KomutOzeti(['a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i', 'j', 'k', 'l'])) > 0);
end;

var
  Tanim: TBaglantiTanimi;
  Dosya: string;
  Gomulu: Boolean;
begin
  Cikti := TStringList.Create;
  Bag := nil;
  try
    try
      DilYukle('tr');
      Gomulu := Ortam('FBTEST_SUNUCU', '') = '';
      Klasor := Ortam('FBTEST_KLASOR', TPath.Combine(GetEnvironmentVariable('TEMP'), 'duzelttest'));
      if Gomulu then
        ForceDirectories(Klasor);
      Tanim := Default(TBaglantiTanimi);
      Tanim.Ad := 'duzelttest';
      Tanim.Sunucu := Ortam('FBTEST_SUNUCU', '');
      Tanim.Port := StrToInt(Ortam('FBTEST_PORT', '3050'));
      Tanim.VeritabaniYolu := IncludeTrailingPathDelimiter(Klasor) + 'duzelttest_' +
        FormatDateTime('yyyymmdd_hhnnss', Now) + '.fdb';
      Tanim.Kullanici := Ortam('FBTEST_KULLANICI', 'SYSDBA');
      Tanim.Sifre := Ortam('FBTEST_SIFRE', '');
      Tanim.KarakterSeti := VARSAYILAN_KARAKTER_SETI;
      GeciciVeritabaniOlustur(Tanim);
      Bag := FbBaglan(Tanim);
      Cikti.Add('--- Surum ' + Bag.Surum + ', veritabani: ' + Tanim.VeritabaniYolu + ' ---');
      TabloKur;
      Cikti.Add('--- Anahtar ---');
      AnahtarTesti;
      Cikti.Add('--- Degistir ve kaydet ---');
      DegistirVeKaydetTesti;
      Cikti.Add('--- Geri al ---');
      GeriAlTesti;
      Cikti.Add('--- Hata: hepsi geri alinir ---');
      HataGeriAlmaTesti;
      Cikti.Add('--- Silinmis kayit ---');
      SilinmisKayitTesti;
      Cikti.Add('--- Bilesik anahtar ---');
      BilesikAnahtarTesti;
      Cikti.Add('--- Yeni kayit ---');
      EklemeTesti;
      Cikti.Add('--- Coklu ---');
      CokluTesti;
      Cikti.Add('--- Dil anahtarlari ---');
      DilAnahtarTesti;
      FbBaglantiyiKes(Bag);
      Bag := nil;
      if Gomulu then
      begin
        ForceDirectories(TPath.Combine(Klasor, '_arsiv'));
        Dosya := Tanim.VeritabaniYolu;
        if FileExists(Dosya) then
          TFile.Move(Dosya, TPath.Combine(TPath.Combine(Klasor, '_arsiv'), ExtractFileName(Dosya)));
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
