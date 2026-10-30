{ fKolonIslem.pas - Kolon islemi penceresi (Asama 3g-2): ekle, adini degistir, tip / NOT NULL / varsayilan degistir, sil.
  Pencere yalniz alanlari toplar ve komut onizlemesini gosterir; komutu uKolon uretir ve calistirir. }
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
    edtTip: TEdit;
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
    procedure FormCloseQuery(Sender: TObject; var CanClose: Boolean);
  private
    FBag: TAcikBaglanti;
    FEski: TKolonGirdisi;
    function GirdiOku: TKolonGirdisi;
  end;

{ Pencereyi acar. Tamam'da Yeni'ye girilen degerleri koyar (komut onizlemesi pencerede gorunur), True doner. }
function KolonPenceresiGoster(Bag: TAcikBaglanti; const Eski: TKolonGirdisi; out Yeni: TKolonGirdisi): Boolean;

implementation

{$R *.dfm}

function TfrmKolonIslem.GirdiOku: TKolonGirdisi;
begin
  Result := FEski;
  Result.YeniAd := Trim(edtAd.Text);
  Result.Tip := Trim(edtTip.Text);
  Result.Varsayilan := Trim(edtVarsayilan.Text);
  Result.BosOlmaz := chkBosOlmaz.Checked;
end;

procedure TfrmKolonIslem.AlanDegisti(Sender: TObject);
begin
  memKomut.Text := KolonKomutlari(FBag, FEski, GirdiOku);
end;

procedure TfrmKolonIslem.FormCloseQuery(Sender: TObject; var CanClose: Boolean);
var
  Uyari: string;
begin
  if ModalResult <> mrOk then
    Exit;
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
    Pencere.edtTip.Visible := Pencere.lblTip.Visible;
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
    Pencere.edtTip.Text := Eski.Tip;
    Pencere.edtVarsayilan.Text := Eski.Varsayilan;
    Pencere.chkBosOlmaz.Checked := Eski.BosOlmaz;
    Pencere.AlanDegisti(nil);
    Result := Pencere.ShowModal = mrOk;
    if Result then
      Yeni := Pencere.GirdiOku;
  finally
    Pencere.Free;
  end;
end;

end.
