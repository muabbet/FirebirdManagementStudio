{ fHakkinda.pas - Hakkinda penceresi (ad, surum, yetki, lisans). Yonetici rozetine tiklaninca acilir.
  Surum yazisi, hata bildirirken kopyalanabilsin diye panoya alinabilir. }
unit fHakkinda;

interface

uses
  System.SysUtils, System.Classes, Vcl.Controls, Vcl.Forms, Vcl.StdCtrls, Vcl.ExtCtrls, Vcl.Clipbrd,
  uDil, uOnay, uUygulama;

type
  TfrmHakkinda = class(TForm)
    lblAd: TLabel;
    lblSurumBaslik: TLabel;
    lblSurumEtiket: TLabel;
    lblSurumDeger: TLabel;
    lblPlatformEtiket: TLabel;
    lblPlatformDeger: TLabel;
    lblYetkiEtiket: TLabel;
    lblYetkiDeger: TLabel;
    btnKopyala: TButton;
    btnFikir: TButton;
    lblLisansBaslik: TLabel;
    lblLisans: TLabel;
    pnlAlt: TPanel;
    btnTamam: TButton;
    procedure btnKopyalaClick(Sender: TObject);
    procedure btnFikirClick(Sender: TObject);
  end;

procedure HakkindaGoster(YoneticiMi: Boolean);

implementation

{$R *.dfm}

procedure TfrmHakkinda.btnKopyalaClick(Sender: TObject);
begin
  Clipboard.AsText := UYGULAMA_ADI + ' ' + UYGULAMA_SURUMU;
end;

procedure TfrmHakkinda.btnFikirClick(Sender: TObject);
begin
  AdresiAc(GERI_BILDIRIM_ADRESI);
end;

procedure HakkindaGoster(YoneticiMi: Boolean);
var
  Pencere: TfrmHakkinda;
begin
  Pencere := TfrmHakkinda.Create(Application);
  try
    Pencere.Caption := T('HAKKINDA_BASLIK');
    Pencere.lblAd.Caption := UYGULAMA_ADI;
    Pencere.lblSurumBaslik.Caption := T('HAKKINDA_SURUM_BASLIK');
    Pencere.lblSurumEtiket.Caption := T('HAKKINDA_SURUM');
    Pencere.lblSurumDeger.Caption := UYGULAMA_SURUMU;
    Pencere.lblPlatformEtiket.Caption := T('HAKKINDA_PLATFORM');
    Pencere.lblPlatformDeger.Caption := 'Windows 64 bit';
    Pencere.lblYetkiEtiket.Caption := T('HAKKINDA_YETKI');
    if YoneticiMi then
      Pencere.lblYetkiDeger.Caption := T('YONETICI_ROZET')
    else
      Pencere.lblYetkiDeger.Caption := T('HAKKINDA_YETKI_NORMAL');
    Pencere.btnKopyala.Caption := T('BTN_SURUMU_KOPYALA');
    DugmeyiYaziyaUydur(Pencere.btnKopyala);
    Pencere.btnFikir.Caption := T('BTN_FIKIR_ONERI');
    DugmeyiYaziyaUydur(Pencere.btnFikir);
    { Iki dugme ayni genislikte ve alt alta hizali dursun (genislik yaziya gore, ikisinden buyugu). }
    if Pencere.btnKopyala.Width > Pencere.btnFikir.Width then
      Pencere.btnFikir.Width := Pencere.btnKopyala.Width
    else
      Pencere.btnKopyala.Width := Pencere.btnFikir.Width;
    Pencere.lblLisansBaslik.Caption := T('HAKKINDA_LISANS_BASLIK');
    Pencere.lblLisans.Caption := T('HAKKINDA_LISANS_METIN');
    Pencere.btnTamam.Caption := T('BTN_TAMAM');
    Pencere.ShowModal;
  finally
    Pencere.Free;
  end;
end;

end.
