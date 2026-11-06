program TabloTasarimFormTest;

{ Asama 7g: tablo tasarim penceresi gorunum testi (komut satiri). Formu gercekten acar, hucre secer, listeden tip secer, tablo adi yazar ve
  her adimda pencerenin goruntusunu PNG olarak kaydeder (klasor: FBTEST_RESIM, varsayilan %TEMP%\tasarimform). Sonra pencereyi kapatir.
  Cikis kodu: hata sayisi (0 = gecti). }

{$APPTYPE CONSOLE}

uses
  Winapi.Windows, System.SysUtils, System.Classes, System.IOUtils, Vcl.Forms, Vcl.Controls, Vcl.Graphics, Vcl.ExtCtrls,
  Vcl.Imaging.pngimage, FireDAC.Stan.Intf, FireDAC.Stan.Option, FireDAC.Comp.Client, FireDAC.Phys.FB, FireDAC.ConsoleUI.Wait,
  uDil, uBaglanti, uTabloTasarim, fTabloTasarim;

type
  TGorevli = class
    Zamanlayici: TTimer;
    Adim: Integer;
    Klasor: string;
    Hatalar: Integer;
    procedure Tik(Sender: TObject);
    procedure Resim(Pencere: TForm; const Ad: string);
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
    Writeln('OK    resim: ', TPath.Combine(Klasor, Ad + '.png'));
  finally
    Png.Free;
    Bmp.Free;
  end;
end;

procedure TGorevli.Tik(Sender: TObject);
var
  P: TfrmTabloTasarim;
  i: Integer;
begin
  Inc(Adim);
  if not (Screen.ActiveForm is TfrmTabloTasarim) then
  begin
    if Adim > 10 then
    begin
      Writeln('HATA  pencere acilmadi');
      Inc(Hatalar);
      Zamanlayici.Enabled := False;
    end;
    Exit;
  end;
  P := TfrmTabloTasarim(Screen.ActiveForm);
  case Adim of
    1: Resim(P, '1_acilis');
    2:
      begin
        { Tip hucresine git: liste hucrenin ustunde gorunmeli }
        P.gridKolon.Row := 2;
        P.gridKolon.Col := 1;
      end;
    3:
      begin
        Resim(P, '2_tip_hucresi');
        Writeln('      combo gorunur: ', P.cmbHucre.Visible, ', secili: ', P.cmbHucre.Text, ', sol: ', P.cmbHucre.Left);
        if not P.cmbHucre.Visible then
          Inc(Hatalar);
        i := P.cmbHucre.Items.IndexOf('NUMERIC');
        P.cmbHucre.ItemIndex := i;
        P.cmbHucre.OnChange(P.cmbHucre);
        P.edtTablo.Text := 'T_DENEME';
      end;
    4:
      begin
        Resim(P, '3_numeric_secildi');
        Writeln('      boyut hucresi: ', P.gridKolon.Cells[2, 2], ' (beklenen 18,2)');
        if P.gridKolon.Cells[2, 2] <> '18,2' then
          Inc(Hatalar);
        Writeln('      sql: ', StringReplace(P.memSql.Text, #13#10, ' | ', [rfReplaceAll]));
        if Pos('NUMERIC(18,2)', P.memSql.Text) = 0 then
          Inc(Hatalar);
        { Yeni kolon ekle }
        P.btnEkle.Click;
      end;
    5:
      begin
        Resim(P, '4_kolon_eklendi');
        Writeln('      satir sayisi: ', P.gridKolon.RowCount, ' (beklenen 4)');
        if P.gridKolon.RowCount <> 4 then
          Inc(Hatalar);
        P.gridKolon.Cells[0, 3] := 'TARIH';
        P.gridKolon.Row := 3;
        P.gridKolon.Col := 3;
      end;
    6:
      begin
        Resim(P, '5_evet_hayir_hucresi');
        P.ModalResult := mrCancel;
        Zamanlayici.Enabled := False;
      end;
  end;
end;

var
  Gorevli: TGorevli;
  Tanim: TBaglantiTanimi;
  Klasor, Yol, Notlar: string;
  Bag: TAcikBaglanti;
  Yeni: string;
begin
  ExitCode := 1;
  Gorevli := TGorevli.Create;
  try
    try
      DilYukle('tr');
      Klasor := GetEnvironmentVariable('FBTEST_RESIM');
      if Klasor = '' then
        Klasor := TPath.Combine(GetEnvironmentVariable('TEMP'), 'tasarimform');
      ForceDirectories(Klasor);
      Gorevli.Klasor := Klasor;
      Yol := TPath.Combine(Klasor, 'form_' + FormatDateTime('yyyymmdd_hhnnss', Now) + '.fdb');
      Tanim := Default(TBaglantiTanimi);
      Tanim.Ad := 'formtest';
      Tanim.Port := 3050;
      Tanim.VeritabaniYolu := Yol;
      Tanim.Kullanici := 'SYSDBA';
      Tanim.KarakterSeti := VARSAYILAN_KARAKTER_SETI;
      FbVeritabaniOlustur(Tanim);
      Bag := FbBaglan(Tanim);
      Application.Initialize;
      Gorevli.Zamanlayici := TTimer.Create(nil);
      Gorevli.Zamanlayici.Interval := 700;
      Gorevli.Zamanlayici.OnTimer := Gorevli.Tik;
      Gorevli.Zamanlayici.Enabled := True;
      Notlar := '';
      TabloTasarimPenceresiniGoster(Bag, nil, TStringList.Create, Yeni);
      Writeln('OK    pencere kapandi, hatalar: ', Gorevli.Hatalar);
      ExitCode := Gorevli.Hatalar;
      FbBaglantiyiKes(Bag);
    except
      on E: Exception do
      begin
        Writeln('HATA  ', E.ClassName, ': ', E.Message);
        ExitCode := 1;
      end;
    end;
  finally
    Gorevli.Free;
  end;
end.
