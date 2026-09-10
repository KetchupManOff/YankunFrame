# YankunFrame - Project State

## Overview
Self-hosted digital photo frame web app for iMac 2017 Retina 4K DCI-P3.
Python backend scans configurable media directories, serves resized WebP for images,
raw video/GIF for other media. Vanilla JS frontend with GPU crossfade, supports
images, GIFs, videos, and RAW camera formats.

## Tech Stack
- Backend: Python 3 + http.server + Pillow (WebP + ICC profiles) + pillow-heif + rawpy
- Frontend: HTML5 + CSS3 + Vanilla JS (zero frameworks)
- Display: 4096x2304, DCI-P3 gamut, GPU-accelerated opacity transitions

## Files
- server.py (~400 lines) - HTTP server + image resizing + caching + raw/video serving
- config.json - server/media/display settings
- requirements.txt - Python dependencies
- run.sh - Launch script for macOS
- send_to_imac.bat - Windows drag-and-drop photo transfer (scp to iMac)
- send_to_imac.ps1 - Windows PowerShell photo transfer (scp to iMac)
- static/index.html - SPA shell with img + video elements
- static/css/styles.css - P3 styles + extended settings UI
- static/js/api.js - Backend API client (media list, config, dirs)
- static/js/preloader.js - Media preloading (N+1), image + video support
- static/js/settings.js - Settings panel + localStorage + media dirs management
- static/js/app.js - Main loop orchestrator (image/video/GIF routing)

## Status
- Step 1 (server+config): COMPLETE — multi-dir, RAW, video, GIF support
- Step 2 (HTML+CSS): COMPLETE — video elements, extended settings UI
- Step 3 (api.js): COMPLETE — media types, config API, dirs API
- Step 4 (settings.js): COMPLETE — video volume/mute, media dirs CRUD
- Step 5 (preloader.js): COMPLETE — image + video dual-element preloading
- Step 6 (app.js): COMPLETE — video/GIF/image routing + live polling + keyboard nav
- Step 7 (run.sh+docs): COMPLETE
- Step 8 (testing): PENDING
- Step 9 (live refresh): COMPLETE — polls /api/images every 30s, merges new files
- Step 10 (keyboard nav): COMPLETE — ←→ arrows, wraps around, resets auto-timer
- Step 11 (kiosk mode): COMPLETE — AppleScript Cmd+Ctrl+F + JS fullscreen fallback + Chrome --kiosk
- Step 12 (native macOS app): COMPLETE — WKWebView borderless .app in YankunFrameNative/