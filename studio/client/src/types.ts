/**
 * studio/client/src/types.ts -- Shared Type Definitions
 */

export interface ComponentItem {
  index: number;
  kind: string;
  name: string;
  archetype?: string;
  args?: string[];
  calls?: string[];
  line1: number;
  line2: number;
  code?: string;
  is_cli_runner?: boolean;
}

export interface ParseResult {
  file?: string;
  line_count: number;
  component_count: number;
  components: ComponentItem[];
  tokens_count: number;
  raw_lines?: string[];
}

export interface AnalyzeResult {
  file_type: string;
  archetype: string;
  imports: string[];
  functions: string[];
  component_count: number;
  components: ComponentItem[];
}

export interface TrceFields {
  id: string;
  who?: string;
  what?: string;
  where?: string;
  when?: string;
  why?: string;
  how?: string;
  line?: number;
  is_valid: boolean;
  missing_fields: string[];
}

export interface CheckResult {
  file_path: string;
  is_valid: boolean;
  coverage_pct: number;
  annotated_components: number;
  total_components: number;
  errors: string[];
  warnings: string[];
  traces: TrceFields[];
}

export interface AnnotateResult {
  original_lines: string[];
  annotated_lines: string[];
  annotated_text: string;
  inserted_count: number;
  components_annotated: number;
}

export interface PitfallTrap {
  line: number;
  trap: string;
  title: string;
  severity: 'warning' | 'error' | 'info';
  description: string;
  suggestion: string;
  code_snippet?: string;
}

export interface QuizQuestion {
  id: number;
  question: string;
  options: string[];
  correct_index: number;
  explanation: string;
  target_line?: number;
}

export interface ConsoleEntry {
  id: string;
  code: string;
  timestamp: string;
  output: string[];
  messages: string[];
  warnings: string[];
  error?: string | null;
  value_text?: string[];
  value_class?: string | null;
  value_length?: number | null;
  plot_file?: string | null;
}

export interface WorkspaceObject {
  name: string;
  type: string;
  class: string;
  size: string;
  preview: string;
}

export interface PlotItem {
  id: string;
  data_uri: string;
  timestamp: string;
}

export interface SampleScript {
  name: string;
  path: string;
  content: string;
  size: number;
}

export interface FileItem {
  name: string;
  path: string;
  relPath: string;
  isDirectory: boolean;
  isR: boolean;
  size: number;
}

export type ThemeMode = 'mocha' | 'latte';

export type SidebarTab = 'files' | 'ast' | 'trce' | 'pitfalls' | 'quiz';

export type RightRailTab = 'workspace' | 'plots' | 'help';
