program TriggerDuzenleTest;

{ Asama 3e-2: uProsedur (tetikleyici duzenle ve kaydet) testi (komut satiri). ProsedurDuzenleTest ile ayni kalip.

  A) HER KIPTE: saf kurallar (ad dogrulama, dil anahtarlari). Veritabani gerekmez.
  B) GOMULU kip (FBTEST_SUNUCU bos): program kendi gecici veritabanini olusturur ve yazma testlerini orada yapar.
  C) SUNUCU kip: yazma testleri YALNIZCA yerel sunucuda 3052, 3053 ve 3054 portlarinda ve FBTEST_YAZMA=1 verilmisse
     calisir; baska portta (3050 ve 3051 dahil) kod seviyesinde REDDEDILIR. Testler FBY_TEST_ ile baslayan tablo ve
     tetikleyiciler olusturur, sonunda siler.

  Ortam degiskenleri: FBTEST_SUNUCU, FBTEST_PORT, FBTEST_YOL, FBTEST_KULLANICI, FBTEST_SIFRE, FBTEST_CIKTI, FBTEST_YAZMA.
  Yedekler %TEMP%\triggertest_veri altina yazilir. Cikis kodu: hata sayisi (0 = hepsi gecti). }

{$APPTYPE CONSOLE}

uses
  System.SysUtils, System.Classes, System.StrUtils, System.IOUtils, Data.DB,
  FireDAC.Stan.Intf, FireDAC.Stan.Option, FireDAC.Stan.Error, FireDAC.Comp.Client, FireDAC.Phys.FB,
  FireDAC.ConsoleUI.Wait,
  Vcl.Forms, Vcl.Controls, Vcl.ExtCtrls,
  uDil, uBaglanti, uMetadata, uSorgu, uDDL, uKullanici, uProsedur, uEditor, fProsedurSekme;

const
  TB = 'FBY_TEST_TB';
  TB2 = 'FBY_TEST_TB2';
  TR = 'FBY_TEST_TR1';
  TR_DB = 'FBY_TEST_DBT';
  TR_DDL = 'FBY_TEST_DDLT';
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
{ ---------- A) Kurallar ---------- }

procedure KurallarBolumu;
var
  Metin, Hepsi, Anahtar, Dil: string;
  Anahtarlar: TArray<string>;
begin
  Cikti.Add('');
  Cikti.Add('=== A) Kurallar (veritabani gerekmez) ===');
  Metin := 'SET TERM ^ ;' + sLineBreak + 'CREATE OR ALTER TRIGGER FBY_X FOR T' + sLineBreak + 'ACTIVE BEFORE INSERT POSITION 0' + sLineBreak +
    'AS begin end^' + sLineBreak + 'SET TERM ; ^';
  Kontrol('Ad dogrula: dogru ad kabul', NesneAdiniDogrula(ntTetikleyici, Metin, 'FBY_X') = '');
  Kontrol('Ad dogrula: baska ad reddedilir (ERR_TRG_AD_DEGISTI)',
    NesneAdiniDogrula(ntTetikleyici, StringReplace(Metin, 'FBY_X', 'FBY_Y', []), 'FBY_X') = TF('ERR_TRG_AD_DEGISTI', ['FBY_X', 'FBY_Y']));
  Kontrol('Ad dogrula: tirnakli ad kabul', NesneAdiniDogrula(ntTetikleyici, StringReplace(Metin, 'FBY_X', '"FBY X"', []), 'FBY X') = '');
  Kontrol('Ad dogrula: CREATE TRIGGER (OR ALTER yok) reddedilir',
    NesneAdiniDogrula(ntTetikleyici, 'CREATE TRIGGER FBY_X FOR T AS begin end', 'FBY_X') = TF('ERR_TRG_BASLIK_YOK', ['FBY_X', 'FBY_X']));
  Kontrol('Ad dogrula: PROCEDURE basligi tetikleyici sekmesinde reddedilir',
    NesneAdiniDogrula(ntTetikleyici, 'CREATE OR ALTER PROCEDURE FBY_X AS begin end', 'FBY_X') <> '');
  Kontrol('Ad dogrula: TRIGGER basligi prosedur sekmesinde reddedilir', NesneAdiniDogrula(ntProsedur, Metin, 'FBY_X') <> '');
  Kontrol('Ad dogrula: bos metin ve DROP TRIGGER reddedilir',
    (NesneAdiniDogrula(ntTetikleyici, '  ', 'FBY_X') <> '') and (NesneAdiniDogrula(ntTetikleyici, 'DROP TRIGGER FBY_X', 'FBY_X') <> ''));
  Anahtarlar := ['AGAC_TETIKLEYICILER', 'TRG_SEKME', 'TRG_BILGI', 'TRG_YEDEK_BASLIK', 'ONAY_TRG_KAYDET', 'MSG_TRG_KAYDEDILDI',
    'ERR_TRG_KAYDEDILEMEDI', 'MSG_TRG_GERI_ALINDI', 'MSG_TRG_ACILDI', 'ERR_TRG_BASLIK_YOK', 'ERR_TRG_AD_DEGISTI',
    'ERR_TRG_TABLO_DEGISTI', 'ERR_SALT_OKUNUR_KOLON'];
  for Dil in ['tr', 'en', 'de'] do
  begin
    DilYukle(Dil);
    Hepsi := '';
    for Anahtar in Anahtarlar do
      if T(Anahtar) = Anahtar then
        Hepsi := Hepsi + ' ' + Anahtar;
    Kontrol('Dil ' + Dil + ': tum trigger anahtarlari tanimli', Hepsi = '');
    if Hepsi <> '' then
      Not_('eksik:' + Hepsi);
  end;
  DilYukle('tr');
  Kontrol('Dil: tr onay metni trigger adini tasir, veriyi bozabilir uyarisi ve soru iceriyor',
    (Pos('FBY_X', TF('ONAY_TRG_KAYDET', ['FBY_X'])) > 0) and (Pos('?', TF('ONAY_TRG_KAYDET', ['FBY_X'])) > 0) and
    (Pos('trigger veriyi bozabilir', TF('ONAY_TRG_KAYDET', ['FBY_X'])) > 0));
end;

{ ---------- B) Veritabani ---------- }

procedure Kur;
begin
  Dene(Bag, 'drop trigger ' + TR);
  Dene(Bag, 'drop table ' + TB);
  Dene(Bag, 'drop table ' + TB2);
  Yurut(Bag, 'create table ' + TB + ' (ID integer, AD varchar(30), LOG varchar(30))');
  Yurut(Bag, 'create table ' + TB2 + ' (ID integer, LOG varchar(30))');
  Yurut(Bag, 'create trigger ' + TR + ' for ' + TB + ' active before insert position 5 as' + sLineBreak + 'begin' + sLineBreak +
    '  new.LOG = ''v1'';' + sLineBreak + 'end');
end;

{ Tabloya satir ekler, trigger'in yazdigi LOG degerini verir. }
function EkleOku(const Tablo: string): string;
begin
  Inc(Sayac);
  Yurut(Bag, 'insert into ' + Tablo + ' (ID) values (' + IntToStr(Sayac) + ')');
  Result := Skaler(Bag, 'select LOG from ' + Tablo + ' where ID = ' + IntToStr(Sayac));
end;

function Listede(const Ad: string; out Bilgi: TTetikleyiciBilgisi): Boolean;
var
  Tetik: TTetikleyiciBilgisi;
begin
  Result := False;
  Bilgi := Default(TTetikleyiciBilgisi);
  for Tetik in TetikleyicileriListele(Bag) do
    if Tetik.Ad = Ad then
    begin
      Bilgi := Tetik;
      Exit(True);
    end;
end;

procedure KaydetBolumu;
var
  Metin, Yeni, Yedek, YedekMetni: string;
  Sonuc: TProsedurSonucu;
  Bilgi: TTetikleyiciBilgisi;
  Once, Sonra: Integer;
begin
  Cikti.Add('');
  Cikti.Add('=== B1) Liste, duzenle metni, kaydet (surum ' + Bag.Surum + ') ===');
  Kur;
  Kontrol('Liste: tetikleyici tablo adiyla geliyor (agacta "AD (TABLO)")',
    Listede(TR, Bilgi) and (Bilgi.Tablo = TB) and Bilgi.Aktif and (Bilgi.Zaman = 'BEFORE') and (Bilgi.Olaylar = 'INSERT') and (Bilgi.Sira = 5));
  Kontrol('Liste: govde metni okunmuyor (hizli liste)', Listede(TR, Bilgi) and (Trim(Bilgi.Kaynak) = ''));
  Metin := TetikleyiciDuzenleScripti(Bag, TR);
  Not_('duzenleme metni: ' + TekSatir(Metin, 400));
  Kontrol('Duzenle metni CREATE OR ALTER TRIGGER ile basliyor', Pos('CREATE OR ALTER TRIGGER ' + TR, Metin) > 0);
  Kontrol('Duzenle metni tablo, zaman/olay, POSITION, ACTIVE mevcut halinden',
    (Pos('FOR ' + TB, Metin) > 0) and (Pos('ACTIVE', Metin) > 0) and (Pos('INACTIVE', Metin) = 0) and (Pos('BEFORE INSERT', Metin) > 0) and
    (Pos('POSITION 5', Metin) > 0));
  Kontrol('Duzenle metni SET TERM ^ sarmali, TEK komut', (Pos('SET TERM ^ ;', Metin) = 1) and (Length(KomutlaraBol(Metin)) = 1));
  Kontrol('Duzenle metni ad dogrulamasindan geciyor', NesneAdiniDogrula(ntTetikleyici, Metin, TR) = '');
  Kontrol('ScriptUret(ntTetikleyici) CREATE TRIGGER uretiyor', Pos('CREATE TRIGGER ' + TR, ScriptUret(Bag, ntTetikleyici, TR)) > 0);
  Kontrol('Tetikleyici eski davranisi: LOG = v1', EkleOku(TB) = 'v1');

  Yeni := StringReplace(Metin, '''v1''', '''v2''', []);
  Kontrol('(deneme duzeni) metinde v1 vardi', Yeni <> Metin);
  ForceDirectories(ProsedurYedekKlasoru(Bag.Tanim.Ad));
  Once := Length(TDirectory.GetFiles(ProsedurYedekKlasoru(Bag.Tanim.Ad), '*.sql'));
  Sonuc := NesneKaydet(Bag, ntTetikleyici, TR, Yeni);
  if not Sonuc.Basarili then
    Not_('hata: ' + Sonuc.Cumle + ' / ' + Sonuc.Ayrinti);
  Kontrol('Kaydet basarili', Sonuc.Basarili);
  Kontrol('Tetikleyici yeni davranis: LOG = v2', EkleOku(TB) = 'v2');
  Kontrol('Sonuc: tek komut, CREATE OR ALTER TRIGGER ile basliyor', (Length(Sonuc.Komutlar) = 1) and (Pos('CREATE OR ALTER TRIGGER', Sonuc.Komutlar[0]) = 1));
  Not_('SQL ozeti: ' + TekSatir(string.Join(' || ', Sonuc.Komutlar)));
  Yedek := Sonuc.YedekDosyasi;
  Kontrol('Yedek dosyasi var, _arsiv\<baglanti> altinda, adi trigger_ADI_...sql',
    FileExists(Yedek) and (Pos(ProsedurYedekKlasoru(Bag.Tanim.Ad), Yedek) = 1) and StartsText('trigger_' + TR + '_', ExtractFileName(Yedek)) and
    EndsText('.sql', Yedek));
  Not_('yedek: ' + Yedek);
  YedekMetni := '';
  if FileExists(Yedek) then
  begin
    YedekMetni := TFile.ReadAllText(Yedek, TEncoding.GetEncoding(1254));
    Kontrol('Yedek eski govdeyi iceriyor (v1), yenisini degil', (Pos('''v1''', YedekMetni) > 0) and (Pos('''v2''', YedekMetni) = 0));
    Kontrol('Yedek CREATE OR ALTER TRIGGER ve SET NAMES iceriyor', (Pos('CREATE OR ALTER TRIGGER ' + TR, YedekMetni) > 0) and (Pos('SET NAMES ', YedekMetni) > 0));
  end;
  Sonra := Length(TDirectory.GetFiles(ProsedurYedekKlasoru(Bag.Tanim.Ad), '*.sql'));
  Kontrol('Tam bir yedek dosyasi eklendi', Sonra = Once + 1);
  Sonuc := NesneKaydet(Bag, ntTetikleyici, TR, StringReplace(YedekMetni, 'SET NAMES ', '-- SET NAMES ', []));
  Kontrol('Yedek metniyle geri kaydetme basarili', Sonuc.Basarili);
  Kontrol('Geri yuklenince LOG = v1', EkleOku(TB) = 'v1');

  { Pasif trigger: INACTIVE korunur }
  Yurut(Bag, 'alter trigger ' + TR + ' inactive');
  Metin := TetikleyiciDuzenleScripti(Bag, TR);
  Kontrol('Pasif trigger: duzenleme metni INACTIVE', Pos('INACTIVE', Metin) > 0);
  Kontrol('Pasif trigger: listede Aktif=False', Listede(TR, Bilgi) and not Bilgi.Aktif);
  Sonuc := NesneKaydet(Bag, ntTetikleyici, TR, StringReplace(Metin, '''v1''', '''v3''', []));
  Kontrol('Pasif trigger: kaydet basarili ve hala pasif',
    Sonuc.Basarili and (Skaler(Bag, 'select rdb$trigger_inactive from rdb$triggers where rdb$trigger_name = ''' + TR + '''') = '1'));
  Kontrol('Pasif trigger calismiyor (LOG bos)', EkleOku(TB) = '');
  Yurut(Bag, 'alter trigger ' + TR + ' active');
  Kontrol('Tekrar aktif: yeni govde v3 calisiyor', EkleOku(TB) = 'v3');
end;

{ Kaydetmeyi dener, sonucu yazar. Zorunlu: reddedilmeli, cumle bos/genel olmamali, eski trigger bozulmamali. }
procedure HataDene(const Etiket, Metin: string; Zorunlu: Boolean);
var
  Sonuc: TProsedurSonucu;
begin
  Sonuc := NesneKaydet(Bag, ntTetikleyici, TR, Metin);
  Not_(Etiket + ': basarili=' + BoolToStr(Sonuc.Basarili, True) + ' cumle=' + TekSatir(Sonuc.Cumle) + '  ayrinti=' + TekSatir(Sonuc.Ayrinti) +
    '  satir=' + IntToStr(Sonuc.Satir));
  if Zorunlu then
  begin
    Kontrol(Etiket + ': reddedildi, anlasilir cumle (genel hata degil), Ayrinti dolu',
      (not Sonuc.Basarili) and (Sonuc.Cumle <> '') and (Sonuc.Cumle <> T('ERR_GENEL')) and (Pos('ERR_', Sonuc.Cumle) = 0) and (Sonuc.Ayrinti <> ''));
    Kontrol(Etiket + ': eski trigger bozulmadi',
      Pos('''v1''', Skaler(Bag, 'select rdb$trigger_source from rdb$triggers where rdb$trigger_name = ''' + TR + '''')) > 0);
  end;
end;

procedure HataBolumu;
var
  Metin: string;
  Sonuc: TProsedurSonucu;
begin
  Cikti.Add('');
  Cikti.Add('=== B2) Hatalar: cumle + Ayrinti, eski trigger bozulmuyor ===');
  Kur;
  Metin := TetikleyiciDuzenleScripti(Bag, TR);
  HataDene('sozdizimi', StringReplace(Metin, 'new.LOG = ''v1'';', 'new.LOG = = ''v1'';', [rfIgnoreCase]), True);
  HataDene('olmayan kolon', StringReplace(Metin, 'new.LOG', 'new.YOKKOLON', [rfIgnoreCase]), True);
  { OR ALTER ile baska tabloya baglama tablo degistirme sayilir ve kaydetmeden reddedilir (Ayrinti bos); gercek Table unknown yalniz yeni olusturmada olur. }
  HataDene('olmayan tabloya baglama', StringReplace(Metin, 'FOR ' + TB, 'FOR FBY_TEST_YOKTABLO', []), False);
  HataDene('DELETE tetikleyicisinde NEW', StringReplace(Metin, 'BEFORE INSERT', 'BEFORE DELETE', []), False);
  Kur;
  Sonuc := NesneKaydet(Bag, ntTetikleyici, TR, StringReplace(Metin, 'BEFORE INSERT', 'AFTER INSERT', []));
  Not_('AFTER tetikleyicide NEW atama: basarili=' + BoolToStr(Sonuc.Basarili, True) + ' cumle=' + TekSatir(Sonuc.Cumle) + ' ayrinti=' + TekSatir(Sonuc.Ayrinti));
  Kontrol('AFTER tetikleyicide NEW atama: salt okunur kolon cumlesi (hata kabul edilirse)',
    Sonuc.Basarili or (Pos('read-only', Sonuc.Ayrinti) = 0) or (Sonuc.Cumle = T('ERR_SALT_OKUNUR_KOLON')));
  Kur;
  { Tablo degistirme: Firebird (5.0.4 olculdu) hata vermeden tetikleyiciyi baska tabloya TASIR; program bunu kaydetmeden reddeder. }
  Sonuc := NesneKaydet(Bag, ntTetikleyici, TR, StringReplace(Metin, 'FOR ' + TB, 'FOR ' + TB2, []));
  Kontrol('Tablo degistirme reddedildi (ERR_TRG_TABLO_DEGISTI), veritabanina dokunulmadi, trigger ayni tabloda',
    (not Sonuc.Basarili) and (Sonuc.Cumle = TF('ERR_TRG_TABLO_DEGISTI', [TR, TB, TB2])) and (Length(Sonuc.Komutlar) = 0) and
    (Skaler(Bag, 'select rdb$relation_name from rdb$triggers where rdb$trigger_name = ''' + TR + '''') = TB));
  Not_('tablo degistirme cumlesi: ' + TekSatir(Sonuc.Cumle));
  Sonuc := NesneKaydet(Bag, ntTetikleyici, TR, StringReplace(Metin, 'FOR ' + TB, 'FOR ' + LowerCase(TB), []));
  Kontrol('Kucuk harfli ayni tablo adi tablo degistirme sayilmaz', Sonuc.Basarili);
  Kur;
  Sonuc := NesneKaydet(Bag, ntTetikleyici, TR, StringReplace(Metin, TR, 'FBY_TEST_TR9', [rfReplaceAll]));
  Kontrol('Ad degisikligi reddedildi, veritabanina dokunulmadi, yeni trigger olusmadi',
    (not Sonuc.Basarili) and (Sonuc.Cumle = TF('ERR_TRG_AD_DEGISTI', [TR, 'FBY_TEST_TR9'])) and (Length(Sonuc.Komutlar) = 0) and
    (Skaler(Bag, 'select count(*) from rdb$triggers where rdb$trigger_name = ''FBY_TEST_TR9''') = '0'));
  Sonuc := NesneKaydet(Bag, ntTetikleyici, TR, StringReplace(Metin, 'CREATE OR ALTER TRIGGER', 'CREATE TRIGGER', []));
  Kontrol('Basliksiz (CREATE TRIGGER) metin reddedildi', (not Sonuc.Basarili) and (Sonuc.Cumle = TF('ERR_TRG_BASLIK_YOK', [TR, TR])));
end;

procedure YedekYazilamazBolumu;
var
  Klasor, Dosya: string;
  Sonuc: TProsedurSonucu;
  Metin: string;
begin
  Cikti.Add('');
  Cikti.Add('=== B4) Eski tanim yedeklenemezse kaydetme DURUR ===');
  Kur;
  Metin := TetikleyiciDuzenleScripti(Bag, TR);
  Klasor := TPath.Combine(TPath.GetTempPath, 'triggertest_yedeksiz');
  TDirectory.CreateDirectory(Klasor);
  Dosya := TPath.Combine(Klasor, '_arsiv');
  TFile.WriteAllText(Dosya, 'engel');
  VeriKlasoruAyarla(Klasor);
  try
    Sonuc := NesneKaydet(Bag, ntTetikleyici, TR, StringReplace(Metin, '''v1''', '''v9''', []));
  finally
    VeriKlasoruAyarla(VeriKlasoru);
  end;
  Kontrol('Yedek yazilamadi: basarisiz, cumle ERR_PRS_YEDEK_YAZILAMADI', (not Sonuc.Basarili) and (Sonuc.Cumle = T('ERR_PRS_YEDEK_YAZILAMADI')));
  Kontrol('Yedek yazilamadi: veritabanina dokunulmadi', (Length(Sonuc.Komutlar) = 0) and (EkleOku(TB) = 'v1'));
  TFile.Delete(Dosya);
end;

procedure OzelTurlerBolumu;
var
  Bilgi: TTetikleyiciBilgisi;
  Metin: string;
  Sonuc: TProsedurSonucu;
  Hata: string;
begin
  Cikti.Add('');
  Cikti.Add('=== B5) Veritabani tetikleyicisi (ON CONNECT) ve DDL tetikleyicisi (3.0+) ===');
  Dene(Bag, 'drop trigger ' + TR_DB);
  Yurut(Bag, 'create trigger ' + TR_DB + ' inactive on connect position 0 as begin end');
  Kontrol('DB tetikleyicisi listede: tablo yok, tur ON CONNECT, pasif',
    Listede(TR_DB, Bilgi) and (Bilgi.Tablo = '') and (Bilgi.Olaylar = 'ON CONNECT') and not Bilgi.Aktif and not Bilgi.Desteklenmiyor);
  Metin := TetikleyiciDuzenleScripti(Bag, TR_DB);
  Not_('DB trigger metni: ' + TekSatir(Metin, 300));
  Kontrol('DB tetikleyicisi duzenleme metni: ON CONNECT, FOR yok, INACTIVE',
    (Pos('CREATE OR ALTER TRIGGER ' + TR_DB, Metin) > 0) and (Pos('ON CONNECT', Metin) > 0) and (Pos(' FOR ', Metin) = 0) and (Pos('INACTIVE', Metin) > 0));
  Sonuc := NesneKaydet(Bag, ntTetikleyici, TR_DB, StringReplace(Metin, 'begin', '/* duzenlendi */ begin', [rfIgnoreCase]));
  if not Sonuc.Basarili then
    Not_('DB trigger kaydet hata: ' + Sonuc.Cumle + ' / ' + Sonuc.Ayrinti);
  Kontrol('DB tetikleyicisi kaydedilebiliyor', Sonuc.Basarili);
  Dene(Bag, 'drop trigger ' + TR_DB);
  if StrToIntDef(Copy(Bag.Surum, 1, 1), 0) < 3 then
  begin
    Not_('surum ' + Bag.Surum + ': DDL tetikleyicisi yok (2.5), atlandi');
    Exit;
  end;
  Dene(Bag, 'drop trigger ' + TR_DDL);
  try
    Yurut(Bag, 'create trigger ' + TR_DDL + ' inactive before create table as begin end');
  except
    on E: Exception do
    begin
      Not_('DDL tetikleyicisi olusturulamadi: ' + HataKodlari(E));
      Exit;
    end;
  end;
  Kontrol('DDL tetikleyicisi listede: tur DDL, duzenlenemez isaretli', Listede(TR_DDL, Bilgi) and (Bilgi.Olaylar = 'DDL') and Bilgi.Desteklenmiyor);
  Hata := '';
  try
    TetikleyiciDuzenleScripti(Bag, TR_DDL);
  except
    on E: EMetadataHatasi do
      Hata := E.Message;
  end;
  Kontrol('DDL tetikleyicisi: duzenleme metni uretilmiyor (anlasilir EMetadataHatasi)', Hata <> '');
  Dene(Bag, 'drop trigger ' + TR_DDL);
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
  Kur;
  Metin := TetikleyiciDuzenleScripti(Bag, TR);
  Inc(Sayac);
  T2 := Tanim;
  T2.Ad := 'trigger_test_y' + IntToStr(Sayac);
  T2.Kullanici := YETKISIZ;
  if Gomulu then
    T2.Sifre := 'x'
  else
  begin
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
      Not_('yetkisiz kullanici baglanamadi: ' + Hata + ' (bu kipte denenemiyor)');
      Exit;
    end;
    Sonuc := NesneKaydet(Bag2, ntTetikleyici, TR, StringReplace(Metin, '''v1''', '''v4''', []));
    Not_('yetkisiz: basarili=' + BoolToStr(Sonuc.Basarili, True) + ' cumle=' + TekSatir(Sonuc.Cumle) + '  ayrinti=' + TekSatir(Sonuc.Ayrinti));
    Kontrol('Yetkisiz kullanici: kaydetme reddedildi, cumle ERR_YETKI_YOK', (not Sonuc.Basarili) and (Sonuc.Cumle = T('ERR_YETKI_YOK')));
    Kontrol('Yetkisiz kullanici: trigger degismedi', EkleOku(TB) = 'v1');
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
  Kur;
  Metin := StringReplace(TetikleyiciDuzenleScripti(Bag, TR), 'new.LOG = ''v1'';', 'new.LOG = = ''v1'';', [rfIgnoreCase]);
  for Dil in ['tr', 'en', 'de'] do
  begin
    DilYukle(Dil);
    Sonuc := NesneKaydet(Bag, ntTetikleyici, TR, Metin);
    Not_(Dil + ': ' + TekSatir(Sonuc.Cumle));
    Kontrol('Dil ' + Dil + ': sozdizimi cumlesi cevrilmis', (Sonuc.Cumle <> '') and (Pos('ERR_', Sonuc.Cumle) = 0));
    Not_(Dil + ' ad degisti: ' + TekSatir(TF('ERR_TRG_AD_DEGISTI', [TR, 'X'])));
    Not_(Dil + ' onay: ' + TekSatir(TF('ONAY_TRG_KAYDET', [TR])));
  end;
  DilYukle('tr');
end;

procedure SekmeBolumu;
var
  Form: TForm;
  Sekme: TProsedurSekme;
  Satirlar: TStringList;
begin
  Cikti.Add('');
  Cikti.Add('=== B9) Arayuz duman testi: trigger sekmesi ===');
  Kur;
  Satirlar := TStringList.Create;
  Form := TForm.CreateNew(nil);
  try
    Sekme := TProsedurSekme.Create(Form);
    Sekme.Parent := Form;
    Sekme.Align := alClient;
    Sekme.AnaSonuc := Satirlar;
    Sekme.Tur := ntTetikleyici;
    Sekme.Yukle(Bag, TR);
    Kontrol('Sekme: baslik "Trigger: ADI (baglanti)"', Sekme.Baslik = TF('TRG_SEKME', [TR, Bag.Tanim.Ad]));
    Kontrol('Sekme: Kaydet dugmesi yazisi dilden ve OnClick bagli', (Sekme.btnKaydet.Caption = T('PRS_KAYDET')) and Assigned(Sekme.btnKaydet.OnClick));
    Kontrol('Sekme: bilgi satiri trigger metni', Sekme.lblBilgi.Caption = TF('TRG_BILGI', [TR]));
    Sekme.F5Ipucu;
    Kontrol('Sekme: F5 yalniz ipucu yazar', (Satirlar.Count = 1) and (Satirlar[0] = T('MSG_PRS_F5_IPUCU')));
    Sekme.BaglantiAd := 'yok_boyle_baglanti';
    Sekme.Kaydet;
    Kontrol('Sekme: baglanti yoksa Kaydet mesaj yazar', (Satirlar.Count = 2) and (Pos('yok_boyle_baglanti', Satirlar[1]) > 0));
  finally
    Form.Free;
    Satirlar.Free;
  end;
end;

procedure Temizle;
begin
  Dene(Bag, 'drop trigger ' + TR_DB);
  Dene(Bag, 'drop trigger ' + TR_DDL);
  Dene(Bag, 'drop trigger ' + TR);
  Dene(Bag, 'drop table ' + TB);
  Dene(Bag, 'drop table ' + TB2);
end;

{ ---------- Ana akis ---------- }

var
  YazmaIstendi, YazmaIzni, KendiVeritabanim: Boolean;
  Neden, Klasor: string;
begin
  Cikti := TStringList.Create;
  Bag := nil;
  KendiVeritabanim := False;
  VeriKlasoru := TPath.Combine(GetEnvironmentVariable('TEMP'), 'triggertest_veri');
  try
    try
      DilYukle('tr');
      Tanim.Ad := 'trigger_test';
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
        Klasor := TPath.Combine(GetEnvironmentVariable('TEMP'), 'triggertest');
        ForceDirectories(Klasor);
        Tanim.VeritabaniYolu := TPath.Combine(Klasor, 'test_' + FormatDateTime('yyyymmdd_hhnnss', Now) + '.fdb');
        GeciciVeritabaniOlustur(Tanim);
        KendiVeritabanim := True;
      end;
      if Tanim.VeritabaniYolu = '' then
        raise Exception.Create('FBTEST_YOL bos: sunucudaki var olan bir veritabani yolu verin.');

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

      Cikti.Add('TriggerDuzenleTest  ' + FormatDateTime('yyyy-mm-dd hh:nn:ss', Now));
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
          YedekYazilamazBolumu;
          OzelTurlerBolumu;
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
    Cikti.SaveToFile(Ortam('FBTEST_CIKTI', 'triggertest.txt'), TEncoding.UTF8);
  finally
    Cikti.Free;
  end;
  ExitCode := Hatalar;
end.
