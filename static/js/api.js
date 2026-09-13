const YankunAPI = (() => {
  const IMAGE_PIPELINE_VERSION = "original-jpeg-v1";

  async function fetchMediaList() {
    const resp = await fetch("/api/images");
    if (!resp.ok) throw new Error("API error: " + resp.status);
    return resp.json();
  }

  async function fetchConfig() {
    const resp = await fetch("/api/config");
    if (!resp.ok) throw new Error("API error: " + resp.status);
    return resp.json();
  }

  async function updateMediaDirs(dirs) {
    const resp = await fetch("/api/config/media-dirs", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ dirs: dirs })
    });
    if (!resp.ok) throw new Error("API error: " + resp.status);
    return resp.json();
  }

  function getImageUrl(filename) {
    return "/image/" + encodeURIComponent(filename) +
      "?v=" + IMAGE_PIPELINE_VERSION;
  }

  function getMediaUrl(filename) {
    return "/media/" + encodeURIComponent(filename);
  }

  return { fetchMediaList, fetchConfig, updateMediaDirs,
           getImageUrl, getMediaUrl };
})();
