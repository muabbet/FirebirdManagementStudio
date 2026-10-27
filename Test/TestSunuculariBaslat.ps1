# TestSunuculariBaslat.ps1 - Atilabilir test sunucularini gizli pencerede baslatir / durdurur.
#   .\Test\TestSunuculariBaslat.ps1           -> 2.5 (3054), 3.0 (3052), 4.0 (3053) baslatir
#   .\Test\TestSunuculariBaslat.ps1 -Durdur   -> yalniz bu uc test sunucusunu durdurur
# Gercek sunuculara (2.5 servisi :3050, 5.0 :3051) DOKUNMAZ: yalniz asagidaki yollari bilir.
param([switch]$Durdur)

$Sunucular = @(
    @{ Ad = '2.5 test'; Yol = 'C:\Firebird\Firebird25\bin\fbserver.exe';  Port = 3054 },
    @{ Ad = '3.0 test'; Yol = 'C:\Firebird\Firebird30\firebird.exe';      Port = 3052 },
    @{ Ad = '4.0 test'; Yol = 'C:\Firebird\Firebird40\firebird.exe';      Port = 3053 }
)

foreach ($S in $Sunucular) {
    $Calisan = Get-Process | Where-Object { $_.Path -eq $S.Yol }
    if ($Durdur) {
        if ($Calisan) { $Calisan | Stop-Process; Write-Host "$($S.Ad): durduruldu" }
        else { Write-Host "$($S.Ad): zaten kapali" }
        continue
    }
    if ($Calisan) { Write-Host "$($S.Ad): zaten calisiyor (port $($S.Port))"; continue }
    if (-not (Test-Path $S.Yol)) { Write-Host "$($S.Ad): BULUNAMADI $($S.Yol)"; continue }
    Start-Process -FilePath $S.Yol -ArgumentList '-a' -WorkingDirectory (Split-Path $S.Yol) -WindowStyle Hidden
}

if (-not $Durdur) {
    Start-Sleep -Seconds 3
    foreach ($S in $Sunucular) {
        $Acik = (Test-NetConnection 127.0.0.1 -Port $S.Port -WarningAction SilentlyContinue).TcpTestSucceeded
        Write-Host ("{0}: port {1} {2}" -f $S.Ad, $S.Port, $(if ($Acik) { 'ACIK' } else { 'KAPALI' }))
    }
}
