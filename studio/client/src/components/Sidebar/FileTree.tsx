/**
 * studio/client/src/components/Sidebar/FileTree.tsx -- File Explorer & Samples Loader
 */

import React, { useEffect, useState } from 'react';
import { Folder, FolderOpen, FileCode, Sparkles, RefreshCw, ChevronRight, ChevronDown } from 'lucide-react';
import { FileItem, SampleScript } from '../../types';
import { listFiles, getSamples } from '../../services/api';

interface FileTreeProps {
  currentFile: string;
  onOpenFile: (path: string) => void;
}

export const FileTree: React.FC<FileTreeProps> = ({ currentFile, onOpenFile }) => {
  const [files, setFiles] = useState<FileItem[]>([]);
  const [samples, setSamples] = useState<SampleScript[]>([]);
  const [loading, setLoading] = useState(false);
  const [samplesExpanded, setSamplesExpanded] = useState(true);
  const [workspaceExpanded, setWorkspaceExpanded] = useState(true);

  const loadData = async () => {
    setLoading(true);
    try {
      const [fileRes, sampleRes] = await Promise.all([
        listFiles(),
        getSamples()
      ]);
      setFiles(fileRes.items);
      setSamples(sampleRes);
    } catch (err) {
      console.error('Failed to load files:', err);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    loadData();
  }, []);

  return (
    <div className="h-full flex flex-col bg-rt-mantle text-xs select-none">
      {/* Header bar */}
      <div className="h-9 px-3 border-b border-rt-surface-0 flex items-center justify-between font-semibold tracking-wider text-rt-text-soft uppercase text-[11px]">
        <span>Explorer</span>
        <button
          onClick={loadData}
          disabled={loading}
          className="p-1 hover:bg-rt-surface-0 rounded text-rt-text-faint hover:text-rt-text transition"
          title="Refresh Explorer"
        >
          <RefreshCw className={`w-3.5 h-3.5 ${loading ? 'animate-spin' : ''}`} />
        </button>
      </div>

      <div className="flex-1 overflow-y-auto p-2 space-y-3">
        {/* Bundled Samples Section */}
        <div>
          <button
            onClick={() => setSamplesExpanded(!samplesExpanded)}
            className="w-full flex items-center space-x-1.5 py-1 px-1 text-rt-mauve font-semibold hover:bg-rt-surface-0/50 rounded"
          >
            {samplesExpanded ? <ChevronDown className="w-3.5 h-3.5" /> : <ChevronRight className="w-3.5 h-3.5" />}
            <Sparkles className="w-3.5 h-3.5 text-rt-yellow" />
            <span>Sample Scripts</span>
            <span className="text-[10px] text-rt-text-faint ml-auto font-mono">{samples.length}</span>
          </button>

          {samplesExpanded && (
            <div className="mt-1 space-y-0.5 pl-3 border-l border-rt-surface-0 ml-2">
              {samples.map((sample) => {
                const isSelected = currentFile === sample.path;
                return (
                  <button
                    key={sample.name}
                    onClick={() => onOpenFile(sample.path)}
                    className={`w-full text-left flex items-center space-x-2 py-1.5 px-2 rounded font-mono text-[11px] transition ${
                      isSelected
                        ? 'bg-rt-surface-0 text-rt-mauve font-bold shadow-sm'
                        : 'text-rt-text-soft hover:bg-rt-surface-0/50 hover:text-rt-text'
                    }`}
                  >
                    <FileCode className="w-3.5 h-3.5 text-rt-blue flex-shrink-0" />
                    <span className="truncate">{sample.name}</span>
                  </button>
                );
              })}
            </div>
          )}
        </div>

        {/* Project Files Section */}
        <div>
          <button
            onClick={() => setWorkspaceExpanded(!workspaceExpanded)}
            className="w-full flex items-center space-x-1.5 py-1 px-1 text-rt-text-soft font-semibold hover:bg-rt-surface-0/50 rounded"
          >
            {workspaceExpanded ? <ChevronDown className="w-3.5 h-3.5" /> : <ChevronRight className="w-3.5 h-3.5" />}
            <Folder className="w-3.5 h-3.5 text-rt-blue" />
            <span>Workspace</span>
          </button>

          {workspaceExpanded && (
            <div className="mt-1 space-y-0.5 pl-3 border-l border-rt-surface-0 ml-2">
              {files.map((file) => {
                const isSelected = currentFile === file.path;
                return (
                  <button
                    key={file.path}
                    onClick={() => !file.isDirectory && onOpenFile(file.path)}
                    className={`w-full text-left flex items-center space-x-2 py-1.5 px-2 rounded font-mono text-[11px] transition ${
                      isSelected
                        ? 'bg-rt-surface-0 text-rt-teal font-bold'
                        : file.isDirectory
                        ? 'text-rt-text font-sans hover:bg-rt-surface-0/30'
                        : file.isR
                        ? 'text-rt-text-soft hover:bg-rt-surface-0/50 hover:text-rt-text'
                        : 'text-rt-text-faint hover:bg-rt-surface-0/30'
                    }`}
                  >
                    {file.isDirectory ? (
                      <FolderOpen className="w-3.5 h-3.5 text-rt-yellow flex-shrink-0" />
                    ) : (
                      <FileCode className={`w-3.5 h-3.5 ${file.isR ? 'text-rt-teal' : 'text-rt-text-faint'} flex-shrink-0`} />
                    )}
                    <span className="truncate">{file.name}</span>
                  </button>
                );
              })}
            </div>
          )}
        </div>
      </div>
    </div>
  );
};
