{ fBaglanti.pas - Baglanti penceresi (yeni baglanti kaydi veya mevcut kaydi duzenleme).
  Form sadece arayuzu bilir; baglanma, kayit ve sifreleme uBaglanti'dadir.
  "Kaydet" sadece kaydeder. "Baglan" baglanir, basarili olursa kaydeder. }
unit fBaglanti;

interface

uses
  System.SysUtils, System.Classes, Vcl.Controls, Vcl.Forms, Vcl.StdCtrls,
  Vcl.ExtCtrls, Vcl.Dialogs,
  uDil, uBaglanti, uOnay, uSunucuBul, fSunucuSec;

type
  TBaglantiSonucu = (bsIptal, bsKaydedildi, bsBaglandi);

  TfrmBaglanti = class(TForm)
    pnlSag: TPanel;
    lblAd: TLabel;
    edtAd: TEdit;
    lblSunucu: TLabel;
    edtSunucu: TEdit;
    btnSunucular: TButton;
    lblPort: TLabel;
    edtPort: TEdit;
    lblYol: TLabel;
    edtYol: TEdit;
    btnGozat: TButton;
    lblKullanici: TLabel;
    edtKullanici: TEdit;
    lblSifre: TLabel;
    edtSifre: TEdit;
    lblKarakter: TLabel;
    cmbKarakter: TComboBox;
    btnAlgila: TButton;
    chkSifreKaydet: TCheckBox;
    pnlHata: TPanel;
    lblHata: TLabel;
    btnAyrinti: TButton;
    memAyrinti: TMemo;
    pnlAlt: TPanel;
    btnKapat: TButton;
    btnBaglan: TButton;
    btnKaydet: TButton;
    btnOlustur: TButton;
    dlgAc: TOpenDialog;
    procedure FormCreate(Sender: TObject);
    procedure btnGozatClick(Sender: TObject);
    procedure btnAyrintiClick(Sender: TObject);
    procedure btnAlgilaClick(Sender: TObject);
    procedure btnSunucularClick(Sender: TObject);
    procedure btnKaydetClick(Sender: TObject);
    procedure btnOlusturClick(Sender: TObject);
    procedure btnBaglanClick(Sender: TObject);
    procedure btnKapatClick(Sender: TObject);
  private
    FEskiAd: string;
    FSonuc: TBaglantiSonucu;
    FKaydedilenAd: string;
    procedure YazilariYenile;
    procedure DugmeyiYaziyaUydur(Dugme: TButton);
    procedure AlanlariBosalt;
    procedure IlkSunucuyuBul;
    procedure AlanlaraYaz(const Tanim: TBaglantiTanimi);
    function AlanlardanOku(out Tanim: TBaglantiTanimi; AdKontrolu: Boolean = True): Boolean;
    function AdKullanilabilirMi(const Ad: string): Boolean;
    procedure HataGoster(const Anlasilir, Ayrinti: string);
    procedure HatayiGizle;
  public
    procedure Hazirla(const DuzenlenecekAd, KlonAd: string);
  end;

{ DuzenlenecekAd bos ise yeni kayit, doluysa o kayit duzenlenir.
  KlonAd doluysa yeni kayit, o kaydin bilgileriyle dolu ve "(kopya)" adiyla acilir.
  Kaydedilen (veya baglanilan) baglantinin adi KaydedilenAd'a yazilir. }
function BaglantiPenceresiniGoster(const DuzenlenecekAd, KlonAd: string;
  out KaydedilenAd: string): TBaglantiSonucu;

implementation

{$R *.dfm}

function BaglantiPenceresiniGoster(const DuzenlenecekAd, KlonAd: string;
  out KaydedilenAd: string): TBaglantiSonucu;
var
  Pencere: TfrmBaglanti;
begin
  Pencere := TfrmBaglanti.Create(Application);
  try
    Pencere.Hazirla(DuzenlenecekAd, KlonAd);
    Pencere.ShowModal;
    Result := Pencere.FSonuc;
    KaydedilenAd := Pencere.FKaydedilenAd;
  finally
    Pencere.Free;
  end;
end;

procedure TfrmBaglanti.FormCreate(Sender: TObject);
begin
  FSonuc := bsIptal;
  YazilariYenile;
  AlanlariBosalt;
end;

procedure TfrmBaglanti.Hazirla(const DuzenlenecekAd, KlonAd: string);
var
  Tanim: TBaglantiTanimi;
begin
  FEskiAd := DuzenlenecekAd;
  if KlonAd <> '' then
  begin
    if KayitliBaglantiBul(KlonAd, Tanim) then
    begin
      AlanlaraYaz(Tanim);
      edtAd.Text := TF('KLON_AD', [KlonAd]);
    end;
    Exit;
  end;
  if DuzenlenecekAd = '' then
  begin
    IlkSunucuyuBul;
    Exit;
  end;
  Caption := T('BAGLANTI_DUZENLE_BASLIK');
  if KayitliBaglantiBul(DuzenlenecekAd, Tanim) then
    AlanlaraYaz(Tanim);
end;

procedure TfrmBaglanti.YazilariYenile;
begin
  Caption := T('BAGLANTI_BASLIK');
  lblAd.Caption := T('LBL_BAGLANTI_AD');
  lblSunucu.Caption := T('LBL_SUNUCU');
  lblPort.Caption := T('LBL_PORT');
  lblYol.Caption := T('LBL_VERITABANI');
  lblKullanici.Caption := T('LBL_KULLANICI');
  lblSifre.Caption := T('LBL_SIFRE');
  lblKarakter.Caption := T('LBL_KARAKTER_SETI');
  chkSifreKaydet.Caption := T('CHK_SIFRE_KAYDET');
  btnAyrinti.Caption := T('AYRINTI');
  btnAlgila.Caption := T('BTN_KARAKTER_ALGILA');
  btnSunucular.Caption := T('BTN_SUNUCULAR');
  btnBaglan.Caption := T('BTN_BAGLAN');
  btnKaydet.Caption := T('BTN_KAYDET');
  btnOlustur.Caption := T('BTN_VT_OLUSTUR');
  btnKapat.Caption := T('BTN_KAPAT');
  dlgAc.Filter := T('DOSYA_FILTRE');
  DugmeyiYaziyaUydur(btnOlustur);
  DugmeyiYaziyaUydur(btnAyrinti);
  DugmeyiYaziyaUydur(btnAlgila);
  DugmeyiYaziyaUydur(btnSunucular);
  DugmeyiYaziyaUydur(btnBaglan);
  DugmeyiYaziyaUydur(btnKaydet);
  DugmeyiYaziyaUydur(btnKapat);
end;

{ Dugme genisligi yaziya gore uzar (Almanca yazilar kesilmesin). }
procedure TfrmBaglanti.DugmeyiYaziyaUydur(Dugme: TButton);
begin
  Dugme.Width := Dugme.Constraints.MinWidth;
  if Canvas.TextWidth(Dugme.Caption) + 32 > Dugme.Width then
    Dugme.Width := Canvas.TextWidth(Dugme.Caption) + 32;
end;

procedure TfrmBaglanti.AlanlariBosalt;
begin
  edtAd.Text := '';
  edtSunucu.Text := VARSAYILAN_SUNUCU;
  edtPort.Text := IntToStr(VARSAYILAN_PORT);
  edtYol.Text := '';
  edtKullanici.Text := VARSAYILAN_KULLANICI;
  edtSifre.Text := '';
  cmbKarakter.Text := VARSAYILAN_KARAKTER_SETI;
  chkSifreKaydet.Checked := False;
  HatayiGizle;
end;

{ Yeni baglanti acilirken bu bilgisayardaki Firebird sunucularina bakilir: varsayilan port (3050) bir Firebird sunucusu
  degilse ve baska bir sunucu bulunduysa port onunla doldurulur (kullanici bilmeden bos porta baglanmaya calismasin).
  Birden fazla sunucu varsa "Sunucular" dugmesiyle secilir. }
procedure TfrmBaglanti.IlkSunucuyuBul;
var
  Bulunanlar: TArray<TBulunanSunucu>;
  Kayit: TBulunanSunucu;
begin
  Screen.Cursor := crHourGlass;
  try
    Bulunanlar := SunuculariBul('localhost');
  finally
    Screen.Cursor := crDefault;
  end;
  if Length(Bulunanlar) = 0 then
    Exit;
  for Kayit in Bulunanlar do
    if Kayit.Port = VARSAYILAN_PORT then
      Exit;
  edtPort.Text := IntToStr(Bulunanlar[0].Port);
end;

{ "Sunucular": yazilan sunucuda (bos = bu bilgisayar) calisan Firebird sunuculari listelenir, secilen sunucu ve port
  alanlara yazilir. }
procedure TfrmBaglanti.btnSunucularClick(Sender: TObject);
var
  Sunucu: string;
  Port: Integer;
begin
  if SunucuSec(Trim(edtSunucu.Text), Sunucu, Port) then
  begin
    edtSunucu.Text := Sunucu;
    edtPort.Text := IntToStr(Port);
  end;
end;

procedure TfrmBaglanti.AlanlaraYaz(const Tanim: TBaglantiTanimi);
begin
  edtAd.Text := Tanim.Ad;
  edtSunucu.Text := Tanim.Sunucu;
  edtPort.Text := IntToStr(Tanim.Port);
  edtYol.Text := Tanim.VeritabaniYolu;
  edtKullanici.Text := Tanim.Kullanici;
  edtSifre.Text := Tanim.Sifre;
  cmbKarakter.Text := Tanim.KarakterSeti;
  chkSifreKaydet.Checked := Tanim.SifreyiKaydet;
  HatayiGizle;
end;

{ Alanlari kontrol eder. Hata varsa pencerede yazar ve False doner. }
function TfrmBaglanti.AlanlardanOku(out Tanim: TBaglantiTanimi; AdKontrolu: Boolean): Boolean;
var
  Port: Integer;
begin
  Result := False;
  Tanim := Default(TBaglantiTanimi);
  if Trim(edtYol.Text) = '' then
  begin
    HataGoster(T('ERR_YOL_BOS'), '');
    Exit;
  end;
  if not TryStrToInt(Trim(edtPort.Text), Port) or (Port < 1) or (Port > 65535) then
  begin
    HataGoster(T('ERR_PORT'), '');
    Exit;
  end;
  Tanim.Sunucu := Trim(edtSunucu.Text);
  Tanim.Port := Port;
  Tanim.VeritabaniYolu := Trim(edtYol.Text);
  Tanim.Kullanici := Trim(edtKullanici.Text);
  Tanim.Sifre := edtSifre.Text;
  Tanim.KarakterSeti := Trim(cmbKarakter.Text);
  Tanim.SifreyiKaydet := chkSifreKaydet.Checked;
  Tanim.Ad := Trim(edtAd.Text);
  if Tanim.Ad = '' then
    Tanim.Ad := Tanim.Sunucu + ' - ' + ExtractFileName(StringReplace(Tanim.VeritabaniYolu, '/', '\', [rfReplaceAll]));
  if AdKontrolu and not AdKullanilabilirMi(Tanim.Ad) then
    Exit;
  Result := True;
end;

{ Ayni adli baska bir kayit varsa kullanilamaz (duzenlerken kendi adi serbest). }
function TfrmBaglanti.AdKullanilabilirMi(const Ad: string): Boolean;
var
  Baska: TBaglantiTanimi;
begin
  Result := True;
  if (FEskiAd <> '') and SameText(FEskiAd, Ad) then
    Exit;
  if KayitliBaglantiBul(Ad, Baska) then
  begin
    HataGoster(TF('ERR_AD_VAR', [Ad]), '');
    Result := False;
  end;
end;

procedure TfrmBaglanti.HataGoster(const Anlasilir, Ayrinti: string);
begin
  lblHata.Caption := Anlasilir;
  memAyrinti.Text := Ayrinti;
  memAyrinti.Visible := False;
  btnAyrinti.Visible := Ayrinti <> '';
  pnlHata.Visible := True;
end;

procedure TfrmBaglanti.HatayiGizle;
begin
  pnlHata.Visible := False;
  memAyrinti.Visible := False;
end;

procedure TfrmBaglanti.btnGozatClick(Sender: TObject);
begin
  if dlgAc.Execute then
    edtYol.Text := dlgAc.FileName;
end;

procedure TfrmBaglanti.btnAyrintiClick(Sender: TObject);
begin
  memAyrinti.Visible := not memAyrinti.Visible;
end;

{ "Algila": girilen sunucu, yol, kullanici ve sifreyle veritabanina gecici baglanir, karakter setini okuyup kutuya yazar
  (yanlis karakter setiyle baglanilmasin). Baglanti kaydedilmez ve acik birakilmaz. }
procedure TfrmBaglanti.btnAlgilaClick(Sender: TObject);
var
  Tanim: TBaglantiTanimi;
  Bulunan: string;
begin
  if not AlanlardanOku(Tanim, False) then
    Exit;
  HatayiGizle;
  Screen.Cursor := crHourGlass;
  try
    try
      Bulunan := KarakterSetiAlgila(Tanim);
    except
      on E: Exception do
      begin
        HataGoster(HataMetniniCevir(E), E.Message);
        Exit;
      end;
    end;
  finally
    Screen.Cursor := crDefault;
  end;
  { Karakter seti kutusu acik gelir (IBExpert gibi); Algila veritabanindakini okuyup kutuyu kapatir. Veritabaninin
    varsayilan karakter seti yoksa (NONE) kutu acik kalir ve kullanici secer. }
  if SameText(Bulunan, 'NONE') then
  begin
    cmbKarakter.Text := VARSAYILAN_KARAKTER_SETI;
    cmbKarakter.Enabled := True;
    UyariGoster(TF('MSG_KARAKTER_NONE', [VARSAYILAN_KARAKTER_SETI]));
  end
  else
  begin
    cmbKarakter.Text := Bulunan;
    cmbKarakter.Enabled := False;
    UyariGoster(TF('MSG_KARAKTER_ALGILANDI', [Bulunan]));
  end;
end;

procedure TfrmBaglanti.btnKaydetClick(Sender: TObject);
var
  Tanim: TBaglantiTanimi;
begin
  if not AlanlardanOku(Tanim) then
    Exit;
  HatayiGizle;
  try
    BaglantiKaydet(Tanim, FEskiAd);
  except
    on E: Exception do
    begin
      HataGoster(T('ERR_KAYDEDILEMEDI'), E.Message);
      Exit;
    end;
  end;
  FKaydedilenAd := Tanim.Ad;
  FSonuc := bsKaydedildi;
  ModalResult := mrOk;
end;

{ "Veritabani olustur": yazilan sunucu, yol, kullanici, sifre ve karakter setiyle YENI, bos bir veritabani kurar,
  sonra "Baglan" gibi baglanir ve kaydeder. Calisacak CREATE DATABASE onay penceresinde yazili gorunur. }
procedure TfrmBaglanti.btnOlusturClick(Sender: TObject);
var
  Tanim: TBaglantiTanimi;
begin
  { Karakter seti kutusu mevcut veritabani icin kapalidir; yeni veritabaninda kullanici secer. }
  cmbKarakter.Enabled := True;
  if Trim(cmbKarakter.Text) = '' then
    cmbKarakter.Text := VARSAYILAN_KARAKTER_SETI;
  if not AlanlardanOku(Tanim) then
    Exit;
  HatayiGizle;
  if not OnayIste(TF('ONAY_VT_OLUSTUR', [VeritabaniOlusturSql(Tanim)])) then
    Exit;
  Screen.Cursor := crHourGlass;
  try
    try
      FbVeritabaniOlustur(Tanim);
    except
      on E: Exception do
      begin
        HataGoster(HataMetniniCevir(E), E.Message);
        Exit;
      end;
    end;
  finally
    Screen.Cursor := crDefault;
  end;
  btnBaglanClick(Sender);
end;

procedure TfrmBaglanti.btnBaglanClick(Sender: TObject);
var
  Tanim: TBaglantiTanimi;
begin
  if not AlanlardanOku(Tanim) then
    Exit;
  HatayiGizle;
  Screen.Cursor := crHourGlass;
  try
    try
      { Karakter seti baglanirken otomatik algilanir; kullanilan set kutuda gorunur ve kayda yazilir. }
      Tanim.KarakterSeti := FbBaglan(Tanim).Tanim.KarakterSeti;
      cmbKarakter.Text := Tanim.KarakterSeti;
    except
      on E: Exception do
      begin
        HataGoster(HataMetniniCevir(E), E.Message);
        Exit;
      end;
    end;
  finally
    Screen.Cursor := crDefault;
  end;
  { Baglanti kuruldu. Kayit basarisiz olsa bile baglanti acik kalir ve pencere kapanir. }
  try
    BaglantiKaydet(Tanim, FEskiAd);
  except
    on E: Exception do
      UyariGoster(T('ERR_KAYIT_BASARISIZ') + #13#10#13#10 + T('AYRINTI') + ': ' + E.Message);
  end;
  FKaydedilenAd := Tanim.Ad;
  FSonuc := bsBaglandi;
  ModalResult := mrOk;
end;

procedure TfrmBaglanti.btnKapatClick(Sender: TObject);
begin
  ModalResult := mrCancel;
end;

end.
