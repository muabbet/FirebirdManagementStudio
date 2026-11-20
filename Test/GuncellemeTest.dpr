program GuncellemeTest;

{ Yeni surum denetimi (uGuncelleme) testi, komut satiri. Surum karsilastirma, GitHub cevabini cozme ve sahte indirme adresinin
  reddi ag olmadan denenir. Son bolum gercek GitHub'a sorar; ag yoksa o bolum "atlandi" yazilir (hata sayilmaz).
  Ortam degiskeni: FBTEST_CIKTI (sonuc dosyasi). Cikis kodu: hata sayisi (0 = hepsi gecti). }

{$APPTYPE CONSOLE}

uses
  System.SysUtils, System.Classes,
  uGuncelleme;

const
  ORNEK_JSON =
    '{"tag_name":"v0.10","assets":[' +
    '{"name":"notlar.txt","size":10,"browser_download_url":"https://github.com/muabbet/FirebirdManagementStudio/releases/download/v0.10/notlar.txt"},' +
    '{"name":"FirebirdManagementStudio-0.10-win64.zip","size":7851670,"browser_download_url":"https://github.com/muabbet/FirebirdManagementStudio/releases/download/v0.10/FirebirdManagementStudio-0.10-win64.zip"}]}';
  SAHTE_JSON =
    '{"tag_name":"v9.0","assets":[{"name":"x.zip","size":5,"browser_download_url":"https://baska-site.example/x.zip"}]}';

var
  Cikti: TStringList;
  Hatalar, KontrolSayisi: Integer;

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

procedure KarsilastirmaTesti;
begin
  Kontrol('0.10 > 0.9 (sayi olarak, yazi olarak degil)', SurumKarsilastir('0.10', '0.9') = 1);
  Kontrol('v0.9 = 0.9', SurumKarsilastir('v0.9', '0.9') = 0);
  Kontrol('0.9 < 1.0', SurumKarsilastir('0.9', '1.0') = -1);
  Kontrol('1.0 = 1.0.0', SurumKarsilastir('1.0', '1.0.0') = 0);
  Kontrol('1.0.1 > 1.0', SurumKarsilastir('1.0.1', '1.0') = 1);
  Kontrol('bozuk yazi 0 sayilir', SurumKarsilastir('abc', '0.0') = 0);
end;

procedure CozmeTesti;
var
  B: TSurumBilgisi;
begin
  B := SurumBilgisiniCoz(ORNEK_JSON, '0.9');
  Kontrol('ornek JSON cozuldu', B.Basarili);
  Kontrol('surum 0.10 (v atildi)', B.Surum = '0.10');
  Kontrol('0.9 icin yeni', B.Yeni);
  Kontrol('zip dosyasi secildi (txt degil)', B.DosyaAdi = 'FirebirdManagementStudio-0.10-win64.zip');
  Kontrol('boyut okundu', B.Boyut = 7851670);
  Kontrol('adres GitHub projesi', Pos('https://github.com/muabbet/FirebirdManagementStudio/', B.Adres) = 1);
  B := SurumBilgisiniCoz(ORNEK_JSON, '0.10');
  Kontrol('ayni surumde yeni degil', B.Basarili and not B.Yeni);
  B := SurumBilgisiniCoz(SAHTE_JSON, '0.9');
  Kontrol('baska siteye giden adres reddedilir', B.Basarili and B.Yeni and (B.Adres = ''));
  B := SurumBilgisiniCoz('bozuk', '0.9');
  Kontrol('bozuk cevap: basarisiz, hata yazili', (not B.Basarili) and (B.Hata <> ''));
  B := SurumBilgisiniCoz('{"mesaj":"yok"}', '0.9');
  Kontrol('tag_name yok: basarisiz', not B.Basarili);
end;

procedure AgTesti;
var
  B: TSurumBilgisi;
begin
  B := SonSurumuDenetle('0.0.1');
  if not B.Basarili then
  begin
    Cikti.Add('ATLANDI  GitHub'#39'a ulasilamadi: ' + B.Hata);
    Exit;
  end;
  Kontrol('GitHub: son surum okundu (' + B.Surum + ')', B.Surum <> '');
  Kontrol('GitHub: 0.0.1 icin yeni', B.Yeni);
  Kontrol('GitHub: zip adresi var', (B.DosyaAdi <> '') and (B.Adres <> ''));
  B := SonSurumuDenetle('999.0');
  Kontrol('GitHub: 999.0 icin yeni degil', B.Basarili and not B.Yeni);
end;

begin
  Cikti := TStringList.Create;
  try
    try
      KarsilastirmaTesti;
      CozmeTesti;
      AgTesti;
    except
      on E: Exception do
      begin
        Cikti.Add('HATA  beklenmeyen istisna: ' + E.ClassName + ': ' + E.Message);
        Inc(Hatalar);
      end;
    end;
    Cikti.Add('');
    Cikti.Add('Kontrol sayisi: ' + IntToStr(KontrolSayisi) + ', Hata sayisi: ' + IntToStr(Hatalar));
    if GetEnvironmentVariable('FBTEST_CIKTI') <> '' then
      Cikti.SaveToFile(GetEnvironmentVariable('FBTEST_CIKTI'), TEncoding.UTF8)
    else
      Writeln(Cikti.Text);
  finally
    Cikti.Free;
  end;
  ExitCode := Hatalar;
end.
