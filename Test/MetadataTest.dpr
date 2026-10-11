program MetadataTest;

{ Komut satiri denemesi: bir veritabanina baglanir, surumu, agac listelerini,
  bir tablonun kolonlarini ve ilk satirlarini UTF-8 bir dosyaya yazar.
  Program arayuzunu acmadan uBaglanti / uMetadata / uSorgu'yu dener.

  Sifre HICBIR dosyaya yazilmaz, ortam degiskeninden okunur:
    FBTEST_SUNUCU (bos birakilirsa yerel/embedded), FBTEST_PORT, FBTEST_YOL,
    FBTEST_KULLANICI, FBTEST_SIFRE, FBTEST_KARAKTER, FBTEST_CIKTI, FBTEST_TABLO }

{$APPTYPE CONSOLE}

uses
  System.SysUtils, System.Classes, System.IOUtils, System.Variants, Data.DB,
  FireDAC.Stan.Error, FireDAC.Comp.Client,
  uDil, uBaglanti, uMetadata, uSorgu;

function Ortam(const Ad, Varsayilan: string): string;
begin
  Result := GetEnvironmentVariable(Ad);
  if Result = '' then
    Result := Varsayilan;
end;

procedure Listele(Cikti: TStrings; const Baslik: string; Liste: TStrings);
var
  Ad: string;
begin
  Cikti.Add(Baslik + ' (' + IntToStr(Liste.Count) + ')');
  for Ad in Liste do
    Cikti.Add('  ' + Ad);
end;

var
  Tanim: TBaglantiTanimi;
  Cikti, Liste: TStringList;
  Tablo: string;
  Kolonlar: TDataSet;
  Veri: TDataSet;
  i: Integer;
  Satir: string;
  Basit: TFDQuery;
  Bag, Bag2: TAcikBaglanti;
  Tanim2: TBaglantiTanimi;
begin
  Cikti := TStringList.Create;
  Liste := TStringList.Create;
  try
    try
      DilYukle('tr');
      Tanim.Ad := 'test';
      Tanim.Sunucu := Ortam('FBTEST_SUNUCU', '');
      Tanim.Port := StrToInt(Ortam('FBTEST_PORT', '3050'));
      Tanim.VeritabaniYolu := Ortam('FBTEST_YOL', '');
      Tanim.Kullanici := Ortam('FBTEST_KULLANICI', 'SYSDBA');
      Tanim.Sifre := Ortam('FBTEST_SIFRE', '');
      Tanim.KarakterSeti := Ortam('FBTEST_KARAKTER', VARSAYILAN_KARAKTER_SETI);
      Bag := FbBaglan(Tanim);
      Cikti.Add('Baglandi. Surum: ' + Bag.Surum);
      TablolariGetir(Bag, Liste);
      Listele(Cikti, 'Tablolar', Liste);
      Tablo := Ortam('FBTEST_TABLO', '');
      if (Tablo = '') and (Liste.Count > 0) then
        Tablo := Liste[0];
      ViewlariGetir(Bag, Liste);
      Listele(Cikti, 'View', Liste);
      ProsedurleriGetir(Bag, Liste);
      Listele(Cikti, 'Prosedur', Liste);
      GeneratorleriGetir(Bag, Liste);
      Listele(Cikti, 'Generator', Liste);
      if Tablo <> '' then
      begin
        Cikti.Add('--- Kolonlar: ' + Tablo);
        Kolonlar := KolonTablosuOlustur(Bag, Tablo, nil);
        while not Kolonlar.Eof do
        begin
          Cikti.Add('  ' + Kolonlar.FieldByName('AD').AsString + ' | ' +
            Kolonlar.FieldByName('TIP').AsString + ' | ' +
            Kolonlar.FieldByName('BOS_OLUR').AsString);
          Kolonlar.Next;
        end;
        Cikti.Add('--- Ilk satirlar: ' + Tablo);
        { Karsilastirma: varsayilan getirme ayarlariyla acilan sorgu }
        Basit := TFDQuery.Create(nil);
        Basit.Connection := Bag.Baglanti;
        Basit.SQL.Text := 'SELECT FIRST 100 * FROM "' + Tablo + '"';
        Basit.Open;
        Cikti.Add('[varsayilan ayarli sorgu] FbIslemAcikMi(Bag) = ' + BoolToStr(FbIslemAcikMi(Bag), True) + ', sunucuda acik islem = ' +
          VarToStr(Bag.Baglanti.ExecSQLScalar('SELECT COUNT(*) FROM MON$TRANSACTIONS WHERE MON$ATTACHMENT_ID = CURRENT_CONNECTION AND MON$TRANSACTION_ID <> CURRENT_TRANSACTION')));
        Basit.Close;
        Basit.Free;
        Veri := TabloVerisiSorgusu(Bag, Tablo, 5, nil);
        Cikti.Add('Sorgu acik, FbIslemAcikMi(Bag) = ' + BoolToStr(FbIslemAcikMi(Bag), True) + ', sunucuda acik islem sayisi = ' +
          VarToStr(Bag.Baglanti.ExecSQLScalar('SELECT COUNT(*) FROM MON$TRANSACTIONS WHERE MON$ATTACHMENT_ID = CURRENT_CONNECTION AND MON$TRANSACTION_ID <> CURRENT_TRANSACTION')));
        while not Veri.Eof do
        begin
          Satir := '';
          for i := 0 to Veri.FieldCount - 1 do
            Satir := Satir + Veri.Fields[i].AsString + ' | ';
          Cikti.Add('  ' + Satir);
          Veri.Next;
        end;
      end;
      { Yanlis sifre (sunucu varsa; gomulu kipte sifre kontrol edilmez): acik baglanti listesine girmemeli. }
      if Tanim.Sunucu <> '' then
      begin
        Tanim2 := Tanim;
        Tanim2.Ad := 'yanlis-sifre';
        Tanim2.Sifre := 'kesinlikle-yanlis-sifre';
        try
          FbBaglan(Tanim2);
          Cikti.Add('YANLIS SIFRE: hata beklenirdi ama baglandi');
        except
          on E: Exception do
            Cikti.Add('Yanlis sifre: anlasilir mesaj = ' + HataMetniniCevir(E) + ', listede yok = ' +
              BoolToStr(FbAcikBaglanti('yanlis-sifre') = nil, True));
        end;
      end;
      { Ikinci veritabani verilmisse: iki baglanti ayni anda acik kalabilmeli. }
      if Ortam('FBTEST_YOL2', '') <> '' then
      begin
        Tanim2 := Tanim;
        Tanim2.Ad := 'test2';
        Tanim2.VeritabaniYolu := Ortam('FBTEST_YOL2', '');
        Tanim2.Sifre := Ortam('FBTEST_SIFRE2', Tanim.Sifre);
        Bag2 := FbBaglan(Tanim2);
        Cikti.Add('Ikinci baglanti: ' + Bag2.Tanim.Ad + ' Surum: ' + Bag2.Surum);
        Cikti.Add('Iki baglanti ayni anda acik: ' + BoolToStr(
          (FbAcikBaglanti('test') = Bag) and (FbAcikBaglanti('test2') = Bag2) and
          Bag.Baglanti.Connected and Bag2.Baglanti.Connected, True));
        Cikti.Add('Ayni adla tekrar baglanma ayni nesneyi verir: ' +
          BoolToStr(FbBaglan(Tanim2) = Bag2, True));
        TablolariGetir(Bag2, Liste);
        Listele(Cikti, 'Ikinci baglanti tablolari', Liste);
        FbBaglantiyiKes(Bag);
        Cikti.Add('Birincisi kesildi, ikincisi hala acik: ' + BoolToStr(
          (FbAcikBaglanti('test') = nil) and (FbAcikBaglanti('test2') = Bag2) and
          Bag2.Baglanti.Connected, True));
        TablolariGetir(Bag2, Liste);
        Cikti.Add('Ikincisi birincisi kesildikten sonra calisiyor, tablo sayisi: ' + IntToStr(Liste.Count));
        FbBaglantiyiKes(Bag2);
      end
      else
        FbBaglantiyiKes(Bag);
    except
      on E: Exception do
      begin
        Cikti.Add('HATA (ham): ' + E.ClassName + ': ' + E.Message);
        if E is EFDDBEngineException then
          for i := 0 to EFDDBEngineException(E).ErrorCount - 1 do
            Cikti.Add('  hata kodu: ' + IntToStr(EFDDBEngineException(E).Errors[i].ErrorCode));
        Cikti.Add('HATA (anlasilir): ' + HataMetniniCevir(E));
      end;
    end;
    Cikti.SaveToFile(Ortam('FBTEST_CIKTI', 'cikti.txt'), TEncoding.UTF8);
  finally
    Liste.Free;
    Cikti.Free;
  end;
end.
