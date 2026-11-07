program IndeksOnerFormTest;

{ Index oner penceresi gorunum testi (komut satiri): gecici veritabani kurar, pencereyi acar, goruntusunu PNG kaydeder
  (%TEMP%\indeksform). Ortam: FBTEST_SUNUCU, FBTEST_PORT, FBTEST_SIFRE, FBTEST_KLASOR. }

{$APPTYPE CONSOLE}

uses
  Winapi.Windows, System.SysUtils, System.Classes, System.IOUtils, Vcl.Forms, Vcl.Controls, Vcl.Graphics, Vcl.ExtCtrls,
  Vcl.Imaging.pngimage, FireDAC.Stan.Intf, FireDAC.Stan.Option, FireDAC.Comp.Client, FireDAC.Phys.FB, FireDAC.ConsoleUI.Wait,
  uDil, uBaglanti, uSorgu, fIndeksOner;

type
  TGorevli = class
    Zamanlayici: TTimer;
    Adim: Integer;
    Klasor: string;
    procedure Tik(Sender: TObject);
  end;

var
  Gorevli: TGorevli;
  Bag: TAcikBaglanti;
  Sonuc: TStringList;

function Ortam(const Ad, Varsayilan: string): string;
begin
  Result := GetEnvironmentVariable(Ad);
  if Result = '' then
    Result := Varsayilan;
end;

procedure TGorevli.Tik(Sender: TObject);
var
  Bmp: TBitmap;
  Png: TPngImage;
begin
  Inc(Adim);
  if Screen.ActiveForm = nil then
    Exit;
  if Adim = 1 then
  begin
    Bmp := Screen.ActiveForm.GetFormImage;
    Png := TPngImage.Create;
    try
      Png.Assign(Bmp);
      Png.SaveToFile(TPath.Combine(Klasor, 'indeks_oner.png'));
    finally
      Png.Free;
      Bmp.Free;
    end;
    Screen.ActiveForm.Close;
    Zamanlayici.Enabled := False;
  end;
end;

var
  Tanim: TBaglantiTanimi;
  i: Integer;
begin
  Gorevli := TGorevli.Create;
  Sonuc := TStringList.Create;
  DilYukle(Ortam('FBTEST_DIL', 'tr'));
  Application.Initialize;
  Tanim := Default(TBaglantiTanimi);
  Tanim.Ad := 'indeksform';
  Tanim.Sunucu := Ortam('FBTEST_SUNUCU', 'localhost');
  Tanim.Port := StrToInt(Ortam('FBTEST_PORT', '3050'));
  Tanim.Kullanici := 'SYSDBA';
  Tanim.Sifre := Ortam('FBTEST_SIFRE', '');
  Tanim.KarakterSeti := VARSAYILAN_KARAKTER_SETI;
  Tanim.VeritabaniYolu := IncludeTrailingPathDelimiter(Ortam('FBTEST_KLASOR', 'C:\Temp\bakimtest')) + 'indeksform_' + FormatDateTime('hhnnss', Now) + '.fdb';
  FbVeritabaniOlustur(Tanim);
  Bag := FbBaglan(Tanim);
  SorguCalistir(Bag, 'CREATE TABLE T_MUSTERI (ID INTEGER NOT NULL PRIMARY KEY, AD VARCHAR(40))').Free;
  SorguCalistir(Bag, 'CREATE TABLE T_SATIS (ID INTEGER NOT NULL PRIMARY KEY, MUSTERI_ID INTEGER, TARIH DATE, DURUM CHAR(1))').Free;
  SorguCalistir(Bag, 'CREATE TABLE T_KUCUK (ID INTEGER NOT NULL PRIMARY KEY)').Free;
  for i := 0 to 4 do
  begin
    SorguCalistir(Bag, 'EXECUTE BLOCK AS DECLARE I INTEGER = ' + IntToStr(i * 1000 + 1) + '; BEGIN WHILE (I <= ' + IntToStr(i * 1000 + 1000) +
      ') DO BEGIN INSERT INTO T_MUSTERI VALUES (:I, ''AD'' || :I); I = I + 1; END END').Free;
    SorguCalistir(Bag, 'EXECUTE BLOCK AS DECLARE I INTEGER = ' + IntToStr(i * 1000 + 1) + '; BEGIN WHILE (I <= ' + IntToStr(i * 1000 + 1000) +
      ') DO BEGIN INSERT INTO T_SATIS VALUES (:I, MOD(:I, 500), DATEADD(MOD(:I, 300) DAY TO DATE ''2026-01-01''), IIF(MOD(:I, 10) = 0, ''A'', ''B'')); I = I + 1; END END').Free;
  end;
  Gorevli.Klasor := TPath.Combine(GetEnvironmentVariable('TEMP'), 'indeksform');
  ForceDirectories(Gorevli.Klasor);
  Gorevli.Zamanlayici := TTimer.Create(nil);
  Gorevli.Zamanlayici.Interval := 1500;
  Gorevli.Zamanlayici.OnTimer := Gorevli.Tik;
  IndeksOnerPenceresiniGoster(Bag, 'SELECT * FROM T_SATIS S JOIN T_MUSTERI M ON M.ID = S.MUSTERI_ID WHERE S.DURUM = ''A'' AND S.TARIH >= ''2026-06-01''', nil, Sonuc);
  Writeln('tamam');
  FbBaglantiyiKes(Bag);
end.
