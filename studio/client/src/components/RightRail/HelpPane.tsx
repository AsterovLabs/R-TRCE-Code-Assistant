/**
 * studio/client/src/components/RightRail/HelpPane.tsx -- Quick R & TRCE Reference Pane
 */

import React, { useState } from 'react';
import { HelpCircle, BookOpen, ExternalLink, Code2 } from 'lucide-react';

export const HelpPane: React.FC = () => {
  const [activeTab, setActiveTab] = useState<'trce' | 'pipes' | 'base'>('trce');

  return (
    <div className="h-full flex flex-col bg-rt-mantle text-xs select-none">
      {/* Header */}
      <div className="h-9 px-3 border-b border-rt-surface-0 flex items-center justify-between font-semibold tracking-wider text-rt-text-soft uppercase text-[11px]">
        <div className="flex items-center space-x-1.5">
          <BookOpen className="w-3.5 h-3.5 text-rt-yellow" />
          <span>Documentation & Help</span>
        </div>
      </div>

      {/* Mini Tabs */}
      <div className="flex border-b border-rt-surface-0 text-[11px] font-semibold bg-rt-crust/50">
        <button
          onClick={() => setActiveTab('trce')}
          className={`flex-1 py-1.5 text-center transition ${
            activeTab === 'trce' ? 'border-b-2 border-rt-mauve text-rt-mauve' : 'text-rt-text-faint hover:text-rt-text'
          }`}
        >
          TRCE Standard
        </button>
        <button
          onClick={() => setActiveTab('pipes')}
          className={`flex-1 py-1.5 text-center transition ${
            activeTab === 'pipes' ? 'border-b-2 border-rt-mauve text-rt-mauve' : 'text-rt-text-faint hover:text-rt-text'
          }`}
        >
          Pipes & Formulas
        </button>
        <button
          onClick={() => setActiveTab('base')}
          className={`flex-1 py-1.5 text-center transition ${
            activeTab === 'base' ? 'border-b-2 border-rt-mauve text-rt-mauve' : 'text-rt-text-faint hover:text-rt-text'
          }`}
        >
          Key Shortcuts
        </button>
      </div>

      <div className="flex-1 overflow-y-auto p-3 space-y-3 font-sans leading-relaxed text-rt-text-soft">
        {activeTab === 'trce' && (
          <div className="space-y-3 text-[11px]">
            <div>
              <span className="font-bold text-rt-teal">The 6-Point TRCE Standard:</span>
              <p className="mt-1 text-rt-text-faint">
                Every functional component documents who, what, where, when, why, and how to maintain agentic continuity.
              </p>
            </div>

            <div className="p-2.5 rounded bg-rt-crust border border-rt-surface-1 font-mono text-[10px] space-y-1 text-rt-text-muted">
              <div><span className="text-rt-mauve font-bold">@trce-id</span> trce-&lt;namespace&gt;-&lt;NNN&gt;</div>
              <div><span className="text-rt-blue font-bold">@trce-who</span> Initiating actor / system component</div>
              <div><span className="text-rt-teal font-bold">@trce-what</span> Concrete mechanical action</div>
              <div><span className="text-rt-green font-bold">@trce-where</span> Position in system &amp; call dependencies</div>
              <div><span className="text-rt-yellow font-bold">@trce-when</span> Lifecycle hook, event trigger</div>
              <div><span className="text-rt-peach font-bold">@trce-why</span> Architectural intent or business rule</div>
              <div><span className="text-rt-maroon font-bold">@trce-how</span> Structural implementation &amp; state mutations</div>
            </div>

            <div>
              <span className="font-bold text-rt-mauve">100% Coverage Invariant:</span>
              <p className="mt-1 text-rt-text-faint">
                The test suite asserts that every source file maintains 100% coverage and that all trace IDs are globally unique and indexed in Context.md.
              </p>
            </div>
          </div>
        )}

        {activeTab === 'pipes' && (
          <div className="space-y-3 text-[11px]">
            <div>
              <span className="font-bold text-rt-blue">Base Pipe <code className="text-rt-mauve font-mono">|&gt;</code> (R &gt;= 4.1):</span>
              <p className="mt-1 text-rt-text-faint">
                Passes the left-hand side as the first argument to the right-hand function call.
              </p>
              <div className="p-2 rounded bg-rt-crust font-mono text-[10px] mt-1 text-rt-text">
                mtcars |&gt; subset(cyl == 4) |&gt; head()
              </div>
            </div>

            <div>
              <span className="font-bold text-rt-teal">Formula Notation <code className="text-rt-mauve font-mono">y ~ x1 + x2</code>:</span>
              <p className="mt-1 text-rt-text-faint">
                Defines symbolic models for statistical estimation (lm, aov, glm).
              </p>
              <div className="p-2 rounded bg-rt-crust font-mono text-[10px] mt-1 text-rt-text">
                model &lt;- lm(mpg ~ wt + hp, data = mtcars)
              </div>
            </div>
          </div>
        )}

        {activeTab === 'base' && (
          <div className="space-y-2 text-[11px]">
            <div className="font-bold text-rt-text">Editor Shortcuts:</div>
            <div className="space-y-1.5 font-mono text-[10px]">
              <div className="flex justify-between p-1.5 rounded bg-rt-crust">
                <span className="text-rt-text-soft">Run Selection / Line</span>
                <span className="text-rt-teal font-bold">Ctrl + Enter</span>
              </div>
              <div className="flex justify-between p-1.5 rounded bg-rt-crust">
                <span className="text-rt-text-soft">Save Document</span>
                <span className="text-rt-teal font-bold">Ctrl + S</span>
              </div>
              <div className="flex justify-between p-1.5 rounded bg-rt-crust">
                <span className="text-rt-text-soft">Console History Prev</span>
                <span className="text-rt-teal font-bold">Up Arrow</span>
              </div>
              <div className="flex justify-between p-1.5 rounded bg-rt-crust">
                <span className="text-rt-text-soft">Console History Next</span>
                <span className="text-rt-teal font-bold">Down Arrow</span>
              </div>
            </div>
          </div>
        )}
      </div>
    </div>
  );
};
