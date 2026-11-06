unit uTabloKopya;

{ Bir veritabanindaki tabloyu baska bir veritabanina (ya da ayni veritabaninda baska bir ada) kopyalama (Asama 7f).

  Hedeflenen Firebird surumleri: 2.5, 3.0, 4.0, 5.0 (iki veritabani farkli surumde olabilir)

  Kurallar (sade ve guvenli):
    - Kaynak tabloya DOKUNULMAZ (salt okunur islemle okunur).
    - Hedefte tablo YOKSA once yapisi olusturulur (kolonlar, PRIMARY KEY / UNIQUE / CHECK, indexler; uDDL.TabloYapiScripti) ve
      onaylanir. Yabanci anahtarlar, tetikleyiciler, yetkiler ve generator degerleri KOPYALANMAZ.
      Kolonlar bir domain kullaniyorsa hedefte o domain onceden olmalidir; yoksa hicbir sey yapilmaz ve eksik domain'ler soylenir.
    - Hedefte tablo VARSA yapisina dokunulmaz; yalniz verileri, adi ayni olan kolonlara eklenir (INSERT).
    - Veriler hedefte TEK islemde eklenir: hata ya da iptalde hicbir satir eklenmez. (Tablo az once olusturulduysa bos kalir;
      yeniden denemek icin "var olan tabloya ekle" yolu kullanilir.)
    - Hesaplanan ve GENERATED ALWAYS kimlik kolonlarinin verisi kopyalanmaz (hedefte kendiliginden uretilir).
  Hata istisna olarak firlamaz, sonuc kaydina yazilir. }

interface

uses
  System.SysUtils, System.Classes, System.Generics.Collections, uBaglanti, uAktar;

type
  TKopyaSonucu = record
    Basarili: Boolean;
    Iptal: Boolean;
    { Hedefte tablo bu islemle olusturuldu (hata olsa bile). }
    TabloOlustu: Boolean;
    Kopyalanan: Int64;
    Cumle: string;
    Ayrinti: string;
    { Hedefte calisan CREATE komutlari (SQL mesaji icin). }
    Komutlar: TArray<string>;
  end;

{ Hedefte bu adda tablo var mi? (Ad, AdHazirla ile hazirlanmis olmali.) }
function HedefteTabloVarMi(Hedef: TAcikBaglanti; const Ad: string): Boolean;

{ Kaynak tablonun kolonlari hedefte olmayan domain kullaniyorsa o domain adlari ", " ile; yoksa bos. }
function EksikDomainler(Kaynak: TAcikBaglanti; const Tablo: string; Hedef: TAcikBaglanti): string;

{ Hedefte CREATE TABLE olarak calisacak komutlar (onay penceresinde gosterilir). }
function KopyaYapiScripti(Kaynak: TAcikBaglanti; const Tablo, HedefAd: string): string;

{ Kopyalar. VeriDe False ise yalniz yapi olusturulur (hedefte tablo yokken). Ilerleme: aktarilan satir sayisi, Iptal True yapilirsa
  veriler eklenmez. Kaynak ve Hedef ayni baglanti olabilir (ayni veritabaninda baska ada kopya). }
function TabloKopyala(Kaynak: TAcikBaglanti; const Tablo: string; Hedef: TAcikBaglanti; const HedefAd: string;
  VeriDe: Boolean; Ilerleme: TCsvIlerlemesi): TKopyaSonucu;

implementation

uses
  Data.DB, FireDAC.Stan.Intf, FireDAC.Stan.Option, FireDAC.Stan.Param, FireDAC.Comp.Client,
  System.Variants, uDil, uMetadata, uDDL, uProsedur;

const
  ILERLEME_ARALIGI = 200;

{ Tek parametreli sorgunun ilk degeri (yazi olarak). }
function TekDegerYazi(Bag: TAcikBaglanti; const Sql, Parametre: string): string;
begin
  Result := VarToStr(Bag.Baglanti.ExecSQLScalar(Sql, [Parametre]));
end;

function HedefteTabloVarMi(Hedef: TAcikBaglanti; const Ad: string): Boolean;
begin
  Result := TekDegerYazi(Hedef, 'select count(*) from rdb$relations where rdb$relation_name = :A', Ad) <> '0';
end;

function EksikDomainler(Kaynak: TAcikBaglanti; const Tablo: string; Hedef: TAcikBaglanti): string;
var
  Kolon: TKolonBilgisi;
begin
  Result := '';
  for Kolon in KolonlariOku(Kaynak, Tablo) do
    if (Kolon.Domain <> '') and (TekDegerYazi(Hedef, 'select count(*) from rdb$fields where rdb$field_name = :A', Kolon.Domain) = '0') and
      (Pos(Kolon.Domain, Result) = 0) then
    begin
      if Result <> '' then
        Result := Result + ', ';
      Result := Result + Kolon.Domain;
    end;
end;

function KopyaYapiScripti(Kaynak: TAcikBaglanti; const Tablo, HedefAd: string): string;
begin
  Result := TabloYapiScripti(Kaynak, Tablo, HedefAd);
end;

{ Veri kopyalanabilen kolon adlari: hesaplanan ve GENERATED ALWAYS kimlik kolonlari yok. }
function KopyaKolonlari(Bag: TAcikBaglanti; const Tablo: string): TArray<string>;
var
  Kolon: TKolonBilgisi;
  Liste: TList<string>;
begin
  Liste := TList<string>.Create;
  try
    for Kolon in KolonlariOku(Bag, Tablo) do
      if (Kolon.Hesaplanan = '') and not (Kolon.Kimlik and Kolon.KimlikHep) then
        Liste.Add(Kolon.Ad);
    Result := Liste.ToArray;
  finally
    Liste.Free;
  end;
end;

{ Iki listenin ortak adlari (kaynaktaki sirayla, buyuk/kucuk harf farksiz). }
function OrtakAdlar(const Kaynak, Hedef: TArray<string>): TArray<string>;
var
  Ad, Aday: string;
  Liste: TList<string>;
begin
  Liste := TList<string>.Create;
  try
    for Ad in Kaynak do
      for Aday in Hedef do
        if SameText(Ad, Aday) then
        begin
          Liste.Add(Ad);
          Break;
        end;
    Result := Liste.ToArray;
  finally
    Liste.Free;
  end;
end;

{ Verileri tek islemde ekler. Hata istisna olarak firlar (cagiran toparlar). }
procedure VeriKopyala(Kaynak: TAcikBaglanti; const Tablo: string; Hedef: TAcikBaglanti; const HedefAd: string;
  Ilerleme: TCsvIlerlemesi; var Sonuc: TKopyaSonucu);
var
  Adlar: TArray<string>;
  Okuma, Yazma: TFDTransaction;
  Oku, Ekle: TFDQuery;
  Parametreler: TArray<TFDParam>;
  SelectKolon, InsertKolon, Degerler: string;
  i: Integer;
  Satir: Int64;
  Iptal: Boolean;
begin
  Adlar := OrtakAdlar(KopyaKolonlari(Kaynak, Tablo), KopyaKolonlari(Hedef, HedefAd));
  if Length(Adlar) = 0 then
    raise EKayitKurali.Create(T('ERR_KOPYA_ORTAK_KOLON_YOK'));
  SelectKolon := '';
  Degerler := '';
  for i := 0 to High(Adlar) do
  begin
    if i > 0 then
    begin
      SelectKolon := SelectKolon + ', ';
      Degerler := Degerler + ', ';
    end;
    SelectKolon := SelectKolon + AdiYaz(Kaynak, Adlar[i]);
    Degerler := Degerler + ':P' + IntToStr(i);
  end;
  { Hedefte kolon adlari ayni olsa da yazilisi (buyuk/kucuk harf, tirnak) hedefe gore yazilir. }
  InsertKolon := '';
  for i := 0 to High(Adlar) do
  begin
    if i > 0 then
      InsertKolon := InsertKolon + ', ';
    InsertKolon := InsertKolon + AdiYaz(Hedef, Adlar[i]);
  end;
  Okuma := TFDTransaction.Create(nil);
  Yazma := TFDTransaction.Create(nil);
  Oku := TFDQuery.Create(nil);
  Ekle := TFDQuery.Create(nil);
  try
    Okuma.Connection := Kaynak.Baglanti;
    Okuma.Options.ReadOnly := True;
    Okuma.Options.AutoCommit := False;
    Oku.Connection := Kaynak.Baglanti;
    Oku.Transaction := Okuma;
    Oku.FetchOptions.Mode := fmOnDemand;
    Oku.FetchOptions.RowsetSize := 500;
    Oku.SQL.Text := 'SELECT ' + SelectKolon + ' FROM ' + AdiYaz(Kaynak, Tablo);
    Yazma.Connection := Hedef.Baglanti;
    Yazma.Options.AutoCommit := False;
    Ekle.Connection := Hedef.Baglanti;
    Ekle.Transaction := Yazma;
    Ekle.SQL.Text := 'INSERT INTO ' + AdiYaz(Hedef, HedefAd) + ' (' + InsertKolon + ') VALUES (' + Degerler + ')';
    Okuma.StartTransaction;
    Yazma.StartTransaction;
    Satir := 0;
    try
      try
        Oku.Open;
        SetLength(Parametreler, Length(Adlar));
        for i := 0 to High(Adlar) do
          Parametreler[i] := Ekle.ParamByName('P' + IntToStr(i));
        while not Oku.Eof do
        begin
          Inc(Satir);
          for i := 0 to High(Adlar) do
            Parametreler[i].AssignFieldValue(Oku.Fields[i], Oku.Fields[i].Value);
          Ekle.ExecSQL;
          Inc(Sonuc.Kopyalanan);
          if Assigned(Ilerleme) and (Sonuc.Kopyalanan mod ILERLEME_ARALIGI = 0) then
          begin
            Iptal := False;
            Ilerleme(Sonuc.Kopyalanan, Iptal);
            if Iptal then
            begin
              Yazma.Rollback;
              Sonuc.Iptal := True;
              Sonuc.Kopyalanan := 0;
              Exit;
            end;
          end;
          Oku.Next;
        end;
        Yazma.Commit;
        Sonuc.Basarili := True;
      except
        on E: Exception do
        begin
          try
            if Yazma.Active then
              Yazma.Rollback;
          except
            { Rollback da basarisiz olursa asil hata gosterilir. }
          end;
          Sonuc.Kopyalanan := 0;
          Sonuc.Cumle := TF('ERR_KOPYA_SATIR', [Satir]) + ' ' + HataMetniniCevir(E);
          Sonuc.Ayrinti := E.Message;
        end;
      end;
    finally
      if Okuma.Active then
        Okuma.Rollback;
    end;
  finally
    Ekle.Free;
    Oku.Free;
    Yazma.Free;
    Okuma.Free;
  end;
end;

function TabloKopyala(Kaynak: TAcikBaglanti; const Tablo: string; Hedef: TAcikBaglanti; const HedefAd: string;
  VeriDe: Boolean; Ilerleme: TCsvIlerlemesi): TKopyaSonucu;
var
  Eksik: string;
  Yapi: TProsedurSonucu;
begin
  Result := Default(TKopyaSonucu);
  try
    if not HedefteTabloVarMi(Hedef, HedefAd) then
    begin
      Eksik := EksikDomainler(Kaynak, Tablo, Hedef);
      if Eksik <> '' then
      begin
        Result.Cumle := TF('ERR_KOPYA_DOMAIN', [Eksik]);
        Exit;
      end;
      Yapi := Default(TProsedurSonucu);
      MetniCalistir(Hedef, KopyaYapiScripti(Kaynak, Tablo, HedefAd), Yapi);
      Result.Komutlar := Yapi.Komutlar;
      if not Yapi.Basarili then
      begin
        Result.Cumle := Yapi.Cumle;
        Result.Ayrinti := Yapi.Ayrinti;
        Exit;
      end;
      Result.TabloOlustu := True;
    end;
    if VeriDe then
      VeriKopyala(Kaynak, Tablo, Hedef, HedefAd, Ilerleme, Result)
    else
      Result.Basarili := True;
  except
    on E: Exception do
    begin
      Result.Basarili := False;
      if E is EKayitKurali then
        Result.Cumle := E.Message
      else
      begin
        Result.Cumle := HataMetniniCevir(E);
        Result.Ayrinti := E.Message;
      end;
    end;
  end;
end;

end.
