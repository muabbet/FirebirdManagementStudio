program AktifBaglantiTest;

{ Asama 7c: uAktifBaglanti (aktif baglantilar ve baglanti koparma) testi (komut satiri).
  Gecici bir veritabani acilir ve ona ikinci bir baglanti kurulur; gercek veriye dokunulmaz.
  Ortam degiskenleri: FBTEST_SUNUCU (bos = yerel), FBTEST_PORT, FBTEST_KLASOR, FBTEST_KULLANICI, FBTEST_SIFRE, FBTEST_CIKTI.
  Cikis kodu: hata sayisi (0 = hepsi gecti). }

{$APPTYPE CONSOLE}

uses
  System.SysUtils, System.Classes, System.StrUtils, System.IOUtils, Data.DB,
  FireDAC.Stan.Intf, FireDAC.Stan.Option, FireDAC.Stan.Error, FireDAC.Comp.Client, FireDAC.Phys.FB,
  FireDAC.ConsoleUI.Wait,
  uDil, uBaglanti, uSorgu, uProsedur, uAktifBaglanti;

var
  Cikti: TStringList;
  Hatalar, KontrolSayisi: Integer;

function Ortam(const Ad, Varsayilan: string): string;
begin
  Result := GetEnvironmentVariable(Ad);
  if Result = '' then
    Result := Varsayilan;
end;

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

function TanimYap(const Ad, Yol: string): TBaglantiTanimi;
begin
  Result := Default(TBaglantiTanimi);
  Result.Ad := Ad;
  Result.Sunucu := Ortam('FBTEST_SUNUCU', '');
  Result.Port := StrToInt(Ortam('FBTEST_PORT', '3050'));
  Result.VeritabaniYolu := Yol;
  Result.Kullanici := Ortam('FBTEST_KULLANICI', 'SYSDBA');
  Result.Sifre := Ortam('FBTEST_SIFRE', '');
  Result.KarakterSeti := VARSAYILAN_KARAKTER_SETI;
end;

{ Listedeki satir sayisi ve verilen numarali satirin alani. }
function Satirlar(Sorgu: TFDQuery): Integer;
begin
  Result := 0;
  Sorgu.First;
  while not Sorgu.Eof do
  begin
    Inc(Result);
    Sorgu.Next;
  end;
end;

function SatirBul(Sorgu: TFDQuery; Numara: Int64): Boolean;
begin
  Result := Sorgu.Locate('ID', Numara, []);
end;

var
  Tanim1, Tanim2: TBaglantiTanimi;
  Klasor, Yol: string;
  Gomulu: Boolean;
  A, B: TAcikBaglanti;
  Sorgu: TFDQuery;
  Sonuc: TProsedurSonucu;
  ANo, BNo: Int64;
  Dil, Anahtar, Eksik: string;
const
  Anahtarlar: array[0..30] of string = ('BTN_AKTIF_BAGLANTI', 'AKTIF_BASLIK', 'AKTIF_BILGI', 'AKTIF_BILGI_YETKI', 'AKTIF_YENILE',
    'AKTIF_KOPAR', 'AKTIF_KOL_ID', 'AKTIF_KOL_KULLANICI', 'AKTIF_KOL_PROGRAM', 'AKTIF_KOL_ADRES', 'AKTIF_KOL_BAGLANMA',
    'AKTIF_KOL_DURUM', 'AKTIF_KOL_ISLEM', 'AKTIF_KOL_ESKI', 'AKTIF_KOL_SORGU', 'AKTIF_KOL_BEN', 'AKTIF_DURUM_CALISIYOR',
    'AKTIF_DURUM_BOSTA', 'AKTIF_BEN_EVET', 'AKTIF_ONAY_KOPAR', 'MSG_AKTIF_KOPARILDI', 'ERR_AKTIF_KOPARILAMADI',
    'ERR_AKTIF_KENDI', 'ERR_AKTIF_SECIM', 'ERR_AKTIF_LISTE', 'AKTIF_KOL_ID', 'AKTIF_KOL_ID', 'AKTIF_KOL_ID', 'AKTIF_KOL_ID',
    'AKTIF_KOL_ID', 'AKTIF_KOL_ID');
begin
  Cikti := TStringList.Create;
  A := nil;
  B := nil;
  try
    try
      DilYukle('tr');
      Gomulu := Ortam('FBTEST_SUNUCU', '') = '';
      Klasor := Ortam('FBTEST_KLASOR', TPath.Combine(GetEnvironmentVariable('TEMP'), 'aktiftest'));
      if Gomulu then
        ForceDirectories(Klasor);
      Yol := IncludeTrailingPathDelimiter(Klasor) + 'aktif_' + FormatDateTime('yyyymmdd_hhnnss', Now) + '.fdb';
      Tanim1 := TanimYap('aktif_a', Yol);
      Tanim2 := TanimYap('aktif_b', Yol);
      FbVeritabaniOlustur(Tanim1);
      A := FbBaglan(Tanim1);
      B := FbBaglan(Tanim2);
      Cikti.Add('--- Surum ' + A.Surum + ' ---');
      ANo := BenimBaglantiNo(A);
      BNo := BenimBaglantiNo(B);
      Kontrol('iki baglantinin numarasi farkli ve gecerli', (ANo > 0) and (BNo > 0) and (ANo <> BNo));

      Cikti.Add('--- Liste ---');
      Sorgu := AktifBaglantiSorgusu(A, nil);
      try
        Kontrol('liste en az iki baglanti gosteriyor', Satirlar(Sorgu) >= 2);
        Kontrol('kendi baglantimiz listede', SatirBul(Sorgu, ANo));
        Kontrol('kendi baglantimiz BEN = 1', Sorgu.FieldByName('BEN').AsInteger = 1);
        Kontrol('kullanici yazili', Trim(Sorgu.FieldByName('KULLANICI').AsString) <> '');
        Kontrol('baglanma zamani var', not Sorgu.FieldByName('BAGLANMA').IsNull);
        Kontrol('diger baglanti listede, BEN = 0', SatirBul(Sorgu, BNo) and (Sorgu.FieldByName('BEN').AsInteger = 0));
        SatirBul(Sorgu, ANo);
        Cikti.Add('      kendi satirimiz: kullanici=' + Sorgu.FieldByName('KULLANICI').AsString + ', program=' +
          Sorgu.FieldByName('PROGRAM').AsString + ', islem=' + Sorgu.FieldByName('ISLEM_SAYISI').AsString + ', durum=' +
          Sorgu.FieldByName('CALISIYOR').AsString);
        Kontrol('listeyi okurken bu sorgu kendi satirinda calisiyor gorunur (CALISIYOR = 1)', Sorgu.FieldByName('CALISIYOR').AsInteger = 1);
      finally
        Sorgu.Free;
      end;

      Cikti.Add('--- Koparma ---');
      Sonuc := BaglantiKopar(A, ANo);
      Kontrol('kendi baglantimizi koparma reddedilir', (not Sonuc.Basarili) and (Sonuc.Cumle <> ''));
      Sonuc := BaglantiKopar(A, BNo);
      if not Sonuc.Basarili then
        Cikti.Add('      ' + Sonuc.Cumle + ' | ' + Sonuc.Ayrinti);
      Kontrol('diger baglanti koparildi', Sonuc.Basarili);
      Kontrol('calisan komut kaydedildi (DELETE FROM MON$ATTACHMENTS)', (Length(Sonuc.Komutlar) = 1) and (Pos('MON$ATTACHMENTS', Sonuc.Komutlar[0]) > 0));
      Sorgu := AktifBaglantiSorgusu(A, nil);
      try
        Kontrol('koparilan baglanti listeden gitti', not SatirBul(Sorgu, BNo));
        Kontrol('kendi baglantimiz duruyor', SatirBul(Sorgu, ANo));
      finally
        Sorgu.Free;
      end;
      Sonuc := Default(TProsedurSonucu);
      try
        SorguCalistir(B, 'select 1 from rdb$database').Free;
        Kontrol('koparilan baglanti artik sorgu calistiramaz', False);
      except
        on E: Exception do
          Kontrol('koparilan baglanti artik sorgu calistiramaz (hata: ' + Copy(E.ClassName, 1, 30) + ')', True);
      end;

      Cikti.Add('--- Dil anahtarlari ---');
      for Dil in ['tr', 'en', 'de'] do
      begin
        DilYukle(Dil);
        Eksik := '';
        for Anahtar in Anahtarlar do
          if T(Anahtar) = Anahtar then
            Eksik := Eksik + ' ' + Anahtar;
        Kontrol('dil ' + Dil + ': 7c anahtarlari tam' + IfThen(Eksik <> '', ' (eksik:' + Eksik + ')'), Eksik = '');
        Kontrol('dil ' + Dil + ': onay ve mesaj bicimi gecerli',
          (Pos('KULL', TF('AKTIF_ONAY_KOPAR', [7, 'KULL', 'PRG', 'ADR', 'DELETE'])) > 0) and
          (Pos('PRG', TF('MSG_AKTIF_KOPARILDI', [7, 'KULL', 'PRG'])) > 0) and (Pos('7', TF('AKTIF_BILGI', [7])) > 0));
      end;
      DilYukle('tr');

      try
        FbBaglantiyiKes(B);
      except
        { Zaten koparilmis baglantinin kapatilmasi hata verebilir; onemsiz. }
      end;
      FbBaglantiyiKes(A);
      A := nil;
      B := nil;
      if Gomulu then
      begin
        ForceDirectories(TPath.Combine(Klasor, '_arsiv'));
        TFile.Move(Yol, TPath.Combine(TPath.Combine(Klasor, '_arsiv'), ExtractFileName(Yol)));
      end;
    except
      on E: Exception do
      begin
        Cikti.Add('HATA  beklenmeyen istisna: ' + E.ClassName + ': ' + E.Message);
        Inc(Hatalar);
      end;
    end;
    Cikti.Add('');
    Cikti.Add('Kontrol sayisi: ' + IntToStr(KontrolSayisi) + ', Hata sayisi: ' + IntToStr(Hatalar));
    if Ortam('FBTEST_CIKTI', '') <> '' then
      Cikti.SaveToFile(Ortam('FBTEST_CIKTI', ''), TEncoding.UTF8);
    Writeln(Cikti.Text);
  finally
    Cikti.Free;
  end;
  ExitCode := Hatalar;
end.
