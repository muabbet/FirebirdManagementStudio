{ uIndeksOner.pas - Sorgu icin index onerisi (Asama 7d, ikinci adim).
  Nasil calisir (basit, tahmin degil olgu): sorgunun planina bakilir; "NATURAL" (index'siz tam tarama) yapilan ve 1000'den cok
  satiri olan tablolar bulunur; sorgunun WHERE / JOIN ON kosullarinda o tablonun hangi kolonlari kullaniliyorsa (= ve IN once,
  sonra < > BETWEEN, STARTING WITH, 'abc%' gibi LIKE) onlarin uzerine CREATE INDEX onerilir. Zaten basinda o kolon olan bir index
  varsa oneri yapilmaz (not dusulur). Index olusturulduktan sonra plan yeniden alinip once / sonra gosterilir.
  Oneri bir SQL ayristirmasina dayanir (sade bir sozcuk ayirici); karmasik sorgularda (view ici, ifadeli kosul) oneri cikmaz ve
  neden notta yazilir. Hicbir sey kendiliginden olusturulmaz: cagiran kullanicidan net onay alir.
  Tum surumlerde (2.5, 3.0, 4.0, 5.0) calisir; sade ve sade plan metinlerini (NATURAL ve "Full Scan") tanir. }
unit uIndeksOner;

interface

uses
  System.SysUtils, System.Classes, System.Generics.Collections, uBaglanti, uProsedur;

type
  { ktBaglanti: iki kolon birbirine esitleniyor (JOIN anahtari); sabit degerle esitlik ktEsit }
  TKosulTuru = (ktEsit, ktAralik, ktBaglanti);

  { SQL'in kosulunda gecen bir kolon basvurusu }
  TKosulKolonu = record
    { "S.TARIH" icindeki S; yoksa bos }
    On: string;
    Kolon: string;
    Tur: TKosulTuru;
  end;

  { FROM / JOIN / UPDATE'te gecen tablo ve takma adi }
  TSqlTablosu = record
    Tablo: string;
    Takma: string;
  end;

  TIndeksOnerisi = record
    Tablo: string;
    Kolonlar: TArray<string>;
    { Olusturulacak index'in adi ve komutu }
    Ad: string;
    Sql: string;
    { Insan icin kisa aciklama }
    Neden: string;
  end;

  TIndeksRaporu = record
    Basarili: Boolean;
    Cumle: string;
    Ayrinti: string;
    Plan: string;
    Oneriler: TArray<TIndeksOnerisi>;
    { Oneri yapilamayan ya da gerek olmayan durumlarin aciklamalari }
    Notlar: TArray<string>;
  end;

{ SQL metninden FROM / JOIN tablolarini ve kosullardaki kolonlari cikarir (saf yordam). False: SQL ayristirilamadi. }
function SqlKosullariniOku(const Sql: string; out Tablolar: TArray<TSqlTablosu>; out Kosullar: TArray<TKosulKolonu>): Boolean;

{ Plan metninden index'siz taranan tablo / takma adlarini verir (saf yordam). Hem kisa plan ("PLAN (S NATURAL)") hem
  ayrintili plan ('Table "SATIS" as "S" Full Scan') tanir. }
function PlandaTaramaAdlari(const Plan: string): TArray<string>;

{ Sorgunun planina bakip index onerilerini hazirlar. Veritabanina YAZMAZ. }
function IndeksOnerisiHazirla(Bag: TAcikBaglanti; const Sql: string): TIndeksRaporu;

{ Oneriyi olusturur (CREATE INDEX). Hata Sonuc'ta anlasilir cumleyle gelir. }
function IndeksOlustur(Bag: TAcikBaglanti; const Oneri: TIndeksOnerisi): TProsedurSonucu;

implementation

uses
  System.StrUtils, System.Math, System.Variants, uDil, uSorgu, uMetadata, uNesneYonet;

const
  { Bundan az satirli tabloda tam tarama sorun degildir: oneri yapilmaz }
  KUCUK_TABLO_SATIR = 1000;
  { Bir indexte en cok kac kolon onerilir }
  EN_COK_KOLON = 3;

type
  TJetonTuru = (jtKimlik, jtSayi, jtYazi, jtSembol);

  TJeton = record
    Tur: TJetonTuru;
    { Kimlik: tirnaksizsa BUYUK harf, tirnakliysa oldugu gibi; yazi: tirnaksiz icerik; sembol: oldugu gibi }
    Metin: string;
    Tirnakli: Boolean;
  end;

  TDurum = (dDiger, dSecim, dFrom, dKosul);

{ ---------- sozcuk ayirici ---------- }

function Jetonla(const Sql: string): TArray<TJeton>;
var
  Liste: TList<TJeton>;
  i, Uzunluk, Basla: Integer;
  J: TJeton;
  Karakter: Char;
begin
  Liste := TList<TJeton>.Create;
  try
    i := 1;
    Uzunluk := Length(Sql);
    while i <= Uzunluk do
    begin
      Karakter := Sql[i];
      if Karakter <= ' ' then
        Inc(i)
      else if (Karakter = '-') and (i < Uzunluk) and (Sql[i + 1] = '-') then
      begin
        while (i <= Uzunluk) and (Sql[i] <> #10) do
          Inc(i);
      end
      else if (Karakter = '/') and (i < Uzunluk) and (Sql[i + 1] = '*') then
      begin
        Inc(i, 2);
        while (i < Uzunluk) and not ((Sql[i] = '*') and (Sql[i + 1] = '/')) do
          Inc(i);
        Inc(i, 2);
      end
      else if Karakter = '''' then
      begin
        Basla := i + 1;
        Inc(i);
        while i <= Uzunluk do
        begin
          if Sql[i] = '''' then
          begin
            if (i < Uzunluk) and (Sql[i + 1] = '''') then
              Inc(i, 2)
            else
              Break;
          end
          else
            Inc(i);
        end;
        J.Tur := jtYazi;
        J.Metin := Copy(Sql, Basla, i - Basla);
        J.Tirnakli := False;
        Liste.Add(J);
        Inc(i);
      end
      else if Karakter = '"' then
      begin
        Basla := i + 1;
        Inc(i);
        while (i <= Uzunluk) and (Sql[i] <> '"') do
          Inc(i);
        J.Tur := jtKimlik;
        J.Metin := Copy(Sql, Basla, i - Basla);
        J.Tirnakli := True;
        Liste.Add(J);
        Inc(i);
      end
      else if CharInSet(Karakter, ['A'..'Z', 'a'..'z', '_']) then
      begin
        Basla := i;
        while (i <= Uzunluk) and CharInSet(Sql[i], ['A'..'Z', 'a'..'z', '0'..'9', '_', '$']) do
          Inc(i);
        J.Tur := jtKimlik;
        J.Metin := UpperCase(Copy(Sql, Basla, i - Basla));
        J.Tirnakli := False;
        Liste.Add(J);
      end
      else if CharInSet(Karakter, ['0'..'9']) then
      begin
        Basla := i;
        while (i <= Uzunluk) and CharInSet(Sql[i], ['0'..'9', '.']) do
          Inc(i);
        J.Tur := jtSayi;
        J.Metin := Copy(Sql, Basla, i - Basla);
        J.Tirnakli := False;
        Liste.Add(J);
      end
      else
      begin
        { Iki karakterli semboller: <= >= <> != || ^= }
        J.Tur := jtSembol;
        J.Tirnakli := False;
        if (Copy(Sql, i, 2) = '<=') or (Copy(Sql, i, 2) = '>=') or (Copy(Sql, i, 2) = '<>') or
          (Copy(Sql, i, 2) = '!=') or (Copy(Sql, i, 2) = '||') or (Copy(Sql, i, 2) = '^=') then
        begin
          J.Metin := Copy(Sql, i, 2);
          Inc(i, 2);
        end
        else
        begin
          J.Metin := Karakter;
          Inc(i);
        end;
        Liste.Add(J);
      end;
    end;
    Result := Liste.ToArray;
  finally
    Liste.Free;
  end;
end;

function AnahtarKelimeMi(const J: TJeton): Boolean;
const
  KELIMELER = ',SELECT,FROM,WHERE,AND,OR,NOT,IN,IS,NULL,LIKE,BETWEEN,STARTING,WITH,CONTAINING,ON,JOIN,INNER,LEFT,RIGHT,FULL,' +
    'OUTER,CROSS,GROUP,BY,ORDER,HAVING,UNION,PLAN,ROWS,FOR,AS,SET,UPDATE,DELETE,INSERT,INTO,EXISTS,ANY,ALL,SOME,DISTINCT,' +
    'FIRST,SKIP,CASE,WHEN,THEN,ELSE,END,TRUE,FALSE,UNKNOWN,ASC,DESC,NATURAL,RETURNING,VALUES,SIMILAR,TO,ESCAPE,' +
    'CURRENT_DATE,CURRENT_TIME,CURRENT_TIMESTAMP,CURRENT_USER,CURRENT_ROLE,CURRENT_CONNECTION,CURRENT_TRANSACTION,NOW,TODAY,' +
    'TOMORROW,YESTERDAY,USER,ROW_COUNT,';
begin
  Result := (J.Tur = jtKimlik) and (not J.Tirnakli) and (Pos(',' + J.Metin + ',', KELIMELER) > 0);
end;

function Sembolmu(const J: TJeton; const Metin: string): Boolean;
begin
  Result := (J.Tur = jtSembol) and (J.Metin = Metin);
end;

function Kelimemi(const J: TJeton; const Metin: string): Boolean;
begin
  Result := (J.Tur = jtKimlik) and (not J.Tirnakli) and (J.Metin = Metin);
end;

{ ---------- SQL'den tablo ve kosul kolonlari ---------- }

{ J[Konum] bir '=' ise sag tarafi bir kolon mu (JOIN)? }
function SagTarafKolonMu(const J: TArray<TJeton>; Konum: Integer): Boolean;
var
  Sonraki: Integer;
begin
  Result := False;
  Sonraki := Konum + 1;
  if (Sonraki >= Length(J)) or (J[Sonraki].Tur <> jtKimlik) or AnahtarKelimeMi(J[Sonraki]) then
    Exit;
  { ON.KOLON: ad, '.', kolon; sonrasinda fonksiyon parantezi ya da aritmetik olmamali }
  if (Sonraki + 2 < Length(J)) and Sembolmu(J[Sonraki + 1], '.') then
    Sonraki := Sonraki + 2;
  if Sonraki + 1 < Length(J) then
    if Sembolmu(J[Sonraki + 1], '(') or (J[Sonraki + 1].Tur = jtSembol) and ((J[Sonraki + 1].Metin = '+') or
      (J[Sonraki + 1].Metin = '-') or (J[Sonraki + 1].Metin = '*') or (J[Sonraki + 1].Metin = '/') or (J[Sonraki + 1].Metin = '||')) then
      Exit;
  Result := True;
end;

function SqlKosullariniOku(const Sql: string; out Tablolar: TArray<TSqlTablosu>; out Kosullar: TArray<TKosulKolonu>): Boolean;
var
  J: TArray<TJeton>;
  TabloListesi: TList<TSqlTablosu>;
  KosulListesi: TList<TKosulKolonu>;
  Durum: array[0..40] of TDurum;
  Derinlik, i, Sonraki: Integer;
  TabloBekle: Boolean;
  T: TSqlTablosu;
  K: TKosulKolonu;
  Onceki, Sonrakijeton: TJeton;
  OncekiVar, SonrakiVar, Atla: Boolean;
  Islem: string;
  EslesenTur: TKosulTuru;
begin
  Tablolar := nil;
  Kosullar := nil;
  J := Jetonla(Sql);
  Result := Length(J) > 0;
  if not Result then
    Exit;
  TabloListesi := TList<TSqlTablosu>.Create;
  KosulListesi := TList<TKosulKolonu>.Create;
  try
    Derinlik := 0;
    Durum[0] := dDiger;
    TabloBekle := False;
    i := 0;
    while i < Length(J) do
    begin
      { --- parantez ve anahtar sozcuklerle durum --- }
      if Sembolmu(J[i], '(') then
      begin
        if Derinlik < High(Durum) then
        begin
          Inc(Derinlik);
          Durum[Derinlik] := Durum[Derinlik - 1];
        end;
        if TabloBekle then
          TabloBekle := False;
        Inc(i);
        Continue;
      end;
      if Sembolmu(J[i], ')') then
      begin
        if Derinlik > 0 then
          Dec(Derinlik);
        Inc(i);
        Continue;
      end;
      if Kelimemi(J[i], 'SELECT') then
        Durum[Derinlik] := dSecim
      else if Kelimemi(J[i], 'FROM') or Kelimemi(J[i], 'UPDATE') then
      begin
        Durum[Derinlik] := dFrom;
        TabloBekle := True;
      end
      else if Kelimemi(J[i], 'JOIN') then
      begin
        Durum[Derinlik] := dFrom;
        TabloBekle := True;
      end
      else if Kelimemi(J[i], 'WHERE') or Kelimemi(J[i], 'ON') then
        Durum[Derinlik] := dKosul
      else if Kelimemi(J[i], 'GROUP') or Kelimemi(J[i], 'ORDER') or Kelimemi(J[i], 'HAVING') or Kelimemi(J[i], 'UNION') or
        Kelimemi(J[i], 'PLAN') or Kelimemi(J[i], 'ROWS') or Kelimemi(J[i], 'SET') or Kelimemi(J[i], 'FOR') then
        Durum[Derinlik] := dDiger
      else if (Durum[Derinlik] = dFrom) and TabloBekle and (J[i].Tur = jtKimlik) and not AnahtarKelimeMi(J[i]) then
      begin
        { tablo adi, istege bagli AS, istege bagli takma ad }
        T.Tablo := J[i].Metin;
        T.Takma := '';
        Sonraki := i + 1;
        if (Sonraki < Length(J)) and Kelimemi(J[Sonraki], 'AS') then
          Inc(Sonraki);
        if (Sonraki < Length(J)) and (J[Sonraki].Tur = jtKimlik) and not AnahtarKelimeMi(J[Sonraki]) then
        begin
          T.Takma := J[Sonraki].Metin;
          Inc(Sonraki);
        end;
        TabloListesi.Add(T);
        TabloBekle := False;
        { virgulle devam eden tablo listesi }
        if (Sonraki < Length(J)) and Sembolmu(J[Sonraki], ',') then
        begin
          TabloBekle := True;
          Inc(Sonraki);
        end;
        i := Sonraki;
        Continue;
      end
      else if (Durum[Derinlik] = dKosul) and (J[i].Tur = jtKimlik) and not AnahtarKelimeMi(J[i]) then
      begin
        { kolon basvurusu: ya KOLON ya ON.KOLON }
        K.On := '';
        K.Kolon := J[i].Metin;
        Sonraki := i + 1;
        if (Sonraki + 1 < Length(J)) and Sembolmu(J[Sonraki], '.') and (J[Sonraki + 1].Tur = jtKimlik) then
        begin
          K.On := J[i].Metin;
          K.Kolon := J[Sonraki + 1].Metin;
          Sonraki := Sonraki + 2;
        end;
        OncekiVar := i > 0;
        SonrakiVar := Sonraki < Length(J);
        if OncekiVar then
          Onceki := J[i - 1];
        if SonrakiVar then
          Sonrakijeton := J[Sonraki];
        Atla := False;
        { fonksiyon cagrisi (ad sonrasi '(') ya da fonksiyonun argumani: UPPER(KOLON) }
        if SonrakiVar and Sembolmu(Sonrakijeton, '(') then
          Atla := True;
        if OncekiVar and Sembolmu(Onceki, '(') and (i >= 2) and (J[i - 2].Tur = jtKimlik) and not AnahtarKelimeMi(J[i - 2]) then
          Atla := True;
        { aritmetik ifadede kolon: A + 1 = B }
        if SonrakiVar and (Sonrakijeton.Tur = jtSembol) and ((Sonrakijeton.Metin = '+') or (Sonrakijeton.Metin = '-') or
          (Sonrakijeton.Metin = '*') or (Sonrakijeton.Metin = '/') or (Sonrakijeton.Metin = '||')) then
          Atla := True;
        if OncekiVar and (Onceki.Tur = jtSembol) and ((Onceki.Metin = '+') or (Onceki.Metin = '-') or (Onceki.Metin = '*') or
          (Onceki.Metin = '/') or (Onceki.Metin = '||')) then
          Atla := True;
        if not Atla then
        begin
          Islem := '';
          { kolon OP deger }
          if SonrakiVar then
          begin
            if Sonrakijeton.Tur = jtSembol then
              Islem := Sonrakijeton.Metin
            else if Sonrakijeton.Tur = jtKimlik then
              Islem := Sonrakijeton.Metin;
          end;
          EslesenTur := ktEsit;
          Atla := True;
          if (Islem = '=') or (Islem = 'IN') then
          begin
            EslesenTur := ktEsit;
            if (Islem = '=') and SagTarafKolonMu(J, Sonraki) then
              EslesenTur := ktBaglanti;
            Atla := False;
          end
          else if (Islem = '<') or (Islem = '>') or (Islem = '<=') or (Islem = '>=') or (Islem = 'BETWEEN') or (Islem = 'STARTING') then
          begin
            EslesenTur := ktAralik;
            Atla := False;
          end
          else if Islem = 'LIKE' then
          begin
            { 'abc%' index kullanir, '%abc' kullanmaz }
            if (Sonraki + 1 < Length(J)) and (J[Sonraki + 1].Tur = jtYazi) and (J[Sonraki + 1].Metin <> '') and
              not CharInSet(J[Sonraki + 1].Metin[1], ['%', '_']) then
            begin
              EslesenTur := ktAralik;
              Atla := False;
            end;
          end
          else if OncekiVar and (Onceki.Tur = jtSembol) then
          begin
            { DEGER OP kolon }
            if Onceki.Metin = '=' then
            begin
              EslesenTur := ktEsit;
              { solunda da bir kolon varsa JOIN }
              if (i >= 2) and (J[i - 2].Tur = jtKimlik) and not AnahtarKelimeMi(J[i - 2]) then
                EslesenTur := ktBaglanti;
              Atla := False;
            end
            else if (Onceki.Metin = '<') or (Onceki.Metin = '>') or (Onceki.Metin = '<=') or (Onceki.Metin = '>=') then
            begin
              EslesenTur := ktAralik;
              Atla := False;
            end;
          end;
          if not Atla then
          begin
            K.Tur := EslesenTur;
            KosulListesi.Add(K);
          end;
        end;
        i := Sonraki;
        Continue;
      end;
      Inc(i);
    end;
    Tablolar := TabloListesi.ToArray;
    Kosullar := KosulListesi.ToArray;
  finally
    KosulListesi.Free;
    TabloListesi.Free;
  end;
end;

{ ---------- plandan tarama ---------- }

function PlandaTaramaAdlari(const Plan: string): TArray<string>;
var
  Liste: TList<string>;
  Satirlar: TStringList;
  Satir, Ad: string;
  J: TArray<TJeton>;
  i: Integer;
begin
  Liste := TList<string>.Create;
  Satirlar := TStringList.Create;
  try
    Satirlar.Text := Plan;
    for Satir in Satirlar do
    begin
      { Ayrintili plan (3.0+): Table "SATIS" as "S" Full Scan }
      if ContainsText(Satir, 'Full Scan') then
      begin
        J := Jetonla(Satir);
        { TABLE ad [AS takma] FULL SCAN }
        for i := 0 to High(J) - 1 do
          if Kelimemi(J[i], 'TABLE') and (J[i + 1].Tur = jtKimlik) then
          begin
            Ad := J[i + 1].Metin;
            if (i + 3 <= High(J)) and Kelimemi(J[i + 2], 'AS') and (J[i + 3].Tur = jtKimlik) then
              Ad := J[i + 3].Metin;
            if not Liste.Contains(Ad) then
              Liste.Add(Ad);
          end;
      end;
    end;
    { Kisa plan: "PLAN JOIN (S NATURAL, M INDEX (PK_M))" }
    J := Jetonla(Plan);
    for i := 1 to High(J) do
      if Kelimemi(J[i], 'NATURAL') and (J[i - 1].Tur = jtKimlik) and not AnahtarKelimeMi(J[i - 1]) then
        if not Liste.Contains(J[i - 1].Metin) then
          Liste.Add(J[i - 1].Metin);
    Result := Liste.ToArray;
  finally
    Satirlar.Free;
    Liste.Free;
  end;
end;

{ ---------- oneri ---------- }

function KolonVarMi(const Kolonlar: TArray<TKolonBilgisi>; const Ad: string): Boolean;
var
  K: TKolonBilgisi;
begin
  Result := False;
  for K in Kolonlar do
    if SameText(K.Ad, Ad) then
      Exit(True);
end;

function TabloyuBul(const Tablolar: TArray<TSqlTablosu>; const Ad: string): Integer;
var
  i: Integer;
begin
  Result := -1;
  for i := 0 to High(Tablolar) do
    if (Tablolar[i].Takma <> '') and SameText(Tablolar[i].Takma, Ad) then
      Exit(i);
  for i := 0 to High(Tablolar) do
    if SameText(Tablolar[i].Tablo, Ad) then
      Exit(i);
end;

function SatirSayisiKucukMu(Bag: TAcikBaglanti; const Tablo: string): Boolean;
begin
  Result := StrToInt64Def(VarToStr(Bag.Baglanti.ExecSQLScalar('SELECT COUNT(*) FROM (SELECT FIRST ' +
    IntToStr(KUCUK_TABLO_SATIR + 1) + ' 1 AS X FROM ' + AdHazirla(Tablo) + ')')), 0) <= KUCUK_TABLO_SATIR;
end;

function IndeksAdiVarMi(Bag: TAcikBaglanti; const Ad: string): Boolean;
begin
  Result := StrToIntDef(VarToStr(Bag.Baglanti.ExecSQLScalar('SELECT COUNT(*) FROM RDB$INDICES WHERE RDB$INDEX_NAME = ''' +
    StringReplace(Ad, '''', '''''', [rfReplaceAll]) + '''')), 0) > 0;
end;

function YeniIndeksAdi(Bag: TAcikBaglanti; const Tablo: string; const Kolonlar: TArray<string>): string;
var
  Taban, Aday: string;
  i, Sayac: Integer;
begin
  Taban := 'IX_' + Tablo;
  for i := 0 to High(Kolonlar) do
    Taban := Taban + '_' + Kolonlar[i];
  Taban := Copy(Taban, 1, 28);
  Aday := Taban;
  Sayac := 1;
  while IndeksAdiVarMi(Bag, Aday) do
  begin
    Inc(Sayac);
    Aday := Taban + '_' + IntToStr(Sayac);
  end;
  Result := Aday;
end;

function BasindaKolonVarMi(Bag: TAcikBaglanti; const Tablo, Kolon: string): string;
var
  Indeks: TIndeksBilgisi;
begin
  Result := '';
  for Indeks in IndeksleriOku(Bag, Tablo) do
    if (not Indeks.Pasif) and (Indeks.Ifade = '') and (Length(Indeks.Kolonlar) > 0) and SameText(Indeks.Kolonlar[0], Kolon) then
      Exit(Indeks.Ad);
end;

function IndeksOnerisiHazirla(Bag: TAcikBaglanti; const Sql: string): TIndeksRaporu;
var
  Tablolar: TArray<TSqlTablosu>;
  Kosullar: TArray<TKosulKolonu>;
  Taramalar: TArray<string>;
  Kolonlar: TArray<TArray<TKolonBilgisi>>;
  Oneriler: TList<TIndeksOnerisi>;
  Notlar: TList<string>;
  Tarama, Mevcut, KolonYazisi: string;
  i, n, TabloNo, Eslesen: Integer;
  Adaylar: TList<string>;
  Aralik, Baglanti: string;
  O: TIndeksOnerisi;
  K: TKosulKolonu;
  Kolon: string;
  Sahibi: Integer;
  JoinOnerisi: Boolean;
begin
  Result := Default(TIndeksRaporu);
  try
    Result.Plan := SorguPlaniAl(Bag, Sql);
  except
    on E: Exception do
    begin
      Result.Cumle := T('ERR_PLAN_ALINAMADI') + ' ' + HataMetniniCevir(E);
      Result.Ayrinti := E.Message;
      Exit;
    end;
  end;
  Oneriler := TList<TIndeksOnerisi>.Create;
  Notlar := TList<string>.Create;
  try
    if Result.Plan = '' then
      Notlar.Add(T('MSG_PLAN_YOK'))
    else
    begin
      Taramalar := PlandaTaramaAdlari(Result.Plan);
      if Length(Taramalar) = 0 then
        Notlar.Add(T('INDEKS_NOT_TARAMA_YOK'))
      else if not SqlKosullariniOku(Sql, Tablolar, Kosullar) then
        Notlar.Add(T('INDEKS_NOT_SQL_OKUNAMADI'))
      else
      begin
        SetLength(Kolonlar, Length(Tablolar));
        for i := 0 to High(Tablolar) do
          Kolonlar[i] := KolonlariOku(Bag, Tablolar[i].Tablo);
        for Tarama in Taramalar do
        begin
          TabloNo := TabloyuBul(Tablolar, Tarama);
          if TabloNo < 0 then
          begin
            Notlar.Add(TF('INDEKS_NOT_TABLO_YOK', [Tarama]));
            Continue;
          end;
          if SatirSayisiKucukMu(Bag, Tablolar[TabloNo].Tablo) then
          begin
            Notlar.Add(TF('INDEKS_NOT_KUCUK', [Tablolar[TabloNo].Tablo, KUCUK_TABLO_SATIR]));
            Continue;
          end;
          { bu tabloya ait kosul kolonlari }
          Adaylar := TList<string>.Create;
          try
            Aralik := '';
            Baglanti := '';
            for K in Kosullar do
            begin
              if K.On <> '' then
                Sahibi := TabloyuBul(Tablolar, K.On)
              else
              begin
                { onsuz kolon: yalniz bir tabloda varsa o tablonundur }
                Sahibi := -1;
                Eslesen := 0;
                for n := 0 to High(Tablolar) do
                  if KolonVarMi(Kolonlar[n], K.Kolon) then
                  begin
                    Inc(Eslesen);
                    Sahibi := n;
                  end;
                if Eslesen <> 1 then
                  Sahibi := -1;
              end;
              if (Sahibi <> TabloNo) or not KolonVarMi(Kolonlar[TabloNo], K.Kolon) then
                Continue;
              Kolon := K.Kolon;
              if K.Tur = ktEsit then
              begin
                if (not Adaylar.Contains(Kolon)) and (Adaylar.Count < EN_COK_KOLON - 1) then
                  Adaylar.Add(Kolon);
              end
              else if K.Tur = ktBaglanti then
              begin
                if Baglanti = '' then
                  Baglanti := Kolon;
              end
              else if (Aralik = '') and (not Adaylar.Contains(Kolon)) then
                Aralik := Kolon;
            end;
            if (Aralik <> '') and (Adaylar.Count < EN_COK_KOLON) then
              Adaylar.Add(Aralik);
            { Sabit degerle filtre kolonu yoksa JOIN kolonu (tek kolonlu index) }
            JoinOnerisi := (Adaylar.Count = 0) and (Baglanti <> '');
            if JoinOnerisi then
              Adaylar.Add(Baglanti);
            if Adaylar.Count = 0 then
            begin
              Notlar.Add(TF('INDEKS_NOT_KOSUL_YOK', [Tablolar[TabloNo].Tablo]));
              Continue;
            end;
            Mevcut := BasindaKolonVarMi(Bag, Tablolar[TabloNo].Tablo, Adaylar[0]);
            if Mevcut <> '' then
            begin
              Notlar.Add(TF('INDEKS_NOT_VAR', [Tablolar[TabloNo].Tablo, Mevcut, Adaylar[0]]));
              Continue;
            end;
            O := Default(TIndeksOnerisi);
            O.Tablo := Tablolar[TabloNo].Tablo;
            O.Kolonlar := Adaylar.ToArray;
            O.Ad := YeniIndeksAdi(Bag, O.Tablo, O.Kolonlar);
            KolonYazisi := '';
            for n := 0 to High(O.Kolonlar) do
              KolonYazisi := KolonYazisi + IfThen(n > 0, ', ', '') + AdHazirla(O.Kolonlar[n]);
            O.Sql := 'CREATE INDEX ' + AdHazirla(O.Ad) + ' ON ' + AdHazirla(O.Tablo) + ' (' + KolonYazisi + ')';
            if JoinOnerisi then
              O.Neden := TF('INDEKS_NEDEN_BAGLANTI', [O.Tablo, KolonYazisi])
            else
              O.Neden := TF('INDEKS_NEDEN', [O.Tablo, KolonYazisi]);
            Oneriler.Add(O);
          finally
            Adaylar.Free;
          end;
        end;
      end;
    end;
    Result.Oneriler := Oneriler.ToArray;
    Result.Notlar := Notlar.ToArray;
    Result.Basarili := True;
  finally
    Notlar.Free;
    Oneriler.Free;
  end;
end;

function IndeksOlustur(Bag: TAcikBaglanti; const Oneri: TIndeksOnerisi): TProsedurSonucu;
begin
  Result := Default(TProsedurSonucu);
  MetniCalistir(Bag, Oneri.Sql, Result);
end;

end.
