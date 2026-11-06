unit uUygulama;

{ Uygulamanin adi ve surum numarasi tek yerde durur (acilis ekrani ve hakkinda yazilari buradan okur).
  Surum degisince yalniz UYGULAMA_SURUMU degistirilir (ve FirebirdManagementStudio.dproj icindeki FileVersion/ProductVersion). }

interface

const
  { Windows gorev cubugu bu kimlikle gruplar ve ikonu buradan okur. Kimlik yeni verilince Windows'un eski (onbellekteki) ikonu atlanir. }
  UYGULAMA_KIMLIGI = 'FirebirdManagementStudio.Ana';
  UYGULAMA_ADI = 'Firebird Management Studio';
  UYGULAMA_SURUMU = '0.5';
  { Fikir, oneri ve hata bildirimi: GitHub Issues (hazir sablonlar var). Hakkinda penceresindeki dugme acar. }
  GERI_BILDIRIM_ADRESI = 'https://github.com/muabbet/FirebirdManagementStudio/issues/new/choose';

{ Program acilirken, ilk form olusmadan once cagrilir. }
procedure UygulamaKimliginiAyarla;

{ Adresi kullanicinin varsayilan tarayicisinda acar. }
procedure AdresiAc(const Adres: string);

implementation

uses
  Winapi.Windows, Winapi.ShellAPI, Winapi.ShlObj;

procedure UygulamaKimliginiAyarla;
begin
  SetCurrentProcessExplicitAppUserModelID(UYGULAMA_KIMLIGI);
end;

procedure AdresiAc(const Adres: string);
begin
  ShellExecute(0, 'open', PChar(Adres), nil, nil, SW_SHOWNORMAL);
end;

end.
