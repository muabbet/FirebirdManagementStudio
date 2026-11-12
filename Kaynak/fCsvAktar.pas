{ fCsvAktar.pas - "Disa aktar" (CSV) penceresi (Asama 3b).
  Form sadece arayuzu bilir; is uAktar.CsvAktar'dadir. Tek secenek: hedef dosya (ayrac, kodlama, baslik
  satiri sabittir). Uzun surerken ilerleme yazilir, Iptal ile durdurulur; iptalde yarim dosya silinmez. }
unit fCsvAktar;

interface

uses
  Winapi.Windows, System.SysUtils, System.Classes, System.IOUtils, System.Diagnostics, Vcl.Controls, Vcl.Forms,
  Vcl.StdCtrls, Vcl.ExtCtrls, Vcl.Dialogs,
  uDil, uOnay, uBaglanti, uAktar;

type
  TfrmCsvAktar = class(TForm)
    lblDosya: TLabel;
    edtDosya: TEdit;
    btnSec: TButton;
    lblDurum: TLabel;
    pnlAlt: TPanel;
    btnKapat: TButton;
    btnBaslat: TButton;
    dlgKaydet: TSaveDialog;
    procedure btnSecClick(Sender: TObject);
    procedure btnBaslatClick(Sender: TObject);
    procedure btnKapatClick(Sender: TObject);
    procedure FormCloseQuery(Sender: TObject; var CanClose: Boolean);
  private
    FBag: TAcikBaglanti;
    FSql: string;
    FSonuc: TStrings;
    FCalisiyor: Boolean;
    FIptalIstendi: Boolean;
    FSonGuncelleme: Cardinal;
    procedure YazilariYaz(const Ad: string; Filtreli: Boolean);
    procedure CalisiyorAyarla(Calisiyor: Boolean);
    procedure Ilerle(SatirSayisi: Int64; var Iptal: Boolean);
    procedure SonucuYaz(Tamam: Boolean; const Dosya: string; SatirSayisi: Int64; Sure: Int64; Uyarilar: TStrings);
  end;

{ Pencereyi gosterir. Ad: varsayilan dosya adinin basi (tablo adi ya da "sorgu"). Bitince ozet ve uyarilar
  Sonuc'a (ana pencerenin sonuc alani) eklenir. }
procedure CsvPenceresiniGoster(Bag: TAcikBaglanti; const Sql, Ad: string; Sonuc: TStrings; Filtreli: Boolean = False);

implementation

{$R *.dfm}

procedure CsvPenceresiniGoster(Bag: TAcikBaglanti; const Sql, Ad: string; Sonuc: TStrings; Filtreli: Boolean);
var
  Pencere: TfrmCsvAktar;
begin
  Pencere := TfrmCsvAktar.Create(Application);
  try
    Pencere.FBag := Bag;
    Pencere.FSql := Sql;
    Pencere.FSonuc := Sonuc;
    Pencere.YazilariYaz(Ad, Filtreli);
    Pencere.ShowModal;
  finally
    Pencere.Free;
  end;
end;

procedure TfrmCsvAktar.YazilariYaz(const Ad: string; Filtreli: Boolean);
begin
  Caption := T('AKTAR_BASLIK');
  { Tablo sekmesinde filtre varsa yalniz filtreye uyan satirlar aktarilir; pencere basliginda yazar. }
  if Filtreli then
    Caption := Caption + ' (' + T('LBL_FILTRELI') + ')';
  lblDosya.Caption := T('AKTAR_DOSYA');
  btnSec.Caption := T('AKTAR_SEC');
  btnBaslat.Caption := T('AKTAR_BASLAT');
  btnKapat.Caption := T('BTN_KAPAT');
  dlgKaydet.Filter := T('AKTAR_FILTRE');
  edtDosya.Text := TPath.Combine(TPath.GetDocumentsPath, VarsayilanCsvAdi(Ad));
  DugmeyiYaziyaUydur(btnSec);
  DugmeyiYaziyaUydur(btnBaslat);
  DugmeyiYaziyaUydur(btnKapat);
end;

procedure TfrmCsvAktar.CalisiyorAyarla(Calisiyor: Boolean);
begin
  FCalisiyor := Calisiyor;
  FIptalIstendi := False;
  edtDosya.Enabled := not Calisiyor;
  btnSec.Enabled := not Calisiyor;
  btnBaslat.Enabled := not Calisiyor;
  if Calisiyor then
    btnKapat.Caption := T('BTN_IPTAL')
  else
    btnKapat.Caption := T('BTN_KAPAT');
  DugmeyiYaziyaUydur(btnKapat);
end;

{ Aktarma sirasinda cagrilir: durum yazisini gunceller (kisa aralikla), pencerenin donmamasi icin
  mesajlari isler ve iptal istendiyse bildirir. }
procedure TfrmCsvAktar.Ilerle(SatirSayisi: Int64; var Iptal: Boolean);
begin
  if GetTickCount - FSonGuncelleme > 80 then
  begin
    FSonGuncelleme := GetTickCount;
    lblDurum.Caption := TF('AKTAR_ILERLEME', [Format('%.0n', [SatirSayisi + 0.0])]);
    Application.ProcessMessages;
  end;
  Iptal := FIptalIstendi;
end;

procedure TfrmCsvAktar.btnSecClick(Sender: TObject);
begin
  dlgKaydet.FileName := edtDosya.Text;
  if dlgKaydet.Execute then
    edtDosya.Text := dlgKaydet.FileName;
end;

procedure TfrmCsvAktar.btnKapatClick(Sender: TObject);
begin
  if FCalisiyor then
    FIptalIstendi := True
  else
    ModalResult := mrCancel;
end;

procedure TfrmCsvAktar.FormCloseQuery(Sender: TObject; var CanClose: Boolean);
begin
  if FCalisiyor then
  begin
    FIptalIstendi := True;
    CanClose := False;
  end;
end;

{ Ana pencerenin sonuc alanina yazilacak satirlar: ozet ve (varsa) uyarilar. }
procedure TfrmCsvAktar.SonucuYaz(Tamam: Boolean; const Dosya: string; SatirSayisi: Int64; Sure: Int64;
  Uyarilar: TStrings);
var
  Sayi, Saniye, Uyari: string;
begin
  Sayi := Format('%.0n', [SatirSayisi + 0.0]);
  Saniye := Format('%.1f', [Sure / 1000]);
  if Tamam then
    FSonuc.Add(TF('AKTAR_BITTI', [Dosya, Sayi, Saniye]))
  else
    FSonuc.Add(TF('AKTAR_IPTAL', [Sayi, Dosya]));
  for Uyari in Uyarilar do
    FSonuc.Add('  ' + Uyari);
end;

procedure TfrmCsvAktar.btnBaslatClick(Sender: TObject);
var
  Dosya: string;
  Kodlama: TEncoding;
  Yazici: TStreamWriter;
  Uyarilar: TStringList;
  Saat: TStopwatch;
  SatirSayisi: Int64;
  Tamam: Boolean;
begin
  Dosya := Trim(edtDosya.Text);
  if Dosya = '' then
  begin
    UyariGoster(T('ERR_AKTAR_DOSYA_BOS'));
    Exit;
  end;
  if FileExists(Dosya) and not OnayIste(TF('ONAY_UZERINE_YAZ', [Dosya, DateTimeToStr(TFile.GetLastWriteTime(Dosya))])) then
    Exit;
  Uyarilar := TStringList.Create;
  { UTF-8 BOM'lu: Excel cift tiklayinca Turkce karakterleri dogru okur. }
  Kodlama := TUTF8Encoding.Create(True);
  try
    CalisiyorAyarla(True);
    try
      Saat := TStopwatch.StartNew;
      try
        Yazici := TStreamWriter.Create(Dosya, False, Kodlama);
        try
          Tamam := CsvAktar(FBag, FSql, Yazici, WindowsCsvSecenekleri, Uyarilar, Ilerle, SatirSayisi);
        finally
          Yazici.Free;
        end;
      except
        on E: Exception do
        begin
          { Pencere acik kalir: dosya baska programda aciksa kullanici kapatip tekrar Baslat'a basabilir. }
          lblDurum.Caption := '';
          UyariGoster(T('ERR_AKTAR_YAPILAMADI') + ' ' + AktarmaHatasiniCevir(E) + sLineBreak + sLineBreak +
            T('AYRINTI') + ': ' + E.Message);
          Exit;
        end;
      end;
    finally
      CalisiyorAyarla(False);
    end;
    SonucuYaz(Tamam, Dosya, SatirSayisi, Saat.ElapsedMilliseconds, Uyarilar);
    ModalResult := mrOk;
  finally
    Kodlama.Free;
    Uyarilar.Free;
  end;
end;

end.
