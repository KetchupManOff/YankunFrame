import argparse, json, mimetypes, os, sys, traceback, urllib.parse
from http.server import HTTPServer, BaseHTTPRequestHandler
from pathlib import Path

HAS_PILLOW = False
try:
    from PIL import Image
    HAS_PILLOW = True
except ImportError:
    print("[WARN] Pillow not installed.", file=sys.stderr)

try:
    from pillow_heif import register_heif_opener
    register_heif_opener()
except ImportError:
    pass

HAS_RAWPY = False
try:
    import rawpy
    import numpy as np
    HAS_RAWPY = True
except ImportError:
    print("[WARN] rawpy not installed. RAW formats will be skipped.",
          file=sys.stderr)

def load_config(path="config.json"):
    defaults = {
        "server": {"host": "127.0.0.1", "port": 8080},
        "paths": {"media_dirs": ["./photos"], "cache_dir": "./cache",
                  "static_dir": "./static"},
        "image": {
            "max_width": 4096, "max_height": 2304, "webp_quality": 85,
            "allowed_extensions": [
                ".jpg", ".jpeg", ".png", ".webp", ".heic", ".heif",
                ".tiff", ".tif", ".bmp", ".svg",
                ".cr2", ".cr3", ".dng", ".arw", ".nef", ".orf",
                ".rw2", ".raf", ".pef", ".srf", ".raw", ".3fr",
                ".ari", ".srw", ".x3f", ".erf", ".mrw", ".dcr",
                ".kdc", ".fff", ".mos", ".iiq"]
        },
        "video": {
            "allowed_extensions": [".mp4", ".webm", ".mov", ".avi",
                                   ".mkv", ".m4v"],
            "default_muted": False, "default_volume": 80
        },
        "gif": {"enabled": True},
        "display": {"interval_seconds": 30}
    }
    if os.path.isfile(path):
        with open(path, "r", encoding="utf-8") as f:
            user = json.load(f)
        for s in defaults:
            if s in user:
                if isinstance(defaults[s], dict):
                    defaults[s].update(user[s])
                else:
                    defaults[s] = user[s]
    # backward compat: photos_dir -> media_dirs
    if "photos_dir" in defaults["paths"] and not defaults["paths"].get("media_dirs"):
        defaults["paths"]["media_dirs"] = [defaults["paths"]["photos_dir"]]
    return defaults

def resolve_path(base, rel):
    p = Path(rel)
    return str(p) if p.is_absolute() else str((base / p).resolve())

RAW_EXTENSIONS = {
    ".cr2", ".cr3", ".dng", ".arw", ".nef", ".orf", ".rw2", ".raf",
    ".pef", ".srf", ".raw", ".3fr", ".ari", ".srw", ".x3f", ".erf",
    ".mrw", ".dcr", ".kdc", ".fff", ".mos", ".iiq"
}
GIF_EXTENSION = ".gif"
SVG_EXTENSION = ".svg"


def ext_lower(fname):
    return os.path.splitext(fname)[1].lower()


def classify_media(fname, config):
    """Return one of: 'image', 'video', 'gif', 'raw', None"""
    ext = ext_lower(fname)
    img_exts = [e.lower() for e in config["image"]["allowed_extensions"]]
    vid_exts = [e.lower() for e in config["video"]["allowed_extensions"]]
    if ext in vid_exts:
        return "video"
    if ext == GIF_EXTENSION and config.get("gif", {}).get("enabled", True):
        return "gif"
    if ext in img_exts:
        if ext in RAW_EXTENSIONS:
            return "raw"
        return "image"
    return None


def cache_key(fname, mw, mh, q):
    stem = Path(fname).stem
    safe = "".join(c if c.isalnum() or c in "._-" else "_" for c in stem)
    return f"{safe}_{mw}x{mh}_q{q}.webp"


def open_raw_image(path):
    """Open a RAW file using rawpy and return a Pillow Image (RGB)."""
    if not HAS_RAWPY:
        return None
    try:
        with rawpy.imread(path) as raw:
            try:
                thumb = raw.extract_thumb()
                if thumb.format == rawpy.ThumbFormat.JPEG:
                    from io import BytesIO
                    return Image.open(BytesIO(thumb.data)).convert("RGB")
            except Exception:
                pass
            rgb = raw.postprocess(
                use_camera_wb=True,
                half_size=True,
                no_auto_bright=False,
                output_bps=8
            )
            return Image.fromarray(rgb)
    except Exception:
        return None


def resize_and_cache(orig, cache, mw, mh, q, is_raw=False):
    if not HAS_PILLOW:
        return False
    try:
        if is_raw:
            img = open_raw_image(orig)
            if img is None:
                return False
        else:
            img = Image.open(orig)
    except Exception:
        return False
    icc = img.info.get("icc_profile", None)
    if img.mode in ("RGBA", "P", "LA"):
        bg = Image.new("RGBA", img.size, (255, 255, 255))
        if img.mode != "RGBA":
            img = img.convert("RGBA")
        img = Image.alpha_composite(bg, img)
        img = img.convert("RGB")
    elif img.mode in ("CMYK", "L", "I", "F"):
        img = img.convert("RGB")
    ow, oh = img.size
    s = min(mw / ow if ow > mw else 1.0, mh / oh if oh > mh else 1.0)
    if s < 1.0:
        img = img.resize((max(1, int(ow * s)), max(1, int(oh * s))),
                         Image.LANCZOS)
    kw = {"quality": q, "method": 6}
    if icc:
        kw["icc_profile"] = icc
    os.makedirs(os.path.dirname(cache), exist_ok=True)
    img.save(cache, "WEBP", **kw)
    print(f"[CACHE] {os.path.basename(cache)}")
    return True

MIME_MAP = {
    ".html": "text/html; charset=utf-8",
    ".css": "text/css; charset=utf-8",
    ".js": "application/javascript; charset=utf-8",
    ".json": "application/json; charset=utf-8",
    ".webp": "image/webp",
    ".svg": "image/svg+xml",
    ".gif": "image/gif",
    ".mp4": "video/mp4",
    ".webm": "video/webm",
    ".mov": "video/quicktime",
    ".mkv": "video/x-matroska",
    ".avi": "video/x-msvideo",
    ".m4v": "video/mp4",
}


def guess_mime(path):
    ext = os.path.splitext(path)[1].lower()
    return MIME_MAP.get(ext) or mimetypes.guess_type(path)[0] or "application/octet-stream"

class YankunHandler(BaseHTTPRequestHandler):
    config = None
    project_root = None
    media_dirs = None
    cache_dir = None
    static_dir = None
    image_cfg = None
    video_cfg = None
    gif_cfg = None

    def do_GET(self):
        p = urllib.parse.urlparse(self.path).path
        try:
            if p == "/api/images":
                self._api_images()
            elif p == "/api/config":
                self._api_config()
            elif p.startswith("/image/"):
                self._serve_image(p)
            elif p.startswith("/media/"):
                self._serve_media(p)
            else:
                self._serve_static(p)
        except Exception:
            self.send_error(500, "Internal Server Error")
            traceback.print_exc()

    def do_POST(self):
        p = urllib.parse.urlparse(self.path).path
        try:
            if p == "/api/config/media-dirs":
                self._api_set_media_dirs()
            else:
                self.send_error(404, "Not Found")
        except Exception:
            self.send_error(500, "Internal Server Error")
            traceback.print_exc()

    # ── API: list all media ──────────────────────────────────
    def _api_images(self):
        results = []
        seen = set()
        for mdir in self.media_dirs:
            if not os.path.isdir(mdir):
                continue
            try:
                entries = sorted(os.listdir(mdir))
            except OSError:
                continue
            for fname in entries:
                full = os.path.join(mdir, fname)
                if not os.path.isfile(full):
                    continue
                mtype = classify_media(fname, self.config)
                if mtype is None:
                    continue
                if fname in seen:
                    continue
                seen.add(fname)
                results.append({
                    "name": fname,
                    "type": mtype,
                    "dir": mdir
                })
        self._send_json(results)

    # ── API: expose config to frontend ──────────────────────
    def _api_config(self):
        self._send_json({
            "media_dirs": self.config["paths"].get("media_dirs", []),
            "video_default_muted":
                self.video_cfg.get("default_muted", False),
            "video_default_volume":
                self.video_cfg.get("default_volume", 80),
            "display": self.config.get("display", {}),
            "image": {
                "max_width": self.image_cfg.get("max_width", 4096),
                "max_height": self.image_cfg.get("max_height", 2304),
            }
        })

    # ── API: update media dirs ──────────────────────────────
    def _api_set_media_dirs(self):
        length = int(self.headers.get("Content-Length", 0))
        if length == 0:
            self.send_error(400, "Empty body")
            return
        body = self.rfile.read(length)
        try:
            data = json.loads(body)
        except json.JSONDecodeError:
            self.send_error(400, "Invalid JSON")
            return
        dirs = data.get("dirs", None)
        if not isinstance(dirs, list):
            self.send_error(400, "Missing 'dirs' array")
            return
        validated = []
        for d in dirs:
            if not isinstance(d, str):
                continue
            p = resolve_path(self.project_root, d)
            if os.path.isdir(p):
                validated.append(d)
            else:
                print(f"[WARN] Dir not found, skipped: {p}")
        self.config["paths"]["media_dirs"] = validated
        self.media_dirs = [resolve_path(self.project_root, d)
                           for d in validated]
        config_path = os.path.join(self.project_root, "config.json")
        try:
            with open(config_path, "w", encoding="utf-8") as f:
                json.dump(self.config, f, indent=2, ensure_ascii=False)
        except OSError as e:
            print(f"[ERROR] Could not save config: {e}", file=sys.stderr)
        self._send_json({"ok": True, "media_dirs": validated})

    def _serve_image(self, path):
        fname = urllib.parse.unquote(path[len("/image/"):])
        orig = self._find_media_file(fname)
        if orig is None:
            self.send_error(404, "Not Found")
            return

        ext = ext_lower(fname)
        is_raw = ext in RAW_EXTENSIONS
        is_svg = ext == SVG_EXTENSION

        # SVG & GIF: serve raw
        if is_svg or (ext == GIF_EXTENSION and
                      self.gif_cfg.get("enabled", True)):
            self._serve_raw_file(orig, ext)
            return

        # RAW: needs rawpy
        if is_raw and not HAS_RAWPY:
            self.send_error(415, "RAW support requires rawpy library")
            return

        mw = self.image_cfg.get("max_width", 4096)
        mh = self.image_cfg.get("max_height", 2304)
        q = self.image_cfg.get("webp_quality", 85)
        cname = cache_key(fname, mw, mh, q)
        cpath = os.path.join(self.cache_dir, cname)

        need = True
        if os.path.isfile(cpath):
            try:
                if os.path.getmtime(cpath) >= os.path.getmtime(orig):
                    need = False
            except OSError:
                pass

        if need:
            if not resize_and_cache(orig, cpath, mw, mh, q,
                                    is_raw=is_raw):
                self._serve_raw_file(orig, ext)
                return

        try:
            with open(cpath, "rb") as f:
                data = f.read()
        except OSError:
            self.send_error(500, "Failed to read cache")
            return

        self.send_response(200)
        self.send_header("Content-Type", "image/webp")
        self.send_header("Content-Length", str(len(data)))
        self.send_header("Cache-Control", "public, max-age=3600")
        self.end_headers()
        self.wfile.write(data)

    def _serve_media(self, path):
        """Serve raw files: videos, GIFs, SVGs."""
        fname = urllib.parse.unquote(path[len("/media/"):])
        orig = self._find_media_file(fname)
        if orig is None:
            self.send_error(404, "Not Found")
            return
        self._serve_raw_file(orig, ext_lower(fname))

    def _find_media_file(self, fname):
        """Search all media_dirs for a file by name."""
        for mdir in self.media_dirs:
            candidate = os.path.join(mdir, fname)
            if os.path.isfile(candidate):
                return candidate
        return None

    def _serve_raw_file(self, fullpath, ext):
        """Serve any file as-is with appropriate MIME type."""
        try:
            with open(fullpath, "rb") as f:
                data = f.read()
        except OSError:
            self.send_error(500, "Failed to read file")
            return
        self.send_response(200)
        self.send_header("Content-Type", guess_mime(fullpath))
        self.send_header("Content-Length", str(len(data)))
        self.send_header("Cache-Control", "public, max-age=3600")
        self.send_header("Accept-Ranges", "bytes")
        self.end_headers()
        self.wfile.write(data)

    def _send_json(self, obj):
        data = json.dumps(obj, ensure_ascii=False).encode("utf-8")
        self.send_response(200)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def log_message(self, format, *args):
        pass

    def _serve_static(self, path):
        if path == '/' or path == '':
            path = '/index.html'
        norm = os.path.normpath(path.lstrip('/'))
        if norm.startswith('..') or os.path.isabs(norm):
            self.send_error(403, 'Forbidden')
            return
        fp = os.path.join(self.static_dir, norm)
        if not os.path.isfile(fp):
            self.send_error(404, 'Not Found')
            return
        try:
            with open(fp, 'rb') as f:
                data = f.read()
        except OSError:
            self.send_error(500, 'Failed to read file')
            return
        self.send_response(200)
        self.send_header('Content-Type', guess_mime(fp))
        self.send_header('Content-Length', str(len(data)))
        self.send_header('Cache-Control', 'public, max-age=600')
        self.end_headers()
        self.wfile.write(data)


def make_handler(config, root):
    class H(YankunHandler):
        pass
    H.config = config
    H.project_root = root
    H.media_dirs = [resolve_path(root, d)
                    for d in config["paths"].get("media_dirs", [])]
    H.cache_dir = resolve_path(root, config["paths"]["cache_dir"])
    H.static_dir = resolve_path(root, config["paths"]["static_dir"])
    H.image_cfg = config["image"]
    H.video_cfg = config.get("video", {})
    H.gif_cfg = config.get("gif", {"enabled": True})
    return H


def main():
    ap = argparse.ArgumentParser(description='YankunFrame server')
    ap.add_argument('--host', default=None)
    ap.add_argument('--port', type=int, default=None)
    ap.add_argument('--config', default='config.json')
    args = ap.parse_args()
    root = Path(__file__).resolve().parent
    cfg = load_config(args.config)
    host = args.host or cfg['server']['host']
    port = args.port or cfg['server']['port']
    for d in cfg["paths"].get("media_dirs", []):
        os.makedirs(resolve_path(root, d), exist_ok=True)
    for k in ("cache_dir", "static_dir"):
        os.makedirs(resolve_path(root, cfg["paths"][k]), exist_ok=True)
    handler = make_handler(cfg, root)
    srv = HTTPServer((host, port), handler)
    print(f'[YankunFrame] http://{host}:{port}')
    print(f'[YankunFrame] Media dirs: {handler.media_dirs}')
    print('[YankunFrame] Press Ctrl+C to stop.')
    try:
        srv.serve_forever()
    except KeyboardInterrupt:
        print("\n[YankunFrame] Shutting down.")
        srv.shutdown()


if __name__ == '__main__':
    main()
