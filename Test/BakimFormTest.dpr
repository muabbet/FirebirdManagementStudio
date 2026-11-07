program BakimFormTest;

{ Asama 7d: bakim penceresi gorunum testi (komut satiri). Gecici veritabani kurar, formu acar, raporu hazirlatir ve her sekmenin
  goruntusunu PNG kaydeder (klasor: FBTEST_RESIM, varsayilan %TEMP%\bakimform). Ortam: FBTEST_SUNUCU, FBTEST_PORT, FBTEST_SIFRE, FBTEST_KLASOR. }

{$APPTYPE CONSOLE}

uses
  Winapi.Windows, System.SysUtils, System.Classes, System.IOUtils, Vcl.Forms, Vcl.Controls, Vcl.Graphics, Vcl.ExtCtrls,
  Vcl.Imaging.pngimage, FireDAC.Stan.Intf, FireDAC.Stan.Option, FireDAC.Comp.Client, FireDAC.Phys.FB, FireDAC.ConsoleUI.Wait,
  uDil, uBaglanti, uSorgu, fBakim;

type
  TGorevli = class
    Zamanlayici: TTimer;
    Adim: Integer;
    Klasor: string;
    Hatalar: Integer;
    procedure Tik(Sender: TObject);
    procedure Resim(Pencere: TForm; const Ad: string);
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

procedure TGorevli.Resim(Pencere: TForm; const Ad: string);
var
  Bmp: TBitmap;
  Png: TPngImage;
begin
  Bmp := Pencere.GetFormImage;
  Png := TPngImage.Create;
  try
    Png.Assign(Bmp);
    Png.SaveToFile(TPath.Combine(Klasor, Ad + '.png'));
  finally
    Png.Free;
    Bmp.Free;
  end;
end;

procedure TGorevli.Tik(Sender: TObject);
var
  P: TfrmBakim;
begin
  Inc(Adim);
  if not (Screen.ActiveForm is TfrmBakim) then
  begin
    if Adim > 10 then
    begin
      Writeln('HATA  pencere acilmadi');
      Inc(Hatalar);
      Zamanlayici.Enabled := False;
    end;
    Exit;
  end;
  P := TfrmBakim(Screen.ActiveForm);
  if (Adim > 2) and (not P.btnRapor.Enabled) then
  begin
    Dec(Adim);
    Exit;
  end;
  case Adim of
    1: Resim(P, '1_acilis');
    2: P.btnRapor.Click;
    3:
      begin
        Resim(P, '2_ozet');
        P.pgSekmeler.ActivePage := P.tsTablolar;
        Writeln(P.memOzet.Text);
        Writeln('tablo satiri: ', P.lvTablolar.Items.Count, ', index satiri: ', P.lvIndeksler.Items.Count);
        if (P.lvTablolar.Items.Count < 2) or (P.lvIndeksler.Items.Count < 3) then
          Inc(Hatalar);
        if P.btnBaslat.Enabled = False then
          Writeln('not: bakim dugmesi kapali (is yok)');
      end;
    4:
      begin
        Resim(P, '3_tablolar');
        P.pgSekmeler.ActivePage := P.tsIndeksler;
      end;
    5:
      begin
        Resim(P, '4_indeksler');
        P.pgSekmeler.ActivePage := P.tsIsler;
      end;
    6:
      begin
        Resim(P, '5_isler');
        Zamanlayici.Enabled := False;
        P.Close;
      end;
  end;
end;

var
  Tanim: TBaglantiTanimi;
  Yol: string;
  i: Integer;
begin
  Gorevli := TGorevli.Create;
  Sonuc := TStringList.Create;
  try
    DilYukle(Ortam('FBTEST_DIL', 'tr'));
    Application.Initialize;
    Tanim := Default(TBaglantiTanimi);
    Tanim.Ad := 'bakimform';
    Tanim.Sunucu := Ortam('FBTEST_SUNUCU', 'localhost');
    Tanim.Port := StrToInt(Ortam('FBTEST_PORT', '3050'));
    Tanim.Kullanici := 'SYSDBA';
    Tanim.Sifre := Ortam('FBTEST_SIFRE', '');
    Tanim.KarakterSeti := VARSAYILAN_KARAKTER_SETI;
    Yol := IncludeTrailingPathDelimiter(Ortam('FBTEST_KLASOR', 'C:\Temp\bakimtest')) + 'form_' + FormatDateTime('hhnnss', Now) + '.fdb';
    Tanim.VeritabaniYolu := Yol;
    FbVeritabaniOlustur(Tanim);
    Bag := FbBaglan(Tanim);
    SorguCalistir(Bag, 'CREATE TABLE T_BUYUK (ID INTEGER NOT NULL PRIMARY KEY, AD VARCHAR(40), SAYI INTEGER)').Free;
    SorguCalistir(Bag, 'CREATE INDEX IX_BUYUK_AD ON T_BUYUK (AD)').Free;
    SorguCalistir(Bag, 'CREATE TABLE T_KUCUK (ID INTEGER NOT NULL PRIMARY KEY)').Free;
    for i := 0 to 9 do
      SorguCalistir(Bag, 'EXECUTE BLOCK AS DECLARE I INTEGER = ' + IntToStr(i * 1000 + 1) + '; BEGIN WHILE (I <= ' + IntToStr(i * 1000 + 1000) +
        ') DO BEGIN INSERT INTO T_BUYUK VALUES (:I, ''AD'' || :I, MOD(:I, 7)); I = I + 1; END END').Free;
    SorguCalistir(Bag, 'DELETE FROM T_BUYUK WHERE ID > 3000').Free;
    SorguCalistir(Bag, 'UPDATE T_BUYUK SET SAYI = SAYI + 1 WHERE ID <= 2000').Free;
    Gorevli.Klasor := Ortam('FBTEST_RESIM', TPath.Combine(GetEnvironmentVariable('TEMP'), 'bakimform'));
    ForceDirectories(Gorevli.Klasor);
    Gorevli.Zamanlayici := TTimer.Create(nil);
    Gorevli.Zamanlayici.Interval := 1500;
    Gorevli.Zamanlayici.OnTimer := Gorevli.Tik;
    BakimPenceresiniGoster(Bag, nil, Sonuc);
    Writeln('Sonuc alani:');
    Writeln(Sonuc.Text);
    FbBaglantiyiKes(Bag);
    Writeln('Hata sayisi: ', Gorevli.Hatalar);
    ExitCode := Gorevli.Hatalar;
  except
    on E: Exception do
    begin
      Writeln('HATA  ', E.ClassName, ': ', E.Message);
      ExitCode := 1;
    end;
  end;
end.
