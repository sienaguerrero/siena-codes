(function () {
  "use strict";
  var Y2K = window.Y2K = window.Y2K || {};

  Y2K.motion = function (reduce) {
    var root = document.documentElement;
    if (reduce) root.setAttribute("data-motion", "reduce");
    else root.removeAttribute("data-motion");
  };

  Y2K.tabs = function (list) {
    var tabs = Array.prototype.slice.call(list.querySelectorAll('[role="tab"]'));
    if (!tabs.length || list.dataset.y2kReady) return;
    list.dataset.y2kReady = "true";
    var select = function (tab, focus, quiet) {
      tabs.forEach(function (t) {
        var on = t === tab;
        t.setAttribute("aria-selected", on ? "true" : "false");
        t.setAttribute("tabindex", on ? "0" : "-1");
        var id = t.getAttribute("aria-controls");
        var panel = id && document.getElementById(id);
        if (panel) panel.hidden = !on;
      });
      if (focus) tab.focus();
      if (!quiet) list.dispatchEvent(new CustomEvent("y2k:tab", { bubbles: true, detail: { tab: tab, value: tab.dataset.value || tab.textContent.trim() } }));
    };
    tabs.forEach(function (t) {
      t.addEventListener("click", function () { select(t, false, false); });
      t.addEventListener("keydown", function (e) {
        var i = tabs.indexOf(t), n = tabs.length, next = null;
        if (e.key === "ArrowRight") next = tabs[(i + 1) % n];
        else if (e.key === "ArrowLeft") next = tabs[(i - 1 + n) % n];
        else if (e.key === "Home") next = tabs[0];
        else if (e.key === "End") next = tabs[n - 1];
        if (next) { e.preventDefault(); select(next, true, false); }
      });
    });
    var current = tabs.filter(function (t) { return t.getAttribute("aria-selected") === "true"; })[0] || tabs[0];
    select(current, false, true);
  };

  Y2K.ticker = function (ticker) {
    var btn = ticker.querySelector(".y2k-ticker-pause");
    if (!btn || ticker.dataset.y2kReady) return;
    ticker.dataset.y2kReady = "true";
    var set = function (paused) {
      ticker.classList.toggle("is-paused", paused);
      btn.setAttribute("aria-pressed", paused ? "true" : "false");
      btn.setAttribute("aria-label", paused ? "Resume the ticker" : "Pause the ticker");
      btn.textContent = paused ? "▶" : "‖";
    };
    set(ticker.classList.contains("is-paused"));
    btn.addEventListener("click", function () { set(!ticker.classList.contains("is-paused")); });
  };

  Y2K.init = function (root) {
    root = root || document;
    root.querySelectorAll('.y2k-tabs[role="tablist"]').forEach(Y2K.tabs);
    root.querySelectorAll(".y2k-ticker").forEach(Y2K.ticker);
  };

  if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", function () { Y2K.init(); });
  else Y2K.init();
})();
