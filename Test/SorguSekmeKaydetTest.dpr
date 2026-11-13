program SorguSekmeKaydetTest;

{ SQL dosyasi kaydetme ve "kaydedilmemis degisiklik" isaretinin testi (veritabani gerekmez): bir sorgu sekmesi
  (frame) kurar; dosyasi olmayan, dosyasi olan, degisen, kaydedilen sekmede KaydedilmemisMi'yi dener.
  Ortam: FBTEST_CIKTI (sonuc dosyasi, bos ise ekrana). Cikis kodu: hata sayisi. }

{$APPTYPE CONSOLE}

uses
  Winapi.Windows, System.SysUtils, System.Classes, System.IOUtils, Vcl.Forms, Vcl.Controls,
  uDil, uSqlDosya, fSorguSekme;

var
  Cikti: TStringList;
  Hatalar: Integer;

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

var
  Form: TForm;
  Sekme: TSorguSekme;
  Klasor, Yol, CiktiYolu: string;
begin
  Cikti := TStringList.Create;
  Hatalar := 0;
  Application.Initialize;
  Form := TForm.CreateNew(Application);
  try
    Form.Width := 800;
    Form.Height := 600;
    Sekme := TSorguSekme.Create(Form);
    Sekme.Parent := Form;
    Sekme.Align := alClient;
    Sekme.Hazirla(1, 'deneme');
    Form.Show;
    Application.ProcessMessages;

    Klasor := TPath.Combine(TPath.GetTempPath, 'sqlkaydet_' + FormatDateTime('hhnnsszzz', Now));
    ForceDirectories(Klasor);
    Yol := TPath.Combine(Klasor, 'sorgu.sql');

    Sekme.MetinYaz('select 1 from rdb$database;');
    Kontrol('Dosyasi olmayan sekme: kaydedilmemis sayilmaz', not Sekme.KaydedilmemisMi);
    Kontrol('Baslik dosyasizken "Sorgu 1 [deneme]" bicimi', Pos('[deneme]', Sekme.Baslik) > 0);

    Sekme.Dosya := Yol;
    Sekme.DegisimiSifirla;
    Kontrol('Dosyasi var, degismemis: sorulmaz', not Sekme.KaydedilmemisMi);
    Kontrol('Baslik dosya adi', Pos('sorgu.sql [deneme]', Sekme.Baslik) = 1);

    Sekme.MetinYaz('select 2 from rdb$database;');
    Kontrol('Yazi degisince kaydedilmemis', Sekme.KaydedilmemisMi);

    Kontrol('Kaydet (dosya bilinen) sormadan yazar', Sekme.SqlKaydet(False));
    Kontrol('Dosya icerigi yazilan metin', SqlDosyasiniOku(Yol) = 'select 2 from rdb$database;');
    Kontrol('Kaydedince isaret kalkar', not Sekme.KaydedilmemisMi);

    Sekme.MetinYaz('select 3 from rdb$database;');
    Kontrol('Tekrar degisince isaret doner', Sekme.KaydedilmemisMi);
    Kontrol('Kaydetmeden dosya eski kalir', SqlDosyasiniOku(Yol) = 'select 2 from rdb$database;');

    Form.Free;
  except
    on E: Exception do
    begin
      Cikti.Add('HATA  Beklenmeyen istisna: ' + E.Message);
      Inc(Hatalar);
    end;
  end;
  Cikti.Add(IntToStr(Hatalar) + ' hata');
  CiktiYolu := GetEnvironmentVariable('FBTEST_CIKTI');
  if CiktiYolu <> '' then
    Cikti.SaveToFile(CiktiYolu, TEncoding.UTF8)
  else
    Writeln(Cikti.Text);
  Cikti.Free;
  ExitCode := Hatalar;
end.
