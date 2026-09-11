var YankunApp = (() => {
  var media = [];
  var index = 0;
  var timer = null;
  var settings = null;
  var pollTimer = null;
  var POLL_INTERVAL_MS = 30000; // Check for new photos every 30 seconds

  function shuffle(arr) {
    var a = arr.slice();
    for (var i = a.length - 1; i > 0; i--) {
      var j = Math.floor(Math.random() * (i + 1));
      var t = a[i]; a[i] = a[j]; a[j] = t;
    }
    return a;
  }

  function getUrl(item) {
    if (item.type === "video") {
      return YankunAPI.getMediaUrl(item.name);
    }
    // GIFs and images both use /image/ endpoint
    // (GIFs are served raw from there)
    return YankunAPI.getImageUrl(item.name);
  }

  async function start() {
    settings = Settings.load();
    Settings.applyToUI(settings);
    Settings.setupPanel();

    var overlay = document.getElementById("loading-overlay");
    var msg = document.getElementById("loading-msg");

    try {
      media = await YankunAPI.fetchMediaList();
    } catch (e) {
      console.error("Failed to load media list:", e);
      if (msg) msg.textContent = "Cannot connect to server. Retrying...";
      setTimeout(start, 5000);
      return;
    }

    if (media.length === 0) {
      console.warn("No media found, retrying in 10s...");
      if (msg) msg.textContent = "No photos found. Check your photos folder. Retrying...";
      setTimeout(start, 10000);
      return;
    }

    if (settings.shuffle) {
      media = shuffle(media);
    }

    index = 0;
    showCurrent();
    startPolling();
    setupKeyboard();
  }

  // ── Live media pool refresh (no restart needed) ──────────
  function startPolling() {
    clearInterval(pollTimer);
    pollTimer = setInterval(pollNewMedia, POLL_INTERVAL_MS);
  }

  function pollNewMedia() {
    YankunAPI.fetchMediaList().then(function(freshList) {
      var existingNames = {};
      for (var i = 0; i < media.length; i++) {
        existingNames[media[i].name] = true;
      }

      var added = 0;
      for (var j = 0; j < freshList.length; j++) {
        var item = freshList[j];
        if (!existingNames[item.name]) {
          media.push(item);
          existingNames[item.name] = true;
          added++;
        }
      }

      if (added > 0) {
        console.log("[YankunFrame] " + added + " new media file(s) detected and added to pool");
      }
    }).catch(function(e) {
      // Silently ignore transient network errors during polling
    });
  }

  // ── Keyboard navigation + fullscreen ──────────────────
  var fullscreenRequested = false;

  function requestFullscreen() {
    if (fullscreenRequested) return;
    fullscreenRequested = true;
    var el = document.documentElement;
    if (el.requestFullscreen) {
      el.requestFullscreen().catch(function() {});
    } else if (el.webkitRequestFullscreen) {
      el.webkitRequestFullscreen();
    }
  }

  function setupKeyboard() {
    // Force focus on body so keydown events are captured
    document.body.focus();

    // Also re-focus on any click/blur to ensure keys always work
    document.body.addEventListener("blur", function() {
      setTimeout(function() { document.body.focus(); }, 50);
    });

    window.addEventListener("keydown", function(e) {
      // Ignore if user is typing in an input, textarea, or using a select dropdown
      var tag = e.target.tagName;
      if (tag === "INPUT" || tag === "TEXTAREA" || tag === "SELECT") {
        return;
      }

      // Request fullscreen on first keypress
      requestFullscreen();

      // Support both .key (modern) and .keyCode (legacy)
      var key = e.key || e.keyIdentifier || "";
      var code = e.keyCode || e.which;

      if (key === "ArrowRight" || key === "Right" || code === 39) {
        e.preventDefault();
        e.stopPropagation();
        navigateBy(1);
      } else if (key === "ArrowLeft" || key === "Left" || code === 37) {
        e.preventDefault();
        e.stopPropagation();
        navigateBy(-1);
      }
    }, true); // capture phase to beat any other listeners

    // Also try to fullscreen on first click anywhere
    document.body.addEventListener("click", requestFullscreen, { once: true });
  }

  function navigateBy(delta) {
    if (media.length === 0) return;

    // Reset auto-advance timer
    clearTimeout(timer);

    // Move index with wrap-around
    index = (index + delta + media.length) % media.length;

    // Show the new current photo and restart the timer
    showCurrent();
  }

  function showCurrent() {
    if (media.length === 0) return;
    var item = media[index];
    var url = getUrl(item);
    var vol = Settings.getVideoSettings();
    settings = Settings.load();
    // [2026-09-11] Pass interval for random video start feature
    ImagePreloader.setCurrent(url, item.type, vol, settings.interval);
    scheduleNext();

    // Hide loading overlay once first image is shown
    var overlay = document.getElementById("loading-overlay");
    if (overlay) {
      overlay.classList.add("hidden");
    }
  }

  function scheduleNext() {
    clearTimeout(timer);
    var nextIdx = (index + 1) % media.length;
    var nextItem = media[nextIdx];
    var nextUrl = getUrl(nextItem);
    var vol = Settings.getVideoSettings();

    settings = Settings.load();
    // [2026-09-11] Pass interval for random video start feature
    ImagePreloader.preloadNext(nextUrl, nextItem.type, vol, settings.interval);
    timer = setTimeout(transition, settings.interval * 1000);
  }

  function transition() {
    var nextIdx = (index + 1) % media.length;
    var nextItem = media[nextIdx];
    var nextUrl = getUrl(nextItem);
    var afterIdx = (nextIdx + 1) % media.length;
    var afterItem = media[afterIdx];
    var afterUrl = getUrl(afterItem);
    var vol = Settings.getVideoSettings();

    settings = Settings.load();
    // [2026-09-11] Pass interval for random video start feature
    ImagePreloader.swap(afterUrl, afterItem.type, vol, settings.interval);
    index = nextIdx;

    timer = setTimeout(transition, settings.interval * 1000);
  }

  return { start };
})();

document.addEventListener("DOMContentLoaded", function() {
  YankunApp.start();
});
