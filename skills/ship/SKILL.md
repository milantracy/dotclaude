---
name: ship
description: Get a reviewed change ready to send and commit it locally. Checks that self-review approved the current code (re-reviews any delta), runs format, lint, build, and impacted tests, writes the commit message with the project's trailers (e.g. sign-off, Assisted-by), and verifies DCO. Never pushes. Runs only when the user types /ship.
argument-hint: "[--amend | --new] [--skip-review] [-m <subject>]"
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

## 4. Commit

- **Amend or new commit:** follow the overlay. `--amend` and `--new` force one.
  Ask when it's unclear.
- **Message:** start from the commit message draft that self-review checked,
  if this session has one. Update it for any later changes. Otherwise draft it
  from the final diff and the change's intent. Follow the overlay's format
  rules. Show it to the user before committing.
- **Trailers:** use the overlay's trailers. Without an overlay, use
  `git commit -s` plus the default attribution trailer from the session
  instructions. Add trailers with `--trailer "<Key>: <value>"`; don't
  hand-format them.
- Stage only the files from step 1, then commit.

## 5. Verify

- `git rev-parse HEAD^{tree}` equals the stamped tree. If not, explain why
  (for example, files intentionally left out).
- **DCO:** every commit in `base..HEAD` has
  `Signed-off-by: <user.name> <user.email>`:
  `git log --format='%H%n%(trailers:key=Signed-off-by,valueonly)' base..HEAD`.
- The required trailers are present, and forbidden ones (per the overlay) are
  absent.

## 6. Report

- Commit SHA and subject.
- Table of checks: format, lint, build, tests (with target count), DCO. Mark
  each passed, failed, or skipped, and show the commands used.
- Review status: stamped (rounds, user decisions) or skipped.
- The push command for the user to run themselves (for example
  `git push -u origin <branch>`, or `--force-with-lease` after an amend).
  **Never push.**
