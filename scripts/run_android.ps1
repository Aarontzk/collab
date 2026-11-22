# Jalankan Collab di emulator Android dalam satu perintah:
# nyalakan emulator kalau belum hidup, tunggu sampai siap, lalu flutter run dengan env.json.
# -NoRun: hanya nyalakan emulator, tanpa flutter run.
param([switch]$NoRun)

$ErrorActionPreference = 'Stop'
Set-Location (Split-Path $PSScriptRoot -Parent)

if (-not (Test-Path 'env.json')) {
    Write-Host 'env.json belum ada. Salin env.example.json menjadi env.json lalu isi kuncinya.' -ForegroundColor Red
    exit 1
}

$sdk = if ($env:ANDROID_HOME) { $env:ANDROID_HOME } else { Join-Path $env:LOCALAPPDATA 'Android\Sdk' }
$adb = Join-Path $sdk 'platform-tools\adb.exe'
if (-not (Test-Path $adb)) {
    Write-Host "adb tidak ditemukan di $adb. Pasang Android SDK lewat Android Studio." -ForegroundColor Red
    exit 1
}

function Get-RunningEmulator {
    & $adb devices | Select-String '^(emulator-\d+)\s+device' | ForEach-Object { $_.Matches[0].Groups[1].Value } | Select-Object -First 1
}

$device = Get-RunningEmulator
if (-not $device) {
    $emulatorExe = Join-Path $sdk 'emulator\emulator.exe'
    $emulatorId = & $emulatorExe -list-avds 2>$null |
        Where-Object { $_ -match '^\S+$' -and $_ -notmatch '^INFO' } |
        Select-Object -First 1
    if (-not $emulatorId) {
        Write-Host 'Belum ada emulator Android. Buat dulu di Android Studio > Device Manager.' -ForegroundColor Red
        exit 1
    }
    Write-Host "Menyalakan emulator $emulatorId ..."
    Start-Process -FilePath $emulatorExe -ArgumentList '-avd', $emulatorId

    # Cold boot pertama bisa lama. Error adb selama booting (device offline) diabaikan.
    $ErrorActionPreference = 'Continue'
    $deadline = (Get-Date).AddMinutes(8)
    do {
        Start-Sleep -Seconds 3
        Write-Host '.' -NoNewline
        $device = Get-RunningEmulator
        $booted = if ($device) { (& $adb -s $device shell getprop sys.boot_completed 2>$null) -match '1' } else { $false }
        if ((Get-Date) -gt $deadline) {
            Write-Host 'Emulator tidak siap dalam 8 menit. Coba nyalakan dari Android Studio.' -ForegroundColor Red
            exit 1
        }
    } until ($booted)
    Write-Host ''
}

if ($NoRun) {
    Write-Host "Emulator siap: $device"
    exit 0
}

Write-Host "Menjalankan Collab di $device ..."
flutter run -d $device --dart-define-from-file=env.json
