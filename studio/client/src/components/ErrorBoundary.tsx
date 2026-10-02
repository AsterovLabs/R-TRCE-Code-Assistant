/**
 * studio/client/src/components/ErrorBoundary.tsx -- Component Fault Isolation & Recovery
 */

import React, { Component, ErrorInfo, ReactNode } from 'react';
import { AlertCircle, RotateCcw } from 'lucide-react';

interface Props {
  children: ReactNode;
  fallbackTitle?: string;
  onReset?: () => void;
}

interface State {
  hasError: boolean;
  error: Error | null;
}

export class ErrorBoundary extends Component<Props, State> {
  public state: State = {
    hasError: false,
    error: null
  };

  public static getDerivedStateFromError(error: Error): State {
    return { hasError: true, error };
  }

  public componentDidCatch(error: Error, errorInfo: ErrorInfo) {
    console.error('[R-TRCE ErrorBoundary] Component error caught:', error, errorInfo);
  }

  private handleReset = () => {
    this.setState({ hasError: false, error: null });
    if (this.props.onReset) {
      this.props.onReset();
    }
  };

  public render() {
    if (this.state.hasError) {
      return (
        <div className="h-full w-full flex flex-col items-center justify-center p-6 bg-rt-mantle text-xs select-none">
          <div className="max-w-md w-full p-4 rounded-xl bg-rt-crust border border-rt-surface-1 shadow-lg text-center space-y-3">
            <div className="w-10 h-10 rounded-full bg-rt-red/15 text-rt-red flex items-center justify-center mx-auto">
              <AlertCircle className="w-5 h-5" />
            </div>
            
            <div>
              <h3 className="font-semibold text-rt-text text-sm">
                {this.props.fallbackTitle || 'Component Error'}
              </h3>
              <p className="mt-1 text-[11px] text-rt-text-muted font-mono leading-relaxed break-words bg-rt-surface-0/60 p-2 rounded border border-rt-surface-1 text-left">
                {this.state.error?.message || 'An unexpected rendering error occurred.'}
              </p>
            </div>

            <button
              onClick={this.handleReset}
              className="inline-flex items-center space-x-1.5 px-3 py-1.5 rounded-lg bg-rt-surface-0 hover:bg-rt-surface-1 text-rt-mauve font-semibold text-xs transition border border-rt-surface-2 active:scale-95"
            >
              <RotateCcw className="w-3.5 h-3.5" />
              <span>Retry Component</span>
            </button>
          </div>
        </div>
      );
    }

    return this.props.children;
  }
}
