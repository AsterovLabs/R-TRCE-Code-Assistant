/**
 * studio/client/src/components/ProjectOverviewModal.tsx -- Project-Level Health & Architecture Inspector
 */

import React from 'react';
import {
  FolderGit2,
  Package,
  FileCode,
  ShieldCheck,
  AlertTriangle,
  FileCheck2,
  CheckCircle2,
  X,
  RefreshCw,
  FolderTree
} from 'lucide-react';
import { ProjectOverview } from '../types';

interface ProjectOverviewModalProps {
  isOpen: boolean;
  overview: ProjectOverview | null;
  loading: boolean;
  onRefresh: () => void;
  onClose: () => void;
}

export const ProjectOverviewModal: React.FC<ProjectOverviewModalProps> = ({
  isOpen,
  overview,
  loading,
  onRefresh,
  onClose
}) => {
  if (!isOpen) return null;

  const meta = overview?.metadata;
  const val = overview?.validation;

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/60 backdrop-blur-sm p-4">
      <div className="w-full max-w-3xl max-h-[85vh] bg-rt-mantle border border-rt-surface-1 rounded-xl shadow-2xl flex flex-col overflow-hidden animate-in fade-in zoom-in-95 duration-150">
        {/* Header */}
        <div className="h-14 px-5 border-b border-rt-surface-0 flex items-center justify-between bg-rt-crust select-none">
          <div className="flex items-center space-x-3">
            <div className="p-2 rounded-lg bg-rt-mauve/15 text-rt-mauve">
              <FolderGit2 className="w-5 h-5" />
            </div>
            <div>
              <div className="flex items-center space-x-2">
                <h3 className="font-bold text-sm text-rt-text">{meta?.name || 'Project Overview'}</h3>
                {val && (
                  <span
                    className={`text-xs px-2 py-0.5 rounded-full font-mono font-bold ${
                      val.coverage_pct >= 90
                        ? 'bg-rt-green/20 text-rt-green'
                        : val.coverage_pct >= 50
                        ? 'bg-rt-peach/20 text-rt-peach'
                        : 'bg-rt-red/20 text-rt-red'
                    }`}
                  >
                    {val.coverage_pct.toFixed(1)}% Coverage
                  </span>
                )}
              </div>
              <p className="text-xs text-rt-text-faint font-mono truncate max-w-md">
                {meta?.path}
              </p>
            </div>
          </div>
          <div className="flex items-center space-x-2">
            <button
              onClick={onRefresh}
              disabled={loading}
              className="p-1.5 rounded-lg text-rt-text-faint hover:text-rt-text hover:bg-rt-surface-0 transition"
              title="Refresh project metrics"
            >
              <RefreshCw className={`w-4 h-4 ${loading ? 'animate-spin' : ''}`} />
            </button>
            <button
              onClick={onClose}
              className="p-1.5 rounded-lg text-rt-text-faint hover:text-rt-text hover:bg-rt-surface-0 transition"
            >
              <X className="w-5 h-5" />
            </button>
          </div>
        </div>

        {/* Content */}
        <div className="flex-1 overflow-y-auto p-5 space-y-5">
          {loading && !overview ? (
            <div className="h-48 flex items-center justify-center text-rt-text-faint text-xs">
              <RefreshCw className="w-5 h-5 animate-spin mr-2 text-rt-mauve" />
              <span>Analyzing project structure & traces...</span>
            </div>
          ) : (
            <>
              {/* Stat Cards */}
              <div className="grid grid-cols-2 sm:grid-cols-4 gap-3">
                <div className="p-3 rounded-lg bg-rt-surface-0/60 border border-rt-surface-1">
                  <div className="flex items-center space-x-2 text-rt-blue text-xs font-semibold mb-1">
                    <FileCode className="w-4 h-4" />
                    <span>R Files</span>
                  </div>
                  <div className="text-lg font-mono font-bold text-rt-text">
                    {meta?.r_files_count || 0}
                  </div>
                  <div className="text-[10px] text-rt-text-faint">
                    Tracked in directory
                  </div>
                </div>

                <div className="p-3 rounded-lg bg-rt-surface-0/60 border border-rt-surface-1">
                  <div className="flex items-center space-x-2 text-rt-teal text-xs font-semibold mb-1">
                    <ShieldCheck className="w-4 h-4" />
                    <span>TRCE Coverage</span>
                  </div>
                  <div className="text-lg font-mono font-bold text-rt-teal">
                    {val?.coverage_pct ? `${val.coverage_pct.toFixed(0)}%` : '0%'}
                  </div>
                  <div className="text-[10px] text-rt-text-faint">
                    {val?.annotated_targets || 0} of {val?.total_targets || 0} components
                  </div>
                </div>

                <div className="p-3 rounded-lg bg-rt-surface-0/60 border border-rt-surface-1">
                  <div className="flex items-center space-x-2 text-rt-mauve text-xs font-semibold mb-1">
                    <Package className="w-4 h-4" />
                    <span>Archetype</span>
                  </div>
                  <div className="text-sm font-semibold text-rt-text truncate mt-1">
                    {meta?.is_package ? meta.package_name || 'R Package' : 'R Script Suite'}
                  </div>
                  <div className="text-[10px] text-rt-text-faint">
                    {meta?.rproj_file ? 'RStudio Project' : 'Standard Directory'}
                  </div>
                </div>

                <div className="p-3 rounded-lg bg-rt-surface-0/60 border border-rt-surface-1">
                  <div className="flex items-center space-x-2 text-rt-peach text-xs font-semibold mb-1">
                    <FolderTree className="w-4 h-4" />
                    <span>Config Hooks</span>
                  </div>
                  <div className="text-xs font-mono text-rt-text mt-1 space-y-0.5">
                    <div className={meta?.rprofile_file ? 'text-rt-green' : 'text-rt-text-faint'}>
                      {meta?.rprofile_file ? '✓ .Rprofile' : '– .Rprofile'}
                    </div>
                    <div className={meta?.renviron_file ? 'text-rt-green' : 'text-rt-text-faint'}>
                      {meta?.renviron_file ? '✓ .Renviron' : '– .Renviron'}
                    </div>
                  </div>
                </div>
              </div>

              {/* Duplicate Trace Warnings */}
              {val?.duplicate_ids && val.duplicate_ids.length > 0 && (
                <div className="p-3 rounded-lg bg-rt-red/10 border border-rt-red/30 space-y-1">
                  <div className="flex items-center space-x-2 text-xs font-bold text-rt-red">
                    <AlertTriangle className="w-4 h-4 flex-shrink-0" />
                    <span>Duplicate @trce-id values found across project files:</span>
                  </div>
                  <div className="flex flex-wrap gap-1.5 pt-1">
                    {val.duplicate_ids.map((id) => (
                      <span key={id} className="px-2 py-0.5 rounded bg-rt-red/20 text-rt-red font-mono text-[11px]">
                        {id}
                      </span>
                    ))}
                  </div>
                </div>
              )}

              {/* R Files List */}
              <div className="space-y-2">
                <div className="flex items-center justify-between text-xs font-semibold text-rt-text-soft">
                  <span>Project R Files ({meta?.r_files?.length || 0})</span>
                </div>
                <div className="max-h-48 overflow-y-auto space-y-1 rounded-lg border border-rt-surface-0 bg-rt-surface-0/30 p-2">
                  {(meta?.r_files || []).map((file) => (
                    <div
                      key={file}
                      className="flex items-center space-x-2 px-2 py-1 rounded text-xs font-mono text-rt-text-soft hover:bg-rt-surface-0"
                    >
                      <FileCode className="w-3.5 h-3.5 text-rt-blue flex-shrink-0" />
                      <span className="truncate">{file}</span>
                    </div>
                  ))}
                  {(!meta?.r_files || meta.r_files.length === 0) && (
                    <div className="text-center py-4 text-xs text-rt-text-faint">
                      No .R files detected in this directory yet.
                    </div>
                  )}
                </div>
              </div>

              {/* Architectural Explanation */}
              {overview?.explanation?.text && (
                <div className="space-y-2">
                  <div className="text-xs font-semibold text-rt-text-soft">
                    Architectural Narrative & Dependency Breakdown
                  </div>
                  <pre className="p-3 rounded-lg bg-rt-surface-0/60 border border-rt-surface-1 text-[11px] font-mono text-rt-text whitespace-pre-wrap max-h-56 overflow-y-auto leading-relaxed">
                    {overview.explanation.text}
                  </pre>
                </div>
              )}
            </>
          )}
        </div>

        {/* Footer */}
        <div className="h-12 px-5 border-t border-rt-surface-0 flex items-center justify-end bg-rt-crust">
          <button
            onClick={onClose}
            className="px-4 py-1.5 rounded-lg text-xs font-medium bg-rt-surface-0 hover:bg-rt-surface-1 text-rt-text transition"
          >
            Done
          </button>
        </div>
      </div>
    </div>
  );
};
