unit uKayitDuzelt;

{ Tablo verisi gridinde kayit duzeltme (Asama 4d).

  Hedeflenen Firebird surumleri: 2.5, 3.0, 4.0, 5.0

  Kurallar (sade ve guvenli):
    - Yalniz BIRINCIL ANAHTARI olan tablolarda acilir. Mevcut kaydin birincil anahtar kolonlari degistirilemez;
      yeni kayitta yazilabilir (bos birakilirsa varsayilan/generator/tetikleyici doldurur).
    - Degisiklikler once SADECE bellekte bekler (FireDAC CachedUpdates); veritabanina hicbir sey yazilmaz.
      Islem (transaction) yalnizca Kaydet sirasinda acilir: butun UPDATE'ler tek islemde calisir, hepsi
      basariliysa onaylanir (commit), biri bile hata verir veya tam 1 satir etkilemezse HEPSI geri alinir.
    - Yeni kayit eklenebilir (bellekte bekler, Kaydet'te INSERT olur; bos birakilan kolon INSERT'e girmez, boylece
      DEFAULT ve tetikleyiciler calisir). Satir silme yok.
    - BLOB, hesaplanan ve "GENERATED ALWAYS" kimlik kolonlari duzenlenmez.
    - Bos birakilan sayi/tarih alani NULL olur; metin alaninda bos yazi bos yazi olarak kalir ('' ile NULL ayri).
  Hata istisna olarak firlamaz, sonuc kaydina yazilir. }

interface

uses
  System.SysUtils, System.Classes, System.Variants, System.Generics.Collections,
  Data.DB, FireDAC.Stan.Intf, FireDAC.Stan.Option, FireDAC.Stan.Param, FireDAC.Comp.DataSet, FireDAC.Comp.Client,
  uDil, uBaglanti, uMetadata, uSorgu;

type
  { Bekleyen bir satirin veritabaninda ne olacagi. }
  TSatirTuru = (stGuncelle, stEkle, stSil);

  TDuzeltSonucu = record
    Basarili: Boolean;
    Cumle: string;
    Ayrinti: string;
    { Calistirilan (hata olunca denenen) UPDATE'ler; yonetim mesaji alanina yazilir. }
    Komutlar: TArray<string>;
  end;

  { Bir tablo gridinin duzeltme durumu. Veri seti Sahip'e aittir; bu nesne onu yok etmez. }
  TKayitDuzelt = class
  private
    FBag: TAcikBaglanti;
    FTablo: string;
    FVeri: TFDQuery;
    FAnahtar: TArray<string>;
    { Her zaman kilitli kolonlar: BLOB, hesaplanan, GENERATED ALWAYS kimlik. }
    FKilitli: TArray<string>;
    FEkleniyor: Boolean;
    FSiliniyor: Boolean;
    FDegisti: TProc;
    procedure EklemeyiEngelle(DataSet: TDataSet);
    procedure SilmeyiEngelle(DataSet: TDataSet);
    procedure KayitDegisti(DataSet: TDataSet);
    procedure SatirDegisti(DataSet: TDataSet);
    procedure AlanlariKilitle;
    function AdVarMi(const Liste: TArray<string>; const Ad: string): Boolean;
    function SatirAlanlari(out Tur: TSatirTuru): TArray<TField>;
    function SatirMetni(Alanlar: TArray<TField>; Tur: TSatirTuru; Gercek: Boolean): string;
    function AnahtarKosulu(Gercek: Boolean): string;
    function SilMetni(Gercek: Boolean): string;
    function GuncelleMetni(Alanlar: TArray<TField>; Gercek: Boolean): string;
    function EkleMetni(Alanlar: TArray<TField>; Gercek: Boolean): string;
  public
    constructor Create(Bag: TAcikBaglanti; const Tablo: string; Veri: TFDQuery; Degisti: TProc);
    { Tabloda birincil anahtar var mi? Yoksa duzeltme acilmaz. }
    function AnahtarVar: Boolean;
    { Duzeltmeyi acar: veri seti degistirilebilir olur, anahtar/BLOB/hesaplanan alanlar kilitlenir. }
    procedure Ac;
    { Duzeltmeyi kapatir (bekleyen degisiklikleri atmaz; once GeriAl cagrilmali). }
    procedure Kapat;
    { Yazilmakta olan satiri bellege isler (grid satir degistirince bunu kendisi yapar; Kaydet/Geri al/Bitir oncesi cagrilir). }
    procedure SatiriBitir;
    { Su anki kaydi silinmek uzere isaretler (grid'den kalkar; veritabaninda Kaydet'e kadar durur, Geri al geri getirir). }
    procedure KaydiSil;
    { Kaydet'te SILINECEK kayit sayisi (onay penceresi uyarisi icin). }
    function SilinecekSayisi: Integer;
    { Gridin sonuna bos bir yeni kayit ekler (bellekte; Kaydet'e kadar veritabanina gitmez). }
    procedure YeniKayit;
    { Bekleyen (kaydedilmemis) degisiklik yapilmis satir sayisi. }
    function BekleyenSayisi: Integer;
    { Onay penceresi icin: bekleyen UPDATE'lerin okunur metni (degerler yazi olarak). }
    function OnayKomutlari: TArray<string>;
    { Bekleyenleri tek islemde uygular ve onaylar; hatada hepsini geri alir. }
    function Kaydet: TDuzeltSonucu;
    { Bekleyenleri atar (veritabanina dokunmaz). }
    procedure GeriAl;
  end;

{ Onay penceresinde gorunecek UPDATE listesi; cok uzunsa ilk 10'u, kalani "... N tane daha" olarak. }
function KomutOzeti(const Komutlar: TArray<string>): string;

{ Duzeltmeye uygun veri seti: tablonun ilk satirlari, degisiklikler bellekte tutulur. Sorgu, Sahip ile yok olur. }
function DuzeltilebilirVeriSorgusu(Bag: TAcikBaglanti; const Tablo: string; SatirSayisi: Integer;
  Sahip: TComponent): TFDQuery;

implementation

const
  DEGISEN_KAYITLAR: TFDUpdateRecordTypes = [rtModified, rtInserted, rtDeleted];
  TUM_KAYITLAR: TFDUpdateRecordTypes = [rtUnmodified, rtModified, rtInserted];

function DuzeltilebilirVeriSorgusu(Bag: TAcikBaglanti; const Tablo: string; SatirSayisi: Integer;
  Sahip: TComponent): TFDQuery;
begin
  Result := TFDQuery.Create(Sahip);
  try
    Result.Connection := Bag.Baglanti;
    Result.CachedUpdates := True;
    Result.FetchOptions.Mode := fmAll;
    Result.SQL.Text := 'SELECT FIRST ' + IntToStr(SatirSayisi) + ' * FROM ' + TirnakliAd(Tablo);
    Result.Open;
  except
    Result.Free;
    raise;
  end;
end;

{ UPDATE metninde gorunecek deger (yalniz gosterim icin; calistirmada parametre kullanilir). }
function DegerMetni(Alan: TField; Deger: Variant): string;
begin
  if VarIsNull(Deger) or VarIsEmpty(Deger) then
    Exit('NULL');
  case Alan.DataType of
    ftSmallint, ftInteger, ftWord, ftLargeint, ftAutoInc, ftShortint, ftByte, ftLongWord,
    ftFloat, ftCurrency, ftBCD, ftFMTBcd, ftSingle, ftExtended:
      Result := StringReplace(VarToStr(Deger), FormatSettings.DecimalSeparator, '.', []);
    ftBoolean:
      if Deger then Result := 'TRUE' else Result := 'FALSE';
    ftDate:
      Result := '''' + FormatDateTime('yyyy-mm-dd', Deger) + '''';
    ftTime:
      Result := '''' + FormatDateTime('hh:nn:ss', Deger) + '''';
    ftDateTime, ftTimeStamp:
      Result := '''' + FormatDateTime('yyyy-mm-dd hh:nn:ss', Deger) + '''';
  else
    Result := '''' + StringReplace(VarToStr(Deger), '''', '''''', [rfReplaceAll]) + '''';
  end;
end;

function KomutOzeti(const Komutlar: TArray<string>): string;
const
  EN_COK = 10;
var
  i: Integer;
begin
  Result := '';
  for i := 0 to High(Komutlar) do
    if i < EN_COK then
      Result := Result + Komutlar[i] + sLineBreak;
  if Length(Komutlar) > EN_COK then
    Result := Result + TF('MSG_DUZ_DAHA_FAZLA', [Length(Komutlar) - EN_COK]);
end;

constructor TKayitDuzelt.Create(Bag: TAcikBaglanti; const Tablo: string; Veri: TFDQuery; Degisti: TProc);
var
  Kisit: TKisitBilgisi;
begin
  inherited Create;
  FBag := Bag;
  FTablo := Tablo;
  FVeri := Veri;
  FDegisti := Degisti;
  SetLength(FAnahtar, 0);
  for Kisit in KisitlariOku(Bag, Tablo) do
    if Kisit.Tur = ktBirincil then
      FAnahtar := Kisit.Kolonlar;
end;

function TKayitDuzelt.AnahtarVar: Boolean;
begin
  Result := Length(FAnahtar) > 0;
end;

function TKayitDuzelt.AdVarMi(const Liste: TArray<string>; const Ad: string): Boolean;
var
  Eleman: string;
begin
  Result := False;
  for Eleman in Liste do
    if SameText(Eleman, Ad) then
      Result := True;
end;

{ BLOB, hesaplanan ve GENERATED ALWAYS kolonlar her zaman kilitli; birincil anahtar yalniz mevcut kayitta (SatirDegisti). }
procedure TKayitDuzelt.AlanlariKilitle;
var
  Kolonlar: TArray<TKolonBilgisi>;
  Kolon: TKolonBilgisi;
  Alan: TField;
begin
  Kolonlar := KolonlariOku(FBag, FTablo);
  SetLength(FKilitli, 0);
  for Alan in FVeri.Fields do
  begin
    { Zorunlu kolonu bos birakmayi Firebird Kaydet'te reddeder; grid satirdan cikarken kendi (Ingilizce) hatasini vermesin. }
    Alan.Required := False;
    if Alan.IsBlob then
      FKilitli := FKilitli + [Alan.FieldName];
    for Kolon in Kolonlar do
      if SameText(Kolon.Ad, Alan.FieldName) and ((Kolon.Hesaplanan <> '') or (Kolon.Kimlik and Kolon.KimlikHep)) then
        FKilitli := FKilitli + [Alan.FieldName];
  end;
  SatirDegisti(FVeri);
end;

{ Satir degisince (ya da yeni satir acilinca): anahtar kolonlari mevcut kayitta kilitli, yeni kayitta acik. }
procedure TKayitDuzelt.SatirDegisti(DataSet: TDataSet);
var
  Alan: TField;
  YeniSatir: Boolean;
begin
  YeniSatir := (FVeri.State = dsInsert) or (FVeri.UpdateStatus = usInserted);
  for Alan in FVeri.Fields do
    Alan.ReadOnly := AdVarMi(FKilitli, Alan.FieldName) or (AdVarMi(FAnahtar, Alan.FieldName) and not YeniSatir);
end;

procedure TKayitDuzelt.Ac;
begin
  AlanlariKilitle;
  FVeri.BeforeInsert := EklemeyiEngelle;
  FVeri.BeforeDelete := SilmeyiEngelle;
  FVeri.AfterPost := KayitDegisti;
  FVeri.AfterCancel := KayitDegisti;
  FVeri.AfterInsert := SatirDegisti;
  FVeri.AfterScroll := SatirDegisti;
end;

procedure TKayitDuzelt.Kapat;
begin
  FVeri.BeforeInsert := nil;
  FVeri.BeforeDelete := nil;
  FVeri.AfterPost := nil;
  FVeri.AfterCancel := nil;
  FVeri.AfterInsert := nil;
  FVeri.AfterScroll := nil;
end;

{ Grid, son satirdan asagi inince ya da Insert tusunda yeni satir acmaya calisir; burada kesilir.
  Yalniz "Yeni kayit" dugmesi (YeniKayit) izin verir. }
procedure TKayitDuzelt.EklemeyiEngelle(DataSet: TDataSet);
begin
  if not FEkleniyor then
    Abort;
end;

procedure TKayitDuzelt.YeniKayit;
begin
  SatiriBitir;
  FEkleniyor := True;
  try
    FVeri.Append;
  finally
    FEkleniyor := False;
  end;
end;

{ Ctrl+Delete satiri silmeye calisir; burada kesilir. Yalniz "Kayit sil" dugmesi (KaydiSil) izin verir. }
procedure TKayitDuzelt.SilmeyiEngelle(DataSet: TDataSet);
begin
  if not FSiliniyor then
    Abort;
end;

procedure TKayitDuzelt.KaydiSil;
begin
  if FVeri.IsEmpty then
    Exit;
  SatiriBitir;
  FSiliniyor := True;
  try
    FVeri.Delete;
  finally
    FSiliniyor := False;
  end;
  KayitDegisti(FVeri);
end;

procedure TKayitDuzelt.KayitDegisti(DataSet: TDataSet);
begin
  if Assigned(FDegisti) then
    FDegisti();
end;

procedure TKayitDuzelt.SatiriBitir;
begin
  if FVeri.State in dsEditModes then
    FVeri.Post;
end;

function TKayitDuzelt.BekleyenSayisi: Integer;
begin
  Result := FVeri.ChangeCount;
end;

{ Su anki satirin (degisen ya da yeni) komuta girecek alanlari. Ekleme True ise satir yenidir: bos olmayan,
  kilitli olmayan alanlar. Degilse: degeri ESKI degerinden farkli, kilitli ve anahtar olmayan alanlar. }
function TKayitDuzelt.SatirAlanlari(out Tur: TSatirTuru): TArray<TField>;
var
  Alan: TField;
begin
  SetLength(Result, 0);
  case FVeri.UpdateStatus of
    usInserted: Tur := stEkle;
    usDeleted: Tur := stSil;
  else
    Tur := stGuncelle;
  end;
  if Tur = stSil then
    Exit;
  for Alan in FVeri.Fields do
    if AdVarMi(FKilitli, Alan.FieldName) then
      Continue
    else if Tur = stEkle then
    begin
      if not Alan.IsNull then
        Result := Result + [Alan];
    end
    else if not AdVarMi(FAnahtar, Alan.FieldName) and not VarSameValue(Alan.OldValue, Alan.Value) then
      Result := Result + [Alan];
end;

function TKayitDuzelt.SatirMetni(Alanlar: TArray<TField>; Tur: TSatirTuru; Gercek: Boolean): string;
begin
  case Tur of
    stEkle: Result := EkleMetni(Alanlar, Gercek);
    stSil: Result := SilMetni(Gercek);
  else
    Result := GuncelleMetni(Alanlar, Gercek);
  end;
end;

{ WHERE kismi: birincil anahtar kolonlari, kaydin ESKI degerleriyle. }
function TKayitDuzelt.AnahtarKosulu(Gercek: Boolean): string;
var
  Alan: TField;
  i: Integer;
begin
  Result := '';
  for i := 0 to High(FAnahtar) do
  begin
    if i > 0 then
      Result := Result + ' AND ';
    Alan := FVeri.FieldByName(FAnahtar[i]);
    if Gercek then
      Result := Result + TirnakliAd(FAnahtar[i]) + ' = :K' + IntToStr(i)
    else
      Result := Result + TirnakliAd(FAnahtar[i]) + ' = ' + DegerMetni(Alan, Alan.OldValue);
  end;
end;

function TKayitDuzelt.SilMetni(Gercek: Boolean): string;
begin
  Result := 'DELETE FROM ' + TirnakliAd(FTablo) + ' WHERE ' + AnahtarKosulu(Gercek);
end;

{ Bos birakilan kolonlar INSERT'e girmez (DEFAULT, generator ve tetikleyici onlari doldurur). }
function TKayitDuzelt.EkleMetni(Alanlar: TArray<TField>; Gercek: Boolean): string;
var
  Kolonlar, Degerler: string;
  i: Integer;
begin
  if Length(Alanlar) = 0 then
    Exit('INSERT INTO ' + TirnakliAd(FTablo) + ' DEFAULT VALUES');
  for i := 0 to High(Alanlar) do
  begin
    if i > 0 then
    begin
      Kolonlar := Kolonlar + ', ';
      Degerler := Degerler + ', ';
    end;
    Kolonlar := Kolonlar + TirnakliAd(Alanlar[i].FieldName);
    if Gercek then
      Degerler := Degerler + ':D' + IntToStr(i)
    else
      Degerler := Degerler + DegerMetni(Alanlar[i], Alanlar[i].Value);
  end;
  Result := 'INSERT INTO ' + TirnakliAd(FTablo) + ' (' + Kolonlar + ') VALUES (' + Degerler + ')';
end;

{ Gercek=True: parametreli (calistirilacak); False: degerleri yazili (onay penceresi ve SQL mesaji). }
function TKayitDuzelt.GuncelleMetni(Alanlar: TArray<TField>; Gercek: Boolean): string;
var
  i: Integer;
begin
  Result := '';
  for i := 0 to High(Alanlar) do
  begin
    if i > 0 then
      Result := Result + ', ';
    if Gercek then
      Result := Result + TirnakliAd(Alanlar[i].FieldName) + ' = :D' + IntToStr(i)
    else
      Result := Result + TirnakliAd(Alanlar[i].FieldName) + ' = ' + DegerMetni(Alanlar[i], Alanlar[i].Value);
  end;
  Result := 'UPDATE ' + TirnakliAd(FTablo) + ' SET ' + Result + ' WHERE ' + AnahtarKosulu(Gercek);
end;

function TKayitDuzelt.SilinecekSayisi: Integer;
var
  Yer: TBookmark;
begin
  Result := 0;
  FVeri.FilterChanges := [rtDeleted];
  FVeri.DisableControls;
  Yer := FVeri.GetBookmark;
  try
    FVeri.First;
    while not FVeri.Eof do
    begin
      Inc(Result);
      FVeri.Next;
    end;
  finally
    FVeri.FilterChanges := TUM_KAYITLAR;
    if FVeri.BookmarkValid(Yer) then
      FVeri.GotoBookmark(Yer);
    FVeri.FreeBookmark(Yer);
    FVeri.EnableControls;
  end;
end;

function TKayitDuzelt.OnayKomutlari: TArray<string>;
var
  Yer: TBookmark;
  Alanlar: TArray<TField>;
  Tur: TSatirTuru;
begin
  SetLength(Result, 0);
  FVeri.FilterChanges := DEGISEN_KAYITLAR;
  FVeri.DisableControls;
  Yer := FVeri.GetBookmark;
  try
    FVeri.First;
    while not FVeri.Eof do
    begin
      Alanlar := SatirAlanlari(Tur);
      if (Tur <> stGuncelle) or (Length(Alanlar) > 0) then
        Result := Result + [SatirMetni(Alanlar, Tur, False) + ';'];
      FVeri.Next;
    end;
  finally
    FVeri.FilterChanges := TUM_KAYITLAR;
    if FVeri.BookmarkValid(Yer) then
      FVeri.GotoBookmark(Yer);
    FVeri.FreeBookmark(Yer);
    FVeri.EnableControls;
  end;
end;

function TKayitDuzelt.Kaydet: TDuzeltSonucu;
var
  Islem: TFDTransaction;
  Sorgu: TFDQuery;
  Yer: TBookmark;
  Alanlar: TArray<TField>;
  Tur: TSatirTuru;
  i: Integer;
  Komutlar: TList<string>;
begin
  Result := Default(TDuzeltSonucu);
  Komutlar := TList<string>.Create;
  Islem := TFDTransaction.Create(nil);
  Sorgu := TFDQuery.Create(nil);
  try
    Islem.Connection := FBag.Baglanti;
    Islem.Options.AutoCommit := False;
    Sorgu.Connection := FBag.Baglanti;
    Sorgu.Transaction := Islem;
    FVeri.FilterChanges := DEGISEN_KAYITLAR;
    FVeri.DisableControls;
    Yer := FVeri.GetBookmark;
    try
      try
        Islem.StartTransaction;
        FVeri.First;
        while not FVeri.Eof do
        begin
          Alanlar := SatirAlanlari(Tur);
          if (Tur <> stGuncelle) or (Length(Alanlar) > 0) then
          begin
            Komutlar.Add(SatirMetni(Alanlar, Tur, False) + ';');
            Sorgu.SQL.Text := SatirMetni(Alanlar, Tur, True);
            for i := 0 to High(Alanlar) do
            begin
              Sorgu.Params[i].DataType := Alanlar[i].DataType;
              if Alanlar[i].IsNull then
                Sorgu.Params[i].Clear
              else
                Sorgu.Params[i].Value := Alanlar[i].Value;
            end;
            if Tur <> stEkle then
              for i := 0 to High(FAnahtar) do
              begin
                Sorgu.ParamByName('K' + IntToStr(i)).DataType := FVeri.FieldByName(FAnahtar[i]).DataType;
                Sorgu.ParamByName('K' + IntToStr(i)).Value := FVeri.FieldByName(FAnahtar[i]).OldValue;
              end;
            Sorgu.ExecSQL;
            { Her komut tam 1 kayit etkiler; baskasi olursa (tetikleyici, silinmis kayit) hicbir sey kaydedilmez. }
            if Sorgu.RowsAffected <> 1 then
              raise EKayitKurali.Create(TF('ERR_DUZ_SATIR_SAYISI', [Sorgu.RowsAffected]));
          end;
          FVeri.Next;
        end;
        Islem.Commit;
        Result.Basarili := True;
      except
        on E: Exception do
        begin
          try
            if Islem.Active then
              Islem.Rollback;
          except
            { Rollback da basarisiz olursa asil hata gosterilir. }
          end;
          if E is EKayitKurali then
            Result.Cumle := E.Message
          else
            Result.Cumle := HataMetniniCevir(E);
          Result.Ayrinti := E.Message;
        end;
      end;
    finally
      FVeri.FilterChanges := TUM_KAYITLAR;
      if FVeri.BookmarkValid(Yer) then
        FVeri.GotoBookmark(Yer);
      FVeri.FreeBookmark(Yer);
      FVeri.EnableControls;
    end;
    Result.Komutlar := Komutlar.ToArray;
  finally
    Sorgu.Free;
    Islem.Free;
    Komutlar.Free;
  end;
end;

procedure TKayitDuzelt.GeriAl;
begin
  if FVeri.State in dsEditModes then
    FVeri.Cancel;
  FVeri.CancelUpdates;
end;

end.
