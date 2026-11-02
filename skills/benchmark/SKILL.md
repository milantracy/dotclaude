---
name: benchmark
description: Measure the performance effect of our change with an A/B benchmark (base vs change). Plans which benchmarks cover the change, builds both sides without touching the user's checkout, runs them interleaved until the results are statistically sound, checks the numbers for common mistakes, and writes a report for the PR description. Use when a change may affect performance, or when the user asks to benchmark or compare.
argument-hint: "[benchmark targets or filter] [--base <ref>] [--plan-only]"
---

# Benchmark (A/B)

Kit: `~/.claude/review-kit/`. Detect the overlay from its `README.md` and read
`projects/<name>/benchmark.md` when one exists. The overlay supplies the stats
tool, the stop rule, the benchmark targets, and the build and run commands. It
overrides the defaults below.

## Rules

- **Same everything except the change.** Same machine, flags, inputs, and
  harness for both sides. If the change modifies the benchmark or harness
  itself, say so, and use the same harness binary for both sides where possible.
- **Never change system configuration yourself.** That includes sudo, daemon
  configs, service restarts, CPU governors, and kernel parameters. Print the
  exact commands and let the user run them.
- **Report what happened.** Count failed and short-circuited runs; never drop
  them silently. Report "no significant change" results too.
- **Don't touch the user's checkout.** Build the base in a separate worktree,
  and remove it when done.

## 1. Plan

- **Base:** `--base <ref>`, or by default `git merge-base HEAD <upstream default
  branch>`. **Change:** the current working tree, including uncommitted edits.
  Record both SHAs, plus the tree hash for the change from
  `~/.claude/review-kit/bin/review-stamp tree`. `/ship` matches reports by this
  hash.
- **Benchmarks:** from the diff, list the code paths the change touches. Pick
  the existing benchmarks that cover them (see the overlay). If none covers the
  effect directly, propose a new benchmark and write it first.
- **Hypothesis:** for each metric, write the expected direction: faster,
  slower, or unchanged. Include metrics that must **not** move (for example,
  unrelated workloads).
- **Cost:** estimate the run time. If it's over about 30 minutes, or needs
  system changes, show the plan and wait for the user's go-ahead.
- With `--plan-only`, stop here and show the plan.

## 2. Build

- Base: `git worktree add <tmp>/base <base-sha>`, then build there.
- Change: build from the current tree.
- Copy each side's binaries to `<tmp>/base/` and `<tmp>/change/`, so that the
  runs use fixed files that later builds can't change.

## 3. Run

- **Interleave** in ABBA order (A B B A, then repeat). This cancels slow drift
  from heat, caches, and background load. Never run all of A, then all of B.
- Run one iteration per call, and append the output to `base.txt` or
  `change.txt`.
- **Noise floor (optional, recommended on VMs or unknown machines):** first run
  a short A/A comparison (the base binary against itself). Any "difference"
  there is noise. A real effect must be clearly larger than it.
- **Stop rule:** from the overlay. Without one, use at least 10 runs per side.
  Run more if the spread is high (more than 5% on microbenchmarks).
- Record the environment: CPU model and core count, kernel, VM or bare metal,
  CPU governor if visible, load average before and after, flags, and SHAs.

## 4. Analyze

Use the overlay's stats tool. Without an overlay, report the median, the spread
(stddev or IQR), n per side, and a Mann-Whitney U p-value. If no tool for the
test is available, say so; don't invent significance.

Before you believe a result, check:
- **Plausible size:** does the delta fit the share of runtime that the change
  touches? A 20% win from code that takes 2% of the time is a measurement bug.
- **Timed region:** is the target work inside it, and the setup outside it?
- **Errors:** did any runs fail or take a shortcut? Do both sides do the same
  work (same output, same byte counts)?
- **Noise:** is the spread small enough for the claimed delta? Was the machine
  quiet?
- **Hypothesis:** did every metric move as expected? Explain each surprise, or
  mark it unexplained.
- **End-to-end:** does a microbenchmark win show up on a path that users see?
  If that wasn't measured, say so.

## 5. Report

Save the report to the overlay's report location (default
`~/workspace/benchmarks/<branch>-<YYYYMMDD>.md`):

```
# Benchmark: <branch> — <one-line change summary>
tree: <hash from review-stamp tree>
branch: <branch>
Base `<sha>`, change `<sha>`.
Environment: <CPU, cores, kernel, VM/bare metal, platform, flags>.
Commands: <exact build and run commands>.

## Hypothesis
<metric: expected direction>

## Results
<raw stats-tool output>

## Interpretation
<what moved, what didn't, surprises and their explanations, caveats
 (noise, VM, unmeasured end-to-end effect)>

## For the PR description
<the stats-tool output plus 2-4 sentences, following the overlay's rules>
```

Tell the user the headline result, any failed sanity checks, and the report
path. Remove the base worktree.
