{ uBaglanti.pas - Baglanti tanimlari, baglanma/kopma, kayitli baglanti listesi.

  Hedeflenen Firebird surumleri: 2.5, 3.0, 4.0, 5.0
  Denenen Firebird surumleri: 2.5.9, 5.0.4 (3.0 ve 4.0 henuz denenmedi)

  Istemci: Win64 derleme, uygulamanin yanindaki "istemci" klasorundeki
  fbclient.dll (Firebird 5.0, 64 bit). Tek bir fbclient.dll yuklenir, hem eski
  hem yeni sunuculara onunla baglanilir. Ikinci bir dll yuklenmez.

  Sifreler JSON'a duz yazilmaz: Windows DPAPI ile sifrelenir (sadece ayni
  Windows kullanicisi cozebilir). }
unit uBaglanti;

interface

uses
  Winapi.Windows, System.SysUtils, System.Classes, System.IOUtils, System.JSON,
  System.NetEncoding, System.Generics.Collections, System.Variants, Data.DB,
  FireDAC.Stan.Intf, FireDAC.Stan.Option, FireDAC.Stan.Error, FireDAC.UI.Intf,
  FireDAC.Phys.Intf, FireDAC.Stan.Def, FireDAC.Stan.Pool, FireDAC.Stan.Async,
  FireDAC.Phys, FireDAC.Phys.FB, FireDAC.Phys.FBDef, FireDAC.Phys.IBBase,
  FireDAC.VCLUI.Wait, FireDAC.DApt, FireDAC.Comp.Client,
  uDil;

type
  TBaglantiTanimi = record
    Ad: string;
    Sunucu: string;
    Port: Integer;
    VeritabaniYolu: string;
    Kullanici: string;
    Sifre: string;
    KarakterSeti: string;
    SifreyiKaydet: Boolean;
    Klasor: string;
  end;

  { Kayit kurali ihlali (ayni ad, bos ad vb.): mesaj kullaniciya oldugu gibi gosterilir. }
  EKayitKurali = class(Exception);

  { Acik bir baglanti. Acik baglantilar tek bir listede durur. }
  TAcikBaglanti = class
    Tanim: TBaglantiTanimi;
    Surum: string;
    { Veritabaninin SQL dialecti (1 veya 3); sorgu baglantisinin dialecti degil }
    Dialect: Integer;
    Baglanti: TFDConnection;
    destructor Destroy; override;
  end;

const
  VARSAYILAN_SUNUCU = 'localhost';
  VARSAYILAN_PORT = 3050;
  VARSAYILAN_KULLANICI = 'SYSDBA';
  VARSAYILAN_KARAKTER_SETI = 'WIN1254';
  VARSAYILAN_DIALECT = 3;

{ Kayitli baglantilar ve klasorler (baglantilar.json) }
function KayitliBaglantilar: TArray<TBaglantiTanimi>;
function KayitliKlasorler: TArray<string>;
function KayitliBaglantiBul(const Ad: string; out Tanim: TBaglantiTanimi): Boolean;
{ EskiAd doluysa o adli kayit yenisiyle degisir (ad degistirme). Klasor bilgisi eski kayittan korunur. }
procedure BaglantiKaydet(const Tanim: TBaglantiTanimi; const EskiAd: string = '');
procedure BaglantiListedenKaldir(const Ad: string);
procedure KlasorEkle(const Ad: string);
procedure KlasorYenidenAdlandir(const EskiAd, YeniAd: string);
procedure KlasorKaldir(const Ad: string);
procedure BaglantiKlasoruAyarla(const BaglantiAd, Klasor: string);
function BozukDosyaUyarisiAl: string;

{ Acik baglantilar }
function FbBaglan(const Tanim: TBaglantiTanimi): TAcikBaglanti;
{ Servis API'si (2.5 kullanici listesi) icin ayni surucu baglantisi; ikinci bir surucu acilmaz. }
function FbSurucu: TFDPhysFBDriverLink;
procedure FbBaglantiyiKes(Bag: TAcikBaglanti);
function FbAcikBaglanti(const Ad: string): TAcikBaglanti;
function FbIslemAcikMi(Bag: TAcikBaglanti): Boolean;
{ Sunucu bos, localhost ve 127.0.0.1 ayni yerel makine sayilir. }
function YerelSunucuMu(const Sunucu: string): Boolean;
{ Ayni sunucudaki ayni veritabani yolu acik bir baglantida kullaniliyorsa o baglantinin adini verir, yoksa bos. }
function FbYoluAcikBaglantidaMi(const Sunucu, Yol: string): string;

function HataMetniniCevir(Hata: Exception): string;

implementation

type
  TVeriBlob = record
    cbData: DWORD;
    pbData: PByte;
  end;
  PVeriBlob = ^TVeriBlob;

function DpapiKoru(GirdiVeri: PVeriBlob; Aciklama: PWideChar; Entropi: PVeriBlob;
  Ayrilmis: Pointer; Istem: Pointer; Bayraklar: DWORD; CiktiVeri: PVeriBlob): BOOL; stdcall;
  external 'crypt32.dll' name 'CryptProtectData';

function DpapiAc(GirdiVeri: PVeriBlob; Aciklama: PPWideChar; Entropi: PVeriBlob;
  Ayrilmis: Pointer; Istem: Pointer; Bayraklar: DWORD; CiktiVeri: PVeriBlob): BOOL; stdcall;
  external 'crypt32.dll' name 'CryptUnprotectData';

type
  { baglantilar.json icerigi: baglantilar ve (bos olanlar dahil) klasor adlari }
  TKayit = class
    Baglantilar: TList<TBaglantiTanimi>;
    Klasorler: TList<string>;
    constructor Create;
    destructor Destroy; override;
  end;

var
  GSurucu: TFDPhysFBDriverLink;
  GAcikBaglantilar: TObjectList<TAcikBaglanti>;
  GBozukDosyaUyarisi: string;

destructor TAcikBaglanti.Destroy;
begin
  Baglanti.Free;
  inherited;
end;

constructor TKayit.Create;
begin
  inherited;
  Baglantilar := TList<TBaglantiTanimi>.Create;
  Klasorler := TList<string>.Create;
end;

destructor TKayit.Destroy;
begin
  Klasorler.Free;
  Baglantilar.Free;
  inherited;
end;

{ ---------- Sifre saklama (DPAPI) ---------- }

function SifreSifrele(const Duz: string): string;
var
  Girdi, Cikti: TVeriBlob;
  Bayt: TBytes;
  Kodlayici: TBase64Encoding;
begin
  Result := '';
  if Duz = '' then
    Exit;
  Bayt := TEncoding.UTF8.GetBytes(Duz);
  Girdi.cbData := Length(Bayt);
  Girdi.pbData := @Bayt[0];
  if not DpapiKoru(@Girdi, nil, nil, nil, nil, 0, @Cikti) then
    raise Exception.Create(T('ERR_DPAPI'));
  try
    Kodlayici := TBase64Encoding.Create(0);
    try
      Result := Kodlayici.EncodeBytesToString(Cikti.pbData, Cikti.cbData);
    finally
      Kodlayici.Free;
    end;
  finally
    LocalFree(HLOCAL(Cikti.pbData));
  end;
end;

{ Cozemezse (baska Windows kullanicisi vb.) bos doner, program calismaya devam eder. }
function SifreCoz(const Sifreli: string): string;
var
  Girdi, Cikti: TVeriBlob;
  Bayt: TBytes;
begin
  Result := '';
  if Sifreli = '' then
    Exit;
  try
    Bayt := TNetEncoding.Base64.DecodeStringToBytes(Sifreli);
  except
    Exit;
  end;
  if Length(Bayt) = 0 then
    Exit;
  Girdi.cbData := Length(Bayt);
  Girdi.pbData := @Bayt[0];
  if not DpapiAc(@Girdi, nil, nil, nil, nil, 0, @Cikti) then
    Exit;
  try
    SetLength(Bayt, Cikti.cbData);
    if Cikti.cbData > 0 then
      Move(Cikti.pbData^, Bayt[0], Cikti.cbData);
    Result := TEncoding.UTF8.GetString(Bayt);
  finally
    LocalFree(HLOCAL(Cikti.pbData));
  end;
end;

{ ---------- Kayitli baglantilar (JSON) ---------- }

function BaglantiDosyasi: string;
begin
  Result := TPath.Combine(UygulamaVeriKlasoru, 'baglantilar.json');
end;

{ Bozuk baglanti dosyasini silmeden, tarihli bir adla yanina tasir ve kullaniciya
  gosterilecek uyariyi hazirlar. }
procedure BozukDosyayiYanaTasi;
var
  YeniAd: string;
begin
  YeniAd := BaglantiDosyasi + '.bozuk-' + FormatDateTime('yyyymmdd-hhnnss', Now);
  TFile.Move(BaglantiDosyasi, YeniAd);
  GBozukDosyaUyarisi := TF('ERR_BAGLANTI_DOSYASI_BOZUK', [YeniAd]);
end;

function BozukDosyaUyarisiAl: string;
begin
  Result := GBozukDosyaUyarisi;
  GBozukDosyaUyarisi := '';
end;

function KlasorSirasi(Liste: TList<string>; const Ad: string): Integer;
var
  i: Integer;
begin
  Result := -1;
  for i := 0 to Liste.Count - 1 do
    if SameText(Liste[i], Trim(Ad)) then
      Exit(i);
end;

function BaglantiSirasi(Kayit: TKayit; const Ad: string): Integer;
var
  i: Integer;
begin
  Result := -1;
  for i := 0 to Kayit.Baglantilar.Count - 1 do
    if SameText(Kayit.Baglantilar[i].Ad, Ad) then
      Exit(i);
end;

{ Dosyayi okur. Eski bicim (Klasor ve Klasorler olmayan) da okunur. Okunamayan
  dosya "bos liste" sayilmaz: silinmez, yanina tasinir. }
function DosyayiOku: TKayit;
var
  Kok: TJSONValue;
  Dizi, KlasorDizisi: TJSONArray;
  Oge: TJSONValue;
  Tanim: TBaglantiTanimi;
  SifreliMetin, KlasorAdi: string;
  i: Integer;
begin
  Result := TKayit.Create;
  if not TFile.Exists(BaglantiDosyasi) then
    Exit;
  Kok := TJSONObject.ParseJSONValue(TFile.ReadAllText(BaglantiDosyasi, TEncoding.UTF8));
  if (Kok = nil) or not (Kok is TJSONObject) then
  begin
    Kok.Free;
    BozukDosyayiYanaTasi;
    Exit;
  end;
  try
    if not Kok.TryGetValue<TJSONArray>('Baglantilar', Dizi) then
    begin
      BozukDosyayiYanaTasi;
      Exit;
    end;
    for Oge in Dizi do
    begin
      Tanim := Default(TBaglantiTanimi);
      Oge.TryGetValue<string>('Ad', Tanim.Ad);
      Oge.TryGetValue<string>('Sunucu', Tanim.Sunucu);
      if not Oge.TryGetValue<Integer>('Port', Tanim.Port) then
        Tanim.Port := VARSAYILAN_PORT;
      Oge.TryGetValue<string>('VeritabaniYolu', Tanim.VeritabaniYolu);
      Oge.TryGetValue<string>('Kullanici', Tanim.Kullanici);
      if not Oge.TryGetValue<string>('KarakterSeti', Tanim.KarakterSeti) then
        Tanim.KarakterSeti := VARSAYILAN_KARAKTER_SETI;
      Oge.TryGetValue<string>('Klasor', Tanim.Klasor);
      SifreliMetin := '';
      Oge.TryGetValue<string>('SifreDpapi', SifreliMetin);
      Tanim.Sifre := SifreCoz(SifreliMetin);
      Tanim.SifreyiKaydet := SifreliMetin <> '';
      Result.Baglantilar.Add(Tanim);
    end;
    { Eski biciminde Klasorler yoktur: liste bos kalir. }
    if Kok.TryGetValue<TJSONArray>('Klasorler', KlasorDizisi) then
      for Oge in KlasorDizisi do
      begin
        KlasorAdi := Oge.Value;
        if (KlasorAdi <> '') and (KlasorSirasi(Result.Klasorler, KlasorAdi) < 0) then
          Result.Klasorler.Add(KlasorAdi);
      end;
    { Elle bozulmus dosya: listede olmayan klasor adi kaybolmasin, listeye eklenir. }
    for i := 0 to Result.Baglantilar.Count - 1 do
    begin
      KlasorAdi := Result.Baglantilar[i].Klasor;
      if (KlasorAdi <> '') and (KlasorSirasi(Result.Klasorler, KlasorAdi) < 0) then
        Result.Klasorler.Add(KlasorAdi);
    end;
  finally
    Kok.Free;
  end;
end;

procedure DosyayiYaz(Kayit: TKayit);
var
  Kok: TJSONObject;
  Dizi, KlasorDizisi: TJSONArray;
  Oge: TJSONObject;
  Tanim: TBaglantiTanimi;
  KlasorAdi, Gecici: string;
begin
  Kok := TJSONObject.Create;
  try
    KlasorDizisi := TJSONArray.Create;
    Kok.AddPair('Klasorler', KlasorDizisi);
    for KlasorAdi in Kayit.Klasorler do
      KlasorDizisi.Add(KlasorAdi);
    Dizi := TJSONArray.Create;
    Kok.AddPair('Baglantilar', Dizi);
    for Tanim in Kayit.Baglantilar do
    begin
      Oge := TJSONObject.Create;
      Oge.AddPair('Ad', Tanim.Ad);
      Oge.AddPair('Sunucu', Tanim.Sunucu);
      Oge.AddPair('Port', TJSONNumber.Create(Tanim.Port));
      Oge.AddPair('VeritabaniYolu', Tanim.VeritabaniYolu);
      Oge.AddPair('Kullanici', Tanim.Kullanici);
      Oge.AddPair('KarakterSeti', Tanim.KarakterSeti);
      Oge.AddPair('Klasor', Tanim.Klasor);
      if Tanim.SifreyiKaydet then
        Oge.AddPair('SifreDpapi', SifreSifrele(Tanim.Sifre))
      else
        Oge.AddPair('SifreDpapi', '');
      Dizi.AddElement(Oge);
    end;
    { Once gecici dosyaya yazilir, sonra yerine konur: yazma yarida kesilirse
      eski dosya bozulmaz. }
    Gecici := BaglantiDosyasi + '.tmp';
    TFile.WriteAllText(Gecici, Kok.Format(2), TEncoding.UTF8);
    if not MoveFileEx(PChar(Gecici), PChar(BaglantiDosyasi),
      MOVEFILE_REPLACE_EXISTING or MOVEFILE_WRITE_THROUGH) then
      RaiseLastOSError;
  finally
    Kok.Free;
  end;
end;

function KayitliBaglantilar: TArray<TBaglantiTanimi>;
var
  Kayit: TKayit;
begin
  Kayit := DosyayiOku;
  try
    Result := Kayit.Baglantilar.ToArray;
  finally
    Kayit.Free;
  end;
end;

function KayitliKlasorler: TArray<string>;
var
  Kayit: TKayit;
begin
  Kayit := DosyayiOku;
  try
    Result := Kayit.Klasorler.ToArray;
  finally
    Kayit.Free;
  end;
end;

function KayitliBaglantiBul(const Ad: string; out Tanim: TBaglantiTanimi): Boolean;
var
  Kayit: TKayit;
  i: Integer;
begin
  Result := False;
  Tanim := Default(TBaglantiTanimi);
  Kayit := DosyayiOku;
  try
    i := BaglantiSirasi(Kayit, Ad);
    if i >= 0 then
    begin
      Tanim := Kayit.Baglantilar[i];
      Result := True;
    end;
  finally
    Kayit.Free;
  end;
end;

procedure BaglantiKaydet(const Tanim: TBaglantiTanimi; const EskiAd: string);
var
  Kayit: TKayit;
  Yeni: TBaglantiTanimi;
  i: Integer;
begin
  Kayit := DosyayiOku;
  try
    Yeni := Tanim;
    if EskiAd <> '' then
      i := BaglantiSirasi(Kayit, EskiAd)
    else
      i := BaglantiSirasi(Kayit, Tanim.Ad);
    if i >= 0 then
    begin
      { Klasor degisikligi sadece BaglantiKlasoruAyarla ile yapilir. }
      Yeni.Klasor := Kayit.Baglantilar[i].Klasor;
      Kayit.Baglantilar[i] := Yeni;
    end
    else
      Kayit.Baglantilar.Add(Yeni);
    DosyayiYaz(Kayit);
  finally
    Kayit.Free;
  end;
end;

procedure BaglantiListedenKaldir(const Ad: string);
var
  Kayit: TKayit;
  i: Integer;
begin
  Kayit := DosyayiOku;
  try
    i := BaglantiSirasi(Kayit, Ad);
    if i >= 0 then
      Kayit.Baglantilar.Delete(i);
    DosyayiYaz(Kayit);
  finally
    Kayit.Free;
  end;
end;

{ ---------- Klasorler ---------- }

procedure KlasorEkle(const Ad: string);
var
  Kayit: TKayit;
begin
  if Trim(Ad) = '' then
    raise EKayitKurali.Create(T('ERR_KLASOR_AD_BOS'));
  Kayit := DosyayiOku;
  try
    if KlasorSirasi(Kayit.Klasorler, Ad) >= 0 then
      raise EKayitKurali.Create(TF('ERR_KLASOR_VAR', [Trim(Ad)]));
    Kayit.Klasorler.Add(Trim(Ad));
    DosyayiYaz(Kayit);
  finally
    Kayit.Free;
  end;
end;

{ Klasorun icindeki baglantilar yeni ada tasinir. }
procedure KlasorYenidenAdlandir(const EskiAd, YeniAd: string);
var
  Kayit: TKayit;
  Tanim: TBaglantiTanimi;
  i, Sira: Integer;
begin
  if Trim(YeniAd) = '' then
    raise EKayitKurali.Create(T('ERR_KLASOR_AD_BOS'));
  Kayit := DosyayiOku;
  try
    Sira := KlasorSirasi(Kayit.Klasorler, EskiAd);
    if Sira < 0 then
      Exit;
    { Sadece buyuk/kucuk harf degisiyorsa (ayni klasor) cakisma sayilmaz. }
    if (KlasorSirasi(Kayit.Klasorler, YeniAd) >= 0) and not SameText(EskiAd, Trim(YeniAd)) then
      raise EKayitKurali.Create(TF('ERR_KLASOR_VAR', [Trim(YeniAd)]));
    Kayit.Klasorler[Sira] := Trim(YeniAd);
    for i := 0 to Kayit.Baglantilar.Count - 1 do
      if SameText(Kayit.Baglantilar[i].Klasor, EskiAd) then
      begin
        Tanim := Kayit.Baglantilar[i];
        Tanim.Klasor := Trim(YeniAd);
        Kayit.Baglantilar[i] := Tanim;
      end;
    DosyayiYaz(Kayit);
  finally
    Kayit.Free;
  end;
end;

{ Klasor kalkar, icindeki baglantilar silinmez, kok duzeye cikar. }
procedure KlasorKaldir(const Ad: string);
var
  Kayit: TKayit;
  Tanim: TBaglantiTanimi;
  i, Sira: Integer;
begin
  Kayit := DosyayiOku;
  try
    Sira := KlasorSirasi(Kayit.Klasorler, Ad);
    if Sira >= 0 then
      Kayit.Klasorler.Delete(Sira);
    for i := 0 to Kayit.Baglantilar.Count - 1 do
      if SameText(Kayit.Baglantilar[i].Klasor, Ad) then
      begin
        Tanim := Kayit.Baglantilar[i];
        Tanim.Klasor := '';
        Kayit.Baglantilar[i] := Tanim;
      end;
    DosyayiYaz(Kayit);
  finally
    Kayit.Free;
  end;
end;

{ Klasor bos verilirse baglanti kok duzeye cikar. }
procedure BaglantiKlasoruAyarla(const BaglantiAd, Klasor: string);
var
  Kayit: TKayit;
  Tanim: TBaglantiTanimi;
  i: Integer;
begin
  Kayit := DosyayiOku;
  try
    i := BaglantiSirasi(Kayit, BaglantiAd);
    if i < 0 then
      Exit;
    if (Klasor <> '') and (KlasorSirasi(Kayit.Klasorler, Klasor) < 0) then
      raise EKayitKurali.Create(TF('ERR_KLASOR_YOK', [Klasor]));
    Tanim := Kayit.Baglantilar[i];
    Tanim.Klasor := Klasor;
    Kayit.Baglantilar[i] := Tanim;
    DosyayiYaz(Kayit);
  finally
    Kayit.Free;
  end;
end;

{ ---------- Firebird baglantilari ---------- }

function IstemciDosyasi: string;
begin
  Result := TPath.Combine(ExtractFilePath(ParamStr(0)), 'istemci\fbclient.dll');
end;

procedure SurucuyuHazirla;
begin
  if GSurucu <> nil then
    Exit;
  if not TFile.Exists(IstemciDosyasi) then
    raise Exception.Create(TF('ERR_ISTEMCI_YOK', [IstemciDosyasi]));
  GSurucu := TFDPhysFBDriverLink.Create(nil);
  GSurucu.VendorLib := IstemciDosyasi;
end;

function FbSurucu: TFDPhysFBDriverLink;
begin
  SurucuyuHazirla;
  Result := GSurucu;
end;

function FbAcikBaglanti(const Ad: string): TAcikBaglanti;
var
  Bag: TAcikBaglanti;
begin
  Result := nil;
  for Bag in GAcikBaglantilar do
    if SameText(Bag.Tanim.Ad, Ad) then
      Exit(Bag);
end;

{ Yeni baglanti listeye eklenir, digerleri acik kalir. Ayni adli baglanti zaten
  aciksa onu verir. Kurulamazsa hata verir ve listeye bir sey eklenmez. }
function FbBaglan(const Tanim: TBaglantiTanimi): TAcikBaglanti;
var
  Yeni: TFDConnection;
  Bag: TAcikBaglanti;
begin
  Result := FbAcikBaglanti(Tanim.Ad);
  if Result <> nil then
    Exit;
  SurucuyuHazirla;
  Yeni := TFDConnection.Create(nil);
  try
    Yeni.DriverName := 'FB';
    Yeni.LoginPrompt := False;
    { Sunucu bos birakilirsa yerel baglanti (ag kullanilmaz). }
    if Tanim.Sunucu <> '' then
    begin
      Yeni.Params.Values['Server'] := Tanim.Sunucu;
      Yeni.Params.Values['Port'] := IntToStr(Tanim.Port);
      Yeni.Params.Values['Protocol'] := 'TCPIP';
    end;
    Yeni.Params.Values['Database'] := Tanim.VeritabaniYolu;
    Yeni.Params.Values['User_Name'] := Tanim.Kullanici;
    Yeni.Params.Values['Password'] := Tanim.Sifre;
    Yeni.Params.Values['CharacterSet'] := Tanim.KarakterSeti;
    Yeni.Params.Values['SQLDialect'] := IntToStr(VARSAYILAN_DIALECT);
    Yeni.Params.Values['Pooled'] := 'False';
    Yeni.Open;
    Bag := TAcikBaglanti.Create;
    Bag.Baglanti := Yeni;
    Bag.Tanim := Tanim;
    Bag.Surum := VarToStr(Yeni.ExecSQLScalar(
      'SELECT RDB$GET_CONTEXT(''SYSTEM'', ''ENGINE_VERSION'') FROM RDB$DATABASE'));
    Bag.Dialect := VARSAYILAN_DIALECT;
    try
      Bag.Dialect := StrToIntDef(VarToStr(Yeni.ExecSQLScalar('SELECT MON$SQL_DIALECT FROM MON$DATABASE')),
        VARSAYILAN_DIALECT);
    except
      { Eski surumlerde MON$ tablolari yok; dialect 3 varsayilir. }
    end;
  except
    Yeni.Free;
    raise;
  end;
  GAcikBaglantilar.Add(Bag);
  Result := Bag;
end;

{ Cagiran once bu baglantiya ait sekmeleri kapatmis olmalidir. }
procedure FbBaglantiyiKes(Bag: TAcikBaglanti);
begin
  GAcikBaglantilar.Remove(Bag);
end;

function FbIslemAcikMi(Bag: TAcikBaglanti): Boolean;
begin
  Result := (Bag <> nil) and Bag.Baglanti.Connected and Bag.Baglanti.InTransaction;
end;

function YerelSunucuMu(const Sunucu: string): Boolean;
begin
  Result := (Sunucu = '') or SameText(Sunucu, 'localhost') or (Sunucu = '127.0.0.1');
end;

function FbYoluAcikBaglantidaMi(const Sunucu, Yol: string): string;
var
  Bag: TAcikBaglanti;
  AyniSunucu: Boolean;
begin
  Result := '';
  for Bag in GAcikBaglantilar do
  begin
    AyniSunucu := SameText(Bag.Tanim.Sunucu, Sunucu) or (YerelSunucuMu(Bag.Tanim.Sunucu) and YerelSunucuMu(Sunucu));
    if AyniSunucu and SameText(Bag.Tanim.VeritabaniYolu, Yol) then
      Exit(Bag.Tanim.Ad);
  end;
end;

{ ---------- Anlasilir hata cumleleri ---------- }

function Iceriyor(const Metin, Parca: string): Boolean;
begin
  Result := Pos(LowerCase(Parca), LowerCase(Metin)) > 0;
end;

{ Firebird hata kodlari (Firebird 5.0.4 iberror_c.h dosyasindan alinmistir). }
const
  GDS_LOGIN = 335544472;
  GDS_NETWORK_ERROR = 335544721;
  GDS_CONNECT_REJECT = 335544421;
  GDS_IO_ERROR = 335544344;
  GDS_UNAVAILABLE = 335544375;
  GDS_CONN_LOST = 335544648;
  GDS_NET_READ_ERR = 335544726;
  GDS_NET_WRITE_ERR = 335544727;
  GDS_SHUTDOWN = 335544528;
  GDS_ATT_SHUTDOWN = 335544856;
  GDS_LOCK_CONFLICT = 335544345;
  GDS_DEADLOCK = 335544336;
  GDS_UPDATE_CONFLICT = 335544451;
  GDS_LOCK_TIMEOUT = 335544510;
  GDS_TOKEN_UNKNOWN = 335544634;
  GDS_OBJ_IN_USE = 335544453;
  GDS_READ_ONLY_TRANS = 335544361;
  { Asama 3d olcumu (3.0.14 sunucu): "no permission for ... access" ve "record not found for user" }
  GDS_YETKI_YOK = 335544352;
  GDS_KULLANICI_YOK = 336723990;

{ Firebird hata koduna bakar. Taninan bir kod varsa cumleyi verir. }
function KodundanCevir(Hata: EFDDBEngineException; out Cevap: string): Boolean;
var
  i: Integer;
begin
  Result := True;
  for i := 0 to Hata.ErrorCount - 1 do
  begin
    { SQL komutu hatalari: FireDAC bunlari surumden bagimsiz siniflandirir. }
    case Hata.Errors[i].Kind of
      ekUKViolated:
        begin
          Cevap := T('ERR_SQL_BENZERSIZ');
          Exit;
        end;
      ekFKViolated:
        begin
          Cevap := T('ERR_SQL_YABANCI_ANAHTAR');
          Exit;
        end;
      ekObjNotExists:
        begin
          Cevap := T('ERR_SQL_NESNE_YOK');
          Exit;
        end;
    end;
    case Hata.Errors[i].ErrorCode of
      GDS_TOKEN_UNKNOWN:
        begin
          Cevap := T('ERR_SQL_SOZDIZIMI');
          Exit;
        end;
      GDS_OBJ_IN_USE:
        begin
          Cevap := T('ERR_NESNE_KULLANIMDA');
          Exit;
        end;
      GDS_READ_ONLY_TRANS:
        begin
          Cevap := T('ERR_SALT_OKUNUR');
          Exit;
        end;
      GDS_YETKI_YOK:
        begin
          Cevap := T('ERR_YETKI_YOK');
          Exit;
        end;
      GDS_KULLANICI_YOK:
        begin
          Cevap := T('ERR_KULLANICI_YOK');
          Exit;
        end;
      GDS_LOGIN:
        begin
          Cevap := T('ERR_SIFRE');
          Exit;
        end;
      GDS_NETWORK_ERROR, GDS_CONNECT_REJECT:
        begin
          Cevap := T('ERR_SUNUCU');
          Exit;
        end;
      GDS_CONN_LOST, GDS_NET_READ_ERR, GDS_NET_WRITE_ERR, GDS_SHUTDOWN, GDS_ATT_SHUTDOWN:
        begin
          Cevap := T('ERR_KOPTU');
          Exit;
        end;
      GDS_LOCK_CONFLICT, GDS_DEADLOCK, GDS_UPDATE_CONFLICT, GDS_LOCK_TIMEOUT:
        begin
          Cevap := T('ERR_KILIT');
          Exit;
        end;
      GDS_IO_ERROR, GDS_UNAVAILABLE:
        begin
          Cevap := T('ERR_VERITABANI');
          Exit;
        end;
    end;
  end;
  Result := False;
end;

{ Hata kodu bilinmiyorsa (ornegin istemci dll yuklenemedi) ham mesajda dar
  ifadeler aranir. Hicbiri uymazsa genel cumle doner. }
function MetindenCevir(const HamMesaj: string): string;
begin
  if Iceriyor(HamMesaj, 'vendor library') or Iceriyor(HamMesaj, 'fbclient') then
    Result := T('ERR_ISTEMCI')
  else if Iceriyor(HamMesaj, 'user name and password') or
    Iceriyor(HamMesaj, 'incorrect user name') then
    Result := T('ERR_SIFRE')
  else if Iceriyor(HamMesaj, 'network request') or Iceriyor(HamMesaj, 'connection refused') then
    Result := T('ERR_SUNUCU')
  else if Iceriyor(HamMesaj, 'i/o error') or Iceriyor(HamMesaj, 'unavailable database') then
    Result := T('ERR_VERITABANI')
  else if Iceriyor(HamMesaj, 'token unknown') or Iceriyor(HamMesaj, 'sql error code = -104') then
    Result := T('ERR_SQL_SOZDIZIMI')
  { Olcum (2.5.9): prosedur govdesinde olmayan degisken/kolon "Column unknown" (-206) verir, FireDAC bunu
    ekObjNotExists saymaz. }
  else if Iceriyor(HamMesaj, 'column unknown') or Iceriyor(HamMesaj, 'table unknown') or
    Iceriyor(HamMesaj, 'procedure unknown') then
    Result := T('ERR_SQL_NESNE_YOK')
  { Olcum (2.5.9, DROP PROCEDURE): "cannot delete ... there are N dependencies". }
  else if Iceriyor(HamMesaj, 'dependencies') then
    Result := T('ERR_NESNE_BAGIMLI')
  { Olcum (5.0.4, AFTER tetikleyicide NEW.KOLON atamasi): "attempted update of read-only column TABLO.KOLON". }
  else if Iceriyor(HamMesaj, 'read-only column') then
    Result := T('ERR_SALT_OKUNUR_KOLON')
  else
    Result := T('ERR_GENEL');
end;

{ Nesne baska bir sonuc tarafindan kullaniliyorsa FireDAC hata listesinde isc_obj_in_use kodu
  gelmez (olcum: 5.0.4'te ilk kod 335544351 veya 335544345 olur), "object ... is in use" yalnizca
  mesaj metnindedir. Bu yuzden once metne bakilir; yoksa kayit kilidi cumlesi yaniltici olurdu. }
{ "Problematic key value is ("PLG$USER_NAME" = 'ADI')" metninden kullanici adini alir; bulunamazsa genel cumle. }
function KullaniciVarCumlesi(const HamMesaj: string): string;
var
  Bas, Son: Integer;
  Anahtar: string;
begin
  Bas := Pos('"PLG$USER_NAME" = ''', HamMesaj);
  Anahtar := '"PLG$USER_NAME" = ''';
  if Bas = 0 then
  begin
    Bas := Pos('"RDB$USER_NAME" = ''', HamMesaj);
    Anahtar := '"RDB$USER_NAME" = ''';
  end;
  if Bas > 0 then
  begin
    Bas := Bas + Length(Anahtar);
    Son := Pos('''', Copy(HamMesaj, Bas, MaxInt));
    if Son > 1 then
      Exit(TF('ERR_KULLANICI_VAR', [Copy(HamMesaj, Bas, Son - 1)]));
  end;
  Result := T('ERR_KULLANICI_VAR_GENEL');
end;

function HataMetniniCevir(Hata: Exception): string;
begin
  if Iceriyor(Hata.Message, '" is in use') then
    Exit(T('ERR_NESNE_KULLANIMDA'));
  { CREATE USER hatalari (3.0+, olcum 3.0.14 ve 4.0.7): iki farkli neden ayni ilk kodu (336723987, "add record error")
    tasir, bu yuzden kodla degil metinle ayrilir. 2.5'in metni farkli olabilir (sunucuda olculmedi). }
  { 3.0+: tablo PLG$SRP_VIEW / PLG$SRP; 2.5 (olcum 2.5.9): tablo USERS / RDB$USERS. }
  if Iceriyor(Hata.Message, 'no permission') and
    (Iceriyor(Hata.Message, 'PLG$SRP_VIEW') or Iceriyor(Hata.Message, 'to TABLE USERS')) then
    Exit(T('ERR_KULLANICI_YONETIM_YETKI'));
  if Iceriyor(Hata.Message, 'violation of PRIMARY or UNIQUE KEY') and
    (Iceriyor(Hata.Message, 'PLG$SRP') or Iceriyor(Hata.Message, 'RDB$USERS')) then
    Exit(KullaniciVarCumlesi(Hata.Message));
  { Olcum (2.5.9, yetkisiz ALTER PROCEDURE): kod 335544352 gelmiyor, yalniz "no permission for protect access to
    PROCEDURE X" metni var. Erisim turu (protect, INSERT, DELETE, ALTER...) ne olursa olsun ayni cumle. }
  if Iceriyor(Hata.Message, 'no permission for') then
    Exit(T('ERR_YETKI_YOK'));
  { Olcum (3f, 2.5.9 - 5.0.4): view kolonu baska view tarafindan kullaniliyorsa "Column X from table V is referenced in
    view W"; DROP'ta "cannot delete ... there are N dependencies". Kod 2.5'te nesne-yok koduyla karisabildigi icin
    kodlardan ONCE metne bakilir. }
  if Iceriyor(Hata.Message, 'is referenced in') or Iceriyor(Hata.Message, 'dependencies') then
    Exit(T('ERR_NESNE_BAGIMLI'));
  if (Hata is EFDDBEngineException) and KodundanCevir(EFDDBEngineException(Hata), Result) then
    Exit;
  Result := MetindenCevir(Hata.Message);
end;

initialization
  GAcikBaglantilar := TObjectList<TAcikBaglanti>.Create(True);

finalization
  FreeAndNil(GAcikBaglantilar);
  FreeAndNil(GSurucu);

end.
