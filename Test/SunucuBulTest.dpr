program SunucuBulTest;

{ uSunucuBul testi (komut satiri): yerel makinede 3050-3069 portlarinda Firebird sunuculari aranir, bulunanlar
  FBTEST_CIKTI dosyasina yazilir. Beklenen: acik olan test sunuculari (3052 = 3.0, 3053 = 4.0, 3054 = 2.5) ve varsa
  gercek sunuculari (3050, 3051). Firebird olmayan acik port (ornek 80, 445) listede olmamali. Cikis kodu: hata sayisi. }

{$APPTYPE CONSOLE}

uses
  System.SysUtils, System.Classes, Winapi.Windows, uSunucuBul;

var
  Cikti: TStringList;
  Liste: TArray<TBulunanSunucu>;
  Kayit: TBulunanSunucu;
  Hatalar: Integer;
  Baslangic: Cardinal;
  Protokol: Integer;
begin
  Cikti := TStringList.Create;
  try
    Hatalar := 0;
    Baslangic := GetTickCount;
    Liste := SunuculariBul('localhost');
    Cikti.Add('Tarama suresi: ' + IntToStr(GetTickCount - Baslangic) + ' ms, bulunan: ' + IntToStr(Length(Liste)));
    for Kayit in Liste do
      Cikti.Add('  ' + Kayit.Sunucu + ':' + IntToStr(Kayit.Port) + '  protokol=' + IntToStr(Kayit.Protokol) + '  surum~' + Kayit.Surum);
    { Bilinen acik olmayan port: bulunmamali }
    if FirebirdPortuMu('127.0.0.1', 3069, Protokol) then
    begin
      Cikti.Add('HATA: 3069 Firebird sanildi');
      Inc(Hatalar);
    end;
    { Firebird olmayan ama acik olabilecek port (SMB 445): Firebird sanilmamali }
    if FirebirdPortuMu('127.0.0.1', 445, Protokol) then
    begin
      Cikti.Add('HATA: 445 Firebird sanildi');
      Inc(Hatalar);
    end
    else
      Cikti.Add('OK    445 (Firebird degil) Firebird sanilmadi');
    Cikti.Add('Hata: ' + IntToStr(Hatalar));
    Cikti.SaveToFile(GetEnvironmentVariable('FBTEST_CIKTI'), TEncoding.UTF8);
  finally
    Cikti.Free;
  end;
  ExitCode := Hatalar;
end.
