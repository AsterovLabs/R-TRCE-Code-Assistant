/**
 * studio/server/server.js -- R-TRCE Code Assistant Local Studio Backend Daemon
 * Copyright (c) 2026 Asterov Labs. All Rights Reserved.
 * Licensed under the Asterov Labs Proprietary Software License.
 */

const express = require('express');
const cors = require('cors');
const http = require('http');
const { WebSocketServer } = require('ws');
const { spawn } = require('child_process');
const path = require('path');
const fs = require('fs');
const readline = require('readline');

const rawPortArg = process.argv.slice(2).find(arg => /^\d+$/.test(arg));
const PORT = parseInt(process.env.PORT || rawPortArg || '8084', 10);
const HOST = process.env.HOST || '127.0.0.1';
const ROOT_DIR = path.resolve(__dirname, '..', '..');
const CLIENT_DIST = path.resolve(__dirname, '..', 'client', 'dist');

let activeProjectDir = process.env.PROJECT_DIR ? path.resolve(process.env.PROJECT_DIR) : ROOT_DIR;
const CONFIG_DIR = path.join(process.env.HOME || process.env.USERPROFILE || '.', '.r-trce-code-assistant');
const RECENT_PROJECTS_FILE = path.join(CONFIG_DIR, 'recent_projects.json');

function getRecentProjects() {
  try {
    if (fs.existsSync(RECENT_PROJECTS_FILE)) {
      return JSON.parse(fs.readFileSync(RECENT_PROJECTS_FILE, 'utf8'));
    }
  } catch (e) {}
  return [];
}

function saveRecentProject(dirPath) {
  try {
    fs.mkdirSync(CONFIG_DIR, { recursive: true });
    let recents = getRecentProjects().filter(p => p.path !== dirPath);
    recents.unshift({
      path: dirPath,
      name: path.basename(dirPath),
      lastOpened: new Date().toISOString()
    });
    recents = recents.slice(0, 20);
    fs.writeFileSync(RECENT_PROJECTS_FILE, JSON.stringify(recents, null, 2), 'utf8');
  } catch (e) {}
}

saveRecentProject(activeProjectDir);

// ============================================================================
// 1. Polyglot Language Worker Process Manager
// ============================================================================

function findRscript() {
  if (process.env.RSCRIPT_BIN && fs.existsSync(process.env.RSCRIPT_BIN)) {
    return process.env.RSCRIPT_BIN;
  }
  if (process.env.R_ENV) {
    const candidate = path.join(process.env.R_ENV, 'bin', process.platform === 'win32' ? 'Rscript.exe' : 'Rscript');
    if (fs.existsSync(candidate)) return candidate;
  }
  if (process.env.RTRCE_R_HOME) {
    const candidate = path.join(process.env.RTRCE_R_HOME, 'bin', process.platform === 'win32' ? 'Rscript.exe' : 'Rscript');
    if (fs.existsSync(candidate)) return candidate;
  }

  if (process.platform === 'win32') {
    const programFiles = process.env['ProgramFiles'] || 'C:\\Program Files';
    const rDir = path.join(programFiles, 'R');
    if (fs.existsSync(rDir)) {
      try {
        const entries = fs.readdirSync(rDir).filter(name => name.startsWith('R-'));
        for (const entry of entries) {
          const candidate = path.join(rDir, entry, 'bin', 'Rscript.exe');
          if (fs.existsSync(candidate)) return candidate;
        }
      } catch (e) {}
    }
    return 'Rscript.exe';
  }

  const home = process.env.HOME || process.env.USERPROFILE || '';
  if (home) {
    const localCandidate = path.join(home, '.r-env', 'bin', 'Rscript');
    if (fs.existsSync(localCandidate)) return localCandidate;
  }

  return 'Rscript';
}

function findPython() {
  if (process.env.PYTHON_BIN && fs.existsSync(process.env.PYTHON_BIN)) {
    return process.env.PYTHON_BIN;
  }
  return process.platform === 'win32' ? 'python.exe' : 'python3';
}

class LanguageWorker {
  constructor(name, command, scriptArgs, languageKey) {
    this.name = name;
    this.command = command;
    this.scriptArgs = scriptArgs;
    this.languageKey = languageKey;
    this.process = null;
    this.pendingRequests = new Map();
    this.reqCounter = 0;
    this.isReady = false;
    this.readyCallbacks = [];
    this.version = null;
    this.pid = null;
    this.start();
  }

  start() {
    console.log(`[${this.name}-Worker] Spawning worker process: "${this.command}" ${this.scriptArgs.map(a => `"${a}"`).join(' ')}`);
    this.process = spawn(this.command, this.scriptArgs, {
      cwd: ROOT_DIR,
      stdio: ['pipe', 'pipe', 'inherit'],
      shell: process.platform === 'win32',
      env: { ...process.env, PYTHONUNBUFFERED: '1' }
    });

    this.pid = this.process.pid;

    const rl = readline.createInterface({
      input: this.process.stdout,
      terminal: false
    });

    rl.on('line', (line) => {
      line = line.trim();
      if (!line) return;

      try {
        const msg = JSON.parse(line);
        if (msg.event === 'ready') {
          console.log(`[${this.name}-Worker] Ready (PID: ${msg.pid}, version: ${msg.r_version || msg.version})`);
          this.isReady = true;
          this.version = msg.r_version || msg.version;
          while (this.readyCallbacks.length > 0) {
            this.readyCallbacks.shift()();
          }
          if (activeProjectDir) {
            this.send('open_project', { path: activeProjectDir })
              .then(() => console.log(`[${this.name}-Worker] Project initialized at: ${activeProjectDir}`))
              .catch(err => console.warn(`[${this.name}-Worker] Project init warning:`, err.message));
          }
          return;
        }

        if (msg.id && this.pendingRequests.has(msg.id)) {
          const { resolve } = this.pendingRequests.get(msg.id);
          this.pendingRequests.delete(msg.id);
          resolve(msg);
        }
      } catch (err) {
        console.error(`[${this.name}-Worker] Failed to parse stdout line:`, line, err);
      }
    });

    this.process.on('exit', (code, signal) => {
      console.warn(`[${this.name}-Worker] Exited with code ${code}, signal ${signal}`);
      this.isReady = false;
      for (const [id, req] of this.pendingRequests.entries()) {
        req.reject(new Error(`${this.name} Worker exited with code ${code}`));
      }
      this.pendingRequests.clear();
      // Auto-restart after 1.5s
      setTimeout(() => this.start(), 1500);
    });

    this.process.on('error', (err) => {
      console.error(`[${this.name}-Worker] Process error:`, err);
    });
  }

  waitUntilReady() {
    if (this.isReady) return Promise.resolve();
    return new Promise((resolve) => {
      this.readyCallbacks.push(resolve);
    });
  }

  async send(action, payload = {}) {
    await this.waitUntilReady();
    const id = `req-${this.languageKey}-${++this.reqCounter}-${Date.now()}`;
    const message = JSON.stringify({ id, action, payload }) + '\n';

    return new Promise((resolve, reject) => {
      const timer = setTimeout(() => {
        if (this.pendingRequests.has(id)) {
          this.pendingRequests.delete(id);
          reject(new Error(`Timeout waiting for ${this.name}-Worker action '${action}'`));
        }
      }, 30000); // 30s timeout

      this.pendingRequests.set(id, {
        resolve: (val) => {
          clearTimeout(timer);
          resolve(val);
        },
        reject: (err) => {
          clearTimeout(timer);
          reject(err);
        }
      });

      this.process.stdin.write(message);
    });
  }
}

// Workers Registry
const workers = {
  r: new LanguageWorker('R', findRscript(), [path.join(__dirname, 'r_worker.R')], 'r'),
  python: new LanguageWorker('Python', findPython(), [path.join(__dirname, 'py_worker.py')], 'py'),
  javascript: new LanguageWorker('Node', process.execPath, [path.join(__dirname, 'node_worker.js')], 'js')
};

// Aliases
const rWorker = workers.r;

function detectLanguage(fileOrLang) {
  if (!fileOrLang) return 'r';
  const str = String(fileOrLang).toLowerCase();
  if (str === 'python' || str === 'py' || str.endsWith('.py') || str.endsWith('.ipynb')) {
    return 'python';
  }
  if (str === 'javascript' || str === 'js' || str === 'node' || str.endsWith('.js') || str.endsWith('.mjs') || str.endsWith('.ts')) {
    return 'javascript';
  }
  return 'r';
}

function getWorker(langOrFile) {
  const key = detectLanguage(langOrFile);
  return workers[key] || workers.r;
}

// ============================================================================
// 2. Express Application Setup
// ============================================================================

const app = express();
app.use(cors());
app.use(express.json({ limit: '20mb' }));

// Health and Status across all workers
app.get('/api/status', async (req, res) => {
  try {
    const statuses = {};
    for (const [key, w] of Object.entries(workers)) {
      try {
        const ping = await w.send('ping');
        statuses[key] = {
          online: true,
          version: w.version,
          pid: w.pid,
          details: ping.result
        };
      } catch (e) {
        statuses[key] = { online: false, error: e.message };
      }
    }

    res.json({
      status: 'online',
      root_dir: ROOT_DIR,
      active_project: activeProjectDir,
      workers: statuses,
      // Backwards compatibility fields for R
      r_version: workers.r.version,
      worker_pid: workers.r.pid
    });
  } catch (err) {
    res.status(500).json({ status: 'error', error: err.message });
  }
});

// Unified Polyglot Language Action Dispatcher
app.post(['/api/lang/action', '/api/r/action'], async (req, res) => {
  const { action, payload, language, lang } = req.body;
  if (!action) {
    return res.status(400).json({ ok: false, error: 'Missing action field' });
  }

  const requestedLang = language || lang || payload?.file || payload?.language || 'r';
  const worker = getWorker(requestedLang);

  try {
    const response = await worker.send(action, payload || {});
    if (!response.ok) {
      return res.status(400).json({ ok: false, error: response.error });
    }
    res.json(response);
  } catch (err) {
    res.status(500).json({ ok: false, error: err.message });
  }
});

// Bundled Samples
function discoverSampleFiles(dir, baseDir = dir) {
  let results = [];
  if (!fs.existsSync(dir)) return results;
  const entries = fs.readdirSync(dir, { withFileTypes: true });
  for (const entry of entries) {
    const fullPath = path.join(dir, entry.name);
    if (entry.isDirectory()) {
      results = results.concat(discoverSampleFiles(fullPath, baseDir));
    } else if (/\.(r|py|js|ts)$/i.test(entry.name)) {
      const relPath = path.relative(baseDir, fullPath);
      let size = 0;
      try {
        size = fs.statSync(fullPath).size;
      } catch (e) {
        // ignore
      }
      try {
        const content = fs.readFileSync(fullPath, 'utf8');
        results.push({
          name: relPath,
          path: fullPath,
          content: content,
          size: size,
          language: detectLanguage(entry.name)
        });
      } catch (e) {
        // ignore unreadable
      }
    }
  }
  return results;
}

app.get('/api/samples', async (req, res) => {
  try {
    const samplesDir = path.join(ROOT_DIR, 'samples');
    const samples = discoverSampleFiles(samplesDir).sort((a, b) => a.name.localeCompare(b.name));
    res.json({ samples });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Project Management Endpoints
app.get('/api/project/current', (req, res) => {
  res.json({
    path: activeProjectDir,
    name: path.basename(activeProjectDir)
  });
});

app.post('/api/project/open', async (req, res) => {
  const targetPath = req.body.path;
  if (!targetPath) {
    return res.status(400).json({ ok: false, error: 'Missing path parameter' });
  }

  const resolved = path.resolve(targetPath);
  if (!fs.existsSync(resolved) || !fs.statSync(resolved).isDirectory()) {
    return res.status(400).json({ ok: false, error: 'Directory does not exist or is not a directory' });
  }

  activeProjectDir = resolved;
  saveRecentProject(activeProjectDir);

  try {
    const workerResults = {};
    for (const [key, w] of Object.entries(workers)) {
      try {
        const r = await w.send('open_project', { path: activeProjectDir });
        workerResults[key] = r.result;
      } catch (e) {
        workerResults[key] = { error: e.message };
      }
    }
    res.json({
      ok: true,
      activeProjectDir,
      name: path.basename(activeProjectDir),
      workers: workerResults
    });
  } catch (err) {
    res.status(500).json({ ok: false, error: err.message });
  }
});

app.get('/api/project/recent', (req, res) => {
  res.json({ recent: getRecentProjects() });
});

app.get('/api/project/overview', async (req, res) => {
  try {
    const overview = await rWorker.send('project_overview', { path: activeProjectDir });
    res.json(overview.result || overview);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.post('/api/project/pick-folder', async (req, res) => {
  if (global.electronDialog) {
    try {
      const result = await global.electronDialog.showOpenDialog(global.mainWindow || undefined, {
        title: 'Open Project Directory',
        properties: ['openDirectory', 'createDirectory']
      });
      if (!result.canceled && result.filePaths && result.filePaths.length > 0) {
        activeProjectDir = result.filePaths[0];
        saveRecentProject(activeProjectDir);
        for (const w of Object.values(workers)) {
          w.send('open_project', { path: activeProjectDir }).catch(() => {});
        }
        return res.json({ canceled: false, path: result.filePaths[0], nativeSupported: true });
      }
      return res.json({ canceled: true, nativeSupported: true });
    } catch (err) {
      return res.status(500).json({ error: err.message, nativeSupported: true });
    }
  }
  res.json({ nativeSupported: false });
});

// File Browser & Management
app.get('/api/files', (req, res) => {
  const currentProject = activeProjectDir || ROOT_DIR;
  let dirPath = req.query.dir ? path.resolve(currentProject, req.query.dir) : currentProject;

  // Defensive traversal check: ensure dirPath is within currentProject OR within ROOT_DIR/samples
  const relProject = path.relative(currentProject, dirPath);
  const isInsideProject = !relProject.startsWith('..') && !path.isAbsolute(relProject);

  const samplesDir = path.join(ROOT_DIR, 'samples');
  const relSamples = path.relative(samplesDir, dirPath);
  const isInsideSamples = !relSamples.startsWith('..') && !path.isAbsolute(relSamples);

  if (!isInsideProject && !isInsideSamples) {
    return res.status(403).json({ error: 'Access denied: Path outside project root' });
  }

  try {
    if (!fs.existsSync(dirPath)) {
      return res.status(404).json({ error: 'Directory not found' });
    }
    const items = fs.readdirSync(dirPath, { withFileTypes: true })
      .filter(item => !item.name.startsWith('.git') && item.name !== 'node_modules' && item.name !== 'dist' && item.name !== '.gemini')
      .map(item => {
        const itemPath = path.join(dirPath, item.name);
        const relPath = path.relative(currentProject, itemPath);
        let isDir = item.isDirectory();
        let size = 0;
        try {
          const stat = fs.statSync(itemPath);
          isDir = stat.isDirectory();
          size = isDir ? 0 : stat.size;
        } catch (e) {
          // ignore unreadable or broken symlink
        }
        return {
          name: item.name,
          path: itemPath,
          relPath: relPath,
          isDirectory: isDir,
          isR: item.name.endsWith('.R') || item.name.endsWith('.r'),
          isPython: item.name.endsWith('.py'),
          isJs: item.name.endsWith('.js') || item.name.endsWith('.ts'),
          language: detectLanguage(item.name),
          size: size
        };
      })
      .sort((a, b) => {
        if (a.isDirectory && !b.isDirectory) return -1;
        if (!a.isDirectory && b.isDirectory) return 1;
        return a.name.localeCompare(b.name);
      });

    res.json({
      currentDir: dirPath,
      projectDir: currentProject,
      projectName: path.basename(currentProject),
      relativeDir: path.relative(currentProject, dirPath),
      items
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.post('/api/files/read', (req, res) => {
  const filePath = req.body.path;
  if (!filePath) {
    return res.status(400).json({ error: 'Missing path parameter' });
  }

  const currentProject = activeProjectDir || ROOT_DIR;
  const resolved = path.isAbsolute(filePath) ? path.resolve(filePath) : path.resolve(currentProject, filePath);

  const relProject = path.relative(currentProject, resolved);
  const isInsideProject = !relProject.startsWith('..') && !path.isAbsolute(relProject);

  const samplesDir = path.join(ROOT_DIR, 'samples');
  const relSamples = path.relative(samplesDir, resolved);
  const isInsideSamples = !relSamples.startsWith('..') && !path.isAbsolute(relSamples);

  if (!isInsideProject && !isInsideSamples) {
    return res.status(403).json({ error: 'Access denied: File outside active project or samples' });
  }

  try {
    if (!fs.existsSync(resolved)) {
      return res.status(404).json({ error: 'File not found' });
    }
    const content = fs.readFileSync(resolved, 'utf8');
    res.json({ path: resolved, relativePath: path.relative(currentProject, resolved), content });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.post('/api/files/write', (req, res) => {
  const { path: filePath, content } = req.body;
  if (!filePath || typeof content !== 'string') {
    return res.status(400).json({ error: 'Missing path or content parameter' });
  }

  const currentProject = activeProjectDir || ROOT_DIR;
  const resolved = path.isAbsolute(filePath) ? path.resolve(filePath) : path.resolve(currentProject, filePath);

  const relProject = path.relative(currentProject, resolved);
  const isInsideProject = !relProject.startsWith('..') && !path.isAbsolute(relProject);

  if (!isInsideProject) {
    return res.status(403).json({ error: 'Access denied: Write target outside active project' });
  }

  try {
    fs.mkdirSync(path.dirname(resolved), { recursive: true });
    fs.writeFileSync(resolved, content, 'utf8');
    res.json({ ok: true, path: resolved, relativePath: path.relative(currentProject, resolved) });
  } catch (err) {
    res.status(500).json({ ok: false, error: err.message });
  }
});

// Serve frontend build if available
if (fs.existsSync(CLIENT_DIST)) {
  console.log(`[HTTP] Serving static frontend build from ${CLIENT_DIST}`);
  app.use(express.static(CLIENT_DIST));
  app.get('*', (req, res) => {
    res.sendFile(path.join(CLIENT_DIST, 'index.html'));
  });
}

// ============================================================================
// 3. HTTP Server and WebSocket Terminal REPL
// ============================================================================

const server = http.createServer(app);
const wss = new WebSocketServer({ server, path: '/ws/terminal' });

wss.on('connection', (ws) => {
  console.log('[WebSocket] Client connected to live terminal stream');

  ws.on('message', async (raw) => {
    try {
      const msg = JSON.parse(raw.toString());
      const targetWorker = getWorker(msg.lang || msg.language || msg.file || 'r');

      if (msg.type === 'eval') {
        const response = await targetWorker.send('eval', {
          code: msg.code,
          timeout: msg.timeout || 10,
          wd: msg.wd || activeProjectDir
        });
        ws.send(JSON.stringify({
          type: 'eval_result',
          id: msg.id,
          lang: targetWorker.languageKey,
          ok: response.ok,
          result: response.result,
          error: response.error
        }));
      } else if (msg.type === 'reset') {
        const response = await targetWorker.send('reset_session');
        ws.send(JSON.stringify({
          type: 'reset_result',
          id: msg.id,
          lang: targetWorker.languageKey,
          ok: response.ok,
          result: response.result
        }));
      } else if (msg.type === 'workspace') {
        const response = await targetWorker.send('workspace');
        ws.send(JSON.stringify({
          type: 'workspace_result',
          id: msg.id,
          lang: targetWorker.languageKey,
          ok: response.ok,
          result: response.result
        }));
      }
    } catch (err) {
      ws.send(JSON.stringify({
        type: 'error',
        error: err.message
      }));
    }
  });

  ws.on('close', () => {
    console.log('[WebSocket] Client disconnected');
  });
});

server.listen(PORT, HOST, () => {
  console.log('================================================================');
  console.log(`  R-TRCE Code Assistant -- Local Studio Daemon`);
  console.log(`  Asterov Labs (c) 2026`);
  console.log(`  Listening on: http://${HOST}:${PORT}`);
  console.log(`  WebSocket URL: ws://${HOST}:${PORT}/ws/terminal`);
  console.log('================================================================');
});
