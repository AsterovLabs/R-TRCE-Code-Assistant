/**
 * studio/client/src/components/Sidebar/FileTree.tsx -- File Explorer & Samples Loader
 */

import React, { useEffect, useState, useCallback } from 'react';
import {
  Folder,
  FolderOpen,
  FileCode,
  FilePlus,
  Sparkles,
  RefreshCw,
  ChevronRight,
  ChevronDown,
  FolderTree,
  FileText
} from 'lucide-react';
import { FileItem, SampleScript } from '../../types';
import { listFiles, getSamples } from '../../services/api';
import { ensureArray } from '../../utils/array';

interface FileTreeProps {
  currentFile: string;
  projectName?: string;
  projectPath?: string;
  onOpenFile: (path: string) => void;
  onNewScript?: () => void;
  onOpenFolder?: () => void;
}

interface DirectoryNodeProps {
  item: FileItem;
  level: number;
  currentFile: string;
  onOpenFile: (path: string) => void;
}

const getFileIcon = (name: string, isR?: boolean) => {
  const ext = name.split('.').pop()?.toLowerCase();
  if (isR || ext === 'r') {
    return <FileCode className="w-3.5 h-3.5 text-rt-teal flex-shrink-0" />;
  }
  if (ext === 'py' || ext === 'ipynb') {
    return <FileCode className="w-3.5 h-3.5 text-rt-yellow flex-shrink-0" />;
  }
  if (ext === 'js' || ext === 'jsx' || ext === 'ts' || ext === 'tsx' || ext === 'mjs') {
    return <FileCode className="w-3.5 h-3.5 text-rt-peach flex-shrink-0" />;
  }
  if (ext === 'rmd' || ext === 'qmd') {
    return <FileCode className="w-3.5 h-3.5 text-rt-mauve flex-shrink-0" />;
  }
  if (ext === 'md' || ext === 'markdown') {
    return <FileText className="w-3.5 h-3.5 text-rt-blue flex-shrink-0" />;
  }
  if (ext === 'json') {
    return <FileCode className="w-3.5 h-3.5 text-rt-green flex-shrink-0" />;
  }
  return <FileText className="w-3.5 h-3.5 text-rt-text-faint flex-shrink-0" />;
};

const DirectoryNode: React.FC<DirectoryNodeProps> = ({
  item,
  level,
  currentFile,
  onOpenFile
}) => {
  const [expanded, setExpanded] = useState(false);
  const [children, setChildren] = useState<FileItem[]>([]);
  const [loading, setLoading] = useState(false);

  const fetchChildren = useCallback(async () => {
    setLoading(true);
    try {
      const res = await listFiles(item.relPath);
      setChildren(ensureArray(res?.items));
    } catch (err) {
      console.error(`Failed to list directory '${item.relPath}':`, err);
      setChildren([]);
    } finally {
      setLoading(false);
    }
  }, [item.relPath]);

  const toggleExpand = async (e: React.MouseEvent) => {
    e.stopPropagation();
    if (!expanded) {
      await fetchChildren();
    }
    setExpanded(prev => !prev);
  };

  const isSelected = currentFile === item.path;

  if (item.isDirectory) {
    const childrenList = ensureArray(children);
    return (
      <div className="w-full">
        <button
          onClick={toggleExpand}
          style={{ paddingLeft: `${Math.max(4, level * 14)}px` }}
          className="w-full text-left flex items-center space-x-1.5 py-1 px-1.5 rounded font-mono text-[11px] transition text-rt-text hover:bg-rt-surface-0/60 group"
          title={item.relPath}
        >
          <span className="text-rt-text-faint group-hover:text-rt-mauve transition-colors">
            {expanded ? (
              <ChevronDown className="w-3.5 h-3.5 flex-shrink-0" />
            ) : (
              <ChevronRight className="w-3.5 h-3.5 flex-shrink-0" />
            )}
          </span>
          {expanded ? (
            <FolderOpen className="w-3.5 h-3.5 text-rt-yellow flex-shrink-0" />
          ) : (
            <Folder className="w-3.5 h-3.5 text-rt-blue flex-shrink-0" />
          )}
          <span className="truncate font-sans font-medium text-rt-text-soft group-hover:text-rt-text">
            {item.name}
          </span>
          {loading && (
            <RefreshCw className="w-2.5 h-2.5 animate-spin text-rt-text-faint ml-auto" />
          )}
        </button>

        {expanded && (
          <div className="relative">
            {childrenList.length === 0 && !loading && (
              <div
                style={{ paddingLeft: `${(level + 1) * 14 + 18}px` }}
                className="py-1 text-[10px] text-rt-text-faint italic font-sans"
              >
                (empty folder)
              </div>
            )}
            {childrenList.map(child => (
              <DirectoryNode
                key={child.path}
                item={child}
                level={level + 1}
                currentFile={currentFile}
                onOpenFile={onOpenFile}
              />
            ))}
          </div>
        )}
      </div>
    );
  }

  // Regular File Node
  return (
    <button
      onClick={() => onOpenFile(item.path)}
      style={{ paddingLeft: `${Math.max(4, level * 14 + 14)}px` }}
      className={`w-full text-left flex items-center space-x-1.5 py-1 px-1.5 rounded font-mono text-[11px] transition ${
        isSelected
          ? 'bg-rt-surface-0 text-rt-teal font-bold shadow-sm'
          : item.isR
          ? 'text-rt-text-soft hover:bg-rt-surface-0/40 hover:text-rt-text'
          : 'text-rt-text-faint hover:bg-rt-surface-0/20 hover:text-rt-text-soft'
      }`}
      title={item.relPath}
    >
      {getFileIcon(item.name, item.isR)}
      <span className="truncate">{item.name}</span>
    </button>
  );
};

export const FileTree: React.FC<FileTreeProps> = ({
  currentFile,
  projectName,
  projectPath,
  onOpenFile,
  onNewScript,
  onOpenFolder
}) => {
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
      setFiles(ensureArray(fileRes?.items));
      setSamples(ensureArray(sampleRes));
    } catch (err) {
      console.error('Failed to load files:', err);
      setFiles([]);
      setSamples([]);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    loadData();
  }, [projectPath]);

  const sampleList = ensureArray(samples);
  const fileList = ensureArray(files);

  return (
    <div className="h-full flex flex-col bg-rt-mantle text-xs select-none">
      {/* Header bar */}
      <div className="h-9 px-3 border-b border-rt-surface-0 flex items-center justify-between font-semibold tracking-wider text-rt-text-soft uppercase text-[11px]">
        <div className="flex items-center space-x-1.5">
          <FolderTree className="w-3.5 h-3.5 text-rt-mauve" />
          <span>Explorer</span>
        </div>
        <div className="flex items-center space-x-1">
          {onOpenFolder && (
            <button
              onClick={onOpenFolder}
              className="p-1 hover:bg-rt-surface-0 rounded text-rt-text-faint hover:text-rt-text transition"
              title="Open Project Folder..."
            >
              <FolderOpen className="w-3.5 h-3.5 text-rt-blue" />
            </button>
          )}
          {onNewScript && (
            <button
              onClick={onNewScript}
              className="p-1 hover:bg-rt-surface-0 rounded text-rt-text-faint hover:text-rt-text transition"
              title="New R Script"
            >
              <FilePlus className="w-3.5 h-3.5" />
            </button>
          )}
          <button
            onClick={loadData}
            disabled={loading}
            className="p-1 hover:bg-rt-surface-0 rounded text-rt-text-faint hover:text-rt-text transition"
            title="Refresh Explorer"
          >
            <RefreshCw className={`w-3.5 h-3.5 ${loading ? 'animate-spin' : ''}`} />
          </button>
        </div>
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
            <span className="text-[10px] text-rt-text-faint ml-auto font-mono">{sampleList.length}</span>
          </button>

          {samplesExpanded && (
            <div className="mt-1 space-y-0.5 pl-2 border-l border-rt-surface-0 ml-2">
              {sampleList.map((sample) => {
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
            <span className="truncate max-w-[140px]">{projectName || 'Workspace'}</span>
            <span className="text-[10px] text-rt-text-faint ml-auto font-mono">{fileList.length}</span>
          </button>

          {workspaceExpanded && (
            <div className="mt-1 space-y-0.5 pl-1 border-l border-rt-surface-0 ml-2">
              {fileList.map((file) => (
                <DirectoryNode
                  key={file.path}
                  item={file}
                  level={0}
                  currentFile={currentFile}
                  onOpenFile={onOpenFile}
                />
              ))}
            </div>
          )}
        </div>
      </div>
    </div>
  );
};
