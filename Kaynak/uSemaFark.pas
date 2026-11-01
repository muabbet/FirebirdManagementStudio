unit uSemaFark;

{ Asama 4b: iki veritabaninin sema farkini bulur.
  Yontem sade: her nesnenin CREATE script'i (uDDL) iki tarafta da uretilir ve satir satir karsilastirilir.
  Tablo ve view script'i kolonlari, kisitlari, indeksleri ve (tablo/view'a bagli) tetikleyicileri de icerir; bu yuzden
  onlarin farki ayni tablonun altinda gorunur. Yalniz veritabani tetikleyicileri (tabloya bagli olmayan) ayri
  karsilastirilir. Generator'in degeri veri sayildigi icin karsilastirilmaz (yalniz var/yok ve artis).
  Veritabaninda hicbir sey degistirilmez, yalniz okunur.

  Hedeflenen Firebird surumleri: 2.5, 3.0, 4.0, 5.0 (surume bagli kisim uMetadata/uDDL icindedir). }

interface

uses
  System.SysUtils, System.Classes, System.Generics.Collections, uBaglanti, uDDL;

type
  TFarkDurumu = (fdSadeceKaynakta, fdSadeceHedefte, fdFarkli);

  { Ayrinti: nesne yalniz bir tarafta ise o tarafin CREATE script'i; farkliysa satir farki ('- ' yalniz kaynakta,
    '+ ' yalniz hedefte olan satir). }
  TFarkKaydi = record
    Tur: TNesneTuru;
    Ad: string;
    Durum: TFarkDurumu;
    Ayrinti: string;
  end;

{ Iki acik baglantiyi karsilastirir. Ilerleme her nesne turunde bir kez cagrilir (tur sirasi: tablo, view, prosedur,
  tetikleyici, domain, exception, generator). }
function SemaKarsilastir(Kaynak, Hedef: TAcikBaglanti; Ilerleme: TProc<TNesneTuru>): TArray<TFarkKaydi>;

{ Baglanti adlarindan karsilastirir: acik olani kullanir, degilse kayitli sifreyle gecici baglanir ve isi bitince kapatir.
  Baglanilamazsa istisna verir (cagiran HataMetniniCevir ile gosterir). }
function SemaKarsilastirAdlarla(const KaynakAd, HedefAd: string; Ilerleme: TProc<TNesneTuru>): TArray<TFarkKaydi>;

implementation

uses
  uDil, uMetadata;

function AdlariAl(Bag: TAcikBaglanti; Tur: TNesneTuru): TArray<string>;
var
  Dongu: TArray<string>;
  Liste: TList<string>;
  Tetik: TTetikleyiciBilgisi;
  Alan: TDomainBilgisi;
  Istisna: TIstisnaBilgisi;
begin
  case Tur of
    ntTablo: Result := TabloAdlari(Bag);
    ntView: Result := ViewAdlariSirali(Bag, Dongu);
    ntProsedur: Result := ProsedurAdlari(Bag);
    ntGenerator: Result := GeneratorAdlari(Bag);
  else
    begin
      Liste := TList<string>.Create;
      try
        case Tur of
          ntTetikleyici:
            for Tetik in TetikleyicileriListele(Bag) do
              if Tetik.Tablo = '' then
                Liste.Add(Tetik.Ad);
          ntDomain:
            for Alan in DomainleriOku(Bag) do
              Liste.Add(Alan.Ad);
          ntIstisna:
            for Istisna in IstisnalariOku(Bag) do
              Liste.Add(Istisna.Ad);
        end;
        Result := Liste.ToArray;
      finally
        Liste.Free;
      end;
    end;
  end;
end;

{ Karsilastirma icin script satirlari: sag bosluklar ve bos satirlar atilir; generator'in SET GENERATOR (deger) satiri
  atilir. }
function SatirlariAl(Bag: TAcikBaglanti; Tur: TNesneTuru; const Ad: string): TStringList;
var
  Ham: TStringList;
  Satir: string;
begin
  Result := TStringList.Create;
  Ham := TStringList.Create;
  try
    Ham.Text := ScriptUret(Bag, Tur, Ad);
    for Satir in Ham do
    begin
      if Trim(Satir) = '' then
        Continue;
      if (Tur = ntGenerator) and Trim(Satir).StartsWith('SET GENERATOR', True) then
        Continue;
      Result.Add(TrimRight(Satir));
    end;
  finally
    Ham.Free;
  end;
end;

{ Iki satir listesi ayniysa '' ; satirlar ayni ama sirasi farkliysa kisa not ; degilse '- ' ve '+ ' satirlari. }
function SatirFarki(Kaynak, Hedef: TStringList; const SiraNotu: string): string;
var
  Satir: string;
  Fark: TStringList;
begin
  if Kaynak.Text = Hedef.Text then
    Exit('');
  Fark := TStringList.Create;
  try
    for Satir in Kaynak do
      if Hedef.IndexOf(Satir) < 0 then
        Fark.Add('- ' + Satir);
    for Satir in Hedef do
      if Kaynak.IndexOf(Satir) < 0 then
        Fark.Add('+ ' + Satir);
    if Fark.Count = 0 then
      Fark.Add(SiraNotu);
    Result := Fark.Text;
  finally
    Fark.Free;
  end;
end;

procedure FarkEkle(Liste: TList<TFarkKaydi>; Tur: TNesneTuru; const Ad: string; Durum: TFarkDurumu;
  const Ayrinti: string);
var
  Kayit: TFarkKaydi;
begin
  Kayit.Tur := Tur;
  Kayit.Ad := Ad;
  Kayit.Durum := Durum;
  Kayit.Ayrinti := Ayrinti;
  Liste.Add(Kayit);
end;

function ScriptVeyaHata(Bag: TAcikBaglanti; Tur: TNesneTuru; const Ad: string): string;
begin
  try
    Result := ScriptUret(Bag, Tur, Ad);
  except
    on E: Exception do
      Result := E.Message;
  end;
end;

function Icinde(const Liste: TArray<string>; const Ad: string): Boolean;
var
  Oge: string;
begin
  Result := False;
  for Oge in Liste do
    if Oge = Ad then
      Exit(True);
end;

procedure TuruKarsilastir(Kaynak, Hedef: TAcikBaglanti; Tur: TNesneTuru; Liste: TList<TFarkKaydi>);
var
  KAdlar, HAdlar: TArray<string>;
  Ad, Fark: string;
  KSatir, HSatir: TStringList;
begin
  KAdlar := AdlariAl(Kaynak, Tur);
  HAdlar := AdlariAl(Hedef, Tur);
  for Ad in KAdlar do
    if not Icinde(HAdlar, Ad) then
      FarkEkle(Liste, Tur, Ad, fdSadeceKaynakta, ScriptVeyaHata(Kaynak, Tur, Ad));
  for Ad in HAdlar do
    if not Icinde(KAdlar, Ad) then
      FarkEkle(Liste, Tur, Ad, fdSadeceHedefte, ScriptVeyaHata(Hedef, Tur, Ad));
  { Generator var/yok disinda bir sey karsilastirmaz: artis farki script'te INCREMENT BY satiri olarak gorunur. }
  for Ad in KAdlar do
    if Icinde(HAdlar, Ad) then
    begin
      KSatir := nil;
      HSatir := nil;
      try
        try
          KSatir := SatirlariAl(Kaynak, Tur, Ad);
          HSatir := SatirlariAl(Hedef, Tur, Ad);
          Fark := SatirFarki(KSatir, HSatir, T('FARK_SIRA'));
        except
          on E: Exception do
            Fark := E.Message;
        end;
        if Fark <> '' then
          FarkEkle(Liste, Tur, Ad, fdFarkli, Fark);
      finally
        KSatir.Free;
        HSatir.Free;
      end;
    end;
end;

function SemaKarsilastir(Kaynak, Hedef: TAcikBaglanti; Ilerleme: TProc<TNesneTuru>): TArray<TFarkKaydi>;
var
  Liste: TList<TFarkKaydi>;
  Tur: TNesneTuru;
begin
  Liste := TList<TFarkKaydi>.Create;
  try
    for Tur in [ntTablo, ntView, ntProsedur, ntTetikleyici, ntDomain, ntIstisna, ntGenerator] do
    begin
      if Assigned(Ilerleme) then
        Ilerleme(Tur);
      TuruKarsilastir(Kaynak, Hedef, Tur, Liste);
    end;
    Result := Liste.ToArray;
  finally
    Liste.Free;
  end;
end;

{ Acik baglanti varsa onu, yoksa kayitli sifreyle gecici baglanti verir. Gecici ise Gecici True doner. }
function BaglantiAl(const Ad: string; out Gecici: Boolean): TAcikBaglanti;
var
  Tanim: TBaglantiTanimi;
begin
  Gecici := False;
  Result := FbAcikBaglanti(Ad);
  if Result <> nil then
    Exit;
  if not KayitliBaglantiBul(Ad, Tanim) then
    raise Exception.Create(TF('FARK_BAGLANTI_YOK', [Ad]));
  Result := FbGeciciBaglan(Tanim);
  Gecici := True;
end;

function SemaKarsilastirAdlarla(const KaynakAd, HedefAd: string; Ilerleme: TProc<TNesneTuru>): TArray<TFarkKaydi>;
var
  K, H: TAcikBaglanti;
  KGecici, HGecici: Boolean;
begin
  K := nil;
  H := nil;
  KGecici := False;
  HGecici := False;
  try
    K := BaglantiAl(KaynakAd, KGecici);
    H := BaglantiAl(HedefAd, HGecici);
    Result := SemaKarsilastir(K, H, Ilerleme);
  finally
    if KGecici then
      K.Free;
    if HGecici then
      H.Free;
  end;
end;

end.
