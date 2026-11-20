{ uVeriFark.pas - Iki tablonun verisini birincil anahtarla karsilastirma (Asama 7u).

  Hedeflenen Firebird surumleri: 2.5, 3.0, 4.0, 5.0 (iki tablo farkli surumde olabilir)
  Denenen Firebird surumleri: 5.0.4 (3.0 ve 4.0'da denenecek)

  Kurallar (sade ve guvenli):
    - Iki tabloya da YALNIZ OKUNUR; hicbir komut calistirilmaz. Sonuc, HEDEF tabloyu KAYNAGA esitleyecek bir script'tir
      (INSERT: yalniz kaynakta olan, UPDATE: farkli olan, DELETE: yalniz hedefte olan; DELETE yalniz istenirse yazilir).
    - Iki tabloda da ayni birincil anahtar kolonlari olmali. Karsilastirilan kolonlar iki tabloda ortak adli olanlardir
      (hesaplanan, GENERATED ALWAYS kimlik ve ikili BLOB kolonlari karsilastirilmaz).
    - Hedef tablo bellege alinir (anahtar -> degerler), kaynak satir satir gezilir. Bellek icin her tabloda en cok
      VERI_FARK_SATIR_SINIRI satir; fazlasinda hicbir sey yapilmaz ve nedeni soylenir.
    - Degerler SQL degeri yazisi olarak karsilastirilir (uAktar.AlanSqlDegeri): 1 ile 1.0 farkli sayilmaz, NULL ile bos metin farklidir.
  Hata istisna olarak firlamaz, sonuc kaydina yazilir. }
unit uVeriFark;

interface

uses
  System.SysUtils, System.Classes, uBaglanti;

const
  VERI_FARK_SATIR_SINIRI = 200000;
  { Script'te en cok bu kadar komut yazilir (editor cok buyuk metinde yavaslar); sayilar yine de tamdir. }
  VERI_FARK_KOMUT_SINIRI = 50000;

type
  TVeriFarkSonucu = record
    Basarili: Boolean;
    { Basarisizsa: anlasilir cumle ve ham mesaj. }
    Cumle: string;
    Ayrinti: string;
    SadeceKaynakta: Int64;
    SadeceHedefte: Int64;
    Farkli: Int64;
    Ayni: Int64;
    { Hedefi kaynaga esitleyen komutlar (yorum satirlariyla). Fark yoksa bos. }
    Script: string;
    Uyarilar: TArray<string>;
  end;

{ SilmeYaz: yalniz hedefte olan satirlar icin DELETE de yazilsin mi. }
function VeriFarkiBul(Kaynak: TAcikBaglanti; const KaynakTablo: string; Hedef: TAcikBaglanti; const HedefTablo: string;
  SilmeYaz: Boolean): TVeriFarkSonucu;

implementation

uses
  System.Generics.Collections, System.StrUtils, Data.DB, FireDAC.Comp.Client, uDil, uMetadata, uSorgu, uAktar;

const
  { Anahtar ve deger listelerinde ayirac: SQL degerinde bulunmaz. }
  AYRAC = #1;

type
  EVeriFark = class(Exception);

  TSatirOlayi = reference to procedure(const Degerler: TArray<string>; Sorgu: TFDQuery);

function Listede(const Liste: TArray<string>; const Ad: string): Boolean;
var
  Eleman: string;
begin
  Result := False;
  for Eleman in Liste do
    if SameText(Eleman, Ad) then
      Exit(True);
end;

function AdListesi(const Adlar: TArray<string>): string;
var
  Ad: string;
begin
  Result := '';
  for Ad in Adlar do
  begin
    if Result <> '' then
      Result := Result + ', ';
    Result := Result + TirnakliAd(Ad);
  end;
end;

function BirincilAnahtar(Bag: TAcikBaglanti; const Tablo: string): TArray<string>;
var
  Bilgi: TTabloBilgisi;
  Kisit: TKisitBilgisi;
begin
  SetLength(Result, 0);
  Bilgi := TabloBilgisiOku(Bag, Tablo);
  for Kisit in Bilgi.Kisitlar do
    if Kisit.Tur = ktBirincil then
      Exit(Kisit.Kolonlar);
end;

{ Tabloyu salt okunur, anlik goruntulu islemle gezer; her satirin degerleri (Kolonlar sirasiyla SQL degeri olarak)
  Olay'a verilir. Degerler dizisi her satirda ayni diziyi kullanir: saklanacaksa kopyalanmalidir. }
procedure TabloyuGez(Bag: TAcikBaglanti; const Tablo: string; const Kolonlar: TArray<string>; Olay: TSatirOlayi);
var
  Islem: TFDTransaction;
  Sorgu: TFDQuery;
  Degerler: TArray<string>;
  i: Integer;
begin
  Islem := TFDTransaction.Create(nil);
  Sorgu := TFDQuery.Create(nil);
  try
    SaltOkunurSorguAc(Bag, 'SELECT ' + AdListesi(Kolonlar) + ' FROM ' + TirnakliAd(Tablo), Islem, Sorgu);
    SetLength(Degerler, Sorgu.FieldCount);
    while not Sorgu.Eof do
    begin
      for i := 0 to Sorgu.FieldCount - 1 do
        Degerler[i] := AlanSqlDegeri(Sorgu.Fields[i]);
      Olay(Degerler, Sorgu);
      Sorgu.Next;
    end;
  finally
    Sorgu.Free;
    if Islem.Active then
      Islem.Rollback;
    Islem.Free;
  end;
end;

{ Degerler dizisinin [Bas, Bas + Sayi) bolumunu AYRAC ile birlestirir. }
function Birlestir(const Degerler: TArray<string>; Bas, Sayi: Integer): string;
var
  i: Integer;
begin
  Result := '';
  for i := Bas to Bas + Sayi - 1 do
  begin
    if i > Bas then
      Result := Result + AYRAC;
    Result := Result + Degerler[i];
  end;
end;

{ "A" = deger AND "B" = deger (anahtar kolonlari ve degerleri). }
function Kosul(const Anahtar: TArray<string>; const Degerler: TArray<string>): string;
var
  i: Integer;
begin
  Result := '';
  for i := 0 to High(Anahtar) do
  begin
    if i > 0 then
      Result := Result + ' AND ';
    Result := Result + TirnakliAd(Anahtar[i]) + ' = ' + Degerler[i];
  end;
end;

function VeriFarkiBul(Kaynak: TAcikBaglanti; const KaynakTablo: string; Hedef: TAcikBaglanti; const HedefTablo: string;
  SilmeYaz: Boolean): TVeriFarkSonucu;
var
  KaynakKolonlari, HedefKolonlari: TArray<TKolonBilgisi>;
  Anahtar, HedefAnahtar: TArray<string>;
  Diger, Tum: TArray<string>;
  Kolon, HedefKolon: TKolonBilgisi;
  Liste: TList<string>;
  Komutlar: TStringList;
  Uyarilar: TList<string>;
  HedefSatirlari: TDictionary<string, string>;
  Ikili: TList<string>;
  IkiliBelli: Boolean;
  IkiliMi: TArray<Boolean>;
  KomutSiniri: Boolean;
  KomutEkle: TProc<string>;
  Say, NAyni, NFarkli, NKaynakta: Int64;
  i: Integer;
  Hedefte, Ad, Eksik: string;

begin
  { Komut sinirina varilinca yenileri yazilmaz (sayilar yine de sayilir). }
  KomutEkle :=
    procedure(Sql: string)
    begin
      if Komutlar.Count >= VERI_FARK_KOMUT_SINIRI then
        KomutSiniri := True
      else
        Komutlar.Add(Sql);
    end;
  FillChar(Result, SizeOf(Result), 0);
  Liste := TList<string>.Create;
  Komutlar := TStringList.Create;
  Uyarilar := TList<string>.Create;
  Ikili := TList<string>.Create;
  HedefSatirlari := TDictionary<string, string>.Create;
  try
    try
      { 1. Ortak anahtar. }
      Anahtar := BirincilAnahtar(Kaynak, KaynakTablo);
      HedefAnahtar := BirincilAnahtar(Hedef, HedefTablo);
      if (Length(Anahtar) = 0) or (Length(HedefAnahtar) = 0) then
        raise EVeriFark.Create(T('ERR_VF_ANAHTAR_YOK'));
      Eksik := '';
      if Length(Anahtar) <> Length(HedefAnahtar) then
        Eksik := '1';
      for Ad in Anahtar do
        if not Listede(HedefAnahtar, Ad) then
          Eksik := '1';
      if Eksik <> '' then
        raise EVeriFark.Create(T('ERR_VF_ANAHTAR_FARKLI'));

      { 2. Karsilastirilacak kolonlar: iki tabloda ortak adli, hesaplanan ve GENERATED ALWAYS olmayan (anahtar disinda). }
      KaynakKolonlari := KolonlariOku(Kaynak, KaynakTablo);
      HedefKolonlari := KolonlariOku(Hedef, HedefTablo);
      for Kolon in KaynakKolonlari do
        for HedefKolon in HedefKolonlari do
          if SameText(Kolon.Ad, HedefKolon.Ad) and not Listede(Anahtar, Kolon.Ad) then
          begin
            if (Kolon.Hesaplanan = '') and (HedefKolon.Hesaplanan = '') and not (Kolon.Kimlik and Kolon.KimlikHep) and
              not (HedefKolon.Kimlik and HedefKolon.KimlikHep) then
              Liste.Add(Kolon.Ad);
            Break;
          end;
      Diger := Liste.ToArray;
      SetLength(Tum, Length(Anahtar) + Length(Diger));
      for i := 0 to High(Anahtar) do
        Tum[i] := Anahtar[i];
      for i := 0 to High(Diger) do
        Tum[Length(Anahtar) + i] := Diger[i];

      { 3. Hedef tabloyu belle al: anahtar -> degerler. }
      TabloyuGez(Hedef, HedefTablo, Tum,
        procedure(const Degerler: TArray<string>; Sorgu: TFDQuery)
        begin
          if HedefSatirlari.Count >= VERI_FARK_SATIR_SINIRI then
            raise EVeriFark.Create(TF('ERR_VF_COK_BUYUK', [HedefTablo, VERI_FARK_SATIR_SINIRI]));
          HedefSatirlari.AddOrSetValue(Birlestir(Degerler, 0, Length(Anahtar)),
            Birlestir(Degerler, Length(Anahtar), Length(Diger)));
        end);

      { 4. Kaynagi gez. }
      IkiliBelli := False;
      Say := 0;
      NAyni := 0;
      NFarkli := 0;
      NKaynakta := 0;
      TabloyuGez(Kaynak, KaynakTablo, Tum,
        procedure(const Degerler: TArray<string>; Sorgu: TFDQuery)
        var
          Anah, Degerleri, Eski, Ekler, Atamalar: string;
          Eskiler: TArray<string>;
          j: Integer;
        begin
          Inc(Say);
          if Say > VERI_FARK_SATIR_SINIRI then
            raise EVeriFark.Create(TF('ERR_VF_COK_BUYUK', [KaynakTablo, VERI_FARK_SATIR_SINIRI]));
          if not IkiliBelli then
          begin
            IkiliBelli := True;
            SetLength(IkiliMi, Sorgu.FieldCount);
            for j := 0 to Sorgu.FieldCount - 1 do
            begin
              IkiliMi[j] := AlanIkiliMi(Sorgu.Fields[j]);
              if IkiliMi[j] then
                Ikili.Add(Sorgu.Fields[j].FieldName);
            end;
          end;
          Anah := Birlestir(Degerler, 0, Length(Anahtar));
          Degerleri := Birlestir(Degerler, Length(Anahtar), Length(Diger));
          if HedefSatirlari.TryGetValue(Anah, Eski) then
          begin
            HedefSatirlari.Remove(Anah);
            if Eski = Degerleri then
              Inc(NAyni)
            else
            begin
              Inc(NFarkli);
              { Yalniz farkli kolonlar guncellenir. }
              Eskiler := Eski.Split([AYRAC]);
              Atamalar := '';
              for j := 0 to High(Diger) do
                if (Eskiler[j] <> Degerler[Length(Anahtar) + j]) and not IkiliMi[Length(Anahtar) + j] then
                begin
                  if Atamalar <> '' then
                    Atamalar := Atamalar + ', ';
                  Atamalar := Atamalar + TirnakliAd(Diger[j]) + ' = ' + Degerler[Length(Anahtar) + j];
                end;
              if Atamalar <> '' then
                KomutEkle('UPDATE ' + TirnakliAd(HedefTablo) + ' SET ' + Atamalar + ' WHERE ' + Kosul(Anahtar, Degerler) + ';');
            end;
          end
          else
          begin
            Inc(NKaynakta);
            Ekler := '';
            Atamalar := '';
            for j := 0 to High(Tum) do
              if not IkiliMi[j] then
              begin
                if Ekler <> '' then
                begin
                  Ekler := Ekler + ', ';
                  Atamalar := Atamalar + ', ';
                end;
                Ekler := Ekler + TirnakliAd(Tum[j]);
                Atamalar := Atamalar + Degerler[j];
              end;
            KomutEkle('INSERT INTO ' + TirnakliAd(HedefTablo) + ' (' + Ekler + ') VALUES (' + Atamalar + ');');
          end;
        end);

      { 5. Hedefte kalanlar: yalniz hedefte olanlar. }
      Result.Ayni := NAyni;
      Result.Farkli := NFarkli;
      Result.SadeceKaynakta := NKaynakta;
      Result.SadeceHedefte := HedefSatirlari.Count;
      if SilmeYaz then
        for Hedefte in HedefSatirlari.Keys do
          KomutEkle('DELETE FROM ' + TirnakliAd(HedefTablo) + ' WHERE ' + Kosul(Anahtar, Hedefte.Split([AYRAC])) + ';');

      { 6. Script ve uyarilar. }
      if Ikili.Count > 0 then
      begin
        Eksik := '';
        for Ad in Ikili do
          Eksik := Eksik + IfThen(Eksik <> '', ', ', '') + Ad;
        Uyarilar.Add(TF('VF_UYARI_IKILI', [Eksik]));
      end;
      if KomutSiniri then
        Uyarilar.Add(TF('VF_UYARI_KOMUT_SINIRI', [VERI_FARK_KOMUT_SINIRI]));
      if Komutlar.Count > 0 then
      begin
        Result.Script := '-- ' + TF('VF_SCRIPT_BASLIK', [Kaynak.Tanim.Ad + '.' + KaynakTablo, Hedef.Tanim.Ad + '.' + HedefTablo]) +
          sLineBreak + '-- ' + TF('VF_SCRIPT_OZET', [Result.SadeceKaynakta, Result.Farkli, Result.SadeceHedefte]) + sLineBreak +
          '-- ' + T('VF_SCRIPT_CALISTIRMA') + sLineBreak;
        if (Result.SadeceHedefte > 0) and not SilmeYaz then
          Result.Script := Result.Script + '-- ' + T('VF_SCRIPT_SILME_YOK') + sLineBreak;
        Result.Script := Result.Script + sLineBreak + Komutlar.Text;
      end;
      Result.Uyarilar := Uyarilar.ToArray;
      Result.Basarili := True;
    except
      on E: EVeriFark do
        Result.Cumle := E.Message;
      on E: Exception do
      begin
        Result.Cumle := HataMetniniCevir(E);
        Result.Ayrinti := E.Message;
      end;
    end;
  finally
    HedefSatirlari.Free;
    Ikili.Free;
    Uyarilar.Free;
    Komutlar.Free;
    Liste.Free;
  end;
end;

end.
