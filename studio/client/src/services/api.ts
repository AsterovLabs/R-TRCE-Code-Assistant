/**
 * studio/client/src/services/api.ts -- REST API Service Client
 */

import { SampleScript, FileItem, RecentProject, ProjectOverview, CurrentProjectInfo } from '../types';

const API_BASE = '/api';

export async function getStatus() {
  const res = await fetch(`${API_BASE}/status`);
  if (!res.ok) throw new Error(`HTTP ${res.status}: ${res.statusText}`);
  return res.json();
}

export async function getCurrentProject(): Promise<CurrentProjectInfo> {
  const res = await fetch(`${API_BASE}/project/current`);
  if (!res.ok) throw new Error('Failed to get current project');
  return res.json();
}

export async function openProject(path: string): Promise<{ ok: boolean; activeProjectDir: string; name: string }> {
  const res = await fetch(`${API_BASE}/project/open`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ path })
  });
  if (!res.ok) {
    const err = await res.json().catch(() => ({}));
    throw new Error(err.error || 'Failed to open project');
  }
  return res.json();
}

export async function getRecentProjects(): Promise<RecentProject[]> {
  const res = await fetch(`${API_BASE}/project/recent`);
  if (!res.ok) throw new Error('Failed to get recent projects');
  const data = await res.json();
  return data.recent || [];
}

export async function getProjectOverview(): Promise<ProjectOverview> {
  const res = await fetch(`${API_BASE}/project/overview`);
  if (!res.ok) throw new Error('Failed to get project overview');
  return res.json();
}

export async function pickFolder(): Promise<{ canceled: boolean; path?: string; nativeSupported: boolean }> {
  const res = await fetch(`${API_BASE}/project/pick-folder`, { method: 'POST' });
  if (!res.ok) throw new Error('Failed to pick folder');
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

export async function langAction<T = any>(action: string, payload: Record<string, any> = {}, language?: string): Promise<T> {
  const res = await fetch(`${API_BASE}/lang/action`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ action, payload, language })
  });
  const data = await res.json();
  if (!res.ok || !data.ok) {
    throw new Error(data.error || `Action '${action}' failed`);
  }
  return data.result as T;
}

export const rAction = langAction;
