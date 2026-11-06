program IceAktarFormTest;

{ Asama 7b: ice aktar penceresi duman testi (komut satiri). Formu olusturur (DFM okunur, olaylar baglanir) ve yok eder;
  pencere gosterilmez. Cikis kodu: hata sayisi (0 = gecti). }

{$APPTYPE CONSOLE}

uses
  System.SysUtils, Vcl.Forms, Vcl.Controls, uDil, fIceAktar, fTabloKopya, fAktifBaglanti;

var
  Pencere: TfrmIceAktar;
  Kopya: TfrmTabloKopya;
  Aktif: TfrmAktifBaglanti;
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
        Aktif := TfrmAktifBaglanti.Create(nil);
        try
          Writeln('OK    form olusturuldu: ', Aktif.ClassName, ', bilesen sayisi ', Aktif.ComponentCount);
          ExitCode := 0;
        finally
          Aktif.Free;
        end;
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
