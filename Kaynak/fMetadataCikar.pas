{ fMetadataCikar.pas - "Metadata cikar" penceresi (Asama 3a Adim 2).
  Form sadece arayuzu bilir; is uDDL.MetadataCikar'dadir. Hedef: dosya (varsayilan) veya pano.
  CREATE DATABASE / CONNECT / sifre secenekleri varsayilan KAPALIDIR; sifre isaretlenirse net uyari gosterilir.
  Sifre kayitli baglantidan (DPAPI) gelir, burada yazilmaz. Uzun surerken ilerleme yazilir, Iptal ile durdurulur;
  iptalde yarim dosya silinmez. }
unit fMetadataCikar;

interface

uses
  Winapi.Windows, System.SysUtils, System.Classes, System.IOUtils, Vcl.Controls, Vcl.Forms, Vcl.StdCtrls, Vcl.ExtCtrls,
  Vcl.Dialogs, Vcl.Clipbrd,
  uDil, uOnay, uBaglanti, uDDL;

type
  TfrmMetadataCikar = class(TForm)
    gbHedef: TGroupBox;
    rbDosya: TRadioButton;
    edtDosya: TEdit;
    btnGozat: TButton;
    rbPano: TRadioButton;
    gbSecenekler: TGroupBox;
    chkCreateDb: TCheckBox;
    chkConnect: TCheckBox;
    chkSifre: TCheckBox;
    lblUyari: TLabel;
    lblDurum: TLabel;
    pnlAlt: TPanel;
    btnKapat: TButton;
    btnCikar: TButton;
    dlgKaydet: TSaveDialog;
    procedure HedefDegisti(Sender: TObject);
    procedure SecenekDegisti(Sender: TObject);
    procedure btnGozatClick(Sender: TObject);
    procedure btnCikarClick(Sender: TObject);
    procedure btnKapatClick(Sender: TObject);
    procedure FormCloseQuery(Sender: TObject; var CanClose: Boolean);
  private
    FBag: TAcikBaglanti;
    FSonuc: TStrings;
    FCalisiyor: Boolean;
    FIptalIstendi: Boolean;
    FSonGuncelleme: Cardinal;
    procedure YazilariYaz;
    procedure CalisiyorAyarla(Calisiyor: Boolean);
    function SecenekleriOku: TCikarSecenekleri;
    procedure Ilerle(const Aciklama: string; var Iptal: Boolean);
    procedure SonucuYaz(const Ozet: string; Uyarilar: TStrings);
    procedure DosyayaCikar;
    procedure PanoyaCikar;
  end;

{ Pencereyi gosterir. Bitince ana pencerenin sonuc alanina yazilacak satirlar Sonuc'a eklenir. }
procedure MetadataPenceresiniGoster(Bag: TAcikBaglanti; Sonuc: TStrings);

implementation

{$R *.dfm}

const
  { Panoya bundan buyuk metin konmaz (karakter sayisi; yaklasik 8 MB). }
  PANO_SINIRI = 8 * 1024 * 1024;

procedure MetadataPenceresiniGoster(Bag: TAcikBaglanti; Sonuc: TStrings);
var
  Pencere: TfrmMetadataCikar;
begin
  Pencere := TfrmMetadataCikar.Create(Application);
  try
    Pencere.FBag := Bag;
    Pencere.FSonuc := Sonuc;
    Pencere.YazilariYaz;
    Pencere.HedefDegisti(nil);
    Pencere.SecenekDegisti(nil);
    Pencere.ShowModal;
  finally
    Pencere.Free;
  end;
end;

procedure TfrmMetadataCikar.YazilariYaz;
begin
  Caption := T('MD_BASLIK') + ' - ' + FBag.Tanim.Ad;
  gbHedef.Caption := T('MD_HEDEF');
  rbDosya.Caption := T('MD_HEDEF_DOSYA');
  rbPano.Caption := T('MD_HEDEF_PANO');
  btnGozat.Caption := T('MD_DOSYA_SEC');
  gbSecenekler.Caption := T('MD_SECENEKLER');
  chkCreateDb.Caption := T('MD_CREATE_DB');
  chkConnect.Caption := T('MD_CONNECT');
  chkSifre.Caption := T('MD_SIFRE');
  lblUyari.Caption := T('MD_SIFRE_UYARI');
  btnCikar.Caption := T('MD_CIKAR');
  btnKapat.Caption := T('BTN_KAPAT');
  dlgKaydet.Filter := T('MD_DOSYA_FILTRE');
end;

procedure TfrmMetadataCikar.HedefDegisti(Sender: TObject);
begin
  edtDosya.Enabled := rbDosya.Checked;
  btnGozat.Enabled := rbDosya.Checked;
end;

{ Sifre kutusu sadece CREATE DATABASE veya CONNECT isaretliyken anlamlidir. }
procedure TfrmMetadataCikar.SecenekDegisti(Sender: TObject);
begin
  chkSifre.Enabled := chkCreateDb.Checked or chkConnect.Checked;
  if not chkSifre.Enabled then
    chkSifre.Checked := False;
  lblUyari.Visible := chkSifre.Checked;
end;

procedure TfrmMetadataCikar.CalisiyorAyarla(Calisiyor: Boolean);
begin
  FCalisiyor := Calisiyor;
  FIptalIstendi := False;
  gbHedef.Enabled := not Calisiyor;
  gbSecenekler.Enabled := not Calisiyor;
  btnCikar.Enabled := not Calisiyor;
  if Calisiyor then
    btnKapat.Caption := T('BTN_IPTAL')
  else
    btnKapat.Caption := T('BTN_KAPAT');
end;

function TfrmMetadataCikar.SecenekleriOku: TCikarSecenekleri;
begin
  Result.VeritabaniOlustur := chkCreateDb.Checked;
  Result.BaglantiYaz := chkConnect.Checked;
  Result.SifreYaz := chkSifre.Checked;
end;

{ Cikarma sirasinda cagrilir: durum yazisini gunceller (kisa aralikla), pencerenin donmamasi icin
  mesajlari isler ve iptal istendiyse bildirir. }
procedure TfrmMetadataCikar.Ilerle(const Aciklama: string; var Iptal: Boolean);
begin
  if GetTickCount - FSonGuncelleme > 80 then
  begin
    FSonGuncelleme := GetTickCount;
    lblDurum.Caption := Aciklama;
    Application.ProcessMessages;
  end;
  Iptal := FIptalIstendi;
end;

procedure TfrmMetadataCikar.btnGozatClick(Sender: TObject);
begin
  dlgKaydet.FileName := edtDosya.Text;
  if dlgKaydet.Execute then
    edtDosya.Text := dlgKaydet.FileName;
end;

procedure TfrmMetadataCikar.btnKapatClick(Sender: TObject);
begin
  if FCalisiyor then
    FIptalIstendi := True
  else
    ModalResult := mrCancel;
end;

procedure TfrmMetadataCikar.FormCloseQuery(Sender: TObject; var CanClose: Boolean);
begin
  if FCalisiyor then
  begin
    FIptalIstendi := True;
    CanClose := False;
  end;
end;

{ Ana pencerenin sonuc alanina yazilacak satirlar: ozet ve (varsa) uyarilar. }
procedure TfrmMetadataCikar.SonucuYaz(const Ozet: string; Uyarilar: TStrings);
var
  Uyari: string;
begin
  FSonuc.Add(Ozet);
  if Uyarilar.Count > 0 then
    FSonuc.Add(TF('MD_UYARI_SAYISI', [Uyarilar.Count]));
  for Uyari in Uyarilar do
    FSonuc.Add('  ' + Uyari);
end;

procedure TfrmMetadataCikar.DosyayaCikar;
var
  Dosya: string;
  Kodlama: TEncoding;
  Yazici: TStreamWriter;
  Uyarilar: TStringList;
  Tamam: Boolean;
begin
  Dosya := Trim(edtDosya.Text);
  if Dosya = '' then
  begin
    UyariGoster(T('ERR_MD_DOSYA_BOS'));
    Exit;
  end;
  if FileExists(Dosya) and not OnayIste(TF('ONAY_UZERINE_YAZ', [Dosya, DateTimeToStr(TFile.GetLastWriteTime(Dosya))])) then
    Exit;
  Uyarilar := TStringList.Create;
  Kodlama := TUTF8Encoding.Create(False);
  try
    CalisiyorAyarla(True);
    try
      try
        Yazici := TStreamWriter.Create(Dosya, False, Kodlama);
        try
          Tamam := MetadataCikar(FBag, SecenekleriOku, Yazici, Uyarilar, Ilerle);
        finally
          Yazici.Free;
        end;
      except
        on E: Exception do
        begin
          FSonuc.Add(T('ERR_MD_YAZILAMADI') + ' ' + HataMetniniCevir(E));
          FSonuc.Add(T('AYRINTI') + ': ' + E.Message);
          ModalResult := mrCancel;
          Exit;
        end;
      end;
    finally
      CalisiyorAyarla(False);
    end;
    if Tamam then
      SonucuYaz(TF('MD_BITTI_DOSYA', [Dosya]), Uyarilar)
    else
      SonucuYaz(TF('MD_IPTAL_DOSYA', [Dosya]), Uyarilar);
    ModalResult := mrOk;
  finally
    Kodlama.Free;
    Uyarilar.Free;
  end;
end;

procedure TfrmMetadataCikar.PanoyaCikar;
var
  Yazici: TStringWriter;
  Uyarilar: TStringList;
  Metin: string;
  Tamam: Boolean;
begin
  Uyarilar := TStringList.Create;
  Yazici := TStringWriter.Create;
  try
    CalisiyorAyarla(True);
    try
      try
        Tamam := MetadataCikar(FBag, SecenekleriOku, Yazici, Uyarilar, Ilerle);
      except
        on E: Exception do
        begin
          FSonuc.Add(T('ERR_MD_YAZILAMADI') + ' ' + HataMetniniCevir(E));
          FSonuc.Add(T('AYRINTI') + ': ' + E.Message);
          ModalResult := mrCancel;
          Exit;
        end;
      end;
    finally
      CalisiyorAyarla(False);
    end;
    if not Tamam then
    begin
      SonucuYaz(T('MD_IPTAL_PANO'), Uyarilar);
      ModalResult := mrOk;
      Exit;
    end;
    Metin := Yazici.ToString;
    if Length(Metin) > PANO_SINIRI then
    begin
      { Sessizce kesilmez; pencere acik kalir, kullanici dosyaya kaydedebilir. }
      lblDurum.Caption := '';
      UyariGoster(TF('MD_PANO_BUYUK', [Length(Metin) div (1024 * 1024)]));
      Exit;
    end;
    Clipboard.AsText := Metin;
    SonucuYaz(TF('MD_BITTI_PANO', [Length(Metin)]), Uyarilar);
    ModalResult := mrOk;
  finally
    Yazici.Free;
    Uyarilar.Free;
  end;
end;

procedure TfrmMetadataCikar.btnCikarClick(Sender: TObject);
begin
  if rbDosya.Checked then
    DosyayaCikar
  else
    PanoyaCikar;
end;

end.
