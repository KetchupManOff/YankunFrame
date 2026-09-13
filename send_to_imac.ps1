# ============================================
#  YankunFrame — Smart send to iMac
#  Auto-converts RAW / non-permitted formats before transfer
#  Usage : .\send_to_imac.ps1 photo1.cr2 video.wmv ...
# ============================================
# AI_CHANGELOG:
# [2026-09-11] Complete rewrite: smart auto-conversion for RAW, videos,
#   and non-permitted images. Detects ffmpeg/ImageMagick, converts before
#   SCP, cleans up temp files, shows size comparison.
# ============================================
param(
    [Parameter(ValueFromRemainingArguments=$true)]
    [string[]]$Files
)

# ── Configuration ──────────────────────────────────────────
$REMOTE = "yank@imac-de-yank.local"
$DEST   = "/users/yank_imac/Desktop/YankunFrame/photos/"

# Permitted extensions (kept in sync with config.json)
$PERMITTED = @(
    ".jpg", ".jpeg", ".png", ".webp", ".heic", ".heif",
    ".bmp", ".svg",
    ".mp4", ".webm", ".mov", ".avi", ".mkv", ".m4v",
    ".gif"
)

# RAW photo extensions -> convert to JPEG
$RAW_EXTS = @(
    ".cr2", ".cr3", ".crw",      # Canon
    ".nef", ".nrw",              # Nikon
    ".arw", ".srf", ".sr2",      # Sony
    ".dng",                      # Adobe / universal
    ".orf",                      # Olympus
    ".raf",                      # Fujifilm
    ".rw2",                      # Panasonic
    ".pef",                      # Pentax
    ".3fr",                      # Hasselblad
    ".mef",                      # Mamiya
    ".mos",                      # Leaf
    ".erf",                      # Epson
    ".kdc", ".dcr",              # Kodak
    ".mrw",                      # Minolta
    ".x3f",                      # Sigma
    ".fff"                       # Imacon
)

# Video extensions NOT in permitted -> convert to H.264 MP4
$VIDEO_CONVERT_EXTS = @(
    ".wmv", ".flv", ".3gp", ".3g2",
    ".mts", ".m2ts", ".m2t",
    ".vob", ".ogv", ".ogg",
    ".ts", ".mxf",
    ".divx", ".xvid",
    ".rm", ".rmvb",
    ".asf"
)

# Extra image formats -> convert to JPEG
$IMAGE_CONVERT_EXTS = @(
    ".tiff", ".tif",
    ".psd", ".eps", ".ai",
    ".pcx", ".tga", ".icns",
    ".jp2", ".j2k", ".jpx",
    ".exr", ".hdr"
)

# ── Tool detection ─────────────────────────────────────────
$FFMPEG = $null
$MAGICK = $null

try {
    $null = Get-Command ffmpeg -ErrorAction Stop
    $FFMPEG = (Get-Command ffmpeg).Source
    Write-Host "[INFO] ffmpeg found: $FFMPEG" -ForegroundColor Gray
} catch {
    Write-Host "[WARN] ffmpeg not found. Video & RAW conversion disabled." -ForegroundColor Yellow
    Write-Host "       Install: winget install ffmpeg  or  choco install ffmpeg" -ForegroundColor Yellow
}

try {
    $null = Get-Command magick -ErrorAction Stop
    $MAGICK = (Get-Command magick).Source
    Write-Host "[INFO] ImageMagick found: $MAGICK" -ForegroundColor Gray
} catch {
    Write-Host "[INFO] ImageMagick not found. Using ffmpeg fallback." -ForegroundColor Gray
}

# ── Conversion functions ───────────────────────────────────

function Convert-RawToJpeg {
    param([string]$InputPath, [string]$OutputPath)
    
    # Try ImageMagick first (better RAW support)
    if ($MAGICK) {
        & magick convert $InputPath -auto-orient `
            -resize "4096x2304>" -quality 85 $OutputPath 2>$null
        if ($LASTEXITCODE -eq 0 -and (Test-Path $OutputPath)) { return $true }
    }
    
    # Fallback to ffmpeg
    if ($FFMPEG) {
        & ffmpeg -y -i $InputPath `
            -vf "scale='min(4096,iw)':'min(2304,ih)':force_original_aspect_ratio=decrease" `
            -q:v 3 $OutputPath 2>$null
        if ($LASTEXITCODE -eq 0 -and (Test-Path $OutputPath)) { return $true }
    }
    
    return $false
}

function Convert-ImageToJpeg {
    param([string]$InputPath, [string]$OutputPath)
    
    if ($MAGICK) {
        & magick convert $InputPath -auto-orient `
            -resize "4096x2304>" -quality 85 $OutputPath 2>$null
        if ($LASTEXITCODE -eq 0 -and (Test-Path $OutputPath)) { return $true }
    }
    
    if ($FFMPEG) {
        & ffmpeg -y -i $InputPath `
            -vf "scale='min(4096,iw)':'min(2304,ih)':force_original_aspect_ratio=decrease" `
            -q:v 3 $OutputPath 2>$null
        if ($LASTEXITCODE -eq 0 -and (Test-Path $OutputPath)) { return $true }
    }
    
    return $false
}

function Convert-VideoToMp4 {
    param([string]$InputPath, [string]$OutputPath)
    
    if (-not $FFMPEG) {
        Write-Host "  SKIP: ffmpeg required" -ForegroundColor Yellow
        return $false
    }
    
    # H.264 MP4, max 1920x1080, 30fps, stripped audio (photo frame)
    & ffmpeg -y -i $InputPath `
        -c:v libx264 -preset fast -crf 23 -profile:v main -level 4.0 `
        -vf "scale='min(1920,iw)':min'(1080,ih)':force_original_aspect_ratio=decrease,fps=30" `
        -an -movflags +faststart $OutputPath 2>$null
    
    if ($LASTEXITCODE -eq 0 -and (Test-Path $OutputPath)) { return $true }
    return $false
}
# ── Main ───────────────────────────────────────────────────

if (-not $Files -or $Files.Count -eq 0) {
    Write-Host "Aucun fichier fourni." -ForegroundColor Yellow
    Write-Host "Usage : .\send_to_imac.ps1 photo1.jpg photo2.cr2 video.wmv ..."
    Write-Host "Tu peux aussi glisser-deposer des fichiers dans le terminal."
    exit 1
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host " YankunFrame — Smart Send to iMac" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Target : ${REMOTE}:${DEST}" -ForegroundColor Gray
Write-Host "Files  : $($Files.Count)" -ForegroundColor Gray
Write-Host ""

$success   = 0
$fail      = 0
$converted = 0
$TEMP_DIR  = Join-Path $env:TEMP "yankunframe_convert"
New-Item -ItemType Directory -Force -Path $TEMP_DIR | Out-Null

for ($i = 0; $i -lt $Files.Count; $i++) {
    $file   = $Files[$i]
    $name   = Split-Path $file -Leaf
    $ext    = [System.IO.Path]::GetExtension($name).ToLower()
    $base   = [System.IO.Path]::GetFileNameWithoutExtension($name)
    $num    = $i + 1
    $sendPath = $file
    $convertedFile = $null
    $action = ""

    if (-not (Test-Path $file)) {
        Write-Host "[$num/$($Files.Count)] $name  NOT FOUND" -ForegroundColor Red
        $fail++
        continue
    }

    # ── Determine action ──
    if ($PERMITTED -contains $ext) {
        $action = "send as-is"
    }
    elseif ($RAW_EXTS -contains $ext) {
        $action = "RAW -> JPEG"
        $convertedFile = Join-Path $TEMP_DIR "$base.jpg"
    }
    elseif ($VIDEO_CONVERT_EXTS -contains $ext) {
        $action = "video -> MP4"
        $convertedFile = Join-Path $TEMP_DIR "$base.mp4"
    }
    elseif ($IMAGE_CONVERT_EXTS -contains $ext) {
        $action = "image -> JPEG"
        $convertedFile = Join-Path $TEMP_DIR "$base.jpg"
    }
    else {
        $action = "unknown (sending as-is)"
    }

    # ── Convert if needed ──
    if ($convertedFile) {
        Write-Host "[$num/$($Files.Count)] $name  [$action]" -NoNewline
        
        $convertOk = $false
        if ($RAW_EXTS -contains $ext) {
            $convertOk = Convert-RawToJpeg -InputPath $file -OutputPath $convertedFile
        }
        elseif ($VIDEO_CONVERT_EXTS -contains $ext) {
            $convertOk = Convert-VideoToMp4 -InputPath $file -OutputPath $convertedFile
        }
        elseif ($IMAGE_CONVERT_EXTS -contains $ext) {
            $convertOk = Convert-ImageToJpeg -InputPath $file -OutputPath $convertedFile
        }

        if ($convertOk) {
            $sendPath = $convertedFile
            $converted++
            $sizeBefore = (Get-Item $file).Length
            $sizeAfter  = (Get-Item $convertedFile).Length
            $ratio = [math]::Round(100 * $sizeAfter / [Math]::Max(1, $sizeBefore))
            $beforeMB = ($sizeBefore/1MB).ToString('0.0')
            $afterMB  = ($sizeAfter/1MB).ToString('0.0')
            Write-Host "  -> ${beforeMB}MB -> ${afterMB}MB (${ratio}%)" -ForegroundColor Gray
        } else {
            Write-Host "  X Conversion failed, skipping" -ForegroundColor Red
            $fail++
            continue
        }
    } else {
        Write-Host "[$num/$($Files.Count)] $name  [$action]" -NoNewline
    }

    # ── Send via SCP ──
    scp $sendPath "${REMOTE}:${DEST}" 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  OK" -ForegroundColor Green
        $success++
        if ($convertedFile -and (Test-Path $convertedFile)) {
            Remove-Item $convertedFile -Force
        }
    } else {
        Write-Host "  X SCP failed" -ForegroundColor Red
        $fail++
    }
}

# ── Cleanup ─────────────────────────────────────────────────
if (Test-Path $TEMP_DIR) {
    Remove-Item $TEMP_DIR -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Termine !                    " -ForegroundColor Cyan
Write-Host "  Sent as-is : $($success - $converted)" -ForegroundColor Gray
if ($converted -gt 0) {
    Write-Host "  Converted  : $converted" -ForegroundColor Magenta
}
Write-Host "  Failed     : $fail" -ForegroundColor $(if ($fail -gt 0) { "Red" } else { "Gray" })
Write-Host ""
Write-Host "Pense a rafraichir la page du cadre photo." -ForegroundColor Yellow
Write-Host "========================================" -ForegroundColor Cyan