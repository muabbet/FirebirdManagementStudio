{ uSorgu.pas - SQL calistirma.

  Tablo sekmesi: bir tablonun ilk satirlarini getirir (salt okunur).
  Sorgu sekmesi: yazilan tek bir SQL komutunu calistirir. SELECT ise sonuc
  SATIR_PARCASI'ser satir cekilir, kullanici asagi indikce devami gelir (FireDAC
  fmOnDemand). Komut baska bir sey ise (INSERT, UPDATE, DDL ...) etkilenen satir
  sayisi doner.

  Islem davranisi aciktir: her sorgu sekmesinin kendi islemi vardir ve
  OTOMATIK ONAY (autocommit) kullanilir; komut bitince commit olur. Boylece
  bir sekmede acik kalan sonuc, baska sekmenin komutundan etkilenmez.
  Tehlikeli komutlar (DROP, WHERE'siz DELETE/UPDATE) icin TehlikeliSorguUyarisi
  ile onay anahtari alinir; onayi isteyen yer arayuzdur. }
unit uSorgu;

interface

uses
  System.SysUtils, System.Classes, System.Diagnostics, System.RegularExpressions,
  Data.DB,
  FireDAC.Stan.Intf, FireDAC.Stan.Option, FireDAC.Stan.Param, FireDAC.Stan.Error,
  FireDAC.DatS, FireDAC.Phys.Intf, FireDAC.DApt.Intf, FireDAC.Comp.DataSet,
  FireDAC.Comp.Client,
  uBaglanti;

const
  ILK_SATIR_SAYISI = 100;
  SATIR_PARCASI = 500;

type
  { Bir sorgu sekmesinin son sonucu. Sekme sonucu serbest birakinca sorgu kapanir. }
  TSorguSonucu = class
  public
    Sorgu: TFDQuery;
    Islem: TFDTransaction;
    SatirVar: Boolean;
    Etkilenen: Integer;
    Sure: Int64;
    destructor Destroy; override;
  end;

function TabloVerisiSorgusu(Bag: TAcikBaglanti; const Tablo: string; SatirSayisi: Integer;
  Sahip: TComponent): TFDQuery;

{ Yazilan komutu calistirir. Hata olursa istisna firlar, cagiran HataMetniniCevir ile gosterir. }
function SorguCalistir(Bag: TAcikBaglanti; const Sql: string): TSorguSonucu;

{ Komut tehlikeliyse dil anahtarini ('ONAY_SORGU_...') verir, degilse bos doner. }
function TehlikeliSorguUyarisi(const Sql: string): string;

implementation

function TirnakliAd(const Ad: string): string;
begin
  Result := '"' + StringReplace(Ad, '"', '""', [rfReplaceAll]) + '"';
end;

destructor TSorguSonucu.Destroy;
begin
  Sorgu.Free;
  Islem.Free;
  inherited;
end;

{ Sondaki bosluk ve noktali virgulleri atar (Firebird komutun sonundaki ';' i kabul etmez). }
function SonNoktaliVirgulleriAt(const Sql: string): string;
begin
  Result := Trim(Sql);
  while (Result <> '') and (Result[Length(Result)] = ';') do
    Result := Trim(Copy(Result, 1, Length(Result) - 1));
end;

{ Yorumlari ve tirnak icindeki yazilari bosluga cevirir. Boylece 'DROP' kelimesi
  bir yazinin icinde gecince yanlis uyari cikmaz. }
function YorumlariVeYazilariAt(const Sql: string): string;
var
  i, Boy: Integer;
  Tirnak: Char;
begin
  Result := '';
  Boy := Length(Sql);
  i := 1;
  while i <= Boy do
  begin
    if (Sql[i] = '-') and (i < Boy) and (Sql[i + 1] = '-') then
    begin
      while (i <= Boy) and (Sql[i] <> #10) do
        Inc(i);
    end
    else if (Sql[i] = '/') and (i < Boy) and (Sql[i + 1] = '*') then
    begin
      Inc(i, 2);
      while (i < Boy) and not ((Sql[i] = '*') and (Sql[i + 1] = '/')) do
        Inc(i);
      Inc(i, 2);
      Result := Result + ' ';
    end
    else if (Sql[i] = '''') or (Sql[i] = '"') then
    begin
      Tirnak := Sql[i];
      Inc(i);
      while (i <= Boy) and (Sql[i] <> Tirnak) do
        Inc(i);
      Inc(i);
      Result := Result + ' ';
    end
    else
    begin
      Result := Result + Sql[i];
      Inc(i);
    end;
  end;
end;

function TehlikeliSorguUyarisi(const Sql: string): string;
var
  Yalin: string;
begin
  Result := '';
  Yalin := YorumlariVeYazilariAt(Sql);
  if TRegEx.IsMatch(Yalin, '\bDROP\b', [roIgnoreCase]) then
    Result := 'ONAY_SORGU_DROP'
  else if TRegEx.IsMatch(Yalin, '^\s*(DELETE|UPDATE)\b', [roIgnoreCase]) and
    not TRegEx.IsMatch(Yalin, '^\s*UPDATE\s+OR\b', [roIgnoreCase]) and
    not TRegEx.IsMatch(Yalin, '\bWHERE\b', [roIgnoreCase]) then
    Result := 'ONAY_SORGU_WHERE_YOK';
end;

function SorguCalistir(Bag: TAcikBaglanti; const Sql: string): TSorguSonucu;
var
  Saat: TStopwatch;
begin
  Result := TSorguSonucu.Create;
  try
    Result.Islem := TFDTransaction.Create(nil);
    Result.Islem.Connection := Bag.Baglanti;
    Result.Islem.Options.AutoCommit := True;
    Result.Sorgu := TFDQuery.Create(nil);
    Result.Sorgu.Connection := Bag.Baglanti;
    Result.Sorgu.Transaction := Result.Islem;
    { Yazilan komut oldugu gibi gitsin: ':ad' parametre, '!ad' makro sayilmasin. }
    Result.Sorgu.ResourceOptions.ParamCreate := False;
    Result.Sorgu.ResourceOptions.MacroCreate := False;
    Result.Sorgu.ResourceOptions.MacroExpand := False;
    Result.Sorgu.ResourceOptions.EscapeExpand := False;
    Result.Sorgu.FetchOptions.Mode := fmOnDemand;
    Result.Sorgu.FetchOptions.RowsetSize := SATIR_PARCASI;
    Result.Sorgu.SQL.Text := SonNoktaliVirgulleriAt(Sql);
    Saat := TStopwatch.StartNew;
    Result.Sorgu.OpenOrExecute;
    Result.Sure := Saat.ElapsedMilliseconds;
    Result.SatirVar := Result.Sorgu.Active;
    if Result.SatirVar then
      Result.Etkilenen := 0
    else
      Result.Etkilenen := Result.Sorgu.RowsAffected;
  except
    Result.Free;
    raise;
  end;
end;

{ Sorgu, Sahip ile birlikte yok olur. Sorgu salt okunurdur. }
function TabloVerisiSorgusu(Bag: TAcikBaglanti; const Tablo: string; SatirSayisi: Integer;
  Sahip: TComponent): TFDQuery;
begin
  Result := TFDQuery.Create(Sahip);
  try
    Result.Connection := Bag.Baglanti;
    Result.UpdateOptions.ReadOnly := True;
    { En fazla 100 satir hepsi birden cekilir. Boylece okuma isleminin sunucuda
      acik kalmasi onlenir (sorgu sekmesi parca parca ceker, bkz. SorguCalistir). }
    Result.FetchOptions.Mode := fmAll;
    Result.SQL.Text := 'SELECT FIRST ' + IntToStr(SatirSayisi) + ' * FROM ' + TirnakliAd(Tablo);
    Result.Open;
  except
    Result.Free;
    raise;
  end;
end;

end.
