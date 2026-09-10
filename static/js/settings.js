const Settings = (() => {
  const DEFAULTS = {
    fit: "cover", interval: 30, transition: 1500, shuffle: 0,
    videoMuted: false, videoVolume: 80
  };

  function load() {
    try {
      const raw = localStorage.getItem("yankunframe_settings");
      if (raw) return Object.assign({}, DEFAULTS, JSON.parse(raw));
    } catch (e) {}
    return { ...DEFAULTS };
  }

  function save(s) { localStorage.setItem("yankunframe_settings", JSON.stringify(s)); }

  function getVideoSettings() {
    var s = load();
    return { muted: s.videoMuted, volume: s.videoVolume };
  }

  function applyToUI(s) {
    // Custom selects: set trigger text + mark selected option
    selectOption("set-fit", s.fit);
    selectOption("set-interval", String(s.interval));
    selectOption("set-transition", String(s.transition));
    selectOption("set-shuffle", String(s.shuffle));

    document.getElementById("set-video-muted").checked = s.videoMuted;
    document.getElementById("set-video-volume").value = s.videoVolume;
    document.getElementById("vol-label").textContent = s.videoVolume + "%";
    document.getElementById("vol-row").style.display = s.videoMuted ? "none" : "";

    var dur = (s.transition / 1000) + "s";
    ["img-a","img-b","vid-a","vid-b"].forEach(function(id) {
      var el = document.getElementById(id);
      el.style.transitionDuration = dur;
      el.style.objectFit = s.fit;
    });
  }

  function selectOption(containerId, value) {
    var container = document.getElementById(containerId);
    var trigger = container.querySelector(".custom-select-trigger");
    var options = container.querySelectorAll("li");
    for (var i = 0; i < options.length; i++) {
      options[i].classList.remove("selected");
      if (options[i].getAttribute("data-value") === value) {
        options[i].classList.add("selected");
        trigger.textContent = options[i].textContent;
      }
    }
  }

  function readFromUI() {
    return {
      fit: readSelectValue("set-fit"),
      interval: parseInt(readSelectValue("set-interval")),
      transition: parseInt(readSelectValue("set-transition")),
      shuffle: parseInt(readSelectValue("set-shuffle")),
      videoMuted: document.getElementById("set-video-muted").checked,
      videoVolume: parseInt(document.getElementById("set-video-volume").value)
    };
  }

  function readSelectValue(containerId) {
    var container = document.getElementById(containerId);
    var selected = container.querySelector("li.selected");
    return selected ? selected.getAttribute("data-value") : "";
  }

  // ── Media Dirs Management ──────────────────────────────
  async function loadMediaDirs() {
    try {
      var cfg = await YankunAPI.fetchConfig();
      renderMediaDirs(cfg.media_dirs || []);
    } catch (e) {
      console.warn("Failed to load media dirs:", e);
    }
  }

  function renderMediaDirs(dirs) {
    var list = document.getElementById("media-dirs-list");
    list.innerHTML = "";
    dirs.forEach(function(d, i) {
      var item = document.createElement("div");
      item.className = "media-dir-item";
      item.innerHTML = '<span>' + d + '</span>' +
        '<button data-idx="' + i + '">✕</button>';
      list.appendChild(item);
    });
    // Bind remove buttons
    list.querySelectorAll("button").forEach(function(btn) {
      btn.addEventListener("click", async function() {
        var idx = parseInt(this.getAttribute("data-idx"));
        var newDirs = dirs.filter(function(_, i) { return i !== idx; });
        try {
          await YankunAPI.updateMediaDirs(newDirs);
          renderMediaDirs(newDirs);
        } catch (e) { console.warn("Failed to update media dirs:", e); }
      });
    });
  }

  // ── Custom Select Dropdowns ─────────────────────────────
  function setupCustomSelects() {
    var selects = document.querySelectorAll(".custom-select");
    var activeSelect = null;

    selects.forEach(function(select) {
      var trigger = select.querySelector(".custom-select-trigger");

      trigger.addEventListener("click", function(e) {
        e.stopPropagation();
        // Close other open selects
        if (activeSelect && activeSelect !== select) {
          activeSelect.classList.remove("open");
        }
        // Toggle this one
        select.classList.toggle("open");
        activeSelect = select.classList.contains("open") ? select : null;
      });

      select.querySelectorAll("li").forEach(function(li) {
        li.addEventListener("click", function(e) {
          e.stopPropagation();
          var value = li.getAttribute("data-value");
          // Update UI
          selectOption(select.id, value);
          // Close dropdown
          select.classList.remove("open");
          activeSelect = null;
          // Save settings
          var s = readFromUI();
          save(s);
          applyToUI(s);
        });
      });
    });

    // Close any open select on outside click
    document.addEventListener("click", function() {
      if (activeSelect) {
        activeSelect.classList.remove("open");
        activeSelect = null;
      }
    });
  }

  function setupPanel() {
    var icon = document.getElementById("settings-icon");
    var panel = document.getElementById("settings-panel");
    var timer = null;

    // Show icon + cursor on mouse move; hide icon after idle
    document.addEventListener("mousemove", function() {
      icon.classList.add("visible");
      clearTimeout(timer);
      timer = setTimeout(function() {
        icon.classList.remove("visible");
      }, 3000);
    });

    icon.addEventListener("click", function() {
      panel.classList.remove("hidden");
      panel.classList.add("visible");
      loadMediaDirs();
    });

    document.getElementById("settings-close").addEventListener("click", function() {
      panel.classList.remove("visible");
      panel.classList.add("hidden");
    });

    // Setup custom select dropdowns
    setupCustomSelects();

    // Video controls
    document.getElementById("set-video-muted").addEventListener("change", function() {
      var s = readFromUI();
      save(s);
      applyToUI(s);
    });

    document.getElementById("set-video-volume").addEventListener("change", function() {
      var s = readFromUI();
      save(s);
      applyToUI(s);
    });

    // Volume slider live update
    document.getElementById("set-video-volume").addEventListener("input", function() {
      document.getElementById("vol-label").textContent = this.value + "%";
    });

    // Add media dir button
    document.getElementById("btn-add-dir").addEventListener("click", async function() {
      var input = document.getElementById("new-media-dir");
      var val = input.value.trim();
      if (!val) return;
      try {
        var cfg = await YankunAPI.fetchConfig();
        var dirs = cfg.media_dirs || [];
        if (dirs.indexOf(val) === -1) {
          dirs.push(val);
          await YankunAPI.updateMediaDirs(dirs);
          renderMediaDirs(dirs);
        }
        input.value = "";
      } catch (e) { console.warn("Failed to add dir:", e); }
    });
  }

  return { load, save, applyToUI, readFromUI, setupPanel,
           getVideoSettings, loadMediaDirs };
})();
