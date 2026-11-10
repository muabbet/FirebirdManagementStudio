{ uFiltre.pas - Tablo gridinde bir hucreye sag tiklayinca filtre (Asama 7 sonrasi, gunluk is).
  Hucrenin degerinden WHERE parcasi uretir (ornek: "TUTAR" > 100). Form sadece menuyu bilir, SQL'i burasi yazar.
  Uretilen yazi uSorgu.FiltreKosulu ile sorguya girer; baska bir filtre zaten varsa VE ile eklenir. }
unit uFiltre;

interface

uses
  System.SysUtils, Data.DB;

type
  { Sag tik menusundeki islemler. }
  THucreIslemi = (hiEsit, hiFarkli, hiBuyuk, hiKucuk, hiIceren, hiBos, hiBosDegil);

{ BLOB ve ikili kolonlarda filtre yapilmaz. }
function FiltreyeUygunMu(Alan: TField): Boolean;
{ "Iceren" yalniz yazi kolonlarinda anlamli. }
function MetinAlaniMi(Alan: TField): Boolean;
{ "Buyuk" ve "kucuk" sayi, tarih ve saat kolonlarinda anlamli. }
function SiralanabilirMi(Alan: TField): Boolean;

{ Hucrenin degerinden kosul uretir. Hucre bos (NULL) ise yalniz hiBos / hiBosDegil verilebilir. }
function HucreFiltresi(Alan: TField; Islem: THucreIslemi): string;

{ Eski filtre doluysa "(eski) AND yeni", degilse yeni; yeni bossa eski aynen kalir. }
function FiltreBirlestir(const Eski, Yeni: string): string;

{ Kolon altindaki filtre kutusuna yazilanlari kosula cevirir (cxGrid'deki filtre satiri gibi). Yazi bossa sonuc bos.
  Gecersiz yazida sonuc bos kalir, Hata anlasilir cumleyle dolar (kutu kirmizi olur, sorgu calismaz).
  Yazim: ad (iceren), ad* (ile baslayan), =5, >10, >=10, <10, <=10, <>5, 10..20 (arasi), - (bos), !- (bos olmayan).
  Sayi ve tarih kolonunda yalniz deger "esit" demektir; tarih: 2026-11-09 ya da 09.11.2026. }
function SatirFiltresi(const AlanAdi: string; Tur: TFieldType; const Yazi: string; out Hata: string): string;

implementation

uses
  System.StrUtils, uDil, uSorgu;

type
  TSutunTuru = (stMetin, stSayi, stTarih, stSaat, stZaman, stMantik);

function FiltreyeUygunMu(Alan: TField): Boolean;
begin
  Result := not (Alan.DataType in [ftBlob, ftGraphic, ftBytes, ftVarBytes, ftTypedBinary, ftOraBlob, ftOraClob]);
end;

function MetinAlaniMi(Alan: TField): Boolean;
begin
  Result := Alan.DataType in [ftString, ftWideString, ftFixedChar, ftFixedWideChar, ftMemo, ftWideMemo, ftFmtMemo];
end;

function SiralanabilirMi(Alan: TField): Boolean;
begin
  Result := Alan.DataType in [ftSmallint, ftInteger, ftWord, ftLargeint, ftAutoInc, ftShortint, ftByte, ftLongWord,
    ftFloat, ftCurrency, ftBCD, ftFMTBcd, ftSingle, ftExtended, ftDate, ftTime, ftDateTime, ftTimeStamp];
end;

{ Degerin SQL'deki yazilisi; yazi ve tarihler tirnaklanir, tirnak isareti ikilenir. }
function DegerYazisi(Alan: TField): string;
begin
  case Alan.DataType of
    ftSmallint, ftInteger, ftWord, ftLargeint, ftAutoInc, ftShortint, ftByte, ftLongWord,
    ftFloat, ftCurrency, ftBCD, ftFMTBcd, ftSingle, ftExtended:
      Result := StringReplace(Alan.AsString, FormatSettings.DecimalSeparator, '.', []);
    ftBoolean:
      if Alan.AsBoolean then
        Result := 'TRUE'
      else
        Result := 'FALSE';
    ftDate:
      Result := '''' + FormatDateTime('yyyy-mm-dd', Alan.AsDateTime) + '''';
    ftTime:
      Result := '''' + FormatDateTime('hh:nn:ss', Alan.AsDateTime) + '''';
    ftDateTime, ftTimeStamp:
      Result := '''' + FormatDateTime('yyyy-mm-dd hh:nn:ss', Alan.AsDateTime) + '''';
  else
    Result := '''' + StringReplace(Alan.AsString, '''', '''''', [rfReplaceAll]) + '''';
  end;
end;

function HucreFiltresi(Alan: TField; Islem: THucreIslemi): string;
var
  Kolon: string;
begin
  Kolon := TirnakliAd(Alan.FieldName);
  case Islem of
    hiBos:
      Exit(Kolon + ' IS NULL');
    hiBosDegil:
      Exit(Kolon + ' IS NOT NULL');
  end;
  if Alan.IsNull then
    Exit(Kolon + ' IS NULL');
  case Islem of
    hiEsit: Result := Kolon + ' = ' + DegerYazisi(Alan);
    hiFarkli: Result := Kolon + ' <> ' + DegerYazisi(Alan);
    hiBuyuk: Result := Kolon + ' > ' + DegerYazisi(Alan);
    hiKucuk: Result := Kolon + ' < ' + DegerYazisi(Alan);
  else
    Result := Kolon + ' CONTAINING ''' + StringReplace(Alan.AsString, '''', '''''', [rfReplaceAll]) + '''';
  end;
end;

function SutunTuru(Tur: TFieldType): TSutunTuru;
begin
  case Tur of
    ftSmallint, ftInteger, ftWord, ftLargeint, ftAutoInc, ftShortint, ftByte, ftLongWord,
    ftFloat, ftCurrency, ftBCD, ftFMTBcd, ftSingle, ftExtended:
      Result := stSayi;
    ftDate: Result := stTarih;
    ftTime: Result := stSaat;
    ftDateTime, ftTimeStamp: Result := stZaman;
    ftBoolean: Result := stMantik;
  else
    Result := stMetin;
  end;
end;

function TirnakliMetin(const Metin: string): string;
begin
  Result := '''' + StringReplace(Metin, '''', '''''', [rfReplaceAll]) + '''';
end;

{ Yalniz rakam, +, -, nokta ve e kabul edilir; virgul ondalik ayiraci sayilir. }
function SayiYazisi(const Metin: string; out Yazi: string): Boolean;
var
  S: string;
  D: Double;
  i: Integer;
begin
  Result := False;
  S := StringReplace(Trim(Metin), ',', '.', [rfReplaceAll]);
  if S = '' then
    Exit;
  for i := 1 to Length(S) do
    if not CharInSet(S[i], ['0'..'9', '+', '-', '.', 'e', 'E']) then
      Exit;
  if not TryStrToFloat(S, D, TFormatSettings.Invariant) then
    Exit;
  Yazi := S;
  Result := True;
end;

{ 2026-11-09 (ISO) ya da bilgisayarin tarih bicimi (09.11.2026); ayirici yoksa tarih sayilmaz ("5" tarih degildir). }
function ZamanOku(const Metin: string; out Zaman: TDateTime): Boolean;
var
  Iso: TFormatSettings;
  S: string;
begin
  Result := False;
  S := Trim(Metin);
  if (Pos('-', S) = 0) and (Pos('.', S) = 0) and (Pos('/', S) = 0) then
    Exit;
  Iso := TFormatSettings.Invariant;
  Iso.DateSeparator := '-';
  Iso.ShortDateFormat := 'yyyy-mm-dd';
  Iso.TimeSeparator := ':';
  Iso.ShortTimeFormat := 'hh:nn';
  Iso.LongTimeFormat := 'hh:nn:ss';
  Result := TryStrToDateTime(S, Zaman, Iso) or TryStrToDateTime(S, Zaman);
end;

function MantikYazisi(const Metin: string; out Yazi: string): Boolean;
var
  S: string;
begin
  S := LowerCase(Trim(Metin));
  Result := True;
  if MatchStr(S, ['true', '1', 'evet', 'yes', 'ja', 'do' + #$011F + 'ru', 'dogru']) then
    Yazi := 'TRUE'
  else if MatchStr(S, ['false', '0', 'hayir', 'hay' + #$0131 + 'r', 'no', 'nein', 'yanlis', 'yanl' + #$0131 + 's']) then
    Yazi := 'FALSE'
  else
    Result := False;
end;

{ Yazilan degerin SQL'deki yazilisi (sayi, tarih, saat, tirnakli yazi); gecersizse Hata dolar. }
function MetinDegeriYazisi(Turu: TSutunTuru; const Metin: string; out Yazi, Hata: string): Boolean;
var
  Zaman: TDateTime;
begin
  Result := True;
  Hata := '';
  case Turu of
    stSayi:
      if not SayiYazisi(Metin, Yazi) then
      begin
        Hata := TF('FILTRE_HATA_SAYI', [Metin]);
        Result := False;
      end;
    stTarih, stZaman:
      if not ZamanOku(Metin, Zaman) then
      begin
        Hata := TF('FILTRE_HATA_TARIH', [Metin]);
        Result := False;
      end
      else if Turu = stTarih then
        Yazi := '''' + FormatDateTime('yyyy-mm-dd', Zaman) + ''''
      else
        Yazi := '''' + FormatDateTime('yyyy-mm-dd hh:nn:ss', Zaman) + '''';
    stSaat:
      if (Pos(':', Metin) = 0) or not TryStrToTime(Trim(Metin), Zaman) then
      begin
        Hata := TF('FILTRE_HATA_SAAT', [Metin]);
        Result := False;
      end
      else
        Yazi := '''' + FormatDateTime('hh:nn:ss', Zaman) + '''';
    stMantik:
      if not MantikYazisi(Metin, Yazi) then
      begin
        Hata := TF('FILTRE_HATA_MANTIK', [Metin]);
        Result := False;
      end;
  else
    Yazi := TirnakliMetin(Metin);
  end;
end;

{ Zaman damgasi kolonunda saatsiz tarih yazilirsa o gunun tamamini kapsar: >= gun 00:00 ve < ertesi gun 00:00. }
function GunAraligi(const Kolon: string; Bas, Son: TDateTime): string;
begin
  Result := '(' + Kolon + ' >= ''' + FormatDateTime('yyyy-mm-dd', Bas) + ' 00:00:00'' AND ' + Kolon + ' < ''' +
    FormatDateTime('yyyy-mm-dd', Son + 1) + ' 00:00:00'')';
end;

function SatirFiltresi(const AlanAdi: string; Tur: TFieldType; const Yazi: string; out Hata: string): string;
var
  Turu: TSutunTuru;
  Metin, Islem, Sol, Sag, YazSol, YazSag, Kolon: string;
  P: Integer;
  ZamanSol, ZamanSag: TDateTime;
begin
  Hata := '';
  Result := '';
  Metin := Trim(Yazi);
  if Metin = '' then
    Exit;
  Turu := SutunTuru(Tur);
  Kolon := TirnakliAd(AlanAdi);
  if Metin = '-' then
    Exit(Kolon + ' IS NULL');
  if Metin = '!-' then
    Exit(Kolon + ' IS NOT NULL');

  { Arasi: 10..20 (yalniz sayi ve tarih turlerinde) }
  P := Pos('..', Metin);
  if (Turu in [stSayi, stTarih, stSaat, stZaman]) and (P > 1) and (P < Length(Metin) - 1) then
  begin
    Sol := Trim(Copy(Metin, 1, P - 1));
    Sag := Trim(Copy(Metin, P + 2, MaxInt));
    if not MetinDegeriYazisi(Turu, Sol, YazSol, Hata) then
      Exit;
    if not MetinDegeriYazisi(Turu, Sag, YazSag, Hata) then
      Exit;
    if (Turu = stZaman) and (Pos(':', Sag) = 0) and ZamanOku(Sol, ZamanSol) and ZamanOku(Sag, ZamanSag) then
      Exit(GunAraligi(Kolon, ZamanSol, ZamanSag));
    Exit(Kolon + ' BETWEEN ' + YazSol + ' AND ' + YazSag);
  end;

  { Basindaki islem: >= <= <> != > < = }
  Islem := '';
  if StartsStr('>=', Metin) or StartsStr('<=', Metin) or StartsStr('<>', Metin) or StartsStr('!=', Metin) then
  begin
    Islem := Copy(Metin, 1, 2);
    if Islem = '!=' then
      Islem := '<>';
    Metin := Trim(Copy(Metin, 3, MaxInt));
  end
  else if CharInSet(Metin[1], ['>', '<', '=']) then
  begin
    Islem := Metin[1];
    Metin := Trim(Copy(Metin, 2, MaxInt));
  end;
  { Yalniz islem yazildi, deger daha yazilmadi: henuz filtre yok. }
  if Metin = '' then
    Exit;

  if Turu = stMetin then
  begin
    if Islem <> '' then
      Exit(Kolon + ' ' + Islem + ' ' + TirnakliMetin(Metin));
    if (Length(Metin) > 1) and EndsStr('*', Metin) then
      Exit('UPPER(' + Kolon + ') STARTING WITH UPPER(' + TirnakliMetin(Copy(Metin, 1, Length(Metin) - 1)) + ')');
    if (Length(Metin) > 1) and StartsStr('*', Metin) then
      Metin := Copy(Metin, 2, MaxInt);
    Exit(Kolon + ' CONTAINING ' + TirnakliMetin(Metin));
  end;

  if not MetinDegeriYazisi(Turu, Metin, YazSol, Hata) then
    Exit;
  if (Islem = '') or (Islem = '=') then
  begin
    if (Turu = stZaman) and (Pos(':', Metin) = 0) and ZamanOku(Metin, ZamanSol) then
      Exit(GunAraligi(Kolon, ZamanSol, ZamanSol));
    Exit(Kolon + ' = ' + YazSol);
  end;
  Result := Kolon + ' ' + Islem + ' ' + YazSol;
end;

function FiltreBirlestir(const Eski, Yeni: string): string;
begin
  if Trim(Yeni) = '' then
    Exit(Eski);
  if Trim(Eski) = '' then
    Exit(Yeni);
  { Eski filtrede "--" yorumu varsa kapatan parantez yenisine yazilsin diye satir sonu konur. }
  if Pos('--', Eski) > 0 then
    Result := '(' + Eski + sLineBreak + ') AND ' + Yeni
  else
    Result := '(' + Eski + ') AND ' + Yeni;
end;

end.
