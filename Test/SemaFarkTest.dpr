program SemaFarkTest;

{ Asama 4b: iki veritabaninin sema farki (uSemaFark) testi (komut satiri).
  GOMULU kipte kendi gecici veritabanlarini acar (yalniz kendi olusturdugu dosyalara yazar); kayitli baglanti dosyasi
  da gecici klasorde tutulur (VeriKlasoruAyarla), gercek baglantilar.json'a dokunulmaz.
  Cikis kodu: hata sayisi (0 = hepsi gecti). Sonuc FBTEST_CIKTI dosyasina yazilir. }

{$APPTYPE CONSOLE}

uses
  System.SysUtils, System.Classes, System.IOUtils, System.StrUtils,
  FireDAC.Stan.Intf, FireDAC.Stan.Option, FireDAC.Stan.Error, FireDAC.Comp.Client, FireDAC.Phys.FB,
  FireDAC.ConsoleUI.Wait, Vcl.Forms, Vcl.Controls,
  uDil, uBaglanti, uKullanici, uDDL, uSemaFark, fSemaFark;

var
  Cikti: TStringList;
  Hatalar, KontrolSayisi: Integer;
  Klasor: string;

procedure Kontrol(const Ad: string; Sonuc: Boolean);
begin
  Inc(KontrolSayisi);
  if Sonuc then
    Cikti.Add('OK    ' + Ad)
  else
  begin
    Cikti.Add('HATA  ' + Ad);
    Inc(Hatalar);
  end;
end;

function YeniTanim(const Ad: string): TBaglantiTanimi;
begin
  Result := Default(TBaglantiTanimi);
  Result.Ad := Ad;
  Result.Sunucu := '';
  Result.Port := 3050;
  Result.VeritabaniYolu := TPath.Combine(Klasor, Ad + '_' + FormatDateTime('hhnnsszzz', Now) + '.fdb');
  Result.Kullanici := 'SYSDBA';
  Result.Sifre := 'masterkey';
  Result.KarakterSeti := VARSAYILAN_KARAKTER_SETI;
  Result.SifreyiKaydet := True;
end;

procedure VeritabaniOlustur(const T: TBaglantiTanimi);
var
  Surucu: TFDPhysFBDriverLink;
  Baglanti: TFDConnection;
begin
  Surucu := TFDPhysFBDriverLink.Create(nil);
  Baglanti := TFDConnection.Create(nil);
  try
    Surucu.VendorLib := ExtractFilePath(ParamStr(0)) + 'istemci\fbclient.dll';
    Baglanti.DriverName := 'FB';
    Baglanti.LoginPrompt := False;
    Baglanti.Params.Values['Database'] := T.VeritabaniYolu;
    Baglanti.Params.Values['User_Name'] := T.Kullanici;
    Baglanti.Params.Values['Password'] := T.Sifre;
    Baglanti.Params.Values['OpenMode'] := 'Create';
    Baglanti.Params.Values['CharacterSet'] := T.KarakterSeti;
    Baglanti.Open;
    Baglanti.Close;
  finally
    Baglanti.Free;
    Surucu.Free;
  end;
end;

{ Kayitli baglanti olarak yazar, veritabanini olusturur ve komutlari calistirir (her komut ayri). }
procedure Hazirla(const T: TBaglantiTanimi; const Komutlar: array of string);
var
  Bag: TAcikBaglanti;
  Komut: string;
  Sorgu: TFDQuery;
begin
  VeritabaniOlustur(T);
  BaglantiKaydet(T);
  Bag := FbGeciciBaglan(T);
  try
    for Komut in Komutlar do
    begin
      Sorgu := KomutHazirla(Bag, Komut);
      try
        Sorgu.ExecSQL;
      finally
        Sorgu.Free;
      end;
    end;
  finally
    Bag.Free;
  end;
end;

function Bul(const Farklar: TArray<TFarkKaydi>; Tur: TNesneTuru; const Ad: string; out Kayit: TFarkKaydi): Boolean;
var
  F: TFarkKaydi;
begin
  Result := False;
  for F in Farklar do
    if (F.Tur = Tur) and (F.Ad = Ad) then
    begin
      Kayit := F;
      Exit(True);
    end;
end;

procedure SemaBolumu;
var
  TA, TB: TBaglantiTanimi;
  A, B: TAcikBaglanti;
  Farklar: TArray<TFarkKaydi>;
  F: TFarkKaydi;
  Hata: string;
  TurSayisi: Integer;
begin
  Cikti.Add('');
  Cikti.Add('=== B) Sema karsilastirma ===');
  TA := YeniTanim('sema_a');
  TB := YeniTanim('sema_b');
  Hazirla(TA, ['create table T1 (ID integer not null, AD varchar(20))',
    'create table SADECEA (X integer)',
    'create view V1 (ID) as select ID from T1',
    'create procedure P1 returns (R integer) as begin R = 1; suspend; end',
    'create domain D1 as integer default 0',
    'create generator G1', 'create exception E1 ''hata bir''']);
  Hazirla(TB, ['create table T1 (ID integer not null, AD varchar(30))',
    'create table SADECEB (Y integer)',
    'create view V1 (ID) as select ID from T1',
    'create procedure P1 returns (R integer) as begin R = 2; suspend; end',
    'create domain D1 as integer default 0',
    'create generator G1', 'create generator G2', 'set generator G1 to 500']);
  A := FbGeciciBaglan(TA);
  B := FbGeciciBaglan(TB);
  try
    { Ayni veritabani kendisiyle: fark yok }
    Farklar := SemaKarsilastir(A, A, nil);
    Kontrol('Ayni veritabani kendisiyle: fark yok', Length(Farklar) = 0);

    TurSayisi := 0;
    Farklar := SemaKarsilastir(A, B,
      procedure(Tur: TNesneTuru)
      begin
        Inc(TurSayisi);
      end);
    Kontrol('Ilerleme: yedi tur icin bildirim geldi', TurSayisi = 7);
    Kontrol('Tablo: yalniz kaynaktaki bulundu',
      Bul(Farklar, ntTablo, 'SADECEA', F) and (F.Durum = fdSadeceKaynakta));
    Kontrol('Tablo: yalniz kaynaktaki icin CREATE script var', Bul(Farklar, ntTablo, 'SADECEA', F) and ContainsText(F.Ayrinti, 'CREATE TABLE SADECEA'));
    Kontrol('Tablo: yalniz hedefteki bulundu',
      Bul(Farklar, ntTablo, 'SADECEB', F) and (F.Durum = fdSadeceHedefte));
    Kontrol('Tablo: kolon boyu farki bulundu',
      Bul(Farklar, ntTablo, 'T1', F) and (F.Durum = fdFarkli));
    Kontrol('Tablo: farkta eski ve yeni satir (- VARCHAR(20), + VARCHAR(30))',
      Bul(Farklar, ntTablo, 'T1', F) and ContainsText(F.Ayrinti, '- ') and ContainsText(F.Ayrinti, 'VARCHAR(20)') and
      ContainsText(F.Ayrinti, '+ ') and ContainsText(F.Ayrinti, 'VARCHAR(30)'));
    Kontrol('View: ayni, fark yok', not Bul(Farklar, ntView, 'V1', F));
    Kontrol('Prosedur: govde farki bulundu', Bul(Farklar, ntProsedur, 'P1', F) and (F.Durum = fdFarkli));
    Kontrol('Domain: ayni, fark yok', not Bul(Farklar, ntDomain, 'D1', F));
    Kontrol('Exception: yalniz kaynaktaki bulundu', Bul(Farklar, ntIstisna, 'E1', F) and (F.Durum = fdSadeceKaynakta));
    Kontrol('Generator: degeri farkli ama fark sayilmadi', not Bul(Farklar, ntGenerator, 'G1', F));
    Kontrol('Generator: yalniz hedefteki bulundu', Bul(Farklar, ntGenerator, 'G2', F) and (F.Durum = fdSadeceHedefte));
    Kontrol('Toplam: tam 6 fark (SADECEA, SADECEB, T1, P1, E1, G2)', Length(Farklar) = 6);

    { Ters yon: kaynak ile hedef yer degistirince durumlar da yer degistirir }
    Farklar := SemaKarsilastir(B, A, nil);
    Kontrol('Ters yon: SADECEA artik hedefte', Bul(Farklar, ntTablo, 'SADECEA', F) and (F.Durum = fdSadeceHedefte));
  finally
    A.Free;
    B.Free;
  end;

  { Baglanti adlariyla (kayitli sifreyle gecici baglanir) }
  Farklar := SemaKarsilastirAdlarla('sema_a', 'sema_b', nil);
  Kontrol('Adlarla karsilastirma ayni sonucu verir', Length(Farklar) = 6);
  Hata := '';
  try
    SemaKarsilastirAdlarla('sema_a', 'yok_boyle_baglanti', nil);
  except
    on E: Exception do
      Hata := E.Message;
  end;
  Kontrol('Kayitsiz baglanti adi anlasilir hata verir', ContainsText(Hata, 'yok_boyle_baglanti'));
end;

procedure DilBolumu;
const
  Anahtarlar: array[0..32] of string = ('FARK_TUR_TABLO', 'FARK_TUR_VIEW', 'FARK_TUR_PROSEDUR', 'FARK_TUR_TETIKLEYICI',
    'FARK_TUR_DOMAIN', 'FARK_TUR_ISTISNA', 'FARK_TUR_GENERATOR', 'FARK_DURUM_KAYNAKTA', 'FARK_DURUM_HEDEFTE',
    'FARK_DURUM_FARKLI', 'FARK_KAYNAK', 'FARK_HEDEF', 'BTN_KARSILASTIR', 'FARK_SUTUN_TUR', 'FARK_SUTUN_AD',
    'FARK_SUTUN_DURUM', 'FARK_IPUCU', 'FARK_YOK', 'FARK_OZET', 'FARK_ILERLEME', 'FARK_SECIM_YOK', 'FARK_AYNI',
    'FARK_SONUC_SATIRI', 'FARK_BASLIK_KAYNAKTA', 'FARK_BASLIK_HEDEFTE', 'FARK_BASLIK_FARKLI', 'FARK_SIRA',
    'FARK_BAGLANTI_YOK', 'BTN_SEMA_FARKI', 'FARK_SEKME', 'AYRINTI', 'BTN_TAMAM', 'BTN_KAPAT');
var
  Dil, Anahtar, Eksik: string;
begin
  Cikti.Add('');
  Cikti.Add('=== A) Arayuz ve dil anahtarlari ===');
  { Arayuz duman testi: sekmenin .dfm'i hatasiz yuklenir (gosterilmez) }
  with TSemaFarkSekme.Create(nil) do
    Free;
  Kontrol('Duman: sema farki sekmesi olusuyor (dfm hatasi yok)', True);
  for Dil in ['tr', 'en', 'de'] do
  begin
    DilYukle(Dil);
    Eksik := '';
    for Anahtar in Anahtarlar do
      if T(Anahtar) = Anahtar then
        Eksik := Eksik + ' ' + Anahtar;
    Kontrol('Dil ' + Dil + ': 4b anahtarlari tanimli', Eksik = '');
    if Eksik <> '' then
      Cikti.Add('      eksik:' + Eksik);
  end;
  DilYukle('tr');
end;

begin
  Cikti := TStringList.Create;
  try
    try
      DilYukle('tr');
      Klasor := TPath.Combine(GetEnvironmentVariable('TEMP'), 'semafarktest');
      ForceDirectories(Klasor);
      VeriKlasoruAyarla(TPath.Combine(Klasor, 'veri'));
      Cikti.Add('SemaFarkTest  ' + FormatDateTime('yyyy-mm-dd hh:nn:ss', Now));
      DilBolumu;
      SemaBolumu;
    except
      on E: Exception do
      begin
        Cikti.Add('');
        Cikti.Add('HATA (beklenmeyen): ' + E.ClassName + ': ' + E.Message);
        Inc(Hatalar);
      end;
    end;
    Cikti.Add('');
    Cikti.Add('Kontrol: ' + IntToStr(KontrolSayisi) + '  Hata: ' + IntToStr(Hatalar));
    Cikti.SaveToFile(GetEnvironmentVariable('FBTEST_CIKTI'), TEncoding.UTF8);
  finally
    Cikti.Free;
  end;
  ExitCode := Hatalar;
end.
