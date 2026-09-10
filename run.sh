#!/bin/bash
# YankunFrame - Digital Photo Frame for iMac
# Auto-fix Windows CRLF line endings
sed -i '' -e 's/\r$//' "$0" 2>/dev/null

cd "$(dirname "$0")" || exit 1
ROOT_DIR=$(pwd)

echo "🖼  YankunFrame starting..."

# Priority 1: Launch native .app if it exists (compiled from YankunFrameNative/)
if [ -d "$ROOT_DIR/YankunFrame.app" ]; then
    echo "🎯 Launching native app..."
    open "$ROOT_DIR/YankunFrame.app"
    echo "✅ Running — close the app window to stop."
    exit 0
fi

# Priority 2: Start server and open in browser
python3 server.py &
sleep 2

# Try Chrome/Chromium kiosk mode (borderless), fall back to Safari
if open -a "Google Chrome" --args --kiosk --no-first-run \
    --disable-default-apps --disable-sync \
    "http://127.0.0.1:8080" 2>/dev/null; then
    echo "✅ Chrome kiosk mode (borderless)"
elif open -a "Chromium" --args --kiosk --no-first-run \
    "http://127.0.0.1:8080" 2>/dev/null; then
    echo "✅ Chromium kiosk mode (borderless)"
else
    # Fallback: Safari + AppleScript fullscreen
    osascript -e '
    tell application "Safari"
        activate
        open location "http://127.0.0.1:8080"
        delay 3
    end tell
    tell application "System Events"
        tell process "Safari"
            keystroke "f" using {command down, control down}
            delay 1
            keystroke "\\" using {command down, shift down}
        end tell
    end tell
    ' 2>/dev/null || open http://127.0.0.1:8080
    echo "ℹ️  Safari mode (compile native app for borderless: bash YankunFrameNative/compile.sh)"
fi

echo ""
echo "Running — http://127.0.0.1:8080"
wait
