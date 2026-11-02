# gVisor review overlay

Used by the code-reviewer agent, for both self-review and pr-review.

## Read the in-tree guidance first (source of truth)

Upstream maintains these files. Read them from the checkout under review; don't
rely on memory. To save context, read only the parts that apply to the touched
paths.

- `.gemini/styleguide.md`: the upstream review guide (priorities, checklocks,
  syscall-test expectations, hot paths, performance rules). Use it as the
  checklist.
- `AGENTS.md`: compatibility codes (`COMPATIBILITY:*`), the PR checklist, and
  rules for comments and prose.
- `CONTRIBUTING.md`: the Coding Guidelines section.
- `SECURITY.md`: for changes to the Sentry, gofer, seccomp, or host calls.
- `.agents/skills/gvisor-performance/SKILL.md`: when the diff touches a hot
  path listed in `AGENTS.md`.
- `.agents/skills/gvisor-kernel-development/SKILL.md`: when the change modifies
  kernel behavior.

If a file is missing (old branch), read it from the default branch instead.

## Security

- **Untrusted inputs:** treat all of these as attacker-controlled:
  - syscall args and app memory;
  - file contents, ioctl payloads, raw packets and TCP options;
  - user-mounted filesystems (for example a user-mounted overlay over tmpfs);
  - checkpoint images being restored;
  - the OCI spec, annotations, and environment;
  - files that the gofer serves.
- **Categories:** label every security finding with its `SECURITY.md` category.
  The boundary-crossing categories are `Escape`, `HostLeak`, `Exfil`,
  `Lateral`, `HostDoS`, and `PeerDoS`. The in-sandbox categories are
  `InternalEsc`, `InternalRead`, `SelfDoS`, and `Integrity`. Check the
  definitions in `SECURITY.md`.
- **Host syscalls and seccomp:** treat a new host syscall or a wider seccomp
  filter as at least a RED FLAG until it is justified.
- **Host FDs:** validate them, close them on every error path, and make sure
  something keeps the FD open during unlocked host I/O, so that a concurrent
  `Release()` can't close it.
- **Paths:** host, gofer, and overlay upper-layer operations must start from
  validated FDs or dentries. They must not follow untrusted symlinks or `..`.
- **Sizes:** check sizes and counters from untrusted input for wraparound, and
  bound every allocation they control.
- **`panic()` audit:** a new `panic()` that an in-sandbox action can reach is
  `SelfDoS`. This includes races on a user-mounted filesystem. Ask for an error
  return instead.

## Concurrency

- New protected fields need `+checklocks` annotations. Question every new
  `+checklocksignore` or `+checklocksforce`. Prefer a small restructuring that
  lets checklocks see the lock lifecycle.
- Trace the lock order across callers and callbacks. Look for inversions with
  existing orders (for example `Inotify.mu` → `Watches.mu` → `Inotify.evMu`).
- Drop locks before calling notifiers (`queue.Notify`), host I/O, or other
  blocking operations.
- When several cleanups or unlocks are stacked with `defer`, check that the
  reverse (last-in, first-out) order is correct.
- Register on the wait queue before checking the state, so that no wakeup is
  lost. Look for sends on closed channels.

## Linux parity

- Check Linux claims against Linux source (`path/file.c:function()`; give the
  commit when behavior depends on the version) or against a syscall test that
  passes on `native`. Man pages are not enough. Cite RFC sections for protocol
  behavior.
- Look for differences in how gVisor and Linux represent state. For example, a
  gVisor flag can be true where Linux checks both a flag and a nonzero value.
  Also check where in the state machine a helper runs, relative to validation.
- A short code comment that names the analogous Linux function is welcome.

## Tests

- App-visible behavior needs `test/syscalls/linux` tests (or packetimpact or
  packetdrill for wire behavior), not Go unit tests. Check that the test fails
  without the change.
- If Linux documents the behavior as undefined, the test must be stable on
  `native`, or gate the strict assertions on `IsRunningOnGvisor()`.
- gVisor-only features (checkpoint/restore, the `runsc` CLI, sidecars, SDKs)
  need a test that runs a real container (for example
  `runsc/container/container_test.go`), not mock-heavy unit tests.
- Flag tests that will be slow on the ptrace or systrap platforms, for example
  thousands of threads or rounds where fewer reproduce the bug.

## Performance claims

When the change claims a performance effect, or touches a hot path listed in
`AGENTS.md`, check the numbers:
- Does the delta fit the share of runtime that the change touches?
- Were both sides tuned and run with the same flags?
- Were runs interleaved (A, B, A, B) and reported as median and range?
- Were errors and short-circuited operations counted?
- Is the target work inside the timed region, and the setup outside it
  (`b.StopTimer()`/`b.StartTimer()`)?
- Does a microbenchmark win show up on a path that users see?

## Other checks
- **Compatibility code:** a compatibility fix needs a `COMPATIBILITY:*` code and
  a real-world app in the commit message or PR description.
- **Checkpoint/restore:** for new fields on saved structs, check whether they
  should be `state:"nosave"` and rebuilt in `afterLoad`. Check whether old saved
  state must still load, and whether the ordering in save/restore hooks is safe.
- **Comments:** describe the code as it is. Don't describe the bug the change
  fixes or name the callers. Replace a prose lock precondition ("mu must be
  held") with a `+checklocks` annotation.
- **runsc, shim, or containerd changes:** consider each runtime setup
  separately: k8s with the systemd or cgroupfs cgroup driver, Docker,
  standalone runsc, cgroup v1 and v2, rootless. Bugs often hide in the setup the
  author didn't test.

## Build and test commands

- `bazel test //path/to:target`, or `make test TARGETS=//path/to:target` (Docker
  wrapper).
- Syscall tests: `bazel test //test/syscalls:<name>_test_native` and
  `..._runsc_ptrace`, or `make syscall-tests TARGETS=...`.

## pr-review report conventions

- Reports go to `~/workspace/reviews/pr-<n>.md` (re-reviews:
  `pr-<n>-rev<k>.md`). Older reports may be at `~/workspace/gvisor-pr-<n>-review.md`.
- Write the "Review comments" section in ASD-STE100 Simplified Technical English:
  short sentences, one instruction per sentence, active voice, no idioms.
