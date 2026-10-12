program SorguTest;

{ Asama 2b Adim 4 + 2c Adim 2: uSorgu testleri (komut satiri). Once veritabanisiz kontroller
  (KomutlaraBol, TehlikeliSorguUyarisi, KomutTuruBul, TabloAdiniBul), sonra GECICI bir
  veritabaninda SorguCalistir, hata cumleleri, sorgu plani ve BetikCalistir denenir.
  Gecici tablolar SORGUTEST_T ve SORGUTEST_C'dir, sonunda DROP edilir. Gercek veriye dokunmaz.

  Ortam degiskenleri: FBTEST_SUNUCU (bos = gomulu), FBTEST_PORT, FBTEST_YOL (GECICI bir test
  veritabani), FBTEST_KULLANICI, FBTEST_SIFRE, FBTEST_CIKTI (sonuc dosyasi).
  FBTEST_YOL verilmezse sadece veritabanisiz kontroller calisir.
  Cikis kodu: hata sayisi (0 = hepsi gecti). }

{$APPTYPE CONSOLE}

uses
  System.SysUtils, System.Classes, System.Generics.Collections, Data.DB,
  FireDAC.Stan.Error, FireDAC.Comp.Client, FireDAC.Phys.FB,
  uDil, uBaglanti, uSorgu;

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

{ Parcalarin birlesimi: "[a][b]" biciminde, kontrolu kolaylastirir. }
function Birlestir(const Parcalar: TArray<string>): string;
var
  P: string;
begin
  Result := '';
  for P in Parcalar do
    Result := Result + '[' + P + ']';
end;

procedure BolmeKontrol(const Ad, Metin, Beklenen: string);
var
  Gelen: string;
begin
  Gelen := Birlestir(KomutlaraBol(Metin));
  Kontrol('KomutlaraBol: ' + Ad, Gelen = Beklenen);
  if Gelen <> Beklenen then
    Cikti.Add('      gelen: ' + Gelen);
end;

procedure VeritabanisizTestler;
begin
  Cikti.Add('--- KomutlaraBol ---');
  BolmeKontrol('basit ;', 'select 1 from rdb$database; select 2 from rdb$database;',
    '[select 1 from rdb$database][select 2 from rdb$database]');
  BolmeKontrol('son satirda ; yok', 'a;b', '[a][b]');
  BolmeKontrol('bos komutlar atilir', ';; a ;  ; b;;', '[a][b]');
  BolmeKontrol('sadece yorum komut degil', '-- merhaba' + #10 + 'a; /* x */ ; b', '[-- merhaba' + #10 + 'a][b]');
  BolmeKontrol('tirnak icinde ;', 'insert into t values (''a;b''); select "x;y" from t',
    '[insert into t values (''a;b'')][select "x;y" from t]');
  BolmeKontrol('yorum icinde ;', 'a -- x;y' + #10 + '; b /* ; */', '[a -- x;y][b /* ; */]');
  BolmeKontrol('iki katli tirnak', 'select ''it''''s;ok'' from t; b', '[select ''it''''s;ok'' from t][b]');
  BolmeKontrol('SET TERM ile prosedur',
    'SET TERM ^ ;' + #10 + 'CREATE PROCEDURE P AS BEGIN x = 1; y = 2; END^' + #10 + 'SET TERM ; ^' + #10 +
    'select 1 from rdb$database;',
    '[CREATE PROCEDURE P AS BEGIN x = 1; y = 2; END][select 1 from rdb$database]');
  BolmeKontrol('SET TERM kucuk harf, ^ bitisik', 'set term ^;create procedure p as begin x=1; end^set term ;^ a;',
    '[create procedure p as begin x=1; end][a]');
  BolmeKontrol('hic komut yok', '  ' + #10 + ' ; -- sadece yorum', '');
  BolmeKontrol('bos yazi', '', '');

  Cikti.Add('--- TehlikeliSorguUyarisi ---');
  Kontrol('DROP TABLE', TehlikeliSorguUyarisi('drop table t') = 'ONAY_SORGU_DROP');
  Kontrol('ALTER TABLE DROP', TehlikeliSorguUyarisi('alter table t drop kolon') = 'ONAY_SORGU_DROP');
  Kontrol('WHERE''siz DELETE', TehlikeliSorguUyarisi('delete from t') = 'ONAY_SORGU_WHERE_YOK');
  Kontrol('WHERE''siz UPDATE', TehlikeliSorguUyarisi('update t set a = 1') = 'ONAY_SORGU_WHERE_YOK');
  Kontrol('WHERE''li DELETE', TehlikeliSorguUyarisi('delete from t where id = 1') = '');
  Kontrol('WHERE''li UPDATE', TehlikeliSorguUyarisi('update t set a = 1 where id = 1') = '');
  Kontrol('UPDATE OR INSERT uyari vermez', TehlikeliSorguUyarisi('update or insert into t (id) values (1)') = '');
  Kontrol('yazi icinde drop', TehlikeliSorguUyarisi('select ''drop table x'' from t') = '');
  Kontrol('yorum icinde drop', TehlikeliSorguUyarisi('select 1 from t -- drop table x') = '');
  Kontrol('SELECT', TehlikeliSorguUyarisi('select * from t') = '');

  Cikti.Add('--- KomutTuruBul ---');
  Kontrol('commit', KomutTuruBul('commit') = ktCommit);
  Kontrol('COMMIT WORK', KomutTuruBul('  COMMIT WORK') = ktCommit);
  Kontrol('rollback', KomutTuruBul('rollback') = ktRollback);
  Kontrol('SET SQL DIALECT', KomutTuruBul('SET SQL DIALECT 3') = ktIsql);
  Kontrol('SET NAMES', KomutTuruBul('set names win1254') = ktIsql);
  Kontrol('CONNECT', KomutTuruBul('connect ''x.fdb''') = ktIsql);
  Kontrol('SET GENERATOR normal', KomutTuruBul('set generator g to 5') = ktNormal);
  Kontrol('SELECT normal', KomutTuruBul('select 1 from rdb$database') = ktNormal);

  Cikti.Add('--- TabloAdiniBul ---');
  Kontrol('takma ad', TabloAdiniBul('select m. from musteri m', 'm') = 'MUSTERI');
  Kontrol('AS ile takma ad', TabloAdiniBul('select m. from musteri as m where 1=1', 'M') = 'MUSTERI');
  Kontrol('tablo adi dogrudan', TabloAdiniBul('select musteri. from musteri', 'musteri') = 'MUSTERI');
  Kontrol('JOIN takma adi', TabloAdiniBul('select s. from musteri m join siparis s on s.mid = m.id', 's') = 'SIPARIS');
  Kontrol('LEFT JOIN takma adi', TabloAdiniBul('select x. from a left join b x on 1=1', 'x') = 'B');
  Kontrol('WHERE takma ad sayilmaz', TabloAdiniBul('select musteri. from musteri where 1=1', 'where') = 'WHERE');
  Kontrol('FROM yok: ad tablo sayilir', TabloAdiniBul('select m.', 'm') = 'M');
  Kontrol('tirnakli tablo adi', TabloAdiniBul('select m. from "Musteri" m', 'm') = 'Musteri');
  Kontrol('imlecten sonraki FROM', TabloAdiniBul('select a, m. ' + #10 + ' from  musteri   m', 'm') = 'MUSTERI');
end;

procedure SatirSayisi(const Sql: string; Beklenen: Integer; const Ad: string);
var
  S: TSorguSonucu;
begin
  S := SorguCalistir(Bag, Sql);
  try
    Kontrol(Ad, S.SatirVar and (S.Sorgu.Fields[0].AsInteger = Beklenen));
  finally
    S.Free;
  end;
end;

function HataCumlesi(const Sql: string): string;
begin
  Result := '';
  try
    SorguCalistir(Bag, Sql).Free;
  except
    on E: Exception do
      Result := HataMetniniCevir(E);
  end;
end;

procedure BirakDene(const Sql: string; Yaz: Boolean);
begin
  try
    SorguCalistir(Bag, Sql).Free;
  except
    on E: Exception do
      if Yaz then
        Cikti.Add('      temizlik: ' + Sql + ' -> ' + E.Message);
  end;
end;

procedure Temizle(Yaz: Boolean);
begin
  BirakDene('DROP PROCEDURE SORGUTEST_P', Yaz);
  BirakDene('DROP TABLE SORGUTEST_C', Yaz);
  BirakDene('DROP TABLE SORGUTEST_T', Yaz);
end;

{ Hata sirasindaki Firebird hata kodlari ve cumle: "[kod:tur ...] cumle". Adim 2 olcumu icin. }
function KodluHata(const Sql: string): string;
var
  i: Integer;
begin
  Result := 'hata yok';
  try
    SorguCalistir(Bag, Sql).Free;
  except
    on E: Exception do
    begin
      Result := '';
      if E is EFDDBEngineException then
        for i := 0 to EFDDBEngineException(E).ErrorCount - 1 do
          Result := Result + '[' + IntToStr(EFDDBEngineException(E).Errors[i].ErrorCode) + ':' +
            IntToStr(Ord(EFDDBEngineException(E).Errors[i].Kind)) + ']';
      Result := Result + ' ' + HataMetniniCevir(E);
    end;
  end;
end;

procedure KilitTablosuKur;
begin
  BirakDene('DROP TABLE SORGUTEST_K', False);
  SorguCalistir(Bag, 'CREATE TABLE SORGUTEST_K (ID INTEGER NOT NULL PRIMARY KEY, YAZI VARCHAR(40))').Free;
  SorguCalistir(Bag,
    'EXECUTE BLOCK AS DECLARE I INTEGER = 1; BEGIN WHILE (I <= 1200) DO BEGIN ' +
    'INSERT INTO SORGUTEST_K VALUES (:I, ''satir '' || :I); I = I + 1; END END').Free;
end;

{ Adim 2: acik SELECT sonucu tabloyu kilitliyor mu? Olcum (5.0.4 gomulu): acik SELECT varken DROP
  "object ... is in use" ile reddedilir; ALTER ADD, CREATE INDEX ve DML gecer. Hata listesinde
  isc_obj_in_use kodu yoktur, bu yuzden cumle mesaj metninden secilir (bkz. HataMetniniCevir). }
procedure KilitTestleri;
var
  A, S: TSorguSonucu;
  Kayitlar: TList<TKomutKaydi>;
  Gelen: string;
begin
  Cikti.Add('--- Acik SELECT ve nesne kilidi (Adim 2) ---');
  KilitTablosuKur;
  A := SorguCalistir(Bag, 'select * from SORGUTEST_K order by ID');
  Gelen := KodluHata('drop table SORGUTEST_K');
  Cikti.Add('      A acik, drop table: ' + Gelen);
  Kontrol('acik SELECT varken DROP: nesne kullanimda cumlesi', Pos(T('ERR_NESNE_KULLANIMDA'), Gelen) > 0);
  Kontrol('acik SELECT varken DROP: kayit kilidi cumlesi DEGIL', Pos(T('ERR_KILIT'), Gelen) = 0);
  Kontrol('acik SELECT varken ALTER ADD gecer', KodluHata('alter table SORGUTEST_K add C integer') = 'hata yok');
  Kontrol('acik SELECT varken CREATE INDEX gecer',
    KodluHata('create index SORGUTEST_K_I on SORGUTEST_K (YAZI)') = 'hata yok');
  Kontrol('acik SELECT varken INSERT gecer',
    KodluHata('insert into SORGUTEST_K (ID, YAZI) values (5000, ''x'')') = 'hata yok');
  Kontrol('acik SELECT varken UPDATE gecer', KodluHata('update SORGUTEST_K set YAZI = ''y'' where ID = 1') = 'hata yok');
  Kontrol('acik SELECT varken DELETE gecer', KodluHata('delete from SORGUTEST_K where ID = 5000') = 'hata yok');
  A.Free;
  Kontrol('sonuc birakilinca DROP gecer', KodluHata('drop table SORGUTEST_K') = 'hata yok');

  Kayitlar := TList<TKomutKaydi>.Create;
  try
    KilitTablosuKur;
    S := BetikCalistir(Bag, KomutlaraBol('select * from SORGUTEST_K; drop table SORGUTEST_K'), Kayitlar);
    Kontrol('betik select; drop: 2 komut da calisti', (Kayitlar.Count = 2) and (Kayitlar[1].Durum = kdCalisti));
    Kontrol('betik select; drop: onceki sonuc kapatildi kaydi', (Kayitlar.Count = 2) and Kayitlar[1].OncekiSonucKapandi);
    Kontrol('betik select; drop: izgarada tutulan sonuc yok', S = nil);
    S.Free;

    KilitTablosuKur;
    Kayitlar.Clear;
    S := BetikCalistir(Bag, KomutlaraBol('select * from SORGUTEST_K; ' +
      'insert into SORGUTEST_K (ID, YAZI) values (6000, ''x''); update SORGUTEST_K set YAZI = ''z'' where ID = 6000; ' +
      'delete from SORGUTEST_K where ID = 6000'), Kayitlar);
    Kontrol('betik select + DML: 4 komut calisti', (Kayitlar.Count = 4) and (Kayitlar[3].Durum = kdCalisti));
    Kontrol('betik select + DML: sonuc izgarada kalir, kapatma yok', (S <> nil) and
      not Kayitlar[1].OncekiSonucKapandi and not Kayitlar[2].OncekiSonucKapandi and not Kayitlar[3].OncekiSonucKapandi);
    S.Free;

    Kayitlar.Clear;
    S := BetikCalistir(Bag, KomutlaraBol('select * from SORGUTEST_K; alter table SORGUTEST_K add D integer; ' +
      'select * from SORGUTEST_K'), Kayitlar);
    Kontrol('betik select; alter; select: kapatma sadece 2. komutta', (Kayitlar.Count = 3) and
      Kayitlar[1].OncekiSonucKapandi and not Kayitlar[2].OncekiSonucKapandi and (S <> nil));
    S.Free;
  finally
    Kayitlar.Free;
  end;
  BirakDene('DROP TABLE SORGUTEST_K', False);
end;

procedure VeritabaniTestleri;
var
  S: TSorguSonucu;
  Say: Integer;
  Plan: string;
  Kayitlar: TList<TKomutKaydi>;
  Komutlar: TArray<string>;
begin
  Cikti.Add('--- Veritabani: surum ' + Bag.Surum + ' ---');
  Temizle(False);
  SorguCalistir(Bag, 'CREATE TABLE SORGUTEST_T (ID INTEGER NOT NULL PRIMARY KEY, YAZI VARCHAR(40))').Free;
  SorguCalistir(Bag, 'CREATE TABLE SORGUTEST_C (ID INTEGER NOT NULL PRIMARY KEY, ' +
    'TID INTEGER REFERENCES SORGUTEST_T(ID))').Free;
  SorguCalistir(Bag,
    'EXECUTE BLOCK AS DECLARE I INTEGER = 1; BEGIN WHILE (I <= 1200) DO BEGIN ' +
    'INSERT INTO SORGUTEST_T VALUES (:I, ''satir '' || :I); I = I + 1; END END').Free;

  Cikti.Add('--- SorguCalistir ---');
  S := SorguCalistir(Bag, 'select * from SORGUTEST_T order by ID');
  try
    Kontrol('SELECT: ilk parca 500 satir', S.SatirVar and (S.Sorgu.RecordCount = SATIR_PARCASI));
    Say := 0;
    while not S.Sorgu.Eof do
    begin
      Inc(Say);
      S.Sorgu.Next;
    end;
    Kontrol('SELECT: sonuna gidince 1200 satir (RecordCount=' + IntToStr(S.Sorgu.RecordCount) + ')',
      (Say = 1200) and (S.Sorgu.RecordCount = 1200));
  finally
    S.Free;
  end;
  S := SorguCalistir(Bag, 'insert into SORGUTEST_T values (5000, ''yeni'')');
  Kontrol('INSERT: Etkilenen = 1', (not S.SatirVar) and (S.Etkilenen = 1));
  S.Free;
  S := SorguCalistir(Bag, 'update SORGUTEST_T set YAZI = ''x'' where ID <= 10');
  Kontrol('UPDATE: Etkilenen = 10', (not S.SatirVar) and (S.Etkilenen = 10));
  S.Free;
  S := SorguCalistir(Bag, 'create table SORGUTEST_D (A integer)');
  Kontrol('DDL: satir yok', not S.SatirVar);
  S.Free;
  SatirSayisi('select count(*) from rdb$relations where rdb$relation_name = ''SORGUTEST_D''', 1, 'DDL kalici (tablo olustu)');
  SorguCalistir(Bag, 'drop table SORGUTEST_D').Free;
  SatirSayisi('select count(*) from SORGUTEST_T', 1201, 'INSERT kalici (1201 satir)');

  Cikti.Add('--- Hata cumleleri ---');
  Kontrol('benzersiz ihlali', HataCumlesi('insert into SORGUTEST_T values (1, ''a'')') = T('ERR_SQL_BENZERSIZ'));
  Kontrol('yabanci anahtar', HataCumlesi('insert into SORGUTEST_C values (1, 999999)') = T('ERR_SQL_YABANCI_ANAHTAR'));
  Kontrol('nesne yok', Pos(T('ERR_SQL_NESNE_YOK'), HataCumlesi('select * from OLMAYAN_TABLO_X')) = 1);
  Kontrol('yazim hatasi', HataCumlesi('selec 1 from rdb$database') = T('ERR_SQL_SOZDIZIMI'));
  Cikti.Add('      yazim hatasi cumlesi: ' + HataCumlesi('selec 1 from rdb$database'));
  Cikti.Add('      nesne yok cumlesi: ' + HataCumlesi('select * from OLMAYAN_TABLO_X'));

  Cikti.Add('--- Sorgu plani ---');
  Plan := SorguPlaniAl(Bag, 'select * from SORGUTEST_T where ID = 5');
  Kontrol('SELECT plani geliyor: ' + StringReplace(Plan, sLineBreak, ' | ', [rfReplaceAll]), Plan <> '');
  SorguPlaniAl(Bag, 'insert into SORGUTEST_T values (6000, ''plan'')');
  SatirSayisi('select count(*) from SORGUTEST_T where ID = 6000', 0, 'INSERT plani satir eklemedi');
  SorguPlaniAl(Bag, 'update SORGUTEST_T set YAZI = ''plan'' where ID = 5000');
  SatirSayisi('select count(*) from SORGUTEST_T where YAZI = ''plan''', 0, 'UPDATE plani veriyi degistirmedi');
  SorguPlaniAl(Bag, 'delete from SORGUTEST_T');
  SatirSayisi('select count(*) from SORGUTEST_T', 1201, 'DELETE plani satir silmedi');

  Cikti.Add('--- Coklu komut (BetikCalistir) ---');
  Kayitlar := TList<TKomutKaydi>.Create;
  try
    Komutlar := KomutlaraBol('insert into SORGUTEST_C values (1, 1); insert into SORGUTEST_C values (2, 2); ' +
      'select count(*) from SORGUTEST_C');
    S := BetikCalistir(Bag, Komutlar, Kayitlar);
    Kontrol('3 komut: 3 kayit, hepsi calisti', (Kayitlar.Count = 3) and (Kayitlar[0].Durum = kdCalisti) and
      (Kayitlar[1].Durum = kdCalisti) and (Kayitlar[2].Durum = kdCalisti));
    Kontrol('3 komut: son SELECT sonucu doner (2)', (S <> nil) and (S.Sorgu.Fields[0].AsInteger = 2));
    S.Free;

    Kayitlar.Clear;
    Komutlar := KomutlaraBol('insert into SORGUTEST_C values (3, 3); insert into SORGUTEST_C values (3, 3); ' +
      'insert into SORGUTEST_C values (4, 4)');
    S := BetikCalistir(Bag, Komutlar, Kayitlar);
    Kontrol('ortada hata: 2 kayit, 2. kayit hata', (Kayitlar.Count = 2) and (Kayitlar[1].Durum = kdHata));
    Kontrol('ortada hata: hata cumlesi benzersiz', (Kayitlar.Count = 2) and (Kayitlar[1].Hata = T('ERR_SQL_BENZERSIZ')));
    Kontrol('ortada hata: SELECT yok, sonuc nil', S = nil);
    SatirSayisi('select count(*) from SORGUTEST_C where ID = 4', 0, 'ortada hata: 3. komut calismadi');
    SatirSayisi('select count(*) from SORGUTEST_C where ID = 3', 1, 'ortada hata: 1. komut geri alinmadi (kalici)');

    Kayitlar.Clear;
    Komutlar := KomutlaraBol('insert into SORGUTEST_C values (10, 1); commit; insert into SORGUTEST_C values (11, 1)');
    S := BetikCalistir(Bag, Komutlar, Kayitlar);
    Kontrol('COMMIT atlanir, digerleri calisir', (Kayitlar.Count = 3) and (Kayitlar[1].Durum = kdAtlandi) and
      (Kayitlar[1].Tur = ktCommit) and (Kayitlar[2].Durum = kdCalisti));

    Kayitlar.Clear;
    Komutlar := KomutlaraBol('insert into SORGUTEST_C values (20, 1); rollback; insert into SORGUTEST_C values (21, 1)');
    S := BetikCalistir(Bag, Komutlar, Kayitlar);
    Kontrol('ROLLBACK durdurur (2 kayit, 2. durdu)', (Kayitlar.Count = 2) and (Kayitlar[1].Durum = kdDurdu));
    SatirSayisi('select count(*) from SORGUTEST_C where ID = 20', 1, 'ROLLBACK: 1. komut kalici');
    SatirSayisi('select count(*) from SORGUTEST_C where ID = 21', 0, 'ROLLBACK: 3. komut calismadi');

    Kayitlar.Clear;
    Komutlar := KomutlaraBol('SET SQL DIALECT 3; select 1 from rdb$database');
    S := BetikCalistir(Bag, Komutlar, Kayitlar);
    Kontrol('isql komutu atlanir, sonrasi calisir', (Kayitlar.Count = 2) and (Kayitlar[0].Durum = kdAtlandi) and
      (Kayitlar[0].Tur = ktIsql) and (S <> nil));
    S.Free;

    Kayitlar.Clear;
    Komutlar := KomutlaraBol('SET TERM ^ ;' + #10 +
      'create procedure SORGUTEST_P returns (R integer) as begin R = 7; suspend; end^' + #10 +
      'SET TERM ; ^' + #10 + 'select R from SORGUTEST_P');
    S := BetikCalistir(Bag, Komutlar, Kayitlar);
    Kontrol('SET TERM betigi: prosedur olustu ve calisti', (S <> nil) and (Kayitlar.Count = 2) and
      (S.Sorgu.Fields[0].AsInteger = 7));
    S.Free;
  finally
    Kayitlar.Free;
  end;

  KilitTestleri;
  Temizle(True);
end;

{ Gomulu kipte (sunucu bos) veritabani dosyasi yoksa olusturur; boylece gecici bir test
  veritabani icin elle hazirlik gerekmez. Sunucu doluysa hicbir sey yapmaz. }
procedure GeciciVeritabaniOlustur(const Tanim: TBaglantiTanimi);
var
  Surucu: TFDPhysFBDriverLink;
  Baglanti: TFDConnection;
begin
  if (Tanim.Sunucu <> '') or FileExists(Tanim.VeritabaniYolu) then
    Exit;
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

var
  Tanim: TBaglantiTanimi;
  Dosya: string;
begin
  Cikti := TStringList.Create;
  try
    try
      DilYukle('tr');
      VeritabanisizTestler;
      if Ortam('FBTEST_YOL', '') <> '' then
      begin
        Tanim.Ad := 'sorgutest';
        Tanim.Sunucu := Ortam('FBTEST_SUNUCU', '');
        Tanim.Port := StrToInt(Ortam('FBTEST_PORT', '3050'));
        Tanim.VeritabaniYolu := Ortam('FBTEST_YOL', '');
        Tanim.Kullanici := Ortam('FBTEST_KULLANICI', 'SYSDBA');
        Tanim.Sifre := Ortam('FBTEST_SIFRE', '');
        Tanim.KarakterSeti := VARSAYILAN_KARAKTER_SETI;
        GeciciVeritabaniOlustur(Tanim);
        Bag := FbBaglan(Tanim);
        VeritabaniTestleri;
      end
      else
        Cikti.Add('FBTEST_YOL verilmedi: veritabani testleri atlandi.');
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



