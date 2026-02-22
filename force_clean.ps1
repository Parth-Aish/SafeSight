Write-Host "🚧 STARTING COMPLETE FORCE CLEANUP..." -ForegroundColor Cyan

# 1. Kill ALL lingering processes that lock files
Write-Host "Killing stuck Dart/Flutter/Gradle processes..." -ForegroundColor Yellow
Stop-Process -Name "dart" -ErrorAction SilentlyContinue
Stop-Process -Name "flutter" -ErrorAction SilentlyContinue
Stop-Process -Name "java" -ErrorAction SilentlyContinue # Kotlin/Gradle daemon
Stop-Process -Name "adb" -ErrorAction SilentlyContinue
Stop-Process -Name "gradle" -ErrorAction SilentlyContinue
Write-Host "✓ Processes killed" -ForegroundColor Green

# 2. Force delete local project cache folders
Write-Host "Deleting local project cache folders..." -ForegroundColor Yellow
Remove-Item -Path ".dart_tool" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item -Path "build" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item -Path ".gradle" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item -Path "pubspec.lock" -Force -ErrorAction SilentlyContinue
Remove-Item -Path "android/.gradle" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item -Path "android/build" -Recurse -Force -ErrorAction SilentlyContinue
Write-Host "✓ Local caches deleted" -ForegroundColor Green

# 3. Clear Gradle daemon cache (USER-LEVEL - helps prevent Gradle conflicts)
Write-Host "Clearing Gradle daemon cache..." -ForegroundColor Yellow
$gradleUserHome = "$($env:USERPROFILE)\.gradle"
if (Test-Path $gradleUserHome) {
    Remove-Item -Path "$gradleUserHome/daemon" -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item -Path "$gradleUserHome/caches" -Recurse -Force -ErrorAction SilentlyContinue
    Write-Host "✓ Gradle daemon cache cleared" -ForegroundColor Green
}

# 4. Run Flutter Clean (official Flutter cleanup)
Write-Host "Running Flutter Clean..." -ForegroundColor Green
flutter clean

# 5. Get fresh packages
Write-Host "Getting Packages..." -ForegroundColor Green
flutter pub get

# 6. Optional: Rebuild native Android files
Write-Host "Rebuilding Android native files..." -ForegroundColor Green
cd android
gradlew.bat clean
cd ..

Write-Host "✅ COMPLETE CLEANUP DONE! You can now run the app without issues." -ForegroundColor Cyan
Write-Host "Next: Run 'flutter run' or 'flutter pub get' to rebuild" -ForegroundColor Magenta