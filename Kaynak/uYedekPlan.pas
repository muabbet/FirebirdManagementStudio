{ uYedekPlan.pas - Zamanlanmis otomatik yedek (7x).

  Hedeflenen Firebird surumleri: 2.5, 3.0, 4.0, 5.0
  Denenen Firebird surumleri: 3.0.14, 4.0.7 (testler)

  Her kayitli baglanti icin en cok bir plan vardir: klasor, saat (her gun), kac yedek tutulacagi.
  Plan yedekplanlari.json dosyasinda durur. Zamanlama Windows Gorev Zamanlayici'ya birakilir (kendi arka plan
  servisimiz yok): gorev, programin kendisini "FirebirdManagementStudio.exe /yedek "Baglanti adi"" diye
  gorunmeden calistirir; bu kip yedegi alir, sonucu yedekgunlugu.txt dosyasina yazar ve kapanir.
  Sifre hicbir yere yazilmaz: gorev kayitli baglantiyi (DPAPI) kendisi cozer; bu yuzden baglantinin sifresi
  kayitli olmali ve gorev ayni Windows kullanicisi oturum aciksken calisir.

  Hicbir yedek silinmez: tutulacak sayidan eski yedekler klasorun altindaki "Eski" klasorune tasinir. }
unit uYedekPlan;

interface

uses
  System.SysUtils, System.Classes, uBaglanti, uYedek;

type
  TYedekPlani = record
    BaglantiAd: string;
    Klasor: string;
    { "HH:MM" }
    Saat: string;
    Sakla: Integer;
  end;

const
  YEDEK_SAKLA_VARSAYILAN = 7;

{ Plan dosyasi (yedekplanlari.json) }
function YedekPlaniOku(const BaglantiAd: string; out Plan: TYedekPlani): Boolean;
procedure YedekPlaniKaydet(const Plan: TYedekPlani);
procedure YedekPlaniSil(const BaglantiAd: string);

{ Yeni plan icin onerilen klasor: Belgelerim\FirebirdYedek\<baglanti adi> }
function VarsayilanYedekKlasoru(const BaglantiAd: string): string;

{ Plani denetler; sorun varsa anlasilir cumle, yoksa bos. }
function YedekPlaniDenetle(const Plan: TYedekPlani): string;

{ Windows Gorev Zamanlayici'daki gorev: adi, kuruldu mu, kur (var olanin yerine gecer), kaldir.
  Basarisizsa Cumle dolu doner, Ham schtasks ciktisidir. }
function YedekGorevAdi(const BaglantiAd: string): string;
function YedekGorevVarMi(const BaglantiAd: string): Boolean;
function YedekGoreviKur(const Plan: TYedekPlani; out Cumle, Ham: string): Boolean;
function YedekGoreviKaldir(const BaglantiAd: string; out Cumle, Ham: string): Boolean;

{ Gorevin XML'i (denemeler icin ayri yazildi): her gun Saat'te, kacirilirsa bilgisayar acilinca calisir. }
function YedekGorevXml(const Plan: TYedekPlani): string;

{ Plani simdi calistirir (gorev de bunu kullanir): yedegi alir, eski yedekleri "Eski" klasorune tasir,
  sonucu gunluge yazar. Basariliysa True. }
function YedekPlaniCalistir(const BaglantiAd: string; Cikti: TYedekCiktisi; out Sonuc: TYedekSonucu): Boolean;

{ Klasordeki bu veritabaninin yedeklerinden en yeni Sakla tanesi kalir, fazlasi Klasor\Eski'ye tasinir
  (silinmez). Tasinan dosya sayisini verir. }
function EskiYedekleriTasi(const Klasor, VeritabaniYolu: string; Sakla: Integer): Integer;

{ Gunluk: son Say satir (eskiden yeniye) }
function YedekGunlugu(const BaglantiAd: string; Say: Integer): TArray<string>;

{ Program "/yedek" ile acildiysa True (dpr, arayuzu hic acmadan bu kipe girer). }
function YedekGoreviMi: Boolean;
{ Gorev kipini calistirir; cikis kodu: 0 basarili, 1 yedek alinamadi. }
function YedekGoreviCalistir: Integer;

implementation

uses
  Winapi.Windows, System.IOUtils, System.JSON, System.StrUtils, System.Generics.Collections,
  System.Generics.Defaults, uDil;

const
  GOREV_ONEKI = 'FirebirdManagementStudio Yedek - ';

function PlanDosyasi: string;
begin
  Result := TPath.Combine(UygulamaVeriKlasoru, 'yedekplanlari.json');
end;

function GunlukDosyasi: string;
begin
  Result := TPath.Combine(UygulamaVeriKlasoru, 'yedekgunlugu.txt');
end;

{ ---------- Plan dosyasi ---------- }

function PlanlariOku: TJSONObject;
var
  Kok: TJSONValue;
begin
  Result := nil;
  if TFile.Exists(PlanDosyasi) then
  begin
    Kok := TJSONObject.ParseJSONValue(TFile.ReadAllText(PlanDosyasi, TEncoding.UTF8));
    if Kok is TJSONObject then
      Result := TJSONObject(Kok)
    else
      Kok.Free;
  end;
  if Result = nil then
    Result := TJSONObject.Create;
end;

procedure PlanlariYaz(Kok: TJSONObject);
begin
  TFile.WriteAllText(PlanDosyasi, Kok.Format(2), TEncoding.UTF8);
end;

function YedekPlaniOku(const BaglantiAd: string; out Plan: TYedekPlani): Boolean;
var
  Kok: TJSONObject;
  Oge: TJSONValue;
begin
  Plan := Default(TYedekPlani);
  Kok := PlanlariOku;
  try
    Oge := Kok.GetValue(BaglantiAd);
    Result := Oge is TJSONObject;
    if Result then
    begin
      Plan.BaglantiAd := BaglantiAd;
      Oge.TryGetValue<string>('Klasor', Plan.Klasor);
      Oge.TryGetValue<string>('Saat', Plan.Saat);
      if not Oge.TryGetValue<Integer>('Sakla', Plan.Sakla) then
        Plan.Sakla := YEDEK_SAKLA_VARSAYILAN;
    end;
  finally
    Kok.Free;
  end;
end;

procedure YedekPlaniKaydet(const Plan: TYedekPlani);
var
  Kok, Oge: TJSONObject;
begin
  Kok := PlanlariOku;
  try
    Kok.RemovePair(Plan.BaglantiAd).Free;
    Oge := TJSONObject.Create;
    Oge.AddPair('Klasor', Plan.Klasor);
    Oge.AddPair('Saat', Plan.Saat);
    Oge.AddPair('Sakla', TJSONNumber.Create(Plan.Sakla));
    Kok.AddPair(Plan.BaglantiAd, Oge);
    PlanlariYaz(Kok);
  finally
    Kok.Free;
  end;
end;

procedure YedekPlaniSil(const BaglantiAd: string);
var
  Kok: TJSONObject;
  Eski: TJSONPair;
begin
  Kok := PlanlariOku;
  try
    Eski := Kok.RemovePair(BaglantiAd);
    if Eski <> nil then
    begin
      Eski.Free;
      PlanlariYaz(Kok);
    end;
  finally
    Kok.Free;
  end;
end;

function VarsayilanYedekKlasoru(const BaglantiAd: string): string;
var
  Ad: string;
  i: Integer;
begin
  Ad := BaglantiAd;
  for i := 1 to Length(Ad) do
    if CharInSet(Ad[i], ['\', '/', ':', '*', '?', '"', '<', '>', '|']) then
      Ad[i] := '_';
  Result := TPath.Combine(TPath.Combine(TPath.GetDocumentsPath, 'FirebirdYedek'), Ad);
end;

function SaatGecerliMi(const Saat: string): Boolean;
var
  S, D: Integer;
begin
  Result := (Length(Saat) = 5) and (Saat[3] = ':') and TryStrToInt(Copy(Saat, 1, 2), S) and
    TryStrToInt(Copy(Saat, 4, 2), D) and (S >= 0) and (S <= 23) and (D >= 0) and (D <= 59);
end;

function YedekPlaniDenetle(const Plan: TYedekPlani): string;
begin
  Result := '';
  if Pos('"', Plan.BaglantiAd) > 0 then
    Result := T('ERR_YEDEKPLAN_AD')
  else if Trim(Plan.Klasor) = '' then
    Result := T('ERR_YEDEKPLAN_KLASOR_BOS')
  else if not SaatGecerliMi(Plan.Saat) then
    Result := T('ERR_YEDEKPLAN_SAAT')
  else if Plan.Sakla < 1 then
    Result := T('ERR_YEDEKPLAN_SAKLA');
end;

{ ---------- Windows Gorev Zamanlayici ---------- }

function YedekGorevAdi(const BaglantiAd: string): string;
begin
  Result := GOREV_ONEKI + BaglantiAd;
end;

function SchtasksYolu: string;
begin
  Result := TPath.Combine(GetEnvironmentVariable('SystemRoot'), 'System32\schtasks.exe');
end;

function SchtasksCalistir(const Arguman: string; out Ham: string): Boolean;
var
  Kod: Cardinal;
begin
  Result := AltIslemCalistir(SchtasksYolu, Arguman, '', nil, Ham, Kod) and (Kod = 0);
end;

function XmlKacis(const Metin: string): string;
begin
  Result := StringReplace(Metin, '&', '&amp;', [rfReplaceAll]);
  Result := StringReplace(Result, '<', '&lt;', [rfReplaceAll]);
  Result := StringReplace(Result, '>', '&gt;', [rfReplaceAll]);
  Result := StringReplace(Result, '"', '&quot;', [rfReplaceAll]);
end;

function YedekGorevXml(const Plan: TYedekPlani): string;
begin
  Result :=
    '<?xml version="1.0" encoding="UTF-16"?>' + sLineBreak +
    '<Task version="1.2" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task">' + sLineBreak +
    '  <Triggers>' + sLineBreak +
    '    <CalendarTrigger>' + sLineBreak +
    '      <StartBoundary>' + FormatDateTime('yyyy-mm-dd', Date) + 'T' + Plan.Saat + ':00</StartBoundary>' + sLineBreak +
    '      <Enabled>true</Enabled>' + sLineBreak +
    '      <ScheduleByDay><DaysInterval>1</DaysInterval></ScheduleByDay>' + sLineBreak +
    '    </CalendarTrigger>' + sLineBreak +
    '  </Triggers>' + sLineBreak +
    '  <Principals>' + sLineBreak +
    '    <Principal id="Author"><LogonType>InteractiveToken</LogonType></Principal>' + sLineBreak +
    '  </Principals>' + sLineBreak +
    '  <Settings>' + sLineBreak +
    '    <MultipleInstancesPolicy>IgnoreNew</MultipleInstancesPolicy>' + sLineBreak +
    '    <DisallowStartIfOnBatteries>false</DisallowStartIfOnBatteries>' + sLineBreak +
    '    <StopIfGoingOnBatteries>false</StopIfGoingOnBatteries>' + sLineBreak +
    '    <StartWhenAvailable>true</StartWhenAvailable>' + sLineBreak +
    '    <ExecutionTimeLimit>PT12H</ExecutionTimeLimit>' + sLineBreak +
    '  </Settings>' + sLineBreak +
    '  <Actions Context="Author">' + sLineBreak +
    '    <Exec>' + sLineBreak +
    '      <Command>' + XmlKacis(ParamStr(0)) + '</Command>' + sLineBreak +
    '      <Arguments>/yedek &quot;' + XmlKacis(Plan.BaglantiAd) + '&quot;</Arguments>' + sLineBreak +
    '    </Exec>' + sLineBreak +
    '  </Actions>' + sLineBreak +
    '</Task>' + sLineBreak;
end;

function YedekGorevVarMi(const BaglantiAd: string): Boolean;
var
  Ham: string;
begin
  Result := SchtasksCalistir('/Query /TN "' + YedekGorevAdi(BaglantiAd) + '"', Ham);
end;

function YedekGoreviKur(const Plan: TYedekPlani; out Cumle, Ham: string): Boolean;
var
  XmlDosyasi: string;
begin
  Cumle := YedekPlaniDenetle(Plan);
  Ham := '';
  if Cumle <> '' then
    Exit(False);
  { XML veri klasorune yazilir ve orada kalir (silinmez, kucuk ve zararsiz) }
  XmlDosyasi := TPath.Combine(UygulamaVeriKlasoru, 'yedekgorevi.xml');
  TFile.WriteAllText(XmlDosyasi, YedekGorevXml(Plan), TEncoding.Unicode);
  Result := SchtasksCalistir('/Create /F /TN "' + YedekGorevAdi(Plan.BaglantiAd) + '" /XML "' + XmlDosyasi + '"', Ham);
  if not Result then
    Cumle := TF('ERR_YEDEKPLAN_GOREV', [Trim(Ham)]);
end;

function YedekGoreviKaldir(const BaglantiAd: string; out Cumle, Ham: string): Boolean;
begin
  Cumle := '';
  Result := SchtasksCalistir('/Delete /F /TN "' + YedekGorevAdi(BaglantiAd) + '"', Ham);
  if not Result then
    Cumle := TF('ERR_YEDEKPLAN_GOREV', [Trim(Ham)]);
end;

{ ---------- Eski yedekler ve gunluk ---------- }

function EskiYedekleriTasi(const Klasor, VeritabaniYolu: string; Sakla: Integer): Integer;
var
  Ornek, Onek, EskiKlasor, Hedef: string;
  Dosyalar: TArray<string>;
  i: Integer;
begin
  Result := 0;
  if not TDirectory.Exists(Klasor) then
    Exit;
  { Adlar VarsayilanYedekAdi bicimindedir: <ad>_yyyymmdd_hhnnss.fbk; yalniz bu bicimdekilere dokunulur }
  Ornek := VarsayilanYedekAdi(VeritabaniYolu);
  Onek := Copy(Ornek, 1, Length(Ornek) - Length('_yyyymmdd_hhnnss.fbk'));
  Dosyalar := TDirectory.GetFiles(Klasor, Onek + '_????????_??????.fbk');
  TArray.Sort<string>(Dosyalar);
  EskiKlasor := TPath.Combine(Klasor, 'Eski');
  for i := 0 to Length(Dosyalar) - Sakla - 1 do
  begin
    ForceDirectories(EskiKlasor);
    Hedef := TPath.Combine(EskiKlasor, ExtractFileName(Dosyalar[i]));
    if TFile.Exists(Hedef) then
      Hedef := Hedef + '-' + FormatDateTime('yyyymmdd-hhnnss', Now);
    TFile.Move(Dosyalar[i], Hedef);
    Inc(Result);
  end;
end;

procedure GunluguYaz(const BaglantiAd: string; Basarili: Boolean; const Metin: string);
var
  Durum, Satir: string;
begin
  if Basarili then
    Durum := 'OK'
  else
    Durum := 'HATA';
  Satir := FormatDateTime('yyyy-mm-dd hh:nn:ss', Now) + ' | ' + BaglantiAd + ' | ' + Durum + ' | ' +
    StringReplace(StringReplace(Metin, #13, ' ', [rfReplaceAll]), #10, ' ', [rfReplaceAll]);
  try
    TFile.AppendAllText(GunlukDosyasi, Satir + sLineBreak, TEncoding.UTF8);
  except
    { gunluk yazilamazsa yedegin kendisi bozulmasin }
  end;
end;

function YedekGunlugu(const BaglantiAd: string; Say: Integer): TArray<string>;
var
  Liste: TList<string>;
  Satir: string;
  Baslangic: Integer;
begin
  Liste := TList<string>.Create;
  try
    if TFile.Exists(GunlukDosyasi) then
      for Satir in TFile.ReadAllLines(GunlukDosyasi, TEncoding.UTF8) do
        if Pos(' | ' + BaglantiAd + ' | ', Satir) > 0 then
          Liste.Add(Satir);
    Baslangic := Liste.Count - Say;
    if Baslangic < 0 then
      Baslangic := 0;
    Result := Copy(Liste.ToArray, Baslangic, Liste.Count - Baslangic);
  finally
    Liste.Free;
  end;
end;

{ ---------- Calistirma ---------- }

function YedekPlaniCalistir(const BaglantiAd: string; Cikti: TYedekCiktisi; out Sonuc: TYedekSonucu): Boolean;
var
  Plan: TYedekPlani;
  Tanim: TBaglantiTanimi;
  Hedef, Metin: string;
  Tasinan: Integer;
begin
  Sonuc := Default(TYedekSonucu);
  Result := False;
  try
    if not YedekPlaniOku(BaglantiAd, Plan) then
      Sonuc.Cumle := TF('ERR_YEDEKPLAN_YOK', [BaglantiAd])
    else if not KayitliBaglantiBul(BaglantiAd, Tanim) then
      Sonuc.Cumle := TF('ERR_KAYIT_YOK', [BaglantiAd])
    else if Tanim.Sifre = '' then
      Sonuc.Cumle := T('ERR_YEDEKPLAN_SIFRE')
    else if not GbakVarMi then
      Sonuc.Cumle := T('ERR_YEDEK_GBAK_YOK')
    else
    begin
      ForceDirectories(Plan.Klasor);
      Hedef := TPath.Combine(Plan.Klasor, VarsayilanYedekAdi(Tanim.VeritabaniYolu));
      Result := YedekAl(Tanim, Hedef, Cikti, Sonuc);
      if Result then
      begin
        Tasinan := EskiYedekleriTasi(Plan.Klasor, Tanim.VeritabaniYolu, Plan.Sakla);
        Metin := TF('YEDEKPLAN_GUNLUK_TAMAM', [Sonuc.Dosya, BoyutMetni(TFile.GetSize(Sonuc.Dosya)),
          Format('%.1f', [Sonuc.Sure / 1000]), Tasinan]);
        GunluguYaz(BaglantiAd, True, Metin);
        Exit;
      end;
    end;
  except
    on E: Exception do
    begin
      Result := False;
      Sonuc.Cumle := E.Message;
    end;
  end;
  if Sonuc.Iptal then
    Sonuc.Cumle := T('YEDEK_IPTAL');
  GunluguYaz(BaglantiAd, False, T('ERR_YEDEK_YAPILAMADI') + ' ' + Sonuc.Cumle);
end;

function YedekGoreviMi: Boolean;
begin
  Result := (ParamCount >= 2) and SameText(ParamStr(1), '/yedek');
end;

function YedekGoreviCalistir: Integer;
var
  Sonuc: TYedekSonucu;
begin
  DilYukle(SonKullanilanDil);
  if YedekPlaniCalistir(ParamStr(2), nil, Sonuc) then
    Result := 0
  else
    Result := 1;
end;

end.
