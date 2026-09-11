const ImagePreloader = (() => {
  let imgA = null, imgB = null, activeSlot = 0;

  function isVideo(url) {
    return url && url.startsWith("/media/");
  }

  function getEl(slot) {
    var prefix = slot === 0 ? "img-a" : "img-b";
    return document.getElementById(prefix);
  }

  function getVid(slot) {
    var prefix = slot === 0 ? "vid-a" : "vid-b";
    return document.getElementById(prefix);
  }

  async function loadImage(url) {
    return new Promise((resolve, reject) => {
      const img = new Image();
      img.onload = () => img.decode().then(() => resolve(img));
      img.onerror = () => reject(new Error("Load failed: " + url));
      img.src = url;
    });
  }

  function hideAll() {
    ["img-a","img-b","vid-a","vid-b"].forEach(function(id) {
      var el = document.getElementById(id);
      el.classList.remove("active");
      el.src = "";
      if (el.tagName === "VIDEO") {
        el.pause();
        el.removeAttribute("src");
      }
    });
  }

  // ── Random video start time ──────────────────────────────
  // Picks a random currentTime so the clip shows a different
  // segment each time.  Leaves at least displayInterval seconds
  // before the end so the video stays on screen for the full
  // display duration without reaching the end marker.
  // [2026-09-11] Added random video start feature.
  function _setupRandomStart(vid, displayInterval) {
    vid.addEventListener('loadedmetadata', function onMeta() {
      var duration = vid.duration;
      if (duration && isFinite(duration) && duration > displayInterval) {
        var maxStart = duration - displayInterval;
        vid.currentTime = Math.random() * maxStart;
      }
    }, { once: true });
  }

  function showMedia(slot, url, mediaType, volumeSettings) {
    var isVid = (mediaType === "video");
    var imgEl = getEl(slot);
    var vidEl = getVid(slot);

    // Hide both, then show the right one
    imgEl.classList.remove("active");
    imgEl.src = "";
    vidEl.classList.remove("active");
    vidEl.pause();
    vidEl.removeAttribute("src");

    if (isVid) {
      vidEl.src = url;
      vidEl.muted = volumeSettings.muted;
      vidEl.volume = volumeSettings.volume / 100;
      vidEl.load();
      vidEl.classList.add("active");
      vidEl.play().catch(function(e) { console.warn("Video play prevented:", e); });
    } else {
      imgEl.src = url;
      imgEl.classList.add("active");
    }
  }

  function setCurrent(url, mediaType, volumeSettings, displayInterval) {
    hideAll();
    var slot = 0;
    if (mediaType === "video") {
      var vid = getVid(slot);
      // [2026-09-11] Random video start: wait for metadata then
      // seek to a random position before playing.
      vid.addEventListener('loadedmetadata', function onMeta() {
        var duration = vid.duration;
        if (duration && isFinite(duration) && duration > displayInterval) {
          var maxStart = duration - displayInterval;
          vid.currentTime = Math.random() * maxStart;
        }
        vid.play().catch(function(e) { console.warn("Video play prevented:", e); });
      }, { once: true });
      vid.src = url;
      vid.muted = volumeSettings.muted;
      vid.volume = volumeSettings.volume / 100;
      vid.load();
      vid.classList.add("active");
      activeSlot = 0;
    } else {
      var img = getEl(slot);
      img.src = url;
      img.classList.add("active");
      activeSlot = 0;
    }
  }

  async function preloadNext(url, mediaType, volumeSettings, displayInterval) {
    var nextSlot = 1 - activeSlot;
    if (mediaType === "video") {
      var vid = getVid(nextSlot);
      // [2026-09-11] Pre-seek the preloaded video to a random
      // position so it's ready when swapped in.
      _setupRandomStart(vid, displayInterval);
      vid.src = url;
      vid.muted = volumeSettings.muted;
      vid.volume = volumeSettings.volume / 100;
      vid.load();
    } else {
      try {
        await loadImage(url);
        var el = getEl(nextSlot);
        el.src = url;
      } catch (e) { console.warn(e); return null; }
    }
    return true;
  }

  function swap(nextUrl, nextType, volumeSettings, displayInterval) {
    var oldImg = getEl(activeSlot);
    var oldVid = getVid(activeSlot);
    oldImg.classList.remove("active");
    oldImg.src = "";
    oldVid.classList.remove("active");
    oldVid.pause();
    oldVid.removeAttribute("src");

    var newSlot = 1 - activeSlot;
    if (nextUrl && nextType) {
      if (nextType === "video") {
        var newVid = getVid(newSlot);
        newVid.classList.add("active");
        newVid.play().catch(function(e) { console.warn("Video play prevented:", e); });
      } else {
        getEl(newSlot).classList.add("active");
      }
    } else {
      // already preloaded
      getEl(newSlot).classList.add("active");
      var newVid = getVid(newSlot);
      if (newVid.src && newVid.src !== window.location.href) {
        newVid.play().catch(function(e) { console.warn("Video play prevented:", e); });
      }
    }
    activeSlot = newSlot;

    if (nextUrl) preloadNext(nextUrl, nextType, volumeSettings, displayInterval);
  }

  return { loadImage, setCurrent, preloadNext, swap, hideAll };
})();
