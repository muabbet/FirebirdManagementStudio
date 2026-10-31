{ fSunucuSec.pas - "Sunucular" penceresi: bir bilgisayarda calisan Firebird sunucularini listeler, kullanici birini secer.
  Form yalniz listeyi gosterir; tarama uSunucuBul'dadir. Secilen sunucu ve port Baglanti penceresine yazilir. }
unit fSunucuSec;

interface

uses
  System.SysUtils, System.Classes, Vcl.Controls, Vcl.Forms, Vcl.StdCtrls, Vcl.ExtCtrls, Vcl.ComCtrls,
  uDil, uSunucuBul, uOnay;

type
  TfrmSunucuSec = class(TForm)
    lblBilgi: TLabel;
    lvSunucu: TListView;
    pnlAlt: TPanel;
    btnKapat: TButton;
    btnSec: TButton;
    procedure FormShow(Sender: TObject);
    procedure btnSecClick(Sender: TObject);
  private
    FSunucu: string;
    FBulunanlar: TArray<TBulunanSunucu>;
    procedure Tara;
  end;

{ Pencereyi acar ve Sunucu'yu (bos = bu bilgisayar) tarar. Kullanici bir satir secerse True doner ve
  SecilenSunucu / SecilenPort dolar. }
function SunucuSec(const Sunucu: string; out SecilenSunucu: string; out SecilenPort: Integer): Boolean;

implementation

{$R *.dfm}

var
  GSecilen: TBulunanSunucu;

function SunucuSec(const Sunucu: string; out SecilenSunucu: string; out SecilenPort: Integer): Boolean;
var
  Pencere: TfrmSunucuSec;
begin
  Pencere := TfrmSunucuSec.Create(Application);
  try
    Pencere.FSunucu := Sunucu;
    Pencere.Caption := T('SUNUCU_BASLIK');
    Pencere.lvSunucu.Columns[0].Caption := T('SUNUCU_SUTUN_SUNUCU');
    Pencere.lvSunucu.Columns[1].Caption := T('SUNUCU_SUTUN_PORT');
    Pencere.lvSunucu.Columns[2].Caption := T('SUNUCU_SUTUN_SURUM');
    Pencere.btnSec.Caption := T('BTN_SEC');
    Pencere.btnKapat.Caption := T('BTN_KAPAT');
    DugmeyiYaziyaUydur(Pencere.btnSec);
    DugmeyiYaziyaUydur(Pencere.btnKapat);
    Result := Pencere.ShowModal = mrOk;
    if Result then
    begin
      SecilenSunucu := GSecilen.Sunucu;
      SecilenPort := GSecilen.Port;
    end;
  finally
    Pencere.Free;
  end;
end;

procedure TfrmSunucuSec.FormShow(Sender: TObject);
begin
  Tara;
end;

{ Taramayi yapar (yarim saniye kadar surer) ve listeyi doldurur. }
procedure TfrmSunucuSec.Tara;
var
  Kayit: TBulunanSunucu;
  Satir: TListItem;
begin
  lblBilgi.Caption := T('SUNUCU_TARANIYOR');
  btnSec.Enabled := False;
  Screen.Cursor := crHourGlass;
  Update;
  try
    FBulunanlar := SunuculariBul(FSunucu);
  finally
    Screen.Cursor := crDefault;
  end;
  lvSunucu.Items.Clear;
  for Kayit in FBulunanlar do
  begin
    Satir := lvSunucu.Items.Add;
    Satir.Caption := Kayit.Sunucu;
    Satir.SubItems.Add(IntToStr(Kayit.Port));
    if Kayit.Surum <> '' then
      Satir.SubItems.Add(TF('SUNUCU_SURUM', [Kayit.Surum]))
    else
      Satir.SubItems.Add(T('SUNUCU_SURUM_BILINMIYOR'));
  end;
  if Length(FBulunanlar) = 0 then
    lblBilgi.Caption := T('SUNUCU_YOK')
  else
  begin
    lblBilgi.Caption := TF('SUNUCU_BULUNDU', [Length(FBulunanlar)]);
    lvSunucu.ItemIndex := 0;
    btnSec.Enabled := True;
  end;
end;

procedure TfrmSunucuSec.btnSecClick(Sender: TObject);
begin
  if lvSunucu.ItemIndex < 0 then
    Exit;
  GSecilen := FBulunanlar[lvSunucu.ItemIndex];
  ModalResult := mrOk;
end;

end.
