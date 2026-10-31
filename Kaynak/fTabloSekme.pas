{ fTabloSekme.pas - Bir tablo sekmesinin icerigi: ustte kolonlar, altta ilk satirlar.
  Frame sadece arayuzu bilir; isi uMetadata ve uSorgu yapar. }
unit fTabloSekme;

interface

uses
  System.SysUtils, System.Classes, Data.DB, Vcl.Controls, Vcl.Forms, Vcl.ExtCtrls,
  Vcl.StdCtrls, Vcl.Grids, Vcl.DBGrids, Vcl.ComCtrls,
  uDil, uOnay, uBaglanti, uMetadata, uSorgu, uSonucGrid, uKullanici, uProsedur, uKolon, uIndeksKisit, fKolonIslem, fYapiIslem, fCsvAktar;

type
  TTabloSekme = class(TFrame)
    pnlKolonlar: TPanel;
    pcYapi: TPageControl;
    tsKolonlar: TTabSheet;
    pnlKolonDugme: TPanel;
    btnKolonEkle: TButton;
    btnKolonAd: TButton;
    btnKolonDegistir: TButton;
    btnKolonSil: TButton;
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
    gridVeri: TDBGrid;
    dsKolonlar: TDataSource;
    dsVeri: TDataSource;
    dsIndeksler: TDataSource;
    dsKisitlar: TDataSource;
    dsBagimliliklar: TDataSource;
    procedure btnDisaAktarClick(Sender: TObject);
    procedure btnKolonEkleClick(Sender: TObject);
    procedure btnKolonAdClick(Sender: TObject);
    procedure btnKolonDegistirClick(Sender: TObject);
    procedure btnKolonSilClick(Sender: TObject);
    procedure btnIndeksOlusturClick(Sender: TObject);
    procedure btnIndeksSilClick(Sender: TObject);
    procedure btnIndeksDurumClick(Sender: TObject);
    procedure btnKisitEkleClick(Sender: TObject);
    procedure btnKisitSilClick(Sender: TObject);
  private
    FVeriGrid: TSonucGrid;
    procedure Yaz(const Metin: string);
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
  FVeriGrid := TSonucGrid.Create(gridVeri);
  YenidenYukle(Bag);
  btnDisaAktar.Enabled := True;
end;

{ Kolonlar, yapi sekmeleri ve ilk satirlar bastan okunur (acilista ve kolon islemlerinden sonra). }
procedure TTabloSekme.YenidenYukle(Bag: TAcikBaglanti);
begin
  dsKolonlar.DataSet.Free;
  dsVeri.DataSet.Free;
  dsKolonlar.DataSet := KolonTablosuOlustur(Bag, TabloAdi, Self);
  YapiyiYukle(Bag);
  dsVeri.DataSet := TabloVerisiSorgusu(Bag, TabloAdi, ILK_SATIR_SAYISI, Self);
  FVeriGrid.YeniSonuc;
  YazilariYenile;
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
  btnKolonEkle.Caption := T('BTN_KOLON_EKLE');
  btnKolonAd.Caption := T('BTN_KOLON_AD');
  btnKolonDegistir.Caption := T('BTN_KOLON_DEGISTIR');
  btnKolonSil.Caption := T('BTN_KOLON_SIL');
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
