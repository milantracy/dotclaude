# review-kit

This kit contains the shared parts of the review and ship workflow.

## Files

### `~/.claude/agents/code-reviewer.md`

This file defines the reviewer agent. The reviewer starts with no context. It
reads the diff, the code around the diff, and the project overlay. It does not
change files, and no overlay can change that rule. Each instance can get a lens:
one objective, such as security or tests. The review skills start several
instances in parallel, one per lens. Each reviewer reports each problem with a
severity, a location, and a failure scenario. In a blind review, it first finds
the root cause without the author's reasoning. Then it reads the reasoning of
the author and verifies each claim. In follow-up exchanges, it examines the
reply to each of its own findings: a fix, a rebuttal, or a request to leave the
finding. It accepts a rebuttal only when the rebuttal has evidence. It cannot
revert the change, so it writes a plan (`GATE4`) of the tests that must fail
without the change. The coordinator runs that plan. The `self-review` and
`pr-review` skills use this agent.

### `~/.claude/skills/self-review/SKILL.md`

This skill reviews our own changes. It classifies the risk of the change and
starts one reviewer agent per lens, in parallel. Each lens gets the context that
`lenses.md` gives it. The correctness reviewer first forms its own root cause
from the problem alone. Then it reads our root cause, design, rejected
alternatives, and draft commit message, and verifies each claim. We merge the
findings and check them with four gates. Gate 4 runs the tests with and without
the change, in a separate worktree. We fix each problem or argue with its
reviewer. We reject a reviewer's finding only when that reviewer agrees. Each
new round starts fresh reviewers on the full change. The skill defines when the
loop stops and which disputes go to the user. At the end, the skill writes a
review stamp.

### `~/.claude/skills/shipme/SKILL.md`

This skill prepares a reviewed change and commits it. First, it compares the
working tree with the review stamp. If the code changed after the review, it
starts a review of the new changes only. Then it runs the format, lint, build,
and test steps. If the change touches a performance-sensitive path, it looks for
a benchmark report for the same code. If no such report exists, it asks the user
what to do. It does not start a benchmark without permission. It writes the
commit message and adds the trailers from the overlay. It does not add a
sign-off, because only a human can certify the DCO. It tells the user which
commits need one. It does not push. The skill runs only when the user types
`/shipme`.

### `~/.claude/skills/pr-review/SKILL.md`

This skill reviews pull requests from other persons. It gets the pull request,
its comments, and its inline review threads, and puts the code in a separate
worktree. It starts one reviewer agent per lens, in parallel. Then it merges the
findings, removes feedback that is already on the pull request, and checks each
finding with the four gates. It removes the incorrect findings. It writes a
report with a verdict and a draft review comment for each finding. If an earlier
report exists, it gives the status of each earlier problem. It posts comments
only when the user tells it to post.

### `~/.claude/skills/benchmark/SKILL.md`

This skill measures the performance effect of our change. It builds the base
and the change, and runs the benchmarks in an alternating order. It stops when
the result is statistically sound. It examines the numbers for usual errors and
writes a report for the PR description. It does not change the system
configuration. It gives the commands to the user instead.

### `lenses.md`

This file lists the lenses, the risk tiers, and the default lens set for each
tier. It also says how much context each lens gets in each skill. A project
overlay can replace the tiers, the lens sets, the context, and the
objectives.

### `coordinator.md`

This file contains the rules that both review skills use as coordinator: the
ledger, the four gates, the Gate 4 steps, and the rules for arguing with a
reviewer. Each skill states only how it differs.

### `bin/review-stamp`

This script records the state of the working tree that the review approved. It
calculates one hash for the tracked files and the untracked files. It does not
change the git index. The `shipme` skill uses the script to find changes made
after the review.

### `projects/<name>/review.md`

This file contains the review rules for one project. The reviewer agent and the
review skills (as coordinator) read it. It tells the agent which project
documents to read first, and lists checks that are specific to the project. It
can also change anything that `lenses.md` or `coordinator.md` says an overlay
can change.

### `projects/<name>/ship.md`

This file contains the ship rules for one project. The `shipme` skill reads it.
It lists the check commands, the method to find the tests, and the commit
format. It also lists the trailers that a commit must have.

### `projects/<name>/benchmark.md`

This file contains the benchmark rules for one project. The `benchmark` skill
reads it. It gives the statistics tool, the stop rule, the benchmark targets,
and the commands to build and run the benchmarks.

### `projects/gvisor/`

These files are the overlay for gVisor. See `projects/gvisor/review.md` for the
documents it reads and how it maps the gVisor review rules to lenses.

## Overlay detection

| Signal | Overlay dir |
|---|---|
| `go.mod` module `gvisor.dev/gvisor`, or a remote URL containing `google/gvisor` | `projects/gvisor/` |

If no signal matches, no overlay applies. Use the guidance in the repository:
`AGENTS.md`, `CLAUDE.md`, `CONTRIBUTING.md`, `.gemini/styleguide.md`, and the CI
configuration.

To add a project, make `projects/<name>/review.md`, `ship.md`, or both. Then add
a row to the table.
