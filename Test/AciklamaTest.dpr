program AciklamaTest;

{ Tablo ve kolon aciklamasi (COMMENT ON) yazma/okuma testi (uAciklama): yaz, oku, Turkce harf, tek tirnak, noktali virgul,
  cok satirli metin, bos metinle kaldirma, kolon tablosunda ACIKLAMA, kucuk harfli tirnakli ad, olmayan tablo.
  Gercek veriye dokunulmaz: kendi gecici veritabanini kurar, dosya silinmez.
  Ortam: FBTEST_SUNUCU (bos = yerel), FBTEST_PORT, FBTEST_KLASOR, FBTEST_KULLANICI, FBTEST_SIFRE, FBTEST_CIKTI.
  Cikis kodu: hata sayisi. }

{$APPTYPE CONSOLE}

uses
  System.SysUtils, System.Classes, System.IOUtils, Data.DB,
  FireDAC.Stan.Intf, FireDAC.Stan.Option, FireDAC.Stan.Error, FireDAC.Comp.Client, FireDAC.Phys.FB,
  FireDAC.ConsoleUI.Wait,
  uDil, uBaglanti, uSorgu, uMetadata, uProsedur, uAciklama;

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

procedure Calistir(const Sql: string);
begin
  SorguCalistir(Bag, Sql).Free;
end;

procedure Dene;
var
  S: TProsedurSonucu;
  Kolonlar: TFDMemTable;
  Metin: string;
begin
  Calistir('CREATE TABLE T_ACK (ID INTEGER NOT NULL PRIMARY KEY, AD VARCHAR(20))');
  Calistir('INSERT INTO T_ACK VALUES (1, ''a'')');
  Kontrol('Baslangicta aciklama yok', (TabloAciklamasiOku(Bag, 'T_ACK') = '') and (KolonAciklamasiOku(Bag, 'T_ACK', 'AD') = ''));

  S := AciklamaYaz(Bag, 'T_ACK', '', 'M'#$FC''#$15F'teri kart'#$131'');
  Cikti.Add('Tablo aciklama: basarili=' + BoolToStr(S.Basarili, True) + ' cumle=' + S.Cumle + ' ham=' + Copy(S.Ayrinti, 1, 200));
  Kontrol('Tablo aciklamasi yazildi', S.Basarili);
  Kontrol('Tablo aciklamasi okunur (Turkce harf dogru)', TabloAciklamasiOku(Bag, 'T_ACK') = 'M'#$FC''#$15F'teri kart'#$131'');
  Kontrol('Calisan komut SQL karsiligi olarak donuyor', (Length(S.Komutlar) = 1) and (Pos('COMMENT ON TABLE', S.Komutlar[0]) = 1));

  Metin := 'Ad'#$131': ''k'#$131'sa'' ad; ikinci c'#$FC'mle';
  S := AciklamaYaz(Bag, 'T_ACK', 'AD', Metin);
  Kontrol('Kolon aciklamasi (tek tirnak ve noktali virgul) yazildi', S.Basarili);
  Kontrol('Kolon aciklamasi aynen okunur', KolonAciklamasiOku(Bag, 'T_ACK', 'AD') = Metin);
  Kontrol('Kolon komutu COMMENT ON COLUMN', (Length(S.Komutlar) = 1) and (Pos('COMMENT ON COLUMN', S.Komutlar[0]) = 1));
  Kontrol('Tablo aciklamasi kolonla karismadi', TabloAciklamasiOku(Bag, 'T_ACK') = 'M'#$FC''#$15F'teri kart'#$131'');

  Metin := 'satir 1' + #13#10 + 'satir 2';
  S := AciklamaYaz(Bag, 'T_ACK', 'ID', Metin);
  Kontrol('Cok satirli aciklama yazilir ve okunur', S.Basarili and (KolonAciklamasiOku(Bag, 'T_ACK', 'ID') = Metin));

  Kolonlar := KolonTablosuOlustur(Bag, 'T_ACK', nil);
  try
    Kontrol('Kolon tablosunda ACIKLAMA alani var', Kolonlar.FindField('ACIKLAMA') <> nil);
    Kolonlar.Locate('AD', 'AD', []);
    Kontrol('Kolon tablosunda AD kolonunun aciklamasi gorunur', Pos('k'#$131'sa', Kolonlar.FieldByName('ACIKLAMA').AsString) > 0);
    Kolonlar.Locate('AD', 'ID', []);
    Kontrol('Cok satirli aciklama gridde tek satir', Kolonlar.FieldByName('ACIKLAMA').AsString = 'satir 1 satir 2');
  finally
    Kolonlar.Free;
  end;

  S := AciklamaYaz(Bag, 'T_ACK', 'AD', '');
  Kontrol('Bos metin aciklamayi kaldirir', S.Basarili and (KolonAciklamasiOku(Bag, 'T_ACK', 'AD') = '') and
    (Pos('IS NULL', S.Komutlar[0]) > 0));
  Kontrol('Veriye dokunulmadi', KayitSayisi(Bag, 'T_ACK', '') = 1);

  { Kucuk harfli, tirnakli ad }
  Calistir('CREATE TABLE "kucuk_tablo" ("Ad" VARCHAR(10))');
  S := AciklamaYaz(Bag, 'kucuk_tablo', 'Ad', 'kucuk harfli');
  Kontrol('Kucuk harfli tirnakli tablo ve kolon', S.Basarili and (KolonAciklamasiOku(Bag, 'kucuk_tablo', 'Ad') = 'kucuk harfli'));

  { Olmayan tablo: hata, anlasilir cumle, hicbir sey olmaz }
  S := AciklamaYaz(Bag, 'YOK_BOYLE_TABLO', '', 'x');
  Cikti.Add('Olmayan tablo: basarili=' + BoolToStr(S.Basarili, True) + ' cumle=' + S.Cumle);
  Kontrol('Olmayan tabloda basarisiz, cumle dolu', (not S.Basarili) and (S.Cumle <> ''));
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
      Klasor := Ortam('FBTEST_KLASOR', TPath.Combine(GetEnvironmentVariable('TEMP'), 'acktest'));
      if Ortam('FBTEST_SUNUCU', '') = '' then
        ForceDirectories(Klasor);
      Yol := IncludeTrailingPathDelimiter(Klasor) + 'ack_' + FormatDateTime('yyyymmdd_hhnnss', Now) + '.fdb';
      Tanim := Default(TBaglantiTanimi);
      Tanim.Ad := 'acktest';
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
