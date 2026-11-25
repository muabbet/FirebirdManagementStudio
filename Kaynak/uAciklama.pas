{ uAciklama.pas - Tablo ve kolon aciklamasi (COMMENT ON) okuma ve yazma (Kolonlar sekmesi > Aciklama).

  COMMENT ON TABLE / COLUMN Firebird 2.5, 3.0, 4.0 ve 5.0'in hepsinde ayni calisir. Bos metin aciklamayi kaldirir
  (IS NULL). Komut tek acik islemde calisir (hata olursa hicbir sey kalmaz). Tablo yapisi yedeklenmez: yalniz aciklama
  metni degisir, tabloya ve veriye dokunulmaz. }
unit uAciklama;

interface

uses
  System.SysUtils, System.Classes,
  FireDAC.Comp.Client,
  uBaglanti, uMetadata, uProsedur, uDDL;

{ Tablonun aciklamasi; yoksa bos. }
function TabloAciklamasiOku(Bag: TAcikBaglanti; const Tablo: string): string;
{ Kolonun aciklamasi; yoksa bos. }
function KolonAciklamasiOku(Bag: TAcikBaglanti; const Tablo, Kolon: string): string;
{ COMMENT ON TABLE ad IS '...'; (Metin bos ise IS NULL). Kolon bos degilse COMMENT ON COLUMN tablo.kolon. }
function AciklamaKomutu(Bag: TAcikBaglanti; const Tablo, Kolon, Metin: string): string;
{ Komutu tek islemde calistirir; calisan komut Sonuc.Komutlar'a yazilir. }
function AciklamaYaz(Bag: TAcikBaglanti; const Tablo, Kolon, Metin: string): TProsedurSonucu;

{ Agactaki bir nesnenin (tablo, view, prosedur, trigger, domain, exception, generator) aciklamasi; yoksa bos. }
function NesneAciklamasiOku(Bag: TAcikBaglanti; Tur: TNesneTuru; const Ad: string): string;
{ COMMENT ON TABLE|VIEW|PROCEDURE|TRIGGER|DOMAIN|EXCEPTION|GENERATOR ad IS '...'; (Metin bos ise IS NULL). }
function NesneAciklamaKomutu(Bag: TAcikBaglanti; Tur: TNesneTuru; const Ad, Metin: string): string;
{ Komutu tek islemde calistirir; calisan komut Sonuc.Komutlar'a yazilir. }
function NesneAciklamaYaz(Bag: TAcikBaglanti; Tur: TNesneTuru; const Ad, Metin: string): TProsedurSonucu;

implementation

function Sabit(const Metin: string): string;
begin
  Result := '''' + StringReplace(Metin, '''', '''''', [rfReplaceAll]) + '''';
end;

{ Ilk satirin METIN alani; satir yoksa ''. Adlar yazi sabiti olarak gider (RDB$ adlari CHAR, bosluk fark etmez). }
function MetinOku(Bag: TAcikBaglanti; const Sql: string): string;
var
  Sorgu: TFDQuery;
begin
  Result := '';
  Sorgu := TFDQuery.Create(nil);
  try
    Sorgu.Connection := Bag.Baglanti;
    Sorgu.SQL.Text := Sql;
    Sorgu.Open;
    if not Sorgu.Eof then
      Result := Sorgu.FieldByName('METIN').AsString;
  finally
    Sorgu.Free;
  end;
end;

function TabloAciklamasiOku(Bag: TAcikBaglanti; const Tablo: string): string;
begin
  Result := MetinOku(Bag, 'select rdb$description as METIN from rdb$relations where rdb$relation_name = ' +
    Sabit(Tablo));
end;

function KolonAciklamasiOku(Bag: TAcikBaglanti; const Tablo, Kolon: string): string;
begin
  Result := MetinOku(Bag, 'select rdb$description as METIN from rdb$relation_fields where rdb$relation_name = ' +
    Sabit(Tablo) + ' and rdb$field_name = ' + Sabit(Kolon));
end;

function AciklamaKomutu(Bag: TAcikBaglanti; const Tablo, Kolon, Metin: string): string;
var
  Deger: string;
begin
  if Metin = '' then
    Deger := 'NULL'
  else
    Deger := Sabit(Metin);
  if Kolon = '' then
    Result := 'COMMENT ON TABLE ' + AdiYaz(Bag, Tablo) + ' IS ' + Deger + ';'
  else
    Result := 'COMMENT ON COLUMN ' + AdiYaz(Bag, Tablo) + '.' + AdiYaz(Bag, Kolon) + ' IS ' + Deger + ';';
end;

function AciklamaYaz(Bag: TAcikBaglanti; const Tablo, Kolon, Metin: string): TProsedurSonucu;
begin
  Result := Default(TProsedurSonucu);
  MetniCalistir(Bag, AciklamaKomutu(Bag, Tablo, Kolon, Metin), Result);
end;

function NesneAciklamasiOku(Bag: TAcikBaglanti; Tur: TNesneTuru; const Ad: string): string;
var
  Tablo, Alan: string;
begin
  case Tur of
    ntTablo, ntView:
      begin
        Tablo := 'rdb$relations';
        Alan := 'rdb$relation_name';
      end;
    ntProsedur:
      begin
        Tablo := 'rdb$procedures';
        Alan := 'rdb$procedure_name';
      end;
    ntTetikleyici:
      begin
        Tablo := 'rdb$triggers';
        Alan := 'rdb$trigger_name';
      end;
    ntDomain:
      begin
        Tablo := 'rdb$fields';
        Alan := 'rdb$field_name';
      end;
    ntIstisna:
      begin
        Tablo := 'rdb$exceptions';
        Alan := 'rdb$exception_name';
      end;
  else
    begin
      Tablo := 'rdb$generators';
      Alan := 'rdb$generator_name';
    end;
  end;
  Result := MetinOku(Bag, 'select rdb$description as METIN from ' + Tablo + ' where ' + Alan + ' = ' + Sabit(Ad));
end;

function NesneAciklamaKomutu(Bag: TAcikBaglanti; Tur: TNesneTuru; const Ad, Metin: string): string;
var
  Anahtar, Deger: string;
begin
  case Tur of
    ntTablo: Anahtar := 'TABLE';
    ntView: Anahtar := 'VIEW';
    ntProsedur: Anahtar := 'PROCEDURE';
    ntTetikleyici: Anahtar := 'TRIGGER';
    ntDomain: Anahtar := 'DOMAIN';
    ntIstisna: Anahtar := 'EXCEPTION';
  else
    Anahtar := 'GENERATOR';
  end;
  if Metin = '' then
    Deger := 'NULL'
  else
    Deger := Sabit(Metin);
  Result := 'COMMENT ON ' + Anahtar + ' ' + AdiYaz(Bag, Ad) + ' IS ' + Deger + ';';
end;

function NesneAciklamaYaz(Bag: TAcikBaglanti; Tur: TNesneTuru; const Ad, Metin: string): TProsedurSonucu;
begin
  Result := Default(TProsedurSonucu);
  MetniCalistir(Bag, NesneAciklamaKomutu(Bag, Tur, Ad, Metin), Result);
end;

end.
