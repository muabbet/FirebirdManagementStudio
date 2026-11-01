unit uUygulama;

{ Uygulamanin adi ve surum numarasi tek yerde durur (acilis ekrani ve hakkinda yazilari buradan okur).
  Surum degisince yalniz UYGULAMA_SURUMU degistirilir (ve FirebirdManagementStudio.dproj icindeki FileVersion/ProductVersion). }

interface

const
  { Windows gorev cubugu bu kimlikle gruplar ve ikonu buradan okur. Kimlik yeni verilince Windows'un eski (onbellekteki) ikonu atlanir. }
  UYGULAMA_KIMLIGI = 'FirebirdManagementStudio.Ana';
  UYGULAMA_ADI = 'Firebird Management Studio';
  UYGULAMA_SURUMU = '0.4';

{ Program acilirken, ilk form olusmadan once cagrilir. }
procedure UygulamaKimliginiAyarla;

implementation

uses
  Winapi.ShlObj;

procedure UygulamaKimliginiAyarla;
begin
  SetCurrentProcessExplicitAppUserModelID(UYGULAMA_KIMLIGI);
end;

end.
