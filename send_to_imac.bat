@echo off
setlocal enabledelayedexpansion
REM ============================================
REM  YankunFrame - Smart send to iMac
REM  Auto-converts RAW / non-permitted formats
REM  Glisse-depose tes fichiers sur ce .bat
REM ============================================
REM AI_CHANGELOG:
REM [2026-09-11] Complete rewrite: auto-conversion for RAW,
REM   videos, non-permitted images. Detects ffmpeg/magick,
REM   converts before SCP, cleans up temp files.
REM ============================================

set REMOTE=yank@imac-de-yank.local
set DEST=/users/yank_imac/Desktop/YankunFrame/photos/

if "%~1"=="" (
    echo Aucun fichier fourni.
    echo Glisse-depose des photos/videos sur ce fichier ^(.bat^) pour les envoyer.
    pause
    exit /b 1
)

echo.
echo ========================================
echo  YankunFrame - Smart Send to iMac
echo ========================================
echo Target : %REMOTE%:%DEST%
echo.

REM ── Tool detection ───────────────────────────────────────
set HAS_FFMPEG=0
set HAS_MAGICK=0

where ffmpeg >nul 2>&1
if %errorlevel%==0 (
    set HAS_FFMPEG=1
    echo [INFO] ffmpeg found
) else (
    echo [WARN] ffmpeg not found. Video conversion disabled.
    echo        Install: winget install ffmpeg
)

where magick >nul 2>&1
if %errorlevel%==0 (
    set HAS_MAGICK=1
    echo [INFO] ImageMagick found
) else (
    echo [INFO] ImageMagick not found. Using ffmpeg fallback.
)
echo.

REM ── Temp dir ─────────────────────────────────────────────
set TEMP_DIR=%TEMP%\yankunframe_convert
if not exist "%TEMP_DIR%" mkdir "%TEMP_DIR%"

REM ── Count files ──────────────────────────────────────────
set TOTAL=0
for %%f in (%*) do set /a TOTAL+=1

set COUNT=0
set SUCCESS=0
set FAIL=0
set CONVERTED=0

:loop
if "%~1"=="" goto done
set /a COUNT+=1

set "FILE=%~1"
set "NAME=%~nx1"
set "EXT=%~x1"
set "ACTION="

REM Check permitted extensions first (send as-is)
for %%e in (".JPG" ".JPEG" ".PNG" ".WEBP" ".HEIC" ".HEIF" ".TIFF" ".TIF" ".BMP" ".SVG" ".MP4" ".WEBM" ".MOV" ".AVI" ".MKV" ".M4V" ".GIF") do (
    if /i "!EXT!"=="%%e" set "ACTION=send as-is"
)
REM Check RAW extensions
if not defined ACTION (
    for %%e in (".CR2" ".CR3" ".CRW" ".NEF" ".NRW" ".ARW" ".SRF" ".SR2" ".DNG" ".ORF" ".RAF" ".RW2" ".PEF" ".3FR" ".MEF" ".MOS" ".ERF" ".KDC" ".DCR" ".MRW" ".X3F" ".FFF") do (
        if /i "!EXT!"=="%%e" set "ACTION=RAW->JPG"
    )
)
REM Check non-permitted video extensions
if not defined ACTION (
    for %%e in (".WMV" ".FLV" ".3GP" ".3G2" ".MTS" ".M2TS" ".M2T" ".VOB" ".OGV" ".OGG" ".TS" ".MXF" ".DIVX" ".XVID" ".RM" ".RMVB" ".ASF") do (
        if /i "!EXT!"=="%%e" set "ACTION=video->MP4"
    )
)
REM Check non-permitted image extensions
if not defined ACTION (
    for %%e in (".PSD" ".EPS" ".AI" ".PCX" ".TGA" ".ICNS" ".JP2" ".J2K" ".JPX" ".EXR" ".HDR") do (
        if /i "!EXT!"=="%%e" set "ACTION=image->JPG"
    )
)
if not defined ACTION set "ACTION=unknown"

REM ── Convert if needed ────────────────────────────────────
set "SENDPATH=%FILE%"
set "CONVFILE="

set "BASENAME=%~n1"

if "!ACTION!"=="RAW->JPG" (
    set "CONVFILE=%TEMP_DIR%\!BASENAME!.jpg"
    call :convert_raw "%FILE%" "!CONVFILE!"
    if !errorlevel!==0 (
        set "SENDPATH=!CONVFILE!"
        set /a CONVERTED+=1
        echo [!COUNT!/%TOTAL%] !NAME!  [RAW-^>JPG]
    ) else (
        echo [!COUNT!/%TOTAL%] !NAME!  [RAW-^>JPG]  X Conversion failed
        set /a FAIL+=1
        shift
        goto loop
    )
) else if "!ACTION!"=="video->MP4" (
    set "CONVFILE=%TEMP_DIR%\!BASENAME!.mp4"
    call :convert_video "%FILE%" "!CONVFILE!"
    if !errorlevel!==0 (
        set "SENDPATH=!CONVFILE!"
        set /a CONVERTED+=1
        echo [!COUNT!/%TOTAL%] !NAME!  [video-^>MP4]
    ) else (
        echo [!COUNT!/%TOTAL%] !NAME!  [video-^>MP4]  X Conversion failed
        set /a FAIL+=1
        shift
        goto loop
    )
) else if "!ACTION!"=="image->JPG" (
    set "CONVFILE=%TEMP_DIR%\!BASENAME!.jpg"
    call :convert_image "%FILE%" "!CONVFILE!"
    if !errorlevel!==0 (
        set "SENDPATH=!CONVFILE!"
        set /a CONVERTED+=1
        echo [!COUNT!/%TOTAL%] !NAME!  [image-^>JPG]
    ) else (
        echo [!COUNT!/%TOTAL%] !NAME!  [image-^>JPG]  X Conversion failed
        set /a FAIL+=1
        shift
        goto loop
    )
) else (
    echo [!COUNT!/%TOTAL%] !NAME!  [!ACTION!]
)

REM ── SCP transfer ─────────────────────────────────────────
scp "!SENDPATH!" "%REMOTE%:%DEST%" >nul 2>&1
if !errorlevel!==0 (
    echo    OK
    set /a SUCCESS+=1
    if defined CONVFILE if exist "!CONVFILE!" del "!CONVFILE!"
) else (
    echo    X SCP failed
    set /a FAIL+=1
)

shift
goto loop
REM ── Conversion subroutines ───────────────────────────────

:convert_raw
if %HAS_MAGICK%==1 (
    magick convert "%~1" -auto-orient -resize "4096x2304^>" -quality 85 "%~2" >nul 2>&1
    if exist "%~2" exit /b 0
)
if %HAS_FFMPEG%==1 (
    ffmpeg -y -i "%~1" -vf "scale='min(4096,iw)':'min(2304,ih)':force_original_aspect_ratio=decrease" -q:v 3 "%~2" >nul 2>&1
    if exist "%~2" exit /b 0
)
exit /b 1

:convert_image
if %HAS_MAGICK%==1 (
    magick convert "%~1" -auto-orient -resize "4096x2304^>" -quality 85 "%~2" >nul 2>&1
    if exist "%~2" exit /b 0
)
if %HAS_FFMPEG%==1 (
    ffmpeg -y -i "%~1" -vf "scale='min(4096,iw)':'min(2304,ih)':force_original_aspect_ratio=decrease" -q:v 3 "%~2" >nul 2>&1
    if exist "%~2" exit /b 0
)
exit /b 1

:convert_video
if %HAS_FFMPEG%==0 (
    echo SKIP: ffmpeg required
    exit /b 1
)
ffmpeg -y -i "%~1" -c:v libx264 -preset fast -crf 23 ^
  -profile:v main -level 4.0 ^
  -vf "scale='min(1920,iw)':'min(1080,ih)':force_original_aspect_ratio=decrease,fps=30" ^
  -an -movflags +faststart "%~2" >nul 2>&1
if exist "%~2" exit /b 0
exit /b 1

REM ── Done ─────────────────────────────────────────────────
:done
if exist "%TEMP_DIR%" rmdir /s /q "%TEMP_DIR%" >nul 2>&1

echo.
echo ========================================
echo Termine !
echo   Sent as-is : %SUCCESS%
if %CONVERTED% gtr 0 echo   Converted  : %CONVERTED%
echo   Failed     : %FAIL%
echo.
echo Pense a rafraichir la page du cadre photo.
echo ========================================
pause
endlocal