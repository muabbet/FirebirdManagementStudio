program TabloTasarimTest;

{ Asama 7g: uTabloTasarim (tabloyu tasarlayip olusturma) testi (komut satiri).
  Gecici bir veritabani acilir; gercek veriye dokunulmaz.
  Ortam degiskenleri: FBTEST_SUNUCU (bos = yerel), FBTEST_PORT, FBTEST_KLASOR, FBTEST_KULLANICI, FBTEST_SIFRE, FBTEST_CIKTI.
  Cikis kodu: hata sayisi (0 = hepsi gecti). }

{$APPTYPE CONSOLE}

uses
  System.SysUtils, System.Classes, System.StrUtils, System.IOUtils, Data.DB,
  FireDAC.Stan.Intf, FireDAC.Stan.Option, FireDAC.Stan.Error, FireDAC.Comp.Client, FireDAC.Phys.FB,
  FireDAC.ConsoleUI.Wait,
  uDil, uBaglanti, uSorgu, uMetadata, uProsedur, uKolon, uTabloTasarim;

var
  Cikti: TStringList;
  Hatalar, KontrolSayisi: Integer;
  Bag: TAcikBaglanti;
  Tipler: TArray<TVeriTipi>;

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
      Result := Trim(Q.Fields[0].AsString);
  finally
    Q.Free;
  end;
end;

function Kolon(const Ad, Tip, Boyut: string; BosOlmaz, Birincil, OtoArtan: Boolean; const Varsayilan: string): TTasarimKolon;
begin
  Result.Ad := Ad;
  Result.Tip := Tip;
  Result.Boyut := Boyut;
  Result.BosOlmaz := BosOlmaz;
  Result.Birincil := Birincil;
  Result.OtoArtan := OtoArtan;
  Result.Varsayilan := Varsayilan;
end;

function Dogrula(const Tablo: string; const K: TArray<TTasarimKolon>): string;
begin
  Result := TasarimDogrula(Bag, Tablo, K, Tipler);
end;

procedure TipTesti;
var
  Tip: TVeriTipi;
begin
  Kontrol('tip listesi dolu (veri_tipleri.txt okundu)', Length(Tipler) > 10);
  Kontrol('VARCHAR bulunur ve uzunluk ister', TasarimTipiBul('varchar', Tipler, Tip) and (Tip.Parametre = tpUzunluk));
  Kontrol('VARCHAR varsayilan boyut 50', TasarimBoyutVarsayilani(Tip) = '50');
  Kontrol('NUMERIC varsayilan boyut 18,2', TasarimTipiBul('NUMERIC', Tipler, Tip) and (TasarimBoyutVarsayilani(Tip) = '18,2'));
  Kontrol('INTEGER boyut istemez', TasarimTipiBul('INTEGER', Tipler, Tip) and (TasarimBoyutVarsayilani(Tip) = ''));
  Kontrol('olmayan tip bulunamaz', not TasarimTipiBul('YOKTIP', Tipler, Tip));
  Kontrol('tam sayi tipleri', TasarimTamSayiMi('INTEGER') and TasarimTamSayiMi('bigint') and not TasarimTamSayiMi('VARCHAR'));
end;

procedure DogrulamaTesti;
var
  Gecerli: TArray<TTasarimKolon>;
begin
  Gecerli := [Kolon('ID', 'INTEGER', '', True, True, False, '')];
  Kontrol('gecerli tasarim: uyari yok', Dogrula('T_X', Gecerli) = '');
  Kontrol('bos tablo adi', Dogrula('  ', Gecerli) <> '');
  Kontrol('kolon yok', Dogrula('T_X', []) <> '');
  Kontrol('bos kolon adi, satir numarasi soyleniyor',
    Pos('2', Dogrula('T_X', [Kolon('ID', 'INTEGER', '', False, False, False, ''), Kolon('', 'INTEGER', '', False, False, False, '')])) > 0);
  Kontrol('ayni kolon adi (buyuk/kucuk harf farksiz)',
    Dogrula('T_X', [Kolon('Ad', 'INTEGER', '', False, False, False, ''), Kolon('AD', 'INTEGER', '', False, False, False, '')]) <> '');
  Kontrol('tip secilmemis', Dogrula('T_X', [Kolon('A', '', '', False, False, False, '')]) <> '');
  Kontrol('VARCHAR boyutu 0 gecersiz', Dogrula('T_X', [Kolon('A', 'VARCHAR', '0', False, False, False, '')]) <> '');
  Kontrol('VARCHAR boyutu 40000 gecersiz', Dogrula('T_X', [Kolon('A', 'VARCHAR', '40000', False, False, False, '')]) <> '');
  Kontrol('VARCHAR boyutu yazi (abc) gecersiz', Dogrula('T_X', [Kolon('A', 'VARCHAR', 'abc', False, False, False, '')]) <> '');
  Kontrol('NUMERIC olcek hassasiyetten buyuk gecersiz', Dogrula('T_X', [Kolon('A', 'NUMERIC', '5,6', False, False, False, '')]) <> '');
  Kontrol('NUMERIC 12,2 gecerli', Dogrula('T_X', [Kolon('A', 'NUMERIC', '12,2', False, False, False, '')]) = '');
  Kontrol('otomatik artan VARCHAR olamaz', Dogrula('T_X', [Kolon('A', 'VARCHAR', '10', False, False, True, '')]) <> '');
  Kontrol('iki otomatik artan olamaz', Dogrula('T_X', [Kolon('A', 'INTEGER', '', False, False, True, ''), Kolon('B', 'INTEGER', '', False, False, True, '')]) <> '');
  Kontrol('otomatik artan + varsayilan olamaz', Dogrula('T_X', [Kolon('A', 'INTEGER', '', False, False, True, '5')]) <> '');
  Kontrol('bos tablo adinda script uretilmez', TasarimScripti(Bag, '', Gecerli, Tipler) = '');
end;

procedure OlusturmaTesti;
var
  K: TArray<TTasarimKolon>;
  Script: string;
  S: TProsedurSonucu;
  Kimlik: Boolean;
begin
  Kimlik := KimlikDestegi(Bag);
  K := [Kolon('id', 'INTEGER', '', True, True, Kimlik, ''),
    Kolon('ad', 'VARCHAR', '50', True, False, False, '''x'''),
    Kolon('sayi', 'NUMERIC', '12,2', False, False, False, ''),
    Kolon('tarih', 'DATE', '', False, False, False, 'CURRENT_DATE'),
    Kolon('notu', 'BLOB SUB_TYPE TEXT', '', False, False, False, '')];
  Script := TasarimScripti(Bag, 'T_Tas', K, Tipler);
  Cikti.Add(StringReplace(Script, #13#10, ' | ', [rfReplaceAll]));
  Kontrol('script CREATE TABLE T_TAS (basit ad buyuk harfe cevrildi)', StartsText('CREATE TABLE T_TAS (', Script));
  Kontrol('script VARCHAR(50), NUMERIC(12,2) ve PRIMARY KEY (ID)',
    (Pos('VARCHAR(50)', Script) > 0) and (Pos('NUMERIC(12,2)', Script) > 0) and (Pos('PRIMARY KEY (ID)', Script) > 0));
  Kontrol('script varsayilan ve NOT NULL', (Pos('DEFAULT ''x'' NOT NULL', Script) > 0) and (Pos('DEFAULT CURRENT_DATE', Script) > 0));
  if Kimlik then
    Kontrol('script otomatik artan kimlik', Pos('ID INTEGER GENERATED BY DEFAULT AS IDENTITY', Script) > 0)
  else
    Kontrol('script ID NOT NULL (kimlik yok)', Pos('ID INTEGER NOT NULL', Script) > 0);
  S := TasarimOlustur(Bag, 'T_Tas', K, Tipler);
  if not S.Basarili then
    Cikti.Add('      ' + S.Cumle + ' | ' + S.Ayrinti);
  Kontrol('tablo olusturuldu', S.Basarili);
  Kontrol('calisan komut kaydedildi', (Length(S.Komutlar) = 1) and (Pos('CREATE TABLE', S.Komutlar[0]) > 0));
  Kontrol('5 kolon, sirasi ayni', Oku('select count(*) from rdb$relation_fields where rdb$relation_name = ''T_TAS''') = '5');
  Kontrol('ilk kolon ID', Oku('select rdb$field_name from rdb$relation_fields where rdb$relation_name = ''T_TAS'' and rdb$field_position = 0') = 'ID');
  Kontrol('PRIMARY KEY var', Oku('select count(*) from rdb$relation_constraints where rdb$relation_name = ''T_TAS'' and rdb$constraint_type = ''PRIMARY KEY''') = '1');
  Kontrol('AD NOT NULL', Oku('select rdb$null_flag from rdb$relation_fields where rdb$relation_name = ''T_TAS'' and rdb$field_name = ''AD''') = '1');
  Kontrol('SAYI bos olabilir', Oku('select rdb$null_flag from rdb$relation_fields where rdb$relation_name = ''T_TAS'' and rdb$field_name = ''SAYI''') = '<NULL>');
  Kontrol('SAYI olcegi 2 (NUMERIC(12,2))', Oku('select f.rdb$field_scale from rdb$relation_fields r join rdb$fields f on f.rdb$field_name = r.rdb$field_source where r.rdb$relation_name = ''T_TAS'' and r.rdb$field_name = ''SAYI''') = '-2');
  SorguCalistir(Bag, 'INSERT INTO T_TAS (AD) VALUES (''a'')').Free;
  if Kimlik then
  begin
    SorguCalistir(Bag, 'INSERT INTO T_TAS (AD) VALUES (''b'')').Free;
    Kontrol('otomatik artan: ID kendiliginden 1, 2', (Oku('select min(id) from t_tas') = '1') and (Oku('select max(id) from t_tas') = '2'));
  end
  else
    Kontrol('(kimlik yok: ID elle verilir)', True);
  Kontrol('varsayilan AD calisti', Oku('select count(*) from t_tas where ad = ''a'' or ad = ''b''') = '2');
  S := TasarimOlustur(Bag, 'T_Tas', K, Tipler);
  Kontrol('ayni adli tablo: basarisiz ve anlasilir', (not S.Basarili) and (Pos('T_TAS', S.Cumle) > 0));
end;

procedure BilesikAnahtarVeOzelAdTesti;
var
  K: TArray<TTasarimKolon>;
  Script: string;
  S: TProsedurSonucu;
  Tablo: string;
begin
  { Bilesik anahtar }
  K := [Kolon('A', 'INTEGER', '', False, True, False, ''), Kolon('B', 'INTEGER', '', False, True, False, ''), Kolon('C', 'VARCHAR', '10', False, False, False, '')];
  Script := TasarimScripti(Bag, 'T_BIL', K, Tipler);
  Kontrol('bilesik anahtar: PRIMARY KEY (A, B)', Pos('PRIMARY KEY (A, B)', Script) > 0);
  S := TasarimOlustur(Bag, 'T_BIL', K, Tipler);
  Kontrol('bilesik anahtarli tablo olustu', S.Basarili);
  Kontrol('A ve B kendiliginden NOT NULL', Oku('select count(*) from rdb$relation_fields where rdb$relation_name = ''T_BIL'' and rdb$null_flag = 1') = '2');
  { Anahtar kelime ve bosluklu / Turkce adlar tirnaga alinir }
  Tablo := 'M'#252#351'teri Listesi';
  K := [Kolon('ORDER', 'INTEGER', '', False, False, False, ''), Kolon('Ad'#305' Soyad'#305, 'VARCHAR', '30', False, False, False, '')];
  Script := TasarimScripti(Bag, Tablo, K, Tipler);
  Kontrol('bosluklu tablo adi tirnakli', Pos('CREATE TABLE "M'#252#351'teri Listesi"', Script) > 0);
  Kontrol('anahtar kelime kolon adi tirnakli', Pos('"ORDER" INTEGER', Script) > 0);
  S := TasarimOlustur(Bag, Tablo, K, Tipler);
  if not S.Basarili then
    Cikti.Add('      ' + S.Cumle + ' | ' + S.Ayrinti);
  Kontrol('ozel adli tablo olustu', S.Basarili);
  Kontrol('tablo adi aynen kaydedildi', Oku('select count(*) from rdb$relations where rdb$relation_name = ''M'#252#351'teri Listesi''') = '1');
end;

procedure DomainTesti;
var
  K: TArray<TTasarimKolon>;
  S: TProsedurSonucu;
  Yerel: TArray<TVeriTipi>;
  Tip: TVeriTipi;
begin
  SorguCalistir(Bag, 'CREATE DOMAIN D_TASKOD AS VARCHAR(12)').Free;
  Yerel := KolonTipleri(Bag);
  Kontrol('domain tip listesinde', TasarimTipiBul('D_TASKOD', Yerel, Tip) and Tip.Domain);
  K := [Kolon('ID', 'INTEGER', '', False, True, False, ''), Kolon('KOD', 'D_TASKOD', '', False, False, False, '')];
  S := TasarimOlustur(Bag, 'T_DOM', K, Yerel);
  if not S.Basarili then
    Cikti.Add('      ' + S.Cumle + ' | ' + S.Ayrinti);
  Kontrol('domain kolonlu tablo olustu', S.Basarili);
  Kontrol('kolon domain kullaniyor', Oku('select r.rdb$field_source from rdb$relation_fields r where r.rdb$relation_name = ''T_DOM'' and r.rdb$field_name = ''KOD''') = 'D_TASKOD');
end;

procedure DilAnahtarTesti;
const
  Anahtarlar: array[0..38] of string = ('MENU_YENI_TABLO_TASARIM', 'TAS_BASLIK', 'TAS_TABLO_AD', 'TAS_KOL_AD', 'TAS_KOL_TIP',
    'TAS_KOL_BOYUT', 'TAS_KOL_BOS_OLMAZ', 'TAS_KOL_BIRINCIL', 'TAS_KOL_OTO', 'TAS_KOL_VARSAYILAN', 'TAS_EVET', 'TAS_HAYIR',
    'TAS_KOLON_EKLE', 'TAS_KOLON_SIL', 'TAS_YUKARI', 'TAS_ASAGI', 'TAS_SQL', 'TAS_OLUSTUR', 'TAS_IPUCU', 'TAS_OTO_25', 'TAS_ONAY',
    'MSG_TAS_OLUSTURULDU', 'ERR_TAS_OLUSTURULAMADI', 'ERR_TAS_TABLO_AD_BOS', 'ERR_TAS_KOLON_YOK', 'ERR_TAS_KOLON_AD_BOS',
    'ERR_TAS_KOLON_AD_TEKRAR', 'ERR_TAS_TIP_YOK', 'ERR_TAS_BOYUT', 'ERR_TAS_OTO_TIP', 'ERR_TAS_OTO_VARSAYILAN',
    'ERR_TAS_OTO_COK', 'ERR_TAS_OTO_SURUM', 'ERR_TAS_TABLO_VAR', 'MENU_YENI_TABLO', 'TAS_EVET', 'TAS_HAYIR', 'TAS_EVET', 'TAS_HAYIR');
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
    Kontrol('dil ' + Dil + ': 7g anahtarlari tam' + IfThen(Eksik <> '', ' (eksik:' + Eksik + ')'), Eksik = '');
    Kontrol('dil ' + Dil + ': bicimli mesajlar gecerli',
      (Pos('T_X', TF('TAS_ONAY', ['T_X', 'SQL'])) > 0) and (Pos('T_X', TF('MSG_TAS_OLUSTURULDU', ['T_X'])) > 0) and
      (Pos('KOL', TF('ERR_TAS_BOYUT', ['KOL', 'x'])) > 0) and (Pos('3', TF('ERR_TAS_KOLON_AD_BOS', [3])) > 0));
  end;
  DilYukle('tr');
end;

var
  Tanim: TBaglantiTanimi;
  Klasor, Yol: string;
  Gomulu: Boolean;
begin
  Cikti := TStringList.Create;
  Bag := nil;
  try
    try
      DilYukle('tr');
      Gomulu := Ortam('FBTEST_SUNUCU', '') = '';
      Klasor := Ortam('FBTEST_KLASOR', TPath.Combine(GetEnvironmentVariable('TEMP'), 'tasarimtest'));
      if Gomulu then
        ForceDirectories(Klasor);
      Yol := IncludeTrailingPathDelimiter(Klasor) + 'tasarim_' + FormatDateTime('yyyymmdd_hhnnss', Now) + '.fdb';
      Tanim := Default(TBaglantiTanimi);
      Tanim.Ad := 'tasarimtest';
      Tanim.Sunucu := Ortam('FBTEST_SUNUCU', '');
      Tanim.Port := StrToInt(Ortam('FBTEST_PORT', '3050'));
      Tanim.VeritabaniYolu := Yol;
      Tanim.Kullanici := Ortam('FBTEST_KULLANICI', 'SYSDBA');
      Tanim.Sifre := Ortam('FBTEST_SIFRE', '');
      Tanim.KarakterSeti := VARSAYILAN_KARAKTER_SETI;
      FbVeritabaniOlustur(Tanim);
      Bag := FbBaglan(Tanim);
      Cikti.Add('--- Surum ' + Bag.Surum + ', kimlik destegi: ' + BoolToStr(KimlikDestegi(Bag), True) + ' ---');
      Tipler := KolonTipleri(Bag);
      Cikti.Add('--- Tipler ---');
      TipTesti;
      Cikti.Add('--- Dogrulama ---');
      DogrulamaTesti;
      Cikti.Add('--- Olusturma ---');
      OlusturmaTesti;
      Cikti.Add('--- Bilesik anahtar ve ozel adlar ---');
      BilesikAnahtarVeOzelAdTesti;
      Cikti.Add('--- Domain ---');
      DomainTesti;
      Cikti.Add('--- Dil anahtarlari ---');
      DilAnahtarTesti;
      FbBaglantiyiKes(Bag);
      Bag := nil;
      if Gomulu then
      begin
        ForceDirectories(TPath.Combine(Klasor, '_arsiv'));
        TFile.Move(Yol, TPath.Combine(TPath.Combine(Klasor, '_arsiv'), ExtractFileName(Yol)));
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
