{ uYedekDogrula.pas - Yedegi dogrulama (hic geri yuklenmemis yedek guvenilir degildir).

  Hedeflenen Firebird surumleri: 2.5, 3.0, 4.0, 5.0
  Denenen Firebird surumleri: 3.0.14, 4.0.7 (testler)

  Planin klasorundeki bu veritabaninin en yeni yedegi (.fbk) YENI ve benzersiz bir dosyaya geri yuklenir
  (Klasor\Dogrulama\<ad>_dogrulama_yyyymmdd_hhnnss.fdb), geri yuklenen veritabani acilir, nesne sayilari ve her
  tablonun kayit sayisi okunur; sonuc canli veritabaniyla karsilastirilarak raporlanir. Canli veritabanina yalniz
  okunur (sayim) dokunulur. Geri yuklenen dosya SILINMEZ: yer kaplar, isi bitince kullanici elle siler.

  Geri yukleme sunucu kipinde hedef yolu SUNUCUNUN diski sayar; bu yuzden yalniz bu bilgisayardaki sunucuda
  (ya da gomulu kipte) dogrulanir.

  Sonuc yedekgunlugu.txt dosyasina DOGRULAMA-OK / DOGRULAMA-HATA olarak yazilir (yedek satirlari OK / HATA'dir;
  acilis uyarisi yalniz onlara bakar). }
unit uYedekDogrula;

interface

uses
  System.SysUtils, System.Classes, uBaglanti, uYedek;

const
  { Kayit sayisi yerine: tablo okunamadi / canli veritabaninda yok }
  SAYIM_OKUNAMADI = -1;
  SAYIM_YOK = -2;

type
  TDogrulamaHazirligi = record
    BaglantiAd: string;
    Tanim: TBaglantiTanimi;
    { Dogrulanacak en yeni yedek }
    YedekDosyasi: string;
    YedekBoyutu: Int64;
    { Geri yuklenecek yeni dosya (henuz yok) }
    HedefDosya: string;
    { Geri yuklenen dosyanin kabaca kaplayacagi yer }
    TahminiBoyut: Int64;
  end;

  TDogrulamaSonucu = record
    Gecerli: Boolean;
    Iptal: Boolean;
    { Tek cumlelik sonuc: "Yedek gecerli: ..." ya da "Yedek GECERSIZ: ..." }
    Ozet: string;
    { Ozet + yapi ve kayit sayisi karsilastirmasi + dosya yeri (cok satirli) }
    Rapor: string;
    { Ham gbak metni ve komut (yalniz geri yukleme basarisizsa dolu) }
    Ayrinti: string;
    { Geri yuklenen dosya (olusmadiysa yine de yolu) }
    GeriYuklenen: string;
    TabloSayisi: Integer;
    Sure: Int64;
  end;

{ Dogrulama icin gerekenleri hazirlar: plan, kayitli baglanti ve sifresi, gbak, yerel sunucu, planin klasorunde yedek.
  Olmazsa False ve anlasilir Cumle doner. Hicbir dosya olusturmaz. }
function DogrulamaHazirla(const BaglantiAd: string; out Hazirlik: TDogrulamaHazirligi; out Cumle: string): Boolean;

{ Kullaniciya gosterilecek onay metni: hangi yedek, hangi yeni dosya, canliya dokunulmaz, dosya silinmez, yer. }
function DogrulamaOnayMetni(const Hazirlik: TDogrulamaHazirligi): string;

{ Dogrulamayi yapar (uzun surer; Cikti ile ilerleme ve iptal) ve sonucu gunluge yazar. Gecerliyse True. }
function YedegiDogrula(const Hazirlik: TDogrulamaHazirligi; Cikti: TYedekCiktisi; out Sonuc: TDogrulamaSonucu): Boolean;

implementation

uses
  System.IOUtils, System.Diagnostics, uDil, uMetadata, uSorgu, uYedekPlan;

type
  TYapiSayilari = record
    Tablo, View, Prosedur, Tetikleyici, Generator: Integer;
  end;

function SureMetni(Milisaniye: Int64): string;
begin
  Result := Format('%.1f', [Milisaniye / 1000]);
end;

{ ---------- Hazirlik ---------- }

function DogrulamaHedefi(const Klasor, VeritabaniYolu: string): string;
var
  Ornek, Onek, Ad: string;
  Sira: Integer;
begin
  Ornek := VarsayilanYedekAdi(VeritabaniYolu);
  Onek := Copy(Ornek, 1, Length(Ornek) - Length('_yyyymmdd_hhnnss.fbk'));
  Ad := TPath.Combine(TPath.Combine(Klasor, 'Dogrulama'), Onek + '_dogrulama_' + FormatDateTime('yyyymmdd_hhnnss', Now));
  Result := Ad + '.fdb';
  Sira := 1;
  { Var olan dosya hicbir zaman ezilmez: ayni saniyede ikinci dogrulama _2 alir }
  while TFile.Exists(Result) do
  begin
    Inc(Sira);
    Result := Ad + '_' + IntToStr(Sira) + '.fdb';
  end;
end;

function DogrulamaHazirla(const BaglantiAd: string; out Hazirlik: TDogrulamaHazirligi; out Cumle: string): Boolean;
var
  Plan: TYedekPlani;
begin
  Hazirlik := Default(TDogrulamaHazirligi);
  Hazirlik.BaglantiAd := BaglantiAd;
  Cumle := '';
  if not YedekPlaniOku(BaglantiAd, Plan) then
    Cumle := TF('ERR_YEDEKPLAN_YOK', [BaglantiAd])
  else if not KayitliBaglantiBul(BaglantiAd, Hazirlik.Tanim) then
    Cumle := TF('ERR_KAYIT_YOK', [BaglantiAd])
  else if Hazirlik.Tanim.Sifre = '' then
    Cumle := T('ERR_YEDEKPLAN_SIFRE')
  else if not GbakVarMi then
    Cumle := T('ERR_YEDEK_GBAK_YOK')
  else if not YerelSunucuMu(Hazirlik.Tanim.Sunucu) then
    Cumle := T('ERR_DOGRULA_UZAK')
  else
  begin
    Hazirlik.YedekDosyasi := EnYeniYedekDosyasi(Plan.Klasor, Hazirlik.Tanim.VeritabaniYolu);
    if Hazirlik.YedekDosyasi = '' then
      Cumle := TF('ERR_DOGRULA_YEDEK_YOK', [Plan.Klasor])
    else
    begin
      Hazirlik.YedekBoyutu := TFile.GetSize(Hazirlik.YedekDosyasi);
      Hazirlik.HedefDosya := DogrulamaHedefi(Plan.Klasor, Hazirlik.Tanim.VeritabaniYolu);
      { Canli dosya bu bilgisayardaysa kabaca onun kadar yer kaplar, degilse yedek boyutu bir fikir verir }
      if TFile.Exists(Hazirlik.Tanim.VeritabaniYolu) then
        Hazirlik.TahminiBoyut := TFile.GetSize(Hazirlik.Tanim.VeritabaniYolu)
      else
        Hazirlik.TahminiBoyut := Hazirlik.YedekBoyutu;
    end;
  end;
  Result := Cumle = '';
end;

function DogrulamaOnayMetni(const Hazirlik: TDogrulamaHazirligi): string;
begin
  Result := TF('DOGRULA_ONAY', [Hazirlik.YedekDosyasi, BoyutMetni(Hazirlik.YedekBoyutu), Hazirlik.HedefDosya,
    BoyutMetni(Hazirlik.TahminiBoyut)]);
end;

{ ---------- Okuma ---------- }

procedure YapiSayilariniOku(Bag: TAcikBaglanti; out Sayilar: TYapiSayilari);
var
  Dongu: TArray<string>;
begin
  Sayilar.Tablo := Length(TabloAdlari(Bag));
  Sayilar.View := Length(ViewAdlariSirali(Bag, Dongu));
  Sayilar.Prosedur := Length(ProsedurAdlari(Bag));
  Sayilar.Tetikleyici := Length(TetikleyicileriListele(Bag));
  Sayilar.Generator := Length(GeneratorAdlari(Bag));
end;

{ Tablo adi Liste'de var mi (Firebird adlari harf buyuklugune duyarlidir) }
function ListedeVar(const Liste: TArray<string>; const Ad: string): Boolean;
var
  Oge: string;
begin
  Result := False;
  for Oge in Liste do
    if Oge = Ad then
      Exit(True);
end;

function SayimMetni(Sayi: Int64): string;
begin
  if Sayi = SAYIM_OKUNAMADI then
    Result := T('DOGRULA_OKUNAMADI')
  else if Sayi = SAYIM_YOK then
    Result := T('DOGRULA_YOK')
  else
    Result := IntToStr(Sayi);
end;

function KayitSayisiniOku(Bag: TAcikBaglanti; const Tablo: string): Int64;
begin
  try
    Result := KayitSayisi(Bag, Tablo, '');
  except
    Result := SAYIM_OKUNAMADI;
  end;
end;

procedure YapiSatiriEkle(Rapor: TStrings; const TurAnahtari: string; Yedekte, Canlida: Integer; CanliVar: Boolean);
var
  Satir: string;
begin
  if CanliVar then
  begin
    Satir := TF('DOGRULA_YAPI_SATIR', [T(TurAnahtari), Yedekte, Canlida]);
    if Yedekte <> Canlida then
      Satir := Satir + ' ' + T('DOGRULA_FARK_BILGI');
  end
  else
    Satir := TF('DOGRULA_YAPI_SATIR_YEDEK', [T(TurAnahtari), Yedekte]);
  Rapor.Add('  ' + Satir);
end;

{ Geri yuklenen veritabanini ve (varsa) canliyi okur; Sonuc'u ve Rapor'u doldurur. }
procedure GeriYuklenenOku(const Hazirlik: TDogrulamaHazirligi; Cikti: TYedekCiktisi; var Sonuc: TDogrulamaSonucu;
  Rapor: TStrings);
var
  Yedek, Canli: TAcikBaglanti;
  YedekTanim: TBaglantiTanimi;
  YedekSay, CanliSay: TYapiSayilari;
  Tablolar, CanliTablolar: TArray<string>;
  YedekKayit, CanliKayit: TArray<Int64>;
  Okunamayan: string;
  OkunamayanSayi, FarkSayisi, i: Integer;
  Iptal: Boolean;
begin
  YedekTanim := Hazirlik.Tanim;
  YedekTanim.VeritabaniYolu := Hazirlik.HedefDosya;
  Yedek := nil;
  Canli := nil;
  try
    try
      Yedek := FbGeciciBaglan(YedekTanim);
    except
      on E: Exception do
      begin
        Sonuc.Ozet := TF('DOGRULA_OZET_GECERSIZ', [TF('ERR_DOGRULA_ACILMADI', [HataMetniniCevir(E)])]);
        Sonuc.Ayrinti := E.Message;
        Exit;
      end;
    end;
    YapiSayilariniOku(Yedek, YedekSay);
    Tablolar := TabloAdlari(Yedek);
    SetLength(YedekKayit, Length(Tablolar));
    SetLength(CanliKayit, Length(Tablolar));
    Iptal := False;
    OkunamayanSayi := 0;
    Okunamayan := '';
    for i := 0 to High(Tablolar) do
    begin
      if Assigned(Cikti) then
      begin
        Cikti('', Iptal);
        if Iptal then
        begin
          Sonuc.Iptal := True;
          Sonuc.Ozet := T('DOGRULA_OZET_IPTAL');
          Exit;
        end;
      end;
      YedekKayit[i] := KayitSayisiniOku(Yedek, Tablolar[i]);
      if YedekKayit[i] = SAYIM_OKUNAMADI then
      begin
        Inc(OkunamayanSayi);
        if OkunamayanSayi <= 5 then
        begin
          if Okunamayan <> '' then
            Okunamayan := Okunamayan + ', ';
          Okunamayan := Okunamayan + Tablolar[i];
        end;
      end;
    end;
    Sonuc.TabloSayisi := Length(Tablolar);

    { Canli veritabani (yalniz sayim); baglanamazsa karsilastirma yapilmaz, dogrulama yine gecerli olabilir }
    try
      Canli := FbGeciciBaglan(Hazirlik.Tanim);
      CanliTablolar := TabloAdlari(Canli);
      YapiSayilariniOku(Canli, CanliSay);
      for i := 0 to High(Tablolar) do
        if ListedeVar(CanliTablolar, Tablolar[i]) then
          CanliKayit[i] := KayitSayisiniOku(Canli, Tablolar[i])
        else
          CanliKayit[i] := SAYIM_YOK;
    except
      Canli.Free;
      Canli := nil;
    end;

    if OkunamayanSayi > 0 then
      Sonuc.Ozet := TF('DOGRULA_OZET_OKUNAMAYAN', [OkunamayanSayi, Okunamayan])
    else
    begin
      Sonuc.Gecerli := True;
      Sonuc.Ozet := TF('DOGRULA_OZET_GECERLI', [Length(Tablolar)]);
    end;

    Rapor.Add(Sonuc.Ozet);
    Rapor.Add('');
    Rapor.Add(T('DOGRULA_YAPI_BASLIK'));
    YapiSatiriEkle(Rapor, 'DOGRULA_TUR_TABLO', YedekSay.Tablo, CanliSay.Tablo, Canli <> nil);
    YapiSatiriEkle(Rapor, 'DOGRULA_TUR_VIEW', YedekSay.View, CanliSay.View, Canli <> nil);
    YapiSatiriEkle(Rapor, 'DOGRULA_TUR_PROSEDUR', YedekSay.Prosedur, CanliSay.Prosedur, Canli <> nil);
    YapiSatiriEkle(Rapor, 'DOGRULA_TUR_TETIKLEYICI', YedekSay.Tetikleyici, CanliSay.Tetikleyici, Canli <> nil);
    YapiSatiriEkle(Rapor, 'DOGRULA_TUR_GENERATOR', YedekSay.Generator, CanliSay.Generator, Canli <> nil);
    Rapor.Add('');
    if Canli <> nil then
      Rapor.Add(T('DOGRULA_KAYIT_BASLIK'))
    else
      Rapor.Add(T('DOGRULA_KAYIT_BASLIK_YEDEK') + ' ' + T('DOGRULA_CANLI_YOK'));
    FarkSayisi := 0;
    for i := 0 to High(Tablolar) do
      if Canli <> nil then
      begin
        if YedekKayit[i] <> CanliKayit[i] then
        begin
          Inc(FarkSayisi);
          Rapor.Add('  ' + TF('DOGRULA_KAYIT_SATIR', [Tablolar[i], SayimMetni(YedekKayit[i]), SayimMetni(CanliKayit[i])]) +
            ' ' + T('DOGRULA_FARK_BILGI'));
        end
        else
          Rapor.Add('  ' + TF('DOGRULA_KAYIT_SATIR', [Tablolar[i], SayimMetni(YedekKayit[i]), SayimMetni(CanliKayit[i])]));
      end
      else
        Rapor.Add('  ' + Tablolar[i] + ': ' + SayimMetni(YedekKayit[i]));
    if FarkSayisi > 0 then
      Rapor.Add(TF('DOGRULA_FARK_OZET', [FarkSayisi]));
  finally
    Canli.Free;
    Yedek.Free;
  end;
end;

{ ---------- Dogrulama ---------- }

function YedegiDogrula(const Hazirlik: TDogrulamaHazirligi; Cikti: TYedekCiktisi; out Sonuc: TDogrulamaSonucu): Boolean;
var
  Geri: TYedekSonucu;
  Rapor: TStringList;
  Saat: TStopwatch;
begin
  Sonuc := Default(TDogrulamaSonucu);
  Sonuc.GeriYuklenen := Hazirlik.HedefDosya;
  Rapor := TStringList.Create;
  Saat := TStopwatch.StartNew;
  try
    try
      ForceDirectories(ExtractFilePath(Hazirlik.HedefDosya));
      if not GeriYukle(Hazirlik.Tanim, Hazirlik.YedekDosyasi, Hazirlik.HedefDosya, Cikti, Geri) then
      begin
        Sonuc.Iptal := Geri.Iptal;
        if Geri.Iptal then
          Sonuc.Ozet := T('DOGRULA_OZET_IPTAL')
        else
          Sonuc.Ozet := TF('DOGRULA_OZET_GECERSIZ', [Geri.Cumle]);
        Sonuc.Ayrinti := Geri.Ayrinti + sLineBreak + Geri.HamCikti;
        Rapor.Add(Sonuc.Ozet);
        if Geri.YarimDosya <> '' then
          Rapor.Add(TF('DOGRULA_YARIM', [Geri.YarimDosya]));
      end
      else
        GeriYuklenenOku(Hazirlik, Cikti, Sonuc, Rapor);
    except
      on E: Exception do
      begin
        Sonuc.Gecerli := False;
        Sonuc.Ozet := TF('DOGRULA_OZET_GECERSIZ', [HataMetniniCevir(E)]);
        Sonuc.Ayrinti := E.Message;
        Rapor.Clear;
        Rapor.Add(Sonuc.Ozet);
      end;
    end;
    Sonuc.Sure := Saat.ElapsedMilliseconds;
    if Sonuc.Ozet = '' then
      Sonuc.Ozet := T('DOGRULA_OZET_IPTAL');
    if Rapor.Count = 0 then
      Rapor.Add(Sonuc.Ozet);
    Rapor.Add('');
    Rapor.Add(TF('DOGRULA_RAPOR_YEDEK', [Hazirlik.YedekDosyasi]));
    Rapor.Add(TF('DOGRULA_RAPOR_DOSYA', [Hazirlik.HedefDosya]));
    Rapor.Add(TF('DOGRULA_RAPOR_SURE', [SureMetni(Sonuc.Sure)]));
    Sonuc.Rapor := Trim(Rapor.Text);
  finally
    Rapor.Free;
  end;
  if Sonuc.Gecerli then
    GunlukSatiriYaz(Hazirlik.BaglantiAd, 'DOGRULAMA-OK', TF('DOGRULA_GUNLUK_TAMAM', [Hazirlik.YedekDosyasi,
      Sonuc.TabloSayisi, Hazirlik.HedefDosya, SureMetni(Sonuc.Sure)]))
  else
    GunlukSatiriYaz(Hazirlik.BaglantiAd, 'DOGRULAMA-HATA', Sonuc.Ozet + ' (' + Hazirlik.YedekDosyasi + ')');
  Result := Sonuc.Gecerli;
end;

end.
