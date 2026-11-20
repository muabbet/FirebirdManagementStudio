unit uGuncelleme;

{ Yeni surum denetimi: GitHub'daki son surumu (releases/latest) sorar, bizimkinden yeniyse bildirir.
  Kullanici onaylarsa zip dosyasi Indirilenler klasorune iner. Calisan exe'ye DOKUNULMAZ: kullanici zipi acip
  exe'yi kendisi degistirir. Giden istek yalniz GitHub'a gider ve kisisel bilgi tasimaz (genel bir istemci adi vardir). }

interface

type
  TSurumBilgisi = record
    Basarili: Boolean;
    Yeni: Boolean;
    Surum: string;
    DosyaAdi: string;
    Adres: string;
    Boyut: Int64;
    Hata: string;
  end;

const
  SON_SURUM_ADRESI = 'https://api.github.com/repos/muabbet/FirebirdManagementStudio/releases/latest';
  INDIRME_ADRES_BASI = 'https://github.com/muabbet/FirebirdManagementStudio/';

{ "v0.10" ya da "0.9" gibi yazilari sayilara bolup karsilastirir: A yeni ise 1, esit ise 0, eski ise -1. }
function SurumKarsilastir(const A, B: string): Integer;

{ GitHub'in JSON cevabindan surum bilgisini cikarir (ag olmadan denenebilsin diye ayri). }
function SurumBilgisiniCoz(const Json, MevcutSurum: string): TSurumBilgisi;

{ Agdan sorar. Hata olursa Basarili = False, Hata dolu; program bundan dolayi bir sey yapmaz. }
function SonSurumuDenetle(const MevcutSurum: string): TSurumBilgisi;

{ Zipi Indirilenler klasorune indirir; ayni adli dosya varsa ezmez, (1), (2) ekler. Sonuc: dosyanin yolu. }
function SurumuIndir(const Bilgi: TSurumBilgisi): string;

{ Indirilecek klasor (Indirilenler; bulunamazsa Belgelerim). }
function IndirmeKlasoru: string;

{ Yeni surum bulununca sorar; evet denirse indirir. Sonuc: mesaj alanina yazilacak cumle (yapilacak bir sey yoksa bos). }
function YeniSurumuSorVeIndir(const Bilgi: TSurumBilgisi): string;

implementation

uses
  System.SysUtils, System.Classes, System.JSON, System.IOUtils, System.Net.HttpClient,
  Vcl.Controls, Vcl.Forms, Winapi.Windows, Winapi.ShellAPI, uDil, uOnay;

function SurumParcalari(const Yazi: string): TArray<Integer>;
var
  Temiz: string;
  Parca: TArray<string>;
  I: Integer;
begin
  Temiz := Trim(Yazi);
  if (Temiz <> '') and CharInSet(Temiz[1], ['v', 'V']) then
    Delete(Temiz, 1, 1);
  Parca := Temiz.Split(['.']);
  SetLength(Result, Length(Parca));
  for I := 0 to High(Parca) do
    Result[I] := StrToIntDef(Parca[I], 0);
end;

function SurumKarsilastir(const A, B: string): Integer;
var
  PA, PB: TArray<Integer>;
  I, N, VA, VB: Integer;
begin
  PA := SurumParcalari(A);
  PB := SurumParcalari(B);
  N := Length(PA);
  if Length(PB) > N then
    N := Length(PB);
  for I := 0 to N - 1 do
  begin
    VA := 0;
    VB := 0;
    if I < Length(PA) then
      VA := PA[I];
    if I < Length(PB) then
      VB := PB[I];
    if VA > VB then
      Exit(1);
    if VA < VB then
      Exit(-1);
  end;
  Result := 0;
end;

function SurumBilgisiniCoz(const Json, MevcutSurum: string): TSurumBilgisi;
var
  Kok, Dosya: TJSONObject;
  Dosyalar: TJSONArray;
  Deger: TJSONValue;
  Ad, Adres: string;
  I: Integer;
begin
  Result := Default(TSurumBilgisi);
  Deger := TJSONObject.ParseJSONValue(Json);
  try
    if not (Deger is TJSONObject) then
    begin
      Result.Hata := 'JSON okunamadi';
      Exit;
    end;
    Kok := TJSONObject(Deger);
    Result.Surum := Kok.GetValue<string>('tag_name', '');
    if Result.Surum = '' then
    begin
      Result.Hata := 'tag_name yok';
      Exit;
    end;
    if Result.Surum[1] in ['v', 'V'] then
      Delete(Result.Surum, 1, 1);
    Result.Basarili := True;
    Result.Yeni := SurumKarsilastir(Result.Surum, MevcutSurum) > 0;
    { Ilk .zip dosyasi indirilecek dosyadir. Adres yalniz bu projenin GitHub adresiyse kabul edilir. }
    if Kok.TryGetValue<TJSONArray>('assets', Dosyalar) then
      for I := 0 to Dosyalar.Count - 1 do
      begin
        Dosya := Dosyalar.Items[I] as TJSONObject;
        Ad := Dosya.GetValue<string>('name', '');
        Adres := Dosya.GetValue<string>('browser_download_url', '');
        if SameText(ExtractFileExt(Ad), '.zip') and Adres.StartsWith(INDIRME_ADRES_BASI) then
        begin
          Result.DosyaAdi := ExtractFileName(Ad);
          Result.Adres := Adres;
          Result.Boyut := Dosya.GetValue<Int64>('size', 0);
          Break;
        end;
      end;
  finally
    Deger.Free;
  end;
end;

function SonSurumuDenetle(const MevcutSurum: string): TSurumBilgisi;
var
  Istemci: THTTPClient;
  Cevap: IHTTPResponse;
begin
  Result := Default(TSurumBilgisi);
  Istemci := THTTPClient.Create;
  try
    try
      Istemci.UserAgent := 'FirebirdManagementStudio';
      Istemci.ConnectionTimeout := 5000;
      Istemci.ResponseTimeout := 8000;
      Cevap := Istemci.Get(SON_SURUM_ADRESI);
      if Cevap.StatusCode <> 200 then
      begin
        Result.Hata := 'HTTP ' + IntToStr(Cevap.StatusCode);
        Exit;
      end;
      Result := SurumBilgisiniCoz(Cevap.ContentAsString(TEncoding.UTF8), MevcutSurum);
    except
      on E: Exception do
        Result.Hata := E.Message;
    end;
  finally
    Istemci.Free;
  end;
end;

function IndirmeKlasoru: string;
begin
  Result := TPath.GetDownloadsPath;
  if (Result = '') or not TDirectory.Exists(Result) then
    Result := TPath.GetDocumentsPath;
end;

function SurumuIndir(const Bilgi: TSurumBilgisi): string;
var
  Istemci: THTTPClient;
  Dosya: TFileStream;
  Gecici, Ad, Uzanti: string;
  Sayi: Integer;
begin
  if (Bilgi.Adres = '') or not Bilgi.Adres.StartsWith(INDIRME_ADRES_BASI) then
    raise Exception.Create('Indirme adresi yok');
  { Ayni adli dosya varsa ezilmez: ad(1).zip, ad(2).zip ... }
  Ad := TPath.GetFileNameWithoutExtension(Bilgi.DosyaAdi);
  Uzanti := ExtractFileExt(Bilgi.DosyaAdi);
  Result := TPath.Combine(IndirmeKlasoru, Bilgi.DosyaAdi);
  Sayi := 0;
  while TFile.Exists(Result) do
  begin
    Inc(Sayi);
    Result := TPath.Combine(IndirmeKlasoru, Ad + '(' + IntToStr(Sayi) + ')' + Uzanti);
  end;
  { Yarim kalan indirme asil adla durmasin: once .indiriliyor adiyla yazilir, bitince adi degisir. }
  Gecici := Result + '.indiriliyor';
  Istemci := THTTPClient.Create;
  try
    Istemci.UserAgent := 'FirebirdManagementStudio';
    Istemci.ConnectionTimeout := 10000;
    Dosya := TFileStream.Create(Gecici, fmCreate);
    try
      if Istemci.Get(Bilgi.Adres, Dosya).StatusCode <> 200 then
        raise Exception.Create('Indirme basarisiz');
    finally
      Dosya.Free;
    end;
    TFile.Move(Gecici, Result);
  finally
    Istemci.Free;
  end;
end;

function YeniSurumuSorVeIndir(const Bilgi: TSurumBilgisi): string;
var
  Yol: string;
begin
  Result := '';
  if not Bilgi.Yeni then
    Exit;
  if Bilgi.Adres = '' then
    Exit(TF('MSG_YENI_SURUM_DOSYASIZ', [Bilgi.Surum]));
  if not OnayIste(TF('GUNC_SOR', [Bilgi.Surum, Bilgi.DosyaAdi, Bilgi.Boyut / 1048576, IndirmeKlasoru])) then
    Exit('');
  Screen.Cursor := crHourGlass;
  try
    try
      Yol := SurumuIndir(Bilgi);
    except
      on E: Exception do
      begin
        UyariGoster(T('ERR_GUNC_INDIRILEMEDI') + #13#10 + E.Message);
        Exit('');
      end;
    end;
  finally
    Screen.Cursor := crDefault;
  end;
  { Indirilen dosya klasorde secili gosterilir; program kendiliginden degismez. }
  ShellExecute(0, 'open', 'explorer.exe', PChar('/select,"' + Yol + '"'), nil, SW_SHOWNORMAL);
  Result := TF('MSG_GUNC_INDI', [Yol]);
end;

end.
