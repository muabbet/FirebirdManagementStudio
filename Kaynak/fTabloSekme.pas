{ fTabloSekme.pas - Bir tablo sekmesinin icerigi: ustte kolonlar, altta ilk satirlar.
  Frame sadece arayuzu bilir; isi uMetadata ve uSorgu yapar. }
unit fTabloSekme;

interface

uses
  System.SysUtils, System.Classes, Data.DB, Vcl.Controls, Vcl.Forms, Vcl.ExtCtrls,
  Vcl.StdCtrls, Vcl.Grids, Vcl.DBGrids,
  uDil, uOnay, uBaglanti, uMetadata, uSorgu, uSonucGrid, fCsvAktar;

type
  TTabloSekme = class(TFrame)
    pnlKolonlar: TPanel;
    lblKolonlar: TLabel;
    gridKolonlar: TDBGrid;
    Bolucu: TSplitter;
    pnlVeri: TPanel;
    pnlVeriBaslik: TPanel;
    lblVeri: TLabel;
    btnDisaAktar: TButton;
    gridVeri: TDBGrid;
    dsKolonlar: TDataSource;
    dsVeri: TDataSource;
    procedure btnDisaAktarClick(Sender: TObject);
  private
    FVeriGrid: TSonucGrid;
  public
    BaglantiAd: string;
    TabloAdi: string;
    { Disa aktarma ozeti buraya (ana pencerenin sonuc alani) yazilir; ana pencere atar. }
    AnaSonuc: TStrings;
    procedure Yukle(Bag: TAcikBaglanti; const Tablo: string);
    procedure YazilariYenile;
  end;

implementation

{$R *.dfm}

procedure TTabloSekme.Yukle(Bag: TAcikBaglanti; const Tablo: string);
begin
  BaglantiAd := Bag.Tanim.Ad;
  TabloAdi := Tablo;
  dsKolonlar.DataSet := KolonTablosuOlustur(Bag, Tablo, Self);
  dsVeri.DataSet := TabloVerisiSorgusu(Bag, Tablo, ILK_SATIR_SAYISI, Self);
  FVeriGrid := TSonucGrid.Create(gridVeri);
  FVeriGrid.YeniSonuc;
  btnDisaAktar.Enabled := True;
  YazilariYenile;
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

procedure TTabloSekme.YazilariYenile;
begin
  lblKolonlar.Caption := T('LBL_KOLONLAR');
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
end;

end.
