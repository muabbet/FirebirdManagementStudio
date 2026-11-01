unit uTopluGuncelle;

{ Bir UPDATE komutunu secilen birden cok veritabaninda onizleyip uygular (Asama 4c).

  Hedeflenen Firebird surumleri: 2.5, 3.0, 4.0, 5.0 (her veritabani kendi surumuyle konusur)

  Kurallar (sade ve guvenli):
    - Yalniz tek bir UPDATE komutu kabul edilir (INSERT/DELETE/DDL yok).
    - ONIZLEME: komut her veritabaninda kendi islemi (transaction) icinde calistirilir, etkilenen satir sayisi alinir ve
      islem GERI ALINIR; veri degismez. Not: tetikleyicinin dis etkileri (generator, dis dosya, UDF) geri alinmaz.
    - UYGULA: komut her veritabaninda ayri bir islemde calisir; basariliysa onaylanir (commit), hata varsa o veritabani
      geri alinir ve diger veritabanlari etkilenmez. Hangi veritabaninin ne yaptigi kayda yazilir.
    - Acik baglanti varsa o kullanilir (kendi ayri islemiyle, acik sekmelerin islemine karismaz); yoksa kayitli sifreyle
      GECICI baglanti acilir ve isi bitince kapatilir. Sifresi kayitli olmayan kapali baglanti atlanir.
  Hata istisna olarak firlamaz, her veritabaninin kaydina yazilir. }

interface

uses
  System.SysUtils, System.Classes, System.StrUtils, System.Diagnostics, System.RegularExpressions,
  FireDAC.Stan.Option, FireDAC.Comp.Client,
  uDil, uBaglanti, uSorgu, uCokluSorgu;

type
  TTopluDurum = (tdTamam, tdHata, tdAtlandi);

  { Bir veritabaninin sonucu: durum, etkilenen satir sayisi, sure, hata cumlesi (anlasilir) ve ham ayrinti. }
  TTopluKayit = record
    Ad: string;
    Durum: TTopluDurum;
    Satir: Integer;
    Sure: Int64;
    Cumle: string;
    Ayrinti: string;
  end;

{ Yazi tek bir UPDATE mi? Degilse anlasilir cumle, tamamsa bos. }
function TopluKontrol(const Sql: string): string;

{ UPDATE'de WHERE var mi (yorum ve '...' yazilari sayilmaz)? Yoksa tum satirlar degisir. }
function TopluWhereVar(const Sql: string): Boolean;

{ Veri degistirmeden: her veritabaninda komutu deneyip geri alir, etkilenen satir sayisini verir. }
function TopluOnizle(const Adlar: TArray<string>; const Sql: string; Ilerleme: TProc<string>): TArray<TTopluKayit>;

{ Komutu her veritabaninda ayri islemde uygular ve onaylar (commit). Cagiran once kullanicidan onay almis olmalidir. }
function TopluUygula(const Adlar: TArray<string>; const Sql: string; Ilerleme: TProc<string>): TArray<TTopluKayit>;

implementation

function TopluKontrol(const Sql: string): string;
var
  Komutlar: TArray<string>;
begin
  Result := '';
  Komutlar := KomutlaraBol(Sql);
  if Length(Komutlar) = 0 then
    Exit(T('ERR_SORGU_BOS'));
  if Length(Komutlar) > 1 then
    Exit(T('ERR_TOPLU_TEK_KOMUT'));
  if IlkSozcuk(Komutlar[0]) <> 'UPDATE' then
    Result := T('ERR_TOPLU_SADECE_UPDATE');
end;

{ Yorumlari ve tirnak icindeki yazilari atar (icinde "where" geciyor diye WHERE var sanilmasin). }
function YaziVeYorumuAt(const Sql: string): string;
var
  i: Integer;
  Tirnakta: Boolean;
begin
  Result := '';
  Tirnakta := False;
  i := 1;
  while i <= Length(Sql) do
  begin
    if Tirnakta then
    begin
      if Sql[i] = '''' then
        Tirnakta := False;
    end
    else if Sql[i] = '''' then
      Tirnakta := True
    else if Copy(Sql, i, 2) = '--' then
    begin
      while (i <= Length(Sql)) and not CharInSet(Sql[i], [#10, #13]) do
        Inc(i);
      Continue;
    end
    else if Copy(Sql, i, 2) = '/*' then
    begin
      Inc(i, 2);
      while (i < Length(Sql)) and (Copy(Sql, i, 2) <> '*/') do
        Inc(i);
      Inc(i, 2);
      Continue;
    end
    else
      Result := Result + Sql[i];
    Inc(i);
  end;
end;

function TopluWhereVar(const Sql: string): Boolean;
begin
  Result := TRegEx.IsMatch(YaziVeYorumuAt(Sql), '\bWHERE\b', [roIgnoreCase]);
end;

{ Bir veritabaninda calistirir. Uygula True ise onaylar, degilse geri alir. Hata istisna olarak gelir. }
function BirindeCalistir(Bag: TAcikBaglanti; const Sql: string; Uygula: Boolean): Integer;
var
  Islem: TFDTransaction;
  Sorgu: TFDQuery;
begin
  Islem := TFDTransaction.Create(nil);
  Sorgu := TFDQuery.Create(nil);
  try
    Islem.Connection := Bag.Baglanti;
    Islem.Options.AutoCommit := False;
    Sorgu.Connection := Bag.Baglanti;
    Sorgu.Transaction := Islem;
    { Yazilan komut oldugu gibi gitsin: ':ad' parametre, '!ad' makro, suslu parantez sayilmasin. }
    Sorgu.ResourceOptions.ParamCreate := False;
    Sorgu.ResourceOptions.MacroCreate := False;
    Sorgu.ResourceOptions.MacroExpand := False;
    Sorgu.ResourceOptions.EscapeExpand := False;
    Sorgu.SQL.Text := Sql;
    Islem.StartTransaction;
    try
      Sorgu.ExecSQL;
      Result := Sorgu.RowsAffected;
      if Uygula then
        Islem.Commit
      else
        Islem.Rollback;
    except
      try
        if Islem.Active then
          Islem.Rollback;
      except
        { Rollback da basarisiz olursa asil hata gosterilir. }
      end;
      raise;
    end;
  finally
    Sorgu.Free;
    Islem.Free;
  end;
end;

function HepsindeCalistir(const Adlar: TArray<string>; const Sql: string; Uygula: Boolean;
  Ilerleme: TProc<string>): TArray<TTopluKayit>;
var
  Ad: string;
  Kayit: TTopluKayit;
  Tanim: TBaglantiTanimi;
  Bag: TAcikBaglanti;
  Gecici: Boolean;
  Saat: TStopwatch;
begin
  SetLength(Result, 0);
  for Ad in Adlar do
  begin
    if Assigned(Ilerleme) then
      Ilerleme(Ad);
    Kayit := Default(TTopluKayit);
    Kayit.Ad := Ad;
    Bag := FbAcikBaglanti(Ad);
    Gecici := False;
    Saat := TStopwatch.StartNew;
    try
      try
        if Bag = nil then
        begin
          if not KayitliBaglantiBul(Ad, Tanim) or (Tanim.Sifre = '') then
          begin
            Kayit.Durum := tdAtlandi;
            Kayit.Cumle := T('COKLU_SIFRE_YOK');
            Continue;
          end;
          Bag := FbGeciciBaglan(Tanim);
          Gecici := True;
        end;
        Kayit.Satir := BirindeCalistir(Bag, Sql, Uygula);
        Kayit.Durum := tdTamam;
        Kayit.Sure := Saat.ElapsedMilliseconds;
      except
        on E: Exception do
        begin
          Kayit.Durum := tdHata;
          Kayit.Cumle := HataMetniniCevir(E);
          Kayit.Ayrinti := E.Message;
        end;
      end;
    finally
      if Gecici then
        Bag.Free;
      Result := Result + [Kayit];
    end;
  end;
end;

function TopluOnizle(const Adlar: TArray<string>; const Sql: string; Ilerleme: TProc<string>): TArray<TTopluKayit>;
begin
  Result := HepsindeCalistir(Adlar, Sql, False, Ilerleme);
end;

function TopluUygula(const Adlar: TArray<string>; const Sql: string; Ilerleme: TProc<string>): TArray<TTopluKayit>;
begin
  Result := HepsindeCalistir(Adlar, Sql, True, Ilerleme);
end;

end.
