program KullaniciOlcum;

{ Asama 3d (kullanici ve yetki yonetimi) OLCUM programi. Ozellik kodu degildir; once gercegi ogrenmek icindir.

  VARSAYILAN: YALNIZCA OKUR. Baglanir, surumu yazar, kullanici listesini ve yetkileri okumayi dener,
  hangi yolun hangi surumde calistigini (hata mesajiyla) cikti dosyasina yazar.

  FBTEST_YAZMA=1 verilirse ve (sunucu 127.0.0.1/localhost ve port 3052 veya 3053) ise ya da gomulu kipte
  program KENDI actigi gecici veritabaniyla calisiyorsa: test kullanicisi FBY_TEST olusturur, sifresini
  degistirir, GRANT/REVOKE dener, kullaniciyi siler. Port 3050/3051 (gercek veri) ve baska her sunucu kod
  seviyesinde REDDEDILIR; reddedilince yazma bolumu hic calismaz, okuma bolumu yine calisir.

  Ortam degiskenleri: FBTEST_SUNUCU (bos = gomulu), FBTEST_PORT, FBTEST_YOL (sunucudaki var olan veritabani;
  gomulu kipte bos birakilirsa gecici veritabani acilir), FBTEST_KULLANICI, FBTEST_SIFRE, FBTEST_CIKTI,
  FBTEST_YAZMA. Sifre hicbir yere yazilmaz. }

{$APPTYPE CONSOLE}

uses
  System.SysUtils, System.Classes, System.IOUtils, System.StrUtils, System.Variants, Data.DB,
  FireDAC.Stan.Error, FireDAC.Comp.Client, FireDAC.Phys.FB, FireDAC.Phys.IBBase,
  FireDAC.Phys.IBWrapper, FireDAC.DatS, FireDAC.ConsoleUI.Wait,
  uDil, uBaglanti;

const
  { Test kullanicilari ve gecici nesneler (yalnizca yazma bolumunde kullanilir) }
  TEST_KULLANICI = 'FBY_TEST';
  TEST_KULLANICI_SERVIS = 'FBY_SVC';
  TEST_TABLO = 'FBY_OLCUM_T';
  TEST_ROL = 'FBY_ROL';
  TEST_SISTEM_ROLU = 'FBY_SYSROL';
  SIFRE_1 = 'Ilk12345';
  SIFRE_2 = 'Ikinci123';
  SIFRE_3 = 'Ucuncu123';

var
  Cikti: TStringList;
  Bag: TAcikBaglanti;
  SurumNo: Integer;

function Ortam(const Ad, Varsayilan: string): string;
begin
  Result := GetEnvironmentVariable(Ad);
  if Result = '' then
    Result := Varsayilan;
end;

function TekSatir(const Metin: string): string;
begin
  Result := StringReplace(StringReplace(Metin, #13, ' ', [rfReplaceAll]), #10, ' | ', [rfReplaceAll]);
end;

{ Hata: sinif, ham mesaj, Firebird/SQL kodlari ve bizim anlasilir cumlemiz (uBaglanti.HataMetniniCevir) }
function HataYaz(E: Exception): string;
var
  I: Integer;
begin
  Result := E.ClassName + ': ' + TekSatir(E.Message);
  if E is EFDDBEngineException then
    for I := 0 to EFDDBEngineException(E).ErrorCount - 1 do
      Result := Result + ' [kod=' + IntToStr(EFDDBEngineException(E).Errors[I].ErrorCode) + ']';
  try
    Result := Result + '  => cevirisi: ' + TekSatir(HataMetniniCevir(E));
  except
    on E2: Exception do
      Result := Result + '  => cevirisi alinamadi: ' + E2.Message;
  end;
end;

function SatirMetni(Sorgu: TFDQuery): string;
var
  I: Integer;
  Alan: TField;
begin
  Result := '';
  for I := 0 to Sorgu.FieldCount - 1 do
  begin
    Alan := Sorgu.Fields[I];
    if I > 0 then
      Result := Result + ' | ';
    if Alan.IsNull then
      Result := Result + '<NULL>'
    else
      Result := Result + Trim(Alan.AsString);
  end;
end;

{ SELECT'i dener; kolon adlarini ve (en cok EnCok) satiri yazar. Basari: True. }
function Sorgula(const Etiket, Sql: string; EnCok: Integer = 40): Boolean;
var
  Sorgu: TFDQuery;
  I, Say: Integer;
  Basliklar: string;
begin
  Result := False;
  Sorgu := TFDQuery.Create(nil);
  try
    Sorgu.Connection := Bag.Baglanti;
    try
      Sorgu.SQL.Text := Sql;
      Sorgu.Open;
      Basliklar := '';
      for I := 0 to Sorgu.FieldCount - 1 do
      begin
        if I > 0 then
          Basliklar := Basliklar + ' | ';
        Basliklar := Basliklar + Sorgu.Fields[I].FieldName;
      end;
      Cikti.Add('[CALISTI] ' + Etiket);
      Cikti.Add('          kolonlar: ' + Basliklar);
      Say := 0;
      while not Sorgu.Eof do
      begin
        Inc(Say);
        if Say <= EnCok then
          Cikti.Add('          ' + SatirMetni(Sorgu));
        Sorgu.Next;
      end;
      Cikti.Add('          toplam satir: ' + IntToStr(Say) + IfThen(Say > EnCok, ' (ilk ' + IntToStr(EnCok) + ' yazildi)', ''));
      Result := True;
    except
      on E: Exception do
        Cikti.Add('[HATA]    ' + Etiket + ' -> ' + HataYaz(E));
    end;
  finally
    Sorgu.Free;
  end;
end;

{ DDL/komut dener (otomatik commit). Basari: True. }
function Komut(const Etiket, Sql: string): Boolean;
begin
  Result := False;
  try
    Bag.Baglanti.ExecSQL(Sql);
    Cikti.Add('[CALISTI] ' + Etiket + '   (' + Sql + ')');
    Result := True;
  except
    on E: Exception do
      Cikti.Add('[HATA]    ' + Etiket + '   (' + Sql + ') -> ' + HataYaz(E));
  end;
end;

{ Temizlikte hata onemsiz; sonucu yazmaz. }
procedure Sessiz(const Sql: string);
begin
  try
    Bag.Baglanti.ExecSQL(Sql);
  except
  end;
end;

{ Servis API'si (FireDAC TFDIBSecurity): kullanici listesi. Kendi surucu baglantisini acar ve kapatir. }
procedure ServisListesi(const Etiket, Sunucu: string; Port: Integer; const Kullanici, Sifre: string);
var
  Surucu: TFDPhysFBDriverLink;
  Guvenlik: TFDIBSecurity;
  I: Integer;
  Tablo: TFDDatSTable;
begin
  Surucu := TFDPhysFBDriverLink.Create(nil);
  Guvenlik := TFDIBSecurity.Create(nil);
  try
    try
      Surucu.VendorLib := ExtractFilePath(ParamStr(0)) + 'istemci\fbclient.dll';
      Guvenlik.DriverLink := Surucu;
      if Sunucu <> '' then
      begin
        Guvenlik.Protocol := ipTCPIP;
        Guvenlik.Host := Sunucu;
        Guvenlik.Port := Port;
      end
      else
        Guvenlik.Protocol := ipLocal;
      Guvenlik.UserName := Kullanici;
      Guvenlik.Password := Sifre;
      Guvenlik.DisplayUsers;
      Tablo := Guvenlik.Users;
      Cikti.Add('[CALISTI] ' + Etiket + ' (TFDIBSecurity.DisplayUsers; kolonlar: kullanici | ad | ortaad | soyad | userid | groupid)');
      for I := 0 to Tablo.Rows.Count - 1 do
        Cikti.Add('          ' + VarToStr(Tablo.Rows[I].GetData(0)) + ' | ' + VarToStr(Tablo.Rows[I].GetData(2)) +
          ' | ' + VarToStr(Tablo.Rows[I].GetData(3)) + ' | ' + VarToStr(Tablo.Rows[I].GetData(4)) +
          ' | ' + VarToStr(Tablo.Rows[I].GetData(5)) + ' | ' + VarToStr(Tablo.Rows[I].GetData(6)));
      Cikti.Add('          toplam satir: ' + IntToStr(Tablo.Rows.Count) +
        '   (not: bu yolda "yonetici", "aktif/pasif", "eklenti" bilgisi yok)');
    except
      on E: Exception do
        Cikti.Add('[HATA]    ' + Etiket + ' -> ' + HataYaz(E));
    end;
  finally
    Guvenlik.Free;
    Surucu.Free;
  end;
end;

{ Servis API'si ile ekle / goster / sil denemesi (yalniz yazma bolumunde, FBY_SVC) }
procedure ServisYazma(const Sunucu: string; Port: Integer; const Kullanici, Sifre: string);
var
  Surucu: TFDPhysFBDriverLink;
  Guvenlik: TFDIBSecurity;
begin
  Surucu := TFDPhysFBDriverLink.Create(nil);
  Guvenlik := TFDIBSecurity.Create(nil);
  try
    try
      Surucu.VendorLib := ExtractFilePath(ParamStr(0)) + 'istemci\fbclient.dll';
      Guvenlik.DriverLink := Surucu;
      if Sunucu <> '' then
      begin
        Guvenlik.Protocol := ipTCPIP;
        Guvenlik.Host := Sunucu;
        Guvenlik.Port := Port;
      end
      else
        Guvenlik.Protocol := ipLocal;
      Guvenlik.UserName := Kullanici;
      Guvenlik.Password := Sifre;
      Guvenlik.AUserName := TEST_KULLANICI_SERVIS;
      Guvenlik.APassword := SIFRE_1;
      Guvenlik.AFirstName := 'Servis';
      Guvenlik.ALastName := 'Deneme';
      Guvenlik.AddUser;
      Cikti.Add('[CALISTI] Servis API: AddUser ' + TEST_KULLANICI_SERVIS);
      Guvenlik.APassword := SIFRE_2;
      Guvenlik.ModifyUser;
      Cikti.Add('[CALISTI] Servis API: ModifyUser (sifre) ' + TEST_KULLANICI_SERVIS);
      Guvenlik.DeleteUser;
      Cikti.Add('[CALISTI] Servis API: DeleteUser ' + TEST_KULLANICI_SERVIS);
    except
      on E: Exception do
        Cikti.Add('[HATA]    Servis API yazma (AddUser/ModifyUser/DeleteUser) -> ' + HataYaz(E));
    end;
    { Yarim kalmissa temizle }
    try
      Guvenlik.AUserName := TEST_KULLANICI_SERVIS;
      Guvenlik.DeleteUser;
    except
    end;
  finally
    Guvenlik.Free;
    Surucu.Free;
  end;
end;

{ ---------- OKUMA BOLUMU ---------- }

procedure OkumaBolumu;
begin
  Cikti.Add('');
  Cikti.Add('=== OKUMA 1) Kim baglandi, hangi yontemle ===');
  Sorgula('CURRENT_USER / CURRENT_ROLE', 'select CURRENT_USER, CURRENT_ROLE from RDB$DATABASE');
  Sorgula('Veritabani sahibi (MON$DATABASE.MON$OWNER; 2.1+)', 'select MON$OWNER from MON$DATABASE');
  Sorgula('Guvenlik veritabani turu (MON$SEC_DATABASE; 3.0+)', 'select MON$SEC_DATABASE from MON$DATABASE');
  Sorgula('Dogrulama yontemi (MON$AUTH_METHOD; 3.0+)',
    'select MON$AUTH_METHOD from MON$ATTACHMENTS where MON$ATTACHMENT_ID = CURRENT_CONNECTION');
  Sorgula('Baglanti rolu bilgisi', 'select MON$ROLE from MON$ATTACHMENTS where MON$ATTACHMENT_ID = CURRENT_CONNECTION');

  Cikti.Add('');
  Cikti.Add('=== OKUMA 2) Kullanici listesi: SQL yolu (SEC$USERS, 3.0+) ===');
  Sorgula('SEC$USERS (tum kolonlar)', 'select * from SEC$USERS');
  Sorgula('SEC$USERS (secili kolonlar)',
    'select SEC$USER_NAME, SEC$FIRST_NAME, SEC$MIDDLE_NAME, SEC$LAST_NAME, SEC$ACTIVE, SEC$ADMIN, SEC$PLUGIN from SEC$USERS');
  Sorgula('SEC$USER_ATTRIBUTES (etiketler)', 'select * from SEC$USER_ATTRIBUTES');
  Sorgula('SEC$DB_CREATORS (veritabani olusturma yetkisi, 3.0+)', 'select * from SEC$DB_CREATORS');
  Sorgula('SEC$GLOBAL_AUTH_MAPPING (3.0+)', 'select * from SEC$GLOBAL_AUTH_MAPPING');

  Cikti.Add('');
  Cikti.Add('=== OKUMA 3) Roller ===');
  Sorgula('RDB$ROLES', 'select RDB$ROLE_NAME, RDB$OWNER_NAME, RDB$SYSTEM_FLAG from RDB$ROLES');
  Sorgula('RDB$ROLES sistem ayricaliklari (4.0+)',
    'select RDB$ROLE_NAME, HEX_ENCODE(RDB$SYSTEM_PRIVILEGES) from RDB$ROLES where RDB$SYSTEM_PRIVILEGES is not null');

  Cikti.Add('');
  Cikti.Add('=== OKUMA 4) RDB$USER_PRIVILEGES ozeti ===');
  Sorgula('Kolonlar (bos sonuc kolon adlarini gosterir)', 'select first 1 * from RDB$USER_PRIVILEGES');
  Sorgula('Toplam kayit sayisi', 'select count(*) from RDB$USER_PRIVILEGES');
  Sorgula('Verilen kullanici/rol/nesne turu ve yetki harfi basina sayi',
    'select RDB$USER_TYPE, RDB$PRIVILEGE, count(*) from RDB$USER_PRIVILEGES group by RDB$USER_TYPE, RDB$PRIVILEGE ' +
    'order by RDB$USER_TYPE, RDB$PRIVILEGE', 60);
  Sorgula('Alici (kullanici/rol) basina yetki sayisi (yalniz kullanici ve rol: tur 8 ve 13)',
    'select RDB$USER, RDB$USER_TYPE, count(*) from RDB$USER_PRIVILEGES where RDB$USER_TYPE in (8, 13) ' +
    'group by RDB$USER, RDB$USER_TYPE order by 3 desc', 30);
  Sorgula('Rol uyelikleri (M)', 'select RDB$USER, RDB$RELATION_NAME, RDB$GRANT_OPTION from RDB$USER_PRIVILEGES where RDB$PRIVILEGE = ''M''', 30);
  Sorgula('DDL yetkileri (C/L/O; 3.0+)',
    'select RDB$USER, RDB$PRIVILEGE, RDB$RELATION_NAME, RDB$OBJECT_TYPE from RDB$USER_PRIVILEGES where RDB$PRIVILEGE in (''C'', ''L'', ''O'')', 30);
  Sorgula('PUBLIC icin verilenler', 'select RDB$PRIVILEGE, count(*) from RDB$USER_PRIVILEGES where RDB$USER = ''PUBLIC'' group by RDB$PRIVILEGE', 20);
  Sorgula('Tablo/gorunum yetkileri ornegi (ilk 15)',
    'select first 15 RDB$USER, RDB$PRIVILEGE, RDB$RELATION_NAME, RDB$FIELD_NAME, RDB$GRANT_OPTION from RDB$USER_PRIVILEGES ' +
    'where RDB$OBJECT_TYPE in (0, 1) and RDB$USER_TYPE in (8, 13) order by RDB$RELATION_NAME', 15);
end;

{ ---------- YAZMA BOLUMU ---------- }

{ FBY_TEST ile ayri bir baglanti acar; CURRENT_USER'i yazar. Basari: True }
function TestKullanicisiylaBaglan(const Etiket, Sifre: string; const Tanim: TBaglantiTanimi): Boolean;
var
  T: TBaglantiTanimi;
  B: TAcikBaglanti;
begin
  Result := False;
  T := Tanim;
  T.Ad := 'olcum_fby_' + IntToStr(Random(100000));
  T.Kullanici := TEST_KULLANICI;
  T.Sifre := Sifre;
  try
    B := FbBaglan(T);
    try
      Cikti.Add('[CALISTI] ' + Etiket + ' -> baglandi, CURRENT_USER = ' +
        VarToStr(B.Baglanti.ExecSQLScalar('select CURRENT_USER from RDB$DATABASE')));
      Result := True;
    finally
      FbBaglantiyiKes(B);
    end;
  except
    on E: Exception do
      Cikti.Add('[HATA]    ' + Etiket + ' -> ' + HataYaz(E));
  end;
end;

{ FBY_TEST olarak bir komut dener (kendi sifresini degistirme, yetkisiz islem vb.) }
procedure TestKullanicisiylaKomut(const Etiket, Sifre, Sql: string; const Tanim: TBaglantiTanimi);
var
  T: TBaglantiTanimi;
  B: TAcikBaglanti;
begin
  T := Tanim;
  T.Ad := 'olcum_fby_' + IntToStr(Random(100000));
  T.Kullanici := TEST_KULLANICI;
  T.Sifre := Sifre;
  try
    B := FbBaglan(T);
    try
      B.Baglanti.ExecSQL(Sql);
      Cikti.Add('[CALISTI] ' + Etiket + '   (FBY_TEST olarak: ' + Sql + ')');
    finally
      FbBaglantiyiKes(B);
    end;
  except
    on E: Exception do
      Cikti.Add('[HATA]    ' + Etiket + '   (FBY_TEST olarak: ' + Sql + ') -> ' + HataYaz(E));
  end;
end;

procedure YazmaTemizligi;
begin
  Sessiz('REVOKE ALL ON ' + TEST_TABLO + ' FROM ' + TEST_KULLANICI);
  Sessiz('DROP TABLE ' + TEST_TABLO);
  Sessiz('DROP ROLE ' + TEST_ROL);
  Sessiz('DROP ROLE ' + TEST_SISTEM_ROLU);
  Sessiz('REVOKE CREATE TABLE FROM ' + TEST_KULLANICI);
  Sessiz('DROP USER ' + TEST_KULLANICI);
  Sessiz('DROP USER ' + TEST_KULLANICI_SERVIS);
end;

procedure YazmaBolumu(const Tanim: TBaglantiTanimi);
var
  Olustu: Boolean;
begin
  Cikti.Add('');
  Cikti.Add('=== YAZMA (yalniz test sunucusu / gecici veritabani; test kullanicisi ' + TEST_KULLANICI + ') ===');
  YazmaTemizligi;

  Cikti.Add('');
  Cikti.Add('--- Y1) Kullanici ekle (SQL) ---');
  Olustu := Komut('CREATE USER (ad/soyad ile)',
    'CREATE USER ' + TEST_KULLANICI + ' PASSWORD ''' + SIFRE_1 + ''' FIRSTNAME ''Test'' MIDDLENAME ''Orta'' LASTNAME ''Kullanici''');
  Sorgula('Eklenen kullanici SEC$USERS''ta (3.0+)',
    'select * from SEC$USERS where SEC$USER_NAME = ''' + TEST_KULLANICI + '''');
  ServisListesi('Servis API kullanici listesi (ekleme sonrasi)', Tanim.Sunucu, Tanim.Port, Tanim.Kullanici, Tanim.Sifre);
  if Olustu then
    TestKullanicisiylaBaglan('Yeni kullanici ilk sifresiyle baglanabiliyor mu', SIFRE_1, Tanim);

  Cikti.Add('');
  Cikti.Add('--- Y2) Yonetici (SYSDBA) baska kullanicinin sifresini degistirir ---');
  if Komut('ALTER USER ... PASSWORD', 'ALTER USER ' + TEST_KULLANICI + ' PASSWORD ''' + SIFRE_2 + '''') then
  begin
    TestKullanicisiylaBaglan('Eski sifre artik calismamali', SIFRE_1, Tanim);
    TestKullanicisiylaBaglan('Yeni sifre ile baglanti', SIFRE_2, Tanim);
  end;

  Cikti.Add('');
  Cikti.Add('--- Y3) Kullanici KENDI sifresini degistirir ---');
  TestKullanicisiylaKomut('ALTER CURRENT USER (3.0+)', SIFRE_2,
    'ALTER CURRENT USER SET PASSWORD ''' + SIFRE_3 + '''', Tanim);
  TestKullanicisiylaBaglan('ALTER CURRENT USER sonrasi: ucuncu sifre', SIFRE_3, Tanim);
  { Basarisiz olduysa (2.5 gibi) ikinci yol: ALTER USER kendi_adi }
  TestKullanicisiylaKomut('ALTER USER kendi adi (2.5 yolu)', SIFRE_3,
    'ALTER USER ' + TEST_KULLANICI + ' PASSWORD ''' + SIFRE_2 + '''', Tanim);
  TestKullanicisiylaBaglan('Sifre su an hangisi: ikinci sifre', SIFRE_2, Tanim);
  TestKullanicisiylaBaglan('Sifre su an hangisi: ucuncu sifre', SIFRE_3, Tanim);
  TestKullanicisiylaKomut('Siradan kullanici baska kullanicinin sifresini degistirmeye calisir', SIFRE_2,
    'ALTER USER SYSDBA PASSWORD ''x1234567''', Tanim);
  TestKullanicisiylaKomut('Siradan kullanici yeni kullanici eklemeye calisir', SIFRE_2,
    'CREATE USER FBY_YASAK PASSWORD ''x1234567''', Tanim);
  Sessiz('DROP USER FBY_YASAK');

  Cikti.Add('');
  Cikti.Add('--- Y4) Ad/soyad, yonetici (RDB$ADMIN) ve aktif/pasif ---');
  Komut('ALTER USER ad/soyad', 'ALTER USER ' + TEST_KULLANICI + ' FIRSTNAME ''Yeni'' LASTNAME ''Soyad''');
  Komut('GRANT ADMIN ROLE', 'ALTER USER ' + TEST_KULLANICI + ' GRANT ADMIN ROLE');
  Sorgula('Yonetici bayragi (SEC$ADMIN; 3.0+)',
    'select SEC$USER_NAME, SEC$FIRST_NAME, SEC$LAST_NAME, SEC$ADMIN, SEC$ACTIVE from SEC$USERS where SEC$USER_NAME = ''' + TEST_KULLANICI + '''');
  ServisListesi('Servis API listesi (yonetici yapildiktan sonra)', Tanim.Sunucu, Tanim.Port, Tanim.Kullanici, Tanim.Sifre);
  Komut('REVOKE ADMIN ROLE', 'ALTER USER ' + TEST_KULLANICI + ' REVOKE ADMIN ROLE');
  Komut('INACTIVE (3.0+)', 'ALTER USER ' + TEST_KULLANICI + ' INACTIVE');
  TestKullanicisiylaBaglan('Pasif kullanici baglanabilmeli mi (baglanamamali)', SIFRE_2, Tanim);
  Komut('ACTIVE (3.0+)', 'ALTER USER ' + TEST_KULLANICI + ' ACTIVE');
  Komut('TAGS (3.0+)', 'ALTER USER ' + TEST_KULLANICI + ' TAGS (DEPARTMAN = ''test'')');
  Sorgula('SEC$USER_ATTRIBUTES (etiket)', 'select * from SEC$USER_ATTRIBUTES where SEC$USER_NAME = ''' + TEST_KULLANICI + '''');

  Cikti.Add('');
  Cikti.Add('--- Y5) GRANT / REVOKE (tablo, rol) ---');
  Komut('Gecici tablo', 'CREATE TABLE ' + TEST_TABLO + ' (ID INTEGER NOT NULL PRIMARY KEY, A VARCHAR(10))');
  Komut('GRANT SELECT, INSERT', 'GRANT SELECT, INSERT ON ' + TEST_TABLO + ' TO ' + TEST_KULLANICI);
  Komut('GRANT UPDATE (A) sutun yetkisi', 'GRANT UPDATE (A) ON ' + TEST_TABLO + ' TO ' + TEST_KULLANICI);
  Sorgula('RDB$USER_PRIVILEGES: tabloya verilenler',
    'select RDB$USER, RDB$PRIVILEGE, RDB$FIELD_NAME, RDB$GRANT_OPTION, RDB$GRANTOR from RDB$USER_PRIVILEGES where RDB$RELATION_NAME = ''' + TEST_TABLO + '''');
  TestKullanicisiylaKomut('Yetkili kullanici INSERT yapar', SIFRE_2, 'INSERT INTO ' + TEST_TABLO + ' VALUES (1, ''a'')', Tanim);
  TestKullanicisiylaKomut('Yetkisiz kullanici DELETE yapar (hata beklenir)', SIFRE_2, 'DELETE FROM ' + TEST_TABLO, Tanim);
  Komut('REVOKE INSERT', 'REVOKE INSERT ON ' + TEST_TABLO + ' FROM ' + TEST_KULLANICI);
  TestKullanicisiylaKomut('REVOKE sonrasi INSERT (hata beklenir)', SIFRE_2, 'INSERT INTO ' + TEST_TABLO + ' VALUES (2, ''b'')', Tanim);
  Komut('CREATE ROLE', 'CREATE ROLE ' + TEST_ROL);
  Komut('GRANT SELECT -> rol', 'GRANT SELECT ON ' + TEST_TABLO + ' TO ROLE ' + TEST_ROL);
  Komut('GRANT rol -> kullanici', 'GRANT ' + TEST_ROL + ' TO ' + TEST_KULLANICI);
  Sorgula('Rol uyeligi (M) ve rol yetkisi',
    'select RDB$USER, RDB$USER_TYPE, RDB$PRIVILEGE, RDB$RELATION_NAME, RDB$GRANT_OPTION from RDB$USER_PRIVILEGES ' +
    'where RDB$USER in (''' + TEST_ROL + ''', ''' + TEST_KULLANICI + ''') or RDB$RELATION_NAME = ''' + TEST_ROL + '''');
  Komut('REVOKE rol <- kullanici', 'REVOKE ' + TEST_ROL + ' FROM ' + TEST_KULLANICI);
  Komut('REVOKE ALL', 'REVOKE ALL ON ' + TEST_TABLO + ' FROM ' + TEST_KULLANICI);

  Cikti.Add('');
  Cikti.Add('--- Y6) Surume ozel: DDL yetkisi (3.0+), sistem ayricaligi (4.0+) ---');
  Komut('GRANT CREATE TABLE (DDL yetkisi)', 'GRANT CREATE TABLE TO ' + TEST_KULLANICI);
  Sorgula('DDL yetkisi kaydi (C harfi)',
    'select RDB$USER, RDB$PRIVILEGE, RDB$RELATION_NAME, RDB$OBJECT_TYPE from RDB$USER_PRIVILEGES where RDB$USER = ''' + TEST_KULLANICI + '''');
  Komut('REVOKE CREATE TABLE', 'REVOKE CREATE TABLE FROM ' + TEST_KULLANICI);
  Komut('Sistem ayricalikli rol (4.0+)',
    'CREATE ROLE ' + TEST_SISTEM_ROLU + ' SET SYSTEM PRIVILEGES TO USER_MANAGEMENT');
  Sorgula('Rolun sistem ayricaliklari', 'select RDB$ROLE_NAME, HEX_ENCODE(RDB$SYSTEM_PRIVILEGES) from RDB$ROLES where RDB$ROLE_NAME = ''' + TEST_SISTEM_ROLU + '''');

  Cikti.Add('');
  Cikti.Add('--- Y7) Servis API ile ekle/degistir/sil (FireDAC TFDIBSecurity) ---');
  ServisYazma(Tanim.Sunucu, Tanim.Port, Tanim.Kullanici, Tanim.Sifre);

  Cikti.Add('');
  Cikti.Add('--- Y8) Silme ---');
  YazmaTemizligi;
  Komut('DROP USER (yeniden; kullanici zaten silindiyse hata beklenir)', 'DROP USER ' + TEST_KULLANICI);
  Sorgula('Kullanici gitti mi (SEC$USERS)', 'select SEC$USER_NAME from SEC$USERS where SEC$USER_NAME = ''' + TEST_KULLANICI + '''');
  ServisListesi('Servis API listesi (silme sonrasi)', Tanim.Sunucu, Tanim.Port, Tanim.Kullanici, Tanim.Sifre);
end;

{ ---------- ANA AKIS ---------- }

function GeciciVeritabaniOlustur(const Tanim: TBaglantiTanimi): Boolean;
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
    Result := True;
  finally
    Baglanti.Free;
    Surucu.Free;
  end;
end;

var
  Tanim: TBaglantiTanimi;
  Gomulu, YazmaIstendi, YazmaIzni, KendiVeritabanim: Boolean;
  Klasor, Neden: string;
begin
  Cikti := TStringList.Create;
  Bag := nil;
  KendiVeritabanim := False;
  Gomulu := False;
  Randomize;
  try
    try
      DilYukle('tr');
      Tanim.Ad := 'kullanici_olcum';
      Tanim.Sunucu := Ortam('FBTEST_SUNUCU', '');
      Tanim.Port := StrToInt(Ortam('FBTEST_PORT', '3050'));
      Tanim.VeritabaniYolu := Ortam('FBTEST_YOL', '');
      Tanim.Kullanici := Ortam('FBTEST_KULLANICI', 'SYSDBA');
      Tanim.Sifre := Ortam('FBTEST_SIFRE', '');
      Tanim.KarakterSeti := VARSAYILAN_KARAKTER_SETI;
      Gomulu := Tanim.Sunucu = '';
      YazmaIstendi := Ortam('FBTEST_YAZMA', '') = '1';

      { Gomulu kipte yol verilmediyse kendi gecici veritabanimizi aciyoruz (yalniz bunda yazma serbest). }
      if Gomulu and (Tanim.VeritabaniYolu = '') then
      begin
        Klasor := TPath.Combine(GetEnvironmentVariable('TEMP'), 'kullaniciolcum');
        ForceDirectories(Klasor);
        Tanim.VeritabaniYolu := TPath.Combine(Klasor, 'olcum_' + FormatDateTime('yyyymmdd_hhnnss', Now) + '.fdb');
        GeciciVeritabaniOlustur(Tanim);
        KendiVeritabanim := True;
      end;
      if Tanim.VeritabaniYolu = '' then
        raise Exception.Create('FBTEST_YOL bos: sunucudaki var olan bir veritabani yolu verin.');

      { Yazma izni kod seviyesinde: gercek veri portlari (3050, 3051) ve tanimsiz her sunucu reddedilir. }
      YazmaIzni := False;
      Neden := '';
      if not YazmaIstendi then
        Neden := 'FBTEST_YAZMA=1 verilmedi (varsayilan: yalniz okuma)'
      else if Gomulu then
      begin
        YazmaIzni := KendiVeritabanim;
        if not YazmaIzni then
          Neden := 'gomulu kipte yazma yalniz programin kendi actigi gecici veritabaniyla serbest (FBTEST_YOL bos birakin)';
      end
      else if not YerelSunucuMu(Tanim.Sunucu) then
        Neden := 'yazma yalniz yerel (127.0.0.1/localhost) test sunucusunda serbest'
      else if (Tanim.Port = 3052) or (Tanim.Port = 3053) then
        YazmaIzni := True
      else
        Neden := 'port ' + IntToStr(Tanim.Port) + ': yazma YALNIZ 3052 ve 3053 portunda serbest (3050/3051 gercek veri icerir)';

      Cikti.Add('KullaniciOlcum  ' + FormatDateTime('yyyy-mm-dd hh:nn:ss', Now));
      Cikti.Add('Sunucu: ' + IfThen(Gomulu, '(gomulu)', Tanim.Sunucu + ':' + IntToStr(Tanim.Port)));
      Cikti.Add('Veritabani: ' + Tanim.VeritabaniYolu + IfThen(KendiVeritabanim, '  (gecici, program acti)', ''));
      Cikti.Add('Kullanici: ' + Tanim.Kullanici + '  (sifre yazilmaz)');
      Cikti.Add('Yazma bolumu: ' + IfThen(YazmaIzni, 'ACIK', 'KAPALI - ' + Neden));

      Bag := FbBaglan(Tanim);
      SurumNo := StrToIntDef(Copy(Bag.Surum, 1, Pos('.', Bag.Surum) - 1), 0);
      Cikti.Add('');
      Cikti.Add('Surum: ' + Bag.Surum + '  (ana surum ' + IntToStr(SurumNo) + ')');

      Cikti.Add('');
      Cikti.Add('=== OKUMA 0) Servis API ile kullanici listesi (FireDAC TFDIBSecurity) ===');
      ServisListesi('Servis API kullanici listesi', Tanim.Sunucu, Tanim.Port, Tanim.Kullanici, Tanim.Sifre);
      OkumaBolumu;
      if YazmaIzni then
        YazmaBolumu(Tanim);
    except
      on E: Exception do
      begin
        Cikti.Add('');
        Cikti.Add('HATA (ham): ' + E.ClassName + ': ' + TekSatir(E.Message));
        Cikti.Add('HATA (anlasilir): ' + HataMetniniCevir(E));
      end;
    end;
    { Yazma acikken yarim kalmis bir sey varsa temizle }
    if (Bag <> nil) and (Ortam('FBTEST_YAZMA', '') = '1') and
       (Gomulu and KendiVeritabanim or (not Gomulu and ((Tanim.Port = 3052) or (Tanim.Port = 3053)) and YerelSunucuMu(Tanim.Sunucu))) then
      YazmaTemizligi;
    if KendiVeritabanim and (Bag <> nil) then
      FbBaglantiyiKes(Bag);
    Cikti.SaveToFile(Ortam('FBTEST_CIKTI', 'kullaniciolcum.txt'), TEncoding.UTF8);
  finally
    Cikti.Free;
  end;
end.
