# Example R scripts

Five small, self-contained scripts used as inputs for the Studio and the CLI. They exist so
you have something to point the tool at immediately after installing — no need to hunt for an
R file first.

| File | Archetype it demonstrates | Good command to try |
| :--- | :--- | :--- |
| `01_shiny_app.R` | Shiny Interactive Web Application (`ui` + reactive `server`) | `rtrce explain samples/01_shiny_app.R` |
| `02_data_pipeline.R` | Star schema: load, validate, flatten, report lineage | `rtrce annotate samples/02_data_pipeline.R` |
| `03_statistics.R` | ANOVA variance decomposition and effect sizes | `rtrce explain samples/03_statistics.R` |
| `04_cli_tool.R` | Subcommand router with `usage()` and an execution guard | `rtrce parse samples/04_cli_tool.R` |
| `05_student_traps.R` | **Deliberately broken style** — nine classic beginner traps | `rtrce pitfalls samples/05_student_traps.R` |
| `09_cassie_companion.R` | Companion Telemetry & Linear Model (Dedicated to Cassie 🐾) | `rtrce run samples/09_cassie_companion.R` |

## Where these appear

* **Studio:** the "Load an example script" dropdown lists everything here as soon as you open
  the Studio.
* **CLI:** pass the path directly, e.g. `rtrce tutor samples/04_cli_tool.R`.

## Important

`05_student_traps.R` is **intentionally bad code**. Do not copy it. It calls `setwd()`, uses
`attach()`, compares with `== NA`, converts factors with `as.numeric()`, grows a data frame
with `rbind()` inside a loop, writes to the global environment with `<<-`, and imports both
`MASS` and `dplyr` so their `select()` functions collide. Each one is there to give the
Pitfall Sentinel something real to report.

Adding your own examples is fine: drop any `.R` file in this directory and it shows up in the
Studio picker. The discovery order is a sibling `R Test` checkout, then `samples/` here, then
`~/.r-trce-code-assistant/samples`, then `~/.r-trce/samples`.
