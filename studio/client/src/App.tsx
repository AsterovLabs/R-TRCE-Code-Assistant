/**
 * studio/client/src/App.tsx -- R-TRCE Code Assistant Studio Root Component
 */

import React, { useState, useEffect, useCallback, useRef } from 'react';
import { Header } from './components/Header';
import { Workbench } from './components/Workbench';
import { ErrorBoundary } from './components/ErrorBoundary';
import { DiffModal } from './components/Editor/DiffModal';
import { OpenProjectModal } from './components/OpenProjectModal';
import { ProjectOverviewModal } from './components/ProjectOverviewModal';
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
  AnnotateResult,
  RecentProject,
  ProjectOverview
} from './types';
import {
  readFile,
  writeFile,
  rAction,
  getSamples,
  getCurrentProject,
  openProject,
  getRecentProjects,
  getProjectOverview,
  pickFolder
} from './services/api';
import { terminalWs } from './services/websocket';

export const App: React.FC = () => {
  // Theme state
  const [theme, setTheme] = useState<ThemeMode>('mocha');

  // Project Workspace state
  const [projectName, setProjectName] = useState<string>('');
  const [projectPath, setProjectPath] = useState<string>('');
  const [recentProjects, setRecentProjects] = useState<RecentProject[]>([]);
  const [isOpenProjectModal, setIsOpenProjectModal] = useState<boolean>(false);
  const [isOverviewModal, setIsOverviewModal] = useState<boolean>(false);
  const [projectOverview, setProjectOverview] = useState<ProjectOverview | null>(null);
  const [overviewLoading, setOverviewLoading] = useState<boolean>(false);

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

  // Project Workspace Handlers
  const refreshProject = useCallback(async () => {
    try {
      const [curr, recents] = await Promise.all([
        getCurrentProject(),
        getRecentProjects()
      ]);
      setProjectName(curr.name);
      setProjectPath(curr.path);
      setRecentProjects(recents);
    } catch (e) {
      console.warn('Failed to load project details:', e);
    }
  }, []);

  useEffect(() => {
    refreshProject();
  }, [refreshProject]);

  const handleOpenProject = async (targetPath: string) => {
    const res = await openProject(targetPath);
    setProjectPath(res.activeProjectDir);
    setProjectName(res.name);
    const recents = await getRecentProjects().catch(() => []);
    setRecentProjects(recents);
    terminalWs.send({ type: 'workspace' });
    setConsoleEntries((prev) => [
      ...prev,
      {
        id: `sys-${Date.now()}`,
        code: '',
        timestamp: new Date().toLocaleTimeString(),
        output: [`[Workspace] Switched active project to: ${res.activeProjectDir}`],
        messages: [],
        warnings: []
      }
    ]);
    if (currentFile && !currentFile.startsWith(res.activeProjectDir) && !currentFile.includes('samples')) {
      setCurrentFile('');
      setCode('');
      setOriginalCode('');
      setIsModified(false);
      setAnalysis(null);
      setCheckResult(null);
      setPitfalls([]);
    }
  };

  const handlePickFolderNative = async (): Promise<string | null> => {
    try {
      const res = await pickFolder();
      if (!res.canceled && res.path) {
        return res.path;
      }
    } catch (e) {
      console.warn('pickFolder error:', e);
    }
    return null;
  };

  const handleShowProjectOverview = async () => {
    setIsOverviewModal(true);
    setOverviewLoading(true);
    try {
      const overview = await getProjectOverview();
      setProjectOverview(overview);
    } catch (err) {
      console.error('Failed to load project overview:', err);
    } finally {
      setOverviewLoading(false);
    }
  };

const getLanguageForFile = (filePath: string): string => {
  const ext = filePath.split('.').pop()?.toLowerCase();
  switch (ext) {
    case 'r':
    case 'rmd':
    case 'qmd':
      return 'r';
    case 'json':
      return 'json';
    case 'md':
    case 'markdown':
      return 'markdown';
    case 'js':
    case 'jsx':
    case 'mjs':
      return 'javascript';
    case 'ts':
    case 'tsx':
      return 'typescript';
    case 'css':
      return 'css';
    case 'html':
      return 'html';
    case 'sh':
    case 'bash':
      return 'shell';
    case 'yaml':
    case 'yml':
      return 'yaml';
    default:
      return 'plaintext';
  }
};

const isSupportedSourceFile = (filePath: string): boolean => {
  if (!filePath) return true;
  return /\.(r|rmd|qmd|py|ipynb|js|mjs|ts)$/i.test(filePath);
};

  const activeLang = getLanguageForFile(currentFile || 'untitled.R');

  // Run AST Analysis & TRCE Check on code
  const runAnalysis = useCallback(async (currentCode: string, filePath?: string) => {
    if (!currentCode.trim()) return;
    const targetFile = filePath || currentFile;
    if (targetFile && !isSupportedSourceFile(targetFile)) {
      setAnalysis(null);
      setCheckResult(null);
      setPitfalls([]);
      return;
    }
    const lang = getLanguageForFile(targetFile);
    try {
      const [astRes, trceRes, pitfallRes] = await Promise.all([
        rAction<AnalyzeResult>('analyze', { code: currentCode, file: targetFile }, lang),
        rAction<CheckResult>('check', { code: currentCode, file: targetFile }, lang),
        rAction<{ traps: PitfallTrap[] }>('pitfalls', { code: currentCode, file: targetFile }, lang)
      ]);

      setAnalysis(astRes);
      setCheckResult(trceRes);
      setPitfalls(pitfallRes.traps || []);
    } catch (err) {
      console.warn('AST analysis error:', err);
    }
  }, [currentFile]);

  // Load a file
  const handleOpenFile = async (filePath: string) => {
    try {
      const res = await readFile(filePath);
      setCurrentFile(res.path);
      setCode(res.content);
      setOriginalCode(res.content);
      setIsModified(false);
      runAnalysis(res.content, res.path);
    } catch (err) {
      console.error('Failed to open file:', err);
    }
  };

  // Create a new scratch script
  const handleNewScript = (ext: string = 'R') => {
    const filename = `untitled.${ext}`;
    setCurrentFile(filename);
    let template = '# Untitled R Script\n# Write R code or press Annotate to generate TRCE doc-blocks\n\n';
    if (ext.toLowerCase() === 'py') {
      template = '# Untitled Python Script\n# Write Python code or press Annotate to generate TRCE doc-blocks\n\n';
    } else if (ext.toLowerCase() === 'js') {
      template = '// Untitled JavaScript Script\n// Write JS code or press Annotate to generate TRCE doc-blocks\n\n';
    }
    setCode(template);
    setOriginalCode(template);
    setIsModified(false);
    runAnalysis(template, filename);
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
    if (!currentFile || currentFile.startsWith('untitled.')) {
      const fname = prompt('Enter filename to save script:', currentFile || 'script.R');
      if (!fname) return;
      try {
        await writeFile(fname, code);
        setCurrentFile(fname);
        setOriginalCode(code);
        setIsModified(false);
        runAnalysis(code, fname);
      } catch (err) {
        console.error('Failed to save file:', err);
      }
      return;
    }
    try {
      await writeFile(currentFile, code);
      setOriginalCode(code);
      setIsModified(false);
      runAnalysis(code, currentFile);
    } catch (err) {
      console.error('Failed to save:', err);
    }
  };

  // Run selection or current line
  const handleRunSelection = () => {
    if (isEvaluating) return;
    setIsEvaluating(true);
    terminalWs.evaluate(code, 10, undefined, activeLang);
  };

  // Run entire script
  const handleRunAll = () => {
    if (isEvaluating) return;
    setIsEvaluating(true);
    terminalWs.evaluate(code, 10, undefined, activeLang);
  };

  // Synthesize 6-point annotations & open Diff Modal
  const handleAnnotate = async () => {
    if (currentFile && !isSupportedSourceFile(currentFile)) {
      alert('TRCE annotation synthesis is supported for R, Python, and JavaScript/TypeScript scripts.');
      return;
    }
    const prefix = activeLang === 'python' ? 'trce-py' : (activeLang === 'javascript' || activeLang === 'typescript' ? 'trce-js' : 'trce-r');

    try {
      const res = await rAction<AnnotateResult>('annotate', {
        code,
        file: currentFile,
        style: 'jsdoc',
        prefix
      }, activeLang);

      if (!res.inserted_count || res.inserted_count === 0) {
        alert(`All components in this ${activeLang.toUpperCase()} file are already 100% annotated with valid TRCE telemetry!`);
        return;
      }

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
    if (currentFile && !currentFile.startsWith('untitled.')) {
      await writeFile(currentFile, newText);
      setOriginalCode(newText);
      setIsModified(false);
    } else {
      setIsModified(true);
    }
    runAnalysis(newText, currentFile);
  };

  // Generate quiz
  const handleGenerateQuiz = async () => {
    try {
      const res = await rAction<QuizQuestion[]>('quiz', { code }, activeLang);
      setQuiz(res || []);
    } catch (err) {
      console.warn('Quiz generation failed:', err);
    }
  };

  // Console execution
  const handleExecuteConsole = (cmd: string) => {
    setIsEvaluating(true);
    terminalWs.evaluate(cmd, 10, undefined, activeLang);
  };

  // Clear Console
  const handleClearConsole = () => {
    setConsoleEntries([]);
  };

  // Reset Session
  const handleResetSession = () => {
    terminalWs.reset(activeLang);
  };

  // Refresh Workspace
  const handleRefreshWorkspace = () => {
    terminalWs.getWorkspace(activeLang);
  };

  return (
    <div className="h-screen w-screen flex flex-col bg-rt-crust text-rt-text overflow-hidden font-sans select-none">
      {/* Top Header */}
      <Header
        currentFile={currentFile}
        isModified={isModified}
        theme={theme}
        projectName={projectName}
        projectPath={projectPath}
        recentProjects={recentProjects}
        onOpenProjectModal={() => setIsOpenProjectModal(true)}
        onOpenRecentProject={handleOpenProject}
        onShowProjectOverview={handleShowProjectOverview}
        onToggleTheme={toggleTheme}
        onRunSelection={handleRunSelection}
        onRunAll={handleRunAll}
        onSave={handleSave}
        onAnnotate={handleAnnotate}
        onValidate={() => runAnalysis(code)}
        isEvaluating={isEvaluating}
      />

      {/* Main IDE Workbench */}
      <ErrorBoundary fallbackTitle="Workbench Error">
        <Workbench
          theme={theme}
          currentFile={currentFile}
          code={code}
          language={getLanguageForFile(currentFile)}
          onChangeCode={handleCodeChange}
          onOpenFile={handleOpenFile}
          onNewScript={handleNewScript}
          projectName={projectName}
          projectPath={projectPath}
          onOpenFolder={() => setIsOpenProjectModal(true)}
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
      </ErrorBoundary>

      {/* Status Bar */}
      <StatusBar
        cursorLine={cursorPosition.line}
        cursorCol={cursorPosition.col}
        currentFile={currentFile}
        coveragePct={checkResult?.coverage_pct}
        traceCount={checkResult?.traces?.length}
        language={activeLang}
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

      {/* Open Project Modal */}
      <OpenProjectModal
        isOpen={isOpenProjectModal}
        currentPath={projectPath}
        recentProjects={recentProjects}
        onOpenPath={handleOpenProject}
        onPickFolderNative={handlePickFolderNative}
        onClose={() => setIsOpenProjectModal(false)}
      />

      {/* Project Overview & Health Modal */}
      <ProjectOverviewModal
        isOpen={isOverviewModal}
        overview={projectOverview}
        loading={overviewLoading}
        onRefresh={handleShowProjectOverview}
        onClose={() => setIsOverviewModal(false)}
      />
    </div>
  );
};
