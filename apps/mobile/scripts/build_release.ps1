# Builds the Play Store release bundle (AAB).
#
# Unlike a plain `flutter build appbundle`, this refuses to build when
# android/key.properties is missing -- build.gradle.kts would otherwise
# silently fall back to the debug key, and a debug-signed bundle is
# rejected by the Play Console. Run from apps/mobile:
#
#   powershell -ExecutionPolicy Bypass -File scripts/build_release.ps1
$ErrorActionPreference = "Stop"
Set-Location (Join-Path $PSScriptRoot "..")

if (-not (Test-Path "dart_define.json")) {
    throw "dart_define.json bulunamadi. dart_define.example.json'i kopyalayip SUPABASE_URL / SUPABASE_ANON_KEY degerlerini girin."
}
if (-not (Test-Path "android/key.properties")) {
    throw "android/key.properties bulunamadi. README.md > 'Imzalama anahtari' bolumune bakin."
}

flutter clean
flutter pub get
flutter analyze
if ($LASTEXITCODE -ne 0) { throw "flutter analyze basarisiz." }
flutter test
if ($LASTEXITCODE -ne 0) { throw "flutter test basarisiz." }

# --obfuscate needs --split-debug-info; the symbols directory must be
# kept (not committed) per release to symbolicate Play Console crashes.
flutter build appbundle --release `
    --dart-define-from-file=dart_define.json `
    --obfuscate --split-debug-info=build/symbols
if ($LASTEXITCODE -ne 0) { throw "flutter build appbundle basarisiz." }

Write-Host ""
Write-Host "AAB hazir: build/app/outputs/bundle/release/app-release.aab"
Write-Host "Debug sembolleri: build/symbols (bu surum icin saklayin)"
