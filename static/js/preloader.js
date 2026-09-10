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
    } else {
      imgEl.src = url;
      imgEl.classList.add("active");
    }
  }

  function setCurrent(url, mediaType, volumeSettings) {
    hideAll();
    var slot = 0;
    if (mediaType === "video") {
      var vid = getVid(slot);
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

  async function preloadNext(url, mediaType, volumeSettings) {
    var nextSlot = 1 - activeSlot;
    if (mediaType === "video") {
      var vid = getVid(nextSlot);
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

  function swap(nextUrl, nextType, volumeSettings) {
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
        getVid(newSlot).classList.add("active");
      } else {
        getEl(newSlot).classList.add("active");
      }
    } else {
      // already preloaded
      getEl(newSlot).classList.add("active");
      getVid(newSlot).classList.add("active");
      // only one is actually loaded
    }
    activeSlot = newSlot;

    if (nextUrl) preloadNext(nextUrl, nextType, volumeSettings);
  }

  return { loadImage, setCurrent, preloadNext, swap, hideAll };
})();
