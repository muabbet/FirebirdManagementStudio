{ fKolonIslem.pas - Kolon islemi penceresi (Asama 3g-2): ekle, adini degistir, tip / NOT NULL / varsayilan degistir, sil.
  Pencere yalniz alanlari toplar ve komut onizlemesini gosterir; komutu uKolon uretir ve calistirir.
  Veri tipi listeden secilir (liste veri_tipleri.txt'ten, bagli surume gore + veritabaninin domain'leri); VARCHAR / CHAR
  icin uzunluk, NUMERIC / DECIMAL icin toplam basamak ve olcek ayri kutularda sorulur. }
unit fKolonIslem;

interface

uses
  System.SysUtils, System.Classes, Vcl.Controls, Vcl.Forms, Vcl.StdCtrls, Vcl.ExtCtrls,
  uDil, uBaglanti, uMetadata, uKolon, uOnay;

type
  TfrmKolonIslem = class(TForm)
    lblAd: TLabel;
    edtAd: TEdit;
    lblTip: TLabel;
    cmbTip: TComboBox;
    lblUzunluk: TLabel;
    edtUzunluk: TEdit;
    lblHassasiyet: TLabel;
    edtHassasiyet: TEdit;
    lblOlcek: TLabel;
    edtOlcek: TEdit;
    lblVarsayilan: TLabel;
    edtVarsayilan: TEdit;
    chkBosOlmaz: TCheckBox;
    lblNot: TLabel;
    lblKomut: TLabel;
    memKomut: TMemo;
    pnlAlt: TPanel;
    btnIptal: TButton;
    btnTamam: TButton;
    procedure AlanDegisti(Sender: TObject);
    procedure TipDegisti(Sender: TObject);
    procedure FormCloseQuery(Sender: TObject; var CanClose: Boolean);
  private
    FBag: TAcikBaglanti;
    FEski: TKolonGirdisi;
    FTipler: TArray<TVeriTipi>;
    { Pencere acilirken mevcut tipin listedeki yeri ve sayilari; degismediyse eski tip metni aynen korunur
      (CHARACTER SET gibi ekler kaybolmasin). FIlkSira -1: ekleme (eski tip yok). }
    FIlkSira: Integer;
    FIlkSayi1: Integer;
    FIlkSayi2: Integer;
    { Listede olmayan mevcut tip icin eklenen "(mevcut) ..." maddesinin sirasi; yoksa -1. }
    FMevcutSira: Integer;
    function GirdiOku: TKolonGirdisi;
    function SeciliTip: TVeriTipi;
    function SeciliTipVarMi: Boolean;
    procedure TipleriDoldur;
    procedure GorunurlukAyarla;
    procedure SayilariVarsayilanYap;
  end;

{ Pencereyi acar. Tamam'da Yeni'ye girilen degerleri koyar (komut onizlemesi pencerede gorunur), True doner. }
function KolonPenceresiGoster(Bag: TAcikBaglanti; const Eski: TKolonGirdisi; out Yeni: TKolonGirdisi): Boolean;

implementation

{$R *.dfm}

function TfrmKolonIslem.SeciliTipVarMi: Boolean;
begin
  Result := (cmbTip.ItemIndex >= 0) and (cmbTip.ItemIndex < Length(FTipler));
end;

function TfrmKolonIslem.SeciliTip: TVeriTipi;
begin
  if SeciliTipVarMi then
    Result := FTipler[cmbTip.ItemIndex]
  else
    Result := Default(TVeriTipi);
end;

function TfrmKolonIslem.GirdiOku: TKolonGirdisi;
var
  Sayi1, Sayi2: Integer;
begin
  Result := FEski;
  Result.YeniAd := Trim(edtAd.Text);
  Result.Varsayilan := Trim(edtVarsayilan.Text);
  Result.BosOlmaz := chkBosOlmaz.Checked;
  { Ad ve silme islemlerinde tip alanlari gizli: tip aynen kalir. }
  if not (FEski.Islem in [kiEkle, kiDegistir]) then
    Exit;
  Sayi1 := StrToIntDef(edtUzunluk.Text, 0);
  Sayi2 := StrToIntDef(edtOlcek.Text, 0);
  if SeciliTip.Parametre = tpHassasiyet then
    Sayi1 := StrToIntDef(edtHassasiyet.Text, 0);
  if cmbTip.ItemIndex = FMevcutSira then
    Result.Tip := FEski.Tip
  else if (cmbTip.ItemIndex = FIlkSira) and (Sayi1 = FIlkSayi1) and (Sayi2 = FIlkSayi2) and (FEski.Tip <> '') then
    Result.Tip := FEski.Tip
  else if SeciliTipVarMi then
    Result.Tip := TipMetniOlustur(SeciliTip, Sayi1, Sayi2)
  else
    Result.Tip := '';
end;

{ Listeyi doldurur ve baslangic secimini yapar: ekleme = VARCHAR, degistirme = kolonun mevcut tipi. }
procedure TfrmKolonIslem.TipleriDoldur;
var
  i, Sira, S1, S2: Integer;
begin
  FTipler := KolonTipleri(FBag);
  cmbTip.Items.Clear;
  for i := 0 to High(FTipler) do
    if FTipler[i].Domain then
      cmbTip.Items.Add(TF('KOLON_TIP_DOMAIN', [FTipler[i].Ad]))
    else
      cmbTip.Items.Add(FTipler[i].Ad);
  FIlkSira := -1;
  FMevcutSira := -1;
  if FEski.Islem = kiDegistir then
  begin
    if TipAyristir(FEski.Tip, FTipler, Sira, S1, S2) then
    begin
      cmbTip.ItemIndex := Sira;
      FIlkSira := Sira;
      FIlkSayi1 := S1;
      FIlkSayi2 := S2;
      edtUzunluk.Text := IntToStr(S1);
      edtHassasiyet.Text := IntToStr(S1);
      edtOlcek.Text := IntToStr(S2);
    end
    else
    begin
      FMevcutSira := cmbTip.Items.Add(TF('KOLON_TIP_MEVCUT', [FEski.Tip]));
      cmbTip.ItemIndex := FMevcutSira;
    end;
  end
  else
  begin
    for i := 0 to High(FTipler) do
      if SameText(FTipler[i].Ad, 'VARCHAR') then
        cmbTip.ItemIndex := i;
    SayilariVarsayilanYap;
  end;
end;

{ Secilen tipin onceden yazili sayilarini kutulara koyar (VARCHAR 50, NUMERIC 18 ve 2 gibi). }
procedure TfrmKolonIslem.SayilariVarsayilanYap;
begin
  if not SeciliTipVarMi then
    Exit;
  edtUzunluk.Text := IntToStr(SeciliTip.Varsayilan1);
  edtHassasiyet.Text := IntToStr(SeciliTip.Varsayilan1);
  edtOlcek.Text := IntToStr(SeciliTip.Varsayilan2);
end;

{ Uzunluk, toplam basamak ve olcek kutulari yalniz secilen tip isterse gorunur. }
procedure TfrmKolonIslem.GorunurlukAyarla;
var
  TipAlani: Boolean;
begin
  TipAlani := FEski.Islem in [kiEkle, kiDegistir];
  lblUzunluk.Visible := TipAlani and (SeciliTip.Parametre = tpUzunluk);
  edtUzunluk.Visible := lblUzunluk.Visible;
  lblHassasiyet.Visible := TipAlani and (SeciliTip.Parametre = tpHassasiyet);
  edtHassasiyet.Visible := lblHassasiyet.Visible;
  lblOlcek.Visible := lblHassasiyet.Visible;
  edtOlcek.Visible := lblHassasiyet.Visible;
end;

procedure TfrmKolonIslem.TipDegisti(Sender: TObject);
begin
  SayilariVarsayilanYap;
  AlanDegisti(Sender);
end;

procedure TfrmKolonIslem.AlanDegisti(Sender: TObject);
begin
  GorunurlukAyarla;
  memKomut.Text := KolonKomutlari(FBag, FEski, GirdiOku);
end;

procedure TfrmKolonIslem.FormCloseQuery(Sender: TObject; var CanClose: Boolean);
var
  Uyari: string;
begin
  if ModalResult <> mrOk then
    Exit;
  Uyari := '';
  if (FEski.Islem in [kiEkle, kiDegistir]) and (cmbTip.ItemIndex <> FMevcutSira) and SeciliTipVarMi then
  begin
    if SeciliTip.Parametre = tpHassasiyet then
      Uyari := TipSayilariniDogrula(FBag, SeciliTip, StrToIntDef(edtHassasiyet.Text, 0), StrToIntDef(edtOlcek.Text, 0))
    else
      Uyari := TipSayilariniDogrula(FBag, SeciliTip, StrToIntDef(edtUzunluk.Text, 0), 0);
  end;
  if Uyari = '' then
    Uyari := KolonGirdisiniDogrula(GirdiOku);
  if (Uyari = '') and (Trim(memKomut.Text) = '') then
    Uyari := T('ERR_KOLON_DEGISIKLIK_YOK');
  if Uyari <> '' then
  begin
    UyariGoster(Uyari);
    CanClose := False;
  end;
end;

function KolonPenceresiGoster(Bag: TAcikBaglanti; const Eski: TKolonGirdisi; out Yeni: TKolonGirdisi): Boolean;
const
  BASLIKLAR: array[TKolonIslemi] of string = ('KOLON_BASLIK_EKLE', 'KOLON_BASLIK_AD', 'KOLON_BASLIK_DEGISTIR', 'KOLON_BASLIK_SIL');
var
  Pencere: TfrmKolonIslem;
begin
  Pencere := TfrmKolonIslem.Create(Application);
  try
    Pencere.FBag := Bag;
    Pencere.FEski := Eski;
    Pencere.Caption := TF(BASLIKLAR[Eski.Islem], [Eski.Tablo, Eski.Kolon]);
    Pencere.lblAd.Caption := T('KOLON_ETIKET_AD');
    Pencere.lblTip.Caption := T('KOLON_ETIKET_TIP');
    Pencere.lblUzunluk.Caption := T('KOLON_ETIKET_UZUNLUK');
    Pencere.lblHassasiyet.Caption := T('KOLON_ETIKET_HASSASIYET');
    Pencere.lblOlcek.Caption := T('KOLON_ETIKET_OLCEK');
    Pencere.lblVarsayilan.Caption := T('KOLON_ETIKET_VARSAYILAN');
    Pencere.chkBosOlmaz.Caption := T('KOLON_ETIKET_BOS_OLMAZ');
    Pencere.lblKomut.Caption := T('KOLON_ETIKET_KOMUT');
    Pencere.btnTamam.Caption := T('BTN_TAMAM');
    Pencere.btnIptal.Caption := T('BTN_IPTAL');
    DugmeyiYaziyaUydur(Pencere.btnTamam);
    DugmeyiYaziyaUydur(Pencere.btnIptal);
    { Hangi alanlar islemin parcasi: ekle = hepsi, ad = yalniz ad, degistir = tip/varsayilan/NOT NULL, sil = hicbiri. }
    Pencere.lblAd.Visible := Eski.Islem in [kiEkle, kiAd];
    Pencere.edtAd.Visible := Pencere.lblAd.Visible;
    Pencere.lblTip.Visible := Eski.Islem in [kiEkle, kiDegistir];
    Pencere.cmbTip.Visible := Pencere.lblTip.Visible;
    Pencere.lblVarsayilan.Visible := Pencere.lblTip.Visible;
    Pencere.edtVarsayilan.Visible := Pencere.lblTip.Visible;
    Pencere.chkBosOlmaz.Visible := Pencere.lblTip.Visible;
    Pencere.lblNot.Visible := False;
    if Eski.Islem = kiSil then
    begin
      Pencere.lblNot.Caption := T('KOLON_SIL_NOT');
      Pencere.lblNot.Visible := True;
    end;
    { Firebird 2.5'te NOT NULL degistirilemez: kutu kapali, nedeni yazili. }
    if (Eski.Islem = kiDegistir) and not KolonNullDegistirilebilir(Bag) then
    begin
      Pencere.chkBosOlmaz.Enabled := False;
      Pencere.lblNot.Caption := T('KOLON_NULL_YOK_25');
      Pencere.lblNot.Visible := True;
    end;
    Pencere.edtAd.Text := Eski.YeniAd;
    Pencere.edtVarsayilan.Text := Eski.Varsayilan;
    Pencere.chkBosOlmaz.Checked := Eski.BosOlmaz;
    if Eski.Islem in [kiEkle, kiDegistir] then
      Pencere.TipleriDoldur;
    Pencere.AlanDegisti(nil);
    Result := Pencere.ShowModal = mrOk;
    if Result then
      Yeni := Pencere.GirdiOku;
  finally
    Pencere.Free;
  end;
end;

end.
