program GorunumTest;

{ Gorunum duzenlemeleri testi (komut satiri): tablo listesi sekmesi (fTabloListe), tablo ozetleri (uMetadata),
  baglanti yolu metni (uBaglanti), dil anahtarlari. GOMULU kipte kendi gecici veritabanini acar; kayitli baglanti dosyasi
  gecici klasorde tutulur (VeriKlasoruAyarla). Cikis kodu: hata sayisi (0 = hepsi gecti). Sonuc FBTEST_CIKTI dosyasina yazilir. }

{$APPTYPE CONSOLE}

uses
  System.SysUtils, System.Classes, System.IOUtils, System.StrUtils,
  FireDAC.Stan.Intf, FireDAC.Stan.Option, FireDAC.Stan.Error, FireDAC.Comp.Client, FireDAC.Phys.FB,
  FireDAC.ConsoleUI.Wait, Vcl.Forms, Vcl.Controls, Vcl.ComCtrls,
  uDil, uBaglanti, uMetadata, uKullanici, fTabloListe;

var
  Cikti: TStringList;
  Hatalar, KontrolSayisi: Integer;
  Klasor: string;

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

procedure VeritabaniOlustur(const T: TBaglantiTanimi);
var
  Surucu: TFDPhysFBDriverLink;
  Baglanti: TFDConnection;
begin
  Surucu := TFDPhysFBDriverLink.Create(nil);
  Baglanti := TFDConnection.Create(nil);
  try
    Surucu.VendorLib := ExtractFilePath(ParamStr(0)) + 'istemci\fbclient.dll';
    Baglanti.DriverName := 'FB';
    Baglanti.LoginPrompt := False;
    Baglanti.Params.Values['Database'] := T.VeritabaniYolu;
    Baglanti.Params.Values['User_Name'] := T.Kullanici;
    Baglanti.Params.Values['Password'] := T.Sifre;
    Baglanti.Params.Values['OpenMode'] := 'Create';
    Baglanti.Params.Values['CharacterSet'] := T.KarakterSeti;
    Baglanti.Open;
    Baglanti.Close;
  finally
    Baglanti.Free;
    Surucu.Free;
  end;
end;

procedure Komut(Bag: TAcikBaglanti; const Sql: string);
var
  Sorgu: TFDQuery;
begin
  Sorgu := KomutHazirla(Bag, Sql);
  try
    Sorgu.ExecSQL;
  finally
    Sorgu.Free;
  end;
end;

procedure YolBolumu;
var
  Tanim: TBaglantiTanimi;
begin
  Cikti.Add('');
  Cikti.Add('=== A) Baglanti yolu metni ===');
  Tanim := Default(TBaglantiTanimi);
  Tanim.VeritabaniYolu := 'C:\Veri\FABRIKA.FDB';
  Kontrol('Yol: sunucusuz baglantida yalniz dosya yolu', BaglantiYolu(Tanim) = 'C:\Veri\FABRIKA.FDB');
  Tanim.Sunucu := '192.168.1.5';
  Tanim.Port := 3052;
  Kontrol('Yol: sunuculuda sunucu/port:yol', BaglantiYolu(Tanim) = '192.168.1.5/3052:C:\Veri\FABRIKA.FDB');
end;

procedure ListeBolumu;
var
  Tanim: TBaglantiTanimi;
  Bag: TAcikBaglanti;
  Ozetler: TArray<TTabloOzeti>;
  Form: TForm;
  Sekme: TTabloListeSekme;
begin
  Cikti.Add('');
  Cikti.Add('=== B) Tablo listesi sekmesi ===');
  Tanim := Default(TBaglantiTanimi);
  Tanim.Ad := 'gorunum_a';
  Tanim.Port := 3050;
  Tanim.VeritabaniYolu := TPath.Combine(Klasor, 'GORUNUM_' + FormatDateTime('hhnnsszzz', Now) + '.fdb');
  Tanim.Kullanici := 'SYSDBA';
  Tanim.Sifre := 'masterkey';
  Tanim.KarakterSeti := VARSAYILAN_KARAKTER_SETI;
  VeritabaniOlustur(Tanim);
  Bag := FbBaglan(Tanim);
  Komut(Bag, 'create table FBY_L1 (ID integer not null, AD varchar(20), TUTAR numeric(10,2) default 0)');
  Komut(Bag, 'create table FBY_L2 (A integer)');
  Komut(Bag, 'create table FBY_L3 (A integer, B integer, C integer, D varchar(5))');
  Komut(Bag, 'comment on table FBY_L1 is ''deneme aciklamasi''');
  Bag.Baglanti.Commit;

  Ozetler := TabloOzetleriniOku(Bag);
  Kontrol('Ozet: uc tablo geldi', Length(Ozetler) = 3);
  Kontrol('Ozet: ad ve alan sayisi dogru', (Ozetler[0].Ad = 'FBY_L1') and (Ozetler[0].AlanSayisi = 3) and
    (Ozetler[2].Ad = 'FBY_L3') and (Ozetler[2].AlanSayisi = 4));
  Kontrol('Ozet: aciklama okundu, olmayan bos', (Ozetler[0].Aciklama = 'deneme aciklamasi') and (Ozetler[1].Aciklama = ''));

  Form := TForm.Create(nil);
  try
    Sekme := TTabloListeSekme.Create(Form);
    Sekme.Parent := Form;
    Sekme.Align := alClient;
    Sekme.Yukle(Bag);
    Kontrol('Liste: uc satir', Sekme.lvTablolar.Items.Count = 3);
    Kontrol('Liste: ada gore artan', (Sekme.lvTablolar.Items[0].Caption = 'FBY_L1') and (Sekme.lvTablolar.Items[2].Caption = 'FBY_L3'));
    Kontrol('Liste: alan sayisi ve aciklama kolonlari',
      (Sekme.lvTablolar.Items[0].SubItems[0] = '3') and (Sekme.lvTablolar.Items[0].SubItems[1] = 'deneme aciklamasi'));

    { Basliga tiklayinca siralama: ayni kolona ikinci tiklayinca ters yon }
    Sekme.lvTablolarColumnClick(nil, Sekme.lvTablolar.Columns[0]);
    Kontrol('Siralama: ad basligina tiklayinca ters (azalan)', Sekme.lvTablolar.Items[0].Caption = 'FBY_L3');
    Sekme.lvTablolarColumnClick(nil, Sekme.lvTablolar.Columns[1]);
    Kontrol('Siralama: alan sayisi sayi olarak artan (1, 3, 4)',
      (Sekme.lvTablolar.Items[0].Caption = 'FBY_L2') and (Sekme.lvTablolar.Items[2].Caption = 'FBY_L3'));
    Sekme.lvTablolarColumnClick(nil, Sekme.lvTablolar.Columns[1]);
    Kontrol('Siralama: alan sayisi azalan', Sekme.lvTablolar.Items[0].Caption = 'FBY_L3');

    { Tabloya tiklayinca alanlar }
    Sekme.lvTablolarSelectItem(nil, Sekme.lvTablolar.FindCaption(0, 'FBY_L1', False, True, False), True);
    Kontrol('Alanlar: FBY_L1 icin uc alan', Sekme.lvAlanlar.Items.Count = 3);
    Kontrol('Alanlar: ilk kolon veritabani sirasi (1, 2, 3) ve liste bu sirada',
      (Sekme.lvAlanlar.Items[0].Caption = '1') and (Sekme.lvAlanlar.Items[1].Caption = '2') and
      (Sekme.lvAlanlar.Items[2].Caption = '3') and (Sekme.lvAlanlar.Items[0].SubItems[0] = 'ID'));
    Kontrol('Alanlar: ad, tip, bos olabilir, varsayilan',
      (Pos('INTEGER', UpperCase(Sekme.lvAlanlar.Items[0].SubItems[1])) > 0) and
      (Sekme.lvAlanlar.Items[0].SubItems[2] = T('LISTE_HAYIR')) and (Sekme.lvAlanlar.Items[1].SubItems[2] = T('LISTE_EVET')) and
      (Pos('DEFAULT', UpperCase(Sekme.lvAlanlar.Items[2].SubItems[3])) > 0));
    Sekme.lvAlanlarColumnClick(nil, Sekme.lvAlanlar.Columns[1]);
    Kontrol('Alanlar: Alan basligina tiklayinca ada gore artan (AD, ID, TUTAR)',
      (Sekme.lvAlanlar.Items[0].SubItems[0] = 'AD') and (Sekme.lvAlanlar.Items[2].SubItems[0] = 'TUTAR'));
    Sekme.lvAlanlarColumnClick(nil, Sekme.lvAlanlar.Columns[1]);
    Kontrol('Alanlar: ikinci tiklayinca ters (TUTAR, ID, AD)',
      (Sekme.lvAlanlar.Items[0].SubItems[0] = 'TUTAR') and (Sekme.lvAlanlar.Items[2].SubItems[0] = 'AD'));
    Sekme.lvAlanlarColumnClick(nil, Sekme.lvAlanlar.Columns[0]);
    Kontrol('Alanlar: Sira basligina tiklayinca eklenme sirasina doner (ID, AD, TUTAR)',
      (Sekme.lvAlanlar.Items[0].SubItems[0] = 'ID') and (Sekme.lvAlanlar.Items[1].SubItems[0] = 'AD') and
      (Sekme.lvAlanlar.Items[2].SubItems[0] = 'TUTAR'));
    Sekme.lvAlanlarColumnClick(nil, Sekme.lvAlanlar.Columns[0]);
    Kontrol('Alanlar: Sira ters (3, 2, 1)',
      (Sekme.lvAlanlar.Items[0].Caption = '3') and (Sekme.lvAlanlar.Items[2].Caption = '1'));
    { Ayrinti goster/kapat }
    Kontrol('Ayrinti: baslangicta acik', Sekme.AyrintiAcik);
    Sekme.AyrintiAyarla(False);
    Kontrol('Ayrinti: kapatilinca gorunmez', not Sekme.AyrintiAcik);
    Sekme.AyrintiAyarla(True);
    Kontrol('Ayrinti: tekrar acilir', Sekme.AyrintiAcik);

    { Yenile: veritabanina eklenen tablo gorunur, secim korunur }
    Komut(Bag, 'create table FBY_L4 (X integer)');
    Bag.Baglanti.Commit;
    Sekme.Yenile;
    Kontrol('Yenile: yeni tablo listeye geldi', Sekme.lvTablolar.Items.Count = 4);
    Kontrol('Yenile: onceki secim (FBY_L1) korundu ve alanlari gorunuyor',
      (Sekme.lvTablolar.Selected <> nil) and (Sekme.lvTablolar.Selected.Caption = 'FBY_L1') and (Sekme.lvAlanlar.Items.Count = 3));

    { Cift tiklama: tablo acma olayi }
    Sekme.TabloAc := procedure(Tablo: string)
      begin
        Cikti.Add('      tablo ac istendi: ' + Tablo);
      end;
    Sekme.lvTablolarDblClick(nil);
    Sekme.YazilariYenile;
    Kontrol('Yazilar: baslik secili dilden', Pos(T('LISTE_SUTUN_TABLO'), Sekme.lvTablolar.Columns[0].Caption) = 1);
  finally
    Form.Free;
  end;
  FbBaglantiyiKes(Bag);
end;

procedure DilBolumu;
const
  Anahtarlar: array[0..26] of string = ('LISTE_SUTUN_SIRA', 'GRUP_GORUNUM', 'BTN_AYRINTI_KAPAT', 'BTN_AYRINTI_GOSTER', 'BTN_TUM_KAPAT',
    'MENU_SEKME_YENILE', 'MENU_TUM_SEKMELERI_KAPAT', 'MSG_SEKME_YENILENDI', 'SEKME_TUMU_SOR', 'LISTE_SEKME',
    'LISTE_ALANLAR', 'LISTE_SUTUN_TABLO', 'LISTE_SUTUN_ALAN_SAYISI', 'LISTE_SUTUN_ACIKLAMA', 'LISTE_SUTUN_ALAN',
    'LISTE_SUTUN_TIP', 'LISTE_SUTUN_BOS_OLABILIR', 'LISTE_SUTUN_VARSAYILAN', 'LISTE_EVET', 'LISTE_HAYIR',
    'ERR_LISTE_ACILAMADI', 'DURUM_BAGLI', 'DURUM_BAGLI_DEGIL', 'MENU_SEKME_KAPAT', 'APP_BASLIK', 'BTN_BAGLAN', 'BTN_KES');
var
  Dil, Anahtar, Eksik: string;
begin
  Cikti.Add('');
  Cikti.Add('=== C) Dil anahtarlari ===');
  for Dil in ['tr', 'en', 'de'] do
  begin
    DilYukle(Dil);
    Eksik := '';
    for Anahtar in Anahtarlar do
      if T(Anahtar) = Anahtar then
        Eksik := Eksik + ' ' + Anahtar;
    Kontrol('Dil ' + Dil + ': gorunum anahtarlari tanimli', Eksik = '');
    if Eksik <> '' then
      Cikti.Add('      eksik:' + Eksik);
  end;
  DilYukle('tr');
end;

begin
  Cikti := TStringList.Create;
  try
    try
      DilYukle('tr');
      Klasor := TPath.Combine(GetEnvironmentVariable('TEMP'), 'gorunumtest');
      ForceDirectories(Klasor);
      VeriKlasoruAyarla(TPath.Combine(Klasor, 'veri'));
      Cikti.Add('GorunumTest  ' + FormatDateTime('yyyy-mm-dd hh:nn:ss', Now));
      YolBolumu;
      DilBolumu;
      ListeBolumu;
    except
      on E: Exception do
      begin
        Cikti.Add('');
        Cikti.Add('HATA (beklenmeyen): ' + E.ClassName + ': ' + E.Message);
        Inc(Hatalar);
      end;
    end;
    Cikti.Add('');
    Cikti.Add('Kontrol: ' + IntToStr(KontrolSayisi) + '  Hata: ' + IntToStr(Hatalar));
    Cikti.SaveToFile(GetEnvironmentVariable('FBTEST_CIKTI'), TEncoding.UTF8);
  finally
    Cikti.Free;
  end;
  ExitCode := Hatalar;
end.
