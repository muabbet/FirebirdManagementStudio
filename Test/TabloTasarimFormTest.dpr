program TabloTasarimFormTest;

{ Asama 7g: tablo tasarim penceresi gorunum ve etkilesim testi (komut satiri). Formu gercekten acar; hucre secer, liste menusunu klavyeyle acar
  (oge sayisini sayar, EndMenu ile kapatir), liste degerlerini yazar ve her adimda pencerenin goruntusunu PNG olarak kaydeder
  (klasor: FBTEST_RESIM, varsayilan %TEMP%\tasarimform). Gercek fare oynamaz. Cikis kodu: hata sayisi (0 = gecti). }

{$APPTYPE CONSOLE}

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Classes, System.IOUtils, System.Types, Vcl.Forms, Vcl.Controls,
  Vcl.Graphics, Vcl.ExtCtrls, Vcl.Grids, Vcl.StdCtrls, Vcl.Menus, Vcl.Imaging.pngimage, FireDAC.Stan.Intf, FireDAC.Stan.Option,
  FireDAC.Comp.Client, FireDAC.Phys.FB, FireDAC.ConsoleUI.Wait,
  uDil, uBaglanti, uTabloTasarim, fTabloTasarim;

type
  TGorevli = class
    Zamanlayici: TTimer;
    Adim: Integer;
    Klasor: string;
    Hatalar: Integer;
    MenuOgeSayisi: Integer;
    MenuIlkOge: string;
    procedure Tik(Sender: TObject);
    procedure Resim(Pencere: TForm; const Ad: string);
    procedure Kontrol(const Ad: string; Sonuc: Boolean);
  end;

procedure TGorevli.Kontrol(const Ad: string; Sonuc: Boolean);
begin
  if Sonuc then
    Writeln('OK    ', Ad)
  else
  begin
    Writeln('HATA  ', Ad);
    Inc(Hatalar);
  end;
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
  P: TfrmTabloTasarim;
begin
  Inc(Adim);
  if Adim = 6 then
  begin
    { Menu (ic ice dongu) acikken gelen tik: oge sayisini say ve menuyu kapat. Adim 5'teki Perform buna kadar bekler. }
    if Screen.ActiveForm is TfrmTabloTasarim then
    begin
      MenuOgeSayisi := TfrmTabloTasarim(Screen.ActiveForm).pmListe.Items.Count;
      if MenuOgeSayisi > 0 then
        MenuIlkOge := TfrmTabloTasarim(Screen.ActiveForm).pmListe.Items[0].Caption;
    end;
    EndMenu;
    Exit;
  end;
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
    1:
      begin
        Resim(P, '1_acilis');
        Kontrol('liste menusu bilesen olarak var', P.pmListe <> nil);
      end;
    2:
      begin
        { Yeni kolon ekle ve adini yaz }
        P.btnEkle.Click;
        P.gridKolon.Cells[0, 3] := 'MIKTAR';
        P.gridKolon.Row := 3;
        P.gridKolon.Col := 1;
        P.DegerSec(1, 3, 'DECIMAL');
      end;
    3:
      begin
        Resim(P, '2_decimal_secildi');
        Kontrol('DECIMAL hucreye yazildi', P.gridKolon.Cells[1, 3] = 'DECIMAL');
        Kontrol('boyut 18,2 oldu', P.gridKolon.Cells[2, 3] = '18,2');
        Kontrol('SQL DECIMAL(18,2) iceriyor', Pos('MIKTAR DECIMAL(18,2)', P.memSql.Text) > 0);
        P.DegerSec(3, 3, 'Evet');
        P.DegerSec(4, 3, 'Evet');
      end;
    4:
      begin
        Kontrol('Bos olamaz Evet', P.gridKolon.Cells[3, 3] = 'Evet');
        Kontrol('Birincil anahtar Evet', P.gridKolon.Cells[4, 3] = 'Evet');
        Kontrol('SQL NOT NULL ve PRIMARY KEY (ID, MIKTAR)', (Pos('MIKTAR DECIMAL(18,2) NOT NULL', P.memSql.Text) > 0) and
          (Pos('PRIMARY KEY (ID, MIKTAR)', P.memSql.Text) > 0));
        { Tip degerini baska bir tipe cevir ve geri: kalicilik }
        P.DegerSec(1, 3, 'VARCHAR');
        Kontrol('VARCHAR secilince boyut 50', (P.gridKolon.Cells[1, 3] = 'VARCHAR') and (P.gridKolon.Cells[2, 3] = '50'));
        P.DegerSec(1, 3, 'DATE');
        Kontrol('DATE secilince boyut bos', (P.gridKolon.Cells[1, 3] = 'DATE') and (P.gridKolon.Cells[2, 3] = ''));
        P.DegerSec(1, 3, 'DECIMAL');
        P.gridKolon.Row := 3;
        P.gridKolon.Col := 1;
      end;
    5:
      begin
        { Klavye: Bosluk ile liste menusunu ac (Perform, menu kapanana kadar bekler; adim 6 menuyu kapatir) }
        Resim(P, '3_menu_oncesi');
        P.gridKolon.SetFocus;
        P.gridKolon.Perform(WM_KEYDOWN, VK_SPACE, 0);
        Kontrol('menu acildi ve tip listesi dolu (en az 15 oge)', MenuOgeSayisi >= 15);
        Writeln('      menu oge sayisi: ', MenuOgeSayisi, ', ilki: ', MenuIlkOge);
        Kontrol('menu kapandiktan sonra hucre DECIMAL kaldi', P.gridKolon.Cells[1, 3] = 'DECIMAL');
      end;
    7:
      begin
        Resim(P, '4_menu_sonrasi');
      end;
    8:
      begin
        { Satir tasima }
        P.gridKolon.Row := 3;
        P.btnYukari.Click;
        Kontrol('Yukari tasi: MIKTAR 2. satira cikti', (P.gridKolon.Cells[0, 2] = 'MIKTAR') and (P.gridKolon.Cells[0, 3] = 'AD'));
        Kontrol('Yukari tasi: tip ve boyut kolonla birlikte tasindi', (P.gridKolon.Cells[1, 2] = 'DECIMAL') and (P.gridKolon.Cells[2, 2] = '18,2'));
        P.btnAsagi.Click;
        Kontrol('Asagi tasi: geri geldi', (P.gridKolon.Cells[0, 3] = 'MIKTAR') and (P.gridKolon.Cells[1, 3] = 'DECIMAL'));
        P.btnCikar.Click;
        Kontrol('Kolonu cikar: satir sayisi 3', P.gridKolon.RowCount = 3);
        Kontrol('Kolonu cikar: MIKTAR gitti', (P.gridKolon.Cells[0, 1] = 'ID') and (P.gridKolon.Cells[0, 2] = 'AD'));
      end;
    9:
      begin
        Resim(P, '5_son');
        P.ModalResult := mrCancel;
        Zamanlayici.Enabled := False;
      end;
  end;
end;

var
  Gorevli: TGorevli;
  Tanim: TBaglantiTanimi;
  Klasor, Yol: string;
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
      TabloTasarimPenceresiniGoster(Bag, nil, TStringList.Create, Yeni);
      Writeln('      pencere kapandi, hata sayisi: ', Gorevli.Hatalar);
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
