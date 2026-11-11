{ uAra.pas - Veritabaninda arama (gunluk is): "bu ad nerede geciyor?"
  Tablo, view, prosedur, trigger ve exception adlarinda, kolon adlarinda ve (istenirse) view/prosedur/trigger
  kaynak metinlerinde aranir. Buyuk kucuk harf fark etmez, yazinin bir yeri gecmesi yeter. Yalniz okur, hicbir sey yazmaz.
  Sistem nesneleri (RDB$..., MON$...) aranmaz. Sorgular sistem tablolarina (RDB$) dogrudan yazilir; 2.5, 3.0, 4.0, 5.0'te ayni. }
unit uAra;

interface

uses
  System.SysUtils, System.Classes, System.Generics.Collections, Data.DB,
  FireDAC.Stan.Intf, FireDAC.Stan.Option, FireDAC.Stan.Param, FireDAC.Stan.Error,
  FireDAC.DatS, FireDAC.Phys.Intf, FireDAC.DApt.Intf, FireDAC.Comp.DataSet, FireDAC.Comp.Client,
  uBaglanti, uDDL;

const
  { Cok genis bir arama listeyi bogmasin: bu kadar sonuctan sonra durulur. }
  ARAMA_SINIRI = 500;
  { Bu kadar kisa yazi aranmaz (her seyi bulur). }
  ARAMA_EN_KISA = 2;

type
  TAramaYeri = (ayAd, ayKolon, ayKaynak);

  { Tur: nesnenin turu (kolonda tablo ya da view). Ad: nesnenin adi. Ayrinti: kolon adi ya da kaynaktaki ilk eslesen satir. }
  TAramaSonucu = record
    Tur: TNesneTuru;
    Ad: string;
    Yer: TAramaYeri;
    Ayrinti: string;
  end;

{ Yazi yeterince uzun degilse bos doner. Sinira ulasilirsa Kesildi True olur. Hata olursa istisna firlar. }
function MetadataAra(Bag: TAcikBaglanti; const Yazi: string; KaynaktaDaAra: Boolean; out Kesildi: Boolean): TArray<TAramaSonucu>;

implementation

{ Kaynak metninde yazinin gectigi ilk satir (kisaltilmis, sol bosluklari atilmis). }
function EslesenSatir(const Kaynak, Yazi: string): string;
var
  Satirlar: TStringList;
  Satir: string;
begin
  Result := '';
  Satirlar := TStringList.Create;
  try
    Satirlar.Text := Kaynak;
    for Satir in Satirlar do
      if Pos(UpperCase(Yazi), UpperCase(Satir)) > 0 then
      begin
        Result := Trim(Satir);
        if Length(Result) > 120 then
          Result := Copy(Result, 1, 117) + '...';
        Exit;
      end;
  finally
    Satirlar.Free;
  end;
end;

procedure Ekle(Liste: TList<TAramaSonucu>; Tur: TNesneTuru; const Ad: string; Yer: TAramaYeri; const Ayrinti: string);
var
  Sonuc: TAramaSonucu;
begin
  Sonuc.Tur := Tur;
  Sonuc.Ad := Ad;
  Sonuc.Yer := Yer;
  Sonuc.Ayrinti := Ayrinti;
  Liste.Add(Sonuc);
end;

{ Sql: ":Y" parametreli SELECT. Ilk kolon nesne adi; Yer = ayKolon ise ikinci kolon kolon adi ve ucuncusu 0 (tablo) / 1 (view),
  Yer = ayKaynak ise ikinci kolon kaynak metnidir. }
procedure Topla(Bag: TAcikBaglanti; const Sql, Yazi: string; Tur: TNesneTuru; Yer: TAramaYeri; Liste: TList<TAramaSonucu>);
var
  Sorgu: TFDQuery;
  Ad, Ayrinti: string;
  TurU: TNesneTuru;
begin
  Sorgu := TFDQuery.Create(nil);
  try
    Sorgu.Connection := Bag.Baglanti;
    Sorgu.UpdateOptions.ReadOnly := True;
    Sorgu.FetchOptions.Mode := fmAll;
    Sorgu.SQL.Text := Sql;
    Sorgu.ParamByName('Y').AsString := Yazi;
    Sorgu.Open;
    while (not Sorgu.Eof) and (Liste.Count < ARAMA_SINIRI + 1) do
    begin
      Ad := Trim(Sorgu.Fields[0].AsString);
      Ayrinti := '';
      TurU := Tur;
      case Yer of
        ayKolon:
          begin
            Ayrinti := Trim(Sorgu.Fields[1].AsString);
            if Sorgu.Fields[2].AsInteger = 1 then
              TurU := ntView
            else
              TurU := ntTablo;
          end;
        ayKaynak:
          Ayrinti := EslesenSatir(Sorgu.Fields[1].AsString, Yazi);
      end;
      Ekle(Liste, TurU, Ad, Yer, Ayrinti);
      Sorgu.Next;
    end;
  finally
    Sorgu.Free;
  end;
end;

function MetadataAra(Bag: TAcikBaglanti; const Yazi: string; KaynaktaDaAra: Boolean; out Kesildi: Boolean): TArray<TAramaSonucu>;
var
  Liste: TList<TAramaSonucu>;
  Aranan: string;
begin
  Kesildi := False;
  Aranan := Trim(Yazi);
  if Length(Aranan) < ARAMA_EN_KISA then
    Exit(nil);
  Liste := TList<TAramaSonucu>.Create;
  try
    { Adlar: tablo ve view birbirinden view_blr ile ayrilir (view'larda dolu). }
    Topla(Bag, 'select trim(rdb$relation_name) from rdb$relations where coalesce(rdb$system_flag, 0) = 0 ' +
      'and rdb$view_blr is null and rdb$relation_name containing :Y order by 1', Aranan, ntTablo, ayAd, Liste);
    Topla(Bag, 'select trim(rdb$relation_name) from rdb$relations where coalesce(rdb$system_flag, 0) = 0 ' +
      'and rdb$view_blr is not null and rdb$relation_name containing :Y order by 1', Aranan, ntView, ayAd, Liste);
    Topla(Bag, 'select trim(rdb$procedure_name) from rdb$procedures where coalesce(rdb$system_flag, 0) = 0 ' +
      'and rdb$procedure_name containing :Y order by 1', Aranan, ntProsedur, ayAd, Liste);
    Topla(Bag, 'select trim(rdb$trigger_name) from rdb$triggers where coalesce(rdb$system_flag, 0) = 0 ' +
      'and rdb$trigger_name containing :Y order by 1', Aranan, ntTetikleyici, ayAd, Liste);
    Topla(Bag, 'select trim(rdb$exception_name) from rdb$exceptions where coalesce(rdb$system_flag, 0) = 0 ' +
      'and rdb$exception_name containing :Y order by 1', Aranan, ntIstisna, ayAd, Liste);
    Topla(Bag, 'select trim(f.rdb$relation_name), trim(f.rdb$field_name), ' +
      'case when r.rdb$view_blr is null then 0 else 1 end from rdb$relation_fields f ' +
      'join rdb$relations r on r.rdb$relation_name = f.rdb$relation_name ' +
      'where coalesce(r.rdb$system_flag, 0) = 0 and f.rdb$field_name containing :Y order by 1, 2',
      Aranan, ntTablo, ayKolon, Liste);
    if KaynaktaDaAra then
    begin
      Topla(Bag, 'select trim(rdb$relation_name), rdb$view_source from rdb$relations where coalesce(rdb$system_flag, 0) = 0 ' +
        'and rdb$view_blr is not null and rdb$view_source containing :Y order by 1', Aranan, ntView, ayKaynak, Liste);
      Topla(Bag, 'select trim(rdb$procedure_name), rdb$procedure_source from rdb$procedures where coalesce(rdb$system_flag, 0) = 0 ' +
        'and rdb$procedure_source containing :Y order by 1', Aranan, ntProsedur, ayKaynak, Liste);
      Topla(Bag, 'select trim(rdb$trigger_name), rdb$trigger_source from rdb$triggers where coalesce(rdb$system_flag, 0) = 0 ' +
        'and rdb$trigger_source containing :Y order by 1', Aranan, ntTetikleyici, ayKaynak, Liste);
    end;
    Kesildi := Liste.Count > ARAMA_SINIRI;
    if Kesildi then
      Liste.Count := ARAMA_SINIRI;
    Result := Liste.ToArray;
  finally
    Liste.Free;
  end;
end;

end.
