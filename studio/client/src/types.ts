/**
 * studio/client/src/types.ts -- Shared Type Definitions
 */

export interface ComponentItem {
  index?: number;
  kind?: string;
  name: string;
  type?: string;
  archetype?: string;
  args?: string[];
  calls?: string[];
  calls_local?: string[];
  called_by?: string[];
  line1?: number;
  line2?: number;
  start_line?: number;
  end_line?: number;
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
  original_lines?: string[];
  annotated_lines?: string[];
  original_text?: string;
  annotated_text: string;
  inserted_count: number;
  components_annotated?: number;
  trace_ids?: string[];
}

export interface PitfallTrap {
  id?: string;
  line: number;
  trap?: string;
  name?: string;
  title: string;
  severity: 'warning' | 'error' | 'critical' | 'advisory' | 'info';
  description?: string;
  explanation?: string;
  suggestion?: string;
  recommendation?: string;
  code_snippet?: string;
  code?: string;
  replacement?: string;
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
  language?: string;
}

export interface FileItem {
  name: string;
  path: string;
  relPath: string;
  isDirectory: boolean;
  isR?: boolean;
  isPython?: boolean;
  isJs?: boolean;
  language?: string;
  size: number;
}

export interface RecentProject {
  path: string;
  name: string;
  lastOpened: string;
}

export interface ProjectMetadata {
  path: string;
  name: string;
  is_package: boolean;
  package_name: string | null;
  rproj_file: string | null;
  renviron_file: string | null;
  rprofile_file: string | null;
  r_files_count: number;
  r_files: string[];
}

export interface ProjectOverview {
  metadata: ProjectMetadata;
  validation: {
    total_files: number;
    total_targets: number;
    annotated_targets: number;
    coverage_pct: number;
    all_valid: boolean;
    duplicate_ids: string[];
    missing_fields_count: number;
  };
  explanation?: {
    text: string;
    markdown: string;
  };
}

export interface CurrentProjectInfo {
  path: string;
  name: string;
}

export type ThemeMode = 'mocha' | 'latte';

export type SidebarTab = 'files' | 'ast' | 'trce' | 'pitfalls' | 'quiz';

export type RightRailTab = 'workspace' | 'plots' | 'help';

