program SqlDosyaTest;

{ uSqlDosya testi (komut satiri, veritabani gerekmez): Turkce karakterli UTF-8 yazma/okuma,
  UTF-8 imli, UTF-16 imli ve ANSI (1254) dosyalarin dogru okunmasi, bos dosya, uzanti kontrolu.
  Ortam: FBTEST_CIKTI (sonuc dosyasi, bos ise ekrana). Cikis kodu: hata sayisi. }

{$APPTYPE CONSOLE}

uses
  Winapi.Windows, System.SysUtils, System.Classes, System.IOUtils,
  uSqlDosya;

const
  { Turkce karakterler kod sayfasindan bagimsiz olsun diye kodla yazilir: g s i I o u c. }
  TURKCE = 'select ''' + #$011F + #$015F + #$0131 + #$0130 + #$00F6 + #$00FC + #$00E7 + ''' from rdb$database;';

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

procedure BaytYaz(const Yol: string; const Ek: TBytes; Kodlama: TEncoding; const Metin: string);
var
  Veri: TBytes;
begin
  Veri := Ek + Kodlama.GetBytes(Metin);
  TFile.WriteAllBytes(Yol, Veri);
end;

var
  Klasor, Yol, CiktiYolu: string;
  Bayt: TBytes;
begin
  Cikti := TStringList.Create;
  Hatalar := 0;
  Klasor := TPath.Combine(TPath.GetTempPath, 'sqldosyatest_' + FormatDateTime('hhnnsszzz', Now));
  ForceDirectories(Klasor);
  try
    Yol := TPath.Combine(Klasor, 'a.sql');

    SqlDosyasiniYaz(Yol, TURKCE);
    Bayt := TFile.ReadAllBytes(Yol);
    Kontrol('Yazilan dosya imsiz UTF-8', (Length(Bayt) > 3) and not ((Bayt[0] = $EF) and (Bayt[1] = $BB)));
    Kontrol('Yaz/oku: Turkce karakterler ayni', SqlDosyasiniOku(Yol) = TURKCE);

    BaytYaz(Yol, [$EF, $BB, $BF], TEncoding.UTF8, TURKCE);
    Kontrol('UTF-8 imli: im metne girmez', SqlDosyasiniOku(Yol) = TURKCE);

    BaytYaz(Yol, [$FF, $FE], TEncoding.Unicode, TURKCE);
    Kontrol('UTF-16 imli okunur', SqlDosyasiniOku(Yol) = TURKCE);

    BaytYaz(Yol, [], TEncoding.UTF8, 'select 1 from rdb$database;' + sLineBreak + 'select 2 from rdb$database;');
    Kontrol('Imsiz saf ASCII UTF-8 sayilir', SqlDosyasiniOku(Yol) = 'select 1 from rdb$database;' + sLineBreak + 'select 2 from rdb$database;');

    { ANSI (1254): UTF-8 olarak gecersiz bayt dizisi; Turkce Windows'ta dogru, baska kod sayfasinda yalniz "okunur" kontrolu yapilir. }
    TFile.WriteAllBytes(Yol, [Ord('s'), Ord(' '), $FD, $DE, $F0]);
    Kontrol('Gecersiz UTF-8 (ANSI) hata vermez', Length(SqlDosyasiniOku(Yol)) = 5);
    if GetACP = 1254 then
      Kontrol('ANSI 1254: i, S, g dogru', SqlDosyasiniOku(Yol) = 's ' + #$0131 + #$015E + #$011F)
    else
      Cikti.Add('ATLANDI ANSI 1254 icerik kontrolu (Windows kod sayfasi ' + IntToStr(GetACP) + ')');

    TFile.WriteAllBytes(Yol, []);
    Kontrol('Bos dosya bos metin verir', SqlDosyasiniOku(Yol) = '');

    SqlDosyasiniYaz(Yol, TURKCE);
    SqlDosyasiniYaz(Yol, 'yeni');
    Kontrol('Var olan dosyanin ustune yazar (kisaltir)', SqlDosyasiniOku(Yol) = 'yeni');

    Kontrol('Uzanti .sql', SqlDosyasiMi('C:\x\Y.sql'));
    Kontrol('Uzanti .SQL buyuk harf', SqlDosyasiMi('c:\x\y.SQL'));
    Kontrol('Uzanti .txt degil', not SqlDosyasiMi('c:\x\y.txt'));
    Kontrol('Uzantisiz degil', not SqlDosyasiMi('c:\x\sql'));

    try
      SqlDosyasiniOku(TPath.Combine(Klasor, 'yok.sql'));
      Kontrol('Olmayan dosya istisna verir', False);
    except
      Kontrol('Olmayan dosya istisna verir', True);
    end;

    { Gecici klasor test sonunda silinmez (hicbir sey kendiliginden silinmez); temp'te kalir. }
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
