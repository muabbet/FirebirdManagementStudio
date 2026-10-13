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
  System.SysUtils, System.Classes, System.Generics.Collections, Vcl.Controls, Vcl.Graphics,
  SynEdit, SynHighlighterSQL, SynCompletionProposal,
  uSorgu, uMetadata;

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
    procedure OneriHazirla(Kind: SynCompletionType; Sender: TObject; var CurrentInput: string;
      var x, y: Integer; var CanExecute: Boolean);
    procedure OneriSecildi(Sender: TObject; var Value: string; Shift: TShiftState; Index: Integer;
      EndToken: WideChar);
    function NoktadanOnceAd: string;
    function TabloKolonlari(const Tablo: string): TStringList;
  public
    { Kolon onerisi icin gerekli; atanmazsa "ad." yazilinca liste acilmaz. }
    KolonGetirici: TKolonGetirici;
    constructor Create(Ust: TWinControl); reintroduce;
    destructor Destroy; override;
    { Secili yazi varsa sadece onu, yoksa editordeki tum yaziyi verir (F5 bunu calistirir). }
    function CalistirilacakMetin: string;
    procedure OdakVer;
    { Editorun tum yazisini degistirir (calistirmaz). }
    procedure MetinYaz(const Metin: string);
    { Dosya: anahtar_kelimeler.txt yolu. Surum: sunucu surumu ("5.0.4"); bos ise tum kelimeler. }
    procedure AnahtarKelimeleriYukle(const Dosya, Surum: string);
    { Tablo, view, prosedur, generator adlarini oneri listesine koyar. }
    procedure NesneAdlariniVer(Liste: TStrings);
  end;

implementation

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
  FEdit.Highlighter := FRenk;
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

procedure TSqlEditor.OdakVer;
begin
  if FEdit.CanFocus then
    FEdit.SetFocus;
end;

procedure TSqlEditor.AnahtarKelimeleriYukle(const Dosya, Surum: string);
begin
  AnahtarKelimeleriOku(Dosya, Surum, FAnahtarKelimeler);
end;

procedure TSqlEditor.MetinYaz(const Metin: string);
begin
  FEdit.Text := Metin;
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
