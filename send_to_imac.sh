#!/usr/bin/env bash
# ============================================
#  YankunFrame — Smart send to iMac (macOS/Linux)
#  Auto-converts RAW / non-permitted formats before transfer
#  Usage : ./send_to_imac.sh photo1.cr2 video.wmv ...
# ============================================
# AI_CHANGELOG:
# [2026-09-11] New script for macOS/Linux. Auto-converts RAW, videos,
#   and non-permitted images using ffmpeg / ImageMagick / sips.
# ============================================
set -u

# ── Configuration ──────────────────────────────────────────
REMOTE="yank@imac-de-yank.local"
DEST="/users/yank_imac/Desktop/YankunFrame/photos/"

# Permitted extensions (kept in sync with config.json)
PERMITTED=".jpg .jpeg .png .webp .heic .heif .tiff .tif .bmp .svg .mp4 .webm .mov .avi .mkv .m4v .gif"

# RAW photo extensions -> convert to JPEG
RAW_EXTS=".cr2 .cr3 .crw .nef .nrw .arw .srf .sr2 .dng .orf .raf .rw2 .pef .3fr .mef .mos .erf .kdc .dcr .mrw .x3f .fff"

# Video extensions NOT permitted -> convert to H.264 MP4
VIDEO_CONVERT_EXTS=".wmv .flv .3gp .3g2 .mts .m2ts .m2t .vob .ogv .ogg .ts .mxf .divx .xvid .rm .rmvb .asf"

# Image extensions NOT permitted -> convert to JPEG
IMAGE_CONVERT_EXTS=".psd .eps .ai .pcx .tga .icns .jp2 .j2k .jpx .exr .hdr"

# ── Helpers ────────────────────────────────────────────────
have() { command -v "$1" >/dev/null 2>&1; }

lower() { echo "$1" | tr '[:upper:]' '[:lower:]'; }

ext_of() { lower "${1##*.}"; }

base_of() { local n; n="$(basename "$1")"; echo "${n%.*}"; }

in_list() { # $1=ext, $2=space-separated list
    local e
    for e in $2; do [ "$e" = "$1" ] && return 0; done
    return 1
}

# ── Tool detection ─────────────────────────────────────────
FFMPEG=""; MAGICK=""; SIPS=""

if have ffmpeg; then
    FFMPEG="$(command -v ffmpeg)"
    echo "[INFO] ffmpeg found: $FFMPEG"
else
    echo "[WARN] ffmpeg not found. Video/RAW conversion disabled."
    echo "       Install: brew install ffmpeg"
fi

if have magick; then
    MAGICK="$(command -v magick)"
    echo "[INFO] ImageMagick found: $MAGICK"
elif have convert; then
    MAGICK="$(command -v convert)"
    echo "[INFO] ImageMagick (convert) found: $MAGICK"
fi

if have sips; then
    SIPS="$(command -v sips)"
    echo "[INFO] macOS sips found (built-in image converter)"
fi
# ── Conversion functions ───────────────────────────────────
convert_to_jpeg() { # $1=input, $2=output
    local in="$1" out="$2"
    # ImageMagick first (best RAW support)
    if [ -n "$MAGICK" ]; then
        "$MAGICK" "$in" -auto-orient -resize '4096x2304>' -quality 85 "$out" 2>/dev/null
        [ -f "$out" ] && return 0
    fi
    # ffmpeg fallback (handles many RAW formats too)
    if [ -n "$FFMPEG" ]; then
        ffmpeg -y -loglevel error -i "$in" \
            -vf "scale='min(4096,iw)':'min(2304,ih)':force_original_aspect_ratio=decrease" \
            -q:v 3 "$out" 2>/dev/null
        [ -f "$out" ] && return 0
    fi
    # macOS built-in sips (JPEG/PNG/TIFF only, no RAW)
    if [ -n "$SIPS" ]; then
        sips -s format jpeg -s formatOptions 85 --resampleWidth 4096 "$in" --out "$out" >/dev/null 2>&1
        [ -f "$out" ] && return 0
    fi
    return 1
}

convert_to_mp4() { # $1=input, $2=output
    if [ -z "$FFMPEG" ]; then
        echo "  SKIP: ffmpeg required for video conversion" >&2
        return 1
    fi
    ffmpeg -y -loglevel error -i "$1" \
        -c:v libx264 -preset fast -crf 23 -profile:v main -level 4.0 \
        -vf "scale='min(1920,iw)':'min(1080,ih)':force_original_aspect_ratio=decrease,fps=30" \
        -an -movflags +faststart "$2" 2>/dev/null
    [ -f "$2" ] && return 0
    return 1
}

# ── Main ───────────────────────────────────────────────────
if [ $# -eq 0 ]; then
    echo "Aucun fichier fourni."
    echo "Usage : $0 photo1.jpg photo2.cr2 video.wmv ..."
    exit 1
fi

echo ""
echo "========================================"
echo " YankunFrame - Smart Send to iMac"
echo "========================================"
echo "Target : ${REMOTE}:${DEST}"
echo "Files  : $#"
echo ""

TEMP_DIR="${TMPDIR:-/tmp}/yankunframe_convert"
mkdir -p "$TEMP_DIR"

SUCCESS=0; FAIL=0; CONVERTED=0; COUNT=0

for file in "$@"; do
    COUNT=$((COUNT+1))
    name="$(basename "$file")"
    ext="$(ext_of "$file")"
    base="$(base_of "$file")"
    send_path="$file"
    conv_file=""
    action=""

    if [ ! -f "$file" ]; then
        echo "[$COUNT/$#] $name  NOT FOUND"
        FAIL=$((FAIL+1))
        continue
    fi

    # ── Classify ──
    if in_list "$ext" "$PERMITTED"; then
        action="send as-is"
    elif in_list "$ext" "$RAW_EXTS"; then
        action="RAW -> JPEG"
        conv_file="$TEMP_DIR/$base.jpg"
    elif in_list "$ext" "$VIDEO_CONVERT_EXTS"; then
        action="video -> MP4"
        conv_file="$TEMP_DIR/$base.mp4"
    elif in_list "$ext" "$IMAGE_CONVERT_EXTS"; then
        action="image -> JPEG"
        conv_file="$TEMP_DIR/$base.jpg"
    else
        action="unknown (sending as-is)"
    fi

    # ── Convert if needed ──
    if [ -n "$conv_file" ]; then
        echo "[$COUNT/$#] $name  [$action]"
        if [ "$action" = "video -> MP4" ]; then
            convert_to_mp4 "$file" "$conv_file"
        else
            convert_to_jpeg "$file" "$conv_file"
        fi

        if [ -f "$conv_file" ]; then
            before=$(stat -f%z "$file" 2>/dev/null || echo 0)
            after=$(stat -f%z "$conv_file" 2>/dev/null || echo 0)
            if [ "$before" -gt 0 ] 2>/dev/null; then
                pct=$(( after * 100 / before ))
                echo "  -> $((before/1048576))MB -> $((after/1048576))MB (${pct}%)"
            fi
            send_path="$conv_file"
            CONVERTED=$((CONVERTED+1))
        else
            echo "  X Conversion failed, skipping"
            FAIL=$((FAIL+1))
            continue
        fi
    else
        echo "[$COUNT/$#] $name  [$action]"
    fi

    # ── SCP ──
    if scp -o ConnectTimeout=15 "$send_path" "${REMOTE}:${DEST}" >/dev/null 2>&1; then
        echo "   OK"
        SUCCESS=$((SUCCESS+1))
        [ -n "$conv_file" ] && rm -f "$conv_file"
    else
        echo "   X SCP failed"
        FAIL=$((FAIL+1))
    fi
done

rm -rf "$TEMP_DIR"

echo ""
echo "========================================"
echo "Termine !"
echo "  Sent as-is : $((SUCCESS - CONVERTED))"
[ "$CONVERTED" -gt 0 ] && echo "  Converted  : $CONVERTED"
echo "  Failed     : $FAIL"
echo ""
echo "Pense a rafraichir la page du cadre photo."
echo "========================================"
echo ""