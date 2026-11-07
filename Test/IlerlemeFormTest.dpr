program IlerlemeFormTest;

{ Ilerleme penceresi gorunum testi (komut satiri): buyukce bir gecici veritabani kurar, uKlonla ile kopyalarken pencerenin
  goruntusunu PNG kaydeder (%TEMP%\ilerlemeform). Ortam: FBTEST_SUNUCU, FBTEST_PORT, FBTEST_SIFRE, FBTEST_KLASOR, FBTEST_SATIR. }

{$APPTYPE CONSOLE}

uses
  Winapi.Windows, System.SysUtils, System.Classes, System.IOUtils, Vcl.Forms, Vcl.Graphics, Vcl.Imaging.pngimage,
  FireDAC.Stan.Intf, FireDAC.Stan.Option, FireDAC.Comp.Client, FireDAC.Phys.FB, FireDAC.ConsoleUI.Wait,
  uDil, uBaglanti, uSorgu, uYedek, uKlonla, fIlerleme;

type
  TGozlemci = class
    P: TfrmIlerleme;
    Klasor: string;
    Sayac: Integer;
    SonResim: Cardinal;
    procedure Cikti(const Satir: string; var Iptal: Boolean);
    procedure Adim(const Metin, Dosya: string);
  end;

procedure TGozlemci.Adim(const Metin, Dosya: string);
begin
  P.AdimBildir(Metin, Dosya);
  Writeln('adim: ', Metin, ' | izlenen: ', Dosya);
end;

procedure TGozlemci.Cikti(const Satir: string; var Iptal: Boolean);
var
  Bmp: TBitmap;
  Png: TPngImage;
begin
  P.Cikti(Satir, Iptal);
  if (GetTickCount - SonResim > 1500) and (Sayac < 4) then
  begin
    SonResim := GetTickCount;
    Inc(Sayac);
    Bmp := P.GetFormImage;
    Png := TPngImage.Create;
    try
      Png.Assign(Bmp);
      Png.SaveToFile(TPath.Combine(Klasor, 'ilerleme_' + IntToStr(Sayac) + '.png'));
    finally
      Png.Free;
      Bmp.Free;
    end;
  end;
end;

function Ortam(const Ad, Varsayilan: string): string;
begin
  Result := GetEnvironmentVariable(Ad);
  if Result = '' then
    Result := Varsayilan;
end;

var
  Tanim: TBaglantiTanimi;
  Bag: TAcikBaglanti;
  G: TGozlemci;
  S: TKlonSonucu;
  Yol: string;
  i, Parca: Integer;
begin
  DilYukle('tr');
  Application.Initialize;
  Tanim := Default(TBaglantiTanimi);
  Tanim.Ad := 'ilerleme';
  Tanim.Sunucu := Ortam('FBTEST_SUNUCU', 'localhost');
  Tanim.Port := StrToInt(Ortam('FBTEST_PORT', '3050'));
  Tanim.Kullanici := 'SYSDBA';
  Tanim.Sifre := Ortam('FBTEST_SIFRE', '');
  Tanim.KarakterSeti := VARSAYILAN_KARAKTER_SETI;
  Yol := IncludeTrailingPathDelimiter(Ortam('FBTEST_KLASOR', 'C:\Temp\bakimtest')) + 'ilerleme_' + FormatDateTime('hhnnss', Now) + '.fdb';
  Tanim.VeritabaniYolu := Yol;
  FbVeritabaniOlustur(Tanim);
  Bag := FbBaglan(Tanim);
  SorguCalistir(Bag, 'CREATE TABLE T_BUYUK (ID INTEGER NOT NULL PRIMARY KEY, AD VARCHAR(100), NOTU VARCHAR(200))').Free;
  SorguCalistir(Bag, 'CREATE INDEX IX_BUYUK_AD ON T_BUYUK (AD)').Free;
  Parca := StrToInt(Ortam('FBTEST_SATIR', '1000000')) div 20000;
  for i := 0 to Parca - 1 do
    SorguCalistir(Bag, 'EXECUTE BLOCK AS DECLARE I INTEGER = ' + IntToStr(i * 20000 + 1) + '; BEGIN WHILE (I <= ' + IntToStr(i * 20000 + 20000) +
      ') DO BEGIN INSERT INTO T_BUYUK VALUES (:I, ''AD'' || :I || ''xxxxxxxxxxxxxxxxxxxxxxxxxxxx'', ''NOT'' || :I || ''yyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyy''); I = I + 1; END END').Free;
  Writeln('veri hazir');
  G := TGozlemci.Create;
  G.Klasor := TPath.Combine(GetEnvironmentVariable('TEMP'), 'ilerlemeform');
  ForceDirectories(G.Klasor);
  G.P := IlerlemeAc(T('KLON_ILERLEME_BASLIK'));
  try
    S := VeritabaniKlonla(Tanim, Yol + '_kopya.fdb', G.Cikti, G.Adim);
  finally
    G.P.Bitir;
  end;
  Writeln('basarili: ', S.Basarili, ' ', S.Cumle);
  FbBaglantiyiKes(Bag);
end.
