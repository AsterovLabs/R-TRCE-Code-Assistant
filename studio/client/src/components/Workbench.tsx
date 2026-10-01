/**
 * studio/client/src/components/Workbench.tsx -- Multi-Pane Resizable IDE Workbench
 */

import React from 'react';
import { Panel, PanelGroup, PanelResizeHandle } from 'react-resizable-panels';
import { SidebarNav } from './Sidebar/SidebarNav';
import { FileTree } from './Sidebar/FileTree';
import { AstExplorer } from './Sidebar/AstExplorer';
import { TrceInspector } from './Sidebar/TrceInspector';
import { PitfallsView } from './Sidebar/PitfallsView';
import { QuizView } from './Sidebar/QuizView';
import { MonacoEditor } from './Editor/MonacoEditor';
import { RConsole } from './Console/RConsole';
import { PlotsPane } from './RightRail/PlotsPane';
import { WorkspacePane } from './RightRail/WorkspacePane';
import { HelpPane } from './RightRail/HelpPane';
import {
  ThemeMode,
  SidebarTab,
  RightRailTab,
  AnalyzeResult,
  CheckResult,
  PitfallTrap,
  QuizQuestion,
  ConsoleEntry,
  WorkspaceObject,
  PlotItem
} from '../types';

interface WorkbenchProps {
  theme: ThemeMode;
  currentFile: string;
  code: string;
  onChangeCode: (code: string) => void;
  onOpenFile: (path: string) => void;
  onRunSelection: () => void;
  onSave: () => void;
  onCursorChange: (line: number, col: number) => void;
  targetLine: number | null;
  onSelectLine: (line: number) => void;
  analysis: AnalyzeResult | null;
  checkResult: CheckResult | null;
  pitfalls: PitfallTrap[];
  quiz: QuizQuestion[];
  onGenerateQuiz: () => void;
  onAnnotate: () => void;
  consoleEntries: ConsoleEntry[];
  onExecuteConsole: (cmd: string) => void;
  onClearConsole: () => void;
  onResetSession: () => void;
  plots: PlotItem[];
  workspaceObjects: WorkspaceObject[];
  onRefreshWorkspace: () => void;
  isEvaluating?: boolean;
}

export const Workbench: React.FC<WorkbenchProps> = ({
  theme,
  currentFile,
  code,
  onChangeCode,
  onOpenFile,
  onRunSelection,
  onSave,
  onCursorChange,
  targetLine,
  onSelectLine,
  analysis,
  checkResult,
  pitfalls,
  quiz,
  onGenerateQuiz,
  onAnnotate,
  consoleEntries,
  onExecuteConsole,
  onClearConsole,
  onResetSession,
  plots,
  workspaceObjects,
  onRefreshWorkspace,
  isEvaluating = false
}) => {
  const [activeSidebarTab, setActiveSidebarTab] = React.useState<SidebarTab>('files');
  const [activeRightRailTab, setActiveRightRailTab] = React.useState<RightRailTab>('plots');

  return (
    <div className="flex-1 flex overflow-hidden">
      {/* Activity Bar */}
      <SidebarNav
        activeTab={activeSidebarTab}
        onTabChange={setActiveSidebarTab}
        pitfallCount={pitfalls.length}
        coveragePct={checkResult?.coverage_pct}
      />

      {/* Main Resizable Panel Group */}
      <PanelGroup direction="horizontal" className="flex-1">
        {/* Left Sidebar Panel */}
        <Panel defaultSize={22} minSize={15} maxSize={35} className="bg-rt-mantle border-r border-rt-surface-0 flex flex-col">
          {activeSidebarTab === 'files' && (
            <FileTree currentFile={currentFile} onOpenFile={onOpenFile} />
          )}
          {activeSidebarTab === 'ast' && (
            <AstExplorer analysis={analysis} onSelectLine={onSelectLine} />
          )}
          {activeSidebarTab === 'trce' && (
            <TrceInspector
              checkResult={checkResult}
              onAnnotate={onAnnotate}
              onSelectLine={onSelectLine}
            />
          )}
          {activeSidebarTab === 'pitfalls' && (
            <PitfallsView pitfalls={pitfalls} onSelectLine={onSelectLine} />
          )}
          {activeSidebarTab === 'quiz' && (
            <QuizView quiz={quiz} onGenerateQuiz={onGenerateQuiz} />
          )}
        </Panel>

        <PanelResizeHandle className="w-1 bg-rt-surface-0 hover:bg-rt-mauve transition cursor-col-resize select-none" />

        {/* Center Section: Editor & Console */}
        <Panel defaultSize={54} minSize={30} className="flex flex-col">
          <PanelGroup direction="vertical">
            {/* Monaco Editor */}
            <Panel defaultSize={65} minSize={25} className="bg-rt-base flex flex-col">
              <MonacoEditor
                value={code}
                onChange={onChangeCode}
                theme={theme}
                onRunSelection={onRunSelection}
                onSave={onSave}
                onCursorChange={onCursorChange}
                targetLine={targetLine}
              />
            </Panel>

            <PanelResizeHandle className="h-1 bg-rt-surface-0 hover:bg-rt-mauve transition cursor-row-resize select-none" />

            {/* R Console */}
            <Panel defaultSize={35} minSize={15} className="bg-rt-crust flex flex-col">
              <RConsole
                entries={consoleEntries}
                onExecute={onExecuteConsole}
                onClear={onClearConsole}
                onResetSession={onResetSession}
                isEvaluating={isEvaluating}
              />
            </Panel>
          </PanelGroup>
        </Panel>

        <PanelResizeHandle className="w-1 bg-rt-surface-0 hover:bg-rt-mauve transition cursor-col-resize select-none" />

        {/* Right Rail: Workspace, Plots & Help */}
        <Panel defaultSize={24} minSize={15} maxSize={40} className="bg-rt-mantle border-l border-rt-surface-0 flex flex-col">
          {/* Rail Header Tab Switcher */}
          <div className="h-9 px-2 border-b border-rt-surface-0 flex items-center space-x-1 bg-rt-crust/50 select-none">
            <button
              onClick={() => setActiveRightRailTab('plots')}
              className={`px-2.5 py-1 rounded text-[11px] font-semibold transition ${
                activeRightRailTab === 'plots'
                  ? 'bg-rt-surface-0 text-rt-mauve'
                  : 'text-rt-text-faint hover:text-rt-text'
              }`}
            >
              Plots {plots.length > 0 && `(${plots.length})`}
            </button>
            <button
              onClick={() => setActiveRightRailTab('workspace')}
              className={`px-2.5 py-1 rounded text-[11px] font-semibold transition ${
                activeRightRailTab === 'workspace'
                  ? 'bg-rt-surface-0 text-rt-mauve'
                  : 'text-rt-text-faint hover:text-rt-text'
              }`}
            >
              Workspace {workspaceObjects.length > 0 && `(${workspaceObjects.length})`}
            </button>
            <button
              onClick={() => setActiveRightRailTab('help')}
              className={`px-2.5 py-1 rounded text-[11px] font-semibold transition ${
                activeRightRailTab === 'help'
                  ? 'bg-rt-surface-0 text-rt-mauve'
                  : 'text-rt-text-faint hover:text-rt-text'
              }`}
            >
              Help
            </button>
          </div>

          <div className="flex-1 overflow-hidden">
            {activeRightRailTab === 'plots' && (
              <PlotsPane plots={plots} />
            )}
            {activeRightRailTab === 'workspace' && (
              <WorkspacePane
                objects={workspaceObjects}
                onRefresh={onRefreshWorkspace}
              />
            )}
            {activeRightRailTab === 'help' && (
              <HelpPane />
            )}
          </div>
        </Panel>
      </PanelGroup>
    </div>
  );
};
