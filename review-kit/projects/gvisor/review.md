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

## Additional checks

- **Trust boundary:** everything from the sandboxed app is untrusted: syscall
  args, app memory, file contents, ioctl payloads, packets. Treat new host
  syscalls or seccomp filter changes as at least a RED FLAG until they are
  justified.
- **Linux claims:** check against Linux source (file and function; the commit
  when behavior is version-dependent) or against a syscall test that passes on
  `native`. Man pages are not enough.
- **Tests:** app-visible behavior needs `test/syscalls` tests (or packetimpact
  or packetdrill for wire behavior), not Go unit tests. Check that the test
  fails without the change.
- **Compatibility code:** a compatibility fix needs a `COMPATIBILITY:*` code and
  a real-world app in the commit message or PR description.
- **Checkpoint/restore:** for new fields on saved structs, check whether they
  should be `state:"nosave"` and rebuilt in `afterLoad`. Check whether old saved
  state must still load, and whether the ordering in save/restore hooks is safe.
- **Locking:** new protected fields need `+checklocks` annotations. Question
  every new `+checklocksignore` or `+checklocksforce`.
- **Comments:** describe the code as it is. Don't describe the bug the change
  fixes or name the callers.
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
