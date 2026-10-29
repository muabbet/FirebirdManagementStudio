{ uNesneYonet.pas - View, exception, domain ve generator yonetimi (Asama 3f): silme, yeni nesne sablonu,
  domain degistirme (varsayilan deger, CHECK, ad).

  Hedeflenen Firebird surumleri: 2.5, 3.0, 4.0, 5.0
  Denenen Firebird surumleri: 2.5.9, 3.0.14, 4.0.7, 5.0.4 (bkz. ASAMA3F_RAPOR.md)

  Her islem ayni adimlarla calisir (uProsedur'un ortak parcalari):
    1. Eski tanim tam CREATE script'i olarak <veri klasoru>\_arsiv\<baglanti adi>\ altina yedeklenir.
       Yazilamazsa islem DURUR, veritabanina dokunulmaz.
    2. Komut tek ACIK islemde calisir: basariliysa commit, hata verirse rollback.
  Hata istisna olarak firlamaz, TProsedurSonucu'na yazilir; form gosterir. }
unit uNesneYonet;

interface

uses
  System.SysUtils, System.Classes, System.StrUtils, System.RegularExpressions,
  uDil, uBaglanti, uMetadata, uDDL, uProsedur;

type
  { Domain'de desteklenen uc is. Tip degistirme bu surumde yok. }
  TDomainIslemi = (diVarsayilan, diKontrol, diAd);

const
  { Onay penceresinde en cok bu kadar bagimli nesne listelenir, fazlasi "ve N tane daha" olur. }
  EN_COK_BAGIMLI = 10;

{ Silme: view, exception, domain, generator (baska tur verilmez). }
function SilmeKomutu(Bag: TAcikBaglanti; Tur: TNesneTuru; const Ad: string): string;
{ Onay penceresinin metni: ne silinecek, geri alinamaz, yedek, kullananlar (en cok 10). }
function SilmeOnayMetni(Bag: TAcikBaglanti; Tur: TNesneTuru; const Ad: string): string;
function NesneSil(Bag: TAcikBaglanti; Tur: TNesneTuru; const Ad: string): TProsedurSonucu;

{ Bagimlilik listesini onay metnine yazilacak satirlara cevirir (en cok EN_COK_BAGIMLI, sonra "ve N tane daha"). }
function BagimlilikMetni(const Liste: TArray<TBagimlilik>): string;

{ Yeni nesne duzenleme sekmesinin bos sablonu (ntIstisna, ntDomain). }
function YeniNesneSablonu(Tur: TNesneTuru): string;

{ Domain'in yazi kutusuna konacak mevcut degeri (varsayilan ifade, CHECK ifadesi, ad). }
function DomainMevcutDeger(Bag: TAcikBaglanti; const Ad: string; Islem: TDomainIslemi): string;
{ Calisacak komut(lar), "; " ile ayrilmis tek metin olarak (onay penceresinde de gosterilir). Deger bos:
  varsayilan / CHECK kaldirilir. }
function DomainKomutlari(Bag: TAcikBaglanti; const Ad: string; Islem: TDomainIslemi; const Deger: string): string;
function DomainDegistir(Bag: TAcikBaglanti; const Ad: string; Islem: TDomainIslemi; const Deger: string): TProsedurSonucu;
function DomainOnayMetni(Bag: TAcikBaglanti; const Ad: string; const Komutlar: string): string;

implementation

function TurSqlAdi(Tur: TNesneTuru): string;
begin
  case Tur of
    ntView: Result := 'VIEW';
    ntIstisna: Result := 'EXCEPTION';
    ntDomain: Result := 'DOMAIN';
  else
    Result := 'SEQUENCE';
  end;
end;

{ Onay metninde gorunen tur yazisi (dil dosyasindan). }
function TurYazisi(Tur: TNesneTuru): string;
begin
  case Tur of
    ntView: Result := T('TUR_VIEW');
    ntIstisna: Result := T('TUR_ISTISNA');
    ntDomain: Result := T('TUR_DOMAIN');
  else
    Result := T('TUR_GENERATOR');
  end;
end;

function BagimlilikTuruYazisi(Tur: Integer): string;
begin
  case Tur of
    BAG_KOLON: Result := T('BAG_TUR_KOLON');
    1: Result := T('BAG_TUR_VIEW');
    2: Result := T('BAG_TUR_TETIKLEYICI');
    3: Result := T('BAG_TUR_HESAPLANAN');
    5: Result := T('BAG_TUR_PROSEDUR');
  else
    Result := T('BAG_TUR_DIGER');
  end;
end;

function BagimlilikMetni(const Liste: TArray<TBagimlilik>): string;
var
  i: Integer;
begin
  Result := '';
  for i := 0 to High(Liste) do
  begin
    if i >= EN_COK_BAGIMLI then
    begin
      Result := Result + sLineBreak + TF('ONAY_SIL_DAHA_FAZLA', [Length(Liste) - EN_COK_BAGIMLI]);
      Break;
    end;
    if i > 0 then
      Result := Result + sLineBreak;
    Result := Result + '- ' + BagimlilikTuruYazisi(Liste[i].Tur) + ': ' + Liste[i].Ad;
  end;
end;

function HedefBul(Tur: TNesneTuru): TBagimlilikHedefi;
begin
  case Tur of
    ntView: Result := bhView;
    ntIstisna: Result := bhIstisna;
    ntDomain: Result := bhDomain;
  else
    Result := bhGenerator;
  end;
end;

function SilmeKomutu(Bag: TAcikBaglanti; Tur: TNesneTuru; const Ad: string): string;
begin
  Result := 'DROP ' + TurSqlAdi(Tur) + ' ' + AdiYaz(Bag, Ad);
end;

function SilmeOnayMetni(Bag: TAcikBaglanti; Tur: TNesneTuru; const Ad: string): string;
var
  Kullananlar: TArray<TBagimlilik>;
begin
  Result := TF('ONAY_SIL', [TurYazisi(Tur), Ad]);
  Kullananlar := BagimliNesneler(Bag, HedefBul(Tur), Ad);
  if Length(Kullananlar) = 0 then
    Result := Result + sLineBreak + sLineBreak + T('ONAY_SIL_BAGIMLI_YOK')
  else
    Result := Result + sLineBreak + sLineBreak + T('ONAY_SIL_BAGIMLI') + sLineBreak + BagimlilikMetni(Kullananlar);
  Result := Result + sLineBreak + sLineBreak + T('ONAY_SIL_SORU');
end;

function NesneSil(Bag: TAcikBaglanti; Tur: TNesneTuru; const Ad: string): TProsedurSonucu;
begin
  Result := Default(TProsedurSonucu);
  if not EskiTanimiYedekle(Bag, Tur, Ad, True, Result) then
    Exit;
  MetniCalistir(Bag, SilmeKomutu(Bag, Tur, Ad), Result);
end;

function YeniNesneSablonu(Tur: TNesneTuru): string;
begin
  if Tur = ntDomain then
    Result := 'CREATE DOMAIN YENI_DOMAIN AS VARCHAR(50);' + sLineBreak
  else
    Result := 'CREATE EXCEPTION YENI_EXCEPTION ''' + T('EXC_SABLON_MESAJ') + ''';' + sLineBreak;
end;

{ ---------- Domain ---------- }

{ Yazilan degerin basindaki anahtar sozcugu atar: "DEFAULT 5" -> "5", "CHECK (VALUE > 0)" -> "(VALUE > 0)". }
function SozcuguAt(const Deger, Sozcuk: string): string;
begin
  Result := Trim(Deger);
  if StartsText(Sozcuk, Result) and ((Length(Result) = Length(Sozcuk)) or CharInSet(Result[Length(Sozcuk) + 1], [' ', #9, #13, #10, '('])) then
    Result := Trim(Copy(Result, Length(Sozcuk) + 1, MaxInt));
end;

function DomainMevcutDeger(Bag: TAcikBaglanti; const Ad: string; Islem: TDomainIslemi): string;
var
  Bilgi: TDomainBilgisi;
begin
  Bilgi := DomainBilgisiOku(Bag, Ad);
  case Islem of
    diVarsayilan: Result := SozcuguAt(Bilgi.Varsayilan, 'DEFAULT');
    diKontrol: Result := SozcuguAt(Bilgi.Kontrol, 'CHECK');
  else
    Result := Ad;
  end;
end;

function DomainKomutlari(Bag: TAcikBaglanti; const Ad: string; Islem: TDomainIslemi; const Deger: string): string;
var
  On, Ifade: string;
begin
  On := 'ALTER DOMAIN ' + AdiYaz(Bag, Ad);
  case Islem of
    diVarsayilan:
      begin
        Ifade := SozcuguAt(Deger, 'DEFAULT');
        if Ifade = '' then
          Result := On + ' DROP DEFAULT'
        else
          Result := On + ' SET DEFAULT ' + Ifade;
      end;
    diKontrol:
      begin
        { Domain'de tek CHECK olabilir: once varsa kaldirilir (olmayana DROP CONSTRAINT hata vermez, olculdu), sonra eklenir. }
        Ifade := SozcuguAt(Deger, 'CHECK');
        Result := On + ' DROP CONSTRAINT';
        if Ifade <> '' then
        begin
          if Ifade[1] <> '(' then
            Ifade := '(' + Ifade + ')';
          Result := Result + ';' + sLineBreak + On + ' ADD CHECK ' + Ifade;
        end;
      end;
  else
    Result := On + ' TO ' + AdiYaz(Bag, Trim(Deger));
  end;
end;

function DomainDegistir(Bag: TAcikBaglanti; const Ad: string; Islem: TDomainIslemi; const Deger: string): TProsedurSonucu;
begin
  Result := Default(TProsedurSonucu);
  if (Islem = diAd) and (Trim(Deger) = '') then
  begin
    Result.Cumle := T('ERR_DOM_AD_BOS');
    Exit;
  end;
  if not EskiTanimiYedekle(Bag, ntDomain, Ad, True, Result) then
    Exit;
  if Islem = diAd then
    Result.Ad := Trim(Deger);
  MetniCalistir(Bag, DomainKomutlari(Bag, Ad, Islem, Deger), Result);
end;

function DomainOnayMetni(Bag: TAcikBaglanti; const Ad: string; const Komutlar: string): string;
var
  Kullananlar: TArray<TBagimlilik>;
begin
  Result := TF('ONAY_DOM_DEGISTIR', [Ad, Komutlar]);
  Kullananlar := BagimliNesneler(Bag, bhDomain, Ad);
  if Length(Kullananlar) > 0 then
    Result := Result + sLineBreak + sLineBreak + T('ONAY_DOM_KULLANANLAR') + sLineBreak + BagimlilikMetni(Kullananlar);
  Result := Result + sLineBreak + sLineBreak + T('ONAY_DOM_SORU');
end;

end.
