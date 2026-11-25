program EditorYorumTest;

{ Editorde Ctrl+/ (uEditor.YorumDegistir) testi: satirlari yorum yapma ve yorumu kaldirma. Veritabani gerekmez.
  Ortam: FBTEST_CIKTI (bos ise ekrana yazar). Cikis kodu: hata sayisi. }

{$APPTYPE CONSOLE}

uses
  System.SysUtils, System.Classes,
  uEditor;

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

function Esit(const A, B: TArray<string>): Boolean;
var
  i: Integer;
begin
  Result := Length(A) = Length(B);
  if Result then
    for i := 0 to High(A) do
      if A[i] <> B[i] then
        Exit(False);
end;

procedure Dene;
var
  S: TArray<string>;
begin
  Kontrol('Tek satir yorum olur', Esit(YorumDegistir(['SELECT 1']), ['-- SELECT 1']));
  Kontrol('Yorumlu satirin yorumu kalkar', Esit(YorumDegistir(['-- SELECT 1']), ['SELECT 1']));
  Kontrol('Bosluksuz "--" de kalkar', Esit(YorumDegistir(['--SELECT 1']), ['SELECT 1']));
  Kontrol('Girintili yorumda girinti korunur', Esit(YorumDegistir(['    -- AD,']), ['    AD,']));
  S := YorumDegistir(['SELECT *', '', 'FROM T']);
  Kontrol('Bos satira dokunulmaz', Esit(S, ['-- SELECT *', '', '-- FROM T']));
  Kontrol('Ileri geri ayni metne doner', Esit(YorumDegistir(S), ['SELECT *', '', 'FROM T']));
  Kontrol('Karisik secimde hepsi yorum olur (once yorum ekler)',
    Esit(YorumDegistir(['-- SELECT *', 'FROM T']), ['-- -- SELECT *', '-- FROM T']));
  Kontrol('Yalniz bos satirlar degismez', Esit(YorumDegistir(['', '  ']), ['', '  ']));
  Kontrol('Satir icindeki -- yorum sayilmaz, basa eklenir', Esit(YorumDegistir(['SELECT 1 -- not']), ['-- SELECT 1 -- not']));
  Kontrol('Yorum kaldirirken yalniz ilk -- silinir', Esit(YorumDegistir(['-- a -- b']), ['a -- b']));
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
