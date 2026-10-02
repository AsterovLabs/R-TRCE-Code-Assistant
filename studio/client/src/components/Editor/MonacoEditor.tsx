/**
 * studio/client/src/components/Editor/MonacoEditor.tsx -- Monaco Source Editor with TRCE Decorations
 */

import React, { useEffect, useRef } from 'react';
import Editor, { Monaco, OnMount } from '@monaco-editor/react';
import { ThemeMode } from '../../types';

interface MonacoEditorProps {
  value: string;
  onChange: (value: string) => void;
  theme: ThemeMode;
  language?: string;
  onRunSelection: () => void;
  onSave: () => void;
  onCursorChange?: (line: number, col: number) => void;
  targetLine?: number | null;
}

export const MonacoEditor: React.FC<MonacoEditorProps> = ({
  value,
  onChange,
  theme,
  language = 'r',
  onRunSelection,
  onSave,
  onCursorChange,
  targetLine
}) => {
  const editorRef = useRef<any>(null);
  const monacoRef = useRef<Monaco | null>(null);
  const decorationsRef = useRef<string[]>([]);

  // Jump to target line when requested (e.g. from AST or Pitfall click)
  useEffect(() => {
    if (editorRef.current && targetLine && targetLine > 0) {
      editorRef.current.revealLineInCenter(targetLine);
      editorRef.current.setPosition({ lineNumber: targetLine, column: 1 });
      editorRef.current.focus();
    }
  }, [targetLine]);

  // Update TRCE Gutter Badges whenever document content changes
  useEffect(() => {
    if (!editorRef.current || !monacoRef.current) return;

    const model = editorRef.current.getModel();
    if (!model) return;

    const lines = model.getLinesContent();
    const newDecorations: any[] = [];

    lines.forEach((lineText: string, idx: number) => {
      const lineNum = idx + 1;
      if (lineText.includes('@trce-id')) {
        newDecorations.push({
          range: new monacoRef.current!.Range(lineNum, 1, lineNum, 1),
          options: {
            isWholeLine: false,
            glyphMarginClassName: 'trce-gutter-glyph valid',
            glyphMarginHoverMessage: { value: '**TRCE Telemetry Anchor**\nAudited 6-Point Trace Directive' }
          }
        });
      }
    });

    decorationsRef.current = editorRef.current.deltaDecorations(decorationsRef.current, newDecorations);
  }, [value]);

  const handleEditorMount: OnMount = (editor, monaco) => {
    editorRef.current = editor;
    monacoRef.current = monaco;

    // Define Asterov Catppuccin Mocha (Dark) Theme
    monaco.editor.defineTheme('asterov-mocha', {
      base: 'vs-dark',
      inherit: true,
      rules: [
        { token: 'comment', foreground: '7f849c', fontStyle: 'italic' },
        { token: 'keyword', foreground: 'cba6f7', fontStyle: 'bold' }, // Mauve
        { token: 'string', foreground: 'a6e3a1' },                     // Green
        { token: 'number', foreground: 'fab387' },                     // Peach
        { token: 'type', foreground: '89b4fa' },                       // Blue
        { token: 'function', foreground: '89b4fa' },                   // Blue
        { token: 'operator', foreground: '94e2d5' },                   // Teal
        { token: 'variable', foreground: 'cdd6f4' },                   // Text
      ],
      colors: {
        'editor.background': '#1e1e2e',       // rt-base
        'editor.foreground': '#cdd6f4',       // rt-text
        'editorLineNumber.foreground': '#585b70',
        'editorLineNumber.activeForeground': '#cba6f7',
        'editorCursor.foreground': '#cba6f7',
        'editor.selectionBackground': '#45475a80',
        'editor.lineHighlightBackground': '#31324440',
        'editorGutter.background': '#181825', // rt-mantle
      }
    });

    // Define Asterov Catppuccin Latte (Light) Theme
    monaco.editor.defineTheme('asterov-latte', {
      base: 'vs',
      inherit: true,
      rules: [
        { token: 'comment', foreground: '8c8fa1', fontStyle: 'italic' },
        { token: 'keyword', foreground: '8839ef', fontStyle: 'bold' },
        { token: 'string', foreground: '40a02b' },
        { token: 'number', foreground: 'fe640b' },
        { token: 'type', foreground: '1e66f5' },
        { token: 'function', foreground: '1e66f5' },
        { token: 'operator', foreground: '179299' },
        { token: 'variable', foreground: '4c4f69' },
      ],
      colors: {
        'editor.background': '#eff1f5',
        'editor.foreground': '#4c4f69',
        'editorLineNumber.foreground': '#acb0be',
        'editorLineNumber.activeForeground': '#8839ef',
        'editorCursor.foreground': '#8839ef',
        'editor.selectionBackground': '#bcc0cc80',
        'editor.lineHighlightBackground': '#ccd0da40',
        'editorGutter.background': '#e6e9ef',
      }
    });

    // Set initial theme
    monaco.editor.setTheme(theme === 'mocha' ? 'asterov-mocha' : 'asterov-latte');

    // Keybindings: Ctrl+Enter (Run Line/Selection), Ctrl+S (Save)
    editor.addCommand(monaco.KeyMod.CtrlCmd | monaco.KeyCode.Enter, () => {
      onRunSelection();
    });

    editor.addCommand(monaco.KeyMod.CtrlCmd | monaco.KeyCode.KeyS, () => {
      onSave();
    });

    // Cursor position tracker
    editor.onDidChangeCursorPosition((e) => {
      if (onCursorChange) {
        onCursorChange(e.position.lineNumber, e.position.column);
      }
    });

    // Custom TRCE Hover Provider
    monaco.languages.registerHoverProvider('r', {
      provideHover: (model, position) => {
        const lineContent = model.getLineContent(position.lineNumber);
        if (lineContent.includes('@trce-id')) {
          const match = lineContent.match(/@trce-id\s+([\w-]+)/);
          const traceId = match ? match[1] : 'TRCE Directive';
          return {
            range: new monaco.Range(position.lineNumber, 1, position.lineNumber, lineContent.length),
            contents: [
              { value: `### TRCE Telemetry Block \`${traceId}\`` },
              { value: `* **Standard:** Canonical 6-Point Structural Scaffolding\n* **Compliance:** Asterov Agentic Continuity Protocol\n* **Namespace:** \`${traceId.split('-')[1] || 'r'}\`` }
            ]
          };
        }
        return null;
      }
    });
  };

  return (
    <div className="h-full w-full relative overflow-hidden bg-rt-base">
      <Editor
        height="100%"
        defaultLanguage="r"
        language={language}
        value={value}
        onChange={(val) => onChange(val || '')}
        theme={theme === 'mocha' ? 'asterov-mocha' : 'asterov-latte'}
        onMount={handleEditorMount}
        options={{
          glyphMargin: true,
          fontFamily: '"JetBrains Mono", Consolas, "Courier New", monospace',
          fontSize: 13,
          lineHeight: 20,
          minimap: { enabled: true, maxColumn: 80 },
          scrollBeyondLastLine: false,
          smoothScrolling: true,
          automaticLayout: true,
          tabSize: 2,
          renderLineHighlight: 'all',
          cursorBlinking: 'smooth',
          bracketPairColorization: { enabled: true },
          padding: { top: 8, bottom: 8 }
        }}
      />
    </div>
  );
};
