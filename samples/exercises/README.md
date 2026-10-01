# R-TRCE Code Assistant -- Student Exercises

Practice scripts designed to illustrate core R programming concepts, common beginner pitfalls, and performance optimization techniques.

### Exercises:
1. `01_fix_the_bug.R` -- Common beginner traps: missing value comparisons, safe looping on empty vectors, and namespace collisions.
2. `02_optimize_memory.R` -- Copy-on-modify semantics: why `rbind()` in a loop is $O(n^2)$ and how to pre-allocate memory properly.
3. `03_clean_survey_factors.R` -- Working with factors: preserving true numeric values when converting survey responses.

### How to Practice:
* **Audit pitfalls:** `rtrce pitfalls samples/exercises/01_fix_the_bug.R`
* **Student walkthrough:** `rtrce tutor samples/exercises/02_optimize_memory.R`
* **Deep dive on a line:** `rtrce teach samples/exercises/03_clean_survey_factors.R 22`
* **In the Studio:** Open `samples/exercises/` in the Studio Files pane or paste into the CodeMirror editor.
