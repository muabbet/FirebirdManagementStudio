{ fTabloSekme.pas - Bir tablo sekmesinin icerigi: ustte kolonlar, altta ilk satirlar.
  Frame sadece arayuzu bilir; isi uMetadata ve uSorgu yapar. }
unit fTabloSekme;

interface

uses
  System.SysUtils, System.Classes, Data.DB, Vcl.Controls, Vcl.Forms, Vcl.ExtCtrls,
  Vcl.StdCtrls, Vcl.Grids, Vcl.DBGrids, Vcl.ComCtrls, FireDAC.Comp.Client,
  uDil, uOnay, uBaglanti, uMetadata, uSorgu, uSonucGrid, uKayitDuzelt, uKullanici, uProsedur, uKolon, uIndeksKisit, fKolonIslem, fYapiIslem, fCsvAktar, fIceAktar;

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
    btnDuzenle: TButton;
    btnIceAktar: TButton;
    btnYeniKayit: TButton;
    btnSil: TButton;
    btnKaydet: TButton;
    btnGeriAl: TButton;
    gridVeri: TDBGrid;
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
    procedure btnIndeksOlusturClick(Sender: TObject);
    procedure btnIndeksSilClick(Sender: TObject);
    procedure btnIndeksDurumClick(Sender: TObject);
    procedure btnKisitEkleClick(Sender: TObject);
    procedure btnKisitSilClick(Sender: TObject);
  private
    FVeriGrid: TSonucGrid;
    { Nil degilse kayit duzeltme kipi acik (Asama 4d). }
    FDuzelt: TKayitDuzelt;
    procedure Yaz(const Metin: string);
    procedure VeriyiYukle(Bag: TAcikBaglanti);
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
    destructor Destroy; override;
    procedure Yukle(Bag: TAcikBaglanti; const Tablo: string);
    { Sag tik "Yenile": kolonlar, yapi ve ilk satirlar veritabanindan yeniden okunur. }
    procedure Yenile;
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
  btnDuzenle.Enabled := True;
  btnIceAktar.Enabled := True;
end;

destructor TTabloSekme.Destroy;
begin
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
  dsKolonlar.DataSet.Free;
  dsKolonlar.DataSet := KolonTablosuOlustur(Bag, TabloAdi, Self);
  YapiyiYukle(Bag);
  VeriyiYukle(Bag);
  YazilariYenile;
end;

{ Yalniz alttaki veri gridi: ilk satirlar salt okunur olarak yeniden okunur. }
procedure TTabloSekme.VeriyiYukle(Bag: TAcikBaglanti);
begin
  dsVeri.DataSet.Free;
  dsVeri.DataSet := TabloVerisiSorgusu(Bag, TabloAdi, ILK_SATIR_SAYISI, Self);
  FVeriGrid.YeniSonuc;
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
    Veri := DuzeltilebilirVeriSorgusu(Bag, TabloAdi, ILK_SATIR_SAYISI, Self);
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
  FVeriGrid.YeniSonuc;
  FVeriGrid.Duzenle(True);
  btnYeniKayit.Visible := True;
  btnSil.Visible := True;
  btnKaydet.Visible := True;
  btnGeriAl.Visible := True;
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
end;

{ Kipte "islem" bilgisi: islem yalniz Kaydet sirasinda acilir, bekleyenler henuz sadece bellekte. }
procedure TTabloSekme.DuzenlemeDurumunuYaz;
begin
  if FDuzelt = nil then
  begin
    lblVeri.Caption := T('LBL_ILK_SATIRLAR');
    lblVeri.Hint := '';
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
  DuzenlemeDurumunuYaz;
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
