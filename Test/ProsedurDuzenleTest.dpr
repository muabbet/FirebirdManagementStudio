program ProsedurDuzenleTest;

{ Asama 3e-1: uProsedur (sakli prosedur duzenle ve kaydet) testi (komut satiri).

  Uc bolum var:
    A) HER KIPTE: saf kurallar (ad dogrulama, SQL ozeti, hata satiri, yedek klasoru, dil anahtarlari). Veritabani gerekmez.
    B) GOMULU kip (FBTEST_SUNUCU bos): program kendi gecici veritabanini olusturur ve tum yazma testlerini orada yapar.
    C) SUNUCU kip: B bolumundeki yazma testleri YALNIZCA yerel sunucuda 3052, 3053 ve 3054 portlarinda ve
       FBTEST_YAZMA=1 verilmisse calisir; baska portta (3050 ve 3051 dahil) kod seviyesinde REDDEDILIR.
       Yazma testleri FBY_TEST_ ile baslayan prosedurler olusturur ve sonunda siler.

  Ortam degiskenleri: FBTEST_SUNUCU (bos = gomulu), FBTEST_PORT, FBTEST_YOL (sunucudaki VAR OLAN veritabani),
  FBTEST_KULLANICI, FBTEST_SIFRE, FBTEST_CIKTI (sonuc dosyasi), FBTEST_YAZMA. Sifre hicbir yere yazilmaz.
  Yedek dosyalari gecici bir veri klasorune (%TEMP%\prosedurtest_veri) yazilir, gercek veri klasorune dokunulmaz.
  Cikis kodu: hata sayisi (0 = hepsi gecti). }

{$APPTYPE CONSOLE}

uses
  System.SysUtils, System.Classes, System.StrUtils, System.IOUtils, Data.DB,
  FireDAC.Stan.Intf, FireDAC.Stan.Option, FireDAC.Stan.Error, FireDAC.Comp.Client, FireDAC.Phys.FB,
  FireDAC.ConsoleUI.Wait,
  Vcl.Forms, Vcl.Controls, Vcl.ExtCtrls,
  uDil, uBaglanti, uMetadata, uSorgu, uDDL, uKullanici, uProsedur, uEditor, fProsedurSekme;

const
  P1 = 'FBY_TEST_P1';
  P2 = 'FBY_TEST_P2';
  P_ISIM = 'FBY_TEST_Q';
  PAKET = 'FBY_TEST_PAKET';
  { Turkce harfler: g u s i(noktasiz) o c ve noktali buyuk I }
  TURKCE = #$011F#$00FC#$015F#$0131#$00F6#$00E7#$0130;
  YETKISIZ = 'FBY_YETKISIZ';

var
  Cikti: TStringList;
  Hatalar, KontrolSayisi, Sayac: Integer;
  Tanim: TBaglantiTanimi;
  Bag: TAcikBaglanti;
  Gomulu: Boolean;
  VeriKlasoru: string;

function Ortam(const Ad, Varsayilan: string): string;
begin
  Result := GetEnvironmentVariable(Ad);
  if Result = '' then
    Result := Varsayilan;
end;

function TekSatir(const Metin: string; Uzunluk: Integer = 300): string;
begin
  Result := Copy(StringReplace(StringReplace(Metin, #13, '', [rfReplaceAll]), #10, ' | ', [rfReplaceAll]), 1, Uzunluk);
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

procedure Not_(const Metin: string);
begin
  Cikti.Add('      ' + Metin);
end;

{ Hata: sinif, ham mesaj ve Firebird kodlari }
function HataKodlari(E: Exception): string;
var
  I: Integer;
begin
  Result := E.ClassName + ': ' + TekSatir(E.Message);
  if E is EFDDBEngineException then
    for I := 0 to EFDDBEngineException(E).ErrorCount - 1 do
      Result := Result + ' [kod=' + IntToStr(EFDDBEngineException(E).Errors[I].ErrorCode) + ']';
end;

procedure GeciciVeritabaniOlustur(const T: TBaglantiTanimi);
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

{ Tek komutu calistirir (kendi otomatik onayli islemiyle). Hata olursa istisna firlar. }
procedure Yurut(B: TAcikBaglanti; const Sql: string);
var
  Sorgu: TFDQuery;
begin
  Sorgu := KomutHazirla(B, Sql);
  try
    Sorgu.ExecSQL;
  finally
    Sorgu.Free;
  end;
end;

{ Hata verirse sessizce gecer (temizlik). }
procedure Dene(B: TAcikBaglanti; const Sql: string);
begin
  try
    Yurut(B, Sql);
  except
  end;
end;

{ Komutu dener, hatanin Firebird kodlarini ve bizim cumlemizi yazar (ceviri tablosunu gercek koddan kurmak icin). }
procedure KodDene(const Ad: string; B: TAcikBaglanti; const Sql: string);
begin
  try
    Yurut(B, Sql);
    Not_(Ad + ': hata YOK (komut basarili oldu)');
  except
    on E: Exception do
      Not_(Ad + ': ' + HataKodlari(E) + '  => ' + TekSatir(HataMetniniCevir(E)));
  end;
end;

function Skaler(B: TAcikBaglanti; const Sql: string): string;
var
  Sorgu: TFDQuery;
begin
  Sorgu := KomutHazirla(B, Sql);
  try
    Sorgu.Open;
    if Sorgu.Eof then
      Result := '<satir yok>'
    else
      Result := Sorgu.Fields[0].AsString;
  finally
    Sorgu.Free;
  end;
end;

function ProsedurVarMi(B: TAcikBaglanti; const Ad: string): Boolean;
begin
  Result := Skaler(B, 'select count(*) from rdb$procedures where rdb$procedure_name = ''' + Ad + '''') <> '0';
end;

function ListedeVarMi(B: TAcikBaglanti; const Ad: string): Boolean;
var
  Liste: TStringList;
begin
  Liste := TStringList.Create;
  try
    ProsedurleriGetir(B, Liste);
    Result := Liste.IndexOf(Ad) >= 0;
  finally
    Liste.Free;
  end;
end;

{ 2.x mi? 3.0+ ALTER hatasi satir numarasi vermez (olculdu). }
function Surum25: Boolean;
begin
  Result := Copy(Bag.Surum, 1, 2) = '2.';
end;

{ Beklenen satir ya da (bilinmiyorsa) 0; baska bir satir YANLIS sayilir. }
function SatirDogruMu(Beklenen, Gelen: Integer): Boolean;
begin
  Result := (Gelen = 0) or (Gelen = Beklenen);
end;

function SatirNo(const Metin, Parca: string): Integer;
var
  Satirlar: TArray<string>;
  I: Integer;
begin
  Result := 0;
  Satirlar := StringReplace(Metin, #13, '', [rfReplaceAll]).Split([#10]);
  for I := 0 to High(Satirlar) do
    if Pos(Parca, Satirlar[I]) > 0 then
      Exit(I + 1);
end;

{ ---------- A) Kurallar ---------- }

procedure KurallarBolumu;
var
  Metin, Hepsi, Anahtar: string;
  Dil: string;
  Anahtarlar: TArray<string>;
begin
  Cikti.Add('');
  Cikti.Add('=== A) Kurallar (veritabani gerekmez) ===');
  Metin := 'SET TERM ^ ;' + sLineBreak + 'CREATE OR ALTER PROCEDURE FBY_X' + sLineBreak + 'AS begin end^' + sLineBreak + 'SET TERM ; ^';
  Kontrol('Ad dogrula: dogru ad kabul', ProsedurAdiniDogrula(Metin, 'FBY_X') = '');
  Kontrol('Ad dogrula: kucuk harfli yazim kabul (buyuk harfe cevrilir)',
    ProsedurAdiniDogrula(StringReplace(Metin, 'FBY_X', 'fby_x', []), 'FBY_X') = '');
  Kontrol('Ad dogrula: baska ad reddedilir (ERR_PRS_AD_DEGISTI)',
    ProsedurAdiniDogrula(StringReplace(Metin, 'FBY_X', 'FBY_Y', []), 'FBY_X') = TF('ERR_PRS_AD_DEGISTI', ['FBY_X', 'FBY_Y']));
  Kontrol('Ad dogrula: tirnakli ad kabul',
    ProsedurAdiniDogrula(StringReplace(Metin, 'FBY_X', '"FBY X"', []), 'FBY X') = '');
  Kontrol('Ad dogrula: tirnakli kucuk harf farkli ad sayilir',
    ProsedurAdiniDogrula(StringReplace(Metin, 'FBY_X', '"fby_x"', []), 'FBY_X') <> '');
  Kontrol('Ad dogrula: basta yorum satiri olabilir',
    ProsedurAdiniDogrula('-- yorum' + sLineBreak + '/* blok */' + sLineBreak + Metin, 'FBY_X') = '');
  Kontrol('Ad dogrula: CREATE PROCEDURE (OR ALTER yok) reddedilir',
    ProsedurAdiniDogrula('CREATE PROCEDURE FBY_X AS begin end', 'FBY_X') = TF('ERR_PRS_BASLIK_YOK', ['FBY_X', 'FBY_X']));
  Kontrol('Ad dogrula: bos metin reddedilir', ProsedurAdiniDogrula('   ', 'FBY_X') <> '');
  Kontrol('Ad dogrula: DROP PROCEDURE reddedilir', ProsedurAdiniDogrula('DROP PROCEDURE FBY_X', 'FBY_X') <> '');

  Kontrol('SqlOzeti: tek satir oldugu gibi', SqlOzeti('CREATE OR ALTER PROCEDURE A AS BEGIN END') = 'CREATE OR ALTER PROCEDURE A AS BEGIN END');
  Kontrol('SqlOzeti: cok satir ilk satir + (N satir)',
    SqlOzeti('CREATE OR ALTER PROCEDURE A' + sLineBreak + 'AS' + sLineBreak + 'BEGIN' + sLineBreak + 'END') =
    'CREATE OR ALTER PROCEDURE A ... ' + TF('PRS_SATIR_SAYISI', [4]));
  Kontrol('HataSatiriBul: Token unknown - line 5, column 3', HataSatiriBul('Dynamic SQL Error -Token unknown - line 5, column 3 -x') = 5);
  Kontrol('HataSatiriBul: At line 12, column 8', HataSatiriBul('Column unknown -X -At line 12, column 8') = 12);
  Kontrol('HataSatiriBul: satir yok -> 0', HataSatiriBul('object FBY is in use') = 0);

  VeriKlasoruAyarla(VeriKlasoru);
  Kontrol('Yedek klasoru: _arsiv altinda baglanti adi, yasak karakterler altcizgi',
    ProsedurYedekKlasoru('a:b/c') = TPath.Combine(TPath.Combine(VeriKlasoru, '_arsiv'), 'a_b_c'));

  { Yeni dil anahtarlari uc dilde de var (anahtarin kendisi gorunmuyor) }
  Anahtarlar := ['MENU_PROSEDUR_DUZENLE', 'PRS_SEKME', 'PRS_KAYDET', 'PRS_BILGI', 'PRS_SATIR_SAYISI', 'PRS_YEDEK_BASLIK', 'ONAY_PRS_KAYDET',
    'ONAY_PRS_COK_KOMUT', 'MSG_PRS_VAZGECILDI', 'MSG_PRS_KAYDEDILDI', 'MSG_PRS_YEDEKLENDI', 'ERR_PRS_KAYDEDILEMEDI',
    'MSG_PRS_DOKUNULMADI', 'MSG_PRS_GERI_ALINDI', 'MSG_PRS_HATA_SATIRI', 'MSG_PRS_F5_IPUCU', 'MSG_PRS_ACILDI',
    'ERR_PRS_BASLIK_YOK', 'ERR_PRS_AD_DEGISTI', 'ERR_PRS_YEDEK_YAZILAMADI', 'ERR_NESNE_BAGIMLI'];
  for Dil in ['tr', 'en', 'de'] do
  begin
    DilYukle(Dil);
    Hepsi := '';
    for Anahtar in Anahtarlar do
      if T(Anahtar) = Anahtar then
        Hepsi := Hepsi + ' ' + Anahtar;
    Kontrol('Dil ' + Dil + ': tum yeni anahtarlar tanimli', Hepsi = '');
    if Hepsi <> '' then
      Not_('eksik:' + Hepsi);
  end;
  DilYukle('tr');
  Kontrol('Dil: tr onay metni prosedur adini tasir ve soru iceriyor',
    (Pos('FBY_X', TF('ONAY_PRS_KAYDET', ['FBY_X'])) > 0) and (Pos('?', TF('ONAY_PRS_KAYDET', ['FBY_X'])) > 0));
end;

{ ---------- B) Veritabani: duzenle ve kaydet ---------- }

procedure P1Olustur;
begin
  Dene(Bag, 'drop procedure ' + P2);
  Dene(Bag, 'drop procedure ' + P1);
  Yurut(Bag, 'create procedure ' + P1 + ' returns (X integer) as' + sLineBreak + 'begin' + sLineBreak + '  X = 1;' + sLineBreak +
    '  suspend;' + sLineBreak + 'end');
end;

procedure KaydetBolumu;
var
  Metin, Yeni, Yedek, YedekMetni: string;
  Sonuc: TProsedurSonucu;
  Dosyalar: TArray<string>;
  Once, Sonra: Integer;
begin
  Cikti.Add('');
  Cikti.Add('=== B1) Duzenle metni ve kaydet (surum ' + Bag.Surum + ') ===');
  P1Olustur;
  Metin := ProsedurDuzenleMetni(Bag, P1);
  Not_('duzenleme metni: ' + TekSatir(Metin, 400));
  Kontrol('Duzenle metni CREATE OR ALTER PROCEDURE ile basliyor', Pos('CREATE OR ALTER PROCEDURE ' + P1, Metin) > 0);
  Kontrol('Duzenle metni SET TERM ^ sarmali', (Pos('SET TERM ^ ;', Metin) = 1) and (Pos('SET TERM ; ^', Metin) > 0));
  Kontrol('Duzenle metni "CREATE PROCEDURE" (OR ALTER olmadan) icermiyor', Pos('CREATE PROCEDURE', Metin) = 0);
  Kontrol('Duzenle metni ad dogrulamasindan geciyor', ProsedurAdiniDogrula(Metin, P1) = '');
  Kontrol('Duzenle metni KomutlaraBol ile TEK komut (SET TERM sayilmiyor)', Length(KomutlaraBol(Metin)) = 1);
  Kontrol('ScriptUret hala CREATE PROCEDURE uretiyor (degismedi)', Pos('CREATE PROCEDURE ' + P1, ScriptUret(Bag, ntProsedur, P1)) > 0);

  { Govdeyi degistir -> kaydet -> yeni sonuc, eski yedekte }
  Yeni := StringReplace(Metin, 'X = 1', 'X = 2', []);
  Kontrol('(deneme duzeni) metinde X = 1 vardi', Yeni <> Metin);
  ForceDirectories(ProsedurYedekKlasoru(Bag.Tanim.Ad));
  Once := Length(TDirectory.GetFiles(ProsedurYedekKlasoru(Bag.Tanim.Ad), '*.sql'));
  Sonuc := ProsedurKaydet(Bag, P1, Yeni);
  if not Sonuc.Basarili then
    Not_('hata: ' + Sonuc.Cumle + ' / ' + Sonuc.Ayrinti);
  Kontrol('Kaydet basarili', Sonuc.Basarili);
  Kontrol('Prosedur yeni hali: X = 2 donuyor', Skaler(Bag, 'select X from ' + P1) = '2');
  Kontrol('Sonuc: tek komut, SET TERM sayilmadi, ozetinde (N satir)',
    (Length(Sonuc.Komutlar) = 1) and (Pos(' ... ' + Copy(TF('PRS_SATIR_SAYISI', [0]), 1, 1), Sonuc.Komutlar[0]) > 0));
  Not_('SQL ozeti: ' + TekSatir(string.Join(' || ', Sonuc.Komutlar)));
  Yedek := Sonuc.YedekDosyasi;
  Kontrol('Yedek dosyasi var ve _arsiv\<baglanti> altinda',
    FileExists(Yedek) and (Pos(ProsedurYedekKlasoru(Bag.Tanim.Ad), Yedek) = 1) and StartsText('prosedur_' + P1 + '_', ExtractFileName(Yedek)) and
    EndsText('.sql', Yedek));
  Not_('yedek: ' + Yedek);
  YedekMetni := '';
  if FileExists(Yedek) then
  begin
    YedekMetni := TFile.ReadAllText(Yedek, TEncoding.GetEncoding(1254));
    Kontrol('Yedek eski govdeyi iceriyor (X = 1), yenisini degil', (Pos('X = 1', YedekMetni) > 0) and (Pos('X = 2', YedekMetni) = 0));
    Kontrol('Yedek CREATE OR ALTER PROCEDURE ve SET NAMES iceriyor (geri yuklenebilir)',
      (Pos('CREATE OR ALTER PROCEDURE ' + P1, YedekMetni) > 0) and (Pos('SET NAMES ', YedekMetni) > 0));
  end;
  Sonra := Length(TDirectory.GetFiles(ProsedurYedekKlasoru(Bag.Tanim.Ad), '*.sql'));
  Kontrol('Tam bir yedek dosyasi eklendi', Sonra = Once + 1);
  Kontrol('Yeniden okunan duzenleme metni yeni govdeyi tasiyor', Pos('X = 2', ProsedurDuzenleMetni(Bag, P1)) > 0);

  { Yedegi geri yukle: yedek dosyasindaki metin yeniden kaydedilebiliyor mu (CREATE OR ALTER) }
  Sonuc := ProsedurKaydet(Bag, P1, StringReplace(YedekMetni, 'SET NAMES ', '-- SET NAMES ', []));
  Kontrol('Yedek metniyle geri kaydetme basarili (yorum satiri ve SET NAMES atlanir)', Sonuc.Basarili);
  if not Sonuc.Basarili then
    Not_('hata: ' + Sonuc.Cumle + ' / ' + Sonuc.Ayrinti);
  Kontrol('Geri yuklenince X = 1', Skaler(Bag, 'select X from ' + P1) = '1');
  Dosyalar := TDirectory.GetFiles(ProsedurYedekKlasoru(Bag.Tanim.Ad), 'prosedur_' + P1 + '_*.sql');
  Kontrol('Iki kayit = iki farkli yedek dosyasi (ayni saniyede de ezilmez)', Length(Dosyalar) >= 2);
end;

procedure HataBolumu;
var
  Metin, Bozuk: string;
  Sonuc: TProsedurSonucu;
  Satir: Integer;
begin
  Cikti.Add('');
  Cikti.Add('=== B2) Hatalar: eski prosedur bozulmaz, anlasilir cumle, satir no ===');
  P1Olustur;
  Metin := ProsedurDuzenleMetni(Bag, P1);

  { Sozdizimi }
  Bozuk := StringReplace(Metin, 'X = 1;', 'X = = 2;', []);
  Satir := SatirNo(Bozuk, 'X = = 2;');
  Sonuc := ProsedurKaydet(Bag, P1, Bozuk);
  Not_('sozdizimi: cumle=' + TekSatir(Sonuc.Cumle) + '  ayrinti=' + TekSatir(Sonuc.Ayrinti) + '  satir=' + IntToStr(Sonuc.Satir) + ' (beklenen ' + IntToStr(Satir) + ')');
  Kontrol('Sozdizimi hatasi: basarisiz', not Sonuc.Basarili);
  Kontrol('Sozdizimi hatasi: anlasilir cumle (ERR_SQL_SOZDIZIMI)', Sonuc.Cumle = T('ERR_SQL_SOZDIZIMI'));
  Kontrol('Sozdizimi hatasi: ham mesaj Ayrinti''da', Sonuc.Ayrinti <> '');
  Kontrol('Sozdizimi hatasi: editor satiri dogru (satir bilinmiyorsa 0, yanlis satir degil)', SatirDogruMu(Satir, Sonuc.Satir));
  Kontrol('Sozdizimi hatasi: denenen SQL listede', Length(Sonuc.Komutlar) = 1);
  Kontrol('Sozdizimi hatasi: eski prosedur bozulmadi (X = 1)', Skaler(Bag, 'select X from ' + P1) = '1');
  Kontrol('Sozdizimi hatasi: yedek yine de yazildi (hata veritabaninda)', FileExists(Sonuc.YedekDosyasi));

  KodDene('ham kod (sozdizimi)', Bag, 'alter procedure ' + P1 + ' returns (X integer) as begin X = = 2; suspend; end');
  KodDene('ham kod (olmayan degisken)', Bag, 'alter procedure ' + P1 + ' returns (X integer) as begin X = YOK_DEGISKEN; suspend; end');
  KodDene('ham kod (olmayan tablo)', Bag, 'alter procedure ' + P1 + ' returns (X integer) as begin select 1 from YOK_TABLO into :X; suspend; end');
  KodDene('ham kod (olmayan kolon)', Bag, 'alter procedure ' + P1 + ' returns (X integer) as begin select YOK_KOLON from RDB$DATABASE into :X; suspend; end');
  KodDene('ham kod (olmayan prosedur cagrisi)', Bag, 'alter procedure ' + P1 + ' returns (X integer) as begin execute procedure YOK_PRS; suspend; end');

  { Anlam hatasi: olmayan degisken }
  Bozuk := StringReplace(Metin, 'X = 1;', 'X = YOK_BOYLE_DEGISKEN;', []);
  Satir := SatirNo(Bozuk, 'YOK_BOYLE_DEGISKEN');
  Sonuc := ProsedurKaydet(Bag, P1, Bozuk);
  Not_('anlam: cumle=' + TekSatir(Sonuc.Cumle) + '  ayrinti=' + TekSatir(Sonuc.Ayrinti) + '  satir=' + IntToStr(Sonuc.Satir) + ' (beklenen ' + IntToStr(Satir) + ')');
  Kontrol('Olmayan degisken: basarisiz ve genel hata cumlesi DEGIL', (not Sonuc.Basarili) and (Sonuc.Cumle <> T('ERR_GENEL')));
  Kontrol('Olmayan degisken: eski prosedur bozulmadi', Skaler(Bag, 'select X from ' + P1) = '1');
  Kontrol('Olmayan degisken: editor satiri (2.5 verir; 3.0+ vermez, o zaman 0 kalir, yanlis satir olmaz)', SatirDogruMu(Satir, Sonuc.Satir));
  if Surum25 then
    Kontrol('2.5: Column unknown hata satirini verir', Sonuc.Satir = Satir);

  { Cok komutlu metin: ikinci komut hata -> hepsi geri alinir }
  Sonuc := ProsedurKaydet(Bag, P1, StringReplace(Metin, 'X = 1', 'X = 7', []) + sLineBreak + 'ALTER PROCEDURE YOK_BOYLE_PROSEDUR AS begin end;');
  Not_('cok komut: cumle=' + TekSatir(Sonuc.Cumle) + '  ayrinti=' + TekSatir(Sonuc.Ayrinti) + '  komut=' + IntToStr(Length(Sonuc.Komutlar)));
  Kontrol('Cok komut: ikincisi hata -> basarisiz, iki komut denendi', (not Sonuc.Basarili) and (Length(Sonuc.Komutlar) = 2));
  Kontrol('Cok komut: ilk komut da GERI ALINDI (X hala 1, yarim kalmadi)', Skaler(Bag, 'select X from ' + P1) = '1');

  { Ad degistirme: yeni prosedur olusmamali }
  Sonuc := ProsedurKaydet(Bag, P1, StringReplace(Metin, P1, P_ISIM, [rfReplaceAll]));
  Kontrol('Baska ad: reddedildi, ERR_PRS_AD_DEGISTI cumlesi', (not Sonuc.Basarili) and (Sonuc.Cumle = TF('ERR_PRS_AD_DEGISTI', [P1, P_ISIM])));
  Kontrol('Baska ad: veritabanina dokunulmadi (komut yok, yedek yok, yeni prosedur yok)',
    (Length(Sonuc.Komutlar) = 0) and (Sonuc.YedekDosyasi = '') and not ProsedurVarMi(Bag, P_ISIM));

  { Basliksiz metin }
  Sonuc := ProsedurKaydet(Bag, P1, 'SELECT 1 FROM RDB$DATABASE');
  Kontrol('Basliksiz metin (baska komut): reddedildi, hicbir sey calismadi', (not Sonuc.Basarili) and (Length(Sonuc.Komutlar) = 0));
end;

procedure TurkceVeSetTermBolumu;
var
  Metin, Yeni: string;
  Sonuc: TProsedurSonucu;
  Gelen: string;
begin
  Cikti.Add('');
  Cikti.Add('=== B3) SET TERM govdesi, Turkce harf, adi tirnakli prosedur ===');
  Dene(Bag, 'drop procedure ' + P2);
  Dene(Bag, 'drop procedure ' + P1);
  { Birden fazla ';' iceren govde }
  Yurut(Bag, 'create procedure ' + P1 + ' returns (S varchar(40)) as' + sLineBreak + 'declare variable I integer;' + sLineBreak +
    'begin' + sLineBreak + '  I = 0;' + sLineBreak + '  S = ''x'';' + sLineBreak + '  suspend;' + sLineBreak + 'end');
  Metin := ProsedurDuzenleMetni(Bag, P1);
  Yeni := StringReplace(Metin, 'S = ''x'';', '-- yorum: ' + TURKCE + sLineBreak + '  S = ''' + TURKCE + ' Sisli'';', []);
  Kontrol('(deneme duzeni) Turkce metin yerlesti', Yeni <> Metin);
  Sonuc := ProsedurKaydet(Bag, P1, Yeni);
  if not Sonuc.Basarili then
    Not_('hata: ' + Sonuc.Cumle + ' / ' + Sonuc.Ayrinti);
  Kontrol('Cok ";" iceren SET TERM govdesi kaydedildi', Sonuc.Basarili);
  Gelen := Skaler(Bag, 'select S from ' + P1);
  Kontrol('Turkce metin sabiti aynen donuyor', Gelen = TURKCE + ' Sisli');
  if Gelen <> TURKCE + ' Sisli' then
    Not_('gelen: ' + Gelen);
  Kontrol('Turkce yorum yeniden okunan duzenleme metninde aynen duruyor', Pos('-- yorum: ' + TURKCE, ProsedurDuzenleMetni(Bag, P1)) > 0);
  { okunan metin degistirilmeden yeniden kaydedilince bozulmuyor }
  Sonuc := ProsedurKaydet(Bag, P1, ProsedurDuzenleMetni(Bag, P1));
  Kontrol('Okunan metin degistirilmeden yeniden kaydedilebiliyor', Sonuc.Basarili);
  Kontrol('Yeniden kaydetmeden sonra da Turkce metin aynen', (Skaler(Bag, 'select S from ' + P1) = TURKCE + ' Sisli') and
    (Pos('-- yorum: ' + TURKCE, ProsedurDuzenleMetni(Bag, P1)) > 0));

  { Tirnakli, bosluklu ad }
  Dene(Bag, 'drop procedure "FBY Test Q"');
  Yurut(Bag, 'create procedure "FBY Test Q" returns (X integer) as begin X = 5; suspend; end');
  Metin := ProsedurDuzenleMetni(Bag, 'FBY Test Q');
  Kontrol('Tirnakli ad: duzenleme metni "FBY Test Q" tirnakli', Pos('CREATE OR ALTER PROCEDURE "FBY Test Q"', Metin) > 0);
  Sonuc := ProsedurKaydet(Bag, 'FBY Test Q', StringReplace(Metin, 'X = 5', 'X = 6', []));
  if not Sonuc.Basarili then
    Not_('hata: ' + Sonuc.Cumle + ' / ' + Sonuc.Ayrinti);
  Kontrol('Tirnakli ad: kaydedildi', Sonuc.Basarili and (Skaler(Bag, 'select X from "FBY Test Q"') = '6'));
  Kontrol('Tirnakli ad: yedek dosya adinda bosluk yok', Pos(' ', ExtractFileName(Sonuc.YedekDosyasi)) = 0);
  Dene(Bag, 'drop procedure "FBY Test Q"');
end;

procedure YedekYazilamazBolumu;
var
  Klasor, Dosya: string;
  Sonuc: TProsedurSonucu;
  Metin: string;
begin
  Cikti.Add('');
  Cikti.Add('=== B4) Eski tanim yedeklenemezse kaydetme DURUR ===');
  P1Olustur;
  Metin := ProsedurDuzenleMetni(Bag, P1);
  { _arsiv yerine ayni adli bir DOSYA koyulur: klasor acilamaz }
  Klasor := TPath.Combine(TPath.GetTempPath, 'prosedurtest_yedeksiz');
  TDirectory.CreateDirectory(Klasor);
  Dosya := TPath.Combine(Klasor, '_arsiv');
  TFile.WriteAllText(Dosya, 'engel');
  VeriKlasoruAyarla(Klasor);
  try
    Sonuc := ProsedurKaydet(Bag, P1, StringReplace(Metin, 'X = 1', 'X = 9', []));
  finally
    VeriKlasoruAyarla(VeriKlasoru);
  end;
  Not_('cumle=' + TekSatir(Sonuc.Cumle) + '  ayrinti=' + TekSatir(Sonuc.Ayrinti));
  Kontrol('Yedek yazilamadi: basarisiz, cumle ERR_PRS_YEDEK_YAZILAMADI', (not Sonuc.Basarili) and (Sonuc.Cumle = T('ERR_PRS_YEDEK_YAZILAMADI')));
  Kontrol('Yedek yazilamadi: ayrintida neden var', Sonuc.Ayrinti <> '');
  Kontrol('Yedek yazilamadi: veritabanina dokunulmadi (komut yok, prosedur ayni)',
    (Length(Sonuc.Komutlar) = 0) and (Skaler(Bag, 'select X from ' + P1) = '1'));
  TFile.Delete(Dosya);
end;

procedure PaketBolumu;
begin
  Cikti.Add('');
  Cikti.Add('=== B5) Paketli prosedur (3.0+) kapsam disi ===');
  if StrToIntDef(Copy(Bag.Surum, 1, 1), 0) < 3 then
  begin
    Not_('surum ' + Bag.Surum + ': paket yok (2.5), atlandi');
    Exit;
  end;
  Dene(Bag, 'drop package ' + PAKET);
  Yurut(Bag, 'create package ' + PAKET + ' as begin procedure PKG_PRS returns (X integer); end');
  Yurut(Bag, 'create package body ' + PAKET + ' as begin procedure PKG_PRS returns (X integer) as begin X = 3; suspend; end end');
  Kontrol('Paketli prosedur agac listesinde yok (menu hic gorunmez)', not ListedeVarMi(Bag, 'PKG_PRS'));
  try
    ProsedurDuzenleMetni(Bag, 'PKG_PRS');
    Kontrol('Paketli prosedurun duzenleme metni alinamaz', False);
  except
    on E: EMetadataHatasi do
    begin
      Kontrol('Paketli prosedurun duzenleme metni alinamaz (EMetadataHatasi)', True);
      Not_('mesaj: ' + E.Message);
    end;
  end;
  Dene(Bag, 'drop package ' + PAKET);
end;

procedure KullanimdaBolumu;
var
  Bag2: TAcikBaglanti;
  T2: TBaglantiTanimi;
  Sorgu: TFDQuery;
  Metin: string;
  Sonuc: TProsedurSonucu;
  E: Exception;
begin
  Cikti.Add('');
  Cikti.Add('=== B6) Baska baglanti prosedurunu kullanirken / bagimli nesne ===');
  Dene(Bag, 'drop procedure ' + P2);
  Dene(Bag, 'drop procedure ' + P1);
  { P1 bir satir doner; P2 P1'i cagirip uc satir doner. Baska baglanti P2'nin ilk satirini cekip imleci acik tutar:
    P2 calisiyor ve P1'i kullaniyor. }
  Yurut(Bag, 'create procedure ' + P1 + ' returns (X integer) as' + sLineBreak + 'begin' + sLineBreak + '  X = 1;' + sLineBreak +
    '  suspend;' + sLineBreak + 'end');
  Yurut(Bag, 'create procedure ' + P2 + ' returns (Y integer) as declare variable V integer; begin ' +
    'for select X from ' + P1 + ' into :V do begin Y = :V; suspend; Y = :V + 1; suspend; Y = :V + 2; suspend; end end');
  Metin := ProsedurDuzenleMetni(Bag, P1);

  Inc(Sayac);
  T2 := Tanim;
  T2.Ad := 'prosedur_test_b' + IntToStr(Sayac);
  Bag2 := FbBaglan(T2);
  Sorgu := KomutHazirla(Bag2, 'select Y from ' + P2);
  try
    Sorgu.FetchOptions.Mode := fmOnDemand;
    Sorgu.FetchOptions.RowsetSize := 1;
    Sorgu.Open;
    KodDene('ham kod (P1 kullanimda, govde)', Bag, 'alter procedure ' + P1 + ' returns (X integer) as begin X = 5; suspend; end');
    Dene(Bag, 'create or alter procedure ' + P1 + ' returns (X integer) as begin X = 1; suspend; end');
    KodDene('ham kod (P2 calisiyor, govde)', Bag, 'alter procedure ' + P2 + ' returns (Y integer) as begin Y = 5; suspend; end');
    Dene(Bag, 'create or alter procedure ' + P2 + ' returns (Y integer) as declare variable V integer; begin ' +
      'for select X from ' + P1 + ' into :V do begin Y = :V; suspend; Y = :V + 1; suspend; Y = :V + 2; suspend; end end');
    Sonuc := ProsedurKaydet(Bag, P1, StringReplace(Metin, 'X = 1', 'X = 3', []));
    Not_('kullanimda: basarili=' + BoolToStr(Sonuc.Basarili, True) + ' cumle=' + TekSatir(Sonuc.Cumle) + '  ayrinti=' + TekSatir(Sonuc.Ayrinti));
    if not Surum25 then
      Kontrol('3.0+: baska baglanti kullanirken ALTER reddedilir (nesne kullanimda, kod 335544345)', not Sonuc.Basarili);
    if Sonuc.Basarili then
      Not_('BILGI: bu surumde baska baglanti kullanirken de ALTER basardi (nesne kullanimda hatasi uretilemedi)')
    else
    begin
      Kontrol('Baska baglanti kullanirken: anlasilir cumle (ERR_NESNE_KULLANIMDA)', Sonuc.Cumle = T('ERR_NESNE_KULLANIMDA'));
      Kontrol('Baska baglanti kullanirken: eski prosedur bozulmadi', Skaler(Bag, 'select X from ' + P1) = '1');
    end;
    Sorgu.Close;
  finally
    Sorgu.Free;
    FbBaglantiyiKes(Bag2);
  end;
  { "is in use" metni (DROP ile 5.0.4'te olculdu): sentetik istisnayla cumle denetimi }
  E := Exception.Create('unsuccessful metadata update' + #13#10 + 'MODIFY RDB$PROCEDURES failed' + #13#10 + 'no permission for protect access to PROCEDURE FBY_TEST_P1');
  try
    Kontrol('Metin (2.5.9 olcumu): "no permission for protect access" -> ERR_YETKI_YOK', HataMetniniCevir(E) = T('ERR_YETKI_YOK'));
  finally
    E.Free;
  end;
  E := Exception.Create('unsuccessful metadata update' + #13#10 + 'object PROCEDURE "FBY_TEST_P1" is in use');
  try
    Kontrol('Metin: "object ... is in use" -> ERR_NESNE_KULLANIMDA', HataMetniniCevir(E) = T('ERR_NESNE_KULLANIMDA'));
  finally
    E.Free;
  end;

  { Bagimli nesne: P2, P1'i kullaniyor. DROP gercek hata verir (2.5.9: "there are 1 dependencies"). }
  try
    Yurut(Bag, 'drop procedure ' + P1);
    Kontrol('Bagimli prosedur DROP edilemez', False);
  except
    on Ex: Exception do
    begin
      Not_('bagimli DROP: ' + HataKodlari(Ex));
      Kontrol('Bagimli nesne: DROP hatasi -> ERR_NESNE_BAGIMLI cumlesi', HataMetniniCevir(Ex) = T('ERR_NESNE_BAGIMLI'));
    end;
  end;
  { Parametre degistirme: 2.5'te kabul edilir, 3.0+ reddedebilir; kabul/ret + cumle yazilir. }
  Metin := StringReplace(StringReplace(Metin, 'X INTEGER', 'W INTEGER', []), 'X = 1', 'W = 1', []);
  KodDene('ham kod (bagimli, parametre degisimi)', Bag, 'alter procedure ' + P1 + ' returns (W integer) as begin W = 1; suspend; end');
  Dene(Bag, 'create or alter procedure ' + P1 + ' returns (X integer) as begin X = 1; suspend; end');
  Sonuc := ProsedurKaydet(Bag, P1, Metin);
  Not_('bagimli parametre degisimi: basarili=' + BoolToStr(Sonuc.Basarili, True) + ' cumle=' + TekSatir(Sonuc.Cumle) +
    '  ayrinti=' + TekSatir(Sonuc.Ayrinti));
  if not Sonuc.Basarili then
  begin
    Kontrol('Bagimli parametre degisimi reddedildi: genel hata cumlesi DEGIL', Sonuc.Cumle <> T('ERR_GENEL'));
    Kontrol('Bagimli parametre degisimi reddedildi: eski prosedur bozulmadi', Skaler(Bag, 'select X from ' + P1) = '1');
  end;
  Dene(Bag, 'drop procedure ' + P2);
  Dene(Bag, 'drop procedure ' + P1);
end;

procedure YetkisizBolumu;
var
  T2: TBaglantiTanimi;
  Bag2: TAcikBaglanti;
  Metin: string;
  Sonuc: TProsedurSonucu;
  Hata: string;
begin
  Cikti.Add('');
  Cikti.Add('=== B7) Yetkisiz kullanici ===');
  P1Olustur;
  Metin := ProsedurDuzenleMetni(Bag, P1);
  Inc(Sayac);
  T2 := Tanim;
  T2.Ad := 'prosedur_test_y' + IntToStr(Sayac);
  T2.Kullanici := YETKISIZ;
  if Gomulu then
    T2.Sifre := 'x'
  else
  begin
    { Sunucuda yetkisiz kullanici ayri olusturulur (yalniz test sunucusunda, sonunda silinir). }
    if not KullaniciYetenekleri(Bag).YonetimVar then
    begin
      Not_('kullanici olusturulamiyor, atlandi');
      Exit;
    end;
    try
      KullaniciSil(Bag, YETKISIZ);
    except
    end;
    KullaniciEkle(Bag, YETKISIZ, 'Yetkisiz123', 'Yetkisiz123', '', '', False);
    T2.Sifre := 'Yetkisiz123';
  end;
  Bag2 := nil;
  Hata := '';
  try
    try
      Bag2 := FbBaglan(T2);
    except
      on E: Exception do
        Hata := HataKodlari(E);
    end;
    if Bag2 = nil then
    begin
      Not_('yetkisiz kullanici baglanamadi: ' + Hata + ' (bu kipte yetkisiz baglanti denenemiyor)');
      Exit;
    end;
    Sonuc := ProsedurKaydet(Bag2, P1, StringReplace(Metin, 'X = 1', 'X = 4', []));
    Not_('yetkisiz: basarili=' + BoolToStr(Sonuc.Basarili, True) + ' cumle=' + TekSatir(Sonuc.Cumle) + '  ayrinti=' + TekSatir(Sonuc.Ayrinti) +
      ' yedek=' + Sonuc.YedekDosyasi);
    Kontrol('Yetkisiz kullanici: kaydetme reddedildi', not Sonuc.Basarili);
    Kontrol('Yetkisiz kullanici: anlasilir cumle (ERR_YETKI_YOK)', Sonuc.Cumle = T('ERR_YETKI_YOK'));
    Kontrol('Yetkisiz kullanici: prosedur degismedi', Skaler(Bag, 'select X from ' + P1) = '1');
  finally
    if Bag2 <> nil then
      FbBaglantiyiKes(Bag2);
    if not Gomulu then
      try
        KullaniciSil(Bag, YETKISIZ);
      except
      end;
  end;
end;

procedure DilCumleleriBolumu;
var
  Dil: string;
  Sonuc: TProsedurSonucu;
  Metin: string;
begin
  Cikti.Add('');
  Cikti.Add('=== B8) Hata cumleleri uc dilde ===');
  P1Olustur;
  Metin := StringReplace(ProsedurDuzenleMetni(Bag, P1), 'X = 1;', 'X = = 2;', []);
  for Dil in ['tr', 'en', 'de'] do
  begin
    DilYukle(Dil);
    Sonuc := ProsedurKaydet(Bag, P1, Metin);
    Not_(Dil + ': ' + TekSatir(Sonuc.Cumle));
    Kontrol('Dil ' + Dil + ': sozdizimi cumlesi cevrilmis (anahtar degil, bos degil)',
      (Sonuc.Cumle <> '') and (Pos('ERR_', Sonuc.Cumle) = 0));
    Not_(Dil + ' ad degisti: ' + TekSatir(TF('ERR_PRS_AD_DEGISTI', [P1, 'X'])));
    Not_(Dil + ' bagimli: ' + TekSatir(T('ERR_NESNE_BAGIMLI')));
  end;
  DilYukle('tr');
end;

procedure SekmeBolumu;
var
  Form: TForm;
  Sekme: TProsedurSekme;
  Panel: TPanel;
  Editor: TSqlEditor;
  Satirlar: TStringList;
begin
  Cikti.Add('');
  Cikti.Add('=== B9) Arayuz duman testi: sekme ve editor olusuyor (dfm hatasi yok) ===');
  P1Olustur;
  Satirlar := TStringList.Create;
  Form := TForm.CreateNew(nil);
  try
    Sekme := TProsedurSekme.Create(Form);
    Sekme.Parent := Form;
    Sekme.Align := alClient;
    Sekme.AnaSonuc := Satirlar;
    Sekme.Yukle(Bag, P1);
    Kontrol('Sekme: baslik "Prosedur: ADI (baglanti)"', Sekme.Baslik = TF('PRS_SEKME', [P1, Bag.Tanim.Ad]));
    Kontrol('Sekme: Kaydet dugmesi yazisi dilden', Sekme.btnKaydet.Caption = T('PRS_KAYDET'));
    Kontrol('Sekme: Kaydet dugmesinin OnClick olayi bagli', Assigned(Sekme.btnKaydet.OnClick));
    Sekme.F5Ipucu;
    Kontrol('Sekme: F5 yalniz ipucu yazar', (Satirlar.Count = 1) and (Satirlar[0] = T('MSG_PRS_F5_IPUCU')));
    Sekme.BaglantiAd := 'yok_boyle_baglanti';
    Sekme.Kaydet;
    Kontrol('Sekme: baglanti yoksa Kaydet mesaj yazar, onay penceresi acmaz', (Satirlar.Count = 2) and (Pos('yok_boyle_baglanti', Satirlar[1]) > 0));
    Panel := TPanel.Create(Form);
    Panel.Parent := Form;
    Editor := TSqlEditor.Create(Panel);
    Editor.MetinYaz('a' + sLineBreak + 'b' + sLineBreak + 'c');
    Editor.SatiraGit(2);
    Editor.SatiraGit(99);
    Editor.SatiraGit(0);
    Kontrol('Editor: TumMetin yazilan metni verir, SatiraGit sinir disi satirda hata vermez', Pos('b', Editor.TumMetin) > 0);
  finally
    Form.Free;
    Satirlar.Free;
  end;
end;

procedure Temizle;
begin
  Dene(Bag, 'drop procedure ' + P2);
  Dene(Bag, 'drop procedure ' + P1);
  Dene(Bag, 'drop procedure "FBY Test Q"');
  Dene(Bag, 'drop package ' + PAKET);
end;

{ ---------- Ana akis ---------- }

var
  YazmaIstendi, YazmaIzni, KendiVeritabanim: Boolean;
  Neden, Klasor: string;
begin
  Cikti := TStringList.Create;
  Bag := nil;
  KendiVeritabanim := False;
  VeriKlasoru := TPath.Combine(GetEnvironmentVariable('TEMP'), 'prosedurtest_veri');
  try
    try
      DilYukle('tr');
      Tanim.Ad := 'prosedur_test';
      Tanim.Sunucu := Ortam('FBTEST_SUNUCU', '');
      Tanim.Port := StrToInt(Ortam('FBTEST_PORT', '3050'));
      Tanim.VeritabaniYolu := Ortam('FBTEST_YOL', '');
      Tanim.Kullanici := Ortam('FBTEST_KULLANICI', 'SYSDBA');
      Tanim.Sifre := Ortam('FBTEST_SIFRE', '');
      if (Tanim.Sunucu = '') and (Tanim.Sifre = '') then
        Tanim.Sifre := 'masterkey';
      Tanim.KarakterSeti := VARSAYILAN_KARAKTER_SETI;
      Gomulu := Tanim.Sunucu = '';
      YazmaIstendi := Ortam('FBTEST_YAZMA', '') = '1';

      if Gomulu and (Tanim.VeritabaniYolu = '') then
      begin
        Klasor := TPath.Combine(GetEnvironmentVariable('TEMP'), 'prosedurtest');
        ForceDirectories(Klasor);
        Tanim.VeritabaniYolu := TPath.Combine(Klasor, 'test_' + FormatDateTime('yyyymmdd_hhnnss', Now) + '.fdb');
        GeciciVeritabaniOlustur(Tanim);
        KendiVeritabanim := True;
      end;
      if Tanim.VeritabaniYolu = '' then
        raise Exception.Create('FBTEST_YOL bos: sunucudaki var olan bir veritabani yolu verin.');

      { Yazma izni kod seviyesinde: gomulu kendi gecici veritabaninda serbest; sunucuda yalniz yerel 3052, 3053, 3054. }
      YazmaIzni := False;
      Neden := '';
      if Gomulu then
        YazmaIzni := KendiVeritabanim
      else if not YazmaIstendi then
        Neden := 'FBTEST_YAZMA=1 verilmedi (varsayilan: yazma yok)'
      else if not YerelSunucuMu(Tanim.Sunucu) then
        Neden := 'yazma yalniz yerel (127.0.0.1/localhost) test sunucusunda serbest'
      else if (Tanim.Port = 3052) or (Tanim.Port = 3053) or (Tanim.Port = 3054) then
        YazmaIzni := True
      else
        Neden := 'port ' + IntToStr(Tanim.Port) + ': yazma YALNIZ 3052, 3053 ve 3054 portunda serbest (3050/3051 gercek veri icerir)';

      Cikti.Add('ProsedurDuzenleTest  ' + FormatDateTime('yyyy-mm-dd hh:nn:ss', Now));
      Cikti.Add('Sunucu: ' + IfThen(Gomulu, '(gomulu)', Tanim.Sunucu + ':' + IntToStr(Tanim.Port)));
      Cikti.Add('Veritabani: ' + Tanim.VeritabaniYolu + IfThen(KendiVeritabanim, '  (gecici, program acti)', ''));
      Cikti.Add('Kullanici: ' + Tanim.Kullanici + '  (sifre yazilmaz)');
      Cikti.Add('Yazma bolumu: ' + IfThen(YazmaIzni, 'ACIK', 'KAPALI - ' + Neden));

      if TDirectory.Exists(VeriKlasoru) then
        TDirectory.Delete(VeriKlasoru, True);
      KurallarBolumu;
      VeriKlasoruAyarla(VeriKlasoru);

      if YazmaIzni then
      begin
        Bag := FbBaglan(Tanim);
        Cikti.Add('Surum: ' + Bag.Surum);
        try
          KaydetBolumu;
          HataBolumu;
          TurkceVeSetTermBolumu;
          YedekYazilamazBolumu;
          PaketBolumu;
          KullanimdaBolumu;
          YetkisizBolumu;
          DilCumleleriBolumu;
          SekmeBolumu;
        finally
          Temizle;
        end;
      end;
    except
      on E: Exception do
      begin
        Cikti.Add('');
        Cikti.Add('HATA (beklenmeyen): ' + HataKodlari(E));
        Inc(Hatalar);
      end;
    end;
    Cikti.Add('');
    Cikti.Add('Kontrol: ' + IntToStr(KontrolSayisi) + '  Hata: ' + IntToStr(Hatalar));
    Cikti.SaveToFile(Ortam('FBTEST_CIKTI', 'prosedurtest.txt'), TEncoding.UTF8);
  finally
    Cikti.Free;
  end;
  ExitCode := Hatalar;
end.
