{ fAna.pas - Ana form: sol agac, sag sekmeler, alt sonuc alani, ust arac cubugu.
  Form sadece arayuzu bilir; is uBaglanti, uMetadata, uSorgu unit'lerindedir.

  Agac: kokte klasorler ve kayitli baglantilar durur. Baglanti acilinca altinda yedi dal (Tablolar, View'lar,
  Prosedurler, Trigger'lar, Domain'ler, Exception'lar, Generator'lar) dolar. Birden fazla
  baglanti ayni anda acik olabilir. Her agac dugumunun Data alani bir
  TAgacOgesi'ni gosterir; dugumun ne oldugu orada yazar. }
unit fAna;

interface

uses
  Winapi.Windows, System.SysUtils, System.Classes, System.Generics.Collections,
  Vcl.Controls, Vcl.Graphics, Vcl.Forms, Vcl.ComCtrls, Vcl.ExtCtrls, Vcl.StdCtrls,
  Vcl.Menus, Vcl.ImgList, Vcl.VirtualImageList, Vcl.BaseImageCollection,
  Vcl.ImageCollection,
  uDil, uIkon, uSerit, uOnay, uBaglanti, uMetadata, uSorgu, uDDL, fBaglanti, fMetinSor, fMetadataCikar, fYedek,
  fTabloSekme, fSorguSekme, fKullanicilar, fProsedurSekme, fGeneratorDeger, uProsedur, uNesneYonet, uYetki, fYetkiler, fCokluSorgu, fTopluGuncelle, fTabloListe, fSemaFark, fHakkinda, uYonetici, fTabloKopya, fAktifBaglanti, fTabloTasarim, fBakim, uKlonla, uYedek, fIlerleme, fIndeksOner, uAra, fAra;

type
  TAgacTuru = (atKlasor, atBaglanti, atDal, atNesne);

  { Agac dugumunun kimligi. BaglantiAd: dugumun ait oldugu kayitli baglanti
    (klasorde bos). Ad: klasor adi veya nesne adi. DalNo: dal ve nesne icin. }
  TAgacOgesi = class
    Tur: TAgacTuru;
    BaglantiAd: string;
    Ad: string;
    DalNo: Integer;
    { Yalniz tetikleyici nesnesinde: pasif ise agacta soluk cizilir; DDL tetikleyicisinde script/duzenleme yok. }
    Pasif: Boolean;
    Duzenlenemez: Boolean;
  end;

  TfrmAna = class(TForm)
    pnlUst: TPanel;
    pnlDil: TPanel;
    cmbDil: TComboBox;
    btnYonetici: TButton;
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
    miBagimliliklar: TMenuItem;
    miYetkiler: TMenuItem;
    miScriptUret: TMenuItem;
    miNesneDuzenle: TMenuItem;
    miYeniTabloTasarim: TMenuItem;
    miYeniNesne: TMenuItem;
    miDomVarsayilan: TMenuItem;
    miDomKontrol: TMenuItem;
    miDomAd: TMenuItem;
    miGenDeger: TMenuItem;
    miTabloKopyala: TMenuItem;
    miTabloBosalt: TMenuItem;
    miNesneSil: TMenuItem;
    miBaglan: TMenuItem;
    miKes: TMenuItem;
    miYenile: TMenuItem;
    miDuzenle: TMenuItem;
    miKaldir: TMenuItem;
    miMetadataCikar: TMenuItem;
    miYedek: TMenuItem;
    miKlonla: TMenuItem;
    miVeritabaniKopyala: TMenuItem;
    miKlasorAdi: TMenuItem;
    miKlasorKaldir: TMenuItem;
    miYeniKlasor: TMenuItem;
    pmSekme: TPopupMenu;
    miSekmeKapat: TMenuItem;
    miSekmeYenile: TMenuItem;
    miTumSekmeleriKapat: TMenuItem;
    procedure FormCreate(Sender: TObject);
    procedure FormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure pcCalismaChange(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure btnYeniBaglantiClick(Sender: TObject);
    procedure btnKlonlaClick(Sender: TObject);
    procedure btnBaglanClick(Sender: TObject);
    procedure btnYeniSorguClick(Sender: TObject);
    procedure btnCokluSorguClick(Sender: TObject);
    procedure btnTopluGuncelleClick(Sender: TObject);
    procedure btnSemaFarkiClick(Sender: TObject);
    procedure btnCalistirClick(Sender: TObject);
    procedure btnPlanClick(Sender: TObject);
    procedure btnIndeksOnerClick(Sender: TObject);
    procedure btnGecmisClick(Sender: TObject);
    procedure btnMetadataClick(Sender: TObject);
    procedure btnYedekClick(Sender: TObject);
    procedure btnKullanicilarClick(Sender: TObject);
    procedure btnAktifBaglantiClick(Sender: TObject);
    procedure btnBakimClick(Sender: TObject);
    procedure btnAraClick(Sender: TObject);
    procedure btnYenileClick(Sender: TObject);
    procedure cmbDilChange(Sender: TObject);
    procedure btnYoneticiClick(Sender: TObject);
    procedure tvNesnelerChange(Sender: TObject; Node: TTreeNode);
    procedure tvNesnelerCustomDrawItem(Sender: TCustomTreeView; Node: TTreeNode; State: TCustomDrawState;
      var DefaultDraw: Boolean);
    procedure tvNesnelerDblClick(Sender: TObject);
    procedure tvNesnelerMouseDown(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure tvNesnelerDragOver(Sender, Source: TObject; X, Y: Integer;
      State: TDragState; var Accept: Boolean);
    procedure tvNesnelerDragDrop(Sender, Source: TObject; X, Y: Integer);
    procedure pmNesnePopup(Sender: TObject);
    procedure miAcClick(Sender: TObject);
    procedure miBagimliliklarClick(Sender: TObject);
    procedure miYetkilerClick(Sender: TObject);
    procedure miScriptUretClick(Sender: TObject);
    procedure miNesneDuzenleClick(Sender: TObject);
    procedure miYeniNesneClick(Sender: TObject);
    procedure miYeniTabloTasarimClick(Sender: TObject);
    procedure miDomVarsayilanClick(Sender: TObject);
    procedure miDomKontrolClick(Sender: TObject);
    procedure miDomAdClick(Sender: TObject);
    procedure miGenDegerClick(Sender: TObject);
    procedure miNesneSilClick(Sender: TObject);
    procedure miTabloBosaltClick(Sender: TObject);
    procedure miTabloKopyalaClick(Sender: TObject);
    procedure miBaglanClick(Sender: TObject);
    procedure miKesClick(Sender: TObject);
    procedure miYenileClick(Sender: TObject);
    procedure miDuzenleClick(Sender: TObject);
    procedure miKaldirClick(Sender: TObject);
    procedure miMetadataCikarClick(Sender: TObject);
    procedure miYedekClick(Sender: TObject);
    procedure miVeritabaniKopyalaClick(Sender: TObject);
    procedure miKlasorAdiClick(Sender: TObject);
    procedure miKlasorKaldirClick(Sender: TObject);
    procedure miYeniKlasorClick(Sender: TObject);
    procedure miSekmeKapatClick(Sender: TObject);
    procedure miSekmeYenileClick(Sender: TObject);
    procedure miTumSekmeleriKapatClick(Sender: TObject);
    procedure pmSekmePopup(Sender: TObject);
    procedure tvNesnelerMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
    procedure pcCalismaMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
    procedure btnAyrintiClick(Sender: TObject);
    procedure btnTumKapatClick(Sender: TObject);
  private
    icSerit: TImageCollection;
    FSerit: TSerit;
    btnYeniBaglanti: TSeritDugmesi;
    btnKlonla: TSeritDugmesi;
    btnBaglan: TSeritDugmesi;
    btnYenile: TSeritDugmesi;
    btnYeniSorgu: TSeritDugmesi;
    btnCokluSorgu: TSeritDugmesi;
    btnTopluGuncelle: TSeritDugmesi;
    btnSemaFarki: TSeritDugmesi;
    btnAyrinti: TSeritDugmesi;
    btnTumKapat: TSeritDugmesi;
    btnCalistir: TSeritDugmesi;
    btnPlan: TSeritDugmesi;
    btnIndeksOner: TSeritDugmesi;
    btnGecmis: TSeritDugmesi;
    btnMetadata: TSeritDugmesi;
    btnYedek: TSeritDugmesi;
    btnKullanicilar: TSeritDugmesi;
    btnAktifBaglanti: TSeritDugmesi;
    btnBakim: TSeritDugmesi;
    btnAra: TSeritDugmesi;
    FDilKodlari: TArray<string>;
    FOgeler: TObjectList<TAgacOgesi>;
    FSurukleNode: TTreeNode;
    { Fare hangi agac dugumunun ustunde (yol ipucu yalniz dugum degisince guncellenir). }
    FHintDugum: TTreeNode;
    { Gorunum sekmesi: tablo listesi sekmelerinde alan ayrintisi acik mi (yeni sekmeler de buna gore acilir). }
    FAyrintiAcik: Boolean;
    FSorguNo: Integer;
    { Olusturma isi biten "Yeni" sekmesi: sekmenin kendi olayinin icinde silinmez, kuyruktan kapatilir. }
    FKapatilacakSayfa: TTabSheet;
    procedure SeritKur;
    procedure YazilariYenile;
    procedure DilListesiniDoldur;
    procedure DurumuGuncelle;
    procedure MesajYaz(const Metin: string);
    procedure SqlMesajiYaz(const Komutlar: TArray<string>);
    procedure HataYaz(const Mesaj: string; const HamMesaj: string);
    procedure KayitHatasiGoster(Hata: Exception);
    { agac }
    procedure OgeBagla(Dugme: TTreeNode; Ikon: Integer; Tur: TAgacTuru;
      const BaglantiAd, Ad: string; DalNo: Integer);
    function OgeAl(Dugme: TTreeNode): TAgacOgesi;
    function KlasorDugmesiEkle(const Ad: string; Ust: TTreeNode): TTreeNode;
    procedure DugumuTasi(Dugme, Ust: TTreeNode);
    function DugumAltindaMi(Dugme, Ata: TTreeNode): Boolean;
    function BaglantiDugmesiEkle(Ust: TTreeNode; const Ad: string): TTreeNode;
    function KlasorDugmesiBul(const Ad: string): TTreeNode;
    function BaglantiDugmesineCik(Dugme: TTreeNode): TTreeNode;
    function SeciliBaglantiDugmesi: TTreeNode;
    procedure AgaciKur;
    procedure DalIciniDoldur(Dal: TTreeNode; Bag: TAcikBaglanti);
    procedure DallariDoldur(Dugme: TTreeNode; Bag: TAcikBaglanti);
    procedure DalDoldur(Dal: TTreeNode; Ikon: Integer; Liste: TStrings);
    procedure TetikleyiciDaliDoldur(Dal: TTreeNode; const Liste: TArray<TTetikleyiciBilgisi>);
    procedure AgacYazilariniYenile;
    { baglanti islemleri }
    procedure BaglantiyiAc(Dugme: TTreeNode);
    procedure BaglantiyiKapat(Dugme: TTreeNode);
    procedure AgaciYenile(Dugme: TTreeNode);
    procedure TabloyuBosalt(Dugme: TTreeNode);
    procedure TabloyuTasarla(Dal: TTreeNode);
    procedure TabloyuKopyala(Dugme: TTreeNode);
    procedure BaglantiAgaciniYenile(const BaglantiAd: string);
    procedure YeniBaglanti(const KlonAd: string);
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
    function KullanicilarAl(Sayfa: TTabSheet): TKullanicilar;
    procedure KullanicilarAc(Dugme: TTreeNode);
    function SorguSekmeAl(Sayfa: TTabSheet): TSorguSekme;
    function AktifSorguSekmesi: TSorguSekme;
    function CokluSekmeAl(Sayfa: TTabSheet): TCokluSorguSekme;
    function AktifCokluSekme: TCokluSorguSekme;
    function TopluSekmeAl(Sayfa: TTabSheet): TTopluGuncelleSekme;
    function AktifTopluSekme: TTopluGuncelleSekme;
    procedure TopluGuncelleAc;
    function FarkSekmeAl(Sayfa: TTabSheet): TSemaFarkSekme;
    procedure SemaFarkiAc;
    function ListeSekmeAl(Sayfa: TTabSheet): TTabloListeSekme;
    procedure TabloListesiAc(Dugme: TTreeNode);
    procedure TabloSekmesiAc(const BaglantiAd, Tablo: string; const Filtre: string = '');
    procedure TumSekmeleriKapat;
    procedure AyrintiDugmesiniYaz;
    procedure CokluSorguAc;
    procedure SorguDurumuYaz(Sender: TObject);
    procedure SorguYapisiDegisti(Sender: TObject);
    procedure YeniSorgu(const Metin: string = '');
    procedure ScriptAc(Dugme: TTreeNode);
    function ProsedurSekmeAl(Sayfa: TTabSheet): TProsedurSekme;
    function AktifProsedurSekmesi: TProsedurSekme;
    procedure NesneDuzenleAc(Dugme: TTreeNode);
    procedure NesneDuzenleSekmesiAc(const BaglantiAd, Ad: string; Tur: TNesneTuru);
    procedure AramaSonucunuAc(const BaglantiAd: string; const Sonuc: TAramaSonucu);
    function DalTuru(DalNo: Integer): TNesneTuru;
    function DalDugmesiBul(const BaglantiAd: string; DalNo: Integer): TTreeNode;
    procedure DalYenile(Dal: TTreeNode);
    procedure YeniNesneAc(Dal: TTreeNode);
    procedure YeniNesneOlusturuldu(Sender: TObject);
    procedure SayfayiKapat;
    procedure NesneSekmeleriniKapat(const BaglantiAd: string; Tur: TNesneTuru; const Ad: string);
    procedure NesneyiSil(Dugme: TTreeNode);
    procedure DomainDegistirAc(Dugme: TTreeNode; Islem: TDomainIslemi);
    procedure GeneratorDegeriAc(Dugme: TTreeNode);
    procedure YeniGeneratorAc(Dal: TTreeNode);
    procedure MetadataCikarAc(Dugme: TTreeNode);
    procedure YedekPenceresiAc(Dugme: TTreeNode);
    procedure VeritabaniKopyala(Dugme: TTreeNode);
    procedure SorguyuCalistir;
    procedure PlaniGoster;
  end;

var
  frmAna: TfrmAna;

implementation

{$R *.dfm}


const
  DAL_TABLO = 0;
  DAL_VIEW = 1;
  DAL_PROSEDUR = 2;
  DAL_TETIKLEYICI = 3;
  DAL_DOMAIN = 4;
  DAL_ISTISNA = 5;
  DAL_GENERATOR = 6;
  DAL_SAYISI = 7;

procedure TfrmAna.FormCreate(Sender: TObject);
var
  Uyari: string;
begin
  FOgeler := TObjectList<TAgacOgesi>.Create(True);
  FAyrintiAcik := True;
  DilYukle(SonKullanilanDil);
  IkonlariYukle(icIkonlar, vilIkonlar);
  SeritKur;
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
  FSerit.Free;
  FOgeler.Free;
end;

{ Ustteki serit: gruplar ve dugmeler soldan saga bu siraya gore dizilir. Dugmenin
  yazisi ve ikonu uSerit'te, isi asagidaki btn...Click yordamlarindadir. }
procedure TfrmAna.SeritKur;
begin
  { Serit kendi ikon koleksiyonunu kullanir (agacinkine dokunmaz). }
  icSerit := TImageCollection.Create(Self);
  IkonlariKoleksiyonaYukle(icSerit);
  FSerit := TSerit.Create(pnlUst, icSerit, CurrentPPI);
  btnYeniBaglanti := FSerit.Ekle('GRUP_BAGLANTI', 'BTN_YENI_BAGLANTI', IKON_VERITABANI, btnYeniBaglantiClick);
  btnKlonla := FSerit.Ekle('GRUP_BAGLANTI', 'BTN_KLONLA', IKON_KLONLA, btnKlonlaClick);
  btnBaglan := FSerit.Ekle('GRUP_BAGLANTI', 'BTN_BAGLAN', IKON_BAGLAN, btnBaglanClick);
  btnYenile := FSerit.Ekle('GRUP_BAGLANTI', 'BTN_YENILE', IKON_YENILE, btnYenileClick);
  btnYeniSorgu := FSerit.Ekle('GRUP_SORGU', 'BTN_YENI_SORGU', IKON_SORGU, btnYeniSorguClick);
  btnCokluSorgu := FSerit.Ekle('GRUP_SORGU', 'BTN_COKLU_SORGU', IKON_VERITABANI, btnCokluSorguClick);
  btnTopluGuncelle := FSerit.Ekle('GRUP_SORGU', 'BTN_TOPLU_GUNCELLE', IKON_VERITABANI, btnTopluGuncelleClick);
  btnCalistir := FSerit.Ekle('GRUP_SORGU', 'BTN_CALISTIR', IKON_CALISTIR, btnCalistirClick);
  btnPlan := FSerit.Ekle('GRUP_SORGU', 'BTN_PLAN', IKON_PLAN, btnPlanClick);
  btnIndeksOner := FSerit.Ekle('GRUP_SORGU', 'BTN_INDEKS_ONER', IKON_PLAN, btnIndeksOnerClick);
  btnGecmis := FSerit.Ekle('GRUP_SORGU', 'BTN_GECMIS', IKON_SORGU, btnGecmisClick);
  btnMetadata := FSerit.Ekle('GRUP_YONETIM', 'MENU_METADATA_CIKAR', IKON_METADATA, btnMetadataClick);
  btnYedek := FSerit.Ekle('GRUP_YONETIM', 'MENU_YEDEK', IKON_YEDEK, btnYedekClick);
  btnKullanicilar := FSerit.Ekle('GRUP_YONETIM', 'BTN_KULLANICILAR', IKON_KULLANICI, btnKullanicilarClick);
  btnSemaFarki := FSerit.Ekle('GRUP_YONETIM', 'BTN_SEMA_FARKI', IKON_PLAN, btnSemaFarkiClick);
  btnAktifBaglanti := FSerit.Ekle('GRUP_YONETIM', 'BTN_AKTIF_BAGLANTI', IKON_VERITABANI, btnAktifBaglantiClick);
  btnBakim := FSerit.Ekle('GRUP_YONETIM', 'BTN_BAKIM', IKON_VERITABANI, btnBakimClick);
  btnAra := FSerit.Ekle('GRUP_YONETIM', 'BTN_ARA', IKON_PLAN, btnAraClick);
  btnKullanicilar.ShowHint := True;
  btnAyrinti := FSerit.Ekle('GRUP_GORUNUM', 'BTN_AYRINTI_KAPAT', IKON_VIEW, btnAyrintiClick);
  btnTumKapat := FSerit.Ekle('GRUP_GORUNUM', 'BTN_TUM_KAPAT', IKON_KAPAT, btnTumKapatClick);
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
  SorguSekme: TSorguSekme;
  KullaniciSekme: TKullanicilar;
  ProsedurSekme: TProsedurSekme;
  CokluSekme: TCokluSorguSekme;
  FarkSekme: TSemaFarkSekme;
  TopluSekme: TTopluGuncelleSekme;
  ListeSekme: TTabloListeSekme;
begin
  Caption := T('APP_BASLIK');
  FSerit.YazilariYenile;
  pnlUst.Height := FSerit.Yukseklik;
  miAc.Caption := T('MENU_AC');
  miBagimliliklar.Caption := T('MENU_BAGIMLILIKLAR');
  miYetkiler.Caption := T('MENU_YETKILER');
  miScriptUret.Caption := T('MENU_SCRIPT_URET');
  miNesneDuzenle.Caption := T('MENU_PROSEDUR_DUZENLE');
  miDomVarsayilan.Caption := T('MENU_DOM_VARSAYILAN');
  miDomKontrol.Caption := T('MENU_DOM_KONTROL');
  miDomAd.Caption := T('MENU_DOM_AD');
  miGenDeger.Caption := T('MENU_GEN_DEGER');
  miNesneSil.Caption := T('MENU_SIL');
  miTabloBosalt.Caption := T('MENU_TABLO_BOSALT');
  miTabloKopyala.Caption := T('MENU_TABLO_KOPYALA');
  miYeniTabloTasarim.Caption := T('MENU_YENI_TABLO_TASARIM');
  miBaglan.Caption := T('BTN_BAGLAN');
  miKes.Caption := T('BTN_KES');
  miYenile.Caption := T('MENU_YENILE');
  miDuzenle.Caption := T('MENU_DUZENLE');
  miKaldir.Caption := T('MENU_KAYITTAN_KALDIR');
  miMetadataCikar.Caption := T('MENU_METADATA_CIKAR');
  miYedek.Caption := T('MENU_YEDEK');
  miKlonla.Caption := T('MENU_KLONLA');
  miVeritabaniKopyala.Caption := T('MENU_VERITABANI_KOPYALA');
  miKlasorAdi.Caption := T('MENU_KLASOR_ADLANDIR');
  miKlasorKaldir.Caption := T('MENU_KLASOR_KALDIR');
  miYeniKlasor.Caption := T('BTN_YENI_KLASOR');
  miSekmeKapat.Caption := T('MENU_SEKME_KAPAT');
  miSekmeYenile.Caption := T('MENU_SEKME_YENILE');
  miTumSekmeleriKapat.Caption := T('MENU_TUM_SEKMELERI_KAPAT');
  AyrintiDugmesiniYaz;
  cmbDil.Hint := T('LBL_DIL');
  if YoneticiMi then
    btnYonetici.Caption := T('YONETICI_ROZET')
  else
    btnYonetici.Caption := T('YONETICI_YUKSELT');
  btnYonetici.Hint := T('YONETICI_IPUCU');
  AgacYazilariniYenile;
  for i := 0 to pcCalisma.PageCount - 1 do
  begin
    Sekme := SekmeAl(pcCalisma.Pages[i]);
    if Sekme <> nil then
      Sekme.YazilariYenile;
    KullaniciSekme := KullanicilarAl(pcCalisma.Pages[i]);
    if KullaniciSekme <> nil then
    begin
      pcCalisma.Pages[i].Caption := TF('KUL_SEKME', [KullaniciSekme.BaglantiAd]);
      KullaniciSekme.YazilariYenile;
    end;
    SorguSekme := SorguSekmeAl(pcCalisma.Pages[i]);
    if SorguSekme <> nil then
    begin
      pcCalisma.Pages[i].Caption := SorguSekme.Baslik;
      SorguSekme.YazilariYenile;
    end;
    ProsedurSekme := ProsedurSekmeAl(pcCalisma.Pages[i]);
    if ProsedurSekme <> nil then
    begin
      pcCalisma.Pages[i].Caption := ProsedurSekme.Baslik;
      ProsedurSekme.YazilariYenile;
    end;
    CokluSekme := CokluSekmeAl(pcCalisma.Pages[i]);
    if CokluSekme <> nil then
    begin
      pcCalisma.Pages[i].Caption := T('COKLU_SEKME');
      CokluSekme.YazilariYenile;
    end;
    TopluSekme := TopluSekmeAl(pcCalisma.Pages[i]);
    if TopluSekme <> nil then
    begin
      pcCalisma.Pages[i].Caption := T('TOPLU_SEKME');
      TopluSekme.YazilariYenile;
    end;
    ListeSekme := ListeSekmeAl(pcCalisma.Pages[i]);
    if ListeSekme <> nil then
    begin
      pcCalisma.Pages[i].Caption := TF('LISTE_SEKME', [ListeSekme.BaglantiAd]);
      ListeSekme.YazilariYenile;
    end;
    FarkSekme := FarkSekmeAl(pcCalisma.Pages[i]);
    if FarkSekme <> nil then
    begin
      pcCalisma.Pages[i].Caption := T('FARK_SEKME');
      FarkSekme.YazilariYenile;
    end;
  end;
  DurumuGuncelle;
end;

{ Sorgu sekmesi sonuc yazinca: son sorgunun suresi ve satir sayisi durum cubugunun sag panellerine. }
procedure TfrmAna.SorguDurumuYaz(Sender: TObject);
begin
  stbDurum.Panels[3].Text := TSorguSekme(Sender).SonSure;
  stbDurum.Panels[4].Text := TSorguSekme(Sender).SonSatir;
end;

{ Sorgu sekmesinde CREATE/ALTER/DROP calisinca: o baglantinin agaci (Tablolar, View'lar vb.) kendiliginden yenilenir. }
procedure TfrmAna.SorguYapisiDegisti(Sender: TObject);
begin
  BaglantiAgaciniYenile(TSorguSekme(Sender).BaglantiAd);
end;

{ Adi verilen baglantinin agaci (Tablolar, View'lar vb.) sunucudan yeniden okunur. }
procedure TfrmAna.BaglantiAgaciniYenile(const BaglantiAd: string);
var
  i: Integer;
begin
  for i := 0 to tvNesneler.Items.Count - 1 do
    if (OgeAl(tvNesneler.Items[i]) <> nil) and (OgeAl(tvNesneler.Items[i]).Tur = atBaglanti) and
      SameText(OgeAl(tvNesneler.Items[i]).BaglantiAd, BaglantiAd) then
    begin
      AgaciYenile(tvNesneler.Items[i]);
      Exit;
    end;
end;

{ Tablolar dalina sag tik "Yeni tablo (tasarimla)": kolonlar gridde duzenlenir, olusacak SQL altta gorunur; tablo olusunca dal yenilenir. }
procedure TfrmAna.TabloyuTasarla(Dal: TTreeNode);
var
  Bag: TAcikBaglanti;
  YeniTablo: string;
begin
  Bag := FbAcikBaglanti(OgeAl(Dal).BaglantiAd);
  if Bag = nil then
    Exit;
  if TabloTasarimPenceresiniGoster(Bag, SqlMesajiYaz, memSonuc.Lines, YeniTablo) then
    DalYenile(Dal);
  DurumuGuncelle;
end;

{ Sag tik "Baska veritabanina kopyala": pencere (hedef veritabani ve ad, net onay, tek islem); sonra hedef baglantinin agaci yenilenir. }
procedure TfrmAna.TabloyuKopyala(Dugme: TTreeNode);
var
  Oge: TAgacOgesi;
  Bag: TAcikBaglanti;
  HedefAd: string;
begin
  Oge := OgeAl(Dugme);
  Bag := FbAcikBaglanti(Oge.BaglantiAd);
  if Bag = nil then
    Exit;
  if TabloKopyaPenceresiniGoster(Bag, Oge.Ad, SqlMesajiYaz, memSonuc.Lines, HedefAd) then
    BaglantiAgaciniYenile(HedefAd);
  DurumuGuncelle;
end;

{ Durum cubugu ve dugmeler: agacta secili baglantiya gore. }
procedure TfrmAna.DurumuGuncelle;
var
  Dugme: TTreeNode;
  Ad: string;
  Bag: TAcikBaglanti;
  Tanim: TBaglantiTanimi;
  Yol: string;
begin
  Dugme := SeciliBaglantiDugmesi;
  Bag := nil;
  Ad := '';
  if Dugme <> nil then
  begin
    Ad := OgeAl(Dugme).BaglantiAd;
    Bag := FbAcikBaglanti(Ad);
  end;
  { Secili baglantinin yolu (sunucu ve dosya) durum cubugunda ad ile birlikte yazilir. }
  Yol := '';
  if (Dugme <> nil) and KayitliBaglantiBul(Ad, Tanim) then
    Yol := '  -  ' + BaglantiYolu(Tanim);
  if Dugme = nil then
  begin
    stbDurum.Panels[0].Text := T('DURUM_SECIM_YOK');
    stbDurum.Panels[1].Text := '';
    stbDurum.Panels[2].Text := '';
  end
  else if Bag = nil then
  begin
    stbDurum.Panels[0].Text := Ad + Yol;
    stbDurum.Panels[1].Text := '';
    stbDurum.Panels[2].Text := T('DURUM_BAGLI_DEGIL');
  end
  else
  begin
    stbDurum.Panels[0].Text := TF('DURUM_BAGLI', [Ad]) + Yol;
    stbDurum.Panels[1].Text := TF('DURUM_SURUM', [Bag.Surum]);
    if FbIslemAcikMi(Bag) then
      stbDurum.Panels[2].Text := T('DURUM_ISLEM_ACIK')
    else
      stbDurum.Panels[2].Text := T('DURUM_ISLEM_KAPALI');
  end;
  { Bagla/Kes tek dugme: yazisi ve ikonu secili baglantinin durumuna gore degisir. }
  if Bag = nil then
    btnBaglan.Ayarla('BTN_BAGLAN', IKON_BAGLAN)
  else
    btnBaglan.Ayarla('BTN_KES', IKON_KES);
  btnBaglan.Enabled := Dugme <> nil;
  { Klonla: yalniz dogrudan bir baglanti dugumu secili iken (klasor, tablo vb. degil). }
  btnKlonla.Enabled := (tvNesneler.Selected <> nil) and (OgeAl(tvNesneler.Selected).Tur = atBaglanti);
  btnYenile.Enabled := Bag <> nil;
  btnYeniSorgu.Enabled := Bag <> nil;
  btnCalistir.Enabled := AktifSorguSekmesi <> nil;
  btnPlan.Enabled := AktifSorguSekmesi <> nil;
  btnIndeksOner.Enabled := AktifSorguSekmesi <> nil;
  btnGecmis.Enabled := AktifSorguSekmesi <> nil;
  btnMetadata.Enabled := Bag <> nil;
  btnYedek.Enabled := Dugme <> nil;
  btnAktifBaglanti.Enabled := Bag <> nil;
  btnBakim.Enabled := Bag <> nil;
  btnAra.Enabled := Bag <> nil;
  { Kullanicilar: yalniz acik ve sunucu kipindeki baglantida; gomulu baglantida gerekce arac ipucunda. }
  btnKullanicilar.Enabled := (Bag <> nil) and KullaniciYetenekleri(Bag).YonetimVar;
  if (Bag <> nil) and not KullaniciYetenekleri(Bag).YonetimVar then
    btnKullanicilar.Hint := T('ERR_KULLANICI_GOMULU')
  else
    btnKullanicilar.Hint := '';
end;

procedure TfrmAna.MesajYaz(const Metin: string);
begin
  memSonuc.Lines.Add(Metin);
end;

{ Yonetim islemlerinin calistirdigi SQL'i mesaj alanina yazar (sifre zaten *** gelir). Sekmeler bunu cagirir. }
procedure TfrmAna.SqlMesajiYaz(const Komutlar: TArray<string>);
var
  Komut: string;
begin
  for Komut in Komutlar do
    MesajYaz(T('SQL_ETIKET') + ' ' + Komut);
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

{ Yeni klasor, Ust'un (nil = kok) icinde, oradaki ilk baglantinin onune konur (klasorler ustte durur). }
function TfrmAna.KlasorDugmesiEkle(const Ad: string; Ust: TTreeNode): TTreeNode;
begin
  Result := tvNesneler.Items.AddChild(Ust, Ad);
  OgeBagla(Result, IKON_KLASOR, atKlasor, '', Ad, 0);
  DugumuTasi(Result, Ust);
end;

{ Dugumu Ust'un (nil = kok) altina tasir. Klasor, oradaki ilk baglantinin onune girer; baglanti en sona. }
procedure TfrmAna.DugumuTasi(Dugme, Ust: TTreeNode);
var
  Kardes: TTreeNode;
begin
  Kardes := nil;
  if OgeAl(Dugme).Tur = atKlasor then
  begin
    if Ust = nil then
      Kardes := tvNesneler.Items.GetFirstNode
    else
      Kardes := Ust.GetFirstChild;
    while (Kardes <> nil) and (OgeAl(Kardes).Tur <> atBaglanti) do
      Kardes := Kardes.GetNextSibling;
  end;
  if Kardes <> nil then
    Dugme.MoveTo(Kardes, naInsert)
  else if Ust = nil then
    Dugme.MoveTo(nil, naAdd)
  else
    Dugme.MoveTo(Ust, naAddChild);
end;

{ Dugum, Ata'nin kendisi ya da altindaki bir dugum mu (klasoru kendi icine tasimayi engellemek icin). }
function TfrmAna.DugumAltindaMi(Dugme, Ata: TTreeNode): Boolean;
begin
  Result := False;
  while Dugme <> nil do
  begin
    if Dugme = Ata then
      Exit(True);
    Dugme := Dugme.Parent;
  end;
end;

{ Ust nil ise baglanti kok duzeye eklenir. Kapali baglanti "fisi cekilmis" ikonuyla gorunur. }
function TfrmAna.BaglantiDugmesiEkle(Ust: TTreeNode; const Ad: string): TTreeNode;
begin
  Result := tvNesneler.Items.AddChild(Ust, Ad);
  OgeBagla(Result, IKON_KES, atBaglanti, Ad, '', 0);
end;

{ Klasor adlari butun agacta tektir; klasor kokte de bir klasorun icinde de olabilir. }
function TfrmAna.KlasorDugmesiBul(const Ad: string): TTreeNode;
var
  i: Integer;
begin
  for i := 0 to tvNesneler.Items.Count - 1 do
  begin
    Result := tvNesneler.Items[i];
    if (OgeAl(Result) <> nil) and (OgeAl(Result).Tur = atKlasor) and SameText(OgeAl(Result).Ad, Ad) then
      Exit;
  end;
  Result := nil;
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
  Klasor: TKlasorKaydi;
  Tanim: TBaglantiTanimi;
  Ust: TTreeNode;
begin
  tvNesneler.Items.BeginUpdate;
  try
    tvNesneler.Items.Clear;
    FOgeler.Clear;
    FSurukleNode := nil;
    for Klasor in KayitliKlasorAgaci do
      KlasorDugmesiEkle(Klasor.Ad, KlasorDugmesiBul(Klasor.Ust));
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

{ Tetikleyiciler: adin yaninda bagli oldugu tablo; veritabani ve DDL tetikleyicisinde tablo yerine tur (ON CONNECT, DDL).
  Pasif olanlar agacta soluk cizilir (tvNesnelerCustomDrawItem). }
procedure TfrmAna.TetikleyiciDaliDoldur(Dal: TTreeNode; const Liste: TArray<TTetikleyiciBilgisi>);
var
  Tetik: TTetikleyiciBilgisi;
  Dugme: TTreeNode;
  Yer: string;
begin
  for Tetik in Liste do
  begin
    Yer := Tetik.Tablo;
    if Yer = '' then
      Yer := Tetik.Olaylar;
    Dugme := tvNesneler.Items.AddChild(Dal, Tetik.Ad + ' (' + Yer + ')');
    OgeBagla(Dugme, IKON_TETIKLEYICI, atNesne, OgeAl(Dal).BaglantiAd, Tetik.Ad, OgeAl(Dal).DalNo);
    OgeAl(Dugme).Pasif := not Tetik.Aktif;
    OgeAl(Dugme).Duzenlenemez := Tetik.Desteklenmiyor;
  end;
end;

{ Tek dalin icini sunucudan okuyup doldurur (dal dugumu zaten vardir). }
procedure TfrmAna.DalIciniDoldur(Dal: TTreeNode; Bag: TAcikBaglanti);
var
  Liste: TStringList;
begin
  Liste := TStringList.Create;
  try
    Dal.DeleteChildren;
    case OgeAl(Dal).DalNo of
      DAL_TABLO:
        begin
          TablolariGetir(Bag, Liste);
          DalDoldur(Dal, IKON_TABLO, Liste);
        end;
      DAL_VIEW:
        begin
          ViewlariGetir(Bag, Liste);
          DalDoldur(Dal, IKON_VIEW, Liste);
        end;
      DAL_PROSEDUR:
        begin
          ProsedurleriGetir(Bag, Liste);
          DalDoldur(Dal, IKON_PROSEDUR, Liste);
        end;
      DAL_TETIKLEYICI:
        TetikleyiciDaliDoldur(Dal, TetikleyicileriListele(Bag));
      DAL_DOMAIN:
        begin
          DomainleriGetir(Bag, Liste);
          DalDoldur(Dal, IKON_DOMAIN, Liste);
        end;
      DAL_ISTISNA:
        begin
          IstisnalariGetir(Bag, Liste);
          DalDoldur(Dal, IKON_ISTISNA, Liste);
        end;
    else
      GeneratorleriGetir(Bag, Liste);
      DalDoldur(Dal, IKON_GENERATOR, Liste);
    end;
  finally
    Liste.Free;
  end;
end;

{ Baglantinin altindaki yedi dali sunucudan okuyup yeniden doldurur. }
procedure TfrmAna.DallariDoldur(Dugme: TTreeNode; Bag: TAcikBaglanti);
var
  Dallar: array[0..DAL_SAYISI - 1] of TTreeNode;
  i: Integer;
begin
  tvNesneler.Items.BeginUpdate;
  try
    Dugme.DeleteChildren;
    for i := 0 to DAL_SAYISI - 1 do
    begin
      Dallar[i] := tvNesneler.Items.AddChild(Dugme, '');
      OgeBagla(Dallar[i], IKON_KLASOR, atDal, Bag.Tanim.Ad, '', i);
    end;
    for i := 0 to DAL_SAYISI - 1 do
      DalIciniDoldur(Dallar[i], Bag);
    Dugme.Expand(False);
    Dallar[DAL_TABLO].Expand(False);
  finally
    tvNesneler.Items.EndUpdate;
  end;
  AgacYazilariniYenile;
end;

{ Dal basliklarini secili dille yazar (sayilariyla birlikte). }
procedure TfrmAna.AgacYazilariniYenile;
const
  ANAHTARLAR: array[0..DAL_SAYISI - 1] of string = (
    'AGAC_TABLOLAR', 'AGAC_VIEWLAR', 'AGAC_PROSEDURLER', 'AGAC_TETIKLEYICILER', 'AGAC_DOMAINLER',
    'AGAC_ISTISNALAR', 'AGAC_GENERATORLER');
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
  { Baglanirken durum cubugunda ne yapildigi gorunur (yavas aglarda pencere donmus sanilmasin). }
  stbDurum.Panels[0].Text := TF('MSG_BAGLANIYOR', [Ad]);
  stbDurum.Update;
  Screen.Cursor := crHourGlass;
  try
    try
      Bag := FbBaglan(Tanim);
    except
      on E: Exception do
      begin
        HataYaz(TF('ERR_BAGLANTI_ACILAMADI', [Ad]) + ' ' + HataMetniniCevir(E), E.Message);
        DurumuGuncelle;
        Exit;
      end;
    end;
    stbDurum.Panels[0].Text := TF('MSG_AGAC_OKUNUYOR', [Ad]);
    stbDurum.Update;
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

{ KlonAd doluysa o baglantinin bilgileriyle dolu pencere acilir; yeni kayit
  kaynagin klasorune konur. }
procedure TfrmAna.YeniBaglanti(const KlonAd: string);
var
  Ad: string;
  Dugme, Ust: TTreeNode;
  Kaynak: TBaglantiTanimi;
  Sonuc: TBaglantiSonucu;
begin
  Sonuc := BaglantiPenceresiniGoster('', KlonAd, Ad);
  if Sonuc = bsIptal then
    Exit;
  Ust := nil;
  if (KlonAd <> '') and KayitliBaglantiBul(KlonAd, Kaynak) and (Kaynak.Klasor <> '') then
  begin
    try
      BaglantiKlasoruAyarla(Ad, Kaynak.Klasor);
      Ust := KlasorDugmesiBul(Kaynak.Klasor);
    except
      on E: Exception do
        KayitHatasiGoster(E);
    end;
  end;
  case Sonuc of
    bsKaydedildi:
      Dugme := BaglantiDugmesiEkle(Ust, Ad);
    bsBaglandi:
      begin
        Dugme := BaglantiDugmesiEkle(Ust, Ad);
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
  if BaglantiPenceresiniGoster(Ad, '', YeniAd) = bsIptal then
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

{ Secili dugum bir klasorse yeni klasor onun icine girer; degilse (bos alana sag tik secimi kaldirir) kok duzeye. }
procedure TfrmAna.YeniKlasor;
var
  Ad, UstAdi: string;
  Ust: TTreeNode;
begin
  Ust := nil;
  UstAdi := '';
  if (tvNesneler.Selected <> nil) and (OgeAl(tvNesneler.Selected).Tur = atKlasor) then
  begin
    Ust := tvNesneler.Selected;
    UstAdi := OgeAl(Ust).Ad;
  end;
  Ad := '';
  if not MetinSor(T('KLASOR_YENI_BASLIK'), T('LBL_KLASOR_AD'), Ad, False) then
    Exit;
  try
    KlasorEkle(Ad, UstAdi);
  except
    on E: Exception do
    begin
      KayitHatasiGoster(E);
      Exit;
    end;
  end;
  if Ust <> nil then
    Ust.Expand(False);
  tvNesneler.Selected := KlasorDugmesiEkle(Trim(Ad), Ust);
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

{ Klasor kalkar; icindeki baglantilar ve alt klasorler silinmez, klasorun ustune (ustu yoksa kok duzeye) cikar. }
procedure TfrmAna.KlasoruKaldir(Dugme: TTreeNode);
var
  Ad: string;
  Ust: TTreeNode;
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
  Ust := Dugme.Parent;
  while Dugme.Count > 0 do
    DugumuTasi(Dugme.GetFirstChild, Ust);
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

function TfrmAna.SorguSekmeAl(Sayfa: TTabSheet): TSorguSekme;
begin
  Result := nil;
  if (Sayfa.ControlCount > 0) and (Sayfa.Controls[0] is TSorguSekme) then
    Result := TSorguSekme(Sayfa.Controls[0]);
end;

function TfrmAna.ProsedurSekmeAl(Sayfa: TTabSheet): TProsedurSekme;
begin
  Result := nil;
  if (Sayfa.ControlCount > 0) and (Sayfa.Controls[0] is TProsedurSekme) then
    Result := TProsedurSekme(Sayfa.Controls[0]);
end;

function TfrmAna.AktifProsedurSekmesi: TProsedurSekme;
begin
  Result := nil;
  if pcCalisma.ActivePage <> nil then
    Result := ProsedurSekmeAl(pcCalisma.ActivePage);
end;

function TfrmAna.KullanicilarAl(Sayfa: TTabSheet): TKullanicilar;
begin
  Result := nil;
  if (Sayfa.ControlCount > 0) and (Sayfa.Controls[0] is TKullanicilar) then
    Result := TKullanicilar(Sayfa.Controls[0]);
end;

{ Her baglanti icin tek "Kullanicilar" sekmesi: ikinci tiklamada mevcut sekme one gelir. }
procedure TfrmAna.KullanicilarAc(Dugme: TTreeNode);
var
  Ad: string;
  Bag: TAcikBaglanti;
  Sayfa: TTabSheet;
  Sekme: TKullanicilar;
  i: Integer;
begin
  Ad := OgeAl(Dugme).BaglantiAd;
  Bag := FbAcikBaglanti(Ad);
  if Bag = nil then
    Exit;
  for i := 0 to pcCalisma.PageCount - 1 do
  begin
    Sekme := KullanicilarAl(pcCalisma.Pages[i]);
    if (Sekme <> nil) and SameText(Sekme.BaglantiAd, Ad) then
    begin
      pcCalisma.ActivePage := pcCalisma.Pages[i];
      Exit;
    end;
  end;
  Sayfa := TTabSheet.Create(pcCalisma);
  Sayfa.PageControl := pcCalisma;
  Sayfa.Caption := TF('KUL_SEKME', [Ad]);
  Sayfa.ImageIndex := IKON_KULLANICI;
  Sekme := TKullanicilar.Create(Sayfa);
  Sekme.Parent := Sayfa;
  Sekme.Align := alClient;
  Sekme.AnaSonuc := memSonuc.Lines;
  Sekme.SqlYaz := SqlMesajiYaz;
  try
    Sekme.Yukle(Bag);
  except
    on E: Exception do
    begin
      Sayfa.Free;
      HataYaz(T('ERR_KULLANICI_LISTE') + ' ' + HataMetniniCevir(E), E.Message);
      Exit;
    end;
  end;
  pcCalisma.ActivePage := Sayfa;
  MesajYaz(TF('KUL_MSG_ACILDI', [Ad]));
  DurumuGuncelle;
end;

function TfrmAna.AktifSorguSekmesi: TSorguSekme;
begin
  Result := nil;
  if pcCalisma.ActivePage <> nil then
    Result := SorguSekmeAl(pcCalisma.ActivePage);
end;

{ Secili (acik) baglanti icin yeni bir sorgu sekmesi acar. Metin doluysa editore yazilir (calistirilmaz). }
procedure TfrmAna.YeniSorgu(const Metin: string);
var
  Dugme: TTreeNode;
  Bag: TAcikBaglanti;
  Sayfa: TTabSheet;
  Sekme: TSorguSekme;
begin
  Dugme := SeciliBaglantiDugmesi;
  Bag := nil;
  if Dugme <> nil then
    Bag := FbAcikBaglanti(OgeAl(Dugme).BaglantiAd);
  if Bag = nil then
  begin
    UyariGoster(T('ERR_SORGU_BAGLANTI_SEC'));
    Exit;
  end;
  Inc(FSorguNo);
  Sayfa := TTabSheet.Create(pcCalisma);
  Sayfa.PageControl := pcCalisma;
  Sayfa.ImageIndex := IKON_SORGU;
  Sekme := TSorguSekme.Create(Sayfa);
  Sekme.Parent := Sayfa;
  Sekme.Align := alClient;
  Sekme.AnaSonuc := memSonuc.Lines;
  Sekme.OnDurum := SorguDurumuYaz;
  Sekme.OnYapiDegisti := SorguYapisiDegisti;
  Sekme.Hazirla(FSorguNo, Bag.Tanim.Ad);
  if Metin <> '' then
    Sekme.MetinYaz(Metin);
  Sayfa.Caption := Sekme.Baslik;
  pcCalisma.ActivePage := Sayfa;
  Sekme.EditoreOdaklan;
  DurumuGuncelle;
end;

{ Secili nesnenin CREATE script'ini yeni bir sorgu sekmesinde acar (calistirmaz). }
procedure TfrmAna.ScriptAc(Dugme: TTreeNode);
var
  Oge: TAgacOgesi;
  Bag: TAcikBaglanti;
  Tur: TNesneTuru;
  Script: string;
begin
  Oge := OgeAl(Dugme);
  Bag := FbAcikBaglanti(Oge.BaglantiAd);
  if Bag = nil then
    Exit;
  Tur := DalTuru(Oge.DalNo);
  try
    Script := ScriptUret(Bag, Tur, Oge.Ad);
  except
    on E: EMetadataHatasi do
    begin
      HataYaz(E.Message, '');
      Exit;
    end;
    on E: Exception do
    begin
      HataYaz(T('ERR_DDL_ALINAMADI') + ' ' + HataMetniniCevir(E), E.Message);
      Exit;
    end;
  end;
  YeniSorgu(Script);
  MesajYaz(TF('MSG_SCRIPT_URETILDI', [Oge.Ad]));
end;

{ Prosedurun, tetikleyicinin veya view'in CREATE OR ALTER metnini duzenleme sekmesinde acar (hangisi oldugu agactaki
  dalindan gelir). Ayni baglantida ayni nesne zaten aciksa o sekmeye gecilir (yazilmis ama kaydedilmemis metin kaybolmasin). }
procedure TfrmAna.NesneDuzenleAc(Dugme: TTreeNode);
begin
  NesneDuzenleSekmesiAc(OgeAl(Dugme).BaglantiAd, OgeAl(Dugme).Ad, DalTuru(OgeAl(Dugme).DalNo));
end;

{ Arama sonucu: tablo kendi sekmesinde, view / prosedur / trigger / exception duzenleme sekmesinde acilir. }
procedure TfrmAna.AramaSonucunuAc(const BaglantiAd: string; const Sonuc: TAramaSonucu);
begin
  if Sonuc.Tur = ntTablo then
    TabloSekmesiAc(BaglantiAd, Sonuc.Ad)
  else
    NesneDuzenleSekmesiAc(BaglantiAd, Sonuc.Ad, Sonuc.Tur);
end;

{ Yonetim > Ara: secili (acik) baglantida ad ve kaynak aramasi; secilen nesne sekmede acilir. }
procedure TfrmAna.btnAraClick(Sender: TObject);
var
  Bag: TAcikBaglanti;
  Secim: TAramaSonucu;
begin
  if SeciliBaglantiDugmesi = nil then
    Exit;
  Bag := FbAcikBaglanti(OgeAl(SeciliBaglantiDugmesi).BaglantiAd);
  if (Bag <> nil) and AraPenceresiniGoster(Bag, Secim) then
    AramaSonucunuAc(Bag.Tanim.Ad, Secim);
end;

procedure TfrmAna.NesneDuzenleSekmesiAc(const BaglantiAd, Ad: string; Tur: TNesneTuru);
var
  Bag: TAcikBaglanti;
  Sayfa: TTabSheet;
  Sekme: TProsedurSekme;
  i: Integer;
begin
  Bag := FbAcikBaglanti(BaglantiAd);
  if Bag = nil then
    Exit;
  for i := 0 to pcCalisma.PageCount - 1 do
  begin
    Sekme := ProsedurSekmeAl(pcCalisma.Pages[i]);
    if (Sekme <> nil) and not Sekme.Yeni and SameText(Sekme.BaglantiAd, BaglantiAd) and (Sekme.NesneAdi = Ad) and
      (TurOnEki(Sekme.Tur) = TurOnEki(Tur)) then
    begin
      pcCalisma.ActivePage := pcCalisma.Pages[i];
      Exit;
    end;
  end;
  Sayfa := TTabSheet.Create(pcCalisma);
  Sayfa.PageControl := pcCalisma;
  case Tur of
    ntTetikleyici: Sayfa.ImageIndex := IKON_TETIKLEYICI;
    ntView: Sayfa.ImageIndex := IKON_VIEW;
    ntIstisna: Sayfa.ImageIndex := IKON_ISTISNA;
  else
    Sayfa.ImageIndex := IKON_PROSEDUR;
  end;
  Sekme := TProsedurSekme.Create(Sayfa);
  Sekme.Parent := Sayfa;
  Sekme.Align := alClient;
  Sekme.Tur := Tur;
  Sekme.AnaSonuc := memSonuc.Lines;
  Sekme.SqlYaz := SqlMesajiYaz;
  try
    Sekme.Yukle(Bag, Ad);
  except
    on E: EMetadataHatasi do
    begin
      Sayfa.Free;
      HataYaz(E.Message, '');
      Exit;
    end;
    on E: Exception do
    begin
      Sayfa.Free;
      HataYaz(T('ERR_DDL_ALINAMADI') + ' ' + HataMetniniCevir(E), E.Message);
      Exit;
    end;
  end;
  Sayfa.Caption := Sekme.Baslik;
  pcCalisma.ActivePage := Sayfa;
  Sekme.EditoreOdaklan;
  MesajYaz(TF('MSG_' + TurOnEki(Tur) + '_ACILDI', [Ad]));
  DurumuGuncelle;
end;

{ Dal numarasindan nesne turu (prosedur dahil her dal icin). }
function TfrmAna.DalTuru(DalNo: Integer): TNesneTuru;
begin
  case DalNo of
    DAL_TABLO: Result := ntTablo;
    DAL_VIEW: Result := ntView;
    DAL_PROSEDUR: Result := ntProsedur;
    DAL_TETIKLEYICI: Result := ntTetikleyici;
    DAL_DOMAIN: Result := ntDomain;
    DAL_ISTISNA: Result := ntIstisna;
  else
    Result := ntGenerator;
  end;
end;

{ Baglantinin altindaki dal dugumu (agacta yoksa nil). }
function TfrmAna.DalDugmesiBul(const BaglantiAd: string; DalNo: Integer): TTreeNode;
var
  i: Integer;
begin
  for i := 0 to tvNesneler.Items.Count - 1 do
  begin
    Result := tvNesneler.Items[i];
    if (OgeAl(Result) <> nil) and (OgeAl(Result).Tur = atDal) and (OgeAl(Result).DalNo = DalNo) and
      SameText(OgeAl(Result).BaglantiAd, BaglantiAd) then
      Exit;
  end;
  Result := nil;
end;

{ Yalniz bu dalin icini sunucudan yeniden okur (olusturma, silme, ad degisikligi sonrasi); dal acik/kapali durumu korunur. }
procedure TfrmAna.DalYenile(Dal: TTreeNode);
var
  Bag: TAcikBaglanti;
  Acikti: Boolean;
begin
  if Dal = nil then
    Exit;
  Bag := FbAcikBaglanti(OgeAl(Dal).BaglantiAd);
  if Bag = nil then
    Exit;
  Acikti := Dal.Expanded;
  tvNesneler.Items.BeginUpdate;
  try
    DalIciniDoldur(Dal, Bag);
    Dal.Expanded := Acikti;
  finally
    tvNesneler.Items.EndUpdate;
  end;
  AgacYazilariniYenile;
end;

{ Dala sag tik "Yeni": exception ve domain icin bos sablonlu duzenleme sekmesi acar (Kaydet = olusturur). Ayni baglanti
  ve turde "Yeni" sekmesi zaten aciksa ona gecilir. }
procedure TfrmAna.YeniNesneAc(Dal: TTreeNode);
var
  Oge: TAgacOgesi;
  Bag: TAcikBaglanti;
  Sayfa: TTabSheet;
  Sekme: TProsedurSekme;
  Tur: TNesneTuru;
  i: Integer;
begin
  Oge := OgeAl(Dal);
  Bag := FbAcikBaglanti(Oge.BaglantiAd);
  if Bag = nil then
    Exit;
  Tur := DalTuru(Oge.DalNo);
  for i := 0 to pcCalisma.PageCount - 1 do
  begin
    Sekme := ProsedurSekmeAl(pcCalisma.Pages[i]);
    if (Sekme <> nil) and Sekme.Yeni and SameText(Sekme.BaglantiAd, Oge.BaglantiAd) and
      (TurOnEki(Sekme.Tur) = TurOnEki(Tur)) then
    begin
      pcCalisma.ActivePage := pcCalisma.Pages[i];
      Exit;
    end;
  end;
  Sayfa := TTabSheet.Create(pcCalisma);
  Sayfa.PageControl := pcCalisma;
  if Tur = ntTablo then
    Sayfa.ImageIndex := IKON_TABLO
  else if Tur = ntDomain then
    Sayfa.ImageIndex := IKON_DOMAIN
  else
    Sayfa.ImageIndex := IKON_ISTISNA;
  Sekme := TProsedurSekme.Create(Sayfa);
  Sekme.Parent := Sayfa;
  Sekme.Align := alClient;
  Sekme.Tur := Tur;
  Sekme.AnaSonuc := memSonuc.Lines;
  Sekme.SqlYaz := SqlMesajiYaz;
  Sekme.OnOlusturuldu := YeniNesneOlusturuldu;
  try
    Sekme.YeniHazirla(Bag);
  except
    on E: Exception do
    begin
      Sayfa.Free;
      HataYaz(T('ERR_DDL_ALINAMADI') + ' ' + HataMetniniCevir(E), E.Message);
      Exit;
    end;
  end;
  Sayfa.Caption := Sekme.Baslik;
  pcCalisma.ActivePage := Sayfa;
  Sekme.EditoreOdaklan;
  MesajYaz(T('MSG_' + TurOnEki(Tur) + '_YENI_ACILDI'));
  DurumuGuncelle;
end;

{ "Yeni" sekmesi nesneyi olusturdu: dal yenilenir, is bitti sayilip sekme kapatilir (kuyruktan: sekmenin kendi olayi
  bitmeden silinmesin). Exception'i duzenlemek icin agactan Duzenle'ye basilir. }
procedure TfrmAna.YeniNesneOlusturuldu(Sender: TObject);
var
  Sekme: TProsedurSekme;
  DalNo: Integer;
begin
  Sekme := TProsedurSekme(Sender);
  if Sekme.Tur = ntTablo then
    DalNo := DAL_TABLO
  else if Sekme.Tur = ntDomain then
    DalNo := DAL_DOMAIN
  else
    DalNo := DAL_ISTISNA;
  DalYenile(DalDugmesiBul(Sekme.BaglantiAd, DalNo));
  FKapatilacakSayfa := TTabSheet(Sekme.Parent);
  TThread.ForceQueue(nil, SayfayiKapat);
end;

procedure TfrmAna.SayfayiKapat;
begin
  if FKapatilacakSayfa <> nil then
  begin
    FKapatilacakSayfa.Free;
    FKapatilacakSayfa := nil;
  end;
  DurumuGuncelle;
end;

{ Silinen nesnenin acik duzenleme sekmeleri kapatilir (kaydedilirse nesne yeniden olusurdu). }
procedure TfrmAna.NesneSekmeleriniKapat(const BaglantiAd: string; Tur: TNesneTuru; const Ad: string);
var
  i: Integer;
  Sekme: TProsedurSekme;
  TabloSekmesi: TTabloSekme;
begin
  for i := pcCalisma.PageCount - 1 downto 0 do
  begin
    { Silinen tablonun acik tablo sekmeleri (kolon/veri) de kapanir. }
    TabloSekmesi := SekmeAl(pcCalisma.Pages[i]);
    if (Tur = ntTablo) and (TabloSekmesi <> nil) and SameText(TabloSekmesi.BaglantiAd, BaglantiAd) and
      (TabloSekmesi.TabloAdi = Ad) then
    begin
      pcCalisma.Pages[i].Free;
      Continue;
    end;
    Sekme := ProsedurSekmeAl(pcCalisma.Pages[i]);
    if (Sekme <> nil) and not Sekme.Yeni and SameText(Sekme.BaglantiAd, BaglantiAd) and (Sekme.NesneAdi = Ad) and
      (TurOnEki(Sekme.Tur) = TurOnEki(Tur)) then
      pcCalisma.Pages[i].Free;
  end;
end;

{ Sag tik "Tum kayitlari sil": net onay (satir sayisi, DELETE komutu, geri alinamaz) + tablo adini yazdirma; sonra tek islemde
  DELETE FROM. Hata olursa hicbir satir silinmez. Acik tablo sekmeleri yeniden okunur. }
procedure TfrmAna.TabloyuBosalt(Dugme: TTreeNode);
var
  Oge: TAgacOgesi;
  Bag: TAcikBaglanti;
  Onay, Yazilan: string;
  Sayi: Int64;
  Sonuc: TProsedurSonucu;
  i: Integer;
  TabloSekmesi: TTabloSekme;
begin
  Oge := OgeAl(Dugme);
  Bag := FbAcikBaglanti(Oge.BaglantiAd);
  if Bag = nil then
    Exit;
  try
    Sayi := TabloSatirSayisi(Bag, Oge.Ad);
    Onay := BosaltmaOnayMetni(Bag, Oge.Ad);
  except
    on E: Exception do
    begin
      HataYaz(HataMetniniCevir(E), E.Message);
      Exit;
    end;
  end;
  if Sayi = 0 then
  begin
    MesajYaz(TF('MSG_BOSALT_ZATEN_BOS', [Oge.Ad]));
    Exit;
  end;
  if not OnayIste(Onay) then
  begin
    MesajYaz(T('MSG_BOSALT_VAZGECILDI'));
    Exit;
  end;
  { Yanlislikla bosaltilmasin diye tablonun adi yazdirilir (tablo silmedeki gibi). }
  Yazilan := '';
  if not MetinSor(T('BOSALT_AD_BASLIK'), TF('BOSALT_AD_ETIKET', [Oge.Ad]), Yazilan, False) then
  begin
    MesajYaz(T('MSG_BOSALT_VAZGECILDI'));
    Exit;
  end;
  if not SameText(Trim(Yazilan), Oge.Ad) then
  begin
    UyariGoster(T('ERR_BOSALT_AD_UYMADI'));
    MesajYaz(T('MSG_BOSALT_VAZGECILDI'));
    Exit;
  end;
  Sonuc := TabloBosalt(Bag, Oge.Ad);
  if Sonuc.Basarili then
  begin
    MesajYaz(TF('MSG_BOSALT_YAPILDI', [Oge.Ad, Sayi]));
    { Acik tablo sekmeleri bos tabloyu gostersin. }
    for i := 0 to pcCalisma.PageCount - 1 do
    begin
      TabloSekmesi := SekmeAl(pcCalisma.Pages[i]);
      if (TabloSekmesi <> nil) and SameText(TabloSekmesi.BaglantiAd, Oge.BaglantiAd) and (TabloSekmesi.TabloAdi = Oge.Ad) then
        TabloSekmesi.Yenile;
    end;
  end
  else
  begin
    HataYaz(TF('ERR_BOSALT_YAPILAMADI', [Oge.Ad]) + ' ' + Sonuc.Cumle, Sonuc.Ayrinti);
    MesajYaz(T('MSG_BOSALT_GERI_ALINDI'));
  end;
  SqlMesajiYaz(Sonuc.Komutlar);
  DurumuGuncelle;
end;

{ Sag tik "Sil": net onay (nesne, geri alinamaz, yedek, kullananlar), yedek + DROP, sonuc ve SQL mesaj alaninda. }
procedure TfrmAna.NesneyiSil(Dugme: TTreeNode);
var
  Oge: TAgacOgesi;
  Bag: TAcikBaglanti;
  Tur: TNesneTuru;
  Dal: TTreeNode;
  Onay, Yazilan: string;
  Sonuc: TProsedurSonucu;
begin
  Oge := OgeAl(Dugme);
  Bag := FbAcikBaglanti(Oge.BaglantiAd);
  if Bag = nil then
    Exit;
  Tur := DalTuru(Oge.DalNo);
  try
    Onay := SilmeOnayMetni(Bag, Tur, Oge.Ad);
  except
    on E: Exception do
    begin
      HataYaz(T('ERR_DDL_ALINAMADI') + ' ' + HataMetniniCevir(E), E.Message);
      Exit;
    end;
  end;
  if not OnayIste(Onay) then
  begin
    MesajYaz(T('MSG_SIL_VAZGECILDI'));
    Exit;
  end;
  { Tablo: yanlislikla silinmesin diye adi yazdirilir (veriler yedeklenmez). }
  if Tur = ntTablo then
  begin
    Yazilan := '';
    if not MetinSor(T('SIL_TABLO_AD_BASLIK'), TF('SIL_TABLO_AD_ETIKET', [Oge.Ad]), Yazilan, False) then
    begin
      MesajYaz(T('MSG_SIL_VAZGECILDI'));
      Exit;
    end;
    if not SameText(Trim(Yazilan), Oge.Ad) then
    begin
      UyariGoster(T('ERR_SIL_TABLO_AD_UYMADI'));
      MesajYaz(T('MSG_SIL_VAZGECILDI'));
      Exit;
    end;
  end;
  Dal := Dugme.Parent;
  Sonuc := NesneSil(Bag, Tur, Oge.Ad);
  if Sonuc.Basarili then
  begin
    MesajYaz(TF('MSG_SIL_YAPILDI', [Oge.Ad]));
    MesajYaz(TF('MSG_PRS_YEDEKLENDI', [Sonuc.YedekDosyasi]));
    NesneSekmeleriniKapat(Oge.BaglantiAd, Tur, Oge.Ad);
    DalYenile(Dal);
  end
  else
  begin
    HataYaz(TF('ERR_SIL_YAPILAMADI', [Oge.Ad]) + ' ' + Sonuc.Cumle, Sonuc.Ayrinti);
    if Length(Sonuc.Komutlar) = 0 then
      MesajYaz(T('MSG_PRS_DOKUNULMADI'))
    else
      MesajYaz(T('MSG_SIL_GERI_ALINDI'));
  end;
  SqlMesajiYaz(Sonuc.Komutlar);
  DurumuGuncelle;
end;

{ Generator sag tik "Degeri goster/ayarla": kucuk pencerede simdiki deger, yeni deger ve generator'i kullananlar; sonra
  SQL'in gorundugu net onay (yeni deger kucukse ek uyari); yedek + komut. }
procedure TfrmAna.GeneratorDegeriAc(Dugme: TTreeNode);
var
  Oge: TAgacOgesi;
  Bag: TAcikBaglanti;
  Mevcut, Yeni: Int64;
  Kullananlar: string;
  Sonuc: TProsedurSonucu;
begin
  Oge := OgeAl(Dugme);
  Bag := FbAcikBaglanti(Oge.BaglantiAd);
  if Bag = nil then
    Exit;
  try
    Mevcut := GeneratorDeger(Bag, Oge.Ad);
    Kullananlar := GeneratorKullananlarMetni(Bag, Oge.Ad);
  except
    on E: Exception do
    begin
      HataYaz(T('ERR_DDL_ALINAMADI') + ' ' + HataMetniniCevir(E), E.Message);
      Exit;
    end;
  end;
  if not GeneratorDegerPenceresi(Oge.Ad, Mevcut, Kullananlar, Yeni) then
    Exit;
  if Yeni = Mevcut then
  begin
    MesajYaz(TF('MSG_GEN_DEGISMEDI', [Oge.Ad, Mevcut]));
    Exit;
  end;
  if not OnayIste(GeneratorDegerOnayMetni(Bag, Oge.Ad, Mevcut, Yeni)) then
  begin
    MesajYaz(T('MSG_GEN_VAZGECILDI'));
    Exit;
  end;
  Sonuc := GeneratorDegerAyarla(Bag, Oge.Ad, Yeni);
  if Sonuc.Basarili then
  begin
    MesajYaz(TF('MSG_GEN_AYARLANDI', [Oge.Ad, Mevcut, Yeni]));
    MesajYaz(TF('MSG_PRS_YEDEKLENDI', [Sonuc.YedekDosyasi]));
  end
  else
  begin
    HataYaz(TF('ERR_GEN_AYARLANAMADI', [Oge.Ad]) + ' ' + Sonuc.Cumle, Sonuc.Ayrinti);
    if Length(Sonuc.Komutlar) = 0 then
      MesajYaz(T('MSG_PRS_DOKUNULMADI'))
    else
      MesajYaz(T('MSG_GEN_GERI_ALINDI'));
  end;
  SqlMesajiYaz(Sonuc.Komutlar);
  DurumuGuncelle;
end;

{ Generator dalina sag tik "Yeni generator": ad sorulur, net onay, CREATE SEQUENCE; dal yenilenir. }
procedure TfrmAna.YeniGeneratorAc(Dal: TTreeNode);
var
  Oge: TAgacOgesi;
  Bag: TAcikBaglanti;
  Ad: string;
  Sonuc: TProsedurSonucu;
begin
  Oge := OgeAl(Dal);
  Bag := FbAcikBaglanti(Oge.BaglantiAd);
  if Bag = nil then
    Exit;
  Ad := '';
  if not MetinSor(T('GEN_YENI_BASLIK'), T('GEN_YENI_ETIKET'), Ad, False) then
    Exit;
  Ad := AdHazirla(Ad);
  if Ad = '' then
  begin
    UyariGoster(T('ERR_GEN_AD_BOS'));
    Exit;
  end;
  if not OnayIste(TF('ONAY_GEN_YENI', [Ad])) then
  begin
    MesajYaz(T('MSG_GEN_VAZGECILDI'));
    Exit;
  end;
  Sonuc := GeneratorOlustur(Bag, Ad);
  if Sonuc.Basarili then
  begin
    MesajYaz(TF('MSG_GEN_OLUSTURULDU', [Ad]));
    DalYenile(Dal);
  end
  else
  begin
    HataYaz(TF('ERR_GEN_OLUSTURULAMADI', [Ad]) + ' ' + Sonuc.Cumle, Sonuc.Ayrinti);
    MesajYaz(T('MSG_YENI_GERI_ALINDI'));
  end;
  SqlMesajiYaz(Sonuc.Komutlar);
  DurumuGuncelle;
end;

{ Domain sag tik: varsayilan degeri, CHECK'i veya adi degistirir. Her is kucuk bir yazi penceresi (mevcut deger yazili,
  bos birakmak varsayilani/CHECK'i kaldirir) + SQL'in gorundugu net onay penceresi. }
procedure TfrmAna.DomainDegistirAc(Dugme: TTreeNode; Islem: TDomainIslemi);
const
  ONEKLER: array[TDomainIslemi] of string = ('DOM_VARSAYILAN', 'DOM_KONTROL', 'DOM_AD');
var
  Oge: TAgacOgesi;
  Bag: TAcikBaglanti;
  Deger, Komutlar: string;
  Dal: TTreeNode;
  Sonuc: TProsedurSonucu;
begin
  Oge := OgeAl(Dugme);
  Bag := FbAcikBaglanti(Oge.BaglantiAd);
  if Bag = nil then
    Exit;
  try
    Deger := DomainMevcutDeger(Bag, Oge.Ad, Islem);
  except
    on E: Exception do
    begin
      HataYaz(T('ERR_DDL_ALINAMADI') + ' ' + HataMetniniCevir(E), E.Message);
      Exit;
    end;
  end;
  if not MetinSor(TF(ONEKLER[Islem] + '_BASLIK', [Oge.Ad]), T(ONEKLER[Islem] + '_ETIKET'), Deger, False) then
    Exit;
  if (Islem = diAd) and (Trim(Deger) = '') then
  begin
    UyariGoster(T('ERR_DOM_AD_BOS'));
    Exit;
  end;
  Komutlar := DomainKomutlari(Bag, Oge.Ad, Islem, Deger);
  if not OnayIste(DomainOnayMetni(Bag, Oge.Ad, Komutlar)) then
  begin
    MesajYaz(T('MSG_DOM_VAZGECILDI'));
    Exit;
  end;
  Dal := Dugme.Parent;
  Sonuc := DomainDegistir(Bag, Oge.Ad, Islem, Deger);
  if Sonuc.Basarili then
  begin
    MesajYaz(TF('MSG_DOM_DEGISTI', [Oge.Ad]));
    MesajYaz(TF('MSG_PRS_YEDEKLENDI', [Sonuc.YedekDosyasi]));
    DalYenile(Dal);
  end
  else
  begin
    HataYaz(TF('ERR_DOM_DEGISTIRILEMEDI', [Oge.Ad]) + ' ' + Sonuc.Cumle, Sonuc.Ayrinti);
    if Length(Sonuc.Komutlar) = 0 then
      MesajYaz(T('MSG_PRS_DOKUNULMADI'))
    else
      MesajYaz(T('MSG_DOM_GERI_ALINDI'));
  end;
  SqlMesajiYaz(Sonuc.Komutlar);
  DurumuGuncelle;
end;

{ Bagli veritabaninin tum yapisini dosyaya/panoya cikaran pencereyi acar; sonucu sonuc alanina yazar. }
procedure TfrmAna.MetadataCikarAc(Dugme: TTreeNode);
var
  Bag: TAcikBaglanti;
  Sonuc: TStringList;
  Satir: string;
begin
  Bag := FbAcikBaglanti(OgeAl(Dugme).BaglantiAd);
  if Bag = nil then
    Exit;
  Sonuc := TStringList.Create;
  try
    MetadataPenceresiniGoster(Bag, Sonuc);
    for Satir in Sonuc do
      MesajYaz(Satir);
  finally
    Sonuc.Free;
  end;
end;

{ Yedek/geri yukleme penceresini acar; baglanti acik olmak zorunda degil. Sifre kayitli degilse sorulur (kaydedilmez). }
{ Sag tik > Veritabanini kopyala: yeni dosya yolu sorulur, net onay alinir, yedekle + yeni dosyaya geri yukle; istenirse yeni baglanti eklenir. }
procedure TfrmAna.VeritabaniKopyala(Dugme: TTreeNode);
var
  Ad, Sifre, YeniYol, YeniAd: string;
  Tanim: TBaglantiTanimi;
  Bag: TAcikBaglanti;
  Sonuc: TKlonSonucu;
  Ust: TTreeNode;
  Ilerleme: TfrmIlerleme;
begin
  Ad := OgeAl(Dugme).BaglantiAd;
  Bag := FbAcikBaglanti(Ad);
  if Bag <> nil then
    Tanim := Bag.Tanim
  else if not KayitliBaglantiBul(Ad, Tanim) then
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
  YeniYol := KlonYoluOner(Tanim.VeritabaniYolu);
  if not MetinSor(T('KLON_BASLIK'), T('KLON_ISTEK'), YeniYol, False) then
    Exit;
  YeniYol := Trim(YeniYol);
  if (YeniYol = '') or SameText(YeniYol, Tanim.VeritabaniYolu) then
  begin
    UyariGoster(T('ERR_KLON_AYNI_YOL'));
    Exit;
  end;
  if not OnayIste(KlonOnayMetni(Tanim, YeniYol, KlonYedekYolu(Tanim, YeniYol))) then
    Exit;
  MesajYaz(TF('MSG_KLON_BASLADI', [Ad, YeniYol]));
  Ilerleme := IlerlemeAc(T('KLON_ILERLEME_BASLIK'));
  try
    Sonuc := VeritabaniKlonla(Tanim, YeniYol, Ilerleme.Cikti, Ilerleme.AdimBildir);
  finally
    Ilerleme.Bitir;
  end;
  if Sonuc.Iptal then
  begin
    MesajYaz(T('MSG_KLON_IPTAL'));
    Exit;
  end;
  if not Sonuc.Basarili then
  begin
    HataYaz(Sonuc.Cumle, Sonuc.Ayrinti);
    UyariGoster(Sonuc.Cumle);
    Exit;
  end;
  MesajYaz(TF('MSG_KLON_TAMAM', [YeniYol]));
  MesajYaz(TF('MSG_KLON_YEDEK', [Sonuc.YedekDosya]));
  if not OnayIste(TF('KLON_BAGLANTI_SOR', [YeniYol])) then
    Exit;
  try
    YeniAd := KlonBaglantisiniEkle(Tanim, YeniYol);
    Ust := nil;
    if Tanim.Klasor <> '' then
    begin
      BaglantiKlasoruAyarla(YeniAd, Tanim.Klasor);
      Ust := KlasorDugmesiBul(Tanim.Klasor);
    end;
    tvNesneler.Selected := BaglantiDugmesiEkle(Ust, YeniAd);
    MesajYaz(TF('MSG_KLON_EKLENDI', [YeniAd]));
  except
    on E: Exception do
      KayitHatasiGoster(E);
  end;
end;

procedure TfrmAna.YedekPenceresiAc(Dugme: TTreeNode);
var
  Ad, Sifre, Satir: string;
  Tanim: TBaglantiTanimi;
  Bag: TAcikBaglanti;
  Sonuc: TStringList;
begin
  Ad := OgeAl(Dugme).BaglantiAd;
  Bag := FbAcikBaglanti(Ad);
  if Bag <> nil then
    Tanim := Bag.Tanim
  else if not KayitliBaglantiBul(Ad, Tanim) then
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
  Sonuc := TStringList.Create;
  try
    YedekPenceresiniGoster(Tanim, Sonuc);
    for Satir in Sonuc do
      MesajYaz(Satir);
  finally
    Sonuc.Free;
  end;
end;

procedure TfrmAna.SorguyuCalistir;
begin
  if AktifTopluSekme <> nil then
    AktifTopluSekme.Onizle
  else if AktifCokluSekme <> nil then
    AktifCokluSekme.Calistir
  else if AktifSorguSekmesi <> nil then
    AktifSorguSekmesi.Calistir;
end;

function TfrmAna.CokluSekmeAl(Sayfa: TTabSheet): TCokluSorguSekme;
begin
  Result := nil;
  if (Sayfa.ControlCount > 0) and (Sayfa.Controls[0] is TCokluSorguSekme) then
    Result := TCokluSorguSekme(Sayfa.Controls[0]);
end;

function TfrmAna.AktifCokluSekme: TCokluSorguSekme;
begin
  Result := nil;
  if pcCalisma.ActivePage <> nil then
    Result := CokluSekmeAl(pcCalisma.ActivePage);
end;

{ Coklu sorgu sekmesi (bir tane); aciksa one gelir. Baglanti secmek gerekmez: veritabanlari sekmede secilir. }
procedure TfrmAna.CokluSorguAc;
var
  i: Integer;
  Sayfa: TTabSheet;
  Sekme: TCokluSorguSekme;
begin
  for i := 0 to pcCalisma.PageCount - 1 do
    if CokluSekmeAl(pcCalisma.Pages[i]) <> nil then
    begin
      pcCalisma.ActivePage := pcCalisma.Pages[i];
      Exit;
    end;
  Sayfa := TTabSheet.Create(pcCalisma);
  Sayfa.PageControl := pcCalisma;
  Sayfa.ImageIndex := IKON_VERITABANI;
  Sayfa.Caption := T('COKLU_SEKME');
  Sekme := TCokluSorguSekme.Create(Sayfa);
  Sekme.Parent := Sayfa;
  Sekme.Align := alClient;
  Sekme.AnaSonuc := memSonuc.Lines;
  Sekme.Hazirla;
  pcCalisma.ActivePage := Sayfa;
end;

procedure TfrmAna.btnCokluSorguClick(Sender: TObject);
begin
  CokluSorguAc;
end;

function TfrmAna.TopluSekmeAl(Sayfa: TTabSheet): TTopluGuncelleSekme;
begin
  Result := nil;
  if (Sayfa.ControlCount > 0) and (Sayfa.Controls[0] is TTopluGuncelleSekme) then
    Result := TTopluGuncelleSekme(Sayfa.Controls[0]);
end;

function TfrmAna.AktifTopluSekme: TTopluGuncelleSekme;
begin
  Result := nil;
  if pcCalisma.ActivePage <> nil then
    Result := TopluSekmeAl(pcCalisma.ActivePage);
end;

{ Toplu guncelleme sekmesi (bir tane); aciksa one gelir. Veritabanlari sekmede secilir. }
procedure TfrmAna.TopluGuncelleAc;
var
  i: Integer;
  Sayfa: TTabSheet;
  Sekme: TTopluGuncelleSekme;
begin
  for i := 0 to pcCalisma.PageCount - 1 do
    if TopluSekmeAl(pcCalisma.Pages[i]) <> nil then
    begin
      pcCalisma.ActivePage := pcCalisma.Pages[i];
      Exit;
    end;
  Sayfa := TTabSheet.Create(pcCalisma);
  Sayfa.PageControl := pcCalisma;
  Sayfa.ImageIndex := IKON_VERITABANI;
  Sayfa.Caption := T('TOPLU_SEKME');
  Sekme := TTopluGuncelleSekme.Create(Sayfa);
  Sekme.Parent := Sayfa;
  Sekme.Align := alClient;
  Sekme.AnaSonuc := memSonuc.Lines;
  Sekme.Hazirla;
  pcCalisma.ActivePage := Sayfa;
end;

procedure TfrmAna.btnTopluGuncelleClick(Sender: TObject);
begin
  TopluGuncelleAc;
end;

function TfrmAna.FarkSekmeAl(Sayfa: TTabSheet): TSemaFarkSekme;
begin
  Result := nil;
  if (Sayfa.ControlCount > 0) and (Sayfa.Controls[0] is TSemaFarkSekme) then
    Result := TSemaFarkSekme(Sayfa.Controls[0]);
end;

{ Sema farki sekmesi (bir tane); aciksa one gelir. Veritabanlari sekmede secilir. }
procedure TfrmAna.SemaFarkiAc;
var
  i: Integer;
  Sayfa: TTabSheet;
  Sekme: TSemaFarkSekme;
begin
  for i := 0 to pcCalisma.PageCount - 1 do
    if FarkSekmeAl(pcCalisma.Pages[i]) <> nil then
    begin
      pcCalisma.ActivePage := pcCalisma.Pages[i];
      Exit;
    end;
  Sayfa := TTabSheet.Create(pcCalisma);
  Sayfa.PageControl := pcCalisma;
  Sayfa.ImageIndex := IKON_PLAN;
  Sayfa.Caption := T('FARK_SEKME');
  Sekme := TSemaFarkSekme.Create(Sayfa);
  Sekme.Parent := Sayfa;
  Sekme.Align := alClient;
  Sekme.AnaSonuc := memSonuc.Lines;
  Sekme.Hazirla;
  pcCalisma.ActivePage := Sayfa;
end;

procedure TfrmAna.btnSemaFarkiClick(Sender: TObject);
begin
  SemaFarkiAc;
end;

procedure TfrmAna.PlaniGoster;
begin
  if AktifSorguSekmesi <> nil then
    AktifSorguSekmesi.PlanGoster;
end;

procedure TfrmAna.BaglantiSekmeleriniKapat(const BaglantiAd: string);
var
  i: Integer;
  Sekme: TTabloSekme;
  SorguSekme: TSorguSekme;
  KullaniciSekme: TKullanicilar;
  ProsedurSekme: TProsedurSekme;
begin
  for i := pcCalisma.PageCount - 1 downto 0 do
  begin
    Sekme := SekmeAl(pcCalisma.Pages[i]);
    if (Sekme <> nil) and SameText(Sekme.BaglantiAd, BaglantiAd) then
      pcCalisma.Pages[i].Free
    else
    begin
      SorguSekme := SorguSekmeAl(pcCalisma.Pages[i]);
      if (SorguSekme <> nil) and SameText(SorguSekme.BaglantiAd, BaglantiAd) then
        pcCalisma.Pages[i].Free
      else
      begin
        KullaniciSekme := KullanicilarAl(pcCalisma.Pages[i]);
        if (KullaniciSekme <> nil) and SameText(KullaniciSekme.BaglantiAd, BaglantiAd) then
          pcCalisma.Pages[i].Free
        else
        begin
          ProsedurSekme := ProsedurSekmeAl(pcCalisma.Pages[i]);
          if (ProsedurSekme <> nil) and SameText(ProsedurSekme.BaglantiAd, BaglantiAd) then
            pcCalisma.Pages[i].Free;
        end;
      end;
    end;
  end;
end;

{ Ayni tablo iki ayri baglantida ayri sekmelerde acilir; ayni baglantida tekrar acilirsa o sekmeye gecilir. }
procedure TfrmAna.TabloAc(Dugme: TTreeNode);
begin
  TabloSekmesiAc(OgeAl(Dugme).BaglantiAd, OgeAl(Dugme).Ad);
end;

procedure TfrmAna.TabloSekmesiAc(const BaglantiAd, Tablo: string; const Filtre: string);
var
  Bag: TAcikBaglanti;
  Sayfa: TTabSheet;
  Sekme: TTabloSekme;
  i: Integer;
begin
  Bag := FbAcikBaglanti(BaglantiAd);
  if Bag = nil then
    Exit;
  { Filtreli acilista (iliskili kayit) her seferinde yeni sekme acilir; acik duran sekmenin filtresi bozulmasin. }
  if Filtre = '' then
    for i := 0 to pcCalisma.PageCount - 1 do
    begin
      Sekme := SekmeAl(pcCalisma.Pages[i]);
      if (Sekme <> nil) and SameText(Sekme.BaglantiAd, BaglantiAd) and (Sekme.TabloAdi = Tablo) then
      begin
        pcCalisma.ActivePage := pcCalisma.Pages[i];
        Exit;
      end;
    end;
  Sayfa := TTabSheet.Create(pcCalisma);
  Sayfa.PageControl := pcCalisma;
  Sayfa.Caption := Tablo + ' [' + BaglantiAd + ']';
  if Filtre <> '' then
    Sayfa.Caption := Sayfa.Caption + ' (' + T('LBL_FILTRELI') + ')';
  Sayfa.ImageIndex := IKON_TABLO;
  Sekme := TTabloSekme.Create(Sayfa);
  Sekme.Parent := Sayfa;
  Sekme.Align := alClient;
  Sekme.AnaSonuc := memSonuc.Lines;
  Sekme.SqlYaz := SqlMesajiYaz;
  Sekme.FiltreliAc :=
    procedure(const IliskiliTablo, IliskiliFiltre: string)
    begin
      TabloSekmesiAc(BaglantiAd, IliskiliTablo, IliskiliFiltre);
    end;
  try
    Sekme.Yukle(Bag, Tablo, Filtre);
  except
    on E: Exception do
    begin
      Sayfa.Free;
      HataYaz(TF('ERR_TABLO_ACILAMADI', [Tablo]) + ' ' + HataMetniniCevir(E), E.Message);
      Exit;
    end;
  end;
  pcCalisma.ActivePage := Sayfa;
  MesajYaz(TF('MSG_TABLO_ACILDI', [Tablo, BaglantiAd, ILK_SATIR_SAYISI]));
  DurumuGuncelle;
end;

{ ---------- Dugme ve menu olaylari ---------- }

procedure TfrmAna.btnKlonlaClick(Sender: TObject);
begin
  if SeciliBaglantiDugmesi <> nil then
    YeniBaglanti(OgeAl(SeciliBaglantiDugmesi).BaglantiAd);
end;

procedure TfrmAna.btnYeniBaglantiClick(Sender: TObject);
begin
  YeniBaglanti('');
end;

{ Tek dugme: secili baglanti kapaliysa baglanir, aciksa keser. }
procedure TfrmAna.btnBaglanClick(Sender: TObject);
var
  Dugme: TTreeNode;
begin
  Dugme := SeciliBaglantiDugmesi;
  if Dugme = nil then
    Exit;
  if FbAcikBaglanti(OgeAl(Dugme).BaglantiAd) = nil then
    BaglantiyiAc(Dugme)
  else
  begin
    BaglantiyiKapat(Dugme);
    MesajYaz(TF('MSG_KESILDI', [OgeAl(Dugme).BaglantiAd]));
    DurumuGuncelle;
  end;
end;

procedure TfrmAna.btnYeniSorguClick(Sender: TObject);
begin
  YeniSorgu;
end;

procedure TfrmAna.btnCalistirClick(Sender: TObject);
begin
  SorguyuCalistir;
end;

{ Sorgu > Index oner: aktif sorgu sekmesindeki komut icin index onerisi penceresi. }
procedure TfrmAna.btnIndeksOnerClick(Sender: TObject);
begin
  if AktifSorguSekmesi <> nil then
    AktifSorguSekmesi.IndeksOner(SqlMesajiYaz);
end;

{ Sorgu > Gecmis: SQL gecmisi ve sik kullanilan sorgular penceresi (aktif sorgu sekmesine ekler). }
procedure TfrmAna.btnGecmisClick(Sender: TObject);
begin
  if AktifSorguSekmesi <> nil then
    AktifSorguSekmesi.GecmisiAc;
end;

procedure TfrmAna.btnPlanClick(Sender: TObject);
begin
  PlaniGoster;
end;

procedure TfrmAna.btnMetadataClick(Sender: TObject);
begin
  if SeciliBaglantiDugmesi <> nil then
    MetadataCikarAc(SeciliBaglantiDugmesi);
end;

procedure TfrmAna.btnYedekClick(Sender: TObject);
begin
  if SeciliBaglantiDugmesi <> nil then
    YedekPenceresiAc(SeciliBaglantiDugmesi);
end;

{ Yonetim > Aktif baglantilar: secili (acik) baglantida kim bagli, ne calisiyor; istenirse baglanti koparilir. }
procedure TfrmAna.btnAktifBaglantiClick(Sender: TObject);
var
  Bag: TAcikBaglanti;
begin
  if SeciliBaglantiDugmesi = nil then
    Exit;
  Bag := FbAcikBaglanti(OgeAl(SeciliBaglantiDugmesi).BaglantiAd);
  if Bag <> nil then
    AktifBaglantiPenceresiniGoster(Bag, SqlMesajiYaz, memSonuc.Lines);
end;

{ Yonetim > Veritabani bakimi: once rapor (veritabanina yazmaz), sonra onayla bakim. }
procedure TfrmAna.btnBakimClick(Sender: TObject);
var
  Bag: TAcikBaglanti;
begin
  if SeciliBaglantiDugmesi = nil then
    Exit;
  Bag := FbAcikBaglanti(OgeAl(SeciliBaglantiDugmesi).BaglantiAd);
  if (Bag <> nil) and BakimPenceresiniGoster(Bag, SqlMesajiYaz, memSonuc.Lines) then
    VeritabaniKopyala(SeciliBaglantiDugmesi);
end;

procedure TfrmAna.btnKullanicilarClick(Sender: TObject);
begin
  if SeciliBaglantiDugmesi <> nil then
    KullanicilarAc(SeciliBaglantiDugmesi);
end;

{ F5: aktif sekme bir sorgu sekmesiyse calistirir (prosedur sekmesinde yalniz ipucu yazar).
  Ctrl+L: komutun planini gosterir. Ctrl+S: aktif sekme prosedur duzenleme sekmesiyse kaydeder. }
procedure TfrmAna.FormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  if Key = VK_F5 then
  begin
    Key := 0;
    if AktifProsedurSekmesi <> nil then
      AktifProsedurSekmesi.F5Ipucu
    else
      SorguyuCalistir;
  end
  else if (Key = Ord('S')) and (ssCtrl in Shift) and (AktifProsedurSekmesi <> nil) then
  begin
    Key := 0;
    AktifProsedurSekmesi.Kaydet;
  end
  else if (Key = Ord('L')) and (ssCtrl in Shift) then
  begin
    Key := 0;
    PlaniGoster;
  end;
end;

procedure TfrmAna.pcCalismaChange(Sender: TObject);
begin
  DurumuGuncelle;
end;

procedure TfrmAna.btnYenileClick(Sender: TObject);
begin
  if SeciliBaglantiDugmesi <> nil then
    AgaciYenile(SeciliBaglantiDugmesi);
end;

procedure TfrmAna.cmbDilChange(Sender: TObject);
begin
  if cmbDil.ItemIndex < 0 then
    Exit;
  DilYukle(FDilKodlari[cmbDil.ItemIndex]);
  SonKullanilanDiliKaydet;
  YazilariYenile;
end;

{ Yonetici degilse: once sorar, evet denirse yonetici olarak yeniden acar ve bu pencereyi kapatir.
  Acik baglantilar ve sekmeler kapanir, bu yuzden soru bunu yazar. }
procedure TfrmAna.btnYoneticiClick(Sender: TObject);
begin
  if YoneticiMi then
  begin
    HakkindaGoster(True);
    Exit;
  end;
  if not OnayIste(T('YONETICI_SOR')) then
    Exit;
  if YoneticiOlarakYenidenBaslat then
    Application.Terminate
  else
    UyariGoster(T('YONETICI_BASLATILAMADI'));
end;

procedure TfrmAna.tvNesnelerChange(Sender: TObject; Node: TTreeNode);
begin
  DurumuGuncelle;
end;

{ Pasif tetikleyici adi agacta soluk (ve secili degilse) cizilir; baska dugume dokunulmaz. }
procedure TfrmAna.tvNesnelerCustomDrawItem(Sender: TCustomTreeView; Node: TTreeNode; State: TCustomDrawState;
  var DefaultDraw: Boolean);
begin
  if (OgeAl(Node) <> nil) and OgeAl(Node).Pasif and not (cdsSelected in State) then
    Sender.Canvas.Font.Color := clGrayText;
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
    TabloAc(Dugme)
  else if (OgeAl(Dugme).Tur = atDal) and (OgeAl(Dugme).DalNo = DAL_TABLO) then
    TabloListesiAc(Dugme);
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
  if (Dugme <> nil) and (OgeAl(Dugme).Tur in [atBaglanti, atKlasor]) then
  begin
    FSurukleNode := Dugme;
    tvNesneler.BeginDrag(False, 5);
  end;
end;

{ Baglanti ya da klasor bir klasorun ustune birakilabilir. Bos alana birakilirsa kok duzeye cikar.
  Klasor kendi icine ya da altindaki bir klasorun icine birakilamaz. }
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
    Accept := (OgeAl(Hedef).Tur = atKlasor) and (FSurukleNode.Parent <> Hedef) and not DugumAltindaMi(Hedef, FSurukleNode);
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
    if OgeAl(FSurukleNode).Tur = atKlasor then
      KlasorUstuAyarla(OgeAl(FSurukleNode).Ad, KlasorAdi)
    else
      BaglantiKlasoruAyarla(OgeAl(FSurukleNode).BaglantiAd, KlasorAdi);
  except
    on E: Exception do
    begin
      KayitHatasiGoster(E);
      FSurukleNode := nil;
      Exit;
    end;
  end;
  DugumuTasi(FSurukleNode, Hedef);
  if Hedef <> nil then
    Hedef.Expand(False);
  FSurukleNode := nil;
end;

{ Sag tik menusu: tiklanan dugume gore sadece ilgili maddeler gorunur. }
procedure TfrmAna.pmNesnePopup(Sender: TObject);
var
  Nokta: TPoint;
  Dugme: TTreeNode;
  Tur: TAgacTuru;
  Bos, Acik, Uretilebilir: Boolean;
begin
  Nokta := tvNesneler.ScreenToClient(Mouse.CursorPos);
  if PtInRect(tvNesneler.ClientRect, Nokta) then
    Dugme := tvNesneler.GetNodeAt(Nokta.X, Nokta.Y)
  else
    Dugme := tvNesneler.Selected;
  Bos := Dugme = nil;
  Tur := atKlasor;
  Acik := False;
  { Bos alana sag tik secimi kaldirir: "Yeni klasor" kok duzeye eklesin, eski secili klasorun icine degil. }
  if Bos then
    tvNesneler.Selected := nil;
  if not Bos then
  begin
    tvNesneler.Selected := Dugme;
    Tur := OgeAl(Dugme).Tur;
    if Tur <> atKlasor then
      Acik := FbAcikBaglanti(OgeAl(Dugme).BaglantiAd) <> nil;
  end;
  { Bos alanda "Yeni klasor", klasore sag tikta "Alt klasor ekle" (klasorun icine). }
  miYeniKlasor.Visible := Bos or (Tur = atKlasor);
  if Bos then
    miYeniKlasor.Caption := T('BTN_YENI_KLASOR')
  else
    miYeniKlasor.Caption := T('MENU_ALT_KLASOR');
  miKlasorAdi.Visible := (not Bos) and (Tur = atKlasor);
  miKlasorKaldir.Visible := (not Bos) and (Tur = atKlasor);
  miBaglan.Visible := (not Bos) and (Tur = atBaglanti);
  miKes.Visible := (not Bos) and (Tur = atBaglanti);
  miDuzenle.Visible := (not Bos) and (Tur = atBaglanti);
  miKaldir.Visible := (not Bos) and (Tur = atBaglanti);
  miMetadataCikar.Visible := (not Bos) and (Tur = atBaglanti) and Acik;
  miYedek.Visible := (not Bos) and (Tur = atBaglanti);
  miKlonla.Visible := (not Bos) and (Tur = atBaglanti);
  miVeritabaniKopyala.Visible := (not Bos) and (Tur = atBaglanti);
  miAc.Visible := (not Bos) and (Tur = atNesne) and (OgeAl(Dugme).DalNo = DAL_TABLO);
  miBagimliliklar.Visible := miAc.Visible;
  { DDL tetikleyicisinde (script uretilmeyen tur) Script uret ve Duzenle gizlenir; Yenile kalir. }
  Uretilebilir := (not Bos) and (Tur = atNesne) and not OgeAl(Dugme).Duzenlenemez;
  miScriptUret.Visible := Uretilebilir;
  { Yetkiler: tablo, view ve prosedur (kimde ne yetkisi var, ver / geri al). }
  miYetkiler.Visible := Uretilebilir and (OgeAl(Dugme).DalNo in [DAL_TABLO, DAL_VIEW, DAL_PROSEDUR]);
  miNesneDuzenle.Visible := Uretilebilir and (OgeAl(Dugme).DalNo in [DAL_VIEW, DAL_PROSEDUR, DAL_TETIKLEYICI, DAL_ISTISNA]);
  { Domain: CREATE OR ALTER yok; yalniz uc kucuk is (varsayilan, CHECK, ad). Sil: view, exception, domain, generator. }
  miDomVarsayilan.Visible := Uretilebilir and (OgeAl(Dugme).DalNo = DAL_DOMAIN);
  miDomKontrol.Visible := miDomVarsayilan.Visible;
  miDomAd.Visible := miDomVarsayilan.Visible;
  miNesneSil.Visible := Uretilebilir and (OgeAl(Dugme).DalNo in [DAL_TABLO, DAL_VIEW, DAL_DOMAIN, DAL_ISTISNA, DAL_GENERATOR]);
  miTabloBosalt.Visible := Uretilebilir and (OgeAl(Dugme).DalNo = DAL_TABLO);
  miTabloKopyala.Visible := miTabloBosalt.Visible;
  { Dala sag tik: yeni exception / domain. }
  miYeniNesne.Visible := (not Bos) and (Tur = atDal) and Acik and (OgeAl(Dugme).DalNo in [DAL_TABLO, DAL_DOMAIN, DAL_ISTISNA, DAL_GENERATOR]);
  miYeniTabloTasarim.Visible := miYeniNesne.Visible and (OgeAl(Dugme).DalNo = DAL_TABLO);
  if miYeniNesne.Visible then
    case OgeAl(Dugme).DalNo of
      DAL_TABLO: miYeniNesne.Caption := T('MENU_YENI_TABLO');
      DAL_DOMAIN: miYeniNesne.Caption := T('MENU_YENI_DOMAIN');
      DAL_ISTISNA: miYeniNesne.Caption := T('MENU_YENI_ISTISNA');
    else
      miYeniNesne.Caption := T('MENU_YENI_GENERATOR');
    end;
  miGenDeger.Visible := Uretilebilir and (OgeAl(Dugme).DalNo = DAL_GENERATOR);
  miYenile.Visible := (not Bos) and (Tur <> atKlasor) and Acik;
  miBaglan.Enabled := not Acik;
  miKes.Enabled := Acik;
end;

procedure TfrmAna.miAcClick(Sender: TObject);
begin
  if tvNesneler.Selected <> nil then
    TabloAc(tvNesneler.Selected);
end;

{ Secili tablo / view / prosedurun yetkiler penceresi. }
procedure TfrmAna.miYetkilerClick(Sender: TObject);
var
  Oge: TAgacOgesi;
  Bag: TAcikBaglanti;
  Tur: TYetkiNesnesi;
begin
  if tvNesneler.Selected = nil then
    Exit;
  Oge := OgeAl(tvNesneler.Selected);
  Bag := FbAcikBaglanti(Oge.BaglantiAd);
  if Bag = nil then
    Exit;
  if Oge.DalNo = DAL_PROSEDUR then
    Tur := ynProsedur
  else
    Tur := ynTablo;
  YetkiPenceresiniGoster(Bag, ykNesne, Oge.Ad, Tur, memSonuc.Lines, SqlMesajiYaz);
end;

{ Tabloyu acar ve "Bagimliliklar" alt sekmesini one getirir. }
procedure TfrmAna.miBagimliliklarClick(Sender: TObject);
var
  Sekme: TTabloSekme;
begin
  if tvNesneler.Selected = nil then
    Exit;
  TabloAc(tvNesneler.Selected);
  Sekme := SekmeAl(pcCalisma.ActivePage);
  if Sekme <> nil then
    Sekme.BagimliliklariGoster;
end;

procedure TfrmAna.miScriptUretClick(Sender: TObject);
begin
  if tvNesneler.Selected <> nil then
    ScriptAc(tvNesneler.Selected);
end;

procedure TfrmAna.miNesneDuzenleClick(Sender: TObject);
begin
  if tvNesneler.Selected <> nil then
    NesneDuzenleAc(tvNesneler.Selected);
end;

procedure TfrmAna.miYeniNesneClick(Sender: TObject);
begin
  if (tvNesneler.Selected <> nil) and (OgeAl(tvNesneler.Selected).Tur = atDal) then
  begin
    if OgeAl(tvNesneler.Selected).DalNo = DAL_GENERATOR then
      YeniGeneratorAc(tvNesneler.Selected)
    else
      YeniNesneAc(tvNesneler.Selected);
  end;
end;

procedure TfrmAna.miGenDegerClick(Sender: TObject);
begin
  if tvNesneler.Selected <> nil then
    GeneratorDegeriAc(tvNesneler.Selected);
end;

procedure TfrmAna.miDomVarsayilanClick(Sender: TObject);
begin
  if tvNesneler.Selected <> nil then
    DomainDegistirAc(tvNesneler.Selected, diVarsayilan);
end;

procedure TfrmAna.miDomKontrolClick(Sender: TObject);
begin
  if tvNesneler.Selected <> nil then
    DomainDegistirAc(tvNesneler.Selected, diKontrol);
end;

procedure TfrmAna.miDomAdClick(Sender: TObject);
begin
  if tvNesneler.Selected <> nil then
    DomainDegistirAc(tvNesneler.Selected, diAd);
end;

procedure TfrmAna.miNesneSilClick(Sender: TObject);
begin
  if tvNesneler.Selected <> nil then
    NesneyiSil(tvNesneler.Selected);
end;

procedure TfrmAna.miYeniTabloTasarimClick(Sender: TObject);
begin
  if tvNesneler.Selected <> nil then
    TabloyuTasarla(tvNesneler.Selected);
end;

procedure TfrmAna.miTabloKopyalaClick(Sender: TObject);
begin
  if tvNesneler.Selected <> nil then
    TabloyuKopyala(tvNesneler.Selected);
end;

procedure TfrmAna.miTabloBosaltClick(Sender: TObject);
begin
  if tvNesneler.Selected <> nil then
    TabloyuBosalt(tvNesneler.Selected);
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

procedure TfrmAna.miMetadataCikarClick(Sender: TObject);
begin
  if SeciliBaglantiDugmesi <> nil then
    MetadataCikarAc(SeciliBaglantiDugmesi);
end;

procedure TfrmAna.miVeritabaniKopyalaClick(Sender: TObject);
begin
  if SeciliBaglantiDugmesi <> nil then
    VeritabaniKopyala(SeciliBaglantiDugmesi);
end;

procedure TfrmAna.miYedekClick(Sender: TObject);
begin
  if SeciliBaglantiDugmesi <> nil then
    YedekPenceresiAc(SeciliBaglantiDugmesi);
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

procedure TfrmAna.miSekmeYenileClick(Sender: TObject);
var
  Sayfa: TTabSheet;
begin
  Sayfa := pcCalisma.ActivePage;
  if Sayfa = nil then
    Exit;
  if SekmeAl(Sayfa) <> nil then
    SekmeAl(Sayfa).Yenile
  else if ListeSekmeAl(Sayfa) <> nil then
    ListeSekmeAl(Sayfa).Yenile
  else if KullanicilarAl(Sayfa) <> nil then
    KullanicilarAl(Sayfa).Yenile;
  MesajYaz(T('MSG_SEKME_YENILENDI'));
end;

procedure TfrmAna.miTumSekmeleriKapatClick(Sender: TObject);
begin
  TumSekmeleriKapat;
end;

{ Sag tik menusu: Yenile yalniz verisi olan sekmelerde (tablo, tablo listesi, kullanicilar) acik olur. }
procedure TfrmAna.pmSekmePopup(Sender: TObject);
var
  Sayfa: TTabSheet;
begin
  Sayfa := pcCalisma.ActivePage;
  miSekmeKapat.Enabled := Sayfa <> nil;
  miTumSekmeleriKapat.Enabled := pcCalisma.PageCount > 0;
  miSekmeYenile.Enabled := (Sayfa <> nil) and
    ((SekmeAl(Sayfa) <> nil) or (ListeSekmeAl(Sayfa) <> nil) or (KullanicilarAl(Sayfa) <> nil));
end;

{ Sag tikla basligina basilan sekme secilir; menu o sekme icin calisir. }
procedure TfrmAna.pcCalismaMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
var
  Sira: Integer;
begin
  if Button <> mbRight then
    Exit;
  Sira := pcCalisma.IndexOfTabAt(X, Y);
  if Sira >= 0 then
    pcCalisma.ActivePageIndex := Sira;
end;

{ Fare bir baglantinin ustune gelince veritabani yolu ipucu olarak gorunur. }
procedure TfrmAna.tvNesnelerMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
var
  Dugme: TTreeNode;
  Tanim: TBaglantiTanimi;
  Yol: string;
begin
  Dugme := tvNesneler.GetNodeAt(X, Y);
  if Dugme = FHintDugum then
    Exit;
  FHintDugum := Dugme;
  Yol := '';
  if (Dugme <> nil) and (OgeAl(Dugme).Tur = atBaglanti) and KayitliBaglantiBul(OgeAl(Dugme).BaglantiAd, Tanim) then
    Yol := BaglantiYolu(Tanim);
  tvNesneler.Hint := Yol;
  Application.CancelHint;
end;

function TfrmAna.ListeSekmeAl(Sayfa: TTabSheet): TTabloListeSekme;
begin
  Result := nil;
  if (Sayfa.ControlCount > 0) and (Sayfa.Controls[0] is TTabloListeSekme) then
    Result := TTabloListeSekme(Sayfa.Controls[0]);
end;

{ "Tablolar" dalina cift tiklayinca: o baglantinin tum tablolari liste sekmesinde acilir (aciksa one gelir). }
procedure TfrmAna.TabloListesiAc(Dugme: TTreeNode);
var
  Ad: string;
  Bag: TAcikBaglanti;
  Sayfa: TTabSheet;
  Sekme: TTabloListeSekme;
  i: Integer;
begin
  Ad := OgeAl(Dugme).BaglantiAd;
  Bag := FbAcikBaglanti(Ad);
  if Bag = nil then
    Exit;
  for i := 0 to pcCalisma.PageCount - 1 do
  begin
    Sekme := ListeSekmeAl(pcCalisma.Pages[i]);
    if (Sekme <> nil) and SameText(Sekme.BaglantiAd, Ad) then
    begin
      pcCalisma.ActivePage := pcCalisma.Pages[i];
      Exit;
    end;
  end;
  Sayfa := TTabSheet.Create(pcCalisma);
  Sayfa.PageControl := pcCalisma;
  Sayfa.ImageIndex := IKON_TABLO;
  Sayfa.Caption := TF('LISTE_SEKME', [Ad]);
  Sekme := TTabloListeSekme.Create(Sayfa);
  Sekme.Parent := Sayfa;
  Sekme.Align := alClient;
  Sekme.AyrintiAyarla(FAyrintiAcik);
  Sekme.TabloAc :=
    procedure(Tablo: string)
    begin
      TabloSekmesiAc(Ad, Tablo);
    end;
  try
    Sekme.Yukle(Bag);
  except
    on E: Exception do
    begin
      Sayfa.Free;
      HataYaz(TF('ERR_LISTE_ACILAMADI', [Ad]) + ' ' + HataMetniniCevir(E), E.Message);
      Exit;
    end;
  end;
  Sekme.YazilariYenile;
  pcCalisma.ActivePage := Sayfa;
  DurumuGuncelle;
end;

{ Tum sekmeleri kapatir; acik sorgu metni ve duzenlemeler kaybolacagi icin once sorar. }
procedure TfrmAna.TumSekmeleriKapat;
begin
  if pcCalisma.PageCount = 0 then
    Exit;
  if not OnayIste(T('SEKME_TUMU_SOR')) then
    Exit;
  while pcCalisma.PageCount > 0 do
    pcCalisma.Pages[0].Free;
  DurumuGuncelle;
end;

{ Gorunum sekmesi tek dugme: ayrinti aciksa yazisi "kapat", kapaliysa "goster" olur. }
procedure TfrmAna.AyrintiDugmesiniYaz;
begin
  if FAyrintiAcik then
    btnAyrinti.Ayarla('BTN_AYRINTI_KAPAT', IKON_VIEW)
  else
    btnAyrinti.Ayarla('BTN_AYRINTI_GOSTER', IKON_VIEW);
end;

procedure TfrmAna.btnAyrintiClick(Sender: TObject);
var
  i: Integer;
  Sekme: TTabloListeSekme;
begin
  FAyrintiAcik := not FAyrintiAcik;
  for i := 0 to pcCalisma.PageCount - 1 do
  begin
    Sekme := ListeSekmeAl(pcCalisma.Pages[i]);
    if Sekme <> nil then
      Sekme.AyrintiAyarla(FAyrintiAcik);
  end;
  AyrintiDugmesiniYaz;
end;

procedure TfrmAna.btnTumKapatClick(Sender: TObject);
begin
  TumSekmeleriKapat;
end;

end.
