# gVisor ship overlay

Used by the `ship` skill. Re-read the PR guidelines in `AGENTS.md` and the "Code
reviews" section of `CONTRIBUTING.md` on each run, in case they changed.

## Checks (run in this order)

1. **Format:** `gofmt -l` on changed `.go` files, and fix with `gofmt -w`. Run
   `make lint-fix` only if `make lint` reports formatting problems.
2. **Lint:** `make lint`. Also run `make lint-cc` if any `.cc` or `.h` file
   changed. Both run in the Docker wrapper and are slow; run them anyway. That is
   what ship is for.
3. **Build:** `bazel build` (or `make build TARGETS=...`) for the targets that
   own the changed files.
4. **Impacted tests:**
   - Find test targets that depend on the changed files:
     `bazel query 'tests(rdeps(//..., set(<changed files>), 2))'`.
   - If a changed file is under `test/syscalls/linux/`, or the change alters
     syscall behavior in `pkg/sentry`, add the matching
     `//test/syscalls:<name>_test_native` and `..._test_runsc_ptrace` targets.
   - If the set has more than about 30 targets (common for core packages like
     `pkg/sentry/kernel` or `pkg/state`), show the list and ask which to run.
     Never start an unbounded test run without asking.
   - `CONTRIBUTING.md` says to run `bazel test ...` before sending; mention
     this when the impacted set was trimmed.

## Commit rules

- **Subject:** `<path or component>: <imperative summary>`, matching `git log`
  style (for example `pkg/state: add graph encoder state`). Keep it within 72
  characters.
- **Body:** what changed and why, wrapped at 72 characters. For a
  compatibility fix, include the `COMPATIBILITY:*` code and the real-world app
  (see `AGENTS.md`). For changes to a path in the "Performance sensitivity"
  section of `AGENTS.md`, include the `benchstat` results from the
  `benchmark` skill's report.
- **Trailers:**
  - `Signed-off-by: <git user.name> <git user.email>` via `git commit -s`.
  - `Assisted-by: Claude Opus 5.5`.
  - **No `Co-Authored-By` line.** gVisor's AI policy (`CONTRIBUTING.md`) says
    the contributor remains the sole author. This overrides the default
    attribution.
- **Amend, don't stack:** when the branch already has the commit for this
  change (iterating on a PR), amend it. A branch with several commits must have
  independent, logical commits that apply separately (for example a numbered
  series). Ask when it is unclear whether to amend or add a commit.

## DCO note

gVisor requires a Google CLA, not DCO. The sign-off is the user's own policy.
Check that every commit in `base..HEAD` has a `Signed-off-by` that matches
`git config user.email`.
