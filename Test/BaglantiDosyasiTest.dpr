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
