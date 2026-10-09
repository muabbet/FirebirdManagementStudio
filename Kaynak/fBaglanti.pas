{ fBaglanti.pas - Baglanti penceresi.
  Form sadece arayuzu bilir; baglanma, kayit ve sifreleme uBaglanti'dadir.
  Basarili baglantida pencere kapanir ve baglanti kayitli listeye eklenir. }
unit fBaglanti;

interface

uses
  System.SysUtils, System.Classes, Vcl.Controls, Vcl.Forms, Vcl.StdCtrls,
  Vcl.ExtCtrls, Vcl.Dialogs,
  uDil, uBaglanti, uOnay;

type
  TfrmBaglanti = class(TForm)
    pnlSol: TPanel;
    lblKayitli: TLabel;
    lstKayitli: TListBox;
    pnlSag: TPanel;
    lblAd: TLabel;
    edtAd: TEdit;
    lblSunucu: TLabel;
    edtSunucu: TEdit;
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
    chkSifreKaydet: TCheckBox;
    pnlHata: TPanel;
    lblHata: TLabel;
    btnAyrinti: TButton;
    memAyrinti: TMemo;
    pnlAlt: TPanel;
    btnKapat: TButton;
    btnBaglan: TButton;
    btnSil: TButton;
    btnYeni: TButton;
    dlgAc: TOpenDialog;
    procedure FormCreate(Sender: TObject);
    procedure lstKayitliClick(Sender: TObject);
    procedure btnYeniClick(Sender: TObject);
    procedure btnSilClick(Sender: TObject);
    procedure btnGozatClick(Sender: TObject);
    procedure btnAyrintiClick(Sender: TObject);
    procedure btnBaglanClick(Sender: TObject);
    procedure btnKapatClick(Sender: TObject);
  private
    FKayitlilar: TArray<TBaglantiTanimi>;
    procedure YazilariYenile;
    procedure DugmeyiYaziyaUydur(Dugme: TButton);
    procedure ListeyiDoldur;
    procedure AlanlariBosalt;
    procedure AlanlaraYaz(const Tanim: TBaglantiTanimi);
    function AlanlardanOku(out Tanim: TBaglantiTanimi): Boolean;
    procedure HataGoster(const Anlasilir, Ayrinti: string);
    procedure HatayiGizle;
  end;

function BaglantiPenceresiniGoster: Boolean;

implementation

{$R *.dfm}

function BaglantiPenceresiniGoster: Boolean;
var
  Pencere: TfrmBaglanti;
begin
  Pencere := TfrmBaglanti.Create(Application);
  try
    Result := Pencere.ShowModal = mrOk;
  finally
    Pencere.Free;
  end;
end;

procedure TfrmBaglanti.FormCreate(Sender: TObject);
var
  Uyari: string;
begin
  YazilariYenile;
  ListeyiDoldur;
  AlanlariBosalt;
  { Kayitli baglanti dosyasi bozuksa silinmeden yanina tasinmistir, kullanici bilgilendirilir. }
  Uyari := BozukDosyaUyarisiAl;
  if Uyari <> '' then
    HataGoster(Uyari, '');
end;

procedure TfrmBaglanti.YazilariYenile;
begin
  Caption := T('BAGLANTI_BASLIK');
  lblKayitli.Caption := T('LBL_KAYITLI');
  lblAd.Caption := T('LBL_BAGLANTI_AD');
  lblSunucu.Caption := T('LBL_SUNUCU');
  lblPort.Caption := T('LBL_PORT');
  lblYol.Caption := T('LBL_VERITABANI');
  lblKullanici.Caption := T('LBL_KULLANICI');
  lblSifre.Caption := T('LBL_SIFRE');
  lblKarakter.Caption := T('LBL_KARAKTER_SETI');
  chkSifreKaydet.Caption := T('CHK_SIFRE_KAYDET');
  btnAyrinti.Caption := T('AYRINTI');
  btnBaglan.Caption := T('BTN_BAGLAN');
  btnKapat.Caption := T('BTN_KAPAT');
  btnYeni.Caption := T('BTN_YENI');
  btnSil.Caption := T('BTN_SIL');
  dlgAc.Filter := T('DOSYA_FILTRE');
  DugmeyiYaziyaUydur(btnAyrinti);
  DugmeyiYaziyaUydur(btnBaglan);
  DugmeyiYaziyaUydur(btnKapat);
  DugmeyiYaziyaUydur(btnYeni);
  DugmeyiYaziyaUydur(btnSil);
end;

{ Dugme genisligi yaziya gore uzar (Almanca yazilar kesilmesin). }
procedure TfrmBaglanti.DugmeyiYaziyaUydur(Dugme: TButton);
begin
  Dugme.Width := Dugme.Constraints.MinWidth;
  if Canvas.TextWidth(Dugme.Caption) + 32 > Dugme.Width then
    Dugme.Width := Canvas.TextWidth(Dugme.Caption) + 32;
end;

procedure TfrmBaglanti.ListeyiDoldur;
var
  Tanim: TBaglantiTanimi;
begin
  FKayitlilar := KayitliBaglantilar;
  lstKayitli.Items.BeginUpdate;
  try
    lstKayitli.Items.Clear;
    for Tanim in FKayitlilar do
      lstKayitli.Items.Add(Tanim.Ad);
  finally
    lstKayitli.Items.EndUpdate;
  end;
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
function TfrmBaglanti.AlanlardanOku(out Tanim: TBaglantiTanimi): Boolean;
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
  Result := True;
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

procedure TfrmBaglanti.lstKayitliClick(Sender: TObject);
begin
  if lstKayitli.ItemIndex >= 0 then
    AlanlaraYaz(FKayitlilar[lstKayitli.ItemIndex]);
end;

procedure TfrmBaglanti.btnYeniClick(Sender: TObject);
begin
  lstKayitli.ItemIndex := -1;
  AlanlariBosalt;
end;

procedure TfrmBaglanti.btnSilClick(Sender: TObject);
var
  Ad: string;
begin
  if lstKayitli.ItemIndex < 0 then
    Exit;
  Ad := FKayitlilar[lstKayitli.ItemIndex].Ad;
  if not OnayIste(TF('ONAY_BAGLANTI_SIL', [Ad])) then
    Exit;
  BaglantiListedenKaldir(Ad);
  ListeyiDoldur;
  AlanlariBosalt;
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
      FbBaglan(Tanim);
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
    BaglantiKaydet(Tanim);
  except
    on E: Exception do
      UyariGoster(T('ERR_KAYIT_BASARISIZ') + #13#10#13#10 + T('AYRINTI') + ': ' + E.Message);
  end;
  ModalResult := mrOk;
end;

procedure TfrmBaglanti.btnKapatClick(Sender: TObject);
begin
  ModalResult := mrCancel;
end;

end.
