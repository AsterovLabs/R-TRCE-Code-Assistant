/**
 * studio/client/src/components/Console/RConsole.tsx -- Interactive R REPL Console
 */

import React, { useState, useRef, useEffect } from 'react';
import { Terminal, Trash2, RotateCcw, CornerDownLeft, AlertCircle, AlertTriangle, Info } from 'lucide-react';
import { ConsoleEntry } from '../../types';

interface RConsoleProps {
  entries: ConsoleEntry[];
  onExecute: (code: string) => void;
  onClear: () => void;
  onResetSession: () => void;
  isEvaluating?: boolean;
}

export const RConsole: React.FC<RConsoleProps> = ({
  entries,
  onExecute,
  onClear,
  onResetSession,
  isEvaluating = false
}) => {
  const [input, setInput] = useState('');
  const [historyIndex, setHistoryIndex] = useState<number | null>(null);
  const scrollRef = useRef<HTMLDivElement>(null);
  const inputRef = useRef<HTMLInputElement>(null);

  // Auto-scroll on new entries
  useEffect(() => {
    if (scrollRef.current) {
      scrollRef.current.scrollTop = scrollRef.current.scrollHeight;
    }
  }, [entries, isEvaluating]);

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (!input.trim() || isEvaluating) return;
    onExecute(input);
    setInput('');
    setHistoryIndex(null);
  };

  const handleKeyDown = (e: React.KeyboardEvent) => {
    // Up arrow: walk back in history
    if (e.key === 'ArrowUp') {
      e.preventDefault();
      const executedCommands = entries.map(en => en.code).filter(Boolean);
      if (executedCommands.length === 0) return;

      const nextIdx = historyIndex === null ? executedCommands.length - 1 : Math.max(0, historyIndex - 1);
      setHistoryIndex(nextIdx);
      setInput(executedCommands[nextIdx] || '');
    }
    // Down arrow: walk forward in history
    else if (e.key === 'ArrowDown') {
      e.preventDefault();
      const executedCommands = entries.map(en => en.code).filter(Boolean);
      if (historyIndex === null) return;

      const nextIdx = historyIndex + 1;
      if (nextIdx >= executedCommands.length) {
        setHistoryIndex(null);
        setInput('');
      } else {
        setHistoryIndex(nextIdx);
        setInput(executedCommands[nextIdx] || '');
      }
    }
  };

  return (
    <div className="h-full flex flex-col bg-rt-crust text-xs font-mono select-text">
      {/* Console Toolbar */}
      <div className="h-8 px-3 border-b border-rt-surface-0 flex items-center justify-between bg-rt-mantle select-none flex-shrink-0">
        <div className="flex items-center space-x-2 text-rt-text-soft font-sans font-semibold text-[11px] uppercase tracking-wider">
          <Terminal className="w-3.5 h-3.5 text-rt-teal" />
          <span>Interactive R Console</span>
          {isEvaluating && (
            <span className="flex items-center space-x-1 text-rt-yellow font-normal lowercase">
              <span className="w-1.5 h-1.5 rounded-full bg-rt-yellow animate-ping" />
              <span>running...</span>
            </span>
          )}
        </div>

        <div className="flex items-center space-x-1">
          <button
            onClick={onClear}
            className="p-1 rounded hover:bg-rt-surface-0 text-rt-text-faint hover:text-rt-text transition"
            title="Clear Console"
          >
            <Trash2 className="w-3.5 h-3.5" />
          </button>
          <button
            onClick={onResetSession}
            className="p-1 rounded hover:bg-rt-surface-0 text-rt-text-faint hover:text-rt-text transition"
            title="Restart R Session"
          >
            <RotateCcw className="w-3.5 h-3.5" />
          </button>
        </div>
      </div>

      {/* Output Log Area */}
      <div ref={scrollRef} className="flex-1 overflow-y-auto p-3 space-y-2 leading-relaxed">
        {entries.length === 0 && (
          <div className="text-rt-text-faint text-[11px] font-sans italic py-2">
            R session online. Press Ctrl+Enter on any line in the editor, or enter code below.
          </div>
        )}

        {entries.map((entry) => (
          <div key={entry.id} className="space-y-1">
            {/* Input code prompt */}
            {entry.code && (
              <div className="flex items-start space-x-1.5 text-rt-mauve font-semibold">
                <span className="text-rt-text-faint select-none">&gt;</span>
                <span className="whitespace-pre-wrap">{entry.code}</span>
              </div>
            )}

            {/* Standard console output */}
            {entry.output && entry.output.length > 0 && (
              <div className="text-rt-text whitespace-pre-wrap pl-3 border-l border-rt-surface-1">
                {entry.output.join('\n')}
              </div>
            )}

            {/* Messages */}
            {entry.messages && entry.messages.length > 0 && (
              <div className="flex items-start space-x-2 text-rt-blue bg-rt-blue/10 p-2 rounded text-[11px]">
                <Info className="w-3.5 h-3.5 mt-0.5 flex-shrink-0" />
                <div className="whitespace-pre-wrap">{entry.messages.join('\n')}</div>
              </div>
            )}

            {/* Warnings */}
            {entry.warnings && entry.warnings.length > 0 && (
              <div className="flex items-start space-x-2 text-rt-yellow bg-rt-yellow/10 p-2 rounded text-[11px]">
                <AlertTriangle className="w-3.5 h-3.5 mt-0.5 flex-shrink-0" />
                <div className="whitespace-pre-wrap">{entry.warnings.join('\n')}</div>
              </div>
            )}

            {/* Errors */}
            {entry.error && (
              <div className="flex items-start space-x-2 text-rt-red bg-rt-red/10 p-2 rounded text-[11px]">
                <AlertCircle className="w-3.5 h-3.5 mt-0.5 flex-shrink-0" />
                <div className="whitespace-pre-wrap font-bold">Error: {entry.error}</div>
              </div>
            )}
          </div>
        ))}
      </div>

      {/* Command Prompt Input */}
      <form onSubmit={handleSubmit} className="h-10 px-3 border-t border-rt-surface-0 bg-rt-mantle flex items-center space-x-2 flex-shrink-0">
        <span className="text-rt-teal font-bold select-none">&gt;</span>
        <input
          ref={inputRef}
          type="text"
          value={input}
          onChange={(e) => setInput(e.target.value)}
          onKeyDown={handleKeyDown}
          disabled={isEvaluating}
          placeholder={isEvaluating ? 'Executing...' : 'Type R expression (e.g. plot(cars) or summary(x)) and press Enter'}
          className="flex-1 bg-transparent text-rt-text outline-none text-xs font-mono placeholder:text-rt-text-faint/60"
        />
        <button
          type="submit"
          disabled={!input.trim() || isEvaluating}
          className="p-1 rounded text-rt-text-faint hover:text-rt-teal disabled:opacity-30 transition"
          title="Send Command"
        >
          <CornerDownLeft className="w-3.5 h-3.5" />
        </button>
      </form>
    </div>
  );
};
