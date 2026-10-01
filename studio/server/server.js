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

const PORT = parseInt(process.env.PORT || process.argv[2] || '8084', 10);
const HOST = process.env.HOST || '127.0.0.1';
const ROOT_DIR = path.resolve(__dirname, '..', '..');
const CLIENT_DIST = path.resolve(__dirname, '..', 'client', 'dist');

// ============================================================================
// 1. Long-Running R Worker Process Manager
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

class RWorker {
  constructor(scriptPath) {
    this.scriptPath = scriptPath;
    this.process = null;
    this.pendingRequests = new Map();
    this.reqCounter = 0;
    this.isReady = false;
    this.readyCallbacks = [];
    this.rVersion = null;
    this.pid = null;
    this.rscriptBin = findRscript();
    this.start();
  }

  start() {
    console.log(`[R-Worker] Spawning R worker process: "${this.rscriptBin}" "${this.scriptPath}"`);
    this.process = spawn(this.rscriptBin, [this.scriptPath], {
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
          console.log(`[R-Worker] Ready (PID: ${msg.pid}, R: ${msg.r_version})`);
          this.isReady = true;
          this.rVersion = msg.r_version;
          while (this.readyCallbacks.length > 0) {
            this.readyCallbacks.shift()();
          }
          return;
        }

        if (msg.id && this.pendingRequests.has(msg.id)) {
          const { resolve } = this.pendingRequests.get(msg.id);
          this.pendingRequests.delete(msg.id);
          resolve(msg);
        }
      } catch (err) {
        console.error('[R-Worker] Failed to parse stdout line:', line, err);
      }
    });

    this.process.on('exit', (code, signal) => {
      console.warn(`[R-Worker] Exited with code ${code}, signal ${signal}`);
      this.isReady = false;
      for (const [id, req] of this.pendingRequests.entries()) {
        req.reject(new Error(`R Worker exited with code ${code}`));
      }
      this.pendingRequests.clear();
      // Auto-restart after 1s
      setTimeout(() => this.start(), 1000);
    });

    this.process.on('error', (err) => {
      console.error('[R-Worker] Process error:', err);
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
    const id = `req-${++this.reqCounter}-${Date.now()}`;
    const message = JSON.stringify({ id, action, payload }) + '\n';

    return new Promise((resolve, reject) => {
      const timer = setTimeout(() => {
        if (this.pendingRequests.has(id)) {
          this.pendingRequests.delete(id);
          reject(new Error(`Timeout waiting for R-Worker action '${action}'`));
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

const rWorker = new RWorker(path.join(__dirname, 'r_worker.R'));

// ============================================================================
// 2. Express Application Setup
// ============================================================================

const app = express();
app.use(cors());
app.use(express.json({ limit: '20mb' }));

// Health and Status
app.get('/api/status', async (req, res) => {
  try {
    const ping = await rWorker.send('ping');
    res.json({
      status: 'online',
      r_version: rWorker.rVersion,
      worker_pid: rWorker.pid,
      root_dir: ROOT_DIR,
      details: ping.result
    });
  } catch (err) {
    res.status(500).json({ status: 'error', error: err.message });
  }
});

// Generic R Action Dispatcher
app.post('/api/r/action', async (req, res) => {
  const { action, payload } = req.body;
  if (!action) {
    return res.status(400).json({ ok: false, error: 'Missing action field' });
  }

  try {
    const response = await rWorker.send(action, payload || {});
    if (!response.ok) {
      return res.status(400).json({ ok: false, error: response.error });
    }
    res.json(response);
  } catch (err) {
    res.status(500).json({ ok: false, error: err.message });
  }
});

// Bundled Samples
app.get('/api/samples', async (req, res) => {
  try {
    const samplesDir = path.join(ROOT_DIR, 'samples');
    if (!fs.existsSync(samplesDir)) {
      return res.json({ samples: [] });
    }

    const files = fs.readdirSync(samplesDir).filter(f => f.endsWith('.R'));
    const samples = files.map(filename => {
      const fullPath = path.join(samplesDir, filename);
      const content = fs.readFileSync(fullPath, 'utf8');
      return {
        name: filename,
        path: fullPath,
        content: content,
        size: fs.statSync(fullPath).size
      };
    });

    res.json({ samples });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// File Browser & Management
app.get('/api/files', (req, res) => {
  const dirPath = req.query.dir ? path.resolve(ROOT_DIR, req.query.dir) : ROOT_DIR;

  // Basic security check: prevent directory traversal outside root
  if (!dirPath.startsWith(ROOT_DIR)) {
    return res.status(403).json({ error: 'Access denied: Path outside project root' });
  }

  try {
    const items = fs.readdirSync(dirPath, { withFileTypes: true })
      .filter(item => !item.name.startsWith('.git') && item.name !== 'node_modules' && item.name !== 'dist')
      .map(item => {
        const itemPath = path.join(dirPath, item.name);
        const relPath = path.relative(ROOT_DIR, itemPath);
        return {
          name: item.name,
          path: itemPath,
          relPath: relPath,
          isDirectory: item.isDirectory(),
          isR: item.name.endsWith('.R') || item.name.endsWith('.r'),
          size: item.isDirectory() ? 0 : fs.statSync(itemPath).size
        };
      })
      .sort((a, b) => {
        if (a.isDirectory && !b.isDirectory) return -1;
        if (!a.isDirectory && b.isDirectory) return 1;
        return a.name.localeCompare(b.name);
      });

    res.json({ currentDir: dirPath, relativeDir: path.relative(ROOT_DIR, dirPath), items });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.post('/api/files/read', (req, res) => {
  const filePath = req.body.path;
  if (!filePath) {
    return res.status(400).json({ error: 'Missing path parameter' });
  }

  const resolved = path.resolve(ROOT_DIR, filePath);
  if (!resolved.startsWith(ROOT_DIR)) {
    return res.status(403).json({ error: 'Access denied' });
  }

  try {
    if (!fs.existsSync(resolved)) {
      return res.status(404).json({ error: 'File not found' });
    }
    const content = fs.readFileSync(resolved, 'utf8');
    res.json({ path: resolved, relativePath: path.relative(ROOT_DIR, resolved), content });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.post('/api/files/write', (req, res) => {
  const { path: filePath, content } = req.body;
  if (!filePath || typeof content !== 'string') {
    return res.status(400).json({ error: 'Missing path or content parameter' });
  }

  const resolved = path.resolve(ROOT_DIR, filePath);
  if (!resolved.startsWith(ROOT_DIR)) {
    return res.status(403).json({ error: 'Access denied' });
  }

  try {
    fs.mkdirSync(path.dirname(resolved), { recursive: true });
    fs.writeFileSync(resolved, content, 'utf8');
    res.json({ ok: true, path: resolved, relativePath: path.relative(ROOT_DIR, resolved) });
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
      if (msg.type === 'eval') {
        const response = await rWorker.send('eval', {
          code: msg.code,
          timeout: msg.timeout || 10,
          wd: msg.wd
        });
        ws.send(JSON.stringify({
          type: 'eval_result',
          id: msg.id,
          ok: response.ok,
          result: response.result,
          error: response.error
        }));
      } else if (msg.type === 'reset') {
        const response = await rWorker.send('reset_session');
        ws.send(JSON.stringify({
          type: 'reset_result',
          id: msg.id,
          ok: response.ok,
          result: response.result
        }));
      } else if (msg.type === 'workspace') {
        const response = await rWorker.send('workspace');
        ws.send(JSON.stringify({
          type: 'workspace_result',
          id: msg.id,
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
