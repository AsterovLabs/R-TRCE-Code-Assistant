/**
 * studio/server/electron-main.js -- Native Desktop IDE Shell
 * Copyright (c) 2026 Asterov Labs. All Rights Reserved.
 * Licensed under the Asterov Labs Proprietary Software License.
 */

const { app, BrowserWindow, shell, nativeImage, dialog } = require('electron');
const path = require('path');
const fs = require('fs');
const http = require('http');

// Expose dialog globally for local API handlers
global.electronDialog = dialog;

// Check CLI arguments for project directory if not already in env
if (!process.env.PROJECT_DIR) {
  const dirArg = process.argv.slice(2).find(arg => 
    !arg.startsWith('-') && !/^\d+$/.test(arg) && fs.existsSync(arg) && fs.statSync(arg).isDirectory()
  );
  if (dirArg) {
    process.env.PROJECT_DIR = path.resolve(dirArg);
  }
}

// Bypass sandbox restrictions on Linux when not setuid-root
app.commandLine.appendSwitch('no-sandbox');
app.commandLine.appendSwitch('disable-gpu-sandbox');

// Set application identity for X11/Wayland window managers and taskbars
if (process.platform === 'win32' && typeof app.setAppUserModelId === 'function') {
  app.setAppUserModelId('com.asterovlabs.rtrcestudio');
}
app.setName('R-TRCE Studio');

const PORT = parseInt(process.env.PORT || '8084', 10);
const HOST = process.env.HOST || '127.0.0.1';
process.env.PORT = String(PORT);
process.env.HOST = HOST;

let mainWindow = null;

function getAppIconPath() {
  const candidates = [
    path.join(__dirname, '..', 'client', 'public', 'brand', 'asterov-icon.png'),
    path.join(__dirname, '..', 'client', 'dist', 'brand', 'asterov-icon.png'),
    path.join(__dirname, '..', '..', 'www', 'brand', 'asterov-icon.png'),
    path.join(process.env.HOME || '', '.local', 'share', 'icons', 'hicolor', '512x512', 'apps', 'rtrce-studio.png'),
    path.join(__dirname, '..', 'client', 'public', 'brand', 'asterov-icon.svg')
  ];
  for (const candidate of candidates) {
    if (fs.existsSync(candidate)) {
      return candidate;
    }
  }
  return undefined;
}

function getAppIcon() {
  const iconPath = getAppIconPath();
  if (iconPath && iconPath.endsWith('.png')) {
    const img = nativeImage.createFromPath(iconPath);
    if (!img.isEmpty()) return img;
  }
  return iconPath;
}

function startBackend() {
  require('./server.js');
}

function waitForServer(callback, maxRetries = 50) {
  let retries = 0;
  const check = () => {
    const req = http.get(`http://${HOST}:${PORT}/api/status`, (res) => {
      if (res.statusCode === 200) {
        callback();
      } else {
        retry();
      }
    });
    req.on('error', () => retry());
    req.end();
  };

  const retry = () => {
    retries++;
    if (retries > maxRetries) {
      console.warn('Backend server poll timeout, opening window directly');
      callback();
      return;
    }
    setTimeout(check, 100);
  };

  check();
}

function createWindow() {
  const appIcon = getAppIcon();
  const iconPath = getAppIconPath();

  mainWindow = new BrowserWindow({
    title: 'R-TRCE Code Assistant -- Asterov Labs',
    width: 1440,
    height: 900,
    minWidth: 1024,
    minHeight: 640,
    backgroundColor: '#181825',
    icon: appIcon || iconPath,
    webPreferences: {
      nodeIntegration: false,
      contextIsolation: true
    },
    show: false
  });
  global.mainWindow = mainWindow;

  if (appIcon && typeof mainWindow.setIcon === 'function') {
    try {
      mainWindow.setIcon(appIcon);
    } catch (_) {}
  }

  mainWindow.loadURL(`http://${HOST}:${PORT}`);

  mainWindow.once('ready-to-show', () => {
    if (appIcon && typeof mainWindow.setIcon === 'function') {
      try {
        mainWindow.setIcon(appIcon);
      } catch (_) {}
    }
    mainWindow.show();
  });

  mainWindow.webContents.setWindowOpenHandler(({ url }) => {
    if (url.startsWith('http:') || url.startsWith('https:')) {
      if (!url.includes(`localhost:${PORT}`) && !url.includes(`127.0.0.1:${PORT}`)) {
        shell.openExternal(url);
        return { action: 'deny' };
      }
    }
    return { action: 'allow' };
  });

  mainWindow.on('closed', () => {
    mainWindow = null;
    global.mainWindow = null;
  });
}

const gotLock = app.requestSingleInstanceLock();
if (!gotLock) {
  app.quit();
} else {
  app.on('second-instance', () => {
    if (mainWindow) {
      if (mainWindow.isMinimized()) mainWindow.restore();
      mainWindow.focus();
    }
  });

  app.whenReady().then(() => {
    startBackend();
    waitForServer(() => {
      createWindow();
    });

    app.on('activate', () => {
      if (BrowserWindow.getAllWindows().length === 0) {
        createWindow();
      }
    });
  });

  app.on('window-all-closed', () => {
    app.quit();
    process.exit(0);
  });
}
