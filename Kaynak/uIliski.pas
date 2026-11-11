{ uIliski.pas - Iliskili kayitlara git (gunluk is).
  Gridde bir kayit secilince: (1) yabanci anahtar hucresindeki degerin gosterdigi ana kayit, (2) bu kaydi kullanan
  baska tablolardaki kayitlar. Burada yalniz hedef tablo ve WHERE kosulu uretilir; sekmeyi acmak ana formun isidir.
  Hicbir sey veritabanina yazilmaz. }
unit uIliski;

interface

uses
  System.SysUtils, System.Classes, System.Generics.Collections, Data.DB,
  uBaglanti, uMetadata;

type
  { Gidilecek yer: hangi tabloda hangi kosulla acilacagi. Adet: kosula uyan kayit sayisi (bilinmiyorsa -1). }
  TIliskiliKayit = record
    Tablo: string;
    { Gosterim icin: "MUSTERI_ID" ya da "KOD, YIL" }
    Kolonlar: string;
    Filtre: string;
    Adet: Int64;
  end;

{ AlanAdi bir yabanci anahtarin kolonuysa ve kayittaki anahtar degerleri bos degilse, bagli ana kaydin
  tablosunu ve kosulunu verir. Kisitlar: tablonun kisitlari (KisitlariOku). }
function BagliKayitBul(const Kisitlar: TArray<TKisitBilgisi>; const AlanAdi: string; Veri: TDataSet;
  out Kayit: TIliskiliKayit): Boolean;

{ Bu kaydi (birincil anahtar ya da benzersiz kisit degerleriyle) kullanan baska tablolardaki kayitlar.
  Yalniz en az bir kaydi olan tablolar gelir; Adet doludur. Bos anahtar degeri olan kisit atlanir. }
function KullananKayitlariBul(Bag: TAcikBaglanti; const Kisitlar: TArray<TKisitBilgisi>; Veri: TDataSet): TArray<TIliskiliKayit>;

implementation

uses
  uFiltre, uSorgu;

function Birlestir(const Parcalar: TArray<string>): string;
var
  i: Integer;
begin
  Result := '';
  for i := 0 to High(Parcalar) do
  begin
    if i > 0 then
      Result := Result + ', ';
    Result := Result + Parcalar[i];
  end;
end;

{ "HEDEF1" = deger1 AND "HEDEF2" = deger2; degerler kayittaki Kaynak kolonlarindan gelir. Bos deger varsa False. }
function KosulYaz(const Hedef, Kaynak: TArray<string>; Veri: TDataSet; out Kosul: string): Boolean;
var
  i: Integer;
  Alan: TField;
begin
  Kosul := '';
  Result := (Length(Hedef) > 0) and (Length(Hedef) = Length(Kaynak));
  if not Result then
    Exit;
  for i := 0 to High(Hedef) do
  begin
    Alan := Veri.FindField(Kaynak[i]);
    if (Alan = nil) or Alan.IsNull then
    begin
      Kosul := '';
      Exit(False);
    end;
    if Kosul <> '' then
      Kosul := Kosul + ' AND ';
    Kosul := Kosul + TirnakliAd(Hedef[i]) + ' = ' + DegerYazisi(Alan);
  end;
end;

function BagliKayitBul(const Kisitlar: TArray<TKisitBilgisi>; const AlanAdi: string; Veri: TDataSet;
  out Kayit: TIliskiliKayit): Boolean;
var
  Kisit: TKisitBilgisi;
  Kolon, Kosul: string;
begin
  Kayit := Default(TIliskiliKayit);
  Kayit.Adet := -1;
  for Kisit in Kisitlar do
  begin
    if Kisit.Tur <> ktYabanci then
      Continue;
    for Kolon in Kisit.Kolonlar do
      if SameText(Kolon, AlanAdi) then
      begin
        if not KosulYaz(Kisit.HedefKolonlar, Kisit.Kolonlar, Veri, Kosul) then
          Exit(False);
        Kayit.Tablo := Kisit.HedefTablo;
        Kayit.Kolonlar := Birlestir(Kisit.HedefKolonlar);
        Kayit.Filtre := Kosul;
        Exit(True);
      end;
  end;
  Result := False;
end;

function KullananKayitlariBul(Bag: TAcikBaglanti; const Kisitlar: TArray<TKisitBilgisi>; Veri: TDataSet): TArray<TIliskiliKayit>;
var
  Liste: TList<TIliskiliKayit>;
  Kisit: TKisitBilgisi;
  Kullanan: TYabanciKolonlar;
  Kayit: TIliskiliKayit;
  Kosul: string;
begin
  Liste := TList<TIliskiliKayit>.Create;
  try
    for Kisit in Kisitlar do
    begin
      if not (Kisit.Tur in [ktBirincil, ktBenzersiz]) then
        Continue;
      for Kullanan in KisitaBagliYabanciKolonlar(Bag, Kisit.GercekAd) do
      begin
        { Kullanan tablonun yabanci kolonlari, bu tablonun anahtar kolonlarina sirayla karsilik gelir. }
        if not KosulYaz(Kullanan.Kolonlar, Kisit.Kolonlar, Veri, Kosul) then
          Continue;
        Kayit.Tablo := Kullanan.Tablo;
        Kayit.Kolonlar := Birlestir(Kullanan.Kolonlar);
        Kayit.Filtre := Kosul;
        Kayit.Adet := KayitSayisi(Bag, Kayit.Tablo, Kayit.Filtre);
        if Kayit.Adet > 0 then
          Liste.Add(Kayit);
      end;
    end;
    Result := Liste.ToArray;
  finally
    Liste.Free;
  end;
end;

end.
