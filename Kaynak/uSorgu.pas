{ uSorgu.pas - SQL calistirma.

  Asama 1'de sadece bir tablonun ilk satirlarini getirir. Parca parca cekme,
  hata yakalama ve sorgu plani Asama 2'de buraya eklenecek.
  Veri sadece okunur, bu unit hicbir sey degistirmez. }
unit uSorgu;

interface

uses
  System.SysUtils, System.Classes, Data.DB,
  FireDAC.Stan.Intf, FireDAC.Stan.Option, FireDAC.Stan.Param, FireDAC.Stan.Error,
  FireDAC.DatS, FireDAC.Phys.Intf, FireDAC.DApt.Intf, FireDAC.Comp.DataSet,
  FireDAC.Comp.Client,
  uBaglanti;

const
  ILK_SATIR_SAYISI = 100;

function TabloVerisiSorgusu(const Tablo: string; SatirSayisi: Integer;
  Sahip: TComponent): TFDQuery;

implementation

function TirnakliAd(const Ad: string): string;
begin
  Result := '"' + StringReplace(Ad, '"', '""', [rfReplaceAll]) + '"';
end;

{ Sorgu, Sahip ile birlikte yok olur. Sorgu salt okunurdur. }
function TabloVerisiSorgusu(const Tablo: string; SatirSayisi: Integer;
  Sahip: TComponent): TFDQuery;
begin
  Result := TFDQuery.Create(Sahip);
  try
    Result.Connection := FbBaglantisi;
    Result.UpdateOptions.ReadOnly := True;
    { En fazla 100 satir hepsi birden cekilir. Boylece okuma isleminin sunucuda
      acik kalmasi onlenir (parca parca cekme Asama 2'de, buraya eklenecek). }
    Result.FetchOptions.Mode := fmAll;
    Result.SQL.Text := 'SELECT FIRST ' + IntToStr(SatirSayisi) + ' * FROM ' + TirnakliAd(Tablo);
    Result.Open;
  except
    Result.Free;
    raise;
  end;
end;

end.
