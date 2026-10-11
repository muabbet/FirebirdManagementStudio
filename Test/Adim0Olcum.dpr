program Adim0Olcum;

{ Asama 2b Adim 0 olcumleri (komut satiri). Bir veritabanina baglanir, sunlari olcer:
  1) fmOnDemand ile sonuc parca parca geliyor mu (RecordCount 500, 1000, ...)
  2) Kismen yuklenmis sonucta baslik siralamasi (IndexFieldNames) nasil davraniyor
  3) Acik sorgu varken baska sekmede insert/commit yapilinca acik sonuc bozuluyor mu
  Veritabaninda gecici bir tablo (OLCUM_T) olusturur ve sonunda DROP eder.

  Ortam degiskenleri: FBTEST_SUNUCU (bos = gomulu), FBTEST_PORT, FBTEST_YOL,
  FBTEST_KULLANICI, FBTEST_SIFRE, FBTEST_CIKTI }

{$APPTYPE CONSOLE}

uses
  System.SysUtils, System.Classes, System.Variants, Data.DB,
  FireDAC.Stan.Error, FireDAC.Comp.Client,
  uDil, uBaglanti, uSorgu;

function Ortam(const Ad, Varsayilan: string): string;
begin
  Result := GetEnvironmentVariable(Ad);
  if Result = '' then
    Result := Varsayilan;
end;

var
  Tanim: TBaglantiTanimi;
  Cikti: TStringList;
  Bag: TAcikBaglanti;
  S1, S2: TSorguSonucu;
  Say, Adim: Integer;
  Onceki: Integer;
begin
  Cikti := TStringList.Create;
  try
    try
      DilYukle('tr');
      Tanim.Ad := 'olcum';
      Tanim.Sunucu := Ortam('FBTEST_SUNUCU', '');
      Tanim.Port := StrToInt(Ortam('FBTEST_PORT', '3050'));
      Tanim.VeritabaniYolu := Ortam('FBTEST_YOL', '');
      Tanim.Kullanici := Ortam('FBTEST_KULLANICI', 'SYSDBA');
      Tanim.Sifre := Ortam('FBTEST_SIFRE', '');
      Tanim.KarakterSeti := VARSAYILAN_KARAKTER_SETI;
      Bag := FbBaglan(Tanim);
      Cikti.Add('Surum: ' + Bag.Surum);

      { Onceki yarim kalmis bir denemeden artik varsa temizle (yoksa hata onemsiz). }
      try SorguCalistir(Bag, 'DROP TABLE OLCUM_C').Free; except end;
      try SorguCalistir(Bag, 'DROP TABLE OLCUM_T').Free; except end;
      SorguCalistir(Bag, 'CREATE TABLE OLCUM_T (ID INTEGER NOT NULL PRIMARY KEY, YAZI VARCHAR(40))').Free;
      SorguCalistir(Bag,
        'EXECUTE BLOCK AS DECLARE I INTEGER = 1; BEGIN WHILE (I <= 2300) DO BEGIN ' +
        'INSERT INTO OLCUM_T VALUES (:I, ''satir '' || :I); I = I + 1; END END').Free;

      Cikti.Add('');
      Cikti.Add('--- 1) fmOnDemand: parca parca geliyor mu? (2300 satir var) ---');
      S1 := SorguCalistir(Bag, 'select * from OLCUM_T order by ID');
      Cikti.Add('Open sonrasi RecordCount = ' + IntToStr(S1.Sorgu.RecordCount));
      Onceki := S1.Sorgu.RecordCount;
      Adim := 0;
      while not S1.Sorgu.Eof do
      begin
        S1.Sorgu.Next;
        Inc(Adim);
        if S1.Sorgu.RecordCount <> Onceki then
        begin
          Cikti.Add(Format('Satir %d ilerlenince RecordCount %d -> %d', [Adim, Onceki, S1.Sorgu.RecordCount]));
          Onceki := S1.Sorgu.RecordCount;
        end;
      end;
      Cikti.Add('Sonunda RecordCount = ' + IntToStr(S1.Sorgu.RecordCount));
      S1.Free;

      Cikti.Add('');
      Cikti.Add('--- 2) Kismen yuklenmis sonucta siralama ---');
      S1 := SorguCalistir(Bag, 'select * from OLCUM_T order by ID');
      Cikti.Add('Once: RecordCount = ' + IntToStr(S1.Sorgu.RecordCount) + ', ilk ID = ' + S1.Sorgu.FieldByName('ID').AsString);
      S1.Sorgu.IndexFieldNames := 'ID:D';
      S1.Sorgu.First;
      Cikti.Add('IndexFieldNames=ID:D sonrasi: RecordCount = ' + IntToStr(S1.Sorgu.RecordCount) +
        ', ilk ID = ' + S1.Sorgu.FieldByName('ID').AsString);
      S1.Sorgu.Last;
      Cikti.Add('Son satira gidince: RecordCount = ' + IntToStr(S1.Sorgu.RecordCount) +
        ', son ID = ' + S1.Sorgu.FieldByName('ID').AsString);
      S1.Sorgu.IndexFieldNames := '';
      S1.Sorgu.First;
      Cikti.Add('Siralama kalkinca: ilk ID = ' + S1.Sorgu.FieldByName('ID').AsString);
      S1.Free;

      Cikti.Add('');
      Cikti.Add('--- 3) Acik sorgu varken baska sekmede insert ---');
      S1 := SorguCalistir(Bag, 'select * from OLCUM_T order by ID');
      Cikti.Add('Sekme 1 acik: RecordCount = ' + IntToStr(S1.Sorgu.RecordCount));
      Cikti.Add('Sunucuda acik islem sayisi (bu baglanti, kendi islemi haric): ' +
        VarToStr(Bag.Baglanti.ExecSQLScalar(
          'SELECT COUNT(*) FROM MON$TRANSACTIONS WHERE MON$ATTACHMENT_ID = CURRENT_CONNECTION AND MON$TRANSACTION_ID <> CURRENT_TRANSACTION')));
      S2 := SorguCalistir(Bag, 'insert into OLCUM_T values (9999, ''yeni'')');
      Cikti.Add('Sekme 2 insert: Etkilenen = ' + IntToStr(S2.Etkilenen));
      S2.Free;
      Cikti.Add('Sekme 1 hala acik mi: ' + BoolToStr(S1.Sorgu.Active, True) +
        ', RecordCount = ' + IntToStr(S1.Sorgu.RecordCount));
      S1.Sorgu.Last;
      Cikti.Add('Sekme 1 sona gidince RecordCount = ' + IntToStr(S1.Sorgu.RecordCount) +
        ' (2300 = eski goruntu, 2301 = yeni satir da gorundu)');
      S1.Free;
      Say := Bag.Baglanti.ExecSQLScalar('select count(*) from OLCUM_T');
      Cikti.Add('Yeni sorguda count(*) = ' + IntToStr(Say) + ' (insert kalici oldu mu)');

      Cikti.Add('');
      Cikti.Add('--- 5) Sorgu plani (calistirmadan) ---');
      Cikti.Add('select: ' + SorguPlaniAl(Bag, 'select * from OLCUM_T where ID = 5'));
      Say := Bag.Baglanti.ExecSQLScalar('select count(*) from OLCUM_T');
      Cikti.Add('insert: ' + SorguPlaniAl(Bag, 'insert into OLCUM_T values (7777, ''plan'')'));
      Cikti.Add('update: ' + SorguPlaniAl(Bag, 'update OLCUM_T set YAZI = ''x'' where ID = 5'));
      Cikti.Add('delete: ' + SorguPlaniAl(Bag, 'delete from OLCUM_T'));
      Cikti.Add('satir sayisi plan oncesi/sonrasi: ' + IntToStr(Say) + ' / ' +
        VarToStr(Bag.Baglanti.ExecSQLScalar('select count(*) from OLCUM_T')));
      Cikti.Add('ID=5 yazisi: ' + VarToStr(Bag.Baglanti.ExecSQLScalar('select YAZI from OLCUM_T where ID = 5')));
      Cikti.Add('DDL plani: [' + SorguPlaniAl(Bag, 'create table OLCUM_X (A integer)') + ']');
      try
        SorguPlaniAl(Bag, 'select * from OLCUM_YOK');
      except
        on E: Exception do
          Cikti.Add('hatali sql: ' + HataMetniniCevir(E));
      end;
      Cikti.Add('');
      Cikti.Add('--- 4) Hata cumleleri ---');
      SorguCalistir(Bag, 'CREATE TABLE OLCUM_C (ID INTEGER NOT NULL PRIMARY KEY, OLCUM_ID INTEGER REFERENCES OLCUM_T(ID))').Free;
      for Adim := 0 to 3 do
      begin
        try
          case Adim of
            0: SorguCalistir(Bag, 'insert into OLCUM_T values (1, ''tekrar'')').Free;
            1: SorguCalistir(Bag, 'insert into OLCUM_C values (1, 424242)').Free;
            2: SorguCalistir(Bag, 'select * from OLCUM_YOK').Free;
            3: SorguCalistir(Bag, 'selec 1 from rdb$database').Free;
          end;
          Cikti.Add(IntToStr(Adim) + ': hata beklenirdi, olmadi');
        except
          on E: Exception do
          begin
            Cikti.Add(IntToStr(Adim) + ': ' + HataMetniniCevir(E));
            Cikti.Add('     ham: ' + StringReplace(E.Message, #13#10, ' | ', [rfReplaceAll]));
            if E is EFDDBEngineException then
              for Say := 0 to EFDDBEngineException(E).ErrorCount - 1 do
                Cikti.Add('     kod=' + IntToStr(EFDDBEngineException(E).Errors[Say].ErrorCode) +
                  ' tur=' + IntToStr(Ord(EFDDBEngineException(E).Errors[Say].Kind)));
          end;
        end;
      end;
      SorguCalistir(Bag, 'DROP TABLE OLCUM_C').Free;
      SorguCalistir(Bag, 'DROP TABLE OLCUM_T').Free;
      Cikti.Add('');
      Cikti.Add('OLCUM_T silindi.');
    except
      on E: Exception do
      begin
        Cikti.Add('HATA (ham): ' + E.ClassName + ': ' + E.Message);
        Cikti.Add('HATA (anlasilir): ' + HataMetniniCevir(E));
      end;
    end;
    Cikti.SaveToFile(Ortam('FBTEST_CIKTI', 'cikti.txt'), TEncoding.UTF8);
  finally
    Cikti.Free;
  end;
end.
