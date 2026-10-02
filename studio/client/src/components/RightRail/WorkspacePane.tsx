/**
 * studio/client/src/components/RightRail/WorkspacePane.tsx -- R Session Environment Variable Inspector
 */

import React from 'react';
import { Database, RefreshCw, Box } from 'lucide-react';
import { WorkspaceObject } from '../../types';
import { ensureArray } from '../../utils/array';

interface WorkspacePaneProps {
  objects: WorkspaceObject[];
  onRefresh: () => void;
  isLoading?: boolean;
}

export const WorkspacePane: React.FC<WorkspacePaneProps> = ({
  objects,
  onRefresh,
  isLoading = false
}) => {
  const objectList = ensureArray(objects);

  return (
    <div className="h-full flex flex-col bg-rt-mantle text-xs select-none">
      {/* Header */}
      <div className="h-9 px-3 border-b border-rt-surface-0 flex items-center justify-between font-semibold tracking-wider text-rt-text-soft uppercase text-[11px]">
        <div className="flex items-center space-x-1.5">
          <Database className="w-3.5 h-3.5 text-rt-teal" />
          <span>Workspace Environment</span>
        </div>
        <div className="flex items-center space-x-2">
          <span className="font-mono text-rt-teal font-bold">{objectList.length}</span>
          <button
            onClick={onRefresh}
            disabled={isLoading}
            className="p-1 rounded hover:bg-rt-surface-0 text-rt-text-faint hover:text-rt-text transition"
            title="Refresh Environment"
          >
            <RefreshCw className={`w-3 h-3 ${isLoading ? 'animate-spin' : ''}`} />
          </button>
        </div>
      </div>

      <div className="flex-1 overflow-y-auto p-2">
        {objectList.length === 0 ? (
          <div className="h-full flex flex-col items-center justify-center p-6 text-center text-xs text-rt-text-muted">
            <Box className="w-8 h-8 mb-2 opacity-30 text-rt-teal" />
            <p>Environment is empty.</p>
            <p className="mt-1 text-rt-text-faint text-[11px]">
              Variables and functions created in your session will appear here.
            </p>
          </div>
        ) : (
          <div className="space-y-1.5">
            {objects.map((obj) => (
              <div
                key={obj.name}
                className="p-2 rounded bg-rt-surface-0/60 border border-rt-surface-1 font-mono text-[11px] space-y-1"
              >
                <div className="flex items-center justify-between">
                  <span className="font-bold text-rt-mauve truncate">{obj.name}</span>
                  <span className="text-[10px] text-rt-text-faint">{obj.size}</span>
                </div>

                <div className="flex items-center space-x-2 text-[10px] text-rt-text-muted font-sans">
                  <span className="bg-rt-crust px-1.5 py-0.5 rounded text-rt-teal font-mono">
                    {obj.class || obj.type}
                  </span>
                  <span className="text-rt-text-faint truncate font-mono">
                    {obj.preview}
                  </span>
                </div>
              </div>
            ))}
          </div>
        )}
      </div>
    </div>
  );
};
