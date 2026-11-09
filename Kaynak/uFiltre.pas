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

{ Eski filtre doluysa "(eski) AND yeni", degilse yeni. }
function FiltreBirlestir(const Eski, Yeni: string): string;

implementation

uses
  uSorgu;

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

function FiltreBirlestir(const Eski, Yeni: string): string;
begin
  if Trim(Eski) = '' then
    Exit(Yeni);
  { Eski filtrede "--" yorumu varsa kapatan parantez yenisine yazilsin diye satir sonu konur. }
  if Pos('--', Eski) > 0 then
    Result := '(' + Eski + sLineBreak + ') AND ' + Yeni
  else
    Result := '(' + Eski + ') AND ' + Yeni;
end;

end.
