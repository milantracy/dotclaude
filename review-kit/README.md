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
without the change. The coordinator runs that plan through the
`fail-first-checker` agent. The `self-review` and `pr-review` skills use
the reviewer agent.

### `~/.claude/agents/fail-first-checker.md`

This file defines the agent that checks that a change's tests fail without
the change and pass with it (Gate 4 of the review skills). It gets the
change, its base, and the reviewers' `GATE4` plans. In a separate
worktree (for pr-review, the head worktree) it runs the targets with the
change and with the production files reverted, then restores the worktree.
It returns a table of each target's result both ways and a verdict, so the
test logs don't fill the coordinator's context. It never touches the repo's
own checkout.

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
report exists, it gives the status of each earlier problem. It runs forked in
the background, so its work stays out of the main session, and it returns a
short summary (verdict, blockers, open questions) and the report path. A
second `/pr-review` started while one runs waits in the foreground. It never
posts; the user posts the comments from the main session. It runs only when
the user types `/pr-review`.

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
ledger, the four gates, how to run Gate 4 with the `fail-first-checker`
agent and read its results, and the rules for arguing with a reviewer. Each
skill states only how it differs.

### `bin/review-stamp`

This script records the state of the working tree that the review approved. It
calculates one hash for the tracked files and the untracked files. It does not
change the git index. The `shipme` skill uses the script to find changes made
after the review.

### `bin/reviewer-guard`

This script is a PreToolUse hook that the `code-reviewer` agent runs before
each Bash command. It rewrites the command to run in an OS sandbox:
`sandbox-exec` on macOS, `bwrap` (bubblewrap) on Linux. The command and the
processes it starts:

- can write only inside a scratch directory for that reviewer
  (`/tmp/claude-reviewer-<uid>/<agent>`, set as `$TMPDIR`, with the Go, pip,
  npm, and XDG caches inside it) and to `/dev/null` and similar device
  files. A command can't replace the directory itself: on macOS the
  profile denies writes to it, and on Linux it is a mount point (its mode
  can still change; a mode others can write makes the hook block). On macOS
  they can also write the heredoc files of `/bin/bash` 3.2, `/tmp/sh-thd*`.
  The repo under review, its `.git` directory, the review worktrees under
  `/tmp`, the user's caches, and `~/.claude` are read-only;
- have no network, loopback included. That also blocks `git push`, `gh`,
  the Docker daemon, ssh-agent, and other local daemons reached over a
  socket;
- can't read the usual credential files (`~/.ssh`, `~/.config/gh`,
  `~/.netrc`, `~/.claude.json`, shell history and startup files, and
  others) and start with an empty environment plus a short list of
  variables (`PATH`, `HOME`, locale, and toolchain settings such as
  `GOFLAGS` and `CARGO_HOME`), so the
  command's own environment holds no tokens. The hook also sets `TMPDIR`,
  the cache paths, `GOPROXY=off`, and `GIT_TERMINAL_PROMPT=0`, overriding
  the user's values. The shell is `$SHELL` if it is bash, zsh (run with
  `-f`, so `~/.zshenv` doesn't run), or sh, else `/bin/bash`;
- on macOS, can't use the keychain, the clipboard, or the window server,
  open files or apps through LaunchServices, create launchd jobs, write
  preferences through cfprefsd (`defaults write`), send Apple events, get
  other processes' task ports, signal processes outside the sandbox, or run
  `osascript`, `open`, `launchctl`, `security`, or `shortcuts`.

The wrapper names `env`, `sandbox-exec`, and `bwrap` by absolute path, and
they must be root-owned, so a program of the same name in `PATH` doesn't
run outside the sandbox. A command that is byte for byte the hook's own
wrapper passes through unchanged (auto mode resends it); anything else is
wrapped again.

Limits:

- Only Bash is sandboxed. The reviewer's Read, Grep, and Glob tools can
  still read credential files, and WebFetch and WebSearch can send data
  out.
- On macOS the sandbox allows everything it doesn't deny. A program can
  still reach system services that the profile doesn't name, and some of
  them act outside the sandbox (for example, LaunchServices registration and
  the Shortcuts runner are not denied by service name; untested).
- On macOS a sandboxed command can read the arguments and environment of
  the user's other processes, Claude Code included (the `kern.procargs2`
  sysctl; no sandbox rule tried stops it). Don't export tokens in the shell
  that runs reviews. On Linux the sandbox has its own process namespace.
- The task-port deny is untested: without developer mode, `task_for_pid`
  fails even outside the sandbox.
- On macOS a sandboxed command can change the `/tmp/sh-thd*` heredoc files
  of other reviewers. Unsandboxed `/bin/bash` writes its heredocs to
  `/var/tmp`, which the sandbox can't write.
- `diff <(...) <(...)` fails in the sandbox, and setuid programs (`ps`,
  `top`, `sudo`) don't run. Write both sides of a diff to `$TMPDIR`.
- Builds and tests that write outside `$TMPDIR` (bazel, `go build` without
  `-o`), download dependencies, use Docker (`make test` in gVisor), or open
  local sockets (Go `httptest`) fail. The reviewer reports such a command
  instead of running it; Gate 4 runs builds and tests in the
  `fail-first-checker` agent, outside the sandbox.
- In auto mode, the first try of each reviewer command is refused because
  the hook changed it, and the reviewer resends the rewritten command. Each
  command costs two tool calls. The hook doesn't approve commands itself
  (`permissionDecision: "allow"`), because that would skip auto mode's
  review of them. In default permission mode, permission rules see the
  rewritten command, so allow rules such as `Bash(git log:*)` no longer
  match and each reviewer command asks for approval.
- `PATH` comes from Claude Code's own environment, which may be shorter
  than the shell's when Claude Code starts from an IDE or the desktop app;
  tools missing from it fail with "command not found".
- It needs `python3`, Claude Code 2.1.295 or later (for `onFailure`; that
  `updatedInput` applies without a permission decision is verified only on
  2.1.332), and `bwrap` on Linux with unprivileged user namespaces (some
  distributions restrict them). If the sandbox is missing, the hook fails, or it times
  out, the command is blocked or fails; none runs unsandboxed. On Linux,
  `bwrap` is looked up in `PATH` and must be root-owned, so a user-owned
  `bwrap` first in `PATH` (Homebrew on Linux) blocks every reviewer
  command.
- Another PreToolUse hook that rewrites Bash commands could replace the
  wrapped command; the hooks docs don't say which rewrite wins.
- The Linux path has never run; only its resend and mask logic is tested,
  with `bwrap` stubbed. On Linux it hides the credential files, the sockets
  and known socket directories directly in `/tmp` (tmux, ssh-agent, X11),
  and `/run`; a socket elsewhere (for example `/tmp/emacs<uid>/server`)
  stays reachable. The list is rebuilt for each command; a resend may also
  match the list of the command before it. Hiding `/run` breaks NixOS,
  where the shell and tools live under `/run/current-system`.
- It is untested inside Claude Code's own Bash sandbox (`/sandbox`).
- Scratch directories stay in `/tmp` until the system clears it.

`bin/reviewer-guard-test` runs write attempts (including loops, wrappers,
`xargs`, hard links, `git -c`, `git config`, `git push`, and `defaults
write`), network, socket, terminal, keychain, clipboard, window server,
LaunchServices, and credential access, tampered resends, programs planted
in `PATH`, and read-only commands through the hook for real, in a
throwaway repo, under zsh and bash. It checks that the writes left no
trace, and that each write, network, and service case but two works
without the sandbox. Run it outside a reviewer session after changing the
guard.

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
