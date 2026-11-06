{ fAktifBaglanti.pas - "Aktif baglantilar" penceresi (Asama 7c).
  Form sadece arayuzu bilir; liste ve baglanti koparma uAktifBaglanti'dadir. Liste "Yenile" ile (ve koparmadan sonra) sunucudan
  yeniden okunur. Secili baglanti, net onayla (kullanici, program, adres, calisacak komut) koparilabilir. }
unit fAktifBaglanti;

interface

uses
  System.SysUtils, System.Classes, Data.DB, Vcl.Controls, Vcl.Forms, Vcl.StdCtrls, Vcl.ExtCtrls, Vcl.Grids, Vcl.DBGrids,
  FireDAC.Comp.Client,
  uDil, uOnay, uBaglanti, uKullanici, uProsedur, uSonucGrid, uAktifBaglanti;

type
  TfrmAktifBaglanti = class(TForm)
    pnlUst: TPanel;
    lblBilgi: TLabel;
    lblYetki: TLabel;
    gridBaglanti: TDBGrid;
    dsBaglanti: TDataSource;
    pnlAlt: TPanel;
    btnYenile: TButton;
    btnKopar: TButton;
    btnKapat: TButton;
    procedure btnYenileClick(Sender: TObject);
    procedure btnKoparClick(Sender: TObject);
  private
    FBag: TAcikBaglanti;
    FSqlYaz: TSqlGoster;
    FSonuc: TStrings;
    FSorgu: TFDQuery;
    FGrid: TSonucGrid;
    procedure YazilariYaz;
    procedure Yenile;
    procedure DurumYazisi(Alan: TField; var Metin: string; GosterimMi: Boolean);
    procedure BenYazisi(Alan: TField; var Metin: string; GosterimMi: Boolean);
    procedure KolonYazisi(const AlanAdi, Anahtar: string);
  end;

{ Pencereyi gosterir. SqlYaz: calisan DELETE'in SQL karsiligi; Sonuc: ana pencerenin sonuc alani (ozet buraya yazilir). }
procedure AktifBaglantiPenceresiniGoster(Bag: TAcikBaglanti; SqlYaz: TSqlGoster; Sonuc: TStrings);

implementation

{$R *.dfm}

procedure AktifBaglantiPenceresiniGoster(Bag: TAcikBaglanti; SqlYaz: TSqlGoster; Sonuc: TStrings);
var
  Pencere: TfrmAktifBaglanti;
begin
  Pencere := TfrmAktifBaglanti.Create(Application);
  try
    Pencere.FBag := Bag;
    Pencere.FSqlYaz := SqlYaz;
    Pencere.FSonuc := Sonuc;
    Pencere.FGrid := TSonucGrid.Create(Pencere.gridBaglanti);
    Pencere.YazilariYaz;
    Pencere.Yenile;
    Pencere.ShowModal;
  finally
    Pencere.Free;
  end;
end;

procedure TfrmAktifBaglanti.YazilariYaz;
begin
  Caption := T('AKTIF_BASLIK') + ' - ' + FBag.Tanim.Ad;
  btnYenile.Caption := T('AKTIF_YENILE');
  btnKopar.Caption := T('AKTIF_KOPAR');
  btnKapat.Caption := T('BTN_KAPAT');
  DugmeyiYaziyaUydur(btnYenile);
  DugmeyiYaziyaUydur(btnKopar);
  DugmeyiYaziyaUydur(btnKapat);
end;

{ 1 = sorgu calisiyor, 0 = bosta. }
procedure TfrmAktifBaglanti.DurumYazisi(Alan: TField; var Metin: string; GosterimMi: Boolean);
begin
  if Alan.AsInteger = 1 then
    Metin := T('AKTIF_DURUM_CALISIYOR')
  else
    Metin := T('AKTIF_DURUM_BOSTA');
end;

{ Bu uygulamanin kendi baglantisi "Siz" yazar, digerleri bos. }
procedure TfrmAktifBaglanti.BenYazisi(Alan: TField; var Metin: string; GosterimMi: Boolean);
begin
  if Alan.AsInteger = 1 then
    Metin := T('AKTIF_BEN_EVET')
  else
    Metin := '';
end;

procedure TfrmAktifBaglanti.KolonYazisi(const AlanAdi, Anahtar: string);
begin
  FSorgu.FieldByName(AlanAdi).DisplayLabel := T(Anahtar);
end;

{ Listeyi sunucudan bastan okur. Okunamazsa (2.1'den eski surum vb.) anlasilir cumle yazilir. }
procedure TfrmAktifBaglanti.Yenile;
begin
  dsBaglanti.DataSet := nil;
  FreeAndNil(FSorgu);
  try
    FSorgu := AktifBaglantiSorgusu(FBag, Self);
  except
    on E: Exception do
    begin
      lblBilgi.Caption := T('ERR_AKTIF_LISTE');
      lblYetki.Caption := HataMetniniCevir(E);
      Exit;
    end;
  end;
  KolonYazisi('ID', 'AKTIF_KOL_ID');
  KolonYazisi('KULLANICI', 'AKTIF_KOL_KULLANICI');
  KolonYazisi('PROGRAM', 'AKTIF_KOL_PROGRAM');
  KolonYazisi('ADRES', 'AKTIF_KOL_ADRES');
  KolonYazisi('BAGLANMA', 'AKTIF_KOL_BAGLANMA');
  KolonYazisi('CALISIYOR', 'AKTIF_KOL_DURUM');
  KolonYazisi('ISLEM_SAYISI', 'AKTIF_KOL_ISLEM');
  KolonYazisi('ESKI_ISLEM', 'AKTIF_KOL_ESKI');
  KolonYazisi('SORGU', 'AKTIF_KOL_SORGU');
  KolonYazisi('BEN', 'AKTIF_KOL_BEN');
  FSorgu.FieldByName('CALISIYOR').OnGetText := DurumYazisi;
  FSorgu.FieldByName('BEN').OnGetText := BenYazisi;
  dsBaglanti.DataSet := FSorgu;
  FGrid.YeniSonuc;
  lblBilgi.Caption := TF('AKTIF_BILGI', [FSorgu.RecordCount]);
  { Yalniz kendi baglantisi gorunuyorsa neden: SYSDBA / veritabani sahibi olmayan kullanici digerlerini goremez. }
  if FSorgu.RecordCount <= 1 then
    lblYetki.Caption := T('AKTIF_BILGI_YETKI')
  else
    lblYetki.Caption := '';
end;

procedure TfrmAktifBaglanti.btnYenileClick(Sender: TObject);
begin
  Yenile;
end;

{ Secili baglantiyi koparir: net onay (kim, hangi program, hangi adres, calisacak komut), sonra komut; sonuc mesaj alaninda. }
procedure TfrmAktifBaglanti.btnKoparClick(Sender: TObject);
var
  Numara: Int64;
  Kullanici, Programi, Adres: string;
  Sonuc: TProsedurSonucu;
begin
  if (FSorgu = nil) or FSorgu.IsEmpty then
  begin
    UyariGoster(T('ERR_AKTIF_SECIM'));
    Exit;
  end;
  if FSorgu.FieldByName('BEN').AsInteger = 1 then
  begin
    UyariGoster(T('ERR_AKTIF_KENDI'));
    Exit;
  end;
  Numara := FSorgu.FieldByName('ID').AsLargeInt;
  Kullanici := FSorgu.FieldByName('KULLANICI').AsString;
  Programi := FSorgu.FieldByName('PROGRAM').AsString;
  Adres := FSorgu.FieldByName('ADRES').AsString;
  if not OnayIste(TF('AKTIF_ONAY_KOPAR', [Numara, Kullanici, Programi, Adres, KoparmaKomutu(Numara) + ';'])) then
    Exit;
  Sonuc := BaglantiKopar(FBag, Numara);
  if Sonuc.Basarili then
    FSonuc.Add(TF('MSG_AKTIF_KOPARILDI', [Numara, Kullanici, Programi]))
  else
  begin
    FSonuc.Add(TF('ERR_AKTIF_KOPARILAMADI', [Numara]) + ' ' + Sonuc.Cumle);
    if Sonuc.Ayrinti <> '' then
      FSonuc.Add(T('AYRINTI') + ': ' + Sonuc.Ayrinti);
    UyariGoster(TF('ERR_AKTIF_KOPARILAMADI', [Numara]) + sLineBreak + sLineBreak + Sonuc.Cumle);
  end;
  if (Length(Sonuc.Komutlar) > 0) and Assigned(FSqlYaz) then
    FSqlYaz(Sonuc.Komutlar);
  Yenile;
end;

end.
