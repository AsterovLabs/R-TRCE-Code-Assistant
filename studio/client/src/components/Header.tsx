/**
 * studio/client/src/components/Header.tsx -- Studio Top Header & Toolbar
 */

import React from 'react';
import { Play, PlaySquare, FileCheck2, Save, Sun, Moon, ShieldCheck, Sparkles } from 'lucide-react';
import { ThemeMode } from '../types';

interface HeaderProps {
  currentFile: string;
  isModified: boolean;
  theme: ThemeMode;
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
  onToggleTheme,
  onRunSelection,
  onRunAll,
  onSave,
  onAnnotate,
  onValidate,
  isEvaluating = false
}) => {
  const fileName = currentFile ? currentFile.split(/[/\\]/).pop() : 'untitled.R';

  return (
    <header className="h-12 bg-rt-mantle border-b border-rt-surface-0 flex items-center justify-between px-3 select-none flex-shrink-0">
      {/* Brand Monogram & Title */}
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
