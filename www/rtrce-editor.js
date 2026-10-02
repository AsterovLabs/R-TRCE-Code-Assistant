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

  // --- Find & Replace Modal Bar ---------------------------------------------
  var findDialog = null;

  function ensureFindDialog(cm) {
    if (findDialog) return findDialog;
    var el = document.createElement("div");
    el.className = "rtrce-find-bar";
    el.style.cssText = "position: absolute; top: 8px; right: 16px; z-index: 100; " +
      "background: var(--rt-mantle, #181825); border: 1px solid var(--rt-border-plain, #313244); " +
      "padding: 8px 12px; border-radius: 8px; box-shadow: 0 8px 24px rgba(0,0,0,0.3); " +
      "display: flex; gap: 8px; align-items: center; font-size: 13px;";

    el.innerHTML =
      '<input type="text" id="rtrce_find_query" placeholder="Find…" style="background:var(--rt-base,#1e1e2e); color:var(--rt-text,#cdd6f4); border:1px solid var(--rt-border-plain,#313244); padding:4px 8px; border-radius:4px; width:140px;" />' +
      '<input type="text" id="rtrce_replace_query" placeholder="Replace…" style="background:var(--rt-base,#1e1e2e); color:var(--rt-text,#cdd6f4); border:1px solid var(--rt-border-plain,#313244); padding:4px 8px; border-radius:4px; width:140px;" />' +
      '<button id="rtrce_find_prev" class="rtrce-btn btn-xs" title="Previous match">▲</button>' +
      '<button id="rtrce_find_next" class="rtrce-btn btn-xs" title="Next match">▼</button>' +
      '<button id="rtrce_replace_btn" class="rtrce-btn btn-xs">Replace</button>' +
      '<button id="rtrce_replace_all_btn" class="rtrce-btn btn-xs">All</button>' +
      '<button id="rtrce_find_close" class="rtrce-btn btn-xs" style="margin-left:4px;">✕</button>';

    document.body.appendChild(el);
    findDialog = el;

    var findInput = el.querySelector("#rtrce_find_query");
    var replaceInput = el.querySelector("#rtrce_replace_query");

    function doFind(rev) {
      var q = findInput.value;
      if (!q || !activeCm) return;
      var cur = activeCm.getCursor();
      var cursor = activeCm.getSearchCursor(q, rev ? cur : { line: cur.line, ch: cur.ch + 1 });
      if (!cursor.find(rev)) {
        cursor = activeCm.getSearchCursor(q, rev ? { line: activeCm.lastLine() } : { line: 0, ch: 0 });
        if (!cursor.find(rev)) return;
      }
      activeCm.setSelection(cursor.from(), cursor.to());
      activeCm.scrollIntoView({ from: cursor.from(), to: cursor.to() }, 20);
    }

    el.querySelector("#rtrce_find_next").onclick = function () { doFind(false); };
    el.querySelector("#rtrce_find_prev").onclick = function () { doFind(true); };
    findInput.onkeydown = function (e) {
      if (e.key === "Enter") {
        e.preventDefault();
        doFind(e.shiftKey);
      } else if (e.key === "Escape") {
        findDialog.style.display = "none";
        if (activeCm) activeCm.focus();
      }
    };

    el.querySelector("#rtrce_replace_btn").onclick = function () {
      if (!activeCm) return;
      var sel = activeCm.getSelection();
      var q = findInput.value;
      var repl = replaceInput.value;
      if (sel && sel.toLowerCase() === q.toLowerCase()) {
        activeCm.replaceSelection(repl);
      }
      doFind(false);
    };

    el.querySelector("#rtrce_replace_all_btn").onclick = function () {
      if (!activeCm) return;
      var q = findInput.value;
      var repl = replaceInput.value;
      if (!q) return;
      var cursor = activeCm.getSearchCursor(q);
      activeCm.operation(function () {
        while (cursor.findNext()) {
          cursor.replace(repl);
        }
      });
    };

    el.querySelector("#rtrce_find_close").onclick = function () {
      findDialog.style.display = "none";
      if (activeCm) activeCm.focus();
    };

    return findDialog;
  }

  var activeCm = null;

  function showFindReplace(cm, withReplace) {
    activeCm = cm;
    var dlg = ensureFindDialog(cm);
    dlg.style.display = "flex";
    var repl = dlg.querySelector("#rtrce_replace_query");
    var replBtn = dlg.querySelector("#rtrce_replace_btn");
    var replAll = dlg.querySelector("#rtrce_replace_all_btn");
    if (withReplace) {
      repl.style.display = "";
      replBtn.style.display = "";
      replAll.style.display = "";
    } else {
      repl.style.display = "none";
      replBtn.style.display = "none";
      replAll.style.display = "none";
    }
    var sel = cm.getSelection();
    var findInput = dlg.querySelector("#rtrce_find_query");
    if (sel && sel.indexOf("\n") === -1) findInput.value = sel;
    findInput.focus();
    findInput.select();
  }

  // --- Autocomplete / IntelliSense popup ------------------------------------
  var autocompletePopup = null;
  var activeAutocomplete = null;

  function closeAutocomplete() {
    if (autocompletePopup && autocompletePopup.parentNode) {
      autocompletePopup.parentNode.removeChild(autocompletePopup);
    }
    autocompletePopup = null;
    activeAutocomplete = null;
  }

  function triggerAutocomplete(id, cm) {
    var cur = cm.getCursor();
    var line = cm.getLine(cur.line);
    var before = line.slice(0, cur.ch);
    var match = before.match(/([A-Za-z0-9_.]+(\$[A-Za-z0-9_.]*)?)$/);
    if (!match) return false;
    var prefix = match[1];
    var startCh = cur.ch - prefix.length;
    sendInput("editor_complete_request", {
      prefix: prefix,
      line: cur.line,
      startCh: startCh,
      endCh: cur.ch,
      id: id,
      nonce: Date.now()
    }, "event");
    return true;
  }

  function handleTabAutocomplete(id, cm) {
    if (autocompletePopup && activeAutocomplete) {
      insertCompletion(activeAutocomplete.selectedIndex);
      return true;
    }
    var cur = cm.getCursor();
    var line = cm.getLine(cur.line);
    var before = line.slice(0, cur.ch);
    if (/^\s*$/.test(before)) return false;
    if (/[A-Za-z0-9_.]$/.test(before)) {
      return triggerAutocomplete(id, cm);
    }
    return false;
  }

  function insertCompletion(index) {
    if (!activeAutocomplete) return;
    var token = activeAutocomplete.tokens[index];
    if (!token) return;
    var cm = activeAutocomplete.cm;
    cm.replaceRange(token, { line: activeAutocomplete.line, ch: activeAutocomplete.startCh }, { line: activeAutocomplete.line, ch: activeAutocomplete.endCh });
    closeAutocomplete();
    cm.focus();
  }

  function updateAutocompleteSelection(delta) {
    if (!activeAutocomplete || !autocompletePopup) return;
    var items = autocompletePopup.querySelectorAll(".rtrce-autocomplete-item");
    if (!items || items.length === 0) return;
    var newIdx = activeAutocomplete.selectedIndex + delta;
    if (newIdx < 0) newIdx = items.length - 1;
    if (newIdx >= items.length) newIdx = 0;
    activeAutocomplete.selectedIndex = newIdx;
    for (var i = 0; i < items.length; i++) {
      if (i === newIdx) {
        items[i].style.backgroundColor = "var(--rt-surface0, #313244)";
        items[i].scrollIntoView({ block: "nearest" });
      } else {
        items[i].style.backgroundColor = "";
      }
    }
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
      "Cmd-/": "toggleComment",
      "Ctrl-F": function (cm) { showFindReplace(cm, false); },
      "Cmd-F": function (cm) { showFindReplace(cm, false); },
      "Ctrl-H": function (cm) { showFindReplace(cm, true); },
      "Cmd-Alt-F": function (cm) { showFindReplace(cm, true); },
      "Ctrl-Space": function (cm) { triggerAutocomplete(id, cm); },
      "Tab": function (cm) {
        if (handleTabAutocomplete(id, cm)) return;
        cm.execCommand("defaultTab");
      }
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

    cm.on("keydown", function (cmInstance, e) {
      if (autocompletePopup && activeAutocomplete) {
        if (e.keyCode === 38) {
          e.preventDefault();
          updateAutocompleteSelection(-1);
          return;
        } else if (e.keyCode === 40) {
          e.preventDefault();
          updateAutocompleteSelection(1);
          return;
        } else if (e.keyCode === 13 || e.keyCode === 9) {
          e.preventDefault();
          insertCompletion(activeAutocomplete.selectedIndex);
          return;
        } else if (e.keyCode === 27) {
          e.preventDefault();
          closeAutocomplete();
          return;
        }
      }
    });

    cm.on("blur", function () {
      window.setTimeout(function () {
        if (!autocompletePopup) return;
        closeAutocomplete();
      }, 200);
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

    registerHandler("rtrce:showCompletions", function (msg) {
      closeAutocomplete();
      if (!msg || !msg.tokens || msg.tokens.length === 0) return;
      var entry = editors[msg.target];
      if (!entry) return;
      var cm = entry.cm;

      activeAutocomplete = {
        id: msg.target,
        cm: cm,
        line: msg.line,
        startCh: msg.startCh,
        endCh: msg.endCh,
        tokens: msg.tokens,
        selectedIndex: 0
      };

      var coords = cm.charCoords({ line: msg.line, ch: msg.startCh }, "page");
      var popup = document.createElement("div");
      popup.className = "rtrce-autocomplete-menu";
      popup.style.cssText = "position: absolute; left: " + coords.left + "px; top: " + (coords.bottom + 2) + "px; " +
        "background: var(--rt-mantle, #181825); border: 1px solid var(--rt-border-plain, #313244); " +
        "border-radius: 6px; box-shadow: 0 8px 24px rgba(0,0,0,0.35); max-height: 200px; overflow-y: auto; " +
        "min-width: 180px; z-index: 2000; font-family: monospace; font-size: 12px; padding: 4px 0;";

      msg.tokens.forEach(function (tok, idx) {
        var item = document.createElement("div");
        item.className = "rtrce-autocomplete-item";
        item.style.cssText = "padding: 4px 10px; cursor: pointer; color: var(--rt-text, #cdd6f4); display: flex; justify-content: space-between; align-items: center;";
        if (idx === 0) item.style.backgroundColor = "var(--rt-surface0, #313244)";

        var isDollar = tok.indexOf("$") !== -1;
        item.innerHTML = '<span>' + tok + '</span><span style="font-size:10px; opacity:0.6; margin-left:8px;">' + (isDollar ? 'col' : 'fn') + '</span>';

        item.addEventListener("mousedown", function (e) {
          e.preventDefault();
          insertCompletion(idx);
        });
        popup.appendChild(item);
      });

      document.body.appendChild(popup);
      autocompletePopup = popup;
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
