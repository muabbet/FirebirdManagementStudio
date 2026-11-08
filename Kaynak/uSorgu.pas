{ uSorgu.pas - SQL calistirma.

  Tablo sekmesi: bir tablonun ilk satirlarini getirir (salt okunur).
  Sorgu sekmesi: yazilan komutu (birden fazlaysa sirayla, bkz. BetikCalistir) calistirir. SELECT ise sonuc
  SATIR_PARCASI'ser satir cekilir, kullanici asagi indikce devami gelir (FireDAC
  fmOnDemand). Komut baska bir sey ise (INSERT, UPDATE, DDL ...) etkilenen satir
  sayisi doner.

  Islem davranisi aciktir: her sorgu sekmesinin kendi islemi vardir ve
  OTOMATIK ONAY (autocommit) kullanilir; komut bitince commit olur. Boylece
  bir sekmede acik kalan sonuc, baska sekmenin komutundan etkilenmez.
  Tehlikeli komutlar (DROP, WHERE'siz DELETE/UPDATE) icin TehlikeliSorguUyarisi
  ile onay anahtari alinir; onayi isteyen yer arayuzdur. }
unit uSorgu;

interface

uses
  System.SysUtils, System.Classes, System.StrUtils, System.Diagnostics, System.RegularExpressions,
  System.Generics.Collections, Data.DB,
  FireDAC.Stan.Intf, FireDAC.Stan.Option, FireDAC.Stan.Param, FireDAC.Stan.Error,
  FireDAC.DatS, FireDAC.Phys.Intf, FireDAC.DApt.Intf, FireDAC.Comp.DataSet,
  FireDAC.Comp.Client, FireDAC.Phys.IBBase, FireDAC.Phys.IBWrapper,
  uBaglanti;

const
  ILK_SATIR_SAYISI = 100;
  SATIR_PARCASI = 500;

type
  { Bir sorgu sekmesinin son sonucu. Sekme sonucu serbest birakinca sorgu kapanir. }
  TSorguSonucu = class
  public
    Sorgu: TFDQuery;
    Islem: TFDTransaction;
    SatirVar: Boolean;
    Etkilenen: Integer;
    Sure: Int64;
    destructor Destroy; override;
  end;

type
  TKomutTuru = (ktNormal, ktCommit, ktRollback, ktIsql);
  TKomutDurumu = (kdCalisti, kdAtlandi, kdDurdu, kdHata);

  { Betikteki bir komutun ne oldugu. Metinleri arayuz (dil dosyasi) yazar. }
  TKomutKaydi = record
    Tur: TKomutTuru;
    Durum: TKomutDurumu;
    Komut: string;
    SatirVar: Boolean;
    Etkilenen: Integer;
    Sure: Int64;
    Hata: string;
    Ayrinti: string;
    OncekiSonucKapandi: Boolean;
  end;

{ Tablonun TUM satirlarini okuyan komut (CSV disa aktarma bunu yeniden calistirir). }
function TabloTumSatirlarSorgusu(const Tablo: string): string;

{ SiraAlan doluysa satirlar sunucuda o kolona gore siralanir (ORDER BY); boylece ilk SatirSayisi satir
  tablonun tamamindan secilir, yalniz yuklenenlerden degil. }
function TabloVerisiSorgusu(Bag: TAcikBaglanti; const Tablo: string; SatirSayisi: Integer;
  Sahip: TComponent; const SiraAlan: string = ''; Azalan: Boolean = False): TFDQuery;

{ Yazilan komutu calistirir. Hata olursa istisna firlar, cagiran HataMetniniCevir ile gosterir. }
function SorguCalistir(Bag: TAcikBaglanti; const Sql: string): TSorguSonucu;

{ Komut tehlikeliyse dil anahtarini ('ONAY_SORGU_...') verir, degilse bos doner. }
function TehlikeliSorguUyarisi(const Sql: string): string;

{ Yaziyi komutlara boler. Ayirici ';' dir; "SET TERM ^ ;" ile degisir (isql gibi), boylece
  prosedur govdesindeki ';' komutu bolmez. Tirnak ve yorum icindeki ayirici bolmez.
  Bos komutlar atilir. Ayirici sonuca dahil edilmez. }
function KomutlaraBol(const Metin: string): TArray<string>;

{ Komut COMMIT, ROLLBACK, isql'e ozgu bir komut (SET SQL DIALECT, CONNECT ...) ya da normal mi? }
function KomutTuruBul(const Komut: string): TKomutTuru;

{ Komutlari sirayla calistirir, ilk hatada durur. Her komut icin Kayitlar'a bir satir eklenir.
  COMMIT ve isql komutlari atlanir, ROLLBACK'te durulur. Donen deger son SELECT'in sonucudur
  (SELECT yoksa nil); onu cagiran serbest birakir. DDL komutundan (ALTER, DROP, RECREATE) once
  tutulan SELECT sonucu kapatilir (nesne kullanimda kalmasin) ve kayda yazilir; DML'de tutulur.
  Hata istisna olarak firlamaz, kayda yazilir. }
function BetikCalistir(Bag: TAcikBaglanti; const Komutlar: TArray<string>;
  Kayitlar: TList<TKomutKaydi>): TSorguSonucu;

{ Yazi tek bir komut mu? }
function TekKomutMu(const Sql: string): Boolean;

{ Komutu CALISTIRMADAN, sadece hazirlayarak (prepare) Firebird sorgu planini verir.
  Hata olursa istisna firlar, cagiran HataMetniniCevir ile gosterir. }
function SorguPlaniAl(Bag: TAcikBaglanti; const Sql: string): string;

{ "m." yazilirken m'nin hangi tablo oldugunu bulur: metinde FROM/JOIN sonrasi "tablo [AS] takma_ad"
  kaliplarina bakar. Takma ad bulunamazsa Ad'in kendisi tablo adi sayilir. Tirnaksiz ad buyuk harfe cevrilir. }
function TabloAdiniBul(const Metin, Ad: string): string;

{ Ad cift tirnaga alinir (tirnak icindeki " iki yazilir); tablo/kolon adi SQL metnine konurken kullanilir. }
function TirnakliAd(const Ad: string): string;

implementation

function TirnakliAd(const Ad: string): string;
begin
  Result := '"' + StringReplace(Ad, '"', '""', [rfReplaceAll]) + '"';
end;

destructor TSorguSonucu.Destroy;
begin
  Sorgu.Free;
  Islem.Free;
  inherited;
end;

{ Sondaki bosluk ve noktali virgulleri atar (Firebird komutun sonundaki ';' i kabul etmez). }
function SonNoktaliVirgulleriAt(const Sql: string): string;
begin
  Result := Trim(Sql);
  while (Result <> '') and (Result[Length(Result)] = ';') do
    Result := Trim(Copy(Result, 1, Length(Result) - 1));
end;

{ Yorumlari ve tirnak icindeki yazilari bosluga cevirir. Boylece 'DROP' kelimesi
  bir yazinin icinde gecince yanlis uyari cikmaz. }
function YorumlariVeYazilariAt(const Sql: string): string;
var
  i, Boy: Integer;
  Tirnak: Char;
begin
  Result := '';
  Boy := Length(Sql);
  i := 1;
  while i <= Boy do
  begin
    if (Sql[i] = '-') and (i < Boy) and (Sql[i + 1] = '-') then
    begin
      while (i <= Boy) and (Sql[i] <> #10) do
        Inc(i);
    end
    else if (Sql[i] = '/') and (i < Boy) and (Sql[i + 1] = '*') then
    begin
      Inc(i, 2);
      while (i < Boy) and not ((Sql[i] = '*') and (Sql[i + 1] = '/')) do
        Inc(i);
      Inc(i, 2);
      Result := Result + ' ';
    end
    else if (Sql[i] = '''') or (Sql[i] = '"') then
    begin
      Tirnak := Sql[i];
      Inc(i);
      while (i <= Boy) and (Sql[i] <> Tirnak) do
        Inc(i);
      Inc(i);
      Result := Result + ' ';
    end
    else
    begin
      Result := Result + Sql[i];
      Inc(i);
    end;
  end;
end;

function TehlikeliSorguUyarisi(const Sql: string): string;
var
  Yalin: string;
begin
  Result := '';
  Yalin := YorumlariVeYazilariAt(Sql);
  if TRegEx.IsMatch(Yalin, '\bDROP\b', [roIgnoreCase]) then
    Result := 'ONAY_SORGU_DROP'
  else if TRegEx.IsMatch(Yalin, '^\s*(DELETE|UPDATE)\b', [roIgnoreCase]) and
    not TRegEx.IsMatch(Yalin, '^\s*UPDATE\s+OR\b', [roIgnoreCase]) and
    not TRegEx.IsMatch(Yalin, '\bWHERE\b', [roIgnoreCase]) then
    Result := 'ONAY_SORGU_WHERE_YOK';
end;

function KomutlaraBol(const Metin: string): TArray<string>;
var
  Liste: TList<string>;
  Komut: TStringBuilder;
  Ayirici, Bas: string;
  i, Boy, Son: Integer;
  Tirnak: Char;
  KodVar: Boolean;
  SetTerm: TMatch;

  procedure KomutuBitir;
  begin
    if KodVar then
      Liste.Add(Trim(Komut.ToString));
    Komut.Clear;
    KodVar := False;
  end;

begin
  Liste := TList<string>.Create;
  Komut := TStringBuilder.Create;
  try
    Ayirici := ';';
    KodVar := False;
    Boy := Length(Metin);
    i := 1;
    while i <= Boy do
    begin
      if (Metin[i] = '-') and (i < Boy) and (Metin[i + 1] = '-') then
      begin
        while (i <= Boy) and (Metin[i] <> #10) do
        begin
          Komut.Append(Metin[i]);
          Inc(i);
        end;
      end
      else if (Metin[i] = '/') and (i < Boy) and (Metin[i + 1] = '*') then
      begin
        Son := PosEx('*/', Metin, i + 2);
        if Son = 0 then
          Son := Boy
        else
          Inc(Son);
        Komut.Append(Copy(Metin, i, Son - i + 1));
        i := Son + 1;
      end
      else if (Metin[i] = '''') or (Metin[i] = '"') then
      begin
        Tirnak := Metin[i];
        Son := PosEx(Tirnak, Metin, i + 1);
        if Son = 0 then
          Son := Boy;
        Komut.Append(Copy(Metin, i, Son - i + 1));
        KodVar := True;
        i := Son + 1;
      end
      else if Copy(Metin, i, Length(Ayirici)) = Ayirici then
      begin
        KomutuBitir;
        Inc(i, Length(Ayirici));
      end
      else
      begin
        { Komutun basinda "SET TERM yeni eski" varsa ayirici degisir, komut sayilmaz. }
        if not KodVar and CharInSet(Metin[i], ['S', 's']) then
        begin
          SetTerm := TRegEx.Match(Copy(Metin, i, 200), '^SET\s+TERM\s+', [roIgnoreCase]);
          if SetTerm.Success then
          begin
            Bas := '';
            Son := PosEx(Ayirici, Metin, i + SetTerm.Length);
            if Son = 0 then
              Son := Boy + 1;
            Bas := Trim(Copy(Metin, i + SetTerm.Length, Son - i - SetTerm.Length));
            if (Bas <> '') and (Pos(' ', Bas) = 0) then
              Ayirici := Bas;
            i := Son + 1;
            Continue;
          end;
        end;
        if not CharInSet(Metin[i], [' ', #9, #10, #13]) then
          KodVar := True;
        Komut.Append(Metin[i]);
        Inc(i);
      end;
    end;
    KomutuBitir;
    Result := Liste.ToArray;
  finally
    Komut.Free;
    Liste.Free;
  end;
end;

function KomutTuruBul(const Komut: string): TKomutTuru;
const
  ISQL_KOMUTLARI = '^\s*(SET\s+(SQL\s+DIALECT|NAMES|AUTODDL|AUTO|BAIL|BLOB|COUNT|ECHO|HEADING|LIST|' +
    'PLAN|PLANONLY|ROWCOUNT|SQLDA_DISPLAY|STATS|TIME|WARNINGS|WNG|MAXROWS)|CONNECT|SHOW|INPUT|OUTPUT|' +
    'QUIT|EXIT|EDIT|HELP|SHELL|BLOBDUMP|BLOBVIEW)\b';
var
  Yalin: string;
begin
  Yalin := YorumlariVeYazilariAt(Komut);
  if TRegEx.IsMatch(Yalin, '^\s*COMMIT\b', [roIgnoreCase]) then
    Result := ktCommit
  else if TRegEx.IsMatch(Yalin, '^\s*ROLLBACK\b', [roIgnoreCase]) then
    Result := ktRollback
  else if TRegEx.IsMatch(Yalin, ISQL_KOMUTLARI, [roIgnoreCase]) then
    Result := ktIsql
  else
    Result := ktNormal;
end;

function TekKomutMu(const Sql: string): Boolean;
begin
  Result := Length(KomutlaraBol(Sql)) <= 1;
end;

function TirnaksizAd(const Ad: string): string;
begin
  if (Length(Ad) >= 2) and (Ad[1] = '"') then
    Result := StringReplace(Copy(Ad, 2, Length(Ad) - 2), '""', '"', [rfReplaceAll])
  else
    Result := UpperCase(Ad);
end;

function TabloAdiniBul(const Metin, Ad: string): string;
const
  ADKALIBI = '("[^"]+"|[A-Za-z_][A-Za-z0-9_$]*)';
  { Takma ad gibi gorunen ama aslinda sonraki SQL sozcugu olanlar. }
  SOZCUKLER = ',WHERE,JOIN,LEFT,RIGHT,INNER,OUTER,FULL,CROSS,NATURAL,ON,ORDER,GROUP,HAVING,' +
    'UNION,PLAN,ROWS,WITH,FOR,INTO,AS,SELECT,';
var
  Eslesme: TMatch;
  Tablo, Takma: string;
begin
  Result := TirnaksizAd(Ad);
  for Eslesme in TRegEx.Matches(Metin, '\b(?:FROM|JOIN)\s+' + ADKALIBI + '(?:\s+(?:AS\s+)?' + ADKALIBI + ')?',
    [roIgnoreCase]) do
  begin
    Tablo := Eslesme.Groups[1].Value;
    Takma := '';
    if (Eslesme.Groups.Count > 2) and Eslesme.Groups[2].Success then
      Takma := Eslesme.Groups[2].Value;
    if (Takma <> '') and (Pos(',' + UpperCase(Takma) + ',', SOZCUKLER) = 0) and
      (TirnaksizAd(Takma) = TirnaksizAd(Ad)) then
      Exit(TirnaksizAd(Tablo));
  end;
end;

type
  { FireDAC'in Firebird komutundaki korunmus alana (FStmt) ulasmak icin. Baska is yapmaz. }
  TFbKomutErisim = class(TFDPhysIBCommandBase);

function SorguPlaniAl(Bag: TAcikBaglanti; const Sql: string): string;
var
  Islem: TFDTransaction;
  Sorgu: TFDQuery;
  Komut: TFbKomutErisim;
begin
  Islem := TFDTransaction.Create(nil);
  Sorgu := TFDQuery.Create(nil);
  try
    Islem.Connection := Bag.Baglanti;
    Sorgu.Connection := Bag.Baglanti;
    Sorgu.Transaction := Islem;
    Sorgu.ResourceOptions.ParamCreate := False;
    Sorgu.ResourceOptions.MacroCreate := False;
    Sorgu.ResourceOptions.MacroExpand := False;
    Sorgu.ResourceOptions.EscapeExpand := False;
    Sorgu.SQL.Text := SonNoktaliVirgulleriAt(Sql);
    Sorgu.Prepare;
    { CREATE/ALTER/DROP gibi komutlarin plani yoktur (FireDAC bunlari hazirlamadan gonderir). }
    if Sorgu.Command.CommandKind in [skStartTransaction, skCommit, skRollback, skCreate,
      skAlter, skDrop, skSet, skSetSchema, skOther] then
      Exit('');
    Komut := TFbKomutErisim(Sorgu.Command.CommandIntf as TFDPhysIBCommandBase);
    { Firebird 3 ve sonrasi ayrintili plani da verir; 2.5'te yalnizca kisa plan var. }
    Result := '';
    if StrToIntDef(Copy(Bag.Surum, 1, Pos('.', Bag.Surum) - 1), 0) >= 3 then
      Result := Komut.FStmt.sql_explain_plan;
    if Result = '' then
      Result := Komut.FStmt.sql_get_plan;
    Result := Trim(Result);
  finally
    Sorgu.Free;
    Islem.Free;
  end;
end;

function SorguCalistir(Bag: TAcikBaglanti; const Sql: string): TSorguSonucu;
var
  Saat: TStopwatch;
begin
  Result := TSorguSonucu.Create;
  try
    Result.Islem := TFDTransaction.Create(nil);
    Result.Islem.Connection := Bag.Baglanti;
    Result.Islem.Options.AutoCommit := True;
    Result.Sorgu := TFDQuery.Create(nil);
    Result.Sorgu.Connection := Bag.Baglanti;
    Result.Sorgu.Transaction := Result.Islem;
    { Yazilan komut oldugu gibi gitsin: ':ad' parametre, '!ad' makro sayilmasin. }
    Result.Sorgu.ResourceOptions.ParamCreate := False;
    Result.Sorgu.ResourceOptions.MacroCreate := False;
    Result.Sorgu.ResourceOptions.MacroExpand := False;
    Result.Sorgu.ResourceOptions.EscapeExpand := False;
    Result.Sorgu.FetchOptions.Mode := fmOnDemand;
    Result.Sorgu.FetchOptions.RowsetSize := SATIR_PARCASI;
    Result.Sorgu.SQL.Text := SonNoktaliVirgulleriAt(Sql);
    Saat := TStopwatch.StartNew;
    Result.Sorgu.OpenOrExecute;
    Result.Sure := Saat.ElapsedMilliseconds;
    Result.SatirVar := Result.Sorgu.Active;
    if Result.SatirVar then
      Result.Etkilenen := 0
    else
      Result.Etkilenen := Result.Sorgu.RowsAffected;
  except
    Result.Free;
    raise;
  end;
end;

{ DDL (nesneyi degistiren/silen) komut mu? Acik bir SELECT sonucu nesneyi kullanimda tuttugu icin
  bu komutlardan once sonuc birakilir (bkz. BetikCalistir). Olcum: Firebird 5.0.4'te DROP takiliyor. }
function KomutDDLMi(const Komut: string): Boolean;
begin
  Result := TRegEx.IsMatch(YorumlariVeYazilariAt(Komut), '^\s*(ALTER|DROP|RECREATE|CREATE\s+OR\s+ALTER)\b',
    [roIgnoreCase]);
end;

function BetikCalistir(Bag: TAcikBaglanti; const Komutlar: TArray<string>;
  Kayitlar: TList<TKomutKaydi>): TSorguSonucu;
var
  Kayit: TKomutKaydi;
  Sonuc: TSorguSonucu;
  Komut: string;
begin
  Result := nil;
  for Komut in Komutlar do
  begin
    Kayit := Default(TKomutKaydi);
    Kayit.Komut := Copy(Trim(Komut), 1, 60);
    Kayit.Tur := KomutTuruBul(Komut);
    case Kayit.Tur of
      ktCommit, ktIsql:
        Kayit.Durum := kdAtlandi;
      ktRollback:
        Kayit.Durum := kdDurdu;
      ktNormal:
        try
          if (Result <> nil) and KomutDDLMi(Komut) then
          begin
            FreeAndNil(Result);
            Kayit.OncekiSonucKapandi := True;
          end;
          Sonuc := SorguCalistir(Bag, Komut);
          Kayit.Durum := kdCalisti;
          Kayit.SatirVar := Sonuc.SatirVar;
          Kayit.Etkilenen := Sonuc.Etkilenen;
          Kayit.Sure := Sonuc.Sure;
          if Sonuc.SatirVar then
          begin
            Result.Free;
            Result := Sonuc;
          end
          else
            Sonuc.Free;
        except
          on E: Exception do
          begin
            Kayit.Durum := kdHata;
            Kayit.Hata := HataMetniniCevir(E);
            Kayit.Ayrinti := E.Message;
          end;
        end;
    end;
    Kayitlar.Add(Kayit);
    if Kayit.Durum in [kdDurdu, kdHata] then
      Break;
  end;
end;

function TabloTumSatirlarSorgusu(const Tablo: string): string;
begin
  Result := 'SELECT * FROM ' + TirnakliAd(Tablo);
end;

{ Sorgu, Sahip ile birlikte yok olur. Sorgu salt okunurdur. }
function TabloVerisiSorgusu(Bag: TAcikBaglanti; const Tablo: string; SatirSayisi: Integer;
  Sahip: TComponent; const SiraAlan: string = ''; Azalan: Boolean = False): TFDQuery;
var
  Siralama: string;
begin
  Siralama := '';
  if SiraAlan <> '' then
  begin
    Siralama := ' ORDER BY ' + TirnakliAd(SiraAlan);
    if Azalan then
      Siralama := Siralama + ' DESC';
  end;
  Result := TFDQuery.Create(Sahip);
  try
    Result.Connection := Bag.Baglanti;
    Result.UpdateOptions.ReadOnly := True;
    { En fazla 100 satir hepsi birden cekilir. Boylece okuma isleminin sunucuda
      acik kalmasi onlenir (sorgu sekmesi parca parca ceker, bkz. SorguCalistir). }
    Result.FetchOptions.Mode := fmAll;
    Result.SQL.Text := 'SELECT FIRST ' + IntToStr(SatirSayisi) + ' * FROM ' + TirnakliAd(Tablo) + Siralama;
    Result.Open;
  except
    Result.Free;
    raise;
  end;
end;

end.
