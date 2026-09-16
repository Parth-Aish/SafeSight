Write-Host "🚧 STARTING AGGRESSIVE FORCE CLEANUP..." -ForegroundColor Cyan

# 1. Aggressively kill lingering processes that lock files
Write-Host "Killing stuck Java/Gradle and Dart processes..." -ForegroundColor Yellow
taskkill /F /IM java.exe /T 2>$null
taskkill /F /IM dart.exe /T 2>$null
taskkill /F /IM flutter.bat /T 2>$null

# Wait 2 seconds for Windows to release the file locks
Start-Sleep -Seconds 2

# 2. Force delete locked folders
Write-Host "Deleting cache folders..." -ForegroundColor Yellow
Remove-Item -Path ".dart_tool" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item -Path "build" -Recurse -Force -ErrorAction SilentlyContinue

# 3. Re-initialize
Write-Host "Running Flutter Clean..." -ForegroundColor Green
flutter clean

Write-Host "Getting Packages..." -ForegroundColor Green
flutter pub get

Write-Host "✅ CLEANUP COMPLETE! The lock is removed. You can now build." -ForegroundColor Cyan