{ fKullananlar.pas - "Bu kaydi kullananlar" listesi: hangi tabloda kac kayit bu kaydi gosteriyor.
  Sadece arayuz: liste uIliski'de hazirlanir, secileni sekmede acmak cagiran tarafin isidir. }
unit fKullananlar;

interface

uses
  System.SysUtils, System.Classes, Vcl.Controls, Vcl.Forms, Vcl.StdCtrls, Vcl.ExtCtrls,
  uDil, uOnay, uIliski;

type
  TfrmKullananlar = class(TForm)
    lblBilgi: TLabel;
    lstKayitlar: TListBox;
    pnlAlt: TPanel;
    btnAc: TButton;
    btnKapat: TButton;
    procedure lstKayitlarDblClick(Sender: TObject);
  end;

{ Tablo: kaydin tablosu. Kayitlar bos olmamali. Ac'a basilirsa ya da satira cift tiklanirsa True doner, Secim dizideki sira. }
function KullananlarPenceresi(const Tablo: string; const Kayitlar: TArray<TIliskiliKayit>; out Secim: Integer): Boolean;

implementation

{$R *.dfm}

function KullananlarPenceresi(const Tablo: string; const Kayitlar: TArray<TIliskiliKayit>; out Secim: Integer): Boolean;
var
  Pencere: TfrmKullananlar;
  Kayit: TIliskiliKayit;
begin
  Secim := -1;
  Pencere := TfrmKullananlar.Create(Application);
  try
    Pencere.Caption := T('ILISKI_KULLANAN_BASLIK');
    Pencere.lblBilgi.Caption := TF('ILISKI_KULLANAN_BILGI', [Tablo]);
    Pencere.btnAc.Caption := T('ILISKI_AC');
    Pencere.btnKapat.Caption := T('BTN_KAPAT');
    DugmeyiYaziyaUydur(Pencere.btnAc);
    DugmeyiYaziyaUydur(Pencere.btnKapat);
    for Kayit in Kayitlar do
      Pencere.lstKayitlar.Items.Add(TF('ILISKI_KULLANAN_SATIR', [Kayit.Tablo, Kayit.Kolonlar, Kayit.Adet]));
    if Pencere.lstKayitlar.Items.Count > 0 then
      Pencere.lstKayitlar.ItemIndex := 0;
    Result := (Pencere.ShowModal = mrOk) and (Pencere.lstKayitlar.ItemIndex >= 0);
    if Result then
      Secim := Pencere.lstKayitlar.ItemIndex;
  finally
    Pencere.Free;
  end;
end;

{ Satira cift tiklamak "Ac" demektir. }
procedure TfrmKullananlar.lstKayitlarDblClick(Sender: TObject);
begin
  if lstKayitlar.ItemIndex >= 0 then
    ModalResult := mrOk;
end;

end.
