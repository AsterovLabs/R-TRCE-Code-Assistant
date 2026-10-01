/**
 * studio/client/src/components/Editor/DiffModal.tsx -- Side-by-Side Monaco Diff Modal
 */

import React from 'react';
import { DiffEditor } from '@monaco-editor/react';
import { Sparkles, Check, X, ShieldCheck } from 'lucide-react';
import { ThemeMode } from '../../types';

interface DiffModalProps {
  isOpen: boolean;
  originalText: string;
  annotatedText: string;
  insertedCount: number;
  theme: ThemeMode;
  onApply: () => void;
  onClose: () => void;
}

export const DiffModal: React.FC<DiffModalProps> = ({
  isOpen,
  originalText,
  annotatedText,
  insertedCount,
  theme,
  onApply,
  onClose
}) => {
  if (!isOpen) return null;

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/60 backdrop-blur-sm p-4">
      <div className="w-full max-w-5xl h-[85vh] bg-rt-mantle border border-rt-surface-1 rounded-xl shadow-2xl flex flex-col overflow-hidden">
        {/* Modal Header */}
        <div className="h-14 px-5 border-b border-rt-surface-0 flex items-center justify-between bg-rt-crust select-none">
          <div className="flex items-center space-x-3">
            <div className="p-2 rounded-lg bg-rt-mauve/15 text-rt-mauve">
              <Sparkles className="w-5 h-5" />
            </div>
            <div>
              <h3 className="font-bold text-sm text-rt-text flex items-center space-x-2">
                <span>TRCE Annotation Diff Preview</span>
                <span className="text-xs px-2 py-0.5 rounded-full bg-rt-teal/20 text-rt-teal font-mono">
                  +{insertedCount} blocks
                </span>
              </h3>
              <p className="text-xs text-rt-text-faint">
                Non-destructive injection of 6-point TRCE doc-comment scaffolding.
              </p>
            </div>
          </div>

          <div className="flex items-center space-x-2">
            <button
              onClick={onClose}
              className="p-1.5 rounded-lg text-rt-text-faint hover:text-rt-text hover:bg-rt-surface-0 transition"
            >
              <X className="w-5 h-5" />
            </button>
          </div>
        </div>

        {/* Monaco Diff Editor */}
        <div className="flex-1 w-full bg-rt-base overflow-hidden">
          <DiffEditor
            height="100%"
            original={originalText}
            modified={annotatedText}
            language="r"
            theme={theme === 'mocha' ? 'asterov-mocha' : 'asterov-latte'}
            options={{
              readOnly: true,
              renderSideBySide: true,
              fontFamily: '"JetBrains Mono", Consolas, "Courier New", monospace',
              fontSize: 12,
              lineHeight: 18,
              smoothScrolling: true,
              scrollBeyondLastLine: false,
              automaticLayout: true
            }}
          />
        </div>

        {/* Modal Footer */}
        <div className="h-14 px-5 border-t border-rt-surface-0 flex items-center justify-between bg-rt-crust select-none">
          <div className="flex items-center space-x-2 text-xs text-rt-text-muted">
            <ShieldCheck className="w-4 h-4 text-rt-green" />
            <span>Guaranteed non-destructive: only adds comments, never edits source lines.</span>
          </div>

          <div className="flex items-center space-x-2">
            <button
              onClick={onClose}
              className="px-4 py-2 rounded-lg border border-rt-surface-1 text-xs font-semibold text-rt-text-soft hover:bg-rt-surface-0 transition"
            >
              Cancel
            </button>
            <button
              onClick={onApply}
              className="px-4 py-2 rounded-lg bg-rt-mauve hover:bg-rt-mauve/90 text-rt-crust font-bold text-xs flex items-center space-x-1.5 shadow-lg shadow-rt-mauve/20 transition active:scale-95"
            >
              <Check className="w-4 h-4" />
              <span>Apply & Save to File</span>
            </button>
          </div>
        </div>
      </div>
    </div>
  );
};
