program SorguGecmisiTest;

{ Asama 7e: uSorguGecmisi testi (komut satiri, veritabani gerekmez). Gecici bir dosyada calisir.
  Ortam: FBTEST_CIKTI (sonuc dosyasi, bos ise ekrana). Cikis kodu: hata sayisi. }

{$APPTYPE CONSOLE}

uses
  System.SysUtils, System.Classes, System.IOUtils,
  uSorguGecmisi;

var
  Cikti: TStringList;
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

var
  Klasor, Yol, CiktiYolu: string;
  Gecmis: TArray<TGecmisKaydi>;
  Sik: TArray<TSikSorgu>;
  Yedekler: TArray<string>;
begin
  Cikti := TStringList.Create;
  Hatalar := 0;
  Klasor := TPath.Combine(TPath.GetTempPath, 'gecmistest_' + FormatDateTime('hhnnsszzz', Now));
  ForceDirectories(Klasor);
  Yol := TPath.Combine(Klasor, 'sorgu_gecmisi.json');
  GecmisDosyasiOzel := Yol;
  try
    Kontrol('Bos dosya: gecmis bos', Length(GecmisiOku) = 0);
    Kontrol('Bos dosya: sik bos', Length(SikSorgulariOku) = 0);

    GecmiseEkle('Baglanti A', 'select * from musteri');
    GecmiseEkle('Baglanti A', 'select * from musteri');  { ayni metin arka arkaya: eklenmez }
    GecmiseEkle('Baglanti B', 'select 1 from rdb$database' + sLineBreak + 'where 1 = 1');
    GecmiseEkle('Baglanti B', '   ');  { bos: eklenmez }
    GecmiseEkle('Baglanti B', 'CREATE USER x PASSWORD ''gizli''');  { sifre: eklenmez }
    GecmiseEkle('Baglanti B', 'alter user x set password ''gizli''');  { kucuk harf: eklenmez }
    Gecmis := GecmisiOku;
    Kontrol('2 kayit (tekrar, bos, sifre atlandi)', Length(Gecmis) = 2);
    Kontrol('En yeni basta', (Length(Gecmis) = 2) and (Gecmis[0].Baglanti = 'Baglanti B') and (Gecmis[1].Baglanti = 'Baglanti A'));
    Kontrol('Cok satirli SQL korunur', (Length(Gecmis) = 2) and (Pos(sLineBreak, Gecmis[0].Sql) > 0));
    Kontrol('Zaman yazili', (Length(Gecmis) = 2) and (Length(Gecmis[0].Zaman) = 19));
    Kontrol('Sifre dosyada yok', Pos('gizli', TFile.ReadAllText(Yol, TEncoding.UTF8)) = 0);

    SikSorguEkle('Musteriler', 'select * from musteri');
    SikSorguEkle('Bir', 'select 1 from rdb$database');
    SikSorguEkle('Bos', '  ');
    Sik := SikSorgulariOku;
    Kontrol('2 sik sorgu (bos atlandi)', Length(Sik) = 2);
    Kontrol('Sik sorgu adi ve SQL', (Length(Sik) = 2) and (Sik[0].Ad = 'Musteriler') and (Sik[1].Sql = 'select 1 from rdb$database'));

    SikSorguSil(0);
    Sik := SikSorgulariOku;
    Kontrol('Sik sorgu silindi, digeri kaldi', (Length(Sik) = 1) and (Sik[0].Ad = 'Bir'));
    SikSorguSil(5);
    Kontrol('Gecersiz sira zarar vermez', Length(SikSorgulariOku) = 1);

    GecmisiTemizle;
    Kontrol('Temizleyince gecmis bos', Length(GecmisiOku) = 0);
    Kontrol('Temizleyince sik sorgu korunur', Length(SikSorgulariOku) = 1);
    Yedekler := TDirectory.GetFiles(Klasor, 'sorgu_gecmisi-temizlenen-*.json');
    Kontrol('Eski gecmis yan dosyaya tasindi (silinmedi)', (Length(Yedekler) = 1) and (Pos('select * from musteri', TFile.ReadAllText(Yedekler[0], TEncoding.UTF8)) > 0));

    { Bozuk dosya: silinmez, yanina tasinir; yeni kayit yine yazilir. }
    TFile.WriteAllText(Yol, '{ bozuk', TEncoding.UTF8);
    GecmiseEkle('Baglanti A', 'select 2 from rdb$database');
    Kontrol('Bozuk dosya sonrasi kayit yazildi', Length(GecmisiOku) = 1);
    Kontrol('Bozuk dosya yanina tasindi', Length(TDirectory.GetFiles(Klasor, '*.bozuk-*')) = 1);
  except
    on E: Exception do
    begin
      Cikti.Add('ISTISNA ' + E.ClassName + ': ' + E.Message);
      Inc(Hatalar);
    end;
  end;
  Cikti.Add(Format('Toplam hata: %d', [Hatalar]));
  CiktiYolu := GetEnvironmentVariable('FBTEST_CIKTI');
  if CiktiYolu <> '' then
    Cikti.SaveToFile(CiktiYolu, TEncoding.UTF8)
  else
    Writeln(Cikti.Text);
  Cikti.Free;
  ExitCode := Hatalar;
end.
