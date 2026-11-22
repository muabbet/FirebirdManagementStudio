program OzellikTest;

{ Veritabani ozellikleri testi (uVeritabaniOzellik): okuma (sayfa boyutu, ODS, dialect, karakter seti, sweep, forced writes,
  yer ayirma, salt okunur), sweep araligi / forced writes / yer ayirma degistirme AYNI baglanti acikken, degisikligin
  gecici yeni baglantiyla gorunmesi, geri alma, gecersiz deger, yanlis sifre, veriye dokunulmadigi.
  Gercek veriye dokunulmaz: kendi gecici veritabanini kurar, dosya silinmez.
  Ortam: FBTEST_SUNUCU (bos = yerel), FBTEST_PORT, FBTEST_KLASOR, FBTEST_KULLANICI, FBTEST_SIFRE, FBTEST_CIKTI.
  Cikis kodu: hata sayisi. }

{$APPTYPE CONSOLE}

uses
  System.SysUtils, System.Classes, System.IOUtils, Data.DB,
  FireDAC.Stan.Intf, FireDAC.Stan.Option, FireDAC.Stan.Error, FireDAC.Comp.Client, FireDAC.Phys.FB,
  FireDAC.ConsoleUI.Wait,
  uDil, uBaglanti, uSorgu, uVeritabaniOzellik;

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

procedure Dene;
var
  O: TVeritabaniOzellikleri;
  S: TOzellikSonucu;
  Bozuk: TAcikBaglanti;
begin
  SorguCalistir(Bag, 'CREATE TABLE T_OZ (ID INTEGER NOT NULL PRIMARY KEY, AD VARCHAR(20))').Free;
  SorguCalistir(Bag, 'INSERT INTO T_OZ VALUES (1, ''a'')').Free;

  Kontrol('gfix.exe bulundu', GfixVarMi);
  O := OzellikleriOku(Bag);
  Cikti.Add(Format('Okunan: ods=%s sayfa=%d sayfaSayisi=%d dialect=%d karakter=%s sweep=%d zorla=%s yer=%s salt=%s',
    [O.Ods, O.SayfaBoyutu, O.SayfaSayisi, O.Dialect, O.KarakterSeti, O.SweepAraligi, BoolToStr(O.ZorlaYaz, True),
     BoolToStr(O.YerAyir, True), BoolToStr(O.SaltOkunur, True)]));
  Kontrol('Okunabildi', not O.Okunamadi);
  Kontrol('Sayfa boyutu 8192, dialect 3, ODS dolu', (O.SayfaBoyutu = 8192) and (O.Dialect = 3) and (O.Ods <> ''));
  Kontrol('Karakter seti dolu', O.KarakterSeti <> '');
  Kontrol('Varsayilanlar: sweep 20000, forced writes acik, yer ayir acik, salt okunur degil',
    (O.SweepAraligi = 20000) and O.ZorlaYaz and O.YerAyir and not O.SaltOkunur);
  Kontrol('Sayfa sayisi 0 degil', O.SayfaSayisi > 0);

  S := SweepAraliginiAyarla(Bag, 30000);
  Cikti.Add('Sweep: ' + S.Komut + ' | ' + S.Cumle + ' | ' + Trim(S.Ham));
  Kontrol('Sweep araligi degisti (baglanti acikken)', S.Basarili and (S.Komut = 'gfix -h 30000'));
  Kontrol('Yeni deger gecici baglantiyla gorunuyor', OzellikleriOku(Bag).SweepAraligi = 30000);

  S := SweepAraliginiAyarla(Bag, 0);
  Kontrol('Sweep 0 (kapali) yapilabilir', S.Basarili and (OzellikleriOku(Bag).SweepAraligi = 0));

  S := ZorlaYaziAyarla(Bag, False);
  Kontrol('Forced writes kapandi', S.Basarili and (S.Komut = 'gfix -w async') and not OzellikleriOku(Bag).ZorlaYaz);
  S := ZorlaYaziAyarla(Bag, True);
  Kontrol('Forced writes acildi', S.Basarili and (S.Komut = 'gfix -w sync') and OzellikleriOku(Bag).ZorlaYaz);

  S := YerAyirmayiAyarla(Bag, False);
  Kontrol('Yer ayirma kapandi (full)', S.Basarili and (S.Komut = 'gfix -use full') and not OzellikleriOku(Bag).YerAyir);
  S := YerAyirmayiAyarla(Bag, True);
  Kontrol('Yer ayirma acildi (reserve)', S.Basarili and (S.Komut = 'gfix -use reserve') and OzellikleriOku(Bag).YerAyir);

  { Geri al: ilk degerler }
  SweepAraliginiAyarla(Bag, 20000);
  O := OzellikleriOku(Bag);
  Kontrol('Ilk degerlere donuldu', (O.SweepAraligi = 20000) and O.ZorlaYaz and O.YerAyir);

  S := SweepAraliginiAyarla(Bag, -5);
  Kontrol('Negatif sweep reddedilir, cumle dolu', (not S.Basarili) and (S.Cumle <> ''));

  { Yanlis sifre: hata, anlasilir cumle, ayar degismez }
  Bozuk := TAcikBaglanti.Create;
  try
    Bozuk.Tanim := Bag.Tanim;
    Bozuk.Tanim.Sifre := 'yanlis_sifre_xyz';
    S := SweepAraliginiAyarla(Bozuk, 12345);
    Cikti.Add('Yanlis sifre: cumle=' + S.Cumle + ' ham=' + Trim(S.Ham));
  finally
    Bozuk.Free;
  end;
  Kontrol('Yanlis sifrede basarisiz, anlasilir cumle', (not S.Basarili) and (S.Cumle <> ''));
  Kontrol('Yanlis sifrede ayar degismedi', OzellikleriOku(Bag).SweepAraligi = 20000);

  Kontrol('Veriye dokunulmadi', KayitSayisi(Bag, 'T_OZ', '') = 1);
end;

var
  Tanim: TBaglantiTanimi;
  Klasor, Yol, CiktiYolu: string;
begin
  Cikti := TStringList.Create;
  Hatalar := 0;
  Bag := nil;
  try
    try
      DilYukle('tr');
      Klasor := Ortam('FBTEST_KLASOR', TPath.Combine(GetEnvironmentVariable('TEMP'), 'ozelliktest'));
      if Ortam('FBTEST_SUNUCU', '') = '' then
        ForceDirectories(Klasor);
      Yol := IncludeTrailingPathDelimiter(Klasor) + 'oz_' + FormatDateTime('yyyymmdd_hhnnss', Now) + '.fdb';
      Tanim := Default(TBaglantiTanimi);
      Tanim.Ad := 'ozellik';
      Tanim.Sunucu := Ortam('FBTEST_SUNUCU', '');
      Tanim.Port := StrToInt(Ortam('FBTEST_PORT', '3050'));
      Tanim.VeritabaniYolu := Yol;
      Tanim.Kullanici := Ortam('FBTEST_KULLANICI', 'SYSDBA');
      Tanim.Sifre := Ortam('FBTEST_SIFRE', '');
      Tanim.KarakterSeti := VARSAYILAN_KARAKTER_SETI;
      FbVeritabaniOlustur(Tanim);
      Bag := FbBaglan(Tanim);
      Cikti.Add('Gecici veritabani: ' + Yol + ' | Surum: ' + Bag.Surum);
      Dene;
    except
      on E: Exception do
      begin
        Cikti.Add('BEKLENMEYEN HATA: ' + E.Message);
        Inc(Hatalar);
      end;
    end;
  finally
    if Bag <> nil then
      FbBaglantiyiKes(Bag);
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
