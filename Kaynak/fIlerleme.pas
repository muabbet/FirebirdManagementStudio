{ fIlerleme.pas - Uzun islemler icin kucuk ilerleme penceresi (Asama 7h: veritabani kopyalama / yeniden yaratma).
  Ne yapildigini yazar (adim), son gbak satirini ve (biliniyorsa) olusan dosyanin boyutunu gosterir, gecen sureyi sayar ve
  hareketli bir cubuk gosterir; yuzde verilemez (gbak toplami onceden bilmez). Iptal dugmesi islemi durdurur.
  Ana pencere islem boyunca kapali tutulur (islem sirasinda baska bir seye tiklanip karisiklik olmasin).
  Kullanim: P := IlerlemeAc(Baslik); try Islem(P.Cikti, P.AdimBildir) finally P.Bitir end; }
unit fIlerleme;

interface

uses
  System.SysUtils, System.Classes, Winapi.Windows, Vcl.Controls, Vcl.Forms, Vcl.StdCtrls, Vcl.ComCtrls, System.IOUtils, uDil, uYedek;

type
  TfrmIlerleme = class(TForm)
    lblBaslik: TLabel;
    lblDetay: TLabel;
    lblSure: TLabel;
    pbIlerleme: TProgressBar;
    btnIptal: TButton;
    procedure btnIptalClick(Sender: TObject);
    procedure FormCloseQuery(Sender: TObject; var CanClose: Boolean);
  private
    FBaslangic: Cardinal;
    FSonGuncelleme: Cardinal;
    FIptalIstendi: Boolean;
    FDosya: string;
    FSonSatir: string;
    procedure Goster;
  public
    { gbak satiri gelince ya da beklerken (Satir bos) cagrilir; TYedekCiktisi ile ayni imza }
    procedure Cikti(const Satir: string; var Iptal: Boolean);
    { Yeni adim: baslik yazisi (ornek "1/2 Yedekleniyor") ve boyutu izlenecek dosya (bos = izlenmez) }
    procedure AdimBildir(const Metin, Dosya: string);
    procedure Bitir;
  end;

{ Pencereyi acar ve gosterir (modsuz; ana pencere kapatilir). Cagiran isi bitince Bitir cagirir. }
function IlerlemeAc(const Baslik: string): TfrmIlerleme;

implementation

{$R *.dfm}

function IlerlemeAc(const Baslik: string): TfrmIlerleme;
begin
  Result := TfrmIlerleme.Create(Application);
  Result.Caption := Baslik;
  Result.btnIptal.Caption := T('BTN_IPTAL');
  Result.lblDetay.Caption := T('ILERLEME_ACIKLAMA');
  Result.FBaslangic := GetTickCount;
  Result.Goster;
end;

procedure TfrmIlerleme.Goster;
begin
  if Application.MainForm <> nil then
  begin
    PopupParent := Application.MainForm;
    Application.MainForm.Enabled := False;
  end;
  Show;
  Update;
end;

procedure TfrmIlerleme.AdimBildir(const Metin, Dosya: string);
begin
  lblBaslik.Caption := Metin;
  FDosya := Dosya;
  FSonSatir := '';
  Update;
end;

function SureYazisi(Milisaniye: Cardinal): string;
var
  Saniye: Cardinal;
begin
  Saniye := Milisaniye div 1000;
  Result := Format('%d:%.2d', [Saniye div 60, Saniye mod 60]);
end;

procedure TfrmIlerleme.Cikti(const Satir: string; var Iptal: Boolean);
var
  Detay: string;
begin
  if Trim(Satir) <> '' then
    FSonSatir := Trim(Satir);
  if GetTickCount - FSonGuncelleme > 150 then
  begin
    FSonGuncelleme := GetTickCount;
    lblSure.Caption := TF('ILERLEME_SURE', [SureYazisi(GetTickCount - FBaslangic)]);
    Detay := T('ILERLEME_ACIKLAMA');
    if (FDosya <> '') and FileExists(FDosya) then
      Detay := Detay + sLineBreak + TF('ILERLEME_DOSYA', [BoyutMetni(TFile.GetSize(FDosya))]);
    if FSonSatir <> '' then
      Detay := Detay + sLineBreak + Copy(FSonSatir, 1, 90);
    lblDetay.Caption := Detay;
    Application.ProcessMessages;
  end;
  Iptal := FIptalIstendi;
end;

procedure TfrmIlerleme.btnIptalClick(Sender: TObject);
begin
  FIptalIstendi := True;
  btnIptal.Enabled := False;
  lblBaslik.Caption := T('ILERLEME_IPTAL_EDILIYOR');
end;

{ Islem bitmeden pencere kapatilamaz; iptal dugmesi kullanilir. }
procedure TfrmIlerleme.FormCloseQuery(Sender: TObject; var CanClose: Boolean);
begin
  CanClose := False;
end;

procedure TfrmIlerleme.Bitir;
begin
  if Application.MainForm <> nil then
    Application.MainForm.Enabled := True;
  Hide;
  Free;
end;

end.
