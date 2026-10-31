{ fKullanicilar.pas - Bir baglantinin sunucu kullanicilari sekmesi (Asama 3d-1).
  Frame sadece arayuzu bilir; liste uMetadata'dan, yazma islemleri uKullanici'dan gelir. Sagdaki menude en fazla
  alti madde vardir. SYSDBA satirinda yalniz "Sifre degistir" ve "Yenile" etkindir (uKullanici de ayrica reddeder). }
unit fKullanicilar;

interface

uses
  System.SysUtils, System.Classes, Data.DB, Winapi.Windows, Vcl.Controls, Vcl.Forms, Vcl.ExtCtrls,
  Vcl.StdCtrls, Vcl.Grids, Vcl.DBGrids, Vcl.Menus,
  FireDAC.Comp.Client,
  uDil, uOnay, uBaglanti, uMetadata, uKullanici, uYetki, fKullaniciDuzenle, fYetkiler;

type
  TKullanicilar = class(TFrame)
    pnlUst: TPanel;
    lblBilgi: TLabel;
    btnYeni: TButton;
    btnYetki: TButton;
    gridKullanicilar: TDBGrid;
    dsKullanicilar: TDataSource;
    pmKullanici: TPopupMenu;
    miSifre: TMenuItem;
    miAdSoyad: TMenuItem;
    miYonetici: TMenuItem;
    miAktif: TMenuItem;
    miYenile: TMenuItem;
    miSil: TMenuItem;
    procedure btnYeniClick(Sender: TObject);
    procedure btnYetkiClick(Sender: TObject);
    procedure gridKullanicilarMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
    procedure pmKullaniciPopup(Sender: TObject);
    procedure miSifreClick(Sender: TObject);
    procedure miAdSoyadClick(Sender: TObject);
    procedure miYoneticiClick(Sender: TObject);
    procedure miAktifClick(Sender: TObject);
    procedure miYenileClick(Sender: TObject);
    procedure miSilClick(Sender: TObject);
  private
    FTablo: TFDMemTable;
    FListe: TArray<TKullaniciBilgisi>;
    FYetenek: TKullaniciYetenekleri;
    function Baglanti: TAcikBaglanti;
    function SeciliAd: string;
    function SeciliKullanici(out Kullanici: TKullaniciBilgisi): Boolean;
    procedure IslemHatasi(Hata: Exception);
    procedure Bilgi(const Metin: string);
    { Son islemin SQL'ini ana pencerenin mesaj alanina yazar (SqlYaz atanmissa). }
    procedure SqlGoster;
  public
    BaglantiAd: string;
    { Islem ozetleri buraya (ana pencerenin sonuc alani) yazilir; ana pencere atar. }
    AnaSonuc: TStrings;
    { Calistirilan SQL'i mesaj alaninda gostermek icin ana pencere atar. }
    SqlYaz: TSqlGoster;
    procedure Yukle(Bag: TAcikBaglanti);
    { Listeyi sunucudan yeniden okur; Sec doluysa o kullanicinin satirina gider. }
    procedure Yenile(const Sec: string = '');
    procedure YazilariYenile;
  end;

implementation

{$R *.dfm}

type
  { DBGrid'in korunmus "Row" ozelligine (aktif satirin sirasi) erismek icin; baska is yapmaz. }
  TSatirErisimi = class(TDBGrid);

function TKullanicilar.Baglanti: TAcikBaglanti;
begin
  Result := FbAcikBaglanti(BaglantiAd);
  if Result = nil then
    UyariGoster(TF('ERR_SORGU_BAGLANTI_YOK', [BaglantiAd]));
end;

function TKullanicilar.SeciliAd: string;
begin
  if (FTablo <> nil) and not FTablo.IsEmpty then
    Result := FTablo.FieldByName('KULLANICI').AsString
  else
    Result := '';
end;

{ Secili satirin tam bilgisi (ad, soyad, yonetici, aktif) listeden alinir. }
function TKullanicilar.SeciliKullanici(out Kullanici: TKullaniciBilgisi): Boolean;
var
  Ad: string;
  Aday: TKullaniciBilgisi;
begin
  Result := False;
  Kullanici := Default(TKullaniciBilgisi);
  Ad := SeciliAd;
  for Aday in FListe do
    if SameText(Aday.Ad, Ad) then
    begin
      Kullanici := Aday;
      Exit(True);
    end;
end;

procedure TKullanicilar.Bilgi(const Metin: string);
begin
  if AnaSonuc <> nil then
    AnaSonuc.Add(Metin);
end;

procedure TKullanicilar.SqlGoster;
begin
  if Assigned(SqlYaz) then
    SqlYaz(SonKomutlar);
end;

{ Kural hatasi kendi cumlesiyle; sunucu hatasi anlasilir cumle + Ayrinti (sonuc alanina) ile gosterilir. }
procedure TKullanicilar.IslemHatasi(Hata: Exception);
begin
  if Hata is EKullaniciKurali then
    UyariGoster(Hata.Message)
  else
  begin
    UyariGoster(HataMetniniCevir(Hata));
    Bilgi(T('AYRINTI') + ': ' + Hata.Message);
  end;
end;

procedure TKullanicilar.Yukle(Bag: TAcikBaglanti);
begin
  BaglantiAd := Bag.Tanim.Ad;
  FYetenek := KullaniciYetenekleri(Bag);
  FTablo := KullaniciTablosuOlustur(Self);
  FListe := KullaniciListesiOku(Bag);
  KullaniciTablosunuDoldur(FTablo, FListe, FYetenek);
  dsKullanicilar.DataSet := FTablo;
  YazilariYenile;
end;

procedure TKullanicilar.Yenile(const Sec: string);
var
  Bag: TAcikBaglanti;
  Hedef: string;
begin
  Bag := Baglanti;
  if Bag = nil then
    Exit;
  if Sec <> '' then
    Hedef := Sec
  else
    Hedef := SeciliAd;
  try
    FListe := KullaniciListesiOku(Bag);
  except
    on E: Exception do
    begin
      IslemHatasi(E);
      Exit;
    end;
  end;
  KullaniciTablosunuDoldur(FTablo, FListe, FYetenek);
  if Hedef <> '' then
    FTablo.Locate('KULLANICI', Hedef, [loCaseInsensitive]);
end;

procedure TKullanicilar.YazilariYenile;
var
  Hedef: string;
begin
  lblBilgi.Caption := T('KUL_BILGI');
  btnYeni.Caption := T('KUL_YENI');
  DugmeyiYaziyaUydur(btnYeni);
  btnYetki.Caption := T('KUL_YETKILER');
  DugmeyiYaziyaUydur(btnYetki);
  miSifre.Caption := T('KUL_MENU_SIFRE');
  miAdSoyad.Caption := T('KUL_MENU_ADSOYAD');
  miYenile.Caption := T('MENU_YENILE');
  miSil.Caption := T('KUL_MENU_SIL');
  if FTablo = nil then
    Exit;
  FTablo.FieldByName('KULLANICI').DisplayLabel := T('KUL_KOL_KULLANICI');
  FTablo.FieldByName('ISIM').DisplayLabel := T('KUL_KOL_ISIM');
  FTablo.FieldByName('SOYAD').DisplayLabel := T('KUL_KOL_SOYAD');
  FTablo.FieldByName('YONETICI').DisplayLabel := T('KUL_KOL_YONETICI');
  FTablo.FieldByName('AKTIF').DisplayLabel := T('KUL_KOL_AKTIF');
  { "Evet/Hayir" yazilari yeni dilde yazilsin diye ayni listeyle yeniden doldurulur (sunucuya gidilmez). }
  Hedef := SeciliAd;
  KullaniciTablosunuDoldur(FTablo, FListe, FYetenek);
  if Hedef <> '' then
    FTablo.Locate('KULLANICI', Hedef, [loCaseInsensitive]);
end;

{ Sag tikta tiklanan satir secilsin (DBGrid kendiliginden secmez). }
procedure TKullanicilar.gridKullanicilarMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState;
  X, Y: Integer);
var
  Hucre: TGridCoord;
begin
  if (Button = mbRight) and (FTablo <> nil) and not FTablo.IsEmpty then
  begin
    Hucre := gridKullanicilar.MouseCoord(X, Y);
    if Hucre.Y >= 1 then
      FTablo.MoveBy(Hucre.Y - TSatirErisimi(gridKullanicilar).Row);
  end;
end;

{ Menu maddelerinin yazisi ve acik/kapali durumu secili satira gore. SYSDBA: yalniz sifre ve yenile. }
procedure TKullanicilar.pmKullaniciPopup(Sender: TObject);
var
  Kullanici: TKullaniciBilgisi;
  Secili, Sysdba, Kendi: Boolean;
  Bag: TAcikBaglanti;
begin
  Bag := FbAcikBaglanti(BaglantiAd);
  Secili := SeciliKullanici(Kullanici);
  Sysdba := Secili and SysdbaMi(Kullanici.Ad);
  Kendi := Secili and (Bag <> nil) and KendiKullanicisiMi(Bag, Kullanici.Ad);
  miSifre.Enabled := Secili;
  miAdSoyad.Enabled := Secili and not Sysdba;
  miYonetici.Visible := FYetenek.YoneticiAyarlanir;
  miYonetici.Enabled := Secili and not Sysdba;
  if Secili and Kullanici.Yonetici then
    miYonetici.Caption := T('KUL_MENU_YONETICI_KALDIR')
  else
    miYonetici.Caption := T('KUL_MENU_YONETICI_YAP');
  miAktif.Visible := FYetenek.AktifPasif;
  miAktif.Enabled := Secili and not Sysdba and not Kendi;
  if Secili and not Kullanici.Aktif then
    miAktif.Caption := T('KUL_MENU_AKTIF_YAP')
  else
    miAktif.Caption := T('KUL_MENU_PASIF_YAP');
  miYenile.Enabled := True;
  miSil.Enabled := Secili and not Sysdba and not Kendi;
end;

{ Secili kullanicinin yetkileri penceresi (3d-2); "Hepsini geri al" orada. Bos satirda dugme bir sey yapmaz. }
procedure TKullanicilar.btnYetkiClick(Sender: TObject);
var
  Bag: TAcikBaglanti;
begin
  Bag := Baglanti;
  if (Bag <> nil) and (SeciliAd <> '') then
    YetkiPenceresiniGoster(Bag, ykKullanici, SeciliAd, ynTablo, AnaSonuc, SqlYaz);
end;

procedure TKullanicilar.btnYeniClick(Sender: TObject);
var
  Bag: TAcikBaglanti;
  Ad: string;
begin
  Bag := Baglanti;
  if (Bag <> nil) and KullaniciPenceresiniGoster(Bag, kiEkle, '', '', '', Ad, SqlYaz) then
  begin
    Bilgi(TF('KUL_MSG_EKLENDI', [Ad]));
    SqlGoster;
    Yenile(Ad);
  end;
end;

procedure TKullanicilar.miSifreClick(Sender: TObject);
var
  Bag: TAcikBaglanti;
  Ad, Yapilan: string;
begin
  Bag := Baglanti;
  Ad := SeciliAd;
  if (Bag = nil) or (Ad = '') then
    Exit;
  if not KullaniciPenceresiniGoster(Bag, kiSifre, Ad, '', '', Yapilan, SqlYaz) then
    Exit;
  Bilgi(TF('KUL_MSG_SIFRE', [Ad]));
  SqlGoster;
  { Baglantinin kendi kullanicisinin sifresi degistiyse, kayitli (DPAPI) sifre de eskimis olur. Acik baglanti etkilenmez. }
  if KendiKullanicisiMi(Bag, Ad) and KayitliSifreSaklaniyorMu(Bag) and OnayIste(T('ONAY_KAYITLI_SIFRE')) then
  begin
    try
      KayitliSifreyiGuncelle(Bag, Bag.Tanim.Sifre);
      Bilgi(T('KUL_MSG_KAYITLI_SIFRE'));
    except
      on E: Exception do
        IslemHatasi(E);
    end;
  end;
end;

procedure TKullanicilar.miAdSoyadClick(Sender: TObject);
var
  Bag: TAcikBaglanti;
  Kullanici: TKullaniciBilgisi;
  Ad: string;
begin
  Bag := Baglanti;
  if (Bag = nil) or not SeciliKullanici(Kullanici) then
    Exit;
  if KullaniciPenceresiniGoster(Bag, kiAdSoyad, Kullanici.Ad, Kullanici.Isim, Kullanici.Soyad, Ad, SqlYaz) then
  begin
    Bilgi(TF('KUL_MSG_ADSOYAD', [Ad]));
    SqlGoster;
    Yenile(Ad);
  end;
end;

procedure TKullanicilar.miYoneticiClick(Sender: TObject);
var
  Bag: TAcikBaglanti;
  Kullanici: TKullaniciBilgisi;
begin
  Bag := Baglanti;
  if (Bag = nil) or not SeciliKullanici(Kullanici) then
    Exit;
  try
    if Kullanici.Yonetici then
    begin
      YoneticiAyarla(Bag, Kullanici.Ad, False);
      Bilgi(TF('KUL_MSG_YONETICI_KALDIRILDI', [Kullanici.Ad]));
    end
    else
    begin
      if not OnayIste(TF('ONAY_YONETICI_YAP_AD', [Kullanici.Ad])) then
        Exit;
      YoneticiAyarla(Bag, Kullanici.Ad, True);
      Bilgi(TF('KUL_MSG_YONETICI_YAPILDI', [Kullanici.Ad]));
    end;
  except
    on E: Exception do
    begin
      IslemHatasi(E);
      SqlGoster;
      Exit;
    end;
  end;
  SqlGoster;
  Yenile(Kullanici.Ad);
end;

procedure TKullanicilar.miAktifClick(Sender: TObject);
var
  Bag: TAcikBaglanti;
  Kullanici: TKullaniciBilgisi;
begin
  Bag := Baglanti;
  if (Bag = nil) or not SeciliKullanici(Kullanici) then
    Exit;
  try
    if Kullanici.Aktif then
    begin
      if not OnayIste(TF('ONAY_PASIF_YAP', [Kullanici.Ad])) then
        Exit;
      AktifAyarla(Bag, Kullanici.Ad, False);
      Bilgi(TF('KUL_MSG_PASIF_YAPILDI', [Kullanici.Ad]));
    end
    else
    begin
      AktifAyarla(Bag, Kullanici.Ad, True);
      Bilgi(TF('KUL_MSG_AKTIF_YAPILDI', [Kullanici.Ad]));
    end;
  except
    on E: Exception do
    begin
      IslemHatasi(E);
      SqlGoster;
      Exit;
    end;
  end;
  SqlGoster;
  Yenile(Kullanici.Ad);
end;

procedure TKullanicilar.miYenileClick(Sender: TObject);
begin
  Yenile;
end;

procedure TKullanicilar.miSilClick(Sender: TObject);
var
  Bag: TAcikBaglanti;
  Ad: string;
begin
  Bag := Baglanti;
  Ad := SeciliAd;
  if (Bag = nil) or (Ad = '') then
    Exit;
  if not OnayIste(TF('ONAY_KULLANICI_SIL', [Ad])) then
    Exit;
  try
    KullaniciSil(Bag, Ad);
  except
    on E: Exception do
    begin
      IslemHatasi(E);
      SqlGoster;
      Exit;
    end;
  end;
  Bilgi(TF('KUL_MSG_SILINDI', [Ad]));
  SqlGoster;
  Yenile;
end;

end.
