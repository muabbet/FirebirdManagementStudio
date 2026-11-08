{ uSonucGrid.pas - Sonuc izgarasinin davranislari (standart TDBGrid uzerine).

  Alti ozellik, bu unit'teki TSonucGrid ile bir TDBGrid'e eklenir:
    1. Baslika tiklayinca siralama (tekrar tiklayinca ters siralama)
    2. Satirlarda bir acik, bir koyu renk (zebra)
    3. NULL degerler gri ve egik yazi ile
    4. Kolon genisligi icerige gore (ilk satirlara bakar)
    5. Ctrl+C: Ctrl+tikla secilen satirlar, secim yoksa aktif hucre kopyalanir
       (sekmeyle ayrili, Excel'e yapistirilabilir)
    6. Uzun yazi ve BLOB kisaltilir, cift tiklayinca tamami acilir

  Kullanim: TSonucGrid.Create(Grid) bir kez; her yeni sonuc verisetine
  baglandiktan sonra YeniSonuc cagrilir. }
unit uSonucGrid;

interface

uses
  System.SysUtils, System.Classes, System.Types, System.Math, System.Variants, Data.DB,
  Winapi.Windows, Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Grids, Vcl.DBGrids,
  Vcl.Clipbrd,
  FireDAC.Comp.DataSet,
  uDil, fMetinGoster;

type
  { Baslik tiklaninca sirayi sunucuya yaptirmak icin: Alan kolon adi, Azalan ise Z-A. }
  TSunucuSirala = procedure(const Alan: string; Azalan: Boolean) of object;

  { Grid sahibidir: grid yok olunca bu nesne de yok olur. }
  TSonucGrid = class(TComponent)
  private
    FGrid: TDBGrid;
    FSiraAlan: string;
    FAzalan: Boolean;
    FDuzenleme: Boolean;
    procedure BaslikTik(Column: TColumn);
    procedure HucreCiz(Sender: TObject; const Rect: TRect; DataCol: Integer;
      Column: TColumn; State: TGridDrawState);
    procedure TusBas(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure CiftTik(Sender: TObject);
    procedure BasliklariYaz;
    procedure KolonGenisliginiAyarla;
    procedure SecimiKopyala;
  public
    { Doluysa baslik tiklayinca (duzenleme kapaliyken) siralama bu olaya birakilir: sonucu sunucuda
      siralayip YeniSonuc(Alan, Azalan) ile geri verir. Bos ise yuklenen satirlar grid icinde siralanir. }
    OnSunucuSirala: TSunucuSirala;
    constructor Create(Grid: TDBGrid); reintroduce;
    { SiraAlan: sonuc zaten o kolona gore sirali geldiyse basliga ok koymak icin. }
    procedure YeniSonuc(const SiraAlan: string = ''; Azalan: Boolean = False);
    { Kayit duzeltme kipi (Asama 4d, bkz. uKayitDuzelt): hucre yazilabilir, degisen hucreler sari. }
    procedure Duzenle(Ac: Boolean);
  end;

implementation

type
  { DefaultRowHeight korumalidir; satir yuksekligini ayarlamak icin tek amacli erisim. }
  TGridErisim = class(TDBGrid);

const
  KISA_UZUNLUK = 100;
  OTO_GENISLIK_SATIR = 50;
  EN_AZ_GENISLIK = 60;
  EN_COK_GENISLIK = 400;
  YUKARI_OK = #$25B2;
  ASAGI_OK = #$25BC;
  { Gorunum (SSMS gibi). Sayilari saga dayamak icin SAYI_SAGA'yi True yapmak yeter. }
  SAYI_SAGA = False;
  RENK_CIZGI = $E0DCDA;
  RENK_BASLIK = $F0F0F0;
  RENK_ZEBRA = $FCF9F7;
  RENK_SECIM = $F7E4CC;
  RENK_DEGISTI = $B3F0FF;
  RENK_YENI = $CCF0CC;

function MemoMu(Alan: TField): Boolean;
begin
  Result := Alan.DataType in [ftMemo, ftWideMemo, ftFmtMemo];
end;

function TekSatir(const Metin: string): string;
begin
  Result := StringReplace(Metin, #13#10, ' ', [rfReplaceAll]);
  Result := StringReplace(Result, #10, ' ', [rfReplaceAll]);
  Result := StringReplace(Result, #13, ' ', [rfReplaceAll]);
end;

{ Hucrede gorunen kisa yazi (NULL olmayan alan icin). }
function HucreMetni(Alan: TField): string;
begin
  if Alan.IsBlob and not MemoMu(Alan) then
  begin
    Result := TF('GRID_BLOB', [TBlobField(Alan).BlobSize]);
    Exit;
  end;
  if Alan.IsBlob then
    Result := Alan.AsString
  else
    Result := Alan.DisplayText;
  Result := TekSatir(Result);
  if Length(Result) > KISA_UZUNLUK then
    Result := Copy(Result, 1, KISA_UZUNLUK) + '...';
end;

{ Cift tiklayinca acilan pencerenin yazisi: kisaltilmamis tam deger.
  Ikili BLOB icin ilk 1024 bayt onaltilik yazilir. }
function HucreTamMetni(Alan: TField): string;
var
  Bayt: TBytes;
  i, Boy: Integer;
begin
  if Alan.IsNull then
    Exit('NULL');
  if Alan.IsBlob and not MemoMu(Alan) then
  begin
    Bayt := TBlobField(Alan).AsBytes;
    Boy := Min(Length(Bayt), 1024);
    Result := TF('GRID_BLOB', [Length(Bayt)]) + #13#10;
    for i := 0 to Boy - 1 do
      Result := Result + IntToHex(Bayt[i], 2) + ' ';
    if Length(Bayt) > Boy then
      Result := Result + #13#10 + TF('GRID_BLOB_ILK', [Boy]);
  end
  else if Alan.IsBlob then
    Result := Alan.AsString
  else
    Result := Alan.DisplayText;
end;

{ Excel'e yapistirilacak tek hucre: NULL bos, sekme/satir sonu/tirnak varsa tirnaga alinir. }
function KopyaMetni(Alan: TField): string;
begin
  if (Alan = nil) or Alan.IsNull then
    Exit('');
  if Alan.IsBlob and not MemoMu(Alan) then
    Exit(HucreMetni(Alan));
  Result := Alan.AsString;
  if (Pos(#9, Result) > 0) or (Pos(#10, Result) > 0) or (Pos(#13, Result) > 0) or
    (Pos('"', Result) > 0) then
    Result := '"' + StringReplace(Result, '"', '""', [rfReplaceAll]) + '"';
end;

constructor TSonucGrid.Create(Grid: TDBGrid);
begin
  inherited Create(Grid);
  FGrid := Grid;
  FGrid.ReadOnly := True;
  FGrid.DefaultDrawing := False;
  FGrid.Options := FGrid.Options + [dgTitles, dgTitleClick, dgIndicator, dgMultiSelect] - [dgRowLines, dgColLines];
  { Cizgileri ve renkleri biz ciziyoruz; VCL Style hucre zeminini ezmesin. }
  FGrid.StyleElements := [seBorder];
  FGrid.Font.Name := 'Segoe UI';
  FGrid.Font.Size := 9;
  FGrid.TitleFont.Assign(FGrid.Font);
  FGrid.FixedColor := RENK_BASLIK;
  FGrid.Canvas.Font.Assign(FGrid.Font);
  TGridErisim(FGrid).DefaultRowHeight := FGrid.Canvas.TextHeight('Wg') + 6;
  FGrid.OnTitleClick := BaslikTik;
  FGrid.OnDrawColumnCell := HucreCiz;
  FGrid.OnKeyDown := TusBas;
  FGrid.OnDblClick := CiftTik;
end;

{ Yeni sonuc verisetine baglandiktan sonra cagrilir: kolonlar yeniden kurulur. }
procedure TSonucGrid.YeniSonuc(const SiraAlan: string; Azalan: Boolean);
begin
  FSiraAlan := SiraAlan;
  FAzalan := Azalan;
  FGrid.Columns.State := csDefault;
  BasliklariYaz;
  KolonGenisliginiAyarla;
end;

procedure TSonucGrid.Duzenle(Ac: Boolean);
begin
  FDuzenleme := Ac;
  FGrid.ReadOnly := not Ac;
  if Ac then
    FGrid.Options := FGrid.Options + [dgEditing]
  else
    FGrid.Options := FGrid.Options - [dgEditing];
  FGrid.Invalidate;
end;

{ ---------- 1. Siralama ---------- }

procedure TSonucGrid.BasliklariYaz;
var
  i: Integer;
  Kolon: TColumn;
  Yazi: string;
begin
  for i := 0 to FGrid.Columns.Count - 1 do
  begin
    Kolon := FGrid.Columns[i];
    Yazi := Kolon.FieldName;
    if Kolon.Field <> nil then
      Yazi := Kolon.Field.DisplayLabel;
    Kolon.Title.Caption := Yazi;
    Kolon.Title.Color := RENK_BASLIK;
    Kolon.Title.Font.Assign(FGrid.Font);
    Kolon.Title.Font.Color := clWindowText;
    Kolon.Title.Font.Style := [];
    if SameText(Kolon.FieldName, FSiraAlan) then
    begin
      if FAzalan then
        Kolon.Title.Caption := Yazi + ' ' + ASAGI_OK
      else
        Kolon.Title.Caption := Yazi + ' ' + YUKARI_OK;
    end;
  end;
end;

{ Siralama, simdiye kadar yuklenen satirlar uzerinde yapilir; sonradan gelen
  satirlar da sirali yere girer. }
procedure TSonucGrid.BaslikTik(Column: TColumn);
var
  Veri: TFDDataSet;
  Alan: TField;
  Yeni: string;
  Z: Boolean;
begin
  if (FGrid.DataSource = nil) or not (FGrid.DataSource.DataSet is TFDDataSet) then
    Exit;
  Veri := TFDDataSet(FGrid.DataSource.DataSet);
  Alan := Column.Field;
  if (Alan = nil) or Alan.IsBlob or (Alan.FieldKind <> fkData) then
    Exit;
  if SameText(FSiraAlan, Alan.FieldName) then
    FAzalan := not FAzalan
  else
  begin
    FSiraAlan := Alan.FieldName;
    FAzalan := False;
  end;
  if Assigned(OnSunucuSirala) and not FDuzenleme then
  begin
    { Sonuc degisecek, bu tiklama olayi bitmeden grid kolonlari yikilmasin: is sirada bekletilir. }
    Yeni := Alan.FieldName;
    Z := FAzalan;
    TThread.ForceQueue(nil,
      procedure
      begin
        OnSunucuSirala(Yeni, Z);
      end);
    Exit;
  end;
  if FAzalan then
    Veri.IndexFieldNames := Alan.FieldName + ':D'
  else
    Veri.IndexFieldNames := Alan.FieldName;
  BasliklariYaz;
end;

{ ---------- 2, 3, 6. Hucre cizimi: zebra, NULL, kisaltma ---------- }

procedure TSonucGrid.HucreCiz(Sender: TObject; const Rect: TRect; DataCol: Integer;
  Column: TColumn; State: TGridDrawState);
var
  Alan: TField;
  Alani: TRect;
  Metin: string;
  Bicim: TTextFormat;
  Secili: Boolean;
begin
  Alan := Column.Field;
  if Alan = nil then
    Exit;
  { Sonuc bos: DBGrid yine de bir satir cizer, bunu bos ve beyaz birak (sahte "NULL" satiri olmasin). }
  if Alan.DataSet.IsEmpty then
  begin
    FGrid.Canvas.Brush.Color := clWindow;
    FGrid.Canvas.FillRect(Rect);
    Exit;
  end;
  Secili :=(gdSelected in State) or FGrid.SelectedRows.CurrentRowSelected;
  FGrid.Canvas.Font.Color := clWindowText;
  if Secili then
    FGrid.Canvas.Brush.Color := RENK_SECIM
  else if FDuzenleme and (FGrid.DataSource.DataSet is TFDDataSet) and
    (TFDDataSet(FGrid.DataSource.DataSet).UpdateStatus = usInserted) then
    FGrid.Canvas.Brush.Color := RENK_YENI
  else if FDuzenleme and (FGrid.DataSource.DataSet is TFDDataSet) and
    (TFDDataSet(FGrid.DataSource.DataSet).UpdateStatus = usModified) and
    not VarSameValue(Alan.OldValue, Alan.Value) then
    FGrid.Canvas.Brush.Color := RENK_DEGISTI
  else if Odd(FGrid.DataSource.DataSet.RecNo) then
    FGrid.Canvas.Brush.Color := clWindow
  else
    FGrid.Canvas.Brush.Color := RENK_ZEBRA;
  FGrid.Canvas.Font.Style := [];
  if Alan.IsNull then
  begin
    Metin := 'NULL';
    FGrid.Canvas.Font.Style := [fsItalic];
    if not Secili then
      FGrid.Canvas.Font.Color := clGrayText;
    Bicim := [tfLeft, tfSingleLine, tfVerticalCenter, tfNoPrefix];
  end
  else
  begin
    Metin := HucreMetni(Alan);
    Bicim := [tfSingleLine, tfVerticalCenter, tfEndEllipsis, tfNoPrefix];
    if SAYI_SAGA and (Column.Alignment = taRightJustify) then
      Include(Bicim, tfRight)
    else
      Include(Bicim, tfLeft);
  end;
  FGrid.Canvas.FillRect(Rect);
  Alani := Rect;
  InflateRect(Alani, -4, 0);
  FGrid.Canvas.TextRect(Alani, Metin, Bicim);
  { Ince hucre cizgileri: sag ve alt kenar. }
  FGrid.Canvas.Pen.Color := RENK_CIZGI;
  FGrid.Canvas.MoveTo(Rect.Right - 1, Rect.Top);
  FGrid.Canvas.LineTo(Rect.Right - 1, Rect.Bottom - 1);
  FGrid.Canvas.LineTo(Rect.Left - 1, Rect.Bottom - 1);
  if gdFocused in State then
    FGrid.Canvas.DrawFocusRect(Rect);
end;

procedure TSonucGrid.CiftTik(Sender: TObject);
var
  Nokta: TPoint;
  Hucre: TGridCoord;
  Alan: TField;
begin
  { Duzeltme kipinde cift tik hucreyi yazmaya acar (DBGrid kendisi yapar), tam metin penceresi acilmaz. }
  if FDuzenleme then
    Exit;
  if (FGrid.DataSource = nil) or (FGrid.DataSource.DataSet = nil) or
    not FGrid.DataSource.DataSet.Active then
    Exit;
  Nokta := FGrid.ScreenToClient(Mouse.CursorPos);
  Hucre := FGrid.MouseCoord(Nokta.X, Nokta.Y);
  { Baslik satiri ve sol gosterge sutunu hucre degildir. }
  if (Hucre.X < 1) or (Hucre.Y < 1) then
    Exit;
  Alan := FGrid.SelectedField;
  if Alan = nil then
    Exit;
  MetinGoster(Alan.FieldName, HucreTamMetni(Alan));
end;

{ ---------- 4. Otomatik kolon genisligi ---------- }

procedure TSonucGrid.KolonGenisliginiAyarla;
var
  Veri: TDataSet;
  Yer: TBookmark;
  Genislik: array of Integer;
  i, Sayac: Integer;
begin
  Veri := FGrid.DataSource.DataSet;
  if (Veri = nil) or not Veri.Active then
    Exit;
  FGrid.Canvas.Font.Assign(FGrid.Font);
  SetLength(Genislik, FGrid.Columns.Count);
  for i := 0 to FGrid.Columns.Count - 1 do
    Genislik[i] := FGrid.Canvas.TextWidth(FGrid.Columns[i].Title.Caption) + 24;
  if not Veri.IsEmpty then
  begin
    Veri.DisableControls;
    Yer := Veri.GetBookmark;
    try
      Veri.First;
      Sayac := 0;
      while (not Veri.Eof) and (Sayac < OTO_GENISLIK_SATIR) do
      begin
        for i := 0 to FGrid.Columns.Count - 1 do
          if (FGrid.Columns[i].Field <> nil) and not FGrid.Columns[i].Field.IsNull then
            Genislik[i] := Max(Genislik[i],
              FGrid.Canvas.TextWidth(HucreMetni(FGrid.Columns[i].Field)) + 12);
        Veri.Next;
        Inc(Sayac);
      end;
      Veri.GotoBookmark(Yer);
    finally
      Veri.FreeBookmark(Yer);
      Veri.EnableControls;
    end;
  end;
  for i := 0 to FGrid.Columns.Count - 1 do
    FGrid.Columns[i].Width := Min(Max(Genislik[i], EN_AZ_GENISLIK), EN_COK_GENISLIK);
end;

{ ---------- 5. Ctrl+C ---------- }

procedure TSonucGrid.TusBas(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  if (Key = Ord('C')) and (ssCtrl in Shift) then
  begin
    SecimiKopyala;
    Key := 0;
  end;
end;

procedure TSonucGrid.SecimiKopyala;
var
  Veri: TDataSet;
  Yer: TBookmark;
  Metin, Satir: string;
  i, j: Integer;
begin
  if (FGrid.DataSource = nil) or (FGrid.DataSource.DataSet = nil) or
    not FGrid.DataSource.DataSet.Active then
    Exit;
  Veri := FGrid.DataSource.DataSet;
  Metin := '';
  if FGrid.SelectedRows.Count = 0 then
    Metin := KopyaMetni(FGrid.SelectedField)
  else
  begin
    Veri.DisableControls;
    Yer := Veri.GetBookmark;
    try
      for i := 0 to FGrid.SelectedRows.Count - 1 do
      begin
        Veri.GotoBookmark(FGrid.SelectedRows[i]);
        Satir := '';
        for j := 0 to FGrid.Columns.Count - 1 do
        begin
          if j > 0 then
            Satir := Satir + #9;
          Satir := Satir + KopyaMetni(FGrid.Columns[j].Field);
        end;
        Metin := Metin + Satir + #13#10;
      end;
      Veri.GotoBookmark(Yer);
    finally
      Veri.FreeBookmark(Yer);
      Veri.EnableControls;
    end;
  end;
  Clipboard.AsText := Metin;
end;

end.
