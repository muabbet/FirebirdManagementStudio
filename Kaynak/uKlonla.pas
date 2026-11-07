{ uKlonla.pas - Veritabanini kopyalama (sag tik "Veritabanini kopyala", Asama 7h).
  Is: veritabani gbak ile gecici bir .fbk dosyasina yedeklenir, sonra YENI bir veritabani dosyasina geri yuklenir.
  Var olan dosya ezilmez (geri yukleme zaten bunu reddeder). Gecici .fbk dosyasi SILINMEZ; yeri sonucta soylenir.
  Yedekleme ve geri yukleme uYedek'tedir; bu unit yalniz onlari siraya dizer. }
unit uKlonla;

interface

uses
  System.SysUtils, System.Classes, uBaglanti, uYedek;

type
  TKlonSonucu = record
    Basarili: Boolean;
    Iptal: Boolean;
    { Basarisizsa anlasilir cumle }
    Cumle: string;
    Ayrinti: string;
    { Gecici yedek dosyasi (yerel) ve olusan yeni veritabani yolu }
    YedekDosya: string;
    YeniYol: string;
  end;

{ "C:\x\FABRIKA.FDB" -> "C:\x\FABRIKA_KOPYA_20261107_131500.FDB" (ayni klasor, ayni uzanti). Yol sunucudaki yoldur. }
function KlonYoluOner(const Yol: string): string;

{ Gecici yedek dosyasinin yolu. Sunucu kipinde SUNUCUDAKI yoldur (yeni veritabaninin yaninda, <yeni>.fbk; her sey sunucuda olur,
  eski sunuculara da uyar); gomulu kipte yerel %TEMP%\FirebirdYonetici\klon\<ad>_yyyymmdd_hhnnss.fbk. }
function KlonYedekYolu(const Tanim: TBaglantiTanimi; const YeniYol: string): string;

{ Onay penceresinin metni: neyin nereye kopyalanacagi. }
function KlonOnayMetni(const Tanim: TBaglantiTanimi; const YeniYol, YedekYolu: string): string;

{ Yedekle + geri yukle. Cikti: gbak satirlari ve beklerken aralikla cagrilir; Iptal True yapilirsa durur. }
function VeritabaniKlonla(const Tanim: TBaglantiTanimi; const YeniYol: string; Cikti: TYedekCiktisi): TKlonSonucu;

{ Yeni veritabanini kayitli baglanti olarak ekler (ayni sunucu, kullanici, sifre ayari); eklenen baglanti adini verir. }
function KlonBaglantisiniEkle(const Tanim: TBaglantiTanimi; const YeniYol: string): string;

implementation

uses
  System.IOUtils, uDil;

function KlonYoluOner(const Yol: string): string;
var
  Klasor, Ad, Uzanti, Ayirici: string;
  i: Integer;
begin
  { Yol Windows ya da Linux sunucusunda olabilir: son ayiriciya kendimiz bakariz }
  i := Length(Yol);
  while (i > 0) and (Yol[i] <> '\') and (Yol[i] <> '/') do
    Dec(i);
  Klasor := Copy(Yol, 1, i);
  Ad := Copy(Yol, i + 1, MaxInt);
  Uzanti := ExtractFileExt(Ad);
  Ad := Copy(Ad, 1, Length(Ad) - Length(Uzanti));
  Ayirici := '_KOPYA_' + FormatDateTime('yyyymmdd_hhnnss', Now);
  Result := Klasor + Ad + Ayirici + Uzanti;
end;

function KlonYedekYolu(const Tanim: TBaglantiTanimi; const YeniYol: string): string;
var
  Ad: string;
  i: Integer;
begin
  if Tanim.Sunucu <> '' then
    Exit(YeniYol + '.fbk');
  Ad := Tanim.VeritabaniYolu;
  i := Length(Ad);
  while (i > 0) and (Ad[i] <> '\') and (Ad[i] <> '/') and (Ad[i] <> ':') do
    Dec(i);
  Ad := Copy(Ad, i + 1, MaxInt);
  Ad := ChangeFileExt(Ad, '');
  Result := TPath.Combine(TPath.Combine(TPath.GetTempPath, 'FirebirdYonetici\klon'),
    Ad + '_' + FormatDateTime('yyyymmdd_hhnnss', Now) + '.fbk');
end;

function KlonOnayMetni(const Tanim: TBaglantiTanimi; const YeniYol, YedekYolu: string): string;
begin
  Result := TF('KLON_ONAY', [Tanim.VeritabaniYolu, YeniYol, YedekYolu]);
end;

{ gbak'i sunucunun servis yoluyla calistirir (-se): 2.5, 3.0, 4.0, 5.0 sunucularinin hepsiyle uyumludur. }
function ServisAdi(const Tanim: TBaglantiTanimi): string;
begin
  Result := '"' + Tanim.Sunucu + '/' + IntToStr(Tanim.Port) + ':service_mgr"';
end;

function ServisIleKlonla(const Tanim: TBaglantiTanimi; const YeniYol, YedekYolu: string; Cikti: TYedekCiktisi): TKlonSonucu;
var
  Ham: string;
  Kod: Cardinal;
  Bitti: Boolean;
  Kullanici: string;
begin
  Result := Default(TKlonSonucu);
  Result.YeniYol := YeniYol;
  Result.YedekDosya := YedekYolu;
  Kullanici := ' -user "' + Tanim.Kullanici + '"';
  { 1. yedekle (yedek dosyasi sunucuda) }
  Bitti := AltIslemCalistir(GbakYolu, '-b' + Kullanici + ' -se ' + ServisAdi(Tanim) + ' "' + Tanim.VeritabaniYolu + '" "' + YedekYolu + '"',
    Tanim.Sifre, Cikti, Ham, Kod);
  if not Bitti then
  begin
    Result.Iptal := True;
    Exit;
  end;
  if Kod <> 0 then
  begin
    Result.Cumle := GbakHatasiniCevir(Ham);
    Result.Ayrinti := Ham;
    Exit;
  end;
  { 2. yeni dosyaya geri yukle (var olan dosya ezilmez: gbak -c reddeder) }
  Bitti := AltIslemCalistir(GbakYolu, '-c' + Kullanici + ' -se ' + ServisAdi(Tanim) + ' "' + YedekYolu + '" "' + YeniYol + '"',
    Tanim.Sifre, Cikti, Ham, Kod);
  if not Bitti then
  begin
    Result.Iptal := True;
    Exit;
  end;
  if Kod <> 0 then
  begin
    Result.Cumle := GbakHatasiniCevir(Ham);
    Result.Ayrinti := Ham;
    Exit;
  end;
  Result.Basarili := True;
end;

function VeritabaniKlonla(const Tanim: TBaglantiTanimi; const YeniYol: string; Cikti: TYedekCiktisi): TKlonSonucu;
var
  Yedek, Geri: TYedekSonucu;
begin
  if Tanim.Sunucu <> '' then
    Exit(ServisIleKlonla(Tanim, YeniYol, KlonYedekYolu(Tanim, YeniYol), Cikti));
  Result := Default(TKlonSonucu);
  Result.YeniYol := YeniYol;
  Result.YedekDosya := KlonYedekYolu(Tanim, YeniYol);
  ForceDirectories(ExtractFilePath(Result.YedekDosya));
  { 1. yedekle }
  if not YedekAl(Tanim, Result.YedekDosya, Cikti, Yedek) then
  begin
    Result.Iptal := Yedek.Iptal;
    Result.Cumle := Yedek.Cumle;
    Result.Ayrinti := Yedek.Ayrinti;
    Exit;
  end;
  { 2. yeni dosyaya geri yukle }
  if not GeriYukle(Tanim, Yedek.Dosya, YeniYol, Cikti, Geri) then
  begin
    Result.Iptal := Geri.Iptal;
    Result.Cumle := Geri.Cumle;
    Result.Ayrinti := Geri.Ayrinti;
    Exit;
  end;
  Result.YedekDosya := Yedek.Dosya;
  Result.Basarili := True;
end;

function KlonBaglantisiniEkle(const Tanim: TBaglantiTanimi; const YeniYol: string): string;
var
  Yeni: TBaglantiTanimi;
  Kayitli: TBaglantiTanimi;
  Sayac: Integer;
begin
  Yeni := Tanim;
  Yeni.VeritabaniYolu := YeniYol;
  Yeni.Ad := TF('KLON_AD', [Tanim.Ad]);
  Sayac := 1;
  while KayitliBaglantiBul(Yeni.Ad, Kayitli) do
  begin
    Inc(Sayac);
    Yeni.Ad := TF('KLON_AD', [Tanim.Ad]) + ' ' + IntToStr(Sayac);
  end;
  BaglantiKaydet(Yeni);
  Result := Yeni.Ad;
end;

end.
