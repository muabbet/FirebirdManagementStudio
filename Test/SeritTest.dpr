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
  Klasor: string;
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

procedure EkranGoruntusuYaz(Form: TForm; const Dosya: string);
var
  Resim: TBitmap;
  Png: TPngImage;
begin
  Resim := TBitmap.Create;
  Png := TPngImage.Create;
  try
    Resim.SetSize(Form.Width, Form.Height);
    Form.Update;
    Sleep(200);
    Application.ProcessMessages;
    BitBlt(Resim.Canvas.Handle, 0, 0, Form.Width, Form.Height, GetDC(0), Form.Left, Form.Top, SRCCOPY);
    Png.Assign(Resim);
    Png.SaveToFile(Dosya);
    Cikti.Add('Ekran goruntusu: ' + Dosya);
  finally
    Png.Free;
    Resim.Free;
  end;
end;

procedure DilDene(const Kod: string);
var
  Form: TForm;
  Ust: TPanel;
  Koleksiyon: TImageCollection;
  Liste: TVirtualImageList;
  Serit: TSerit;
  Dugmeler: array[0..8] of TSeritDugmesi;
  GrupNo: array[0..8] of Integer;
  i, Sekme, Gorunen, Beklenen: Integer;
begin
  DilYukle(Kod);
  Form := TForm.CreateNew(Application);
  Form.Font.Name := 'Segoe UI';
  Form.Font.Height := -13;
  Form.BorderStyle := bsSingle;
  Form.ClientWidth := 1100;
  Form.ClientHeight := 200;
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
  Dugmeler[0] := Serit.Ekle('GRUP_BAGLANTI', 'BTN_YENI_BAGLANTI', IKON_VERITABANI, Dinleyici.Tikla);
  Dugmeler[1] := Serit.Ekle('GRUP_BAGLANTI', 'BTN_KLONLA', IKON_KLONLA, Dinleyici.Tikla);
  Dugmeler[2] := Serit.Ekle('GRUP_BAGLANTI', 'BTN_BAGLAN', IKON_BAGLAN, Dinleyici.Tikla);
  Dugmeler[3] := Serit.Ekle('GRUP_BAGLANTI', 'BTN_YENILE', IKON_YENILE, Dinleyici.Tikla);
  Dugmeler[4] := Serit.Ekle('GRUP_SORGU', 'BTN_YENI_SORGU', IKON_SORGU, Dinleyici.Tikla);
  Dugmeler[5] := Serit.Ekle('GRUP_SORGU', 'BTN_CALISTIR', IKON_CALISTIR, Dinleyici.Tikla);
  Dugmeler[6] := Serit.Ekle('GRUP_SORGU', 'BTN_PLAN', IKON_PLAN, Dinleyici.Tikla);
  Dugmeler[7] := Serit.Ekle('GRUP_YONETIM', 'MENU_METADATA_CIKAR', IKON_METADATA, Dinleyici.Tikla);
  Dugmeler[8] := Serit.Ekle('GRUP_YONETIM', 'MENU_YEDEK', IKON_YEDEK, Dinleyici.Tikla);
  for i := 0 to 8 do
    GrupNo[i] := ord(i >= 4) + ord(i >= 7);
  Dugmeler[1].Enabled := False;
  Dugmeler[5].Enabled := False;
  Serit.YazilariYenile;
  Ust.Height := Serit.Yukseklik;
  { Bagla/Kes dugmesinin en uzun hali de sigmali. }
  Dugmeler[2].Ayarla('BTN_KES', IKON_KES);
  Cikti.Add(Format('[%s] serit genisligi (en genis sekme) %d px, yuksekligi %d px (kullanilabilir yaklasik %d)',
    [Kod, Serit.Genislik, Serit.Yukseklik, Form.ClientWidth - 190]));
  Kontrol(Kod + ': serit dil kutusunun soluna sigiyor', Serit.Genislik <= Form.ClientWidth - 190);
  Kontrol(Kod + ': dugme yuksekligi ayni', Dugmeler[2].Height = Dugmeler[8].Height);
  Form.Show;
  Application.ProcessMessages;

  { Pasif dugmeye (Klonla) ve aktif dugmeye gercek tiklama simulasyonu (Bag. sekmesi acik). }
  Dinleyici.Sayac := 0;
  Tikla(Dugmeler[0]);
  Tikla(Dugmeler[1]);
  Kontrol(Kod + ': aktif dugme tiklaninca OnClick calisir, pasif dugme calismaz', Dinleyici.Sayac = 1);

  for Sekme := 0 to 2 do
  begin
    Serit.SekmeSec(Sekme);
    Application.ProcessMessages;
    Gorunen := 0;
    Beklenen := 0;
    for i := 0 to 8 do
    begin
      if Dugmeler[i].Parent.Visible then
        Inc(Gorunen);
      if GrupNo[i] = Sekme then
        Inc(Beklenen);
      Kontrol(Format('%s: sekme %d, dugme %d %s', [Kod, Sekme, i, 'gorunurluk dogru']),
        Dugmeler[i].Parent.Visible = (GrupNo[i] = Sekme));
    end;
    Kontrol(Format('%s: sekme %d, %d dugme gorunur (beklenen %d)', [Kod, Sekme, Gorunen, Beklenen]),
      Gorunen = Beklenen);
    { Gizli sekmenin dugmelerinin Enabled durumu degismez. }
    Kontrol(Kod + ': Enabled durumu sekme degisince korunur',
      (not Dugmeler[1].Enabled) and (not Dugmeler[5].Enabled) and Dugmeler[0].Enabled and Dugmeler[8].Enabled);
    EkranGoruntusuYaz(Form, TPath.Combine(Klasor, Format('seritTest_%s_%d.png', [Kod, Sekme])));
  end;
  Serit.SekmeSec(0);
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
