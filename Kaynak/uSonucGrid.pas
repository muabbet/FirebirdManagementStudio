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
  System.SysUtils, System.Classes, System.Types, System.Math, Data.DB,
  Winapi.Windows, Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Grids, Vcl.DBGrids,
  Vcl.Clipbrd,
  FireDAC.Comp.DataSet,
  uDil, fMetinGoster;

type
  { Grid sahibidir: grid yok olunca bu nesne de yok olur. }
  TSonucGrid = class(TComponent)
  private
    FGrid: TDBGrid;
    FSiraAlan: string;
    FAzalan: Boolean;
    procedure BaslikTik(Column: TColumn);
    procedure HucreCiz(Sender: TObject; const Rect: TRect; DataCol: Integer;
      Column: TColumn; State: TGridDrawState);
    procedure TusBas(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure CiftTik(Sender: TObject);
    procedure BasliklariYaz;
    procedure KolonGenisliginiAyarla;
    procedure SecimiKopyala;
  public
    constructor Create(Grid: TDBGrid); reintroduce;
    procedure YeniSonuc;
  end;

implementation

const
  KISA_UZUNLUK = 100;
  OTO_GENISLIK_SATIR = 50;
  EN_AZ_GENISLIK = 60;
  EN_COK_GENISLIK = 400;
  YUKARI_OK = #$25B2;
  ASAGI_OK = #$25BC;

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
  FGrid.Options := FGrid.Options + [dgTitles, dgIndicator, dgMultiSelect];
  FGrid.OnTitleClick := BaslikTik;
  FGrid.OnDrawColumnCell := HucreCiz;
  FGrid.OnKeyDown := TusBas;
  FGrid.OnDblClick := CiftTik;
end;

{ Yeni sonuc verisetine baglandiktan sonra cagrilir: kolonlar yeniden kurulur. }
procedure TSonucGrid.YeniSonuc;
begin
  FSiraAlan := '';
  FAzalan := False;
  FGrid.Columns.State := csDefault;
  BasliklariYaz;
  KolonGenisliginiAyarla;
end;

{ ---------- 1. Siralama ---------- }

procedure TSonucGrid.BasliklariYaz;
var
  i: Integer;
  Kolon: TColumn;
begin
  for i := 0 to FGrid.Columns.Count - 1 do
  begin
    Kolon := FGrid.Columns[i];
    Kolon.Title.Caption := Kolon.FieldName;
    if SameText(Kolon.FieldName, FSiraAlan) then
    begin
      if FAzalan then
        Kolon.Title.Caption := Kolon.FieldName + ' ' + ASAGI_OK
      else
        Kolon.Title.Caption := Kolon.FieldName + ' ' + YUKARI_OK;
    end;
  end;
end;

{ Siralama, simdiye kadar yuklenen satirlar uzerinde yapilir; sonradan gelen
  satirlar da sirali yere girer. }
procedure TSonucGrid.BaslikTik(Column: TColumn);
var
  Veri: TFDDataSet;
  Alan: TField;
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
  Secili := (gdSelected in State) or FGrid.SelectedRows.CurrentRowSelected;
  if Secili then
  begin
    FGrid.Canvas.Brush.Color := clHighlight;
    FGrid.Canvas.Font.Color := clHighlightText;
  end
  else
  begin
    if Odd(FGrid.DataSource.DataSet.RecNo) then
      FGrid.Canvas.Brush.Color := clWindow
    else
      FGrid.Canvas.Brush.Color := TColor(RGB(240, 245, 250));
    FGrid.Canvas.Font.Color := clWindowText;
  end;
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
    if Column.Alignment = taRightJustify then
      Include(Bicim, tfRight)
    else
      Include(Bicim, tfLeft);
  end;
  FGrid.Canvas.FillRect(Rect);
  Alani := Rect;
  InflateRect(Alani, -3, 0);
  FGrid.Canvas.TextRect(Alani, Metin, Bicim);
  if gdFocused in State then
    FGrid.Canvas.DrawFocusRect(Rect);
end;

procedure TSonucGrid.CiftTik(Sender: TObject);
var
  Nokta: TPoint;
  Hucre: TGridCoord;
  Alan: TField;
begin
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
