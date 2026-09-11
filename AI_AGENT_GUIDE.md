# AI Agent Guide — YankunFrame

> ⚠️ **READ THIS FIRST before doing anything.**
> The app runs on a remote iMac, NOT on this development machine.
> You develop locally, then deploy to the iMac via SCP/SSH.

---

## 1. Architecture Overview

YankunFrame is a digital photo frame: **native macOS app** (Swift + WKWebView) + **Python backend** serving images/videos via local HTTP.

```
YankunFrame.app (Swift + WKWebView)
  └─ WebView → http://127.0.0.1:8080
       └─ Python server (server.py)
            ├─ /api/images  → list media
            ├─ /image/{name} → resize → WebP cached
            ├─ /media/{name} → serve raw video/GIF/SVG
            └─ /            → static files (index.html + JS/CSS)
```

---

## 2. iMac (Target Machine)

| Property | Value |
|----------|-------|
| Hostname | `imac-de-yank.local` |
| IP | `192.168.18.24` |
| SSH User | `yank` |
| Project root | `/users/yank_imac/Desktop/YankunFrame/` |
| Photos dir | `.../YankunFrame/photos/` |
| Cache dir | `.../YankunFrame/cache/` |
| App bundle | `.../YankunFrame/YankunFrame.app/` |
| Python | 3.9.6 at `/usr/bin/python3` |
| Libraries | Pillow ✅, rawpy ✅ |

### SSH / SCP
```bash
ssh yank@imac-de-yank.local          # or yank@192.168.18.24
scp server.py yank@imac-de-yank.local:/users/yank_imac/Desktop/YankunFrame/
```
⚠️ Password auth. If key needed: `ssh-keygen -y -f ~/.ssh/id_rsa` to get public key.
## 3. Key Files

| File | Purpose |
|------|---------|
| `server.py` | HTTP server — resize images to WebP, serve videos, API |
| `config.json` | Paths, image dims (max_width/max_height/webp_quality), video settings |
| `static/index.html` | Frontend — 2x img, 2x video, settings panel, loading overlay |
| `static/css/styles.css` | All styles — fullscreen, transitions, loading spinner |
| `static/js/api.js` | API client — fetchMediaList, fetchConfig, build URLs |
| `static/js/app.js` | Main logic — slideshow timer, transitions, keyboard nav |
| `static/js/preloader.js` | Double-buffer swap for smooth image/video transitions |
| `static/js/settings.js` | localStorage settings + UI panel binding |
| `YankunFrameNative/main.swift` | Swift app — borderless window, WKWebView, launches Python |
| `YankunFrameNative/compile.sh` | Builds YankunFrame.app from Swift source |

## 4. App Flow

1. User launches `YankunFrame.app`
2. Swift creates borderless fullscreen window + WKWebView
3. Swift launches `python3 server.py` with **cwd = parent of .app**
   (e.g. `~/Desktop/YankunFrame/` — `Bundle.main.bundleURL.deletingLastPathComponent()`)
4. Server starts on :8080, background thread pre-caches all images to WebP
5. WebView loads `http://127.0.0.1:8080` → index.html → JS
6. JS calls `GET /api/images` → returns JSON list of media files
7. JS shows first image via `GET /image/{filename}`
8. Slideshow cycles, preloading next image

> **Working directory is CRITICAL**: changed from inside .app bundle to parent of .app.
> This is how `./photos`, `./cache`, `./static` resolve correctly.

## 5. Config (lowered for old iMac)

```json
{
  "image": {
    "max_width": 1920, "max_height": 1080, "webp_quality": 60
  },
  "display": {
    "interval_seconds": 30, "transition_duration_ms": 1500,
    "shuffle": false, "fit_mode": "cover"
  }
}
```

## 6. Server Features

- **ThreadingHTTPServer** — RAWs don't block other requests
- **Pre-caching** — background thread processes all images at startup
- **Cache invalidation** — re-caches if source file is newer
- **ICC profile** — preserved in WebP output

## 7. Troubleshooting

**"No images" (black screen):**
1. `ssh` in → `curl http://127.0.0.1:8080/api/images` — should return JSON
2. `ls ~/Desktop/YankunFrame/photos/` — must contain image files
3. Check server cwd: `ps aux | grep python`
4. If API returns `[]` but photos exist → wrong working directory

**"Mac slow":**
- RAW files (CR3, 30-50MB) are CPU-heavy
- Lower `max_width`/`max_height` + `webp_quality` further if needed
- Pre-caching runs at startup so initial load is slow but slideshow smooth

## 8. Recent Fixes (2026-09-11)

### No images bug
**Root cause**: Swift set cwd to inside .app bundle, where photos didn't exist.
**Fix**: Changed to `Bundle.main.bundleURL.deletingLastPathComponent()` → `~/Desktop/YankunFrame/`.

### Old iMac performance
- Reduced: 4096x2304 → 1920x1080, quality 85 → 60
- Added: `ThreadingHTTPServer` (was blocking single-threaded)
- Added: Background pre-caching at server startup

### UX: loading feedback
- Added: Loading overlay with spinner in index.html + CSS + JS hooks

## 9. Development Workflow

1. Edit files locally (this project folder)
2. Test: `python3 server.py` → `open http://127.0.0.1:8080`
3. Deploy: `scp` changed files to iMac
4. Restart: Quit and relaunch `YankunFrame.app` on iMac