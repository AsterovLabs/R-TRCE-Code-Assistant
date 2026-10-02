(function() {
  'use strict';

  var COMMANDS = [
    // Run
    { id: 'run-line',    label: 'Run Line / Selection',     keys: 'Ctrl+Enter',       group: 'Run',   action: function() { clickBtn('editor_run_line'); } },
    { id: 'run-all',     label: 'Run All',                  keys: 'Ctrl+Shift+Enter', group: 'Run',   action: function() { clickBtn('editor_run_all'); } },
    // File
    { id: 'save',        label: 'Save File',                keys: 'Ctrl+S',           group: 'File',  action: function() { clickBtn('editor_save'); } },
    // Edit
    { id: 'find',        label: 'Find in Document',         keys: 'Ctrl+F',           group: 'Edit',  action: function() { triggerFind(false); } },
    { id: 'replace',     label: 'Find & Replace',           keys: 'Ctrl+H',           group: 'Edit',  action: function() { triggerFind(true); } },
    // View
    { id: 'toggle-theme', label: 'Toggle Light/Dark Theme', keys: '',                 group: 'View',  action: function() { clickBtn('btn_theme_toggle'); } },
    { id: 'focus-console', label: 'Focus Console',          keys: '',                 group: 'View',  action: function() { focusConsole(); } },
    { id: 'focus-editor',  label: 'Focus Editor',           keys: '',                 group: 'View',  action: function() { focusEditor(); } },
    // Navigate
    { id: 'tab-console',     label: 'Show Console Tab',      keys: '', group: 'Navigate', action: function() { clickTab('Console'); } },
    { id: 'tab-project',     label: 'Show Project Tab',      keys: '', group: 'Navigate', action: function() { clickTab('Project'); } },
    { id: 'tab-walkthrough', label: 'Show Guided Walkthrough', keys: '', group: 'Navigate', action: function() { clickTab('Guided Walkthrough'); } },
    { id: 'tab-annotated',   label: 'Show Annotated Code',   keys: '', group: 'Navigate', action: function() { clickTab('Annotated Code & Traces'); } },
    { id: 'tab-explain',     label: 'Show Architecture',     keys: '', group: 'Navigate', action: function() { clickTab('Architectural Explanation'); } },
    { id: 'tab-ast',         label: 'Show AST & Tokens',     keys: '', group: 'Navigate', action: function() { clickTab('AST & Parse Tokens'); } },
    { id: 'tab-student',     label: 'Show Student Studio',   keys: '', group: 'Navigate', action: function() { clickTab('🎓 Student Studio'); } },
    // Rail panes
    { id: 'tab-learn',     label: 'Show Learn Pane',        keys: '', group: 'Navigate', action: function() { clickTab('Learn'); } },
    { id: 'tab-env',       label: 'Show Environment',       keys: '', group: 'Navigate', action: function() { clickTab('Environment'); } },
    { id: 'tab-files',     label: 'Show Files',             keys: '', group: 'Navigate', action: function() { clickTab('Files'); } },
    { id: 'tab-plots',     label: 'Show Plots',             keys: '', group: 'Navigate', action: function() { clickTab('Plots'); } },
    { id: 'tab-packages',  label: 'Show Packages',          keys: '', group: 'Navigate', action: function() { clickTab('Packages'); } },
    { id: 'tab-help',      label: 'Show Help',              keys: '', group: 'Navigate', action: function() { clickTab('Help'); } },
    // Session
    { id: 'restart',      label: 'Restart R Session',       keys: '',  group: 'Session', action: function() { clickBtn('btn_console_restart'); } },
    { id: 'clear',         label: 'Clear Console',          keys: '',  group: 'Session', action: function() { clickBtn('btn_console_clear'); } },
    // Help
    { id: 'shortcuts',    label: 'Show Keyboard Shortcuts', keys: '?', group: 'Help',    action: function() { clickBtn('btn_shortcuts'); } },
  ];

  function clickBtn(id) {
    var el = document.getElementById(id);
    if (el) el.click();
  }
  function clickTab(label) {
    var links = document.querySelectorAll('.nav-tabs a, .nav-pills a');
    for (var i = 0; i < links.length; i++) {
      if (links[i].textContent.trim() === label) { links[i].click(); return; }
    }
  }
  function focusConsole() {
    var el = document.getElementById('console_source');
    if (el && el._cmInstance) el._cmInstance.focus();
  }
  function focusEditor() {
    var el = document.getElementById('editor_source');
    if (el && el._cmInstance) el._cmInstance.focus();
  }
  function triggerFind(withReplace) {
    focusEditor();
    var el = document.getElementById('editor_source');
    if (el && el._cmInstance) {
      var evt = new KeyboardEvent('keydown', {
        key: withReplace ? 'h' : 'f',
        ctrlKey: true,
        bubbles: true
      });
      el._cmInstance.getInputField().dispatchEvent(evt);
    }
  }

  var backdrop, input, resultsContainer;
  var currentMatches = [];
  var selectedIndex = 0;
  var isOpen = false;

  function init() {
    backdrop = document.createElement('div');
    backdrop.className = 'rtrce-palette-backdrop';
    backdrop.style.display = 'none';

    var card = document.createElement('div');
    card.className = 'rtrce-palette';

    input = document.createElement('input');
    input.className = 'rtrce-palette-input';
    input.type = 'text';
    input.placeholder = 'Type a command...';

    resultsContainer = document.createElement('div');
    resultsContainer.className = 'rtrce-palette-results';

    card.appendChild(input);
    card.appendChild(resultsContainer);
    backdrop.appendChild(card);
    document.body.appendChild(backdrop);

    backdrop.addEventListener('click', function(e) {
      if (e.target === backdrop) closePalette();
    });

    input.addEventListener('input', function() {
      renderResults(input.value);
    });

    input.addEventListener('keydown', function(e) {
      if (!isOpen) return;
      if (e.key === 'Escape') {
        e.preventDefault();
        closePalette();
      } else if (e.key === 'ArrowDown') {
        e.preventDefault();
        setSelectedIndex(selectedIndex + 1);
      } else if (e.key === 'ArrowUp') {
        e.preventDefault();
        setSelectedIndex(selectedIndex - 1);
      } else if (e.key === 'Enter') {
        e.preventDefault();
        executeSelected();
      }
    });
  }

  function getRecentIds() {
    try {
      var val = localStorage.getItem('rtrce.palette.recent');
      return val ? JSON.parse(val) : [];
    } catch (e) {
      return [];
    }
  }

  function addRecentId(id) {
    var recent = getRecentIds();
    recent = recent.filter(function(r) { return r !== id; });
    recent.unshift(id);
    if (recent.length > 5) recent = recent.slice(0, 5);
    try {
      localStorage.setItem('rtrce.palette.recent', JSON.stringify(recent));
    } catch (e) {}
  }

  function scoreMatch(query, label) {
    if (!query) return 1;
    query = query.toLowerCase();
    label = label.toLowerCase();
    var qLen = query.length;
    var lLen = label.length;
    if (qLen > lLen) return 0;
    if (qLen === 0) return 1;

    var index = label.indexOf(query);
    if (index === -1) {
      var qIdx = 0;
      for (var i = 0; i < lLen; i++) {
        if (label[i] === query[qIdx]) {
          qIdx++;
          if (qIdx === qLen) return 0.1;
        }
      }
      return 0;
    }
    
    if (index === 0) return 10;
    if (label[index - 1] === ' ') return 5;
    return 1;
  }

  function renderResults(query) {
    resultsContainer.innerHTML = '';
    currentMatches = [];

    var scored = COMMANDS.map(function(cmd) {
      return { cmd: cmd, score: scoreMatch(query, cmd.label) };
    });

    if (!query) {
      var recentIds = getRecentIds();
      if (recentIds.length > 0) {
        var recentCmds = recentIds.map(function(id) {
          return COMMANDS.filter(function(c) { return c.id === id; })[0];
        }).filter(Boolean);
        
        if (recentCmds.length > 0) {
          addGroup('Recent', recentCmds);
        }
      }
      var groups = {};
      COMMANDS.forEach(function(cmd) {
        if (!groups[cmd.group]) groups[cmd.group] = [];
        groups[cmd.group].push(cmd);
      });
      for (var g in groups) {
        addGroup(g, groups[g]);
      }
    } else {
      var matched = scored.filter(function(item) { return item.score > 0; });
      matched.sort(function(a, b) {
        if (b.score !== a.score) return b.score - a.score;
        return a.cmd.label.localeCompare(b.cmd.label);
      });

      var groups = {};
      matched.forEach(function(item) {
        if (!groups[item.cmd.group]) groups[item.cmd.group] = [];
        groups[item.cmd.group].push(item.cmd);
      });

      for (var g in groups) {
        addGroup(g, groups[g]);
      }
    }

    if (currentMatches.length === 0) {
      var empty = document.createElement('div');
      empty.className = 'rtrce-palette-empty';
      empty.textContent = 'No matching commands';
      resultsContainer.appendChild(empty);
    }

    setSelectedIndex(0);
  }

  function addGroup(groupName, cmds) {
    var groupEl = document.createElement('div');
    groupEl.className = 'rtrce-palette-group';
    groupEl.textContent = groupName;
    resultsContainer.appendChild(groupEl);

    cmds.forEach(function(cmd) {
      var idx = currentMatches.length;
      currentMatches.push(cmd);

      var itemEl = document.createElement('div');
      itemEl.className = 'rtrce-palette-item';
      itemEl.dataset.index = idx;
      
      var labelEl = document.createElement('span');
      labelEl.textContent = cmd.label;
      itemEl.appendChild(labelEl);

      if (cmd.keys) {
        var keysEl = document.createElement('span');
        keysEl.className = 'rtrce-palette-keys';
        keysEl.textContent = cmd.keys;
        itemEl.appendChild(keysEl);
      }

      itemEl.addEventListener('mouseenter', function() {
        setSelectedIndex(idx);
      });
      itemEl.addEventListener('click', function(e) {
        e.stopPropagation();
        executeSelected();
      });

      resultsContainer.appendChild(itemEl);
    });
  }

  function setSelectedIndex(index) {
    if (currentMatches.length === 0) return;
    if (index < 0) index = currentMatches.length - 1;
    if (index >= currentMatches.length) index = 0;
    
    var items = resultsContainer.querySelectorAll('.rtrce-palette-item');
    if (items[selectedIndex]) items[selectedIndex].classList.remove('active');
    
    selectedIndex = index;
    var activeItem = items[selectedIndex];
    if (activeItem) {
      activeItem.classList.add('active');
      activeItem.scrollIntoView({ block: 'nearest' });
    }
  }

  function executeSelected() {
    var cmd = currentMatches[selectedIndex];
    if (cmd) {
      addRecentId(cmd.id);
      closePalette();
      setTimeout(function() {
        cmd.action();
      }, 50);
    }
  }

  function openPalette() {
    if (!backdrop) init();
    isOpen = true;
    input.value = '';
    backdrop.style.display = 'flex';
    renderResults('');
    setTimeout(function() {
      input.focus();
    }, 10);
  }

  function closePalette() {
    isOpen = false;
    if (backdrop) backdrop.style.display = 'none';
  }

  window.rtrce = window.rtrce || {};
  window.rtrce.openPalette = openPalette;

})();
