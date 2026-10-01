# /**
#  * @trce-id trce-exercise-002
#  * @trce-who Student / Data Engineer
#  * @trce-what Contrasts quadratic memory growth in loops against pre-allocated collection
#  * @trce-where samples/exercises/02_optimize_memory.R
#  * @trce-when Code profiling and memory optimization practice
#  * @trce-why Prevents exponential slowdowns caused by copy-on-modify semantics
#  * @trce-how Demonstrates list pre-allocation and single-pass row binding
#  */

# =============================================================================
# Exercise 2: Optimize Memory Allocation
# =============================================================================
# Run with:
#   rtrce pitfalls samples/exercises/02_optimize_memory.R
#   rtrce explain  samples/exercises/02_optimize_memory.R
# =============================================================================

# Slow Approach: Growing a data frame with rbind() inside a loop
# Time complexity: O(n^2) due to copy-on-modify semantics
slow_collector <- function(n = 100) {
  result <- data.frame()
  for (i in seq_len(n)) {
    # Each rbind copies the entire existing data frame
    result <- rbind(result, data.frame(step = i, value = i^2))
  }
  result
}

# Fast Approach: Pre-allocate a list of chunks, combine once
# Time complexity: O(n)
fast_collector <- function(n = 100) {
  chunks <- vector("list", n)
  for (i in seq_len(n)) {
    chunks[[i]] <- data.frame(step = i, value = i^2)
  }
  do.call(rbind, chunks)
}
