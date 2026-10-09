{ uMetadata.pas - Tablo, view, prosedur, generator listeleri ve kolon bilgisi.

  Hedeflenen Firebird surumleri: 2.5, 3.0, 4.0, 5.0
  Denenen Firebird surumleri: 2.5.9, 5.0.4 (3.0 ve 4.0 henuz denenmedi)
  Surume bagli her sey bu unit'te toplanir. Once FireDAC TFDMetaInfoQuery
  kullanilir, yetmezse RDB$ sistem tablolarina dogrudan sorgu yazilir. }
unit uMetadata;

interface

uses
  System.SysUtils, System.Classes, Data.DB,
  FireDAC.Stan.Intf, FireDAC.Stan.Option, FireDAC.Stan.Param, FireDAC.Stan.Error,
  FireDAC.DatS, FireDAC.Phys.Intf, FireDAC.DApt.Intf, FireDAC.Comp.DataSet,
  FireDAC.Comp.Client,
  uDil, uBaglanti;

procedure TablolariGetir(Hedef: TStrings);
procedure ViewlariGetir(Hedef: TStrings);
procedure ProsedurleriGetir(Hedef: TStrings);
procedure GeneratorleriGetir(Hedef: TStrings);
function KolonTablosuOlustur(const Tablo: string; Sahip: TComponent): TFDMemTable;
procedure KolonTablosuYazilariniYenile(Tablo: TDataSet);

implementation

procedure ListeyiDoldur(Sorgu: TFDMetaInfoQuery; const AdAlani: string; Hedef: TStrings);
begin
  Sorgu.Open;
  Hedef.BeginUpdate;
  try
    Hedef.Clear;
    while not Sorgu.Eof do
    begin
      Hedef.Add(Trim(Sorgu.FieldByName(AdAlani).AsString));
      Sorgu.Next;
    end;
  finally
    Hedef.EndUpdate;
  end;
end;

procedure TablolariGetir(Hedef: TStrings);
var
  Sorgu: TFDMetaInfoQuery;
begin
  Sorgu := TFDMetaInfoQuery.Create(nil);
  try
    Sorgu.Connection := FbBaglantisi;
    Sorgu.MetaInfoKind := mkTables;
    Sorgu.TableKinds := [tkTable];
    Sorgu.ObjectScopes := [osMy];
    ListeyiDoldur(Sorgu, 'TABLE_NAME', Hedef);
  finally
    Sorgu.Free;
  end;
end;

procedure ViewlariGetir(Hedef: TStrings);
var
  Sorgu: TFDMetaInfoQuery;
begin
  Sorgu := TFDMetaInfoQuery.Create(nil);
  try
    Sorgu.Connection := FbBaglantisi;
    Sorgu.MetaInfoKind := mkTables;
    Sorgu.TableKinds := [tkView];
    Sorgu.ObjectScopes := [osMy];
    ListeyiDoldur(Sorgu, 'TABLE_NAME', Hedef);
  finally
    Sorgu.Free;
  end;
end;

procedure ProsedurleriGetir(Hedef: TStrings);
var
  Sorgu: TFDMetaInfoQuery;
begin
  Sorgu := TFDMetaInfoQuery.Create(nil);
  try
    Sorgu.Connection := FbBaglantisi;
    Sorgu.MetaInfoKind := mkProcs;
    Sorgu.ObjectScopes := [osMy];
    ListeyiDoldur(Sorgu, 'PROC_NAME', Hedef);
  finally
    Sorgu.Free;
  end;
end;

procedure GeneratorleriGetir(Hedef: TStrings);
var
  Sorgu: TFDMetaInfoQuery;
begin
  Sorgu := TFDMetaInfoQuery.Create(nil);
  try
    Sorgu.Connection := FbBaglantisi;
    Sorgu.MetaInfoKind := mkGenerators;
    Sorgu.ObjectScopes := [osMy];
    ListeyiDoldur(Sorgu, 'GENERATOR_NAME', Hedef);
  finally
    Sorgu.Free;
  end;
end;

function EvetHayir(Deger: Boolean): string;
begin
  if Deger then
    Result := T('EVET')
  else
    Result := T('HAYIR');
end;

function TipMetni(Sorgu: TFDMetaInfoQuery): string;
var
  Ad: string;
  Uzunluk, Hassasiyet, Olcek: Integer;
begin
  Ad := Trim(Sorgu.FieldByName('COLUMN_TYPENAME').AsString);
  Uzunluk := Sorgu.FieldByName('COLUMN_LENGTH').AsInteger;
  Hassasiyet := Sorgu.FieldByName('COLUMN_PRECISION').AsInteger;
  Olcek := Sorgu.FieldByName('COLUMN_SCALE').AsInteger;
  Result := Ad;
  if (Pos('CHAR', UpperCase(Ad)) > 0) and (Uzunluk > 0) then
    Result := Ad + '(' + IntToStr(Uzunluk) + ')'
  else if ((Pos('NUMERIC', UpperCase(Ad)) > 0) or (Pos('DECIMAL', UpperCase(Ad)) > 0)) and (Hassasiyet > 0) then
    Result := Ad + '(' + IntToStr(Hassasiyet) + ',' + IntToStr(Olcek) + ')';
end;

{ Kolon bilgisini kucuk bir bellek tablosuna koyar. Tablo, Sahip ile birlikte yok olur. }
function KolonTablosuOlustur(const Tablo: string; Sahip: TComponent): TFDMemTable;
var
  Sorgu: TFDMetaInfoQuery;
  BosOlur: Boolean;
begin
  Result := TFDMemTable.Create(Sahip);
  Result.FieldDefs.Add('AD', ftString, 128);
  Result.FieldDefs.Add('TIP', ftString, 64);
  Result.FieldDefs.Add('BOS_OLUR', ftString, 8);
  Result.FieldDefs.Add('BOS_OLUR_MI', ftBoolean);
  Result.CreateDataSet;
  Result.FieldByName('AD').DisplayWidth := 30;
  Result.FieldByName('TIP').DisplayWidth := 22;
  Result.FieldByName('BOS_OLUR').DisplayWidth := 14;
  Result.FieldByName('BOS_OLUR_MI').Visible := False;
  Sorgu := TFDMetaInfoQuery.Create(nil);
  try
    Sorgu.Connection := FbBaglantisi;
    Sorgu.MetaInfoKind := mkTableFields;
    { Buyuk/kucuk harf ve ozel karakterler korunsun diye tirnakli verilir. }
    Sorgu.ObjectName := '"' + StringReplace(Tablo, '"', '""', [rfReplaceAll]) + '"';
    Sorgu.Open;
    while not Sorgu.Eof do
    begin
      BosOlur := (Sorgu.FieldByName('COLUMN_ATTRIBUTES').AsInteger and
        (1 shl Ord(caAllowNull))) <> 0;
      Result.Append;
      Result.FieldByName('AD').AsString := Trim(Sorgu.FieldByName('COLUMN_NAME').AsString);
      Result.FieldByName('TIP').AsString := TipMetni(Sorgu);
      Result.FieldByName('BOS_OLUR_MI').AsBoolean := BosOlur;
      Result.FieldByName('BOS_OLUR').AsString := EvetHayir(BosOlur);
      Result.Post;
      Sorgu.Next;
    end;
  finally
    Sorgu.Free;
  end;
  Result.First;
end;


{ Dil degisince "Evet/Hayir" yazilarini yeniden yazar. }
procedure KolonTablosuYazilariniYenile(Tablo: TDataSet);
begin
  Tablo.DisableControls;
  try
    Tablo.First;
    while not Tablo.Eof do
    begin
      Tablo.Edit;
      Tablo.FieldByName('BOS_OLUR').AsString := EvetHayir(Tablo.FieldByName('BOS_OLUR_MI').AsBoolean);
      Tablo.Post;
      Tablo.Next;
    end;
    Tablo.First;
  finally
    Tablo.EnableControls;
  end;
end;

end.