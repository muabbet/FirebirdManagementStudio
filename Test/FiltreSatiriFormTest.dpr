program FiltreSatiriFormTest;

{ Kolon altindaki filtre satirinin GORUNUM testi (komut satiri, veritabani gerekmez): bellekte bir tablo ve TDBGrid
  kurar, uFiltreSatiri'ni takar; pencerenin resmini PNG kaydeder: acilista, bir kolon daraltilinca ve yatay kaydirilinca.
  Ortam: FBTEST_KLASOR (resimlerin klasoru; yoksa %TEMP%\filtreform). }

{$APPTYPE CONSOLE}

uses
  Winapi.Windows, System.SysUtils, System.Classes, System.IOUtils, Data.DB, Vcl.Forms, Vcl.Controls, Vcl.Graphics,
  Vcl.Grids, Vcl.DBGrids, Vcl.StdCtrls, Vcl.Imaging.pngimage,
  FireDAC.Stan.Intf, FireDAC.Stan.Option, FireDAC.Comp.Client,
  uDil, uFiltreSatiri;

type
  TGozlemci = class
    Sayac: Integer;
    OneriSayisi: Integer;
    procedure Degisti(Sender: TObject);
    procedure Oner(const AlanAdi, Yazi: string; Sonuc: TStrings);
  end;

  TGridErisim = class(TDBGrid);

procedure TGozlemci.Degisti(Sender: TObject);
begin
  Inc(Sayac);
end;

procedure TGozlemci.Oner(const AlanAdi, Yazi: string; Sonuc: TStrings);
begin
  Inc(OneriSayisi);
  Sonuc.Add(Yazi + ' Ankara');
  Sonuc.Add(Yazi + ' Adana');
  Sonuc.Add(Yazi + ' Izmir');
  Sonuc.Add(Yazi + ' Bursa');
end;

procedure Bekle(Ms: Integer);
var
  Bitis: Cardinal;
begin
  Bitis := GetTickCount + Cardinal(Ms);
  while GetTickCount < Bitis do
  begin
    Application.ProcessMessages;
    Sleep(10);
  end;
end;

procedure Resim(Form: TForm; const Yol: string);
var
  Bmp: TBitmap;
  Png: TPngImage;
begin
  Bmp := Form.GetFormImage;
  Png := TPngImage.Create;
  try
    Png.Assign(Bmp);
    Png.SaveToFile(Yol);
  finally
    Png.Free;
    Bmp.Free;
  end;
  Writeln('resim: ', Yol);
end;

var
  Klasor: string;
  Form: TForm;
  Grid: TDBGrid;
  Tablo: TFDMemTable;
  Kaynak: TDataSource;
  Satir: TFiltreSatiri;
  Gozlemci: TGozlemci;
  i: Integer;
begin
  Klasor := GetEnvironmentVariable('FBTEST_KLASOR');
  if Klasor = '' then
    Klasor := TPath.Combine(TPath.GetTempPath, 'filtreform');
  ForceDirectories(Klasor);
  Gozlemci := TGozlemci.Create;
  Form := TForm.Create(nil);
  Tablo := TFDMemTable.Create(Form);
  Kaynak := TDataSource.Create(Form);
  Grid := TDBGrid.Create(Form);
  try
    Form.Caption := 'Filtre satiri deneme';
    Form.Position := poDesigned;
    Form.Left := 40;
    Form.Top := 40;
    Form.Width := 900;
    Form.Height := 320;
    Form.Font.Name := 'Segoe UI';
    Form.Font.Size := 9;
    Tablo.FieldDefs.Add('ID', ftInteger);
    Tablo.FieldDefs.Add('AD', ftString, 30);
    Tablo.FieldDefs.Add('TUTAR', ftFloat);
    Tablo.FieldDefs.Add('TARIH', ftDate);
    Tablo.FieldDefs.Add('ZAMAN', ftTimeStamp);
    Tablo.FieldDefs.Add('ACIKLAMA', ftString, 60);
    Tablo.FieldDefs.Add('ADRES', ftString, 60);
    Tablo.FieldDefs.Add('TELEFON', ftString, 20);
    Tablo.FieldDefs.Add('SEHIR', ftString, 20);
    Tablo.FieldDefs.Add('NOT1', ftString, 40);
    Tablo.CreateDataSet;
    for i := 1 to 8 do
      Tablo.AppendRecord([i, 'Kayit ' + IntToStr(i), i * 10.5, EncodeDate(2026, 11, i), Now, 'aciklama', 'adres', '555', 'Ankara', 'x']);
    Tablo.First;
    Kaynak.DataSet := Tablo;
    Grid.Parent := Form;
    Grid.Align := alClient;
    Grid.Options := [dgTitles, dgIndicator, dgColLines, dgRowLines, dgColumnResize, dgTabs];
    Grid.DataSource := Kaynak;
    Form.Show;
    Satir := TFiltreSatiri.Create(Grid, Gozlemci.Degisti);
    Satir.Esitle;
    Bekle(500);
    Resim(Form, TPath.Combine(Klasor, '1_acilis.png'));

    Grid.Columns[1].Width := 60;
    Bekle(400);
    Resim(Form, TPath.Combine(Klasor, '2_kolon_dar.png'));

    TGridErisim(Grid).LeftCol := 4;
    Bekle(400);
    Resim(Form, TPath.Combine(Klasor, '3_kaydirilmis.png'));

    TGridErisim(Grid).LeftCol := 1;
    Form.Width := 500;
    Bekle(400);
    Resim(Form, TPath.Combine(Klasor, '4_dar_pencere.png'));

    { Oneri listesi: ikinci kutuya (AD) yazilir; getirme beklemesinden sonra liste cikar. }
    Form.Width := 900;
    Satir.OnOneri := Gozlemci.Oner;
    for i := 0 to Form.ControlCount - 1 do
      if (Form.Controls[i] is TEdit) and (Form.Controls[i].Visible) and (TEdit(Form.Controls[i]).Tag = 1) then
      begin
        TEdit(Form.Controls[i]).SetFocus;
        TEdit(Form.Controls[i]).Text := 'ka';
        Writeln('kutu bulundu, tag=', TEdit(Form.Controls[i]).Tag, ' onchange atanmis=', Assigned(TEdit(Form.Controls[i]).OnChange), ' metin=', TEdit(Form.Controls[i]).Text);
      end;
    Bekle(1000);
    Writeln('oneri istegi sayisi: ', Gozlemci.OneriSayisi, ' uygula sayisi: ', Gozlemci.Sayac);
    Resim(Form, TPath.Combine(Klasor, '5_oneri.png'));

    Satir.Free;
  finally
    Form.Free;
    Gozlemci.Free;
  end;
end.
