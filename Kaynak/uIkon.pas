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
  IKON_SORGU = 6;
  IKON_CALISTIR = 11;
  IKON_PLAN = 12;
  IKON_METADATA = 13;
  { Yedek icin ayri ikon yok; gecici olarak klasor ikonu (rapora yazildi). }
  IKON_YEDEK = IKON_KLASOR;
  { Kullanicilar icin ayri ikon yok (Ikonlar\svg icinde kullanici ikonu yok); gecici olarak liste ikonu (rapora yazildi). }
  IKON_KULLANICI = IKON_GENERATOR;

procedure IkonlariKoleksiyonaYukle(Koleksiyon: TImageCollection);
procedure IkonlariYukle(Koleksiyon: TImageCollection; Liste: TVirtualImageList);

implementation

const
  IKON_DOSYALARI: array[0..13] of string = (
    'plug', 'plug-off', 'refresh', 'database', 'table', 'eye', 'code',
    'list-numbers', 'folder', 'copy', 'trash', 'player-play', 'list-tree',
    'file-plus');

{ PNG dosyalarini koleksiyona sirayla ekler. Serit kendi koleksiyonunu kullanir:
  agacin ortak koleksiyonuna baska boyutta cizim yapmak agac ikonlarini bozuyor. }
procedure IkonlariKoleksiyonaYukle(Koleksiyon: TImageCollection);
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
end;

procedure IkonlariYukle(Koleksiyon: TImageCollection; Liste: TVirtualImageList);
begin
  IkonlariKoleksiyonaYukle(Koleksiyon);
  { Sanal ikon listesi, koleksiyona sonradan eklenenleri bu sekilde alir. }
  Liste.ColorDepth := cd32Bit;
  Liste.Masked := False;
  Liste.AutoFill := False;
  Liste.AutoFill := True;
end;

end.
