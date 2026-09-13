#!/bin/bash
# YankunFrame - Compile native macOS app
# Usage: double-click this file or run: bash compile.sh
# Requires: Xcode Command Line Tools (run once: xcode-select --install)

# Auto-fix Windows CRLF line endings (in case copied from Windows)
sed -i '' -e 's/\r$//' "$0" 2>/dev/null

cd "$(dirname "$0")" || exit 1
SCRIPT_DIR=$(pwd)
ROOT_DIR=$(dirname "$SCRIPT_DIR")

echo "🖼  YankunFrame - Compiling native app..."

# Create .app bundle structure
APP_DIR="$ROOT_DIR/YankunFrame.app"
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"

# Copy static files into the app bundle (so it's self-contained)
cp -R "$ROOT_DIR/static" "$APP_DIR/Contents/Resources/"
cp "$ROOT_DIR/server.py" "$APP_DIR/Contents/Resources/"
cp "$ROOT_DIR/config.json" "$APP_DIR/Contents/Resources/"
mkdir -p "$APP_DIR/Contents/Resources/photos"
mkdir -p "$APP_DIR/Contents/Resources/cache"

# Copy Info.plist
cp "$SCRIPT_DIR/Info.plist" "$APP_DIR/Contents/"

# Compile Swift source
echo "📦 Compiling..."
swiftc -o "$APP_DIR/Contents/MacOS/YankunFrame" \
    -framework Cocoa \
    -framework WebKit \
    "$SCRIPT_DIR/main.swift" \
    -O \
    -whole-module-optimization

if [ $? -eq 0 ]; then
    echo "✅ App compiled: $ROOT_DIR/YankunFrame.app"
    echo ""
    echo "▶️  To launch: double-click YankunFrame.app"
    echo "   Or move it to your Applications folder."
    echo ""
    echo "ℹ️  First launch: macOS may ask you to allow it in"
    echo "   System Settings → Privacy & Security → Open anyway"
else
    echo "❌ Compilation failed."
    exit 1
fi