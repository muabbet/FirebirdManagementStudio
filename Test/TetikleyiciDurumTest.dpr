program TetikleyiciDurumTest;

{ Tetikleyiciyi aktif / pasif yapma testi (uTetikleyiciDurum): durum okuma, pasifken trigger calismaz, aktifken calisir,
  kucuk harfli tirnakli ad, olmayan trigger, yetkisiz kullanici, dil anahtarlari.
  Gercek veriye dokunulmaz: kendi gecici veritabanini kurar, dosya silinmez.
  Ortam: FBTEST_SUNUCU (bos = yerel), FBTEST_PORT, FBTEST_KLASOR, FBTEST_KULLANICI, FBTEST_SIFRE, FBTEST_CIKTI.
  Cikis kodu: hata sayisi. }

{$APPTYPE CONSOLE}

uses
  System.SysUtils, System.Classes, System.IOUtils, System.StrUtils, Data.DB,
  FireDAC.Stan.Intf, FireDAC.Stan.Option, FireDAC.Stan.Error, FireDAC.Comp.Client, FireDAC.Phys.FB,
  FireDAC.ConsoleUI.Wait,
  uDil, uBaglanti, uSorgu, uMetadata, uProsedur, uTetikleyiciDurum;

var
  Cikti: TStringList;
  Hatalar, KontrolSayisi: Integer;
  Bag: TAcikBaglanti;
  Tanim: TBaglantiTanimi;

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

procedure Calistir(const Sql: string);
begin
  SorguCalistir(Bag, Sql).Free;
end;

{ Trigger metni (govdeli) icin: tek acik islemde calisir. }
procedure TetikKur(const Metin: string);
var
  S: TProsedurSonucu;
begin
  S := Default(TProsedurSonucu);
  MetniCalistir(Bag, 'SET TERM ^ ;' + sLineBreak + Metin + '^' + sLineBreak + 'SET TERM ; ^', S);
  Kontrol('trigger kuruldu: ' + Copy(Metin, 1, 40) + ' ' + S.Cumle, S.Basarili);
end;

function AktifMi(const Ad: string): Boolean;
var
  Simdiki: Boolean;
begin
  Result := TetikleyiciDurumuOku(Bag, Ad, Simdiki) and Simdiki;
end;

function ListedeAktifMi(const Ad: string): Boolean;
var
  Tetik: TTetikleyiciBilgisi;
begin
  Result := False;
  for Tetik in TetikleyicileriListele(Bag) do
    if Tetik.Ad = Ad then
      Result := Tetik.Aktif;
end;

procedure Dene;
var
  S: TProsedurSonucu;
  Aktif: Boolean;
  Komut: string;
begin
  Calistir('CREATE TABLE T_TD (ID INTEGER, AD VARCHAR(20), DOLDUR VARCHAR(10))');
  TetikKur('CREATE TRIGGER TR_TD_BI FOR T_TD ACTIVE BEFORE INSERT POSITION 0 AS BEGIN NEW.DOLDUR = ''TRG''; END');
  TetikKur('CREATE TRIGGER "tr_kucuk_bi" FOR T_TD ACTIVE BEFORE INSERT POSITION 1 AS BEGIN NEW.AD = ''kucuk''; END');

  { durum okuma }
  Kontrol('okuma: TR_TD_BI var ve aktif', TetikleyiciDurumuOku(Bag, 'TR_TD_BI', Aktif) and Aktif);
  Kontrol('okuma: olmayan trigger yok doner', not TetikleyiciDurumuOku(Bag, 'YOK_BOYLE', Aktif));

  { komut ve onay metni }
  Komut := TetikleyiciDurumKomutu(Bag, 'TR_TD_BI', False);
  Cikti.Add('Komut pasif: ' + Komut);
  Kontrol('komut: ALTER TRIGGER ... INACTIVE', (Pos('ALTER TRIGGER', Komut) = 1) and (Pos('INACTIVE', Komut) > 0));
  Komut := TetikleyiciDurumKomutu(Bag, 'tr_kucuk_bi', True);
  Cikti.Add('Komut aktif (kucuk harf): ' + Komut);
  Kontrol('komut: kucuk harfli ad tirnakli', (Pos('"tr_kucuk_bi"', Komut) > 0) and (Pos('ACTIVE', Komut) > 0) and (Pos('INACTIVE', Komut) = 0));
  Kontrol('onay metni pasif: ad ve komut var', (Pos('TR_TD_BI', TetikleyiciDurumOnayMetni(Bag, 'TR_TD_BI', False)) > 0) and
    (Pos('INACTIVE', TetikleyiciDurumOnayMetni(Bag, 'TR_TD_BI', False)) > 0));
  Kontrol('onay metni aktif: ad ve komut var', (Pos('TR_TD_BI', TetikleyiciDurumOnayMetni(Bag, 'TR_TD_BI', True)) > 0) and
    (Pos('ACTIVE', TetikleyiciDurumOnayMetni(Bag, 'TR_TD_BI', True)) > 0));

  { aktifken calisir }
  Calistir('INSERT INTO T_TD (ID) VALUES (1)');
  Kontrol('aktif: trigger kolonlari doldurdu', KayitSayisi(Bag, 'T_TD', '"ID" = 1 AND "DOLDUR" = ''TRG'' AND "AD" = ''kucuk''') = 1);

  { pasife al }
  S := TetikleyiciDurumAyarla(Bag, 'TR_TD_BI', False);
  Cikti.Add('Pasif: basarili=' + BoolToStr(S.Basarili, True) + ' cumle=' + S.Cumle);
  Kontrol('pasif: basarili, komut gorunur (SQL karsiligi)', S.Basarili and (Length(S.Komutlar) = 1) and (Pos('INACTIVE', S.Komutlar[0]) > 0));
  Kontrol('pasif: durum okunur', not AktifMi('TR_TD_BI'));
  Kontrol('pasif: agac listesinde de pasif', not ListedeAktifMi('TR_TD_BI'));
  Kontrol('pasif: diger trigger aktif kaldi', AktifMi('tr_kucuk_bi'));
  Calistir('INSERT INTO T_TD (ID) VALUES (2)');
  Kontrol('pasifken trigger calismadi (DOLDUR bos), digeri calisti', KayitSayisi(Bag, 'T_TD', '"ID" = 2 AND "DOLDUR" IS NULL AND "AD" = ''kucuk''') = 1);

  { zaten pasifken tekrar pasif: sorunsuz }
  S := TetikleyiciDurumAyarla(Bag, 'TR_TD_BI', False);
  Kontrol('pasif iken tekrar pasif: hata vermez', S.Basarili and (not AktifMi('TR_TD_BI')));

  { aktife al }
  S := TetikleyiciDurumAyarla(Bag, 'TR_TD_BI', True);
  Kontrol('aktif: basarili, komut ACTIVE', S.Basarili and (Length(S.Komutlar) = 1) and (Pos('INACTIVE', S.Komutlar[0]) = 0) and
    (Pos('ACTIVE', S.Komutlar[0]) > 0));
  Kontrol('aktif: durum okunur ve listede aktif', AktifMi('TR_TD_BI') and ListedeAktifMi('TR_TD_BI'));
  Calistir('INSERT INTO T_TD (ID) VALUES (3)');
  Kontrol('aktife alinca trigger yine calisir', KayitSayisi(Bag, 'T_TD', '"ID" = 3 AND "DOLDUR" = ''TRG''') = 1);
  Kontrol('veriye dokunulmadi (3 kayit)', KayitSayisi(Bag, 'T_TD', '') = 3);

  { kucuk harfli tirnakli ad }
  S := TetikleyiciDurumAyarla(Bag, 'tr_kucuk_bi', False);
  Cikti.Add('Kucuk harf pasif: basarili=' + BoolToStr(S.Basarili, True) + ' cumle=' + S.Cumle);
  Kontrol('kucuk harfli ad: pasif yapildi', S.Basarili and (not AktifMi('tr_kucuk_bi')));
  Calistir('INSERT INTO T_TD (ID) VALUES (4)');
  Kontrol('kucuk harfli ad: pasifken calismadi', KayitSayisi(Bag, 'T_TD', '"ID" = 4 AND "AD" IS NULL AND "DOLDUR" = ''TRG''') = 1);
  S := TetikleyiciDurumAyarla(Bag, 'tr_kucuk_bi', True);
  Kontrol('kucuk harfli ad: aktif yapildi', S.Basarili and AktifMi('tr_kucuk_bi'));

  { olmayan trigger }
  S := TetikleyiciDurumAyarla(Bag, 'YOK_BOYLE', False);
  Cikti.Add('Olmayan: cumle=' + S.Cumle);
  Kontrol('olmayan trigger: basarisiz, anlasilir cumle, SQL calismadi',
    (not S.Basarili) and (S.Cumle = TF('TETIK_ERR_YOK', ['YOK_BOYLE'])) and (Length(S.Komutlar) = 0));
  { ad buyuk/kucuk harfe duyarli: tr_td_bi ile TR_TD_BI ayni trigger degil }
  S := TetikleyiciDurumAyarla(Bag, 'tr_td_bi', False);
  Kontrol('ad buyuk/kucuk harfe duyarli (tr_td_bi yok sayilir)', (not S.Basarili) and AktifMi('TR_TD_BI'));
end;

{ Tablo sahibi olmayan, yalniz yazma yetkisi olan kullanici: ALTER TRIGGER yetkisi yok. Yalniz sunucuda 3.0+ (CREATE USER). }
procedure YetkisizDene;
var
  Kisitli: TAcikBaglanti;
  KTanim: TBaglantiTanimi;
  S: TProsedurSonucu;
begin
  if (Tanim.Sunucu = '') or (Bag.Surum < '3') then
  begin
    Cikti.Add('Yetkisiz kullanici denemesi atlandi (yerel/gomulu ya da 2.5)');
    Exit;
  end;
  Calistir('CREATE USER TETIK_YETKISIZ PASSWORD ''tetik1234x''');
  try
    Calistir('GRANT SELECT, INSERT, UPDATE, DELETE ON T_TD TO TETIK_YETKISIZ');
    KTanim := Tanim;
    KTanim.Ad := 'tetik_yetkisiz';
    KTanim.Kullanici := 'TETIK_YETKISIZ';
    KTanim.Sifre := 'tetik1234x';
    Kisitli := FbBaglan(KTanim);
    try
      S := TetikleyiciDurumAyarla(Kisitli, 'TR_TD_BI', False);
      Cikti.Add('Yetkisiz: cumle=' + S.Cumle + ' | ham: ' + StringReplace(Copy(S.Ayrinti, 1, 200), sLineBreak, ' ', [rfReplaceAll]));
      Kontrol('yetkisiz kullanici: basarisiz, anlasilir cumle (ERR_YETKI_YOK), ham mesaj Ayrinti''da',
        (not S.Basarili) and (S.Cumle = T('ERR_YETKI_YOK')) and (S.Ayrinti <> ''));
      Kontrol('yetkisiz kullanici: trigger aktif kaldi', AktifMi('TR_TD_BI'));
    finally
      FbBaglantiyiKes(Kisitli);
    end;
  finally
    Calistir('DROP USER TETIK_YETKISIZ');
  end;
end;

procedure DilAnahtarTesti;
const
  Anahtarlar: array[0..9] of string = ('TETIK_MENU_PASIF', 'TETIK_MENU_AKTIF', 'TETIK_ONAY_PASIF', 'TETIK_ONAY_AKTIF',
    'TETIK_MSG_PASIF', 'TETIK_MSG_AKTIF', 'TETIK_MSG_VAZGECILDI', 'TETIK_MSG_GERI_ALINDI', 'TETIK_ERR_YOK', 'TETIK_ERR_YAPILAMADI');
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
    Kontrol('dil ' + Dil + ': anahtarlar tam' + IfThen(Eksik <> '', ' (eksik:' + Eksik + ')'), Eksik = '');
    Kontrol('dil ' + Dil + ': bicimli mesajlar ad ve komutu icerir',
      (Pos('ALTER TRIGGER', TF('TETIK_ONAY_PASIF', ['TR_X', 'ALTER TRIGGER'])) > 0) and (Pos('TR_X', TF('TETIK_ONAY_PASIF', ['TR_X', 'ALTER TRIGGER'])) > 0) and
      (Pos('ALTER TRIGGER', TF('TETIK_ONAY_AKTIF', ['TR_X', 'ALTER TRIGGER'])) > 0) and (Pos('TR_X', TF('TETIK_MSG_PASIF', ['TR_X'])) > 0) and
      (Pos('TR_X', TF('TETIK_MSG_AKTIF', ['TR_X'])) > 0) and (Pos('TR_X', TF('TETIK_ERR_YOK', ['TR_X'])) > 0) and
      (Pos('TR_X', TF('TETIK_ERR_YAPILAMADI', ['TR_X'])) > 0));
  end;
  DilYukle('tr');
end;

var
  Klasor, Yol, CiktiYolu: string;
begin
  Cikti := TStringList.Create;
  Hatalar := 0;
  KontrolSayisi := 0;
  Bag := nil;
  try
    try
      DilYukle('tr');
      Klasor := Ortam('FBTEST_KLASOR', TPath.Combine(GetEnvironmentVariable('TEMP'), 'tetikdurumtest'));
      if Ortam('FBTEST_SUNUCU', '') = '' then
        ForceDirectories(Klasor);
      Yol := IncludeTrailingPathDelimiter(Klasor) + 'tetikdurum_' + FormatDateTime('yyyymmdd_hhnnss', Now) + '.fdb';
      Tanim := Default(TBaglantiTanimi);
      Tanim.Ad := 'tetikdurumtest';
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
      YetkisizDene;
      DilAnahtarTesti;
    except
      on E: Exception do
      begin
        Cikti.Add('BEKLENMEYEN HATA: ' + E.ClassName + ': ' + E.Message);
        Inc(Hatalar);
      end;
    end;
  finally
    if Bag <> nil then
      FbBaglantiyiKes(Bag);
  end;
  Cikti.Add('Kontrol sayisi: ' + IntToStr(KontrolSayisi) + ', Hata sayisi: ' + IntToStr(Hatalar));
  CiktiYolu := Ortam('FBTEST_CIKTI', '');
  if CiktiYolu <> '' then
    Cikti.SaveToFile(CiktiYolu, TEncoding.UTF8)
  else
    Writeln(Cikti.Text);
  Cikti.Free;
  ExitCode := Hatalar;
end.
