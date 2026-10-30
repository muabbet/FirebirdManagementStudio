{ fYapiIslem.pas - Index olustur ve kisit ekle penceresi (Asama 3g-3).
  Pencere yalniz alanlari toplar ve komut onizlemesini gosterir; komutu uIndeksKisit uretir ve calistirir.
  Ayni pencere iki is icin kullanilir: Index (ad, kolonlar, UNIQUE, DESC) ve Kisit (tur secimine gore alanlar). }
unit fYapiIslem;

interface

uses
  System.SysUtils, System.Classes, Vcl.Controls, Vcl.Forms, Vcl.StdCtrls, Vcl.ExtCtrls,
  uDil, uBaglanti, uMetadata, uIndeksKisit, uOnay;

type
  TfrmYapiIslem = class(TForm)
    lblTur: TLabel;
    cmbTur: TComboBox;
    lblAd: TLabel;
    edtAd: TEdit;
    lblKolon: TLabel;
    edtKolon: TEdit;
    lblHedef: TLabel;
    cmbHedef: TComboBox;
    lblHedefKolon: TLabel;
    edtHedefKolon: TEdit;
    lblSil: TLabel;
    cmbSil: TComboBox;
    lblGuncelle: TLabel;
    cmbGuncelle: TComboBox;
    lblIfade: TLabel;
    edtIfade: TEdit;
    chkBenzersiz: TCheckBox;
    chkAzalan: TCheckBox;
    lblKomut: TLabel;
    memKomut: TMemo;
    pnlAlt: TPanel;
    btnIptal: TButton;
    btnTamam: TButton;
    procedure AlanDegisti(Sender: TObject);
    procedure FormCloseQuery(Sender: TObject; var CanClose: Boolean);
  private
    FBag: TAcikBaglanti;
    FTablo: string;
    FKisitMi: Boolean;
    function IndeksOku: TIndeksGirdisi;
    function KisitOku: TKisitGirdisi;
    procedure GorunurlukAyarla;
    function Uyari: string;
  end;

{ Tamam'da G'ye girilen degerleri koyar (komut onizlemesi pencerede gorunur), True doner. }
function IndeksPenceresiGoster(Bag: TAcikBaglanti; const Tablo: string; out G: TIndeksGirdisi): Boolean;
function KisitPenceresiGoster(Bag: TAcikBaglanti; const Tablo: string; out G: TKisitGirdisi): Boolean;

implementation

{$R *.dfm}

const
  { ON DELETE / ON UPDATE secenekleri; ilki (bos) "varsayilan" yazisiyla gorunur. }
  KURALLAR: array[0..4] of string = ('', 'CASCADE', 'SET NULL', 'SET DEFAULT', 'NO ACTION');

function TfrmYapiIslem.IndeksOku: TIndeksGirdisi;
begin
  Result := Default(TIndeksGirdisi);
  Result.Tablo := FTablo;
  Result.Ad := Trim(edtAd.Text);
  Result.Kolonlar := Trim(edtKolon.Text);
  Result.Benzersiz := chkBenzersiz.Checked;
  Result.Azalan := chkAzalan.Checked;
end;

function TfrmYapiIslem.KisitOku: TKisitGirdisi;
begin
  Result := Default(TKisitGirdisi);
  Result.Tablo := FTablo;
  { Combo sirasi TKisitTuru ile ayni: birincil, benzersiz, yabanci, check. }
  Result.Tur := TKisitTuru(cmbTur.ItemIndex);
  Result.Ad := Trim(edtAd.Text);
  Result.Kolonlar := Trim(edtKolon.Text);
  Result.HedefTablo := Trim(cmbHedef.Text);
  Result.HedefKolonlar := Trim(edtHedefKolon.Text);
  Result.SilKurali := KURALLAR[cmbSil.ItemIndex];
  Result.GuncelleKurali := KURALLAR[cmbGuncelle.ItemIndex];
  Result.Ifade := Trim(edtIfade.Text);
end;

{ Kisit turune gore hangi alanlar gorunur: PK/UNIQUE = ad+kolonlar, FK = + hedef ve kurallar, CHECK = ad+kosul. }
procedure TfrmYapiIslem.GorunurlukAyarla;
var
  Tur: TKisitTuru;
  YabanciMi, CheckMi: Boolean;
begin
  if not FKisitMi then
    Exit;
  Tur := TKisitTuru(cmbTur.ItemIndex);
  YabanciMi := Tur = ktYabanci;
  CheckMi := Tur = ktCheck;
  lblKolon.Visible := not CheckMi;
  edtKolon.Visible := not CheckMi;
  lblHedef.Visible := YabanciMi;
  cmbHedef.Visible := YabanciMi;
  lblHedefKolon.Visible := YabanciMi;
  edtHedefKolon.Visible := YabanciMi;
  lblSil.Visible := YabanciMi;
  cmbSil.Visible := YabanciMi;
  lblGuncelle.Visible := YabanciMi;
  cmbGuncelle.Visible := YabanciMi;
  lblIfade.Visible := CheckMi;
  edtIfade.Visible := CheckMi;
end;

procedure TfrmYapiIslem.AlanDegisti(Sender: TObject);
begin
  GorunurlukAyarla;
  if FKisitMi then
    memKomut.Text := KisitKomutu(FBag, yiOlustur, KisitOku)
  else
    memKomut.Text := IndeksKomutu(FBag, yiOlustur, IndeksOku);
end;

function TfrmYapiIslem.Uyari: string;
begin
  if FKisitMi then
    Result := KisitDogrula(KisitOku)
  else
    Result := IndeksDogrula(IndeksOku);
end;

procedure TfrmYapiIslem.FormCloseQuery(Sender: TObject; var CanClose: Boolean);
var
  Metin: string;
begin
  if ModalResult <> mrOk then
    Exit;
  Metin := Uyari;
  if Metin <> '' then
  begin
    UyariGoster(Metin);
    CanClose := False;
  end;
end;

{ Iki pencere icin ortak hazirlik: dugme yazilari, kural listeleri, hedef tablo listesi. }
function PencereKur(Bag: TAcikBaglanti; const Tablo: string; KisitMi: Boolean): TfrmYapiIslem;
var
  Ad: string;
  Kural: string;
begin
  Result := TfrmYapiIslem.Create(Application);
  Result.FBag := Bag;
  Result.FTablo := Tablo;
  Result.FKisitMi := KisitMi;
  Result.lblKolon.Caption := T('YAPI_ETIKET_KOLONLAR');
  Result.lblKomut.Caption := T('KOLON_ETIKET_KOMUT');
  Result.btnTamam.Caption := T('BTN_TAMAM');
  Result.btnIptal.Caption := T('BTN_IPTAL');
  DugmeyiYaziyaUydur(Result.btnTamam);
  DugmeyiYaziyaUydur(Result.btnIptal);
  { Hepsini gizle, isteneni ac. }
  Result.lblTur.Visible := KisitMi;
  Result.cmbTur.Visible := KisitMi;
  Result.lblHedef.Visible := False;
  Result.cmbHedef.Visible := False;
  Result.lblHedefKolon.Visible := False;
  Result.edtHedefKolon.Visible := False;
  Result.lblSil.Visible := False;
  Result.cmbSil.Visible := False;
  Result.lblGuncelle.Visible := False;
  Result.cmbGuncelle.Visible := False;
  Result.lblIfade.Visible := False;
  Result.edtIfade.Visible := False;
  Result.chkBenzersiz.Visible := not KisitMi;
  Result.chkAzalan.Visible := not KisitMi;
  if KisitMi then
  begin
    Result.Caption := TF('YAPI_BASLIK_KISIT', [Tablo]);
    Result.lblTur.Caption := T('YAPI_ETIKET_TUR');
    Result.lblAd.Caption := T('YAPI_ETIKET_AD_KISIT');
    Result.lblHedef.Caption := T('YAPI_ETIKET_HEDEF');
    Result.lblHedefKolon.Caption := T('YAPI_ETIKET_HEDEF_KOLON');
    Result.lblSil.Caption := T('YAPI_ETIKET_SIL');
    Result.lblGuncelle.Caption := T('YAPI_ETIKET_GUNCELLE');
    Result.lblIfade.Caption := T('YAPI_ETIKET_IFADE');
    Result.cmbTur.Items.Clear;
    Result.cmbTur.Items.Add(T('KISIT_PK'));
    Result.cmbTur.Items.Add(T('KISIT_UNIQUE'));
    Result.cmbTur.Items.Add(T('KISIT_FK'));
    Result.cmbTur.Items.Add(T('KISIT_CHECK'));
    Result.cmbTur.ItemIndex := 0;
    for Ad in TabloAdlari(Bag) do
      Result.cmbHedef.Items.Add(Ad);
    for Kural in KURALLAR do
    begin
      if Kural = '' then
      begin
        Result.cmbSil.Items.Add(T('YAPI_KURAL_VARSAYILAN'));
        Result.cmbGuncelle.Items.Add(T('YAPI_KURAL_VARSAYILAN'));
      end
      else
      begin
        Result.cmbSil.Items.Add(Kural);
        Result.cmbGuncelle.Items.Add(Kural);
      end;
    end;
    Result.cmbSil.ItemIndex := 0;
    Result.cmbGuncelle.ItemIndex := 0;
  end
  else
  begin
    Result.Caption := TF('YAPI_BASLIK_INDEKS', [Tablo]);
    Result.lblAd.Caption := T('YAPI_ETIKET_AD_INDEKS');
    Result.chkBenzersiz.Caption := T('YAPI_ETIKET_BENZERSIZ');
    Result.chkAzalan.Caption := T('YAPI_ETIKET_AZALAN');
  end;
  Result.AlanDegisti(nil);
end;

function IndeksPenceresiGoster(Bag: TAcikBaglanti; const Tablo: string; out G: TIndeksGirdisi): Boolean;
var
  Pencere: TfrmYapiIslem;
begin
  Pencere := PencereKur(Bag, Tablo, False);
  try
    Result := Pencere.ShowModal = mrOk;
    if Result then
      G := Pencere.IndeksOku;
  finally
    Pencere.Free;
  end;
end;

function KisitPenceresiGoster(Bag: TAcikBaglanti; const Tablo: string; out G: TKisitGirdisi): Boolean;
var
  Pencere: TfrmYapiIslem;
begin
  Pencere := PencereKur(Bag, Tablo, True);
  try
    Result := Pencere.ShowModal = mrOk;
    if Result then
      G := Pencere.KisitOku;
  finally
    Pencere.Free;
  end;
end;

end.
