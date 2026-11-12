{ fTabloSekme.pas - Bir tablo sekmesinin icerigi: ustte kolonlar, altta ilk satirlar.
  Frame sadece arayuzu bilir; isi uMetadata ve uSorgu yapar. }
unit fTabloSekme;

interface

uses
  System.SysUtils, System.Classes, System.Types, Data.DB, Vcl.Controls, Vcl.Forms, Vcl.ExtCtrls,
  Vcl.StdCtrls, Vcl.Grids, Vcl.DBGrids, Vcl.ComCtrls, Vcl.Menus, FireDAC.Comp.Client,
  uDil, uOnay, uBaglanti, uMetadata, uSorgu, uFiltre, uFiltreSatiri, uSonucGrid, uKayitDuzelt, uKullanici, uProsedur, uKolon, uIndeksKisit, fKolonIslem, fYapiIslem, fCsvAktar, fIceAktar, uIliski, fKullananlar;

type
  { Bir tabloyu hazir filtreyle yeni sekmede acar (iliskili kayitlara git). }
  TFiltreliTabloAc = reference to procedure(const Tablo, Filtre: string);

  { Yalniz gridin korumali "Row" ozelligini okumak icin (sag tikla hangi satirda oldugumuzu bulmak). }
  TGridErisim = class(TDBGrid);

  TTabloSekme = class(TFrame)
    pnlKolonlar: TPanel;
    pcYapi: TPageControl;
    tsKolonlar: TTabSheet;
    pnlKolonDugme: TPanel;
    btnKolonEkle: TButton;
    btnKolonAd: TButton;
    btnKolonDegistir: TButton;
    btnKolonSil: TButton;
    btnKolonPk: TButton;
    gridKolonlar: TDBGrid;
    tsIndeksler: TTabSheet;
    pnlIndeksDugme: TPanel;
    btnIndeksOlustur: TButton;
    btnIndeksSil: TButton;
    btnIndeksDurum: TButton;
    gridIndeksler: TDBGrid;
    tsKisitlar: TTabSheet;
    pnlKisitDugme: TPanel;
    btnKisitEkle: TButton;
    btnKisitSil: TButton;
    gridKisitlar: TDBGrid;
    tsBagimliliklar: TTabSheet;
    gridBagimliliklar: TDBGrid;
    Bolucu: TSplitter;
    pnlVeri: TPanel;
    pnlVeriBaslik: TPanel;
    lblVeri: TLabel;
    btnDisaAktar: TButton;
    btnDuzenle: TButton;
    btnIceAktar: TButton;
    btnYeniKayit: TButton;
    btnSil: TButton;
    btnKaydet: TButton;
    btnGeriAl: TButton;
    edtFiltre: TEdit;
    btnFiltreKaldir: TButton;
    gridVeri: TDBGrid;
    pmVeri: TPopupMenu;
    miFEsit: TMenuItem;
    miFFarkli: TMenuItem;
    miFBuyuk: TMenuItem;
    miFKucuk: TMenuItem;
    miFIceren: TMenuItem;
    miFBos: TMenuItem;
    miFTemizle: TMenuItem;
    miGit: TMenuItem;
    miKullananlar: TMenuItem;
    miOzet: TMenuItem;
    dsKolonlar: TDataSource;
    dsVeri: TDataSource;
    dsIndeksler: TDataSource;
    dsKisitlar: TDataSource;
    dsBagimliliklar: TDataSource;
    procedure btnDisaAktarClick(Sender: TObject);
    procedure btnDuzenleClick(Sender: TObject);
    procedure btnIceAktarClick(Sender: TObject);
    procedure btnYeniKayitClick(Sender: TObject);
    procedure btnSilClick(Sender: TObject);
    procedure btnKaydetClick(Sender: TObject);
    procedure btnGeriAlClick(Sender: TObject);
    procedure btnKolonEkleClick(Sender: TObject);
    procedure btnKolonAdClick(Sender: TObject);
    procedure btnKolonDegistirClick(Sender: TObject);
    procedure btnKolonSilClick(Sender: TObject);
    procedure btnKolonPkClick(Sender: TObject);
    procedure btnIndeksOlusturClick(Sender: TObject);
    procedure btnIndeksSilClick(Sender: TObject);
    procedure btnIndeksDurumClick(Sender: TObject);
    procedure btnKisitEkleClick(Sender: TObject);
    procedure btnKisitSilClick(Sender: TObject);
    procedure dsVeriDataChange(Sender: TObject; Field: TField);
    procedure btnFiltreKaldirClick(Sender: TObject);
    procedure edtFiltreKeyPress(Sender: TObject; var Key: Char);
    procedure pmVeriPopup(Sender: TObject);
    procedure miFiltreClick(Sender: TObject);
    procedure miGitClick(Sender: TObject);
    procedure miKullananlarClick(Sender: TObject);
    procedure miOzetClick(Sender: TObject);
  private
    FVeriGrid: TSonucGrid;
    { Nil degilse kayit duzeltme kipi acik (Asama 4d). }
    FDuzelt: TKayitDuzelt;
    { Veri gridinin satir siniri (100'er artar), sunucu siralamasi ve bekleyen "devam yukle" istegi. }
    FSatirLimit: Integer;
    FSiraAlan: string;
    FSiraAzalan: Boolean;
    { Uygulanan WHERE kosulu ('' = filtre yok): filtre kutusundan ya da hucreye sag tikla gelir. }
    FFiltre: string;
    { Kolon altindaki filtre kutularindan gelen kosul; FFiltre ile VE ile birlesir. }
    FSatirKosulu: string;
    FSatir: TFiltreSatiri;
    { Sag tiklanan hucrenin kolon adi ('' = hucre disinda). }
    FHucreAlan: string;
    FDevamBekliyor: Boolean;
    { Tablonun kisitlari (ilk ihtiyacta okunur, yapi degisince/yenilenince sifirlanir) ve sag tiklanan hucrenin bagli kaydi. }
    FKisitlar: TArray<TKisitBilgisi>;
    FKisitlarOkundu: Boolean;
    FBagliKayit: TIliskiliKayit;
    { Baslik satirina sag tiklanan kolonun adi ('' = baslik disinda): kolon ozeti icin. }
    FOzetAlan: string;
    procedure Yaz(const Metin: string);
    function TamFiltre: string;
    procedure FiltreDegistir(const YeniElle, YeniSatir: string);
    procedure FiltreyiUygula(const Yeni: string);
    procedure FiltreSatiriDegisti(Sender: TObject);
    procedure FiltreOnerisiIste(const AlanAdi, Yazi: string; Sonuc: TStrings);
    procedure FiltreKutusunuAyarla;
    function KisitlariAl: TArray<TKisitBilgisi>;
    procedure IliskiyiAc(const Kayit: TIliskiliKayit);
    procedure VeriyiYukle(Bag: TAcikBaglanti);
    procedure VeriyiSirala(const Alan: string; Azalan: Boolean);
    function VeriyiOku(Bag: TAcikBaglanti): Boolean;
    procedure DevamiYukle;
    procedure DuzenlemeyiAc;
    procedure DuzenlemeyiKapat;
    procedure DuzenlemeDurumunuYaz;
    function BekleyenAtilsinMi: Boolean;
    function BaglantiAl: TAcikBaglanti;
    procedure SonucuBildir(Bag: TAcikBaglanti; const Sonuc: TProsedurSonucu);
    procedure KolonIsle(Islem: TKolonIslemi);
    procedure IndeksIsle(Islem: TYapiIslemi);
    procedure KisitIsle(Islem: TYapiIslemi);
    procedure YenidenYukle(Bag: TAcikBaglanti);
    procedure YapiyiYukle(Bag: TAcikBaglanti);
    procedure YapiAlanYazilari(Kaynak: TDataSource; const Anahtarlar: array of string);
  public
    BaglantiAd: string;
    TabloAdi: string;
    { Disa aktarma ozeti buraya (ana pencerenin sonuc alani) yazilir; ana pencere atar. }
    AnaSonuc: TStrings;
    { Yonetim islemlerinin SQL'i buraya verilir (ana pencerenin SQL mesaji); ana pencere atar. }
    SqlYaz: TSqlGoster;
    { Iliskili kayda gitmek icin: ana pencere tabloyu filtreli yeni sekmede acar; ana pencere atar. }
    FiltreliAc: TFiltreliTabloAc;
    destructor Destroy; override;
    { Filtre doluysa tablo bu WHERE kosuluyla acilir (iliskili kayitlar). }
    procedure Yukle(Bag: TAcikBaglanti; const Tablo: string; const Filtre: string = '');
    { Sag tik "Yenile": kolonlar, yapi ve ilk satirlar veritabanindan yeniden okunur. }
    procedure Yenile;
    procedure YazilariYenile;
    { Sag tik "Bagimliliklar": ustteki alt sekmeyi Bagimliliklar'a getirir. }
    procedure BagimliliklariGoster;
  end;

implementation

{$R *.dfm}

procedure TTabloSekme.Yukle(Bag: TAcikBaglanti; const Tablo: string; const Filtre: string);
begin
  BaglantiAd := Bag.Tanim.Ad;
  TabloAdi := Tablo;
  FFiltre := Filtre;
  FVeriGrid := TSonucGrid.Create(gridVeri);
  FVeriGrid.OnSunucuSirala := VeriyiSirala;
  FSatir := TFiltreSatiri.Create(gridVeri, FiltreSatiriDegisti);
  FSatir.OnOneri := FiltreOnerisiIste;
  YenidenYukle(Bag);
  edtFiltre.Text := FFiltre;
  btnFiltreKaldir.Visible := TamFiltre <> '';
  btnDisaAktar.Enabled := True;
  btnDuzenle.Enabled := True;
  btnIceAktar.Enabled := True;
end;

destructor TTabloSekme.Destroy;
begin
  FSatir.Free;
  FDuzelt.Free;
  inherited;
end;

procedure TTabloSekme.Yenile;
var
  Bag: TAcikBaglanti;
begin
  Bag := FbAcikBaglanti(BaglantiAd);
  if Bag = nil then
    Exit;
  if (FDuzelt <> nil) and not BekleyenAtilsinMi then
    Exit;
  DuzenlemeyiKapat;
  YenidenYukle(Bag);
end;

{ Kolonlar, yapi sekmeleri ve ilk satirlar bastan okunur (acilista ve kolon islemlerinden sonra). }
procedure TTabloSekme.YenidenYukle(Bag: TAcikBaglanti);
begin
  FKisitlarOkundu := False;
  dsKolonlar.DataSet.Free;
  dsKolonlar.DataSet := KolonTablosuOlustur(Bag, TabloAdi, Self);
  YapiyiYukle(Bag);
  VeriyiYukle(Bag);
  YazilariYenile;
end;

{ Yalniz alttaki veri gridi: ilk satirlar salt okunur olarak yeniden okunur. }
procedure TTabloSekme.VeriyiYukle(Bag: TAcikBaglanti);
begin
  FSatirLimit := ILK_SATIR_SAYISI;
  FSiraAlan := '';
  FSiraAzalan := False;
  VeriyiOku(Bag);
end;

{ Veri gridinde baslik tiklaninca: siralama SUNUCUDA yapilir (ORDER BY), boylece tablonun tamami
  siralanir ve ilk 100 satir o siraya gore gelir; yalniz ekrandaki 100 satir degil. }
procedure TTabloSekme.VeriyiSirala(const Alan: string; Azalan: Boolean);
var
  Bag: TAcikBaglanti;
begin
  Bag := BaglantiAl;
  if Bag = nil then
    Exit;
  FSatirLimit := ILK_SATIR_SAYISI;
  FSiraAlan := Alan;
  FSiraAzalan := Azalan;
  VeriyiOku(Bag);
end;

{ Verisetini o anki satir siniri ve siralamayla yeniden okur. Her seferinde okuma biter ve
  sunucuda acik kalmaz (yapi islemleri tabloyu kullanimda bulmasin). }
function TTabloSekme.VeriyiOku(Bag: TAcikBaglanti): Boolean;
begin
  Result := False;
  try
    dsVeri.DataSet.Free;
    dsVeri.DataSet := TabloVerisiSorgusu(Bag, TabloAdi, FSatirLimit, Self, FSiraAlan, FSiraAzalan, TamFiltre);
  except
    on E: Exception do
    begin
      dsVeri.DataSet := nil;
      UyariGoster(HataMetniniCevir(E));
      Exit;
    end;
  end;
  FVeriGrid.YeniSonuc(FSiraAlan, FSiraAzalan);
  FSatir.Esitle;
  DuzenlemeDurumunuYaz;
  Result := True;
end;

{ Sorguya giren tam filtre: ustteki kutu (ve sag tik) ile kolon altindaki kutularin kosullari VE ile birlesir. }
function TTabloSekme.TamFiltre: string;
begin
  Result := FiltreBirlestir(FFiltre, FSatirKosulu);
end;

{ Filtreyi degistirir ve veriyi yeniden okur: kosul sunucuda WHERE olarak calisir. Hatali kosulda hata gosterilir ve
  onceki gorunum geri gelir (kutudaki yazi duzeltilsin diye kalir). Duzenleme kipinde kutular kapalidir. }
procedure TTabloSekme.FiltreDegistir(const YeniElle, YeniSatir: string);
var
  Bag: TAcikBaglanti;
  EskiElle, EskiSatir, Sql: string;
begin
  Bag := BaglantiAl;
  if (Bag = nil) or (FDuzelt <> nil) then
    Exit;
  EskiElle := FFiltre;
  EskiSatir := FSatirKosulu;
  FFiltre := Trim(YeniElle);
  FSatirKosulu := YeniSatir;
  FSatirLimit := ILK_SATIR_SAYISI;
  Sql := TabloVerisiSql(TabloAdi, FSatirLimit, FSiraAlan, FSiraAzalan, TamFiltre);
  if VeriyiOku(Bag) then
    edtFiltre.Text := FFiltre
  else
  begin
    FFiltre := EskiElle;
    FSatirKosulu := EskiSatir;
    VeriyiOku(Bag);
  end;
  btnFiltreKaldir.Visible := TamFiltre <> '';
  { SQL karsiligi (CLAUDE.md): calisan komut alt mesaj alaninda gorunur; hata olunca da denenen komut. }
  if Assigned(SqlYaz) then
    SqlYaz([StringReplace(Sql, sLineBreak, ' ', [rfReplaceAll])]);
end;

procedure TTabloSekme.FiltreyiUygula(const Yeni: string);
begin
  FiltreDegistir(Yeni, FSatirKosulu);
end;

{ Kolon altindaki bir kutuya Enter basildi ya da yazmak birakildi. Gecersiz yazida kutu kirmizi olur, sorgu calismaz. }
procedure TTabloSekme.FiltreSatiriDegisti(Sender: TObject);
var
  Kosul, Hata: string;
begin
  Kosul := FSatir.Kosul(Hata);
  if (Hata <> '') or (Kosul = FSatirKosulu) then
    Exit;
  FiltreDegistir(FFiltre, Kosul);
end;

{ Kolon kutusuna yazarken: o kolonun mevcut degerlerinden en cok 10 tanesi (uSorgu.AlanDegerleri). Baska kolonlarin ve
  ustteki kutunun filtresi de sayilir, boylece yalniz gorunecek satirlardaki degerler onerilir. Yazi hatali ise oneri yok. }
procedure TTabloSekme.FiltreOnerisiIste(const AlanAdi, Yazi: string; Sonuc: TStrings);
var
  Bag: TAcikBaglanti;
  Diger, Hata, Deger: string;
begin
  Bag := BaglantiAl;
  if (Bag = nil) or (FDuzelt <> nil) then
    Exit;
  Diger := FSatir.Kosul(Hata, AlanAdi);
  if Hata <> '' then
    Exit;
  for Deger in AlanDegerleri(Bag, TabloAdi, AlanAdi, Yazi, FiltreBirlestir(FFiltre, Diger), ONERI_ADET) do
    Sonuc.Add(Deger);
end;

procedure TTabloSekme.FiltreKutusunuAyarla;
begin
  edtFiltre.Enabled := FDuzelt = nil;
  btnFiltreKaldir.Enabled := FDuzelt = nil;
  FSatir.Etkin(FDuzelt = nil);
end;

procedure TTabloSekme.btnFiltreKaldirClick(Sender: TObject);
begin
  FSatir.Temizle;
  FiltreDegistir('', '');
end;

{ Sag tik menusu: tiklanan hucreyi bulur (imleci oraya koyar) ve degerine uyan secenekleri gosterir.
  Menu en fazla 6 satirdir: yazida Esit / Farkli / Iceren / Bos, sayi ve tarihte Esit / Farkli / Buyuk / Kucuk / Bos. }
procedure TTabloSekme.pmVeriPopup(Sender: TObject);
var
  Nokta: TPoint;
  Koordinat: TGridCoord;
  Alan: TField;
  Bos: Boolean;
begin
  FHucreAlan := '';
  FBagliKayit := Default(TIliskiliKayit);
  Alan := nil;
  Nokta := gridVeri.ScreenToClient(Mouse.CursorPos);
  Koordinat := gridVeri.MouseCoord(Nokta.X, Nokta.Y);
  if (FDuzelt = nil) and (dsVeri.DataSet <> nil) and dsVeri.DataSet.Active and (Koordinat.Y > 0) and
    (Koordinat.X > 0) and (Koordinat.X <= gridVeri.Columns.Count) then
  begin
    { Imlec kaydirilirken "devam yukle" tetiklenmesin. }
    FDevamBekliyor := True;
    try
      dsVeri.DataSet.MoveBy(Koordinat.Y - TGridErisim(gridVeri).Row);
    finally
      FDevamBekliyor := False;
    end;
    Alan := dsVeri.DataSet.FindField(gridVeri.Columns[Koordinat.X - 1].FieldName);
    if (Alan <> nil) and FiltreyeUygunMu(Alan) then
      FHucreAlan := Alan.FieldName
    else
      Alan := nil;
  end;
  Bos := (Alan <> nil) and Alan.IsNull;
  miFEsit.Caption := T('FILTRE_ESIT');
  miFFarkli.Caption := T('FILTRE_FARKLI');
  miFBuyuk.Caption := T('FILTRE_BUYUK');
  miFKucuk.Caption := T('FILTRE_KUCUK');
  miFIceren.Caption := T('FILTRE_ICEREN');
  if Bos then
    miFBos.Caption := T('FILTRE_BOS_DEGIL')
  else
    miFBos.Caption := T('FILTRE_BOS');
  miFTemizle.Caption := T('FILTRE_TEMIZLE');
  miFEsit.Visible := (Alan <> nil) and not Bos;
  miFFarkli.Visible := (Alan <> nil) and not Bos;
  miFBuyuk.Visible := (Alan <> nil) and not Bos and SiralanabilirMi(Alan);
  miFKucuk.Visible := miFBuyuk.Visible;
  miFIceren.Visible := (Alan <> nil) and not Bos and MetinAlaniMi(Alan);
  miFBos.Visible := Alan <> nil;
  miFTemizle.Visible := (TamFiltre <> '') and (FDuzelt = nil);
  { Iliskili kayitlar: yalniz hucre ustunde ve duzenleme kipi kapaliyken. Bagli kayda git yalniz yabanci anahtar hucresinde. }
  miGit.Visible := False;
  miKullananlar.Visible := (FDuzelt = nil) and (dsVeri.DataSet <> nil) and dsVeri.DataSet.Active and (Koordinat.Y > 0) and
    (Koordinat.X > 0) and (Koordinat.X <= gridVeri.Columns.Count);
  if miKullananlar.Visible then
    miGit.Visible := BagliKayitBul(KisitlariAl, gridVeri.Columns[Koordinat.X - 1].FieldName, dsVeri.DataSet, FBagliKayit);
  miGit.Caption := TF('ILISKI_GIT', [FBagliKayit.Tablo]);
  miKullananlar.Caption := T('ILISKI_KULLANANLAR');
  { Kolon ozeti: kolon basligina sag tik. }
  FOzetAlan := '';
  if (FDuzelt = nil) and (dsVeri.DataSet <> nil) and dsVeri.DataSet.Active and (Koordinat.Y = 0) and
    (Koordinat.X > 0) and (Koordinat.X <= gridVeri.Columns.Count) then
  begin
    Alan := dsVeri.DataSet.FindField(gridVeri.Columns[Koordinat.X - 1].FieldName);
    if (Alan <> nil) and FiltreyeUygunMu(Alan) then
      FOzetAlan := Alan.FieldName;
  end;
  miOzet.Caption := T('OZET_MENU');
  miOzet.Visible := FOzetAlan <> '';
end;

{ Kolon basligina sag tik "Kolon ozeti": filtreye uyan satirlarin sayisi, doluluk, en kucuk/en buyuk, sayi kolonunda
  toplam ve ortalama. Hesap sunucuda yapilir (ekrandaki 100 satir degil, filtrelenmis tablonun tamami); sonuc alt alana yazilir. }
procedure TTabloSekme.miOzetClick(Sender: TObject);
var
  Bag: TAcikBaglanti;
  Alan: TField;
  Kapsam: TOzetKapsami;
  Ozet: TKolonOzeti;
  Satir, Sql: string;
begin
  Bag := BaglantiAl;
  if (Bag = nil) or (FOzetAlan = '') or (dsVeri.DataSet = nil) then
    Exit;
  Alan := dsVeri.DataSet.FindField(FOzetAlan);
  if Alan = nil then
    Exit;
  if SayisalAlanMi(Alan) then
    Kapsam := okSayisal
  else if SiralanabilirMi(Alan) or MetinAlaniMi(Alan) then
    Kapsam := okAralik
  else
    Kapsam := okSade;
  Sql := KolonOzetiSql(TabloAdi, FOzetAlan, Kapsam, TamFiltre);
  try
    Ozet := KolonOzeti(Bag, TabloAdi, FOzetAlan, Kapsam, TamFiltre);
  except
    on E: Exception do
    begin
      if Assigned(SqlYaz) then
        SqlYaz([StringReplace(Sql, sLineBreak, ' ', [rfReplaceAll])]);
      UyariGoster(HataMetniniCevir(E));
      Exit;
    end;
  end;
  Satir := TabloAdi + '.' + FOzetAlan + ': ' + TF('OZET_SATIR', [Ozet.Kayit, Ozet.Dolu, Ozet.Kayit - Ozet.Dolu]);
  if Kapsam in [okAralik, okSayisal] then
    Satir := Satir + ' ' + TF('OZET_ARALIK', [Ozet.EnKucuk, Ozet.EnBuyuk]);
  if Kapsam = okSayisal then
    Satir := Satir + ' ' + TF('OZET_SAYISAL', [Ozet.Toplam, Ozet.Ortalama]);
  if TamFiltre <> '' then
    Satir := Satir + ' (' + T('LBL_FILTRELI') + ')';
  Yaz(Satir);
  if Assigned(SqlYaz) then
    SqlYaz([StringReplace(Sql, sLineBreak, ' ', [rfReplaceAll])]);
end;

{ Tablonun kisitlari ilk ihtiyacta okunur; sag tik her seferinde sorgu calistirmasin. }
function TTabloSekme.KisitlariAl: TArray<TKisitBilgisi>;
var
  Bag: TAcikBaglanti;
begin
  if not FKisitlarOkundu then
  begin
    Bag := BaglantiAl;
    if Bag = nil then
      Exit(nil);
    FKisitlar := KisitlariOku(Bag, TabloAdi);
    FKisitlarOkundu := True;
  end;
  Result := FKisitlar;
end;

{ Ana pencereye "bu tabloyu su filtreyle yeni sekmede ac" der; SQL karsiligi alt alanda gorunur. }
procedure TTabloSekme.IliskiyiAc(const Kayit: TIliskiliKayit);
begin
  if Assigned(SqlYaz) then
    SqlYaz(['SELECT FIRST ' + IntToStr(ILK_SATIR_SAYISI) + ' * FROM ' + TirnakliAd(Kayit.Tablo) + ' WHERE ' + Kayit.Filtre]);
  if Assigned(FiltreliAc) then
    FiltreliAc(Kayit.Tablo, Kayit.Filtre);
end;

{ Sag tik "Bagli kayda git": yabanci anahtarin gosterdigi ana kayit, hedef tabloda filtreli sekmede acilir. }
procedure TTabloSekme.miGitClick(Sender: TObject);
begin
  if FBagliKayit.Tablo <> '' then
    IliskiyiAc(FBagliKayit);
end;

{ Sag tik "Bu kaydi kullananlar": o an secili kaydi baska tablolarda kullananlar listelenir, secilen acilir. }
procedure TTabloSekme.miKullananlarClick(Sender: TObject);
var
  Bag: TAcikBaglanti;
  Kayitlar: TArray<TIliskiliKayit>;
  Secim: Integer;
begin
  Bag := BaglantiAl;
  if (Bag = nil) or (dsVeri.DataSet = nil) or not dsVeri.DataSet.Active then
    Exit;
  try
    Kayitlar := KullananKayitlariBul(Bag, KisitlariAl, dsVeri.DataSet);
  except
    on E: Exception do
    begin
      UyariGoster(HataMetniniCevir(E));
      Exit;
    end;
  end;
  if Length(Kayitlar) = 0 then
  begin
    UyariGoster(TF('ILISKI_KULLANAN_YOK', [TabloAdi]));
    Exit;
  end;
  if KullananlarPenceresi(TabloAdi, Kayitlar, Secim) then
    IliskiyiAc(Kayitlar[Secim]);
end;

{ Menu secimi: hucrenin degerinden kosul uretilir (uFiltre), varsa onceki filtreye VE ile eklenir. }
procedure TTabloSekme.miFiltreClick(Sender: TObject);
var
  Etiket: Integer;
  Alan: TField;
  Islem: THucreIslemi;
begin
  Etiket := (Sender as TMenuItem).Tag;
  if Etiket = 7 then
  begin
    btnFiltreKaldirClick(nil);
    Exit;
  end;
  if (FHucreAlan = '') or (dsVeri.DataSet = nil) or not dsVeri.DataSet.Active then
    Exit;
  Alan := dsVeri.DataSet.FindField(FHucreAlan);
  if Alan = nil then
    Exit;
  if Etiket = 6 then
  begin
    if Alan.IsNull then
      Islem := hiBosDegil
    else
      Islem := hiBos;
  end
  else
    Islem := THucreIslemi(Etiket - 1);
  FiltreyiUygula(FiltreBirlestir(FFiltre, HucreFiltresi(Alan, Islem)));
end;

procedure TTabloSekme.edtFiltreKeyPress(Sender: TObject; var Key: Char);
begin
  if Key = #13 then
  begin
    Key := #0;
    FiltreyiUygula(edtFiltre.Text);
  end;
end;

{ Kullanici son satira gelince 100 satir daha yuklenir: sorgu daha buyuk sinirla yeniden okunur ve
  imlec eski satirda kalir. Tablo bitmisse (satir sayisi sinirdan azsa) bir sey yapmaz. }
procedure TTabloSekme.DevamiYukle;
var
  Bag: TAcikBaglanti;
  Eski: Integer;
begin
  FDevamBekliyor := False;
  Bag := BaglantiAl;
  if (Bag = nil) or (dsVeri.DataSet = nil) or not dsVeri.DataSet.Active then
    Exit;
  Eski := dsVeri.DataSet.RecNo;
  FSatirLimit := FSatirLimit + ILK_SATIR_SAYISI;
  if FDuzelt <> nil then
  begin
    { Duzeltme kipinde: bekleyen degisiklik yokken kip kapatilip daha buyuk sinirla yeniden acilir. }
    if (FDuzelt.BekleyenSayisi > 0) or (dsVeri.DataSet.State <> dsBrowse) then
    begin
      FSatirLimit := FSatirLimit - ILK_SATIR_SAYISI;
      Exit;
    end;
    DuzenlemeyiKapat;
    DuzenlemeyiAc;
  end
  else
    VeriyiOku(Bag);
  if (dsVeri.DataSet <> nil) and dsVeri.DataSet.Active and (Eski > 0) and (Eski <= dsVeri.DataSet.RecordCount) then
    dsVeri.DataSet.RecNo := Eski;
end;

{ Imlec son satira geldiyse ve tabloda daha satir olabilirse devam yuklemesi siraya konur
  (olay bitmeden veriseti yikilmasin diye hemen degil). }
procedure TTabloSekme.dsVeriDataChange(Sender: TObject; Field: TField);
begin
  if FDevamBekliyor or (dsVeri.DataSet = nil) or not dsVeri.DataSet.Active then
    Exit;
  { Duzeltme kipinde yalniz bekleyen degisiklik yokken (yoksa bellekteki degisiklikler kaybolurdu). }
  if (FDuzelt <> nil) and ((FDuzelt.BekleyenSayisi > 0) or (dsVeri.DataSet.State <> dsBrowse)) then
    Exit;
  if (dsVeri.DataSet.RecordCount >= FSatirLimit) and (dsVeri.DataSet.RecNo = dsVeri.DataSet.RecordCount) then
  begin
    FDevamBekliyor := True;
    TThread.ForceQueue(nil, DevamiYukle);
  end;
end;

{ ---------- Kayit duzeltme (Asama 4d, mantik uKayitDuzelt'te) ---------- }

{ Bekleyen degisiklik varsa atilsin mi diye sorar; yoksa (ya da duzeltme kapaliysa) True. }
function TTabloSekme.BekleyenAtilsinMi: Boolean;
begin
  Result := True;
  if FDuzelt = nil then
    Exit;
  FDuzelt.SatiriBitir;
  if FDuzelt.BekleyenSayisi > 0 then
    Result := OnayIste(TF('ONAY_DUZ_ATIL', [FDuzelt.BekleyenSayisi]));
end;

procedure TTabloSekme.DuzenlemeyiAc;
var
  Bag: TAcikBaglanti;
  Veri: TFDQuery;
  Duzelt: TKayitDuzelt;
begin
  Bag := BaglantiAl;
  if Bag = nil then
    Exit;
  try
    Veri := DuzeltilebilirVeriSorgusu(Bag, TabloAdi, FSatirLimit, Self, FSiraAlan, FSiraAzalan, TamFiltre);
    Duzelt := TKayitDuzelt.Create(Bag, TabloAdi, Veri, DuzenlemeDurumunuYaz);
  except
    on E: Exception do
    begin
      UyariGoster(HataMetniniCevir(E));
      Exit;
    end;
  end;
  if not Duzelt.AnahtarVar then
  begin
    Duzelt.Free;
    Veri.Free;
    UyariGoster(TF('ERR_DUZ_ANAHTAR_YOK', [TabloAdi]));
    Exit;
  end;
  dsVeri.DataSet.Free;
  dsVeri.DataSet := Veri;
  FDuzelt := Duzelt;
  FDuzelt.Ac;
  FVeriGrid.YeniSonuc(FSiraAlan, FSiraAzalan);
  FSatir.Esitle;
  FVeriGrid.Duzenle(True);
  btnYeniKayit.Visible := True;
  btnSil.Visible := True;
  btnKaydet.Visible := True;
  btnGeriAl.Visible := True;
  FiltreKutusunuAyarla;
  YazilariYenile;
end;

{ Duzeltme kipini kapatir; bekleyenler zaten atilmis ya da kaydedilmis olmalidir. Veriyi yeniden yuklemek cagirana aittir. }
procedure TTabloSekme.DuzenlemeyiKapat;
begin
  if FDuzelt = nil then
    Exit;
  FDuzelt.Kapat;
  FDuzelt.Free;
  FDuzelt := nil;
  FVeriGrid.Duzenle(False);
  btnYeniKayit.Visible := False;
  btnSil.Visible := False;
  btnKaydet.Visible := False;
  btnGeriAl.Visible := False;
  FiltreKutusunuAyarla;
end;

{ Kipte "islem" bilgisi: islem yalniz Kaydet sirasinda acilir, bekleyenler henuz sadece bellekte. }
procedure TTabloSekme.DuzenlemeDurumunuYaz;
begin
  if FDuzelt = nil then
  begin
    lblVeri.Caption := T('LBL_ILK_SATIRLAR');
    if (dsVeri.DataSet <> nil) and dsVeri.DataSet.Active then
    begin
      lblVeri.Caption := lblVeri.Caption + ' - ' + TF('LBL_SATIR_YUKLENDI', [dsVeri.DataSet.RecordCount]);
      if TamFiltre <> '' then
        lblVeri.Caption := lblVeri.Caption + ' (' + T('LBL_FILTRELI') + ')';
      if dsVeri.DataSet.RecordCount >= FSatirLimit then
        lblVeri.Caption := lblVeri.Caption + ' ' + TF('LBL_SATIR_DEVAMI', [ILK_SATIR_SAYISI]);
    end;
    { Yer dar olursa yazi "..." ile kisalir; tamami ipucunda okunur. }
    lblVeri.Hint := lblVeri.Caption;
  end
  else
  begin
    lblVeri.Caption := T('LBL_DUZ_DURUM');
    lblVeri.Hint := TF('LBL_DUZ_IPUCU', [FDuzelt.BekleyenSayisi]);
    { Bekleyen sayi Kaydet dugmesinin uzerinde: "Kaydet (3)". }
    if FDuzelt.BekleyenSayisi > 0 then
      btnKaydet.Caption := T('BTN_KAYDET') + ' (' + IntToStr(FDuzelt.BekleyenSayisi) + ')'
    else
      btnKaydet.Caption := T('BTN_KAYDET');
    DugmeyiYaziyaUydur(btnKaydet);
  end;
end;

{ Dugme: kipi acar; kipteyken "Duzenlemeyi bitir" olur (bekleyen varsa atilsin mi diye sorar). }
procedure TTabloSekme.btnDuzenleClick(Sender: TObject);
var
  Bag: TAcikBaglanti;
begin
  if FDuzelt = nil then
  begin
    DuzenlemeyiAc;
    Exit;
  end;
  if not BekleyenAtilsinMi then
    Exit;
  Bag := BaglantiAl;
  DuzenlemeyiKapat;
  if Bag <> nil then
    VeriyiYukle(Bag);
  YazilariYenile;
end;

{ Dugme: gridin sonuna bos yeni kayit ekler ve ona gider; yazilanlar Kaydet'e kadar yalniz bellekte kalir. }
procedure TTabloSekme.btnYeniKayitClick(Sender: TObject);
begin
  if FDuzelt = nil then
    Exit;
  FDuzelt.YeniKayit;
  gridVeri.SetFocus;
end;

{ Dugme: secili satirlari (Ctrl+tikla ile cok satir; secim yoksa su anki satir) silinmek uzere isaretler. Satirlar gridden
  kalkar ama veritabanindan SILINMEZ; Kaydet'te net onayla (DELETE komutlari ve sayi yazili) silinir, Geri al geri getirir. }
procedure TTabloSekme.btnSilClick(Sender: TObject);
var
  i: Integer;
begin
  if FDuzelt = nil then
    Exit;
  if gridVeri.SelectedRows.Count = 0 then
    FDuzelt.KaydiSil
  else
  begin
    for i := gridVeri.SelectedRows.Count - 1 downto 0 do
    begin
      dsVeri.DataSet.GotoBookmark(gridVeri.SelectedRows[i]);
      FDuzelt.KaydiSil;
    end;
    gridVeri.SelectedRows.Clear;
  end;
  gridVeri.SetFocus;
end;

{ Dugme: bekleyen UPDATE/INSERT/DELETE'ler net onayla tek islemde calisir. Hatada hepsi geri alinir, degisiklikler gridde kalir. }
procedure TTabloSekme.btnKaydetClick(Sender: TObject);
var
  Bag: TAcikBaglanti;
  Komutlar: TArray<string>;
  Sonuc: TDuzeltSonucu;
  Uyari: string;
begin
  if FDuzelt = nil then
    Exit;
  FDuzelt.SatiriBitir;
  if FDuzelt.BekleyenSayisi = 0 then
  begin
    Yaz(T('MSG_DUZ_DEGISIKLIK_YOK'));
    Exit;
  end;
  Bag := BaglantiAl;
  if Bag = nil then
    Exit;
  Komutlar := FDuzelt.OnayKomutlari;
  Uyari := '';
  if FDuzelt.SilinecekSayisi > 0 then
    Uyari := TF('ONAY_DUZ_SILINECEK', [FDuzelt.SilinecekSayisi]) + sLineBreak + sLineBreak;
  if not OnayIste(Uyari + TF('ONAY_DUZ_KAYDET', [TabloAdi, Length(Komutlar)]) + sLineBreak + sLineBreak + KomutOzeti(Komutlar)) then
  begin
    Yaz(T('MSG_DUZ_VAZGECILDI'));
    Exit;
  end;
  Sonuc := FDuzelt.Kaydet;
  if Sonuc.Basarili then
  begin
    Yaz(TF('MSG_DUZ_TAMAM', [TabloAdi, Length(Sonuc.Komutlar)]));
    DuzenlemeyiKapat;
    VeriyiYukle(Bag);
    YazilariYenile;
  end
  else
  begin
    Yaz(TF('ERR_DUZ_UYGULANAMADI', [TabloAdi]) + ' ' + Sonuc.Cumle);
    if Sonuc.Ayrinti <> '' then
      Yaz(T('AYRINTI') + ': ' + Sonuc.Ayrinti);
    Yaz(T('MSG_DUZ_GERI_ALINDI'));
  end;
  if (Length(Sonuc.Komutlar) > 0) and Assigned(SqlYaz) then
    SqlYaz(Sonuc.Komutlar);
end;

{ Dugme: bekleyen degisiklikleri atar; veritabanina hicbir sey yazilmadigi icin zararsizdir, yine de sorar. }
procedure TTabloSekme.btnGeriAlClick(Sender: TObject);
begin
  if FDuzelt = nil then
    Exit;
  if not BekleyenAtilsinMi then
    Exit;
  FDuzelt.GeriAl;
  DuzenlemeDurumunuYaz;
  gridVeri.Invalidate;
end;

procedure TTabloSekme.Yaz(const Metin: string);
begin
  if AnaSonuc <> nil then
    AnaSonuc.Add(Metin);
end;

{ Dort kolon dugmesinin ortak akisi: pencere, net onay, yedek + calistirma, sonuc mesaji, yeniden okuma. }
procedure TTabloSekme.KolonIsle(Islem: TKolonIslemi);
var
  Bag: TAcikBaglanti;
  Eski, Yeni: TKolonGirdisi;
  Komutlar: string;
begin
  Bag := FbAcikBaglanti(BaglantiAd);
  if Bag = nil then
  begin
    UyariGoster(TF('ERR_SORGU_BAGLANTI_YOK', [BaglantiAd]));
    Exit;
  end;
  if Islem = kiEkle then
  begin
    Eski := Default(TKolonGirdisi);
    Eski.Islem := kiEkle;
    Eski.Tablo := TabloAdi;
  end
  else
  begin
    if dsKolonlar.DataSet.IsEmpty then
      Exit;
    try
      Eski := KolonGirdisiOku(Bag, TabloAdi, dsKolonlar.DataSet.FieldByName('AD').AsString, Islem);
    except
      on E: Exception do
      begin
        UyariGoster(E.Message);
        Exit;
      end;
    end;
  end;
  if not KolonPenceresiGoster(Bag, Eski, Yeni) then
    Exit;
  Komutlar := KolonKomutlari(Bag, Eski, Yeni);
  if not OnayIste(KolonOnayMetni(Bag, Eski, Yeni, Komutlar)) then
  begin
    Yaz(T('MSG_KOLON_VAZGECILDI'));
    Exit;
  end;
  SonucuBildir(Bag, KolonUygula(Bag, Eski, Yeni));
end;

{ Tablo yapisi islemlerinin (kolon, index, kisit) ortak sonu: mesajlar, SQL karsiligi, basarida yeniden okuma. }
procedure TTabloSekme.SonucuBildir(Bag: TAcikBaglanti; const Sonuc: TProsedurSonucu);
begin
  if Sonuc.Basarili then
  begin
    Yaz(TF('MSG_KOLON_TAMAM', [TabloAdi]));
    Yaz(TF('MSG_PRS_YEDEKLENDI', [Sonuc.YedekDosyasi]));
    YenidenYukle(Bag);
  end
  else
  begin
    Yaz(TF('ERR_KOLON_UYGULANAMADI', [TabloAdi]) + ' ' + Sonuc.Cumle);
    if Sonuc.Ayrinti <> '' then
      Yaz(T('AYRINTI') + ': ' + Sonuc.Ayrinti);
    if Length(Sonuc.Komutlar) = 0 then
      Yaz(T('MSG_PRS_DOKUNULMADI'))
    else
      Yaz(T('MSG_KOLON_GERI_ALINDI'));
  end;
  if (Length(Sonuc.Komutlar) > 0) and Assigned(SqlYaz) then
    SqlYaz(Sonuc.Komutlar);
end;

{ Bagli baglanti; yoksa uyari gosterip nil doner. }
function TTabloSekme.BaglantiAl: TAcikBaglanti;
begin
  Result := FbAcikBaglanti(BaglantiAd);
  if Result = nil then
    UyariGoster(TF('ERR_SORGU_BAGLANTI_YOK', [BaglantiAd]));
end;

{ Index dugmeleri: olustur (pencere), sil ve aktif/pasif (seciliye). Hepsi net onay ister. }
procedure TTabloSekme.IndeksIsle(Islem: TYapiIslemi);
var
  Bag: TAcikBaglanti;
  G: TIndeksGirdisi;
  Komut: string;
begin
  Bag := BaglantiAl;
  if Bag = nil then
    Exit;
  if Islem = yiOlustur then
  begin
    if not IndeksPenceresiGoster(Bag, TabloAdi, G) then
      Exit;
  end
  else
  begin
    if dsIndeksler.DataSet.IsEmpty then
      Exit;
    try
      G := IndeksGirdisiOku(Bag, TabloAdi, dsIndeksler.DataSet.FieldByName('AD').AsString);
    except
      on E: Exception do
      begin
        UyariGoster(E.Message);
        Exit;
      end;
    end;
  end;
  Komut := IndeksKomutu(Bag, Islem, G);
  if not OnayIste(IndeksOnayMetni(G, Komut)) then
  begin
    Yaz(T('MSG_KOLON_VAZGECILDI'));
    Exit;
  end;
  SonucuBildir(Bag, IndeksUygula(Bag, Islem, G));
end;

{ Kisit dugmeleri: ekle (pencere) ve sil (seciliye). }
procedure TTabloSekme.KisitIsle(Islem: TYapiIslemi);
var
  Bag: TAcikBaglanti;
  G: TKisitGirdisi;
  Komut: string;
begin
  Bag := BaglantiAl;
  if Bag = nil then
    Exit;
  if Islem = yiOlustur then
  begin
    if not KisitPenceresiGoster(Bag, TabloAdi, G) then
      Exit;
  end
  else
  begin
    if dsKisitlar.DataSet.IsEmpty then
      Exit;
    try
      G := KisitGirdisiOku(Bag, TabloAdi, dsKisitlar.DataSet.FieldByName('AD').AsString);
    except
      on E: Exception do
      begin
        UyariGoster(E.Message);
        Exit;
      end;
    end;
  end;
  Komut := KisitKomutu(Bag, Islem, G);
  if not OnayIste(KisitOnayMetni(Bag, Islem, G, Komut)) then
  begin
    Yaz(T('MSG_KOLON_VAZGECILDI'));
    Exit;
  end;
  SonucuBildir(Bag, KisitUygula(Bag, Islem, G));
end;

procedure TTabloSekme.btnIndeksOlusturClick(Sender: TObject);
begin
  IndeksIsle(yiOlustur);
end;

procedure TTabloSekme.btnIndeksSilClick(Sender: TObject);
begin
  IndeksIsle(yiSil);
end;

procedure TTabloSekme.btnIndeksDurumClick(Sender: TObject);
begin
  IndeksIsle(yiDurum);
end;

procedure TTabloSekme.btnKisitEkleClick(Sender: TObject);
begin
  KisitIsle(yiOlustur);
end;

procedure TTabloSekme.btnKisitSilClick(Sender: TObject);
begin
  KisitIsle(yiSil);
end;

procedure TTabloSekme.btnKolonEkleClick(Sender: TObject);
begin
  KolonIsle(kiEkle);
end;

procedure TTabloSekme.btnKolonAdClick(Sender: TObject);
begin
  KolonIsle(kiAd);
end;

procedure TTabloSekme.btnKolonDegistirClick(Sender: TObject);
begin
  KolonIsle(kiDegistir);
end;

procedure TTabloSekme.btnKolonSilClick(Sender: TObject);
begin
  KolonIsle(kiSil);
end;

{ "Birincil anahtar yap": secili kolon PRIMARY KEY olur. Kolon bos olabiliyorsa (Firebird 3.0 ve ustu) once NOT NULL yapilir;
  iki komut da onay penceresinde yazilidir. Engel varsa (zaten PK var, 2.5'te bos olabilen kolon) anlasilir cumle gosterilir. }
procedure TTabloSekme.btnKolonPkClick(Sender: TObject);
var
  Bag: TAcikBaglanti;
  Plan: TPkPlani;
begin
  Bag := BaglantiAl;
  if (Bag = nil) or dsKolonlar.DataSet.IsEmpty then
    Exit;
  Plan := PkPlaniKur(Bag, TabloAdi, dsKolonlar.DataSet.FieldByName('AD').AsString);
  if Plan.Engel <> '' then
  begin
    UyariGoster(Plan.Engel);
    Exit;
  end;
  if not OnayIste(PkOnayMetni(Plan)) then
  begin
    Yaz(T('MSG_KOLON_VAZGECILDI'));
    Exit;
  end;
  SonucuBildir(Bag, PkUygula(Bag, Plan));
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
{ Dugme: CSV dosyasindan bu tabloya satir ekler (onizleme, kolon esleme, net onay, tek islem; bkz. fIceAktar, uIceAktar).
  Duzeltme kipi aciksken kapali: ice aktarma sonunda veri yeniden okunur, bekleyen degisiklikler kaybolurdu. }
procedure TTabloSekme.btnIceAktarClick(Sender: TObject);
var
  Bag: TAcikBaglanti;
begin
  if FDuzelt <> nil then
  begin
    UyariGoster(T('ERR_ICE_DUZENLEME_ACIK'));
    Exit;
  end;
  Bag := BaglantiAl;
  if Bag = nil then
    Exit;
  if IceAktarPenceresiniGoster(Bag, TabloAdi, SqlYaz, AnaSonuc) then
    VeriyiYukle(Bag);
end;

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
  CsvPenceresiniGoster(Bag, TabloTumSatirlarSorgusu(TabloAdi, TamFiltre, FSiraAlan, FSiraAzalan), TabloAdi, AnaSonuc);
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
  btnKolonEkle.Caption := T('BTN_KOLON_EKLE');
  btnKolonAd.Caption := T('BTN_KOLON_AD');
  btnKolonDegistir.Caption := T('BTN_KOLON_DEGISTIR');
  btnKolonSil.Caption := T('BTN_KOLON_SIL');
  btnKolonPk.Caption := T('BTN_KOLON_PK');
  DugmeyiYaziyaUydur(btnKolonPk);
  DugmeyiYaziyaUydur(btnKolonEkle);
  DugmeyiYaziyaUydur(btnKolonAd);
  DugmeyiYaziyaUydur(btnKolonDegistir);
  DugmeyiYaziyaUydur(btnKolonSil);
  btnIndeksOlustur.Caption := T('BTN_INDEKS_OLUSTUR');
  btnIndeksSil.Caption := T('BTN_INDEKS_SIL');
  btnIndeksDurum.Caption := T('BTN_INDEKS_DURUM');
  btnKisitEkle.Caption := T('BTN_KISIT_EKLE');
  btnKisitSil.Caption := T('BTN_KISIT_SIL');
  DugmeyiYaziyaUydur(btnIndeksOlustur);
  DugmeyiYaziyaUydur(btnIndeksSil);
  DugmeyiYaziyaUydur(btnIndeksDurum);
  DugmeyiYaziyaUydur(btnKisitEkle);
  DugmeyiYaziyaUydur(btnKisitSil);
  DuzenlemeDurumunuYaz;
  edtFiltre.TextHint := T('FILTRE_ETIKET');
  edtFiltre.Hint := T('FILTRE_IPUCU');
  FSatir.YazilariYenile;
  btnFiltreKaldir.Caption := T('FILTRE_KALDIR');
  DugmeyiYaziyaUydur(btnFiltreKaldir);
  btnDisaAktar.Caption := T('AKTAR_DUGME');
  btnIceAktar.Caption := T('BTN_ICE_AKTAR');
  DugmeyiYaziyaUydur(btnIceAktar);
  if FDuzelt = nil then
    btnDuzenle.Caption := T('BTN_DUZENLE')
  else
    btnDuzenle.Caption := T('BTN_DUZ_BITIR');
  btnYeniKayit.Caption := T('BTN_YENI_KAYIT');
  btnSil.Caption := T('BTN_KAYIT_SIL');
  DugmeyiYaziyaUydur(btnSil);
  btnGeriAl.Caption := T('BTN_GERI_AL');
  DugmeyiYaziyaUydur(btnYeniKayit);
  DugmeyiYaziyaUydur(btnDisaAktar);
  DugmeyiYaziyaUydur(btnDuzenle);
  DugmeyiYaziyaUydur(btnKaydet);
  DugmeyiYaziyaUydur(btnGeriAl);
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
