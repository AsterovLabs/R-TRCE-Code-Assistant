/**
 * studio/client/src/components/StatusBar.tsx -- Studio Status Bar Chrome
 */

import React from 'react';
import { ShieldCheck, Wifi, Cpu, FileCode2 } from 'lucide-react';

interface StatusBarProps {
  cursorLine: number;
  cursorCol: number;
  currentFile: string;
  coveragePct?: number;
  traceCount?: number;
  rVersion?: string;
  language?: string;
  isConnected?: boolean;
}

export const StatusBar: React.FC<StatusBarProps> = ({
  cursorLine,
  cursorCol,
  currentFile,
  coveragePct = 100,
  traceCount = 0,
  rVersion = 'Multi-Kernel',
  language = 'R',
  isConnected = true
}) => {
  const fileName = currentFile ? currentFile.split(/[/\\]/).pop() : 'untitled.R';

  return (
    <footer className="h-6 bg-rt-mantle border-t border-rt-surface-0 px-3 flex items-center justify-between text-[11px] text-rt-text-faint font-mono select-none flex-shrink-0">
      {/* Left: Environment & File */}
      <div className="flex items-center space-x-3">
        <div className="flex items-center space-x-1 text-rt-text-muted">
          <Cpu className="w-3 h-3 text-rt-mauve" />
          <span className="font-semibold text-rt-mauve uppercase">{language}</span>
        </div>

        <div className="flex items-center space-x-1 truncate max-w-sm">
          <FileCode2 className="w-3 h-3 text-rt-blue" />
          <span className="text-rt-text-soft">{fileName}</span>
        </div>
      </div>

      {/* Right: TRCE Metrics, Cursor & Socket Status */}
      <div className="flex items-center space-x-4">
        {/* Coverage Badge */}
        <div className="flex items-center space-x-1.5">
          <ShieldCheck className={`w-3 h-3 ${coveragePct === 100 ? 'text-rt-green' : 'text-rt-yellow'}`} />
          <span className={coveragePct === 100 ? 'text-rt-green' : 'text-rt-yellow'}>
            TRCE {Math.round(coveragePct)}% ({traceCount} traces)
          </span>
        </div>

        {/* Cursor Position */}
        <div className="text-rt-text-muted">
          Ln {cursorLine}, Col {cursorCol}
        </div>

        {/* UTF-8 / R */}
        <div className="hidden sm:inline text-rt-text-faint">
          UTF-8
        </div>

        {/* Connection status */}
        <div className="flex items-center space-x-1 text-rt-text-muted">
          <span className={`w-1.5 h-1.5 rounded-full ${isConnected ? 'bg-rt-green' : 'bg-rt-red animate-pulse'}`} />
          <Wifi className="w-3 h-3" />
        </div>
      </div>
    </footer>
  );
};
