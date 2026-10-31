{ uPaket.pas - Programin dosyalari tek .exe'nin icinde.

  Dil dosyalari (Diller), ikonlar (Ikonlar), anahtar_kelimeler.txt, tema (Stiller\Windows10.vsf) ve Firebird istemcisi
  (istemci: fbclient.dll, gbak.exe, eklentiler) derleme sirasinda bir ZIP olarak .exe'ye gomulur (Paket.rc, PaketHazirla.bat).
  Program ilk acilista bu ZIP'i kullanicinin klasorune (%LOCALAPPDATA%\FirebirdYonetici\paket) acar; sonraki acilislarda
  .exe ayni ise tekrar acmaz. Hicbir sey silinmez, yalniz ayni adli dosyalarin ustune yazilir.

  Gelistirme / deneme: .exe'nin yaninda Diller\tr.json varsa (derleme klasoru) gomulu paket kullanilmaz, dosyalar
  oradan okunur. Boylece derleme sonrasi tum dosyalar yanda durur ve testler eskisi gibi calisir. }
unit uPaket;

interface

{ Dosyalarin bulundugu klasor (sonunda '\' yok). Diller, Ikonlar, istemci, Stiller bunun altindadir. }
function PaketKlasoru: string;

implementation

uses
  System.SysUtils, System.Classes, System.IOUtils, System.DateUtils, System.Zip, Winapi.Windows;

const
  KAYNAK_ADI = 'PAKET';

var
  GKlasor: string;

function GomuluPaketVarMi: Boolean;
begin
  Result := FindResource(HInstance, KAYNAK_ADI, RT_RCDATA) <> 0;
end;

{ Paketin kimligi: gomulu ZIP'in boyu ve .exe'nin degisme zamani. Yeni surum .exe'si farkli imza verir. }
function PaketImzasi(Boy: Int64): string;
begin
  Result := IntToStr(Boy) + '_' + IntToStr(DateTimeToUnix(TFile.GetLastWriteTime(ParamStr(0))));
end;

procedure PaketiAc(const Hedef: string);
var
  Kaynak: TResourceStream;
  Zip: TZipFile;
  ImzaDosyasi, Imza: string;
begin
  Kaynak := TResourceStream.Create(HInstance, KAYNAK_ADI, RT_RCDATA);
  try
    Imza := PaketImzasi(Kaynak.Size);
    ImzaDosyasi := TPath.Combine(Hedef, 'paket.imza');
    if TFile.Exists(ImzaDosyasi) and (TFile.ReadAllText(ImzaDosyasi) = Imza) then
      Exit;
    ForceDirectories(Hedef);
    Zip := TZipFile.Create;
    try
      Zip.Open(Kaynak, zmRead);
      Zip.ExtractAll(Hedef);
      Zip.Close;
    finally
      Zip.Free;
    end;
    TFile.WriteAllText(ImzaDosyasi, Imza);
  finally
    Kaynak.Free;
  end;
end;

function PaketKlasoru: string;
var
  Yan: string;
begin
  if GKlasor <> '' then
    Exit(GKlasor);
  Yan := ExcludeTrailingPathDelimiter(ExtractFilePath(ParamStr(0)));
  if TFile.Exists(TPath.Combine(Yan, 'Diller\tr.json')) or not GomuluPaketVarMi then
    GKlasor := Yan
  else
  begin
    GKlasor := TPath.Combine(GetEnvironmentVariable('LOCALAPPDATA'), 'FirebirdYonetici\paket');
    try
      PaketiAc(GKlasor);
    except
      on E: Exception do
        raise Exception.Create('Paket acilamadi / Could not unpack the program files to ' + GKlasor + ': ' + E.Message);
    end;
  end;
  Result := GKlasor;
end;

end.
