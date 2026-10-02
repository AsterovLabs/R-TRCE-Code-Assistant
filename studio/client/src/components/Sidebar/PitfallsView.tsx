/**
 * studio/client/src/components/Sidebar/PitfallsView.tsx -- Pitfall Sentinel Live Trap Detector
 */

import React from 'react';
import { AlertTriangle, ShieldCheck, AlertCircle, Info, Lightbulb, ChevronRight } from 'lucide-react';
import { PitfallTrap } from '../../types';
import { ensureArray } from '../../utils/array';

interface PitfallsViewProps {
  pitfalls: PitfallTrap[];
  onSelectLine: (line: number) => void;
  isLoading?: boolean;
}

export const PitfallsView: React.FC<PitfallsViewProps> = ({
  pitfalls,
  onSelectLine,
  isLoading = false
}) => {
  const trapList = ensureArray(pitfalls);

  if (isLoading) {
    return (
      <div className="h-full flex items-center justify-center p-4 text-xs text-rt-text-faint">
        <div className="animate-spin mr-2">⟳</div> Scanning for beginner traps & memory leaks...
      </div>
    );
  }

  if (trapList.length === 0) {
    return (
      <div className="h-full flex flex-col items-center justify-center p-6 text-center text-xs text-rt-text-muted">
        <ShieldCheck className="w-10 h-10 mb-2 text-rt-green opacity-80" />
        <span className="font-semibold text-rt-text text-sm">Clean Script!</span>
        <p className="mt-1 text-rt-text-faint">
          No memory bottlenecks, growing loops, or R beginner traps detected in this file.
        </p>
      </div>
    );
  }

  const getSeverityBadge = (severity: string) => {
    switch (severity) {
      case 'error':
      case 'critical':
        return <span className="bg-rt-red/20 text-rt-red text-[9px] font-bold px-1.5 py-0.5 rounded uppercase">Hazard</span>;
      case 'warning':
        return <span className="bg-rt-yellow/20 text-rt-yellow text-[9px] font-bold px-1.5 py-0.5 rounded uppercase">Warning</span>;
      default:
        return <span className="bg-rt-blue/20 text-rt-blue text-[9px] font-bold px-1.5 py-0.5 rounded uppercase">Note</span>;
    }
  };

  return (
    <div className="h-full flex flex-col bg-rt-mantle text-xs select-none">
      {/* Header */}
      <div className="h-9 px-3 border-b border-rt-surface-0 flex items-center justify-between font-semibold tracking-wider text-rt-text-soft uppercase text-[11px]">
        <span>Pitfall Sentinel</span>
        <span className="font-mono text-rt-red font-bold">{trapList.length} traps</span>
      </div>

      <div className="flex-1 overflow-y-auto p-3 space-y-3">
        {trapList.map((trap, idx) => {
          const desc = trap.description || trap.explanation;
          const remedy = trap.suggestion || trap.recommendation;

          return (
            <div
              key={idx}
              className="p-3 rounded-lg bg-rt-surface-0/60 border border-rt-surface-1 hover:border-rt-peach/50 transition"
            >
              <div className="flex items-start justify-between gap-2 mb-1.5">
                <div className="flex items-center space-x-1.5 font-semibold text-rt-text">
                  <AlertTriangle className="w-3.5 h-3.5 text-rt-peach flex-shrink-0" />
                  <span className="truncate">{trap.title || trap.trap || trap.name}</span>
                </div>
                <div className="flex items-center space-x-1.5 flex-shrink-0">
                  {getSeverityBadge(trap.severity)}
                  {trap.line && (
                    <button
                      onClick={() => onSelectLine(trap.line)}
                      className="font-mono text-[10px] text-rt-text-faint hover:text-rt-text bg-rt-crust px-1.5 py-0.5 rounded transition"
                      title="Jump to line in editor"
                    >
                      L{trap.line}
                    </button>
                  )}
                </div>
              </div>

              {desc && (
                <p className="text-rt-text-soft text-[11px] leading-relaxed mb-2">
                  {desc}
                </p>
              )}

              {remedy && (
                <div className="p-2 rounded bg-rt-crust border border-rt-surface-0 flex items-start space-x-2 text-[11px]">
                  <Lightbulb className="w-3.5 h-3.5 text-rt-yellow flex-shrink-0 mt-0.5" />
                  <div className="text-rt-text-muted leading-tight">
                    <span className="font-semibold text-rt-yellow">Remedy: </span>
                    {remedy}
                  </div>
                </div>
              )}
            </div>
          );
        })}
      </div>
    </div>
  );
};
