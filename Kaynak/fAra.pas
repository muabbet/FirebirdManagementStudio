{ fAra.pas - Veritabaninda arama penceresi: yaz, Ara'ya bas (ya da Enter), listeden sec, Ac'a bas (ya da cift tikla).
  Sadece arayuz: arama uAra'da, secilen nesneyi sekmede acmak cagiran tarafin (ana pencere) isidir. }
unit fAra;

interface

uses
  System.SysUtils, System.Classes, Vcl.Controls, Vcl.Forms, Vcl.StdCtrls, Vcl.ExtCtrls, Vcl.ComCtrls,
  uDil, uOnay, uBaglanti, uDDL, uAra;

type
  TfrmAra = class(TForm)
    pnlUst: TPanel;
    lblYazi: TLabel;
    edtYazi: TEdit;
    btnAra: TButton;
    chkKaynak: TCheckBox;
    lvSonuc: TListView;
    pnlAlt: TPanel;
    lblSayi: TLabel;
    btnAc: TButton;
    btnKapat: TButton;
    procedure btnAraClick(Sender: TObject);
    procedure btnAcClick(Sender: TObject);
    procedure lvSonucDblClick(Sender: TObject);
  private
    FBag: TAcikBaglanti;
    FSonuclar: TArray<TAramaSonucu>;
    procedure Ara;
    function TurYazisi(Tur: TNesneTuru): string;
    function YerYazisi(Yer: TAramaYeri): string;
  end;

{ Secili sonuca Ac'a basilirsa (ya da cift tiklanirsa) True doner ve Secim dolar. }
function AraPenceresiniGoster(Bag: TAcikBaglanti; out Secim: TAramaSonucu): Boolean;

implementation

{$R *.dfm}

var
  { Pencere kapanip acilinca son yazilan arama kalir. }
  SonYazi: string;
  SonKaynak: Boolean;

function AraPenceresiniGoster(Bag: TAcikBaglanti; out Secim: TAramaSonucu): Boolean;
var
  Pencere: TfrmAra;
begin
  Secim := Default(TAramaSonucu);
  Pencere := TfrmAra.Create(Application);
  try
    Pencere.FBag := Bag;
    Pencere.Caption := TF('ARA_BASLIK', [Bag.Tanim.Ad]);
    Pencere.lblYazi.Caption := T('ARA_YAZI');
    Pencere.chkKaynak.Caption := T('ARA_KAYNAK');
    Pencere.btnAra.Caption := T('ARA_DUGME');
    Pencere.btnAc.Caption := T('ILISKI_AC');
    Pencere.btnKapat.Caption := T('BTN_KAPAT');
    DugmeyiYaziyaUydur(Pencere.btnAra);
    DugmeyiYaziyaUydur(Pencere.btnAc);
    DugmeyiYaziyaUydur(Pencere.btnKapat);
    Pencere.lvSonuc.Columns[0].Caption := T('ARA_SUTUN_TUR');
    Pencere.lvSonuc.Columns[1].Caption := T('ARA_SUTUN_AD');
    Pencere.lvSonuc.Columns[2].Caption := T('ARA_SUTUN_YER');
    Pencere.lvSonuc.Columns[3].Caption := T('ARA_SUTUN_AYRINTI');
    Pencere.lblSayi.Caption := T('ARA_IPUCU');
    Pencere.edtYazi.Text := SonYazi;
    Pencere.chkKaynak.Checked := SonKaynak;
    Pencere.ActiveControl := Pencere.edtYazi;
    Result := (Pencere.ShowModal = mrOk) and (Pencere.lvSonuc.ItemIndex >= 0);
    SonYazi := Pencere.edtYazi.Text;
    SonKaynak := Pencere.chkKaynak.Checked;
    if Result then
      Secim := Pencere.FSonuclar[Pencere.lvSonuc.ItemIndex];
  finally
    Pencere.Free;
  end;
end;

function TfrmAra.TurYazisi(Tur: TNesneTuru): string;
begin
  case Tur of
    ntTablo: Result := T('TUR_TABLO');
    ntView: Result := T('TUR_VIEW');
    ntProsedur: Result := T('TUR_PROSEDUR');
    ntTetikleyici: Result := T('TUR_TETIKLEYICI');
    ntIstisna: Result := T('TUR_ISTISNA');
  else
    Result := '';
  end;
end;

function TfrmAra.YerYazisi(Yer: TAramaYeri): string;
begin
  case Yer of
    ayAd: Result := T('ARA_YER_AD');
    ayKolon: Result := T('ARA_YER_KOLON');
  else
    Result := T('ARA_YER_KAYNAK');
  end;
end;

{ Aramayi calistirir ve listeyi doldurur; hata olursa anlasilir cumleyle gosterilir. }
procedure TfrmAra.Ara;
var
  Kesildi: Boolean;
  Sonuc: TAramaSonucu;
  Satir: TListItem;
begin
  if Length(Trim(edtYazi.Text)) < ARAMA_EN_KISA then
  begin
    UyariGoster(TF('ARA_KISA', [ARAMA_EN_KISA]));
    Exit;
  end;
  Screen.Cursor := crHourGlass;
  try
    try
      FSonuclar := MetadataAra(FBag, edtYazi.Text, chkKaynak.Checked, Kesildi);
    except
      on E: Exception do
      begin
        Screen.Cursor := crDefault;
        UyariGoster(HataMetniniCevir(E));
        Exit;
      end;
    end;
  finally
    Screen.Cursor := crDefault;
  end;
  lvSonuc.Items.BeginUpdate;
  try
    lvSonuc.Items.Clear;
    for Sonuc in FSonuclar do
    begin
      Satir := lvSonuc.Items.Add;
      Satir.Caption := TurYazisi(Sonuc.Tur);
      Satir.SubItems.Add(Sonuc.Ad);
      Satir.SubItems.Add(YerYazisi(Sonuc.Yer));
      Satir.SubItems.Add(Sonuc.Ayrinti);
    end;
  finally
    lvSonuc.Items.EndUpdate;
  end;
  if Length(FSonuclar) = 0 then
    lblSayi.Caption := T('ARA_YOK')
  else if Kesildi then
    lblSayi.Caption := TF('ARA_KESILDI', [ARAMA_SINIRI])
  else
    lblSayi.Caption := TF('ARA_SAYI', [Length(FSonuclar)]);
  if lvSonuc.Items.Count > 0 then
    lvSonuc.ItemIndex := 0;
end;

procedure TfrmAra.btnAraClick(Sender: TObject);
begin
  Ara;
end;

procedure TfrmAra.btnAcClick(Sender: TObject);
begin
  if lvSonuc.ItemIndex >= 0 then
    ModalResult := mrOk;
end;

{ Satira cift tiklamak "Ac" demektir. }
procedure TfrmAra.lvSonucDblClick(Sender: TObject);
begin
  if lvSonuc.ItemIndex >= 0 then
    ModalResult := mrOk;
end;

end.
