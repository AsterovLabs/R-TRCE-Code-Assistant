/**
 * studio/client/src/components/Sidebar/AstExplorer.tsx -- AST Archetype & Component Explorer
 */

import React from 'react';
import { Network, Layers, Terminal, Sparkles, ChevronRight, Hash } from 'lucide-react';
import { AnalyzeResult, ComponentItem } from '../../types';

interface AstExplorerProps {
  analysis: AnalyzeResult | null;
  onSelectLine: (line: number) => void;
  isLoading?: boolean;
}

export const AstExplorer: React.FC<AstExplorerProps> = ({
  analysis,
  onSelectLine,
  isLoading = false
}) => {
  if (isLoading) {
    return (
      <div className="h-full flex items-center justify-center p-4 text-xs text-rt-text-faint">
        <div className="animate-spin mr-2">⟳</div> Analyzing AST structure...
      </div>
    );
  }

  if (!analysis) {
    return (
      <div className="h-full flex flex-col items-center justify-center p-6 text-center text-xs text-rt-text-faint">
        <Network className="w-8 h-8 mb-2 opacity-40 text-rt-mauve" />
        <p>No AST analysis available for the current document.</p>
      </div>
    );
  }

  const getArchetypeColor = (archetype: string) => {
    if (archetype.includes('Shiny')) return 'bg-rt-teal/15 text-rt-teal border-rt-teal/30';
    if (archetype.includes('Snowflake') || archetype.includes('Pipeline')) return 'bg-rt-blue/15 text-rt-blue border-rt-blue/30';
    if (archetype.includes('Statistical')) return 'bg-rt-mauve/15 text-rt-mauve border-rt-mauve/30';
    if (archetype.includes('CLI')) return 'bg-rt-peach/15 text-rt-peach border-rt-peach/30';
    return 'bg-rt-surface-1/40 text-rt-text border-rt-surface-2';
  };

  return (
    <div className="h-full flex flex-col bg-rt-mantle text-xs select-none">
      {/* Header */}
      <div className="h-9 px-3 border-b border-rt-surface-0 flex items-center justify-between font-semibold tracking-wider text-rt-text-soft uppercase text-[11px]">
        <span>AST Archetype</span>
        <span className="font-mono text-rt-mauve">{analysis.component_count} components</span>
      </div>

      <div className="flex-1 overflow-y-auto p-3 space-y-4">
        {/* Archetype Recognition Card */}
        <div className={`p-3 rounded-lg border ${getArchetypeColor(analysis.archetype)}`}>
          <div className="flex items-center space-x-2 mb-1">
            <Sparkles className="w-4 h-4 fill-current opacity-80" />
            <span className="text-[10px] font-bold uppercase tracking-wider opacity-75">Recognized Pattern</span>
          </div>
          <div className="font-semibold text-sm">
            {analysis.archetype}
          </div>
        </div>

        {/* Imported Packages */}
        {analysis.imports && analysis.imports.length > 0 && (
          <div>
            <div className="text-[11px] font-semibold text-rt-text-faint uppercase tracking-wider mb-1.5 flex items-center space-x-1.5">
              <Layers className="w-3.5 h-3.5" />
              <span>Dependencies ({analysis.imports.length})</span>
            </div>
            <div className="flex flex-wrap gap-1.5">
              {analysis.imports.map((pkg) => (
                <span
                  key={pkg}
                  className="px-2 py-0.5 rounded bg-rt-surface-0 border border-rt-surface-1 font-mono text-[11px] text-rt-text-soft"
                >
                  {pkg}
                </span>
              ))}
            </div>
          </div>
        )}

        {/* Component Tree */}
        <div>
          <div className="text-[11px] font-semibold text-rt-text-faint uppercase tracking-wider mb-2 flex items-center space-x-1.5">
            <Terminal className="w-3.5 h-3.5" />
            <span>Annotatable Components</span>
          </div>

          <div className="space-y-1.5">
            {analysis.components.map((comp: ComponentItem) => (
              <div
                key={`${comp.name}-${comp.line1}`}
                onClick={() => onSelectLine(comp.line1)}
                className="p-2 rounded bg-rt-surface-0/50 hover:bg-rt-surface-0 border border-rt-surface-1/60 hover:border-rt-mauve/40 transition cursor-pointer group"
              >
                <div className="flex items-center justify-between font-mono">
                  <span className="font-semibold text-rt-text group-hover:text-rt-mauve transition truncate">
                    {comp.name || '<anonymous>'}
                  </span>
                  <span className="text-[10px] text-rt-text-faint bg-rt-crust px-1.5 py-0.5 rounded">
                    L{comp.line1}–{comp.line2}
                  </span>
                </div>

                <div className="mt-1 flex items-center space-x-2 text-[10px] text-rt-text-muted">
                  <span className="capitalize px-1.5 py-0.2 rounded bg-rt-surface-1/40 text-rt-text-soft">
                    {comp.kind.replace('_', ' ')}
                  </span>
                  {comp.args && comp.args.length > 0 && (
                    <span className="truncate">
                      args: ({comp.args.join(', ')})
                    </span>
                  )}
                </div>
              </div>
            ))}
          </div>
        </div>
      </div>
    </div>
  );
};
