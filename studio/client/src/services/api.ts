/**
 * studio/client/src/services/api.ts -- REST API Service Client
 */

import { SampleScript, FileItem } from '../types';

const API_BASE = '/api';

export async function getStatus() {
  const res = await fetch(`${API_BASE}/status`);
  if (!res.ok) throw new Error(`HTTP ${res.status}: ${res.statusText}`);
  return res.json();
}

export async function getSamples(): Promise<SampleScript[]> {
  const res = await fetch(`${API_BASE}/samples`);
  if (!res.ok) throw new Error('Failed to fetch samples');
  const data = await res.json();
  return data.samples || [];
}

export async function listFiles(dir?: string): Promise<{ currentDir: string; relativeDir: string; items: FileItem[] }> {
  const query = dir ? `?dir=${encodeURIComponent(dir)}` : '';
  const res = await fetch(`${API_BASE}/files${query}`);
  if (!res.ok) throw new Error('Failed to list files');
  return res.json();
}

export async function readFile(filePath: string): Promise<{ path: string; relativePath: string; content: string }> {
  const res = await fetch(`${API_BASE}/files/read`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ path: filePath })
  });
  if (!res.ok) throw new Error('Failed to read file');
  return res.json();
}

export async function writeFile(filePath: string, content: string): Promise<{ ok: boolean; path: string }> {
  const res = await fetch(`${API_BASE}/files/write`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ path: filePath, content })
  });
  if (!res.ok) throw new Error('Failed to write file');
  return res.json();
}

export async function rAction<T = any>(action: string, payload: Record<string, any> = {}): Promise<T> {
  const res = await fetch(`${API_BASE}/r/action`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ action, payload })
  });
  const data = await res.json();
  if (!res.ok || !data.ok) {
    throw new Error(data.error || `R Action '${action}' failed`);
  }
  return data.result as T;
}
