{ uKolon.pas - Tablo kolonu islemleri (Asama 3g-2): ekle, adini degistir, tip / NOT NULL / varsayilan degistir, sil.

  Hedeflenen Firebird surumleri: 2.5, 3.0, 4.0, 5.0
  Surum farki: SET / DROP NOT NULL Firebird 3.0'dan once yoktur (KolonNullDegistirilebilir, uMetadata).

  Her islem ayni adimlarla calisir (uProsedur'un ortak parcalari):
    1. Tablonun tam CREATE script'i <veri klasoru>\_arsiv\<baglanti adi>\tablo_ADI_... olarak yedeklenir.
       Yazilamazsa islem DURUR, veritabanina dokunulmaz. Kolon VERISI yedeklenmez.
    2. Komut(lar) tek ACIK islemde calisir: basariliysa commit, hata verirse rollback.
  Hata istisna olarak firlamaz, TProsedurSonucu'na yazilir; form gosterir. }
unit uKolon;

interface

uses
  System.SysUtils, System.Classes, System.StrUtils, System.Generics.Collections,
  uDil, uPaket, uBaglanti, uMetadata, uDDL, uProsedur, uNesneYonet;

type
  TKolonIslemi = (kiEkle, kiAd, kiDegistir, kiSil);

  { Pencerede duzenlenen / uygulanan degerler. Kolon: mevcut kolonun adi (ekleme disindaki islemler).
    Tip: 'VARCHAR(50)' gibi, ya da kolon domain kullaniyorsa domain adi. Varsayilan: 'DEFAULT' sozcuksuz ifade, bos = yok. }
  TKolonGirdisi = record
    Islem: TKolonIslemi;
    Tablo: string;
    Kolon: string;
    YeniAd: string;
    Tip: string;
    Varsayilan: string;
    BosOlmaz: Boolean;
  end;

{ Kolon veri tipi listesi: veri_tipleri.txt (bagli surume gore) ve ardindan veritabaninin domain'leri. }
function KolonTipleri(Bag: TAcikBaglanti): TArray<TVeriTipi>;
{ Mevcut tip metnini ("VARCHAR(50)", "NUMERIC(18, 2)", domain adi) listedeki tiple eslestirir: Sira (listede yoksa -1) ve
  parantez icindeki sayilar. Listede olmayan tip (ornegin "BLOB SUB_TYPE 1") False doner. }
function TipAyristir(const Tip: string; const Tipler: TArray<TVeriTipi>; out Sira, Sayi1, Sayi2: Integer): Boolean;
{ Secilen tip ve sayilardan SQL tip metni: "VARCHAR(50)", "NUMERIC(18,2)", parametresizlerde yalniz ad. }
function TipMetniOlustur(const Tip: TVeriTipi; Sayi1, Sayi2: Integer): string;
{ Sayilar gecersizse anlasilir cumle (uzunluk 1..32765, hassasiyet 1..en cok, olcek 0..hassasiyet), tamamsa bos. }
function TipSayilariniDogrula(Bag: TAcikBaglanti; const Tip: TVeriTipi; Sayi1, Sayi2: Integer): string;

{ Mevcut kolonun degerleriyle dolu girdi (duzenleme penceresinin baslangici). Hesaplanan kolonda EMetadataHatasi. }
function KolonGirdisiOku(Bag: TAcikBaglanti; const Tablo, Kolon: string; Islem: TKolonIslemi): TKolonGirdisi;
{ Eksik / gecersiz girdide anlasilir cumle, tamamsa bos. }
function KolonGirdisiniDogrula(const Girdi: TKolonGirdisi): string;
{ Calisacak komut(lar), ";" ile ayrilmis tek metin (pencerenin SQL onizlemesi ve onay metni). Degisiklik yoksa bos. }
function KolonKomutlari(Bag: TAcikBaglanti; const Eski, Yeni: TKolonGirdisi): string;
{ Onay penceresinin metni: komutlar, veri kaybi uyarisi (satir sayisiyla), kolonu kullananlar (en cok 10), yedek bilgisi. }
function KolonOnayMetni(Bag: TAcikBaglanti; const Eski, Yeni: TKolonGirdisi; const Komutlar: string): string;
function KolonUygula(Bag: TAcikBaglanti; const Eski, Yeni: TKolonGirdisi): TProsedurSonucu;

implementation

function KolonTipleri(Bag: TAcikBaglanti): TArray<TVeriTipi>;
var
  Liste: TList<TVeriTipi>;
  Domainler: TStringList;
  Tip: TVeriTipi;
  Ad: string;
begin
  Liste := TList<TVeriTipi>.Create;
  Domainler := TStringList.Create;
  try
    Liste.AddRange(VeriTipleriniOku(PaketKlasoru + '\veri_tipleri.txt', Bag.Surum));
    DomainleriGetir(Bag, Domainler);
    for Ad in Domainler do
    begin
      Tip := Default(TVeriTipi);
      Tip.Ad := Ad;
      Tip.Domain := True;
      Liste.Add(Tip);
    end;
    Result := Liste.ToArray;
  finally
    Domainler.Free;
    Liste.Free;
  end;
end;

function TipAyristir(const Tip: string; const Tipler: TArray<TVeriTipi>; out Sira, Sayi1, Sayi2: Integer): Boolean;
var
  Buyuk, Icindekiler: string;
  i, Acik, Kapali, EnUzun: Integer;
  Sayilar: TArray<string>;
begin
  Sira := -1;
  Sayi1 := 0;
  Sayi2 := 0;
  Buyuk := UpperCase(Trim(Tip));
  EnUzun := 0;
  for i := 0 to High(Tipler) do
    if Tipler[i].Domain then
    begin
      if SameText(Tipler[i].Ad, Buyuk) then
      begin
        Sira := i;
        Exit(True);
      end;
    end
    else if (Length(Tipler[i].Ad) > EnUzun) and ((Buyuk = Tipler[i].Ad) or StartsText(Tipler[i].Ad + '(', Buyuk) or
      StartsText(Tipler[i].Ad + ' ', Buyuk)) then
    begin
      Sira := i;
      EnUzun := Length(Tipler[i].Ad);
    end;
  Result := Sira >= 0;
  if Result and (Tipler[Sira].Parametre <> tpYok) then
  begin
    Acik := Pos('(', Buyuk);
    Kapali := Pos(')', Buyuk);
    if (Acik > 0) and (Kapali > Acik) then
    begin
      Icindekiler := Copy(Buyuk, Acik + 1, Kapali - Acik - 1);
      Sayilar := Icindekiler.Split([',']);
      if Length(Sayilar) > 0 then
        Sayi1 := StrToIntDef(Trim(Sayilar[0]), 0);
      if Length(Sayilar) > 1 then
        Sayi2 := StrToIntDef(Trim(Sayilar[1]), 0);
    end;
  end;
end;

function TipMetniOlustur(const Tip: TVeriTipi; Sayi1, Sayi2: Integer): string;
begin
  case Tip.Parametre of
    tpUzunluk: Result := Tip.Ad + '(' + IntToStr(Sayi1) + ')';
    tpHassasiyet: Result := Tip.Ad + '(' + IntToStr(Sayi1) + ',' + IntToStr(Sayi2) + ')';
  else
    Result := Tip.Ad;
  end;
end;

function TipSayilariniDogrula(Bag: TAcikBaglanti; const Tip: TVeriTipi; Sayi1, Sayi2: Integer): string;
begin
  Result := '';
  case Tip.Parametre of
    tpUzunluk:
      if (Sayi1 < 1) or (Sayi1 > 32765) then
        Result := TF('ERR_TIP_UZUNLUK', [32765]);
    tpHassasiyet:
      if (Sayi1 < 1) or (Sayi1 > SayiHassasiyetiAzami(Bag)) then
        Result := TF('ERR_TIP_HASSASIYET', [SayiHassasiyetiAzami(Bag)])
      else if (Sayi2 < 0) or (Sayi2 > Sayi1) then
        Result := T('ERR_TIP_OLCEK');
  end;
end;

function KolonGirdisiOku(Bag: TAcikBaglanti; const Tablo, Kolon: string; Islem: TKolonIslemi): TKolonGirdisi;
var
  Bilgi: TKolonBilgisi;
begin
  Result := Default(TKolonGirdisi);
  Result.Islem := Islem;
  Result.Tablo := Tablo;
  Result.Kolon := Kolon;
  for Bilgi in KolonlariOku(Bag, Tablo) do
    if Bilgi.Ad = Kolon then
    begin
      if Bilgi.Hesaplanan <> '' then
        raise EMetadataHatasi.Create(T('ERR_KOLON_HESAPLANAN'));
      if Bilgi.Domain <> '' then
        Result.Tip := Bilgi.Domain
      else
        Result.Tip := Bilgi.Tip;
      Result.Varsayilan := SozcuguAt(Bilgi.Varsayilan, 'DEFAULT');
      Result.BosOlmaz := Bilgi.BosOlmaz;
      Result.YeniAd := Kolon;
      Exit;
    end;
  raise EMetadataHatasi.Create(TF('ERR_DDL_NESNE_YOK', [Kolon]));
end;

function KolonGirdisiniDogrula(const Girdi: TKolonGirdisi): string;
begin
  Result := '';
  if Girdi.Islem in [kiEkle, kiAd] then
    if AdHazirla(Girdi.YeniAd) = '' then
      Exit(T('ERR_KOLON_AD_BOS'));
  if Girdi.Islem in [kiEkle, kiDegistir] then
    if Trim(Girdi.Tip) = '' then
      Exit(T('ERR_KOLON_TIP_BOS'));
end;

function KolonKomutlari(Bag: TAcikBaglanti; const Eski, Yeni: TKolonGirdisi): string;
var
  On, Kolon, Ifade: string;

  procedure Ekle(const Komut: string);
  begin
    if Result <> '' then
      Result := Result + ';' + sLineBreak;
    Result := Result + Komut;
  end;

begin
  Result := '';
  On := 'ALTER TABLE ' + AdiYaz(Bag, Yeni.Tablo);
  Kolon := AdiYaz(Bag, Yeni.Kolon);
  case Yeni.Islem of
    kiEkle:
      begin
        Ekle(On + ' ADD ' + AdiYaz(Bag, AdHazirla(Yeni.YeniAd)) + ' ' + Trim(Yeni.Tip));
        Ifade := SozcuguAt(Yeni.Varsayilan, 'DEFAULT');
        if Ifade <> '' then
          Result := Result + ' DEFAULT ' + Ifade;
        if Yeni.BosOlmaz then
          Result := Result + ' NOT NULL';
      end;
    kiAd:
      if AdHazirla(Yeni.YeniAd) <> Yeni.Kolon then
        Ekle(On + ' ALTER COLUMN ' + Kolon + ' TO ' + AdiYaz(Bag, AdHazirla(Yeni.YeniAd)));
    kiSil:
      Ekle(On + ' DROP ' + Kolon);
    kiDegistir:
      begin
        if Trim(Yeni.Tip) <> Trim(Eski.Tip) then
          Ekle(On + ' ALTER COLUMN ' + Kolon + ' TYPE ' + Trim(Yeni.Tip));
        Ifade := SozcuguAt(Yeni.Varsayilan, 'DEFAULT');
        if Ifade <> SozcuguAt(Eski.Varsayilan, 'DEFAULT') then
          if Ifade = '' then
            Ekle(On + ' ALTER COLUMN ' + Kolon + ' DROP DEFAULT')
          else
            Ekle(On + ' ALTER COLUMN ' + Kolon + ' SET DEFAULT ' + Ifade);
        if (Yeni.BosOlmaz <> Eski.BosOlmaz) and KolonNullDegistirilebilir(Bag) then
          if Yeni.BosOlmaz then
            Ekle(On + ' ALTER COLUMN ' + Kolon + ' SET NOT NULL')
          else
            Ekle(On + ' ALTER COLUMN ' + Kolon + ' DROP NOT NULL');
      end;
  end;
end;

{ Veri kaybi / bozulma riski: kolon silme, tip degistirme, NOT NULL ekleme (mevcut bos degerler hata verir). }
function VeriRiskiVarMi(const Eski, Yeni: TKolonGirdisi): Boolean;
begin
  Result := (Yeni.Islem = kiSil) or
    ((Yeni.Islem = kiDegistir) and ((Trim(Yeni.Tip) <> Trim(Eski.Tip)) or (Yeni.BosOlmaz and not Eski.BosOlmaz)));
end;

function KolonOnayMetni(Bag: TAcikBaglanti; const Eski, Yeni: TKolonGirdisi; const Komutlar: string): string;
var
  Kullananlar: TArray<TBagimlilik>;
begin
  Result := TF('ONAY_KOLON', [Yeni.Tablo, Komutlar]);
  if VeriRiskiVarMi(Eski, Yeni) then
    Result := Result + sLineBreak + sLineBreak + TF('ONAY_KOLON_VERI_RISKI', [TabloSatirSayisi(Bag, Yeni.Tablo)]);
  if Yeni.Islem <> kiEkle then
  begin
    Kullananlar := KolonBagimliliklariniOku(Bag, Yeni.Tablo, Yeni.Kolon);
    if Length(Kullananlar) > 0 then
      Result := Result + sLineBreak + sLineBreak + T('ONAY_KOLON_KULLANANLAR') + sLineBreak + BagimlilikMetni(Kullananlar);
  end;
  Result := Result + sLineBreak + sLineBreak + T('ONAY_KOLON_YEDEK') + sLineBreak + sLineBreak + T('ONAY_DOM_SORU');
end;

function KolonUygula(Bag: TAcikBaglanti; const Eski, Yeni: TKolonGirdisi): TProsedurSonucu;
var
  Komutlar: string;
begin
  Result := Default(TProsedurSonucu);
  Result.Cumle := KolonGirdisiniDogrula(Yeni);
  if Result.Cumle <> '' then
    Exit;
  Komutlar := KolonKomutlari(Bag, Eski, Yeni);
  if Komutlar = '' then
  begin
    Result.Cumle := T('ERR_KOLON_DEGISIKLIK_YOK');
    Exit;
  end;
  if not TabloYapisiniYedekle(Bag, Yeni.Tablo, Result) then
    Exit;
  Result.Ad := AdHazirla(Yeni.YeniAd);
  MetniCalistir(Bag, Komutlar, Result);
end;

end.
