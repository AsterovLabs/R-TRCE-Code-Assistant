# R-TRCE Code Assistant — Agent Instruction Set

R-TRCE Code Assistant is an architectural analysis, AST comprehension, and TRCE annotation engine specifically designed for R language projects. It extracts semantic intent from R scripts, maps internal and external dependency graphs, and generates complete 6-point TRCE telemetry doc-comments (`@trce-*`).

---

## 1. Architecture

| Component | Location | Purpose |
|-----------|----------|---------|
| CLI Entrypoint | `r_trce.R` | Subcommand router (`parse`, `explain`, `tutor`, `pitfalls`, `quiz`, `teach`, `annotate`, `check`, `export-traces`, `studio`, `doctor`) |
| Native Desktop Studio Shell | `studio/server/electron-main.js` | Electron desktop container, native menus, single-instance lock, no-sandbox configuration |
| Studio Backend Daemon | `studio/server/index.js` | Express & WebSocket daemon providing file I/O, dialog bridges, terminal runners, and worker process lifecycle |
| Studio Headless R Worker | `studio/server/r_worker.R` | Persistent R background process communicating over JSON-RPC stdio for sub-10ms AST analysis, TRCE synthesis, and live execution |
| Studio React Workbench | `studio/client/` | React 18 + Monaco Editor workbench with Asterov Catppuccin theme, interactive REPL, AST & telemetry badges, and Cassie tutor |
| **Shared Helpers** | **`R/common.R`** | **Sourced first by every entry point. Owns `%||%`, `or_default()`, `get_script_dir()`, the annotatable-component rule, trace-ID bookkeeping, the dependency manifest (`required_packages()`, `optional_packages()`, `missing_packages()`) and encoding-tolerant file reading. Never duplicate any of these elsewhere.** |
| Core AST Parser | `R/parser.R` | AST extraction, token mapping, and comment association using base R `parse()` & `getParseData()` |
| Semantic Analyzer | `R/analyzer.R` | Archetype detection (CLI tools, Shiny reactive graphs, snowflake schemas, ANOVA models), call graph |
| Annotation Synthesizer | `R/annotator.R` | 6-point TRCE metadata formulation and non-destructive code injection engine |
| Trace Validator | `R/validator.R` | Audits pattern compliance (`^trce-[a-z0-9]+(?:-[a-z0-9]+)*-[0-9]+$`), 6-field completeness, and coverage |
| Explainer & Exporter | `R/explain.R` | Generates plain text/Markdown architectural narratives and TRCE JSON export |
| Pedagogical Subsystem | `R/pedagogy.R` | Student tutor, pitfall sentinel, pipe/formula deconstruction & comprehension quizzes |
| Teaching Engine | `R/teach.R` | Line-by-line explanation, error decoder, concept tagger, and pedagogical telemetry |
| **Live Session Runtime** | **`R/runtime.R`** | **Dependency-free R session: evaluates submitted code, captures console output/messages/warnings/errors, reports workspace objects, and stores plots. Drives both the Studio daemon and `rtrce run`.** |
| Editor Operations | `R/editor_ops.R` | IDE decisions kept testable: statement at a cursor, line counting, console history |
| Bundled Examples | `samples/` | Five example scripts: one per detected archetype plus a deliberate "student traps" file that exercises all nine pitfall detectors |
| Automated Test Suite | `tests/test_r_trce.R` | Functional verification across synthetic cases, the bundled samples, and the real-world R Test corpus |

**Language Environment:** R (version >= 4.0.0, default: `Rscript`), Node.js (version >= 18 for Studio build), Electron 44+.
**External R Dependencies:** Standard R library + `jsonlite`.

### 1.1 Invariants agents must preserve

1. **One annotatable-component rule.** `is_annotatable_component()` / `select_annotatable_components()` in `R/common.R` are the only definitions. The CLI, validator, annotator and Studio all call them, which is what keeps reported coverage identical across interfaces.
2. **Trace IDs are never reused.** `max_existing_trace_number()` seeds the annotator counter so a partly annotated file continues numbering instead of colliding.
3. **`%||%` and `or_default()` are defined locally.** `%||%` only exists in base R from 4.4.0, but the supported floor is 4.0.0. Use `or_default()` for text inputs so a cleared field falls back instead of emitting an empty annotation field.
4. **Read source through `read_source_lines()`.** It normalises CRLF and re-encodes legacy (cp1252 / Latin-1) files, which otherwise fail with `input string 1 is invalid UTF-8`.
5. **Failures are surfaced, never swallowed.** `parse_r_file()` raises on syntax errors with explicit line and column information.
6. **Annotation is non-destructive.** Only new comment blocks are inserted; existing lines are never edited.
7. **Two trace-ID namespaces.** `trce-rparse-NNN` is the frozen module-level namespace (§2.1 of `Context.md`) and must never be renumbered. Component-level blocks use one namespace per module, `trce-<module>-NNN`, which keeps IDs unique repository-wide. When annotating a source file of this project, pass `--prefix trce-<module> --no-header`.
8. **This repository is 100% self-covered.** `tests/test_r_trce.R` asserts that every source file reports 100% coverage and that every in-source trace ID is indexed in `Context.md` and globally unique. If you add a component, run `rtrce annotate <file> --inplace --no-header --prefix trce-<module>` and update `Context.md` in the same commit.
9. **Never report a pattern found inside a comment.** The Pitfall Sentinel and the ID extractors skip comment lines; keep it that way so teaching notes are never flagged as defects.
10. **One dependency manifest.** `required_packages()`, `optional_packages()` and `missing_packages()` in `R/common.R` are the only definitions. `rtrce doctor`, `install.sh` and `install.ps1` read them instead of carrying private lists, and `tests/test_r_trce.R` fails if either installer hard-codes a package list again. Add a package by editing that manifest, never by editing an installer.
11. **The session engine is Shiny-free.** `R/runtime.R` must never depend on `shiny` or reach into reactive state. The Studio worker daemon and `rtrce run` both call `session_evaluate()`, so a behaviour change in one is a behaviour change in the other.
12. **A hosted session may never kill or block its host.** `R/runtime.R` guards `quit()`/`q()` and refuses to print an interactive server block. Anything else that could terminate or indefinitely block the Studio process belongs behind the same kind of guard, with an explanation the user can read.
13. **R-TRCE Studio is exclusively the native Electron desktop application.** Launchers, desktop entries, and `rtrce studio` must directly execute the Electron desktop shell with zero web browser popups. Pre-built standalone release archives bundle native Electron runtimes so end users require zero build steps.


---

## 2. Agent Workflow Protocol

Every session working in this repository must follow this context loop:

1. **Read `AGENTS.md`** (this file) — authoritative instructions.
2. **Read `Context.md`** — review trace index and monorepo layout.
3. **Verify traces** — ensure code changes map to existing `@trce-rparse-*` tags or introduce new sequential IDs.
4. **Implement changes** — maintain full 6-point TRCE annotations on all functional blocks.
5. **Update `Context.md`** — immediately index new trace pathways.
6. **Run Verification** — execute:
   ```bash
   Rscript tests/test_r_trce.R
   Rscript r_trce.R doctor
   ```

---

## 3. TRCE Annotation Standard in R

Every major functional block or module must include a standardized doc-comment block:

```r
# /**
#  * @trce-id trce-<namespace>-<NNN>
#  * @trce-who <initiating actor, agent tier, or system component>
#  * @trce-what <concrete mechanical action being performed>
#  * @trce-where <position in architecture + upstream/downstream dependencies>
#  * @trce-when <lifecycle hook, event trigger, or temporal condition>
#  * @trce-why <architectural intent, business rule, or problem solved>
#  * @trce-how <structural implementation, state mutations, formula routing>
#  */
```

---

## 4. CLI Command Reference

Installed systems expose `rtrce` (with `r-trce` kept as an alias); from a checkout, prefix
the same arguments with `Rscript r_trce.R`.

| Command | Description |
|---------|-------------|
| `rtrce parse <file>` | Parse R code AST and display identified components |
| `rtrce run <file> [--timeout S] [--wd DIR]` | Run the file in a live session and print the console transcript, workspace and plots |
| `rtrce explain <file> [--md]` | Output architectural explanation and dependency breakdown |
| `rtrce tutor <file>` | Student-friendly walkthrough, concept decoder & pitfall audit |
| `rtrce pitfalls <file>` | Audit code for common beginner traps and memory bottlenecks |
| `rtrce quiz <file> [--md]` | Generate tailored student comprehension quiz & study worksheet |
| `rtrce annotate <file> [opts]` | Synthesize and inject TRCE doc-comments (`--inplace`, `--out`, `--prefix`, `--style`, `--no-header`) |
| `rtrce check <file>` | Validate TRCE annotations (pattern, 6 fields, duplicate check, coverage) |
| `rtrce export-traces <file>` | Export trace graph to TRCE control plane JSON |
| `rtrce studio [port]` | Launch the interactive Shiny Studio (default port 8083) |
| `rtrce doctor` | Run environment diagnostics and self-test verification |

Every command prints a suggested next step on completion. Nothing is written to disk without
`--inplace` or `--out`.

