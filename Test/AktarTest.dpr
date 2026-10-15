program AktarTest;

{ Asama 3b: uAktar (CSV disa aktarma) testi (komut satiri).

  Gecici bir veritabani acilir (varsayilan: gomulu Firebird). Gercek veriye dokunulmaz; sadece bu testin
  kendi gecici veritabani ve CSV dosyalari kullanilir. Cikti CSV'ler testin KENDI bagimsiz okuyucusuyla
  (CsvOku) geri okunur ve beklenen degerlerle karsilastirilir.

  Ortam degiskenleri: FBTEST_SUNUCU (bos = gomulu), FBTEST_PORT, FBTEST_KLASOR (gecici veritabaninin ve
  CSV'lerin konacagi klasor; sunucu verilirse SUNUCUDAKI klasor olmali, CSV'ler ise yine %TEMP%\aktartest'e
  yazilir), FBTEST_KULLANICI, FBTEST_SIFRE, FBTEST_CIKTI (sonuc dosyasi),
  AKTAR_SATIR (buyuk tablonun satir sayisi, varsayilan 100000),
  AKTAR_MILYON (verilirse bu kadar satirlik ikinci bir buyuk tablo da denenir; 1100000 Excel uyarisini da dener).
  Gomulu kipte biten veritabani ve CSV'ler klasorun _arsiv alt klasorune tasinir (silinmez).
  Cikis kodu: hata sayisi (0 = hepsi gecti). }

{$APPTYPE CONSOLE}

uses
  Winapi.Windows, Winapi.PsAPI,
  System.SysUtils, System.Classes, System.StrUtils, System.Math, System.Generics.Collections, System.IOUtils,
  System.Diagnostics, Data.DB,
  FireDAC.Stan.Error, FireDAC.Comp.Client, FireDAC.Phys.FB,
  uDil, uBaglanti, uSorgu, uAktar;

const
  { c g i(noktasiz) o s u I(noktali) }
  TURKCE = #$00E7#$011F#$0131#$00F6#$015F#$00FC#$0130;

var
  Cikti: TStringList;
  Hatalar, KontrolSayisi: Integer;
  Bag: TAcikBaglanti;
  SurumNo: Integer;
  Klasor: string;
  CsvKlasoru: string;
  Damga: string;
  Uretilen: TStringList;

function Ortam(const Ad, Varsayilan: string): string;
begin
  Result := GetEnvironmentVariable(Ad);
  if Result = '' then
    Result := Varsayilan;
end;

procedure Kontrol(const Ad: string; Sonuc: Boolean);
begin
  Inc(KontrolSayisi);
  if Sonuc then
    Cikti.Add('OK    ' + Ad)
  else
  begin
    Cikti.Add('HATA  ' + Ad);
    Inc(Hatalar);
  end;
end;

procedure GeciciVeritabaniOlustur(const Tanim: TBaglantiTanimi);
var
  Surucu: TFDPhysFBDriverLink;
  Baglanti: TFDConnection;
begin
  Surucu := TFDPhysFBDriverLink.Create(nil);
  Baglanti := TFDConnection.Create(nil);
  try
    Surucu.VendorLib := ExtractFilePath(ParamStr(0)) + 'istemci\fbclient.dll';
    Baglanti.DriverName := 'FB';
    Baglanti.LoginPrompt := False;
    Baglanti.Params.Values['Database'] := Tanim.VeritabaniYolu;
    Baglanti.Params.Values['User_Name'] := Tanim.Kullanici;
    Baglanti.Params.Values['Password'] := Tanim.Sifre;
    Baglanti.Params.Values['OpenMode'] := 'Create';
    Baglanti.Params.Values['CharacterSet'] := Tanim.KarakterSeti;
    Baglanti.Open;
    Baglanti.Close;
  finally
    Baglanti.Free;
    Surucu.Free;
  end;
end;

{ Tek komutu uygulamanin kendi calistiricisiyle (SorguCalistir) calistirir; hata olursa istisna firlar. }
procedure Komut(const Sql: string);
begin
  SorguCalistir(Bag, Sql).Free;
end;

function CalismaKumesi: Int64;
var
  Sayac: TProcessMemoryCounters;
begin
  Sayac.cb := SizeOf(Sayac);
  if GetProcessMemoryInfo(GetCurrentProcess, @Sayac, SizeOf(Sayac)) then
    Result := Sayac.WorkingSetSize
  else
    Result := 0;
end;

function MB(Bayt: Int64): string;
begin
  Result := Format('%.1f MB', [Bayt / (1024 * 1024)]);
end;

{ ---------- Bagimsiz CSV okuyucu: uAktar'in kodunu kullanmaz ---------- }

type
  TSatirOlayi = reference to procedure(const Alanlar: TArray<string>);

{ Dosyayi UTF-8 (BOM'u atlayarak) akis olarak okur. Alanlar "..." icinde olabilir, "" bir tirnak demektir. }
procedure CsvOku(const Dosya: string; Ayrac: Char; Olay: TSatirOlayi);
var
  Okuyucu: TStreamReader;
  Alan: TStringBuilder;
  Satir: TList<string>;
  Tirnakta, AlanVar: Boolean;
  C: Char;

  procedure AlaniBitir;
  begin
    Satir.Add(Alan.ToString);
    Alan.Clear;
    AlanVar := False;
  end;

  procedure SatiriBitir;
  begin
    AlaniBitir;
    Olay(Satir.ToArray);
    Satir.Clear;
  end;

begin
  Okuyucu := TStreamReader.Create(Dosya, TEncoding.UTF8, True);
  Alan := TStringBuilder.Create;
  Satir := TList<string>.Create;
  try
    Tirnakta := False;
    AlanVar := False;
    while not Okuyucu.EndOfStream do
    begin
      C := Char(Okuyucu.Read);
      if Tirnakta then
      begin
        if C = '"' then
        begin
          if Okuyucu.Peek = Ord('"') then
          begin
            Okuyucu.Read;
            Alan.Append('"');
          end
          else
            Tirnakta := False;
        end
        else
          Alan.Append(C);
      end
      else if C = '"' then
      begin
        Tirnakta := True;
        AlanVar := True;
      end
      else if C = Ayrac then
      begin
        AlaniBitir;
        AlanVar := True;
      end
      else if C = #13 then
      begin
        if Okuyucu.Peek = 10 then
          Okuyucu.Read;
        SatiriBitir;
      end
      else if C = #10 then
        SatiriBitir
      else
      begin
        Alan.Append(C);
        AlanVar := True;
      end;
    end;
    if AlanVar or (Alan.Length > 0) or (Satir.Count > 0) then
      SatiriBitir;
  finally
    Satir.Free;
    Alan.Free;
    Okuyucu.Free;
  end;
end;

{ Kucuk dosyayi tamamen okur. }
function CsvSatirlari(const Dosya: string; Ayrac: Char): TList<TArray<string>>;
var
  Liste: TList<TArray<string>>;
begin
  Liste := TList<TArray<string>>.Create;
  CsvOku(Dosya, Ayrac,
    procedure(const Alanlar: TArray<string>)
    begin
      Liste.Add(Alanlar);
    end);
  Result := Liste;
end;

{ Dosyanin ham baytlari: ilk uc bayt EF BB BF mi, her LF'den once CR var mi? }
function BomVarMi(const Dosya: string): Boolean;
var
  Bayt: TBytes;
begin
  Bayt := TFile.ReadAllBytes(Dosya);
  Result := (Length(Bayt) >= 3) and (Bayt[0] = $EF) and (Bayt[1] = $BB) and (Bayt[2] = $BF);
end;

function TumLFlerCRliMi(const Dosya: string): Boolean;
var
  Bayt: TBytes;
  i: Integer;
begin
  Result := True;
  Bayt := TFile.ReadAllBytes(Dosya);
  for i := 0 to High(Bayt) do
    if (Bayt[i] = 10) and ((i = 0) or (Bayt[i - 1] <> 13)) then
      Exit(False);
end;

function SonBaytlarCRLFMi(const Dosya: string): Boolean;
var
  Bayt: TBytes;
begin
  Bayt := TFile.ReadAllBytes(Dosya);
  Result := (Length(Bayt) >= 2) and (Bayt[High(Bayt) - 1] = 13) and (Bayt[High(Bayt)] = 10);
end;

function DosyaMetni(const Dosya: string): string;
begin
  Result := TFile.ReadAllText(Dosya, TEncoding.UTF8);
end;

{ ---------- Yardimcilar ---------- }

function AktarDosyaYolu(const Ad: string): string;
begin
  Result := TPath.Combine(CsvKlasoru, Ad + '_' + Damga + '.csv');
  Uretilen.Add(Result);
end;

{ Dosyaya yazar ve sonucu verir. Hata istisna olarak firlar (hata testleri yakalar). }
function Aktar(const Sql, Dosya: string; const Sec: TCsvSecenekleri; Uyarilar: TStrings;
  Ilerleme: TCsvIlerlemesi; out Satir: Int64): Boolean;
var
  Yazici: TStreamWriter;
  Kodlama: TEncoding;
begin
  Kodlama := TUTF8Encoding.Create(True);
  try
    Yazici := TStreamWriter.Create(Dosya, False, Kodlama);
    try
      Result := CsvAktar(Bag, Sql, Yazici, Sec, Uyarilar, Ilerleme, Satir);
    finally
      Yazici.Free;
    end;
  finally
    Kodlama.Free;
  end;
end;

function Secenek(Ayrac, Ondalik: Char): TCsvSecenekleri;
begin
  Result.Ayrac := Ayrac;
  Result.Ondalik := Ondalik;
end;

{ Sayi alanlarindaki '.' i ondalik ayracina cevirir (beklenen degerler '.' ile yazildi). }
function Num(const Deger: string; Ondalik: Char): string;
begin
  Result := StringReplace(Deger, '.', Ondalik, [rfReplaceAll]);
end;

function Birlestir(const Alanlar: TArray<string>): string;
var
  A: string;
begin
  Result := '';
  for A in Alanlar do
    Result := Result + '[' + A + ']';
end;

{ ---------- 1. Alan kurallari ---------- }

procedure AlanTablosunuKur;
var
  Mantik: string;
begin
  Mantik := '';
  if SurumNo >= 3 then
    Mantik := 'MANTIK BOOLEAN, ';
  Komut('CREATE TABLE T_ALAN (ID INTEGER NOT NULL PRIMARY KEY, AD VARCHAR(100), SABIT CHAR(6), SM SMALLINT, ' +
    'TAM INTEGER, BIG BIGINT, NUM NUMERIC(18,2), DES DECIMAL(9,3), KUCUK NUMERIC(4,1), TEK FLOAT, ' +
    'CIFT DOUBLE PRECISION, TAR DATE, SAAT TIME, ZAMAN TIMESTAMP, ' + Mantik +
    'NOTM BLOB SUB_TYPE TEXT, IKILI BLOB SUB_TYPE BINARY)');
  { 1: tipik; ayrac, tirnak ve satir sonu iceren degerler }
  if SurumNo >= 3 then
    Mantik := 'TRUE, '
  else
    Mantik := '';
  Komut('INSERT INTO T_ALAN VALUES (1, ''Ali;Veli'', ''AB'', 32767, 2147483647, 9223372036854775807, ' +
    '1234567890123456.78, -12345.678, 0.5, 0.000123, 123456789.123456, ''2026-03-09'', ''07:05:09'', ' +
    '''2026-03-09 17:45:30'', ' + Mantik + '''satir1'#13#10'satir2;"x"'', ''xyz'')');
  { 2: tirnak, uc degerler, negatifler }
  if SurumNo >= 3 then
    Mantik := 'FALSE, '
  else
    Mantik := '';
  Komut('INSERT INTO T_ALAN VALUES (2, ''Dedi ki "merhaba"'', ''CD'', -32768, -2147483648, ' +
    '-9223372036854775807 - 1, -0.01, 0.001, -99.9, 1.5E20, 1.0E-10, ''1900-01-01'', ''23:59:59'', ' +
    '''2026-12-31 23:59:59.5000'', ' + Mantik + 'NULL, NULL)');
  { 3: bos metin ve NULL'lar }
  if SurumNo >= 3 then
    Mantik := 'NULL, '
  else
    Mantik := '';
  Komut('INSERT INTO T_ALAN VALUES (3, '''', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, ' +
    'NULL, ' + Mantik + 'NULL, NULL)');
  { 4: Turkce karakterler }
  Komut('INSERT INTO T_ALAN (ID, AD, SABIT, NOTM) VALUES (4, ''' + TURKCE + ''', ''' + #$015E + ''', ''' +
    TURKCE + ' ' + TURKCE + ''')');
  { 5: uzun metin }
  Komut('INSERT INTO T_ALAN (ID, NOTM) VALUES (5, ''' + StringOfChar('x', 5000) + ';y'')');
  { 6: kucuk kesirler ve sifirlar }
  Komut('INSERT INTO T_ALAN (ID, SM, TAM, BIG, NUM, DES, KUCUK, TEK, CIFT) VALUES (6, 0, 0, 0, 0, 0, 0, 100, 0.1)');
  { 7: sondaki sifirlar (5.10, 12.500) }
  Komut('INSERT INTO T_ALAN (ID, NUM, DES) VALUES (7, 5.10, 12.500)');
end;

{ Beklenen satirlar. Ondalik ayraci: sayi alanlarinda kullanilir. SurumNo<3'te MANTIK kolonu yok. }
function BeklenenSatir(No: Integer; Ondalik: Char): TArray<string>;
var
  L: TList<string>;
  Uzun: string;

  procedure Ekle(const D: string);
  begin
    L.Add(D);
  end;

  procedure MantikEkle(const D: string);
  begin
    if SurumNo >= 3 then
      L.Add(D);
  end;

begin
  L := TList<string>.Create;
  try
    case No of
      1:
        begin
          Ekle('1'); Ekle('Ali;Veli'); Ekle('AB'); Ekle('32767'); Ekle('2147483647');
          Ekle('9223372036854775807'); Ekle(Num('1234567890123456.78', Ondalik)); Ekle(Num('-12345.678', Ondalik));
          Ekle(Num('0.5', Ondalik)); Ekle(Num('0.000123', Ondalik)); Ekle(Num('123456789.123456', Ondalik));
          Ekle('2026-03-09'); Ekle('07:05:09'); Ekle('2026-03-09 17:45:30'); MantikEkle('TRUE');
          Ekle('satir1'#13#10'satir2;"x"'); Ekle('');
        end;
      2:
        begin
          Ekle('2'); Ekle('Dedi ki "merhaba"'); Ekle('CD'); Ekle('-32768'); Ekle('-2147483648');
          Ekle('-9223372036854775808'); Ekle(Num('-0.01', Ondalik)); Ekle(Num('0.001', Ondalik));
          Ekle(Num('-99.9', Ondalik)); Ekle('150000000000000000000'); Ekle(Num('0.0000000001', Ondalik));
          Ekle('1900-01-01'); Ekle('23:59:59'); Ekle('2026-12-31 23:59:59'); MantikEkle('FALSE');
          Ekle(''); Ekle('');
        end;
      3:
        begin
          Ekle('3'); Ekle('');
          Ekle(''); Ekle(''); Ekle(''); Ekle(''); Ekle(''); Ekle(''); Ekle(''); Ekle(''); Ekle(''); Ekle('');
          Ekle(''); Ekle(''); MantikEkle(''); Ekle(''); Ekle('');
        end;
      4:
        begin
          Ekle('4'); Ekle(TURKCE); Ekle(#$015E);
          Ekle(''); Ekle(''); Ekle(''); Ekle(''); Ekle(''); Ekle(''); Ekle(''); Ekle(''); Ekle('');
          Ekle(''); Ekle(''); MantikEkle(''); Ekle(TURKCE + ' ' + TURKCE); Ekle('');
        end;
      5:
        begin
          Uzun := StringOfChar('x', 5000) + ';y';
          Ekle('5'); Ekle(''); Ekle('');
          Ekle(''); Ekle(''); Ekle(''); Ekle(''); Ekle(''); Ekle(''); Ekle(''); Ekle(''); Ekle('');
          Ekle(''); Ekle(''); MantikEkle(''); Ekle(Uzun); Ekle('');
        end;
      6:
        begin
          Ekle('6'); Ekle(''); Ekle(''); Ekle('0'); Ekle('0'); Ekle('0'); Ekle(Num('0', Ondalik));
          Ekle(Num('0', Ondalik)); Ekle(Num('0', Ondalik)); Ekle('100'); Ekle(Num('0.1', Ondalik));
          Ekle(''); Ekle(''); Ekle(''); MantikEkle(''); Ekle(''); Ekle('');
        end;
      7:
        begin
          Ekle('7'); Ekle(''); Ekle(''); Ekle(''); Ekle(''); Ekle(''); Ekle(Num('5.1', Ondalik));
          Ekle(Num('12.5', Ondalik)); Ekle(''); Ekle(''); Ekle(''); Ekle(''); Ekle(''); Ekle('');
          MantikEkle(''); Ekle(''); Ekle('');
        end;
    end;
    Result := L.ToArray;
  finally
    L.Free;
  end;
end;

function BaslikSatiri: TArray<string>;
var
  L: TList<string>;
  A: string;
begin
  L := TList<string>.Create;
  try
    for A in ['ID', 'AD', 'SABIT', 'SM', 'TAM', 'BIG', 'NUM', 'DES', 'KUCUK', 'TEK', 'CIFT', 'TAR', 'SAAT', 'ZAMAN'] do
      L.Add(A);
    if SurumNo >= 3 then
      L.Add('MANTIK');
    L.Add('NOTM');
    L.Add('IKILI');
    Result := L.ToArray;
  finally
    L.Free;
  end;
end;

procedure AlanKurallariTesti(const Ad: string; const Sec: TCsvSecenekleri);
var
  Dosya: string;
  Uyarilar: TStringList;
  Satirlar: TList<TArray<string>>;
  Satir: Int64;
  i: Integer;
  Tamam: Boolean;
  Metin: string;
begin
  Dosya := AktarDosyaYolu(Ad);
  Uyarilar := TStringList.Create;
  try
    Tamam := Aktar('SELECT * FROM T_ALAN ORDER BY ID', Dosya, Sec, Uyarilar, nil, Satir);
    Kontrol(Ad + ': tamamlandi (True)', Tamam);
    Kontrol(Ad + ': satir sayisi 7', Satir = 7);
    Kontrol(Ad + ': ilk uc bayt EF BB BF (UTF-8 BOM)', BomVarMi(Dosya));
    Kontrol(Ad + ': her LF'#39'den once CR var (CRLF)', TumLFlerCRliMi(Dosya));
    Kontrol(Ad + ': dosya CRLF ile bitiyor', SonBaytlarCRLFMi(Dosya));
    Kontrol(Ad + ': uyari tam bir tane ve IKILI kolonunu adlandiriyor',
      (Uyarilar.Count = 1) and (Pos('IKILI', Uyarilar[0]) > 0));
    Satirlar := CsvSatirlari(Dosya, Sec.Ayrac);
    try
      Kontrol(Ad + ': geri okunan satir sayisi 8 (baslik + 7)', Satirlar.Count = 8);
      if Satirlar.Count = 8 then
      begin
        Kontrol(Ad + ': baslik satiri', Birlestir(Satirlar[0]) = Birlestir(BaslikSatiri));
        for i := 1 to 7 do
        begin
          Kontrol(Ad + ': satir ' + IntToStr(i) + ' alan sayisi ve degerleri',
            Birlestir(Satirlar[i]) = Birlestir(BeklenenSatir(i, Sec.Ondalik)));
          if Birlestir(Satirlar[i]) <> Birlestir(BeklenenSatir(i, Sec.Ondalik)) then
          begin
            Cikti.Add('      gelen:    ' + Copy(Birlestir(Satirlar[i]), 1, 400));
            Cikti.Add('      beklenen: ' + Copy(Birlestir(BeklenenSatir(i, Sec.Ondalik)), 1, 400));
          end;
        end;
      end;
    finally
      Satirlar.Free;
    end;
    Metin := DosyaMetni(Dosya);
    if Sec.Ayrac = ';' then
      Kontrol(Ad + ': ayrac iceren deger tirnakli ("Ali;Veli")', Pos('"Ali;Veli"', Metin) > 0)
    else
      Kontrol(Ad + ': ayrac olmayan karakter ('';'') tirnaklanmadi (Ali;Veli)', (Pos(',Ali;Veli,', Metin) > 0));
    Kontrol(Ad + ': tirnak ikiye katlandi ("Dedi ki ""merhaba""")', Pos('"Dedi ki ""merhaba"""', Metin) > 0);
    Kontrol(Ad + ': Turkce karakterler dosyada bozulmadan duruyor', Pos(TURKCE, Metin) > 0);
  finally
    Uyarilar.Free;
  end;
end;

procedure TakmaAdTesti;
var
  Dosya: string;
  Uyarilar: TStringList;
  Satirlar: TList<TArray<string>>;
  Satir: Int64;
begin
  Dosya := AktarDosyaYolu('takmaad');
  Uyarilar := TStringList.Create;
  try
    Aktar('SELECT ID AS "Kimlik No", AD AS ADI, ''sabit'' AS "A;B" FROM T_ALAN WHERE ID <= 2 ORDER BY ID', Dosya,
      Secenek(';', ','), Uyarilar, nil, Satir);
    Satirlar := CsvSatirlari(Dosya, ';');
    try
      Kontrol('takma ad: baslikta sorgudaki takma adlar (ayrac iceren tirnakli)',
        (Satirlar.Count = 3) and (Birlestir(Satirlar[0]) = '[Kimlik No][ADI][A;B]'));
      Kontrol('takma ad: ikili kolon yok, uyari yok', Uyarilar.Count = 0);
    finally
      Satirlar.Free;
    end;
  finally
    Uyarilar.Free;
  end;
end;

{ ---------- 3. Buyuk tablo ---------- }

type
  TOlcum = class
    Baslangic: Int64;
    Tepe: Int64;
    IptalSatiri: Int64;
    { > 0 ise 2000. satirda bu numarali baglanti baska bir baglantidan koparilir (baglanti kopmasi benzetimi). }
    KoparilacakNo: Integer;
    AnaBag: TAcikBaglanti;
    Cagri: Integer;
    procedure Ilerle(SatirSayisi: Int64; var Iptal: Boolean);
  end;

procedure TOlcum.Ilerle(SatirSayisi: Int64; var Iptal: Boolean);
var
  Simdi: Int64;
  Koparan: TSorguSonucu;
begin
  Inc(Cagri);
  { Her 10 bin satirda bir calisma kumesini ornekler. }
  if SatirSayisi mod 10000 = 0 then
  begin
    Simdi := CalismaKumesi;
    if Simdi > Tepe then
      Tepe := Simdi;
  end;
  if (IptalSatiri > 0) and (SatirSayisi >= IptalSatiri) then
    Iptal := True;
  if (KoparilacakNo > 0) and (SatirSayisi >= 2000) then
  begin
    Koparan := SorguCalistir(AnaBag, 'DELETE FROM MON$ATTACHMENTS WHERE MON$ATTACHMENT_ID = ' + IntToStr(KoparilacakNo));
    Cikti.Add('      MON$ATTACHMENTS silme: etkilenen satir ' + IntToStr(Koparan.Etkilenen) + ', baglanti no ' + IntToStr(KoparilacakNo));
    Koparan.Free;
    KoparilacakNo := 0;
  end;
end;

procedure BuyukTabloKur(const Tablo: string; N: Integer);
var
  Saat: TStopwatch;
begin
  Saat := TStopwatch.StartNew;
  Komut('CREATE TABLE ' + Tablo + ' (ID INTEGER NOT NULL PRIMARY KEY, AD VARCHAR(50), KOD CHAR(8), ' +
    'TUTAR NUMERIC(15,2), ORAN DOUBLE PRECISION, TARIH DATE, ZAMAN TIMESTAMP, ACIKLAMA VARCHAR(200), ' +
    'DURUM SMALLINT, NOTU BLOB SUB_TYPE TEXT)');
  Komut('EXECUTE BLOCK AS DECLARE VARIABLE I INTEGER; BEGIN I = 1; WHILE (I <= ' + IntToStr(N) + ') DO BEGIN ' +
    'INSERT INTO ' + Tablo + ' VALUES (:I, ''Kayit '' || :I, LPAD(:I, 8, ''0''), :I * 1.25, :I * 1.0e0 / 7, ' +
    'DATEADD(MOD(:I, 3000) DAY TO DATE ''2000-01-01''), DATEADD(:I SECOND TO TIMESTAMP ''2000-01-01 00:00:00''), ' +
    '''Aciklama; satir "'' || :I || ''"'', MOD(:I, 3), ''not '' || :I); I = I + 1; END END');
  Cikti.Add('      ' + Tablo + ' ' + IntToStr(N) + ' satir olusturuldu: ' + IntToStr(Saat.ElapsedMilliseconds) + ' ms');
end;

{ Buyuk tabloyu dosyaya aktarir, SATIR SATIR kontrol eder, sure ve bellegi yazar. }
procedure BuyukTabloTesti(const Tablo: string; N: Integer; ExcelUyarisiBeklenir: Boolean);
var
  Dosya: string;
  Uyarilar: TStringList;
  Olcum: TOlcum;
  Satir, Okunan: Int64;
  Saat: TStopwatch;
  Sure: Int64;
  Basta, Sonda: Int64;
  Boyut: Int64;
  Bozuk: Int64;
  IlkBozuk: string;
  Ayrac: Char;
  Tamam: Boolean;
begin
  Ayrac := ';';
  Dosya := AktarDosyaYolu(Tablo);
  Uyarilar := TStringList.Create;
  Olcum := TOlcum.Create;
  try
    Basta := CalismaKumesi;
    Olcum.Tepe := Basta;
    Saat := TStopwatch.StartNew;
    Tamam := Aktar('SELECT * FROM ' + Tablo + ' ORDER BY ID', Dosya, Secenek(Ayrac, ','), Uyarilar, Olcum.Ilerle,
      Satir);
    Sure := Saat.ElapsedMilliseconds;
    Sonda := CalismaKumesi;
    if Sonda > Olcum.Tepe then
      Olcum.Tepe := Sonda;
    Boyut := TFile.GetSize(Dosya);
    Kontrol(Tablo + ': tamamlandi', Tamam);
    Kontrol(Tablo + ': yazilan satir sayisi tam ' + IntToStr(N), Satir = N);
    Cikti.Add('      sure: ' + IntToStr(Sure) + ' ms (' + IntToStr(Round(Satir / Max(Sure, 1) * 1000)) +
      ' satir/sn), dosya: ' + MB(Boyut));
    Cikti.Add('      bellek (calisma kumesi): basta ' + MB(Basta) + ', bitisten sonra ' + MB(Sonda) + ', tepe ' +
      MB(Olcum.Tepe) + ' (artis ' + MB(Olcum.Tepe - Basta) + '); ilerleme cagrisi ' + IntToStr(Olcum.Cagri));
    { Dosyayi bagimsiz okuyucuyla satir satir denetle: sayi ve her satirin degerleri. }
    Okunan := 0;
    Bozuk := 0;
    IlkBozuk := '';
    CsvOku(Dosya, Ayrac,
      procedure(const A: TArray<string>)
      var
        K: Integer;
        Gecerli: Boolean;
        Tutar, Oran: Double;
      begin
        Inc(Okunan);
        if Okunan = 1 then
        begin
          if Birlestir(A) <> '[ID][AD][KOD][TUTAR][ORAN][TARIH][ZAMAN][ACIKLAMA][DURUM][NOTU]' then
            Inc(Bozuk);
          Exit;
        end;
        K := Okunan - 1;
        Gecerli := Length(A) = 10;
        if Gecerli then
        begin
          Tutar := StrToFloatDef(StringReplace(A[3], ',', '.', []), -1, TFormatSettings.Invariant);
          Oran := StrToFloatDef(StringReplace(A[4], ',', '.', []), -1, TFormatSettings.Invariant);
          Gecerli := (A[0] = IntToStr(K)) and (A[1] = 'Kayit ' + IntToStr(K)) and
            (A[2] = RightStr('00000000' + IntToStr(K), 8)) and (Abs(Tutar - K * 1.25) < 0.0001) and
            (Abs(Oran - K / 7) < 1E-9 * K + 1E-12) and
            (A[7] = 'Aciklama; satir "' + IntToStr(K) + '"') and (A[8] = IntToStr(K mod 3)) and
            (A[9] = 'not ' + IntToStr(K)) and (Length(A[5]) = 10) and (Length(A[6]) = 19);
        end;
        if not Gecerli then
        begin
          Inc(Bozuk);
          if IlkBozuk = '' then
            IlkBozuk := 'satir ' + IntToStr(K) + ': ' + Copy(Birlestir(A), 1, 300);
        end;
      end);
    Kontrol(Tablo + ': dosyadan geri okunan satir sayisi = N + 1 (baslik)', Okunan = N + 1);
    Kontrol(Tablo + ': tum satirlarin degerleri (ID, ad, kod, tutar, oran, aciklama, durum, not) dogru',
      Bozuk = 0);
    if Bozuk > 0 then
      Cikti.Add('      ilk bozuk: ' + IlkBozuk);
    if ExcelUyarisiBeklenir then
      Kontrol(Tablo + ': Excel satir siniri uyarisi var',
        (Uyarilar.Count = 1) and (Pos(IntToStr(EXCEL_SATIR_SINIRI), Uyarilar[0]) > 0))
    else
      Kontrol(Tablo + ': Excel uyarisi yok', Uyarilar.Count = 0);
    if Uyarilar.Count > 0 then
      Cikti.Add('      uyari: ' + Uyarilar[0]);
  finally
    Olcum.Free;
    Uyarilar.Free;
  end;
end;

{ ---------- 4. Ekran siniri ---------- }

procedure EkranSiniriTesti(N: Integer);
var
  Dosya, Sql: string;
  Sonuc: TSorguSonucu;
  Uyarilar: TStringList;
  Satir, Okunan: Int64;
  Ilk, Son: string;
  EkranSatiri: Integer;
begin
  Sql := 'SELECT B.ID, A.AD FROM T_BUYUK B JOIN T_ALAN A ON A.ID = MOD(B.ID, 5) + 1 ORDER BY B.ID DESC';
  Sonuc := SorguCalistir(Bag, Sql);
  Uyarilar := TStringList.Create;
  try
    EkranSatiri := Sonuc.Sorgu.RecordCount;
    Cikti.Add('      ekranda yuklu satir: ' + IntToStr(EkranSatiri));
    Kontrol('ekran siniri: ekranda en fazla 500 satir yuklu', (EkranSatiri > 0) and (EkranSatiri <= SATIR_PARCASI));
    Dosya := AktarDosyaYolu('ekran_siniri');
    { Sorgu sekmesi gibi: ekrandaki sonucu ureten SQL, SORGU NESNESINDEN alinir. }
    Aktar(Sonuc.Sorgu.SQL.Text, Dosya, Secenek(';', ','), Uyarilar, nil, Satir);
    Kontrol('ekran siniri: dosyada ' + IntToStr(N) + ' satir (JOIN + ORDER BY sonucu)', Satir = N);
    Okunan := 0;
    Ilk := '';
    Son := '';
    CsvOku(Dosya, ';',
      procedure(const A: TArray<string>)
      begin
        Inc(Okunan);
        if Okunan = 2 then
          Ilk := Birlestir(A);
        Son := Birlestir(A);
      end);
    Kontrol('ekran siniri: geri okunan satir sayisi ' + IntToStr(N + 1), Okunan = N + 1);
    Kontrol('ekran siniri: ilk veri satiri ORDER BY DESC siralamasinda (' + IntToStr(N) + ')',
      Ilk = '[' + IntToStr(N) + '][' + IfThen(N mod 5 = 0, 'Ali;Veli', '') + ']');
    Kontrol('ekran siniri: son satir ID=1', LeftStr(Son, 3) = '[1]');
    Kontrol('ekran siniri: ekrandaki sonuc aktarmadan etkilenmedi (hala en fazla 500 satir yuklu)',
      (Sonuc.Sorgu.RecordCount <= SATIR_PARCASI) and Sonuc.Sorgu.Active);
  finally
    Uyarilar.Free;
    Sonuc.Free;
  end;
end;

{ ---------- 5. Iptal ---------- }

procedure IptalTesti;
var
  Dosya: string;
  Olcum: TOlcum;
  Uyarilar: TStringList;
  Satir, Okunan: Int64;
  Tamam, HepsiTam: Boolean;
  SonSatir: string;
begin
  Dosya := AktarDosyaYolu('iptal');
  Olcum := TOlcum.Create;
  Uyarilar := TStringList.Create;
  try
    Olcum.IptalSatiri := 5000;
    Tamam := Aktar('SELECT * FROM T_BUYUK ORDER BY ID', Dosya, Secenek(';', ','), Uyarilar, Olcum.Ilerle, Satir);
    Kontrol('iptal: False doner', not Tamam);
    Kontrol('iptal: 5000 satirda durdu', Satir = 5000);
    Kontrol('iptal: dosya silinmedi', FileExists(Dosya));
    Okunan := 0;
    HepsiTam := True;
    SonSatir := '';
    CsvOku(Dosya, ';',
      procedure(const A: TArray<string>)
      begin
        Inc(Okunan);
        if Length(A) <> 10 then
          HepsiTam := False;
        SonSatir := A[0];
      end);
    Kontrol('iptal: dosyada baslik + 5000 satir', Okunan = 5001);
    Kontrol('iptal: her satir tam 10 alanli (son satir yarim degil)', HepsiTam);
    Kontrol('iptal: son satirin ID''si 5000', SonSatir = '5000');
    Kontrol('iptal: dosya CRLF ile bitiyor', SonBaytlarCRLFMi(Dosya));
  finally
    Uyarilar.Free;
    Olcum.Free;
  end;
end;

{ ---------- 6. Salt okunur ---------- }

function TabloSatirSayisi(const Tablo: string): Integer;
var
  S: TSorguSonucu;
begin
  S := SorguCalistir(Bag, 'SELECT COUNT(*) FROM ' + Tablo);
  try
    Result := S.Sorgu.Fields[0].AsInteger;
  finally
    S.Free;
  end;
end;

procedure SaltOkunurTesti;
var
  Dosya, Mesaj: string;
  Uyarilar: TStringList;
  Satir: Int64;
  Hata: Boolean;
begin
  Komut('CREATE TABLE T_LOG (X INTEGER)');
  Komut('CREATE PROCEDURE P_YAZ RETURNS (S INTEGER) AS BEGIN INSERT INTO T_LOG VALUES (1); S = 1; SUSPEND; END');
  { Kontrol: ayni komut normal (yazilabilir) islemde veri yazar; yani engel gercekten salt okunur islemdendir. }
  Komut('SELECT * FROM P_YAZ');
  Kontrol('salt okunur: kontrol - normal islemde prosedur 1 satir yazdi', TabloSatirSayisi('T_LOG') = 1);
  Komut('DELETE FROM T_LOG');
  Dosya := AktarDosyaYolu('saltokunur');
  Uyarilar := TStringList.Create;
  try
    Hata := False;
    Mesaj := '';
    try
      Aktar('SELECT * FROM P_YAZ', Dosya, Secenek(';', ','), Uyarilar, nil, Satir);
    except
      on E: Exception do
      begin
        Hata := True;
        Mesaj := AktarmaHatasiniCevir(E);
        Cikti.Add('      hata cumlesi: ' + Mesaj);
        Cikti.Add('      ham mesaj: ' + Copy(StringReplace(E.Message, #13#10, ' ', [rfReplaceAll]), 1, 200));
      end;
    end;
    Kontrol('salt okunur: SELECT * FROM P_YAZ aktarimi hata verdi', Hata);
    Kontrol('salt okunur: hata cumlesi anlasilir (ERR_SALT_OKUNUR)', Mesaj = T('ERR_SALT_OKUNUR'));
    Kontrol('salt okunur: T_LOG bos kaldi, hicbir veri yazilmadi', TabloSatirSayisi('T_LOG') = 0);
  finally
    Uyarilar.Free;
  end;
end;

{ ---------- 7. Hatalar ---------- }

function HataMesaji(const Sql, Dosya: string; K: TAcikBaglanti; Ilerleme: TCsvIlerlemesi = nil): string;
var
  Uyarilar: TStringList;
  Satir: Int64;
  Eski: TAcikBaglanti;
begin
  Result := '';
  Uyarilar := TStringList.Create;
  Eski := Bag;
  try
    Bag := K;
    try
      Aktar(Sql, Dosya, Secenek(';', ','), Uyarilar, Ilerleme, Satir);
      Cikti.Add('      aktarma hatasiz bitti, satir: ' + IntToStr(Satir));
    except
      on E: Exception do
      begin
        Result := AktarmaHatasiniCevir(E);
        Cikti.Add('      [' + E.ClassName + '] ham: ' + Copy(StringReplace(E.Message, #13#10, ' ', [rfReplaceAll]), 1, 160));
        Cikti.Add('      cumle: ' + Result);
      end;
    end;
  finally
    Bag := Eski;
    Uyarilar.Free;
  end;
end;

procedure HataTestleri(const Tanim: TBaglantiTanimi);
var
  Mesaj, Yol: string;
  Kilit: TFileStream;
  Kapali: TAcikBaglanti;
  Olcum: TOlcum;
  Say: TSorguSonucu;
  Ikinci: TBaglantiTanimi;
begin
  { SQL hatalari }
  Mesaj := HataMesaji('SELECT * FROM YOK_BOYLE_TABLO', AktarDosyaYolu('hata_sql'), Bag);
  Kontrol('hata: olmayan tablo -> anlasilir cumle', Mesaj = T('ERR_SQL_NESNE_YOK'));
  Mesaj := HataMesaji('SELEC 1 FROM RDB$DATABASE', AktarDosyaYolu('hata_sozdizimi'), Bag);
  Kontrol('hata: sozdizimi hatasi -> anlasilir cumle', Mesaj = T('ERR_SQL_SOZDIZIMI'));
  { Yazilamayan yol }
  Yol := TPath.Combine(TPath.Combine(CsvKlasoru, 'olmayan_klasor_xyz'), 'a.csv');
  Mesaj := HataMesaji('SELECT * FROM T_ALAN', Yol, Bag);
  Kontrol('hata: olmayan klasor -> anlasilir cumle', Mesaj = T('ERR_AKTAR_DOSYA'));
  { Baska programda acik dosya }
  Yol := AktarDosyaYolu('kilitli');
  Kilit := TFileStream.Create(Yol, fmCreate or fmShareExclusive);
  try
    Mesaj := HataMesaji('SELECT * FROM T_ALAN', Yol, Bag);
    Kontrol('hata: baska programda acik dosya -> anlasilir cumle', Mesaj = T('ERR_AKTAR_DOSYA'));
  finally
    Kilit.Free;
  end;
  { Baglanti kopmasi: aktarma suruyorken baglanti baska bir baglantidan koparilir (MON$ATTACHMENTS). }
  Ikinci := Tanim;
  Ikinci.Ad := 'aktartest_kopma';
  Kapali := FbBaglan(Ikinci);
  Olcum := TOlcum.Create;
  try
    Say := SorguCalistir(Kapali, 'SELECT CURRENT_CONNECTION FROM RDB$DATABASE');
    try
      Olcum.KoparilacakNo := Say.Sorgu.Fields[0].AsInteger;
    finally
      Say.Free;
    end;
    Olcum.AnaBag := Bag;
    Mesaj := HataMesaji('SELECT * FROM T_BUYUK ORDER BY ID', AktarDosyaYolu('hata_kopma'), Kapali, Olcum.Ilerle);
    Cikti.Add('      koparma islemi calistirildi mi (0 = evet): ' + IntToStr(Olcum.KoparilacakNo));
    Kontrol('hata: baglanti kopmasi -> anlasilir cumle (ERR_KOPTU)', Mesaj = T('ERR_KOPTU'));
  finally
    Olcum.Free;
    FbBaglantiyiKes(Kapali);
  end;
end;

{ ---------- 8. Windows ayarlari ve dil ---------- }

procedure WindowsAyarTesti;
var
  S: TCsvSecenekleri;
begin
  S := WindowsCsvSecenekleri;
  Cikti.Add('      Windows liste ayraci -> "' + S.Ayrac + '", ondalik ayraci -> "' + S.Ondalik + '"');
  Kontrol('windows: ayrac ile ondalik ayraci farkli', S.Ayrac <> S.Ondalik);
  Kontrol('windows: ayrac bos degil', S.Ayrac <> #0);
end;

procedure DilAnahtarTesti;
const
  ANAHTARLAR: array[0..16] of string = ('AKTAR_DUGME', 'AKTAR_AD_SORGU', 'AKTAR_BASLIK', 'AKTAR_DOSYA', 'AKTAR_SEC',
    'AKTAR_BASLAT', 'AKTAR_FILTRE', 'AKTAR_ILERLEME', 'AKTAR_BITTI', 'AKTAR_IPTAL', 'AKTAR_UYARI_BLOB',
    'AKTAR_UYARI_EXCEL', 'ERR_AKTAR_DOSYA_BOS', 'ERR_AKTAR_DOSYA', 'ERR_AKTAR_YAPILAMADI', 'ERR_SALT_OKUNUR',
    'ONAY_UZERINE_YAZ');
var
  Dil, Anahtar: string;
  Eksik: string;
begin
  for Dil in ['tr', 'en', 'de'] do
  begin
    DilYukle(Dil);
    Eksik := '';
    for Anahtar in ANAHTARLAR do
      if T(Anahtar) = Anahtar then
        Eksik := Eksik + ' ' + Anahtar;
    Kontrol('dil ' + Dil + ': tum aktarma anahtarlari var' + IfThen(Eksik <> '', ' (eksik:' + Eksik + ')', ''),
      Eksik = '');
  end;
  DilYukle('tr');
end;

procedure DosyalariArsiveTasi(const Klasor: string; const Dosyalar: array of string);
var
  Dosya, Arsiv: string;
begin
  Arsiv := TPath.Combine(Klasor, '_arsiv');
  ForceDirectories(Arsiv);
  for Dosya in Dosyalar do
    if FileExists(Dosya) then
      TFile.Move(Dosya, TPath.Combine(Arsiv, ExtractFileName(Dosya)));
end;

var
  Tanim: TBaglantiTanimi;
  Dosya, Satirlar, Milyon: string;
  Gomulu: Boolean;
  N, NM: Integer;
begin
  Cikti := TStringList.Create;
  Uretilen := TStringList.Create;
  Bag := nil;
  try
    try
      DilYukle('tr');
      Gomulu := Ortam('FBTEST_SUNUCU', '') = '';
      Klasor := Ortam('FBTEST_KLASOR', TPath.Combine(GetEnvironmentVariable('TEMP'), 'aktartest'));
      if Gomulu then
        ForceDirectories(Klasor);
      CsvKlasoru := TPath.Combine(GetEnvironmentVariable('TEMP'), 'aktartest');
      ForceDirectories(CsvKlasoru);
      Damga := FormatDateTime('yyyymmdd_hhnnss', Now);
      Tanim := Default(TBaglantiTanimi);
      Tanim.Ad := 'aktartest';
      Tanim.Sunucu := Ortam('FBTEST_SUNUCU', '');
      Tanim.Port := StrToInt(Ortam('FBTEST_PORT', '3050'));
      Tanim.VeritabaniYolu := IncludeTrailingPathDelimiter(Klasor) + 'aktartest_' + Damga + '.fdb';
      Tanim.Kullanici := Ortam('FBTEST_KULLANICI', 'SYSDBA');
      Tanim.Sifre := Ortam('FBTEST_SIFRE', '');
      Tanim.KarakterSeti := VARSAYILAN_KARAKTER_SETI;
      GeciciVeritabaniOlustur(Tanim);
      Bag := FbBaglan(Tanim);
      SurumNo := StrToIntDef(Copy(Bag.Surum, 1, Pos('.', Bag.Surum) - 1), 0);
      Cikti.Add('--- Surum ' + Bag.Surum + ', veritabani: ' + Tanim.VeritabaniYolu + ' ---');

      Cikti.Add('--- Windows ayarlari ve dil dosyalari ---');
      WindowsAyarTesti;
      DilAnahtarTesti;

      Cikti.Add('--- 1. Alan kurallari ---');
      AlanTablosunuKur;
      AlanKurallariTesti('alan_noktalivirgul_virgul', Secenek(';', ','));
      AlanKurallariTesti('alan_virgul_nokta', Secenek(',', '.'));
      TakmaAdTesti;

      Cikti.Add('--- 3. Buyuk tablo ---');
      N := StrToIntDef(Ortam('AKTAR_SATIR', '100000'), 100000);
      BuyukTabloKur('T_BUYUK', N);
      BuyukTabloTesti('T_BUYUK', N, N > EXCEL_SATIR_SINIRI);
      Cikti.Add('--- 4. Ekran siniri (500 satir) ve dosyada tum satirlar ---');
      EkranSiniriTesti(N);
      Cikti.Add('--- 5. Iptal ---');
      IptalTesti;
      Cikti.Add('--- 6. Salt okunur ---');
      SaltOkunurTesti;
      Cikti.Add('--- 7. Hatalar ---');
      HataTestleri(Tanim);
      Milyon := Ortam('AKTAR_MILYON', '');
      if Milyon <> '' then
      begin
        Cikti.Add('--- 3b. Cok buyuk tablo (' + Milyon + ' satir) ---');
        NM := StrToInt(Milyon);
        BuyukTabloKur('T_MILYON', NM);
        BuyukTabloTesti('T_MILYON', NM, NM > EXCEL_SATIR_SINIRI);
      end;
      FbBaglantiyiKes(Bag);
      Bag := nil;
      { AKTAR_DB_KALSIN verilirse veritabani arsive tasinmaz (arayuzde elle denemek icin). }
      if Gomulu and (Ortam('AKTAR_DB_KALSIN', '') = '') then
        DosyalariArsiveTasi(Klasor, [Tanim.VeritabaniYolu]);
      { CSV'ler de silinmez, _arsiv'e tasinir. }
      for Dosya in Uretilen do
        if FileExists(Dosya) then
          DosyalariArsiveTasi(CsvKlasoru, [Dosya]);
    except
      on E: Exception do
      begin
        Cikti.Add('HATA  beklenmeyen istisna: ' + E.ClassName + ': ' + E.Message);
        Inc(Hatalar);
      end;
    end;
    Cikti.Add('');
    Cikti.Add('Kontrol sayisi: ' + IntToStr(KontrolSayisi) + ', Hata sayisi: ' + IntToStr(Hatalar));
    Satirlar := Ortam('FBTEST_CIKTI', '');
    if Satirlar <> '' then
      Cikti.SaveToFile(Satirlar, TEncoding.UTF8)
    else
      Writeln(Cikti.Text);
  finally
    Uretilen.Free;
    Cikti.Free;
  end;
  ExitCode := Hatalar;
end.
