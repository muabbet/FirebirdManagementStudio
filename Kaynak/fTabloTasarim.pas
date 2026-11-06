{ fTabloTasarim.pas - "Yeni tablo (tasarimla)" penceresi (Asama 7g).
  Form sadece arayuzu bilir; kontrol, CREATE TABLE metni ve olusturma uTabloTasarim'dadir. Kolonlar gridde duzenlenir
  (tip, evet/hayir sutunlari hucredeki acilir listeyle), altta olusacak SQL kolonlar degistikce guncellenir. }
unit fTabloTasarim;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Classes, System.Types, Vcl.Controls, Vcl.Forms, Vcl.StdCtrls,
  Vcl.ExtCtrls, Vcl.Grids, Vcl.Dialogs, Vcl.Menus, Vcl.Graphics,
  uDil, uOnay, uBaglanti, uKullanici, uMetadata, uKolon, uProsedur, uTabloTasarim;

type
  TfrmTabloTasarim = class(TForm)
    lblTablo: TLabel;
    edtTablo: TEdit;
    lblIpucu: TLabel;
    gridKolon: TStringGrid;
    pmListe: TPopupMenu;
    pnlDugme: TPanel;
    btnEkle: TButton;
    btnCikar: TButton;
    btnYukari: TButton;
    btnAsagi: TButton;
    lblSql: TLabel;
    memSql: TMemo;
    lblDurum: TLabel;
    pnlAlt: TPanel;
    btnKapat: TButton;
    btnOlustur: TButton;
    procedure TabloAdiDegisti(Sender: TObject);
    procedure gridKolonDrawCell(Sender: TObject; ACol, ARow: Integer; Rect: TRect; State: TGridDrawState);
    procedure gridKolonKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure gridKolonMouseUp(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
    procedure gridKolonSelectCell(Sender: TObject; ACol, ARow: Integer; var CanSelect: Boolean);
    procedure gridKolonSetEditText(Sender: TObject; ACol, ARow: Integer; const Value: string);
    procedure ListeOgesiSecildi(Sender: TObject);
    procedure btnEkleClick(Sender: TObject);
    procedure btnCikarClick(Sender: TObject);
    procedure btnYukariClick(Sender: TObject);
    procedure btnAsagiClick(Sender: TObject);
    procedure btnOlusturClick(Sender: TObject);
  private
    FBag: TAcikBaglanti;
    FSqlYaz: TSqlGoster;
    FSonuc: TStrings;
    FTipler: TArray<TVeriTipi>;
    FKimlik: Boolean;
    FOlustu: Boolean;
    FYeniAd: string;
    { Acik listenin (menunun) hangi hucre icin acildigi. }
    FListeSutun: Integer;
    FListeSatir: Integer;
    procedure YazilariYaz;
    procedure SatiriYaz(Satir: Integer; const Ad, Tip, Boyut: string; Bos, Birincil, Oto: Boolean);
    procedure SatirEkle(const Ad, Tip, Boyut: string; Bos, Birincil, Oto: Boolean);
    procedure SatiriTemizle(Satir: Integer);
    procedure SatirlariTasi(Kaynak, Hedef: Integer);
    function KolonlariOku: TArray<TTasarimKolon>;
    function EvetHayir(Deger: Boolean): string;
    function EvetMi(const Metin: string): Boolean;
    function KutuSutunuMu(Sutun: Integer): Boolean;
    procedure ListeyiAc(Sutun, Satir: Integer);
    procedure Guncelle;
  public
    { Hucreye liste degeri yazar (tip secilirse boyut varsayilana doner, birincil anahtar bos olamaz olur). Liste menusu ve testler kullanir. }
    procedure DegerSec(Sutun, Satir: Integer; const Deger: string);
  end;

{ Pencereyi gosterir. SqlYaz: calisan CREATE TABLE'in SQL karsiligi; Sonuc: ana pencerenin sonuc alani.
  Tablo olusturulduysa True doner ve YeniTablo olusan adidir (cagiran agaci yeniler). }
function TabloTasarimPenceresiniGoster(Bag: TAcikBaglanti; SqlYaz: TSqlGoster; Sonuc: TStrings;
  out YeniTablo: string): Boolean;

implementation

{$R *.dfm}

const
  SUTUN_AD = 0;
  SUTUN_TIP = 1;
  SUTUN_BOYUT = 2;
  SUTUN_BOS = 3;
  SUTUN_BIRINCIL = 4;
  SUTUN_VARSAYILAN = 5;
  SUTUN_OTO = 6;

function TabloTasarimPenceresiniGoster(Bag: TAcikBaglanti; SqlYaz: TSqlGoster; Sonuc: TStrings;
  out YeniTablo: string): Boolean;
var
  Pencere: TfrmTabloTasarim;
begin
  Result := False;
  YeniTablo := '';
  Pencere := TfrmTabloTasarim.Create(Application);
  try
    Pencere.FBag := Bag;
    Pencere.FSqlYaz := SqlYaz;
    Pencere.FSonuc := Sonuc;
    try
      Pencere.FTipler := KolonTipleri(Bag);
    except
      on E: Exception do
      begin
        UyariGoster(HataMetniniCevir(E) + sLineBreak + sLineBreak + T('AYRINTI') + ': ' + E.Message);
        Exit;
      end;
    end;
    Pencere.FKimlik := KimlikDestegi(Bag);
    Pencere.YazilariYaz;
    Pencere.ShowModal;
    Result := Pencere.FOlustu;
    YeniTablo := Pencere.FYeniAd;
  finally
    Pencere.Free;
  end;
end;

function TfrmTabloTasarim.EvetHayir(Deger: Boolean): string;
begin
  if Deger then
    Result := T('TAS_EVET')
  else
    Result := T('TAS_HAYIR');
end;

function TfrmTabloTasarim.EvetMi(const Metin: string): Boolean;
begin
  Result := SameText(Metin, T('TAS_EVET'));
end;

{ Hucrede acilir liste cikan sutunlar: tip ve evet/hayir sutunlari (yazilarak degistirilmez). }
function TfrmTabloTasarim.KutuSutunuMu(Sutun: Integer): Boolean;
begin
  Result := Sutun in [SUTUN_TIP, SUTUN_BOS, SUTUN_BIRINCIL, SUTUN_OTO];
end;

procedure TfrmTabloTasarim.YazilariYaz;
begin
  Caption := T('TAS_BASLIK');
  lblTablo.Caption := T('TAS_TABLO_AD');
  lblIpucu.Caption := T('TAS_IPUCU');
  if not FKimlik then
    lblIpucu.Caption := lblIpucu.Caption + ' ' + T('TAS_OTO_25');
  lblSql.Caption := T('TAS_SQL');
  btnEkle.Caption := T('TAS_KOLON_EKLE');
  btnCikar.Caption := T('TAS_KOLON_SIL');
  btnYukari.Caption := T('TAS_YUKARI');
  btnAsagi.Caption := T('TAS_ASAGI');
  btnOlustur.Caption := T('TAS_OLUSTUR');
  btnKapat.Caption := T('BTN_KAPAT');
  DugmeyiYaziyaUydur(btnEkle);
  DugmeyiYaziyaUydur(btnCikar);
  DugmeyiYaziyaUydur(btnYukari);
  DugmeyiYaziyaUydur(btnAsagi);
  DugmeyiYaziyaUydur(btnOlustur);
  DugmeyiYaziyaUydur(btnKapat);
  { Otomatik artan sutunu yalniz Firebird 3.0 ve ustunde. }
  if FKimlik then
    gridKolon.ColCount := 7
  else
    gridKolon.ColCount := 6;
  gridKolon.Cells[SUTUN_AD, 0] := T('TAS_KOL_AD');
  gridKolon.Cells[SUTUN_TIP, 0] := T('TAS_KOL_TIP');
  gridKolon.Cells[SUTUN_BOYUT, 0] := T('TAS_KOL_BOYUT');
  gridKolon.Cells[SUTUN_BOS, 0] := T('TAS_KOL_BOS_OLMAZ');
  gridKolon.Cells[SUTUN_BIRINCIL, 0] := T('TAS_KOL_BIRINCIL');
  gridKolon.Cells[SUTUN_VARSAYILAN, 0] := T('TAS_KOL_VARSAYILAN');
  gridKolon.ColWidths[SUTUN_AD] := 150;
  gridKolon.ColWidths[SUTUN_TIP] := 160;
  gridKolon.ColWidths[SUTUN_BOYUT] := 70;
  gridKolon.ColWidths[SUTUN_BOS] := 90;
  gridKolon.ColWidths[SUTUN_BIRINCIL] := 115;
  gridKolon.ColWidths[SUTUN_VARSAYILAN] := 140;
  if FKimlik then
  begin
    gridKolon.Cells[SUTUN_OTO, 0] := T('TAS_KOL_OTO');
    gridKolon.ColWidths[SUTUN_OTO] := 110;
  end;
  { Baslangic: tipik bir tablo (kimlik + ad). Ilk veri satiri izgarada zaten var (RowCount 2). }
  SatiriYaz(1, 'ID', 'INTEGER', '', True, True, FKimlik);
  SatirEkle('AD', 'VARCHAR', '50', False, False, False);
  gridKolon.Row := 1;
  Guncelle;
end;

procedure TfrmTabloTasarim.SatirEkle(const Ad, Tip, Boyut: string; Bos, Birincil, Oto: Boolean);
begin
  gridKolon.RowCount := gridKolon.RowCount + 1;
  SatiriYaz(gridKolon.RowCount - 1, Ad, Tip, Boyut, Bos, Birincil, Oto);
end;

procedure TfrmTabloTasarim.SatiriYaz(Satir: Integer; const Ad, Tip, Boyut: string; Bos, Birincil, Oto: Boolean);
begin
  gridKolon.Cells[SUTUN_AD, Satir] := Ad;
  gridKolon.Cells[SUTUN_TIP, Satir] := Tip;
  gridKolon.Cells[SUTUN_BOYUT, Satir] := Boyut;
  gridKolon.Cells[SUTUN_BOS, Satir] := EvetHayir(Bos);
  gridKolon.Cells[SUTUN_BIRINCIL, Satir] := EvetHayir(Birincil);
  gridKolon.Cells[SUTUN_VARSAYILAN, Satir] := '';
  if FKimlik then
    gridKolon.Cells[SUTUN_OTO, Satir] := EvetHayir(Oto);
end;

procedure TfrmTabloTasarim.SatiriTemizle(Satir: Integer);
begin
  gridKolon.Rows[Satir].Clear;
  gridKolon.Cells[SUTUN_TIP, Satir] := 'VARCHAR';
  gridKolon.Cells[SUTUN_BOYUT, Satir] := '50';
  gridKolon.Cells[SUTUN_BOS, Satir] := EvetHayir(False);
  gridKolon.Cells[SUTUN_BIRINCIL, Satir] := EvetHayir(False);
  if FKimlik then
    gridKolon.Cells[SUTUN_OTO, Satir] := EvetHayir(False);
end;

{ Kaynak satirin icerigini Hedef satirla yer degistirir. }
procedure TfrmTabloTasarim.SatirlariTasi(Kaynak, Hedef: Integer);
var
  Gecici: TStringList;
begin
  Gecici := TStringList.Create;
  try
    Gecici.Assign(gridKolon.Rows[Kaynak]);
    gridKolon.Rows[Kaynak].Assign(gridKolon.Rows[Hedef]);
    gridKolon.Rows[Hedef].Assign(Gecici);
  finally
    Gecici.Free;
  end;
end;

function TfrmTabloTasarim.KolonlariOku: TArray<TTasarimKolon>;
var
  Satir: Integer;
  Kolon: TTasarimKolon;
begin
  SetLength(Result, 0);
  for Satir := 1 to gridKolon.RowCount - 1 do
  begin
    Kolon.Ad := Trim(gridKolon.Cells[SUTUN_AD, Satir]);
    Kolon.Tip := Trim(gridKolon.Cells[SUTUN_TIP, Satir]);
    Kolon.Boyut := Trim(gridKolon.Cells[SUTUN_BOYUT, Satir]);
    Kolon.BosOlmaz := EvetMi(gridKolon.Cells[SUTUN_BOS, Satir]);
    Kolon.Birincil := EvetMi(gridKolon.Cells[SUTUN_BIRINCIL, Satir]);
    Kolon.Varsayilan := Trim(gridKolon.Cells[SUTUN_VARSAYILAN, Satir]);
    Kolon.OtoArtan := FKimlik and EvetMi(gridKolon.Cells[SUTUN_OTO, Satir]);
    Result := Result + [Kolon];
  end;
end;

{ Kontrol sonucu (kirmizi cumle) ve olusacak SQL yenilenir; tasarim gecersizse SQL bos, Olustur kapali. }
procedure TfrmTabloTasarim.Guncelle;
var
  Kolonlar: TArray<TTasarimKolon>;
  Hata: string;
begin
  Kolonlar := KolonlariOku;
  Hata := TasarimDogrula(FBag, edtTablo.Text, Kolonlar, FTipler);
  lblDurum.Caption := Hata;
  { Tablo adi henuz yazilmadiysa onizleme yer tutucu adla gosterilir (kolonlar gecerliyse). }
  if Trim(edtTablo.Text) = '' then
    memSql.Text := TasarimScripti(FBag, 'YENI_TABLO', Kolonlar, FTipler)
  else
    memSql.Text := TasarimScripti(FBag, edtTablo.Text, Kolonlar, FTipler);
  btnOlustur.Enabled := Hata = '';
end;

procedure TfrmTabloTasarim.TabloAdiDegisti(Sender: TObject);
begin
  Guncelle;
end;

{ ---------- Hucredeki acilir liste (menu) ---------- }

{ Liste sutunlarinda hucreyi tiklayinca ya da Bosluk / Enter'a basinca, degerler hucrenin altinda acilir menu olarak cikar. Secilen deger
  dogrudan hucreye yazilir (ust uste binen bilesen, odak ya da duzenleyici sorunu yok). }
procedure TfrmTabloTasarim.ListeyiAc(Sutun, Satir: Integer);
var
  Ogeler: TStringList;
  Tip: TVeriTipi;
  Oge: TMenuItem;
  Alan: TRect;
  Nokta: TPoint;
  i: Integer;
begin
  if (Satir < 1) or not KutuSutunuMu(Sutun) then
    Exit;
  Ogeler := TStringList.Create;
  try
    if Sutun = SUTUN_TIP then
      for Tip in FTipler do
        Ogeler.Add(Tip.Ad)
    else
    begin
      Ogeler.Add(T('TAS_EVET'));
      Ogeler.Add(T('TAS_HAYIR'));
    end;
    pmListe.Items.Clear;
    FListeSutun := Sutun;
    FListeSatir := Satir;
    for i := 0 to Ogeler.Count - 1 do
    begin
      Oge := TMenuItem.Create(pmListe);
      Oge.Caption := Ogeler[i];
      Oge.Checked := SameText(Ogeler[i], gridKolon.Cells[Sutun, Satir]);
      Oge.OnClick := ListeOgesiSecildi;
      { Cok uzun listede (tipler) ikinci sutuna gecsin, ekrandan tasmasin. }
      if (Ogeler.Count > 20) and (i > 0) and (i mod 20 = 0) then
        Oge.Break := mbBarBreak;
      pmListe.Items.Add(Oge);
    end;
  finally
    Ogeler.Free;
  end;
  Alan := gridKolon.CellRect(Sutun, Satir);
  Nokta := gridKolon.ClientToScreen(Point(Alan.Left, Alan.Bottom));
  pmListe.Popup(Nokta.X, Nokta.Y);
end;

procedure TfrmTabloTasarim.ListeOgesiSecildi(Sender: TObject);
begin
  DegerSec(FListeSutun, FListeSatir, TMenuItem(Sender).Caption);
end;

{ Liste degeri hucreye yazilir. Tip degisince boyut varsayilana doner; birincil anahtar ya da otomatik artan secilince bos olamaz olur. }
procedure TfrmTabloTasarim.DegerSec(Sutun, Satir: Integer; const Deger: string);
var
  Tip: TVeriTipi;
begin
  gridKolon.Cells[Sutun, Satir] := Deger;
  if Sutun = SUTUN_TIP then
  begin
    if TasarimTipiBul(Deger, FTipler, Tip) then
      gridKolon.Cells[SUTUN_BOYUT, Satir] := TasarimBoyutVarsayilani(Tip);
  end
  else if ((Sutun = SUTUN_BIRINCIL) or (Sutun = SUTUN_OTO)) and EvetMi(Deger) then
    gridKolon.Cells[SUTUN_BOS, Satir] := T('TAS_EVET');
  Guncelle;
end;

procedure TfrmTabloTasarim.gridKolonMouseUp(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
var
  Hucre: TGridCoord;
begin
  if Button <> mbLeft then
    Exit;
  Hucre := gridKolon.MouseCoord(X, Y);
  if (Hucre.Y >= 1) and KutuSutunuMu(Hucre.X) then
    ListeyiAc(Hucre.X, Hucre.Y);
end;

{ Liste sutunlarindaki hucrelere kucuk bir asagi ok cizilir: tiklayinca liste acilir. }
procedure TfrmTabloTasarim.gridKolonDrawCell(Sender: TObject; ACol, ARow: Integer; Rect: TRect; State: TGridDrawState);
var
  Orta, Ust: Integer;
begin
  if (ARow < 1) or not KutuSutunuMu(ACol) then
    Exit;
  Orta := Rect.Right - 12;
  Ust := (Rect.Top + Rect.Bottom) div 2 - 2;
  gridKolon.Canvas.Brush.Color := clGrayText;
  gridKolon.Canvas.Pen.Color := clGrayText;
  gridKolon.Canvas.Polygon([Point(Orta - 4, Ust), Point(Orta + 4, Ust), Point(Orta, Ust + 5)]);
end;

procedure TfrmTabloTasarim.gridKolonSelectCell(Sender: TObject; ACol, ARow: Integer; var CanSelect: Boolean);
begin
  { Liste sutunlarinda yazarak degistirme kapali (liste kullanilir); digerlerinde acik. }
  if KutuSutunuMu(ACol) then
    gridKolon.Options := gridKolon.Options - [goEditing]
  else
    gridKolon.Options := gridKolon.Options + [goEditing];
end;

{ Bosluk ya da Enter: liste sutununda listeyi ac (klavyeyle secim). }
procedure TfrmTabloTasarim.gridKolonKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  if ((Key = VK_SPACE) or (Key = VK_RETURN)) and (gridKolon.Row >= 1) and KutuSutunuMu(gridKolon.Col) then
  begin
    ListeyiAc(gridKolon.Col, gridKolon.Row);
    Key := 0;
  end;
end;

procedure TfrmTabloTasarim.gridKolonSetEditText(Sender: TObject; ACol, ARow: Integer; const Value: string);
begin
  Guncelle;
end;

{ ---------- Satir dugmeleri ---------- }

procedure TfrmTabloTasarim.btnEkleClick(Sender: TObject);
begin
  SatirEkle('', 'VARCHAR', '50', False, False, False);
  gridKolon.Row := gridKolon.RowCount - 1;
  gridKolon.Col := SUTUN_AD;
  gridKolon.SetFocus;
  Guncelle;
end;

{ Secili kolonu tasarimdan cikarir (son kalan satir silinmez, temizlenir). }
procedure TfrmTabloTasarim.btnCikarClick(Sender: TObject);
var
  Satir: Integer;
begin
  Satir := gridKolon.Row;
  if Satir < 1 then
    Exit;
  if gridKolon.RowCount <= 2 then
    SatiriTemizle(Satir)
  else
  begin
    while Satir < gridKolon.RowCount - 1 do
    begin
      gridKolon.Rows[Satir].Assign(gridKolon.Rows[Satir + 1]);
      Inc(Satir);
    end;
    gridKolon.RowCount := gridKolon.RowCount - 1;
  end;
  Guncelle;
end;

procedure TfrmTabloTasarim.btnYukariClick(Sender: TObject);
begin
  if gridKolon.Row > 1 then
  begin
    SatirlariTasi(gridKolon.Row, gridKolon.Row - 1);
    gridKolon.Row := gridKolon.Row - 1;
    Guncelle;
  end;
end;

procedure TfrmTabloTasarim.btnAsagiClick(Sender: TObject);
begin
  if (gridKolon.Row >= 1) and (gridKolon.Row < gridKolon.RowCount - 1) then
  begin
    SatirlariTasi(gridKolon.Row, gridKolon.Row + 1);
    gridKolon.Row := gridKolon.Row + 1;
    Guncelle;
  end;
end;

{ Olustur: kontrol, ayni adli tablo var mi, net onay (olusacak SQL), tek islemde CREATE TABLE. Hata olursa pencere acik kalir. }
procedure TfrmTabloTasarim.btnOlusturClick(Sender: TObject);
var
  Kolonlar: TArray<TTasarimKolon>;
  Hata, Ad, Script: string;
  Sonuc: TProsedurSonucu;
begin
  Kolonlar := KolonlariOku;
  Hata := TasarimDogrula(FBag, edtTablo.Text, Kolonlar, FTipler);
  if Hata <> '' then
  begin
    UyariGoster(Hata);
    Exit;
  end;
  Ad := TasarimTabloAdi(edtTablo.Text);
  try
    if TasarimTabloVarMi(FBag, Ad) then
    begin
      UyariGoster(TF('ERR_TAS_TABLO_VAR', [Ad]));
      Exit;
    end;
  except
    on E: Exception do
    begin
      UyariGoster(HataMetniniCevir(E) + sLineBreak + sLineBreak + T('AYRINTI') + ': ' + E.Message);
      Exit;
    end;
  end;
  Script := TasarimScripti(FBag, edtTablo.Text, Kolonlar, FTipler);
  if not OnayIste(TF('TAS_ONAY', [Ad, Script])) then
    Exit;
  Sonuc := TasarimOlustur(FBag, edtTablo.Text, Kolonlar, FTipler);
  if (Length(Sonuc.Komutlar) > 0) and Assigned(FSqlYaz) then
    FSqlYaz(Sonuc.Komutlar);
  if Sonuc.Basarili then
  begin
    FSonuc.Add(TF('MSG_TAS_OLUSTURULDU', [Ad]));
    FOlustu := True;
    FYeniAd := Ad;
    ModalResult := mrOk;
    Exit;
  end;
  FSonuc.Add(TF('ERR_TAS_OLUSTURULAMADI', [Ad]) + ' ' + Sonuc.Cumle);
  if Sonuc.Ayrinti <> '' then
    FSonuc.Add(T('AYRINTI') + ': ' + Sonuc.Ayrinti);
  UyariGoster(TF('ERR_TAS_OLUSTURULAMADI', [Ad]) + sLineBreak + sLineBreak + Sonuc.Cumle);
end;

end.
