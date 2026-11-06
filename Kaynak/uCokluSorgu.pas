{ uCokluSorgu.pas - Bir sorguyu birden cok veritabaninda calistirip sonuclari tek tabloda birlestirir (Asama 4a).

  Hedeflenen Firebird surumleri: 2.5, 3.0, 4.0, 5.0 (her veritabani kendi surumuyle konusur)

  Kurallar (sade):
    - Yalniz tek bir SELECT (ya da WITH ... SELECT) calisir; yazan komutlar bu surumde yok (Asama 4c, onayla).
    - Her veritabani icin siradan: acik baglanti varsa o kullanilir; yoksa kayitli baglantinin sifresiyle GECICI baglanti
      acilir ve isi bitince kapatilir (agactaki baglanti listesi degismez). Sifresi kayitli olmayan kapali baglanti
      atlanir (cumlesi yazilir).
    - Bir veritabani hata verirse digerleri calismaya devam eder; hata o veritabaninin satirina yazilir.
    - Birlesik tabloda ilk kolon VERITABANI, sonra sorgunun kolonlari. Veritabanlarinin kolonlari farkliysa kolon
      adlarinin birlesimi alinir, olmayan hucre NULL kalir.
    - Her veritabanindan en cok COKLU_SATIR_SINIRI satir alinir; kesildiyse kayitta isaretlenir.
  Hata istisna olarak firlamaz, her veritabaninin kaydina yazilir. }
unit uCokluSorgu;

interface

uses
  System.SysUtils, System.Classes, System.StrUtils, System.Generics.Collections, System.Diagnostics, Data.DB,
  FireDAC.Comp.Client,
  uDil, uBaglanti, uSorgu;

type
  TCokluDurum = (cdTamam, cdHata, cdAtlandi);

  { Bir veritabaninin sonucu: durum, satir sayisi, sure, hata cumlesi (anlasilir) ve ham ayrinti. }
  TCokluKayit = record
    Ad: string;
    Durum: TCokluDurum;
    Satir: Integer;
    Sure: Int64;
    Kesildi: Boolean;
    Cumle: string;
    Ayrinti: string;
  end;

  TCokluSonuc = class
  public
    { Birlesik sonuc; hic veritabani basarili olmadiysa bos (kolonsuz). Sonuc sahibi (cagiran) serbest birakir. }
    Tablo: TFDMemTable;
    Kayitlar: TList<TCokluKayit>;
    constructor Create;
    destructor Destroy; override;
    function TamamSayisi: Integer;
  end;

const
  COKLU_SATIR_SINIRI = 5000;
  VERITABANI_KOLONU = 'VERITABANI';

{ Yazi tek bir SELECT (ya da WITH) mi? Degilse anlasilir cumle, tamamsa bos. }
function CokluSorguKontrol(const Sql: string): string;

{ Komutun ilk sozcugu (basindaki bosluk ve yorumlar atlanir), BUYUK harf. Toplu guncelleme (uTopluGuncelle) de kullanir. }
function IlkSozcuk(const Komut: string): string;

{ Komut veritabaninin yapisini degistirir mi (CREATE, ALTER, DROP, RECREATE)? Sorgu sekmesi bunun uzerine agaci yeniler. }
function YapiKomutuMu(const Komut: string): Boolean;

{ Bu adli baglanti simdi kullanilabilir mi: acik, ya da kayitli ve sifresi kayitli. }
function CokluBaglantiKullanilabilir(const Ad: string): Boolean;

{ Adlardaki veritabanlarinda sirayla calistirir. Ilerleme (bos olabilir) her veritabanindan once adiyla cagrilir. }
function CokluSorguCalistir(const Adlar: TArray<string>; const Sql: string; Ilerleme: TProc<string>): TCokluSonuc;

implementation

constructor TCokluSonuc.Create;
begin
  inherited;
  Kayitlar := TList<TCokluKayit>.Create;
end;

destructor TCokluSonuc.Destroy;
begin
  Tablo.Free;
  Kayitlar.Free;
  inherited;
end;

function TCokluSonuc.TamamSayisi: Integer;
var
  K: TCokluKayit;
begin
  Result := 0;
  for K in Kayitlar do
    if K.Durum = cdTamam then
      Inc(Result);
end;

{ Komutun ilk sozcugu (basindaki bosluk ve yorumlar atlanir), BUYUK harf. }
function IlkSozcuk(const Komut: string): string;
var
  i, Bas: Integer;
begin
  i := 1;
  while i <= Length(Komut) do
  begin
    if CharInSet(Komut[i], [' ', #9, #10, #13]) then
      Inc(i)
    else if (Copy(Komut, i, 2) = '--') then
    begin
      while (i <= Length(Komut)) and not CharInSet(Komut[i], [#10, #13]) do
        Inc(i);
    end
    else if (Copy(Komut, i, 2) = '/*') then
    begin
      Inc(i, 2);
      while (i < Length(Komut)) and (Copy(Komut, i, 2) <> '*/') do
        Inc(i);
      Inc(i, 2);
    end
    else
      Break;
  end;
  Bas := i;
  while (i <= Length(Komut)) and CharInSet(Komut[i], ['A'..'Z', 'a'..'z', '_']) do
    Inc(i);
  Result := UpperCase(Copy(Komut, Bas, i - Bas));
end;

function YapiKomutuMu(const Komut: string): Boolean;
var
  Sozcuk: string;
begin
  Sozcuk := IlkSozcuk(Komut);
  Result := (Sozcuk = 'CREATE') or (Sozcuk = 'ALTER') or (Sozcuk = 'DROP') or (Sozcuk = 'RECREATE');
end;

function CokluSorguKontrol(const Sql: string): string;
var
  Komutlar: TArray<string>;
  Sozcuk: string;
begin
  Result := '';
  Komutlar := KomutlaraBol(Sql);
  if Length(Komutlar) = 0 then
    Exit(T('ERR_SORGU_BOS'));
  if Length(Komutlar) > 1 then
    Exit(T('ERR_COKLU_TEK_KOMUT'));
  Sozcuk := IlkSozcuk(Komutlar[0]);
  if (Sozcuk <> 'SELECT') and (Sozcuk <> 'WITH') then
    Result := T('ERR_COKLU_SADECE_SELECT');
end;

function CokluBaglantiKullanilabilir(const Ad: string): Boolean;
var
  Tanim: TBaglantiTanimi;
begin
  Result := FbAcikBaglanti(Ad) <> nil;
  if not Result then
    Result := KayitliBaglantiBul(Ad, Tanim) and (Tanim.Sifre <> '');
end;

function BlobMu(Tur: TFieldType): Boolean;
begin
  Result := Tur in [ftBlob, ftMemo, ftWideMemo, ftFmtMemo, ftGraphic, ftTypedBinary, ftOraBlob, ftOraClob];
end;

{ Bir veritabanindan sonucu bellek tablosuna alir (en cok COKLU_SATIR_SINIRI satir). Hata istisna olarak gelir. }
function SonucuAl(Bag: TAcikBaglanti; const Sql: string; var Kayit: TCokluKayit): TFDMemTable;
var
  Sonuc: TSorguSonucu;
  Sorgu: TFDQuery;
  i: Integer;
begin
  Result := nil;
  Sonuc := SorguCalistir(Bag, Sql);
  try
    if not Sonuc.SatirVar then
      raise Exception.Create(T('ERR_COKLU_SATIR_YOK'));
    Sorgu := Sonuc.Sorgu;
    Kayit.Sure := Sonuc.Sure;
    Result := TFDMemTable.Create(nil);
    try
      Result.FieldDefs.Assign(Sorgu.FieldDefs);
      { Hesaplanan kolonlar (COUNT(*) gibi) salt okunur gelir; bellek tablosuna yazilabilsin. }
      for i := 0 to Result.FieldDefs.Count - 1 do
        Result.FieldDefs[i].Attributes := Result.FieldDefs[i].Attributes - [faReadonly];
      Result.CreateDataSet;
      while (not Sorgu.Eof) and (Result.RecordCount < COKLU_SATIR_SINIRI) do
      begin
        Result.Append;
        for i := 0 to Sorgu.FieldCount - 1 do
          if Sorgu.Fields[i].IsNull then
            Result.Fields[i].Clear
          else if BlobMu(Sorgu.Fields[i].DataType) then
            Result.Fields[i].AsString := Sorgu.Fields[i].AsString
          else
            Result.Fields[i].Value := Sorgu.Fields[i].Value;
        Result.Post;
        Sorgu.Next;
      end;
      Kayit.Kesildi := not Sorgu.Eof;
      Kayit.Satir := Result.RecordCount;
    except
      Result.Free;
      raise;
    end;
  finally
    Sonuc.Free;
  end;
end;

{ Veritabani sonuclarinin kolon birlesimiyle tek tablo kurar: ilk kolon VERITABANI. Blob kolonlar metne cevrilir. }
function Birlestir(const Adlar: TArray<string>; Tablolar: TList<TFDMemTable>): TFDMemTable;
var
  Birlesim: TFDMemTable;
  Kaynak: TFDMemTable;
  Tanim, Yeni: TFieldDef;
  i, K: Integer;
  Alan: TField;
begin
  Birlesim := TFDMemTable.Create(nil);
  try
    Yeni := Birlesim.FieldDefs.AddFieldDef;
    Yeni.Name := VERITABANI_KOLONU;
    Yeni.DataType := ftWideString;
    Yeni.Size := 128;
    for Kaynak in Tablolar do
      for i := 0 to Kaynak.FieldDefs.Count - 1 do
      begin
        Tanim := Kaynak.FieldDefs[i];
        if Birlesim.FieldDefs.IndexOf(Tanim.Name) < 0 then
        begin
          Yeni := Birlesim.FieldDefs.AddFieldDef;
          Yeni.Name := Tanim.Name;
          if BlobMu(Tanim.DataType) then
          begin
            Yeni.DataType := ftWideString;
            Yeni.Size := 1000;
          end
          else
          begin
            Yeni.DataType := Tanim.DataType;
            Yeni.Size := Tanim.Size;
            Yeni.Precision := Tanim.Precision;
          end;
        end;
      end;
    Birlesim.CreateDataSet;
    for K := 0 to Tablolar.Count - 1 do
    begin
      Kaynak := Tablolar[K];
      Kaynak.First;
      while not Kaynak.Eof do
      begin
        Birlesim.Append;
        Birlesim.FieldByName(VERITABANI_KOLONU).AsString := Adlar[K];
        for i := 0 to Kaynak.FieldCount - 1 do
        begin
          Alan := Birlesim.FindField(Kaynak.Fields[i].FieldName);
          if (Alan = nil) or Kaynak.Fields[i].IsNull then
            Continue;
          try
            if BlobMu(Kaynak.Fields[i].DataType) then
              Alan.AsString := Copy(Kaynak.Fields[i].AsString, 1, 1000)
            else
              Alan.Value := Kaynak.Fields[i].Value;
          except
            { Baska veritabaninda ayni adli kolonun tipi uymuyorsa hucre bos birakilir. }
            Alan.Clear;
          end;
        end;
        Birlesim.Post;
        Kaynak.Next;
      end;
    end;
    Birlesim.First;
    Result := Birlesim;
  except
    Birlesim.Free;
    raise;
  end;
end;

function CokluSorguCalistir(const Adlar: TArray<string>; const Sql: string; Ilerleme: TProc<string>): TCokluSonuc;
var
  Tablolar: TList<TFDMemTable>;
  TamamAdlari: TList<string>;
  Ad: string;
  Kayit: TCokluKayit;
  Tanim: TBaglantiTanimi;
  Bag: TAcikBaglanti;
  Gecici: Boolean;
  Mem: TFDMemTable;
  Saat: TStopwatch;
begin
  Result := TCokluSonuc.Create;
  Tablolar := TList<TFDMemTable>.Create;
  TamamAdlari := TList<string>.Create;
  try
    for Ad in Adlar do
    begin
      if Assigned(Ilerleme) then
        Ilerleme(Ad);
      Kayit := Default(TCokluKayit);
      Kayit.Ad := Ad;
      Bag := FbAcikBaglanti(Ad);
      Gecici := False;
      Saat := TStopwatch.StartNew;
      try
        try
          if Bag = nil then
          begin
            if not KayitliBaglantiBul(Ad, Tanim) or (Tanim.Sifre = '') then
            begin
              Kayit.Durum := cdAtlandi;
              Kayit.Cumle := T('COKLU_SIFRE_YOK');
              Continue;
            end;
            Bag := FbGeciciBaglan(Tanim);
            Gecici := True;
          end;
          Mem := SonucuAl(Bag, Sql, Kayit);
          Tablolar.Add(Mem);
          TamamAdlari.Add(Ad);
          Kayit.Durum := cdTamam;
          Kayit.Sure := Saat.ElapsedMilliseconds;
        except
          on E: Exception do
          begin
            Kayit.Durum := cdHata;
            Kayit.Cumle := HataMetniniCevir(E);
            Kayit.Ayrinti := E.Message;
          end;
        end;
      finally
        if Gecici then
          Bag.Free;
        Result.Kayitlar.Add(Kayit);
      end;
    end;
    if Tablolar.Count > 0 then
      Result.Tablo := Birlestir(TamamAdlari.ToArray, Tablolar);
  finally
    for Mem in Tablolar do
      Mem.Free;
    Tablolar.Free;
    TamamAdlari.Free;
  end;
end;

end.
