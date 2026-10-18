program SeritTest;

{ Asama 3R: uSerit seridini ayri bir formda kurar (fAna'daki ayni dugme listesiyle), uc dilde ekran
  goruntusunu PNG olarak yazar ve genislikleri olcer. Fare/klavye ile elle deneme DEGILDIR.
  Cikti klasoru: SERITTEST_KLASOR ortam degiskeni (yoksa %TEMP%). Cikis kodu: hata sayisi. }

{$APPTYPE GUI}
{$R '..\Kaynak\Manifest.res'}

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Classes, System.IOUtils, Vcl.Forms, Vcl.Controls,
  Vcl.ExtCtrls, Vcl.Graphics, Vcl.Imaging.pngimage, Vcl.Themes, Vcl.Styles, Vcl.ImageCollection,
  Vcl.VirtualImageList, uDil, uIkon, uSerit;

type
  TDinleyici = class
    Sayac: Integer;
    procedure Tikla(Sender: TObject);
  end;

function PrintWindow(Pencere: HWND; DC: HDC; Bayrak: UINT): BOOL; stdcall; external user32;


procedure TDinleyici.Tikla(Sender: TObject);
begin
  Inc(Sayac);
end;

var
  Cikti: TStringList;
  Hatalar: Integer;
  Klasor, Dosya: string;
  Dinleyici: TDinleyici;

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

procedure StilYukle;
var
  Yol: string;
begin
  Yol := ExtractFilePath(ParamStr(0)) + 'Stiller\Windows10.vsf';
  if FileExists(Yol) and TStyleManager.IsValidStyle(Yol) then
  begin
    TStyleManager.LoadFromFile(Yol);
    TStyleManager.TrySetStyle('Windows10');
  end;
end;

{ Fare tiklamasini denetimin kendi mesaj yoluyla yollar. }
procedure Tikla(Dugme: TSeritDugmesi);
begin
  Dugme.Perform(WM_LBUTTONDOWN, MK_LBUTTON, MakeLong(5, 5));
  Dugme.Perform(WM_LBUTTONUP, 0, MakeLong(5, 5));
end;

procedure DilDene(const Kod: string);
var
  Form: TForm;
  Ust: TPanel;
  Koleksiyon: TImageCollection;
  Liste: TVirtualImageList;
  Serit: TSerit;
  Kes, Yedek, Calistir: TSeritDugmesi;
  Resim: TBitmap;
  Png: TPngImage;
  Genislik: Integer;
begin
  DilYukle(Kod);
  Form := TForm.CreateNew(Application);
  Form.Font.Name := 'Segoe UI';
  Form.Font.Height := -13;
  Form.BorderStyle := bsSingle;
  Form.ClientWidth := 1100;
  Form.ClientHeight := 300;
  Form.Position := poDesigned;
  Form.Left := 20;
  Form.Top := 20;
  Ust := TPanel.Create(Form);
  Ust.Parent := Form;
  Ust.Align := alTop;
  Ust.BevelOuter := bvNone;
  Ust.Height := 100;
  Koleksiyon := TImageCollection.Create(Form);
  Liste := TVirtualImageList.Create(Form);
  Liste.ImageCollection := Koleksiyon;
  IkonlariYukle(Koleksiyon, Liste);
  Serit := TSerit.Create(Ust, Koleksiyon, Form.CurrentPPI);
  Serit.Ekle('GRUP_BAGLANTI', 'BTN_YENI_BAGLANTI', IKON_VERITABANI, Dinleyici.Tikla);
  Serit.Ekle('GRUP_BAGLANTI', 'BTN_KLONLA', IKON_KLONLA, Dinleyici.Tikla).Enabled := False;
  Kes := Serit.Ekle('GRUP_BAGLANTI', 'BTN_BAGLAN', IKON_BAGLAN, Dinleyici.Tikla);
  Serit.Ekle('GRUP_BAGLANTI', 'BTN_YENILE', IKON_YENILE, Dinleyici.Tikla);
  Serit.Ekle('GRUP_SORGU', 'BTN_YENI_SORGU', IKON_SORGU, Dinleyici.Tikla);
  Calistir := Serit.Ekle('GRUP_SORGU', 'BTN_CALISTIR', IKON_CALISTIR, Dinleyici.Tikla);
  Serit.Ekle('GRUP_SORGU', 'BTN_PLAN', IKON_PLAN, Dinleyici.Tikla);
  Serit.Ekle('GRUP_YONETIM', 'MENU_METADATA_CIKAR', IKON_METADATA, Dinleyici.Tikla);
  Yedek := Serit.Ekle('GRUP_YONETIM', 'MENU_YEDEK', IKON_YEDEK, Dinleyici.Tikla);
  Calistir.Enabled := False;
  Serit.YazilariYenile;
  Ust.Height := Serit.Yukseklik;
  { Bagla/Kes dugmesinin en uzun hali de sigmali. }
  Kes.Ayarla('BTN_KES', IKON_KES);
  Genislik := Serit.Genislik;
  Cikti.Add(Format('[%s] serit genisligi %d px, yuksekligi %d px (kullanilabilir yaklasik %d)',
    [Kod, Genislik, Serit.Yukseklik, Form.ClientWidth - 190]));
  Kontrol(Kod + ': serit dil kutusunun soluna sigiyor', Genislik <= Form.ClientWidth - 190);
  Kontrol(Kod + ': dugme yuksekligi ayni', Kes.Height = Yedek.Height);

  Form.Show;
  Application.ProcessMessages;
  { Pasif dugmeye (Klonla) ve aktif dugmeye gercek tiklama simulasyonu. }
  Dinleyici.Sayac := 0;
  Tikla(Yedek);
  Tikla(Calistir);
  Kontrol(Kod + ': aktif dugme tiklaninca OnClick calisir, pasif dugme calismaz', Dinleyici.Sayac = 1);

  Resim := TBitmap.Create;
  Png := TPngImage.Create;
  try
    Resim.SetSize(Form.Width, Form.Height);
    Form.Update;
    Sleep(300);
    Application.ProcessMessages;
    BitBlt(Resim.Canvas.Handle, 0, 0, Form.Width, Form.Height, GetDC(0), Form.Left, Form.Top, SRCCOPY);
    Png.Assign(Resim);
    Dosya := TPath.Combine(Klasor, 'seritTest_' + Kod + '.png');
    Png.SaveToFile(Dosya);
    Cikti.Add('Ekran goruntusu: ' + Dosya);
  finally
    Png.Free;
    Resim.Free;
  end;
  Form.Release;
  Application.ProcessMessages;
  Serit.Free;
end;

begin
  Application.Initialize;
  StilYukle;
  Cikti := TStringList.Create;
  Dinleyici := TDinleyici.Create;
  Klasor := GetEnvironmentVariable('SERITTEST_KLASOR');
  if Klasor = '' then
    Klasor := GetEnvironmentVariable('TEMP');
  try
    DilYukle('tr');
    DilDene('tr');
    DilDene('en');
    DilDene('de');
    Cikti.Add(Format('Hata sayisi: %d', [Hatalar]));
    Cikti.SaveToFile(TPath.Combine(Klasor, 'seritTest.txt'), TEncoding.UTF8);
  finally
    Dinleyici.Free;
    Cikti.Free;
  end;
  ExitCode := Hatalar;
end.
