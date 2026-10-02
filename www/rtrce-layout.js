/* =============================================================================
 * rtrce-layout.js -- IDE shell behaviour for the R-TRCE Studio
 * Copyright (c) 2026 Asterov Labs. All Rights Reserved.
 * Licensed under the Asterov Labs Proprietary Software License.
 * =============================================================================
 * WHAT   The parts of the shell that are pure browser behaviour: draggable pane
 *        splitters, the light/dark theme switch, keeping CodeMirror sized
 *        correctly, and the keyboard-shortcut sheet.
 *
 * WHY    These are what make the app feel like a desktop IDE rather than a web
 *        page: panes you can resize, a theme that remembers you, an editor that
 *        never renders into a stale box, and shortcuts you can look up. None of
 *        it needs the server, so none of it costs a round trip.
 *
 * HOW    Sizes are written as the same CSS custom properties the theme uses
 *        (--rt-bottom-h, --rt-rail-w) and remembered in localStorage. Listeners
 *        are attached defensively so a missing element never breaks the shell.
 * ============================================================================= */

(function () {
  "use strict";

  var STORE_SPLIT = "rtrce.split";
  var STORE_THEME = "rtrce.theme";

  function store(key, value) {
    try { window.localStorage.setItem(key, value); } catch (e) { /* private mode */ }
  }
  function recall(key) {
    try { return window.localStorage.getItem(key); } catch (e) { return null; }
  }
  function root() { return document.documentElement; }

  // --- Splitters ------------------------------------------------------------
  // Clamped to sane ranges so a pane can never be dragged to nothing and become
  // unreachable. Double-clicking a splitter restores the default layout.
  function initSplitters() {
    var splits = [
      { el: document.querySelector('[data-split="bottom"]'), varName: "--rt-bottom-h",
        axis: "y", min: 120, max: function () { return window.innerHeight - 260; } },
      { el: document.querySelector('[data-split="rail"]'), varName: "--rt-rail-w",
        axis: "x", min: 280, max: function () { return window.innerWidth - 460; } }
    ];

    var saved = recall(STORE_SPLIT);
    if (saved) {
      try {
        var sizes = JSON.parse(saved);
        if (sizes.bottom) root().style.setProperty("--rt-bottom-h", sizes.bottom + "px");
        if (sizes.rail) root().style.setProperty("--rt-rail-w", sizes.rail + "px");
      } catch (e) { /* ignore a corrupt value */ }
    }

    splits.forEach(function (spec) {
      if (!spec.el) return;
      var dragging = false;
      spec.el.addEventListener("pointerdown", function (event) {
        dragging = true;
        try { spec.el.setPointerCapture(event.pointerId); } catch (e) {}
        document.body.style.userSelect = "none";
        event.preventDefault();
      });
      spec.el.addEventListener("pointermove", function (event) {
        if (!dragging) return;
        var size = spec.axis === "y" ? (window.innerHeight - event.clientY)
                                     : (window.innerWidth - event.clientX);
        size = Math.max(spec.min, Math.min(spec.max(), size));
        root().style.setProperty(spec.varName, size + "px");
        refreshEditors();
      });
      spec.el.addEventListener("pointerup", function (event) {
        if (!dragging) return;
        dragging = false;
        try { spec.el.releasePointerCapture(event.pointerId); } catch (e) {}
        document.body.style.userSelect = "";
        store(STORE_SPLIT, JSON.stringify({
          bottom: parseInt(getComputedStyle(root()).getPropertyValue("--rt-bottom-h"), 10) || 300,
          rail: parseInt(getComputedStyle(root()).getPropertyValue("--rt-rail-w"), 10) || 420
        }));
      });
      spec.el.addEventListener("dblclick", function () {
        root().style.removeProperty(spec.varName);
        refreshEditors();
      });
    });
  }

  // --- Theme ----------------------------------------------------------------
  // Themes: "cassie" (Dark coat, white ruff & socks, orange blaze), "mocha" (Catppuccin Mocha), "latte" (Light)
  function applyTheme(theme) {
    root().setAttribute("data-rtrce-theme", theme);
    var label = document.getElementById("rtrce-theme-label");
    if (label) {
      if (theme === "cassie") label.textContent = "Cassie 🐾";
      else if (theme === "latte") label.textContent = "Light";
      else label.textContent = "Dark";
    }
  }

  function initTheme() {
    applyTheme(recall(STORE_THEME) || "cassie");
    var button = document.getElementById("rtrce-theme-toggle");
    if (!button) return;
    button.addEventListener("click", function () {
      var current = root().getAttribute("data-rtrce-theme") || "cassie";
      var next = "mocha";
      if (current === "mocha") next = "cassie";
      else if (current === "cassie") next = "latte";
      else next = "mocha";
      applyTheme(next);
      store(STORE_THEME, next);
      refreshEditors();
    });
  }

  // --- Editor sizing --------------------------------------------------------
  // CodeMirror measures its container; when a pane resizes it must be told, or it
  // keeps rendering into the old box (the classic half-drawn editor bug).
  function refreshEditors() {
    document.querySelectorAll(".CodeMirror").forEach(function (node) {
      if (node.CodeMirror) node.CodeMirror.refresh();
    });
  }

  function initResizeHandling() {
    var timer = null;
    window.addEventListener("resize", function () {
      window.clearTimeout(timer);
      timer = window.setTimeout(refreshEditors, 120);
    });
    if (window.ResizeObserver) {
      var host = document.querySelector(".rtrce-editor-host");
      if (host) new ResizeObserver(function () { refreshEditors(); }).observe(host);
    }
  }

  // --- Keyboard shortcut sheet ---------------------------------------------
  var SHORTCUTS = [
    ["Ctrl / Cmd + Shift + P", "Command Palette"],
    ["Ctrl / Cmd + Enter", "Run the selection, or the statement at the cursor"],
    ["Ctrl / Cmd + Shift + Enter", "Run the whole file"],
    ["Ctrl / Cmd + S", "Save back to the file you opened"],
    ["Ctrl / Cmd + /", "Comment or uncomment the selection"],
    ["Enter (in console)", "Submit the command"],
    ["Shift + Enter (console)", "Add another line before submitting"],
    ["Up / Down (console)", "Recall previous commands"],
    ["?", "Show or hide this sheet"],
    ["Esc", "Close this sheet"]
  ];

  function buildSheet() {
    var overlay = document.createElement("div");
    overlay.id = "rtrce-shortcuts";
    overlay.setAttribute("role", "dialog");
    overlay.setAttribute("aria-label", "Keyboard shortcuts");
    overlay.style.cssText =
      "position:fixed;inset:0;background:rgba(17,17,27,.72);backdrop-filter:blur(3px);" +
      "display:none;align-items:center;justify-content:center;z-index:9000;";

    var rows = SHORTCUTS.map(function (pair) {
      return '<tr><td style="padding:6px 14px 6px 0;white-space:nowrap;"><kbd>' + pair[0] +
             "</kbd></td><td style=\"padding:6px 0;color:var(--rt-text-muted);\">" + pair[1] + "</td></tr>";
    }).join("");

    overlay.innerHTML =
      '<div style="background:var(--rt-mantle);border:1px solid var(--rt-border);' +
      "border-radius:var(--rt-radius-lg);padding:22px 24px;max-width:560px;width:92%;" +
      'box-shadow:var(--rt-glow);">' +
      '<div style="display:flex;align-items:center;gap:10px;margin-bottom:14px;">' +
      '<img src="rtrce/brand/asterov-icon.svg" width="24" height="24" alt="">' +
      '<strong style="font-size:15px;">Keyboard shortcuts</strong>' +
      '<button id="rtrce-shortcuts-close" class="rtrce-icon-btn" style="margin-left:auto;" ' +
      'aria-label="Close">&#10005;</button></div>' +
      '<table style="width:100%;font-size:12.5px;border-collapse:collapse;">' + rows + "</table>" +
      "</div>";

    document.body.appendChild(overlay);

    function hide() { overlay.style.display = "none"; }
    function toggle() {
      overlay.style.display = overlay.style.display === "flex" ? "none" : "flex";
    }
    overlay.addEventListener("click", function (event) { if (event.target === overlay) hide(); });
    var close = overlay.querySelector("#rtrce-shortcuts-close");
    if (close) close.addEventListener("click", hide);
    document.addEventListener("keydown", function (event) {
      if (event.key === "Escape") { hide(); return; }

      if ((event.ctrlKey || event.metaKey) && event.shiftKey && event.key.toLowerCase() === "p") {
        event.preventDefault();
        if (window.rtrce && window.rtrce.openPalette) {
          window.rtrce.openPalette();
        }
        return;
      }

      var target = event.target || {};
      var typing = /^(INPUT|TEXTAREA|SELECT)$/.test(target.tagName || "") ||
                   target.isContentEditable ||
                   (target.closest && target.closest(".CodeMirror"));
      if (!typing && (event.key === "?" || (event.key === "/" && event.shiftKey))) {
        event.preventDefault();
        toggle();
      }
    });
    return toggle;
  }

  function init() {
    initTheme();
    initSplitters();
    initResizeHandling();
    var toggle = buildSheet();
    var help = document.getElementById("rtrce-help-toggle");
    if (help) help.addEventListener("click", toggle);
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", init);
  } else {
    init();
  }

  window.rtrceLayout = { refreshEditors: refreshEditors };
})();
