{ fTabloSekme.pas - Bir tablo sekmesinin icerigi: ustte kolonlar, altta ilk satirlar.
  Frame sadece arayuzu bilir; isi uMetadata ve uSorgu yapar. }
unit fTabloSekme;

interface

uses
  System.SysUtils, System.Classes, Data.DB, Vcl.Controls, Vcl.Forms, Vcl.ExtCtrls,
  Vcl.StdCtrls, Vcl.Grids, Vcl.DBGrids, Vcl.ComCtrls,
  uDil, uOnay, uBaglanti, uMetadata, uSorgu, uSonucGrid, fCsvAktar;

type
  TTabloSekme = class(TFrame)
    pnlKolonlar: TPanel;
    pcYapi: TPageControl;
    tsKolonlar: TTabSheet;
    gridKolonlar: TDBGrid;
    tsIndeksler: TTabSheet;
    gridIndeksler: TDBGrid;
    tsKisitlar: TTabSheet;
    gridKisitlar: TDBGrid;
    tsBagimliliklar: TTabSheet;
    gridBagimliliklar: TDBGrid;
    Bolucu: TSplitter;
    pnlVeri: TPanel;
    pnlVeriBaslik: TPanel;
    lblVeri: TLabel;
    btnDisaAktar: TButton;
    gridVeri: TDBGrid;
    dsKolonlar: TDataSource;
    dsVeri: TDataSource;
    dsIndeksler: TDataSource;
    dsKisitlar: TDataSource;
    dsBagimliliklar: TDataSource;
    procedure btnDisaAktarClick(Sender: TObject);
  private
    FVeriGrid: TSonucGrid;
    procedure YapiyiYukle(Bag: TAcikBaglanti);
    procedure YapiAlanYazilari(Kaynak: TDataSource; const Anahtarlar: array of string);
  public
    BaglantiAd: string;
    TabloAdi: string;
    { Disa aktarma ozeti buraya (ana pencerenin sonuc alani) yazilir; ana pencere atar. }
    AnaSonuc: TStrings;
    procedure Yukle(Bag: TAcikBaglanti; const Tablo: string);
    procedure YazilariYenile;
    { Sag tik "Bagimliliklar": ustteki alt sekmeyi Bagimliliklar'a getirir. }
    procedure BagimliliklariGoster;
  end;

implementation

{$R *.dfm}

procedure TTabloSekme.Yukle(Bag: TAcikBaglanti; const Tablo: string);
begin
  BaglantiAd := Bag.Tanim.Ad;
  TabloAdi := Tablo;
  dsKolonlar.DataSet := KolonTablosuOlustur(Bag, Tablo, Self);
  YapiyiYukle(Bag);
  dsVeri.DataSet := TabloVerisiSorgusu(Bag, Tablo, ILK_SATIR_SAYISI, Self);
  FVeriGrid := TSonucGrid.Create(gridVeri);
  FVeriGrid.YeniSonuc;
  btnDisaAktar.Enabled := True;
  YazilariYenile;
end;

{ Index'ler, kisitlar ve bagimliliklar: her seferinde yeniden okunur (dil degisince yazilar da yenilenir). }
procedure TTabloSekme.YapiyiYukle(Bag: TAcikBaglanti);
begin
  dsIndeksler.DataSet.Free;
  dsKisitlar.DataSet.Free;
  dsBagimliliklar.DataSet.Free;
  dsIndeksler.DataSet := IndeksTablosuOlustur(Bag, TabloAdi, Self);
  dsKisitlar.DataSet := KisitTablosuOlustur(Bag, TabloAdi, Self);
  dsBagimliliklar.DataSet := BagimlilikTablosuOlustur(Bag, TabloAdi, Self);
  YapiAlanYazilari(dsIndeksler, ['YAPI_AD', 'YAPI_KOLONLAR', 'YAPI_BENZERSIZ', 'YAPI_YON', 'YAPI_DURUM']);
  YapiAlanYazilari(dsKisitlar, ['YAPI_AD', 'YAPI_TUR', 'YAPI_KOLONLAR', 'YAPI_DETAY']);
  YapiAlanYazilari(dsBagimliliklar, ['YAPI_TUR', 'YAPI_AD']);
end;

{ Bellek tablosunun kolon basliklarini sirayla verilen dil anahtarlariyla yazar. }
procedure TTabloSekme.YapiAlanYazilari(Kaynak: TDataSource; const Anahtarlar: array of string);
var
  i: Integer;
begin
  for i := 0 to High(Anahtarlar) do
    Kaynak.DataSet.Fields[i].DisplayLabel := T(Anahtarlar[i]);
end;

{ Dugme: sekmede yalniz ilk 100 satir gorunse de tablonun TUM satirlarini CSV'ye yazar (bkz. uAktar). }
procedure TTabloSekme.btnDisaAktarClick(Sender: TObject);
var
  Bag: TAcikBaglanti;
begin
  Bag := FbAcikBaglanti(BaglantiAd);
  if Bag = nil then
  begin
    UyariGoster(TF('ERR_SORGU_BAGLANTI_YOK', [BaglantiAd]));
    Exit;
  end;
  CsvPenceresiniGoster(Bag, TabloTumSatirlarSorgusu(TabloAdi), TabloAdi, AnaSonuc);
end;

procedure TTabloSekme.BagimliliklariGoster;
begin
  pcYapi.ActivePage := tsBagimliliklar;
end;

procedure TTabloSekme.YazilariYenile;
var
  Bag: TAcikBaglanti;
begin
  tsKolonlar.Caption := T('LBL_KOLONLAR');
  tsIndeksler.Caption := T('LBL_INDEKSLER');
  tsKisitlar.Caption := T('LBL_KISITLAR');
  tsBagimliliklar.Caption := T('LBL_BAGIMLILIKLAR');
  lblVeri.Caption := T('LBL_ILK_SATIRLAR');
  btnDisaAktar.Caption := T('AKTAR_DUGME');
  DugmeyiYaziyaUydur(btnDisaAktar);
  if dsKolonlar.DataSet <> nil then
  begin
    dsKolonlar.DataSet.FieldByName('AD').DisplayLabel := T('KOLON_AD');
    dsKolonlar.DataSet.FieldByName('TIP').DisplayLabel := T('KOLON_TIP');
    dsKolonlar.DataSet.FieldByName('BOS_OLUR').DisplayLabel := T('KOLON_BOS_OLUR');
    KolonTablosuYazilariniYenile(dsKolonlar.DataSet);
  end;
  { Bagli degilse (kopmus) eski yazilar kalir; dil degisince yalniz bagliyken yeniden okunur. }
  Bag := FbAcikBaglanti(BaglantiAd);
  if (Bag <> nil) and (dsIndeksler.DataSet <> nil) then
    YapiyiYukle(Bag);
end;

end.
