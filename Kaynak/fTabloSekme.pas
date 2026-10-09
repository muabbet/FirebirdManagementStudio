{ fTabloSekme.pas - Bir tablo sekmesinin icerigi: ustte kolonlar, altta ilk satirlar.
  Frame sadece arayuzu bilir; isi uMetadata ve uSorgu yapar. }
unit fTabloSekme;

interface

uses
  System.SysUtils, System.Classes, Data.DB, Vcl.Controls, Vcl.Forms, Vcl.ExtCtrls,
  Vcl.StdCtrls, Vcl.Grids, Vcl.DBGrids,
  uDil, uMetadata, uSorgu;

type
  TTabloSekme = class(TFrame)
    pnlKolonlar: TPanel;
    lblKolonlar: TLabel;
    gridKolonlar: TDBGrid;
    Bolucu: TSplitter;
    pnlVeri: TPanel;
    lblVeri: TLabel;
    gridVeri: TDBGrid;
    dsKolonlar: TDataSource;
    dsVeri: TDataSource;
  public
    procedure Yukle(const Tablo: string);
    procedure YazilariYenile;
  end;

implementation

{$R *.dfm}

procedure TTabloSekme.Yukle(const Tablo: string);
begin
  dsKolonlar.DataSet := KolonTablosuOlustur(Tablo, Self);
  dsVeri.DataSet := TabloVerisiSorgusu(Tablo, ILK_SATIR_SAYISI, Self);
  YazilariYenile;
end;

procedure TTabloSekme.YazilariYenile;
begin
  lblKolonlar.Caption := T('LBL_KOLONLAR');
  lblVeri.Caption := T('LBL_ILK_SATIRLAR');
  if dsKolonlar.DataSet <> nil then
  begin
    dsKolonlar.DataSet.FieldByName('AD').DisplayLabel := T('KOLON_AD');
    dsKolonlar.DataSet.FieldByName('TIP').DisplayLabel := T('KOLON_TIP');
    dsKolonlar.DataSet.FieldByName('BOS_OLUR').DisplayLabel := T('KOLON_BOS_OLUR');
    KolonTablosuYazilariniYenile(dsKolonlar.DataSet);
  end;
end;

end.
