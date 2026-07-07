@echo off
SETLOCAL EnableDelayedExpansion
title Universal Mac Boot Camp Driver Installer für Windows

echo ==================================================
echo    Universal Mac Boot Camp Installer (Windows)    
echo ==================================================
echo.

:: 1. Admin-Rechte prüfen
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo [FEHLER] Bitte starte dieses Skript zwingend als Administrator!
    echo Rechtsklick -> "Als Administrator ausfuehren".
    echo.
    pause
    exit /b 1
)

:: 2. Mac-Modell über das BIOS auslesen
echo [1/4] Ermittle Mac-Hardware-Modell...
for /f "tokens=2 delims==" %%A in ('wmic csproduct get name /value 2^>nul') do set "MAC_MODEL=%%A"

:: Leerzeichen entfernen
set "MAC_MODEL=%MAC_MODEL: =%"

if "%MAC_MODEL%"=="" (
    echo [WARNUNG] Mac-Modell konnte nicht automatisch ausgelesen werden.
    set /p "MAC_MODEL=Bitte gib dein Mac-Modell manuell ein (z.B. MacBookPro11,1): "
) else (
    echo Erkannter Mac: %MAC_MODEL%
)
echo.

:: 3. Temporären Arbeitsordner erstellen
set "WORK_DIR=%SystemDrive%\BootCampTmp"
if not exist "%WORK_DIR%" mkdir "%WORK_DIR%"
cd /d "%WORK_DIR%"

:: 4. Brigadier herunterladen (Nutzt PowerShell im Hintergrund)
echo [2/4] Lade das automatisierte Apple-Treiber-Tool (Brigadier) herunter...
set "BRIGADIER_URL=https://github.com/timsutton/brigadier/releases/latest/download/brigadier.exe"

powershell -Command "[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; Invoke-WebRequest -Uri '%BRIGADIER_URL%' -OutFile 'brigadier.exe'"

if not exist "brigadier.exe" (
    echo [FEHLER] Download von Brigadier fehlgeschlagen. Pruefe deine Internetverbindung.
    pause
    exit /b 1
)
echo Download erfolgreich.
echo.

:: 5. Treiber von Apple anfordern und installieren
echo [3/4] Kontaktiere Apple-Server, lade Boot-Camp-ESD herunter und entpacke...
echo (Dies kann je nach Internetleitung und Mac-Alter 5-20 Minuten dauern. Bitte warten...)
echo.

:: Ausführung von Brigadier mit Parametern:
:: -m bestimmt das Modell
:: -i installiert die MSI/Treiber-Pakete nach dem Entpacken automatisch im Hintergrund
brigadier.exe --model=%MAC_MODEL% --install

if %errorLevel% neq 0 (
    echo.
    echo [HINWEIS] Der automatische Installer meldete einen Fehler oder benötigt einen manuellen Start.
    echo Suche im Ordner "%WORK_DIR%" nach dem erstellten "BootCamp-" Unterordner.
    echo Gehe dort hinein und starte die "Setup.exe" im "BootCamp"-Ordner manuell!
) else (
    echo.
    echo [4/4] Treiber-Download und Installation erfolgreich abgeschlossen!
)

echo.
echo ==================================================
echo Fertig! Bitte starte deinen Mac neu, um alle Treiber zu aktivieren.
echo ==================================================
pause
exit /b 0
