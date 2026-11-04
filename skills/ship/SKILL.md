---
name: ship
description: Get a reviewed change ready to send and commit it locally. Checks that self-review approved the current code (re-reviews any delta), runs format, lint, build, and impacted tests, checks for a current benchmark report when the change touches hot paths, writes the commit message with the project's trailers (e.g. sign-off, Assisted-by), and verifies DCO. Never pushes. Runs only when the user types /ship.
argument-hint: "[--amend | --new] [--skip-review] [--no-benchmark] [-m <subject>]"
disable-model-invocation: true
---

# Ship

Kit: `~/.claude/review-kit/`. Detect the overlay from its `README.md` and read
`projects/<name>/ship.md` when one exists. The overlay overrides the defaults
below.

## 1. Preflight

- `git config user.name` and `user.email` must be set. If they aren't, stop and
  ask.
- If the current branch is the default branch, ask the user for a branch name
  and create the branch before committing.
- Find the base: `git merge-base HEAD <upstream default branch>`.
- Show `git status --short`. Decide which files belong to this change. If any
  untracked or modified file looks unrelated, ask before including it. Never
  `git add -A` blindly.

## 2. Review gate

Run `~/.claude/review-kit/bin/review-stamp check`:
- **Exit 0 (match):** reviewed. Continue.
- **Exit 1 (differs):** the code changed after review. Run the `self-review`
  skill with `--delta <stamped tree>`, so it reviews only what changed.
- **Exit 2 (no stamp):** run the full `self-review` skill.

`--skip-review` bypasses this gate only if the user typed it. Name the skipped
review in the final report.

## 3. Checks

Run the overlay's checks in order. Without an overlay, discover them from the
repo: Makefile targets (`fmt`, `lint`, `test`), `.pre-commit-config.yaml`, CI
config, `package.json` scripts, and similar. Defaults:

1. Format (auto-fix).
2. Lint.
3. Build the affected targets.
4. Impacted tests. Scope them to the changed files. If the set is large, ask
   before running it.

On failure: fix, then rerun that check. Two fix attempts per check at most; then
stop and report.

After the checks, run `review-stamp check` again:
- If only formatter output changed (the diff from the stamped tree is pure
  formatting), run `review-stamp write` without re-review.
- Any other change: go back to step 2 (delta re-review).

## 4. Benchmark gate

Applies only when the overlay has a `benchmark.md` with a "When to benchmark"
rule, and the diff matches it (for gVisor: it touches a path in the
"Performance sensitivity" section of `AGENTS.md`). Otherwise skip this step and
say so in the report. `--no-benchmark` skips it only if the user typed it.

1. `T=$(~/.claude/review-kit/bin/review-stamp tree)`.
2. Look for a report in the overlay's benchmark report directory with the line
   `tree: $T`.
3. **Found:** use its "For the PR description" section in the commit message.
4. **Only older reports:** take the newest report for this branch and run
   `git diff <its tree> $T`. If the diff is only formatting, or only touches
   files outside the benchmark rule (tests, docs), use the report and say so in
   the commit report. Otherwise it's out of date.
5. **None, or out of date:** ask the user (AskUserQuestion) and show which hot
   paths the diff touches:
   - "Run /benchmark now": run the `benchmark` skill, then continue.
   - "Ship without numbers": continue. Name the missing benchmark in the final
     report, and mention it in the commit message only if the user asks.
   - "Stop": stop before the commit.

Never start a benchmark run without asking. Runs can be long and can need
system changes.

## 5. Commit

- **Amend or new commit:** follow the overlay. `--amend` and `--new` force one.
  Ask when it's unclear.
- **Message:** start from the commit message draft that self-review checked,
  if this session has one. Update it for any later changes. Otherwise draft it
  from the final diff and the change's intent. Follow the overlay's format
  rules. Show it to the user before committing.
- **No issue references:** don't put issue or PR IDs in the commit message
  (no `#123`, `Fixes #123`, `Updates #123`, `Closes ...`, or issue URLs), even
  if the project's guidelines suggest it. The user tags the issue in the PR
  body. If the self-review draft has one, drop it from the commit message.
- **Trailers:** use the overlay's trailers. Without an overlay, use
  `git commit -s` plus the default attribution trailer from the session
  instructions. Add trailers with `--trailer "<Key>: <value>"`; don't
  hand-format them.
- Stage only the files from step 1, then commit.

## 6. Verify

- `git rev-parse HEAD^{tree}` equals the stamped tree. If not, explain why
  (for example, files intentionally left out).
- **DCO:** every commit in `base..HEAD` has
  `Signed-off-by: <user.name> <user.email>`:
  `git log --format='%H%n%(trailers:key=Signed-off-by,valueonly)' base..HEAD`.
- The required trailers are present, and forbidden ones (per the overlay) are
  absent.
- The commit message has no issue references (`#<n>`, `Fixes`/`Updates`/
  `Closes`, issue URLs).

## 7. Report

- Commit SHA and subject.
- Table of checks: format, lint, build, tests (with target count), DCO. Mark
  each passed, failed, or skipped, and show the commands used.
- Review status: stamped (rounds, user decisions) or skipped.
- Benchmark: report used (path, exact or near tree match), run now, shipped
  without numbers (by user choice), or not needed.
- The push command for the user to run themselves (for example
  `git push -u origin <branch>`, or `--force-with-lease` after an amend).
  **Never push.**
