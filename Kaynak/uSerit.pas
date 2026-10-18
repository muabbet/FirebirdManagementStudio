{ uSerit.pas - Ust sasedeki gruplu serit (ribbon). Ucuncu parti bilesen yok, yalniz standart VCL.

  Serit gruplardan, grup da dugmelerden olusur: buyuk ikon ustte, yazi altta,
  grubun adi grubun altinda. Dugmenin genisligi yaziya gore uzar; cok uzun yazi
  iki satira bolunur. Dugmeler ve gruplar fAna.pas'ta Ekle ile siralanir, o
  siralama seridin tam tanimidir.

  Renkler StyleServices'ten gelir (VCL Style). Yazilar T(...) ile, dil
  degisince YazilariYenile ile yeniden yazilir. }
unit uSerit;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Classes, System.Types,
  System.Math, System.Generics.Collections, Vcl.Controls, Vcl.Graphics, Vcl.ExtCtrls,
  Vcl.StdCtrls, Vcl.Themes, Vcl.ImageCollection,
  uDil;

type
  { Seridin tek bir dugmesi: ikon + yazi. OnClick'i dogrudan formun yordamidir. }
  TSeritDugmesi = class(TGraphicControl)
  private
    FYaziAnahtari: string;
    FIkonNo: Integer;
    FKoleksiyon: TImageCollection;
    FIkonBoyu: Integer;
    FEnFazlaYaziGenisligi: Integer;
    FBosluk: Integer;
    FUzerinde: Boolean;
    FBasili: Boolean;
    FBoyutDegisti: TNotifyEvent;
    procedure DurumuSifirla;
    procedure IkonCiz(X, Y: Integer);
    procedure CMMouseEnter(var Mesaj: TMessage); message CM_MOUSEENTER;
    procedure CMMouseLeave(var Mesaj: TMessage); message CM_MOUSELEAVE;
    procedure CMEnabledChanged(var Mesaj: TMessage); message CM_ENABLEDCHANGED;
  protected
    procedure Paint; override;
    procedure Click; override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure MouseMove(Shift: TShiftState; X, Y: Integer); override;
    procedure MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
  public
    constructor Create(AOwner: TComponent; Koleksiyon: TImageCollection; PPI: Integer); reintroduce;
    { Yazi anahtarini ve ikonu degistirir; yazi degisince serit yeniden dizilir. }
    procedure Ayarla(const YaziAnahtari: string; IkonNo: Integer);
    { Yaziyi secili dilden yazar, genisligi ve yuksekligi yaziya gore ayarlar. }
    procedure YazilariYenile;
    property OnBoyutDegisti: TNotifyEvent read FBoyutDegisti write FBoyutDegisti;
  end;

  { Bir grup: kendi paneli, dugmeleri, adi ve sagindaki ince cizgi. }
  TSeritGrubu = class
    Anahtar: string;
    Panel: TPanel;
    Etiket: TLabel;
    Cizgi: TBevel;
    Dugmeler: TList<TSeritDugmesi>;
  end;

  TSerit = class
  private
    FKap: TPanel;
    FKoleksiyon: TImageCollection;
    FGruplar: TObjectList<TSeritGrubu>;
    FPPI: Integer;
    FYukseklik: Integer;
    function Olcekle(Deger: Integer): Integer;
    function GrupBul(const Anahtar: string): TSeritGrubu;
    procedure DugmeBoyutuDegisti(Sender: TObject);
  public
    { Kap: seridin konacagi panel (formda yer ayirir). Koleksiyon: 32 px'e yakin PNG ikonlar. }
    constructor Create(Ust: TWinControl; Koleksiyon: TImageCollection; PPI: Integer);
    destructor Destroy; override;
    { GrupAnahtari yoksa grup olusur (sirasi Ekle sirasidir). Yazi ve grup adi T(...) anahtaridir. }
    function Ekle(const GrupAnahtari, YaziAnahtari: string; IkonNo: Integer;
      Tikla: TNotifyEvent): TSeritDugmesi;
    { Butun yazilari secili dilden yazar ve seridi yeniden dizer. }
    procedure YazilariYenile;
    procedure Duzenle;
    function Genislik: Integer;
    property Yukseklik: Integer read FYukseklik;
  end;

implementation

const
  KENAR = 8;
  IKON_BOYU = 32;
  YAZI_GENISLIGI = 100;
  DUGME_ARASI = 2;
  GRUP_ADI_YUKSEKLIGI = 20;
  CIZGI_GENISLIGI = 2;

{ ---------- TSeritDugmesi ---------- }

constructor TSeritDugmesi.Create(AOwner: TComponent; Koleksiyon: TImageCollection; PPI: Integer);
begin
  inherited Create(AOwner);
  FKoleksiyon := Koleksiyon;
  FIkonBoyu := MulDiv(IKON_BOYU, PPI, 96);
  FEnFazlaYaziGenisligi := MulDiv(YAZI_GENISLIGI, PPI, 96);
  FBosluk := MulDiv(KENAR, PPI, 96);
end;

procedure TSeritDugmesi.Ayarla(const YaziAnahtari: string; IkonNo: Integer);
var
  YaziDegisti: Boolean;
begin
  YaziDegisti := FYaziAnahtari <> YaziAnahtari;
  if (not YaziDegisti) and (FIkonNo = IkonNo) then
    Exit;
  FYaziAnahtari := YaziAnahtari;
  FIkonNo := IkonNo;
  if YaziDegisti then
  begin
    YazilariYenile;
    if Assigned(FBoyutDegisti) then
      FBoyutDegisti(Self);
  end
  else
    Invalidate;
end;

procedure TSeritDugmesi.YazilariYenile;
var
  Alan: TRect;
  YaziYuksekligi: Integer;
begin
  Caption := T(FYaziAnahtari);
  Canvas.Font.Assign(Font);
  Alan := Rect(0, 0, FEnFazlaYaziGenisligi, 0);
  DrawText(Canvas.Handle, PChar(Caption), -1, Alan, DT_CALCRECT or DT_WORDBREAK or DT_CENTER);
  { Yazi her zaman iki satirlik yer ayirir, boylece tum dugmeler ayni yukseklikte olur. }
  YaziYuksekligi := 2 * Canvas.TextHeight('Ag');
  Width := Max(Alan.Right, FIkonBoyu) + 2 * FBosluk;
  Height := FBosluk div 2 + FIkonBoyu + FBosluk div 2 + YaziYuksekligi + FBosluk div 2;
  Invalidate;
end;

{ Ikonu koleksiyondan cizer (saydam PNG). Pasif dugmede ikon soluk gorunur: once
  serit zemini uzerine cizilir, sonra yari saydam olarak ekrana konur. }
procedure TSeritDugmesi.IkonCiz(X, Y: Integer);
var
  Gecici: TBitmap;
begin
  if Enabled then
  begin
    FKoleksiyon.Draw(Canvas, Rect(X, Y, X + FIkonBoyu, Y + FIkonBoyu), FIkonNo);
    Exit;
  end;
  Gecici := TBitmap.Create;
  try
    Gecici.SetSize(FIkonBoyu, FIkonBoyu);
    Gecici.Canvas.Brush.Color := StyleServices(Self).GetSystemColor(clBtnFace);
    Gecici.Canvas.FillRect(Rect(0, 0, FIkonBoyu, FIkonBoyu));
    FKoleksiyon.Draw(Gecici.Canvas, Rect(0, 0, FIkonBoyu, FIkonBoyu), FIkonNo);
    Canvas.Draw(X, Y, Gecici, 90);
  finally
    Gecici.Free;
  end;
end;

procedure TSeritDugmesi.Paint;
var
  Ayrinti: TThemedElementDetails;
  Alan: TRect;
  YaziRengi: TColor;
  Servis: TCustomStyleServices;
begin
  Servis := StyleServices(Self);
  if not Enabled then
    Ayrinti := Servis.GetElementDetails(tbPushButtonDisabled)
  else if FBasili and FUzerinde then
    Ayrinti := Servis.GetElementDetails(tbPushButtonPressed)
  else if FUzerinde then
    Ayrinti := Servis.GetElementDetails(tbPushButtonHot)
  else
    Ayrinti := Servis.GetElementDetails(tbPushButtonNormal);
  { Normal ve pasif durumda zemin cizilmez, serit zemini gorunur. }
  if Enabled and FUzerinde then
    Servis.DrawElement(Canvas.Handle, Ayrinti, ClientRect);
  IkonCiz((Width - FIkonBoyu) div 2, FBosluk div 2);
  if not Servis.GetElementColor(Ayrinti, ecTextColor, YaziRengi) or (YaziRengi = clNone) then
    YaziRengi := Servis.GetSystemColor(clWindowText);
  if not Enabled then
    YaziRengi := Servis.GetSystemColor(clGrayText);
  Canvas.Font.Assign(Font);
  Canvas.Font.Color := YaziRengi;
  Canvas.Brush.Style := bsClear;
  SetBkMode(Canvas.Handle, TRANSPARENT);
  Alan := Rect(FBosluk div 2, FBosluk div 2 + FIkonBoyu + FBosluk div 2, Width - FBosluk div 2, Height);
  DrawText(Canvas.Handle, PChar(Caption), -1, Alan, DT_WORDBREAK or DT_CENTER or DT_NOPREFIX);
end;

{ Pasif dugme tiklanmaz. }
procedure TSeritDugmesi.Click;
begin
  if Enabled then
    inherited;
end;

procedure TSeritDugmesi.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  inherited;
  if (Button = mbLeft) and Enabled then
  begin
    FBasili := True;
    Invalidate;
  end;
end;

{ Basili tutarken fare dugmenin disina cikarsa basili gorunumu kalkar. }
procedure TSeritDugmesi.MouseMove(Shift: TShiftState; X, Y: Integer);
begin
  inherited;
  if FBasili and (FUzerinde <> PtInRect(ClientRect, Point(X, Y))) then
  begin
    FUzerinde := not FUzerinde;
    Invalidate;
  end;
end;

procedure TSeritDugmesi.MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  inherited;
  if FBasili then
  begin
    FBasili := False;
    FUzerinde := PtInRect(ClientRect, Point(X, Y));
    Invalidate;
  end;
end;

procedure TSeritDugmesi.DurumuSifirla;
begin
  FUzerinde := False;
  FBasili := False;
  Invalidate;
end;

procedure TSeritDugmesi.CMMouseEnter(var Mesaj: TMessage);
begin
  inherited;
  if Enabled then
  begin
    FUzerinde := True;
    Invalidate;
  end;
end;

procedure TSeritDugmesi.CMMouseLeave(var Mesaj: TMessage);
begin
  inherited;
  if not FBasili then
  begin
    FUzerinde := False;
    Invalidate;
  end;
end;

procedure TSeritDugmesi.CMEnabledChanged(var Mesaj: TMessage);
begin
  inherited;
  DurumuSifirla;
end;

{ ---------- TSerit ---------- }

constructor TSerit.Create(Ust: TWinControl; Koleksiyon: TImageCollection; PPI: Integer);
begin
  inherited Create;
  FPPI := PPI;
  FKoleksiyon := Koleksiyon;
  FGruplar := TObjectList<TSeritGrubu>.Create(True);
  FKap := TPanel.Create(Ust);
  FKap.Parent := Ust;
  FKap.Align := alClient;
  FKap.BevelOuter := bvNone;
  FKap.Caption := '';
  FKap.ShowCaption := False;
end;

destructor TSerit.Destroy;
begin
  { Panel ve icindekiler formun (sahibinin) elindedir; burada yalniz grup kayitlari silinir. }
  FGruplar.Free;
  inherited;
end;

function TSerit.Olcekle(Deger: Integer): Integer;
begin
  Result := MulDiv(Deger, FPPI, 96);
end;

function TSerit.GrupBul(const Anahtar: string): TSeritGrubu;
var
  Grup: TSeritGrubu;
begin
  for Grup in FGruplar do
    if Grup.Anahtar = Anahtar then
      Exit(Grup);
  Result := nil;
end;

function TSerit.Ekle(const GrupAnahtari, YaziAnahtari: string; IkonNo: Integer;
  Tikla: TNotifyEvent): TSeritDugmesi;
var
  Grup: TSeritGrubu;
begin
  Grup := GrupBul(GrupAnahtari);
  if Grup = nil then
  begin
    Grup := TSeritGrubu.Create;
    Grup.Anahtar := GrupAnahtari;
    Grup.Dugmeler := TList<TSeritDugmesi>.Create;
    Grup.Panel := TPanel.Create(FKap);
    Grup.Panel.Parent := FKap;
    Grup.Panel.BevelOuter := bvNone;
    Grup.Panel.ShowCaption := False;
    Grup.Etiket := TLabel.Create(Grup.Panel);
    Grup.Etiket.Parent := Grup.Panel;
    Grup.Etiket.Align := alBottom;
    Grup.Etiket.AutoSize := False;
    Grup.Etiket.Alignment := taCenter;
    Grup.Etiket.Layout := tlCenter;
    Grup.Etiket.Height := Olcekle(GRUP_ADI_YUKSEKLIGI);
    { Grup adi kucuk ve gri; rengi stilden gelir, stil yazi rengini ezmesin. }
    Grup.Etiket.StyleElements := [seClient, seBorder];
    Grup.Etiket.Font.Color := StyleServices(Grup.Etiket).GetSystemColor(clGrayText);
    Grup.Etiket.Font.Height := Round(Grup.Etiket.Font.Height * 0.85);
    Grup.Cizgi := TBevel.Create(FKap);
    Grup.Cizgi.Parent := FKap;
    Grup.Cizgi.Shape := bsLeftLine;
    Grup.Cizgi.Width := Olcekle(CIZGI_GENISLIGI);
    FGruplar.Add(Grup);
  end;
  Result := TSeritDugmesi.Create(Grup.Panel, FKoleksiyon, FPPI);
  Result.Parent := Grup.Panel;
  Result.Ayarla(YaziAnahtari, IkonNo);
  Result.OnClick := Tikla;
  Result.OnBoyutDegisti := DugmeBoyutuDegisti;
  Grup.Dugmeler.Add(Result);
end;

procedure TSerit.DugmeBoyutuDegisti(Sender: TObject);
begin
  Duzenle;
end;

procedure TSerit.YazilariYenile;
var
  Grup: TSeritGrubu;
  Dugme: TSeritDugmesi;
begin
  for Grup in FGruplar do
  begin
    Grup.Etiket.Caption := T(Grup.Anahtar);
    for Dugme in Grup.Dugmeler do
      Dugme.YazilariYenile;
  end;
  Duzenle;
end;

{ Gruplari soldan saga dizer. Grup, dugmelerinin toplam genisligi kadar (grup adi
  daha genisse onun kadar) yer kaplar; dugmeler grubun ortasinda durur. }
procedure TSerit.Duzenle;
var
  Grup: TSeritGrubu;
  Dugme: TSeritDugmesi;
  Olcu: TBitmap;
  X, DugmeX, DugmeGenisligi, AdGenisligi, GrupGenisligi, DugmeYuksekligi, Bosluk: Integer;
begin
  Bosluk := Olcekle(KENAR);
  DugmeYuksekligi := 0;
  for Grup in FGruplar do
    for Dugme in Grup.Dugmeler do
      DugmeYuksekligi := Max(DugmeYuksekligi, Dugme.Height);
  FYukseklik := DugmeYuksekligi + Olcekle(GRUP_ADI_YUKSEKLIGI) + Bosluk div 2;
  Olcu := TBitmap.Create;
  X := Bosluk div 2;
  for Grup in FGruplar do
  begin
    DugmeGenisligi := 0;
    for Dugme in Grup.Dugmeler do
      Inc(DugmeGenisligi, Dugme.Width + Olcekle(DUGME_ARASI));
    Olcu.Canvas.Font.Assign(Grup.Etiket.Font);
    AdGenisligi := Olcu.Canvas.TextWidth(Grup.Etiket.Caption) + 2 * Bosluk;
    GrupGenisligi := Max(DugmeGenisligi, AdGenisligi);
    Grup.Panel.SetBounds(X, 0, GrupGenisligi, FYukseklik);
    DugmeX := (GrupGenisligi - DugmeGenisligi) div 2;
    for Dugme in Grup.Dugmeler do
    begin
      Dugme.SetBounds(DugmeX, Bosluk div 4, Dugme.Width, Dugme.Height);
      Inc(DugmeX, Dugme.Width + Olcekle(DUGME_ARASI));
    end;
    Inc(X, GrupGenisligi);
    Grup.Cizgi.SetBounds(X, Bosluk div 2, Olcekle(CIZGI_GENISLIGI), FYukseklik - Bosluk);
    Inc(X, Olcekle(CIZGI_GENISLIGI) + Bosluk div 2);
    { Son grubun sagindaki cizgi gerekmez. }
    Grup.Cizgi.Visible := Grup <> FGruplar.Last;
  end;
  Olcu.Free;
end;

{ Seridin istedigi toplam genislik (pencere bundan darsa serit kesilir). }
function TSerit.Genislik: Integer;
var
  Grup: TSeritGrubu;
begin
  Result := 0;
  if FGruplar.Count > 0 then
  begin
    Grup := FGruplar.Last;
    Result := Grup.Panel.Left + Grup.Panel.Width;
  end;
end;

end.
