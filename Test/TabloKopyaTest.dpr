program TabloKopyaTest;

{ Asama 7f: uTabloKopya (tabloyu baska veritabanina kopyalama) testi (komut satiri).
  Iki gecici veritabani acilir (varsayilan: gomulu Firebird); gercek veriye dokunulmaz.
  Ortam degiskenleri: FBTEST_SUNUCU (bos = yerel), FBTEST_PORT, FBTEST_KLASOR, FBTEST_KULLANICI, FBTEST_SIFRE, FBTEST_CIKTI.
  Cikti dosyasi bos ise ekrana yazilir. Cikis kodu: hata sayisi (0 = hepsi gecti). }

{$APPTYPE CONSOLE}

uses
  System.SysUtils, System.Classes, System.StrUtils, System.IOUtils, Data.DB,
  FireDAC.Stan.Intf, FireDAC.Stan.Option, FireDAC.Stan.Error, FireDAC.Comp.Client, FireDAC.Phys.FB,
  FireDAC.ConsoleUI.Wait,
  uDil, uBaglanti, uSorgu, uTabloKopya;

const
  { c g i(noktasiz) o s u }
  TURKCE = #$00E7#$011F#$0131#$00F6#$015F#$00FC;
  SATIR_SAYISI = 1200;

type
  TIptalci = class
    procedure Ilerleme(SatirSayisi: Int64; var Iptal: Boolean);
  end;

var
  Cikti: TStringList;
  Hatalar, KontrolSayisi: Integer;
  A, B: TAcikBaglanti;

procedure TIptalci.Ilerleme(SatirSayisi: Int64; var Iptal: Boolean);
begin
  Iptal := SatirSayisi >= 200;
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

procedure Komut(Bag: TAcikBaglanti; const Sql: string);
begin
  SorguCalistir(Bag, Sql).Free;
end;

function Oku(Bag: TAcikBaglanti; const Sql: string): string;
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

function TanimYap(const Ad, Yol: string): TBaglantiTanimi;
begin
  Result := Default(TBaglantiTanimi);
  Result.Ad := Ad;
  Result.Sunucu := Ortam('FBTEST_SUNUCU', '');
  Result.Port := StrToInt(Ortam('FBTEST_PORT', '3050'));
  Result.VeritabaniYolu := Yol;
  Result.Kullanici := Ortam('FBTEST_KULLANICI', 'SYSDBA');
  Result.Sifre := Ortam('FBTEST_SIFRE', '');
  Result.KarakterSeti := VARSAYILAN_KARAKTER_SETI;
end;

procedure KaynakKur;
var
  i: Integer;
begin
  Komut(A, 'CREATE DOMAIN D_KOD AS VARCHAR(12)');
  Komut(A, 'CREATE TABLE T_ANA (ID INTEGER NOT NULL PRIMARY KEY)');
  Komut(A, 'INSERT INTO T_ANA VALUES (1)');
  Komut(A, 'CREATE TABLE T_KAYNAK (ID INTEGER NOT NULL PRIMARY KEY, AD VARCHAR(40), SAYI NUMERIC(9,2), TARIH DATE, ' +
    'ZAMAN TIMESTAMP, NOTU BLOB SUB_TYPE TEXT, IKILI BLOB SUB_TYPE BINARY, KOD VARCHAR(10), ETIKET D_KOD, ' +
    'ANA_ID INTEGER REFERENCES T_ANA (ID), HES COMPUTED BY (COALESCE(AD, ''-'') || ''!''), ' +
    'CONSTRAINT UQ_KOD UNIQUE (KOD), CHECK (SAYI IS NULL OR SAYI >= 0))');
  Komut(A, 'CREATE INDEX IX_KAYNAK_AD ON T_KAYNAK (AD)');
  for i := 1 to SATIR_SAYISI do
    Komut(A, 'INSERT INTO T_KAYNAK (ID, AD, SAYI, TARIH, ZAMAN, NOTU, IKILI, KOD, ETIKET, ANA_ID) VALUES (' +
      IntToStr(i) + ', ''ad' + IntToStr(i) + ''', ' + IntToStr(i) + '.25, ''2024-01-31'', ''2024-01-31 13:45:10'', ''not' +
      IntToStr(i) + ''', x''0001FF'', ''K' + IntToStr(i) + ''', ''E' + IntToStr(i) + ''', 1)');
  { Ozel satirlar: Turkce metin ve NULL'lar }
  Komut(A, 'UPDATE T_KAYNAK SET AD = ''' + TURKCE + ''' WHERE ID = 1');
  Komut(A, 'UPDATE T_KAYNAK SET SAYI = NULL, TARIH = NULL, ZAMAN = NULL, NOTU = NULL, IKILI = NULL, KOD = NULL, ' +
    'ETIKET = NULL, ANA_ID = NULL WHERE ID = 2');
end;

procedure KopyaTesti;
var
  S: TKopyaSonucu;
  Iptalci: TIptalci;
begin
  Cikti.Add('--- Eksik domain ---');
  Kontrol('hedefte olmayan domain bulunur: D_KOD', EksikDomainler(A, 'T_KAYNAK', B) = 'D_KOD');
  S := TabloKopyala(A, 'T_KAYNAK', B, 'T_KAYNAK', True, nil);
  Kontrol('eksik domain: kopyalama basarisiz', not S.Basarili);
  Kontrol('eksik domain: hata cumlesi domain adini soyluyor', Pos('D_KOD', S.Cumle) > 0);
  Kontrol('eksik domain: hedefte tablo olusmadi', not HedefteTabloVarMi(B, 'T_KAYNAK'));
  Komut(B, 'CREATE DOMAIN D_KOD AS VARCHAR(12)');
  Kontrol('domain olusturulunca eksik yok', EksikDomainler(A, 'T_KAYNAK', B) = '');

  Cikti.Add('--- Yapi ve veri kopyasi (hedefte tablo yok) ---');
  S := TabloKopyala(A, 'T_KAYNAK', B, 'T_KAYNAK', True, nil);
  if not S.Basarili then
    Cikti.Add('      ' + S.Cumle + ' | ' + S.Ayrinti);
  Kontrol('kopyalama basarili', S.Basarili and S.TabloOlustu);
  Kontrol('1200 satir kopyalandi', S.Kopyalanan = SATIR_SAYISI);
  Kontrol('hedefte 1200 satir', Oku(B, 'select count(*) from t_kaynak') = IntToStr(SATIR_SAYISI));
  Kontrol('CREATE komutlari kaydedildi', Length(S.Komutlar) >= 2);
  Kontrol('Turkce metin ayni', Oku(B, 'select ad from t_kaynak where id = 1') = TURKCE);
  Kontrol('sayi (NUMERIC) ayni', Oku(B, 'select cast(sayi * 100 as integer) from t_kaynak where id = 5') = '525');
  Kontrol('tarih ayni', Oku(B, 'select extract(year from tarih) || ''-'' || extract(month from tarih) || ''-'' || extract(day from tarih) from t_kaynak where id = 5') = '2024-1-31');
  Kontrol('zaman ayni', Oku(B, 'select extract(hour from zaman) || '':'' || extract(minute from zaman) from t_kaynak where id = 5') = '13:45');
  Kontrol('memo (BLOB metin) ayni', Oku(B, 'select notu from t_kaynak where id = 7') = 'not7');
  Kontrol('ikili BLOB bayt bayt ayni', Oku(B, 'select hex_encode(cast(ikili as varbinary(10))) from t_kaynak where id = 7') = Oku(A, 'select hex_encode(cast(ikili as varbinary(10))) from t_kaynak where id = 7'));
  Kontrol('domain kolonu ayni', Oku(B, 'select etiket from t_kaynak where id = 9') = 'E9');
  Kontrol('NULL''lar NULL kaldi (sayi, tarih, memo, ikili, kod)',
    (Oku(B, 'select sayi from t_kaynak where id = 2') = '<NULL>') and (Oku(B, 'select tarih from t_kaynak where id = 2') = '<NULL>') and
    (Oku(B, 'select notu from t_kaynak where id = 2') = '<NULL>') and (Oku(B, 'select ikili from t_kaynak where id = 2') = '<NULL>') and
    (Oku(B, 'select kod from t_kaynak where id = 2') = '<NULL>'));
  Kontrol('hesaplanan kolon hedefte kendiliginden hesaplandi', Oku(B, 'select hes from t_kaynak where id = 3') = 'ad3!');
  Kontrol('PRIMARY KEY kopyalandi', Oku(B, 'select count(*) from rdb$relation_constraints where rdb$relation_name = ''T_KAYNAK'' and rdb$constraint_type = ''PRIMARY KEY''') = '1');
  Kontrol('UNIQUE kopyalandi', Oku(B, 'select count(*) from rdb$relation_constraints where rdb$relation_name = ''T_KAYNAK'' and rdb$constraint_type = ''UNIQUE''') = '1');
  Kontrol('CHECK kopyalandi', Oku(B, 'select count(*) from rdb$relation_constraints where rdb$relation_name = ''T_KAYNAK'' and rdb$constraint_type = ''CHECK''') = '1');
  Kontrol('FOREIGN KEY KOPYALANMADI', Oku(B, 'select count(*) from rdb$relation_constraints where rdb$relation_name = ''T_KAYNAK'' and rdb$constraint_type = ''FOREIGN KEY''') = '0');
  Kontrol('index kopyalandi (yeni adla)', Oku(B, 'select count(*) from rdb$indices where rdb$relation_name = ''T_KAYNAK'' and rdb$index_name starting with ''IX_T_KAYNAK''') = '1');
  Kontrol('kaynak tablo degismedi (1200 satir)', Oku(A, 'select count(*) from t_kaynak') = IntToStr(SATIR_SAYISI));

  Cikti.Add('--- Hedefte tablo var: yalniz veri eklenir ---');
  S := TabloKopyala(A, 'T_KAYNAK', B, 'T_KAYNAK', True, nil);
  Kontrol('ayni anahtarlar: kopyalama basarisiz', not S.Basarili);
  Cikti.Add('      ' + S.Cumle);
  Kontrol('hata satir numarasini soyluyor', Pos('1', S.Cumle) > 0);
  Kontrol('hicbir satir eklenmedi (hala 1200)', Oku(B, 'select count(*) from t_kaynak') = IntToStr(SATIR_SAYISI));
  Komut(B, 'CREATE TABLE T_HEDEF (ID INTEGER NOT NULL PRIMARY KEY, AD VARCHAR(40), EKSTRA INTEGER DEFAULT 7)');
  S := TabloKopyala(A, 'T_KAYNAK', B, 'T_HEDEF', True, nil);
  if not S.Basarili then
    Cikti.Add('      ' + S.Cumle + ' | ' + S.Ayrinti);
  Kontrol('var olan tabloya ekleme basarili (tablo yeni olusmadi)', S.Basarili and not S.TabloOlustu);
  Kontrol('ortak kolonlar (ID, AD) eklendi: 1200 satir', Oku(B, 'select count(*) from t_hedef') = IntToStr(SATIR_SAYISI));
  Kontrol('hedefte olup kaynakta olmayan kolon DEFAULT aldi', Oku(B, 'select count(*) from t_hedef where ekstra = 7') = IntToStr(SATIR_SAYISI));
  Komut(B, 'CREATE TABLE T_HEDEF2 (X INTEGER)');
  S := TabloKopyala(A, 'T_KAYNAK', B, 'T_HEDEF2', True, nil);
  Kontrol('ortak kolon yok: basarisiz ve anlasilir', (not S.Basarili) and (S.Cumle <> ''));

  Cikti.Add('--- Ayni veritabaninda baska ada ---');
  S := TabloKopyala(A, 'T_KAYNAK', A, 'T_KOPYA', True, nil);
  if not S.Basarili then
    Cikti.Add('      ' + S.Cumle + ' | ' + S.Ayrinti);
  Kontrol('ayni veritabaninda kopya basarili', S.Basarili and (Oku(A, 'select count(*) from t_kopya') = IntToStr(SATIR_SAYISI)));
  Kontrol('kopyada PRIMARY KEY var', Oku(A, 'select count(*) from rdb$relation_constraints where rdb$relation_name = ''T_KOPYA'' and rdb$constraint_type = ''PRIMARY KEY''') = '1');

  Cikti.Add('--- Iptal ve yalniz yapi ---');
  Iptalci := TIptalci.Create;
  try
    S := TabloKopyala(A, 'T_KAYNAK', B, 'T_IPTAL', True, Iptalci.Ilerleme);
  finally
    Iptalci.Free;
  end;
  Kontrol('iptal: Sonuc.Iptal', S.Iptal and not S.Basarili);
  Kontrol('iptal: tablo olustu ama hicbir satir eklenmedi', S.TabloOlustu and (Oku(B, 'select count(*) from t_iptal') = '0'));
  S := TabloKopyala(A, 'T_KAYNAK', B, 'T_YAPI', False, nil);
  Kontrol('yalniz yapi: tablo var, bos', S.Basarili and S.TabloOlustu and (Oku(B, 'select count(*) from t_yapi') = '0'));
end;

procedure DilAnahtarTesti;
const
  Anahtarlar: array[0..25] of string = ('MENU_TABLO_KOPYALA', 'KOPYA_BASLIK', 'KOPYA_KAYNAK', 'KOPYA_HEDEF_DB', 'KOPYA_HEDEF_AD',
    'KOPYA_VERI', 'KOPYA_DURUM_YOK', 'KOPYA_DURUM_VAR', 'KOPYA_BASLAT', 'KOPYA_AD_BOS', 'KOPYA_AYNI', 'KOPYA_ONAY_YENI',
    'KOPYA_ONAY_VAR', 'KOPYA_ONAY_VERI', 'KOPYA_ONAY_YAPI', 'KOPYA_ONAY_NOT', 'KOPYA_ONAY_SORU', 'KOPYA_ILERLEME',
    'MSG_KOPYA_TAMAM', 'MSG_KOPYA_YAPI_TAMAM', 'MSG_KOPYA_IPTAL', 'MSG_KOPYA_TABLO_BOS_KALDI', 'ERR_KOPYA_YAPILAMADI',
    'ERR_KOPYA_DOMAIN', 'ERR_KOPYA_ORTAK_KOLON_YOK', 'ERR_KOPYA_SATIR');
var
  Dil, Anahtar, Eksik: string;
begin
  for Dil in ['tr', 'en', 'de'] do
  begin
    DilYukle(Dil);
    Eksik := '';
    for Anahtar in Anahtarlar do
      if T(Anahtar) = Anahtar then
        Eksik := Eksik + ' ' + Anahtar;
    Kontrol('dil ' + Dil + ': 7f anahtarlari tam' + IfThen(Eksik <> '', ' (eksik:' + Eksik + ')'), Eksik = '');
    try
      Kontrol('dil ' + Dil + ': bicimli mesajlar gecerli',
        (Pos('T_X', TF('KOPYA_ONAY_YENI', ['T_X', 'DB', 'T_Y'])) > 0) and (Pos('T_Y', TF('KOPYA_ONAY_VAR', ['T_X', 'DB', 'T_Y'])) > 0) and
        (Pos('DB', TF('MSG_KOPYA_TAMAM', ['T_X', 'DB', 'T_Y', 5])) > 0) and (Pos('T_Y', TF('MSG_KOPYA_YAPI_TAMAM', ['T_X', 'DB', 'T_Y'])) > 0) and
        (Pos('DB', TF('KOPYA_KAYNAK', ['T_X', 5, 'DB'])) > 0));
    except
      Kontrol('dil ' + Dil + ': mesaj bicim hatasi', False);
    end;
  end;
  DilYukle('tr');
end;

var
  TanimA, TanimB: TBaglantiTanimi;
  Klasor, Damga, YolA, YolB: string;
  Gomulu: Boolean;
begin
  Cikti := TStringList.Create;
  A := nil;
  B := nil;
  try
    try
      DilYukle('tr');
      Gomulu := Ortam('FBTEST_SUNUCU', '') = '';
      Klasor := Ortam('FBTEST_KLASOR', TPath.Combine(GetEnvironmentVariable('TEMP'), 'kopyatest'));
      if Gomulu then
        ForceDirectories(Klasor);
      Damga := FormatDateTime('yyyymmdd_hhnnss', Now);
      YolA := IncludeTrailingPathDelimiter(Klasor) + 'kaynak_' + Damga + '.fdb';
      YolB := IncludeTrailingPathDelimiter(Klasor) + 'hedef_' + Damga + '.fdb';
      TanimA := TanimYap('kopya_a', YolA);
      TanimB := TanimYap('kopya_b', YolB);
      FbVeritabaniOlustur(TanimA);
      FbVeritabaniOlustur(TanimB);
      A := FbBaglan(TanimA);
      B := FbBaglan(TanimB);
      Cikti.Add('--- Surum ' + A.Surum + ' ---');
      KaynakKur;
      KopyaTesti;
      Cikti.Add('--- Dil anahtarlari ---');
      DilAnahtarTesti;
      FbBaglantiyiKes(A);
      FbBaglantiyiKes(B);
      A := nil;
      B := nil;
      if Gomulu then
      begin
        ForceDirectories(TPath.Combine(Klasor, '_arsiv'));
        TFile.Move(YolA, TPath.Combine(TPath.Combine(Klasor, '_arsiv'), ExtractFileName(YolA)));
        TFile.Move(YolB, TPath.Combine(TPath.Combine(Klasor, '_arsiv'), ExtractFileName(YolB)));
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
