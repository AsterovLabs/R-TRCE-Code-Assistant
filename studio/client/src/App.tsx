/**
 * studio/client/src/App.tsx -- R-TRCE Code Assistant Studio Root Component
 */

import React, { useState, useEffect, useCallback, useRef } from 'react';
import { Header } from './components/Header';
import { Workbench } from './components/Workbench';
import { DiffModal } from './components/Editor/DiffModal';
import { StatusBar } from './components/StatusBar';
import {
  ThemeMode,
  AnalyzeResult,
  CheckResult,
  PitfallTrap,
  QuizQuestion,
  ConsoleEntry,
  WorkspaceObject,
  PlotItem,
  AnnotateResult
} from './types';
import {
  readFile,
  writeFile,
  rAction,
  getSamples
} from './services/api';
import { terminalWs } from './services/websocket';

export const App: React.FC = () => {
  // Theme state
  const [theme, setTheme] = useState<ThemeMode>('mocha');

  // Document state
  const [currentFile, setCurrentFile] = useState<string>('');
  const [code, setCode] = useState<string>('');
  const [originalCode, setOriginalCode] = useState<string>('');
  const [isModified, setIsModified] = useState<boolean>(false);
  const [cursorPosition, setCursorPosition] = useState({ line: 1, col: 1 });
  const [targetLine, setTargetLine] = useState<number | null>(null);

  // Analysis & Telemetry state
  const [analysis, setAnalysis] = useState<AnalyzeResult | null>(null);
  const [checkResult, setCheckResult] = useState<CheckResult | null>(null);
  const [pitfalls, setPitfalls] = useState<PitfallTrap[]>([]);
  const [quiz, setQuiz] = useState<QuizQuestion[]>([]);

  // Runtime & Execution state
  const [consoleEntries, setConsoleEntries] = useState<ConsoleEntry[]>([]);
  const [plots, setPlots] = useState<PlotItem[]>([]);
  const [workspaceObjects, setWorkspaceObjects] = useState<WorkspaceObject[]>([]);
  const [isEvaluating, setIsEvaluating] = useState<boolean>(false);
  const [isConnected, setIsConnected] = useState<boolean>(true);

  // Diff Modal state
  const [diffState, setDiffState] = useState<{
    isOpen: boolean;
    originalText: string;
    annotatedText: string;
    insertedCount: number;
  }>({
    isOpen: false,
    originalText: '',
    annotatedText: '',
    insertedCount: 0
  });

  // Toggle theme
  const toggleTheme = () => {
    const nextTheme: ThemeMode = theme === 'mocha' ? 'latte' : 'mocha';
    setTheme(nextTheme);
    document.documentElement.setAttribute('data-rtrce-theme', nextTheme);
  };

  // Connect WebSocket on mount
  useEffect(() => {
    terminalWs.connect();
    const unsubscribe = terminalWs.subscribe((msg) => {
      if (msg.type === 'eval_result') {
        setIsEvaluating(false);
        const res = msg.result;
        if (res) {
          // Add entry to console
          const newEntries: ConsoleEntry[] = (res.entries || []).map((en: any, i: number) => ({
            id: `en-${Date.now()}-${i}`,
            code: en.code || '',
            timestamp: new Date().toLocaleTimeString(),
            output: Array.isArray(en.output) ? en.output : [String(en.output || '')].filter(Boolean),
            messages: en.messages || [],
            warnings: en.warnings || [],
            error: en.error || null,
            value_text: en.value_text || [],
            value_class: en.value_class || null
          }));

          setConsoleEntries((prev) => [...prev, ...newEntries]);

          // Collect plots
          if (res.plots && res.plots.length > 0) {
            const newPlots: PlotItem[] = res.plots.map((p: any) => ({
              id: p.id || `plot-${Date.now()}`,
              data_uri: p.data_uri,
              timestamp: new Date().toLocaleTimeString()
            }));
            setPlots((prev) => [...newPlots, ...prev]);
          }

          // Update workspace objects
          if (res.workspace) {
            setWorkspaceObjects(Array.isArray(res.workspace) ? res.workspace : []);
          }
        } else if (msg.error) {
          setConsoleEntries((prev) => [
            ...prev,
            {
              id: `err-${Date.now()}`,
              code: '',
              timestamp: new Date().toLocaleTimeString(),
              output: [],
              messages: [],
              warnings: [],
              error: msg.error
            }
          ]);
        }
      } else if (msg.type === 'workspace_result') {
        if (msg.result?.workspace) {
          setWorkspaceObjects(Array.isArray(msg.result.workspace) ? msg.result.workspace : []);
        }
      } else if (msg.type === 'reset_result') {
        setConsoleEntries([]);
        setPlots([]);
        setWorkspaceObjects([]);
      }
    });

    return () => {
      unsubscribe();
    };
  }, []);

  // Run AST Analysis & TRCE Check on code
  const runAnalysis = useCallback(async (currentCode: string) => {
    if (!currentCode.trim()) return;
    try {
      const [astRes, trceRes, pitfallRes] = await Promise.all([
        rAction<AnalyzeResult>('analyze', { code: currentCode }),
        rAction<CheckResult>('check', { code: currentCode }),
        rAction<{ traps: PitfallTrap[] }>('pitfalls', { code: currentCode })
      ]);

      setAnalysis(astRes);
      setCheckResult(trceRes);
      setPitfalls(pitfallRes.traps || []);
    } catch (err) {
      console.warn('AST analysis error:', err);
    }
  }, []);

  // Load a file
  const handleOpenFile = async (filePath: string) => {
    try {
      const res = await readFile(filePath);
      setCurrentFile(res.path);
      setCode(res.content);
      setOriginalCode(res.content);
      setIsModified(false);
      runAnalysis(res.content);
    } catch (err) {
      console.error('Failed to open file:', err);
    }
  };

  // Initial load: pick the first sample script
  useEffect(() => {
    const init = async () => {
      try {
        const samples = await getSamples();
        if (samples.length > 0) {
          handleOpenFile(samples[0].path);
        }
      } catch (err) {
        console.error('Init error:', err);
      }
    };
    init();
  }, []);

  // Code edit handler
  const handleCodeChange = (newCode: string) => {
    setCode(newCode);
    setIsModified(newCode !== originalCode);
  };

  // Save file
  const handleSave = async () => {
    if (!currentFile) return;
    try {
      await writeFile(currentFile, code);
      setOriginalCode(code);
      setIsModified(false);
      runAnalysis(code);
    } catch (err) {
      console.error('Failed to save:', err);
    }
  };

  // Run selection or current line
  const handleRunSelection = () => {
    if (isEvaluating) return;
    // For now, if code is present, send either line or selection
    setIsEvaluating(true);
    terminalWs.evaluate(code);
  };

  // Run entire script
  const handleRunAll = () => {
    if (isEvaluating) return;
    setIsEvaluating(true);
    terminalWs.evaluate(code);
  };

  // Synthesize 6-point annotations & open Diff Modal
  const handleAnnotate = async () => {
    try {
      const res = await rAction<AnnotateResult>('annotate', {
        code,
        style: 'jsdoc',
        prefix: 'trce-r'
      });

      setDiffState({
        isOpen: true,
        originalText: code,
        annotatedText: res.annotated_text,
        insertedCount: res.inserted_count
      });
    } catch (err: any) {
      alert(`Annotation synthesis failed: ${err.message}`);
    }
  };

  // Apply annotated code from Diff Modal
  const handleApplyDiff = async () => {
    const newText = diffState.annotatedText;
    setCode(newText);
    setDiffState(prev => ({ ...prev, isOpen: false }));
    if (currentFile) {
      await writeFile(currentFile, newText);
      setOriginalCode(newText);
      setIsModified(false);
      runAnalysis(newText);
    }
  };

  // Generate quiz
  const handleGenerateQuiz = async () => {
    try {
      const res = await rAction<QuizQuestion[]>('quiz', { code });
      setQuiz(res || []);
    } catch (err) {
      console.warn('Quiz generation failed:', err);
    }
  };

  // Console execution
  const handleExecuteConsole = (cmd: string) => {
    setIsEvaluating(true);
    terminalWs.evaluate(cmd);
  };

  // Clear Console
  const handleClearConsole = () => {
    setConsoleEntries([]);
  };

  // Reset Session
  const handleResetSession = () => {
    terminalWs.reset();
  };

  // Refresh Workspace
  const handleRefreshWorkspace = () => {
    terminalWs.getWorkspace();
  };

  return (
    <div className="h-screen w-screen flex flex-col bg-rt-crust text-rt-text overflow-hidden font-sans select-none">
      {/* Top Header */}
      <Header
        currentFile={currentFile}
        isModified={isModified}
        theme={theme}
        onToggleTheme={toggleTheme}
        onRunSelection={handleRunSelection}
        onRunAll={handleRunAll}
        onSave={handleSave}
        onAnnotate={handleAnnotate}
        onValidate={() => runAnalysis(code)}
        isEvaluating={isEvaluating}
      />

      {/* Main IDE Workbench */}
      <Workbench
        theme={theme}
        currentFile={currentFile}
        code={code}
        onChangeCode={handleCodeChange}
        onOpenFile={handleOpenFile}
        onRunSelection={handleRunSelection}
        onSave={handleSave}
        onCursorChange={(line, col) => setCursorPosition({ line, col })}
        targetLine={targetLine}
        onSelectLine={(line) => setTargetLine(line)}
        analysis={analysis}
        checkResult={checkResult}
        pitfalls={pitfalls}
        quiz={quiz}
        onGenerateQuiz={handleGenerateQuiz}
        onAnnotate={handleAnnotate}
        consoleEntries={consoleEntries}
        onExecuteConsole={handleExecuteConsole}
        onClearConsole={handleClearConsole}
        onResetSession={handleResetSession}
        plots={plots}
        workspaceObjects={workspaceObjects}
        onRefreshWorkspace={handleRefreshWorkspace}
        isEvaluating={isEvaluating}
      />

      {/* Status Bar */}
      <StatusBar
        cursorLine={cursorPosition.line}
        cursorCol={cursorPosition.col}
        currentFile={currentFile}
        coveragePct={checkResult?.coverage_pct}
        traceCount={checkResult?.traces?.length}
        isConnected={isConnected}
      />

      {/* Side-by-Side Diff Modal for Annotation Injection */}
      <DiffModal
        isOpen={diffState.isOpen}
        originalText={diffState.originalText}
        annotatedText={diffState.annotatedText}
        insertedCount={diffState.insertedCount}
        theme={theme}
        onApply={handleApplyDiff}
        onClose={() => setDiffState(prev => ({ ...prev, isOpen: false }))}
      />
    </div>
  );
};
