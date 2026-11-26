program SonucGridTest;

{ Sorgu sonucu gridinin sag tik kopyalama yordamlari (uSonucGrid): Kopyala, Basliklarla kopyala,
  Kolonu IN listesi olarak kopyala. Veritabani gerekmez: bellekte tablo (TFDMemTable) gizli bir gride baglanir.
  Ortam: FBTEST_CIKTI (bos ise ekrana yazar). Cikis kodu: hata sayisi. }

{$APPTYPE CONSOLE}

uses
  Winapi.Windows, System.SysUtils, System.Classes, System.Variants, Data.DB, Vcl.Forms, Vcl.DBGrids, Vcl.Clipbrd,
  FireDAC.Stan.Intf, FireDAC.Stan.Option, FireDAC.Comp.DataSet, FireDAC.Comp.Client,
  uSonucGrid;

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

{ Pano baska bir program (pano izleyici) tarafindan kisa sure tutulabilir: pano islemleri birkac kez denenir. }
const
  DENEME = 40;

function Pano: string;
var
  i: Integer;
begin
  for i := 1 to DENEME do
    try
      Exit(Clipboard.AsText);
    except
      Sleep(50);
    end;
  Result := Clipboard.AsText;
end;

procedure PanoYaz(const Metin: string);
var
  i: Integer;
begin
  for i := 1 to DENEME do
    try
      Clipboard.AsText := Metin;
      Exit;
    except
      Sleep(50);
    end;
  Clipboard.AsText := Metin;
end;

function InKopyala(Sonuc: TSonucGrid; const Alan: string): Integer;
var
  i: Integer;
begin
  for i := 1 to DENEME do
    try
      Exit(Sonuc.KolonuInListesiKopyala(Alan));
    except
      Sleep(50);
    end;
  Result := Sonuc.KolonuInListesiKopyala(Alan);
end;

procedure Kopyala(Sonuc: TSonucGrid; Basliklarla: Boolean);
var
  i: Integer;
begin
  for i := 1 to DENEME do
    try
      Sonuc.SecimiKopyala(Basliklarla);
      Exit;
    except
      Sleep(50);
    end;
  Sonuc.SecimiKopyala(Basliklarla);
end;

procedure SatirEkle(Tablo: TFDMemTable; Id: Variant; const Ad: Variant; Tarih: Variant);
begin
  Tablo.Append;
  Tablo.FieldByName('ID').Value := Id;
  Tablo.FieldByName('AD').Value := Ad;
  Tablo.FieldByName('TARIH').Value := Tarih;
  Tablo.Post;
end;

procedure Dene;
var
  Form: TForm;
  Grid: TDBGrid;
  Kaynak: TDataSource;
  Tablo: TFDMemTable;
  Sonuc: TSonucGrid;
  Liste: TStringList;
  Sayi: Integer;
begin
  Liste := TStringList.Create;
  try
    Kontrol('Bos liste bos metin', InListesiMetni(Liste) = '');
    Liste.Add('1');
    Kontrol('Tek deger parantezli', InListesiMetni(Liste) = '(1)');
    Liste.Add('''a''');
    Kontrol('Iki deger virgulle', InListesiMetni(Liste) = '(1, ''a'')');
  finally
    Liste.Free;
  end;

  Form := TForm.CreateNew(nil);
  Tablo := TFDMemTable.Create(Form);
  Kaynak := TDataSource.Create(Form);
  try
    Tablo.FieldDefs.Add('ID', ftInteger);
    Tablo.FieldDefs.Add('AD', ftString, 30);
    Tablo.FieldDefs.Add('TARIH', ftDate);
    Tablo.FieldDefs.Add('VERI', ftBlob);
    Tablo.CreateDataSet;
    SatirEkle(Tablo, 1, 'Ali', EncodeDate(2026, 11, 26));
    SatirEkle(Tablo, 2, 'O''Brien', Null);
    SatirEkle(Tablo, 2, 'Ali', EncodeDate(2026, 11, 26));
    SatirEkle(Tablo, 3, Null, EncodeDate(2025, 1, 2));
    Kaynak.DataSet := Tablo;
    Grid := TDBGrid.Create(Form);
    Grid.Parent := Form;
    Grid.DataSource := Kaynak;
    Sonuc := TSonucGrid.Create(Grid);
    Sonuc.YeniSonuc;
    Kontrol('Grid dort kolon', Grid.Columns.Count = 4);

    Kontrol('Ikili BLOB IN listesine uygun degil', not InListesineUygunMu(Tablo.FieldByName('VERI')));
    Kontrol('Sayi IN listesine uygun', InListesineUygunMu(Tablo.FieldByName('ID')));
    Kontrol('nil uygun degil', not InListesineUygunMu(nil));

    Tablo.RecNo := 2;
    PanoYaz('X');
    Sayi := InKopyala(Sonuc, 'ID');
    Kontrol('ID: 3 farkli deger', Sayi = 3);
    Kontrol('ID: (1, 2, 3)', Pano = '(1, 2, 3)');
    Kontrol('Imlec yerinde kalir', Tablo.RecNo = 2);

    Sayi := InKopyala(Sonuc, 'AD');
    Kontrol('AD: NULL alinmaz, tekrar yok', Sayi = 2);
    Kontrol('AD: tirnak ikiye katlanir', Pano = '(''Ali'', ''O''''Brien'')');

    Sayi := InKopyala(Sonuc, 'TARIH');
    Kontrol('TARIH: 2 farkli tarih', Sayi = 2);
    Kontrol('TARIH: tarih SQL bicimi', Pano = '(''2026-11-26'', ''2025-01-02'')');
    if Pano <> '(''2026-11-26'', ''2025-01-02'')' then
      Cikti.Add('      pano: ' + Pano);

    PanoYaz('X');
    Kontrol('BLOB kolonu kopyalanmaz', InKopyala(Sonuc, 'VERI') = 0);
    Kontrol('Olmayan kolon kopyalanmaz', InKopyala(Sonuc, 'YOK') = 0);
    Kontrol('Pano degismedi', Pano = 'X');

    { Secili satir yokken aktif hucre: 2. satir, ilk kolon (ID). }
    Tablo.RecNo := 2;
    Grid.SelectedIndex := 1;
    Kopyala(Sonuc, False);
    Kontrol('Kopyala: aktif hucre', Pano = 'O''Brien');
    Kopyala(Sonuc, True);
    Kontrol('Basliklarla: kolon adi + deger', Pano = 'AD' + #13#10 + 'O''Brien');

    { Secili satirlar: basliklar sekmeyle ayrili ilk satirda. }
    Grid.SelectedRows.CurrentRowSelected := True;
    Kopyala(Sonuc, True);
    Kontrol('Basliklarla secili satir',
      Pano = 'ID'#9'AD'#9'TARIH'#9'VERI'#13#10 + '2'#9'O''Brien'#9#9#13#10);
    if Pano <> 'ID'#9'AD'#9'TARIH'#9'VERI'#13#10 + '2'#9'O''Brien'#9#9#13#10 then
      Cikti.Add('      pano: ' + StringReplace(Pano, #9, '<TAB>', [rfReplaceAll]));
    Kopyala(Sonuc, False);
    Kontrol('Basliksiz secili satir', Pano = '2'#9'O''Brien'#9#9#13#10);
  finally
    Form.Free;
  end;
end;

var
  CiktiYolu: string;
begin
  Cikti := TStringList.Create;
  Hatalar := 0;
  try
    Dene;
  except
    on E: Exception do
    begin
      Cikti.Add('BEKLENMEYEN HATA: ' + E.Message);
      Inc(Hatalar);
    end;
  end;
  Cikti.Add('Hata sayisi: ' + IntToStr(Hatalar));
  CiktiYolu := GetEnvironmentVariable('FBTEST_CIKTI');
  if CiktiYolu <> '' then
    Cikti.SaveToFile(CiktiYolu, TEncoding.UTF8)
  else
    Writeln(Cikti.Text);
  Cikti.Free;
  ExitCode := Hatalar;
end.
