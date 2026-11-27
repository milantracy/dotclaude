# reviewer-guard

`reviewer-guard` is a PreToolUse hook that the `code-reviewer` agent runs before
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

`reviewer-guard-test` runs write attempts (including loops, wrappers,
`xargs`, hard links, `git -c`, `git config`, `git push`, and `defaults
write`), network, socket, terminal, keychain, clipboard, window server,
LaunchServices, and credential access, tampered resends, programs planted
in `PATH`, and read-only commands through the hook for real, in a
throwaway repo, under zsh and bash. It checks that the writes left no
trace, and that each write, network, and service case but two works
without the sandbox. Run it outside a reviewer session after changing the
guard.
