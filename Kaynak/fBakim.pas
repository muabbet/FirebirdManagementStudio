{ fBakim.pas - "Veritabani bakimi" penceresi (Asama 7d).
  Form sadece arayuzu bilir; rapor ve bakim uBakim'dadir. Akis: "Raporu hazirla" (veritabanina yazmaz) -> rapor sekmelerde
  gorunur -> "Bakimi baslat" net onay ister (yapilacaklar listesi) -> bakim -> bakimdan sonra rapor yeniden hazirlanir. }
unit fBakim;

interface

uses
  System.SysUtils, System.Classes, Winapi.Windows, Vcl.Controls, Vcl.Forms, Vcl.StdCtrls, Vcl.ExtCtrls, Vcl.ComCtrls,
  uDil, uOnay, uBaglanti, uKullanici, uBakim;

type
  TfrmBakim = class(TForm)
    pnlUst: TPanel;
    chkTarama: TCheckBox;
    btnRapor: TButton;
    pgSekmeler: TPageControl;
    tsOzet: TTabSheet;
    tsTablolar: TTabSheet;
    tsIndeksler: TTabSheet;
    tsIsler: TTabSheet;
    memOzet: TMemo;
    lvTablolar: TListView;
    lvIndeksler: TListView;
    memIsler: TMemo;
    pnlAlt: TPanel;
    lblDurum: TLabel;
    btnBaslat: TButton;
    btnIptal: TButton;
    btnKapat: TButton;
    procedure btnRaporClick(Sender: TObject);
    procedure btnBaslatClick(Sender: TObject);
    procedure btnIptalClick(Sender: TObject);
    procedure FormCloseQuery(Sender: TObject; var CanClose: Boolean);
  private
    FBag: TAcikBaglanti;
    FSqlYaz: TSqlGoster;
    FSonuc: TStrings;
    FRapor: TBakimRaporu;
    FRaporVar: Boolean;
    FCalisiyor: Boolean;
    FIptal: Boolean;
    procedure YazilariYaz;
    procedure Calisiyor(Acik: Boolean);
    procedure Izle(const Satir: string; var Iptal: Boolean);
    procedure RaporuGoster;
    procedure Hazirla;
  end;

{ Pencereyi gosterir. SqlYaz: bakimda calisan komutlarin SQL karsiligi; Sonuc: ana pencerenin sonuc alani. }
procedure BakimPenceresiniGoster(Bag: TAcikBaglanti; SqlYaz: TSqlGoster; Sonuc: TStrings);

implementation

{$R *.dfm}

procedure BakimPenceresiniGoster(Bag: TAcikBaglanti; SqlYaz: TSqlGoster; Sonuc: TStrings);
var
  Pencere: TfrmBakim;
begin
  Pencere := TfrmBakim.Create(Application);
  try
    Pencere.FBag := Bag;
    Pencere.FSqlYaz := SqlYaz;
    Pencere.FSonuc := Sonuc;
    Pencere.YazilariYaz;
    Pencere.ShowModal;
  finally
    Pencere.Free;
  end;
end;

procedure TfrmBakim.YazilariYaz;
begin
  Caption := T('BAKIM_BASLIK') + ' - ' + FBag.Tanim.Ad;
  chkTarama.Caption := T('BAKIM_TARAMA');
  btnRapor.Caption := T('BAKIM_RAPOR_HAZIRLA');
  btnBaslat.Caption := T('BAKIM_BASLAT');
  btnIptal.Caption := T('BTN_IPTAL');
  btnKapat.Caption := T('BTN_KAPAT');
  tsOzet.Caption := T('BAKIM_SEKME_OZET');
  tsTablolar.Caption := T('BAKIM_SEKME_TABLO');
  tsIndeksler.Caption := T('BAKIM_SEKME_INDEKS');
  tsIsler.Caption := T('BAKIM_SEKME_IS');
  DugmeyiYaziyaUydur(btnRapor);
  DugmeyiYaziyaUydur(btnBaslat);
  DugmeyiYaziyaUydur(btnIptal);
  DugmeyiYaziyaUydur(btnKapat);
  lvTablolar.Columns[0].Caption := T('BAKIM_KOL_TABLO');
  lvTablolar.Columns[1].Caption := T('BAKIM_KOL_SATIR');
  lvTablolar.Columns[2].Caption := T('BAKIM_KOL_IZ');
  lvTablolar.Columns[3].Caption := T('BAKIM_KOL_ESKI');
  lvTablolar.Columns[4].Caption := T('BAKIM_KOL_DOLULUK');
  lvTablolar.Columns[5].Caption := T('BAKIM_KOL_DURUM');
  lvIndeksler.Columns[0].Caption := T('BAKIM_KOL_INDEKS');
  lvIndeksler.Columns[1].Caption := T('BAKIM_KOL_TABLO');
  lvIndeksler.Columns[2].Caption := T('BAKIM_KOL_TUR');
  lvIndeksler.Columns[3].Caption := T('BAKIM_KOL_DERINLIK');
  lvIndeksler.Columns[4].Caption := T('BAKIM_KOL_YAPRAK');
  lvIndeksler.Columns[5].Caption := T('BAKIM_KOL_DUGUM');
  lvIndeksler.Columns[6].Caption := T('BAKIM_KOL_SEYREK');
  lvIndeksler.Columns[7].Caption := T('BAKIM_KOL_KARAR');
  btnBaslat.Enabled := False;
  btnIptal.Enabled := False;
  memOzet.Text := T('BAKIM_ONCE_RAPOR');
end;

{ Calisirken: raporla/baslat kapali, Iptal acik, pencere kapanmaz. }
procedure TfrmBakim.Calisiyor(Acik: Boolean);
begin
  FCalisiyor := Acik;
  FIptal := False;
  btnRapor.Enabled := not Acik;
  btnBaslat.Enabled := (not Acik) and FRaporVar and FRapor.Basarili and (Length(FRapor.Isler) > 0);
  btnKapat.Enabled := not Acik;
  btnIptal.Enabled := Acik;
  chkTarama.Enabled := not Acik;
  if not Acik then
    lblDurum.Caption := '';
end;

{ Araclarin ciktisi: son satir durum yazisinda gorunur; pencere donmasin diye mesajlar islenir. }
procedure TfrmBakim.Izle(const Satir: string; var Iptal: Boolean);
begin
  { Eski sunucuda gstat'in bilinen "Wrong ODS" satiri hata degildir (rapor yedek kipte surer); ekranda gosterilmez. }
  if (Trim(Satir) <> '') and (Pos('Wrong ODS', Satir) = 0) then
    lblDurum.Caption := TF('BAKIM_CALISIYOR', [Trim(Satir)]);
  Application.ProcessMessages;
  Iptal := FIptal;
end;

procedure TfrmBakim.btnIptalClick(Sender: TObject);
begin
  FIptal := True;
end;

procedure TfrmBakim.FormCloseQuery(Sender: TObject; var CanClose: Boolean);
begin
  CanClose := not FCalisiyor;
end;

function BoyutYazisi(Bayt: Int64): string;
begin
  if Bayt <= 0 then
    Result := '?'
  else if Bayt >= 1024 * 1024 * 1024 then
    Result := FormatFloat('0.0', Bayt / (1024 * 1024 * 1024)) + ' GB'
  else
    Result := FormatFloat('0.0', Bayt / (1024 * 1024)) + ' MB';
end;

function SayiYazisi(Sayi: Int64): string;
begin
  if Sayi < 0 then
    Result := '?'
  else
    Result := FormatFloat('#,##0', Sayi);
end;

{ Raporu sekmelere yazar. }
procedure TfrmBakim.RaporuGoster;
var
  Tablo: TBakimTablosu;
  Indeks: TBakimIndeksi;
  Is_: TBakimIsi;
  Not_: string;
  Satir: TListItem;
begin
  memOzet.Clear;
  lvTablolar.Items.Clear;
  lvIndeksler.Items.Clear;
  memIsler.Clear;
  if not FRapor.Basarili then
  begin
    memOzet.Lines.Add(FRapor.Cumle);
    if FRapor.Ayrinti <> '' then
    begin
      memOzet.Lines.Add('');
      memOzet.Lines.Add(T('AYRINTI') + ':');
      memOzet.Lines.Add(FRapor.Ayrinti);
    end;
    Exit;
  end;
  memOzet.Lines.Add(TF('BAKIM_D_YOL', [FRapor.Durum.Yol]));
  memOzet.Lines.Add(TF('BAKIM_D_SURUM', [FRapor.Durum.Surum, FRapor.Durum.Ods, FRapor.Durum.SayfaBoyutu, BoyutYazisi(FRapor.Durum.Boyut)]));
  memOzet.Lines.Add(TF('BAKIM_D_ISLEM', [FRapor.Durum.EnEskiIslem, FRapor.Durum.EnEskiAktif, FRapor.Durum.SiradakiIslem, FRapor.Durum.SweepAraligi]));
  if FRapor.Durum.BagliKisi >= 0 then
    memOzet.Lines.Add(TF('BAKIM_D_BAGLI', [FRapor.Durum.BagliKisi]))
  else
    memOzet.Lines.Add(T('BAKIM_D_BAGLI_YOK'));
  memOzet.Lines.Add('');
  memOzet.Lines.Add(BakimOzetMetni(FRapor));
  if Length(FRapor.Notlar) > 0 then
  begin
    memOzet.Lines.Add('');
    memOzet.Lines.Add(T('BAKIM_ONAY_NOTLAR'));
    for Not_ in FRapor.Notlar do
      memOzet.Lines.Add('- ' + Not_);
  end;
  if (FRapor.Tarama = tdBozuk) or (FRapor.Tarama = tdYapilamadi) then
  begin
    memOzet.Lines.Add('');
    memOzet.Lines.Add(FRapor.TaramaCikti);
  end;
  for Tablo in FRapor.Tablolar do
  begin
    Satir := lvTablolar.Items.Add;
    Satir.Caption := Tablo.Ad;
    Satir.SubItems.Add(SayiYazisi(Tablo.CanliSatir));
    Satir.SubItems.Add(SayiYazisi(Tablo.SilinmisIzi));
    Satir.SubItems.Add(SayiYazisi(Tablo.EskiSurum));
    Satir.SubItems.Add(IntToStr(Tablo.Doluluk) + '%');
    if Tablo.Temizlenecek then
      Satir.SubItems.Add(T('BAKIM_DURUM_TEMIZ'))
    else if Tablo.Seyrek then
      Satir.SubItems.Add(T('BAKIM_DURUM_SEYREK'))
    else
      Satir.SubItems.Add(T('BAKIM_DURUM_TAMAM'));
  end;
  for Indeks in FRapor.Indeksler do
  begin
    Satir := lvIndeksler.Items.Add;
    Satir.Caption := Indeks.Ad;
    Satir.SubItems.Add(Indeks.Tablo);
    Satir.SubItems.Add(Indeks.Tur);
    Satir.SubItems.Add(IntToStr(Indeks.Derinlik));
    Satir.SubItems.Add(IntToStr(Indeks.Yaprak));
    Satir.SubItems.Add(SayiYazisi(Indeks.Dugum));
    Satir.SubItems.Add(IntToStr(Indeks.SeyrekYuzde) + '%');
    case Indeks.Karar of
      ikYenidenKur: Satir.SubItems.Add(T('BAKIM_KARAR_YENIDEN'));
      ikYedekGeriYukle: Satir.SubItems.Add(T('BAKIM_KARAR_YEDEK'));
    else
      Satir.SubItems.Add(T('BAKIM_KARAR_TAMAM'));
    end;
  end;
  for Is_ in FRapor.Isler do
    memIsler.Lines.Add('- ' + Is_.Aciklama);
  if Length(FRapor.Isler) = 0 then
    memIsler.Lines.Add(T('BAKIM_OZET_GEREKSIZ'));
end;

{ Raporu hazirlar (veritabanina yazmaz); bozuk kayit taramasi kutusu isaretliyse onu da yapar. }
procedure TfrmBakim.Hazirla;
begin
  Calisiyor(True);
  try
    FRapor := BakimRaporuHazirla(FBag, chkTarama.Checked, Izle);
    FRaporVar := True;
  finally
    Calisiyor(False);
  end;
  RaporuGoster;
end;

procedure TfrmBakim.btnRaporClick(Sender: TObject);
begin
  Hazirla;
  if FRapor.Iptal then
    FSonuc.Add(T('MSG_BAKIM_IPTAL'))
  else if FRapor.Basarili then
  begin
    FSonuc.Add(TF('MSG_BAKIM_RAPOR', [FBag.Tanim.Ad]));
    lblDurum.Caption := T('BAKIM_RAPOR_HAZIR');
  end
  else
  begin
    FSonuc.Add(FRapor.Cumle);
    if FRapor.Ayrinti <> '' then
      FSonuc.Add(T('AYRINTI') + ': ' + FRapor.Ayrinti);
    UyariGoster(FRapor.Cumle);
  end;
end;

function EskiToplam(const Rapor: TBakimRaporu): Int64;
var
  Tablo: TBakimTablosu;
begin
  Result := 0;
  for Tablo in Rapor.Tablolar do
    Inc(Result, Tablo.EskiSurum);
end;

function IzToplam(const Rapor: TBakimRaporu): Int64;
var
  Tablo: TBakimTablosu;
begin
  Result := 0;
  for Tablo in Rapor.Tablolar do
    if Tablo.SilinmisIzi > 0 then
      Inc(Result, Tablo.SilinmisIzi);
end;

function SayfaToplam(const Rapor: TBakimRaporu): Int64;
var
  Tablo: TBakimTablosu;
begin
  Result := 0;
  for Tablo in Rapor.Tablolar do
    Inc(Result, Tablo.VeriSayfasi);
end;

{ Bakimi baslatir: once net onay (yapilacaklar + uyarilar), sonra isler, sonra rapor yeniden hazirlanir. }
procedure TfrmBakim.btnBaslatClick(Sender: TObject);
var
  Once: TBakimRaporu;
  Sonuc: TBakimSonucu;
  Satir: string;
begin
  if (not FRaporVar) or (not FRapor.Basarili) then
  begin
    UyariGoster(T('BAKIM_ONCE_RAPOR'));
    Exit;
  end;
  if not OnayIste(BakimOnayMetni(FRapor)) then
    Exit;
  Once := FRapor;
  Calisiyor(True);
  try
    Sonuc := BakimiYap(FBag, FRapor, Izle);
  finally
    Calisiyor(False);
  end;
  if Sonuc.Iptal then
    FSonuc.Add(T('MSG_BAKIM_IPTAL'))
  else
    FSonuc.Add(TF('MSG_BAKIM_TAMAM', [Length(Sonuc.Satirlar), Sonuc.Hatali]));
  for Satir in Sonuc.Satirlar do
    FSonuc.Add('  ' + Satir);
  if (Length(Sonuc.Komutlar) > 0) and Assigned(FSqlYaz) then
    FSqlYaz(Sonuc.Komutlar);
  { Bakimdan sonra raporu yeniden hazirla (tarama yeniden yapilmaz) ve farki goster }
  Calisiyor(True);
  try
    FRapor := BakimRaporuHazirla(FBag, False, Izle);
  finally
    Calisiyor(False);
  end;
  RaporuGoster;
  if FRapor.Basarili then
  begin
    memOzet.Lines.Insert(0, '');
    memOzet.Lines.Insert(0, TF('BAKIM_FARK', [EskiToplam(Once), EskiToplam(FRapor), IzToplam(Once), IzToplam(FRapor),
      SayfaToplam(Once), SayfaToplam(FRapor)]));
    for Satir in Sonuc.Satirlar do
      memOzet.Lines.Insert(2, '  ' + Satir);
    FSonuc.Add(memOzet.Lines[0]);
  end;
end;

end.
