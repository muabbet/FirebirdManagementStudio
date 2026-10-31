{ fYetkiVer.pas - Yetki ver / geri al penceresi (Asama 3d-3).
  Pencere yalniz alanlari toplar ve komut onizlemesini gosterir; komutu uYetki uretir ve calistirir.
  Ver: kime (kullanici, rol, herkes), hangi yetkiler, "baskasina da verebilsin". Geri al: kime ve yetkiler onceden dolu
  gelir (secili satir), kisi degistirilemez, isaretli yetkiler geri alinir. }
unit fYetkiVer;

interface

uses
  System.SysUtils, System.Classes, Vcl.Controls, Vcl.Forms, Vcl.StdCtrls, Vcl.ExtCtrls,
  uDil, uBaglanti, uMetadata, uYetki, uOnay;

type
  TfrmYetkiVer = class(TForm)
    lblHedef: TLabel;
    cmbHedef: TComboBox;
    lblAd: TLabel;
    cmbAd: TComboBox;
    lblYetkiler: TLabel;
    chkS: TCheckBox;
    chkI: TCheckBox;
    chkU: TCheckBox;
    chkD: TCheckBox;
    chkR: TCheckBox;
    chkX: TCheckBox;
    chkSecenek: TCheckBox;
    lblKomut: TLabel;
    memKomut: TMemo;
    pnlAlt: TPanel;
    btnIptal: TButton;
    btnTamam: TButton;
    procedure AlanDegisti(Sender: TObject);
    procedure HedefDegisti(Sender: TObject);
    procedure FormCloseQuery(Sender: TObject; var CanClose: Boolean);
  private
    FBag: TAcikBaglanti;
    FIslem: TYetkiIslemi;
    FIlk: TYetkiGirdisi;
    function GirdiOku: TYetkiGirdisi;
    procedure AdlariDoldur;
    procedure GorunurlukAyarla;
  end;

{ Pencereyi acar. Ilk: nesne (ve geri almada kisi ile yetkiler) dolu girdi. Tamam'da G'ye secimleri koyar. }
function YetkiVerPenceresiGoster(Bag: TAcikBaglanti; Islem: TYetkiIslemi; const Ilk: TYetkiGirdisi;
  out G: TYetkiGirdisi): Boolean;

implementation

{$R *.dfm}

function TfrmYetkiVer.GirdiOku: TYetkiGirdisi;
begin
  Result := FIlk;
  Result.Hedef := TYetkiHedefi(cmbHedef.ItemIndex);
  Result.Ad := Trim(cmbAd.Text);
  Result.Harfler := '';
  if chkS.Checked and chkS.Visible then
    Result.Harfler := Result.Harfler + 'S';
  if chkI.Checked and chkI.Visible then
    Result.Harfler := Result.Harfler + 'I';
  if chkU.Checked and chkU.Visible then
    Result.Harfler := Result.Harfler + 'U';
  if chkD.Checked and chkD.Visible then
    Result.Harfler := Result.Harfler + 'D';
  if chkR.Checked and chkR.Visible then
    Result.Harfler := Result.Harfler + 'R';
  if chkX.Checked and chkX.Visible then
    Result.Harfler := Result.Harfler + 'X';
  Result.Verebilir := chkSecenek.Checked and chkSecenek.Visible;
end;

{ "Kullanici" secilince sunucunun kullanicilari, "Rol" secilince veritabaninin rolleri listelenir. Liste alinamazsa
  (yetki yok, gomulu baglanti) kutu bos kalir; ad elle yazilabilir. }
procedure TfrmYetkiVer.AdlariDoldur;
var
  Ad: string;
  Kullanicilar: TArray<TKullaniciBilgisi>;
  Kullanici: TKullaniciBilgisi;
begin
  cmbAd.Items.Clear;
  case TYetkiHedefi(cmbHedef.ItemIndex) of
    yhKullanici:
      try
        Kullanicilar := KullaniciListesiOku(FBag);
        for Kullanici in Kullanicilar do
          cmbAd.Items.Add(Kullanici.Ad);
      except
      end;
    yhRol:
      try
        for Ad in RolAdlari(FBag) do
          cmbAd.Items.Add(Ad);
      except
      end;
  end;
end;

procedure TfrmYetkiVer.GorunurlukAyarla;
var
  Prosedur, Herkes: Boolean;
begin
  Prosedur := FIlk.NesneTuru = ynProsedur;
  Herkes := TYetkiHedefi(cmbHedef.ItemIndex) = yhHerkes;
  lblAd.Visible := not Herkes;
  cmbAd.Visible := not Herkes;
  chkS.Visible := not Prosedur;
  chkI.Visible := not Prosedur;
  chkU.Visible := not Prosedur;
  chkD.Visible := not Prosedur;
  chkR.Visible := not Prosedur;
  chkX.Visible := Prosedur;
  chkSecenek.Visible := FIslem = yiVer;
end;

procedure TfrmYetkiVer.HedefDegisti(Sender: TObject);
begin
  AdlariDoldur;
  cmbAd.Text := '';
  AlanDegisti(Sender);
end;

procedure TfrmYetkiVer.AlanDegisti(Sender: TObject);
begin
  GorunurlukAyarla;
  memKomut.Text := YetkiKomutu(FBag, FIslem, GirdiOku);
end;

procedure TfrmYetkiVer.FormCloseQuery(Sender: TObject; var CanClose: Boolean);
var
  Uyari: string;
begin
  if ModalResult <> mrOk then
    Exit;
  Uyari := YetkiDogrula(GirdiOku);
  if Uyari <> '' then
  begin
    UyariGoster(Uyari);
    CanClose := False;
  end;
end;

function YetkiVerPenceresiGoster(Bag: TAcikBaglanti; Islem: TYetkiIslemi; const Ilk: TYetkiGirdisi;
  out G: TYetkiGirdisi): Boolean;
var
  Pencere: TfrmYetkiVer;
  Harfler: string;
begin
  Pencere := TfrmYetkiVer.Create(Application);
  try
    Pencere.FBag := Bag;
    Pencere.FIslem := Islem;
    Pencere.FIlk := Ilk;
    if Islem = yiVer then
      Pencere.Caption := TF('YETKI_VER_BASLIK', [Ilk.Nesne])
    else
      Pencere.Caption := TF('YETKI_AL_BASLIK', [Ilk.Nesne]);
    Pencere.lblHedef.Caption := T('YETKI_ETIKET_TUR');
    Pencere.lblAd.Caption := T('YETKI_ETIKET_AD');
    Pencere.lblYetkiler.Caption := T('YETKI_ETIKET_YETKILER');
    Pencere.lblKomut.Caption := T('KOLON_ETIKET_KOMUT');
    Pencere.chkS.Caption := 'SELECT';
    Pencere.chkI.Caption := 'INSERT';
    Pencere.chkU.Caption := 'UPDATE';
    Pencere.chkD.Caption := 'DELETE';
    Pencere.chkR.Caption := 'REFERENCES';
    Pencere.chkX.Caption := 'EXECUTE';
    Pencere.chkSecenek.Caption := T('YETKI_ETIKET_SECENEK');
    Pencere.btnTamam.Caption := T('BTN_TAMAM');
    Pencere.btnIptal.Caption := T('BTN_IPTAL');
    DugmeyiYaziyaUydur(Pencere.btnTamam);
    DugmeyiYaziyaUydur(Pencere.btnIptal);
    Pencere.cmbHedef.Items.Add(T('YETKI_TUR_KULLANICI'));
    Pencere.cmbHedef.Items.Add(T('YETKI_TUR_ROL'));
    Pencere.cmbHedef.Items.Add(T('YETKI_TUR_HERKES'));
    Pencere.cmbHedef.ItemIndex := Ord(Ilk.Hedef);
    Pencere.AdlariDoldur;
    Pencere.cmbAd.Text := Ilk.Ad;
    { Geri almada kisi sabit (secili satir), onceden verilmis yetkiler isaretli gelir; vermede varsayilan SELECT. }
    Harfler := Ilk.Harfler;
    if (Islem = yiVer) and (Harfler = '') then
      if Ilk.NesneTuru = ynProsedur then
        Harfler := 'X'
      else
        Harfler := 'S';
    Pencere.chkS.Checked := Pos('S', Harfler) > 0;
    Pencere.chkI.Checked := Pos('I', Harfler) > 0;
    Pencere.chkU.Checked := Pos('U', Harfler) > 0;
    Pencere.chkD.Checked := Pos('D', Harfler) > 0;
    Pencere.chkR.Checked := Pos('R', Harfler) > 0;
    Pencere.chkX.Checked := Pos('X', Harfler) > 0;
    if Islem = yiAl then
    begin
      Pencere.cmbHedef.Enabled := False;
      Pencere.cmbAd.Enabled := False;
    end;
    Pencere.AlanDegisti(nil);
    Result := Pencere.ShowModal = mrOk;
    if Result then
      G := Pencere.GirdiOku;
  finally
    Pencere.Free;
  end;
end;

end.
