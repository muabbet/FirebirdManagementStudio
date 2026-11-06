unit uAktifBaglanti;

{ Veritabanindaki aktif baglantilar ve islemler (Asama 7c): kim bagli, ne zamandan beri, hangi programdan, su an sorgu calistiriyor mu,
  en eski acik islemi ne zaman basladi; istenirse bir baglantiyi koparma.

  Hedeflenen Firebird surumleri: 2.5, 3.0, 4.0, 5.0 (MON$ izleme tablolari; 2.1'den beri var)

  Kurallar (sade ve guvenli):
    - Liste salt okunur izleme tablolarindan (MON$ATTACHMENTS, MON$TRANSACTIONS, MON$STATEMENTS) okunur; yalnizca bu yordamin kendi
      sorgusu calisir. SYSDBA ve veritabani sahibi tum baglantilari gorur; digerleri yalniz kendi baglantisini gorur (Firebird kurali).
    - Baglanti koparma: DELETE FROM MON$ATTACHMENTS (2.5 ve ustu). O baglantinin yapilmamis isleri geri alinir, programi hata gorur.
      Kendi baglantimiz koparilamaz.
  Hata istisna olarak firlamaz (koparma); liste okuma hatasi istisna olarak gelir. }

interface

uses
  System.SysUtils, System.Classes, uBaglanti, uProsedur, FireDAC.Comp.Client;

{ Aktif baglantilar (sistem baglantilari hari). Kolonlar: ID, KULLANICI, PROGRAM, ADRES, BAGLANMA, CALISIYOR (1 = su an sorgu
  calisiyor, 0 = bosta), ISLEM_SAYISI, ESKI_ISLEM (en eski acik islemin baslangici), SORGU (calisan sorgu metni), BEN (1 = bu baglanti).
  Sorgu Sahip ile yok olur ve acik doner. Hata istisna olarak gelir. }
function AktifBaglantiSorgusu(Bag: TAcikBaglanti; Sahip: TComponent): TFDQuery;

{ Bu uygulamanin kendi baglanti numarasi (koparilamaz). }
function BenimBaglantiNo(Bag: TAcikBaglanti): Int64;

{ Baglanti koparma komutu (onay penceresinde ve SQL mesajinda gosterilir). }
function KoparmaKomutu(Numara: Int64): string;

{ Verilen numarali baglantiyi koparir. Kendi baglantimizda hicbir sey yapmaz ve anlasilir cumleyle basarisiz doner. }
function BaglantiKopar(Bag: TAcikBaglanti; Numara: Int64): TProsedurSonucu;

implementation

uses
  System.Variants, Data.DB, uDil;

const
  SORGU_BASI = 'select a.mon$attachment_id as ID, trim(a.mon$user) as KULLANICI, trim(a.mon$remote_process) as PROGRAM, ' +
    'trim(a.mon$remote_address) as ADRES, a.mon$timestamp as BAGLANMA, a.mon$state as CALISIYOR, ' +
    '(select count(*) from mon$transactions t where t.mon$attachment_id = a.mon$attachment_id) as ISLEM_SAYISI, ' +
    '(select min(t.mon$timestamp) from mon$transactions t where t.mon$attachment_id = a.mon$attachment_id) as ESKI_ISLEM, ' +
    '(select first 1 s.mon$sql_text from mon$statements s where s.mon$attachment_id = a.mon$attachment_id and s.mon$state = 1) as SORGU, ' +
    'iif(a.mon$attachment_id = current_connection, 1, 0) as BEN from mon$attachments a ';
  SORGU_SONU = ' order by a.mon$attachment_id';

function SorguAcDene(Bag: TAcikBaglanti; Sahip: TComponent; const Kosul: string): TFDQuery;
begin
  Result := TFDQuery.Create(Sahip);
  try
    Result.Connection := Bag.Baglanti;
    Result.SQL.Text := SORGU_BASI + Kosul + SORGU_SONU;
    Result.Open;
  except
    Result.Free;
    raise;
  end;
end;

function AktifBaglantiSorgusu(Bag: TAcikBaglanti; Sahip: TComponent): TFDQuery;
begin
  { Sistem baglantilari (cop toplayici gibi) MON$SYSTEM_FLAG ile ayrilir; bu kolon her surumde yoksa filtresiz denenir. }
  try
    Result := SorguAcDene(Bag, Sahip, 'where a.mon$system_flag = 0');
  except
    Result := SorguAcDene(Bag, Sahip, '');
  end;
end;

function BenimBaglantiNo(Bag: TAcikBaglanti): Int64;
begin
  Result := StrToInt64Def(VarToStr(Bag.Baglanti.ExecSQLScalar('select current_connection from rdb$database')), 0);
end;

function KoparmaKomutu(Numara: Int64): string;
begin
  Result := 'DELETE FROM MON$ATTACHMENTS WHERE MON$ATTACHMENT_ID = ' + IntToStr(Numara);
end;

function BaglantiKopar(Bag: TAcikBaglanti; Numara: Int64): TProsedurSonucu;
begin
  Result := Default(TProsedurSonucu);
  if Numara = BenimBaglantiNo(Bag) then
  begin
    Result.Cumle := T('ERR_AKTIF_KENDI');
    Exit;
  end;
  MetniCalistir(Bag, KoparmaKomutu(Numara), Result);
end;

end.
