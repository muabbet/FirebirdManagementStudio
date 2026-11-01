{ fTabloListe.pas - "Tablolar" listesi sekmesi: bir veritabaninin tum tablolari liste halinde (ad, alan sayisi, aciklama).
  Basliga tiklayinca o kolona gore siralar (tekrar tiklayinca ters yon). Listede bir tabloya tiklayinca altta alanlari
  (kolonlari) gorunur; bu ayrinti bolumu Gorunum sekmesindeki dugmeyle acilip kapanir. Cift tiklayinca tablo kendi
  sekmesinde acilir. Sekme yalniz arayuzu bilir; veriyi uMetadata okur. }
unit fTabloListe;

interface

uses
  System.SysUtils, System.Classes, System.StrUtils, Vcl.Controls, Vcl.Forms, Vcl.ExtCtrls, Vcl.StdCtrls,
  Vcl.ComCtrls,
  uDil, uBaglanti, uMetadata;

type
  TTabloListeSekme = class(TFrame)
    lvTablolar: TListView;
    Bolucu: TSplitter;
    pnlAyrinti: TPanel;
    lblAyrinti: TLabel;
    lvAlanlar: TListView;
    procedure lvTablolarColumnClick(Sender: TObject; Column: TListColumn);
    procedure lvTablolarCompare(Sender: TObject; Item1, Item2: TListItem; Data: Integer; var Compare: Integer);
    procedure lvTablolarSelectItem(Sender: TObject; Item: TListItem; Selected: Boolean);
    procedure lvTablolarDblClick(Sender: TObject);
    procedure lvAlanlarColumnClick(Sender: TObject; Column: TListColumn);
    procedure lvAlanlarCompare(Sender: TObject; Item1, Item2: TListItem; Data: Integer; var Compare: Integer);
  private
    FTabloKolon: Integer;
    FTabloArtan: Boolean;
    FAlanKolon: Integer;
    FAlanArtan: Boolean;
    FSeciliTablo: string;
    procedure BasliklariYaz;
    procedure AlanlariGoster(const Tablo: string);
  public
    BaglantiAd: string;
    { Cift tiklayinca tabloyu acar; ana pencere atar. }
    TabloAc: TProc<string>;
    procedure Yukle(Bag: TAcikBaglanti);
    { Listeyi ve secili tablonun alanlarini veritabanindan yeniden okur. }
    procedure Yenile;
    procedure AyrintiAyarla(Goster: Boolean);
    function AyrintiAcik: Boolean;
    procedure YazilariYenile;
  end;

implementation

{$R *.dfm}

const
  { Siralama oklari: #$25B2 yukari ucgen, #$25BC asagi ucgen. }
  OK_ARTAN = ' '#$25B2;
  OK_AZALAN = ' '#$25BC;

procedure TTabloListeSekme.Yukle(Bag: TAcikBaglanti);
begin
  BaglantiAd := Bag.Tanim.Ad;
  FTabloKolon := 0;
  FTabloArtan := True;
  FAlanKolon := 0;
  FAlanArtan := True;
  Yenile;
end;

procedure TTabloListeSekme.Yenile;
var
  Bag: TAcikBaglanti;
  Ozet: TTabloOzeti;
  Satir: TListItem;
  Eski: string;
begin
  Bag := FbAcikBaglanti(BaglantiAd);
  if Bag = nil then
    Exit;
  Eski := FSeciliTablo;
  lvTablolar.Items.BeginUpdate;
  try
    lvTablolar.Items.Clear;
    for Ozet in TabloOzetleriniOku(Bag) do
    begin
      Satir := lvTablolar.Items.Add;
      Satir.Caption := Ozet.Ad;
      Satir.SubItems.Add(IntToStr(Ozet.AlanSayisi));
      Satir.SubItems.Add(Ozet.Aciklama);
    end;
    lvTablolar.CustomSort(nil, FTabloKolon);
  finally
    lvTablolar.Items.EndUpdate;
  end;
  BasliklariYaz;
  { Yenileme sonrasi onceki secim korunur. }
  FSeciliTablo := '';
  lvAlanlar.Items.Clear;
  lblAyrinti.Caption := '';
  Satir := lvTablolar.FindCaption(0, Eski, False, True, False);
  if Satir <> nil then
  begin
    Satir.Selected := True;
    Satir.MakeVisible(False);
  end;
end;

procedure TTabloListeSekme.AyrintiAyarla(Goster: Boolean);
begin
  pnlAyrinti.Visible := Goster;
  Bolucu.Visible := Goster;
end;

function TTabloListeSekme.AyrintiAcik: Boolean;
begin
  Result := pnlAyrinti.Visible;
end;

procedure TTabloListeSekme.YazilariYenile;
begin
  BasliklariYaz;
  if FSeciliTablo <> '' then
    lblAyrinti.Caption := TF('LISTE_ALANLAR', [FSeciliTablo, lvAlanlar.Items.Count]);
end;

{ Baslik yazilari secili dilden yazilir; siralanan kolonun yanina ok konur. }
procedure TTabloListeSekme.BasliklariYaz;
const
  TabloBasliklari: array[0..2] of string = ('LISTE_SUTUN_TABLO', 'LISTE_SUTUN_ALAN_SAYISI', 'LISTE_SUTUN_ACIKLAMA');
  AlanBasliklari: array[0..4] of string = ('LISTE_SUTUN_SIRA', 'LISTE_SUTUN_ALAN', 'LISTE_SUTUN_TIP',
    'LISTE_SUTUN_BOS_OLABILIR', 'LISTE_SUTUN_VARSAYILAN');
var
  i: Integer;
  Ok: string;
begin
  for i := 0 to 2 do
  begin
    Ok := '';
    if i = FTabloKolon then
      Ok := IfThen(FTabloArtan, OK_ARTAN, OK_AZALAN);
    lvTablolar.Columns[i].Caption := T(TabloBasliklari[i]) + Ok;
  end;
  for i := 0 to 4 do
  begin
    Ok := '';
    if i = FAlanKolon then
      Ok := IfThen(FAlanArtan, OK_ARTAN, OK_AZALAN);
    lvAlanlar.Columns[i].Caption := T(AlanBasliklari[i]) + Ok;
  end;
end;

{ Sutun degeri: 0 = ad (Caption), digerleri SubItems. }
function DegerAl(Satir: TListItem; Kolon: Integer): string;
begin
  if Kolon = 0 then
    Result := Satir.Caption
  else
    Result := Satir.SubItems[Kolon - 1];
end;

procedure TTabloListeSekme.lvTablolarColumnClick(Sender: TObject; Column: TListColumn);
begin
  if Column.Index = FTabloKolon then
    FTabloArtan := not FTabloArtan
  else
  begin
    FTabloKolon := Column.Index;
    FTabloArtan := True;
  end;
  lvTablolar.CustomSort(nil, FTabloKolon);
  BasliklariYaz;
end;

{ "Alan sayisi" (kolon 1) sayi olarak, digerleri yazi olarak karsilastirilir. }
procedure TTabloListeSekme.lvTablolarCompare(Sender: TObject; Item1, Item2: TListItem; Data: Integer;
  var Compare: Integer);
begin
  if Data = 1 then
    Compare := StrToIntDef(DegerAl(Item1, Data), 0) - StrToIntDef(DegerAl(Item2, Data), 0)
  else
    Compare := CompareText(DegerAl(Item1, Data), DegerAl(Item2, Data));
  if not FTabloArtan then
    Compare := -Compare;
end;

procedure TTabloListeSekme.lvAlanlarColumnClick(Sender: TObject; Column: TListColumn);
begin
  if Column.Index = FAlanKolon then
    FAlanArtan := not FAlanArtan
  else
  begin
    FAlanKolon := Column.Index;
    FAlanArtan := True;
  end;
  lvAlanlar.CustomSort(nil, FAlanKolon);
  BasliklariYaz;
end;

procedure TTabloListeSekme.lvAlanlarCompare(Sender: TObject; Item1, Item2: TListItem; Data: Integer;
  var Compare: Integer);
begin
  { Sira (kolon 0) sayi olarak, digerleri yazi olarak karsilastirilir. }
  if Data = 0 then
    Compare := StrToIntDef(DegerAl(Item1, Data), 0) - StrToIntDef(DegerAl(Item2, Data), 0)
  else
    Compare := CompareText(DegerAl(Item1, Data), DegerAl(Item2, Data));
  if not FAlanArtan then
    Compare := -Compare;
end;

procedure TTabloListeSekme.lvTablolarSelectItem(Sender: TObject; Item: TListItem; Selected: Boolean);
begin
  if Selected and (Item <> nil) then
    AlanlariGoster(Item.Caption);
end;

{ Secili tablonun alanlari: ilk kolon alanin veritabanindaki sirasi (1, 2, 3 ...), liste de bu sirayla gelir; basliga tiklayinca siralama degisir, Sira basligina tiklayinca ilk haline doner. }
procedure TTabloListeSekme.AlanlariGoster(const Tablo: string);
var
  Bag: TAcikBaglanti;
  Kolon: TKolonBilgisi;
  Satir: TListItem;
  TipMetni: string;
  Sira: Integer;
begin
  FSeciliTablo := Tablo;
  lvAlanlar.Items.Clear;
  FAlanKolon := 0;
  FAlanArtan := True;
  Bag := FbAcikBaglanti(BaglantiAd);
  if Bag = nil then
    Exit;
  lvAlanlar.Items.BeginUpdate;
  try
    Sira := 0;
    for Kolon in KolonlariOku(Bag, Tablo) do
    begin
      Inc(Sira);
      if Kolon.Hesaplanan <> '' then
        TipMetni := 'COMPUTED BY ' + Kolon.Hesaplanan
      else if Kolon.Domain <> '' then
        TipMetni := Kolon.Domain
      else
        TipMetni := Kolon.Tip;
      Satir := lvAlanlar.Items.Add;
      Satir.Caption := IntToStr(Sira);
      Satir.SubItems.Add(Kolon.Ad);
      Satir.SubItems.Add(TipMetni);
      Satir.SubItems.Add(IfThen(Kolon.BosOlmaz, T('LISTE_HAYIR'), T('LISTE_EVET')));
      Satir.SubItems.Add(Kolon.Varsayilan);
    end;
  finally
    lvAlanlar.Items.EndUpdate;
  end;
  lblAyrinti.Caption := TF('LISTE_ALANLAR', [Tablo, lvAlanlar.Items.Count]);
  BasliklariYaz;
end;

procedure TTabloListeSekme.lvTablolarDblClick(Sender: TObject);
begin
  if Assigned(TabloAc) and (lvTablolar.Selected <> nil) then
    TabloAc(lvTablolar.Selected.Caption);
end;

end.
