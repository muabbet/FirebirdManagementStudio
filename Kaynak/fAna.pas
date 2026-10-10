{ fAna.pas - Ana form: sol agac, sag sekmeler, alt sonuc alani, ust arac cubugu.
  Form sadece arayuzu bilir; is uBaglanti, uMetadata, uSorgu unit'lerindedir.

  Agac: kokte klasorler ve kayitli baglantilar durur. Baglanti acilinca altinda
  dort dal (Tablolar, View'lar, Prosedurler, Generator'lar) dolar. Birden fazla
  baglanti ayni anda acik olabilir. Her agac dugumunun Data alani bir
  TAgacOgesi'ni gosterir; dugumun ne oldugu orada yazar. }
unit fAna;

interface

uses
  Winapi.Windows, System.SysUtils, System.Classes, System.Generics.Collections,
  Vcl.Controls, Vcl.Forms, Vcl.ComCtrls, Vcl.ToolWin, Vcl.ExtCtrls, Vcl.StdCtrls,
  Vcl.Menus, Vcl.ImgList, Vcl.VirtualImageList, Vcl.BaseImageCollection,
  Vcl.ImageCollection,
  uDil, uIkon, uOnay, uBaglanti, uMetadata, uSorgu, fBaglanti, fMetinSor,
  fTabloSekme;

type
  TAgacTuru = (atKlasor, atBaglanti, atDal, atNesne);

  { Agac dugumunun kimligi. BaglantiAd: dugumun ait oldugu kayitli baglanti
    (klasorde bos). Ad: klasor adi veya nesne adi. DalNo: dal ve nesne icin. }
  TAgacOgesi = class
    Tur: TAgacTuru;
    BaglantiAd: string;
    Ad: string;
    DalNo: Integer;
  end;

  TfrmAna = class(TForm)
    pnlUst: TPanel;
    tbAna: TToolBar;
    btnYeniBaglanti: TToolButton;
    btnBaglan: TToolButton;
    btnKes: TToolButton;
    btnYenile: TToolButton;
    btnYeniKlasor: TToolButton;
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
    miBaglan: TMenuItem;
    miKes: TMenuItem;
    miYenile: TMenuItem;
    miDuzenle: TMenuItem;
    miKaldir: TMenuItem;
    miKlasorAdi: TMenuItem;
    miKlasorKaldir: TMenuItem;
    miYeniKlasor: TMenuItem;
    pmSekme: TPopupMenu;
    miSekmeKapat: TMenuItem;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure btnYeniBaglantiClick(Sender: TObject);
    procedure btnBaglanClick(Sender: TObject);
    procedure btnKesClick(Sender: TObject);
    procedure btnYenileClick(Sender: TObject);
    procedure btnYeniKlasorClick(Sender: TObject);
    procedure cmbDilChange(Sender: TObject);
    procedure tvNesnelerChange(Sender: TObject; Node: TTreeNode);
    procedure tvNesnelerDblClick(Sender: TObject);
    procedure tvNesnelerMouseDown(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure tvNesnelerDragOver(Sender, Source: TObject; X, Y: Integer;
      State: TDragState; var Accept: Boolean);
    procedure tvNesnelerDragDrop(Sender, Source: TObject; X, Y: Integer);
    procedure pmNesnePopup(Sender: TObject);
    procedure miAcClick(Sender: TObject);
    procedure miBaglanClick(Sender: TObject);
    procedure miKesClick(Sender: TObject);
    procedure miYenileClick(Sender: TObject);
    procedure miDuzenleClick(Sender: TObject);
    procedure miKaldirClick(Sender: TObject);
    procedure miKlasorAdiClick(Sender: TObject);
    procedure miKlasorKaldirClick(Sender: TObject);
    procedure miYeniKlasorClick(Sender: TObject);
    procedure miSekmeKapatClick(Sender: TObject);
  private
    FDilKodlari: TArray<string>;
    FOgeler: TObjectList<TAgacOgesi>;
    FSurukleNode: TTreeNode;
    procedure YazilariYenile;
    procedure DilListesiniDoldur;
    procedure DurumuGuncelle;
    procedure MesajYaz(const Metin: string);
    procedure HataYaz(const Mesaj: string; const HamMesaj: string);
    procedure KayitHatasiGoster(Hata: Exception);
    { agac }
    procedure OgeBagla(Dugme: TTreeNode; Ikon: Integer; Tur: TAgacTuru;
      const BaglantiAd, Ad: string; DalNo: Integer);
    function OgeAl(Dugme: TTreeNode): TAgacOgesi;
    function KlasorDugmesiEkle(const Ad: string): TTreeNode;
    function BaglantiDugmesiEkle(Ust: TTreeNode; const Ad: string): TTreeNode;
    function KlasorDugmesiBul(const Ad: string): TTreeNode;
    function BaglantiDugmesineCik(Dugme: TTreeNode): TTreeNode;
    function SeciliBaglantiDugmesi: TTreeNode;
    procedure AgaciKur;
    procedure DallariDoldur(Dugme: TTreeNode; Bag: TAcikBaglanti);
    procedure DalDoldur(Dal: TTreeNode; Ikon: Integer; Liste: TStrings);
    procedure AgacYazilariniYenile;
    { baglanti islemleri }
    procedure BaglantiyiAc(Dugme: TTreeNode);
    procedure BaglantiyiKapat(Dugme: TTreeNode);
    procedure AgaciYenile(Dugme: TTreeNode);
    procedure YeniBaglanti;
    procedure BaglantiyiDuzenle(Dugme: TTreeNode);
    procedure KayittanKaldir(Dugme: TTreeNode);
    { klasor islemleri }
    procedure YeniKlasor;
    procedure KlasoruYenidenAdlandir(Dugme: TTreeNode);
    procedure KlasoruKaldir(Dugme: TTreeNode);
    { sekmeler }
    function SekmeAl(Sayfa: TTabSheet): TTabloSekme;
    procedure BaglantiSekmeleriniKapat(const BaglantiAd: string);
    procedure TabloAc(Dugme: TTreeNode);
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
var
  Uyari: string;
begin
  FOgeler := TObjectList<TAgacOgesi>.Create(True);
  DilYukle(SonKullanilanDil);
  IkonlariYukle(icIkonlar, vilIkonlar);
  DilListesiniDoldur;
  AgaciKur;
  YazilariYenile;
  { Kayitli baglanti dosyasi bozuksa silinmeden yanina tasinmistir, kullanici bilgilendirilir. }
  Uyari := BozukDosyaUyarisiAl;
  if Uyari <> '' then
    UyariGoster(Uyari);
end;

procedure TfrmAna.FormDestroy(Sender: TObject);
begin
  FOgeler.Free;
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
  Sekme: TTabloSekme;
begin
  Caption := T('APP_BASLIK');
  btnYeniBaglanti.Caption := T('BTN_YENI_BAGLANTI');
  btnBaglan.Caption := T('BTN_BAGLAN');
  btnKes.Caption := T('BTN_KES');
  btnYenile.Caption := T('BTN_YENILE');
  btnYeniKlasor.Caption := T('BTN_YENI_KLASOR');
  miAc.Caption := T('MENU_AC');
  miBaglan.Caption := T('BTN_BAGLAN');
  miKes.Caption := T('BTN_KES');
  miYenile.Caption := T('MENU_YENILE');
  miDuzenle.Caption := T('MENU_DUZENLE');
  miKaldir.Caption := T('MENU_KAYITTAN_KALDIR');
  miKlasorAdi.Caption := T('MENU_KLASOR_ADLANDIR');
  miKlasorKaldir.Caption := T('MENU_KLASOR_KALDIR');
  miYeniKlasor.Caption := T('BTN_YENI_KLASOR');
  miSekmeKapat.Caption := T('MENU_SEKME_KAPAT');
  cmbDil.Hint := T('LBL_DIL');
  AgacYazilariniYenile;
  for i := 0 to pcCalisma.PageCount - 1 do
  begin
    Sekme := SekmeAl(pcCalisma.Pages[i]);
    if Sekme <> nil then
      Sekme.YazilariYenile;
  end;
  DurumuGuncelle;
end;

{ Durum cubugu ve dugmeler: agacta secili baglantiya gore. }
procedure TfrmAna.DurumuGuncelle;
var
  Dugme: TTreeNode;
  Ad: string;
  Bag: TAcikBaglanti;
begin
  Dugme := SeciliBaglantiDugmesi;
  Bag := nil;
  Ad := '';
  if Dugme <> nil then
  begin
    Ad := OgeAl(Dugme).BaglantiAd;
    Bag := FbAcikBaglanti(Ad);
  end;
  if Dugme = nil then
  begin
    stbDurum.Panels[0].Text := T('DURUM_SECIM_YOK');
    stbDurum.Panels[1].Text := '';
    stbDurum.Panels[2].Text := '';
  end
  else if Bag = nil then
  begin
    stbDurum.Panels[0].Text := Ad;
    stbDurum.Panels[1].Text := '';
    stbDurum.Panels[2].Text := T('DURUM_BAGLI_DEGIL');
  end
  else
  begin
    stbDurum.Panels[0].Text := TF('DURUM_BAGLI', [Ad]);
    stbDurum.Panels[1].Text := TF('DURUM_SURUM', [Bag.Surum]);
    if FbIslemAcikMi(Bag) then
      stbDurum.Panels[2].Text := T('DURUM_ISLEM_ACIK')
    else
      stbDurum.Panels[2].Text := T('DURUM_ISLEM_KAPALI');
  end;
  btnBaglan.Enabled := (Dugme <> nil) and (Bag = nil);
  btnKes.Enabled := Bag <> nil;
  btnYenile.Enabled := Bag <> nil;
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

{ Kayit dosyasi islemlerinde hata: kural hatasi (ayni ad vb.) oldugu gibi, digerleri ayrintili. }
procedure TfrmAna.KayitHatasiGoster(Hata: Exception);
begin
  if Hata is EKayitKurali then
    UyariGoster(Hata.Message)
  else
    HataYaz(T('ERR_KAYDEDILEMEDI'), Hata.Message);
end;

{ ---------- Agac: dugum yardimcilari ---------- }

procedure TfrmAna.OgeBagla(Dugme: TTreeNode; Ikon: Integer; Tur: TAgacTuru;
  const BaglantiAd, Ad: string; DalNo: Integer);
var
  Oge: TAgacOgesi;
begin
  Oge := TAgacOgesi.Create;
  Oge.Tur := Tur;
  Oge.BaglantiAd := BaglantiAd;
  Oge.Ad := Ad;
  Oge.DalNo := DalNo;
  FOgeler.Add(Oge);
  Dugme.Data := Oge;
  Dugme.ImageIndex := Ikon;
  Dugme.SelectedIndex := Ikon;
end;

function TfrmAna.OgeAl(Dugme: TTreeNode): TAgacOgesi;
begin
  if Dugme = nil then
    Result := nil
  else
    Result := TAgacOgesi(Dugme.Data);
end;

{ Yeni klasor, kokteki ilk baglantinin onune konur (klasorler ustte durur). }
function TfrmAna.KlasorDugmesiEkle(const Ad: string): TTreeNode;
var
  Dugme: TTreeNode;
begin
  Dugme := tvNesneler.Items.GetFirstNode;
  while (Dugme <> nil) and (OgeAl(Dugme).Tur <> atBaglanti) do
    Dugme := Dugme.GetNextSibling;
  if Dugme = nil then
    Result := tvNesneler.Items.Add(nil, Ad)
  else
    Result := tvNesneler.Items.Insert(Dugme, Ad);
  OgeBagla(Result, IKON_KLASOR, atKlasor, '', Ad, 0);
end;

{ Ust nil ise baglanti kok duzeye eklenir. Kapali baglanti "fisi cekilmis" ikonuyla gorunur. }
function TfrmAna.BaglantiDugmesiEkle(Ust: TTreeNode; const Ad: string): TTreeNode;
begin
  Result := tvNesneler.Items.AddChild(Ust, Ad);
  OgeBagla(Result, IKON_KES, atBaglanti, Ad, '', 0);
end;

function TfrmAna.KlasorDugmesiBul(const Ad: string): TTreeNode;
begin
  Result := tvNesneler.Items.GetFirstNode;
  while Result <> nil do
  begin
    if (OgeAl(Result).Tur = atKlasor) and SameText(OgeAl(Result).Ad, Ad) then
      Exit;
    Result := Result.GetNextSibling;
  end;
end;

{ Dugum bir baglantinin parcasi ise (kendisi, dali, nesnesi) baglanti dugumunu verir. }
function TfrmAna.BaglantiDugmesineCik(Dugme: TTreeNode): TTreeNode;
begin
  Result := Dugme;
  while Result <> nil do
  begin
    { Dugum olusturulurken (Data henuz bagli degilken) agac OnChange tetikleyebilir. }
    if OgeAl(Result) = nil then
      Exit(nil);
    if OgeAl(Result).Tur = atBaglanti then
      Exit;
    if OgeAl(Result).Tur = atKlasor then
      Exit(nil);
    Result := Result.Parent;
  end;
end;

function TfrmAna.SeciliBaglantiDugmesi: TTreeNode;
begin
  Result := BaglantiDugmesineCik(tvNesneler.Selected);
end;

{ ---------- Agac: doldurma ---------- }

{ Programi acarken: kayitli klasorler ve baglantilar. Hicbir baglanti bagli degildir. }
procedure TfrmAna.AgaciKur;
var
  Klasor: string;
  Tanim: TBaglantiTanimi;
  Ust: TTreeNode;
begin
  tvNesneler.Items.BeginUpdate;
  try
    tvNesneler.Items.Clear;
    FOgeler.Clear;
    FSurukleNode := nil;
    for Klasor in KayitliKlasorler do
      KlasorDugmesiEkle(Klasor);
    for Tanim in KayitliBaglantilar do
    begin
      Ust := nil;
      if Tanim.Klasor <> '' then
        Ust := KlasorDugmesiBul(Tanim.Klasor);
      BaglantiDugmesiEkle(Ust, Tanim.Ad);
    end;
    tvNesneler.FullExpand;
  finally
    tvNesneler.Items.EndUpdate;
  end;
end;

procedure TfrmAna.DalDoldur(Dal: TTreeNode; Ikon: Integer; Liste: TStrings);
var
  Ad: string;
  Dugme: TTreeNode;
begin
  for Ad in Liste do
  begin
    Dugme := tvNesneler.Items.AddChild(Dal, Ad);
    OgeBagla(Dugme, Ikon, atNesne, OgeAl(Dal).BaglantiAd, Ad, OgeAl(Dal).DalNo);
  end;
end;

{ Baglantinin altindaki dort dali sunucudan okuyup yeniden doldurur. }
procedure TfrmAna.DallariDoldur(Dugme: TTreeNode; Bag: TAcikBaglanti);
var
  Liste: TStringList;
  Dallar: array[0..3] of TTreeNode;
  i: Integer;
begin
  Liste := TStringList.Create;
  tvNesneler.Items.BeginUpdate;
  try
    Dugme.DeleteChildren;
    for i := 0 to 3 do
    begin
      Dallar[i] := tvNesneler.Items.AddChild(Dugme, '');
      OgeBagla(Dallar[i], IKON_KLASOR, atDal, Bag.Tanim.Ad, '', i);
    end;
    TablolariGetir(Bag, Liste);
    DalDoldur(Dallar[DAL_TABLO], IKON_TABLO, Liste);
    ViewlariGetir(Bag, Liste);
    DalDoldur(Dallar[DAL_VIEW], IKON_VIEW, Liste);
    ProsedurleriGetir(Bag, Liste);
    DalDoldur(Dallar[DAL_PROSEDUR], IKON_PROSEDUR, Liste);
    GeneratorleriGetir(Bag, Liste);
    DalDoldur(Dallar[DAL_GENERATOR], IKON_GENERATOR, Liste);
    Dugme.Expand(False);
    Dallar[DAL_TABLO].Expand(False);
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
  Dugme: TTreeNode;
begin
  for i := 0 to tvNesneler.Items.Count - 1 do
  begin
    Dugme := tvNesneler.Items[i];
    if (OgeAl(Dugme) <> nil) and (OgeAl(Dugme).Tur = atDal) then
      Dugme.Text := T(ANAHTARLAR[OgeAl(Dugme).DalNo]) + ' (' + IntToStr(Dugme.Count) + ')';
  end;
end;

{ ---------- Baglanti islemleri ---------- }

{ Kayitli baglantiya baglanir. Sifre kayitli degilse sorar (sifre kaydedilmez). }
procedure TfrmAna.BaglantiyiAc(Dugme: TTreeNode);
var
  Ad, Sifre: string;
  Tanim: TBaglantiTanimi;
  Bag: TAcikBaglanti;
begin
  Ad := OgeAl(Dugme).BaglantiAd;
  if FbAcikBaglanti(Ad) <> nil then
    Exit;
  if not KayitliBaglantiBul(Ad, Tanim) then
  begin
    HataYaz(TF('ERR_KAYIT_YOK', [Ad]), '');
    Exit;
  end;
  if Tanim.Sifre = '' then
  begin
    Sifre := '';
    if not MetinSor(T('SIFRE_BASLIK'), TF('SIFRE_ISTEK', [Ad]), Sifre, True) then
      Exit;
    Tanim.Sifre := Sifre;
  end;
  Screen.Cursor := crHourGlass;
  try
    try
      Bag := FbBaglan(Tanim);
    except
      on E: Exception do
      begin
        HataYaz(TF('ERR_BAGLANTI_ACILAMADI', [Ad]) + ' ' + HataMetniniCevir(E), E.Message);
        Exit;
      end;
    end;
    Dugme.ImageIndex := IKON_VERITABANI;
    Dugme.SelectedIndex := IKON_VERITABANI;
    try
      DallariDoldur(Dugme, Bag);
    except
      on E: Exception do
        HataYaz(HataMetniniCevir(E), E.Message);
    end;
  finally
    Screen.Cursor := crDefault;
  end;
  MesajYaz(TF('MSG_BAGLANDI', [Ad, Bag.Surum]));
  DurumuGuncelle;
end;

{ Once baglantiya ait sekmeler kapanir, sonra baglanti kesilir. }
procedure TfrmAna.BaglantiyiKapat(Dugme: TTreeNode);
var
  Ad: string;
begin
  Ad := OgeAl(Dugme).BaglantiAd;
  BaglantiSekmeleriniKapat(Ad);
  FbBaglantiyiKes(FbAcikBaglanti(Ad));
  Dugme.DeleteChildren;
  Dugme.ImageIndex := IKON_KES;
  Dugme.SelectedIndex := IKON_KES;
end;

procedure TfrmAna.AgaciYenile(Dugme: TTreeNode);
var
  Bag: TAcikBaglanti;
begin
  Bag := FbAcikBaglanti(OgeAl(Dugme).BaglantiAd);
  if Bag = nil then
    Exit;
  try
    DallariDoldur(Dugme, Bag);
    MesajYaz(TF('MSG_AGAC_YENILENDI', [Bag.Tanim.Ad]));
  except
    on E: Exception do
      HataYaz(HataMetniniCevir(E), E.Message);
  end;
  DurumuGuncelle;
end;

procedure TfrmAna.YeniBaglanti;
var
  Ad: string;
  Dugme: TTreeNode;
begin
  case BaglantiPenceresiniGoster('', Ad) of
    bsKaydedildi:
      Dugme := BaglantiDugmesiEkle(nil, Ad);
    bsBaglandi:
      begin
        Dugme := BaglantiDugmesiEkle(nil, Ad);
        Dugme.ImageIndex := IKON_VERITABANI;
        Dugme.SelectedIndex := IKON_VERITABANI;
        try
          DallariDoldur(Dugme, FbAcikBaglanti(Ad));
        except
          on E: Exception do
            HataYaz(HataMetniniCevir(E), E.Message);
        end;
        MesajYaz(TF('MSG_BAGLANDI', [Ad, FbAcikBaglanti(Ad).Surum]));
      end;
  else
    Exit;
  end;
  tvNesneler.Selected := Dugme;
  DurumuGuncelle;
end;

{ Acik baglanti duzenlenemez: once kesilecegi yazilir ve onay istenir. }
procedure TfrmAna.BaglantiyiDuzenle(Dugme: TTreeNode);
var
  Ad, YeniAd: string;
begin
  Ad := OgeAl(Dugme).BaglantiAd;
  if FbAcikBaglanti(Ad) <> nil then
  begin
    if not OnayIste(TF('ONAY_DUZENLE_KES', [Ad])) then
      Exit;
    BaglantiyiKapat(Dugme);
    MesajYaz(TF('MSG_KESILDI', [Ad]));
  end;
  if BaglantiPenceresiniGoster(Ad, YeniAd) = bsIptal then
  begin
    DurumuGuncelle;
    Exit;
  end;
  OgeAl(Dugme).BaglantiAd := YeniAd;
  Dugme.Text := YeniAd;
  if FbAcikBaglanti(YeniAd) <> nil then
  begin
    Dugme.ImageIndex := IKON_VERITABANI;
    Dugme.SelectedIndex := IKON_VERITABANI;
    try
      DallariDoldur(Dugme, FbAcikBaglanti(YeniAd));
    except
      on E: Exception do
        HataYaz(HataMetniniCevir(E), E.Message);
    end;
    MesajYaz(TF('MSG_BAGLANDI', [YeniAd, FbAcikBaglanti(YeniAd).Surum]));
  end;
  DurumuGuncelle;
end;

{ Baglantiyi agactan ve baglantilar.json'dan cikarir. Veritabanina dokunmaz. }
procedure TfrmAna.KayittanKaldir(Dugme: TTreeNode);
var
  Ad: string;
  Acik: Boolean;
begin
  Ad := OgeAl(Dugme).BaglantiAd;
  Acik := FbAcikBaglanti(Ad) <> nil;
  if Acik then
  begin
    if not OnayIste(TF('ONAY_KAYIT_KALDIR_ACIK', [Ad])) then
      Exit;
  end
  else if not OnayIste(TF('ONAY_KAYIT_KALDIR', [Ad])) then
    Exit;
  try
    BaglantiListedenKaldir(Ad);
  except
    on E: Exception do
    begin
      KayitHatasiGoster(E);
      Exit;
    end;
  end;
  if Acik then
    BaglantiyiKapat(Dugme);
  Dugme.Delete;
  MesajYaz(TF('MSG_KAYIT_KALDIRILDI', [Ad]));
  DurumuGuncelle;
end;

{ ---------- Klasor islemleri ---------- }

procedure TfrmAna.YeniKlasor;
var
  Ad: string;
begin
  Ad := '';
  if not MetinSor(T('KLASOR_YENI_BASLIK'), T('LBL_KLASOR_AD'), Ad, False) then
    Exit;
  try
    KlasorEkle(Ad);
  except
    on E: Exception do
    begin
      KayitHatasiGoster(E);
      Exit;
    end;
  end;
  tvNesneler.Selected := KlasorDugmesiEkle(Trim(Ad));
  DurumuGuncelle;
end;

procedure TfrmAna.KlasoruYenidenAdlandir(Dugme: TTreeNode);
var
  Ad: string;
begin
  Ad := OgeAl(Dugme).Ad;
  if not MetinSor(T('KLASOR_ADLANDIR_BASLIK'), T('LBL_KLASOR_AD'), Ad, False) then
    Exit;
  try
    KlasorYenidenAdlandir(OgeAl(Dugme).Ad, Ad);
  except
    on E: Exception do
    begin
      KayitHatasiGoster(E);
      Exit;
    end;
  end;
  OgeAl(Dugme).Ad := Trim(Ad);
  Dugme.Text := Trim(Ad);
end;

{ Klasor kalkar, icindeki baglantilar silinmez, kok duzeye cikar. }
procedure TfrmAna.KlasoruKaldir(Dugme: TTreeNode);
var
  Ad: string;
begin
  Ad := OgeAl(Dugme).Ad;
  if not OnayIste(TF('ONAY_KLASOR_KALDIR', [Ad])) then
    Exit;
  try
    KlasorKaldir(Ad);
  except
    on E: Exception do
    begin
      KayitHatasiGoster(E);
      Exit;
    end;
  end;
  while Dugme.Count > 0 do
    Dugme.GetFirstChild.MoveTo(nil, naAdd);
  Dugme.Delete;
  MesajYaz(TF('MSG_KLASOR_KALDIRILDI', [Ad]));
  DurumuGuncelle;
end;

{ ---------- Sekmeler ---------- }

function TfrmAna.SekmeAl(Sayfa: TTabSheet): TTabloSekme;
begin
  Result := nil;
  if (Sayfa.ControlCount > 0) and (Sayfa.Controls[0] is TTabloSekme) then
    Result := TTabloSekme(Sayfa.Controls[0]);
end;

procedure TfrmAna.BaglantiSekmeleriniKapat(const BaglantiAd: string);
var
  i: Integer;
  Sekme: TTabloSekme;
begin
  for i := pcCalisma.PageCount - 1 downto 0 do
  begin
    Sekme := SekmeAl(pcCalisma.Pages[i]);
    if (Sekme <> nil) and SameText(Sekme.BaglantiAd, BaglantiAd) then
      pcCalisma.Pages[i].Free;
  end;
end;

{ Ayni tablo iki ayri baglantida ayri sekmelerde acilir; ayni baglantida tekrar acilirsa o sekmeye gecilir. }
procedure TfrmAna.TabloAc(Dugme: TTreeNode);
var
  Oge: TAgacOgesi;
  Bag: TAcikBaglanti;
  Sayfa: TTabSheet;
  Sekme: TTabloSekme;
  i: Integer;
begin
  Oge := OgeAl(Dugme);
  Bag := FbAcikBaglanti(Oge.BaglantiAd);
  if Bag = nil then
    Exit;
  for i := 0 to pcCalisma.PageCount - 1 do
  begin
    Sekme := SekmeAl(pcCalisma.Pages[i]);
    if (Sekme <> nil) and SameText(Sekme.BaglantiAd, Oge.BaglantiAd) and (Sekme.TabloAdi = Oge.Ad) then
    begin
      pcCalisma.ActivePage := pcCalisma.Pages[i];
      Exit;
    end;
  end;
  Sayfa := TTabSheet.Create(pcCalisma);
  Sayfa.PageControl := pcCalisma;
  Sayfa.Caption := Oge.Ad + ' [' + Oge.BaglantiAd + ']';
  Sayfa.ImageIndex := IKON_TABLO;
  Sekme := TTabloSekme.Create(Sayfa);
  Sekme.Parent := Sayfa;
  Sekme.Align := alClient;
  try
    Sekme.Yukle(Bag, Oge.Ad);
  except
    on E: Exception do
    begin
      Sayfa.Free;
      HataYaz(TF('ERR_TABLO_ACILAMADI', [Oge.Ad]) + ' ' + HataMetniniCevir(E), E.Message);
      Exit;
    end;
  end;
  pcCalisma.ActivePage := Sayfa;
  MesajYaz(TF('MSG_TABLO_ACILDI', [Oge.Ad, Oge.BaglantiAd, ILK_SATIR_SAYISI]));
  DurumuGuncelle;
end;

{ ---------- Dugme ve menu olaylari ---------- }

procedure TfrmAna.btnYeniBaglantiClick(Sender: TObject);
begin
  YeniBaglanti;
end;

procedure TfrmAna.btnBaglanClick(Sender: TObject);
begin
  if SeciliBaglantiDugmesi <> nil then
    BaglantiyiAc(SeciliBaglantiDugmesi);
end;

procedure TfrmAna.btnKesClick(Sender: TObject);
var
  Dugme: TTreeNode;
begin
  Dugme := SeciliBaglantiDugmesi;
  if Dugme = nil then
    Exit;
  BaglantiyiKapat(Dugme);
  MesajYaz(TF('MSG_KESILDI', [OgeAl(Dugme).BaglantiAd]));
  DurumuGuncelle;
end;

procedure TfrmAna.btnYenileClick(Sender: TObject);
begin
  if SeciliBaglantiDugmesi <> nil then
    AgaciYenile(SeciliBaglantiDugmesi);
end;

procedure TfrmAna.btnYeniKlasorClick(Sender: TObject);
begin
  YeniKlasor;
end;

procedure TfrmAna.cmbDilChange(Sender: TObject);
begin
  if cmbDil.ItemIndex < 0 then
    Exit;
  DilYukle(FDilKodlari[cmbDil.ItemIndex]);
  SonKullanilanDiliKaydet;
  YazilariYenile;
end;

procedure TfrmAna.tvNesnelerChange(Sender: TObject; Node: TTreeNode);
begin
  DurumuGuncelle;
end;

{ Cift tik: kapali baglantiya baglanir, tabloyu acar. }
procedure TfrmAna.tvNesnelerDblClick(Sender: TObject);
var
  Nokta: TPoint;
  Dugme: TTreeNode;
begin
  Nokta := tvNesneler.ScreenToClient(Mouse.CursorPos);
  Dugme := tvNesneler.GetNodeAt(Nokta.X, Nokta.Y);
  if Dugme = nil then
    Exit;
  if (OgeAl(Dugme).Tur = atBaglanti) and (FbAcikBaglanti(OgeAl(Dugme).BaglantiAd) = nil) then
    BaglantiyiAc(Dugme)
  else if (OgeAl(Dugme).Tur = atNesne) and (OgeAl(Dugme).DalNo = DAL_TABLO) then
    TabloAc(Dugme);
end;

{ Sol dugmeyle bir baglantinin ustune basip surukleyince surukleme baslar. }
procedure TfrmAna.tvNesnelerMouseDown(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
var
  Dugme: TTreeNode;
begin
  if Button <> mbLeft then
    Exit;
  Dugme := tvNesneler.GetNodeAt(X, Y);
  if (Dugme <> nil) and (OgeAl(Dugme).Tur = atBaglanti) then
  begin
    FSurukleNode := Dugme;
    tvNesneler.BeginDrag(False, 5);
  end;
end;

{ Baglanti bir klasorun ustune birakilabilir. Bos alana birakilirsa kok duzeye cikar. }
procedure TfrmAna.tvNesnelerDragOver(Sender, Source: TObject; X, Y: Integer;
  State: TDragState; var Accept: Boolean);
var
  Hedef: TTreeNode;
begin
  Accept := False;
  if (Source <> tvNesneler) or (FSurukleNode = nil) then
    Exit;
  Hedef := tvNesneler.GetNodeAt(X, Y);
  if Hedef = nil then
    Accept := FSurukleNode.Parent <> nil
  else
    Accept := (OgeAl(Hedef).Tur = atKlasor) and (FSurukleNode.Parent <> Hedef);
end;

procedure TfrmAna.tvNesnelerDragDrop(Sender, Source: TObject; X, Y: Integer);
var
  Hedef: TTreeNode;
  KlasorAdi: string;
begin
  if FSurukleNode = nil then
    Exit;
  Hedef := tvNesneler.GetNodeAt(X, Y);
  KlasorAdi := '';
  if Hedef <> nil then
    KlasorAdi := OgeAl(Hedef).Ad;
  try
    BaglantiKlasoruAyarla(OgeAl(FSurukleNode).BaglantiAd, KlasorAdi);
  except
    on E: Exception do
    begin
      KayitHatasiGoster(E);
      FSurukleNode := nil;
      Exit;
    end;
  end;
  if Hedef = nil then
    FSurukleNode.MoveTo(nil, naAdd)
  else
  begin
    FSurukleNode.MoveTo(Hedef, naAddChild);
    Hedef.Expand(False);
  end;
  FSurukleNode := nil;
end;

{ Sag tik menusu: tiklanan dugume gore sadece ilgili maddeler gorunur. }
procedure TfrmAna.pmNesnePopup(Sender: TObject);
var
  Nokta: TPoint;
  Dugme: TTreeNode;
  Tur: TAgacTuru;
  Bos, Acik: Boolean;
begin
  Nokta := tvNesneler.ScreenToClient(Mouse.CursorPos);
  if PtInRect(tvNesneler.ClientRect, Nokta) then
    Dugme := tvNesneler.GetNodeAt(Nokta.X, Nokta.Y)
  else
    Dugme := tvNesneler.Selected;
  Bos := Dugme = nil;
  Tur := atKlasor;
  Acik := False;
  if not Bos then
  begin
    tvNesneler.Selected := Dugme;
    Tur := OgeAl(Dugme).Tur;
    if Tur <> atKlasor then
      Acik := FbAcikBaglanti(OgeAl(Dugme).BaglantiAd) <> nil;
  end;
  miYeniKlasor.Visible := Bos;
  miKlasorAdi.Visible := (not Bos) and (Tur = atKlasor);
  miKlasorKaldir.Visible := (not Bos) and (Tur = atKlasor);
  miBaglan.Visible := (not Bos) and (Tur = atBaglanti);
  miKes.Visible := (not Bos) and (Tur = atBaglanti);
  miDuzenle.Visible := (not Bos) and (Tur = atBaglanti);
  miKaldir.Visible := (not Bos) and (Tur = atBaglanti);
  miAc.Visible := (not Bos) and (Tur = atNesne) and (OgeAl(Dugme).DalNo = DAL_TABLO);
  miYenile.Visible := (not Bos) and (Tur <> atKlasor) and Acik;
  miBaglan.Enabled := not Acik;
  miKes.Enabled := Acik;
end;

procedure TfrmAna.miAcClick(Sender: TObject);
begin
  if tvNesneler.Selected <> nil then
    TabloAc(tvNesneler.Selected);
end;

procedure TfrmAna.miBaglanClick(Sender: TObject);
begin
  if SeciliBaglantiDugmesi <> nil then
    BaglantiyiAc(SeciliBaglantiDugmesi);
end;

procedure TfrmAna.miKesClick(Sender: TObject);
var
  Dugme: TTreeNode;
begin
  Dugme := SeciliBaglantiDugmesi;
  if Dugme = nil then
    Exit;
  BaglantiyiKapat(Dugme);
  MesajYaz(TF('MSG_KESILDI', [OgeAl(Dugme).BaglantiAd]));
  DurumuGuncelle;
end;

procedure TfrmAna.miYenileClick(Sender: TObject);
begin
  if SeciliBaglantiDugmesi <> nil then
    AgaciYenile(SeciliBaglantiDugmesi);
end;

procedure TfrmAna.miDuzenleClick(Sender: TObject);
begin
  if SeciliBaglantiDugmesi <> nil then
    BaglantiyiDuzenle(SeciliBaglantiDugmesi);
end;

procedure TfrmAna.miKaldirClick(Sender: TObject);
begin
  if SeciliBaglantiDugmesi <> nil then
    KayittanKaldir(SeciliBaglantiDugmesi);
end;

procedure TfrmAna.miKlasorAdiClick(Sender: TObject);
begin
  if (tvNesneler.Selected <> nil) and (OgeAl(tvNesneler.Selected).Tur = atKlasor) then
    KlasoruYenidenAdlandir(tvNesneler.Selected);
end;

procedure TfrmAna.miKlasorKaldirClick(Sender: TObject);
begin
  if (tvNesneler.Selected <> nil) and (OgeAl(tvNesneler.Selected).Tur = atKlasor) then
    KlasoruKaldir(tvNesneler.Selected);
end;

procedure TfrmAna.miYeniKlasorClick(Sender: TObject);
begin
  YeniKlasor;
end;

procedure TfrmAna.miSekmeKapatClick(Sender: TObject);
begin
  if pcCalisma.ActivePage <> nil then
    pcCalisma.ActivePage.Free;
  DurumuGuncelle;
end;

end.
