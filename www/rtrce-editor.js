/* =============================================================================
 * rtrce-editor.js -- CodeMirror bridge for the R-TRCE Code Assistant Studio
 * Copyright (c) 2026 Asterov Labs. All Rights Reserved.
 * Licensed under the Asterov Labs Proprietary Software License.
 * =============================================================================
 * WHAT   Turns a plain <textarea> into an R-aware code editor with line numbers,
 *        syntax highlighting, bracket matching and IDE keyboard shortcuts, and
 *        bridges it to the Shiny server in both directions.
 *
 * WHY    The Studio could show code but not edit it, which is the difference
 *        between reading about R and working in it. CodeMirror is vendored under
 *        www/codemirror (MIT) rather than fetched from a CDN so the Studio still
 *        works offline and on an air-gapped machine.
 *
 * HOW    Shiny serves every file under www/ automatically, so this module only
 *        has to (1) initialise an editor for each textarea.rtrce-editor, (2) push
 *        the document to the server on a short debounce, and (3) apply commands
 *        the server sends back (replace document, mark lines, focus).
 *
 * Keyboard shortcuts, matching RStudio where sensible:
 *   Ctrl/Cmd+Enter        run the selection, or the statement at the cursor
 *   Ctrl/Cmd+Shift+Enter  run the whole file
 *   Ctrl/Cmd+S            ask the server to save
 *   Ctrl/Cmd+/            comment / uncomment (CodeMirror addon)
 * ============================================================================= */

(function () {
  "use strict";

  var DEBOUNCE_MS = 300;
  var editors = {};                 // textarea id -> { cm, lastSent, ... }
  var pendingTimers = {};

  // Shiny renamed onInputChange to setInputValue; support both so the Studio
  // keeps working on older Shiny installs.
  //
  // The priority must be "event" or "immediate" -- Shiny *throws* on anything
  // else ("Unexpected input value mode"), and because the calls below run inside
  // debounce timers that exception is invisible: the input simply never arrives.
  // That is exactly how the editor status line and document sync silently did
  // nothing until the browser smoke test caught it.
  var VALID_PRIORITIES = { event: true, immediate: true };

  function sendInput(name, value, priority) {
    var opts = { priority: VALID_PRIORITIES[priority] ? priority : "event" };
    try {
      if (window.Shiny && Shiny.setInputValue) {
        Shiny.setInputValue(name, value, opts);
      } else if (window.Shiny && Shiny.onInputChange) {
        Shiny.onInputChange(name, value);
      }
    } catch (err) {
      // Surface it rather than losing the update quietly.
      noteError("send " + name, err);
      if (window.console && console.error) {
        console.error("R-TRCE: could not send input '" + name + "':", err);
      }
    }
  }

  function debounce(key, fn) {
    if (pendingTimers[key]) window.clearTimeout(pendingTimers[key]);
    pendingTimers[key] = window.setTimeout(fn, DEBOUNCE_MS);
  }

  function cursorPosition(cm) {
    var cursor = cm.getCursor();
    return { line: cursor.line + 1, ch: cursor.ch + 1 };
  }

  function sendDocument(id) {
    var entry = editors[id];
    if (!entry) return;
    var value = entry.cm.getValue();
    entry.lastSent = value;
    sendInput(entry.inputName, value, "input");
  }

  function markBusy(cm, busy) {
    var wrapper = cm.getWrapperElement();
    if (busy) wrapper.classList.add("rtrce-busy");
    else wrapper.classList.remove("rtrce-busy");
  }

  // Ask the server to run something. The server owns the R parser, so it works
  // out what "the statement at the cursor" means; the editor only reports where
  // the cursor is and what is selected.
  function requestRun(entry, mode) {
    if (mode === "all") {
      sendInput(entry.runInput, { scope: "all", nonce: Date.now() }, "event");
      return;
    }
    var selection = entry.cm.getSelection();
    var payload = {
      scope: selection && selection.length > 0 ? "selection" : "statement",
      text: selection || "",
      line: cursorPosition(entry.cm).line,
      nonce: Date.now()
    };
    sendInput(entry.runInput, payload, "event");
  }

  // Up/Down in the console input: only recall history when the caret is on the
  // boundary line, so a multi-line statement can still be edited with arrows.
  function historyRequest(id, cm, direction) {
    var entry = editors[id];
    if (!entry || !entry.historyInput) return;
    var cursor = cm.getCursor();
    var lastLine = cm.lastLine();
    if (direction === "older" && cursor.line !== 0) { CodeMirror.commands.goLineUp(cm); return; }
    if (direction === "newer" && cursor.line !== lastLine) { CodeMirror.commands.goLineDown(cm); return; }
    sendInput(entry.historyInput, { direction: direction, nonce: Date.now() }, "event");
  }

  function initEditor(textarea) {
    var id = textarea.id;
    if (editors[id] || !window.CodeMirror) return;

    var consoleMode = textarea.getAttribute("data-mode") === "console";

    var extraKeys = {
      "Ctrl-Enter": function () { requestRun(editors[id], "run"); },
      "Cmd-Enter": function () { requestRun(editors[id], "run"); },
      "Ctrl-Shift-Enter": function () { requestRun(editors[id], "all"); },
      "Cmd-Shift-Enter": function () { requestRun(editors[id], "all"); },
      "Ctrl-S": function () { sendInput("editor_save_request", Date.now(), "event"); },
      "Cmd-S": function () { sendInput("editor_save_request", Date.now(), "event"); },
      "Ctrl-/": "toggleComment",
      "Cmd-/": "toggleComment"
    };

    if (consoleMode) {
      // A console is a prompt, not a document: Enter submits, Shift+Enter adds a
      // line, and Up/Down recall history unless the caret is inside a multi-line
      // statement (then the arrow keys move the caret, as they should).
      extraKeys = {
        "Enter": function (cm) {
          var entry = editors[id];
          if (!entry) return;
          sendInput(entry.runInput, { text: cm.getValue(), nonce: Date.now() }, "event");
        },
        "Shift-Enter": function (cm) { cm.replaceSelection("\n"); },
        "Up": function (cm) { historyRequest(id, cm, "older"); },
        "Down": function (cm) { historyRequest(id, cm, "newer"); }
      };
    }

    var cm = CodeMirror.fromTextArea(textarea, {
      mode: "r",
      lineNumbers: !consoleMode,
      lineWrapping: true,
      indentUnit: 2,
      tabSize: 2,
      indentWithTabs: false,
      matchBrackets: true,
      autoCloseBrackets: !consoleMode,
      styleActiveLine: !consoleMode,
      // Reserved now so the teaching layer can attach per-line hints later
      // without restructuring the editor.
      gutters: consoleMode ? [] : ["CodeMirror-linenumbers", "rtrce-hints"],
      extraKeys: extraKeys
    });

    editors[id] = {
      cm: cm,
      inputName: textarea.getAttribute("data-shiny-input") || (id + "_content"),
      runInput: textarea.getAttribute("data-shiny-run") || "editor_run_request",
      historyInput: textarea.getAttribute("data-shiny-history"),
      consoleMode: consoleMode,
      lastSent: cm.getValue()
    };

    cm.on("change", function () {
      debounce("doc-" + id, function () { sendDocument(id); });
    });

    // Cursor movement is reported on the same debounce: it feeds the status bar
    // and, later, the teaching layer -- not every keystroke deserves a round trip.
    cm.on("cursorActivity", function () {
      debounce("cursor-" + id, function () {
        sendInput("editor_cursor", {
          line: cursorPosition(cm).line,
          total: cm.lineCount(),
          selection_length: cm.getSelection().length
        }, "input");
      });
    });
  }

  function eachEditor(fn) {
    Object.keys(editors).forEach(function (id) { fn(id, editors[id]); });
  }

  // --- Server -> client commands -------------------------------------------
  // Counters are exposed on window.rtrceDebug: when a pane "does nothing" the
  // first question is whether the message arrived, and this answers it from the
  // browser console without a rebuild.
  function noteDebug(kind) {
    window.rtrceDebug = window.rtrceDebug || { setCode: 0, highlightLines: 0, gutterHints: 0, focus: 0 };
    window.rtrceDebug[kind] = (window.rtrceDebug[kind] || 0) + 1;
  }

  // Shiny requires every custom-message handler to declare exactly one argument,
  // and *throws* otherwise ("handler must be a function that takes one argument").
  // That throw happens during registration, so it silently disabled every handler
  // registered after the offending one: the run highlight and the gutter hints
  // never fired while setCode (registered first) worked fine. Normalising the
  // signature here removes the trap, and a failure is recorded rather than taking
  // the rest of the bridge down with it.
  function registerHandler(type, handler) {
    var wrapped = function (msg) { return handler(msg); };
    try {
      Shiny.addCustomMessageHandler(type, wrapped);
    } catch (err) {
      noteError("register " + type, err);
    }
  }

  function registerHandlers() {
    if (!window.Shiny || !Shiny.addCustomMessageHandler) return;

    registerHandler("rtrce:setCode", function (msg) {
      noteDebug("setCode");
      eachEditor(function (id, entry) {
        if (msg.target && id !== msg.target) return;
        if (entry.cm.getValue() === msg.code) {
          entry.lastSent = msg.code;
          return;                      // already in sync: leave the caret alone
        }
        var cursor = entry.cm.getCursor();
        entry.cm.setValue(msg.code);
        entry.cm.setCursor(cursor);    // keep the caret where the user left it
        entry.lastSent = msg.code;
      });
    });

    registerHandler("rtrce:focus", function (msg) {
      noteDebug("focus");
      eachEditor(function (id, entry) { entry.cm.focus(); });
    });

    registerHandler("rtrce:setBusy", function (msg) {
      eachEditor(function (id, entry) { markBusy(entry.cm, !!(msg && msg.busy)); });
    });

    // Mark the lines that were just run, the way an IDE does.
    registerHandler("rtrce:highlightLines", function (msg) {
      noteDebug("highlightLines");
      eachEditor(function (id, entry) {
        entry.cm.eachLine(function (line) {
          entry.cm.removeLineClass(line, "background", "rtrce-ran");
        });
        if (!msg.from) return;
        // Fill the whole range, not just its ends: a run should look like a
        // highlighted block, which is how an IDE shows "this is what I executed".
        var last = msg.to && msg.to >= msg.from ? msg.to : msg.from;
        for (var line = msg.from; line <= last; line++) {
          entry.cm.addLineClass(line - 1, "background", "rtrce-ran");
        }
        if (msg.scroll !== false) entry.cm.scrollIntoView({ line: msg.from - 1, ch: 0 }, 60);
      });
    });

    // Per-line hints in the reserved gutter, used by the teaching layer.
    registerHandler("rtrce:setGutterHints", function (msg) {
      noteDebug("gutterHints");
      eachEditor(function (id, entry) {
        entry.cm.clearGutter("rtrce-hints");
        (msg.hints || []).forEach(function (hint) {
          if (hint.line < 1 || hint.line > entry.cm.lineCount()) return;
          var el = document.createElement("span");
          el.className = "rtrce-hint rtrce-hint-" + (hint.kind || "info");
          el.textContent = hint.icon || "\u25CF";
          el.title = hint.text || "";
          entry.cm.setGutterMarker(hint.line - 1, "rtrce-hints", el);
        });
      });
    });
  }

  function initAll() {
    var nodes = document.querySelectorAll("textarea.rtrce-editor");
    Array.prototype.forEach.call(nodes, initEditor);
  }

  // The editor does not publish its document on connect: the textarea's rendered
  // content is byte-exact (see studio_editor_ui in R/studio_editor.R) and the
  // server pushes its document on load, so the two start identical without a
  // "wait until connected" dance whose timing can silently fail.

  function noteError(where, err) {
    window.rtrceDebug = window.rtrceDebug || { setCode: 0, highlightLines: 0, gutterHints: 0, focus: 0 };
    window.rtrceDebug.errors = window.rtrceDebug.errors || [];
    window.rtrceDebug.errors.push(where + ": " + (err && err.message ? err.message : String(err)));
  }

  // The editor no longer publishes its document on connect: the textarea's
  // rendered content is byte-exact (see studio_editor_ui) and the server pushes
  // its document on load, so the two start identical without a fragile
  // "wait until connected" dance.
  function boot() {
    if (!window.CodeMirror) {
      // The vendored assets are missing (partial checkout): leave the plain
      // textarea in place so the Studio still works, just without highlighting.
      if (window.console && console.warn) {
        console.warn("R-TRCE: CodeMirror assets not found under www/codemirror; " +
                     "falling back to a plain text editor.");
      }
      return;
    }
    initAll();
    registerHandlers();
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", boot);
  } else {
    boot();
  }

  // Shiny renders some panes after first paint; re-scan so late textareas work.
  document.addEventListener("shiny:value", initAll);

  window.rtrceEditor = { init: initAll, ids: function () { return Object.keys(editors); } };
})();
