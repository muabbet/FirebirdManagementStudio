{ uSorguGecmisi.pas - SQL gecmisi ve sik kullanilan sorgular (Asama 7e).
  Tek bir JSON dosyasi (sorgu_gecmisi.json, uygulama veri klasorunde) iki liste tutar:
    "gecmis": calistirilan her sorgu (zaman, baglanti adi, SQL); en yenisi basta okunur.
    "sik":    kullanicinin adlandirip sakladigi sorgular (ad, SQL).
  Kurallar:
    - Sifre iceren komutlar (PASSWORD sozcugu) gecmise YAZILMAZ.
    - Gecmis kendiliginden silinmez; "Gecmisi temizle" kullanici onayiyla eski kayitlari tarihli bir dosyaya tasir.
    - Dosya bozuksa silinmez, yanina tasinir (baglanti dosyasindaki gibi). }
unit uSorguGecmisi;

interface

type
  TGecmisKaydi = record
    Zaman: string;
    Baglanti: string;
    Sql: string;
  end;

  TSikSorgu = record
    Ad: string;
    Sql: string;
  end;

var
  { Bos degilse gecmis bu dosyaya yazilir (testler icin). Bos ise uygulama veri klasoru kullanilir. }
  GecmisDosyasiOzel: string;

{ Calistirilan metni gecmise ekler. Bos metin, sifre iceren metin ve bir onceki ile ayni metin eklenmez. }
procedure GecmiseEkle(const Baglanti, Sql: string);
{ Gecmis, en yeni basta. }
function GecmisiOku: TArray<TGecmisKaydi>;
{ Tum gecmisi tarihli bir yan dosyaya tasir (silmez). }
procedure GecmisiTemizle;

function SikSorgulariOku: TArray<TSikSorgu>;
procedure SikSorguEkle(const Ad, Sql: string);
{ Sirasi (0 tabanli) verilen sik sorguyu listeden cikarir. }
procedure SikSorguSil(Sira: Integer);

implementation

uses
  System.SysUtils, System.Classes, System.Generics.Collections, System.IOUtils, System.JSON, System.StrUtils, uDil;

function DosyaYolu: string;
begin
  if GecmisDosyasiOzel <> '' then
    Result := GecmisDosyasiOzel
  else
    Result := TPath.Combine(UygulamaVeriKlasoru, 'sorgu_gecmisi.json');
end;

{ Dosyayi okur; yoksa ya da bozuksa bos bir kok nesne verir (bozuk dosya silinmeden yanina tasinir). }
function DosyayiOku: TJSONObject;
var
  Deger: TJSONValue;
begin
  Result := nil;
  if TFile.Exists(DosyaYolu) then
  begin
    Deger := TJSONObject.ParseJSONValue(TFile.ReadAllText(DosyaYolu, TEncoding.UTF8));
    if Deger is TJSONObject then
      Result := TJSONObject(Deger)
    else
    begin
      Deger.Free;
      TFile.Move(DosyaYolu, DosyaYolu + '.bozuk-' + FormatDateTime('yyyymmdd-hhnnss', Now));
    end;
  end;
  if Result = nil then
    Result := TJSONObject.Create;
end;

procedure DosyayaYaz(Kok: TJSONObject);
var
  Gecici: string;
begin
  ForceDirectories(ExtractFilePath(DosyaYolu));
  Gecici := DosyaYolu + '.tmp';
  TFile.WriteAllText(Gecici, Kok.ToJSON, TEncoding.UTF8);
  if TFile.Exists(DosyaYolu) then
    TFile.Delete(DosyaYolu);
  TFile.Move(Gecici, DosyaYolu);
end;

{ Kokteki diziyi verir; yoksa olusturup koke ekler. }
function DiziBul(Kok: TJSONObject; const Ad: string): TJSONArray;
var
  Deger: TJSONValue;
begin
  Deger := Kok.GetValue(Ad);
  if Deger is TJSONArray then
    Exit(TJSONArray(Deger));
  Result := TJSONArray.Create;
  Kok.AddPair(Ad, Result);
end;

function Metin(Nesne: TJSONObject; const Ad: string): string;
begin
  Result := '';
  if Nesne.GetValue(Ad) <> nil then
    Result := Nesne.GetValue(Ad).Value;
end;

procedure GecmiseEkle(const Baglanti, Sql: string);
var
  Kok: TJSONObject;
  Dizi: TJSONArray;
  Kayit: TJSONObject;
begin
  if Trim(Sql) = '' then
    Exit;
  if ContainsText(Sql, 'PASSWORD') then
    Exit;
  Kok := DosyayiOku;
  try
    Dizi := DiziBul(Kok, 'gecmis');
    if (Dizi.Count > 0) and (Metin(Dizi.Items[Dizi.Count - 1] as TJSONObject, 'sql') = Trim(Sql)) then
      Exit;
    Kayit := TJSONObject.Create;
    Kayit.AddPair('zaman', FormatDateTime('yyyy-mm-dd hh:nn:ss', Now));
    Kayit.AddPair('baglanti', Baglanti);
    Kayit.AddPair('sql', Trim(Sql));
    Dizi.AddElement(Kayit);
    DosyayaYaz(Kok);
  finally
    Kok.Free;
  end;
end;

function GecmisiOku: TArray<TGecmisKaydi>;
var
  Kok: TJSONObject;
  Dizi: TJSONArray;
  i, Sayi: Integer;
  Nesne: TJSONObject;
begin
  Kok := DosyayiOku;
  try
    Dizi := DiziBul(Kok, 'gecmis');
    SetLength(Result, Dizi.Count);
    Sayi := 0;
    for i := Dizi.Count - 1 downto 0 do
    begin
      Nesne := Dizi.Items[i] as TJSONObject;
      Result[Sayi].Zaman := Metin(Nesne, 'zaman');
      Result[Sayi].Baglanti := Metin(Nesne, 'baglanti');
      Result[Sayi].Sql := Metin(Nesne, 'sql');
      Inc(Sayi);
    end;
  finally
    Kok.Free;
  end;
end;

procedure GecmisiTemizle;
var
  Kok: TJSONObject;
  Yan: string;
begin
  Kok := DosyayiOku;
  try
    if DiziBul(Kok, 'gecmis').Count = 0 then
      Exit;
    { Dosyanin tamami tarihli bir yan dosyaya kopyalanir (silinmez); ana dosyada yalniz sik sorgular kalir. }
    Yan := ChangeFileExt(DosyaYolu, '') + '-temizlenen-' + FormatDateTime('yyyymmdd-hhnnss', Now) + '.json';
    TFile.Copy(DosyaYolu, Yan);
    Kok.RemovePair('gecmis').Free;
    DosyayaYaz(Kok);
  finally
    Kok.Free;
  end;
end;

function SikSorgulariOku: TArray<TSikSorgu>;
var
  Kok: TJSONObject;
  Dizi: TJSONArray;
  i: Integer;
  Nesne: TJSONObject;
begin
  Kok := DosyayiOku;
  try
    Dizi := DiziBul(Kok, 'sik');
    SetLength(Result, Dizi.Count);
    for i := 0 to Dizi.Count - 1 do
    begin
      Nesne := Dizi.Items[i] as TJSONObject;
      Result[i].Ad := Metin(Nesne, 'ad');
      Result[i].Sql := Metin(Nesne, 'sql');
    end;
  finally
    Kok.Free;
  end;
end;

procedure SikSorguEkle(const Ad, Sql: string);
var
  Kok: TJSONObject;
  Kayit: TJSONObject;
begin
  if Trim(Sql) = '' then
    Exit;
  Kok := DosyayiOku;
  try
    Kayit := TJSONObject.Create;
    Kayit.AddPair('ad', Ad);
    Kayit.AddPair('sql', Trim(Sql));
    DiziBul(Kok, 'sik').AddElement(Kayit);
    DosyayaYaz(Kok);
  finally
    Kok.Free;
  end;
end;

procedure SikSorguSil(Sira: Integer);
var
  Kok: TJSONObject;
  Dizi: TJSONArray;
begin
  Kok := DosyayiOku;
  try
    Dizi := DiziBul(Kok, 'sik');
    if (Sira < 0) or (Sira >= Dizi.Count) then
      Exit;
    Dizi.Remove(Sira).Free;
    DosyayaYaz(Kok);
  finally
    Kok.Free;
  end;
end;

end.
