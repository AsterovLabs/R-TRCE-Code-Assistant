/**
 * studio/client/src/components/RightRail/PlotsPane.tsx -- Interactive Plot Graphics Gallery
 */

import React, { useState } from 'react';
import { Image as ImageIcon, Download, Maximize2, Trash2, X } from 'lucide-react';
import { PlotItem } from '../../types';

interface PlotsPaneProps {
  plots: PlotItem[];
  onClearPlots?: () => void;
}

export const PlotsPane: React.FC<PlotsPaneProps> = ({ plots, onClearPlots }) => {
  const [activePlot, setActivePlot] = useState<PlotItem | null>(null);

  const handleDownload = (plot: PlotItem) => {
    const a = document.createElement('a');
    a.href = plot.data_uri;
    a.download = `r-plot-${plot.id || Date.now()}.png`;
    a.click();
  };

  return (
    <div className="h-full flex flex-col bg-rt-mantle text-xs select-none">
      {/* Header */}
      <div className="h-9 px-3 border-b border-rt-surface-0 flex items-center justify-between font-semibold tracking-wider text-rt-text-soft uppercase text-[11px]">
        <div className="flex items-center space-x-1.5">
          <ImageIcon className="w-3.5 h-3.5 text-rt-blue" />
          <span>Plots Gallery</span>
        </div>
        <div className="flex items-center space-x-1">
          <span className="font-mono text-rt-mauve font-bold">{plots.length}</span>
          {plots.length > 0 && onClearPlots && (
            <button
              onClick={onClearPlots}
              className="p-1 rounded hover:bg-rt-surface-0 text-rt-text-faint hover:text-rt-text transition"
              title="Clear Plots"
            >
              <Trash2 className="w-3 h-3" />
            </button>
          )}
        </div>
      </div>

      <div className="flex-1 overflow-y-auto p-3 space-y-3">
        {plots.length === 0 ? (
          <div className="h-full flex flex-col items-center justify-center p-6 text-center text-xs text-rt-text-muted">
            <ImageIcon className="w-8 h-8 mb-2 opacity-30 text-rt-blue" />
            <p>No plots rendered yet.</p>
            <p className="mt-1 text-rt-text-faint text-[11px]">
              Try running <code className="text-rt-teal font-mono">plot(cars)</code> in the console or editor!
            </p>
          </div>
        ) : (
          plots.map((plot, idx) => (
            <div
              key={plot.id || idx}
              className="p-2 rounded-lg bg-rt-surface-0/60 border border-rt-surface-1 group relative overflow-hidden"
            >
              <div className="flex items-center justify-between mb-1.5 text-[10px] text-rt-text-faint font-mono">
                <span>Plot #{idx + 1}</span>
                <div className="flex items-center space-x-1">
                  <button
                    onClick={() => setActivePlot(plot)}
                    className="p-1 rounded hover:bg-rt-surface-1 text-rt-text-muted hover:text-rt-text transition"
                    title="Zoom in"
                  >
                    <Maximize2 className="w-3 h-3" />
                  </button>
                  <button
                    onClick={() => handleDownload(plot)}
                    className="p-1 rounded hover:bg-rt-surface-1 text-rt-text-muted hover:text-rt-text transition"
                    title="Download PNG"
                  >
                    <Download className="w-3 h-3" />
                  </button>
                </div>
              </div>

              <div
                onClick={() => setActivePlot(plot)}
                className="w-full bg-white rounded cursor-pointer overflow-hidden aspect-[4/3] flex items-center justify-center"
              >
                <img
                  src={plot.data_uri}
                  alt={`Plot ${idx + 1}`}
                  className="w-full h-full object-contain"
                />
              </div>
            </div>
          ))
        )}
      </div>

      {/* Zoom Modal */}
      {activePlot && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/80 p-4">
          <div className="max-w-4xl max-h-[90vh] bg-rt-crust border border-rt-surface-1 rounded-xl p-4 flex flex-col relative shadow-2xl">
            <div className="flex justify-between items-center mb-3">
              <span className="font-mono text-xs text-rt-text-soft font-semibold">
                Plot Preview: {activePlot.id}
              </span>
              <div className="flex items-center space-x-2">
                <button
                  onClick={() => handleDownload(activePlot)}
                  className="px-2.5 py-1 rounded bg-rt-surface-0 hover:bg-rt-surface-1 text-rt-teal text-xs flex items-center space-x-1"
                >
                  <Download className="w-3.5 h-3.5" />
                  <span>Download</span>
                </button>
                <button
                  onClick={() => setActivePlot(null)}
                  className="p-1.5 rounded hover:bg-rt-surface-0 text-rt-text-faint hover:text-rt-text"
                >
                  <X className="w-5 h-5" />
                </button>
              </div>
            </div>
            <div className="flex-1 bg-white rounded overflow-hidden flex items-center justify-center p-2">
              <img
                src={activePlot.data_uri}
                alt="Enlarged Plot"
                className="max-h-[75vh] w-auto object-contain"
              />
            </div>
          </div>
        </div>
      )}
    </div>
  );
};
