{ uIkon.pas - Ikon seti (Tabler Icons, MIT lisansi, bkz. LISANSLAR.md).

  Ikonlar uygulamanin yanindaki "Ikonlar" klasorunden PNG olarak yuklenir.
  Sira, asagidaki IKON_* sabitleriyle ayni olmalidir. }
unit uIkon;

interface

uses
  System.SysUtils, System.IOUtils, Vcl.Graphics, Vcl.ImageCollection, Vcl.VirtualImageList, Vcl.ImgList,
  uDil;

const
  IKON_BAGLAN = 0;
  IKON_KES = 1;
  IKON_YENILE = 2;
  IKON_VERITABANI = 3;
  IKON_TABLO = 4;
  IKON_VIEW = 5;
  IKON_PROSEDUR = 6;
  IKON_GENERATOR = 7;
  IKON_KLASOR = 8;
  IKON_KLONLA = 9;
  IKON_COP = 10;
  IKON_SORGU = 11;
  IKON_CALISTIR = 12;
  IKON_PLAN = 13;

procedure IkonlariYukle(Koleksiyon: TImageCollection; Liste: TVirtualImageList);

implementation

const
  IKON_DOSYALARI: array[0..13] of string = (
    'plug', 'plug-off', 'refresh', 'database', 'table', 'eye', 'code',
    'list-numbers', 'folder', 'copy', 'trash', 'code', 'player-play', 'list-tree');

procedure IkonlariYukle(Koleksiyon: TImageCollection; Liste: TVirtualImageList);
var
  Klasor, Dosya, Ad: string;
begin
  Klasor := TPath.Combine(ExtractFilePath(ParamStr(0)), 'Ikonlar');
  for Ad in IKON_DOSYALARI do
  begin
    Dosya := TPath.Combine(Klasor, Ad + '.png');
    if TFile.Exists(Dosya) then
      Koleksiyon.Add(Ad, Dosya)
    else
      raise Exception.Create(TF('ERR_IKON_YOK', [Dosya]));
  end;
  { Sanal ikon listesi, koleksiyona sonradan eklenenleri bu sekilde alir. }
  Liste.ColorDepth := cd32Bit;
  Liste.Masked := False;
  Liste.AutoFill := False;
  Liste.AutoFill := True;
end;

end.
