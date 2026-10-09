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
      FbBaglan(Tanim);
      Cikti.Add('Baglandi. Surum: ' + FbSurum);
      TablolariGetir(Liste);
      Listele(Cikti, 'Tablolar', Liste);
      Tablo := Ortam('FBTEST_TABLO', '');
      if (Tablo = '') and (Liste.Count > 0) then
        Tablo := Liste[0];
      ViewlariGetir(Liste);
      Listele(Cikti, 'View', Liste);
      ProsedurleriGetir(Liste);
      Listele(Cikti, 'Prosedur', Liste);
      GeneratorleriGetir(Liste);
      Listele(Cikti, 'Generator', Liste);
      if Tablo <> '' then
      begin
        Cikti.Add('--- Kolonlar: ' + Tablo);
        Kolonlar := KolonTablosuOlustur(Tablo, nil);
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
        Basit.Connection := FbBaglantisi;
        Basit.SQL.Text := 'SELECT FIRST 100 * FROM "' + Tablo + '"';
        Basit.Open;
        Cikti.Add('[varsayilan ayarli sorgu] FbIslemAcikMi = ' + BoolToStr(FbIslemAcikMi, True) + ', sunucuda acik islem = ' +
          VarToStr(FbBaglantisi.ExecSQLScalar('SELECT COUNT(*) FROM MON$TRANSACTIONS WHERE MON$ATTACHMENT_ID = CURRENT_CONNECTION AND MON$TRANSACTION_ID <> CURRENT_TRANSACTION')));
        Basit.Close;
        Basit.Free;
        Veri := TabloVerisiSorgusu(Tablo, 5, nil);
        Cikti.Add('Sorgu acik, FbIslemAcikMi = ' + BoolToStr(FbIslemAcikMi, True) + ', sunucuda acik islem sayisi = ' +
          VarToStr(FbBaglantisi.ExecSQLScalar('SELECT COUNT(*) FROM MON$TRANSACTIONS WHERE MON$ATTACHMENT_ID = CURRENT_CONNECTION AND MON$TRANSACTION_ID <> CURRENT_TRANSACTION')));
        while not Veri.Eof do
        begin
          Satir := '';
          for i := 0 to Veri.FieldCount - 1 do
            Satir := Satir + Veri.Fields[i].AsString + ' | ';
          Cikti.Add('  ' + Satir);
          Veri.Next;
        end;
      end;
      FbBaglantiyiKes;
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
