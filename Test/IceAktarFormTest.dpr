program IceAktarFormTest;

{ Asama 7b: ice aktar penceresi duman testi (komut satiri). Formu olusturur (DFM okunur, olaylar baglanir) ve yok eder;
  pencere gosterilmez. Cikis kodu: hata sayisi (0 = gecti). }

{$APPTYPE CONSOLE}

uses
  System.SysUtils, Vcl.Forms, Vcl.Controls, uDil, fIceAktar, fTabloKopya;

var
  Pencere: TfrmIceAktar;
  Kopya: TfrmTabloKopya;
begin
  ExitCode := 1;
  try
    DilYukle('tr');
    Pencere := TfrmIceAktar.Create(nil);
    try
      Writeln('OK    form olusturuldu: ', Pencere.ClassName, ', bilesen sayisi ', Pencere.ComponentCount);
      Kopya := TfrmTabloKopya.Create(nil);
      try
        Writeln('OK    form olusturuldu: ', Kopya.ClassName, ', bilesen sayisi ', Kopya.ComponentCount);
        ExitCode := 0;
      finally
        Kopya.Free;
      end;
    finally
      Pencere.Free;
    end;
  except
    on E: Exception do
      Writeln('HATA  ', E.ClassName, ': ', E.Message);
  end;
end.
