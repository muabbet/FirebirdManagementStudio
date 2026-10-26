program KullaniciTest;

{ Asama 3d-1: uKullanici (sunucu kullanicilari: ekle, sil, sifre, ad/soyad, yonetici, aktif) ve
  uMetadata.KullaniciListesiOku / KullaniciYetenekleri testi (komut satiri).

  Uc bolum var:
    A) HER KIPTE (gomulu de, sunucu da): saf kurallar (kullanici adi, sifre kacirma/gizleme, uyari, hata cumleleri,
       kayitli baglanti sifresi, KomutHazirla ile ozel karakterlerin yorumlanmamasi). Sunucuya yazmaz.
    B) GOMULU kip (FBTEST_SUNUCU bos): kullanici yonetimi yok davranisi (liste ve tum yazma islemleri reddedilir).
       Program kendi gecici veritabanini acar.
    C) SUNUCU kip: liste OKUMA her sunucuda calisir. YAZMA bolumu YALNIZCA yerel sunucuda 3052, 3053 ve 3054
       portlarinda ve FBTEST_YAZMA=1 verilmisse calisir; baska portta (3050 ve 3051 dahil) kod seviyesinde
       REDDEDILIR (yazma hic baslamaz, okuma yine calisir).

  Ortam degiskenleri: FBTEST_SUNUCU (bos = gomulu), FBTEST_PORT, FBTEST_YOL (sunucudaki VAR OLAN veritabani; yeni
  kullanicilarin baglanabildigini denemek icin), FBTEST_KULLANICI, FBTEST_SIFRE, FBTEST_CIKTI (sonuc dosyasi),
  FBTEST_YAZMA. Sifre hicbir yere yazilmaz. Test kullanicilari FBY_TEST3D, FBY_TEST3D_B, FBY_TEST3D_C, FBY_YASAK
  baslar ve test sonunda silinir (yarim kalirsa bir sonraki calistirmada temizlenir).
  Cikis kodu: hata sayisi (0 = hepsi gecti). }

{$APPTYPE CONSOLE}

uses
  System.SysUtils, System.Classes, System.StrUtils, System.IOUtils, Data.DB,
  FireDAC.Stan.Intf, FireDAC.Stan.Error, FireDAC.Comp.Client, FireDAC.Phys.FB,
  FireDAC.ConsoleUI.Wait,
  uDil, uBaglanti, uMetadata, uKullanici;

const
  TEST_KULLANICI = 'FBY_TEST3D';
  TEST_KULLANICI_B = 'FBY_TEST3D_B';
  TEST_KULLANICI_C = 'FBY_TEST3D_C';
  TEST_YASAK = 'FBY_YASAK';
  SIFRE_1 = 'Ilk12345';
  SIFRE_2 = 'Ikinci123';
  SIFRE_3 = 'Ucuncu123';
  // tirnak, iki nokta, &, !, bosluk, suslu parantezler ve ? ozel karakterleri (SQL metninde yorumlanmamali)
  SIFRE_OZEL = 'Ab''c:d&e!f g{h}?i';
  { Turkce harfli sifre: c g i(noktasiz) o s u }
  SIFRE_TURKCE = 'Sifre'#$00E7#$011F#$0131#$00F6#$015F#$00FC'1';
  ISIM_TURKCE = 'Ay'#$015F'e';
  SOYAD_TURKCE = 'Y'#$0131'lmaz';

var
  Cikti: TStringList;
  Hatalar, KontrolSayisi, Sayac: Integer;
  Tanim: TBaglantiTanimi;
  Bag: TAcikBaglanti;
  Gomulu: Boolean;

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

{ Hata: sinif, ham mesaj, Firebird kodlari ve bizim anlasilir cumlemiz }
function HataMetni(E: Exception): string;
var
  I: Integer;
begin
  Result := E.ClassName + ': ' + TekSatir(E.Message);
  if E is EFDDBEngineException then
    for I := 0 to EFDDBEngineException(E).ErrorCount - 1 do
      Result := Result + ' [kod=' + IntToStr(EFDDBEngineException(E).Errors[I].ErrorCode) + ']';
  Result := Result + '  => cevirisi: ' + TekSatir(HataMetniniCevir(E));
end;

{ Islem EKullaniciKurali ile BeklenenMesaj'i vererek reddedilmeli. }
procedure KuralReddi(const Ad: string; Islem: TProc; const BeklenenMesaj: string);
var
  Reddedildi: Boolean;
  Mesaj: string;
begin
  Reddedildi := False;
  Mesaj := '';
  try
    Islem;
  except
    on E: EKullaniciKurali do
    begin
      Reddedildi := True;
      Mesaj := E.Message;
    end;
    on E: Exception do
      Mesaj := 'BEKLENMEYEN: ' + HataMetni(E);
  end;
  Kontrol(Ad, Reddedildi and (Mesaj = BeklenenMesaj));
  if not (Reddedildi and (Mesaj = BeklenenMesaj)) then
    Not_('mesaj: ' + TekSatir(Mesaj));
end;

{ Islem herhangi bir hata vermeli; hatanin ham/cevrilmis metnini yazar. Cevrilen cumle Beklenen ise (bos degilse) kontrol eder. }
function SunucuReddi(const Ad: string; Islem: TProc; const BeklenenCumle: string): string;
var
  Hata: Boolean;
  Cumle: string;
begin
  Hata := False;
  Result := '';
  try
    Islem;
  except
    on E: Exception do
    begin
      Hata := True;
      Result := HataMetni(E);
      if E is EKullaniciKurali then
        Cumle := E.Message
      else
        Cumle := HataMetniniCevir(E);
      if (BeklenenCumle <> '') and (Cumle <> BeklenenCumle) then
        Hata := False;
    end;
  end;
  Kontrol(Ad, Hata);
  Not_(Result);
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

{ Verilen kullanici/sifre ile baglanmayi dener; basarirsa baglanti doner (cagiran kapatir), olmazsa nil. }
function BaglanDene(const Kullanici, Sifre: string; out Hata: string): TAcikBaglanti;
var
  T: TBaglantiTanimi;
begin
  Inc(Sayac);
  T := Tanim;
  T.Ad := 'kullanici_test_' + IntToStr(Sayac);
  T.Kullanici := Kullanici;
  T.Sifre := Sifre;
  Hata := '';
  try
    Result := FbBaglan(T);
  except
    on E: Exception do
    begin
      Result := nil;
      Hata := HataMetni(E);
    end;
  end;
end;

{ Yonetici (SYSDBA olmayan) kullanici icin RDB$ADMIN rolunu belirterek baglanir (uygulamanin baglanti tanimi rol alani
  tasimaz, bu yuzden FbBaglan kullanilmaz; liste kaydina da eklenmez). Cagiran Free ile kapatir. }
function BaglanRolle(const Kullanici, Sifre: string; out Hata: string): TAcikBaglanti;
var
  Yeni: TFDConnection;
begin
  Hata := '';
  Result := nil;
  Yeni := TFDConnection.Create(nil);
  try
    Yeni.DriverName := 'FB';
    Yeni.LoginPrompt := False;
    Yeni.Params.Values['Server'] := Tanim.Sunucu;
    Yeni.Params.Values['Port'] := IntToStr(Tanim.Port);
    Yeni.Params.Values['Protocol'] := 'TCPIP';
    Yeni.Params.Values['Database'] := Tanim.VeritabaniYolu;
    Yeni.Params.Values['User_Name'] := Kullanici;
    Yeni.Params.Values['Password'] := Sifre;
    Yeni.Params.Values['RoleName'] := 'RDB$ADMIN';
    Yeni.Params.Values['CharacterSet'] := Tanim.KarakterSeti;
    Yeni.Params.Values['Pooled'] := 'False';
    FbSurucu;
    Yeni.Open;
    Result := TAcikBaglanti.Create;
    Result.Baglanti := Yeni;
    Result.Tanim := Tanim;
    Result.Tanim.Kullanici := Kullanici;
    Result.Tanim.Sifre := Sifre;
    Result.Surum := Bag.Surum;
  except
    on E: Exception do
    begin
      Hata := HataMetni(E);
      Result := nil;
      Yeni.Free;
    end;
  end;
end;

function BaglanirMi(const Kullanici, Sifre: string): Boolean;
var
  Hata: string;
  B: TAcikBaglanti;
begin
  B := BaglanDene(Kullanici, Sifre, Hata);
  Result := B <> nil;
  if Result then
    FbBaglantiyiKes(B)
  else
    Not_('baglanamadi: ' + Hata);
end;

function ListedeBul(B: TAcikBaglanti; const Ad: string; out K: TKullaniciBilgisi): Boolean;
var
  Liste: TArray<TKullaniciBilgisi>;
  Aday: TKullaniciBilgisi;
begin
  Result := False;
  K := Default(TKullaniciBilgisi);
  Liste := KullaniciListesiOku(B);
  for Aday in Liste do
    if SameText(Aday.Ad, Ad) then
    begin
      K := Aday;
      Exit(True);
    end;
end;

function ListedeVarMi(B: TAcikBaglanti; const Ad: string): Boolean;
var
  K: TKullaniciBilgisi;
begin
  Result := ListedeBul(B, Ad, K);
end;

{ Test kullanicilarini sessizce siler (onceki yarim kalmis calistirma veya test sonu temizligi). }
procedure Temizle(B: TAcikBaglanti);
const
  ADLAR: array[0..3] of string = (TEST_KULLANICI, TEST_KULLANICI_B, TEST_KULLANICI_C, TEST_YASAK);
var
  I: Integer;
begin
  for I := Low(ADLAR) to High(ADLAR) do
    try
      if ListedeVarMi(B, ADLAR[I]) then
        KullaniciSil(B, ADLAR[I]);
    except
    end;
end;

{ ---------- A) Her kipte: saf kurallar ---------- }

procedure KurallarBolumu;
var
  Sorgu: TFDQuery;
  Ham, OncekiAd: string;
  Kayit: TBaglantiTanimi;
  E: Exception;
begin
  Cikti.Add('');
  Cikti.Add('=== A) Kurallar (sunucuya yazmaz) ===');
  { Kullanici adi dogrulama }
  Kontrol('Ad: kucuk harf buyur ve boslugu kirpar', KullaniciAdiniDogrula('  fby_test$1 ') = 'FBY_TEST$1');
  KuralReddi('Ad: bos reddedilir', procedure begin KullaniciAdiniDogrula('   '); end, T('ERR_KULLANICI_AD_BOS'));
  KuralReddi('Ad: bosluk reddedilir', procedure begin KullaniciAdiniDogrula('a b'); end, T('ERR_KULLANICI_AD_GECERSIZ'));
  KuralReddi('Ad: Turkce harf reddedilir', procedure begin KullaniciAdiniDogrula('A'#$011F'a'); end, T('ERR_KULLANICI_AD_GECERSIZ'));
  KuralReddi('Ad: tire reddedilir', procedure begin KullaniciAdiniDogrula('a-b'); end, T('ERR_KULLANICI_AD_GECERSIZ'));
  KuralReddi('Ad: tirnak reddedilir', procedure begin KullaniciAdiniDogrula('a"b'); end, T('ERR_KULLANICI_AD_GECERSIZ'));
  KuralReddi('Ad: nokta virgul (SQL zerki) reddedilir', procedure begin KullaniciAdiniDogrula('a;drop'); end, T('ERR_KULLANICI_AD_GECERSIZ'));
  Kontrol('Ad: 31 karakter kabul', Length(KullaniciAdiniDogrula(StringOfChar('A', 31))) = 31);
  KuralReddi('Ad: 32 karakter reddedilir', procedure begin KullaniciAdiniDogrula(StringOfChar('A', 32)); end, T('ERR_KULLANICI_AD_GECERSIZ'));
  Kontrol('SYSDBA tanimi buyuk/kucuk harf duyarsiz', SysdbaMi('sysdba') and SysdbaMi(' SYSDBA ') and not SysdbaMi('SYSDBA2'));

  { Metin kacirma ve gizleme: sifre tek yerde kacirilir }
  Kontrol('SqlMetni: tirnak iki katina cikar', SqlMetni('a''b') = '''a''''b''');
  Kontrol('EkleKomutu: sifre kacirilir', Pos('PASSWORD ''Ab''''c:d&e!f g{h}?i''', EkleKomutu('X', SIFRE_OZEL, '', '', False)) > 0);
  Kontrol('EkleKomutu(Gizle): sifre gorunmez, *** var',
    (Pos('Ab', EkleKomutu('X', SIFRE_OZEL, '', '', True)) = 0) and (Pos('''***''', EkleKomutu('X', SIFRE_OZEL, '', '', True)) > 0));
  Kontrol('EkleKomutu: ad ve soyad kacirilir', Pos('FIRSTNAME ''O''''Brien''', EkleKomutu('X', 'p', 'O''Brien', '', False)) > 0);
  Kontrol('SifreKomutu(Gizle): sifre gorunmez', Pos(SIFRE_1, SifreKomutu(Bag, 'BASKA', SIFRE_1, True)) = 0);
  Kontrol('SifreKomutu: baska kullanici ALTER USER', StartsText('ALTER USER BASKA PASSWORD ', SifreKomutu(Bag, 'BASKA', 'x', False)));
  if KullaniciYetenekleri(Bag).KendiSifreKomutu = skAlterCurrentUser then
    Kontrol('SifreKomutu: kendi kullanici ALTER CURRENT USER (3.0+)',
      StartsText('ALTER CURRENT USER SET PASSWORD ', SifreKomutu(Bag, Bag.Tanim.Kullanici, 'x', False)))
  else
    Kontrol('SifreKomutu: kendi kullanici ALTER USER kendi_adi (2.5)',
      StartsText('ALTER USER ' + UpperCase(Bag.Tanim.Kullanici) + ' PASSWORD ', SifreKomutu(Bag, Bag.Tanim.Kullanici, 'x', False)));

  { FireDAC ozel karakterleri parametre/makro/kacis sanmamali: SELECT ile (yazmadan) kanitlanir }
  Sorgu := KomutHazirla(Bag, 'select ' + SqlMetni(SIFRE_OZEL) + ' as S from RDB$DATABASE');
  try
    Sorgu.Open;
    Kontrol('KomutHazirla: ozel karakterli metin aynen gider (: & ! { } ? '' bosluk)', Sorgu.FieldByName('S').AsString = SIFRE_OZEL);
    if Sorgu.FieldByName('S').AsString <> SIFRE_OZEL then
      Not_('gelen: [' + Sorgu.FieldByName('S').AsString + ']  giden: [' + SIFRE_OZEL + ']  SQL: ' + Sorgu.SQL.Text);
    Sorgu.Close;
    Sorgu.SQL.Text := 'select ' + SqlMetni(SIFRE_TURKCE) + ' as S from RDB$DATABASE';
    Sorgu.Open;
    Kontrol('KomutHazirla: Turkce harfli metin aynen gider', Sorgu.FieldByName('S').AsString = SIFRE_TURKCE);
  finally
    Sorgu.Free;
  end;

  { Sifre uyarisi }
  if KullaniciYetenekleri(Bag).ListeSql then
  begin
    Kontrol('SifreUyarisi: 20 bayt uyarisiz', SifreUyarisi(Bag, StringOfChar('a', 20)) = '');
    Kontrol('SifreUyarisi: 21 bayt uyari', SifreUyarisi(Bag, StringOfChar('a', 21)) <> '');
    Kontrol('SifreUyarisi: Turkce harf 2 bayt sayilir (11 harf = 22 bayt)', SifreUyarisi(Bag, StringOfChar(#$00E7, 11)) <> '');
  end
  else
  begin
    Kontrol('SifreUyarisi (2.5): 8 karakter uyarisiz', SifreUyarisi(Bag, StringOfChar('a', 8)) = '');
    Kontrol('SifreUyarisi (2.5): 9 karakter uyari', SifreUyarisi(Bag, StringOfChar('a', 9)) <> '');
  end;
  Kontrol('SifreUyarisi: 6 haneli sifre uyarisiz (alt sinir yok)', SifreUyarisi(Bag, '123456') = '');

  { Hata cumleleri (metne dayali olan; kod tabanlilari sunucu bolumunde) }
  E := Exception.Create('add record error' + #13#10 + 'no permission for INSERT access to TABLE PLG$SRP_VIEW');
  try
    Kontrol('HataMetniniCevir: PLG$SRP_VIEW -> yonetici olmali cumlesi', HataMetniniCevir(E) = T('ERR_KULLANICI_YONETIM_YETKI'));
  finally
    E.Free;
  end;
  E := Exception.Create('add record error' + #13#10 + 'violation of PRIMARY or UNIQUE KEY constraint "INTEG_5" on table "PLG$SRP"' +
    #13#10 + 'Problematic key value is ("PLG$USER_NAME" = ''FBY_X'')');
  try
    Kontrol('HataMetniniCevir: PLG$SRP tekrar kaydi -> "FBY_X zaten var" (yonetici olmali degil)',
      HataMetniniCevir(E) = TF('ERR_KULLANICI_VAR', ['FBY_X']));
  finally
    E.Free;
  end;
  E := Exception.Create('add record error | violation of PRIMARY or UNIQUE KEY constraint "INTEG_2" on table "RDB$USERS" | Problematic key value is ("RDB$USER_NAME" = ''FBY_X'')');
  try
    Kontrol('HataMetniniCevir (2.5 metni): RDB$USERS tekrar kaydi -> "FBY_X zaten var"', HataMetniniCevir(E) = TF('ERR_KULLANICI_VAR', ['FBY_X']));
  finally
    E.Free;
  end;
  E := Exception.Create('add record error | no permission for insert/write access to TABLE USERS');
  try
    Kontrol('HataMetniniCevir (2.5 metni): TABLE USERS yetkisi -> yonetici olmali', HataMetniniCevir(E) = T('ERR_KULLANICI_YONETIM_YETKI'));
  finally
    E.Free;
  end;
  E := Exception.Create('find/delete record error | no permission for delete/write access to TABLE USERS');
  try
    Kontrol('HataMetniniCevir (2.5 metni): TABLE USERS silme yetkisi -> yonetici olmali', HataMetniniCevir(E) = T('ERR_KULLANICI_YONETIM_YETKI'));
  finally
    E.Free;
  end;
  E := Exception.Create('add record error' + #13#10 + 'violation of PRIMARY or UNIQUE KEY constraint "INTEG_5" on table "PLG$SRP"');
  try
    Kontrol('HataMetniniCevir: ad bulunamazsa genel "zaten var" cumlesi', HataMetniniCevir(E) = T('ERR_KULLANICI_VAR_GENEL'));
  finally
    E.Free;
  end;
  Ham :=T('ERR_KULLANICI_YONETIM_YETKI') + T('ERR_YETKI_YOK') + T('ERR_KULLANICI_YOK') + T('ERR_KULLANICI_SYSDBA');
  Kontrol('Dil: yeni anahtarlar bulundu (anahtarin kendisi gorunmuyor)', Pos('ERR_', Ham) = 0);

  { Kayitli baglanti sifresi: kendi (gecici) veri klasorunde, gercek baglantilar.json'a dokunmaz }
  VeriKlasoruAyarla(TPath.Combine(GetEnvironmentVariable('TEMP'), 'kullanicitest_veri'));
  ForceDirectories(UygulamaVeriKlasoru);
  OncekiAd := Bag.Tanim.Ad;
  Kayit := Bag.Tanim;
  Kayit.Ad := 'kt_kayit';
  Kayit.Sifre := 'eski_kayitli_sifre';
  Kayit.SifreyiKaydet := True;
  BaglantiKaydet(Kayit);
  Bag.Tanim.Ad := 'kt_kayit';
  Kontrol('Kayitli sifre saklaniyor (SifreyiKaydet)', KayitliSifreSaklaniyorMu(Bag));
  KayitliSifreyiGuncelle(Bag, 'yeni_kayitli_sifre');
  Kontrol('KayitliSifreyiGuncelle: kayit yeni sifreyi tasir',
    KayitliBaglantiBul('kt_kayit', Kayit) and (Kayit.Sifre = 'yeni_kayitli_sifre') and Kayit.SifreyiKaydet);
  BaglantiListedenKaldir('kt_kayit');
  Kontrol('Kayit silindi (test verisi temizligi)', not KayitliBaglantiBul('kt_kayit', Kayit));
  Kontrol('Kayit yokken KayitliSifreSaklaniyorMu False', not KayitliSifreSaklaniyorMu(Bag));
  Bag.Tanim.Ad := OncekiAd;
  VeriKlasoruAyarla('');
end;

{ ---------- B) Gomulu kip ---------- }

procedure GomuluBolumu;
begin
  Cikti.Add('');
  Cikti.Add('=== B) Gomulu kip: kullanici yonetimi yok ===');
  Kontrol('Yetenek: gomuluda YonetimVar False', not KullaniciYetenekleri(Bag).YonetimVar);
  KuralReddi('Liste okuma reddedilir (EMetadataHatasi benzeri)',
    procedure
    begin
      try
        KullaniciListesiOku(Bag);
      except
        on E: EMetadataHatasi do
          raise EKullaniciKurali.Create(E.Message);
      end;
    end, T('ERR_KULLANICI_GOMULU'));
  KuralReddi('Ekle reddedilir', procedure begin KullaniciEkle(Bag, 'FBY_X', 'a', 'a', '', '', False); end, T('ERR_KULLANICI_GOMULU'));
  KuralReddi('Sil reddedilir', procedure begin KullaniciSil(Bag, 'FBY_X'); end, T('ERR_KULLANICI_GOMULU'));
  KuralReddi('Sifre reddedilir', procedure begin SifreDegistir(Bag, 'FBY_X', 'a', 'a'); end, T('ERR_KULLANICI_GOMULU'));
  KuralReddi('Ad/soyad reddedilir', procedure begin AdSoyadDegistir(Bag, 'FBY_X', 'a', 'b'); end, T('ERR_KULLANICI_GOMULU'));
  KuralReddi('Yonetici reddedilir', procedure begin YoneticiAyarla(Bag, 'FBY_X', True); end, T('ERR_KULLANICI_GOMULU'));
  KuralReddi('Aktif/pasif reddedilir', procedure begin AktifAyarla(Bag, 'FBY_X', False); end, T('ERR_KULLANICI_GOMULU'));
end;

{ ---------- C) Sunucu: okuma ---------- }

procedure SunucuOkumaBolumu;
var
  Yetenek: TKullaniciYetenekleri;
  K: TKullaniciBilgisi;
  Liste: TArray<TKullaniciBilgisi>;
begin
  Cikti.Add('');
  Cikti.Add('=== C1) Sunucu: okuma (surum ' + Bag.Surum + ') ===');
  Yetenek := KullaniciYetenekleri(Bag);
  Kontrol('Yetenek: sunucu kipinde YonetimVar True', Yetenek.YonetimVar);
  Not_(Format('yetenekler: ListeSql=%s YoneticiOkunur=%s YoneticiAyarlanir=%s AktifPasif=%s KendiSifre=%s',
    [BoolToStr(Yetenek.ListeSql, True), BoolToStr(Yetenek.YoneticiOkunur, True), BoolToStr(Yetenek.YoneticiAyarlanir, True),
     BoolToStr(Yetenek.AktifPasif, True), IfThen(Yetenek.KendiSifreKomutu = skAlterCurrentUser, 'ALTER CURRENT USER', 'ALTER USER')]));
  try
    Liste := KullaniciListesiOku(Bag);
    Kontrol('Liste okunur (' + IntToStr(Length(Liste)) + ' kullanici)', Length(Liste) >= 1);
    for K in Liste do
      Not_(Format('%s | %s | %s | %s | yonetici=%s aktif=%s bilgiVar=%s',
        [K.Ad, K.Isim, K.OrtaAd, K.Soyad, BoolToStr(K.Yonetici, True), BoolToStr(K.Aktif, True), BoolToStr(K.BilgiVar, True)]));
    Kontrol('Listede SYSDBA var (SYSDBA ile baglanildiysa)', not SysdbaMi(Bag.Tanim.Kullanici) or ListedeVarMi(Bag, 'SYSDBA'));
    Kontrol('BilgiVar: 3.0+ True, 2.5 False', (Length(Liste) = 0) or (Liste[0].BilgiVar = Yetenek.YoneticiOkunur));
  except
    on E: Exception do
      Kontrol('Liste okunamadi: ' + HataMetni(E), False);
  end;
end;

{ ---------- C) Sunucu: yazma (yalniz 3052/3053/3054) ---------- }

procedure SunucuYazmaBolumu;
var
  Yetenek: TKullaniciYetenekleri;
  K: TKullaniciBilgisi;
  BagKendi, BagAdmin: TAcikBaglanti;
  Hata, Ham: string;
begin
  Cikti.Add('');
  Cikti.Add('=== C2) Sunucu: yazma (test kullanicilari ' + TEST_KULLANICI + ', ' + TEST_KULLANICI_B + ') ===');
  Yetenek := KullaniciYetenekleri(Bag);
  Temizle(Bag);

  { Ekle -> listede gorunur -> ilk sifreyle baglanir }
  try
    if not Yetenek.ListeSql then
    begin
      { 2.5: Turkce harfli ad/soyad reddedilir (Services listesinde farkli gorunuyordu); ASCII ile devam edilir. }
      KuralReddi('Ekle (2.5): Turkce harfli ad/soyad reddedilir', procedure begin KullaniciEkle(Bag, TEST_YASAK, 'a', 'a', ISIM_TURKCE, 'x', False); end, T('ERR_ISIM_ASCII_ESKI'));
      KullaniciEkle(Bag, 'fby_test3d', SIFRE_1, SIFRE_1, 'Ayse', 'Yilmaz', False);
    end
    else
      KullaniciEkle(Bag, 'fby_test3d', SIFRE_1, SIFRE_1, ISIM_TURKCE, SOYAD_TURKCE, False);
    Kontrol('Ekle: kullanici eklendi (ad kucuk harfle verildi, buyuk harfe cevrildi)', ListedeBul(Bag, TEST_KULLANICI, K));
    if Yetenek.ListeSql then
      Kontrol('Ekle: ad ve soyad (Turkce harfli) listede dogru', (K.Isim = ISIM_TURKCE) and (K.Soyad = SOYAD_TURKCE))
    else
      Kontrol('Ekle (2.5): ASCII ad ve soyad listede dogru', (K.Isim = 'Ayse') and (K.Soyad = 'Yilmaz'));
    if Yetenek.YoneticiOkunur then
      Kontrol('Ekle: yonetici degil, aktif', (not K.Yonetici) and K.Aktif);
    Kontrol('Ekle: ilk sifreyle baglanir', BaglanirMi(TEST_KULLANICI, SIFRE_1));
  except
    on E: Exception do
      Kontrol('Ekle sirasinda hata: ' + HataMetni(E), False);
  end;

  { Ayni adi yeniden ekle: bizim cumlemiz; sunucunun gercek hatasi da kaydedilir (ceviri icin) }
  KuralReddi('Ekle: ayni ad yeniden eklenemez (kullanici zaten var cumlesi)',
    procedure begin KullaniciEkle(Bag, TEST_KULLANICI, SIFRE_1, SIFRE_1, '', '', False); end,
    TF('ERR_KULLANICI_VAR', [TEST_KULLANICI]));
  try
    KomutHazirla(Bag, EkleKomutu(TEST_KULLANICI, SIFRE_1, '', '', False)).ExecSQL;
    Not_('BILGI: ayni ad sunucuda da eklendi?! (beklenmiyordu)');
  except
    on E: Exception do
    begin
      Not_('BILGI (sunucunun gercek "zaten var" hatasi): ' + StringReplace(HataMetni(E), SIFRE_1, '***', [rfReplaceAll]));
      { 3.0+ metni olculdu (PLG$SRP); 2.5'in metni farkli olabilir, orada yalniz BILGI satiri yazilir. }
      Kontrol('Zaten-var hatasinin cevirisi "kullanici zaten var" (yonetici olmali veya Beklenmeyen DEGIL; 3.0, 4.0, 2.5)',
        HataMetniniCevir(E) = TF('ERR_KULLANICI_VAR', [TEST_KULLANICI]));
    end;
  end;

  { Kural ihlalleri sunucuya gitmeden reddedilir }
  KuralReddi('Ekle: bos sifre reddedilir', procedure begin KullaniciEkle(Bag, TEST_YASAK, '', '', '', '', False); end, T('ERR_SIFRE_BOS'));
  KuralReddi('Ekle: iki sifre farkli reddedilir', procedure begin KullaniciEkle(Bag, TEST_YASAK, 'a', 'b', '', '', False); end, T('ERR_SIFRE_FARKLI'));
  KuralReddi('Ekle: gecersiz ad reddedilir', procedure begin KullaniciEkle(Bag, 'a b', 'a', 'a', '', '', False); end, T('ERR_KULLANICI_AD_GECERSIZ'));
  KuralReddi('Ekle: cok uzun ad soyad reddedilir',
    procedure begin KullaniciEkle(Bag, TEST_YASAK, 'a', 'a', StringOfChar('x', 33), '', False); end, TF('ERR_KULLANICI_ISIM_UZUN', [ISIM_EN_UZUN]));
  Kontrol('Reddedilen kullanici olusmadi', not ListedeVarMi(Bag, TEST_YASAK));

  { Sifre degistir: eski sifre baglanamaz, yeni baglanir }
  try
    SifreDegistir(Bag, TEST_KULLANICI, SIFRE_2, SIFRE_2);
    Kontrol('Sifre: eski sifre artik baglanamaz', not BaglanirMi(TEST_KULLANICI, SIFRE_1));
    Kontrol('Sifre: yeni sifre baglanir', BaglanirMi(TEST_KULLANICI, SIFRE_2));
  except
    on E: Exception do
      Kontrol('Sifre degistirirken hata: ' + HataMetni(E), False);
  end;
  KuralReddi('Sifre: bos reddedilir', procedure begin SifreDegistir(Bag, TEST_KULLANICI, '', ''); end, T('ERR_SIFRE_BOS'));
  KuralReddi('Sifre: farkli reddedilir', procedure begin SifreDegistir(Bag, TEST_KULLANICI, 'a', 'b'); end, T('ERR_SIFRE_FARKLI'));

  // Ozel karakterli sifre (tirnak, iki nokta, &, !, bosluk, suslu parantezler, ?)
  try
    SifreDegistir(Bag, TEST_KULLANICI, SIFRE_OZEL, SIFRE_OZEL);
    Kontrol('Ozel karakterli sifre (: & ! { } ? '' bosluk): ayarlandi ve baglanilir', BaglanirMi(TEST_KULLANICI, SIFRE_OZEL));
  except
    on E: Exception do
      Kontrol('Ozel karakterli sifre ayarlanamadi: ' + HataMetni(E), False);
  end;
  { Olcum: Turkce harfli sifre ayarlanir ama o sifreyle baglanilamaz; bu yuzden ASCII disi sifre reddedilir ve eski sifre kalir. }
  KuralReddi('Sifre: Turkce harfli sifre reddedilir (ASCII cumlesi)',
    procedure begin SifreDegistir(Bag, TEST_KULLANICI, SIFRE_TURKCE, SIFRE_TURKCE); end, T('ERR_SIFRE_ASCII'));
  KuralReddi('Ekle: Turkce harfli sifre reddedilir',
    procedure begin KullaniciEkle(Bag, TEST_YASAK, SIFRE_TURKCE, SIFRE_TURKCE, '', '', False); end, T('ERR_SIFRE_ASCII'));
  Kontrol('Reddedilen Turkce sifre eski sifreyi bozmadi', BaglanirMi(TEST_KULLANICI, SIFRE_OZEL));
  { Ozel karakterli ekleme }
  try
    KullaniciEkle(Bag, TEST_KULLANICI_B, SIFRE_OZEL, SIFRE_OZEL, 'O''Brien', 'a:b&c!d', False);
    Kontrol('Ekle: ozel karakterli sifre ve ad/soyad ile eklendi ve baglanilir', BaglanirMi(TEST_KULLANICI_B, SIFRE_OZEL));
    Kontrol('Ekle: ozel karakterli ad/soyad listede aynen',
      ListedeBul(Bag, TEST_KULLANICI_B, K) and (K.Isim = 'O''Brien') and (K.Soyad = 'a:b&c!d'));
  except
    on E: Exception do
      Kontrol('Ozel karakterli ekleme hatasi: ' + HataMetni(E), False);
  end;

  { Kendi sifresini degistir (baglanti kullanicisi = degistirilen kullanici) }
  BagKendi := BaglanDene(TEST_KULLANICI, SIFRE_OZEL, Hata);
  Kontrol('Kendi baglantisi acildi (' + TEST_KULLANICI + ')', BagKendi <> nil);
  if BagKendi <> nil then
  begin
    try
      try
        SifreDegistir(BagKendi, TEST_KULLANICI, SIFRE_3, SIFRE_3);
        Kontrol('Kendi sifre (' + IfThen(Yetenek.KendiSifreKomutu = skAlterCurrentUser, 'ALTER CURRENT USER', 'ALTER USER kendi_adi') +
          '): yeni sifre baglanir', BaglanirMi(TEST_KULLANICI, SIFRE_3));
        Kontrol('Kendi sifre: eski sifre baglanamaz', not BaglanirMi(TEST_KULLANICI, SIFRE_OZEL));
        Kontrol('Kendi sifre: baglantinin bellekteki sifresi guncellendi', BagKendi.Tanim.Sifre = SIFRE_3);
      except
        on E: Exception do
          Kontrol('Kendi sifresini degistirirken hata: ' + HataMetni(E), False);
      end;

      { Yonetici olmayan kullanici: kendi kendini silme/pasif yapma kuraldan reddedilir; baskasini eklemek/silmek sunucudan }
      KuralReddi('Kendini silemez (yonetici olmasa da kural reddeder)', procedure begin KullaniciSil(BagKendi, TEST_KULLANICI); end, T('ERR_KULLANICI_KENDINI'));
      if Yetenek.AktifPasif then
        KuralReddi('Kendini pasif yapamaz', procedure begin AktifAyarla(BagKendi, TEST_KULLANICI, False); end, T('ERR_KULLANICI_KENDINI'));
      Ham := SunucuReddi('Yonetici olmayan kullanici yeni kullanici ekleyemez (anlasilir cumle)',
        procedure begin KullaniciEkle(BagKendi, TEST_YASAK, 'x1234567', 'x1234567', '', '', False); end,
        T('ERR_KULLANICI_YONETIM_YETKI'));
      Kontrol('Yetkisiz ekleme kullanici olusturmadi', not ListedeVarMi(Bag, TEST_YASAK));
      SunucuReddi('Yonetici olmayan kullanici baskasinin sifresini degistiremez (SYSDBA)',
        procedure begin SifreDegistir(BagKendi, 'SYSDBA', 'x1234567', 'x1234567'); end,
        T('ERR_KULLANICI_YOK'));
      SunucuReddi('Yonetici olmayan kullanici baska kullaniciyi silemez (' + TEST_KULLANICI_B + ')',
        procedure begin KullaniciSil(BagKendi, TEST_KULLANICI_B); end, T('ERR_KULLANICI_YONETIM_YETKI'));
      Kontrol('Yetkisiz silme ' + TEST_KULLANICI_B + ' kullanicisini silmedi', ListedeVarMi(Bag, TEST_KULLANICI_B));
      if Yetenek.ListeSql then
      begin
        Kontrol('Yonetici olmayan kullanici listede yalniz kendini gorur',
          (Length(KullaniciListesiOku(BagKendi)) = 1) and (KullaniciListesiOku(BagKendi)[0].Ad = TEST_KULLANICI));
      end;
    finally
      FbBaglantiyiKes(BagKendi);
    end;
  end;

  { Ad/soyad }
  try
    AdSoyadDegistir(Bag, TEST_KULLANICI, 'Yeni', 'Soyad');
    Kontrol('Ad/soyad degisti', ListedeBul(Bag, TEST_KULLANICI, K) and (K.Isim = 'Yeni') and (K.Soyad = 'Soyad'));
  except
    on E: Exception do
      Kontrol('Ad/soyad hatasi: ' + HataMetni(E), False);
  end;

  { Yonetici yap / kaldir (3.0+) }
  if Yetenek.YoneticiAyarlanir then
  begin
    try
      YoneticiAyarla(Bag, TEST_KULLANICI, True);
      Kontrol('Yonetici yapildi', ListedeBul(Bag, TEST_KULLANICI, K) and K.Yonetici);
      { Yonetici baglantisiyla yeni kullanici eklenir ve SYSDBA olmadan silinir. 3.0.14'te SYSDBA olmayan yonetici
        kullanici yonetebilmek icin ROLE RDB$ADMIN ile baglanmali (olcum); bu yuzden rolle baglanilir. }
      { Moderator isql ile dogruladi (3.0.14): ALTER USER..GRANT ADMIN ROLE yetmez; kullanici yonetimini yaptigi
        VERITABANINDA ayrica GRANT RDB$ADMIN verilmeli ve ROLE RDB$ADMIN ile baglanilmali. Uygulama kodu bunu yapmaz
        (SYSDBA ile kullanilir); yalniz test, SYSDBA olmayan yonetici yolunu dener. }
      KomutHazirla(Bag, 'GRANT RDB$ADMIN TO ' + TEST_KULLANICI).ExecSQL;
      BagAdmin := BaglanRolle(TEST_KULLANICI, SIFRE_3, Hata);
      Kontrol('Yonetici olarak (RDB$ADMIN rolu ile) baglandi', BagAdmin <> nil);
      if BagAdmin = nil then
        Not_(Hata);
      if BagAdmin <> nil then
      begin
        try
          try
            KullaniciEkle(BagAdmin, TEST_KULLANICI_C, SIFRE_1, SIFRE_1, '', '', False);
            Kontrol('Yonetici (SYSDBA degil) yeni kullanici ekleyebilir', ListedeVarMi(BagAdmin, TEST_KULLANICI_C));
            Kontrol('Yonetici tum kullanicilari listede gorur', Length(KullaniciListesiOku(BagAdmin)) >= 3);
            KullaniciSil(BagAdmin, TEST_KULLANICI_C);
            Kontrol('Yonetici kullanici silebilir', not ListedeVarMi(BagAdmin, TEST_KULLANICI_C));
            KuralReddi('Yonetici kendini silemez', procedure begin KullaniciSil(BagAdmin, TEST_KULLANICI); end, T('ERR_KULLANICI_KENDINI'));
            KuralReddi('SYSDBA yonetici baglantisindan da silinemez', procedure begin KullaniciSil(BagAdmin, 'SYSDBA'); end, T('ERR_KULLANICI_SYSDBA'));
          except
            on E: Exception do
              Kontrol('Yonetici islemleri hatasi: ' + HataMetni(E), False);
          end;
        finally
          BagAdmin.Free;
        end;
      end;
      try
        KomutHazirla(Bag, 'REVOKE RDB$ADMIN FROM ' + TEST_KULLANICI).ExecSQL;
      except
      end;
      YoneticiAyarla(Bag, TEST_KULLANICI, False);
      Kontrol('Yonetici kaldirildi', ListedeBul(Bag, TEST_KULLANICI, K) and not K.Yonetici);
    except
      on E: Exception do
        Kontrol('Yonetici yap/kaldir hatasi: ' + HataMetni(E), False);
    end;
    { Ekleme sirasinda yonetici kutusu }
    try
      Temizle(Bag);
      KullaniciEkle(Bag, TEST_KULLANICI_B, SIFRE_1, SIFRE_1, '', '', True);
      Kontrol('Ekle (yonetici kutusu isaretli): yonetici olarak eklendi', ListedeBul(Bag, TEST_KULLANICI_B, K) and K.Yonetici);
    except
      on E: Exception do
        Kontrol('Yonetici olarak ekleme hatasi: ' + HataMetni(E), False);
    end;
  end
  else
  begin
    KuralReddi('Yonetici yap (2.5): arayuzde yok, kod da reddeder', procedure begin YoneticiAyarla(Bag, TEST_KULLANICI, True); end, T('ERR_KULLANICI_OZELLIK_YOK'));
    KuralReddi('Ekle yonetici kutusu (2.5): reddedilir', procedure begin KullaniciEkle(Bag, TEST_YASAK, 'a', 'a', '', '', True); end, T('ERR_KULLANICI_OZELLIK_YOK'));
  end;

  { Pasif / aktif (3.0+) }
  if Yetenek.AktifPasif then
  begin
    try
      Temizle(Bag);
      KullaniciEkle(Bag, TEST_KULLANICI, SIFRE_1, SIFRE_1, '', '', False);
      AktifAyarla(Bag, TEST_KULLANICI, False);
      Kontrol('Pasif yapildi: listede aktif degil', ListedeBul(Bag, TEST_KULLANICI, K) and not K.Aktif);
      Kontrol('Pasif kullanici baglanamaz', not BaglanirMi(TEST_KULLANICI, SIFRE_1));
      AktifAyarla(Bag, TEST_KULLANICI, True);
      Kontrol('Aktif yapildi: baglanir', BaglanirMi(TEST_KULLANICI, SIFRE_1));
    except
      on E: Exception do
        Kontrol('Aktif/pasif hatasi: ' + HataMetni(E), False);
    end;
  end
  else
    KuralReddi('Pasif yap (2.5): kod reddeder', procedure begin AktifAyarla(Bag, TEST_KULLANICI, False); end, T('ERR_KULLANICI_OZELLIK_YOK'));

  { Sil -> listeden gider }
  try
    KullaniciSil(Bag, TEST_KULLANICI);
    Kontrol('Sil: listeden gitti', not ListedeVarMi(Bag, TEST_KULLANICI));
    Kontrol('Sil: silinen kullanici baglanamaz', not BaglanirMi(TEST_KULLANICI, SIFRE_1));
  except
    on E: Exception do
      Kontrol('Silme hatasi: ' + HataMetni(E), False);
  end;
  SunucuReddi('Olmayan kullaniciyi silme hatasi (sunucunun gercek hatasi, ceviri icin)',
    procedure begin KullaniciSil(Bag, TEST_KULLANICI); end, '');

  { SYSDBA korumasi: silme, pasif, yonetici, ad/soyad kuraldan reddedilir; sifre degisebilir (ayni sifreyle) }
  KuralReddi('SYSDBA silinemez', procedure begin KullaniciSil(Bag, 'SYSDBA'); end, T('ERR_KULLANICI_SYSDBA'));
  KuralReddi('SYSDBA (kucuk harfle) silinemez', procedure begin KullaniciSil(Bag, 'sysdba'); end, T('ERR_KULLANICI_SYSDBA'));
  KuralReddi('SYSDBA pasif yapilamaz', procedure begin AktifAyarla(Bag, 'SYSDBA', False); end, T('ERR_KULLANICI_SYSDBA'));
  KuralReddi('SYSDBA yonetici bayragi degistirilemez', procedure begin YoneticiAyarla(Bag, 'SYSDBA', False); end, T('ERR_KULLANICI_SYSDBA'));
  KuralReddi('SYSDBA ad/soyad degistirilemez', procedure begin AdSoyadDegistir(Bag, 'SYSDBA', 'a', 'b'); end, T('ERR_KULLANICI_SYSDBA'));
  Kontrol('SYSDBA hala listede', ListedeVarMi(Bag, 'SYSDBA') or not SysdbaMi(Bag.Tanim.Kullanici));
  if SysdbaMi(Bag.Tanim.Kullanici) then
  begin
    try
      SifreDegistir(Bag, 'SYSDBA', Bag.Tanim.Sifre, Bag.Tanim.Sifre);
      Kontrol('SYSDBA: sifre degistirilebilir (ayni sifre yeniden verildi, degismedi)', BaglanirMi('SYSDBA', Bag.Tanim.Sifre));
    except
      on E: Exception do
        Kontrol('SYSDBA sifre islemi hatasi: ' + HataMetni(E), False);
    end;
  end;

  Temizle(Bag);
  Kontrol('Temizlik: test kullanicilari kalmadi',
    not (ListedeVarMi(Bag, TEST_KULLANICI) or ListedeVarMi(Bag, TEST_KULLANICI_B) or ListedeVarMi(Bag, TEST_KULLANICI_C) or ListedeVarMi(Bag, TEST_YASAK)));
end;

{ ---------- Ana akis ---------- }

var
  YazmaIstendi, YazmaIzni, KendiVeritabanim: Boolean;
  Neden, Klasor: string;
begin
  Cikti := TStringList.Create;
  Bag := nil;
  KendiVeritabanim := False;
  try
    try
      DilYukle('tr');
      Tanim.Ad := 'kullanici_test';
      Tanim.Sunucu := Ortam('FBTEST_SUNUCU', '');
      Tanim.Port := StrToInt(Ortam('FBTEST_PORT', '3050'));
      Tanim.VeritabaniYolu := Ortam('FBTEST_YOL', '');
      Tanim.Kullanici := Ortam('FBTEST_KULLANICI', 'SYSDBA');
      Tanim.Sifre := Ortam('FBTEST_SIFRE', '');
      { Gomulu kip sifreyi dogrulamaz ama bos sifre baglanmayi reddeder: bos ise sahte bir deger verilir. }
      if (Tanim.Sunucu = '') and (Tanim.Sifre = '') then
        Tanim.Sifre := 'masterkey';
      Tanim.KarakterSeti := VARSAYILAN_KARAKTER_SETI;
      Gomulu := Tanim.Sunucu = '';
      YazmaIstendi := Ortam('FBTEST_YAZMA', '') = '1';

      if Gomulu and (Tanim.VeritabaniYolu = '') then
      begin
        Klasor := TPath.Combine(GetEnvironmentVariable('TEMP'), 'kullanicitest');
        ForceDirectories(Klasor);
        Tanim.VeritabaniYolu := TPath.Combine(Klasor, 'test_' + FormatDateTime('yyyymmdd_hhnnss', Now) + '.fdb');
        GeciciVeritabaniOlustur(Tanim);
        KendiVeritabanim := True;
      end;
      if Tanim.VeritabaniYolu = '' then
        raise Exception.Create('FBTEST_YOL bos: sunucudaki var olan bir veritabani yolu verin.');

      { Yazma izni kod seviyesinde: yalniz yerel sunucuda ve 3052, 3053, 3054 portlarinda. }
      YazmaIzni := False;
      Neden := '';
      if Gomulu then
        Neden := 'gomulu kipte kullanici yonetimi yok (yazma bolumu sunucu ister)'
      else if not YazmaIstendi then
        Neden := 'FBTEST_YAZMA=1 verilmedi (varsayilan: yalniz okuma)'
      else if not YerelSunucuMu(Tanim.Sunucu) then
        Neden := 'yazma yalniz yerel (127.0.0.1/localhost) test sunucusunda serbest'
      else if (Tanim.Port = 3052) or (Tanim.Port = 3053) or (Tanim.Port = 3054) then
        YazmaIzni := True
      else
        Neden := 'port ' + IntToStr(Tanim.Port) + ': yazma YALNIZ 3052, 3053 ve 3054 portunda serbest (3050/3051 gercek veri icerir)';

      Cikti.Add('KullaniciTest  ' + FormatDateTime('yyyy-mm-dd hh:nn:ss', Now));
      Cikti.Add('Sunucu: ' + IfThen(Gomulu, '(gomulu)', Tanim.Sunucu + ':' + IntToStr(Tanim.Port)));
      Cikti.Add('Veritabani: ' + Tanim.VeritabaniYolu + IfThen(KendiVeritabanim, '  (gecici, program acti)', ''));
      Cikti.Add('Kullanici: ' + Tanim.Kullanici + '  (sifre yazilmaz)');
      Cikti.Add('Yazma bolumu: ' + IfThen(YazmaIzni, 'ACIK', 'KAPALI - ' + Neden));

      Bag := FbBaglan(Tanim);
      Cikti.Add('Surum: ' + Bag.Surum);

      KurallarBolumu;
      if Gomulu then
        GomuluBolumu
      else
      begin
        SunucuOkumaBolumu;
        if YazmaIzni then
          SunucuYazmaBolumu;
      end;
    except
      on E: Exception do
      begin
        Cikti.Add('');
        Cikti.Add('HATA (beklenmeyen): ' + E.ClassName + ': ' + TekSatir(E.Message));
        Inc(Hatalar);
      end;
    end;
    { Yazma acikken yarim kalan test kullanicilari }
    if (Bag <> nil) and not Gomulu and YazmaIzni then
      Temizle(Bag);
    Cikti.Add('');
    Cikti.Add('Kontrol: ' + IntToStr(KontrolSayisi) + '  Hata: ' + IntToStr(Hatalar));
    Cikti.SaveToFile(Ortam('FBTEST_CIKTI', 'kullanicitest.txt'), TEncoding.UTF8);
  finally
    Cikti.Free;
  end;
  ExitCode := Hatalar;
end.
