# 9ja Transport — reusable local Android build (Windows, no admin).
# One-time setup already done: Flutter C:\Users\User\flutter, Java 17 C:\Users\User\java,
# Android SDK C:\Users\User\Android\Sdk. Just run this file to rebuild the APK.
$ErrorActionPreference = "Stop"
$ROOT = Split-Path -Parent $MyInvocation.MyCommand.Path
$env:JAVA_HOME = "C:\Users\User\java\jdk-17.0.20.1+1"
$env:ANDROID_SDK_ROOT = "C:\Users\User\Android\Sdk"
$env:ANDROID_HOME = $env:ANDROID_SDK_ROOT
$env:Path = "C:\Users\User\flutter\bin;" + $env:Path
Set-Location -LiteralPath (Join-Path $ROOT "app")
flutter pub get
flutter analyze
flutter build apk --release
$apk = Join-Path $ROOT "app\build\app\outputs\flutter-apk\app-release.apk"
$out = Join-Path $ROOT "dist\9ja-transport-v1.apk"
Copy-Item -LiteralPath $apk -Destination $out -Force
Write-Output "APK: $out"
Write-Output ("Size MB: " + [math]::Round((Get-Item $out).Length / 1MB, 1))
Write-Output ("SHA256: " + (Get-FileHash -LiteralPath $out -Algorithm SHA256).Hash)
& "$env:ANDROID_SDK_ROOT\build-tools\36.0.0\apksigner.bat" verify --print-certs $out
