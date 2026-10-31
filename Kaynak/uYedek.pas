{ uYedek.pas - gbak ile yedek alma ve yeni dosyaya geri yukleme (Asama 3c).

  Hedeflenen Firebird surumleri: 2.5, 3.0, 4.0, 5.0
  Denenen Firebird surumleri: 5.0.4 (2.5.9 sunucuda sahibi deneyecek; 3.0 ve 4.0 henuz denenmedi)

  gbak bu bilgisayarda calisir (istemci tarafi), sunucuya ag uzerinden baglanir; yedek dosyasi (.fbk) bu
  bilgisayarda olusur. gbak.exe, fbclient.dll'in yanindaki "istemci" klasorundedir (64 bit Firebird 5.0).
  Windows'a ve gbak'a bagli her sey bu unit'in arkasindadir.

  Geri yukleme yalnizca YENI dosyaya yapilir (gbak -c); -r (replace) hic kullanilmaz.
  Sifre komut satirina yazilmaz: yalnizca alt islemin ortam degiskeni ISC_PASSWORD ile gider. }
unit uYedek;

interface

uses
  System.SysUtils, System.Classes, uBaglanti;

type
  { gbak her cikti satiri yazdiginda ve beklerken aralikla cagrilir (beklerken Satir bostur).
    Iptal True yapilirsa gbak durdurulur. }
  TYedekCiktisi = procedure(const Satir: string; var Iptal: Boolean) of object;

  TYedekSonucu = record
    Basarili: Boolean;
    Iptal: Boolean;
    { Basarisizsa anlasilir cumle (ham metin degil) }
    Cumle: string;
    { Komut satiri (sifresiz), gbak surumu, cikis kodu }
    Ayrinti: string;
    { gbak'in tum ciktisi (ham) }
    HamCikti: string;
    { Cikis kodu 0 iken ciktidaki WARNING satirlari, satir satir }
    Uyarilar: string;
    { Basarida olusan dosya (yedekte .fbk, geri yuklemede yeni veritabani yolu) }
    Dosya: string;
    { Iptal ya da hata sonrasi duran, KULLANILAMAZ dosya; bos = yok. Silinmez. }
    YarimDosya: string;
    Sure: Int64;
  end;

{ gbak.exe'nin yeri (varsayilan: istemci\gbak.exe) ve var olup olmadigi }
function GbakYolu: string;
function GbakVarMi: Boolean;
{ Kullanici baska bir gbak.exe sectiyse bu calisma boyunca onu kullanir; DISKE YAZILMAZ. }
procedure GbakYoluAyarla(const Yol: string);
{ "gbak -z" ciktisinin ilk satiri (ornek: "gbak version WI-V5.0.4.1812 Firebird 5.0"); bulunamazsa bos. }
function GbakSurumu: string;

{ gbak'a verilen baglanti: Sunucu doluysa "sunucu/port:yol", bossa yalnizca yol (gomulu). }
function GbakBaglantiMetni(const Tanim: TBaglantiTanimi; const Yol: string): string;

{ Dosya boyutu okunur bicimde: "12,3 MB" gibi. }
function BoyutMetni(Bayt: Int64): string;

{ "<veritabani dosya adi>_yyyymmdd_hhnnss.fbk" (dosya adinda olmaz denen karakterler '_' olur). }
function VarsayilanYedekAdi(const VeritabaniYolu: string): string;

{ Veritabanini Hedef (.fbk) dosyasina yedekler. Once Hedef + '.yarim' dosyasina yazar, BASARIYLA bitince
  Hedef'in yerine gecirir; hata ya da iptalde .yarim silinmez ve onceki gecerli yedek (varsa) bozulmaz.
  Hedef'in uzerine yazma onayini cagiran alir (uOnay.OnayIste). Onceki bir .yarim dosyasi varsa silinmez,
  tarihli bir adla yanina tasinir. Iptalde False doner. }
function YedekAl(const Tanim: TBaglantiTanimi; const Hedef: string; Cikti: TYedekCiktisi;
  out Sonuc: TYedekSonucu): Boolean;

{ Kaynak (.fbk) dosyasini HedefYol'daki YENI veritabanina geri yukler (gbak -c). Hedef zaten varsa gbak hata
  verir ve dosyaya dokunmaz. Hedef yol acik bir baglantiyla ayniysa gbak calistirilmaz. }
function GeriYukle(const Tanim: TBaglantiTanimi; const Kaynak, HedefYol: string; Cikti: TYedekCiktisi;
  out Sonuc: TYedekSonucu): Boolean;

{ gbak ciktisindaki sik hatalari anlasilir cumleye cevirir; tanimazsa genel cumle verir.
  Eslestirme gbak'in Ingilizce metnine bakar (isletim sistemi hata metinleri yerellesmis gelir). }
function GbakHatasiniCevir(const HamCikti: string): string;

{ Alt islem: Exe'yi gizli pencerede, kabuk kullanmadan calistirir; stdout+stderr borudan satir satir gelir.
  Sifre doluysa SADECE alt islemin ortamina ISC_PASSWORD olarak konur (kendi ortamimiz degismez).
  Iptalde False doner. Baslatilamazsa istisna firlatir. Testler de bunu kullanir. }
function AltIslemCalistir(const Exe, Argumanlar, Sifre: string; Cikti: TYedekCiktisi;
  out HamCikti: string; out CikisKodu: Cardinal): Boolean;

implementation

uses
  Winapi.Windows, System.IOUtils, System.StrUtils, System.Diagnostics, uDil, uPaket;

const
  YARIM_UZANTI = '.yarim';

var
  GGbakYolu: string;
  GGbakSurumu: string;
  GSurumOkundu: Boolean;

{ ---------- gbak yeri ve surumu ---------- }

function GbakYolu: string;
begin
  if GGbakYolu <> '' then
    Result := GGbakYolu
  else
    Result := TPath.Combine(PaketKlasoru, 'istemci\gbak.exe');
end;

function GbakVarMi: Boolean;
begin
  Result := TFile.Exists(GbakYolu);
end;

procedure GbakYoluAyarla(const Yol: string);
begin
  GGbakYolu := Yol;
  GSurumOkundu := False;
end;

function GbakSurumu: string;
var
  Ham: string;
  Kod: Cardinal;
  Satirlar: TStringList;
begin
  if not GSurumOkundu then
  begin
    GGbakSurumu := '';
    if GbakVarMi then
    begin
      Satirlar := TStringList.Create;
      try
        try
          AltIslemCalistir(GbakYolu, '-z', '', nil, Ham, Kod);
          Satirlar.Text := Ham;
          if Satirlar.Count > 0 then
            GGbakSurumu := Trim(Satirlar[0]);
        except
          GGbakSurumu := '';
        end;
      finally
        Satirlar.Free;
      end;
    end;
    GSurumOkundu := True;
  end;
  Result := GGbakSurumu;
end;

{ ---------- Komut hazirligi ---------- }

function GbakBaglantiMetni(const Tanim: TBaglantiTanimi; const Yol: string): string;
begin
  if Tanim.Sunucu = '' then
    Result := Yol
  else
    Result := Tanim.Sunucu + '/' + IntToStr(Tanim.Port) + ':' + Yol;
end;

{ Bosluk ve Turkce karakterli yollar icin. Windows yollarinda " olamaz. }
function Tirnakla(const Metin: string): string;
begin
  Result := '"' + Metin + '"';
end;

function KullaniciArgumani(const Tanim: TBaglantiTanimi): string;
begin
  if Tanim.Kullanici = '' then
    Result := ''
  else
    Result := ' -user ' + Tirnakla(Tanim.Kullanici);
end;

function BoyutMetni(Bayt: Int64): string;
begin
  if Bayt >= 1024 * 1024 * 1024 then
    Result := Format('%.1f GB', [Bayt / (1024 * 1024 * 1024)])
  else if Bayt >= 1024 * 1024 then
    Result := Format('%.1f MB', [Bayt / (1024 * 1024)])
  else
    Result := Format('%.1f KB', [Bayt / 1024]);
end;

function VarsayilanYedekAdi(const VeritabaniYolu: string): string;
var
  Ad: string;
  i: Integer;
begin
  Ad := StringReplace(VeritabaniYolu, '/', '\', [rfReplaceAll]);
  Ad := ChangeFileExt(ExtractFileName(Ad), '');
  if Ad = '' then
    Ad := 'yedek';
  for i := 1 to Length(Ad) do
    if CharInSet(Ad[i], ['\', '/', ':', '*', '?', '"', '<', '>', '|']) then
      Ad[i] := '_';
  Result := Ad + '_' + FormatDateTime('yyyymmdd_hhnnss', Now) + '.fbk';
end;

{ ---------- Alt islem ---------- }

{ Kendi ortamimizin kopyasi; ISC_PASSWORD (varsa) cikarilir, Sifre doluysa eklenir. Sonda cift #0 olur. }
function OrtamBloku(const Sifre: string): string;
var
  Ham, P: PChar;
  Giris: string;
  Tum: TStringBuilder;
begin
  Tum := TStringBuilder.Create;
  try
    Ham := GetEnvironmentStrings;
    try
      P := Ham;
      while P^ <> #0 do
      begin
        Giris := P;
        Inc(P, Length(Giris) + 1);
        if not StartsText('ISC_PASSWORD=', Giris) then
        begin
          Tum.Append(Giris);
          Tum.Append(#0);
        end;
      end;
    finally
      FreeEnvironmentStrings(Ham);
    end;
    if Sifre <> '' then
    begin
      Tum.Append('ISC_PASSWORD=' + Sifre);
      Tum.Append(#0);
    end;
    Tum.Append(#0);
    Result := Tum.ToString;
  finally
    Tum.Free;
  end;
end;

function CiktiKodlamasi: TEncoding;
begin
  Result := TEncoding.GetEncoding(GetACP);
end;

function AltIslemCalistir(const Exe, Argumanlar, Sifre: string; Cikti: TYedekCiktisi;
  out HamCikti: string; out CikisKodu: Cardinal): Boolean;
var
  Guvenlik: TSecurityAttributes;
  OkuUcu, YazUcu, GirisNul: THandle;
  Baslangic: TStartupInfo;
  Bilgi: TProcessInformation;
  KomutSatiri, Ortam: string;
  Kodlama: TEncoding;
  Biriken: TBytes;
  BirikenUzunluk: Integer;
  Tampon: array[0..4095] of Byte;
  Mevcut, Okunan: DWORD;
  Tum: TStringBuilder;
  Iptal: Boolean;

  { Bir satiri ciktiya ekler ve geri cagriyi cagirir }
  procedure SatiriVer(const Satir: string);
  begin
    Tum.AppendLine(Satir);
    if Assigned(Cikti) then
      Cikti(Satir, Iptal);
  end;

  { Birikende tam satir (LF ile biten) varsa ayirip verir }
  procedure SatirlariAyir(Son: Boolean);
  var
    i, Baslangici, Uzunluk: Integer;
  begin
    Baslangici := 0;
    for i := 0 to BirikenUzunluk - 1 do
      if Biriken[i] = 10 then
      begin
        Uzunluk := i - Baslangici;
        if (Uzunluk > 0) and (Biriken[i - 1] = 13) then
          Dec(Uzunluk);
        SatiriVer(Kodlama.GetString(Biriken, Baslangici, Uzunluk));
        Baslangici := i + 1;
      end;
    if Son and (Baslangici < BirikenUzunluk) then
    begin
      SatiriVer(Kodlama.GetString(Biriken, Baslangici, BirikenUzunluk - Baslangici));
      Baslangici := BirikenUzunluk;
    end;
    if Baslangici > 0 then
    begin
      Move(Biriken[Baslangici], Biriken[0], BirikenUzunluk - Baslangici);
      Dec(BirikenUzunluk, Baslangici);
    end;
  end;

  function PipedeVeriVar: Boolean;
  begin
    if not PeekNamedPipe(OkuUcu, nil, 0, nil, @Mevcut, nil) then
      Mevcut := 0;
    Result := Mevcut > 0;
  end;

begin
  Iptal := False;
  HamCikti := '';
  CikisKodu := 0;
  Guvenlik.nLength := SizeOf(Guvenlik);
  Guvenlik.lpSecurityDescriptor := nil;
  Guvenlik.bInheritHandle := True;
  if not CreatePipe(OkuUcu, YazUcu, @Guvenlik, 0) then
    raise Exception.Create(TF('ERR_YEDEK_BASLATILAMADI', [SysErrorMessage(GetLastError)]));
  { Okuma ucu alt islemde miras kalmasin }
  SetHandleInformation(OkuUcu, HANDLE_FLAG_INHERIT, 0);
  GirisNul := CreateFile('NUL', GENERIC_READ, FILE_SHARE_READ or FILE_SHARE_WRITE, @Guvenlik,
    OPEN_EXISTING, 0, 0);
  Kodlama := CiktiKodlamasi;
  Tum := TStringBuilder.Create;
  try
    ZeroMemory(@Baslangic, SizeOf(Baslangic));
    Baslangic.cb := SizeOf(Baslangic);
    Baslangic.dwFlags := STARTF_USESTDHANDLES or STARTF_USESHOWWINDOW;
    Baslangic.wShowWindow := SW_HIDE;
    Baslangic.hStdInput := GirisNul;
    Baslangic.hStdOutput := YazUcu;
    Baslangic.hStdError := YazUcu;
    KomutSatiri := Tirnakla(Exe) + ' ' + Argumanlar;
    UniqueString(KomutSatiri);
    Ortam := OrtamBloku(Sifre);
    if not CreateProcess(PChar(Exe), PChar(KomutSatiri), nil, nil, True,
      CREATE_NO_WINDOW or CREATE_UNICODE_ENVIRONMENT, PChar(Ortam), nil, Baslangic, Bilgi) then
    begin
      Okunan := GetLastError;
      CloseHandle(YazUcu);
      CloseHandle(OkuUcu);
      if GirisNul <> INVALID_HANDLE_VALUE then
        CloseHandle(GirisNul);
      raise Exception.Create(TF('ERR_YEDEK_BASLATILAMADI', [SysErrorMessage(Okunan)]));
    end;
    { Bizim yazma ucumuz kapanmali, yoksa boru hic bitmez }
    CloseHandle(YazUcu);
    if GirisNul <> INVALID_HANDLE_VALUE then
      CloseHandle(GirisNul);
    SetLength(Biriken, 1024);
    BirikenUzunluk := 0;
    try
      while not Iptal do
      begin
        if PipedeVeriVar then
        begin
          if ReadFile(OkuUcu, Tampon, SizeOf(Tampon), Okunan, nil) and (Okunan > 0) then
          begin
            if BirikenUzunluk + Integer(Okunan) > Length(Biriken) then
              SetLength(Biriken, (BirikenUzunluk + Integer(Okunan)) * 2);
            Move(Tampon[0], Biriken[BirikenUzunluk], Okunan);
            Inc(BirikenUzunluk, Okunan);
            SatirlariAyir(False);
          end;
        end
        else if WaitForSingleObject(Bilgi.hProcess, 0) = WAIT_OBJECT_0 then
        begin
          { Islem bitti; borudaki son veri de okunduysa cik }
          if not PipedeVeriVar then
            Break;
        end
        else
        begin
          Sleep(20);
          if Assigned(Cikti) then
            Cikti('', Iptal);
        end;
      end;
      if Iptal then
      begin
        TerminateProcess(Bilgi.hProcess, 1);
        WaitForSingleObject(Bilgi.hProcess, 5000);
      end
      else
        SatirlariAyir(True);
      GetExitCodeProcess(Bilgi.hProcess, CikisKodu);
    finally
      CloseHandle(Bilgi.hThread);
      CloseHandle(Bilgi.hProcess);
      CloseHandle(OkuUcu);
    end;
    HamCikti := Tum.ToString;
    Result := not Iptal;
  finally
    Tum.Free;
  end;
end;

{ ---------- Hata cumleleri ---------- }

function Iceriyor(const Metin, Parca: string): Boolean;
begin
  Result := ContainsText(Metin, Parca);
end;

function GbakHatasiniCevir(const HamCikti: string): string;
begin
  if Iceriyor(HamCikti, 'already exists') then
    Result := T('ERR_YEDEK_HEDEF_VAR')
  else if Iceriyor(HamCikti, 'user name and password') or Iceriyor(HamCikti, 'authentication error') or
    Iceriyor(HamCikti, 'error occurred during login') or Iceriyor(HamCikti, 'incorrect user name') then
    Result := T('ERR_SIFRE')
  else if Iceriyor(HamCikti, 'system privilege') or Iceriyor(HamCikti, 'use_gbak_utility') or
    Iceriyor(HamCikti, 'no permission for') then
    Result := T('ERR_YEDEK_YETKI')
  else if Iceriyor(HamCikti, 'network request') or Iceriyor(HamCikti, 'connection refused') or
    Iceriyor(HamCikti, 'failed to establish a connection') or Iceriyor(HamCikti, 'unavailable database') then
    Result := T('ERR_SUNUCU')
  else if Iceriyor(HamCikti, 'connection lost') or Iceriyor(HamCikti, 'error reading data from the connection') or
    Iceriyor(HamCikti, 'error writing data to the connection') then
    Result := T('ERR_KOPTU')
  else if Iceriyor(HamCikti, 'expected backup version') or Iceriyor(HamCikti, 'unsupported on-disk structure') or
    Iceriyor(HamCikti, 'ods version') then
    Result := T('ERR_YEDEK_SURUM')
  else if Iceriyor(HamCikti, 'expected backup') or Iceriyor(HamCikti, 'unexpected end of file on backup') or
    Iceriyor(HamCikti, 'invalid backup') or Iceriyor(HamCikti, 'bad backup') then
    Result := T('ERR_YEDEK_BOZUK')
  else if Iceriyor(HamCikti, 'cannot open backup file') or Iceriyor(HamCikti, 'cannot write backup') or
    Iceriyor(HamCikti, 'error writing to backup') then
    Result := T('ERR_YEDEK_DOSYA')
  else if Iceriyor(HamCikti, 'i/o error during') then
  begin
    if Iceriyor(HamCikti, '(create)') then
      Result := T('ERR_YEDEK_HEDEF_YAZILAMADI')
    else if Iceriyor(HamCikti, '(open)') then
      Result := T('ERR_YEDEK_KAYNAK_YOK')
    else
      Result := T('ERR_YEDEK_DISK');
  end
  else
    Result := T('ERR_YEDEK_GENEL');
end;

{ ---------- Yedek ve geri yukleme ---------- }

function SatirlarIcindenUyarilar(const HamCikti: string): string;
var
  Satirlar: TStringList;
  Satir: string;
begin
  Result := '';
  Satirlar := TStringList.Create;
  try
    Satirlar.Text := HamCikti;
    for Satir in Satirlar do
      if ContainsText(Satir, 'warning') then
      begin
        if Result <> '' then
          Result := Result + sLineBreak;
        Result := Result + Trim(Satir);
      end;
  finally
    Satirlar.Free;
  end;
end;

function AyrintiHazirla(const Arguman: string; CikisKodu: Cardinal): string;
begin
  Result := TF('YEDEK_AYRINTI_KOMUT', [Tirnakla('gbak') + ' ' + Arguman]) + sLineBreak +
    TF('YEDEK_AYRINTI_GBAK', [GbakSurumu]) + sLineBreak +
    TF('YEDEK_AYRINTI_CIKIS', [Integer(CikisKodu)]);
end;

{ Ayni gbak cagrisi, yedek ve geri yukleme icin ortak. Cikis kodu ve ham cikti Sonuc'a yazilir. }
function GbakCalistir(const Tanim: TBaglantiTanimi; const Arguman: string; Cikti: TYedekCiktisi;
  var Sonuc: TYedekSonucu): Boolean;
var
  Ham: string;
  Kod: Cardinal;
begin
  Result := AltIslemCalistir(GbakYolu, Arguman, Tanim.Sifre, Cikti, Ham, Kod);
  Sonuc.HamCikti := Ham;
  Sonuc.Iptal := not Result;
  Sonuc.Ayrinti := AyrintiHazirla(Arguman, Kod);
  Result := Result and (Kod = 0);
end;

{ Onceki bir yarim dosya silinmez, tarihli bir adla yanina tasinir. }
procedure OncekiYarimiYanaTasi(const Gecici: string);
begin
  if TFile.Exists(Gecici) then
    TFile.Move(Gecici, Gecici + '-' + FormatDateTime('yyyymmdd-hhnnss', Now));
end;

function YedekAl(const Tanim: TBaglantiTanimi; const Hedef: string; Cikti: TYedekCiktisi;
  out Sonuc: TYedekSonucu): Boolean;
var
  Gecici, Arguman: string;
  Saat: TStopwatch;
begin
  Sonuc := Default(TYedekSonucu);
  Gecici := Hedef + YARIM_UZANTI;
  OncekiYarimiYanaTasi(Gecici);
  Arguman := '-b -v' + KullaniciArgumani(Tanim) + ' ' + Tirnakla(GbakBaglantiMetni(Tanim, Tanim.VeritabaniYolu)) +
    ' ' + Tirnakla(Gecici);
  Saat := TStopwatch.StartNew;
  Result := GbakCalistir(Tanim, Arguman, Cikti, Sonuc);
  Sonuc.Sure := Saat.ElapsedMilliseconds;
  if Result then
  begin
    { Basarili: yarim dosya hedefin yerine gecer (eski yedek ancak simdi gider) }
    if MoveFileEx(PChar(Gecici), PChar(Hedef), MOVEFILE_REPLACE_EXISTING or MOVEFILE_WRITE_THROUGH) then
    begin
      Sonuc.Basarili := True;
      Sonuc.Dosya := Hedef;
      Sonuc.Uyarilar := SatirlarIcindenUyarilar(Sonuc.HamCikti);
    end
    else
    begin
      Result := False;
      Sonuc.Cumle := TF('ERR_YEDEK_YERINE_KONAMADI', [SysErrorMessage(GetLastError)]);
      Sonuc.YarimDosya := Gecici;
    end;
    Exit;
  end;
  if TFile.Exists(Gecici) then
    Sonuc.YarimDosya := Gecici;
  if not Sonuc.Iptal then
    Sonuc.Cumle := GbakHatasiniCevir(Sonuc.HamCikti);
end;

function GeriYukle(const Tanim: TBaglantiTanimi; const Kaynak, HedefYol: string; Cikti: TYedekCiktisi;
  out Sonuc: TYedekSonucu): Boolean;
var
  Arguman, AcikAd: string;
  Onceden: Boolean;
  Saat: TStopwatch;
begin
  Sonuc := Default(TYedekSonucu);
  AcikAd := FbYoluAcikBaglantidaMi(Tanim.Sunucu, HedefYol);
  if AcikAd <> '' then
  begin
    Sonuc.Cumle := TF('ERR_YEDEK_HEDEF_ACIK', [AcikAd]);
    Exit(False);
  end;
  { Yerel (gomulu) kullanimda hedef dosya zaten varsa gbak hic calistirilmaz: gbak -c var olan dosyaya bile
    baglanip baslik sayfasini degistirir (olculdu, ASAMA3C_RAPOR.md); biz o dosyaya hic dokunmayiz. }
  if (Tanim.Sunucu = '') and TFile.Exists(HedefYol) then
  begin
    Sonuc.Cumle := T('ERR_YEDEK_HEDEF_VAR');
    Exit(False);
  end;
  { Gomulu kipte hedef yerel dosyadir: onceden var miydi, hata sonrasi yarim dosya kaldi mi anlasilsin. }
  Onceden := (Tanim.Sunucu <> '') or TFile.Exists(HedefYol);
  Arguman := '-c -v' + KullaniciArgumani(Tanim) + ' ' + Tirnakla(Kaynak) + ' ' +
    Tirnakla(GbakBaglantiMetni(Tanim, HedefYol));
  Saat := TStopwatch.StartNew;
  Result := GbakCalistir(Tanim, Arguman, Cikti, Sonuc);
  Sonuc.Sure := Saat.ElapsedMilliseconds;
  if Result then
  begin
    Sonuc.Basarili := True;
    Sonuc.Dosya := HedefYol;
    Sonuc.Uyarilar := SatirlarIcindenUyarilar(Sonuc.HamCikti);
    Exit;
  end;
  if Sonuc.Iptal then
    { Sunucuda olusmus olabilir, yeri bilinmez; yol yine de bildirilir. }
    Sonuc.YarimDosya := HedefYol
  else
  begin
    Sonuc.Cumle := GbakHatasiniCevir(Sonuc.HamCikti);
    if (not Onceden) and TFile.Exists(HedefYol) then
      Sonuc.YarimDosya := HedefYol;
  end;
end;

end.
