{ fGeneratorDeger.pas - Generator'in degerini gosteren ve yeni deger soran kucuk pencere (Asama 3f-4).
  Sadece arayuz: degeri okuma ve ayarlama uNesneYonet'te, onay penceresi cagiran tarafta. Pencere yalniz
  yeni degerin bir tam sayi olup olmadigina bakar. }
unit fGeneratorDeger;

interface

uses
  System.SysUtils, System.Classes, Vcl.Controls, Vcl.Forms, Vcl.StdCtrls, Vcl.ExtCtrls,
  uDil, uOnay;

type
  TfrmGeneratorDeger = class(TForm)
    lblSimdiki: TLabel;
    lblYeni: TLabel;
    edtYeni: TEdit;
    lblKullanan: TLabel;
    memKullanan: TMemo;
    pnlAlt: TPanel;
    btnIptal: TButton;
    btnTamam: TButton;
    procedure FormCloseQuery(Sender: TObject; var CanClose: Boolean);
  end;

{ Ad: generator adi, Mevcut: simdiki deger, Kullananlar: onceden hazirlanmis satirlar (bos olabilir).
  Tamam'a basilir ve yazilan deger tam sayi ise True doner ve Yeni dolar. }
function GeneratorDegerPenceresi(const Ad: string; Mevcut: Int64; const Kullananlar: string; out Yeni: Int64): Boolean;

implementation

{$R *.dfm}

function GeneratorDegerPenceresi(const Ad: string; Mevcut: Int64; const Kullananlar: string; out Yeni: Int64): Boolean;
var
  Pencere: TfrmGeneratorDeger;
begin
  Yeni := Mevcut;
  Pencere := TfrmGeneratorDeger.Create(Application);
  try
    Pencere.Caption := TF('GEN_DEGER_BASLIK', [Ad]);
    Pencere.lblSimdiki.Caption := TF('GEN_DEGER_SIMDIKI', [Mevcut]);
    Pencere.lblYeni.Caption := T('GEN_DEGER_YENI');
    Pencere.lblKullanan.Caption := T('GEN_DEGER_KULLANANLAR');
    if Kullananlar = '' then
      Pencere.memKullanan.Text := T('ONAY_SIL_BAGIMLI_YOK')
    else
      Pencere.memKullanan.Text := Kullananlar;
    Pencere.btnTamam.Caption := T('PRS_KAYDET');
    Pencere.btnIptal.Caption := T('BTN_IPTAL');
    DugmeyiYaziyaUydur(Pencere.btnTamam);
    DugmeyiYaziyaUydur(Pencere.btnIptal);
    Pencere.edtYeni.Text := IntToStr(Mevcut);
    Pencere.ActiveControl := Pencere.edtYeni;
    Result := Pencere.ShowModal = mrOk;
    if Result then
      Result := TryStrToInt64(Trim(Pencere.edtYeni.Text), Yeni);
  finally
    Pencere.Free;
  end;
end;

{ Tamam'a basilirken yazi tam sayi degilse pencere kapanmaz, ne yapilacagi yazilir. }
procedure TfrmGeneratorDeger.FormCloseQuery(Sender: TObject; var CanClose: Boolean);
var
  Sayi: Int64;
begin
  if ModalResult = mrOk then
  begin
    CanClose := TryStrToInt64(Trim(edtYeni.Text), Sayi);
    if not CanClose then
      UyariGoster(T('ERR_GEN_DEGER_GECERSIZ'));
  end;
end;

end.
