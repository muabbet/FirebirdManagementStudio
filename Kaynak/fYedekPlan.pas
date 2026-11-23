{ fYedekPlan.pas - "Yedek planla" penceresi (7x).
  Form sadece arayuzu bilir; is uYedekPlan'dadir. Bir baglanti icin: klasor, saat, kac yedek tutulacagi.
  Planla: Windows Gorev Zamanlayici'ya gorev kurar ve plani yedekplanlari.json'a yazar. Plani kaldir: gorevi
  ve plani kaldirir (yedek dosyalarina dokunmaz). Simdi yedekle: ayni islemi hemen calistirir. }
unit fYedekPlan;

interface

uses
  Winapi.Windows, System.SysUtils, System.Classes, System.IOUtils, Vcl.Controls, Vcl.Forms,
  Vcl.StdCtrls, Vcl.ExtCtrls, Vcl.ComCtrls, Vcl.Dialogs, Vcl.Samples.Spin,
  uDil, uOnay, uBaglanti, uYedek, uYedekPlan, uYedekDogrula;

type
  TfrmYedekPlan = class(TForm)
    lblBaglanti: TLabel;
    lblKlasor: TLabel;
    lblSaat: TLabel;
    lblSakla: TLabel;
    lblNot: TLabel;
    lblDurum: TLabel;
    lblGunluk: TLabel;
    pbYedek: TProgressBar;
    edtKlasor: TEdit;
    btnKlasorSec: TButton;
    dtpSaat: TDateTimePicker;
    spnSakla: TSpinEdit;
    memGunluk: TMemo;
    memDogrula: TMemo;
    pnlAlt: TPanel;
    btnKapat: TButton;
    btnSimdi: TButton;
    btnDogrula: TButton;
    btnKaldir: TButton;
    btnPlanla: TButton;
    dlgKlasor: TFileOpenDialog;
    procedure btnKlasorSecClick(Sender: TObject);
    procedure btnPlanlaClick(Sender: TObject);
    procedure btnKaldirClick(Sender: TObject);
    procedure btnSimdiClick(Sender: TObject);
    procedure btnDogrulaClick(Sender: TObject);
    procedure btnKapatClick(Sender: TObject);
    procedure FormCloseQuery(Sender: TObject; var CanClose: Boolean);
  private
    FAd: string;
    FSonuc: TStrings;
    FSifreVar: Boolean;
    FCalisiyor: Boolean;
    FIptalIstendi: Boolean;
    FSonGuncelleme: Cardinal;
    FBaslangic: Cardinal;
    FIslemYazisi: string;
    procedure YazilariYaz;
    procedure DurumuYenile;
    procedure CalisiyorAyarla(Calisiyor: Boolean);
    procedure CiktiGeldi(const Satir: string; var Iptal: Boolean);
    function PlanFormdan: TYedekPlani;
  end;

{ Pencereyi gosterir. BaglantiAd: kayitli baglanti adi (sifresi kayitli olmali). Yapilan her is Sonuc'a
  (ana pencerenin sonuc alani) bir satir olarak eklenir. }
procedure YedekPlanPenceresiniGoster(const BaglantiAd: string; Sonuc: TStrings);

implementation

{$R *.dfm}

procedure YedekPlanPenceresiniGoster(const BaglantiAd: string; Sonuc: TStrings);
var
  Pencere: TfrmYedekPlan;
begin
  Pencere := TfrmYedekPlan.Create(Application);
  try
    Pencere.FAd := BaglantiAd;
    Pencere.FSonuc := Sonuc;
    Pencere.YazilariYaz;
    Pencere.ShowModal;
  finally
    Pencere.Free;
  end;
end;

procedure TfrmYedekPlan.YazilariYaz;
var
  Plan: TYedekPlani;
  Tanim: TBaglantiTanimi;
  Saat: TDateTime;
begin
  Caption := T('YEDEKPLAN_BASLIK') + ' - ' + FAd;
  lblBaglanti.Caption := TF('YEDEKPLAN_BAGLANTI', [FAd]);
  lblKlasor.Caption := T('YEDEKPLAN_KLASOR');
  lblSaat.Caption := T('YEDEKPLAN_SAAT');
  lblSakla.Caption := T('YEDEKPLAN_SAKLA');
  lblNot.Caption := T('YEDEKPLAN_NOT');
  lblGunluk.Caption := T('YEDEKPLAN_GUNLUK');
  btnKlasorSec.Caption := T('YEDEK_SEC');
  btnPlanla.Caption := T('YEDEKPLAN_PLANLA');
  btnKaldir.Caption := T('YEDEKPLAN_KALDIR');
  btnSimdi.Caption := T('YEDEKPLAN_SIMDI');
  btnDogrula.Caption := T('DOGRULA_DUGME');
  btnKapat.Caption := T('BTN_KAPAT');
  DugmeyiYaziyaUydur(btnKlasorSec);
  DugmeyiYaziyaUydur(btnPlanla);
  DugmeyiYaziyaUydur(btnKaldir);
  DugmeyiYaziyaUydur(btnSimdi);
  DugmeyiYaziyaUydur(btnDogrula);
  DugmeyiYaziyaUydur(btnKapat);
  FSifreVar := KayitliBaglantiBul(FAd, Tanim) and (Tanim.Sifre <> '');
  { Kayitli plan varsa alanlar onunla, yoksa onerilen degerlerle dolar }
  if YedekPlaniOku(FAd, Plan) then
  begin
    edtKlasor.Text := Plan.Klasor;
    Saat := StrToTimeDef(Plan.Saat, EncodeTime(2, 0, 0, 0));
    spnSakla.Value := Plan.Sakla;
  end
  else
  begin
    edtKlasor.Text := VarsayilanYedekKlasoru(FAd);
    Saat := EncodeTime(2, 0, 0, 0);
    spnSakla.Value := YEDEK_SAKLA_VARSAYILAN;
  end;
  dtpSaat.Time := Saat;
  DurumuYenile;
end;

{ Plan ve gorev durumu, dugmelerin acik/kapali hali ve gunluk }
procedure TfrmYedekPlan.DurumuYenile;
var
  Plan: TYedekPlani;
  PlanVar, GorevVar: Boolean;
  Satir: string;
begin
  PlanVar := YedekPlaniOku(FAd, Plan);
  GorevVar := YedekGorevVarMi(FAd);
  if not FSifreVar then
    lblDurum.Caption := T('ERR_YEDEKPLAN_SIFRE')
  else if PlanVar and GorevVar then
    lblDurum.Caption := TF('YEDEKPLAN_DURUM_VAR', [Plan.Saat, Plan.Klasor, Plan.Sakla])
  else if PlanVar then
    lblDurum.Caption := T('YEDEKPLAN_DURUM_GOREV_YOK')
  else if GorevVar then
    lblDurum.Caption := T('YEDEKPLAN_DURUM_PLAN_YOK')
  else
    lblDurum.Caption := T('YEDEKPLAN_DURUM_YOK');
  btnPlanla.Enabled := FSifreVar and not FCalisiyor;
  btnSimdi.Enabled := FSifreVar and PlanVar and not FCalisiyor;
  btnDogrula.Enabled := FSifreVar and PlanVar and not FCalisiyor;
  btnKaldir.Enabled := (PlanVar or GorevVar) and not FCalisiyor;
  memGunluk.Clear;
  for Satir in YedekGunlugu(FAd, 20) do
    memGunluk.Lines.Add(Satir);
end;

procedure TfrmYedekPlan.CalisiyorAyarla(Calisiyor: Boolean);
begin
  FCalisiyor := Calisiyor;
  FIptalIstendi := False;
  pbYedek.Visible := Calisiyor;
  edtKlasor.Enabled := not Calisiyor;
  btnKlasorSec.Enabled := not Calisiyor;
  dtpSaat.Enabled := not Calisiyor;
  spnSakla.Enabled := not Calisiyor;
  btnPlanla.Enabled := not Calisiyor;
  btnKaldir.Enabled := not Calisiyor;
  btnSimdi.Enabled := not Calisiyor;
  btnDogrula.Enabled := not Calisiyor;
  if Calisiyor then
    btnKapat.Caption := T('BTN_IPTAL')
  else
    btnKapat.Caption := T('BTN_KAPAT');
  DugmeyiYaziyaUydur(btnKapat);
end;

{ gbak her satir yazdiginda ve beklerken cagrilir: gecen sureyi gosterir, pencerenin donmamasi icin
  mesajlari isler ve iptal istendiyse bildirir. }
procedure TfrmYedekPlan.CiktiGeldi(const Satir: string; var Iptal: Boolean);
begin
  if GetTickCount - FSonGuncelleme > 80 then
  begin
    FSonGuncelleme := GetTickCount;
    lblDurum.Caption := FIslemYazisi + ' ' +
      TF('YEDEK_SURUYOR', [Format('%.1f', [(GetTickCount - FBaslangic) / 1000])]);
    Application.ProcessMessages;
  end;
  Iptal := FIptalIstendi;
end;

function TfrmYedekPlan.PlanFormdan: TYedekPlani;
begin
  Result.BaglantiAd := FAd;
  Result.Klasor := Trim(edtKlasor.Text);
  Result.Saat := FormatDateTime('hh:nn', dtpSaat.Time);
  Result.Sakla := spnSakla.Value;
end;

procedure TfrmYedekPlan.btnKlasorSecClick(Sender: TObject);
begin
  dlgKlasor.Title := T('YEDEKPLAN_KLASOR_SEC');
  if DirectoryExists(edtKlasor.Text) then
    dlgKlasor.DefaultFolder := edtKlasor.Text;
  if dlgKlasor.Execute then
    edtKlasor.Text := dlgKlasor.FileName;
end;

procedure TfrmYedekPlan.btnPlanlaClick(Sender: TObject);
var
  Plan: TYedekPlani;
  Cumle, Ham: string;
begin
  Plan := PlanFormdan;
  if not YedekGoreviKur(Plan, Cumle, Ham) then
  begin
    UyariGoster(Cumle);
    Exit;
  end;
  YedekPlaniKaydet(Plan);
  FSonuc.Add(TF('MSG_YEDEKPLAN_KURULDU', [FAd, Plan.Saat, Plan.Klasor, Plan.Sakla]));
  DurumuYenile;
end;

procedure TfrmYedekPlan.btnKaldirClick(Sender: TObject);
var
  Plan: TYedekPlani;
  Cumle, Ham: string;
begin
  if not YedekPlaniOku(FAd, Plan) then
    Plan.Klasor := '';
  if not OnayIste(TF('ONAY_YEDEKPLAN_KALDIR', [FAd, Plan.Klasor])) then
    Exit;
  if YedekGorevVarMi(FAd) and not YedekGoreviKaldir(FAd, Cumle, Ham) then
  begin
    UyariGoster(Cumle);
    Exit;
  end;
  YedekPlaniSil(FAd);
  FSonuc.Add(TF('MSG_YEDEKPLAN_KALDIRILDI', [FAd]));
  DurumuYenile;
end;

procedure TfrmYedekPlan.btnSimdiClick(Sender: TObject);
var
  Sonuc: TYedekSonucu;
begin
  FBaslangic := GetTickCount;
  FIslemYazisi := T('YEDEK_ACIKLAMA_YEDEK');
  CalisiyorAyarla(True);
  try
    YedekPlaniCalistir(FAd, CiktiGeldi, Sonuc);
  finally
    CalisiyorAyarla(False);
  end;
  if Sonuc.Basarili then
    FSonuc.Add(TF('MSG_YEDEKPLAN_SIMDI_TAMAM', [FAd, Sonuc.Dosya,
      BoyutMetni(TFile.GetSize(Sonuc.Dosya)), Format('%.1f', [Sonuc.Sure / 1000])]))
  else if Sonuc.Iptal then
    FSonuc.Add(T('YEDEK_IPTAL'))
  else
  begin
    FSonuc.Add(T('ERR_YEDEK_YAPILAMADI') + ' ' + Sonuc.Cumle);
    UyariGoster(T('ERR_YEDEK_YAPILAMADI') + ' ' + Sonuc.Cumle);
  end;
  DurumuYenile;
end;

{ En yeni yedegi yeni bir dosyaya geri yukler ve okur (is uYedekDogrula'dadir); rapor pencerede, ozet ana pencerenin sonuc alaninda. }
procedure TfrmYedekPlan.btnDogrulaClick(Sender: TObject);
var
  Hazirlik: TDogrulamaHazirligi;
  Sonuc: TDogrulamaSonucu;
  Cumle: string;
begin
  if not DogrulamaHazirla(FAd, Hazirlik, Cumle) then
  begin
    UyariGoster(Cumle);
    Exit;
  end;
  if not OnayIste(DogrulamaOnayMetni(Hazirlik)) then
    Exit;
  memDogrula.Clear;
  FBaslangic := GetTickCount;
  FIslemYazisi := T('DOGRULA_ACIKLAMA');
  CalisiyorAyarla(True);
  try
    YedegiDogrula(Hazirlik, CiktiGeldi, Sonuc);
  finally
    CalisiyorAyarla(False);
  end;
  memDogrula.Text := Sonuc.Rapor;
  if Sonuc.Ayrinti <> '' then
    memDogrula.Text := Sonuc.Rapor + sLineBreak + sLineBreak + T('DOGRULA_AYRINTI') + sLineBreak + Sonuc.Ayrinti;
  FSonuc.Add(Sonuc.Ozet + ' ' + TF('DOGRULA_SONUC_DOSYA', [Sonuc.GeriYuklenen]));
  DurumuYenile;
end;

procedure TfrmYedekPlan.btnKapatClick(Sender: TObject);
begin
  if FCalisiyor then
    FIptalIstendi := True
  else
    ModalResult := mrCancel;
end;

procedure TfrmYedekPlan.FormCloseQuery(Sender: TObject; var CanClose: Boolean);
begin
  if FCalisiyor then
  begin
    FIptalIstendi := True;
    CanClose := False;
  end;
end;

end.
