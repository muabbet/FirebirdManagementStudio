{ fMetinSor.pas - Kucuk "bir yazi girin" penceresi.
  Klasor adi sorarken ve sifresiz baglantida sifre sorarken kullanilir.
  Gizli = True ise yazilan karakterler gizlenir (PasswordChar). Girilen deger
  hicbir yere kaydedilmez, sadece cagiran fonksiyona geri verilir. }
unit fMetinSor;

interface

uses
  System.SysUtils, System.Classes, Vcl.Controls, Vcl.Forms, Vcl.StdCtrls,
  Vcl.ExtCtrls,
  uDil;

type
  TfrmMetinSor = class(TForm)
    lblEtiket: TLabel;
    edtDeger: TEdit;
    pnlAlt: TPanel;
    btnIptal: TButton;
    btnTamam: TButton;
  end;

function MetinSor(const Baslik, Etiket: string; var Deger: string; Gizli: Boolean): Boolean;

implementation

{$R *.dfm}

{ Dugme genisligi yaziya gore uzar (Almanca yazilar kesilmesin). }
procedure DugmeyiYaziyaUydur(Pencere: TForm; Dugme: TButton);
begin
  Pencere.Canvas.Font.Assign(Pencere.Font);
  Dugme.Width := Dugme.Constraints.MinWidth;
  if Pencere.Canvas.TextWidth(Dugme.Caption) + 32 > Dugme.Width then
    Dugme.Width := Pencere.Canvas.TextWidth(Dugme.Caption) + 32;
end;

function MetinSor(const Baslik, Etiket: string; var Deger: string; Gizli: Boolean): Boolean;
var
  Pencere: TfrmMetinSor;
begin
  Pencere := TfrmMetinSor.Create(Application);
  try
    Pencere.Caption := Baslik;
    Pencere.lblEtiket.Caption := Etiket;
    Pencere.btnTamam.Caption := T('BTN_TAMAM');
    Pencere.btnIptal.Caption := T('BTN_IPTAL');
    DugmeyiYaziyaUydur(Pencere, Pencere.btnTamam);
    DugmeyiYaziyaUydur(Pencere, Pencere.btnIptal);
    if Gizli then
      Pencere.edtDeger.PasswordChar := '*';
    Pencere.edtDeger.Text := Deger;
    Pencere.ActiveControl := Pencere.edtDeger;
    Result := Pencere.ShowModal = mrOk;
    if Result then
      Deger := Pencere.edtDeger.Text;
  finally
    Pencere.Free;
  end;
end;

end.
