/**
 * studio/client/src/components/Sidebar/TrceInspector.tsx -- TRCE Telemetry & 6-Point Field Auditor
 */

import React from 'react';
import { ShieldCheck, ShieldAlert, CheckCircle2, AlertCircle, Sparkles, ChevronDown, ChevronRight } from 'lucide-react';
import { CheckResult, TrceFields } from '../../types';

interface TrceInspectorProps {
  checkResult: CheckResult | null;
  onAnnotate: () => void;
  onSelectLine: (line: number) => void;
  isLoading?: boolean;
}

export const TrceInspector: React.FC<TrceInspectorProps> = ({
  checkResult,
  onAnnotate,
  onSelectLine,
  isLoading = false
}) => {
  const [expandedTrace, setExpandedTrace] = React.useState<string | null>(null);

  if (isLoading) {
    return (
      <div className="h-full flex items-center justify-center p-4 text-xs text-rt-text-faint">
        <div className="animate-spin mr-2">⟳</div> Auditing TRCE telemetry...
      </div>
    );
  }

  if (!checkResult) {
    return (
      <div className="h-full flex flex-col items-center justify-center p-6 text-center text-xs text-rt-text-faint">
        <ShieldCheck className="w-8 h-8 mb-2 opacity-40 text-rt-green" />
        <p>No TRCE audit available. Click 'Audit' to check the current file.</p>
      </div>
    );
  }

  const coverage = Math.round(checkResult.coverage_pct || 0);
  const isComplete = coverage === 100;

  return (
    <div className="h-full flex flex-col bg-rt-mantle text-xs select-none">
      {/* Header */}
      <div className="h-9 px-3 border-b border-rt-surface-0 flex items-center justify-between font-semibold tracking-wider text-rt-text-soft uppercase text-[11px]">
        <span>TRCE Telemetry</span>
        <span className={`font-mono font-bold ${isComplete ? 'text-rt-green' : 'text-rt-yellow'}`}>
          {coverage}%
        </span>
      </div>

      <div className="flex-1 overflow-y-auto p-3 space-y-4">
        {/* Coverage Progress Card */}
        <div className="p-3 rounded-lg bg-rt-surface-0 border border-rt-surface-1">
          <div className="flex items-center justify-between mb-2">
            <span className="font-semibold text-rt-text">Repository Coverage</span>
            <span className="font-mono text-xs font-bold text-rt-text">
              {checkResult.annotated_components} / {checkResult.total_components} blocks
            </span>
          </div>

          <div className="w-full bg-rt-crust h-2 rounded-full overflow-hidden">
            <div
              className={`h-full transition-all duration-500 rounded-full ${
                isComplete ? 'bg-rt-green' : 'bg-gradient-to-r from-rt-yellow to-rt-teal'
              }`}
              style={{ width: `${coverage}%` }}
            />
          </div>

          {!isComplete && (
            <button
              onClick={onAnnotate}
              className="mt-3 w-full py-1.5 px-2 rounded bg-rt-mauve/20 hover:bg-rt-mauve/30 text-rt-mauve border border-rt-mauve/40 font-semibold flex items-center justify-center space-x-1.5 transition active:scale-95"
            >
              <Sparkles className="w-3.5 h-3.5" />
              <span>Synthesize Missing Annotations</span>
            </button>
          )}
        </div>

        {/* Trace Directives List */}
        <div>
          <div className="text-[11px] font-semibold text-rt-text-faint uppercase tracking-wider mb-2 flex items-center justify-between">
            <span>Directives & 6-Point Scaffolding</span>
            <span className="font-mono">{checkResult.traces?.length || 0}</span>
          </div>

          <div className="space-y-2">
            {checkResult.traces?.map((trace: TrceFields) => {
              const isExpanded = expandedTrace === trace.id;
              const points = [
                { label: 'WHO', val: trace.who },
                { label: 'WHAT', val: trace.what },
                { label: 'WHERE', val: trace.where },
                { label: 'WHEN', val: trace.when },
                { label: 'WHY', val: trace.why },
                { label: 'HOW', val: trace.how },
              ];

              return (
                <div
                  key={trace.id}
                  className="rounded bg-rt-surface-0/60 border border-rt-surface-1 overflow-hidden"
                >
                  <div
                    onClick={() => setExpandedTrace(isExpanded ? null : trace.id)}
                    className="p-2 flex items-center justify-between hover:bg-rt-surface-0 cursor-pointer transition font-mono"
                  >
                    <div className="flex items-center space-x-1.5">
                      {isExpanded ? <ChevronDown className="w-3.5 h-3.5 text-rt-text-faint" /> : <ChevronRight className="w-3.5 h-3.5 text-rt-text-faint" />}
                      <span className="font-bold text-rt-teal">{trace.id}</span>
                    </div>

                    <div className="flex items-center space-x-1">
                      {trace.line && (
                        <span
                          onClick={(e) => {
                            e.stopPropagation();
                            onSelectLine(trace.line!);
                          }}
                          className="text-[10px] text-rt-text-faint hover:text-rt-text bg-rt-crust px-1.5 py-0.5 rounded cursor-pointer"
                        >
                          L{trace.line}
                        </span>
                      )}
                      {trace.is_valid ? (
                        <CheckCircle2 className="w-3.5 h-3.5 text-rt-green" />
                      ) : (
                        <AlertCircle className="w-3.5 h-3.5 text-rt-yellow" />
                      )}
                    </div>
                  </div>

                  {/* 6-Point Badges Indicator */}
                  <div className="px-2 pb-2 pt-0.5 flex flex-wrap gap-1">
                    {points.map((pt) => (
                      <span
                        key={pt.label}
                        className={`text-[9px] font-mono px-1 py-0.2 rounded font-medium ${
                          pt.val
                            ? 'bg-rt-green/15 text-rt-green'
                            : 'bg-rt-red/15 text-rt-red line-through'
                        }`}
                        title={pt.val ? `${pt.label}: ${pt.val}` : `${pt.label} missing!`}
                      >
                        {pt.label}
                      </span>
                    ))}
                  </div>

                  {/* Expanded 6-Point Details */}
                  {isExpanded && (
                    <div className="p-2.5 pt-1.5 bg-rt-crust/50 border-t border-rt-surface-1/60 space-y-1.5 text-[11px]">
                      {points.map((pt) => (
                        <div key={pt.label}>
                          <span className="font-bold font-mono text-rt-text-faint text-[10px] mr-1.5">
                            @{pt.label.toLowerCase()}:
                          </span>
                          <span className={pt.val ? 'text-rt-text-soft' : 'text-rt-red italic'}>
                            {pt.val || 'Missing field'}
                          </span>
                        </div>
                      ))}
                    </div>
                  )}
                </div>
              );
            })}
          </div>
        </div>
      </div>
    </div>
  );
};
