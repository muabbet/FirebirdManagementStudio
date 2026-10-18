{ fYedek.pas - "Yedekle / Geri yukle" penceresi (Asama 3c).
  Form sadece arayuzu bilir; is uYedek.YedekAl ve uYedek.GeriYukle'dedir. Tek pencere, iki mod (Yedek al /
  Geri yukle), ek secenek yok. gbak ciktisi canli gosterilir, Iptal ile durdurulur; iptalde ve hatada yarim
  dosya silinmez. }
unit fYedek;

interface

uses
  Winapi.Windows, System.SysUtils, System.Classes, System.IOUtils, Vcl.Controls, Vcl.Forms,
  Vcl.StdCtrls, Vcl.ExtCtrls, Vcl.Dialogs,
  uDil, uOnay, uBaglanti, uYedek;

type
  TfrmYedek = class(TForm)
    lblKaynak: TLabel;
    lblHedef: TLabel;
    lblDurum: TLabel;
    rgIslem: TRadioGroup;
    edtKaynak: TEdit;
    btnKaynakSec: TButton;
    edtHedef: TEdit;
    btnHedefSec: TButton;
    memCikti: TMemo;
    pnlAlt: TPanel;
    btnKapat: TButton;
    btnBaslat: TButton;
    dlgAc: TOpenDialog;
    dlgKaydet: TSaveDialog;
    dlgGbak: TOpenDialog;
    procedure rgIslemClick(Sender: TObject);
    procedure btnKaynakSecClick(Sender: TObject);
    procedure btnHedefSecClick(Sender: TObject);
    procedure btnBaslatClick(Sender: TObject);
    procedure btnKapatClick(Sender: TObject);
    procedure FormCloseQuery(Sender: TObject; var CanClose: Boolean);
  private
    FTanim: TBaglantiTanimi;
    FSonuc: TStrings;
    FCalisiyor: Boolean;
    FIptalIstendi: Boolean;
    FSonGuncelleme: Cardinal;
    FBaslangic: Cardinal;
    procedure YazilariYaz;
    procedure ModuAyarla;
    procedure CalisiyorAyarla(Calisiyor: Boolean);
    procedure CiktiGeldi(const Satir: string; var Iptal: Boolean);
    function GbakHazirMi: Boolean;
    procedure YedekBaslat;
    procedure GeriYuklemeBaslat;
    procedure SonucuYaz(const Sonuc: TYedekSonucu; const Ozet: string);
  end;

{ Pencereyi gosterir. Tanim: kayitli ya da acik baglanti (sifresi doluysa sorulmaz). Her islem bitince ozet ve
  uyarilar Sonuc'a (ana pencerenin sonuc alani) eklenir. }
procedure YedekPenceresiniGoster(const Tanim: TBaglantiTanimi; Sonuc: TStrings);

implementation

{$R *.dfm}

procedure YedekPenceresiniGoster(const Tanim: TBaglantiTanimi; Sonuc: TStrings);
var
  Pencere: TfrmYedek;
begin
  Pencere := TfrmYedek.Create(Application);
  try
    Pencere.FTanim := Tanim;
    Pencere.FSonuc := Sonuc;
    Pencere.YazilariYaz;
    Pencere.ShowModal;
  finally
    Pencere.Free;
  end;
end;

procedure TfrmYedek.YazilariYaz;
begin
  Caption := T('YEDEK_BASLIK') + ' - ' + FTanim.Ad;
  rgIslem.Items.Clear;
  rgIslem.Items.Add(T('YEDEK_ISLEM_YEDEK'));
  rgIslem.Items.Add(T('YEDEK_ISLEM_GERI'));
  btnKaynakSec.Caption := T('YEDEK_SEC');
  btnHedefSec.Caption := T('YEDEK_SEC');
  btnBaslat.Caption := T('YEDEK_BASLAT');
  btnKapat.Caption := T('BTN_KAPAT');
  DugmeyiYaziyaUydur(btnKaynakSec);
  DugmeyiYaziyaUydur(btnHedefSec);
  DugmeyiYaziyaUydur(btnBaslat);
  DugmeyiYaziyaUydur(btnKapat);
  rgIslem.ItemIndex := 0;
  ModuAyarla;
end;

{ Mod degisince etiketler ve alanlar degisir (ikinci pencere yok); alanlar o moda gore yeniden doldurulur. }
procedure TfrmYedek.ModuAyarla;
var
  Yedek: Boolean;
begin
  Yedek := rgIslem.ItemIndex = 0;
  memCikti.Clear;
  lblDurum.Caption := '';
  edtKaynak.ReadOnly := Yedek;
  btnKaynakSec.Visible := not Yedek;
  btnHedefSec.Visible := Yedek or YerelSunucuMu(FTanim.Sunucu);
  if Yedek then
  begin
    lblKaynak.Caption := T('YEDEK_KAYNAK_VT');
    edtKaynak.Text := GbakBaglantiMetni(FTanim, FTanim.VeritabaniYolu);
    lblHedef.Caption := T('YEDEK_HEDEF_FBK');
    edtHedef.Text := TPath.Combine(TPath.GetDocumentsPath, VarsayilanYedekAdi(FTanim.VeritabaniYolu));
  end
  else
  begin
    lblKaynak.Caption := T('YEDEK_KAYNAK_FBK');
    edtKaynak.Text := '';
    lblHedef.Caption := T('YEDEK_HEDEF_VT');
    edtHedef.Text := '';
  end;
end;

procedure TfrmYedek.CalisiyorAyarla(Calisiyor: Boolean);
begin
  FCalisiyor := Calisiyor;
  FIptalIstendi := False;
  rgIslem.Enabled := not Calisiyor;
  edtKaynak.Enabled := not Calisiyor;
  edtHedef.Enabled := not Calisiyor;
  btnKaynakSec.Enabled := not Calisiyor;
  btnHedefSec.Enabled := not Calisiyor;
  btnBaslat.Enabled := not Calisiyor;
  if Calisiyor then
    btnKapat.Caption := T('BTN_IPTAL')
  else
    btnKapat.Caption := T('BTN_KAPAT');
  DugmeyiYaziyaUydur(btnKapat);
end;

{ gbak her satir yazdiginda ve beklerken cagrilir: satiri gosterir, pencerenin donmamasi icin mesajlari isler
  ve iptal istendiyse bildirir. }
procedure TfrmYedek.CiktiGeldi(const Satir: string; var Iptal: Boolean);
begin
  if Satir <> '' then
    memCikti.Lines.Add(Satir);
  if GetTickCount - FSonGuncelleme > 80 then
  begin
    FSonGuncelleme := GetTickCount;
    lblDurum.Caption := TF('YEDEK_SURUYOR', [Format('%.1f', [(GetTickCount - FBaslangic) / 1000])]);
    Application.ProcessMessages;
  end;
  Iptal := FIptalIstendi;
end;

function TfrmYedek.GbakHazirMi: Boolean;
begin
  if not GbakVarMi then
  begin
    dlgGbak.Title := T('YEDEK_GBAK_SEC');
    dlgGbak.Filter := T('YEDEK_GBAK_FILTRE');
    if dlgGbak.Execute then
      GbakYoluAyarla(dlgGbak.FileName);
  end;
  Result := GbakVarMi;
  if not Result then
    UyariGoster(T('ERR_YEDEK_GBAK_YOK'));
end;

procedure TfrmYedek.rgIslemClick(Sender: TObject);
begin
  ModuAyarla;
end;

procedure TfrmYedek.btnKaynakSecClick(Sender: TObject);
begin
  dlgAc.Filter := T('YEDEK_FBK_FILTRE');
  dlgAc.FileName := edtKaynak.Text;
  if dlgAc.Execute then
    edtKaynak.Text := dlgAc.FileName;
end;

procedure TfrmYedek.btnHedefSecClick(Sender: TObject);
begin
  if rgIslem.ItemIndex = 0 then
  begin
    dlgKaydet.DefaultExt := 'fbk';
    dlgKaydet.Filter := T('YEDEK_FBK_FILTRE');
  end
  else
  begin
    dlgKaydet.DefaultExt := 'fdb';
    dlgKaydet.Filter := T('YEDEK_FDB_FILTRE');
  end;
  dlgKaydet.FileName := edtHedef.Text;
  if dlgKaydet.Execute then
    edtHedef.Text := dlgKaydet.FileName;
end;

procedure TfrmYedek.btnKapatClick(Sender: TObject);
begin
  if FCalisiyor then
    FIptalIstendi := True
  else
    ModalResult := mrCancel;
end;

procedure TfrmYedek.FormCloseQuery(Sender: TObject; var CanClose: Boolean);
begin
  if FCalisiyor then
  begin
    FIptalIstendi := True;
    CanClose := False;
  end;
end;

{ Sonuc alanina (ana pencere) ve bu pencereye: ozet, uyarilar, yarim dosya, hata cumlesi. gbak'in ham ciktisi
  zaten kutuda durur; Ayrinti (sifresiz komut, gbak surumu, cikis kodu) onun altina eklenir. }
procedure TfrmYedek.SonucuYaz(const Sonuc: TYedekSonucu; const Ozet: string);
var
  Satirlar: TStringList;
  Satir: string;
begin
  Satirlar := TStringList.Create;
  try
    if Sonuc.Basarili then
      Satirlar.Add(Ozet)
    else if Sonuc.Iptal then
      Satirlar.Add(T('YEDEK_IPTAL'))
    else
      Satirlar.Add(T('ERR_YEDEK_YAPILAMADI') + ' ' + Sonuc.Cumle);
    if Sonuc.Uyarilar <> '' then
      for Satir in Sonuc.Uyarilar.Split([sLineBreak]) do
        Satirlar.Add('  ' + TF('YEDEK_UYARI', [Satir]));
    if Sonuc.YarimDosya <> '' then
      Satirlar.Add('  ' + TF('YEDEK_YARIM', [Sonuc.YarimDosya]));
    lblDurum.Caption := Satirlar.Text;
    FSonuc.AddStrings(Satirlar);
    memCikti.Lines.Add('');
    memCikti.Lines.Add('--- ' + T('AYRINTI') + ' ---');
    memCikti.Lines.Add(Sonuc.Ayrinti);
    if not (Sonuc.Basarili or Sonuc.Iptal) then
      UyariGoster(Satirlar.Text);
  finally
    Satirlar.Free;
  end;
end;

procedure TfrmYedek.YedekBaslat;
var
  Hedef, Ozet: string;
  Sonuc: TYedekSonucu;
begin
  Hedef := Trim(edtHedef.Text);
  if Hedef = '' then
  begin
    UyariGoster(T('ERR_YEDEK_HEDEF_BOS'));
    Exit;
  end;
  if TFile.Exists(Hedef) and not OnayIste(TF('ONAY_YEDEK_UZERINE_YAZ',
    [Hedef, BoyutMetni(TFile.GetSize(Hedef)), DateTimeToStr(TFile.GetLastWriteTime(Hedef))])) then
    Exit;
  memCikti.Clear;
  FBaslangic := GetTickCount;
  CalisiyorAyarla(True);
  try
    try
      YedekAl(FTanim, Hedef, CiktiGeldi, Sonuc);
    except
      on E: Exception do
      begin
        lblDurum.Caption := '';
        UyariGoster(T('ERR_YEDEK_YAPILAMADI') + ' ' + E.Message);
        Exit;
      end;
    end;
  finally
    CalisiyorAyarla(False);
  end;
  Ozet := '';
  if Sonuc.Basarili then
    Ozet := TF('YEDEK_BITTI_YEDEK', [GbakBaglantiMetni(FTanim, FTanim.VeritabaniYolu), Sonuc.Dosya,
      BoyutMetni(TFile.GetSize(Sonuc.Dosya)), Format('%.1f', [Sonuc.Sure / 1000])]);
  SonucuYaz(Sonuc, Ozet);
end;

procedure TfrmYedek.GeriYuklemeBaslat;
var
  Kaynak, Hedef: string;
  Sonuc: TYedekSonucu;
begin
  Kaynak := Trim(edtKaynak.Text);
  Hedef := Trim(edtHedef.Text);
  if Kaynak = '' then
  begin
    UyariGoster(T('ERR_YEDEK_KAYNAK_BOS'));
    Exit;
  end;
  if Hedef = '' then
  begin
    UyariGoster(T('ERR_YEDEK_HEDEF_BOS'));
    Exit;
  end;
  memCikti.Clear;
  FBaslangic := GetTickCount;
  CalisiyorAyarla(True);
  try
    try
      GeriYukle(FTanim, Kaynak, Hedef, CiktiGeldi, Sonuc);
    except
      on E: Exception do
      begin
        lblDurum.Caption := '';
        UyariGoster(T('ERR_YEDEK_YAPILAMADI') + ' ' + E.Message);
        Exit;
      end;
    end;
  finally
    CalisiyorAyarla(False);
  end;
  SonucuYaz(Sonuc, TF('YEDEK_BITTI_GERI', [Kaynak, GbakBaglantiMetni(FTanim, Hedef),
    Format('%.1f', [Sonuc.Sure / 1000])]));
end;

procedure TfrmYedek.btnBaslatClick(Sender: TObject);
begin
  if not GbakHazirMi then
    Exit;
  if rgIslem.ItemIndex = 0 then
    YedekBaslat
  else
    GeriYuklemeBaslat;
end;

end.
