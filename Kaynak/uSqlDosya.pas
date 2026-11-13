{ uSqlDosya.pas - SQL dosyasi (.sql) okuma ve yazma.

  Okurken kodlama kendiliginden anlasilir: UTF-8 / UTF-16 imi varsa ona gore, yoksa dosya
  gecerli UTF-8 ise UTF-8, degilse Windows'un ANSI kodlamasi (Turkce Windows'ta 1254) kabul edilir.
  Yazarken her zaman imsiz UTF-8 yazilir (isql ve diger araclar imden hoslanmayabilir).
  Bu unit hicbir dosyayi silmez; var olan dosyanin ustune yazma onayi arayuzdedir. }
unit uSqlDosya;

interface

uses
  Winapi.Windows, System.SysUtils, System.Classes, System.IOUtils;

{ Dosyanin metnini verir. Dosya acilamazsa EFOpenError gibi bir istisna olusur. }
function SqlDosyasiniOku(const Yol: string): string;

{ Metni imsiz UTF-8 olarak yazar (dosya yoksa olusur, varsa ustune yazilir). }
procedure SqlDosyasiniYaz(const Yol, Metin: string);

{ Yol uzantisi .sql ise True (buyuk/kucuk harf fark etmez). Surukle-birak bunu kullanir. }
function SqlDosyasiMi(const Yol: string): Boolean;

implementation

{ Baytlar gecerli bir UTF-8 dizisi mi? Gecersizse MultiByteToWideChar 0 doner. }
function GecerliUtf8(const Bayt: TBytes): Boolean;
begin
  if Length(Bayt) = 0 then
    Exit(True);
  Result := MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, PAnsiChar(@Bayt[0]), Length(Bayt), nil, 0) > 0;
end;

function SqlDosyasiniOku(const Yol: string): string;
var
  Bayt: TBytes;
  Kodlama: TEncoding;
  ImUzunlugu: Integer;
begin
  Bayt := TFile.ReadAllBytes(Yol);
  Kodlama := nil;
  ImUzunlugu := TEncoding.GetBufferEncoding(Bayt, Kodlama, TEncoding.Default);
  { Im yoksa GetBufferEncoding varsayilani verir; once UTF-8 mi diye bakariz. }
  if (ImUzunlugu = 0) and GecerliUtf8(Bayt) then
    Kodlama := TEncoding.UTF8;
  Result := Kodlama.GetString(Bayt, ImUzunlugu, Length(Bayt) - ImUzunlugu);
end;

procedure SqlDosyasiniYaz(const Yol, Metin: string);
var
  Bayt: TBytes;
begin
  Bayt := TEncoding.UTF8.GetBytes(Metin);
  TFile.WriteAllBytes(Yol, Bayt);
end;

function SqlDosyasiMi(const Yol: string): Boolean;
begin
  Result := SameText(ExtractFileExt(Yol), '.sql');
end;

end.
