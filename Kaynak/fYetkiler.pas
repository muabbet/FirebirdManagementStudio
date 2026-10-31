{ fYetkiler.pas - Yetkiler penceresi (Asama 3d-2 ve 3d-3). Iki kipi vardir:
    Nesne: bir tablo / view / prosedurde kimin ne yetkisi var; "Yetki ver" ve "Yetkiyi geri al" dugmeleri.
    Kullanici: bir kullanicinin hangi nesnelerde ne yetkisi var; "Hepsini geri al" dugmesi.
  Form yalniz listeyi gosterir ve dugmeleri baglar; okuma, komut uretme ve calistirma uYetki'dedir. }
unit fYetkiler;

interface

uses
  System.SysUtils, System.Classes, Vcl.Controls, Vcl.Forms, Vcl.StdCtrls, Vcl.ExtCtrls, Vcl.ComCtrls,
  uDil, uBaglanti, uMetadata, uKullanici, uProsedur, uYetki, uOnay, fYetkiVer;

type
  TYetkiKipi = (ykNesne, ykKullanici);

  TfrmYetkiler = class(TForm)
    lblBilgi: TLabel;
    lvYetki: TListView;
    pnlAlt: TPanel;
    btnKapat: TButton;
    btnHepsi: TButton;
    btnAl: TButton;
    btnVer: TButton;
    procedure FormShow(Sender: TObject);
    procedure btnVerClick(Sender: TObject);
    procedure btnAlClick(Sender: TObject);
    procedure btnHepsiClick(Sender: TObject);
  private
    FBag: TAcikBaglanti;
    FKip: TYetkiKipi;
    FAd: string;
    FTur: TYetkiNesnesi;
    FMesaj: TStrings;
    FSqlYaz: TSqlGoster;
    FNesneSatirlari: TArray<TNesneYetkisi>;
    FKullaniciSatirlari: TArray<TKullaniciYetkisi>;
    procedure Doldur;
    procedure Yaz(const Metin: string);
    procedure Uygula(Islem: TYetkiIslemi; const G: TYetkiGirdisi);
    procedure SonucuBildir(Islem: TYetkiIslemi; const Nesne: string; const Sonuc: TProsedurSonucu);
    function IlkGirdi: TYetkiGirdisi;
  end;

{ Nesne kipi: Ad = tablo/view/prosedur adi, Tur buna gore. Kullanici kipi: Ad = kullanici adi (Tur kullanilmaz).
  Mesaj: islem ozetleri buraya (ana pencerenin sonuc alani); SqlYaz: calisan SQL'i mesaj alaninda gosterir (bos olabilir). }
procedure YetkiPenceresiniGoster(Bag: TAcikBaglanti; Kip: TYetkiKipi; const Ad: string; Tur: TYetkiNesnesi;
  Mesaj: TStrings; SqlYaz: TSqlGoster);

implementation

{$R *.dfm}

function EvetHayirMetni(Deger: Boolean): string;
begin
  if Deger then
    Result := T('EVET')
  else
    Result := T('HAYIR');
end;

procedure YetkiPenceresiniGoster(Bag: TAcikBaglanti; Kip: TYetkiKipi; const Ad: string; Tur: TYetkiNesnesi;
  Mesaj: TStrings; SqlYaz: TSqlGoster);
var
  Pencere: TfrmYetkiler;
begin
  Pencere := TfrmYetkiler.Create(Application);
  try
    Pencere.FBag := Bag;
    Pencere.FKip := Kip;
    Pencere.FAd := Ad;
    Pencere.FTur := Tur;
    Pencere.FMesaj := Mesaj;
    Pencere.FSqlYaz := SqlYaz;
    Pencere.btnVer.Caption := T('BTN_YETKI_VER');
    Pencere.btnAl.Caption := T('BTN_YETKI_AL');
    Pencere.btnHepsi.Caption := T('BTN_YETKI_HEPSI');
    Pencere.btnKapat.Caption := T('BTN_KAPAT');
    DugmeyiYaziyaUydur(Pencere.btnVer);
    DugmeyiYaziyaUydur(Pencere.btnAl);
    DugmeyiYaziyaUydur(Pencere.btnHepsi);
    DugmeyiYaziyaUydur(Pencere.btnKapat);
    { Dugmeler kipe gore: nesnede Ver / Al, kullanicida yalniz Hepsini geri al. }
    Pencere.btnVer.Visible := Kip = ykNesne;
    Pencere.btnAl.Visible := Kip = ykNesne;
    Pencere.btnHepsi.Visible := Kip = ykKullanici;
    if Kip = ykNesne then
    begin
      Pencere.Caption := TF('YETKI_BASLIK_NESNE', [Ad]);
      Pencere.lblBilgi.Caption := T('YETKI_BILGI_NESNE');
      Pencere.lvYetki.Columns[0].Caption := T('YETKI_SUTUN_YETKILI');
      Pencere.lvYetki.Columns[1].Caption := T('YETKI_SUTUN_TUR');
    end
    else
    begin
      Pencere.Caption := TF('YETKI_BASLIK_KULLANICI', [Ad]);
      Pencere.lblBilgi.Caption := T('YETKI_BILGI_KULLANICI');
      Pencere.lvYetki.Columns[0].Caption := T('YETKI_SUTUN_NESNE');
      Pencere.lvYetki.Columns[1].Caption := T('YETKI_SUTUN_TUR');
    end;
    Pencere.lvYetki.Columns[2].Caption := T('YETKI_SUTUN_YETKILER');
    Pencere.lvYetki.Columns[3].Caption := T('YETKI_SUTUN_VEREBILIR');
    Pencere.ShowModal;
  finally
    Pencere.Free;
  end;
end;

procedure TfrmYetkiler.FormShow(Sender: TObject);
begin
  Doldur;
end;

procedure TfrmYetkiler.Yaz(const Metin: string);
begin
  if FMesaj <> nil then
    FMesaj.Add(Metin);
end;

{ Listeyi veritabanindan okuyup yeniden doldurur. }
procedure TfrmYetkiler.Doldur;
var
  Satir: TListItem;
  N: TNesneYetkisi;
  K: TKullaniciYetkisi;
  TurYazisi: string;
begin
  lvYetki.Items.BeginUpdate;
  try
    lvYetki.Items.Clear;
    if FKip = ykNesne then
    begin
      FNesneSatirlari := NesneYetkileriOku(FBag, FAd, FTur);
      for N in FNesneSatirlari do
      begin
        Satir := lvYetki.Items.Add;
        Satir.Caption := N.Ad;
        case N.Hedef of
          yhRol: TurYazisi := T('YETKI_TUR_ROL');
          yhHerkes: TurYazisi := T('YETKI_TUR_HERKES');
        else
          TurYazisi := T('YETKI_TUR_KULLANICI');
        end;
        Satir.SubItems.Add(TurYazisi);
        Satir.SubItems.Add(N.Yetkiler);
        Satir.SubItems.Add(EvetHayirMetni(N.Verebilir));
      end;
      btnAl.Enabled := Length(FNesneSatirlari) > 0;
    end
    else
    begin
      FKullaniciSatirlari := KullaniciYetkileriOku(FBag, FAd, yhKullanici);
      for K in FKullaniciSatirlari do
      begin
        Satir := lvYetki.Items.Add;
        Satir.Caption := K.Nesne;
        case K.NesneTuru of
          OBJE_TABLO: TurYazisi := T('YETKI_TUR_TABLO');
          OBJE_PROSEDUR: TurYazisi := T('YETKI_TUR_PROSEDUR');
          OBJE_ROL: TurYazisi := T('YETKI_TUR_ROL_UYELIK');
        else
          TurYazisi := T('YETKI_TUR_DIGER');
        end;
        Satir.SubItems.Add(TurYazisi);
        Satir.SubItems.Add(K.Yetkiler);
        Satir.SubItems.Add(EvetHayirMetni(K.Verebilir));
      end;
      btnHepsi.Enabled := Length(FKullaniciSatirlari) > 0;
    end;
    if lvYetki.Items.Count > 0 then
      lvYetki.ItemIndex := 0;
  finally
    lvYetki.Items.EndUpdate;
  end;
end;

{ Nesne kipinde yeni yetki icin bos girdi: nesne bu pencerenin nesnesi. }
function TfrmYetkiler.IlkGirdi: TYetkiGirdisi;
begin
  Result := Default(TYetkiGirdisi);
  Result.Nesne := FAd;
  Result.NesneTuru := FTur;
end;

procedure TfrmYetkiler.btnVerClick(Sender: TObject);
var
  G: TYetkiGirdisi;
begin
  if YetkiVerPenceresiGoster(FBag, yiVer, IlkGirdi, G) then
    Uygula(yiVer, G);
end;

procedure TfrmYetkiler.btnAlClick(Sender: TObject);
var
  Ilk, G: TYetkiGirdisi;
  Secili: TNesneYetkisi;
begin
  if (lvYetki.ItemIndex < 0) or (lvYetki.ItemIndex >= Length(FNesneSatirlari)) then
    Exit;
  Secili := FNesneSatirlari[lvYetki.ItemIndex];
  Ilk := IlkGirdi;
  Ilk.Hedef := Secili.Hedef;
  Ilk.Ad := Secili.Ad;
  Ilk.Harfler := Secili.Harfler;
  if YetkiVerPenceresiGoster(FBag, yiAl, Ilk, G) then
    Uygula(yiAl, G);
end;

{ Onay, uygulama, sonuc mesaji ve listenin yenilenmesi (ver ve al icin ortak). }
procedure TfrmYetkiler.Uygula(Islem: TYetkiIslemi; const G: TYetkiGirdisi);
var
  Komut: string;
begin
  Komut := YetkiKomutu(FBag, Islem, G);
  if not OnayIste(YetkiOnayMetni(Islem, G, Komut)) then
  begin
    Yaz(T('MSG_YETKI_VAZGECILDI'));
    Exit;
  end;
  SonucuBildir(Islem, G.Nesne, YetkiUygula(FBag, Islem, G));
end;

procedure TfrmYetkiler.SonucuBildir(Islem: TYetkiIslemi; const Nesne: string; const Sonuc: TProsedurSonucu);
begin
  if Sonuc.Basarili then
  begin
    if Islem = yiVer then
      Yaz(TF('MSG_YETKI_VERILDI', [Nesne]))
    else
      Yaz(TF('MSG_YETKI_ALINDI', [Nesne]));
  end
  else
  begin
    if Islem = yiVer then
      Yaz(TF('ERR_YETKI_VERILEMEDI', [Nesne]) + ' ' + Sonuc.Cumle)
    else
      Yaz(TF('ERR_YETKI_ALINAMADI', [Nesne]) + ' ' + Sonuc.Cumle);
    if Sonuc.Ayrinti <> '' then
      Yaz(T('AYRINTI') + ': ' + Sonuc.Ayrinti);
    if Length(Sonuc.Komutlar) = 0 then
      Yaz(T('MSG_PRS_DOKUNULMADI'))
    else
      Yaz(T('MSG_YETKI_GERI_ALINDI'));
  end;
  if (Length(Sonuc.Komutlar) > 0) and Assigned(FSqlYaz) then
    FSqlYaz(Sonuc.Komutlar);
  Doldur;
end;

{ Kullanici kipi: kullanicinin tum tablo / view / prosedur yetkileri tek islemde geri alinir (net onayla). }
procedure TfrmYetkiler.btnHepsiClick(Sender: TObject);
var
  Komutlar: string;
begin
  Komutlar := HepsiniAlKomutlari(FBag, FAd, yhKullanici);
  if Komutlar = '' then
  begin
    UyariGoster(T('ERR_YETKI_YOK_ALINACAK'));
    Exit;
  end;
  if not OnayIste(TF('ONAY_YETKI_HEPSI', [FAd, Komutlar])) then
  begin
    Yaz(T('MSG_YETKI_VAZGECILDI'));
    Exit;
  end;
  SonucuBildir(yiAl, FAd, HepsiniAlUygula(FBag, FAd, yhKullanici));
end;

end.
