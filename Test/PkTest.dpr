program PkTest;

{ Birincil anahtar (PRIMARY KEY) ekleme testi (uIndeksKisit.KisitUygula): bos olabilen kolona PK, tekrarlayan veriye PK,
  basarili PK. Gercek veriye dokunulmaz: kendi gecici veritabanini kurar, dosya silinmez.
  Ortam: FBTEST_SUNUCU (bos = yerel), FBTEST_PORT, FBTEST_KLASOR, FBTEST_KULLANICI, FBTEST_SIFRE, FBTEST_CIKTI.
  Cikis kodu: hata sayisi. }

{$APPTYPE CONSOLE}

uses
  System.SysUtils, System.Classes, System.IOUtils, Data.DB,
  FireDAC.Stan.Intf, FireDAC.Stan.Option, FireDAC.Stan.Error, FireDAC.Comp.Client, FireDAC.Phys.FB,
  FireDAC.ConsoleUI.Wait,
  uDil, uBaglanti, uSorgu, uMetadata, uProsedur, uIndeksKisit, uKolon;

var
  Cikti: TStringList;
  Hatalar: Integer;
  Bag: TAcikBaglanti;

function Ortam(const Ad, Varsayilan: string): string;
begin
  Result := GetEnvironmentVariable(Ad);
  if Result = '' then
    Result := Varsayilan;
end;

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

procedure Calistir(const Sql: string);
begin
  SorguCalistir(Bag, Sql).Free;
end;

function PkGirdisi(const Tablo, Kolon: string): TKisitGirdisi;
begin
  Result := Default(TKisitGirdisi);
  Result.Tablo := Tablo;
  Result.Tur := ktBirincil;
  Result.Kolonlar := Kolon;
end;

procedure Dene;
var
  S: TProsedurSonucu;
  Plan: TPkPlani;
  K: TKisitBilgisi;
  Var_: Boolean;
begin
  Calistir('CREATE TABLE T_BOS_OLUR (ID INTEGER, AD VARCHAR(20))');
  Calistir('INSERT INTO T_BOS_OLUR VALUES (1, ''a'')');
  S := KisitUygula(Bag, yiOlustur, PkGirdisi('T_BOS_OLUR', 'ID'));
  Cikti.Add('Bos olabilen kolona PK -> basarili: ' + BoolToStr(S.Basarili, True) + ' | cumle: ' + S.Cumle + ' | ham: ' + Copy(S.Ayrinti, 1, 200));
  Kontrol('Bos olabilen kolona elle PK: anlasilir cumle (NOT NULL once)', (not S.Basarili) and (S.Cumle = T('ERR_PK_BOS_OLUR')));

  Calistir('CREATE TABLE T_NOT_NULL (ID INTEGER NOT NULL, AD VARCHAR(20))');
  Calistir('INSERT INTO T_NOT_NULL VALUES (1, ''a'')');
  Calistir('INSERT INTO T_NOT_NULL VALUES (1, ''b'')');
  S := KisitUygula(Bag, yiOlustur, PkGirdisi('T_NOT_NULL', 'ID'));
  Cikti.Add('Tekrarlayan veriye PK -> basarili: ' + BoolToStr(S.Basarili, True) + ' | cumle: ' + S.Cumle);
  Kontrol('Tekrarlayan veriye PK: anlasilir cumle', (not S.Basarili) and (S.Cumle <> ''));

  Calistir('CREATE TABLE T_TAMAM (ID INTEGER NOT NULL, AD VARCHAR(20))');
  Calistir('INSERT INTO T_TAMAM VALUES (1, ''a'')');
  S := KisitUygula(Bag, yiOlustur, PkGirdisi('T_TAMAM', 'ID'));
  Kontrol('NOT NULL ve benzersiz kolona PK eklenir', S.Basarili);
  Var_ := False;
  for K in KisitlariOku(Bag, 'T_TAMAM') do
    if K.Tur = ktBirincil then
      Var_ := True;
  Kontrol('PK tabloda gorunur', Var_);

  { "Birincil anahtar yap" dugmesi (7o): plan ve uygulama }
  Calistir('CREATE TABLE T_PLAN (ID INTEGER, AD VARCHAR(20))');
  Calistir('INSERT INTO T_PLAN VALUES (1, ''a'')');
  Calistir('INSERT INTO T_PLAN VALUES (2, ''b'')');
  Plan := PkPlaniKur(Bag, 'T_PLAN', 'ID');
  Cikti.Add('Plan: engel=[' + Plan.Engel + '] komutlar=[' + StringReplace(Plan.Komutlar, sLineBreak, ' ', [rfReplaceAll]) + ']');
  Kontrol('Plan: bos olabilen kolonda NOT NULL gerekir, engel yok', (Plan.Engel = '') and Plan.NotNullGerek);
  Kontrol('Plan: komutlar once NOT NULL sonra PRIMARY KEY',
    (Pos('SET NOT NULL', Plan.Komutlar) > 0) and (Pos('PRIMARY KEY', Plan.Komutlar) > Pos('SET NOT NULL', Plan.Komutlar)));
  S := PkUygula(Bag, Plan);
  Cikti.Add('Plan uygula: basarili=' + BoolToStr(S.Basarili, True) + ' cumle=' + S.Cumle);
  Kontrol('Plan uygulandi', S.Basarili);
  Kontrol('Plan: iki komut gorunur (SQL karsiligi)', Length(S.Komutlar) >= 2);
  Var_ := False;
  for K in KisitlariOku(Bag, 'T_PLAN') do
    if K.Tur = ktBirincil then
      Var_ := True;
  Kontrol('Plan: PK olustu', Var_);
  Kontrol('Plan: kolon NOT NULL oldu', KolonGirdisiOku(Bag, 'T_PLAN', 'ID', kiDegistir).BosOlmaz);
  Plan := PkPlaniKur(Bag, 'T_PLAN', 'AD');
  Kontrol('Plan: tabloda zaten PK varsa engel (ERR_PK_VAR)', Plan.Engel = T('ERR_PK_VAR'));

  Calistir('CREATE TABLE T_PLAN_NOT_NULL (ID INTEGER NOT NULL, AD VARCHAR(20))');
  Plan := PkPlaniKur(Bag, 'T_PLAN_NOT_NULL', 'ID');
  Kontrol('Plan: zaten NOT NULL kolonda yalniz PRIMARY KEY komutu', (Plan.Engel = '') and (not Plan.NotNullGerek) and
    (Pos('SET NOT NULL', Plan.Komutlar) = 0) and (Pos('PRIMARY KEY', Plan.Komutlar) > 0));

  { Kolonda NULL deger varsa NOT NULL adimi hata verir, PK'ya gecilmez, tablo bozulmaz }
  Calistir('CREATE TABLE T_PLAN_NULL (ID INTEGER, AD VARCHAR(20))');
  Calistir('INSERT INTO T_PLAN_NULL (AD) VALUES (''x'')');
  Plan := PkPlaniKur(Bag, 'T_PLAN_NULL', 'ID');
  S := PkUygula(Bag, Plan);
  Cikti.Add('NULL veri: basarili=' + BoolToStr(S.Basarili, True) + ' cumle=' + S.Cumle + ' | ham: ' + StringReplace(Copy(S.Ayrinti, 1, 300), sLineBreak, ' ', [rfReplaceAll]));
  Kontrol('NULL veri: plan basarisiz, anlasilir cumle (bos degerleri doldurun)', (not S.Basarili) and (S.Cumle = T('ERR_KOLON_NULL_VAR')));
  Kontrol('NULL veri: kolon NOT NULL olmadi (geri alindi)', not KolonGirdisiOku(Bag, 'T_PLAN_NULL', 'ID', kiDegistir).BosOlmaz);
end;

var
  Tanim: TBaglantiTanimi;
  Klasor, Yol, CiktiYolu: string;
begin
  Cikti := TStringList.Create;
  Hatalar := 0;
  Bag := nil;
  try
    try
      DilYukle('tr');
      Klasor := Ortam('FBTEST_KLASOR', TPath.Combine(GetEnvironmentVariable('TEMP'), 'pktest'));
      if Ortam('FBTEST_SUNUCU', '') = '' then
        ForceDirectories(Klasor);
      Yol := IncludeTrailingPathDelimiter(Klasor) + 'pk_' + FormatDateTime('yyyymmdd_hhnnss', Now) + '.fdb';
      Tanim := Default(TBaglantiTanimi);
      Tanim.Ad := 'pktest';
      Tanim.Sunucu := Ortam('FBTEST_SUNUCU', '');
      Tanim.Port := StrToInt(Ortam('FBTEST_PORT', '3050'));
      Tanim.VeritabaniYolu := Yol;
      Tanim.Kullanici := Ortam('FBTEST_KULLANICI', 'SYSDBA');
      Tanim.Sifre := Ortam('FBTEST_SIFRE', '');
      Tanim.KarakterSeti := VARSAYILAN_KARAKTER_SETI;
      FbVeritabaniOlustur(Tanim);
      Bag := FbBaglan(Tanim);
      Cikti.Add('Gecici veritabani: ' + Yol + ' | Surum: ' + Bag.Surum);
      Dene;
    except
      on E: Exception do
      begin
        Cikti.Add('BEKLENMEYEN HATA: ' + E.Message);
        Inc(Hatalar);
      end;
    end;
  finally
    if Bag <> nil then
      FbBaglantiyiKes(Bag);
  end;
  Cikti.Add('Hata sayisi: ' + IntToStr(Hatalar));
  CiktiYolu := Ortam('FBTEST_CIKTI', '');
  if CiktiYolu <> '' then
    Cikti.SaveToFile(CiktiYolu, TEncoding.UTF8)
  else
    Writeln(Cikti.Text);
  Cikti.Free;
  ExitCode := Hatalar;
end.
