{ fKullaniciDuzenle.pas - Kullanici ekleme / sifre degistirme / ad-soyad duzenleme penceresi (Asama 3d-1).
  Form yalniz alanlari toplar; is uKullanici'dedir (Tamam dugmesi dogrudan KullaniciEkle, SifreDegistir
  veya AdSoyadDegistir'i cagirir). Hata olursa pencere acik kalir, anlasilir cumle ve Ayrinti gosterilir. }
unit fKullaniciDuzenle;

interface

uses
  System.SysUtils, System.Classes, Vcl.Controls, Vcl.Forms, Vcl.StdCtrls, Vcl.ExtCtrls,
  uDil, uOnay, uBaglanti, uMetadata, uKullanici;

type
  TKullaniciIslemi = (kiEkle, kiSifre, kiAdSoyad);

  TfrmKullaniciDuzenle = class(TForm)
    pnlAd: TPanel;
    lblAd: TLabel;
    edtAd: TEdit;
    pnlSifre: TPanel;
    lblSifre: TLabel;
    edtSifre: TEdit;
    pnlSifre2: TPanel;
    lblSifre2: TLabel;
    edtSifre2: TEdit;
    pnlIsim: TPanel;
    lblIsim: TLabel;
    edtIsim: TEdit;
    pnlSoyad: TPanel;
    lblSoyad: TLabel;
    edtSoyad: TEdit;
    pnlYonetici: TPanel;
    chkYonetici: TCheckBox;
    pnlHata: TPanel;
    lblHata: TLabel;
    btnAyrinti: TButton;
    memAyrinti: TMemo;
    pnlAlt: TPanel;
    btnIptal: TButton;
    btnTamam: TButton;
    procedure btnTamamClick(Sender: TObject);
    procedure btnAyrintiClick(Sender: TObject);
  private
    FBag: TAcikBaglanti;
    FIslem: TKullaniciIslemi;
    FKullanici: string;
    procedure Hazirla(Bag: TAcikBaglanti; Islem: TKullaniciIslemi; const Kullanici, Isim, Soyad: string);
    procedure YuksekligiAyarla;
    procedure HataGoster(const Anlasilir, Ayrinti: string);
    procedure HatayiGizle;
  end;

{ Islem kiEkle: yeni kullanici (Kullanici yok sayilir). kiSifre: Kullanici'nin sifresi. kiAdSoyad: Kullanici'nin
  adi/soyadi (Isim ve Soyad mevcut degerlerdir). Islem yapildiysa True doner; YapilanAd o kullanicinin adi. }
function KullaniciPenceresiniGoster(Bag: TAcikBaglanti; Islem: TKullaniciIslemi;
  const Kullanici, Isim, Soyad: string; out YapilanAd: string): Boolean;

implementation

{$R *.dfm}

function KullaniciPenceresiniGoster(Bag: TAcikBaglanti; Islem: TKullaniciIslemi;
  const Kullanici, Isim, Soyad: string; out YapilanAd: string): Boolean;
var
  Pencere: TfrmKullaniciDuzenle;
begin
  Pencere := TfrmKullaniciDuzenle.Create(Application);
  try
    Pencere.Hazirla(Bag, Islem, Kullanici, Isim, Soyad);
    Result := Pencere.ShowModal = mrOk;
    YapilanAd := Pencere.FKullanici;
  finally
    Pencere.Free;
  end;
end;

procedure TfrmKullaniciDuzenle.Hazirla(Bag: TAcikBaglanti; Islem: TKullaniciIslemi;
  const Kullanici, Isim, Soyad: string);
begin
  FBag := Bag;
  FIslem := Islem;
  FKullanici := Kullanici;
  lblAd.Caption := T('KUL_AD');
  lblSifre.Caption := T('KUL_SIFRE');
  lblSifre2.Caption := T('KUL_SIFRE_TEKRAR');
  lblIsim.Caption := T('KUL_ISIM');
  lblSoyad.Caption := T('KUL_SOYAD');
  chkYonetici.Caption := T('KUL_YONETICI_KUTU');
  btnAyrinti.Caption := T('AYRINTI');
  btnTamam.Caption := T('BTN_TAMAM');
  btnIptal.Caption := T('BTN_IPTAL');
  DugmeyiYaziyaUydur(btnTamam);
  DugmeyiYaziyaUydur(btnIptal);
  DugmeyiYaziyaUydur(btnAyrinti);
  edtIsim.Text := Isim;
  edtSoyad.Text := Soyad;
  pnlAd.Visible := Islem = kiEkle;
  pnlSifre.Visible := Islem <> kiAdSoyad;
  pnlSifre2.Visible := Islem <> kiAdSoyad;
  pnlIsim.Visible := Islem <> kiSifre;
  pnlSoyad.Visible := Islem <> kiSifre;
  pnlYonetici.Visible := (Islem = kiEkle) and KullaniciYetenekleri(Bag).YoneticiAyarlanir;
  case Islem of
    kiEkle:
      begin
        Caption := T('KUL_BASLIK_EKLE');
        ActiveControl := edtAd;
      end;
    kiSifre:
      begin
        Caption := TF('KUL_BASLIK_SIFRE', [Kullanici]);
        lblSifre.Caption := T('KUL_SIFRE_YENI');
        ActiveControl := edtSifre;
      end;
    kiAdSoyad:
      begin
        Caption := TF('KUL_BASLIK_ADSOYAD', [Kullanici]);
        ActiveControl := edtIsim;
      end;
  end;
  YuksekligiAyarla;
end;

{ Gorunen satirlara gore pencere yuksekligi. }
procedure TfrmKullaniciDuzenle.YuksekligiAyarla;
var
  Panel: TPanel;
  Yukseklik: Integer;
begin
  Yukseklik := pnlAlt.Height;
  for Panel in [pnlAd, pnlSifre, pnlSifre2, pnlIsim, pnlSoyad, pnlYonetici] do
    if Panel.Visible then
      Yukseklik := Yukseklik + Panel.Height;
  if pnlHata.Visible then
  begin
    btnAyrinti.Top := lblHata.Top + lblHata.Height + lblHata.Margins.Bottom;
    pnlHata.Height := btnAyrinti.Top + btnAyrinti.Height + 8;
    if memAyrinti.Visible then
      pnlHata.Height := pnlHata.Height + memAyrinti.Height + 12;
    Yukseklik := Yukseklik + pnlHata.Height;
  end;
  ClientHeight := Yukseklik;
end;

procedure TfrmKullaniciDuzenle.HataGoster(const Anlasilir, Ayrinti: string);
begin
  lblHata.Caption := Anlasilir;
  memAyrinti.Text := Ayrinti;
  memAyrinti.Visible := False;
  btnAyrinti.Visible := Ayrinti <> '';
  pnlHata.Visible := True;
  YuksekligiAyarla;
end;

procedure TfrmKullaniciDuzenle.HatayiGizle;
begin
  pnlHata.Visible := False;
  memAyrinti.Visible := False;
  YuksekligiAyarla;
end;

procedure TfrmKullaniciDuzenle.btnAyrintiClick(Sender: TObject);
begin
  memAyrinti.Visible := not memAyrinti.Visible;
  YuksekligiAyarla;
end;

{ Tamam: isi uKullanici yapar. Kural hatasi ve sunucu hatasi pencerede gosterilir, pencere acik kalir. }
procedure TfrmKullaniciDuzenle.btnTamamClick(Sender: TObject);
var
  Uyari: string;
begin
  HatayiGizle;
  if FIslem <> kiAdSoyad then
  begin
    Uyari := SifreUyarisi(FBag, edtSifre.Text);
    if Uyari <> '' then
      UyariGoster(Uyari);
  end;
  if (FIslem = kiEkle) and chkYonetici.Visible and chkYonetici.Checked and not OnayIste(T('ONAY_YONETICI_YAP')) then
    Exit;
  try
    case FIslem of
      kiEkle:
        begin
          KullaniciEkle(FBag, edtAd.Text, edtSifre.Text, edtSifre2.Text, edtIsim.Text, edtSoyad.Text,
            chkYonetici.Visible and chkYonetici.Checked);
          FKullanici := KullaniciAdiniDogrula(edtAd.Text);
        end;
      kiSifre:
        SifreDegistir(FBag, FKullanici, edtSifre.Text, edtSifre2.Text);
      kiAdSoyad:
        AdSoyadDegistir(FBag, FKullanici, edtIsim.Text, edtSoyad.Text);
    end;
  except
    on E: EKullaniciYarim do
    begin
      { Kullanici eklendi, yalniz yonetici yapilamadi: pencere kapanir, liste yenilenir. }
      FKullanici := KullaniciAdiniDogrula(edtAd.Text);
      UyariGoster(E.Message);
      ModalResult := mrOk;
      Exit;
    end;
    on E: EKullaniciKurali do
    begin
      HataGoster(E.Message, '');
      Exit;
    end;
    on E: Exception do
    begin
      HataGoster(HataMetniniCevir(E), E.Message);
      Exit;
    end;
  end;
  ModalResult := mrOk;
end;

end.
