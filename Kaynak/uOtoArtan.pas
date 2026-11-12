{ uOtoArtan.pas - Var olan tam sayi kolonunu "otomatik artan" yapma (Kolonlar sekmesi > Otomatik artan yap).

  Firebird'de var olan kolon sonradan IDENTITY yapilamaz (IDENTITY yalniz CREATE TABLE'da, 3.0 ve ustu). Her surumde
  (2.5, 3.0, 4.0, 5.0) calisan standart yol kullanilir: bir generator ve BEFORE INSERT trigger'i. Kolon bos gelirse
  trigger generator'dan siradaki sayiyi yazar; deger verilirse ona dokunmaz. Generator, kolondaki en buyuk degerden
  baslar (mevcut kayitlarla cakismasin). Her sey tek acik islemde calisir (hata olursa hicbiri kalmaz); once tablonun
  yapisi yedeklenir (uProsedur). Hicbir sey silinmez, kolonun kendisi degismez. }
unit uOtoArtan;

interface

uses
  System.SysUtils, System.Classes, System.StrUtils,
  uDil, uBaglanti, uMetadata, uDDL, uProsedur, uSorgu, uKolon, uTabloTasarim;

type
  { Engel doluysa is yapilamaz (anlasilir cumle). Komutlar: onay penceresinde gosterilecek komutlar (SET TERM'siz).
    Betik: calisacak tam metin (SET TERM'li). }
  TOtoPlani = record
    Tablo: string;
    Kolon: string;
    GeneratorAdi: string;
    TetikleyiciAdi: string;
    EnBuyuk: Int64;
    Engel: string;
    Komutlar: string;
    Betik: string;
  end;

{ Plan: tablo ve kolon tam sayi tipinde, hesaplanan ve zaten otomatik artan degil, adlar bos olmali. }
function OtoPlaniKur(Bag: TAcikBaglanti; const Tablo, Kolon: string): TOtoPlani;
{ Plani uygular: tablo yapisi yedeklenir, sonra generator + ayar + trigger tek islemde. }
function OtoUygula(Bag: TAcikBaglanti; const Plan: TOtoPlani): TProsedurSonucu;
{ Onay penceresinin metni: komutlar, "yeni kayitta kolon bos birakilirsa sira numarasi verilir" aciklamasi, yedek bilgisi. }
function OtoOnayMetni(const Plan: TOtoPlani): string;

implementation

const
  { Firebird 2.5 ve 3.0'da en uzun nesne adi 31 karakter. }
  EN_UZUN_AD = 31;

function Kisalt(const Ad: string): string;
begin
  Result := Copy(Ad, 1, EN_UZUN_AD);
end;

function OtoPlaniKur(Bag: TAcikBaglanti; const Tablo, Kolon: string): TOtoPlani;
var
  Eski: TKolonGirdisi;
  Bilgi: TTabloBilgisi;
  K: TKolonBilgisi;
  Adlar: TStringList;
  Trg: TTetikleyiciBilgisi;
  Ozet: TKolonOzeti;
  Ad: string;
begin
  Result := Default(TOtoPlani);
  Result.Tablo := Tablo;
  Result.Kolon := Kolon;
  try
    Eski := KolonGirdisiOku(Bag, Tablo, Kolon, kiDegistir);
  except
    on E: EMetadataHatasi do
    begin
      Result.Engel := E.Message;
      Exit;
    end;
  end;
  if not TasarimTamSayiMi(Eski.Tip) then
  begin
    Result.Engel := TF('ERR_OTO_TIP', [Kolon]);
    Exit;
  end;
  Bilgi := TabloBilgisiOku(Bag, Tablo);
  for K in Bilgi.Kolonlar do
    if SameText(K.Ad, Kolon) and K.Kimlik then
    begin
      Result.Engel := TF('ERR_OTO_ZATEN', [Kolon]);
      Exit;
    end;
  Result.GeneratorAdi := Kisalt('GEN_' + Tablo + '_' + Kolon);
  Result.TetikleyiciAdi := Kisalt('TR_' + Tablo + '_' + Kolon + '_BI');
  { Adlar zaten varsa baska nesneye dokunulmasin. }
  Adlar := TStringList.Create;
  try
    GeneratorleriGetir(Bag, Adlar);
    for Ad in Adlar do
      if SameText(Ad, Result.GeneratorAdi) then
      begin
        Result.Engel := TF('ERR_OTO_AD_VAR', [Result.GeneratorAdi]);
        Exit;
      end;
  finally
    Adlar.Free;
  end;
  for Trg in Bilgi.Tetikleyiciler do
    if SameText(Trg.Ad, Result.TetikleyiciAdi) then
    begin
      Result.Engel := TF('ERR_OTO_AD_VAR', [Result.TetikleyiciAdi]);
      Exit;
    end;
  { Generator kolondaki en buyuk degerden baslar; ilk otomatik deger onun bir fazlasi olur. }
  try
    Ozet := KolonOzeti(Bag, Tablo, Kolon, okAralik, '');
    Result.EnBuyuk := StrToInt64Def(Ozet.EnBuyuk, 0);
  except
    on E: Exception do
    begin
      Result.Engel := HataMetniniCevir(E);
      Exit;
    end;
  end;
  if Result.EnBuyuk < 0 then
    Result.EnBuyuk := 0;
  Result.Komutlar := 'CREATE GENERATOR ' + AdiYaz(Bag, Result.GeneratorAdi) + ';' + sLineBreak +
    'SET GENERATOR ' + AdiYaz(Bag, Result.GeneratorAdi) + ' TO ' + IntToStr(Result.EnBuyuk) + ';' + sLineBreak +
    'CREATE TRIGGER ' + AdiYaz(Bag, Result.TetikleyiciAdi) + ' FOR ' + AdiYaz(Bag, Tablo) +
    ' ACTIVE BEFORE INSERT POSITION 0' + sLineBreak +
    'AS' + sLineBreak + 'BEGIN' + sLineBreak +
    '  IF (NEW.' + AdiYaz(Bag, Kolon) + ' IS NULL) THEN' + sLineBreak +
    '    NEW.' + AdiYaz(Bag, Kolon) + ' = GEN_ID(' + AdiYaz(Bag, Result.GeneratorAdi) + ', 1);' + sLineBreak +
    'END';
  Result.Betik := 'CREATE GENERATOR ' + AdiYaz(Bag, Result.GeneratorAdi) + ';' + sLineBreak +
    'SET GENERATOR ' + AdiYaz(Bag, Result.GeneratorAdi) + ' TO ' + IntToStr(Result.EnBuyuk) + ';' + sLineBreak +
    'SET TERM ^ ;' + sLineBreak +
    'CREATE TRIGGER ' + AdiYaz(Bag, Result.TetikleyiciAdi) + ' FOR ' + AdiYaz(Bag, Tablo) +
    ' ACTIVE BEFORE INSERT POSITION 0' + sLineBreak +
    'AS' + sLineBreak + 'BEGIN' + sLineBreak +
    '  IF (NEW.' + AdiYaz(Bag, Kolon) + ' IS NULL) THEN' + sLineBreak +
    '    NEW.' + AdiYaz(Bag, Kolon) + ' = GEN_ID(' + AdiYaz(Bag, Result.GeneratorAdi) + ', 1);' + sLineBreak +
    'END^' + sLineBreak + 'SET TERM ; ^';
end;

function OtoOnayMetni(const Plan: TOtoPlani): string;
begin
  Result := TF('ONAY_OTO', [Plan.Tablo, Plan.Kolon, Plan.Komutlar]) + sLineBreak + sLineBreak + T('ONAY_KOLON_YEDEK') +
    sLineBreak + sLineBreak + T('ONAY_DOM_SORU');
end;

function OtoUygula(Bag: TAcikBaglanti; const Plan: TOtoPlani): TProsedurSonucu;
begin
  Result := Default(TProsedurSonucu);
  if not TabloYapisiniYedekle(Bag, Plan.Tablo, Result) then
    Exit;
  MetniCalistir(Bag, Plan.Betik, Result);
end;

end.
