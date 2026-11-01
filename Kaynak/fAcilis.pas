unit fAcilis;

{ Acilis ekrani: program acilirken kisa bir sure gorunur (ad, surum, "yukleniyor").
  Form yalniz arayuzu bilir; gosterme ve kapatma asagidaki iki yordamla yapilir. }

interface

uses
  System.SysUtils, System.Classes, Vcl.Controls, Vcl.Forms, Vcl.StdCtrls, Vcl.ExtCtrls, Vcl.ComCtrls;

type
  TfrmAcilis = class(TForm)
    pnlCerceve: TPanel;
    pnlIc: TPanel;
    shpSerit: TShape;
    imgLogo: TImage;
    lblAd: TLabel;
    lblAlt: TLabel;
    lblSurum: TLabel;
    lblDurum: TLabel;
    barBekle: TProgressBar;
  end;

procedure AcilisGoster;
procedure AcilisKapat;

implementation

{$R *.dfm}

uses
  Winapi.Windows, uDil, uUygulama;

const
  EN_AZ_GORUNME_MS = 1200;

var
  GAcilis: TfrmAcilis;
  GBaslangic: UInt64;

procedure AcilisGoster;
begin
  DilYukle(SonKullanilanDil);
  GAcilis := TfrmAcilis.Create(nil);
  GAcilis.lblAd.Caption := UYGULAMA_ADI;
  GAcilis.lblAlt.Caption := T('ACILIS_ALT');
  GAcilis.lblSurum.Caption := TF('ACILIS_SURUM', [UYGULAMA_SURUMU]);
  GAcilis.lblDurum.Caption := T('ACILIS_YUKLENIYOR');
  GAcilis.imgLogo.Picture.Icon.Assign(Application.Icon);
  GAcilis.Show;
  GAcilis.Update;
  GBaslangic := GetTickCount64;
end;

{ Ekran, program hizli acilsa bile okunabilsin diye en az EN_AZ_GORUNME_MS kadar gorunur. }
procedure AcilisKapat;
begin
  if GAcilis = nil then
    Exit;
  while GetTickCount64 - GBaslangic < EN_AZ_GORUNME_MS do
  begin
    Application.ProcessMessages;
    Sleep(20);
  end;
  GAcilis.Free;
  GAcilis := nil;
end;

end.
