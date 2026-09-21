# R-TRCE Code Assistant

**Read, understand and document any R script — from the command line or in a browser.**

R-TRCE Code Assistant parses an R file into its abstract syntax tree, explains what each
function and data structure actually does, and writes standardised 6-point `@trce-*`
documentation blocks into the file for you. It also ships a student-facing suite that flags
common beginner traps, unpacks data pipelines, and generates comprehension quizzes.

Built directly on the architectural patterns and lessons from **R Test** (CLI tools, Shiny reactive graphs, star/snowflake schemas, ANOVA models, and data pipelines).

---

## Start Here in 60 Seconds

```bash
# 1. Check your environment (R version, shiny, jsonlite)
rtrce doctor

# 2. See what a script is really made of
rtrce explain "path/to/script.R"

# 3. Preview the documentation it would add -- nothing is written yet
rtrce annotate "path/to/script.R"

# 4. Write it into the file, then audit the result
rtrce annotate "path/to/script.R" --inplace
rtrce check "path/to/script.R"
```

Not sure what "archetype" or "coverage %" mean? See the [Glossary](#glossary).

---

## Features

* **100% Native R AST Parsing:** Leverages base R's `parse(keep.source = TRUE)` and `getParseData()` to inspect concrete syntax trees, line coordinates, and comment blocks with zero external C++ dependencies.
* **Semantic Architectural Comprehension:** Automatically classifies R code archetypes:
  - **Shiny Interactive Web Applications:** Detects UI hierarchies (`fluidPage`, `navbarPage`, widgets) and Server reactive graphs (`reactive`, `reactiveVal`, `observeEvent`, `renderPlot`).
  - **Relational Data Architectures & Pipelines:** Identifies snowflake/star schema definitions (`TABLES`, `JOIN_PLAN`), defensive validation checks (`validate_tables`), and lineage flattening routines (`build_analytic`).
  - **Statistical & Modeling Engines:** Recognizes ANOVA variance decompositions, method-of-moments estimators, linear models (`lm`), and confounding guards.
  - **Command-Line Tools:** Recognizes `commandArgs` parsing, `usage()` dispatchers, subcommand routers, and execution guards (`if (!interactive())`).
* **Complete 6-Point TRCE Annotations:** Generates rich doc-comments conforming to TRCE control plane standards:
  1. `@trce-id`: Canonical identifier matching `^trce-[a-z0-9]+(?:-[a-z0-9]+)*-[0-9]+$`
  2. `@trce-who`: Initiating actor / system component
  3. `@trce-what`: Mechanical action being performed
  4. `@trce-where`: Architectural position and upstream/downstream call graph
  5. `@trce-when`: Lifecycle trigger or event phase
  6. `@trce-why`: Architectural intent and domain problem solved
  7. `@trce-how`: Structural implementation, state mutations, and formulas
* **Student Tutor & Pedagogical Suite:** Tailored specifically for students learning R:
  - **Student Pitfall Sentinel:** Audits code for common beginner traps (`1:length(x)`, `x == NA`, `attach()`, `as.numeric(factor)`, and quadratic `rbind` memory loops).
  - **Data Pipeline Flow Inspector:** Deconstructs multi-stage native (`|>`) and magrittr (`%>%`) pipelines into discrete, human-readable steps.
  - **Statistical Formula Deconstructor:** Translates model formulas (`y ~ x1 + x2 * x3`) into clear statistical explanations of response variables, predictors, and interaction terms.
  - **Comprehension Quiz Generator:** Generates automated self-study multiple-choice questions directly from user code.
* **Non-Destructive Code Injection:** Automatically injects annotations into R source files while preserving existing formatting, author comments, and indentation.
* **Integrity Audit & Coverage:** Audits existing or generated annotations, verifies field completeness, flags duplicate IDs, and reports coverage percentages.
* **Dual Interfaces:** Provides both a Unix-philosophy command-line tool (`r_trce.R`) and an interactive Shiny web dashboard (`app.R` with dedicated 🎓 Student Studio).

---

## ⚡ 1-Minute Quick Install

### 🐧 Linux & 🍏 macOS (One-Line Auto-Installer)
```bash
curl -fsSL https://raw.githubusercontent.com/AsterovLabs/R-TRCE-Code-Assistant/main/install.sh | bash
```
*Works on all Linux distributions (Debian, Ubuntu, Arch, Fedora, openSUSE, Alpine), Chromebooks (Baguette / Crostini / ChromeOS Linux), and macOS. Creates global `rtrce` and `rtrce-studio` commands (the older `r-trce` / `r-trce-studio` names still work as aliases).*

> [!TIP]
> **Using on a Chromebook (ChromeOS / Baguette Linux)?**
> The interactive studio listens on `0.0.0.0:8083`. You can access it directly inside ChromeOS via `http://localhost:8083` or `http://penguin.linux.test:8083`.


### 🪟 Windows 11 & Windows 10 (PowerShell One-Line Auto-Installer)
Open PowerShell (or Windows Terminal) and run:
```powershell
irm https://raw.githubusercontent.com/AsterovLabs/R-TRCE-Code-Assistant/main/install.ps1 | iex
```
*Auto-detects or installs R via winget, configures `PATH`, adds `rtrce` & `rtrce-studio` commands (plus legacy `r-trce` aliases), and places a desktop shortcut for R-TRCE Code Assistant Studio.*

### 📦 Standalone & Offline Downloads (GitHub Releases)

Pre-packaged bundles are available on the [GitHub Releases](https://github.com/AsterovLabs/R-TRCE-Code-Assistant/releases) page:

| Operating System | Package Archive | Installation |
| :--- | :--- | :--- |
| **Windows 11 / 10** | [`rtrce-code-assistant-windows-all.zip`](https://github.com/AsterovLabs/R-TRCE-Code-Assistant/releases/latest) | Extract zip and double-click `install.bat` |
| **Linux (All Distros)** | [`rtrce-code-assistant-linux-all.tar.gz`](https://github.com/AsterovLabs/R-TRCE-Code-Assistant/releases/latest) | Extract tarball and run `./install.sh` |
| **macOS** | [`rtrce-code-assistant-macos-all.tar.gz`](https://github.com/AsterovLabs/R-TRCE-Code-Assistant/releases/latest) | Extract tarball and run `./install.sh` |

---

## Setup & Requirements

R version >= 4.0.0 is required. If using the Asterov user environment:

```bash
# Path to environment Rscript:
Rscript --version
```

Dependencies (`jsonlite`, `shiny`, `DT`) are pre-installed in `~/.r-env`.

---

## CLI Usage

After running `install.sh` / `install.ps1` you have the `rtrce` command. Working straight
from a checkout, use `Rscript r_trce.R` instead — both take identical arguments.

**Read-only commands** (nothing on disk changes):

| Command | What it does |
| :--- | :--- |
| `rtrce parse <file>` | Lists the components found in the file |
| `rtrce explain <file> [--md]` | Full architecture write-up plus the call graph |
| `rtrce doctor` | Checks R version, `shiny` and `jsonlite` are present |

**Annotate & audit:**

| Command | What it does |
| :--- | :--- |
| `rtrce annotate <file>` | Previews the `@trce-*` blocks it would add |
| `rtrce annotate <file> --out F` | Writes annotated code to `F` |
| `rtrce annotate <file> --inplace` | Rewrites the file in place |
| `rtrce check <file>` | Audits ID clashes, 6-field completeness, coverage % |
| `rtrce export-traces <file> --out F` | Exports the trace index as JSON |

**Learn (built for students):**

| Command | What it does |
| :--- | :--- |
| `rtrce tutor <file>` | Guided walkthrough, component by component |
| `rtrce pitfalls <file>` | Flags beginner traps and memory bottlenecks |
| `rtrce quiz <file> [--md]` | Generates a comprehension quiz from the script |

**Other:**

| Command | What it does |
| :--- | :--- |
| `rtrce studio [port]` | Opens the interactive web Studio (default `8083`) |
| `rtrce help` | Every command, option and example |

### Annotate options

| Option | Effect |
| :--- | :--- |
| `--inplace`, `-i` | Overwrite the target file |
| `--out`, `-o PATH` | Write the annotated code to `PATH` |
| `--prefix NAME` | Trace ID prefix (default `trce-r`) |
| `--style STYLE` | `jsdoc` (default) or `roxygen` |
| `--no-header` | Skip the file-level module header |

### Worked example

```bash
# Inspect, preview, then commit the change
rtrce explain  "complex/R/star.R"
rtrce annotate "complex/R/star.R"            # preview only, nothing written
rtrce annotate "complex/R/star.R" --inplace
rtrce check    "complex/R/star.R"            # expect PASSED at 100% coverage
```

Annotation is **non-destructive**: existing lines are never edited, only new comment blocks
are inserted above each component. Re-running `annotate` after a partial run continues the
trace numbering instead of reusing IDs, so `check` stays clean.


---

## Interactive Shiny Studio & Guided Walkthrough

Launch the visual walkthrough studio:

```bash
# Direct runner script:
./start_studio.sh

# Or directly with Rscript:
Rscript app.R
```

Open `http://127.0.0.1:8083` in your browser:
* **Tab 1: Guided Walkthrough ("Walk Me Through It"):**
  - Drop or select an R script to start a step-by-step interactive inspection.
  - Review each function, reactive node, and pipeline step one by one.
  - View syntax-highlighted code snippets, architectural dependencies, and caller/callee graphs.
  - Inspect, customize, or accept the generated 6-point TRCE annotations (`@trce-*`) as you go.
  - Actions: `[ Accept & Next ]`, `[ Skip ]`, `[ Previous ]`, `[ Annotate All Immediately ]`.
  - Progress tracker and celebration screen upon 100% completion.
* **Tab 2: Annotated Code & Traces:** Real-time view of your annotated code, TRCE audit validation badge, and download buttons (`.R` and `.json`).
* **Tab 3: Architectural Explanation:** View detected archetype, system narratives, and caller-callee dependency matrices.
* **Tab 4: AST & Parse Tokens:** Raw R AST expression coordinates and lexical token streams.
* **Tab 5: 🎓 Student Studio:** Pitfall sentinel, concept decoder, pipeline/formula deconstruction, and a self-study quiz.

No R file handy? The sidebar's **"Or load an example script"** dropdown lists the scripts in
[`samples/`](samples/README.md) — one per archetype plus a deliberately broken file that
trips all nine pitfall detectors.

The sidebar always shows which file is loaded and keeps the "New to TRCE?" panel, so the
six questions and the archetype names are never more than a glance away.

### If a file does not load

The Studio reports the problem in a red banner at the top of every tab rather than showing a
blank page. The two situations it detects are:

* **Syntax errors** — R stops at the first one, and the banner quotes the file, line and
  offending code. Your code is still visible on the "Annotated Code & Traces" tab.
* **Legacy encodings** — files saved as cp1252 / Latin-1 (typical of Windows editors) are
  read and converted automatically, with an amber notice so you know characters were
  reinterpreted.


---

## Verification & Testing

Execute the automated test suite:

```bash
Rscript tests/test_r_trce.R      # 61 assertions, exits non-zero on failure
Rscript r_trce.R doctor          # environment + self-test health check
```

The suite covers parser fidelity, dependency resolution, annotation synthesis, code
injection idempotency, encoding tolerance, the shared helpers, and regression tests for
every bug fixed in the rename pass. It also asserts two repository-wide invariants:

* every source file in this project reports **100% TRCE coverage**, and
* every trace ID used in source is indexed in [`Context.md`](Context.md) and is globally
  unique.

Real-world coverage is exercised against the scripts in `R Test` (`data_entry_viz.R`,
`complex/R/star.R`, `complex/R/variance.R`, `complex/R/schema.R`, `app.R`) when that sibling
checkout is present, and against the bundled `samples/` either way.

---

## Glossary

| Term | Meaning |
| :--- | :--- |
| **TRCE / `@trce-*`** | The six-question documentation standard this tool writes: `who`, `what`, `where`, `when`, `why`, `how`. |
| **Trace / trace ID** | One `@trce-id trce-...-NNN` identifier. Trace IDs are unique per file and exportable as JSON. |
| **Annotatable component** | Anything worth documenting: a function, a Shiny UI/server block, a schema definition, or a CLI runner. Plain assignments are ignored. |
| **Archetype** | The role a component plays — `data_pipeline`, `statistical_model`, `visualization`, `shiny_server`, `cli_dispatcher`, `utility_function`. It drives the wording of the generated annotation. |
| **Coverage %** | Annotated components ÷ annotatable components. `check` reports `PASSED` at 100%. |
| **Idempotent** | Running `annotate` twice adds nothing the second time, and re-running after a partial run continues the numbering instead of duplicating IDs. |

## Repository Map

| Path | Purpose |
| :--- | :--- |
| `r_trce.R` | CLI entry point and command router |
| `app.R` | Interactive Shiny Studio |
| `R/common.R` | Shared helpers: `%||%`, `or_default()`, script location, the annotatable-component rule, trace-ID bookkeeping, encoding-tolerant file reading |
| `R/parser.R` | AST and token extraction, comment association |
| `R/analyzer.R` | Archetype detection and call graph |
| `R/annotator.R` | 6-point annotation synthesis and non-destructive injection |
| `R/validator.R` | ID, field and coverage auditing |
| `R/explain.R` | Text/Markdown explanations and JSON export |
| `R/pedagogy.R` | Student tutor, pitfall sentinel, pipe/formula deconstruction, quizzes |
| `tests/test_r_trce.R` | Automated test suite (61 assertions, includes self-coverage and trace-index guards) |
| `samples/` | Five example scripts covering every detected archetype, plus a deliberate "student traps" file — see [`samples/README.md`](samples/README.md) |
| `AGENTS.md` | Instructions for AI agents working on this repository |
| `Context.md` | Trace index mapping every `@trce-rparse-*` ID to its source file |

---

## 📄 License & Proprietary Rights

Copyright © 2026 Asterov Labs. All Rights Reserved.

Licensed under the **Asterov Labs Proprietary Software License**.
* Permitted: Personal, educational, classroom instruction, and academic non-commercial study.
* Prohibited: Unauthorized commercial distribution, hosting as a paid service, reverse engineering for commercial derivation, or sublicensing without written permission.

See [`LICENSE`](LICENSE) for complete legal terms.

