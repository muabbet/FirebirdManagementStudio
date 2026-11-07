program BaglanOlcum;

{ Baglanma suresi olcumu (komut satiri): karakter seti algilama, asil baglanti ve yedi dalin metadata okumalari ayri ayri olculur.
  Ortam: FBTEST_SUNUCU, FBTEST_PORT, FBTEST_YOL (sunucudaki veritabani yolu), FBTEST_KULLANICI, FBTEST_SIFRE. }

{$APPTYPE CONSOLE}

uses
  System.SysUtils, System.Classes, System.Diagnostics, FireDAC.Stan.Intf, FireDAC.Comp.Client, FireDAC.Phys.FB,
  FireDAC.ConsoleUI.Wait, uDil, uBaglanti, uMetadata;

var
  T0: TStopwatch;
  Tanim: TBaglantiTanimi;
  Bag: TAcikBaglanti;
  Liste: TStringList;
  Bulunan: string;

function Ortam(const Ad, Varsayilan: string): string;
begin
  Result := GetEnvironmentVariable(Ad);
  if Result = '' then
    Result := Varsayilan;
end;

procedure Say(const Ad: string);
begin
  Writeln(Format('%-34s %6d ms', [Ad, T0.ElapsedMilliseconds]));
  T0 := TStopwatch.StartNew;
end;

begin
  DilYukle('tr');
  Tanim := Default(TBaglantiTanimi);
  Tanim.Ad := 'olcum';
  Tanim.Sunucu := Ortam('FBTEST_SUNUCU', 'localhost');
  Tanim.Port := StrToInt(Ortam('FBTEST_PORT', '3050'));
  Tanim.VeritabaniYolu := Ortam('FBTEST_YOL', '');
  Tanim.Kullanici := Ortam('FBTEST_KULLANICI', 'SYSDBA');
  Tanim.Sifre := Ortam('FBTEST_SIFRE', '');
  Tanim.KarakterSeti := VARSAYILAN_KARAKTER_SETI;
  Liste := TStringList.Create;
  try
    T0 := TStopwatch.StartNew;
    Bulunan := KarakterSetiAlgila(Tanim);
    Say('karakter seti algilama (' + Bulunan + ')');
    Bulunan := KarakterSetiAlgila(Tanim);
    Say('karakter seti algilama (2. kez)');
    Bag := FbBaglan(Tanim);
    Say('FbBaglan (algilama dahil, surum ' + Bag.Surum + ')');
    TablolariGetir(Bag, Liste);
    Say('tablolar (' + IntToStr(Liste.Count) + ')');
    ViewlariGetir(Bag, Liste);
    Say('view''lar (' + IntToStr(Liste.Count) + ')');
    ProsedurleriGetir(Bag, Liste);
    Say('prosedurler (' + IntToStr(Liste.Count) + ')');
    TetikleyicileriListele(Bag);
    Say('tetikleyiciler');
    DomainleriGetir(Bag, Liste);
    Say('domain''ler (' + IntToStr(Liste.Count) + ')');
    IstisnalariGetir(Bag, Liste);
    Say('istisnalar (' + IntToStr(Liste.Count) + ')');
    GeneratorleriGetir(Bag, Liste);
    Say('generator''ler (' + IntToStr(Liste.Count) + ')');
    FbBaglantiyiKes(Bag);
  finally
    Liste.Free;
  end;
end.
