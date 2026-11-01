# review-kit

This kit contains the shared parts of the review and ship workflow.

## Files

### `~/.claude/agents/code-reviewer.md`

This file defines the reviewer agent. The reviewer starts with no context. It
reads the diff, the code around the diff, and the project overlay. It does not
change files. It reports each problem with a severity, a location, and a failure
scenario. In a blind review, it first finds the root cause without the author's
reasoning. Then it reads the reasoning of the author and verifies each claim. In
later rounds, it examines each fix and each rebuttal. It accepts a
rebuttal only when the rebuttal has evidence. The `self-review` and `pr-review`
skills use this agent.

### `~/.claude/skills/self-review/SKILL.md`

This skill reviews our own changes. It starts the reviewer agent. It gives the
agent the diff, the overlay, and the context of the problem: the intent, the
symptoms, the evidence, the expected behavior, the scope, and the constraints.
It does not give the design or the reasons for the fix in the first pass. The
reviewer then writes its own root cause and its findings. After that, we give
the reviewer our root cause, our design, our rejected alternatives, and the
draft commit message. The reviewer verifies each claim. It also compares the two
root causes. These two steps are round one. We fix each problem or rebut it
with evidence. The reviewer then examines our reply. This loop has a maximum
of three rounds. If a serious problem stays open after round three, the skill
asks the user to decide. At the end, the skill writes a review stamp.

### `~/.claude/skills/ship/SKILL.md`

This skill prepares a reviewed change and commits it. First, it compares the
working tree with the review stamp. If the code changed after the review, it
starts a review of the new changes only. Then it runs the format, lint, build,
and test steps. It writes the commit message and adds the trailers from the
overlay. It makes sure that each commit has a sign-off. It does not push. The
skill runs only when the user types `/ship`.

### `~/.claude/skills/pr-review/SKILL.md`

This skill reviews pull requests from other persons. It gets the pull request
and puts it in a separate worktree. It starts the reviewer agent. Then it
examines each finding against the code and removes the incorrect findings. It
writes a report with a verdict and a draft review comment for each finding. If an earlier
report exists, it gives the status of each earlier problem. It posts comments
only when the user tells it to post.

### `bin/review-stamp`

This script records the state of the working tree that the review approved. It
calculates one hash for the tracked files and the untracked files. It does not
change the git index. The `ship` skill uses the script to find changes made
after the review.

### `projects/<name>/review.md`

This file contains the review rules for one project. The reviewer agent reads
it. It tells the agent which project documents to read first. It also lists
checks that are specific to the project.

### `projects/<name>/ship.md`

This file contains the ship rules for one project. The `ship` skill reads it.
It lists the check commands, the method to find the tests, and the commit
format. It also lists the trailers that a commit must have.

### `projects/gvisor/`

These files are the overlay for gVisor. The review rules tell the agent to read
the gVisor documents: `.gemini/styleguide.md`, `AGENTS.md`, `CONTRIBUTING.md`,
and `SECURITY.md`. The ship rules add `Signed-off-by` and
`Assisted-by: Claude Opus 5.5` to each commit. They do not add
`Co-Authored-By`, because the gVisor policy says that the contributor is the
only author.

## Overlay detection

| Signal | Overlay dir |
|---|---|
| `go.mod` module `gvisor.dev/gvisor`, or a remote URL containing `google/gvisor` | `projects/gvisor/` |

If no signal matches, no overlay applies. Use the guidance in the repository:
`AGENTS.md`, `CLAUDE.md`, `CONTRIBUTING.md`, `.gemini/styleguide.md`, and the CI
configuration.

To add a project, make `projects/<name>/review.md`, `ship.md`, or both. Then add
a row to the table.
