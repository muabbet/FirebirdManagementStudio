{ uYetki.pas - Yetkiler (Asama 3d-2 ve 3d-3): bir nesnede kimin ne yetkisi var, bir kullanicinin yetkileri, yetki verme ve
  geri alma (GRANT / REVOKE).

  Hedeflenen Firebird surumleri: 2.5, 3.0, 4.0, 5.0 (GRANT / REVOKE sozdizimi dortunde ayni)

  Yetkiler RDB$USER_PRIVILEGES'ten okunur (uMetadata.YetkileriOku; nesne sahibinin kendi otomatik yetkileri gelmez).
  Bu unit satirlari "yetkili taraf basina bir satir" ya da "nesne basina bir satir" haline getirir, komutlari uretir ve
  calistirir. Yetki verme / alma tek ACIK islemde calisir (commit / hatada rollback), SQL'i mesaj alaninda gorunur.
  Hata istisna olarak firlamaz, TProsedurSonucu'na yazilir; form gosterir. }
unit uYetki;

interface

uses
  System.SysUtils, System.Classes, System.StrUtils, System.Generics.Collections,
  uDil, uBaglanti, uMetadata, uDDL, uProsedur, uNesneYonet;

type
  { Yetkinin verildigi taraf: kullanici, rol ya da herkes (PUBLIC). }
  TYetkiHedefi = (yhKullanici, yhRol, yhHerkes);

  { Hangi nesne: tablo, view (ikisi de ayni komutlari alir) ya da prosedur (yalniz EXECUTE). }
  TYetkiNesnesi = (ynTablo, ynProsedur);

  TYetkiIslemi = (yiVer, yiAl);

  { Nesne penceresinde bir satir: yetkili taraf ve ona verilen yetkiler ("SELECT, INSERT, UPDATE (AD)"). }
  TNesneYetkisi = record
    Ad: string;
    Hedef: TYetkiHedefi;
    Yetkiler: string;
    { Tablo duzeyinde verilen yetki harfleri ("SIUD"); komut penceresi bunlari isaretli getirir. }
    Harfler: string;
    { Baskalarina da verebilir (WITH GRANT OPTION) }
    Verebilir: Boolean;
  end;

  { Kullanici penceresinde bir satir: nesne ve o kullanicinin o nesnedeki yetkileri. }
  TKullaniciYetkisi = record
    Nesne: string;
    NesneTuru: Integer;
    Yetkiler: string;
    Harfler: string;
    Verebilir: Boolean;
  end;

  { GRANT / REVOKE icin girdi. Harfler: S select, I insert, U update, D delete, R references (tablo/view); X execute
    (prosedur). }
  TYetkiGirdisi = record
    Nesne: string;
    NesneTuru: TYetkiNesnesi;
    Hedef: TYetkiHedefi;
    Ad: string;
    Harfler: string;
    Verebilir: Boolean;
  end;

const
  { RDB$OBJECT_TYPE degerleri (olculdu): tablo ve view 0, prosedur 5, exception 7, rol 13, generator 14. }
  OBJE_TABLO = 0;
  OBJE_PROSEDUR = 5;
  OBJE_ISTISNA = 7;
  OBJE_ROL = 13;
  OBJE_GENERATOR = 14;

{ Tablo/view ya da prosedur uzerindeki yetkiler, yetkili taraf basina bir satir (kullanici, rol, PUBLIC). }
function NesneYetkileriOku(Bag: TAcikBaglanti; const Nesne: string; Tur: TYetkiNesnesi): TArray<TNesneYetkisi>;
{ Bir kullanicinin (ya da rolun) hangi nesnelerde ne yetkisi var, nesne basina bir satir. }
function KullaniciYetkileriOku(Bag: TAcikBaglanti; const Ad: string; Hedef: TYetkiHedefi): TArray<TKullaniciYetkisi>;

{ Yetki harflerinin okunur yazisi: "SIU" -> "SELECT, INSERT, UPDATE". }
function HarfYazisi(const Harfler: string): string;
{ Pencerede secilebilecek harfler: tablo "SIUDR", prosedur "X". }
function SecilebilirHarfler(Tur: TYetkiNesnesi): string;

{ Calisacak komut ("GRANT SELECT, INSERT ON T TO USER X"); girdi eksikse (harf ya da ad yok) bos. }
function YetkiKomutu(Bag: TAcikBaglanti; Islem: TYetkiIslemi; const G: TYetkiGirdisi): string;
{ Eksik girdide anlasilir cumle, tamamsa bos. }
function YetkiDogrula(const G: TYetkiGirdisi): string;
{ Onay penceresinin metni: ne verilecek / alinacak, kime, hangi komutla; PUBLIC ve GRANT OPTION icin ek uyari. }
function YetkiOnayMetni(Islem: TYetkiIslemi; const G: TYetkiGirdisi; const Komut: string): string;
function YetkiUygula(Bag: TAcikBaglanti; Islem: TYetkiIslemi; const G: TYetkiGirdisi): TProsedurSonucu;

{ Bir kullanicinin tablo, view ve prosedur yetkilerinin HEPSINI geri alan komutlar ("; " ve satir sonuyla ayrilmis tek
  metin, onay penceresinde gosterilir). Rol uyeligi, generator ve exception yetkilerine dokunulmaz. Hic yetki yoksa bos. }
function HepsiniAlKomutlari(Bag: TAcikBaglanti; const Ad: string; Hedef: TYetkiHedefi): string;
function HepsiniAlUygula(Bag: TAcikBaglanti; const Ad: string; Hedef: TYetkiHedefi): TProsedurSonucu;

implementation

const
  HARF_SIRASI = 'SIUDRX';

function HarfYazisi(const Harfler: string): string;
var
  Harf: Char;
  Parca: string;
begin
  Result := '';
  for Harf in Harfler do
  begin
    case Harf of
      'S': Parca := 'SELECT';
      'I': Parca := 'INSERT';
      'U': Parca := 'UPDATE';
      'D': Parca := 'DELETE';
      'R': Parca := 'REFERENCES';
      'X': Parca := 'EXECUTE';
      'G': Parca := 'USAGE';
      'M': Parca := 'MEMBER';
    else
      Parca := Harf;
    end;
    if Result <> '' then
      Result := Result + ', ';
    Result := Result + Parca;
  end;
end;

function SecilebilirHarfler(Tur: TYetkiNesnesi): string;
begin
  if Tur = ynProsedur then
    Result := 'X'
  else
    Result := 'SIUDR';
end;

{ Harfleri S, I, U, D, R, X sirasina koyar (ayni harf bir kez). }
function Sirala(const Harfler: string): string;
var
  Harf: Char;
begin
  Result := '';
  for Harf in HARF_SIRASI do
    if Pos(Harf, Harfler) > 0 then
      Result := Result + Harf;
end;

{ Birlestirilmis yetki metni: once tablo duzeyi harfler, sonra kolon yetkileri ("UPDATE (AD)"). }
function YetkiMetni(const Harfler, Kolonlu: string): string;
begin
  Result := HarfYazisi(Sirala(Harfler));
  if (Result <> '') and (Kolonlu <> '') then
    Result := Result + ', ';
  Result := Result + Kolonlu;
end;

{ Bir yetki satirini hesaplayiciya katar: kolon yetkisi (Alan dolu) kolon listesine, digerleri harflere. }
procedure Katla(const Y: TYetkiBilgisi; var Harfler, Kolonlu: string; var Verebilir: Boolean);
begin
  if Y.SecenekVar = 1 then
    Verebilir := True;
  if Y.Alan <> '' then
  begin
    if Kolonlu <> '' then
      Kolonlu := Kolonlu + ', ';
    Kolonlu := Kolonlu + HarfYazisi(Y.Yetki) + ' (' + Y.Alan + ')';
  end
  else if Pos(Y.Yetki, Harfler) = 0 then
    Harfler := Harfler + Y.Yetki;
end;

function NesneYetkileriOku(Bag: TAcikBaglanti; const Nesne: string; Tur: TYetkiNesnesi): TArray<TNesneYetkisi>;
var
  Y: TYetkiBilgisi;
  Anahtarlar: TStringList;
  Satirlar: TList<TNesneYetkisi>;
  Kolonlar: TStringList;
  Satir: TNesneYetkisi;
  Anahtar, Harfler, Kolonlu: string;
  Sira, ObjeTuru: Integer;
begin
  if Tur = ynProsedur then
    ObjeTuru := OBJE_PROSEDUR
  else
    ObjeTuru := OBJE_TABLO;
  Anahtarlar := TStringList.Create;
  Kolonlar := TStringList.Create;
  Satirlar := TList<TNesneYetkisi>.Create;
  try
    for Y in YetkileriOku(Bag) do
    begin
      if (Y.Nesne <> Nesne) or (Y.NesneTuru <> ObjeTuru) or not (Y.KullaniciTuru in [8, 13]) then
        Continue;
      Anahtar := IntToStr(Y.KullaniciTuru) + ':' + Y.Kullanici;
      Sira := Anahtarlar.IndexOf(Anahtar);
      if Sira < 0 then
      begin
        Satir := Default(TNesneYetkisi);
        Satir.Ad := Y.Kullanici;
        if Y.KullaniciTuru = 13 then
          Satir.Hedef := yhRol
        else if SameText(Y.Kullanici, 'PUBLIC') then
          Satir.Hedef := yhHerkes
        else
          Satir.Hedef := yhKullanici;
        Satirlar.Add(Satir);
        Anahtarlar.Add(Anahtar);
        Kolonlar.Add('');
        Sira := Anahtarlar.Count - 1;
      end;
      Satir := Satirlar[Sira];
      Harfler := Satir.Harfler;
      Kolonlu := Kolonlar[Sira];
      Katla(Y, Harfler, Kolonlu, Satir.Verebilir);
      Satir.Harfler := Harfler;
      Kolonlar[Sira] := Kolonlu;
      Satirlar[Sira] := Satir;
    end;
    for Sira := 0 to Satirlar.Count - 1 do
    begin
      Satir := Satirlar[Sira];
      Satir.Harfler := Sirala(Satir.Harfler);
      Satir.Yetkiler := YetkiMetni(Satir.Harfler, Kolonlar[Sira]);
      Satirlar[Sira] := Satir;
    end;
    Result := Satirlar.ToArray;
  finally
    Satirlar.Free;
    Kolonlar.Free;
    Anahtarlar.Free;
  end;
end;

function KullaniciYetkileriOku(Bag: TAcikBaglanti; const Ad: string; Hedef: TYetkiHedefi): TArray<TKullaniciYetkisi>;
var
  Y: TYetkiBilgisi;
  Anahtarlar: TStringList;
  Satirlar: TList<TKullaniciYetkisi>;
  Kolonlar: TStringList;
  Satir: TKullaniciYetkisi;
  Anahtar, Harfler, Kolonlu: string;
  Sira, TurKodu: Integer;
begin
  if Hedef = yhRol then
    TurKodu := 13
  else
    TurKodu := 8;
  Anahtarlar := TStringList.Create;
  Kolonlar := TStringList.Create;
  Satirlar := TList<TKullaniciYetkisi>.Create;
  try
    for Y in YetkileriOku(Bag) do
    begin
      if (Y.KullaniciTuru <> TurKodu) or not SameText(Y.Kullanici, Ad) then
        Continue;
      Anahtar := IntToStr(Y.NesneTuru) + ':' + Y.Nesne;
      Sira := Anahtarlar.IndexOf(Anahtar);
      if Sira < 0 then
      begin
        Satir := Default(TKullaniciYetkisi);
        Satir.Nesne := Y.Nesne;
        Satir.NesneTuru := Y.NesneTuru;
        Satirlar.Add(Satir);
        Anahtarlar.Add(Anahtar);
        Kolonlar.Add('');
        Sira := Anahtarlar.Count - 1;
      end;
      Satir := Satirlar[Sira];
      Harfler := Satir.Harfler;
      Kolonlu := Kolonlar[Sira];
      Katla(Y, Harfler, Kolonlu, Satir.Verebilir);
      Satir.Harfler := Harfler;
      Kolonlar[Sira] := Kolonlu;
      Satirlar[Sira] := Satir;
    end;
    for Sira := 0 to Satirlar.Count - 1 do
    begin
      Satir := Satirlar[Sira];
      Satir.Harfler := Sirala(Satir.Harfler);
      Satir.Yetkiler := YetkiMetni(Satir.Harfler, Kolonlar[Sira]);
      Satirlar[Sira] := Satir;
    end;
    Result := Satirlar.ToArray;
  finally
    Satirlar.Free;
    Kolonlar.Free;
    Anahtarlar.Free;
  end;
end;

{ "USER ADI", "ROLE ADI" ya da "PUBLIC". Kullanici ve rol adlari AdHazirla ile (basit adlar BUYUK harf). }
function HedefMetni(Bag: TAcikBaglanti; Hedef: TYetkiHedefi; const Ad: string): string;
begin
  case Hedef of
    yhHerkes: Result := 'PUBLIC';
    yhRol: Result := 'ROLE ' + AdiYaz(Bag, AdHazirla(Ad));
  else
    Result := 'USER ' + AdiYaz(Bag, AdHazirla(Ad));
  end;
end;

{ "SELECT, INSERT ON T" ya da "EXECUTE ON PROCEDURE P" (GRANT / REVOKE'un ortak ortasi). }
function YetkiVeNesne(Bag: TAcikBaglanti; const G: TYetkiGirdisi): string;
begin
  if G.NesneTuru = ynProsedur then
    Result := 'EXECUTE ON PROCEDURE ' + AdiYaz(Bag, G.Nesne)
  else
    Result := HarfYazisi(Sirala(G.Harfler)) + ' ON ' + AdiYaz(Bag, G.Nesne);
end;

function YetkiDogrula(const G: TYetkiGirdisi): string;
begin
  Result := '';
  if (G.Hedef <> yhHerkes) and (Trim(G.Ad) = '') then
    Exit(T('ERR_YETKI_AD_BOS'));
  if Sirala(G.Harfler) = '' then
    Exit(T('ERR_YETKI_SECIM_BOS'));
end;

function YetkiKomutu(Bag: TAcikBaglanti; Islem: TYetkiIslemi; const G: TYetkiGirdisi): string;
begin
  if YetkiDogrula(G) <> '' then
    Exit('');
  if Islem = yiVer then
  begin
    Result := 'GRANT ' + YetkiVeNesne(Bag, G) + ' TO ' + HedefMetni(Bag, G.Hedef, G.Ad);
    if G.Verebilir then
      Result := Result + ' WITH GRANT OPTION';
  end
  else
    Result := 'REVOKE ' + YetkiVeNesne(Bag, G) + ' FROM ' + HedefMetni(Bag, G.Hedef, G.Ad);
end;

function YetkiOnayMetni(Islem: TYetkiIslemi; const G: TYetkiGirdisi; const Komut: string): string;
var
  Kime: string;
begin
  if G.Hedef = yhHerkes then
    Kime := T('YETKI_HERKES')
  else
    Kime := G.Ad;
  if Islem = yiVer then
  begin
    Result := TF('ONAY_YETKI_VER', [G.Nesne, Kime, Komut]);
    if G.Hedef = yhHerkes then
      Result := Result + sLineBreak + sLineBreak + T('ONAY_YETKI_HERKES');
    if G.Verebilir then
      Result := Result + sLineBreak + sLineBreak + T('ONAY_YETKI_SECENEK');
  end
  else
    Result := TF('ONAY_YETKI_AL', [G.Nesne, Kime, Komut]);
  Result := Result + sLineBreak + sLineBreak + T('ONAY_DOM_SORU');
end;

function YetkiUygula(Bag: TAcikBaglanti; Islem: TYetkiIslemi; const G: TYetkiGirdisi): TProsedurSonucu;
begin
  Result := Default(TProsedurSonucu);
  Result.Cumle := YetkiDogrula(G);
  if Result.Cumle <> '' then
    Exit;
  MetniCalistir(Bag, YetkiKomutu(Bag, Islem, G), Result);
end;

function HepsiniAlKomutlari(Bag: TAcikBaglanti; const Ad: string; Hedef: TYetkiHedefi): string;
var
  Y: TKullaniciYetkisi;
  Komut: string;
begin
  Result := '';
  for Y in KullaniciYetkileriOku(Bag, Ad, Hedef) do
  begin
    if Y.NesneTuru = OBJE_TABLO then
      Komut := 'REVOKE ALL ON ' + AdiYaz(Bag, Y.Nesne) + ' FROM ' + HedefMetni(Bag, Hedef, Ad)
    else if Y.NesneTuru = OBJE_PROSEDUR then
      Komut := 'REVOKE EXECUTE ON PROCEDURE ' + AdiYaz(Bag, Y.Nesne) + ' FROM ' + HedefMetni(Bag, Hedef, Ad)
    else
      Continue;
    if Result <> '' then
      Result := Result + ';' + sLineBreak;
    Result := Result + Komut;
  end;
end;

function HepsiniAlUygula(Bag: TAcikBaglanti; const Ad: string; Hedef: TYetkiHedefi): TProsedurSonucu;
var
  Komutlar: string;
begin
  Result := Default(TProsedurSonucu);
  Komutlar := HepsiniAlKomutlari(Bag, Ad, Hedef);
  if Komutlar = '' then
  begin
    Result.Cumle := T('ERR_YETKI_YOK_ALINACAK');
    Exit;
  end;
  MetniCalistir(Bag, Komutlar, Result);
end;

end.
