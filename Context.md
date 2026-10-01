# R-TRCE Code Assistant Context & Trace Index

This document maps all `@trce-rparse-*` annotations to their source files and locations across the R-TRCE Code Assistant codebase.

---

## 1. Monorepo Layout

```
R-TRCE Code Assistant/
├── AGENTS.md               # Agent instruction set, architecture invariants & rules
├── Context.md              # Trace index and architectural mapping (this file)
├── README.md               # User guide, quickstart, CLI reference, glossary
├── r_trce.R                # CLI executable router (parse, explain, tutor, pitfalls, quiz, annotate, check, export, studio, doctor)
├── app.R                   # Interactive Shiny studio
├── install.sh              # Linux/macOS auto-installer (creates `rtrce` + `rtrce-studio`)
├── install.ps1 / .bat      # Windows auto-installer (creates `rtrce.cmd` + `rtrce-studio.cmd`)
├── start_studio.sh / .bat  # Studio launchers
├── R/
│   ├── common.R            # Shared helpers: %||%, or_default(), get_script_dir(), annotatable-component
│   │                       # rule, trace-ID bookkeeping, encoding-tolerant file reading, and the
│   │                       # dependency manifest (required_packages / optional_packages)  [SOURCED FIRST]
│   ├── parser.R            # Core AST parsing and token extraction
│   ├── analyzer.R          # Semantic analyzer and archetype recognition
│   ├── annotator.R         # TRCE 6-point annotation generator and code injector
│   ├── validator.R         # Trace integrity and coverage auditing
│   ├── explain.R           # Plain text/Markdown explanation and JSON export
│   ├── pedagogy.R          # Student tutor, pitfall sentinel, pipe/formula deconstruction & quizzes
│   ├── runtime.R           # Live R session: evaluation, console capture, workspace and plots
│   ├── editor_ops.R        # Editable-document logic: statement at a cursor, line counting, console history
│   ├── studio_editor.R     # Studio pane: source editor bound to the working document (+ Run / Save)
│   ├── studio_console.R    # Studio pane: interactive console, transcript and session controls
│   └── studio_panes.R      # Studio panes: Files, Plots, Packages, Help + title bar and status bar chrome
├── www/                    # Vendored browser assets served by Shiny
│   ├── rtrce-theme.css     # The whole visual language: tokens (Catppuccin Mocha/Latte + Asterov gradient), shell, panes
│   ├── rtrce-editor.js     # CodeMirror <-> Shiny bridge (edit, run, history, gutter hints)
│   ├── rtrce-layout.js     # IDE shell behaviour: splitters, theme switch, shortcut sheet
│   ├── brand/              # The Asterov "A" monogram + favicon, copied from the design system
│   └── codemirror/         # CodeMirror 5.65.16 + R mode + addons (MIT; see its LICENSE)
└── tests/
    └── test_r_trce.R       # Automated test suite running against synthetic and real R scripts

Note: the Studio offers example scripts discovered from (in priority order) a sibling
"R Test" checkout, ./samples, ~/.r-trce-code-assistant/samples, then ~/.r-trce/samples.
Every root is optional.
```

---

## 2. TRCE Trace Index

The index is split in two. The **module-level** table records the original one-block-per-file
annotations, whose IDs are a stable telemetry namespace and must never be renumbered. The
**component-level** table records the per-function annotations, which use a per-module
namespace (`trce-<module>-NNN`) so IDs stay unique across the whole repository.

### 2.1 Module-level Trace Index (stable)

| Trace ID | Initiating Actor (`who`) | Action / Responsibility (`what`) | File Location (`where`) |
|----------|--------------------------|----------------------------------|-------------------------|
| `trce-rparse-001` | R-TRCE Code Assistant Engine / Parser Subsystem | Parses R source files into concrete syntax trees and token coordinates using base R AST tools | `R/parser.R` (`parse_r_file`) |
| `trce-rparse-002` | R-TRCE Code Assistant Engine / Lexical Subsystem | Extracts comment blocks and associates them with subsequent code expressions | `R/parser.R` (`extract_comments`, `extract_top_expressions`) |
| `trce-rparse-003` | R-TRCE Code Assistant Engine / Semantic Analysis | Analyzes parsed R AST structures to detect architectural patterns, functions, Shiny graphs, schemas, and pipelines | `R/analyzer.R` (`analyze_r_file`, `classify_expression`) |
| `trce-rparse-004` | R-TRCE Code Assistant Engine / Dependency Resolver | Resolves caller-callee relationships across all functions defined within the R file | `R/analyzer.R` (`resolve_dependencies`) |
| `trce-rparse-005` | R-TRCE Code Assistant Engine / Annotation Synthesizer | Synthesizes complete 6-point TRCE annotations tailored to R architectural archetypes | `R/annotator.R` (`generate_annotation`, `generate_file_header`) |
| `trce-rparse-006` | R-TRCE Code Assistant Engine / Code Injection Subsystem | Injects generated TRCE annotation blocks into R source code preserving syntax and formatting | `R/annotator.R` (`inject_annotations`) |
| `trce-rparse-007` | R-TRCE Code Assistant Engine / Validator Subsystem | Validates TRCE annotations for canonical pattern compliance, 6-field completeness, and coverage | `R/validator.R` (`validate_r_annotations`) |
| `trce-rparse-008` | R-TRCE Code Assistant Engine / Architectural Explainer | Generates plain-text and Markdown architectural explanations and TRCE context mappings for R files | `R/explain.R` (`explain_r_file`, `format_markdown_explanation`, `export_trace_json`) |
| `trce-rparse-009` | User / CLI Operator / Automated Agent | Main CLI command router and option parser for the R-TRCE Code Assistant toolchain | `r_trce.R` (`main`) |
| `trce-rparse-010` | Shiny Web Browser Client / Developer | Interactive Shiny UI and Server studio for AST inspection, architecture explanation, and TRCE annotation | `app.R` (`ui`, `server`) |
| `trce-rparse-011` | Test Suite Runner / CI Verifier | Automated test harness verifying AST parsing, semantic analysis, annotation injection, and trace validation | `tests/test_r_trce.R` (`run_all_tests`) |
| `trce-rparse-012` | R-TRCE Code Assistant Engine / Parser Subsystem | Maps AST expressions to line boundaries and associates preceding comment scaffolding | `R/parser.R` (`extract_top_expressions`) |
| `trce-rparse-013` | R-TRCE Code Assistant Engine / Pedagogical & Educational Subsystem | Deconstructs R ASTs into beginner-friendly explanations, audits student pitfalls, visualizes pipelines/formulas, and synthesizes quizzes | `R/pedagogy.R` (`detect_student_pitfalls`, `deconstruct_pipes`, `deconstruct_formulas`, `generate_student_explanation`, `generate_student_quiz`) |
| `trce-rparse-014` | R-TRCE Code Assistant Engine / Shared Infrastructure | Provides the canonical shared helpers used by every entry point: `%||%`, `or_default()`, `get_script_dir()`, the annotatable-component rule, trace-ID bookkeeping, the dependency manifest, and encoding-tolerant source reading | `R/common.R` (`%||%`, `get_script_dir`, `is_annotatable_component`, `select_annotatable_components`, `max_existing_trace_number`, `read_source_lines`, `required_packages`, `missing_packages`) |
| `trce-rparse-015` | R-TRCE Code Assistant Engine / Live Session Runtime | Evaluates user-submitted R code in a persistent environment and captures the console transcript, value types, warnings, errors and rendered plots | `R/runtime.R` (`new_r_session`, `session_evaluate`, `evaluate_with_capture`) |
| `trce-rparse-016` | R-TRCE Code Assistant Engine / Editor Operations | Resolves the code a "run this" gesture should execute and walks console history, without depending on shiny or the browser | `R/editor_ops.R` (`statement_code_at`, `history_step`, `count_lines`) |
| `trce-rparse-017` | R-TRCE Code Assistant Studio / Source Editor Pane | Two-way binding between the browser editor and the Studio's working document, plus Run / Run All / Save | `R/studio_editor.R` (`studio_editor_ui`, `studio_editor_server`) |
| `trce-rparse-018` | R-TRCE Code Assistant Studio / Console Pane | Interactive R console sharing the editor's live session, with command history, transcript and environment reporting | `R/studio_console.R` (`studio_console_ui`, `studio_console_server`) |
| `trce-rparse-019` | R-TRCE Code Assistant Studio / Workspace Panes | Files, Plots, Packages and Help panes plus the title-bar and status-bar chrome | `R/studio_panes.R` (`studio_files_pane_server`, `studio_plots_pane_server`, `studio_packages_pane_server`, `studio_help_pane_server`, `studio_chrome_server`) |
| `trce-rparse-022` | R-TRCE Code Assistant Engine / Headless Worker Daemon | Long-running persistent R process executing AST analysis and live session commands over a stdio JSON-RPC bridge | `studio/server/r_worker.R` (`worker_main`) |

### 2.2 Component-level Trace Index

| Trace ID | Component | Role | File (lines) |
|----------|-----------|------|--------------|
| `trce-worker-001` | `worker_get_root()` | utility_function | `studio/server/r_worker.R` |
| `trce-worker-002` | `with_temp_code_file()` | utility_function | `studio/server/r_worker.R` |
| `trce-worker-003` | `handle_worker_action()` | utility_function | `studio/server/r_worker.R` |
| `trce-worker-004` | `worker_main()` | utility_function | `studio/server/r_worker.R` |
| `trce-worker-005` | `interactive_guard()` | cli_entrypoint | `studio/server/r_worker.R` |
| `trce-cli-001` | `usage()` | cli_dispatcher | `r_trce.R` (L54-L112) |
| `trce-cli-002` | `run_doctor()` | utility_function | `r_trce.R` (L402-L480) |
| `trce-cli-003` | `interactive_guard()` | cli_entrypoint | `r_trce.R` (L491-L493) |
| `trce-studio-001` | `discover_sample_files()` | utility_function | `app.R` (L206-L227) |
| `trce-studio-002` | `ui()` | shiny_ui | `app.R` (L272-L518) |
| `trce-studio-003` | `server()` | shiny_server | `app.R` (L530-L1367) |
| `trce-studio-004` | `interactive_guard()` | cli_entrypoint | `app.R` (L1381-L1434) |
| `trce-studio-005` | `studio_bind_host()` | utility_function | `app.R` (L116-L125) |
| `trce-studio-006` | `register_studio_assets()` | utility_function | `app.R` (L146-L153) |
| `trce-studio-007` | `studio_asset_version()` | utility_function | `app.R` (L173-L182) |
| `trce-pane-001` | `studio_files_pane_server()` | shiny_server | `R/studio_panes.R` (L54-L172) |
| `trce-pane-002` | `studio_row_click()` | utility_function | `R/studio_panes.R` (L189-L192) |
| `trce-pane-003` | `studio_plots_pane_server()` | shiny_server | `R/studio_panes.R` (L237-L300) |
| `trce-pane-004` | `studio_packages_pane_server()` | shiny_server | `R/studio_panes.R` (L319-L401) |
| `trce-pane-005` | `studio_help_pane_server()` | shiny_server | `R/studio_panes.R` (L418-L473) |
| `trce-pane-006` | `studio_chrome_server()` | shiny_server | `R/studio_panes.R` (L493-L534) |
| `trce-pane-007` | `human_size()` | utility_function | `R/studio_panes.R` (L208-L218) |
| `trce-editor-001` | `statement_code_at()` | utility_function | `R/editor_ops.R` (L56-L100) |
| `trce-editor-002` | `history_step()` | utility_function | `R/editor_ops.R` (L148-L173) |
| `trce-editor-003` | `count_lines()` | utility_function | `R/editor_ops.R` (L121-L126) |
| `trce-ui-editor-001` | `studio_editor_ui()` | shiny_ui | `R/studio_editor.R` (L45-L90) |
| `trce-ui-editor-002` | `studio_editor_server()` | shiny_server | `R/studio_editor.R` (L112-L220) |
| `trce-ui-console-001` | `studio_console_ui()` | shiny_ui | `R/studio_console.R` (L46-L90) |
| `trce-ui-console-002` | `studio_console_server()` | shiny_server | `R/studio_console.R` (L110-L185) |
| `trce-common-001` | `or_default()` | utility_function | `R/common.R` (L52-L56) |
| `trce-common-002` | `get_script_dir()` | cli_dispatcher | `R/common.R` (L74-L82) |
| `trce-common-003` | `is_annotatable_component()` | utility_function | `R/common.R` (L103-L106) |
| `trce-common-004` | `select_annotatable_components()` | utility_function | `R/common.R` (L120-L124) |
| `trce-common-009` | `extract_trace_ids()` | utility_function | `R/common.R` (L146-L152) |
| `trce-common-005` | `max_existing_trace_number()` | utility_function | `R/common.R` (L165-L179) |
| `trce-common-006` | `leading_banner_lines()` | utility_function | `R/common.R` (L193-L199) |
| `trce-common-007` | `tidy_source_lines()` | utility_function | `R/common.R` (L216-L218) |
| `trce-common-008` | `read_source_lines()` | utility_function | `R/common.R` (L239-L265) |
| `trce-common-010` | `required_packages()` | utility_function | `R/common.R` (L288-L290) |
| `trce-common-011` | `optional_packages()` | utility_function | `R/common.R` (L303-L305) |
| `trce-common-012` | `missing_packages()` | utility_function | `R/common.R` (L318-L322) |
| `trce-analyzer-001` | `classify_expression()` | utility_function | `R/analyzer.R` (L81-L206) |
| `trce-analyzer-002` | `analyze_function_node()` | statistical_model | `R/analyzer.R` (L218-L275) |
| `trce-analyzer-003` | `extract_function_calls()` | utility_function | `R/analyzer.R` (L287-L303) |
| `trce-analyzer-004` | `detect_imports()` | utility_function | `R/analyzer.R` (L315-L330) |
| `trce-analyzer-005` | `parse_existing_trce()` | utility_function | `R/analyzer.R` (L381-L414) |
| `trce-analyzer-006` | `detect_file_archetype()` | utility_function | `R/analyzer.R` (L426-L446) |
| `trce-annotator-001` | `generate_file_header()` | utility_function | `R/annotator.R` (L41-L56) |
| `trce-annotator-002` | `determine_who()` | utility_function | `R/annotator.R` (L68-L86) |
| `trce-annotator-003` | `determine_what()` | utility_function | `R/annotator.R` (L98-L137) |
| `trce-annotator-004` | `determine_where()` | utility_function | `R/annotator.R` (L149-L168) |
| `trce-annotator-005` | `determine_when()` | utility_function | `R/annotator.R` (L180-L198) |
| `trce-annotator-006` | `determine_why()` | utility_function | `R/annotator.R` (L210-L248) |
| `trce-annotator-007` | `determine_how()` | utility_function | `R/annotator.R` (L260-L300) |
| `trce-annotator-008` | `format_trce_block()` | utility_function | `R/annotator.R` (L312-L337) |
| `trce-annotator-009` | `inject_single_block()` | utility_function | `R/annotator.R` (L451-L460) |
| `trce-validator-001` | `validate_r_annotations()` | data_pipeline | `R/validator.R` (L30-L122) |
| `trce-validator-002` | `extract_all_trce_blocks()` | utility_function | `R/validator.R` (L134-L204) |
| `trce-explain-001` | `format_text_explanation()` | utility_function | `R/explain.R` (L49-L106) |
| `trce-explain-002` | `format_markdown_explanation()` | utility_function | `R/explain.R` (L117-L194) |
| `trce-explain-003` | `export_trace_json()` | utility_function | `R/explain.R` (L206-L235) |
| `trce-pedagogy-001` | `deconstruct_pipes()` | utility_function | `R/pedagogy.R` (L206-L315) |
| `trce-pedagogy-002` | `describe_pipe_verb()` | utility_function | `R/pedagogy.R` (L326-L344) |
| `trce-pedagogy-003` | `deconstruct_formulas()` | statistical_model | `R/pedagogy.R` (L359-L396) |
| `trce-pedagogy-004` | `analyze_single_formula()` | utility_function | `R/pedagogy.R` (L407-L428) |
| `trce-pedagogy-005` | `package_primer()` | utility_function | `R/pedagogy.R` (L443-L466) |
| `trce-pedagogy-006` | `generate_student_explanation()` | utility_function | `R/pedagogy.R` (L481-L574) |
| `trce-pedagogy-007` | `generate_student_quiz()` | utility_function | `R/pedagogy.R` (L589-L675) |
| `trce-runtime-001` | `new_r_session()` | utility_function | `R/runtime.R` (L101-L119) |
| `trce-runtime-002` | `session_is_incomplete()` | utility_function | `R/runtime.R` (L194-L205) |
| `trce-runtime-003` | `preview_value()` | utility_function | `R/runtime.R` (L217-L234) |
| `trce-runtime-004` | `session_workspace()` | data_pipeline | `R/runtime.R` (L247-L269) |
| `trce-runtime-005` | `evaluate_with_capture()` | data_pipeline | `R/runtime.R` (L291-L402) |
| `trce-runtime-006` | `session_evaluate()` | data_pipeline | `R/runtime.R` (L420-L488) |
| `trce-runtime-007` | `session_set_wd()` | utility_function | `R/runtime.R` (L161-L174) |
| `trce-runtime-008` | `session_reset()` | utility_function | `R/runtime.R` (L132-L144) |
| `trce-runtime-009` | `format_console_entry()` | utility_function | `R/runtime.R` (L501-L512) |
| `trce-runtime-010` | `install_quit_guard()` | utility_function | `R/runtime.R` (L64-L80) | 

Coverage is 100% of annotatable components in every source file, verified by
`rtrce check <file>` and asserted by `tests/test_r_trce.R`.

---

## 3. Telemetry & Cross-System Routing

Every `@trce-*` tag, in either namespace, adheres to TRCE Go engine compatibility rules:
- Pattern: `^trce-[a-z0-9]+(?:-[a-z0-9]+)*-[0-9]+$`
- 6 Fields: `@trce-id`, `@trce-who`, `@trce-what`, `@trce-where`, `@trce-when`, `@trce-why`, `@trce-how`
- Comment style: `# /** ... */` (JSDoc format in R) or `#'` (Roxygen format)
- Compatible with TRCE daemon file watchers and `trce check` audits.

Two namespaces are in use:

| Namespace | Scope | Renumbering |
|-----------|-------|-------------|
| `trce-rparse-NNN` | Module-level blocks (§2.1), one per file | **Frozen.** These survive the product rename and must not be renumbered. |
| `trce-<module>-NNN` | Component-level blocks (§2.2) | Extended freely; each module owns its own counter, which keeps IDs unique across the repository. |

The canonical pattern is defined once, in `TRACE_ID_REGEX` (`R/common.R`), and shared by the
validator, the analyzer's existing-annotation reader and the ID extractors.

---

## 4. Rename & Hardening Pass (recorded)

The product was renamed from **R-TRCE** to **R-TRCE Code Assistant**. Deliberately unchanged
so existing telemetry and muscle memory keep working: the `trce-rparse-*` ID namespace, the
default annotation prefix `trce-r`, the entry filenames `r_trce.R` / `app.R`, and the Studio
port `8083`. New names: GitHub repo `AsterovLabs/R-TRCE-Code-Assistant`, commands `rtrce` /
`rtrce-studio` (legacy `r-trce` / `r-trce-studio` retained as aliases), install dir
`~/.r-trce-code-assistant` (falls back to an existing `~/.r-trce`), env var `RTRCE_HOME`
(falls back to `R_TRCE_HOME`).

Defects fixed in the same pass:

| Defect | Where | Fix |
|--------|-------|-----|
| Re-annotating a partly annotated file reused IDs, so `check` reported duplicate `@trce-id` | `R/annotator.R` | Counter seeded from `max_existing_trace_number()` (`trce-rparse-006`) |
| File header duplicated when a licence banner exceeded 25 lines | `R/annotator.R` | `leading_banner_lines()` scans the whole banner |
| Studio rendered a blank page on unreadable/unparseable files | `app.R` | `parsed_data()` records `load_error()`, rendered as a banner on every tab (`trce-rparse-010`) |
| Legacy cp1252 / Latin-1 files failed with `input string 1 is invalid UTF-8` | `R/common.R`, `R/parser.R` | `read_source_lines()` converts and reports (`trce-rparse-014`) |

| `%||%` silently required R >= 4.4 while the documented floor is 4.0 | `R/common.R` | Defined locally |
| Annotatable-component rule copy-pasted in five places | CLI, `R/common.R`, `R/validator.R`, `R/annotator.R`, `app.R` | Single definition in `R/common.R` |
| `p$file_path` overwritten with a bare filename | `app.R` | Real path preserved for validation and JSON export |
| `ast_expressions_table` unguarded on files with zero expressions | `app.R` | Empty-state guard added |
| Developer-only `/home/sam/.r-env/bin/Rscript` baked into launcher and docs | `start_studio.sh`, `README.md`, `AGENTS.md` | Resolved via `R_ENV` / `~/.r-env` / `command -v Rscript` |
| Sample discovery required a sibling folder named exactly `R Test` | `app.R` | Four optional roots |
| Child-annotation text had a double space after `Upstream:` / `Downstream:` | `R/annotator.R` | `paste0()` instead of `paste()` (`trce-annotator-004`) |
| A single-clause `@trce-how` began with a lower-case word | `R/annotator.R` | The joined clause list is sentence-cased (`trce-annotator-007`) |
| Prose mentioning `@trce-id` (e.g. a teaching note) shadowed the real ID in the analyzer | `R/analyzer.R`, `R/common.R` | `parse_existing_trce()` now requires the canonical pattern; `TRACE_ID_REGEX` centralised (`trce-analyzer-005`) |
| Pitfall Sentinel reported trap patterns that appeared inside comments | `R/pedagogy.R` | Comment lines are excluded from the pattern scans (`trce-rparse-013`) |
| `DT` was documented as a dependency that no installer ever installed, and the doctor hard-coded the package names it checked | `README.md`, `install.sh`, `install.ps1`, `rtrce doctor` | One manifest — `required_packages()` / `optional_packages()` / `missing_packages()` in `R/common.R` — read by the doctor and both installers, with a test that fails if either installer goes back to a private list (`trce-common-010` … `trce-common-012`) |

---

## 5. Self-Coverage & Bundled Examples

The tool documents itself, which is also how the defects above were found:

```bash
rtrce annotate <file> --inplace --no-header --prefix trce-<module>
```

Every source file reports **100% coverage** under `rtrce check`, and re-running `annotate`
adds zero blocks (idempotent). This is asserted by `tests/test_r_trce.R`, together with a
check that every ID present in source is indexed above.

`samples/` ships five example scripts — one per detected archetype plus a deliberately
"broken style" file that exercises all nine Pitfall Sentinel detectors — so a fresh install
has something to open in the Studio immediately. See `samples/README.md`.

---

## 6. Live Session & Editor (Phase 1, recorded)

The Studio could read, explain and document R code but never *run* it, which made it a report
about R rather than a place to work in R. Phase 1 adds the missing half.

| Piece | What it does | Trace IDs |
|-------|--------------|-----------|
| `R/runtime.R` | A dependency-free R session: evaluates submitted code, captures printed values, `cat()` output, messages, warnings, errors and plots, and reports the workspace | `trce-rparse-015`, `trce-runtime-001` … `-010` |
| `rtrce run <file>` | The same engine on the command line: prints the transcript, the workspace and where any plots were written | `trce-cli-003` route, `R/runtime.R` |
| `R/editor_ops.R` | The IDE-style decisions, kept testable: which statement a Ctrl+Enter should run, how long the document is, how Up/Down walk history | `trce-rparse-016`, `trce-editor-001` … `-003` |
| `R/studio_editor.R`, `R/studio_console.R` | The two panes: a CodeMirror editor bound to the working document, and a console sharing the same session | `trce-rparse-017`/`-018`, `trce-ui-editor-001`/`-002`, `trce-ui-console-001`/`-002` |
| `www/` | Vendored CodeMirror 5.65.16 (MIT) plus the Shiny bridge, so the Studio works offline with no new R package | — (not R source, so not covered by the trace index) |

Behavioural decisions worth remembering, each of which came from running real files rather than
from theory:

| Decision | Why |
|----------|-----|
| `quit()`/`q()` are shadowed in a hidden parent frame | One bundled sample ends a branch with `quit()`; unguarded it terminates the whole Studio process, taking every other session with it (`trce-runtime-010`) |
| Printing a `shiny.appobj` is refused with an explanation | `samples/01_shiny_app.R` ends with `shinyApp(ui, server)`, and printing that starts a server and blocks the host |
| Output is flushed by closing the sink before it is read | A line written without a trailing newline stays in the connection buffer, so `cat("x")` was silently dropped |
| Every evaluation runs under `setTimeLimit` | A runaway loop in the Studio would otherwise wedge the process (verified: 1 s budget interrupts in 1.05 s) |
| Plots are captured only when the display list proves something was drawn | Otherwise an untouched PNG device is presented as a plot |
| The Studio binds to `127.0.0.1` unless `HOST` / `RTRCE_ALLOW_REMOTE=1` is set | The page runs R code; remote access must be a deliberate, announced choice (`trce-studio-005`) |
| Custom-message handlers in `www/rtrce-editor.js` are registered through one helper | Shiny throws unless a handler takes exactly one argument, and that throw silently disabled every handler registered after it — the run highlight and gutter hints never fired |
| Assets are served with a `?v=<mtime>` token | A cached `rtrce-editor.js` after an upgrade is indistinguishable from a broken feature (`trce-studio-007`) |
| `count_lines()` rather than `strsplit()` | R drops a trailing empty field, so the status line disagreed with the editor's gutter by one line (`trce-editor-003`) |

---

## 7. Design Language (Phase 2, recorded)

The Studio follows the Asterov "A" icon. That is a contract, not a preference: this screen is
the first surface of what may become an agentic-first TRCE IDE, so it should look like Asterov
before it looks like anything else. The tokens live in `www/rtrce-theme.css` and nowhere else.

| Token group | Values |
|-------------|--------|
| Surfaces (dark = Mocha) | `--rt-crust #11111b`, `--rt-mantle #181825`, `--rt-base #1e1e2e`, `--rt-surface-0/1/2` |
| Surfaces (light = Latte) | `--rt-base #eff1f5` and friends, switched by `[data-rtrce-theme="latte"]` on `<html>` |
| Accents | mauve `#cba6f7`, blue `#89b4fa`, teal `#94e2d5`, green `#a6e3a1`, yellow `#f9e2af`, peach `#fab387`, red `#f38ba8` |
| Signature | `--rt-grad: linear-gradient(135deg, #cba6f7, #89b4fa, #94e2d5)` -- the icon's own stroke |
| Type | Inter (UI), JetBrains Mono (code, numerics, status), Cinzel reserved for the wider suite |
| Shape | radii 6 / 10 / 16 px, soft glows (`--rt-glow`), gradients only as accents or hairlines |

Rules that follow from it:

1. **Every colour comes from a token.** No literal hex in R or in component CSS; the theme is the
   only place a colour is named. Both themes are checked for WCAG contrast (body 11.3:1,
   secondary 7.4:1, accents 7-13:1 on dark).
2. **The gradient is an accent, never a surface.** It appears on the wordmark, the primary action,
   a 1px hairline under the title bar, and as a soft wash behind the empty states.
3. **Teaching surfaces are mauve.** `.rtrce-teach` exists so that an explanation never looks like
   an error and an error never looks like an explanation.
4. **The theme stylesheet loads last and is scoped** (`.rtrce-app .CodeMirror`). CodeMirror's own
   CSS sets an editor background at equal specificity, so a theme that relies on source order
   alone renders a white editor -- which is what happened before this was fixed.
5. **Fonts are named, never downloaded.** No CDN, no bundled font files: offline use is a feature.
6. **Layout metrics are shared with the splitter script.** `--rt-bottom-h` and `--rt-rail-w` are
   read and written by both `www/rtrce-layout.js` and the R defaults, so a drag cannot disagree
   with a default.

The panes themselves follow RStudio's mental model, because familiarity is the point: source
above console on the left, Environment / Files / Plots / Packages / Help in the right rail, the
editor and console sharing one session, and the analysis views (walkthrough, annotations,
explanation, AST, student studio) as tabs of the bottom panel rather than replacements for it.

| Piece | What it does | Trace IDs |
|-------|--------------|-----------|
| Title bar | Asterov mark, document chip, live session pill, theme switch, shortcut sheet | `trce-rparse-019`, `trce-pane-006` |
| Status bar | Working directory, cursor line, object and command counts, TRCE coverage, R version | `trce-pane-006` |
| Files pane | Browse, open text files into the editor, change the session working directory | `trce-pane-001`, `trce-pane-002`, `trce-pane-007` |
| Plots pane | The newest captured plot, its history, and a full-size link | `trce-pane-003` |
| Packages pane | What is installed, what this file imports, and what the tool requires | `trce-pane-004` |
| Help pane | Shortcuts, the six questions, the vocabulary, how the panes fit together | `trce-pane-005` |
| Splitters, theme, shortcuts | `www/rtrce-layout.js` -- browser-only, remembered in localStorage | -- |

| `trce-rparse-020` | `teach.R` module | teaching_subsystem | `R/teach.R` |
| `trce-teach-001` | `concept_tags_for_lines()` | utility_function | `R/teach.R` |
| `trce-teach-002` | `explain_code_line()` | utility_function | `R/teach.R` |
| `trce-teach-005` | `TEACH_ERRORS` | data_schema | `R/teach.R` |
| `trce-teach-003` | `explain_r_error()` | utility_function | `R/teach.R` |
| `trce-teach-004` | `describe_run()` | utility_function | `R/teach.R` |
| `trce-rparse-021` | `studio_learn_pane_server()` | shiny_server | `R/studio_learn.R` |
