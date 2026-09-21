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
│   └── pedagogy.R          # Student tutor, pitfall sentinel, pipe/formula deconstruction & quizzes
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

### 2.2 Component-level Trace Index

| Trace ID | Component | Role | File (lines) |
|----------|-----------|------|--------------|
| `trce-cli-001` | `usage()` | cli_dispatcher | `r_trce.R` (L54-L112) |
| `trce-cli-002` | `run_doctor()` | utility_function | `r_trce.R` (L402-L480) |
| `trce-cli-003` | `interactive_guard()` | cli_entrypoint | `r_trce.R` (L491-L493) |
| `trce-studio-001` | `discover_sample_files()` | utility_function | `app.R` (L114-L135) |
| `trce-studio-002` | `ui()` | shiny_ui | `app.R` (L180-L343) |
| `trce-studio-003` | `server()` | shiny_server | `app.R` (L355-L1047) |
| `trce-studio-004` | `interactive_guard()` | cli_entrypoint | `app.R` (L1061-L1098) |
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

