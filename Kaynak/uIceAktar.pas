unit uIceAktar;

{ CSV dosyasindan tabloya veri aktarma (Asama 7b).

  Hedeflenen Firebird surumleri: 2.5, 3.0, 4.0, 5.0

  Kurallar (sade ve guvenli):
    - Dosya tablonun YENI satirlarini ekler (INSERT); var olan satirlara dokunmaz.
    - Hepsi TEK islemde calisir: tum satirlar eklenir ve onaylanir (commit), ya da ilk hatada / iptalde HICBIRI eklenmez.
    - Hata satir numarasi, kolon ve deger ile bildirilir (ornek: Satir 12, kolon TARIH: "31.02.2026" tarih olarak okunamadi).
    - Eslenmeyen kolonlar INSERT'e girmez (DEFAULT, generator ve tetikleyici onlari doldurur). Bos hucre NULL olur
      (metin kolonunda da: '' ile NULL ayri tutulmaz). BLOB, hesaplanan ve GENERATED ALWAYS kolonlar aktarilmaz.
    - Dosya bicimi: ayrac (; , sekme |) ve kodlama (UTF-8 / ANSI) dosyadan tahmin edilir, kullanici degistirebilir.
      Disa aktarmanin (uAktar) urettigi dosya aynen okunur. Sayida yalniz secilen ondalik ayraci kabul edilir
      (1.234 ile 1,234 karismasin); tarihte yyyy-mm-dd, dd.mm.yyyy, dd/mm/yyyy; mantikta TRUE/FALSE/1/0/evet/hayir.
  Hata istisna olarak firlamaz, sonuc kaydina yazilir. }

interface

uses
  System.SysUtils, System.Classes, System.Generics.Collections, Data.DB, uBaglanti, uAktar;

type
  TIceKodlama = (ikUtf8, ikAnsi);

  TIceSecenek = record
    Ayrac: Char;
    Ondalik: Char;
    Kodlama: TIceKodlama;
    BaslikVar: Boolean;
  end;

  { Aktarilabilen bir tablo kolonu. }
  TIceKolon = record
    Ad: string;
    Alan: TFieldType;
  end;

  TCsvOnizleme = record
    Baslik: TArray<string>;
    Satirlar: TArray<TArray<string>>;
  end;

  TIceSonuc = record
    Basarili: Boolean;
    Iptal: Boolean;
    Eklenen: Int64;
    Cumle: string;
    Ayrinti: string;
  end;

{ Dosyadan kodlama ve ayraci tahmin eder; ondalik ayraci Windows'tan, ilk satir baslik varsayilir. }
function IceAktarVarsayilan(const Dosya: string): TIceSecenek;

{ Ilk MaxSatir veri satirini okur (baslik satiri varsa ayri verilir). }
function CsvOnizle(const Dosya: string; const Sec: TIceSecenek; MaxSatir: Integer): TCsvOnizleme;

{ Dosyadaki veri satiri sayisi (bos satirlar ve baslik haric). }
function CsvVeriSatiriSayisi(const Dosya: string; const Sec: TIceSecenek): Int64;

{ Tabloya aktarilabilen kolonlar (BLOB, hesaplanan ve GENERATED ALWAYS kimlik kolonlari yok). Hata istisna olarak gelir. }
function IceAktarKolonlari(Bag: TAcikBaglanti; const Tablo: string): TArray<TIceKolon>;

{ Her tablo kolonu icin CSV kolon numarasi (0'dan), eslesme yoksa -1. Baslik varsa ada gore (buyuk/kucuk harf farksiz),
  yoksa ya da hic ad eslesmezse sirayla. }
function OtomatikEsleme(const Kolonlar: TArray<TIceKolon>; const Onizleme: TCsvOnizleme;
  BaslikVar: Boolean): TArray<Integer>;

{ Calisacak INSERT. Gercek=True: parametre adlari :P0, :P1 (calistirmak icin); False: kolon adlari (:AD, :SAYI; onay penceresi ve
  SQL mesaji icin). }
function IceAktarKomutu(const Tablo: string; const Kolonlar: TArray<TIceKolon>; const Esleme: TArray<Integer>;
  Gercek: Boolean): string;

{ Dosyayi tek islemde ekler. Iptal True yapilirsa hicbir sey eklenmez (Sonuc.Iptal). }
function IceAktar(Bag: TAcikBaglanti; const Tablo, Dosya: string; const Sec: TIceSecenek;
  const Kolonlar: TArray<TIceKolon>; const Esleme: TArray<Integer>; Ilerleme: TCsvIlerlemesi): TIceSonuc;

implementation

uses
  System.Math, System.DateUtils, Data.FmtBcd, FireDAC.Stan.Intf, FireDAC.Stan.Option, FireDAC.Stan.Param,
  FireDAC.Comp.Client, uDil, uMetadata, uSorgu;

const
  ILERLEME_ARALIGI = 200;
  KODLAMA_OKUMA = 65536;

type
  { Dosyayi satir satir (kayit kayit) okur. "..." icinde ayrac ve satir sonu olabilir, "" bir tirnak demektir. }
  TCsvOkuyucu = class
  private
    FOkuyucu: TStreamReader;
    FAyrac: Char;
  public
    constructor Create(const Dosya: string; const Sec: TIceSecenek);
    destructor Destroy; override;
    function Oku(out Alanlar: TArray<string>): Boolean;
  end;

constructor TCsvOkuyucu.Create(const Dosya: string; const Sec: TIceSecenek);
begin
  inherited Create;
  FAyrac := Sec.Ayrac;
  if Sec.Kodlama = ikUtf8 then
    FOkuyucu := TStreamReader.Create(Dosya, TEncoding.UTF8, True)
  else
    FOkuyucu := TStreamReader.Create(Dosya, TEncoding.ANSI, False);
end;

destructor TCsvOkuyucu.Destroy;
begin
  FOkuyucu.Free;
  inherited;
end;

function TCsvOkuyucu.Oku(out Alanlar: TArray<string>): Boolean;
var
  Liste: TList<string>;
  Alan: TStringBuilder;
  C: Integer;
  Tirnakta: Boolean;
begin
  Result := False;
  SetLength(Alanlar, 0);
  if FOkuyucu.EndOfStream then
    Exit;
  Liste := TList<string>.Create;
  Alan := TStringBuilder.Create;
  try
    Tirnakta := False;
    while True do
    begin
      C := FOkuyucu.Read;
      if C < 0 then
        Break;
      if Tirnakta then
      begin
        if C = Ord('"') then
        begin
          if FOkuyucu.Peek = Ord('"') then
          begin
            FOkuyucu.Read;
            Alan.Append('"');
          end
          else
            Tirnakta := False;
        end
        else
          Alan.Append(Char(C));
      end
      else if (C = Ord('"')) and (Alan.Length = 0) then
        Tirnakta := True
      else if C = Ord(FAyrac) then
      begin
        Liste.Add(Alan.ToString);
        Alan.Clear;
      end
      else if C = 13 then
      begin
        if FOkuyucu.Peek = 10 then
          FOkuyucu.Read;
        Break;
      end
      else if C = 10 then
        Break
      else
        Alan.Append(Char(C));
    end;
    Liste.Add(Alan.ToString);
    Alanlar := Liste.ToArray;
    Result := True;
  finally
    Alan.Free;
    Liste.Free;
  end;
end;

{ Bos satir (tek bos alan) veri sayilmaz. }
function BosSatir(const Alanlar: TArray<string>): Boolean;
begin
  Result := (Length(Alanlar) = 1) and (Alanlar[0] = '');
end;

{ Bayt dizisi gecerli UTF-8 mi? Okunan parcanin sonundaki yarim kalmis karakter hata sayilmaz. }
function GecerliUtf8(const Bayt: TBytes; Boy: Integer): Boolean;
var
  i, Ek: Integer;
begin
  Result := True;
  i := 0;
  while i < Boy do
  begin
    if Bayt[i] < $80 then
      Ek := 0
    else if (Bayt[i] and $E0) = $C0 then
      Ek := 1
    else if (Bayt[i] and $F0) = $E0 then
      Ek := 2
    else if (Bayt[i] and $F8) = $F0 then
      Ek := 3
    else
      Exit(False);
    if i + Ek >= Boy then
      Exit(True);
    while Ek > 0 do
    begin
      Inc(i);
      if (Bayt[i] and $C0) <> $80 then
        Exit(False);
      Dec(Ek);
    end;
    Inc(i);
  end;
end;

function IceAktarVarsayilan(const Dosya: string): TIceSecenek;
var
  Akis: TFileStream;
  Bayt: TBytes;
  Boy, i, En: Integer;
  Tirnakta: Boolean;
  Sayac: array[0..3] of Integer;
  Adaylar: array[0..3] of Char;
begin
  Result.Ondalik := WindowsCsvSecenekleri.Ondalik;
  Result.Ayrac := WindowsCsvSecenekleri.Ayrac;
  Result.Kodlama := ikUtf8;
  Result.BaslikVar := True;
  Akis := TFileStream.Create(Dosya, fmOpenRead or fmShareDenyNone);
  try
    SetLength(Bayt, KODLAMA_OKUMA);
    Boy := Akis.Read(Bayt[0], KODLAMA_OKUMA);
  finally
    Akis.Free;
  end;
  { BOM varsa UTF-8; yoksa gecerli UTF-8 ise UTF-8, degilse ANSI (Excel'in "CSV" kaydi). }
  if not ((Boy >= 3) and (Bayt[0] = $EF) and (Bayt[1] = $BB) and (Bayt[2] = $BF)) and not GecerliUtf8(Bayt, Boy) then
    Result.Kodlama := ikAnsi;
  { Ayrac: ilk satirda "..." disinda en cok gecen aday. }
  Adaylar[0] := ';';
  Adaylar[1] := ',';
  Adaylar[2] := #9;
  Adaylar[3] := '|';
  for i := 0 to 3 do
    Sayac[i] := 0;
  Tirnakta := False;
  for i := 0 to Boy - 1 do
  begin
    if Bayt[i] = Ord('"') then
      Tirnakta := not Tirnakta
    else if (not Tirnakta) and ((Bayt[i] = 10) or (Bayt[i] = 13)) then
      Break
    else if not Tirnakta then
      for En := 0 to 3 do
        if Bayt[i] = Ord(Adaylar[En]) then
          Inc(Sayac[En]);
  end;
  En := -1;
  for i := 0 to 3 do
    if (Sayac[i] > 0) and ((En < 0) or (Sayac[i] > Sayac[En])) then
      En := i;
  if En >= 0 then
    Result.Ayrac := Adaylar[En];
end;

function CsvOnizle(const Dosya: string; const Sec: TIceSecenek; MaxSatir: Integer): TCsvOnizleme;
var
  Okuyucu: TCsvOkuyucu;
  Alanlar: TArray<string>;
  Liste: TList<TArray<string>>;
begin
  Result := Default(TCsvOnizleme);
  Liste := TList<TArray<string>>.Create;
  Okuyucu := TCsvOkuyucu.Create(Dosya, Sec);
  try
    if Sec.BaslikVar then
    begin
      while Okuyucu.Oku(Alanlar) and BosSatir(Alanlar) do
        ;
      Result.Baslik := Alanlar;
    end;
    while (Liste.Count < MaxSatir) and Okuyucu.Oku(Alanlar) do
      if not BosSatir(Alanlar) then
        Liste.Add(Alanlar);
    Result.Satirlar := Liste.ToArray;
  finally
    Okuyucu.Free;
    Liste.Free;
  end;
end;

function CsvVeriSatiriSayisi(const Dosya: string; const Sec: TIceSecenek): Int64;
var
  Okuyucu: TCsvOkuyucu;
  Alanlar: TArray<string>;
begin
  Result := 0;
  Okuyucu := TCsvOkuyucu.Create(Dosya, Sec);
  try
    while Okuyucu.Oku(Alanlar) do
      if not BosSatir(Alanlar) then
        Inc(Result);
  finally
    Okuyucu.Free;
  end;
  if Sec.BaslikVar and (Result > 0) then
    Dec(Result);
end;

{ Aktarilabilir alan turu mu? (ikili BLOB, dizi vb. degil) }
function AktarilabilirTur(Tur: TFieldType): Boolean;
begin
  Result := Tur in [ftString, ftWideString, ftFixedChar, ftFixedWideChar, ftMemo, ftWideMemo,
    ftSmallint, ftInteger, ftLargeint, ftWord, ftShortint, ftByte, ftLongWord, ftAutoInc,
    ftFloat, ftSingle, ftExtended, ftCurrency, ftBCD, ftFMTBcd,
    ftDate, ftTime, ftDateTime, ftTimeStamp, ftBoolean];
end;

function IceAktarKolonlari(Bag: TAcikBaglanti; const Tablo: string): TArray<TIceKolon>;
var
  Sorgu: TFDQuery;
  Bilgi: TArray<TKolonBilgisi>;
  B: TKolonBilgisi;
  Alan: TField;
  Kolon: TIceKolon;
  Liste: TList<TIceKolon>;
  Kilitli: Boolean;
begin
  Liste := TList<TIceKolon>.Create;
  Sorgu := TFDQuery.Create(nil);
  try
    Sorgu.Connection := Bag.Baglanti;
    Sorgu.SQL.Text := 'SELECT * FROM ' + TirnakliAd(Tablo) + ' WHERE 1 = 0';
    Sorgu.Open;
    Bilgi := KolonlariOku(Bag, Tablo);
    for Alan in Sorgu.Fields do
    begin
      Kilitli := not AktarilabilirTur(Alan.DataType);
      for B in Bilgi do
        if SameText(B.Ad, Alan.FieldName) and ((B.Hesaplanan <> '') or (B.Kimlik and B.KimlikHep)) then
          Kilitli := True;
      if not Kilitli then
      begin
        Kolon.Ad := Alan.FieldName;
        Kolon.Alan := Alan.DataType;
        Liste.Add(Kolon);
      end;
    end;
    Result := Liste.ToArray;
  finally
    Sorgu.Free;
    Liste.Free;
  end;
end;

function OtomatikEsleme(const Kolonlar: TArray<TIceKolon>; const Onizleme: TCsvOnizleme;
  BaslikVar: Boolean): TArray<Integer>;
var
  i, j, SutunSayisi, Eslesen: Integer;
  Satir: TArray<string>;
begin
  SutunSayisi := Length(Onizleme.Baslik);
  for Satir in Onizleme.Satirlar do
    SutunSayisi := Max(SutunSayisi, Length(Satir));
  SetLength(Result, Length(Kolonlar));
  Eslesen := 0;
  for i := 0 to High(Kolonlar) do
  begin
    Result[i] := -1;
    if BaslikVar then
      for j := 0 to High(Onizleme.Baslik) do
        if SameText(Trim(Onizleme.Baslik[j]), Kolonlar[i].Ad) then
        begin
          Result[i] := j;
          Inc(Eslesen);
          Break;
        end;
  end;
  { Baslik yoksa (ya da hic ad eslesmediyse) sirayla. }
  if Eslesen = 0 then
    for i := 0 to Min(High(Kolonlar), SutunSayisi - 1) do
      Result[i] := i;
end;

function IceAktarKomutu(const Tablo: string; const Kolonlar: TArray<TIceKolon>; const Esleme: TArray<Integer>;
  Gercek: Boolean): string;
var
  Adlar, Degerler: string;
  i: Integer;
begin
  Adlar := '';
  Degerler := '';
  for i := 0 to High(Kolonlar) do
    if Esleme[i] >= 0 then
    begin
      if Adlar <> '' then
      begin
        Adlar := Adlar + ', ';
        Degerler := Degerler + ', ';
      end;
      Adlar := Adlar + TirnakliAd(Kolonlar[i].Ad);
      if Gercek then
        Degerler := Degerler + ':P' + IntToStr(i)
      else
        Degerler := Degerler + ':' + Kolonlar[i].Ad;
    end;
  Result := 'INSERT INTO ' + TirnakliAd(Tablo) + ' (' + Adlar + ') VALUES (' + Degerler + ')';
end;

{ ---------- Deger donusturme ---------- }

function TarihCoz(const Metin: string; out Tarih: TDateTime): Boolean;
var
  Parca: TArray<string>;
  G, A, Y: Integer;
begin
  Result := False;
  Parca := Metin.Split(['-', '.', '/']);
  if Length(Parca) <> 3 then
    Exit;
  if Length(Parca[0]) = 4 then
    Result := TryStrToInt(Parca[0], Y) and TryStrToInt(Parca[1], A) and TryStrToInt(Parca[2], G)
  else if Length(Parca[2]) = 4 then
    Result := TryStrToInt(Parca[0], G) and TryStrToInt(Parca[1], A) and TryStrToInt(Parca[2], Y);
  Result := Result and TryEncodeDate(Y, A, G, Tarih);
end;

function SaatCoz(const Metin: string; out Saat: TDateTime): Boolean;
var
  Parca: TArray<string>;
  S, D, Sn, Ms: Integer;
  SaniyeMetni, MsMetni: string;
begin
  Result := False;
  Parca := Metin.Split([':']);
  if not (Length(Parca) in [2, 3]) then
    Exit;
  Ms := 0;
  Sn := 0;
  if Length(Parca) = 3 then
  begin
    SaniyeMetni := Parca[2];
    if Pos('.', SaniyeMetni) > 0 then
    begin
      MsMetni := Copy(SaniyeMetni, Pos('.', SaniyeMetni) + 1, 3);
      SaniyeMetni := Copy(SaniyeMetni, 1, Pos('.', SaniyeMetni) - 1);
      while Length(MsMetni) < 3 do
        MsMetni := MsMetni + '0';
      if not TryStrToInt(MsMetni, Ms) then
        Exit;
    end;
    if not TryStrToInt(SaniyeMetni, Sn) then
      Exit;
  end;
  Result := TryStrToInt(Parca[0], S) and TryStrToInt(Parca[1], D) and TryEncodeTime(S, D, Sn, Ms, Saat);
end;

function ZamanCoz(const Metin: string; out Zaman: TDateTime): Boolean;
var
  Yer: Integer;
  T, S: TDateTime;
begin
  Yer := Pos('T', Metin);
  if Yer = 0 then
    Yer := Pos(' ', Metin);
  if Yer = 0 then
  begin
    { Yalniz tarih verilmis: gece yarisi. }
    Result := TarihCoz(Metin, Zaman);
    Exit;
  end;
  Result := TarihCoz(Trim(Copy(Metin, 1, Yer - 1)), T) and SaatCoz(Trim(Copy(Metin, Yer + 1, MaxInt)), S);
  if Result then
    Zaman := T + S;
end;

function MantikCoz(const Metin: string; out Deger: Boolean): Boolean;
var
  M: string;
begin
  M := LowerCase(Metin);
  Result := True;
  { dogru = do + g(287) + ru; hayir = hay + i(305) + r; yanlis = yanl + i(305) + s(351) }
  if (M = 'true') or (M = '1') or (M = 'evet') or (M = 'yes') or (M = 'e') or (M = 'y') or (M = 'do'#287'ru') or
    (M = 'dogru') then
    Deger := True
  else if (M = 'false') or (M = '0') or (M = 'hay'#305'r') or (M = 'hayir') or (M = 'no') or (M = 'h') or (M = 'n') or
    (M = 'yanl'#305#351) or (M = 'yanlis') then
    Deger := False
  else
    Result := False;
end;

{ Her kolon icin parametre turu HEP ayni kalir (FireDAC, satirlar arasinda tur degisirse sorguyu yeniden hazirlamak ister). }
function ParamTuru(Alan: TFieldType): TFieldType;
begin
  case Alan of
    ftSmallint, ftInteger, ftLargeint, ftWord, ftShortint, ftByte, ftLongWord, ftAutoInc: Result := ftLargeint;
    ftFloat, ftSingle, ftExtended: Result := ftFloat;
    ftCurrency, ftBCD, ftFMTBcd: Result := ftFMTBcd;
    ftMemo, ftWideMemo: Result := ftWideMemo;
    ftDateTime, ftTimeStamp: Result := ftDateTime;
  else
    Result := Alan;
  end;
end;

{ Metni parametreye yazar. Okunamazsa False doner ve TurAnahtari'na "tam sayi / sayi / tarih ..." dil anahtarini koyar. }
function DegerYaz(Param: TFDParam; Alan: TFieldType; const Metin: string; const FS: TFormatSettings;
  out TurAnahtari: string): Boolean;
var
  I64: Int64;
  F: Double;
  Bcd: TBcd;
  Z: TDateTime;
  B: Boolean;
begin
  Result := True;
  TurAnahtari := '';
  Param.DataType := ParamTuru(Alan);
  if Trim(Metin) = '' then
  begin
    Param.Clear;
    Exit;
  end;
  case Alan of
    ftString, ftWideString, ftFixedChar, ftFixedWideChar:
      Param.AsWideString := Metin;
    ftMemo, ftWideMemo:
      Param.AsWideMemo := Metin;
    ftSmallint, ftInteger, ftLargeint, ftWord, ftShortint, ftByte, ftLongWord, ftAutoInc:
      begin
        TurAnahtari := 'ICE_TUR_TAMSAYI';
        Result := TryStrToInt64(Trim(Metin), I64);
        if Result then
          Param.AsLargeInt := I64;
      end;
    ftFloat, ftSingle, ftExtended:
      begin
        TurAnahtari := 'ICE_TUR_SAYI';
        Result := TryStrToFloat(Trim(Metin), F, FS);
        if Result then
          Param.AsFloat := F;
      end;
    ftCurrency, ftBCD, ftFMTBcd:
      begin
        TurAnahtari := 'ICE_TUR_SAYI';
        Result := TryStrToBcd(Trim(Metin), Bcd, FS);
        if Result then
          Param.AsFMTBCD := Bcd;
      end;
    ftDate:
      begin
        TurAnahtari := 'ICE_TUR_TARIH';
        Result := TarihCoz(Trim(Metin), Z);
        if Result then
          Param.AsDate := Z;
      end;
    ftTime:
      begin
        TurAnahtari := 'ICE_TUR_SAAT';
        Result := SaatCoz(Trim(Metin), Z);
        if Result then
          Param.AsTime := Z;
      end;
    ftDateTime, ftTimeStamp:
      begin
        TurAnahtari := 'ICE_TUR_ZAMAN';
        Result := ZamanCoz(Trim(Metin), Z);
        if Result then
          Param.AsDateTime := Z;
      end;
    ftBoolean:
      begin
        TurAnahtari := 'ICE_TUR_MANTIK';
        Result := MantikCoz(Trim(Metin), B);
        if Result then
          Param.AsBoolean := B;
      end;
  else
    Param.Clear;
  end;
end;

function SayiTuruMu(Alan: TFieldType): Boolean;
begin
  Result := Alan in [ftSmallint, ftInteger, ftLargeint, ftWord, ftShortint, ftByte, ftLongWord, ftAutoInc,
    ftFloat, ftSingle, ftExtended, ftCurrency, ftBCD, ftFMTBcd];
end;

function IceAktar(Bag: TAcikBaglanti; const Tablo, Dosya: string; const Sec: TIceSecenek;
  const Kolonlar: TArray<TIceKolon>; const Esleme: TArray<Integer>; Ilerleme: TCsvIlerlemesi): TIceSonuc;
var
  Islem: TFDTransaction;
  Sorgu: TFDQuery;
  Okuyucu: TCsvOkuyucu;
  Alanlar: TArray<string>;
  FS: TFormatSettings;
  Satir: Int64;
  Metin, Tur: string;
  i: Integer;
  Iptal: Boolean;
begin
  Result := Default(TIceSonuc);
  FS := TFormatSettings.Create;
  FS.DecimalSeparator := Sec.Ondalik;
  FS.ThousandSeparator := #0;
  Islem := TFDTransaction.Create(nil);
  Sorgu := TFDQuery.Create(nil);
  Okuyucu := nil;
  Satir := 0;
  try
    try
      Islem.Connection := Bag.Baglanti;
      Islem.Options.AutoCommit := False;
      Sorgu.Connection := Bag.Baglanti;
      Sorgu.Transaction := Islem;
      Sorgu.SQL.Text := IceAktarKomutu(Tablo, Kolonlar, Esleme, True);
      Okuyucu := TCsvOkuyucu.Create(Dosya, Sec);
      Islem.StartTransaction;
      while Okuyucu.Oku(Alanlar) do
      begin
        Inc(Satir);
        if BosSatir(Alanlar) or (Sec.BaslikVar and (Satir = 1)) then
          Continue;
        for i := 0 to High(Kolonlar) do
          if Esleme[i] >= 0 then
          begin
            if Esleme[i] < Length(Alanlar) then
              Metin := Alanlar[Esleme[i]]
            else
              Metin := '';
            if not DegerYaz(Sorgu.ParamByName('P' + IntToStr(i)), Kolonlar[i].Alan, Metin, FS, Tur) then
            begin
              Result.Cumle := TF('ERR_ICE_DEGER', [Satir, Kolonlar[i].Ad, Metin, T(Tur)]);
              if SayiTuruMu(Kolonlar[i].Alan) then
                Result.Cumle := Result.Cumle + ' ' + TF('ERR_ICE_ONDALIK', [Sec.Ondalik]);
              raise EKayitKurali.Create(Result.Cumle);
            end;
          end;
        Sorgu.ExecSQL;
        Inc(Result.Eklenen);
        if Assigned(Ilerleme) and (Result.Eklenen mod ILERLEME_ARALIGI = 0) then
        begin
          Iptal := False;
          Ilerleme(Result.Eklenen, Iptal);
          if Iptal then
          begin
            Islem.Rollback;
            Result.Iptal := True;
            Result.Eklenen := 0;
            Exit;
          end;
        end;
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
        Result.Basarili := False;
        Result.Eklenen := 0;
        if E is EKayitKurali then
          Result.Cumle := E.Message
        else
        begin
          Result.Cumle := TF('ERR_ICE_SATIR', [Satir]) + ' ' + HataMetniniCevir(E);
          Result.Ayrinti := E.Message;
        end;
      end;
    end;
  finally
    Okuyucu.Free;
    Sorgu.Free;
    Islem.Free;
  end;
end;

end.
