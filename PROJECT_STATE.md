# YankunFrame - Project State

## Project Overview
Self-hosted digital photo frame web app for iMac 2017 Retina 4K DCI-P3.
Python backend scans configurable media directories, serves original JPEG bytes or resized WebP for other images,
raw video/GIF for other media. Vanilla JS frontend with GPU crossfade, supports
images, GIFs, videos, and RAW camera formats.

## Tech Stack & Environment
- Backend: Python 3 + http.server + Pillow (WebP + ICC profiles) + pillow-heif + rawpy
- Frontend: HTML5 + CSS3 + Vanilla JS (zero frameworks)
- Display: 4096x2304, DCI-P3 gamut, GPU-accelerated opacity transitions
- Target runtime: native macOS WKWebView app on iMac 2017; development workspace on Windows

## Architecture & File Map
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

### Current Architecture
- `/image/{name}` passes `.jpg`/`.jpeg` through byte-for-byte; formats requiring conversion use 4096x2304 maximum WebP caches at quality 95.
- JPEG passthrough avoids a second lossy encode and skips startup pre-caching.
- Image and API script URLs carry an image-pipeline revision to bypass stale q60 WKWebView cache entries after deployment.
- The server binds port 8080 before background pre-caching. The native app launches server/config from a canonical `/Users/...` project cwd, owns its Python child, and terminates it on exit.
- Native builds include runtime code/static assets but not duplicate photo/cache contents; the app continues to use root-level `photos/` and `cache/`.
- `/media/{name}` serves video and other raw media; the frontend double-buffers media for crossfades.
- Still images use synchronized foreground/background buffers: the background duplicate fills the canvas with `cover`, 50px Gaussian blur, 15% brightness reduction, and overscan, while the foreground retains the selected Cover/Contain mode.

## Current State & Active Tasks
- Step 1 (server+config): COMPLETE — multi-dir, RAW, video, GIF support
- Step 2 (HTML+CSS): COMPLETE — video elements, extended settings UI
- Step 3 (api.js): COMPLETE — media types, config API, dirs API
- Step 4 (settings.js): COMPLETE — video volume/mute, media dirs CRUD
- Step 5 (preloader.js): COMPLETE — image + video dual-element preloading
- Step 6 (app.js): COMPLETE — video/GIF/image routing + live polling + keyboard nav
- Step 7 (run.sh+docs): COMPLETE
- Step 8 (testing): IN PROGRESS — video playback fix applied (play() calls added)
- Step 9 (live refresh): COMPLETE — polls /api/images every 30s, merges new files
- Step 10 (keyboard nav): COMPLETE — ←→ arrows, wraps around, resets auto-timer
- Step 11 (kiosk mode): COMPLETE — AppleScript Cmd+Ctrl+F + JS fullscreen fallback + Chrome --kiosk
- Step 12 (native macOS app): COMPLETE — WKWebView borderless .app in YankunFrameNative/
- Step 13 (git init + GitHub push): COMPLETE — repo at https://github.com/KetchupManOff/YankunFrame.git
- Step 14 (sleep prevention): COMPLETE — IOKit assertion prevents display sleep when native app is active
- Step 15 (startup hang fix): COMPLETE — Removed Thread.sleep blocking, reordered window creation first, deferred page load via DispatchQueue
- Step 16 (GitHub sync 2026-09-11): COMPLETE — Pulled f815200: server.py refactor, send_to_imac improvements (bat/ps1/sh), native app tweaks, CSS/JS enhancements, AI agent guide + changelog added
- Step 17 (TIFF conversion + 4K resolution): COMPLETE — .tiff/.tif now converted to JPEG in all send scripts; server restored to 4K native (4096×2304) with original-size-until-4K policy
- Step 18 (JPEG quality preservation): COMPLETE and DEPLOYED — JPG/JPEG is served unchanged, converted formats use q95, and the rebuilt app is live on the iMac.
- Step 19 (dynamic blurred image backgrounds): COMPLETE and DEPLOYED — still-image buffers include synchronized, darkened 50px-blur canvas-filling duplicates; the rebuilt app and live assets were verified on the iMac, and video behavior remains unchanged.
- Active limitation: macOS stalls Python when spawned directly by the unsigned GUI app from the protected Desktop folder. The deployed session therefore runs one verified detached backend (PID recorded at verification) alongside the native UI. Next: sign/notarize the app or install the project outside Desktop, then retest fully app-owned server startup.

## Changelog / Completed Steps
- 2026-09-13 15:16:16 -04:00 — Committed the complete JPEG-preservation, native lifecycle, and blurred-background release as `bce9465` (`Preserve JPEG quality and add blurred backgrounds`) and pushed `main` to GitHub. Verified `origin/main` resolves to full commit `bce9465c48b0fa4a5b0955afc2b463e31bc002f0`. Next: visually observe several portrait-image crossfades on the iMac; no further deployment work is pending.
- 2026-09-13 15:15:21 -04:00 — Deployed all 12 pending runtime/native/documentation source files to `/Users/yank_imac/Desktop/YankunFrame` and verified local/remote SHA-256 parity. Clean-built `YankunFrame.app` (124 KB; 84,752-byte executable timestamped 2026-09-13 15:14:43 -0400), launched it as PID 6824, and verified the live versioned blur CSS, 4096x2304 config, and 50-item media API. Removed only the known blocked app-spawned duplicate backend, leaving verified listener PID 6524. The documented static IP timed out, but `imac-de-yank.local` worked. Next: commit and push the complete pending change set to GitHub `origin/main`.
- 2026-09-13 15:03:24 -04:00 — Added dynamic blurred backgrounds for still images using two synchronized backdrop buffers, 50px blur, 15% exposure reduction, and edge-hiding overscan. Preserved foreground Cover/Contain controls and existing video behavior, synchronized transition timing, and versioned changed static assets for WKWebView cache invalidation. JavaScript syntax and Git whitespace checks passed; browser automation was unavailable on the Windows host. Next: deploy `static/index.html`, `static/css/styles.css`, `static/js/preloader.js`, and `static/js/settings.js` to the iMac and visually verify portrait images and crossfades.
- 2026-09-13 14:39:43 -04:00 — Diagnosed the photo degradation as server-side JPEG-to-WebP quality-60 recompression. Added configurable JPG/JPEG passthrough, raised conversion quality to 95, skipped passthrough files during startup pre-cache, and validated byte-identical JPEG HTTP delivery plus WebP conversion behavior. Next: deploy `server.py`, `config.json`, `static/index.html`, and `static/js/api.js` to the iMac and restart YankunFrame.
- 2026-09-13 15:00:08 -04:00 — Deployed corrected runtime/native sources to `/Users/yank_imac/Desktop/YankunFrame`, clean-built `YankunFrame.app` (124 KB, binary timestamp 2026-09-13 14:58:00), launched the app, and left one detached corrected backend listening on 127.0.0.1:8080. Live API reports 4096x2304. Real-photo verification for `Marzy_et_Nivian.jpg` returned `image/jpeg` and matched source SHA-256 `395c38e829ac32734ca960c114e66cba39474a49385ca01c0204bb229b4c9199`. Next: resolve unsigned-app Desktop mediation so the GUI can own server startup directly.