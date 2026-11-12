program BaglantiDosyasiTest;

{ Kayitli baglanti dosyasinin guvenligini dener (K1):
  - bozuk dosya silinmez, yanina tasinir, uyari uretilir
  - yazma gecici dosya uzerinden yapilir
  - sifre DPAPI ile gidis-donus calisir
  Gercek verilere dokunmaz: VeriKlasoruAyarla ile gecici bir klasor kullanir.
  Kullanim: BaglantiDosyasiTest.exe <gecici_klasor> <cikti.txt> }

{$APPTYPE CONSOLE}

uses
  System.SysUtils, System.Classes, System.IOUtils,
  uDil, uBaglanti;

var
  Cikti: TStringList;
  Klasor, Dosya: string;
  Hatalar: Integer;

procedure Kontrol(const Ad: string; Sonuc: Boolean);
begin
  if Sonuc then
    Cikti.Add('OK    ' + Ad)
  else
  begin
    Cikti.Add('HATA  ' + Ad);
    Inc(Hatalar);
  end;
end;

function Tanim(const Ad, Sifre: string; Kaydet: Boolean): TBaglantiTanimi;
begin
  Result := Default(TBaglantiTanimi);
  Result.Ad := Ad;
  Result.Sunucu := 'localhost';
  Result.Port := 3050;
  Result.VeritabaniYolu := 'C:\ornek\' + Ad + '.fdb';
  Result.Kullanici := 'SYSDBA';
  Result.Sifre := Sifre;
  Result.KarakterSeti := 'WIN1254';
  Result.SifreyiKaydet := Kaydet;
end;

function BozukDosyalar: TArray<string>;
begin
  Result := TDirectory.GetFiles(Klasor, 'baglantilar.json.bozuk-*');
end;

procedure BozukSenaryo(const Ad, Icerik: string);
var
  Liste: TArray<TBaglantiTanimi>;
  Once: Integer;
  Uyari: string;
begin
  Once := Length(BozukDosyalar);
  TFile.WriteAllText(Dosya, Icerik, TEncoding.UTF8);
  Liste := KayitliBaglantilar;
  Uyari := BozukDosyaUyarisiAl;
  Kontrol(Ad + ': liste bos doner', Length(Liste) = 0);
  Kontrol(Ad + ': uyari uretildi (.bozuk- gecer)', Pos('.bozuk-', Uyari) > 0);
  Kontrol(Ad + ': bozuk dosya yanina tasindi (silinmedi)', Length(BozukDosyalar) = Once + 1);
  Kontrol(Ad + ': asil dosya yerinde degil', not TFile.Exists(Dosya));
  { ayni saniyede iki bozuk dosya cakismasin }
  Sleep(1100);
end;

{ Klasor alanlari olmayan eski bicimdeki dosya okunabilmeli ve silinmemeli. }
procedure EskiBicimSenaryosu;
var
  Liste: TArray<TBaglantiTanimi>;
begin
  TFile.WriteAllText(Dosya,
    '{"Baglantilar": [' +
    '{"Ad": "Eski1", "Sunucu": "srv", "Port": 3051, "VeritabaniYolu": "C:\\x\\a.fdb", "Kullanici": "SYSDBA", "KarakterSeti": "UTF8", "SifreDpapi": ""},' +
    '{"Ad": "Eski2", "Sunucu": "", "Port": 3050, "VeritabaniYolu": "C:\\x\\b.fdb", "Kullanici": "SYSDBA", "KarakterSeti": "WIN1254", "SifreDpapi": ""}]}',
    TEncoding.UTF8);
  Liste := KayitliBaglantilar;
  Kontrol('eski bicim: 2 baglanti okunur', Length(Liste) = 2);
  Kontrol('eski bicim: alanlar dogru', (Length(Liste) = 2) and (Liste[0].Ad = 'Eski1') and
    (Liste[0].Port = 3051) and (Liste[0].KarakterSeti = 'UTF8') and (Liste[1].Ad = 'Eski2'));
  Kontrol('eski bicim: Klasor bos', (Length(Liste) = 2) and (Liste[0].Klasor = '') and (Liste[1].Klasor = ''));
  Kontrol('eski bicim: klasor listesi bos', Length(KayitliKlasorler) = 0);
  Kontrol('eski bicim: uyari yok, dosya yerinde', (BozukDosyaUyarisiAl = '') and TFile.Exists(Dosya));
  { Eski dosyaya yeni alanlarla yazilinca baglantilar kaybolmaz }
  KlasorEkle('Yeni');
  Kontrol('eski bicim: klasor eklenince baglantilar duruyor', Length(KayitliBaglantilar) = 2);
end;

{ Klasorler: ekleme, bos klasor, baglantiyi tasima, ad degistirme, kaldirma, gidis-donus. }
procedure KlasorSenaryosu;
var
  Liste: TArray<TBaglantiTanimi>;
  Klasorler: TArray<string>;
  Musteri, Eski: string;
  Kural: Boolean;
  Bulunan: TBaglantiTanimi;
begin
  { 'Musteri' ve Turkce karakterli ad: M-u-s-t-e-r-i yerine U+00FC U+015F harfleri }
  Musteri := 'M'#$00FC#$015F'teri';
  TFile.WriteAllText(Dosya, '{"Baglantilar": []}', TEncoding.UTF8);
  BaglantiKaydet(Tanim('A', 'sifre-a', True));
  BaglantiKaydet(Tanim('B', '', False));
  KlasorEkle(Musteri);
  KlasorEkle('Bos klasor');
  Klasorler := KayitliKlasorler;
  Kontrol('klasor: iki klasor kayitli (bos olan dahil)', Length(Klasorler) = 2);

  Kural := False;
  try
    KlasorEkle(AnsiLowerCase(Musteri));
  except
    on EKayitKurali do
      Kural := True;
  end;
  Kontrol('klasor: ayni ad (buyuk/kucuk harf farkli) reddedilir', Kural);
  Kural := False;
  try
    KlasorEkle('   ');
  except
    on EKayitKurali do
      Kural := True;
  end;
  Kontrol('klasor: bos ad reddedilir', Kural);
  Kural := False;
  try
    BaglantiKlasoruAyarla('A', 'Olmayan klasor');
  except
    on EKayitKurali do
      Kural := True;
  end;
  Kontrol('klasor: olmayan klasore tasima reddedilir', Kural);

  BaglantiKlasoruAyarla('A', Musteri);
  Liste := KayitliBaglantilar;
  Kontrol('klasor: A klasore girdi, B kokte', (Length(Liste) = 2) and (Liste[0].Klasor = Musteri) and (Liste[1].Klasor = ''));
  Kontrol('klasor: klasore girince sifre bozulmadi', (Length(Liste) = 2) and (Liste[0].Sifre = 'sifre-a'));
  { Duzenleme (BaglantiKaydet) klasoru silmemeli }
  BaglantiKaydet(Tanim('A', 'sifre-a2', True));
  KayitliBaglantiBul('A', Bulunan);
  Kontrol('klasor: duzenleyince klasor korunur', (Bulunan.Klasor = Musteri) and (Bulunan.Sifre = 'sifre-a2'));
  { Ad degistirme: ayni yerde kalir, klasor korunur }
  BaglantiKaydet(Tanim('A-yeni', 'sifre-a2', True), 'A');
  Liste := KayitliBaglantilar;
  Kontrol('klasor: ad degisti, 2 kayit, sira ve klasor korundu', (Length(Liste) = 2) and
    (Liste[0].Ad = 'A-yeni') and (Liste[0].Klasor = Musteri) and (Liste[1].Ad = 'B'));
  Kontrol('klasor: eski ad artik yok', not KayitliBaglantiBul('A', Bulunan));

  { Dosyadan yeniden okunan hali (program kapanip acilma benzetimi): ayni sonuc }
  Klasorler := KayitliKlasorler;
  Kontrol('klasor: gidis-donus klasor listesi ayni', (Length(Klasorler) = 2) and
    (Klasorler[0] = Musteri) and (Klasorler[1] = 'Bos klasor'));
  Kontrol('klasor: dosyada Klasorler alani var', Pos('"Klasorler"', TFile.ReadAllText(Dosya, TEncoding.UTF8)) > 0);
  Kontrol('klasor: .tmp arkada kalmadi', not TFile.Exists(Dosya + '.tmp'));

  { Klasor adi degisince icindeki baglanti da yeni adi gosterir }
  Eski := Musteri;
  Musteri := Musteri + '2';
  KlasorYenidenAdlandir(Eski, Musteri);
  Liste := KayitliBaglantilar;
  Klasorler := KayitliKlasorler;
  Kontrol('klasor: yeniden adlandirma baglantiya yansidi', (Length(Liste) = 2) and (Liste[0].Klasor = Musteri) and
    (Length(Klasorler) = 2) and (Klasorler[0] = Musteri));
  Kural := False;
  try
    KlasorYenidenAdlandir(Musteri, 'bos KLASOR');
  except
    on EKayitKurali do
      Kural := True;
  end;
  Kontrol('klasor: baska klasorun adina yeniden adlandirma reddedilir', Kural);

  { Klasoru kaldirmak baglantiyi silmez, kok duzeye cikarir }
  KlasorKaldir(Musteri);
  Liste := KayitliBaglantilar;
  Klasorler := KayitliKlasorler;
  Kontrol('klasor: kaldirinca baglanti silinmedi, kokte', (Length(Liste) = 2) and (Liste[0].Ad = 'A-yeni') and (Liste[0].Klasor = ''));
  Kontrol('klasor: kaldirinca sadece diger klasor kaldi', (Length(Klasorler) = 1) and (Klasorler[0] = 'Bos klasor'));

  { Elle bozulmus dosya: Klasorler listesinde olmayan klasor adi kaybolmaz }
  TFile.WriteAllText(Dosya,
    '{"Klasorler": [], "Baglantilar": [{"Ad": "Z", "Sunucu": "s", "Port": 3050, "VeritabaniYolu": "x", "Kullanici": "u", "KarakterSeti": "UTF8", "Klasor": "Yetim", "SifreDpapi": ""}]}',
    TEncoding.UTF8);
  Klasorler := KayitliKlasorler;
  Kontrol('klasor: listede olmayan klasor adi eklenir', (Length(Klasorler) = 1) and (Klasorler[0] = 'Yetim'));

  { Baglantiyi kayittan kaldirmak klasoru silmez }
  BaglantiListedenKaldir('Z');
  Kontrol('klasor: baglanti kalkinca klasor durur', (Length(KayitliBaglantilar) = 0) and (Length(KayitliKlasorler) = 1));
end;

{ Ust klasorun adini (ya da kokte ise bos) verir. }
function UstuNedir(const Agac: TArray<TKlasorKaydi>; const Ad: string): string;
var
  Kayit: TKlasorKaydi;
begin
  Result := '<yok>';
  for Kayit in Agac do
    if SameText(Kayit.Ad, Ad) then
      Exit(Kayit.Ust);
end;

function KuralHatasiVerdi(const Ad, Ust: string; Tasi: Boolean): Boolean;
begin
  Result := False;
  try
    if Tasi then
      KlasorUstuAyarla(Ad, Ust)
    else
      KlasorEkle(Ad, Ust);
  except
    on EKayitKurali do
      Result := True;
  end;
end;

{ Klasor icinde klasor: ekleme, tasima, dongu engeli, ad degistirme, kaldirma, gidis-donus, eski dosya, bozuk dosya. }
procedure IcIceKlasorSenaryosu;
var
  Agac: TArray<TKlasorKaydi>;
  Liste: TArray<TBaglantiTanimi>;
  Ham: string;
begin
  TFile.WriteAllText(Dosya, '{"Baglantilar": []}', TEncoding.UTF8);
  BaglantiKaydet(Tanim('A', '', False));
  KlasorEkle('Musteriler');
  KlasorEkle('Istanbul', 'Musteriler');
  KlasorEkle('Kadikoy', 'Istanbul');
  KlasorEkle('Ankara', 'musteriler');
  Agac := KayitliKlasorAgaci;
  Kontrol('ic ice: 4 klasor', Length(Agac) = 4);
  Kontrol('ic ice: Musteriler kokte', UstuNedir(Agac, 'Musteriler') = '');
  Kontrol('ic ice: Istanbul, Musteriler icinde', UstuNedir(Agac, 'Istanbul') = 'Musteriler');
  Kontrol('ic ice: Kadikoy, Istanbul icinde (3 duzey)', UstuNedir(Agac, 'Kadikoy') = 'Istanbul');
  Kontrol('ic ice: ust adi klasor listesindeki yazilisla saklanir', UstuNedir(Agac, 'Ankara') = 'Musteriler');
  Kontrol('ic ice: ust klasor her zaman once gelir',
    (Agac[0].Ad = 'Musteriler') and (UstuNedir(Agac, 'Kadikoy') <> '') and (Length(Agac) = 4));
  Kontrol('ic ice: olmayan ust klasore ekleme reddedilir', KuralHatasiVerdi('Yeni', 'Olmayan', False));
  Kontrol('ic ice: ayni ad baska duzeyde de reddedilir (adlar butun agacta tek)', KuralHatasiVerdi('kadikoy', 'Ankara', False));
  Kontrol('ic ice: klasor kendi icine giremez', KuralHatasiVerdi('Istanbul', 'Istanbul', True));
  Kontrol('ic ice: klasor altindaki klasorun icine giremez (dongu)', KuralHatasiVerdi('Musteriler', 'Kadikoy', True));
  Kontrol('ic ice: dongu denemesi dosyayi bozmadi', UstuNedir(KayitliKlasorAgaci, 'Musteriler') = '');
  Kontrol('ic ice: olmayan klasoru tasima reddedilir', KuralHatasiVerdi('Olmayan', 'Ankara', True));

  { Tasima ve gidis-donus }
  KlasorUstuAyarla('Kadikoy', 'Ankara');
  Kontrol('ic ice: tasindi', UstuNedir(KayitliKlasorAgaci, 'Kadikoy') = 'Ankara');
  KlasorUstuAyarla('Kadikoy', '');
  Kontrol('ic ice: kok duzeye tasindi', UstuNedir(KayitliKlasorAgaci, 'Kadikoy') = '');
  KlasorUstuAyarla('Kadikoy', 'Istanbul');
  Ham := TFile.ReadAllText(Dosya, TEncoding.UTF8);
  Kontrol('ic ice: dosyada KlasorUstleri alani var', Pos('"KlasorUstleri"', Ham) > 0);
  Kontrol('ic ice: Klasorler listesi duz kaldi (eski surum okuyabilir)', Pos('"Klasorler"', Ham) > 0);
  Kontrol('ic ice: KayitliKlasorler duz liste doner', Length(KayitliKlasorler) = 4);

  { Ad degistirme: altindaki klasorler ve kendi ustu yeni adi gosterir }
  KlasorYenidenAdlandir('Istanbul', 'Ist');
  Agac := KayitliKlasorAgaci;
  Kontrol('ic ice: yeniden adlandirma: alt klasorun ustu yeni ad', UstuNedir(Agac, 'Kadikoy') = 'Ist');
  Kontrol('ic ice: yeniden adlandirma: klasorun kendi ustu korunur', UstuNedir(Agac, 'Ist') = 'Musteriler');
  Kontrol('ic ice: eski ad artik yok', UstuNedir(Agac, 'Istanbul') = '<yok>');

  { Baglanti ic klasore girer; ortadaki klasor kalkinca ikisi de bir ust duzeye cikar }
  BaglantiKlasoruAyarla('A', 'Ist');
  KlasorKaldir('Ist');
  Agac := KayitliKlasorAgaci;
  Liste := KayitliBaglantilar;
  Kontrol('ic ice: kaldirinca alt klasor bir ust duzeye cikti', UstuNedir(Agac, 'Kadikoy') = 'Musteriler');
  Kontrol('ic ice: kaldirinca baglanti bir ust duzeye cikti (kok degil)', (Length(Liste) = 1) and (Liste[0].Klasor = 'Musteriler'));
  Kontrol('ic ice: kaldirilan klasor yok', UstuNedir(Agac, 'Ist') = '<yok>');
  KlasorKaldir('Musteriler');
  Liste := KayitliBaglantilar;
  Kontrol('ic ice: kok klasoru kaldirinca baglanti ve alt klasorler kok duzeye cikar',
    (Liste[0].Klasor = '') and (UstuNedir(KayitliKlasorAgaci, 'Kadikoy') = '') and (UstuNedir(KayitliKlasorAgaci, 'Ankara') = ''));

  { Eski dosya (KlasorUstleri yok): hepsi kokte kalir }
  TFile.WriteAllText(Dosya, '{"Klasorler": ["K1", "K2"], "Baglantilar": []}', TEncoding.UTF8);
  Agac := KayitliKlasorAgaci;
  Kontrol('ic ice: eski dosya: klasorler kokte', (Length(Agac) = 2) and (Agac[0].Ust = '') and (Agac[1].Ust = ''));

  { Elle bozulmus KlasorUstleri: dongu, olmayan klasor ve kendine bagli satirlar yok sayilir, klasor kaybolmaz }
  TFile.WriteAllText(Dosya,
    '{"Klasorler": ["A1", "B1", "C1", "D1"], "KlasorUstleri": {"A1": "B1", "B1": "A1", "C1": "Hayalet", "D1": "D1"}, "Baglantilar": []}',
    TEncoding.UTF8);
  Agac := KayitliKlasorAgaci;
  Kontrol('ic ice: bozuk dosya: 4 klasor de listede', Length(Agac) = 4);
  Kontrol('ic ice: bozuk dosya: olmayan ust ve kendine bagli kokte', (UstuNedir(Agac, 'C1') = '') and (UstuNedir(Agac, 'D1') = ''));
  Kontrol('ic ice: bozuk dosya: dongu kirildi (en az biri kokte)', (UstuNedir(Agac, 'A1') = '') or (UstuNedir(Agac, 'B1') = ''));
  Kontrol('ic ice: bozuk dosya uyari uretmedi', BozukDosyaUyarisiAl = '');
end;

var
  Liste: TArray<TBaglantiTanimi>;
  Bozuklar: TArray<string>;
  Ad: string;
  Ilk: Boolean;
begin
  Cikti := TStringList.Create;
  Hatalar := 0;
  try
    try
      { Uyari metni dil dosyasindan gelir: Diller klasoru exe'nin yaninda olmali }
      if not TDirectory.Exists(TPath.Combine(ExtractFilePath(ParamStr(0)), 'Diller')) then
        raise Exception.Create('Diller klasoru test exe''sinin yaninda yok. Uygulamanin Diller klasorunu exe''nin yanina kopyalayin.');
      Klasor := ParamStr(1);
      TDirectory.CreateDirectory(Klasor);
      VeriKlasoruAyarla(Klasor);
      DilYukle('tr');
      Dosya := TPath.Combine(Klasor, 'baglantilar.json');

      Liste := KayitliBaglantilar;
      Kontrol('dosya yokken liste bos', Length(Liste) = 0);
      Kontrol('dosya yokken uyari yok', BozukDosyaUyarisiAl = '');

      BaglantiKaydet(Tanim('A', 'gizli-sifre-123', True));
      BaglantiKaydet(Tanim('B', 'baska', False));
      Liste := KayitliBaglantilar;
      Kontrol('iki kayit okunur', Length(Liste) = 2);
      Kontrol('sifre DPAPI ile gidis-donus dogru', (Length(Liste) = 2) and (Liste[0].Sifre = 'gizli-sifre-123'));
      Kontrol('sifre saklanmayan kayitta bos', (Length(Liste) = 2) and (Liste[1].Sifre = ''));
      Kontrol('gecici .tmp dosyasi arkada kalmadi', not TFile.Exists(Dosya + '.tmp'));
      Kontrol('dosyada duz metin sifre yok', Pos('gizli-sifre-123', TFile.ReadAllText(Dosya)) = 0);

      BaglantiKaydet(Tanim('A', 'yeni-sifre', True));
      Liste := KayitliBaglantilar;
      Kontrol('ayni adli kayit guncellenir (2 kayit kalir)', Length(Liste) = 2);
      BaglantiListedenKaldir('B');
      Liste := KayitliBaglantilar;
      Kontrol('kaldirinca 1 kayit', Length(Liste) = 1);

      EskiBicimSenaryosu;
      KlasorSenaryosu;
      IcIceKlasorSenaryosu;

      BozukSenaryo('yarim yazilmis JSON', '{"Baglantilar": [ {"Ad": "A", ');
      BozukSenaryo('bos dosya', '');
      BozukSenaryo('JSON ama dizi', '[1,2,3]');
      BozukSenaryo('JSON nesne ama Baglantilar yok', '{"x": 1}');

      { bozuk dosyadan sonra kayit: yeni dosya olusur, bozuklar korunur }
      BaglantiKaydet(Tanim('C', '', False));
      Liste := KayitliBaglantilar;
      Bozuklar := BozukDosyalar;
      Kontrol('bozuktan sonra kayit yeni dosyaya yazilir', (Length(Liste) = 1) and (Liste[0].Ad = 'C'));
      Kontrol('onceki bozuk dosyalar hala duruyor (4 adet)', Length(Bozuklar) = 4);
      Ilk := False;
      for Ad in Bozuklar do
        if TFile.ReadAllText(Ad) = '{"Baglantilar": [ {"Ad": "A", ' then
          Ilk := True;
      Kontrol('bozuk dosyanin icerigi aynen korundu', Ilk);
    except
      on E: Exception do
      begin
        Cikti.Add('BEKLENMEYEN HATA: ' + E.ClassName + ': ' + E.Message);
        Inc(Hatalar);
      end;
    end;
    Cikti.Add('--- toplam hata: ' + IntToStr(Hatalar));
    Cikti.SaveToFile(ParamStr(2), TEncoding.UTF8);
  finally
    Cikti.Free;
  end;
end.
