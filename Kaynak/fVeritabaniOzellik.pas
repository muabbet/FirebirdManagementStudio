{ fVeritabaniOzellik.pas - "Veritabani ozellikleri" penceresi (7y).
  Form sadece arayuzu bilir; okuma ve degistirme uVeritabaniOzellik'tedir. Ustte ozellikler (salt okunur liste), altta
  degistirilebilen uc ayar: sweep araligi, forced writes, yer ayirma. Uygula, yapilacak degisiklikleri yazip net onay ister. }
unit fVeritabaniOzellik;

interface

uses
  System.SysUtils, System.Classes, Vcl.Controls, Vcl.Forms, Vcl.StdCtrls, Vcl.ExtCtrls, Vcl.ComCtrls,
  Vcl.Samples.Spin,
  uDil, uOnay, uBaglanti, uKullanici, uYedek, uVeritabaniOzellik;

type
  TfrmVeritabaniOzellik = class(TForm)
    lblNot: TLabel;
    lvOzellik: TListView;
    grpAyar: TGroupBox;
    lblSweep: TLabel;
    lblSweepIpucu: TLabel;
    spnSweep: TSpinEdit;
    chkZorla: TCheckBox;
    chkYer: TCheckBox;
    pnlAlt: TPanel;
    btnKapat: TButton;
    btnYenile: TButton;
    btnUygula: TButton;
    procedure btnYenileClick(Sender: TObject);
    procedure btnUygulaClick(Sender: TObject);
  private
    FBag: TAcikBaglanti;
    FSqlYaz: TSqlGoster;
    FSonuc: TStrings;
    FGecerli: TVeritabaniOzellikleri;
    procedure YazilariYaz;
    procedure Yenile;
    procedure SatirEkle(const Ad, Deger: string);
    function EvetHayir(Deger: Boolean): string;
    function Degisiklikler: string;
  end;

{ Pencereyi gosterir. Yapilan her degisiklik Sonuc'a (ana pencerenin sonuc alani) yazilir, calisan gfix komutlari SqlYaz ile
  SQL alanina gider. }
procedure VeritabaniOzellikPenceresiniGoster(Bag: TAcikBaglanti; SqlYaz: TSqlGoster; Sonuc: TStrings);

implementation

{$R *.dfm}

procedure VeritabaniOzellikPenceresiniGoster(Bag: TAcikBaglanti; SqlYaz: TSqlGoster; Sonuc: TStrings);
var
  Pencere: TfrmVeritabaniOzellik;
begin
  Pencere := TfrmVeritabaniOzellik.Create(Application);
  try
    Pencere.FBag := Bag;
    Pencere.FSqlYaz := SqlYaz;
    Pencere.FSonuc := Sonuc;
    Pencere.YazilariYaz;
    Pencere.Yenile;
    Pencere.ShowModal;
  finally
    Pencere.Free;
  end;
end;

procedure TfrmVeritabaniOzellik.YazilariYaz;
begin
  Caption := T('OZELLIK_BASLIK') + ' - ' + FBag.Tanim.Ad;
  lvOzellik.Columns[0].Caption := T('OZELLIK_KOL_OZELLIK');
  lvOzellik.Columns[1].Caption := T('OZELLIK_KOL_DEGER');
  lblNot.Caption := T('OZELLIK_NOT');
  grpAyar.Caption := T('OZELLIK_AYARLAR');
  lblSweep.Caption := T('OZELLIK_SWEEP_ETIKET');
  lblSweepIpucu.Caption := T('OZELLIK_SWEEP_IPUCU');
  chkZorla.Caption := T('OZELLIK_ZORLA_ETIKET');
  chkYer.Caption := T('OZELLIK_YER_ETIKET');
  btnUygula.Caption := T('BTN_UYGULA');
  btnYenile.Caption := T('BTN_YENILE');
  btnKapat.Caption := T('BTN_KAPAT');
  DugmeyiYaziyaUydur(btnUygula);
  DugmeyiYaziyaUydur(btnYenile);
  DugmeyiYaziyaUydur(btnKapat);
end;

function TfrmVeritabaniOzellik.EvetHayir(Deger: Boolean): string;
begin
  if Deger then
    Result := T('EVET')
  else
    Result := T('HAYIR');
end;

procedure TfrmVeritabaniOzellik.SatirEkle(const Ad, Deger: string);
var
  Oge: TListItem;
begin
  Oge := lvOzellik.Items.Add;
  Oge.Caption := Ad;
  Oge.SubItems.Add(Deger);
end;

{ Degerler her seferinde gecici yeni baglantiyla okunur (bkz. uVeritabaniOzellik) }
procedure TfrmVeritabaniOzellik.Yenile;
var
  O: TVeritabaniOzellikleri;
  Duzenlenebilir: Boolean;
begin
  O := OzellikleriOku(FBag);
  FGecerli := O;
  lvOzellik.Items.BeginUpdate;
  try
    lvOzellik.Items.Clear;
    SatirEkle(T('OZELLIK_YOL'), O.Yol);
    SatirEkle(T('OZELLIK_SURUM'), O.Surum);
    if O.Okunamadi then
      SatirEkle(T('OZELLIK_OKUNAMADI'), '')
    else
    begin
      SatirEkle(T('OZELLIK_ODS'), O.Ods);
      SatirEkle(T('OZELLIK_SAYFA'), IntToStr(O.SayfaBoyutu));
      SatirEkle(T('OZELLIK_BOYUT'), TF('OZELLIK_BOYUT_DEGER', [BoyutMetni(O.SayfaSayisi * O.SayfaBoyutu), IntToStr(O.SayfaSayisi)]));
      SatirEkle(T('OZELLIK_DIALECT'), IntToStr(O.Dialect));
      SatirEkle(T('OZELLIK_KARAKTER'), O.KarakterSeti);
      SatirEkle(T('OZELLIK_SWEEP'), IntToStr(O.SweepAraligi));
      SatirEkle(T('OZELLIK_ZORLA'), EvetHayir(O.ZorlaYaz));
      SatirEkle(T('OZELLIK_YER'), EvetHayir(O.YerAyir));
      SatirEkle(T('OZELLIK_SALT'), EvetHayir(O.SaltOkunur));
    end;
  finally
    lvOzellik.Items.EndUpdate;
  end;
  Duzenlenebilir := (not O.Okunamadi) and GfixVarMi;
  spnSweep.Enabled := Duzenlenebilir;
  chkZorla.Enabled := Duzenlenebilir;
  chkYer.Enabled := Duzenlenebilir;
  btnUygula.Enabled := Duzenlenebilir;
  if not O.Okunamadi then
  begin
    spnSweep.Value := O.SweepAraligi;
    chkZorla.Checked := O.ZorlaYaz;
    chkYer.Checked := O.YerAyir;
  end;
end;

{ Onay penceresinde ve soruda gosterilecek degisiklik listesi; degisiklik yoksa bos. }
function TfrmVeritabaniOzellik.Degisiklikler: string;
begin
  Result := '';
  if spnSweep.Value <> FGecerli.SweepAraligi then
    Result := Result + TF('OZELLIK_DEG_SWEEP', [FGecerli.SweepAraligi, spnSweep.Value]) + sLineBreak;
  if chkZorla.Checked <> FGecerli.ZorlaYaz then
  begin
    if chkZorla.Checked then
      Result := Result + T('OZELLIK_DEG_ZORLA_AC') + sLineBreak
    else
      Result := Result + T('OZELLIK_DEG_ZORLA_KAPAT') + sLineBreak;
  end;
  if chkYer.Checked <> FGecerli.YerAyir then
  begin
    if chkYer.Checked then
      Result := Result + T('OZELLIK_DEG_YER_AYIR') + sLineBreak
    else
      Result := Result + T('OZELLIK_DEG_YER_DOLDUR') + sLineBreak;
  end;
end;

procedure TfrmVeritabaniOzellik.btnYenileClick(Sender: TObject);
begin
  Yenile;
end;

procedure TfrmVeritabaniOzellik.btnUygulaClick(Sender: TObject);
var
  Liste: string;
  Sonuc: TOzellikSonucu;
  Komutlar: TArray<string>;
  Hata: Boolean;

  { Sonucu kaydeder; hata varsa True }
  function Isle(const Ad: string; const S: TOzellikSonucu): Boolean;
  begin
    SetLength(Komutlar, Length(Komutlar) + 1);
    Komutlar[High(Komutlar)] := S.Komut;
    Result := not S.Basarili;
    if S.Basarili then
      FSonuc.Add(TF('MSG_OZELLIK_TAMAM', [Ad]))
    else
    begin
      FSonuc.Add(TF('ERR_OZELLIK_YAPILAMADI', [Ad]) + ' ' + S.Cumle);
      FSonuc.Add(T('AYRINTI') + ': ' + Trim(S.Ham));
      UyariGoster(TF('ERR_OZELLIK_YAPILAMADI', [Ad]) + ' ' + S.Cumle);
    end;
  end;

begin
  Liste := Degisiklikler;
  if Liste = '' then
  begin
    UyariGoster(T('OZELLIK_DEGISIKLIK_YOK'));
    Exit;
  end;
  if not OnayIste(TF('ONAY_OZELLIK', [FBag.Tanim.Ad, Liste])) then
    Exit;
  SetLength(Komutlar, 0);
  Hata := False;
  if spnSweep.Value <> FGecerli.SweepAraligi then
  begin
    Sonuc := SweepAraliginiAyarla(FBag, spnSweep.Value);
    Hata := Isle(T('OZELLIK_SWEEP'), Sonuc);
  end;
  if (not Hata) and (chkZorla.Checked <> FGecerli.ZorlaYaz) then
  begin
    Sonuc := ZorlaYaziAyarla(FBag, chkZorla.Checked);
    Hata := Isle(T('OZELLIK_ZORLA'), Sonuc);
  end;
  if (not Hata) and (chkYer.Checked <> FGecerli.YerAyir) then
  begin
    Sonuc := YerAyirmayiAyarla(FBag, chkYer.Checked);
    Isle(T('OZELLIK_YER'), Sonuc);
  end;
  if Assigned(FSqlYaz) then
    FSqlYaz(Komutlar);
  Yenile;
end;

end.
