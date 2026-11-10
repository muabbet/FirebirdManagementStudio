{ uFiltreSatiri.pas - Tablo gridinin baslik satirinin altindaki filtre satiri (cxGrid'deki gibi).
  Her kolonun altinda kucuk bir yazi kutusu durur. Yazilanlari uFiltre.SatirFiltresi kosula cevirir; sorguyu
  calistirmak icin Uygula olayini cagirir: yalniz Enter'a basinca ya da oneri listesinden deger secince (yazarken
  kendiliginden filtrelemez; sunucuya gereksiz sorgu gitmesin, yarim yazilmis kosul calismasin).

  Nasil sigiyor: TDBGrid kolon genisligi ve yatay kaydirma degisince haber vermez. Bu yuzden kisa araliklarla
  calisan bir zamanlayici kutulari kolonlarin altina yeniden oturtur (CellRect). Baslik satirini kutular icin
  yukseltmek de burada yapilir; grid kendi yerlesiminde yuksekligi geri alirsa ayni zamanlayici tekrar yukseltir. }
unit uFiltreSatiri;

interface

uses
  Winapi.Windows, System.SysUtils, System.Classes, System.Generics.Collections, System.Types, System.Math, Data.DB,
  Vcl.Controls, Vcl.Graphics, Vcl.StdCtrls, Vcl.ExtCtrls, Vcl.Grids, Vcl.DBGrids,
  uDil, uFiltre;

const
  { Yazarken kutunun altinda en cok kac onerilen deger gorunur. }
  ONERI_ADET = 10;

type
  { Yazi yazilan kutunun kolonu (AlanAdi) icin Yazi'yi iceren degerleri Sonuc'a ekler (uSorgu.AlanDegerleri). }
  TOneriOlayi = procedure(const AlanAdi, Yazi: string; Sonuc: TStrings) of object;

  TFiltreSatiri = class
  private
    FGrid: TDBGrid;
    FUygula: TNotifyEvent;
    FKutular: TList<TEdit>;
    FAlanAdlari: TStringList;
    FTurler: TList<TFieldType>;
    FYerlestirici: TTimer;
    { Grid kendi yazdigi baslik yuksekligi, bizim yukselttigimiz yukseklik ve kutulari doldurmayi bastan yapan bayrak. }
    FTemelYukseklik: Integer;
    FAyarlananYukseklik: Integer;
    FYukleniyor: Boolean;
    { Yazarken kutunun altinda cikan oneri listesi: hangi kutu icin, gorunen degerler, secili sira ve getirme beklemesi. }
    FOneri: TOneriOlayi;
    FOneriPaneli: TPanel;
    FOneriKutusu: TPaintBox;
    FOneriler: TStringList;
    FOneriSira: Integer;
    FOneriZamani: TTimer;
    FSonKutu: TEdit;
    procedure KutulariSil;
    function KolonSirasi(const AlanAdi: string): Integer;
    function GridOrijini: TPoint;
    procedure YazisiDegisti(Sender: TObject);
    procedure TusBasildi(Sender: TObject; var Key: Char);
    procedure YerlestirmeZamani(Sender: TObject);
    function OneriUygunMu(Kutu: TEdit): Boolean;
    procedure OneriGetir(Sender: TObject);
    procedure OneriGoster;
    procedure OneriGizle;
    procedure OneriSec(Sira: Integer);
    procedure OneriCiz(Sender: TObject);
    procedure OneriFare(Sender: TObject; Shift: TShiftState; X, Y: Integer);
    procedure OneriTikla(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
    procedure TusIndi(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure KutuAyrildi(Sender: TObject);
  public
    constructor Create(Grid: TDBGrid; Uygula: TNotifyEvent);
    destructor Destroy; override;
    { Gridin gorunen kolonlarina gore kutulari kurar; kolonlar ayniysa mevcut kutulara dokunmaz (yazilar kalir). }
    procedure Esitle;
    { Kutulari kolonlarin altina oturtur; baslik satirini yukseltir. }
    procedure Yerlestir;
    { Dolu kutulardan WHERE kosulu (VE ile); gecersiz yazili kutu kirmizi olur ve Hata dolar. }
    { HaricAlan doluysa o kolonun kutusu katilmaz (o kolon icin oneri toplarken kendi filtresi sayilmasin). }
    function Kosul(out Hata: string; const HaricAlan: string = ''): string;
    procedure Temizle;
    { Dil degisince kutu ipuclari (hata ipuclari dahil) yeni dilde yazilir. }
    procedure YazilariYenile;
    function Dolu: Boolean;
    { Duzenleme kipinde kutular kapanir. }
    procedure Etkin(Acik: Boolean);
    property OnOneri: TOneriOlayi read FOneri write FOneri;
  end;

implementation

type
  { Yalniz gridin korumali CellRect ve RowHeights ozelliklerini kullanmak icin. }
  TGridErisim = class(TDBGrid);

const
  KUTU_YUKSEKLIK = 22;
  { Baslik satirina eklenen yukseklik: kutu ve ust-alt bosluk. }
  EKLENEN_YUKSEKLIK = KUTU_YUKSEKLIK + 3;
  YERLESTIRME_MS = 80;
  { Oneri listesi: satir yuksekligi ve yazmayi biraktiktan sonra getirmeden once bekleme. }
  ONERI_SATIR = 20;
  ONERI_BEKLEME_MS = 350;

constructor TFiltreSatiri.Create(Grid: TDBGrid; Uygula: TNotifyEvent);
begin
  inherited Create;
  FGrid := Grid;
  FUygula := Uygula;
  FKutular := TList<TEdit>.Create;
  FAlanAdlari := TStringList.Create;
  FTurler := TList<TFieldType>.Create;
  FYerlestirici := TTimer.Create(nil);
  FYerlestirici.Interval := YERLESTIRME_MS;
  FYerlestirici.OnTimer := YerlestirmeZamani;
  FOneriler := TStringList.Create;
  FOneriSira := -1;
  FOneriZamani := TTimer.Create(nil);
  FOneriZamani.Enabled := False;
  FOneriZamani.Interval := ONERI_BEKLEME_MS;
  FOneriZamani.OnTimer := OneriGetir;
  { Oneri listesi: pencereli bir panel (grafik bilesen gridin altinda kalirdi) ve icinde cizim kutusu. Panele ve cizim
    kutusuna tiklamak yazi kutusunun odagini almaz, yani liste tiklamadan once kapanmaz. }
  FOneriPaneli := TPanel.Create(FGrid);
  FOneriPaneli.Parent := FGrid.Parent;
  FOneriPaneli.BevelOuter := bvNone;
  FOneriPaneli.ParentBackground := False;
  FOneriPaneli.Visible := False;
  FOneriKutusu := TPaintBox.Create(FOneriPaneli);
  FOneriKutusu.Parent := FOneriPaneli;
  FOneriKutusu.Align := alClient;
  FOneriKutusu.OnPaint := OneriCiz;
  FOneriKutusu.OnMouseMove := OneriFare;
  FOneriKutusu.OnMouseDown := OneriTikla;
end;

destructor TFiltreSatiri.Destroy;
var
  Kutu: TEdit;
begin
  FYerlestirici.Free;
  FOneriZamani.Free;
  FOneriler.Free;
  { Kutular ve oneri listesi gridin cocuklaridir, grid ile birlikte yok olur; olaylari simdiden birakilir. }
  FOneriKutusu.OnPaint := nil;
  FOneriKutusu.OnMouseMove := nil;
  FOneriKutusu.OnMouseDown := nil;
  for Kutu in FKutular do
  begin
    Kutu.OnChange := nil;
    Kutu.OnKeyPress := nil;
    Kutu.OnKeyDown := nil;
    Kutu.OnExit := nil;
  end;
  FKutular.Free;
  FAlanAdlari.Free;
  FTurler.Free;
  inherited;
end;

procedure TFiltreSatiri.KutulariSil;
var
  Kutu: TEdit;
begin
  OneriGizle;
  FSonKutu := nil;
  for Kutu in FKutular do
    Kutu.Free;
  FKutular.Clear;
  FAlanAdlari.Clear;
  FTurler.Clear;
end;

{ Gridin ic alaninin sol ust kosesi, kutularin durdugu panelin koordinatinda. Kutular gridin cocugu DEGIL, kardesidir:
  TCustomGrid, cocuk bilesenlerin WM_COMMAND mesajini yutar (OnChange hic tetiklenmez); panelde sorun olmaz. }
function TFiltreSatiri.GridOrijini: TPoint;
begin
  Result := FGrid.Parent.ScreenToClient(FGrid.ClientToScreen(Point(0, 0)));
end;

{ Alanin gridde kacinci kolon oldugu; yoksa -1. }
function TFiltreSatiri.KolonSirasi(const AlanAdi: string): Integer;
var
  i: Integer;
begin
  Result := -1;
  for i := 0 to FGrid.Columns.Count - 1 do
    if SameText(FGrid.Columns[i].FieldName, AlanAdi) then
      Exit(i);
end;

procedure TFiltreSatiri.Esitle;
var
  Veri: TDataSet;
  Alan: TField;
  Sutun: TColumn;
  YeniAdlar: TStringList;
  YeniTurler: TList<TFieldType>;
  Eski: TDictionary<string, string>;
  i: Integer;
  Ayni: Boolean;
  Kutu: TEdit;
begin
  if (FGrid.DataSource = nil) or (FGrid.DataSource.DataSet = nil) or not FGrid.DataSource.DataSet.Active then
  begin
    KutulariSil;
    Exit;
  end;
  Veri := FGrid.DataSource.DataSet;
  YeniAdlar := TStringList.Create;
  YeniTurler := TList<TFieldType>.Create;
  Eski := TDictionary<string, string>.Create;
  try
    for i := 0 to FGrid.Columns.Count - 1 do
    begin
      Sutun := FGrid.Columns[i];
      Alan := Veri.FindField(Sutun.FieldName);
      if Sutun.Visible and (Alan <> nil) then
      begin
        YeniAdlar.Add(Alan.FieldName);
        YeniTurler.Add(Alan.DataType);
      end;
    end;
    Ayni := (YeniAdlar.Count = FAlanAdlari.Count);
    if Ayni then
      for i := 0 to YeniAdlar.Count - 1 do
        if (YeniAdlar[i] <> FAlanAdlari[i]) or (YeniTurler[i] <> FTurler[i]) then
          Ayni := False;
    if not Ayni then
    begin
      { Ayni adli kolonlarin yazilari yeni kutulara tasinir. }
      for i := 0 to FAlanAdlari.Count - 1 do
        Eski.AddOrSetValue(FAlanAdlari[i], FKutular[i].Text);
      KutulariSil;
      FYukleniyor := True;
      try
        for i := 0 to YeniAdlar.Count - 1 do
        begin
          Kutu := TEdit.Create(FGrid);
          Kutu.Parent := FGrid.Parent;
          Kutu.Tag := i;
          Kutu.ShowHint := True;
          Kutu.Enabled := not (YeniTurler[i] in [ftBlob, ftGraphic, ftBytes, ftVarBytes, ftTypedBinary, ftOraBlob, ftOraClob]);
          if Eski.ContainsKey(YeniAdlar[i]) then
            Kutu.Text := Eski[YeniAdlar[i]];
          Kutu.OnChange := YazisiDegisti;
          Kutu.OnKeyPress := TusBasildi;
          Kutu.OnKeyDown := TusIndi;
          Kutu.OnExit := KutuAyrildi;
          FKutular.Add(Kutu);
          FAlanAdlari.Add(YeniAdlar[i]);
          FTurler.Add(YeniTurler[i]);
        end;
      finally
        FYukleniyor := False;
      end;
    end;
  finally
    Eski.Free;
    YeniTurler.Free;
    YeniAdlar.Free;
  end;
  for Kutu in FKutular do
    if Kutu.Hint = '' then
      Kutu.Hint := T('FILTRE_SATIR_IPUCU');
  Yerlestir;
end;

procedure TFiltreSatiri.Yerlestir;
var
  Grid: TGridErisim;
  i, Sutun, Kayma: Integer;
  Kutu: TEdit;
  Hucre: TRect;
  Sol, Genislik, Ust: Integer;
  Orijin: TPoint;
begin
  if FKutular.Count = 0 then
    Exit;
  Orijin := GridOrijini;
  Grid := TGridErisim(FGrid);
  if not (dgTitles in Grid.Options) or (Grid.RowCount < 1) then
    Exit;
  { Baslik satiri: grid kendi yuksekligine dondurduyse (yeni veri) yeniden yukseltilir. }
  if Grid.RowHeights[0] <> FAyarlananYukseklik then
    FTemelYukseklik := Grid.RowHeights[0];
  FAyarlananYukseklik := FTemelYukseklik + EKLENEN_YUKSEKLIK;
  if Grid.RowHeights[0] <> FAyarlananYukseklik then
    Grid.RowHeights[0] := FAyarlananYukseklik;

  Kayma := 0;
  if dgIndicator in Grid.Options then
    Kayma := 1;
  for i := 0 to FKutular.Count - 1 do
  begin
    Kutu := FKutular[i];
    { Kutunun kolonu gridde hangi sirada: ad ile bulunur (kolonlar surukle-birakla yer degistirebilir). }
    Sutun := KolonSirasi(FAlanAdlari[i]);
    if Sutun < 0 then
    begin
      Kutu.Visible := False;
      Continue;
    end;
    Hucre := Grid.CellRect(Sutun + Kayma, 0);
    Sol := Hucre.Left;
    Genislik := Hucre.Right - Hucre.Left;
    { Gorunen alanin disinda ya da cok dar: kutu gizlenir. }
    if Sol + Genislik > Grid.ClientWidth then
      Genislik := Grid.ClientWidth - Sol;
    if (Hucre.Right <= Hucre.Left) or (Genislik < 24) then
    begin
      Kutu.Visible := False;
      Continue;
    end;
    Ust := Hucre.Bottom - KUTU_YUKSEKLIK - 2;
    Kutu.SetBounds(Orijin.X + Sol + 1, Orijin.Y + Ust, Genislik - 2, KUTU_YUKSEKLIK);
    Kutu.Visible := True;
  end;
end;

procedure TFiltreSatiri.YerlestirmeZamani(Sender: TObject);
begin
  if FGrid.Showing then
    Yerlestir;
end;

procedure TFiltreSatiri.YazisiDegisti(Sender: TObject);
begin
  if FYukleniyor then
    Exit;
  { Yazarken filtre uygulanmaz. Oneri: yazi degisince eski liste kapanir, kisa beklemeden sonra yenisi getirilir. }
  OneriGizle;
  FSonKutu := Sender as TEdit;
  if Assigned(FOneri) and OneriUygunMu(FSonKutu) then
    FOneriZamani.Enabled := True;
end;

{ Enter: listede bir deger secilmisse onu uygular, degilse yazilani hemen uygular. }
procedure TFiltreSatiri.TusBasildi(Sender: TObject; var Key: Char);
begin
  if Key <> #13 then
    Exit;
  Key := #0;
  if FOneriPaneli.Visible and (FOneriSira >= 0) then
  begin
    OneriSec(FOneriSira);
    Exit;
  end;
  OneriGizle;
  FUygula(Self);
end;

{ Yukari, asagi ok listede gezer; Esc listeyi kapatir. }
procedure TFiltreSatiri.TusIndi(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  if not FOneriPaneli.Visible then
    Exit;
  case Key of
    VK_DOWN:
      begin
        if FOneriSira < FOneriler.Count - 1 then
          Inc(FOneriSira);
        FOneriKutusu.Invalidate;
        Key := 0;
      end;
    VK_UP:
      begin
        if FOneriSira > 0 then
          Dec(FOneriSira);
        FOneriKutusu.Invalidate;
        Key := 0;
      end;
    VK_ESCAPE:
      begin
        OneriGizle;
        Key := 0;
      end;
  end;
end;

procedure TFiltreSatiri.KutuAyrildi(Sender: TObject);
begin
  OneriGizle;
end;

{ Oneri yalniz yazi kolonlarinda ve islem isareti olmayan yazida cikar. }
function TFiltreSatiri.OneriUygunMu(Kutu: TEdit): Boolean;
var
  Sira: Integer;
  Yazi: string;
begin
  Result := False;
  Sira := FKutular.IndexOf(Kutu);
  if (Sira < 0) or not (FTurler[Sira] in [ftString, ftWideString, ftFixedChar, ftFixedWideChar]) then
    Exit;
  Yazi := Trim(Kutu.Text);
  if (Yazi = '') or CharInSet(Yazi[1], ['>', '<', '=', '!', '-', '*']) then
    Exit;
  Result := True;
end;

{ Beklemeden sonra: degerleri sunucudan ister (olay), gelenleri listeler. Oneri yardimcidir; hata asil isi bozmasin diye yutulur. }
procedure TFiltreSatiri.OneriGetir(Sender: TObject);
var
  Sira: Integer;
begin
  FOneriZamani.Enabled := False;
  if (FSonKutu = nil) or not Assigned(FOneri) or not OneriUygunMu(FSonKutu) then
    Exit;
  Sira := FKutular.IndexOf(FSonKutu);
  FOneriler.Clear;
  try
    FOneri(FAlanAdlari[Sira], Trim(FSonKutu.Text), FOneriler);
  except
    FOneriler.Clear;
  end;
  if FOneriler.Count = 0 then
    OneriGizle
  else
    OneriGoster;
end;

procedure TFiltreSatiri.OneriGoster;
var
  Genislik, Sag: Integer;
begin
  Genislik := Max(FSonKutu.Width, 160);
  Sag := GridOrijini.X + FGrid.ClientWidth;
  if FSonKutu.Left + Genislik > Sag then
    Genislik := Max(60, Sag - FSonKutu.Left);
  FOneriPaneli.SetBounds(FSonKutu.Left, FSonKutu.Top + FSonKutu.Height, Genislik, FOneriler.Count * ONERI_SATIR + 2);
  FOneriSira := -1;
  FOneriPaneli.Visible := True;
  FOneriPaneli.BringToFront;
  FOneriKutusu.Invalidate;
end;

procedure TFiltreSatiri.OneriGizle;
begin
  FOneriZamani.Enabled := False;
  FOneriPaneli.Visible := False;
  FOneriSira := -1;
end;

{ Secilen deger kutuya "=deger" olarak yazilir ve filtre hemen uygulanir (secilen degerin tam esiti). }
procedure TFiltreSatiri.OneriSec(Sira: Integer);
begin
  if (FSonKutu = nil) or (Sira < 0) or (Sira >= FOneriler.Count) then
    Exit;
  FYukleniyor := True;
  try
    FSonKutu.Text := '=' + FOneriler[Sira];
  finally
    FYukleniyor := False;
  end;
  FSonKutu.SelStart := Length(FSonKutu.Text);
  OneriGizle;
  FUygula(Self);
end;

procedure TFiltreSatiri.OneriCiz(Sender: TObject);
var
  i: Integer;
  Alan: TRect;
begin
  with FOneriKutusu.Canvas do
  begin
    Font.Assign(FGrid.Font);
    Brush.Color := clWindow;
    Pen.Color := clGray;
    Rectangle(0, 0, FOneriKutusu.Width, FOneriKutusu.Height);
    for i := 0 to FOneriler.Count - 1 do
    begin
      Alan := Rect(1, 1 + i * ONERI_SATIR, FOneriKutusu.Width - 1, 1 + (i + 1) * ONERI_SATIR);
      if i = FOneriSira then
      begin
        Brush.Color := clHighlight;
        Font.Color := clHighlightText;
      end
      else
      begin
        Brush.Color := clWindow;
        Font.Color := clWindowText;
      end;
      FillRect(Alan);
      TextRect(Alan, Alan.Left + 4, Alan.Top + 2, FOneriler[i]);
    end;
  end;
end;

procedure TFiltreSatiri.OneriFare(Sender: TObject; Shift: TShiftState; X, Y: Integer);
var
  Sira: Integer;
begin
  Sira := (Y - 1) div ONERI_SATIR;
  if (Sira >= 0) and (Sira < FOneriler.Count) and (Sira <> FOneriSira) then
  begin
    FOneriSira := Sira;
    FOneriKutusu.Invalidate;
  end;
end;

procedure TFiltreSatiri.OneriTikla(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  if Button = mbLeft then
    OneriSec((Y - 1) div ONERI_SATIR);
end;

function TFiltreSatiri.Kosul(out Hata: string; const HaricAlan: string): string;
var
  i: Integer;
  Parca, KutuHata: string;
begin
  Result := '';
  Hata := '';
  for i := 0 to FKutular.Count - 1 do
  begin
    if (HaricAlan <> '') and SameText(FAlanAdlari[i], HaricAlan) then
      Continue;
    Parca := SatirFiltresi(FAlanAdlari[i], FTurler[i], FKutular[i].Text, KutuHata);
    if KutuHata <> '' then
    begin
      FKutular[i].Font.Color := clRed;
      FKutular[i].Hint := KutuHata;
      if Hata = '' then
        Hata := KutuHata;
      Continue;
    end;
    FKutular[i].Font.Color := clWindowText;
    FKutular[i].Hint := T('FILTRE_SATIR_IPUCU');
    if Parca <> '' then
    begin
      if Result <> '' then
        Result := Result + ' AND ';
      Result := Result + Parca;
    end;
  end;
end;

procedure TFiltreSatiri.YazilariYenile;
var
  Hata: string;
begin
  { Kosul her kutunun ipucunu ve kirmizi rengini o anki dilde yeniden yazar. }
  Kosul(Hata);
end;

procedure TFiltreSatiri.Temizle;
var
  Kutu: TEdit;
begin
  FYukleniyor := True;
  try
    for Kutu in FKutular do
    begin
      Kutu.Text := '';
      Kutu.Font.Color := clWindowText;
    end;
  finally
    FYukleniyor := False;
  end;
end;

function TFiltreSatiri.Dolu: Boolean;
var
  Kutu: TEdit;
begin
  Result := False;
  for Kutu in FKutular do
    if Trim(Kutu.Text) <> '' then
      Exit(True);
end;

procedure TFiltreSatiri.Etkin(Acik: Boolean);
var
  i: Integer;
begin
  for i := 0 to FKutular.Count - 1 do
    FKutular[i].Enabled := Acik and not (FTurler[i] in [ftBlob, ftGraphic, ftBytes, ftVarBytes, ftTypedBinary, ftOraBlob, ftOraClob]);
end;

end.
