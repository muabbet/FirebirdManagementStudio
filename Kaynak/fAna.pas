{ fAna.pas - Ana form: sol agac, sag sekmeler, alt sonuc alani, ust arac cubugu.
  Form sadece arayuzu bilir; is uBaglanti, uMetadata, uSorgu unit'lerindedir. }
unit fAna;

interface

uses
  Winapi.Windows, System.SysUtils, System.Classes, Vcl.Controls, Vcl.Forms,
  Vcl.ComCtrls, Vcl.ToolWin, Vcl.ExtCtrls, Vcl.StdCtrls, Vcl.Menus,
  Vcl.ImgList, Vcl.VirtualImageList, Vcl.BaseImageCollection, Vcl.ImageCollection,
  uDil, uIkon, uBaglanti, uMetadata, fBaglanti, fTabloSekme;

type
  TfrmAna = class(TForm)
    pnlUst: TPanel;
    tbAna: TToolBar;
    btnBaglan: TToolButton;
    btnKes: TToolButton;
    btnYenile: TToolButton;
    pnlDil: TPanel;
    cmbDil: TComboBox;
    stbDurum: TStatusBar;
    tvNesneler: TTreeView;
    bolSol: TSplitter;
    pnlSag: TPanel;
    pcCalisma: TPageControl;
    bolAlt: TSplitter;
    memSonuc: TMemo;
    icIkonlar: TImageCollection;
    vilIkonlar: TVirtualImageList;
    pmNesne: TPopupMenu;
    miAc: TMenuItem;
    miYenile: TMenuItem;
    pmSekme: TPopupMenu;
    miSekmeKapat: TMenuItem;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure btnBaglanClick(Sender: TObject);
    procedure btnKesClick(Sender: TObject);
    procedure btnYenileClick(Sender: TObject);
    procedure cmbDilChange(Sender: TObject);
    procedure tvNesnelerDblClick(Sender: TObject);
    procedure pmNesnePopup(Sender: TObject);
    procedure miAcClick(Sender: TObject);
    procedure miYenileClick(Sender: TObject);
    procedure miSekmeKapatClick(Sender: TObject);
  private
    FDilKodlari: TArray<string>;
    FKokDugum: TTreeNode;
    FDallar: array[0..3] of TTreeNode;
    procedure YazilariYenile;
    procedure DilListesiniDoldur;
    procedure DurumuGuncelle;
    procedure AgaciDoldur;
    function AgaciYenile: Boolean;
    procedure AgaciTemizle;
    procedure AgacYazilariniYenile;
    procedure DalDoldur(DalNo, Ikon: Integer; Liste: TStrings);
    procedure TumSekmeleriKapat;
    procedure TabloAc(const Tablo: string);
    function SeciliTabloAdi: string;
    procedure MesajYaz(const Metin: string);
    procedure HataYaz(const Mesaj: string; const HamMesaj: string);
  end;

var
  frmAna: TfrmAna;

implementation

{$R *.dfm}


const
  DAL_TABLO = 0;
  DAL_VIEW = 1;
  DAL_PROSEDUR = 2;
  DAL_GENERATOR = 3;

procedure TfrmAna.FormCreate(Sender: TObject);
begin
  DilYukle(SonKullanilanDil);
  IkonlariYukle(icIkonlar, vilIkonlar);
  DilListesiniDoldur;
  YazilariYenile;
  DurumuGuncelle;
end;

procedure TfrmAna.FormDestroy(Sender: TObject);
begin
  FbBaglantiyiKes;
end;

procedure TfrmAna.DilListesiniDoldur;
var
  Dil: TDilBilgisi;
begin
  cmbDil.Items.Clear;
  SetLength(FDilKodlari, 0);
  for Dil in DilListesi do
  begin
    cmbDil.Items.Add(Dil.Ad);
    SetLength(FDilKodlari, Length(FDilKodlari) + 1);
    FDilKodlari[High(FDilKodlari)] := Dil.Kod;
    if Dil.Kod = SecilenDil then
      cmbDil.ItemIndex := cmbDil.Items.Count - 1;
  end;
end;

{ Ekrandaki butun yazilari secili dilden yeniden yazar. }
procedure TfrmAna.YazilariYenile;
var
  i: Integer;
begin
  Caption := T('APP_BASLIK');
  btnBaglan.Caption := T('BTN_BAGLAN');
  btnKes.Caption := T('BTN_KES');
  btnYenile.Caption := T('BTN_YENILE');
  miAc.Caption := T('MENU_AC');
  miYenile.Caption := T('MENU_YENILE');
  miSekmeKapat.Caption := T('MENU_SEKME_KAPAT');
  cmbDil.Hint := T('LBL_DIL');
  AgacYazilariniYenile;
  for i := 0 to pcCalisma.PageCount - 1 do
    if pcCalisma.Pages[i].ControlCount > 0 then
      if pcCalisma.Pages[i].Controls[0] is TTabloSekme then
        TTabloSekme(pcCalisma.Pages[i].Controls[0]).YazilariYenile;
  DurumuGuncelle;
end;

procedure TfrmAna.DurumuGuncelle;
begin
  if FbBagliMi then
  begin
    stbDurum.Panels[0].Text := TF('DURUM_BAGLI', [FbAktifBaglantiAdi]);
    stbDurum.Panels[1].Text := TF('DURUM_SURUM', [FbSurum]);
    if FbIslemAcikMi then
      stbDurum.Panels[2].Text := T('DURUM_ISLEM_ACIK')
    else
      stbDurum.Panels[2].Text := T('DURUM_ISLEM_KAPALI');
  end
  else
  begin
    stbDurum.Panels[0].Text := T('DURUM_BAGLI_DEGIL');
    stbDurum.Panels[1].Text := '';
    stbDurum.Panels[2].Text := '';
  end;
  btnKes.Enabled := FbBagliMi;
  btnYenile.Enabled := FbBagliMi;
end;

procedure TfrmAna.MesajYaz(const Metin: string);
begin
  memSonuc.Lines.Add(Metin);
end;

procedure TfrmAna.HataYaz(const Mesaj: string; const HamMesaj: string);
begin
  memSonuc.Lines.Add(Mesaj);
  if HamMesaj <> '' then
    memSonuc.Lines.Add(T('AYRINTI') + ': ' + HamMesaj);
end;

{ ---------- Agac ---------- }

procedure TfrmAna.AgaciTemizle;
begin
  tvNesneler.Items.Clear;
  FKokDugum := nil;
  FDallar[DAL_TABLO] := nil;
  FDallar[DAL_VIEW] := nil;
  FDallar[DAL_PROSEDUR] := nil;
  FDallar[DAL_GENERATOR] := nil;
end;

procedure TfrmAna.DalDoldur(DalNo, Ikon: Integer; Liste: TStrings);
var
  Ad: string;
  Dugum: TTreeNode;
begin
  for Ad in Liste do
  begin
    Dugum := tvNesneler.Items.AddChild(FDallar[DalNo], Ad);
    Dugum.ImageIndex := Ikon;
    Dugum.SelectedIndex := Ikon;
  end;
end;

procedure TfrmAna.AgaciDoldur;
var
  Liste: TStringList;
  i: Integer;
begin
  AgaciTemizle;
  Liste := TStringList.Create;
  tvNesneler.Items.BeginUpdate;
  try
    FKokDugum := tvNesneler.Items.Add(nil, FbAktifBaglantiAdi);
    FKokDugum.ImageIndex := IKON_VERITABANI;
    FKokDugum.SelectedIndex := IKON_VERITABANI;
    for i := 0 to 3 do
    begin
      FDallar[i] := tvNesneler.Items.AddChild(FKokDugum, '');
      FDallar[i].ImageIndex := IKON_KLASOR;
      FDallar[i].SelectedIndex := IKON_KLASOR;
    end;
    TablolariGetir(Liste);
    DalDoldur(DAL_TABLO, IKON_TABLO, Liste);
    ViewlariGetir(Liste);
    DalDoldur(DAL_VIEW, IKON_VIEW, Liste);
    ProsedurleriGetir(Liste);
    DalDoldur(DAL_PROSEDUR, IKON_PROSEDUR, Liste);
    GeneratorleriGetir(Liste);
    DalDoldur(DAL_GENERATOR, IKON_GENERATOR, Liste);
    FKokDugum.Expand(False);
    FDallar[DAL_TABLO].Expand(False);
  finally
    tvNesneler.Items.EndUpdate;
    Liste.Free;
  end;
  AgacYazilariniYenile;
end;

{ Dal basliklarini secili dille yazar (sayilariyla birlikte). }
procedure TfrmAna.AgacYazilariniYenile;
const
  ANAHTARLAR: array[0..3] of string = (
    'AGAC_TABLOLAR', 'AGAC_VIEWLAR', 'AGAC_PROSEDURLER', 'AGAC_GENERATORLER');
var
  i: Integer;
begin
  for i := 0 to 3 do
    if FDallar[i] <> nil then
      FDallar[i].Text := T(ANAHTARLAR[i]) + ' (' + IntToStr(FDallar[i].Count) + ')';
end;

{ Secili dugum bir tablo ise adini verir, degilse bos doner. }
function TfrmAna.SeciliTabloAdi: string;
var
  Dugum: TTreeNode;
begin
  Result := '';
  Dugum := tvNesneler.Selected;
  if (Dugum <> nil) and (Dugum.Parent <> nil) and (Dugum.Parent = FDallar[DAL_TABLO]) then
    Result := Dugum.Text;
end;

{ ---------- Sekmeler ---------- }

procedure TfrmAna.TumSekmeleriKapat;
begin
  while pcCalisma.PageCount > 0 do
    pcCalisma.Pages[0].Free;
end;

procedure TfrmAna.TabloAc(const Tablo: string);
var
  Sayfa: TTabSheet;
  Sekme: TTabloSekme;
  i: Integer;
begin
  for i := 0 to pcCalisma.PageCount - 1 do
    if pcCalisma.Pages[i].Caption = Tablo then
    begin
      pcCalisma.ActivePage := pcCalisma.Pages[i];
      Exit;
    end;
  Sayfa := TTabSheet.Create(pcCalisma);
  Sayfa.PageControl := pcCalisma;
  Sayfa.Caption := Tablo;
  Sayfa.ImageIndex := IKON_TABLO;
  Sekme := TTabloSekme.Create(Sayfa);
  Sekme.Parent := Sayfa;
  Sekme.Align := alClient;
  try
    Sekme.Yukle(Tablo);
  except
    on E: Exception do
    begin
      Sayfa.Free;
      HataYaz(TF('ERR_TABLO_ACILAMADI', [Tablo]) + ' ' + HataMetniniCevir(E.Message), E.Message);
      Exit;
    end;
  end;
  pcCalisma.ActivePage := Sayfa;
  MesajYaz(TF('MSG_TABLO_ACILDI', [Tablo, 100]));
  DurumuGuncelle;
end;

{ ---------- Dugme ve menu olaylari ---------- }

{ Agaci sunucudan yeniden okur. Hata olursa sonuc alanina yazar. }
function TfrmAna.AgaciYenile: Boolean;
begin
  Result := False;
  try
    AgaciDoldur;
    Result := True;
  except
    on E: Exception do
      HataYaz(HataMetniniCevir(E.Message), E.Message);
  end;
end;

procedure TfrmAna.btnBaglanClick(Sender: TObject);
begin
  if not BaglantiPenceresiniGoster then
    Exit;
  TumSekmeleriKapat;
  AgaciYenile;
  MesajYaz(TF('MSG_BAGLANDI', [FbAktifBaglantiAdi, FbSurum]));
  DurumuGuncelle;
end;

procedure TfrmAna.btnKesClick(Sender: TObject);
begin
  TumSekmeleriKapat;
  AgaciTemizle;
  FbBaglantiyiKes;
  MesajYaz(T('MSG_KESILDI'));
  DurumuGuncelle;
end;

procedure TfrmAna.btnYenileClick(Sender: TObject);
begin
  if AgaciYenile then
    MesajYaz(T('MSG_AGAC_YENILENDI'));
  DurumuGuncelle;
end;

procedure TfrmAna.cmbDilChange(Sender: TObject);
begin
  if cmbDil.ItemIndex < 0 then
    Exit;
  DilYukle(FDilKodlari[cmbDil.ItemIndex]);
  SonKullanilanDiliKaydet;
  YazilariYenile;
end;

procedure TfrmAna.tvNesnelerDblClick(Sender: TObject);
begin
  if SeciliTabloAdi <> '' then
    TabloAc(SeciliTabloAdi);
end;

procedure TfrmAna.pmNesnePopup(Sender: TObject);
begin
  miAc.Enabled := SeciliTabloAdi <> '';
  miYenile.Enabled := FbBagliMi;
end;

procedure TfrmAna.miAcClick(Sender: TObject);
begin
  if SeciliTabloAdi <> '' then
    TabloAc(SeciliTabloAdi);
end;

procedure TfrmAna.miYenileClick(Sender: TObject);
begin
  if AgaciYenile then
    MesajYaz(T('MSG_AGAC_YENILENDI'));
  DurumuGuncelle;
end;

procedure TfrmAna.miSekmeKapatClick(Sender: TObject);
begin
  if pcCalisma.ActivePage <> nil then
    pcCalisma.ActivePage.Free;
end;

end.
