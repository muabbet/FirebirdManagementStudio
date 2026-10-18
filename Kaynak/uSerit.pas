{ uSerit.pas - Ust sasedeki sekmeli serit (ribbon). Ucuncu parti bilesen yok, yalniz standart VCL.

  Ustte sekme satiri (her grup bir sekme), altinda secili sekmenin dugmeleri:
  buyuk ikon ustte, yazi altta. Dugmenin genisligi yaziya gore uzar; cok uzun
  yazi iki satira bolunur. Dugmeler ve gruplar fAna.pas'ta Ekle ile siralanir, o
  siralama seridin tam tanimidir. Gizli sekmenin dugmeleri de vardir; Enabled
  durumlari fAna.DurumuGuncelle'den aynen guncellenir.

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

  { Sekme satirindaki tek sekme: yazi, secili ise altinda vurgu cizgisi. OnClick'i TSerit'e baglidir. }
  TSeritSekmesi = class(TGraphicControl)
  private
    FSecili: Boolean;
    FUzerinde: Boolean;
    FBosluk: Integer;
    FCizgiKalinligi: Integer;
    procedure SeciliAyarla(Deger: Boolean);
    procedure CMMouseEnter(var Mesaj: TMessage); message CM_MOUSEENTER;
    procedure CMMouseLeave(var Mesaj: TMessage); message CM_MOUSELEAVE;
  protected
    procedure Paint; override;
  public
    constructor Create(AOwner: TComponent; PPI: Integer); reintroduce;
    procedure YaziyiYaz(const Yazi: string);
    property Secili: Boolean read FSecili write SeciliAyarla;
  end;

  { Bir grup = bir sekme: sekme satirindaki yazisi, kendi paneli ve dugmeleri. }
  TSeritGrubu = class
    Anahtar: string;
    Panel: TPanel;
    Sekme: TSeritSekmesi;
    Dugmeler: TList<TSeritDugmesi>;
  end;

  TSerit = class
  private
    FKap: TPanel;
    FKoleksiyon: TImageCollection;
    FGruplar: TObjectList<TSeritGrubu>;
    FPPI: Integer;
    FYukseklik: Integer;
    FGenislik: Integer;
    FSeciliSekme: Integer;
    function Olcekle(Deger: Integer): Integer;
    function GrupBul(const Anahtar: string): TSeritGrubu;
    procedure DugmeBoyutuDegisti(Sender: TObject);
    procedure SekmeTiklandi(Sender: TObject);
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
    { Sekme secer (0 = ilk grup). Varsayilan ilk sekme; program acik kaldikca secim korunur. }
    procedure SekmeSec(No: Integer);
    function Genislik: Integer;
    property Yukseklik: Integer read FYukseklik;
  end;

implementation

const
  KENAR = 8;
  IKON_BOYU = 32;
  YAZI_GENISLIGI = 100;
  DUGME_ARASI = 2;

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

{ ---------- TSeritSekmesi ---------- }

constructor TSeritSekmesi.Create(AOwner: TComponent; PPI: Integer);
begin
  inherited Create(AOwner);
  FBosluk := MulDiv(KENAR, PPI, 96);
  FCizgiKalinligi := MulDiv(3, PPI, 96);
  Cursor := crHandPoint;
end;

procedure TSeritSekmesi.SeciliAyarla(Deger: Boolean);
begin
  if FSecili <> Deger then
  begin
    FSecili := Deger;
    Invalidate;
  end;
end;

{ Yaziyi yazar, genisligi yaziya gore ayarlar. }
procedure TSeritSekmesi.YaziyiYaz(const Yazi: string);
begin
  Caption := Yazi;
  Canvas.Font.Assign(Font);
  Width := Canvas.TextWidth(Yazi) + 3 * FBosluk;
  Height := Canvas.TextHeight('Ag') + FBosluk + FCizgiKalinligi;
  Invalidate;
end;

procedure TSeritSekmesi.Paint;
var
  Servis: TCustomStyleServices;
  Alan: TRect;
begin
  Servis := StyleServices(Self);
  if FUzerinde and not FSecili then
    Servis.DrawElement(Canvas.Handle, Servis.GetElementDetails(tbPushButtonHot), ClientRect);
  Canvas.Font.Assign(Font);
  Canvas.Font.Color := Servis.GetSystemColor(clWindowText);
  Canvas.Brush.Style := bsClear;
  SetBkMode(Canvas.Handle, TRANSPARENT);
  Alan := Rect(0, FBosluk div 4, Width, Height - FCizgiKalinligi);
  DrawText(Canvas.Handle, PChar(Caption), -1, Alan, DT_CENTER or DT_VCENTER or DT_SINGLELINE or DT_NOPREFIX);
  { Secili sekmenin altinda vurgu rengiyle kalin cizgi. }
  if FSecili then
  begin
    Canvas.Brush.Color := Servis.GetSystemColor(clHighlight);
    Canvas.Brush.Style := bsSolid;
    Canvas.FillRect(Rect(FBosluk div 2, Height - FCizgiKalinligi, Width - FBosluk div 2, Height));
  end;
end;

procedure TSeritSekmesi.CMMouseEnter(var Mesaj: TMessage);
begin
  inherited;
  FUzerinde := True;
  Invalidate;
end;

procedure TSeritSekmesi.CMMouseLeave(var Mesaj: TMessage);
begin
  inherited;
  FUzerinde := False;
  Invalidate;
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
    Grup.Sekme := TSeritSekmesi.Create(FKap, FPPI);
    Grup.Sekme.Parent := FKap;
    Grup.Sekme.Tag := FGruplar.Count;
    Grup.Sekme.OnClick := SekmeTiklandi;
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

procedure TSerit.SekmeTiklandi(Sender: TObject);
begin
  SekmeSec(TComponent(Sender).Tag);
end;

{ Yalniz secili sekmenin dugmeleri gorunur. Gizli dugmelerin Enabled durumu degismez. }
procedure TSerit.SekmeSec(No: Integer);
var
  i: Integer;
begin
  if (No < 0) or (No >= FGruplar.Count) then
    Exit;
  FSeciliSekme := No;
  for i := 0 to FGruplar.Count - 1 do
  begin
    FGruplar[i].Panel.Visible := i = FSeciliSekme;
    FGruplar[i].Sekme.Secili := i = FSeciliSekme;
  end;
end;

procedure TSerit.YazilariYenile;
var
  Grup: TSeritGrubu;
  Dugme: TSeritDugmesi;
begin
  for Grup in FGruplar do
  begin
    Grup.Sekme.YaziyiYaz(T(Grup.Anahtar));
    for Dugme in Grup.Dugmeler do
      Dugme.YazilariYenile;
  end;
  Duzenle;
end;

{ Ustte sekme satiri, altinda secili grubun dugmeleri. Her grup kendi panelinde,
  hepsi ayni yerde ust uste durur; yalniz secili olan gorunur. }
procedure TSerit.Duzenle;
var
  Grup: TSeritGrubu;
  Dugme: TSeritDugmesi;
  X, DugmeGenisligi, DugmeYuksekligi, SekmeYuksekligi, Bosluk: Integer;
begin
  Bosluk := Olcekle(KENAR);
  DugmeYuksekligi := 0;
  SekmeYuksekligi := 0;
  for Grup in FGruplar do
  begin
    SekmeYuksekligi := Max(SekmeYuksekligi, Grup.Sekme.Height);
    for Dugme in Grup.Dugmeler do
      DugmeYuksekligi := Max(DugmeYuksekligi, Dugme.Height);
  end;
  FYukseklik := SekmeYuksekligi + DugmeYuksekligi + Bosluk div 2;
  FGenislik := 0;
  X := Bosluk div 2;
  for Grup in FGruplar do
  begin
    Grup.Sekme.SetBounds(X, 0, Grup.Sekme.Width, SekmeYuksekligi);
    Inc(X, Grup.Sekme.Width);
    DugmeGenisligi := 0;
    for Dugme in Grup.Dugmeler do
    begin
      Dugme.SetBounds(DugmeGenisligi, Bosluk div 4, Dugme.Width, Dugme.Height);
      Inc(DugmeGenisligi, Dugme.Width + Olcekle(DUGME_ARASI));
    end;
    Grup.Panel.SetBounds(Bosluk div 2, SekmeYuksekligi, DugmeGenisligi, DugmeYuksekligi + Bosluk div 2);
    FGenislik := Max(FGenislik, Grup.Panel.Left + DugmeGenisligi);
  end;
  FGenislik := Max(FGenislik, X);
  SekmeSec(FSeciliSekme);
end;

{ Seridin en genis halinin genisligi (en genis sekme ya da sekme satiri). }
function TSerit.Genislik: Integer;
begin
  Result := FGenislik;
end;

end.
