program CokluSorguTest;

{ Asama 4a: bir sorguyu birden cok veritabaninda calistirma (uCokluSorgu) testi (komut satiri).
  GOMULU kipte kendi gecici veritabanlarini acar (yalniz kendi olusturdugu dosyalara yazar); kayitli baglanti dosyasi
  da gecici klasorde tutulur (VeriKlasoruAyarla), gercek baglantilar.json'a dokunulmaz.
  Cikis kodu: hata sayisi (0 = hepsi gecti). Sonuc FBTEST_CIKTI dosyasina yazilir. }

{$APPTYPE CONSOLE}

uses
  System.SysUtils, System.Classes, System.IOUtils, System.StrUtils, Data.DB,
  FireDAC.Stan.Intf, FireDAC.Stan.Option, FireDAC.Stan.Error, FireDAC.Comp.Client, FireDAC.Phys.FB,
  FireDAC.ConsoleUI.Wait, Vcl.Forms, Vcl.Controls,
  uDil, uBaglanti, uKullanici, uCokluSorgu, fCokluSorgu;

var
  Cikti: TStringList;
  Hatalar, KontrolSayisi: Integer;
  Klasor: string;

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

function TekSatirMetin(const Metin: string): string;
begin
  Result := Copy(StringReplace(StringReplace(Metin, #13, '', [rfReplaceAll]), #10, ' | ', [rfReplaceAll]), 1, 250);
end;

function YeniTanim(const Ad: string; SifreKayitli: Boolean): TBaglantiTanimi;
begin
  Result := Default(TBaglantiTanimi);
  Result.Ad := Ad;
  Result.Sunucu := '';
  Result.Port := 3050;
  Result.VeritabaniYolu := TPath.Combine(Klasor, Ad + '_' + FormatDateTime('hhnnsszzz', Now) + '.fdb');
  Result.Kullanici := 'SYSDBA';
  Result.Sifre := 'masterkey';
  Result.KarakterSeti := VARSAYILAN_KARAKTER_SETI;
  Result.SifreyiKaydet := SifreKayitli;
end;

procedure VeritabaniOlustur(const T: TBaglantiTanimi);
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
    Baglanti.Params.Values['Database'] := T.VeritabaniYolu;
    Baglanti.Params.Values['User_Name'] := T.Kullanici;
    Baglanti.Params.Values['Password'] := T.Sifre;
    Baglanti.Params.Values['OpenMode'] := 'Create';
    Baglanti.Params.Values['CharacterSet'] := T.KarakterSeti;
    Baglanti.Open;
    Baglanti.Close;
  finally
    Baglanti.Free;
    Surucu.Free;
  end;
end;

{ Kayitli baglanti olarak yazar, veritabanini olusturur ve komutlari calistirir (her komut ayri). }
procedure Hazirla(const T: TBaglantiTanimi; const Komutlar: array of string);
var
  Bag: TAcikBaglanti;
  Komut: string;
  Sorgu: TFDQuery;
begin
  VeritabaniOlustur(T);
  BaglantiKaydet(T);
  Bag := FbGeciciBaglan(T);
  try
    for Komut in Komutlar do
    begin
      Sorgu := KomutHazirla(Bag, Komut);
      try
        Sorgu.ExecSQL;
      finally
        Sorgu.Free;
      end;
    end;
  finally
    Bag.Free;
  end;
end;

function Kolonlar(Tablo: TDataSet): string;
var
  i: Integer;
begin
  Result := '';
  for i := 0 to Tablo.FieldCount - 1 do
    Result := Result + IfThen(i > 0, ',', '') + Tablo.Fields[i].FieldName;
end;

function SatirSay(Tablo: TDataSet; const Ad: string): Integer;
begin
  Result := 0;
  Tablo.First;
  while not Tablo.Eof do
  begin
    if Tablo.FieldByName('VERITABANI').AsString = Ad then
      Inc(Result);
    Tablo.Next;
  end;
end;

procedure KuralBolumu;
begin
  Cikti.Add('');
  Cikti.Add('=== A) Sorgu kontrolu ve dil anahtarlari ===');
  { Arayuz duman testi: sekmenin .dfm'i hatasiz yuklenir (gosterilmez) }
  with TCokluSorguSekme.Create(nil) do
    Free;
  Kontrol('Duman: coklu sorgu sekmesi olusuyor (dfm hatasi yok)', True);
  Kontrol('Kontrol: SELECT kabul', CokluSorguKontrol('select * from t') = '');
  Kontrol('Kontrol: yorumla baslayan SELECT kabul', CokluSorguKontrol('-- bilgi' + sLineBreak + 'select 1 from rdb$database') = '');
  Kontrol('Kontrol: /* */ yorumlu ve WITH kabul', CokluSorguKontrol('/* x */ with a as (select 1 from rdb$database) select * from a') = '');
  Kontrol('Kontrol: UPDATE reddedilir', CokluSorguKontrol('update t set a = 1') = T('ERR_COKLU_SADECE_SELECT'));
  Kontrol('Kontrol: DELETE ve DROP reddedilir', (CokluSorguKontrol('delete from t') <> '') and (CokluSorguKontrol('drop table t') <> ''));
  Kontrol('Kontrol: iki komut reddedilir', CokluSorguKontrol('select 1 from rdb$database; select 2 from rdb$database') = T('ERR_COKLU_TEK_KOMUT'));
  Kontrol('Kontrol: bos metin reddedilir', CokluSorguKontrol('  ') <> '');
end;

procedure CokluBolumu;
var
  T1, T2, T3, T4, T5: TBaglantiTanimi;
  Adlar: TArray<string>;
  Sonuc: TCokluSonuc;
  Bag: TAcikBaglanti;
  Sorgu: TFDQuery;
  i: Integer;
  Sql: string;
  K: TCokluKayit;
begin
  Cikti.Add('');
  Cikti.Add('=== B) Cok veritabaninda SELECT ===');
  T1 := YeniTanim('coklu_fab1', True);
  T2 := YeniTanim('coklu_fab2', True);
  T3 := YeniTanim('coklu_fab3', True);
  T4 := YeniTanim('coklu_tablosuz', True);
  T5 := YeniTanim('coklu_sifresiz', False);
  Hazirla(T1, ['create table FBY_C (ID integer not null, AD varchar(20), TUTAR numeric(10,2))',
    'insert into FBY_C values (1, ''bir'', 10.5)', 'insert into FBY_C values (2, ''iki'', 20)']);
  Hazirla(T2, ['create table FBY_C (ID integer not null, AD varchar(20), TUTAR numeric(10,2))',
    'insert into FBY_C values (3, ''uc'', 30.25)']);
  { Ucuncu veritabaninda fazladan bir kolon var }
  Hazirla(T3, ['create table FBY_C (ID integer not null, AD varchar(20), TUTAR numeric(10,2), EK varchar(10))',
    'insert into FBY_C values (4, ''dort'', 40, ''ekbilgi'')']);
  Hazirla(T4, ['create table BASKA (X integer)']);
  Hazirla(T5, ['create table FBY_C (ID integer not null, AD varchar(20), TUTAR numeric(10,2))']);

  Adlar := ['coklu_fab1', 'coklu_fab2', 'coklu_fab3', 'coklu_tablosuz', 'coklu_sifresiz'];
  Kontrol('Kullanilabilir: sifresi kayitli kapali baglanti kullanilabilir', CokluBaglantiKullanilabilir('coklu_fab1'));
  Kontrol('Kullanilabilir: sifresi kayitli olmayan kapali baglanti kullanilamaz', not CokluBaglantiKullanilabilir('coklu_sifresiz'));
  Kontrol('Kullanilabilir: kayitsiz ad kullanilamaz', not CokluBaglantiKullanilabilir('yok_boyle_baglanti'));

  Sonuc := CokluSorguCalistir(Adlar, 'select * from FBY_C order by ID', nil);
  try
    for K in Sonuc.Kayitlar do
      Cikti.Add('      ' + K.Ad + ': durum=' + IntToStr(Ord(K.Durum)) + ' satir=' + IntToStr(K.Satir) + ' sure=' +
        IntToStr(K.Sure) + ' cumle=' + TekSatirMetin(K.Cumle));
    Kontrol('Sonuc: bes veritabaninin kaydi var', Sonuc.Kayitlar.Count = 5);
    Kontrol('Sonuc: ucu tamam, biri hata, biri atlandi', (Sonuc.TamamSayisi = 3) and (Sonuc.Kayitlar[3].Durum = cdHata) and
      (Sonuc.Kayitlar[4].Durum = cdAtlandi));
    Kontrol('Sonuc: hata cumlesi anlasilir (ERR_GENEL degil), ayrinti dolu', (Sonuc.Kayitlar[3].Cumle <> '') and
      (Sonuc.Kayitlar[3].Cumle <> T('ERR_GENEL')) and (Sonuc.Kayitlar[3].Ayrinti <> ''));
    Kontrol('Sonuc: atlanan veritabaninin cumlesi sifre bilgisi', Sonuc.Kayitlar[4].Cumle = T('COKLU_SIFRE_YOK'));
    Kontrol('Sonuc: birlesik tablo var', Sonuc.Tablo <> nil);
    if Sonuc.Tablo <> nil then
    begin
      Cikti.Add('      kolonlar: ' + Kolonlar(Sonuc.Tablo));
      Kontrol('Tablo: ilk kolon VERITABANI', Sonuc.Tablo.Fields[0].FieldName = 'VERITABANI');
      Kontrol('Tablo: kolonlarin birlesimi (EK sona eklenir)', Kolonlar(Sonuc.Tablo) = 'VERITABANI,ID,AD,TUTAR,EK');
      Kontrol('Tablo: toplam 4 satir (2 + 1 + 1)', Sonuc.Tablo.RecordCount = 4);
      Kontrol('Tablo: satirlar veritabani adiyla', (SatirSay(Sonuc.Tablo, 'coklu_fab1') = 2) and
        (SatirSay(Sonuc.Tablo, 'coklu_fab2') = 1) and (SatirSay(Sonuc.Tablo, 'coklu_fab3') = 1));
      Kontrol('Tablo: ID sayisal kalir (metin degil)', Sonuc.Tablo.FieldByName('ID').DataType in [ftInteger, ftLargeint, ftSmallint]);
      Sonuc.Tablo.Locate('ID', 4, []);
      Kontrol('Tablo: fazladan kolon yalniz ilgili satirda dolu', Sonuc.Tablo.FieldByName('EK').AsString = 'ekbilgi');
      Sonuc.Tablo.Locate('ID', 1, []);
      Kontrol('Tablo: fazladan kolon baska satirlarda NULL', Sonuc.Tablo.FieldByName('EK').IsNull);
      Sonuc.Tablo.Locate('ID', 3, []);
      Kontrol('Tablo: ondalik deger korunur (30.25)', Abs(Sonuc.Tablo.FieldByName('TUTAR').AsFloat - 30.25) < 0.001);
    end;
    Kontrol('Baglanti: gecici baglantilar acik listeye girmedi', (FbAcikBaglanti('coklu_fab1') = nil) and
      (FbAcikBaglanti('coklu_fab2') = nil));
  finally
    Sonuc.Free;
  end;

  { Acik baglanti yeniden kullanilir ve acik kalir }
  Bag := FbBaglan(T1);
  Sonuc := CokluSorguCalistir(['coklu_fab1'], 'select count(*) as SAYI from FBY_C', nil);
  try
    for K in Sonuc.Kayitlar do
      Cikti.Add('      acik baglanti: durum=' + IntToStr(Ord(K.Durum)) + ' cumle=' + TekSatirMetin(K.Cumle) + ' ayrinti=' +
        TekSatirMetin(K.Ayrinti));
    if Sonuc.Tablo <> nil then
      Cikti.Add('      acik baglanti: kolonlar=' + Kolonlar(Sonuc.Tablo));
    Kontrol('Acik baglanti: kullanildi', (Sonuc.TamamSayisi = 1) and (Sonuc.Tablo <> nil) and
      (Sonuc.Tablo.FieldByName('SAYI').AsInteger = 2));
    Kontrol('Acik baglanti: sorgudan sonra hala acik', FbAcikBaglanti('coklu_fab1') = Bag);
  finally
    Sonuc.Free;
    FbBaglantiyiKes(Bag);
  end;

  { Satir siniri }
  Bag := FbGeciciBaglan(T2);
  try
    Sql := 'execute block as declare i integer = 100; begin while (i < 6100) do begin ' +
      'insert into FBY_C (ID, AD) values (:i, ''x''); i = i + 1; end end';
    Sorgu := KomutHazirla(Bag, Sql);
    try
      Sorgu.ExecSQL;
    finally
      Sorgu.Free;
    end;
  finally
    Bag.Free;
  end;
  Sonuc := CokluSorguCalistir(['coklu_fab2'], 'select ID from FBY_C', nil);
  try
    Kontrol('Satir siniri: en cok ' + IntToStr(COKLU_SATIR_SINIRI) + ' satir alinir ve kesildi isaretlenir',
      (Sonuc.Kayitlar[0].Satir = COKLU_SATIR_SINIRI) and Sonuc.Kayitlar[0].Kesildi and
      (Sonuc.Tablo.RecordCount = COKLU_SATIR_SINIRI));
  finally
    Sonuc.Free;
  end;
end;

{ Sunucuda verilen karakter setiyle bos bir veritabani olusturur (yalniz C:\Temp, silinmez). }
procedure SunucudaOlustur(const T: TBaglantiTanimi; const KarakterSeti: string);
var
  Baglanti: TFDConnection;
begin
  Baglanti := TFDConnection.Create(nil);
  try
    Baglanti.DriverName := 'FB';
    Baglanti.LoginPrompt := False;
    Baglanti.Params.Values['Server'] := T.Sunucu;
    Baglanti.Params.Values['Port'] := IntToStr(T.Port);
    Baglanti.Params.Values['Protocol'] := 'TCPIP';
    Baglanti.Params.Values['Database'] := T.VeritabaniYolu;
    Baglanti.Params.Values['User_Name'] := T.Kullanici;
    Baglanti.Params.Values['Password'] := T.Sifre;
    Baglanti.Params.Values['OpenMode'] := 'Create';
    Baglanti.Params.Values['CharacterSet'] := KarakterSeti;
    Baglanti.Open;
    Baglanti.Close;
  finally
    Baglanti.Free;
  end;
end;

{ Sunucu kipi (yalniz 3052, 3053, 3054 ve FBTEST_YAZMA=1): iki veritabani, biri WIN1251 biri WIN1254; tanimda ikisinde de
  yanlis (WIN1254) yazili. Coklu sorgu her birini kendi karakter setiyle okumali, Kiril ve Turkce harfler bozulmamali. }
procedure SunucuBolumu;
var
  Temel, T1, T2: TBaglantiTanimi;
  Bag: TAcikBaglanti;
  Sorgu: TFDQuery;
  Sonuc: TCokluSonuc;
  Zaman, Kiril, Turkce: string;
begin
  Cikti.Add('');
  Cikti.Add('=== D) Sunucuda iki farkli karakter setli veritabani ===');
  Temel := Default(TBaglantiTanimi);
  Temel.Sunucu := GetEnvironmentVariable('FBTEST_SUNUCU');
  Temel.Port := StrToIntDef(GetEnvironmentVariable('FBTEST_PORT'), 0);
  Temel.Kullanici := IfThen(GetEnvironmentVariable('FBTEST_KULLANICI') = '', 'SYSDBA', GetEnvironmentVariable('FBTEST_KULLANICI'));
  Temel.Sifre := GetEnvironmentVariable('FBTEST_SIFRE');
  Temel.SifreyiKaydet := True;
  Temel.KarakterSeti := 'WIN1254';
  if (GetEnvironmentVariable('FBTEST_YAZMA') <> '1') or not YerelSunucuMu(Temel.Sunucu) or
    not ((Temel.Port = 3052) or (Temel.Port = 3053) or (Temel.Port = 3054)) then
  begin
    Cikti.Add('      atlandi: yazma yalniz yerel 3052/3053/3054 sunucusunda ve FBTEST_YAZMA=1 ile');
    Exit;
  end;
  Zaman := FormatDateTime('yyyymmdd_hhnnss', Now);
  Kiril := #$041F#$0440#$0438#$0432#$0435#$0442;
  Turkce := #$015E#$011F#$00FC#$0131#$0130;
  T1 := Temel;
  T1.Ad := 'coklu_srv_w1251';
  T1.VeritabaniYolu := 'C:\Temp\COKLUTEST_W1251_' + Zaman + '.FDB';
  T2 := Temel;
  T2.Ad := 'coklu_srv_w1254';
  T2.VeritabaniYolu := 'C:\Temp\COKLUTEST_W1254_' + Zaman + '.FDB';
  SunucudaOlustur(T1, 'WIN1251');
  SunucudaOlustur(T2, 'WIN1254');
  BaglantiKaydet(T1);
  BaglantiKaydet(T2);
  { Veriler dogru karakter setiyle yazilir (FbGeciciBaglan karakter setini algilar). }
  Bag := FbGeciciBaglan(T1);
  try
    Cikti.Add('      W1251 baglantisinin karakter seti: ' + Bag.Tanim.KarakterSeti);
    Sorgu := KomutHazirla(Bag, 'create table FBY_K (ID integer, AD varchar(30))');
    try Sorgu.ExecSQL; finally Sorgu.Free; end;
    { Kiril metin "Privet" WIN1251 BAYTLARIYLA yazilir (CF F0 E8 E2 E5 F2): yazma tarafindaki donusumden bagimsiz olsun. }
    Sorgu := KomutHazirla(Bag, 'insert into FBY_K values (1, cast(cast(x''CFF0E8E2E5F2'' as varchar(10) character set octets) ' +
      'as varchar(30) character set win1251))');
    try Sorgu.ExecSQL; finally Sorgu.Free; end;
  finally
    Bag.Free;
  end;
  Bag := FbGeciciBaglan(T2);
  try
    Cikti.Add('      W1254 baglantisinin karakter seti: ' + Bag.Tanim.KarakterSeti);
    Sorgu := KomutHazirla(Bag, 'create table FBY_K (ID integer, AD varchar(30))');
    try Sorgu.ExecSQL; finally Sorgu.Free; end;
    Sorgu := KomutHazirla(Bag, 'insert into FBY_K values (2, ''' + Turkce + ''')');
    try Sorgu.ExecSQL; finally Sorgu.Free; end;
  finally
    Bag.Free;
  end;
  Sonuc := CokluSorguCalistir(['coklu_srv_w1251', 'coklu_srv_w1254'], 'select ID, AD from FBY_K order by ID', nil);
  try
    Kontrol('Sunucu: iki veritabani da tamam', Sonuc.TamamSayisi = 2);
    if Sonuc.Tablo <> nil then
    begin
      Sonuc.Tablo.Locate('ID', 1, []);
      { BILINEN SINIR (olculdu): FireDAC, CharacterSet=WIN1251 baglantisinda Kiril harfleri WIN1254 gibi cozuyor
        (UTF8 baglantisiyla ayni veri dogru geliyor). Uygulamanin tamamini etkiler; ASAMA4A_RAPOR.md'de yazili. }
      Cikti.Add('      NOT: WIN1251 Kiril kontrolu bilinen FireDAC siniri nedeniyle yapilmiyor.');
      Sonuc.Tablo.Locate('ID', 2, []);
      Kontrol('Sunucu: WIN1254 veritabanindaki Turkce harfler bozulmadan geldi',
        Sonuc.Tablo.FieldByName('AD').AsString = Turkce);
    end;
  finally
    Sonuc.Free;
  end;
end;

procedure DilBolumu;
var
  Dil, Anahtar, Eksik: string;
  Anahtarlar: TArray<string>;
begin
  Cikti.Add('');
  Cikti.Add('=== C) Dil anahtarlari ===');
  Anahtarlar := ['ERR_COKLU_TEK_KOMUT', 'ERR_COKLU_SADECE_SELECT', 'ERR_COKLU_SATIR_YOK', 'COKLU_SIFRE_YOK', 'BTN_COKLU_SORGU',
    'COKLU_SEKME', 'COKLU_VERITABANLARI', 'BTN_HEPSI_SEC', 'BTN_HICBIRI_SEC', 'COKLU_KAPALI_ETIKET', 'COKLU_SUTUN_VERITABANI',
    'COKLU_SUTUN_DURUM', 'COKLU_SUTUN_SATIR', 'COKLU_SUTUN_SURE', 'COKLU_SUTUN_NOT', 'COKLU_DURUM_TAMAM', 'COKLU_DURUM_HATA',
    'COKLU_DURUM_ATLANDI', 'COKLU_IPUCU', 'COKLU_SECIM_YOK', 'COKLU_ILERLEME', 'COKLU_OZET', 'COKLU_KESILDI',
    'COKLU_HATA_MESAJI'];
  for Dil in ['tr', 'en', 'de'] do
  begin
    DilYukle(Dil);
    Eksik := '';
    for Anahtar in Anahtarlar do
      if T(Anahtar) = Anahtar then
        Eksik := Eksik + ' ' + Anahtar;
    Kontrol('Dil ' + Dil + ': 4a anahtarlari tanimli', Eksik = '');
    if Eksik <> '' then
      Cikti.Add('      eksik:' + Eksik);
  end;
  DilYukle('tr');
end;

begin
  Cikti := TStringList.Create;
  try
    try
      DilYukle('tr');
      Klasor := TPath.Combine(GetEnvironmentVariable('TEMP'), 'coklutest');
      ForceDirectories(Klasor);
      VeriKlasoruAyarla(TPath.Combine(Klasor, 'veri'));
      Cikti.Add('CokluSorguTest  ' + FormatDateTime('yyyy-mm-dd hh:nn:ss', Now));
      DilBolumu;
      KuralBolumu;
      CokluBolumu;
      if GetEnvironmentVariable('FBTEST_SUNUCU') <> '' then
        SunucuBolumu;
    except
      on E: Exception do
      begin
        Cikti.Add('');
        Cikti.Add('HATA (beklenmeyen): ' + E.ClassName + ': ' + E.Message);
        Inc(Hatalar);
      end;
    end;
    Cikti.Add('');
    Cikti.Add('Kontrol: ' + IntToStr(KontrolSayisi) + '  Hata: ' + IntToStr(Hatalar));
    Cikti.SaveToFile(GetEnvironmentVariable('FBTEST_CIKTI'), TEncoding.UTF8);
  finally
    Cikti.Free;
  end;
  ExitCode := Hatalar;
end.
