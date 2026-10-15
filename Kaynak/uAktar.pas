{ uAktar.pas - Sonucu CSV dosyasina aktarma (Asama 3b).

  Hedeflenen Firebird surumleri: 2.5, 3.0, 4.0, 5.0
  Denenen Firebird surumleri: 5.0.4 (2.5.9 sunucuda sahibi deneyecek; 3.0 ve 4.0 henuz denenmedi)

  Disa aktarma, sonucu ureten SELECT'i yeniden calistirir: ayni baglantida, YENI ve SALT OKUNUR bir islemle.
  Satirlar bellekte biriktirilmez, tek tek dosyaya yazilir; bellek satir sayisina bagli buyumez.
  Windows'a bagli tek sey liste ayraci ve ondalik ayracidir (WindowsCsvSecenekleri). }
unit uAktar;

interface

uses
  System.SysUtils, System.Classes, uBaglanti;

const
  { Excel bir sayfada en fazla bu kadar veri satiri (baslik haric) acabilir. }
  EXCEL_SATIR_SINIRI = 1048575;

type
  TCsvSecenekleri = record
    Ayrac: Char;
    Ondalik: Char;
  end;

  { Satirlar yazilirken sik sik cagrilir. Iptal True yapilirsa aktarma durur. }
  TCsvIlerlemesi = procedure(SatirSayisi: Int64; var Iptal: Boolean) of object;

{ Kullanicinin Windows liste ayraci ve ondalik ayraci. Liste ayraci bos ya da ondalik ayraciyla ayniysa ';' olur. }
function WindowsCsvSecenekleri: TCsvSecenekleri;

{ "tablo_20260101_120000.csv" gibi varsayilan dosya adi (dosya adinda olmaz denen karakterler '_' olur). }
function VarsayilanCsvAdi(const Ad: string): string;

{ Sql'i yeni, salt okunur bir islemle yeniden calistirir ve tum satirlari CSV olarak Yazici'ya yazar
  (UTF-8 BOM'u kodlamayi kuran cagirandadir). Ilk satir kolon adlaridir. SatirSayisi baslik haric yazilan satirdir.
  Ikili BLOB kolonlari bos yazilir; ikili kolon atlandiysa ve/veya Excel siniri asildiysa Uyarilar'a cumle eklenir.
  Iptalde False doner; yazilan kisim tam satirlardan olusur. Hata istisna olarak firlar
  (cagiran AktarmaHatasiniCevir ile gosterir). }
function CsvAktar(Bag: TAcikBaglanti; const Sql: string; Yazici: TTextWriter; const Secenekler: TCsvSecenekleri;
  Uyarilar: TStrings; Ilerleme: TCsvIlerlemesi; out SatirSayisi: Int64): Boolean;

{ Aktarma hatasini anlasilir cumleye cevirir: dosya sorunlari (klasor yok, disk dolu, dosya acik) icin
  kendi cumlemiz, veritabani hatalari icin uBaglanti.HataMetniniCevir. }
function AktarmaHatasiniCevir(Hata: Exception): string;

implementation

uses
  Winapi.Windows, System.Math, Data.DB, Data.FmtBcd,
  FireDAC.Stan.Intf, FireDAC.Stan.Option, FireDAC.Stan.Param, FireDAC.Stan.Error,
  FireDAC.DatS, FireDAC.Phys.Intf, FireDAC.DApt.Intf, FireDAC.Comp.DataSet, FireDAC.Comp.Client,
  uDil;

const
  { Ekrandaki sonuc 500'er satir cekilir; aktarma da ayni buyuklukte parcalarla okur. }
  OKUMA_PARCASI = 500;
  { Ilerleme geri cagrisi bu kadar satirda bir cagrilir. }
  ILERLEME_ARALIGI = 100;

type
  TKolonTuru = (ktMetin, ktTamSayi, ktKayan, ktTekKayan, ktBcd, ktTarih, ktSaat, ktZaman, ktMantik,
    ktMetinBlob, ktIkili);

function YerelBilgi(Tur: LCTYPE): string;
var
  Tampon: array[0..15] of Char;
begin
  Result := '';
  if GetLocaleInfo(LOCALE_USER_DEFAULT, Tur, Tampon, Length(Tampon)) > 0 then
    Result := Tampon;
end;

function WindowsCsvSecenekleri: TCsvSecenekleri;
var
  Ayrac, Ondalik: string;
begin
  Ayrac := YerelBilgi(LOCALE_SLIST);
  Ondalik := YerelBilgi(LOCALE_SDECIMAL);
  if Length(Ondalik) = 1 then
    Result.Ondalik := Ondalik[1]
  else
    Result.Ondalik := ',';
  if (Length(Ayrac) = 1) and (Ayrac[1] <> Result.Ondalik) then
    Result.Ayrac := Ayrac[1]
  else
    Result.Ayrac := ';';
  { Ondalik ayrac ';' ise (cok olagandisi) ayrac ile cakismasin diye ayrac ',' olur. }
  if Result.Ayrac = Result.Ondalik then
    Result.Ayrac := ',';
end;

function VarsayilanCsvAdi(const Ad: string): string;
const
  OLMAZ = '\/:*?"<>|';
var
  i: Integer;
begin
  Result := Ad;
  for i := 1 to Length(Result) do
    if (Pos(Result[i], OLMAZ) > 0) or (Result[i] < ' ') then
      Result[i] := '_';
  Result := Result + '_' + FormatDateTime('yyyymmdd_hhnnss', Now) + '.csv';
end;

{ Ayrac, " veya satir sonu iceren deger "..." icine alinir, icindeki " ikiye katlanir. }
function CsvAlani(const Deger: string; Ayrac: Char): string;
begin
  if (Pos(Ayrac, Deger) > 0) or (Pos('"', Deger) > 0) or (Pos(#13, Deger) > 0) or (Pos(#10, Deger) > 0) then
    Result := '"' + StringReplace(Deger, '"', '""', [rfReplaceAll]) + '"'
  else
    Result := Deger;
end;

{ Kayan noktali sayiyi bilimsel gosterim (1E+05) kullanmadan yazar. Basamak: anlamli hane sayisi
  (FLOAT icin 7, DOUBLE icin 15; 0.1 degeri 0.10000000000000001 gibi gurultuyle cikmasin). }
function KayanYaz(Deger: Double; Basamak: Integer; Ondalik: Char): string;
var
  Kayit: TFloatRec;
  Genis: Extended;
  Rakamlar: string;
  Us, i: Integer;
begin
  if IsNaN(Deger) or IsInfinite(Deger) then
    Exit('');
  Genis := Deger;
  FloatToDecimal(Kayit, Genis, fvExtended, Basamak, 9999);
  Rakamlar := '';
  i := 0;
  while (i < Length(Kayit.Digits)) and (Kayit.Digits[i] <> 0) do
  begin
    Rakamlar := Rakamlar + Chr(Kayit.Digits[i]);
    Inc(i);
  end;
  while (Rakamlar <> '') and (Rakamlar[Length(Rakamlar)] = '0') do
    Delete(Rakamlar, Length(Rakamlar), 1);
  if Rakamlar = '' then
    Exit('0');
  { Deger = 0.RAKAMLAR x 10^Us }
  Us := Kayit.Exponent;
  if Us <= 0 then
    Result := '0' + Ondalik + StringOfChar('0', -Us) + Rakamlar
  else if Us >= Length(Rakamlar) then
    Result := Rakamlar + StringOfChar('0', Us - Length(Rakamlar))
  else
    Result := Copy(Rakamlar, 1, Us) + Ondalik + Copy(Rakamlar, Us + 1, MaxInt);
  if Kayit.Negative then
    Result := '-' + Result;
end;

function KolonTuruBul(Alan: TField): TKolonTuru;
begin
  case Alan.DataType of
    ftSmallint, ftInteger, ftLargeint, ftWord, ftShortint, ftByte, ftLongWord, ftAutoInc:
      Result := ktTamSayi;
    ftFloat, ftExtended:
      Result := ktKayan;
    ftSingle:
      Result := ktTekKayan;
    ftBCD, ftFMTBCD, ftCurrency:
      Result := ktBcd;
    ftDate:
      Result := ktTarih;
    ftTime:
      Result := ktSaat;
    ftDateTime, ftTimeStamp:
      Result := ktZaman;
    ftBoolean:
      Result := ktMantik;
    ftMemo, ftWideMemo, ftFmtMemo:
      Result := ktMetinBlob;
    ftBlob, ftGraphic, ftTypedBinary, ftBytes, ftVarBytes, ftOraBlob, ftOraClob:
      Result := ktIkili;
  else
    Result := ktMetin;
  end;
end;

function DegeriYaz(Alan: TField; Tur: TKolonTuru; const Bicim: TFormatSettings): string;
begin
  if Alan.IsNull then
    Exit('');
  case Tur of
    ktTamSayi:
      Result := IntToStr(Alan.AsLargeInt);
    ktKayan:
      Result := KayanYaz(Alan.AsFloat, 15, Bicim.DecimalSeparator);
    ktTekKayan:
      Result := KayanYaz(Alan.AsFloat, 7, Bicim.DecimalSeparator);
    ktBcd:
      Result := BcdToStr(Alan.AsBCD, Bicim);
    ktTarih:
      Result := FormatDateTime('yyyy-mm-dd', Alan.AsDateTime, Bicim);
    ktSaat:
      Result := FormatDateTime('hh:nn:ss', Alan.AsDateTime, Bicim);
    ktZaman:
      Result := FormatDateTime('yyyy-mm-dd hh:nn:ss', Alan.AsDateTime, Bicim);
    ktMantik:
      if Alan.AsBoolean then
        Result := 'TRUE'
      else
        Result := 'FALSE';
    ktIkili:
      Result := '';
  else
    Result := Alan.AsString;
  end;
end;

function CsvAktar(Bag: TAcikBaglanti; const Sql: string; Yazici: TTextWriter; const Secenekler: TCsvSecenekleri;
  Uyarilar: TStrings; Ilerleme: TCsvIlerlemesi; out SatirSayisi: Int64): Boolean;
var
  Islem: TFDTransaction;
  Sorgu: TFDQuery;
  Kural: TFDMapRule;
  Bicim: TFormatSettings;
  Turler: array of TKolonTuru;
  Satir: TStringBuilder;
  Atlanan: string;
  i: Integer;
  Iptal: Boolean;
begin
  SatirSayisi := 0;
  Result := True;
  Iptal := False;
  Bicim := TFormatSettings.Invariant;
  Bicim.DecimalSeparator := Secenekler.Ondalik;
  Islem := TFDTransaction.Create(nil);
  Sorgu := TFDQuery.Create(nil);
  Satir := TStringBuilder.Create;
  try
    Islem.Connection := Bag.Baglanti;
    { Salt okunur: SELECT ... FROM prosedur gibi yan etkili bir komut veri yazamaz, Firebird hata verir.
      Anlik goruntu: uzun surse bile dosya tek bir andaki veriyi yansitir. }
    Islem.Options.ReadOnly := True;
    Islem.Options.Isolation := xiSnapshot;
    Islem.Options.AutoCommit := False;
    Sorgu.Connection := Bag.Baglanti;
    Sorgu.Transaction := Islem;
    { Komut oldugu gibi gitsin: ':ad' parametre, '!ad' makro sayilmasin. }
    Sorgu.ResourceOptions.ParamCreate := False;
    Sorgu.ResourceOptions.MacroCreate := False;
    Sorgu.ResourceOptions.MacroExpand := False;
    Sorgu.ResourceOptions.EscapeExpand := False;
    Sorgu.UpdateOptions.ReadOnly := True;
    { Bellekte biriktirme yok: parca parca okunur, okunan satir birakilir. }
    Sorgu.FetchOptions.Mode := fmOnDemand;
    Sorgu.FetchOptions.Unidirectional := True;
    Sorgu.FetchOptions.RowsetSize := OKUMA_PARCASI;
    Sorgu.FetchOptions.Cache := [];
    { NUMERIC(18,2) gibi degerler Currency'ye (4 hane, ~9e14) sigmasin diye hep FMTBCD okunur. }
    Sorgu.FormatOptions.OwnMapRules := True;
    Kural := Sorgu.FormatOptions.MapRules.Add;
    Kural.SourceDataType := dtBCD;
    Kural.TargetDataType := dtFmtBCD;
    Sorgu.SQL.Text := Trim(Sql);
    Sorgu.Open;

    SetLength(Turler, Sorgu.FieldCount);
    Atlanan := '';
    for i := 0 to Sorgu.FieldCount - 1 do
    begin
      Turler[i] := KolonTuruBul(Sorgu.Fields[i]);
      if Turler[i] = ktIkili then
      begin
        if Atlanan <> '' then
          Atlanan := Atlanan + ', ';
        Atlanan := Atlanan + Sorgu.Fields[i].FieldName;
      end;
      if i > 0 then
        Satir.Append(Secenekler.Ayrac);
      Satir.Append(CsvAlani(Sorgu.Fields[i].FieldName, Secenekler.Ayrac));
    end;
    Satir.Append(#13#10);
    Yazici.Write(Satir.ToString);

    while not Sorgu.Eof do
    begin
      Satir.Clear;
      for i := 0 to Sorgu.FieldCount - 1 do
      begin
        if i > 0 then
          Satir.Append(Secenekler.Ayrac);
        Satir.Append(CsvAlani(DegeriYaz(Sorgu.Fields[i], Turler[i], Bicim), Secenekler.Ayrac));
      end;
      Satir.Append(#13#10);
      Yazici.Write(Satir.ToString);
      Inc(SatirSayisi);
      if (SatirSayisi mod ILERLEME_ARALIGI = 0) and Assigned(Ilerleme) then
      begin
        Ilerleme(SatirSayisi, Iptal);
        if Iptal then
        begin
          Result := False;
          Break;
        end;
      end;
      Sorgu.Next;
    end;
    Yazici.Flush;
    if Assigned(Ilerleme) and Result then
      Ilerleme(SatirSayisi, Iptal);
    if Atlanan <> '' then
      Uyarilar.Add(TF('AKTAR_UYARI_BLOB', [Atlanan]));
    if SatirSayisi > EXCEL_SATIR_SINIRI then
      Uyarilar.Add(TF('AKTAR_UYARI_EXCEL', [EXCEL_SATIR_SINIRI]));
  finally
    Satir.Free;
    Sorgu.Free;
    { Salt okunur islemde commit ile rollback ayni sonucu verir; hicbir sey degismez. }
    if Islem.Active then
      Islem.Rollback;
    Islem.Free;
  end;
end;

function AktarmaHatasiniCevir(Hata: Exception): string;
begin
  { EStreamError: dosya acilamadi/yazilamadi; EInOutError: klasor yok, yol gecersiz gibi. }
  if (Hata is EStreamError) or (Hata is EInOutError) then
    Result := T('ERR_AKTAR_DOSYA')
  else
    Result := HataMetniniCevir(Hata);
end;

end.
