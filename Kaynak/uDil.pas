{ uDil.pas - Cok dilli yazi sistemi.

  Dil dosyalari uygulamanin yanindaki "Diller" klasorunde duz JSON olarak durur
  (tr.json, en.json, de.json). Yeni dil eklemek icin sadece yeni bir JSON konur.
  Yedekleme sirasi: secili dil -> Ingilizce -> anahtarin kendisi.
  Formlarda hicbir sabit yazi olmaz, her yazi T('ANAHTAR') ile gelir. }
unit uDil;

interface

uses
  System.SysUtils, System.Classes, System.JSON, System.IOUtils,
  System.Generics.Collections;

type
  TDilBilgisi = record
    Kod: string;
    Ad: string;
  end;

function DilListesi: TArray<TDilBilgisi>;
procedure DilYukle(const Kod: string);
function SecilenDil: string;
function SonKullanilanDil: string;
procedure SonKullanilanDiliKaydet;
function T(const Anahtar: string): string;
function TF(const Anahtar: string; const Degerler: array of const): string;
function UygulamaVeriKlasoru: string;

implementation

const
  VARSAYILAN_DIL = 'tr';
  YEDEK_DIL = 'en';

var
  GSecili: TDictionary<string, string>;
  GIngilizce: TDictionary<string, string>;
  GKod: string;

function DilKlasoru: string;
begin
  Result := TPath.Combine(ExtractFilePath(ParamStr(0)), 'Diller');
end;

function UygulamaVeriKlasoru: string;
begin
  Result := TPath.Combine(TPath.GetHomePath, 'FirebirdYonetici');
  TDirectory.CreateDirectory(Result);
end;

function AyarDosyasi: string;
begin
  Result := TPath.Combine(UygulamaVeriKlasoru, 'ayar.json');
end;

procedure JsonDosyasiniOku(const Dosya: string; Hedef: TDictionary<string, string>);
var
  Kok: TJSONValue;
  Cift: TJSONPair;
begin
  Hedef.Clear;
  if not TFile.Exists(Dosya) then
    Exit;
  Kok := TJSONObject.ParseJSONValue(TFile.ReadAllText(Dosya, TEncoding.UTF8));
  if Kok = nil then
    Exit;
  try
    if Kok is TJSONObject then
      for Cift in TJSONObject(Kok) do
        Hedef.AddOrSetValue(Cift.JsonString.Value, Cift.JsonValue.Value);
  finally
    Kok.Free;
  end;
end;

function DilListesi: TArray<TDilBilgisi>;
var
  Dosyalar: TArray<string>;
  Sozluk: TDictionary<string, string>;
  Liste: TList<TDilBilgisi>;
  Dosya: string;
  Bilgi: TDilBilgisi;
begin
  Liste := TList<TDilBilgisi>.Create;
  Sozluk := TDictionary<string, string>.Create;
  try
    if TDirectory.Exists(DilKlasoru) then
    begin
      Dosyalar := TDirectory.GetFiles(DilKlasoru, '*.json');
      for Dosya in Dosyalar do
      begin
        JsonDosyasiniOku(Dosya, Sozluk);
        Bilgi.Kod := TPath.GetFileNameWithoutExtension(Dosya);
        if not Sozluk.TryGetValue('DIL_ADI', Bilgi.Ad) then
          Bilgi.Ad := Bilgi.Kod;
        Liste.Add(Bilgi);
      end;
    end;
    Result := Liste.ToArray;
  finally
    Sozluk.Free;
    Liste.Free;
  end;
end;

procedure DilYukle(const Kod: string);
begin
  JsonDosyasiniOku(TPath.Combine(DilKlasoru, YEDEK_DIL + '.json'), GIngilizce);
  JsonDosyasiniOku(TPath.Combine(DilKlasoru, Kod + '.json'), GSecili);
  GKod := Kod;
end;

function SecilenDil: string;
begin
  Result := GKod;
end;

function SonKullanilanDil: string;
var
  Kok: TJSONValue;
  Deger: string;
begin
  Result := VARSAYILAN_DIL;
  if not TFile.Exists(AyarDosyasi) then
    Exit;
  Kok := TJSONObject.ParseJSONValue(TFile.ReadAllText(AyarDosyasi, TEncoding.UTF8));
  if Kok = nil then
    Exit;
  try
    if Kok.TryGetValue<string>('Dil', Deger) and (Deger <> '') then
      Result := Deger;
  finally
    Kok.Free;
  end;
end;

procedure SonKullanilanDiliKaydet;
var
  Nesne: TJSONObject;
begin
  Nesne := TJSONObject.Create;
  try
    Nesne.AddPair('Dil', GKod);
    TFile.WriteAllText(AyarDosyasi, Nesne.ToJSON, TEncoding.UTF8);
  finally
    Nesne.Free;
  end;
end;

function T(const Anahtar: string): string;
begin
  if GSecili.TryGetValue(Anahtar, Result) and (Result <> '') then
    Exit;
  if GIngilizce.TryGetValue(Anahtar, Result) and (Result <> '') then
    Exit;
  Result := Anahtar;
end;

function TF(const Anahtar: string; const Degerler: array of const): string;
begin
  try
    Result := Format(T(Anahtar), Degerler);
  except
    Result := T(Anahtar);
  end;
end;

initialization
  GSecili := TDictionary<string, string>.Create;
  GIngilizce := TDictionary<string, string>.Create;

finalization
  GSecili.Free;
  GIngilizce.Free;

end.
