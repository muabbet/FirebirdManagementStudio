{ fTabloKopya.pas - "Baska veritabanina kopyala" penceresi (Asama 7f).
  Form sadece arayuzu bilir; is uTabloKopya'dadir. Akis: hedef veritabani (acik baglantilar) ve hedef tablo adi -> hedefte tablo
  var mi yok mu yazilir -> Kopyala (net onay: ne olusacak, kac satir, hangi komutlar) -> tek islemde kopyalama.
  Uzun surerken ilerleme yazilir, Iptal ile durdurulur (iptalde hicbir satir eklenmez). }
unit fTabloKopya;

interface

uses
  Winapi.Windows, System.SysUtils, System.Classes, System.StrUtils, Vcl.Controls, Vcl.Forms, Vcl.StdCtrls, Vcl.ExtCtrls,
  uDil, uOnay, uBaglanti, uKullanici, uMetadata, uNesneYonet, uTabloKopya;

type
  TfrmTabloKopya = class(TForm)
    lblKaynak: TLabel;
    lblHedefDb: TLabel;
    cmbHedef: TComboBox;
    lblHedefAd: TLabel;
    edtHedefAd: TEdit;
    chkVeri: TCheckBox;
    lblDurum: TLabel;
    pnlAlt: TPanel;
    btnKapat: TButton;
    btnBaslat: TButton;
    procedure HedefDegisti(Sender: TObject);
    procedure btnBaslatClick(Sender: TObject);
    procedure btnKapatClick(Sender: TObject);
    procedure FormCloseQuery(Sender: TObject; var CanClose: Boolean);
  private
    FKaynak: TAcikBaglanti;
    FTablo: string;
    FSqlYaz: TSqlGoster;
    FSonuc: TStrings;
    FSatirSayisi: Int64;
    { Acik baglanti adlari, kutudaki sirayla. }
    FAdlar: TArray<string>;
    { Hedefte degisiklik oldu (tablo olustu ya da satir eklendi): cagiran hedefin agacini yeniler. }
    FDegisti: Boolean;
    FHedefBaglantiAd: string;
    FCalisiyor: Boolean;
    FIptalIstendi: Boolean;
    FSonGuncelleme: Cardinal;
    procedure YazilariYaz;
    procedure CalisiyorAyarla(Calisiyor: Boolean);
    procedure Ilerle(SatirSayisi: Int64; var Iptal: Boolean);
    function HedefBaglanti: TAcikBaglanti;
    function HedefAdi: string;
  end;

{ Pencereyi gosterir. Sonuc: ana pencerenin sonuc alani (ozet buraya yazilir); SqlYaz: hedefte calisan CREATE komutlari.
  Hedefte bir degisiklik olduysa True doner ve HedefBaglantiAd o baglantinin adidir (cagiran agacini yeniler). }
function TabloKopyaPenceresiniGoster(Kaynak: TAcikBaglanti; const Tablo: string; SqlYaz: TSqlGoster; Sonuc: TStrings;
  out HedefBaglantiAd: string): Boolean;

implementation

{$R *.dfm}

function TabloKopyaPenceresiniGoster(Kaynak: TAcikBaglanti; const Tablo: string; SqlYaz: TSqlGoster; Sonuc: TStrings;
  out HedefBaglantiAd: string): Boolean;
var
  Pencere: TfrmTabloKopya;
begin
  Result := False;
  HedefBaglantiAd := '';
  Pencere := TfrmTabloKopya.Create(Application);
  try
    Pencere.FKaynak := Kaynak;
    Pencere.FTablo := Tablo;
    Pencere.FSqlYaz := SqlYaz;
    Pencere.FSonuc := Sonuc;
    try
      Pencere.FSatirSayisi := TabloSatirSayisi(Kaynak, Tablo);
    except
      on E: Exception do
      begin
        UyariGoster(HataMetniniCevir(E) + sLineBreak + sLineBreak + T('AYRINTI') + ': ' + E.Message);
        Exit;
      end;
    end;
    Pencere.YazilariYaz;
    Pencere.ShowModal;
    Result := Pencere.FDegisti;
    HedefBaglantiAd := Pencere.FHedefBaglantiAd;
  finally
    Pencere.Free;
  end;
end;

procedure TfrmTabloKopya.YazilariYaz;
var
  Ad: string;
begin
  Caption := T('KOPYA_BASLIK') + ' - ' + FTablo;
  lblKaynak.Caption := TF('KOPYA_KAYNAK', [FTablo, FSatirSayisi, FKaynak.Tanim.Ad]);
  lblHedefDb.Caption := T('KOPYA_HEDEF_DB');
  lblHedefAd.Caption := T('KOPYA_HEDEF_AD');
  chkVeri.Caption := T('KOPYA_VERI');
  btnBaslat.Caption := T('KOPYA_BASLAT');
  btnKapat.Caption := T('BTN_KAPAT');
  FAdlar := FbAcikBaglantiAdlari;
  cmbHedef.Items.Clear;
  for Ad in FAdlar do
    cmbHedef.Items.Add(Ad);
  { Varsayilan hedef: kaynaktan farkli ilk acik baglanti (yoksa kaynagin kendisi: ayni veritabaninda baska ada kopya). }
  cmbHedef.ItemIndex := 0;
  for Ad in FAdlar do
    if not SameText(Ad, FKaynak.Tanim.Ad) then
    begin
      cmbHedef.ItemIndex := cmbHedef.Items.IndexOf(Ad);
      Break;
    end;
  edtHedefAd.Text := FTablo;
  DugmeyiYaziyaUydur(btnBaslat);
  DugmeyiYaziyaUydur(btnKapat);
  HedefDegisti(nil);
end;

function TfrmTabloKopya.HedefBaglanti: TAcikBaglanti;
begin
  Result := nil;
  if cmbHedef.ItemIndex >= 0 then
    Result := FbAcikBaglanti(FAdlar[cmbHedef.ItemIndex]);
end;

{ Hedef tablo adi: basit adlar buyuk harfe cevrilir (AdHazirla), bosluklu/ozel adlar yazildigi gibi kalir. }
function TfrmTabloKopya.HedefAdi: string;
begin
  Result := AdHazirla(edtHedefAd.Text);
end;

{ Hedef baglanti ya da ad degisti: hedefte bu adda tablo var mi, durum satirina yazilir. }
procedure TfrmTabloKopya.HedefDegisti(Sender: TObject);
var
  Hedef: TAcikBaglanti;
begin
  Hedef := HedefBaglanti;
  btnBaslat.Enabled := False;
  lblDurum.Caption := '';
  if (Hedef = nil) or (HedefAdi = '') then
    Exit;
  if (Hedef = FKaynak) and SameText(HedefAdi, FTablo) then
  begin
    lblDurum.Caption := T('KOPYA_AYNI');
    Exit;
  end;
  try
    if HedefteTabloVarMi(Hedef, HedefAdi) then
      lblDurum.Caption := T('KOPYA_DURUM_VAR')
    else
      lblDurum.Caption := T('KOPYA_DURUM_YOK');
    btnBaslat.Enabled := True;
  except
    on E: Exception do
      lblDurum.Caption := HataMetniniCevir(E);
  end;
end;

procedure TfrmTabloKopya.CalisiyorAyarla(Calisiyor: Boolean);
begin
  FCalisiyor := Calisiyor;
  FIptalIstendi := False;
  cmbHedef.Enabled := not Calisiyor;
  edtHedefAd.Enabled := not Calisiyor;
  chkVeri.Enabled := not Calisiyor;
  btnBaslat.Enabled := not Calisiyor;
  if Calisiyor then
    btnKapat.Caption := T('BTN_IPTAL')
  else
    btnKapat.Caption := T('BTN_KAPAT');
  DugmeyiYaziyaUydur(btnKapat);
end;

{ Kopyalama sirasinda cagrilir: durum yazisini gunceller, pencerenin donmamasi icin mesajlari isler, iptali bildirir. }
procedure TfrmTabloKopya.Ilerle(SatirSayisi: Int64; var Iptal: Boolean);
begin
  if GetTickCount - FSonGuncelleme > 80 then
  begin
    FSonGuncelleme := GetTickCount;
    lblDurum.Caption := TF('KOPYA_ILERLEME', [SatirSayisi]);
    Application.ProcessMessages;
  end;
  Iptal := FIptalIstendi;
end;

procedure TfrmTabloKopya.btnKapatClick(Sender: TObject);
begin
  if FCalisiyor then
    FIptalIstendi := True
  else
    ModalResult := mrCancel;
end;

procedure TfrmTabloKopya.FormCloseQuery(Sender: TObject; var CanClose: Boolean);
begin
  if FCalisiyor then
  begin
    FIptalIstendi := True;
    CanClose := False;
  end;
end;

{ Kopyala: eksik domain varsa hic baslamaz; net onay (ne olusacak, kac satir, hedefte calisacak komutlar, kopyalanmayanlar);
  sonra tek islemde kopyalar. Hata ya da iptalde hicbir satir eklenmez; tablo yeni olustuysa bos kalir ve bu soylenir. }
procedure TfrmTabloKopya.btnBaslatClick(Sender: TObject);
var
  Hedef: TAcikBaglanti;
  HedefAd, Onay, Eksik: string;
  HedefteVar, VeriDe: Boolean;
  Sonuc: TKopyaSonucu;
begin
  Hedef := HedefBaglanti;
  HedefAd := HedefAdi;
  if HedefAd = '' then
  begin
    UyariGoster(T('KOPYA_AD_BOS'));
    Exit;
  end;
  if Hedef = nil then
    Exit;
  VeriDe := chkVeri.Checked;
  try
    HedefteVar := HedefteTabloVarMi(Hedef, HedefAd);
    if not HedefteVar then
    begin
      Eksik := EksikDomainler(FKaynak, FTablo, Hedef);
      if Eksik <> '' then
      begin
        UyariGoster(TF('ERR_KOPYA_DOMAIN', [Eksik]));
        Exit;
      end;
    end;
    if HedefteVar then
      Onay := TF('KOPYA_ONAY_VAR', [FTablo, Hedef.Tanim.Ad, HedefAd])
    else
      Onay := TF('KOPYA_ONAY_YENI', [FTablo, Hedef.Tanim.Ad, HedefAd]);
    if VeriDe then
      Onay := Onay + sLineBreak + sLineBreak + TF('KOPYA_ONAY_VERI', [FSatirSayisi]);
    if not HedefteVar then
      Onay := Onay + sLineBreak + sLineBreak + T('KOPYA_ONAY_YAPI') + sLineBreak + KopyaYapiScripti(FKaynak, FTablo, HedefAd);
  except
    on E: Exception do
    begin
      UyariGoster(HataMetniniCevir(E) + sLineBreak + sLineBreak + T('AYRINTI') + ': ' + E.Message);
      Exit;
    end;
  end;
  Onay := Onay + sLineBreak + T('KOPYA_ONAY_NOT') + sLineBreak + sLineBreak + T('KOPYA_ONAY_SORU');
  if not OnayIste(Onay) then
    Exit;
  CalisiyorAyarla(True);
  try
    Sonuc := TabloKopyala(FKaynak, FTablo, Hedef, HedefAd, VeriDe, Ilerle);
  finally
    CalisiyorAyarla(False);
  end;
  lblDurum.Caption := '';
  FHedefBaglantiAd := Hedef.Tanim.Ad;
  if Sonuc.TabloOlustu or (Sonuc.Kopyalanan > 0) then
    FDegisti := True;
  if (Length(Sonuc.Komutlar) > 0) and Assigned(FSqlYaz) then
    FSqlYaz(Sonuc.Komutlar);
  if Sonuc.Basarili then
  begin
    if VeriDe then
      FSonuc.Add(TF('MSG_KOPYA_TAMAM', [FTablo, Hedef.Tanim.Ad, HedefAd, Sonuc.Kopyalanan]))
    else
      FSonuc.Add(TF('MSG_KOPYA_YAPI_TAMAM', [FTablo, Hedef.Tanim.Ad, HedefAd]));
    ModalResult := mrOk;
    Exit;
  end;
  if Sonuc.Iptal then
    FSonuc.Add(T('MSG_KOPYA_IPTAL'))
  else
  begin
    FSonuc.Add(TF('ERR_KOPYA_YAPILAMADI', [FTablo]) + ' ' + Sonuc.Cumle);
    if Sonuc.Ayrinti <> '' then
      FSonuc.Add(T('AYRINTI') + ': ' + Sonuc.Ayrinti);
  end;
  if Sonuc.TabloOlustu then
    FSonuc.Add(T('MSG_KOPYA_TABLO_BOS_KALDI'));
  if not Sonuc.Iptal then
    UyariGoster(TF('ERR_KOPYA_YAPILAMADI', [FTablo]) + sLineBreak + sLineBreak + Sonuc.Cumle +
      IfThen(Sonuc.TabloOlustu, sLineBreak + sLineBreak + T('MSG_KOPYA_TABLO_BOS_KALDI'), ''));
  HedefDegisti(nil);
end;

end.
