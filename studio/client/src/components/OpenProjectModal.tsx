/**
 * studio/client/src/components/OpenProjectModal.tsx -- R Project Selector & Folder Opener
 */

import React, { useState } from 'react';
import { Folder, FolderOpen, History, ArrowRight, X, AlertCircle } from 'lucide-react';
import { RecentProject } from '../types';

interface OpenProjectModalProps {
  isOpen: boolean;
  currentPath: string;
  recentProjects: RecentProject[];
  onOpenPath: (path: string) => Promise<void>;
  onPickFolderNative?: () => Promise<string | null>;
  onClose: () => void;
}

export const OpenProjectModal: React.FC<OpenProjectModalProps> = ({
  isOpen,
  currentPath,
  recentProjects,
  onOpenPath,
  onPickFolderNative,
  onClose
}) => {
  const [inputPath, setInputPath] = useState(currentPath || '');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  if (!isOpen) return null;

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!inputPath.trim()) return;
    setLoading(true);
    setError(null);
    try {
      await onOpenPath(inputPath.trim());
      onClose();
    } catch (err: any) {
      setError(err.message || 'Failed to open project directory');
    } finally {
      setLoading(false);
    }
  };

  const handleRecentClick = async (path: string) => {
    setInputPath(path);
    setLoading(true);
    setError(null);
    try {
      await onOpenPath(path);
      onClose();
    } catch (err: any) {
      setError(err.message || 'Failed to open project directory');
    } finally {
      setLoading(false);
    }
  };

  const handleNativeBrowse = async () => {
    if (!onPickFolderNative) return;
    setError(null);
    try {
      const selected = await onPickFolderNative();
      if (selected) {
        setInputPath(selected);
        setLoading(true);
        await onOpenPath(selected);
        onClose();
      }
    } catch (err: any) {
      setError(err.message || 'Folder picker failed');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/60 backdrop-blur-sm p-4">
      <div className="w-full max-w-xl bg-rt-mantle border border-rt-surface-1 rounded-xl shadow-2xl flex flex-col overflow-hidden animate-in fade-in zoom-in-95 duration-150">
        {/* Header */}
        <div className="h-14 px-5 border-b border-rt-surface-0 flex items-center justify-between bg-rt-crust select-none">
          <div className="flex items-center space-x-3">
            <div className="p-2 rounded-lg bg-rt-blue/15 text-rt-blue">
              <FolderOpen className="w-5 h-5" />
            </div>
            <div>
              <h3 className="font-bold text-sm text-rt-text">Open R Project</h3>
              <p className="text-xs text-rt-text-faint">
                Select an R project directory or repository to inspect and annotate.
              </p>
            </div>
          </div>
          <button
            onClick={onClose}
            className="p-1.5 rounded-lg text-rt-text-faint hover:text-rt-text hover:bg-rt-surface-0 transition"
          >
            <X className="w-5 h-5" />
          </button>
        </div>

        {/* Body */}
        <div className="p-5 space-y-4">
          {error && (
            <div className="p-3 rounded-lg bg-rt-red/10 border border-rt-red/30 flex items-start space-x-2 text-xs text-rt-red">
              <AlertCircle className="w-4 h-4 flex-shrink-0 mt-0.5" />
              <span>{error}</span>
            </div>
          )}

          {/* Path Input Form */}
          <form onSubmit={handleSubmit} className="space-y-3">
            <label className="block text-xs font-medium text-rt-text-soft">
              Project Directory Path
            </label>
            <div className="flex items-center space-x-2">
              <input
                type="text"
                value={inputPath}
                onChange={(e) => setInputPath(e.target.value)}
                placeholder="/path/to/my-r-project"
                disabled={loading}
                className="flex-1 px-3 py-2 text-xs font-mono rounded-lg bg-rt-surface-0 border border-rt-surface-1 text-rt-text placeholder-rt-text-faint focus:outline-none focus:border-rt-blue focus:ring-1 focus:ring-rt-blue transition"
              />
              {onPickFolderNative && (
                <button
                  type="button"
                  onClick={handleNativeBrowse}
                  disabled={loading}
                  className="px-3 py-2 rounded-lg text-xs font-medium bg-rt-surface-0 hover:bg-rt-surface-1 text-rt-text border border-rt-surface-1 transition flex items-center space-x-1.5"
                  title="Browse with OS Folder Picker"
                >
                  <Folder className="w-3.5 h-3.5 text-rt-blue" />
                  <span>Browse...</span>
                </button>
              )}
            </div>

            <div className="flex items-center justify-end space-x-2 pt-1">
              <button
                type="button"
                onClick={onClose}
                disabled={loading}
                className="px-3 py-1.5 rounded text-xs font-medium text-rt-text-faint hover:text-rt-text hover:bg-rt-surface-0 transition"
              >
                Cancel
              </button>
              <button
                type="submit"
                disabled={loading || !inputPath.trim()}
                className="px-4 py-1.5 rounded text-xs font-medium bg-rt-blue hover:bg-rt-blue/90 text-rt-crust font-semibold transition flex items-center space-x-1.5 disabled:opacity-50"
              >
                <span>{loading ? 'Opening...' : 'Open Project'}</span>
                <ArrowRight className="w-3.5 h-3.5" />
              </button>
            </div>
          </form>

          {/* Recent Projects List */}
          {recentProjects.length > 0 && (
            <div className="pt-3 border-t border-rt-surface-0">
              <div className="flex items-center space-x-1.5 text-xs font-medium text-rt-text-faint mb-2">
                <History className="w-3.5 h-3.5" />
                <span>Recent Projects</span>
              </div>
              <div className="max-h-48 overflow-y-auto space-y-1">
                {recentProjects.map((rec) => (
                  <button
                    key={rec.path}
                    onClick={() => handleRecentClick(rec.path)}
                    disabled={loading}
                    className="w-full text-left p-2 rounded-lg hover:bg-rt-surface-0/60 border border-transparent hover:border-rt-surface-1 flex items-center justify-between group transition text-xs"
                  >
                    <div className="truncate pr-2">
                      <div className="font-semibold text-rt-text group-hover:text-rt-blue transition truncate">
                        {rec.name}
                      </div>
                      <div className="font-mono text-[10px] text-rt-text-faint truncate">
                        {rec.path}
                      </div>
                    </div>
                    <ArrowRight className="w-3.5 h-3.5 text-rt-text-faint opacity-0 group-hover:opacity-100 transition-opacity flex-shrink-0" />
                  </button>
                ))}
              </div>
            </div>
          )}
        </div>
      </div>
    </div>
  );
};
