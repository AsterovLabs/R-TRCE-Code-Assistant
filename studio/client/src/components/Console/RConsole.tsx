/**
 * studio/client/src/components/Console/RConsole.tsx -- Interactive R REPL Console
 */

import React, { useState, useRef, useEffect } from 'react';
import { Terminal, Trash2, RotateCcw, CornerDownLeft, AlertCircle, AlertTriangle, Info } from 'lucide-react';
import { ConsoleEntry } from '../../types';
import { ensureArray } from '../../utils/array';

interface RConsoleProps {
  entries: ConsoleEntry[];
  onExecute: (code: string) => void;
  onClear: () => void;
  onResetSession: () => void;
  isEvaluating?: boolean;
  language?: string;
}

export const RConsole: React.FC<RConsoleProps> = ({
  entries,
  onExecute,
  onClear,
  onResetSession,
  isEvaluating = false,
  language = 'r'
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

  const entryList = ensureArray(entries);
  const langKey = (language || 'r').toLowerCase();
  const langName = langKey === 'python' ? 'Python' : langKey === 'javascript' ? 'Node.js' : 'R';
  const promptSymbol = langKey === 'python' ? '>>>' : '>';
  const placeholderText = isEvaluating
    ? 'Executing...'
    : langKey === 'python'
      ? 'Type Python expression (e.g. print(x) or len(items)) and press Enter'
      : langKey === 'javascript'
        ? 'Type JavaScript expression (e.g. console.log(x) or 2+2) and press Enter'
        : 'Type R expression (e.g. plot(cars) or summary(x)) and press Enter';

  return (
    <div className="h-full flex flex-col bg-rt-crust text-xs font-mono select-text">
      {/* Console Toolbar */}
      <div className="h-8 px-3 border-b border-rt-surface-0 flex items-center justify-between bg-rt-mantle select-none flex-shrink-0">
        <div className="flex items-center space-x-2 text-rt-text-soft font-sans font-semibold text-[11px] uppercase tracking-wider">
          <Terminal className="w-3.5 h-3.5 text-rt-teal" />
          <span>Interactive {langName} Console</span>
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
            title={`Restart ${langName} Session`}
          >
            <RotateCcw className="w-3.5 h-3.5" />
          </button>
        </div>
      </div>

      {/* Output Log Area */}
      <div ref={scrollRef} className="flex-1 overflow-y-auto p-3 space-y-2 leading-relaxed">
        {entryList.length === 0 && (
          <div className="text-rt-text-faint text-[11px] font-sans italic py-2">
            {langName} session online. Press Ctrl+Enter on any line in the editor, or enter code below.
          </div>
        )}

        {entryList.map((entry) => {
          const outputs = ensureArray(entry.output);
          const messages = ensureArray(entry.messages);
          const warnings = ensureArray(entry.warnings);

          return (
            <div key={entry.id} className="space-y-1">
              {/* Input code prompt */}
              {entry.code && (
                <div className="flex items-start space-x-1.5 text-rt-mauve font-semibold">
                  <span className="text-rt-text-faint select-none">{promptSymbol}</span>
                  <span className="whitespace-pre-wrap">{entry.code}</span>
                </div>
              )}

              {/* Standard console output */}
              {outputs.length > 0 && (
                <div className="text-rt-text whitespace-pre-wrap pl-3 border-l border-rt-surface-1">
                  {outputs.join('\n')}
                </div>
              )}

              {/* Messages */}
              {messages.length > 0 && (
                <div className="flex items-start space-x-2 text-rt-blue bg-rt-blue/10 p-2 rounded text-[11px]">
                  <Info className="w-3.5 h-3.5 mt-0.5 flex-shrink-0" />
                  <div className="whitespace-pre-wrap">{messages.join('\n')}</div>
                </div>
              )}

              {/* Warnings */}
              {warnings.length > 0 && (
                <div className="flex items-start space-x-2 text-rt-yellow bg-rt-yellow/10 p-2 rounded text-[11px]">
                  <AlertTriangle className="w-3.5 h-3.5 mt-0.5 flex-shrink-0" />
                  <div className="whitespace-pre-wrap">{warnings.join('\n')}</div>
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
          );
        })}
      </div>

      {/* Command Prompt Input */}
      <form onSubmit={handleSubmit} className="h-10 px-3 border-t border-rt-surface-0 bg-rt-mantle flex items-center space-x-2 flex-shrink-0">
        <span className="text-rt-teal font-bold select-none">{promptSymbol}</span>
        <input
          ref={inputRef}
          type="text"
          value={input}
          onChange={(e) => setInput(e.target.value)}
          onKeyDown={handleKeyDown}
          disabled={isEvaluating}
          placeholder={placeholderText}
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
