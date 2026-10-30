@echo off
cd /d "D:\Works\2026\Clonegil"
if exist "build\windows\x64\runner\Release\clonegil.exe" (
    start "" "build\windows\x64\runner\Release\clonegil.exe"
) else (
    flutter run -d windows
)

