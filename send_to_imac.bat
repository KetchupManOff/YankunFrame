@echo off
REM ============================================
REM  YankunFrame — Envoyer des photos vers l'iMac
REM  Glisse-dépose tes photos sur ce fichier .bat
REM ============================================
set REMOTE=yank@imac-de-yank.local
set DEST=/users/yank_imac/Desktop/YankunFrame/photos/

if "%~1"=="" (
    echo Aucun fichier fourni.
    echo Glisse-depose des photos sur ce fichier ^(.bat^) pour les envoyer.
    pause
    exit /b 1
)

echo Envoi de fichiers vers %REMOTE%:%DEST% ...
echo.

set COUNT=0
set TOTAL=0
for %%f in (%*) do set /a TOTAL+=1

:loop
if "%~1"=="" goto done
set /a COUNT+=1
echo [%COUNT%/%TOTAL%] %~nx1
scp "%~1" "%REMOTE%:%DEST%"
if errorlevel 1 (
    echo ERREUR sur %~nx1
) else (
    echo OK : %~nx1
)
echo.
shift
goto loop

:done
echo ==========================================
echo Termine ! %TOTAL% fichier(s) traite(s).
echo Pense a rafraichir la page du cadre photo.
echo ==========================================
pause