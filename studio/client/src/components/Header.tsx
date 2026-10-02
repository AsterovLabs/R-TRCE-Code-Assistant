/**
 * studio/client/src/components/Header.tsx -- Studio Top Header & Toolbar
 */

import React, { useState, useRef, useEffect } from 'react';
import {
  Play,
  PlaySquare,
  FileCheck2,
  Save,
  Sun,
  Moon,
  ShieldCheck,
  Sparkles,
  Folder,
  FolderOpen,
  FolderGit2,
  ChevronDown,
  History,
  Info
} from 'lucide-react';
import { ThemeMode, RecentProject } from '../types';

interface HeaderProps {
  currentFile: string;
  isModified: boolean;
  theme: ThemeMode;
  projectName: string;
  projectPath: string;
  recentProjects: RecentProject[];
  onOpenProjectModal: () => void;
  onOpenRecentProject: (path: string) => void;
  onShowProjectOverview: () => void;
  onToggleTheme: () => void;
  onRunSelection: () => void;
  onRunAll: () => void;
  onSave: () => void;
  onAnnotate: () => void;
  onValidate: () => void;
  isEvaluating?: boolean;
}

export const Header: React.FC<HeaderProps> = ({
  currentFile,
  isModified,
  theme,
  projectName,
  projectPath,
  recentProjects,
  onOpenProjectModal,
  onOpenRecentProject,
  onShowProjectOverview,
  onToggleTheme,
  onRunSelection,
  onRunAll,
  onSave,
  onAnnotate,
  onValidate,
  isEvaluating = false
}) => {
  const fileName = currentFile ? currentFile.split(/[/\\]/).pop() : 'untitled.R';
  const [dropdownOpen, setDropdownOpen] = useState(false);
  const dropdownRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    const handleOutsideClick = (e: MouseEvent) => {
      if (dropdownRef.current && !dropdownRef.current.contains(e.target as Node)) {
        setDropdownOpen(false);
      }
    };
    if (dropdownOpen) {
      document.addEventListener('mousedown', handleOutsideClick);
    }
    return () => {
      document.removeEventListener('mousedown', handleOutsideClick);
    };
  }, [dropdownOpen]);

  return (
    <header className="h-12 bg-rt-mantle border-b border-rt-surface-0 flex items-center justify-between px-3 select-none flex-shrink-0">
      {/* Brand Monogram & Title & Project Selector */}
      <div className="flex items-center space-x-3">
        <div className="flex items-center space-x-2">
          <img src="/brand/favicon.svg" alt="Asterov" className="w-6 h-6" />
          <span className="font-bold text-sm tracking-wide asterov-gradient-text">
            R-TRCE
          </span>
          <span className="text-xs px-1.5 py-0.5 rounded bg-rt-surface-0 text-rt-mauve font-mono font-medium">
            STUDIO
          </span>
        </div>

        {/* Project Selector Dropdown */}
        <div className="relative" ref={dropdownRef}>
          <button
            onClick={() => setDropdownOpen(prev => !prev)}
            className="flex items-center space-x-1.5 px-2.5 py-1 rounded bg-rt-surface-0/60 hover:bg-rt-surface-1 border border-rt-surface-1 text-xs text-rt-text transition group"
            title={`Active Project: ${projectPath}`}
          >
            <FolderGit2 className="w-3.5 h-3.5 text-rt-blue group-hover:text-rt-mauve transition" />
            <span className="font-semibold max-w-[140px] truncate">{projectName || 'Project'}</span>
            <ChevronDown className={`w-3 h-3 text-rt-text-faint transition-transform ${dropdownOpen ? 'rotate-180' : ''}`} />
          </button>

          {dropdownOpen && (
            <div className="absolute left-0 top-full mt-1.5 w-64 bg-rt-mantle border border-rt-surface-1 rounded-xl shadow-xl z-50 p-1.5 text-xs animate-in fade-in duration-100">
              <div className="px-2 py-1 font-mono text-[10px] text-rt-text-faint truncate border-b border-rt-surface-0 mb-1">
                {projectPath}
              </div>

              <button
                onClick={() => {
                  setDropdownOpen(false);
                  onOpenProjectModal();
                }}
                className="w-full flex items-center space-x-2 px-2.5 py-1.5 rounded-lg hover:bg-rt-surface-0 text-rt-text font-medium text-left transition"
              >
                <FolderOpen className="w-3.5 h-3.5 text-rt-blue" />
                <span>Open Project Folder...</span>
              </button>

              <button
                onClick={() => {
                  setDropdownOpen(false);
                  onShowProjectOverview();
                }}
                className="w-full flex items-center space-x-2 px-2.5 py-1.5 rounded-lg hover:bg-rt-surface-0 text-rt-text font-medium text-left transition"
              >
                <Info className="w-3.5 h-3.5 text-rt-mauve" />
                <span>Project Overview & Health</span>
              </button>

              {recentProjects.length > 0 && (
                <>
                  <div className="px-2 pt-2 pb-1 text-[10px] uppercase font-semibold tracking-wider text-rt-text-faint border-t border-rt-surface-0 mt-1 flex items-center space-x-1">
                    <History className="w-3 h-3" />
                    <span>Recent Projects</span>
                  </div>
                  <div className="max-h-40 overflow-y-auto space-y-0.5">
                    {recentProjects.slice(0, 5).map((rec) => (
                      <button
                        key={rec.path}
                        onClick={() => {
                          setDropdownOpen(false);
                          onOpenRecentProject(rec.path);
                        }}
                        className={`w-full flex flex-col items-start px-2.5 py-1 rounded text-left transition ${
                          rec.path === projectPath
                            ? 'bg-rt-surface-0 text-rt-blue font-semibold'
                            : 'hover:bg-rt-surface-0/60 text-rt-text-soft hover:text-rt-text'
                        }`}
                      >
                        <span className="truncate w-full font-medium">{rec.name}</span>
                        <span className="truncate w-full font-mono text-[9px] text-rt-text-faint">{rec.path}</span>
                      </button>
                    ))}
                  </div>
                </>
              )}
            </div>
          )}
        </div>

        {/* Current Document Chip */}
        <div className="flex items-center space-x-1.5 px-2.5 py-1 rounded bg-rt-surface-0/60 border border-rt-surface-1 text-xs">
          <span className="text-rt-text font-mono font-medium truncate max-w-xs">
            {fileName}
          </span>
          {isModified && (
            <span className="w-1.5 h-1.5 rounded-full bg-rt-peach animate-pulse" title="Unsaved changes" />
          )}
        </div>
      </div>

      {/* Main Execution & Annotation Actions */}
      <div className="flex items-center space-x-1.5">
        <button
          onClick={onRunSelection}
          disabled={isEvaluating}
          className="flex items-center space-x-1.5 px-2.5 py-1.5 rounded text-xs font-medium bg-rt-surface-0 hover:bg-rt-surface-1 text-rt-teal hover:text-rt-green transition active:scale-95 disabled:opacity-50"
          title="Run Statement / Selection (Ctrl+Enter)"
        >
          <Play className="w-3.5 h-3.5 fill-current" />
          <span>Run</span>
        </button>

        <button
          onClick={onRunAll}
          disabled={isEvaluating}
          className="flex items-center space-x-1.5 px-2.5 py-1.5 rounded text-xs font-medium bg-rt-surface-0 hover:bg-rt-surface-1 text-rt-blue hover:text-rt-mauve transition active:scale-95 disabled:opacity-50"
          title="Run Entire Script"
        >
          <PlaySquare className="w-3.5 h-3.5" />
          <span>Run All</span>
        </button>

        <div className="h-4 w-px bg-rt-surface-1 mx-1" />

        <button
          onClick={onAnnotate}
          className="flex items-center space-x-1.5 px-2.5 py-1.5 rounded text-xs font-medium bg-rt-surface-0 hover:bg-rt-surface-1 text-rt-mauve hover:text-rt-peach transition active:scale-95"
          title="Synthesize 6-Point TRCE Annotations with Diff Preview"
        >
          <Sparkles className="w-3.5 h-3.5" />
          <span>Annotate</span>
        </button>

        <button
          onClick={onValidate}
          className="flex items-center space-x-1.5 px-2.5 py-1.5 rounded text-xs font-medium bg-rt-surface-0 hover:bg-rt-surface-1 text-rt-green transition active:scale-95"
          title="Validate TRCE Telemetry & 6 Fields"
        >
          <ShieldCheck className="w-3.5 h-3.5" />
          <span>Audit</span>
        </button>

        <button
          onClick={onSave}
          className="flex items-center space-x-1.5 px-2.5 py-1.5 rounded text-xs font-medium bg-rt-surface-0 hover:bg-rt-surface-1 text-rt-text transition active:scale-95"
          title="Save File (Ctrl+S)"
        >
          <Save className="w-3.5 h-3.5" />
          <span>Save</span>
        </button>
      </div>

      {/* Right Controls: Theme & System Status */}
      <div className="flex items-center space-x-2">
        <button
          onClick={onToggleTheme}
          className="p-1.5 rounded hover:bg-rt-surface-0 text-rt-text-muted hover:text-rt-text transition"
          title={`Switch to ${theme === 'mocha' ? 'Light (Latte)' : 'Dark (Mocha)'} Theme`}
        >
          {theme === 'mocha' ? <Sun className="w-4 h-4 text-rt-yellow" /> : <Moon className="w-4 h-4 text-rt-blue" />}
        </button>

        <div className="flex items-center space-x-1.5 text-xs text-rt-text-muted pl-2 border-l border-rt-surface-1">
          <span className="w-2 h-2 rounded-full bg-rt-green shadow-[0_0_8px_var(--rt-green)]" />
          <span className="font-mono text-[11px] hidden sm:inline">R 4.5.2</span>
        </div>
      </div>
    </header>
  );
};
