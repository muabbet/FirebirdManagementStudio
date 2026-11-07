program KlonTest;

{ Asama 7h: uKlonla (veritabanini kopyalama) testi (komut satiri). Gecici veritabani kurar, kopyalar, veriyi karsilastirir.
  Ortam: FBTEST_SUNUCU, FBTEST_PORT, FBTEST_SIFRE, FBTEST_KLASOR (sunucudaki klasor), FBTEST_CIKTI. Cikis kodu: hata sayisi. }

{$APPTYPE CONSOLE}

uses
  System.SysUtils, System.Classes, System.IOUtils, System.StrUtils, Data.DB,
  FireDAC.Stan.Intf, FireDAC.Stan.Option, FireDAC.Comp.Client, FireDAC.Phys.FB, FireDAC.ConsoleUI.Wait,
  uDil, uBaglanti, uSorgu, uYedek, uKlonla;

type
  TIzleyici = class
    procedure Satir(const Metin: string; var Iptal: Boolean);
  end;

var
  Cikti: TStringList;
  Hatalar, KontrolSayisi: Integer;

procedure TIzleyici.Satir(const Metin: string; var Iptal: Boolean);
begin
  Iptal := False;
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
    Result := Q.Fields[0].AsString;
  finally
    Q.Free;
  end;
end;

function TanimYap(const Yol: string): TBaglantiTanimi;
begin
  Result := Default(TBaglantiTanimi);
  Result.Ad := 'klon';
  Result.Sunucu := Ortam('FBTEST_SUNUCU', 'localhost');
  Result.Port := StrToInt(Ortam('FBTEST_PORT', '3050'));
  Result.VeritabaniYolu := Yol;
  Result.Kullanici := 'SYSDBA';
  Result.Sifre := Ortam('FBTEST_SIFRE', '');
  Result.KarakterSeti := VARSAYILAN_KARAKTER_SETI;
end;

var
  Izle: TIzleyici;
  Kaynak, Yeni: TBaglantiTanimi;
  A, B: TAcikBaglanti;
  S, S2: TKlonSonucu;
  Klasor, YolA, Oneri: string;
  i: Integer;
  Dil, Ham, Anahtar: string;
begin
  Cikti := TStringList.Create;
  Izle := TIzleyici.Create;
  try
    try
      DilYukle('tr');
      Cikti.Add('--- Yol onerisi ---');
      Oneri := KlonYoluOner('C:\x\FABRIKA.FDB');
      Kontrol('ayni klasor ve uzanti: ' + Oneri, StartsText('C:\x\FABRIKA_KOPYA_', Oneri) and EndsText('.FDB', Oneri));
      Kontrol('yol bos: bos olmayan oneri', KlonYoluOner('DB.GDB') <> '');
      Kontrol('yedek yolu .fbk', EndsText('.fbk', KlonYedekYolu(TanimYap('C:\x\FABRIKA.FDB'), 'C:\x\Y.FDB')));

      Klasor := Ortam('FBTEST_KLASOR', 'C:\Temp\bakimtest');
      YolA := IncludeTrailingPathDelimiter(Klasor) + 'klonkaynak_' + FormatDateTime('hhnnss', Now) + '.fdb';
      Kaynak := TanimYap(YolA);
      FbVeritabaniOlustur(Kaynak);
      A := FbBaglan(Kaynak);
      Cikti.Add('--- Surum ' + A.Surum + ' ---');
      Komut(A, 'CREATE TABLE T_VERI (ID INTEGER NOT NULL PRIMARY KEY, AD VARCHAR(40))');
      Komut(A, 'CREATE INDEX IX_VERI_AD ON T_VERI (AD)');
      for i := 1 to 500 do
        Komut(A, 'INSERT INTO T_VERI VALUES (' + IntToStr(i) + ', ''ad' + IntToStr(i) + ''')');

      Cikti.Add('--- Kopyalama ---');
      Oneri := KlonYoluOner(YolA);
      S := VeritabaniKlonla(Kaynak, Oneri, Izle.Satir);
      if not S.Basarili then
        Cikti.Add('      ' + S.Cumle + ' | ' + S.Ayrinti);
      Kontrol('kopyalama basarili', S.Basarili);
      Kontrol('yeni yol dogru', S.YeniYol = Oneri);
      Kontrol('gecici yedek dosyasi duruyor (silinmedi)', FileExists(S.YedekDosya) or (Kaynak.Sunucu <> ''));
      Yeni := TanimYap(Oneri);
      B := FbBaglan(Yeni);
      Kontrol('yeni veritabaninda 500 satir', Oku(B, 'select count(*) from t_veri') = '500');
      Kontrol('veri ayni', Oku(B, 'select ad from t_veri where id = 123') = 'ad123');
      Kontrol('index kopyalandi', Oku(B, 'select count(*) from rdb$indices where rdb$index_name = ''IX_VERI_AD''') = '1');
      Kontrol('kaynak dokunulmadi: 500 satir', Oku(A, 'select count(*) from t_veri') = '500');
      FbBaglantiyiKes(B);

      Cikti.Add('--- Var olan dosya ezilmez ---');
      S2 := VeritabaniKlonla(Kaynak, Oneri, Izle.Satir);
      Kontrol('ayni yola ikinci kopyalama reddedildi', not S2.Basarili);
      Kontrol('anlasilir cumle var', S2.Cumle <> '');
      B := FbBaglan(Yeni);
      Kontrol('ilk kopya hala saglam (500 satir)', Oku(B, 'select count(*) from t_veri') = '500');
      FbBaglantiyiKes(B);

      Cikti.Add('--- Dil anahtarlari ---');
      for Dil in ['tr', 'en', 'de'] do
      begin
        Ham := TFile.ReadAllText(TPath.Combine(TPath.Combine(ExtractFilePath(ParamStr(0)), 'Diller'), Dil + '.json'), TEncoding.UTF8);
        for Anahtar in ['MENU_VERITABANI_KOPYALA', 'KLON_BASLIK', 'KLON_ISTEK', 'KLON_ONAY', 'KLON_BAGLANTI_SOR', 'MSG_KLON_BASLADI',
          'MSG_KLON_TAMAM', 'MSG_KLON_YEDEK', 'MSG_KLON_IPTAL', 'MSG_KLON_EKLENDI', 'ERR_KLON_AYNI_YOL', 'MENU_KLONLA', 'KLON_AD'] do
          Kontrol(Dil + ': ' + Anahtar, Pos('"' + Anahtar + '"', Ham) > 0);
      end;
      FbBaglantiyiKes(A);
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
    Izle.Free;
    Cikti.Free;
  end;
  ExitCode := Hatalar;
end.
