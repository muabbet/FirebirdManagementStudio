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

end.
