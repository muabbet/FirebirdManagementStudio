{ fProsedurSekme.pas - Sakli prosedur (3e-1), tetikleyici (3e-2) ve view (3f-2) duzenleme sekmesi: ustte "Kaydet" dugmesi, altta SQL editoru.
  Hangisi oldugu Tur alanindadir (ntTetikleyici, ntView; aksi halde prosedur); Yukle'den once atanir.
  Frame sadece arayuzu bilir; yedekleme ve calistirma uProsedur'dedir.

  Bu sekmede tek yol: Kaydet dugmesi ve Ctrl+S (ikisi de Kaydet'i cagirir). F5 bu sekmede bir sey calistirmaz,
  sadece ipucu yazar; boylece "calistir" ve "kaydet" karismaz. Mesajlar ana pencerenin sonuc alanina (AnaSonuc) yazilir. }
unit fProsedurSekme;

interface

uses
  System.SysUtils, System.Classes, Data.DB, Vcl.Controls, Vcl.Forms, Vcl.ExtCtrls, Vcl.StdCtrls,
  FireDAC.Comp.Client,
  uDil, uOnay, uBaglanti, uMetadata, uSorgu, uEditor, uKullanici, uDDL, uProsedur, uNesneYonet;

type
  TProsedurSekme = class(TFrame)
    pnlUst: TPanel;
    lblBilgi: TLabel;
    btnKaydet: TButton;
    pnlEditor: TPanel;
    procedure btnKaydetClick(Sender: TObject);
  private
    FEditor: TSqlEditor;
    procedure Yaz(const Metin: string);
    function Anahtar(const Bas, Son: string): string;
    procedure EditoruKur(Bag: TAcikBaglanti; const Metin: string);
    procedure OneriHazirla(Bag: TAcikBaglanti);
    procedure KolonlariGetir(const Tablo: string; Kolonlar: TStrings);
    function OnayMetni(const Metin: string): string;
    procedure YeniKaydet(Bag: TAcikBaglanti);
  public
    BaglantiAd: string;
    NesneAdi: string;
    { ntTetikleyici, ntView, ntIstisna, ntDomain: o tur sekmesi; baska her deger prosedur sekmesi (varsayilan).
      Yukle / YeniHazirla'dan once atanir. }
    Tur: TNesneTuru;
    { True: var olan nesneyi degil YENI nesneyi (CREATE EXCEPTION|DOMAIN) olusturan sekme; NesneAdi bostur. }
    Yeni: Boolean;
    { Mesajlar buraya (ana pencerenin sonuc alani) yazilir; ana pencere atar. }
    AnaSonuc: TStrings;
    { Calistirilan SQL'i mesaj alaninda gostermek icin ana pencere atar. }
    SqlYaz: TSqlGoster;
    { Yeni nesne basariyla olusturulunca cagrilir (ana pencere agaci yeniler, sekmeyi kapatir). }
    OnOlusturuldu: TNotifyEvent;
    { Nesnenin (prosedur/tetikleyici/view/exception) CREATE OR ALTER metnini editore koyar. Hata verirse istisna firlar, cagiran gosterir. }
    procedure Yukle(Bag: TAcikBaglanti; const Ad: string);
    { Yeni nesne sekmesi: editore bos sablon (CREATE EXCEPTION|DOMAIN ...) konur. }
    procedure YeniHazirla(Bag: TAcikBaglanti);
    procedure Kaydet;
    procedure F5Ipucu;
    procedure EditoreOdaklan;
    function Baslik: string;
    procedure YazilariYenile;
  end;

implementation

{$R *.dfm}

procedure TProsedurSekme.Yaz(const Metin: string);
begin
  if AnaSonuc <> nil then
    AnaSonuc.Add(Metin);
end;

{ Prosedur, tetikleyici ve view metinleri ayri dil anahtarlarindadir: Bas + tur eki (PRS, TRG, VIEW) + Son,
  ornek Anahtar('ONAY_', '_KAYDET') = ONAY_PRS_KAYDET. }
function TProsedurSekme.Anahtar(const Bas, Son: string): string;
begin
  Result := Bas + TurOnEki(Tur) + Son;
end;

{ Editoru kurar (anahtar kelimeler, Ctrl+Bosluk nesne adlari) ve metni yazar. }
procedure TProsedurSekme.EditoruKur(Bag: TAcikBaglanti; const Metin: string);
begin
  FEditor := TSqlEditor.Create(pnlEditor);
  FEditor.KolonGetirici := KolonlariGetir;
  OneriHazirla(Bag);
  FEditor.MetinYaz(Metin);
  YazilariYenile;
end;

procedure TProsedurSekme.Yukle(Bag: TAcikBaglanti; const Ad: string);
begin
  BaglantiAd := Bag.Tanim.Ad;
  NesneAdi := Ad;
  Yeni := False;
  EditoruKur(Bag, NesneDuzenleMetni(Bag, Tur, Ad));
end;

procedure TProsedurSekme.YeniHazirla(Bag: TAcikBaglanti);
begin
  BaglantiAd := Bag.Tanim.Ad;
  NesneAdi := '';
  Yeni := True;
  EditoruKur(Bag, YeniNesneSablonu(Tur));
end;

{ Ctrl+Bosluk listesi icin anahtar kelimeleri ve nesne adlarini editore verir (bkz. fSorguSekme). }
procedure TProsedurSekme.OneriHazirla(Bag: TAcikBaglanti);
var
  Adlar, Gecici: TStringList;
begin
  FEditor.AnahtarKelimeleriYukle(ExtractFilePath(ParamStr(0)) + 'anahtar_kelimeler.txt', Bag.Surum);
  Adlar := TStringList.Create;
  Gecici := TStringList.Create;
  try
    try
      TablolariGetir(Bag, Gecici);
      Adlar.AddStrings(Gecici);
      ViewlariGetir(Bag, Gecici);
      Adlar.AddStrings(Gecici);
      ProsedurleriGetir(Bag, Gecici);
      Adlar.AddStrings(Gecici);
      GeneratorleriGetir(Bag, Gecici);
      Adlar.AddStrings(Gecici);
    except
      { Nesne adlari alinamazsa sadece anahtar kelimeler onerilir; sekme yine acilir. }
    end;
    FEditor.NesneAdlariniVer(Adlar);
  finally
    Gecici.Free;
    Adlar.Free;
  end;
end;

procedure TProsedurSekme.KolonlariGetir(const Tablo: string; Kolonlar: TStrings);
var
  Bag: TAcikBaglanti;
  Kolon: TFDMemTable;
begin
  Bag := FbAcikBaglanti(BaglantiAd);
  if Bag = nil then
    Exit;
  try
    Kolon := KolonTablosuOlustur(Bag, Tablo, nil);
    try
      while not Kolon.Eof do
      begin
        Kolonlar.Add(Kolon.FieldByName('AD').AsString);
        Kolon.Next;
      end;
    finally
      Kolon.Free;
    end;
  except
    { Tablo bulunamadi ya da okunamadi: kolon onerisi acilmaz, hata gosterilmez. }
  end;
end;

function TProsedurSekme.Baslik: string;
begin
  if Yeni then
    Result := TF(Anahtar('', '_YENI_SEKME'), [BaglantiAd])
  else
    Result := TF(Anahtar('', '_SEKME'), [NesneAdi, BaglantiAd]);
end;

procedure TProsedurSekme.EditoreOdaklan;
begin
  FEditor.OdakVer;
end;

procedure TProsedurSekme.YazilariYenile;
begin
  btnKaydet.Caption := T('PRS_KAYDET');
  DugmeyiYaziyaUydur(btnKaydet);
  if Yeni then
    lblBilgi.Caption := T(Anahtar('', '_YENI_BILGI'))
  else
    lblBilgi.Caption := TF(Anahtar('', '_BILGI'), [NesneAdi]);
end;

procedure TProsedurSekme.F5Ipucu;
begin
  Yaz(T('MSG_PRS_F5_IPUCU'));
end;

{ Onay metni: ne olacagi acik yazilir. Metinde birden fazla komut varsa hepsinin calisacagi, tehlikeli
  (DROP, WHERE'siz DELETE/UPDATE) komut varsa ayrica uyari eklenir. }
function TProsedurSekme.OnayMetni(const Metin: string): string;
var
  Komutlar: TArray<string>;
  Komut, UyariAnahtari: string;
  Uyarilar: string;
begin
  Result := TF(Anahtar('ONAY_', '_KAYDET'), [NesneAdi]);
  Komutlar := KomutlaraBol(Metin);
  if Length(Komutlar) > 1 then
    Result := Result + sLineBreak + sLineBreak + TF('ONAY_PRS_COK_KOMUT', [Length(Komutlar)]);
  Uyarilar := '';
  for Komut in Komutlar do
  begin
    UyariAnahtari := TehlikeliSorguUyarisi(Komut);
    if UyariAnahtari <> '' then
      Uyarilar := Uyarilar + sLineBreak + '- ' + Copy(Trim(Komut), 1, 60) + ': ' + T(UyariAnahtari);
  end;
  if Uyarilar <> '' then
    Result := Result + sLineBreak + Uyarilar;
end;

{ Kaydet: kural kontrolu, net onay, eski tanim yedegi + calistirma (uProsedur), sonucu mesaj alanina yazma. }
procedure TProsedurSekme.Kaydet;
var
  Bag: TAcikBaglanti;
  Metin, Uyari: string;
  Sonuc: TProsedurSonucu;
begin
  Bag := FbAcikBaglanti(BaglantiAd);
  if Bag = nil then
  begin
    Yaz(TF('ERR_SORGU_BAGLANTI_YOK', [BaglantiAd]));
    Exit;
  end;
  if Yeni then
  begin
    YeniKaydet(Bag);
    Exit;
  end;
  Metin := FEditor.TumMetin;
  Uyari := NesneAdiniDogrula(Tur, Metin, NesneAdi);
  if (Uyari = '') and (Tur = ntTetikleyici) then
    Uyari := TetikleyiciTablosunuDogrula(Bag, Metin, NesneAdi);
  if Uyari <> '' then
  begin
    UyariGoster(Uyari);
    Exit;
  end;
  if not OnayIste(OnayMetni(Metin)) then
  begin
    Yaz(T('MSG_PRS_VAZGECILDI'));
    Exit;
  end;
  Sonuc := NesneKaydet(Bag, Tur, NesneAdi, Metin);
  if Sonuc.Basarili then
  begin
    Yaz(TF(Anahtar('MSG_', '_KAYDEDILDI'), [NesneAdi]));
    Yaz(TF('MSG_PRS_YEDEKLENDI', [Sonuc.YedekDosyasi]));
  end
  else
  begin
    Yaz(TF(Anahtar('ERR_', '_KAYDEDILEMEDI'), [NesneAdi]) + ' ' + Sonuc.Cumle);
    if Sonuc.Ayrinti <> '' then
      Yaz(T('AYRINTI') + ': ' + Sonuc.Ayrinti);
    if Length(Sonuc.Komutlar) = 0 then
      Yaz(T('MSG_PRS_DOKUNULMADI'))
    else
      Yaz(T(Anahtar('MSG_', '_GERI_ALINDI')));
    if Sonuc.Satir > 0 then
    begin
      Yaz(TF('MSG_PRS_HATA_SATIRI', [Sonuc.Satir]));
      FEditor.SatiraGit(Sonuc.Satir);
    end;
  end;
  if (Length(Sonuc.Komutlar) > 0) and Assigned(SqlYaz) then
    SqlYaz(Sonuc.Komutlar);
end;

{ Yeni nesne: ad kurali (CREATE EXCEPTION|DOMAIN <ad>), net onay, olusturma. Yedek yok (eski tanim yok). Basarida
  OnOlusturuldu cagrilir; hatada sekme acik kalir, metin duzeltilip yeniden denenir. }
procedure TProsedurSekme.YeniKaydet(Bag: TAcikBaglanti);
var
  Metin, Ad, Uyari: string;
  Sonuc: TProsedurSonucu;
begin
  Metin := FEditor.TumMetin;
  Uyari := YeniNesneAdiniDogrula(Tur, Metin, Ad);
  if Uyari <> '' then
  begin
    UyariGoster(Uyari);
    Exit;
  end;
  if not OnayIste(TF(Anahtar('ONAY_', '_YENI'), [Ad])) then
  begin
    Yaz(T('MSG_PRS_VAZGECILDI'));
    Exit;
  end;
  Sonuc := YeniNesneKaydet(Bag, Tur, Metin);
  if Sonuc.Basarili then
    Yaz(TF(Anahtar('MSG_', '_OLUSTURULDU'), [Ad]))
  else
  begin
    Yaz(TF(Anahtar('ERR_', '_OLUSTURULAMADI'), [Ad]) + ' ' + Sonuc.Cumle);
    if Sonuc.Ayrinti <> '' then
      Yaz(T('AYRINTI') + ': ' + Sonuc.Ayrinti);
    Yaz(T('MSG_YENI_GERI_ALINDI'));
    if Sonuc.Satir > 0 then
    begin
      Yaz(TF('MSG_PRS_HATA_SATIRI', [Sonuc.Satir]));
      FEditor.SatiraGit(Sonuc.Satir);
    end;
  end;
  if (Length(Sonuc.Komutlar) > 0) and Assigned(SqlYaz) then
    SqlYaz(Sonuc.Komutlar);
  if Sonuc.Basarili and Assigned(OnOlusturuldu) then
    OnOlusturuldu(Self);
end;

procedure TProsedurSekme.btnKaydetClick(Sender: TObject);
begin
  Kaydet;
end;

end.
