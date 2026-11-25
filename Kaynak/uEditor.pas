{ uEditor.pas - SQL editorunun (SynEdit) arkasindaki sarmalayici.

  Formlar ve frame'ler SynEdit'i dogrudan bilmez; TSqlEditor'u kullanir.
  SynEdit, RAD Studio 12'ye GetIt/kurulum ile eklenmis olmalidir; editor kod
  icinde olusturulur (formda tasarim zamani bilesen yok), boylece .dfm dosyalari
  SynEdit paketine bagli kalmaz.
  SQL renklendirme SynEdit'in SQL renklendiricisinin Firebird (InterBase 6)
  ayariyla yapilir.

  Otomatik tamamlama (Ctrl+Bosluk): SynEdit'in TSynCompletionProposal bileseni.
  Oneriler uc yerden gelir:
    1. anahtar_kelimeler.txt (bagli sunucunun surumune gore),
    2. veritabaninin tablo/view/prosedur/generator adlari,
    3. "ad." yazilinca o tablonun kolonlari (ad bir takma ad da olabilir).
  Kolonlari editor kendisi sorgulamaz; KolonGetirici ile sekmeden ister ve saklar. }
unit uEditor;

interface

uses
  Winapi.Windows, System.SysUtils, System.Classes, System.Generics.Collections, Vcl.Controls, Vcl.Graphics, Vcl.ExtCtrls,
  SynEdit, SynEditTypes, SynHighlighterSQL, SynCompletionProposal,
  uDil, uSorgu, uMetadata;

{ Ctrl+/ icin: satirlarin hepsi (bos olanlar haric) "--" ile basliyorsa yorum kaldirilir ("-- " ya da "--"),
  degilse her dolu satirin basina "-- " eklenir. Bos satirlara dokunulmaz. }
function YorumDegistir(const Satirlar: TArray<string>): TArray<string>;

type
  { Tablo adini verir, kolon adlarini Kolonlar'a ekler. Tablo yoksa bos birakir. }
  TKolonGetirici = procedure(const Tablo: string; Kolonlar: TStrings) of object;

  { Sahibi (Ust) yok olunca editor de yok olur. }
  TSqlEditor = class(TComponent)
  private
    FEdit: TSynEdit;
    FRenk: TSynSQLSyn;
    FOneri: TSynCompletionProposal;
    FAnahtarKelimeler: TStringList;
    FNesneAdlari: TStringList;
    FKolonlar: TObjectDictionary<string, TStringList>;
    FHataSatiri: Integer;
    FDurum: TPanel;
    procedure DurumDegisti(Sender: TObject; Changes: TSynStatusChanges);
    procedure HataSatiriRengi(Sender: TObject; Line: Integer; var Special: Boolean; var FG, BG: TColor);
    procedure MetinDegisti(Sender: TObject);
    procedure OneriHazirla(Kind: SynCompletionType; Sender: TObject; var CurrentInput: string;
      var x, y: Integer; var CanExecute: Boolean);
    procedure OneriSecildi(Sender: TObject; var Value: string; Shift: TShiftState; Index: Integer;
      EndToken: WideChar);
    function NoktadanOnceAd: string;
    function TabloKolonlari(const Tablo: string): TStringList;
    procedure TusBasildi(Sender: TObject; var Key: Word; Shift: TShiftState);
  public
    { Kolon onerisi icin gerekli; atanmazsa "ad." yazilinca liste acilmaz. }
    KolonGetirici: TKolonGetirici;
    constructor Create(Ust: TWinControl); reintroduce;
    destructor Destroy; override;
    { Secili yazi varsa sadece onu, yoksa editordeki tum yaziyi verir (F5 bunu calistirir). }
    function CalistirilacakMetin: string;
    { Editordeki tum yazi (secim olsa bile). Prosedur kaydetme bunu kullanir. }
    function TumMetin: string;
    { Imleci verilen satirin basina gogoturur ve gorunur yapar (1 tabanli). }
    procedure SatiraGit(Satir: Integer);
    { Hatali satiri koyu zeminle isaretler ve oraya gider (1 tabanli). Yazi degisince veya
      HataSatiriniTemizle ile isaret kalkar. }
    procedure HataSatiriniIsaretle(Satir: Integer);
    procedure HataSatiriniTemizle;
    procedure OdakVer;
    { Yazi son kaydetmeden (ya da DegisimiSifirla'dan) beri degisti mi? }
    function Degisti: Boolean;
    procedure DegisimiSifirla;
    { Editorun tum yazisini degistirir (calistirmaz). }
    procedure MetinYaz(const Metin: string);
    { Dosya: anahtar_kelimeler.txt yolu. Surum: sunucu surumu ("5.0.4"); bos ise tum kelimeler. }
    procedure AnahtarKelimeleriYukle(const Dosya, Surum: string);
    { Tablo, view, prosedur, generator adlarini oneri listesine koyar. }
    procedure NesneAdlariniVer(Liste: TStrings);
    { Secili satirlari (secim yoksa imlecin satirini) yorum yapar ya da yorumu kaldirir (Ctrl+/). Geri al ile donulur. }
    procedure YorumuDegistir;
  end;

implementation

function YorumDegistir(const Satirlar: TArray<string>): TArray<string>;
var
  i: Integer;
  HepsiYorum: Boolean;
  Satir: string;
begin
  HepsiYorum := False;
  for i := 0 to High(Satirlar) do
    if Trim(Satirlar[i]) <> '' then
    begin
      HepsiYorum := True;
      Break;
    end;
  for i := 0 to High(Satirlar) do
    if (Trim(Satirlar[i]) <> '') and not TrimLeft(Satirlar[i]).StartsWith('--') then
      HepsiYorum := False;
  SetLength(Result, Length(Satirlar));
  for i := 0 to High(Satirlar) do
  begin
    Satir := Satirlar[i];
    if Trim(Satir) = '' then
      Result[i] := Satir
    else if HepsiYorum then
    begin
      { Girintiyi koru: ilk "--" (ve ardindaki tek bosluk) silinir. }
      Result[i] := Copy(Satir, 1, Pos('--', Satir) - 1);
      Satir := Copy(Satir, Pos('--', Satir) + 2, MaxInt);
      if Satir.StartsWith(' ') then
        Satir := Copy(Satir, 2, MaxInt);
      Result[i] := Result[i] + Satir;
    end
    else
      Result[i] := '-- ' + Satir;
  end;
end;

function KimlikKarakteri(C: Char): Boolean;
begin
  Result := CharInSet(C, ['A'..'Z', 'a'..'z', '0'..'9', '_', '$']);
end;

constructor TSqlEditor.Create(Ust: TWinControl);
begin
  inherited Create(Ust);
  FAnahtarKelimeler := TStringList.Create;
  FAnahtarKelimeler.Sorted := True;
  FAnahtarKelimeler.Duplicates := dupIgnore;
  FNesneAdlari := TStringList.Create;
  FNesneAdlari.Sorted := True;
  FNesneAdlari.Duplicates := dupIgnore;
  FKolonlar := TObjectDictionary<string, TStringList>.Create([doOwnsValues]);
  FRenk := TSynSQLSyn.Create(Self);
  FRenk.SQLDialect := sqlInterbase6;
  FEdit := TSynEdit.Create(Self);
  FEdit.Parent := Ust;
  FEdit.Align := alClient;
  FEdit.Font.Name := 'Consolas';
  FEdit.Font.Size := 11;
  FEdit.Gutter.ShowLineNumbers := True;
  FEdit.Gutter.Color := TColor($F0F0F0);
  FEdit.Gutter.BorderColor := TColor($E0DCDA);
  FEdit.Gutter.Font.Color := clGrayText;
  FEdit.ActiveLineColor := TColor($FCF4EC);
  { Editorun altinda ince durum satiri: imlecin satiri ve kolonu. }
  FDurum := TPanel.Create(Self);
  FDurum.Parent := Ust;
  FDurum.Align := alBottom;
  FDurum.Height := 22;
  FDurum.BevelOuter := bvNone;
  FDurum.Alignment := taRightJustify;
  FDurum.ParentBackground := False;
  FDurum.Color := TColor($F0F0F0);
  FDurum.StyleElements := [seBorder];
  FDurum.Caption := TF('EDITOR_KONUM', [1, 1]) + '  ';
  FEdit.OnStatusChange := DurumDegisti;
  FEdit.Highlighter := FRenk;
  FEdit.OnSpecialLineColors := HataSatiriRengi;
  FEdit.OnChange := MetinDegisti;
  FEdit.OnKeyDown := TusBasildi;
  FOneri := TSynCompletionProposal.Create(Self);
  { Ctrl+Bosluk bilesenin varsayilan kisayoludur. '.' yazilinca da kisa beklemeden liste acilir. }
  FOneri.Options := FOneri.Options + [scoUseBuiltInTimer];
  FOneri.TimerInterval := 50;
  FOneri.TriggerChars := '.';
  FOneri.OnExecute := OneriHazirla;
  FOneri.OnCodeCompletion := OneriSecildi;
  FOneri.AddEditor(FEdit);
end;

destructor TSqlEditor.Destroy;
begin
  FKolonlar.Free;
  FNesneAdlari.Free;
  FAnahtarKelimeler.Free;
  inherited;
end;

function TSqlEditor.CalistirilacakMetin: string;
begin
  if FEdit.SelAvail then
    Result := FEdit.SelText
  else
    Result := FEdit.Text;
end;

function TSqlEditor.TumMetin: string;
begin
  Result := FEdit.Text;
end;

procedure TSqlEditor.SatiraGit(Satir: Integer);
begin
  if Satir > FEdit.Lines.Count then
    Satir := FEdit.Lines.Count;
  if Satir < 1 then
    Exit;
  FEdit.CaretY := Satir;
  FEdit.CaretX := 1;
  FEdit.EnsureCursorPosVisible;
  if FEdit.Showing then
    OdakVer;
end;

procedure TSqlEditor.HataSatiriniIsaretle(Satir: Integer);
begin
  FHataSatiri := Satir;
  FEdit.Invalidate;
  SatiraGit(Satir);
end;

procedure TSqlEditor.HataSatiriniTemizle;
begin
  if FHataSatiri = 0 then
    Exit;
  FHataSatiri := 0;
  FEdit.Invalidate;
end;

procedure TSqlEditor.HataSatiriRengi(Sender: TObject; Line: Integer; var Special: Boolean;
  var FG, BG: TColor);
begin
  if (FHataSatiri > 0) and (Line = FHataSatiri) then
  begin
    Special := True;
    FG := clWhite;
    BG := $3C3CC8;
  end;
end;

procedure TSqlEditor.DurumDegisti(Sender: TObject; Changes: TSynStatusChanges);
begin
  if (scCaretX in Changes) or (scCaretY in Changes) then
    FDurum.Caption := TF('EDITOR_KONUM', [FEdit.CaretY, FEdit.CaretX]) + '  ';
end;

procedure TSqlEditor.MetinDegisti(Sender: TObject);
begin
  HataSatiriniTemizle;
end;

procedure TSqlEditor.OdakVer;
begin
  if FEdit.CanFocus then
    FEdit.SetFocus;
end;

function TSqlEditor.Degisti: Boolean;
begin
  Result := FEdit.Modified;
end;

procedure TSqlEditor.DegisimiSifirla;
begin
  FEdit.Modified := False;
end;

procedure TSqlEditor.AnahtarKelimeleriYukle(const Dosya, Surum: string);
begin
  AnahtarKelimeleriOku(Dosya, Surum, FAnahtarKelimeler);
end;

procedure TSqlEditor.MetinYaz(const Metin: string);
begin
  FEdit.Text := Metin;
end;

{ Ctrl+/ (ABD klavyesi), Ctrl+Shift+7 (Turkce ve Almanca klavyede "/" Shift+7'dir) ya da Ctrl + sayi tusu "/".
  Ctrl+Shift+7 SynEdit'te 7. yer imini koyardi; burada yorum isine verildi. }
procedure TSqlEditor.TusBasildi(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  if not (ssCtrl in Shift) or (ssAlt in Shift) then
    Exit;
  if (Key = VK_OEM_2) or (Key = VK_DIVIDE) or ((Key = Ord('7')) and (ssShift in Shift)) then
  begin
    YorumuDegistir;
    Key := 0;
  end;
end;

procedure TSqlEditor.YorumuDegistir;
var
  Bas, Son, i: Integer;
  Satirlar, Yeni: TArray<string>;
  Metin: string;
begin
  if FEdit.ReadOnly or (FEdit.Lines.Count = 0) then
    Exit;
  if FEdit.SelAvail then
  begin
    Bas := FEdit.BlockBegin.Line;
    Son := FEdit.BlockEnd.Line;
    { Secim bir sonraki satirin basinda bitiyorsa o satir dahil edilmez. }
    if (FEdit.BlockEnd.Char = 1) and (Son > Bas) then
      Dec(Son);
  end
  else
  begin
    Bas := FEdit.CaretY;
    Son := Bas;
  end;
  if Son > FEdit.Lines.Count then
    Son := FEdit.Lines.Count;
  SetLength(Satirlar, Son - Bas + 1);
  for i := Bas to Son do
    Satirlar[i - Bas] := FEdit.Lines[i - 1];
  Yeni := YorumDegistir(Satirlar);
  Metin := string.Join(sLineBreak, Yeni);
  { Satirlari secip yerine yazmak Geri al (Ctrl+Z) ile tek adimda donulebilir kalir. }
  FEdit.BlockBegin := BufferCoord(1, Bas);
  FEdit.BlockEnd := BufferCoord(Length(FEdit.Lines[Son - 1]) + 1, Son);
  FEdit.SelText := Metin;
  FEdit.BlockBegin := BufferCoord(1, Bas);
  FEdit.BlockEnd := BufferCoord(Length(Yeni[High(Yeni)]) + 1, Son);
end;

procedure TSqlEditor.NesneAdlariniVer(Liste: TStrings);
begin
  FNesneAdlari.Clear;
  FNesneAdlari.AddStrings(Liste);
end;

{ Imlecin hemen onundeki "ad." icindeki ad'i verir (imlecle nokta arasindaki yarim yazi atlanir).
  Nokta yoksa bos doner. }
function TSqlEditor.NoktadanOnceAd: string;
var
  Satir: string;
  Sira, Bitis: Integer;
begin
  Result := '';
  Satir := FEdit.LineText;
  Sira := FEdit.CaretX - 1;
  if Sira > Length(Satir) then
    Sira := Length(Satir);
  while (Sira >= 1) and KimlikKarakteri(Satir[Sira]) do
    Dec(Sira);
  if (Sira < 2) or (Satir[Sira] <> '.') then
    Exit;
  Dec(Sira);
  Bitis := Sira;
  while (Sira >= 1) and KimlikKarakteri(Satir[Sira]) do
    Dec(Sira);
  Result := Copy(Satir, Sira + 1, Bitis - Sira);
end;

{ Tablonun kolonlarini bir kez ister, sonra saklar (bulunamayan tablo icin bos liste saklanir). }
function TSqlEditor.TabloKolonlari(const Tablo: string): TStringList;
begin
  if not FKolonlar.TryGetValue(Tablo, Result) then
  begin
    Result := TStringList.Create;
    if Assigned(KolonGetirici) then
      KolonGetirici(Tablo, Result);
    FKolonlar.Add(Tablo, Result);
  end;
end;

{ Liste acilmadan hemen once: "ad." varsa kolonlar, yoksa anahtar kelimeler ve nesne adlari. }
procedure TSqlEditor.OneriHazirla(Kind: SynCompletionType; Sender: TObject; var CurrentInput: string;
  var x, y: Integer; var CanExecute: Boolean);
var
  Ad: string;
  Kolonlar: TStringList;
begin
  FOneri.ItemList.Clear;
  Ad := NoktadanOnceAd;
  if Ad <> '' then
  begin
    if not CharInSet(Ad[1], ['A'..'Z', 'a'..'z', '_']) then
    begin
      CanExecute := False;
      Exit;
    end;
    Kolonlar := TabloKolonlari(TabloAdiniBul(FEdit.Text, Ad));
    FOneri.ItemList.AddStrings(Kolonlar);
  end
  else
  begin
    FOneri.ItemList.AddStrings(FAnahtarKelimeler);
    FOneri.ItemList.AddStrings(FNesneAdlari);
  end;
  CanExecute := FOneri.ItemList.Count > 0;
end;

{ Anahtar kelime secilince buyuk harfle yazilir; nesne ve kolon adlari oldugu gibi kalir. }
procedure TSqlEditor.OneriSecildi(Sender: TObject; var Value: string; Shift: TShiftState; Index: Integer;
  EndToken: WideChar);
begin
  if (NoktadanOnceAd = '') and (FNesneAdlari.IndexOf(Value) < 0) and (FAnahtarKelimeler.IndexOf(Value) >= 0) then
    Value := UpperCase(Value);
end;

end.
