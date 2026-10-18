program FirebirdYonetici;

{ Firebird Yoneticisi - Win64, Delphi (RAD Studio 12), VCL + FireDAC.
  Hedeflenen Firebird surumleri: 2.5, 3.0, 4.0, 5.0
  Denenen Firebird surumleri: 2.5.9, 5.0.4 }

uses
  System.SysUtils,
  Vcl.Forms,
  Vcl.Themes,
  Vcl.Styles,
  uDil in 'uDil.pas',
  uIkon in 'uIkon.pas',
  uSerit in 'uSerit.pas',
  uOnay in 'uOnay.pas',
  uBaglanti in 'uBaglanti.pas',
  uMetadata in 'uMetadata.pas',
  uSorgu in 'uSorgu.pas',
  uSonucGrid in 'uSonucGrid.pas',
  uEditor in 'uEditor.pas',
  uDDL in 'uDDL.pas',
  uAktar in 'uAktar.pas',
  uYedek in 'uYedek.pas',
  fTabloSekme in 'fTabloSekme.pas' {TabloSekme: TFrame},
  fSorguSekme in 'fSorguSekme.pas' {SorguSekme: TFrame},
  fMetinGoster in 'fMetinGoster.pas' {frmMetinGoster},
  fMetinSor in 'fMetinSor.pas' {frmMetinSor},
  fMetadataCikar in 'fMetadataCikar.pas' {frmMetadataCikar},
  fCsvAktar in 'fCsvAktar.pas' {frmCsvAktar},
  fYedek in 'fYedek.pas' {frmYedek},
  fBaglanti in 'fBaglanti.pas' {frmBaglanti},
  fAna in 'fAna.pas' {frmAna};

{$R *.res}
{$R 'Manifest.res' 'Manifest.rc'}

{ Acik tema: Stiller klasorundeki Windows10.vsf yuklenir. Dosya yoksa standart gorunum kalir. }
procedure StilYukle;
var
  Dosya: string;
begin
  Dosya := ExtractFilePath(ParamStr(0)) + 'Stiller\Windows10.vsf';
  if FileExists(Dosya) and TStyleManager.IsValidStyle(Dosya) then
  begin
    TStyleManager.LoadFromFile(Dosya);
    TStyleManager.TrySetStyle('Windows10');
  end;
end;

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  StilYukle;
  Application.CreateForm(TfrmAna, frmAna);
  Application.Run;
end.
