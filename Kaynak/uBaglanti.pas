{ uBaglanti.pas - Baglanti tanimlari, baglanma/kopma, kayitli baglanti listesi.

  Test edilen Firebird surumleri: 2.5, 3.0, 4.0, 5.0
  (Asama 1'de denenenler: 2.5.9 ve 5.0.4)

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
  end;

const
  VARSAYILAN_SUNUCU = 'localhost';
  VARSAYILAN_PORT = 3050;
  VARSAYILAN_KULLANICI = 'SYSDBA';
  VARSAYILAN_KARAKTER_SETI = 'WIN1254';
  VARSAYILAN_DIALECT = 3;

function KayitliBaglantilar: TArray<TBaglantiTanimi>;
procedure BaglantiKaydet(const Tanim: TBaglantiTanimi);
procedure BaglantiListedenKaldir(const Ad: string);

procedure FbBaglan(const Tanim: TBaglantiTanimi);
procedure FbBaglantiyiKes;
function FbBagliMi: Boolean;
function FbBaglantisi: TFDConnection;
function FbAktifBaglantiAdi: string;
function FbSurum: string;
function FbIslemAcikMi: Boolean;

function HataMetniniCevir(const HamMesaj: string): string;

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

var
  GSurucu: TFDPhysFBDriverLink;
  GBaglanti: TFDConnection;
  GSurum: string;
  GAktifAd: string;

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

function ListeyiOku: TList<TBaglantiTanimi>;
var
  Kok: TJSONValue;
  Dizi: TJSONArray;
  Oge: TJSONValue;
  Tanim: TBaglantiTanimi;
  SifreliMetin: string;
begin
  Result := TList<TBaglantiTanimi>.Create;
  if not TFile.Exists(BaglantiDosyasi) then
    Exit;
  Kok := TJSONObject.ParseJSONValue(TFile.ReadAllText(BaglantiDosyasi, TEncoding.UTF8));
  if Kok = nil then
    Exit;
  try
    if not Kok.TryGetValue<TJSONArray>('Baglantilar', Dizi) then
      Exit;
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
      SifreliMetin := '';
      Oge.TryGetValue<string>('SifreDpapi', SifreliMetin);
      Tanim.Sifre := SifreCoz(SifreliMetin);
      Tanim.SifreyiKaydet := SifreliMetin <> '';
      Result.Add(Tanim);
    end;
  finally
    Kok.Free;
  end;
end;

procedure ListeyiYaz(Liste: TList<TBaglantiTanimi>);
var
  Kok: TJSONObject;
  Dizi: TJSONArray;
  Oge: TJSONObject;
  Tanim: TBaglantiTanimi;
begin
  Kok := TJSONObject.Create;
  try
    Dizi := TJSONArray.Create;
    Kok.AddPair('Baglantilar', Dizi);
    for Tanim in Liste do
    begin
      Oge := TJSONObject.Create;
      Oge.AddPair('Ad', Tanim.Ad);
      Oge.AddPair('Sunucu', Tanim.Sunucu);
      Oge.AddPair('Port', TJSONNumber.Create(Tanim.Port));
      Oge.AddPair('VeritabaniYolu', Tanim.VeritabaniYolu);
      Oge.AddPair('Kullanici', Tanim.Kullanici);
      Oge.AddPair('KarakterSeti', Tanim.KarakterSeti);
      if Tanim.SifreyiKaydet then
        Oge.AddPair('SifreDpapi', SifreSifrele(Tanim.Sifre))
      else
        Oge.AddPair('SifreDpapi', '');
      Dizi.AddElement(Oge);
    end;
    TFile.WriteAllText(BaglantiDosyasi, Kok.Format(2), TEncoding.UTF8);
  finally
    Kok.Free;
  end;
end;

function KayitliBaglantilar: TArray<TBaglantiTanimi>;
var
  Liste: TList<TBaglantiTanimi>;
begin
  Liste := ListeyiOku;
  try
    Result := Liste.ToArray;
  finally
    Liste.Free;
  end;
end;

procedure BaglantiKaydet(const Tanim: TBaglantiTanimi);
var
  Liste: TList<TBaglantiTanimi>;
  i: Integer;
begin
  Liste := ListeyiOku;
  try
    for i := 0 to Liste.Count - 1 do
      if SameText(Liste[i].Ad, Tanim.Ad) then
      begin
        Liste[i] := Tanim;
        ListeyiYaz(Liste);
        Exit;
      end;
    Liste.Add(Tanim);
    ListeyiYaz(Liste);
  finally
    Liste.Free;
  end;
end;

procedure BaglantiListedenKaldir(const Ad: string);
var
  Liste: TList<TBaglantiTanimi>;
  i: Integer;
begin
  Liste := ListeyiOku;
  try
    for i := Liste.Count - 1 downto 0 do
      if SameText(Liste[i].Ad, Ad) then
        Liste.Delete(i);
    ListeyiYaz(Liste);
  finally
    Liste.Free;
  end;
end;

{ ---------- Firebird baglantisi ---------- }

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

{ Yeni baglanti kurulursa eskisi kapatilir. Kurulamazsa eskisi bozulmaz. }
procedure FbBaglan(const Tanim: TBaglantiTanimi);
var
  Yeni: TFDConnection;
  Surum: string;
begin
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
    Surum := VarToStr(Yeni.ExecSQLScalar(
      'SELECT RDB$GET_CONTEXT(''SYSTEM'', ''ENGINE_VERSION'') FROM RDB$DATABASE'));
  except
    Yeni.Free;
    raise;
  end;
  FbBaglantiyiKes;
  GBaglanti := Yeni;
  GSurum := Surum;
  GAktifAd := Tanim.Ad;
end;

procedure FbBaglantiyiKes;
begin
  FreeAndNil(GBaglanti);
  GSurum := '';
  GAktifAd := '';
end;

function FbBagliMi: Boolean;
begin
  Result := (GBaglanti <> nil) and GBaglanti.Connected;
end;

function FbBaglantisi: TFDConnection;
begin
  Result := GBaglanti;
end;

function FbAktifBaglantiAdi: string;
begin
  Result := GAktifAd;
end;

function FbSurum: string;
begin
  Result := GSurum;
end;

function FbIslemAcikMi: Boolean;
begin
  Result := FbBagliMi and GBaglanti.InTransaction;
end;

{ ---------- Anlasilir hata cumleleri ---------- }

function Iceriyor(const Metin, Parca: string): Boolean;
begin
  Result := Pos(LowerCase(Parca), LowerCase(Metin)) > 0;
end;

function HataMetniniCevir(const HamMesaj: string): string;
begin
  if Iceriyor(HamMesaj, 'vendor') or Iceriyor(HamMesaj, 'fbclient') then
    Result := T('ERR_ISTEMCI')
  else if Iceriyor(HamMesaj, 'user name and password') or
    Iceriyor(HamMesaj, 'incorrect user name') or Iceriyor(HamMesaj, 'login') then
    Result := T('ERR_SIFRE')
  else if Iceriyor(HamMesaj, 'network request') or Iceriyor(HamMesaj, 'refused') or
    Iceriyor(HamMesaj, 'establish connection') or Iceriyor(HamMesaj, 'no connection could be made') or
    Iceriyor(HamMesaj, 'unknown host') then
    Result := T('ERR_SUNUCU')
  else if Iceriyor(HamMesaj, 'connection lost') or Iceriyor(HamMesaj, 'shutdown') or
    Iceriyor(HamMesaj, 'error reading data from the connection') or
    Iceriyor(HamMesaj, 'error writing data to the connection') then
    Result := T('ERR_KOPTU')
  else if Iceriyor(HamMesaj, 'lock conflict') or Iceriyor(HamMesaj, 'deadlock') or
    Iceriyor(HamMesaj, 'update conflicts') then
    Result := T('ERR_KILIT')
  else if Iceriyor(HamMesaj, 'i/o error') or Iceriyor(HamMesaj, 'unavailable database') or
    Iceriyor(HamMesaj, 'cannot open') or Iceriyor(HamMesaj, 'file') then
    Result := T('ERR_VERITABANI')
  else
    Result := T('ERR_GENEL');
end;

initialization

finalization
  FbBaglantiyiKes;
  FreeAndNil(GSurucu);

end.
