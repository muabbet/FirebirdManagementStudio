{ uProsedur.pas - Sakli prosedur (Asama 3e-1) ve tetikleyici (Asama 3e-2) duzenleme ve veritabanina kaydetme.
  Ikisi ayni adimlarla calisir; fark yalniz tur (ntProsedur / ntTetikleyici): baslik, yedek dosya adi ve metinler.
  Prosedur* adli yordamlar 3e-1'den kalma ince sarmalardir (davranis ayni); asil is Nesne* yordamlarindadir.

  Hedeflenen Firebird surumleri: 2.5, 3.0, 4.0, 5.0
  Denenen Firebird surumleri: 5.0 gomulu kipte (bkz. ASAMA3E1_RAPOR.md). 2.5, 3.0, 4.0 sunucuda sahibi deneyecek.

  Duzenleme metni uDDL.ProsedurDuzenleScripti / TetikleyiciDuzenleScripti ile gelir (CREATE OR ALTER PROCEDURE|TRIGGER, SET TERM sarmali). Kaydet:
    1. Metindeki prosedur adi sekmedeki adla ayni mi? (baska ad yazilirsa YENI bir prosedur olusurdu, reddedilir)
    2. Eski tanim <veri klasoru>\_arsiv\<baglanti adi>\prosedur_ADI_yyyymmdd_hhnnss.sql dosyasina yazilir.
       Yazilamazsa kaydetme DURUR, veritabanina dokunulmaz.
    3. Metin tek ACIK islemde calisir: hepsi basarili olursa commit, biri hata verirse rollback (yarim kalmaz).
  Paketli prosedurler (3.0+) kapsam disi: agacta listelenmezler, tanimlari da okunmaz (bkz. uMetadata). }
unit uProsedur;

interface

uses
  System.SysUtils, System.Classes, System.IOUtils, System.StrUtils, System.RegularExpressions,
  FireDAC.Stan.Intf, FireDAC.Stan.Option, FireDAC.Stan.Error, FireDAC.Comp.Client,
  uDil, uBaglanti, uMetadata, uSorgu, uDDL;

type
  { Kaydetmenin sonucu. Hata istisna olarak firlamaz, buraya yazilir; arayuz gosterir. }
  TProsedurSonucu = record
    Basarili: Boolean;
    { Hata ise anlasilir cumle (bizim), ham Firebird mesaji ve editordeki hata satiri (yoksa 0). }
    Cumle: string;
    Ayrinti: string;
    Satir: Integer;
    { Calistirilan (hatada denenen) komutlar, SqlOzeti ile kisaltilmis; mesaj alanina yazilir. }
    Komutlar: TArray<string>;
    YedekDosyasi: string;
  end;

{ Duzenleme sekmesinde acilacak metin. Nesne yoksa (prosedurde paketliyse) EMetadataHatasi.
  Tur: ntProsedur veya ntTetikleyici (baska tur verilmez). }
function NesneDuzenleMetni(Bag: TAcikBaglanti; Tur: TNesneTuru; const Ad: string): string;

{ Metindeki ilk komut "CREATE OR ALTER PROCEDURE|TRIGGER <Ad>" ile basliyor mu? Degilse hata cumlesi, tamamsa bos doner. }
function NesneAdiniDogrula(Tur: TNesneTuru; const Metin, Ad: string): string;

{ Yalniz tetikleyici: metindeki FOR tablosu mevcut tabloyla ayni mi? Tablo degistirilemez; degilse hata cumlesi, tamamsa bos. }
function TetikleyiciTablosunuDogrula(Bag: TAcikBaglanti; const Metin, Ad: string): string;

{ Eski tanimi yedekler, metni calistirir. Bkz. unit basligi. }
function NesneKaydet(Bag: TAcikBaglanti; Tur: TNesneTuru; const Ad, Metin: string): TProsedurSonucu;

{ 3e-1'den kalan prosedur sarmalari (Tur = ntProsedur). }
function ProsedurDuzenleMetni(Bag: TAcikBaglanti; const Ad: string): string;
function ProsedurAdiniDogrula(const Metin, Ad: string): string;
function ProsedurKaydet(Bag: TAcikBaglanti; const Ad, Metin: string): TProsedurSonucu;

{ Yedek klasoru: <veri klasoru>\_arsiv\<baglanti adi> }
function ProsedurYedekKlasoru(const BaglantiAd: string): string;

{ Uzun komutun ilk satiri + "(N satir)"; tek satirli komut oldugu gibi. }
function SqlOzeti(const Komut: string): string;

{ Firebird mesajindaki "line N, column M" (komutun kendi satiri) -> N; yoksa 0. }
function HataSatiriBul(const HamMesaj: string): Integer;

implementation

type
  { Eski tanim yedeklenemedi: kaydetme baslamadan durur. }
  EProsedurYedek = class(Exception);

{ Metindeki baslik sozcugu ve dil anahtarlari tura gore secilir. }
function TurSozcugu(Tur: TNesneTuru): string;
begin
  if Tur = ntTetikleyici then
    Result := 'TRIGGER'
  else
    Result := 'PROCEDURE';
end;

function TurOnEki(Tur: TNesneTuru): string;
begin
  if Tur = ntTetikleyici then
    Result := 'TRG'
  else
    Result := 'PRS';
end;

function DosyaOnEki(Tur: TNesneTuru): string;
begin
  if Tur = ntTetikleyici then
    Result := 'trigger_'
  else
    Result := 'prosedur_';
end;

function NesneDuzenleMetni(Bag: TAcikBaglanti; Tur: TNesneTuru; const Ad: string): string;
begin
  if Tur = ntTetikleyici then
    Result := TetikleyiciDuzenleScripti(Bag, Ad)
  else
    Result := ProsedurDuzenleScripti(Bag, Ad);
end;

function NesneAdiniDogrula(Tur: TNesneTuru; const Metin, Ad: string): string;
const
  BASLIK = '^\s*(?:(?:--[^\n]*\n|/\*.*?\*/)\s*)*CREATE\s+OR\s+ALTER\s+%s\s+' +
    '("(?:[^"]|"")+"|[A-Za-z_][A-Za-z0-9_$]*)';
var
  Komutlar: TArray<string>;
  Eslesme: TMatch;
  Yazilan: string;
begin
  Komutlar := KomutlaraBol(Metin);
  if Length(Komutlar) = 0 then
    Exit(TF('ERR_' + TurOnEki(Tur) + '_BASLIK_YOK', [Ad, Ad]));
  Eslesme := TRegEx.Match(Komutlar[0], Format(BASLIK, [TurSozcugu(Tur)]), [roIgnoreCase, roSingleLine]);
  if not Eslesme.Success then
    Exit(TF('ERR_' + TurOnEki(Tur) + '_BASLIK_YOK', [Ad, Ad]));
  Yazilan := Eslesme.Groups[1].Value;
  if (Length(Yazilan) >= 2) and (Yazilan[1] = '"') then
    Yazilan := StringReplace(Copy(Yazilan, 2, Length(Yazilan) - 2), '""', '"', [rfReplaceAll])
  else
    Yazilan := UpperCase(Yazilan);
  if Yazilan = Ad then
    Result := ''
  else
    Result := TF('ERR_' + TurOnEki(Tur) + '_AD_DEGISTI', [Ad, Yazilan]);
end;

{ Tirnakli adi tirnaksiz hale, tirnaksiz adi buyuk harfe cevirir (Firebird adlandirma kurali). }
function AdCoz(const Yazilan: string): string;
begin
  if (Length(Yazilan) >= 2) and (Yazilan[1] = '"') then
    Result := StringReplace(Copy(Yazilan, 2, Length(Yazilan) - 2), '""', '"', [rfReplaceAll])
  else
    Result := UpperCase(Yazilan);
end;

{ Olcum (5.0.4): CREATE OR ALTER TRIGGER ... FOR <baska tablo> hata VERMEZ, tetikleyiciyi sessizce o tabloya tasir.
  Bu yuzden metindeki FOR tablosu (yoksa "tablosuz") mevcut tablo ile ayni olmali; degilse veritabanina dokunulmaz. }
function TetikleyiciTablosunuDogrula(Bag: TAcikBaglanti; const Metin, Ad: string): string;
const
  NESNE_AD = '("(?:[^"]|"")+"|[A-Za-z_][A-Za-z0-9_$]*)';
  BASLIK = '^\s*(?:(?:--[^\n]*\n|/\*.*?\*/)\s*)*CREATE\s+OR\s+ALTER\s+TRIGGER\s+' + NESNE_AD + '(?:\s+FOR\s+' + NESNE_AD + ')?';
var
  Komutlar: TArray<string>;
  Eslesme: TMatch;
  Mevcut, Yazilan: string;
begin
  Result := '';
  Komutlar := KomutlaraBol(Metin);
  if Length(Komutlar) = 0 then
    Exit;
  Eslesme := TRegEx.Match(Komutlar[0], BASLIK, [roIgnoreCase, roSingleLine]);
  if not Eslesme.Success then
    Exit;
  Yazilan := '';
  if (Eslesme.Groups.Count > 2) and Eslesme.Groups[2].Success then
    Yazilan := AdCoz(Eslesme.Groups[2].Value);
  try
    Mevcut := TetikleyiciBilgisiOku(Bag, Ad).Tablo;
  except
    on E: Exception do
      Exit(E.Message);
  end;
  if Yazilan <> Mevcut then
    Result := TF('ERR_TRG_TABLO_DEGISTI', [Ad, IfThen(Mevcut = '', '-', Mevcut), IfThen(Yazilan = '', '-', Yazilan)]);
end;

function ProsedurDuzenleMetni(Bag: TAcikBaglanti; const Ad: string): string;
begin
  Result := NesneDuzenleMetni(Bag, ntProsedur, Ad);
end;

function ProsedurAdiniDogrula(const Metin, Ad: string): string;
begin
  Result := NesneAdiniDogrula(ntProsedur, Metin, Ad);
end;

function ProsedurKaydet(Bag: TAcikBaglanti; const Ad, Metin: string): TProsedurSonucu;
begin
  Result := NesneKaydet(Bag, ntProsedur, Ad, Metin);
end;

function ProsedurYedekKlasoru(const BaglantiAd: string): string;
var
  Temiz: string;
  Harf: Char;
begin
  Temiz := '';
  for Harf in BaglantiAd do
    if CharInSet(Harf, ['\', '/', ':', '*', '?', '"', '<', '>', '|']) or (Ord(Harf) < 32) then
      Temiz := Temiz + '_'
    else
      Temiz := Temiz + Harf;
  Result := TPath.Combine(TPath.Combine(UygulamaVeriKlasoru, '_arsiv'), Trim(Temiz));
end;

function SqlOzeti(const Komut: string): string;
var
  Satirlar: TArray<string>;
  Metin: string;
begin
  Metin := Trim(StringReplace(Komut, #13, '', [rfReplaceAll]));
  Satirlar := Metin.Split([#10]);
  if Length(Satirlar) <= 1 then
    Result := Metin
  else
    Result := TrimRight(Satirlar[0]) + ' ... ' + TF('PRS_SATIR_SAYISI', [Length(Satirlar)]);
end;

function HataSatiriBul(const HamMesaj: string): Integer;
var
  Eslesme: TMatch;
begin
  Eslesme := TRegEx.Match(HamMesaj, 'line\s+(\d+),\s*column\s+\d+', [roIgnoreCase]);
  if Eslesme.Success then
    Result := StrToIntDef(Eslesme.Groups[1].Value, 0)
  else
    Result := 0;
end;

{ Eski tanimi yedek dosyasina yazar, dosyanin yolunu verir. Her hata EProsedurYedek olarak gelir. }
function EskiTanimiYedekle(Bag: TAcikBaglanti; Tur: TNesneTuru; const Ad: string): string;
var
  Klasor, Dosya, Metin: string;
  Kodlama: TEncoding;
  No: Integer;
begin
  try
    Metin := NesneDuzenleMetni(Bag, Tur, Ad);
    Klasor := ProsedurYedekKlasoru(Bag.Tanim.Ad);
    ForceDirectories(Klasor);
    if not DirectoryExists(Klasor) then
      raise EProsedurYedek.Create(Klasor);
    Dosya := TPath.Combine(Klasor, DosyaOnEki(Tur) + ReplaceStr(ReplaceStr(Ad, '"', '_'), ' ', '_') + '_' +
      FormatDateTime('yyyymmdd_hhnnss', Now) + '.sql');
    No := 1;
    while FileExists(Dosya) do
    begin
      Inc(No);
      Dosya := TPath.Combine(Klasor, DosyaOnEki(Tur) + ReplaceStr(ReplaceStr(Ad, '"', '_'), ' ', '_') + '_' +
        FormatDateTime('yyyymmdd_hhnnss', Now) + '_' + IntToStr(No) + '.sql');
    end;
    Metin := '-- ' + T(TurOnEki(Tur) + '_YEDEK_BASLIK') + ': ' + Ad + ' (' + Bag.Tanim.Ad + ')  ' +
      FormatDateTime('yyyy-mm-dd hh:nn:ss', Now) + sLineBreak +
      'SET NAMES ' + ScriptKarakterSeti(Bag) + ';' + sLineBreak + sLineBreak + Metin;
    Kodlama := ScriptKodlamasiOlustur(Bag);
    try
      TFile.WriteAllText(Dosya, Metin, Kodlama);
    finally
      Kodlama.Free;
    end;
    Result := Dosya;
  except
    on E: EProsedurYedek do
      raise;
    on E: Exception do
      raise EProsedurYedek.Create(E.Message);
  end;
end;

{ Komutun metindeki yeri (Aranan'dan itibaren aranir) ve ondan onceki satir sayisi. Hata satiri editor satirina cevrilirken eklenir. }
function KomutunOncekiSatiri(const Metin, Komut: string; var Aranan: Integer): Integer;
var
  Yer, i: Integer;
begin
  Result := 0;
  Yer := PosEx(Komut, Metin, Aranan);
  if Yer = 0 then
    Exit;
  Aranan := Yer + Length(Komut);
  for i := 1 to Yer - 1 do
    if Metin[i] = #10 then
      Inc(Result);
end;

function NesneKaydet(Bag: TAcikBaglanti; Tur: TNesneTuru; const Ad, Metin: string): TProsedurSonucu;
var
  Komutlar: TArray<string>;
  Komut: string;
  Islem: TFDTransaction;
  Sorgu: TFDQuery;
  Aranan, Once, Satir: Integer;
  KomutCalisiyor: Boolean;
begin
  Result := Default(TProsedurSonucu);
  Result.Cumle := NesneAdiniDogrula(Tur, Metin, Ad);
  if (Result.Cumle = '') and (Tur = ntTetikleyici) then
    Result.Cumle := TetikleyiciTablosunuDogrula(Bag, Metin, Ad);
  if Result.Cumle <> '' then
    Exit;
  try
    Result.YedekDosyasi := EskiTanimiYedekle(Bag, Tur, Ad);
  except
    on E: EProsedurYedek do
    begin
      Result.Cumle := T('ERR_PRS_YEDEK_YAZILAMADI');
      Result.Ayrinti := E.Message;
      Exit;
    end;
  end;
  Komutlar := KomutlaraBol(Metin);
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
    Aranan := 1;
    Once := 0;
    KomutCalisiyor := False;
    try
      Islem.StartTransaction;
      for Komut in Komutlar do
      begin
        Once := KomutunOncekiSatiri(Metin, Komut, Aranan);
        Result.Komutlar := Result.Komutlar + [SqlOzeti(Komut)];
        Sorgu.SQL.Text := Komut;
        KomutCalisiyor := True;
        Sorgu.ExecSQL;
        KomutCalisiyor := False;
      end;
      Islem.Commit;
      Result.Basarili := True;
    except
      on E: Exception do
      begin
        try
          if Islem.Active then
            Islem.Rollback;
        except
          { Rollback da basarisiz olursa asil hata gosterilir. }
        end;
        Result.Cumle := HataMetniniCevir(E);
        Result.Ayrinti := E.Message;
        Satir := HataSatiriBul(E.Message);
        if KomutCalisiyor and (Satir > 0) then
          Result.Satir := Once + Satir;
      end;
    end;
  finally
    Sorgu.Free;
    Islem.Free;
  end;
end;

end.
