{ uSunucuBul.pas - Bir bilgisayarda calisan Firebird sunucularini bulur (Baglanti penceresindeki "Sunucular" dugmesi).

  3050-3069 portlari es zamanli taranir. Acik olan her porta Firebird'in ag protokolunun ilk paketi (op_connect)
  gonderilir; Firebird sunucusu op_accept, op_cond_accept, op_accept_data, op_cont_auth (3.0 ve ustu, kimlik dogrulamaya
  devam ister) veya op_reject ile yanit verir. Yanit bu degilse port baska bir programindir. Kullanici adi ve sifre
  gerekmez.

  Surum: paket her seferinde TEK bir protokol surumu teklif eder (17, 16, 15, 14, 13, 12 sirasiyla); sunucunun kabul
  ettigi en yuksek protokolden yaklasik Firebird surumu cikar (olculdu: 2.5 = 12, 3.0.14 = 15, 4.0.7 ve 5.0.4 = 17;
  yani 4.0 ile 5.0 ayirt edilemez, "4.0 / 5.0" yazilir). Tam surum numarasi baglaninca ogrenilir.

  Hedef: Firebird 2.5, 3.0, 4.0, 5.0. }
unit uSunucuBul;

interface

type
  TBulunanSunucu = record
    Sunucu: string;
    Port: Integer;
    { Sunucunun kabul ettigi en yuksek protokol surumu (13 gibi, bilinmiyorsa 0) ve ondan cikan yaklasik surum ("3.0"). }
    Protokol: Integer;
    Surum: string;
  end;

const
  ILK_PORT = 3050;
  SON_PORT = 3069;

{ Sunucu bos, localhost ya da 127.0.0.1 ise yerel makine. Bulunanlar port sirasiyla gelir. Sunucu yoksa ya da
  erisilemiyorsa bos dizi doner (hata firlatmaz). }
function SunuculariBul(const Sunucu: string): TArray<TBulunanSunucu>;

{ Bir portta Firebird sunucusu var mi. Protokol: kabul edilen en yuksek surum (surum anlasilamadiysa 0). }
function FirebirdPortuMu(const Sunucu: string; Port: Integer; out Protokol: Integer): Boolean;

implementation

uses
  System.SysUtils, System.Generics.Collections, System.Generics.Defaults, System.Threading, Winapi.Windows,
  Winapi.Winsock2;

type
  TYanit = (yYok, yKabul, yRed);

const
  ZAMAN_ASIMI_BAGLAN_MS = 300;
  ZAMAN_ASIMI_YANIT_MS = 800;
  OP_CONNECT = 1;
  OP_ATTACH = 19;
  OP_ACCEPT = 3;
  OP_REJECT = 4;
  OP_CONT_AUTH = 92;
  OP_ACCEPT_DATA = 94;
  OP_COND_ACCEPT = 98;
  PROTOKOL_BAYRAGI = $8000;
  { Denenen protokol surumleri, yuksekten alca. }
  PROTOKOLLER: array[0..5] of Integer = (17, 16, 15, 14, 13, 12);

function Baglan(const Adres: AnsiString; Port: Integer; out Soket: TSocket): Boolean;
var
  Hedef: TSockAddrIn;
  Kayit: PHostEnt;
  Ag: u_long;
  Yazma, Hata: TFDSet;
  Sure: TTimeVal;
  HataKodu, Boy: Integer;
begin
  Result := False;
  Soket := socket(AF_INET, SOCK_STREAM, IPPROTO_TCP);
  if Soket = INVALID_SOCKET then
    Exit;
  FillChar(Hedef, SizeOf(Hedef), 0);
  Hedef.sin_family := AF_INET;
  Hedef.sin_port := htons(Port);
  Hedef.sin_addr.S_addr := inet_addr(PAnsiChar(Adres));
  if Hedef.sin_addr.S_addr = u_long(INADDR_NONE) then
  begin
    Kayit := gethostbyname(PAnsiChar(Adres));
    if (Kayit = nil) or (Kayit^.h_addr_list = nil) or (Kayit^.h_addr_list^ = nil) then
    begin
      closesocket(Soket);
      Exit;
    end;
    Move(Kayit^.h_addr_list^^, Hedef.sin_addr, SizeOf(Hedef.sin_addr));
  end;
  Ag := 1;
  ioctlsocket(Soket, FIONBIO, Ag);
  connect(Soket, TSockAddr(Hedef), SizeOf(Hedef));
  FillChar(Yazma, SizeOf(Yazma), 0);
  FillChar(Hata, SizeOf(Hata), 0);
  Yazma.fd_count := 1;
  Yazma.fd_array[0] := Soket;
  Hata.fd_count := 1;
  Hata.fd_array[0] := Soket;
  Sure.tv_sec := 0;
  Sure.tv_usec := ZAMAN_ASIMI_BAGLAN_MS * 1000;
  if (select(0, nil, @Yazma, @Hata, @Sure) > 0) and (Yazma.fd_count > 0) then
  begin
    HataKodu := 0;
    Boy := SizeOf(HataKodu);
    getsockopt(Soket, SOL_SOCKET, SO_ERROR, PAnsiChar(@HataKodu), Boy);
    Result := HataKodu = 0;
  end;
  if not Result then
    closesocket(Soket)
  else
  begin
    Ag := 0;
    ioctlsocket(Soket, FIONBIO, Ag);
  end;
end;

procedure IntEkle(var Veri: TBytes; Deger: Cardinal);
var
  Yer: Integer;
begin
  Yer := Length(Veri);
  SetLength(Veri, Yer + 4);
  Veri[Yer] := (Deger shr 24) and $FF;
  Veri[Yer + 1] := (Deger shr 16) and $FF;
  Veri[Yer + 2] := (Deger shr 8) and $FF;
  Veri[Yer + 3] := Deger and $FF;
end;

{ XDR "opaque": uzunluk (4 bayt), veri, 4'un katina dolgu. }
procedure BlokEkle(var Veri: TBytes; const Blok: TBytes);
var
  Yer, Dolgu: Integer;
begin
  IntEkle(Veri, Length(Blok));
  Yer := Length(Veri);
  Dolgu := (4 - (Length(Blok) mod 4)) mod 4;
  SetLength(Veri, Yer + Length(Blok) + Dolgu);
  if Length(Blok) > 0 then
    Move(Blok[0], Veri[Yer], Length(Blok));
end;

{ op_connect paketi: yalniz Surum protokolu teklif edilir (11 ve uzeri protokol bayragiyla). }
function ElSikismaPaketi(Surum: Integer): TBytes;
var
  Dosya, Kullanici: TBytes;
begin
  Result := nil;
  Dosya := TBytes.Create(Ord('x'));
  { CNCT_user (1) 'x', CNCT_host (4) 'x', CNCT_user_verification (6) bos }
  Kullanici := TBytes.Create(1, 1, Ord('x'), 4, 1, Ord('x'), 6, 0);
  IntEkle(Result, OP_CONNECT);
  IntEkle(Result, OP_ATTACH);
  IntEkle(Result, 2);
  IntEkle(Result, 1);
  BlokEkle(Result, Dosya);
  IntEkle(Result, 1);
  BlokEkle(Result, Kullanici);
  IntEkle(Result, PROTOKOL_BAYRAGI or Cardinal(Surum));
  IntEkle(Result, 1);
  IntEkle(Result, 0);
  IntEkle(Result, 5);
  IntEkle(Result, 1);
end;

function OkuInt(const Veri: array of Byte; Yer: Integer): Cardinal;
begin
  Result := (Cardinal(Veri[Yer]) shl 24) or (Cardinal(Veri[Yer + 1]) shl 16) or (Cardinal(Veri[Yer + 2]) shl 8) or
    Cardinal(Veri[Yer + 3]);
end;

{ Sunucuya tek protokol surumu teklif eder: kabul (accept / cond_accept / accept_data / cont_auth), red ya da yanit yok. }
function SurumSor(const Adres: AnsiString; Port, Surum: Integer): TYanit;
var
  Soket: TSocket;
  Paket: TBytes;
  Yanit: array[0..63] of Byte;
  Alinan, Sure: Integer;
begin
  Result := yYok;
  if not Baglan(Adres, Port, Soket) then
    Exit;
  try
    Sure := ZAMAN_ASIMI_YANIT_MS;
    setsockopt(Soket, SOL_SOCKET, SO_RCVTIMEO, PAnsiChar(@Sure), SizeOf(Sure));
    Paket := ElSikismaPaketi(Surum);
    if send(Soket, Paket[0], Length(Paket), 0) <= 0 then
      Exit;
    FillChar(Yanit, SizeOf(Yanit), 0);
    Alinan := recv(Soket, Yanit, SizeOf(Yanit), 0);
    if Alinan < 4 then
      Exit;
    case OkuInt(Yanit, 0) of
      OP_ACCEPT, OP_ACCEPT_DATA, OP_COND_ACCEPT, OP_CONT_AUTH:
        Result := yKabul;
      OP_REJECT:
        Result := yRed;
    end;
  finally
    closesocket(Soket);
  end;
end;

function FirebirdPortuMu(const Sunucu: string; Port: Integer; out Protokol: Integer): Boolean;
var
  Adres: AnsiString;
  Surum: Integer;
  Yanit: TYanit;
begin
  Result := False;
  Protokol := 0;
  Adres := AnsiString(Trim(Sunucu));
  if (Adres = '') or SameText(string(Adres), 'localhost') then
    Adres := '127.0.0.1';
  for Surum in PROTOKOLLER do
  begin
    Yanit := SurumSor(Adres, Port, Surum);
    if Yanit = yKabul then
    begin
      Protokol := Surum;
      Exit(True);
    end;
    if Yanit = yRed then
      Result := True
    else if not Result then
      Exit;
  end;
end;

function ProtokoldenSurum(Protokol: Integer): string;
begin
  if Protokol <= 0 then
    Result := ''
  else if Protokol <= 12 then
    Result := '2.x'
  else if Protokol <= 15 then
    Result := '3.0'
  else
    Result := '4.0 / 5.0';
end;

function SunuculariBul(const Sunucu: string): TArray<TBulunanSunucu>;
var
  Liste: TList<TBulunanSunucu>;
  Veri: TWSAData;
  Ad: string;
begin
  Liste := TList<TBulunanSunucu>.Create;
  try
    if WSAStartup(MakeWord(2, 2), Veri) = 0 then
    try
      Ad := Trim(Sunucu);
      if Ad = '' then
        Ad := 'localhost';
      { Portlar es zamanli taranir (kapali port yerel makinede bile yuzlerce ms bekletir; sirayla 20 port ~5 sn surerdi). }
      TParallel.For(ILK_PORT, SON_PORT,
        procedure(Port: Integer)
        var
          Bulunan: TBulunanSunucu;
          Surum: Integer;
        begin
          if FirebirdPortuMu(Ad, Port, Surum) then
          begin
            Bulunan.Sunucu := Ad;
            Bulunan.Port := Port;
            Bulunan.Protokol := Surum;
            Bulunan.Surum := ProtokoldenSurum(Surum);
            TMonitor.Enter(Liste);
            try
              Liste.Add(Bulunan);
            finally
              TMonitor.Exit(Liste);
            end;
          end;
        end);
    finally
      WSACleanup;
    end;
    Liste.Sort(TComparer<TBulunanSunucu>.Construct(
      function(const A, B: TBulunanSunucu): Integer
      begin
        Result := A.Port - B.Port;
      end));
    Result := Liste.ToArray;
  finally
    Liste.Free;
  end;
end;

end.
