# gVisor review overlay

Used by the code-reviewer agent and by the coordinator in the self-review and
pr-review skills.

## Read the in-tree guidance for your lens (source of truth)

Upstream maintains these files. Read them from the checkout under review; don't
rely on memory. Read **only the sections listed for your lens**: find a
section with Grep for its heading, then Read that range. If your `Lens:`
field names two lenses (a merged reviewer, or a pr-review lens that "also
covers" another), read the rows of both. If Grep doesn't find a heading,
list the file's headings, read the closest one, and say so under CHECKED.
Read another section only when a finding depends on it, and cite it.

| Lens | Sections |
|---|---|
| every lens | `REVIEW.md` §1 "Core Principles". |
| correctness | `REVIEW.md` Review 2. `AGENTS.md` "Modifying gVisor kernel behavior" and "Compatibility in practice" (the `COMPATIBILITY:*` codes). When the change touches save/restore: `AGENTS.md` "Filesystem checkpoint versioning" and the checkpoint rule in `.gemini/styleguide.md` "Priorities". When it modifies kernel behavior: `.agents/skills/gvisor-kernel-development/SKILL.md`. |
| tests | `REVIEW.md` Review 2 (the test parts). `.gemini/styleguide.md` "Testing". |
| design | `REVIEW.md` Review 1. `CONTRIBUTING.md` "Coding Guidelines" (it has the allowed dependencies of `core` and `runsc`). `.gemini/styleguide.md` "Coding guidelines". |
| style-description | `AGENTS.md` "gVisor code conventions" and "Git / GitHub / PR Guidelines" (stop at "Buildkite CI results"). `REVIEW.md` Review 1 (naming, comments, description). `.gemini/styleguide.md` "Style". |
| security, hardening | `REVIEW.md` Review 4. `SECURITY.md` "Security issue taxonomy" and "Attacker prerequisites". `AGENTS.md` "Security first". |
| performance (also `performance-regression`, `performance-optimization`) | `REVIEW.md` Review 3. `AGENTS.md` "Performance sensitivity". `.gemini/styleguide.md` "Performance". When the diff touches a path listed there: `.agents/skills/gvisor-performance/SKILL.md`. |
| concurrency | `REVIEW.md` Review 3 (the concurrency part). |
| docs | Nothing more. |
| catch-all | `REVIEW.md` §2 (Reviews 1 to 4). |
| free-range | `AGENTS.md` "Important gVisor subpackages" and the agent list in "Adversarial review". |
| any other lens (a free-range proposal) | The sections that the coordinator names in the `Lens:` objective. If it names none, list the headings of `REVIEW.md` and `AGENTS.md`, read the ones that match your objective, and say so under CHECKED. |
| coordinator | `REVIEW.md` "Four-Gate Verification Filter", §3, and §4, and the title of each Review in §2 (the lens objectives). `AGENTS.md` "Performance sensitivity" (the hot paths, to choose the lenses), "Git / GitHub / PR Guidelines", and "Adversarial review". For a free-range proposal that you start, name its sections in the `Lens:` objective. |

If a file is missing (old branch), read it from the default branch instead. If
this overlay and an in-tree file disagree on what to check or on a severity,
the in-tree file wins. The review process (who reviews, gates, rounds) follows
the kit, with the deviations below. For Gates 1-3 and the review-comment
format, the `REVIEW.md` text refines the kit's generic version (for example,
its list of untrusted boundaries for Gate 1).

## Deliberate deviations from `AGENTS.md` and `REVIEW.md`

The kit keeps these on purpose. They are not conflicts to resolve in favor of
the in-tree files:
- **Read-only reviewers.** `AGENTS.md` lets reviewer agents edit code in
  their own worktree. Our reviewers stay read-only, and the coordinator runs
  Gate 4 (see `coordinator.md`).
- **Round cap.** `AGENTS.md` asks the human after the tenth round. The kit's
  cap (see the self-review skill) is lower.
- **Benchmarks.** `AGENTS.md` has the coordinator run benchmarks after a
  fix that may change performance. The kit runs benchmarks only with the
  user's permission (the `benchmark` skill and /shipme's benchmark gate).
- **Context for the correctness lens.** `AGENTS.md` starts every sub-agent
  with minimal context. The kit gives the correctness reviewer a blind brief
  (the problem, not the solution) and then the author's reasoning, so that
  it forms its own root cause first and then verifies the author's claims.
  Every reviewer also gets the risk tier.
- **Gate failures are argued, not dropped.** `REVIEW.md` drops findings that
  fail Gates 1-3. The kit argues them with the reviewer first, which is the
  `AGENTS.md` rule ("do not reject a finding unless the sub-agent agrees").
  NITs are the exception (below).
- **Merged reviewers below the High tier.** `AGENTS.md` lists security and
  security hardening, the two performance agents, and stylistic and
  documentation as separate agents. Below High, the kit gives each pair to
  one reviewer with both objectives (see "Lenses"). `AGENTS.md` itself says
  to scale the number of sub-agents to the size and risk of the change.
- **Smaller follow-up rounds.** `AGENTS.md` says that some agents must be
  present for any change. The kit runs the full set in round 1 only (of a
  `--delta` review too, for what the delta touches). Later rounds run the
  follow-up set in `lenses.md`, so any agent but correctness and catch-all
  (stylistic, free-range, testing, security, hardening, performance,
  documentation) can be absent from them.
- **NITs are not argued.** The coordinator settles each NIT without asking
  its reviewer (`coordinator.md`, "Arguing"), and lists the ones it left
  for the user.
- **Sections, not whole files.** Each reviewer reads only the in-tree
  sections for its lens (the table above).

## Risk tiers

Use the tiers in `REVIEW.md` §3 (Low, Medium, High) instead of the kit
defaults. They set the depth of the security and performance lenses.

## Lenses

Use these sets instead of the kit defaults. Give each reviewer the lens name
and the matching objective from `AGENTS.md` or `REVIEW.md`.

**self-review** (our own changes): the "Adversarial review" set in `AGENTS.md`.

| `AGENTS.md` agent | Kit lens | When |
|---|---|---|
| correctness | correctness | always |
| stylistic | style-description | always |
| catch-all | catch-all | always |
| free-range | free-range | always |
| testing exhaustivity | tests | unless the change only touches tests, build infra, or docs |
| security | security | any Sentry, gofer, `runsc`, or seccomp change |
| security hardening | hardening | any Sentry, gofer, `runsc`, or seccomp change |
| performance regression | performance, labeled `performance-regression` | any Sentry, gofer, or `runsc` change, or a hot path in `AGENTS.md` |
| performance optimization | performance, labeled `performance-optimization` (a separate reviewer at the High tier) | same as performance regression |
| documentation | docs | when the change can make docs wrong |
| (`REVIEW.md` Review 1) | design | any change with non-test code |

Add **concurrency** (`REVIEW.md` Review 3, concurrency part) when the change
touches locks, wait queues, or goroutines. Run a conditional lens when its
condition holds, at every tier. If you are not sure, run it.

**Merged reviewers (self-review, Low and Medium tier):** when both lenses
of a pair apply, start one reviewer for the pair (`lenses.md`, "Merged
reviewers"):

| Label | Lenses |
|---|---|
| `security` | security + hardening |
| `performance` | `performance-regression` + `performance-optimization` |
| `style-docs` | style-description + docs |

At the High tier, start each lens as its own reviewer.

**Rounds 2 to 5:** use the follow-up set in `lenses.md`, not the
self-review lens table. Judge a lens's area by what the fix changes (the
examples in `lenses.md`), not by the "When" column: a fix in a Sentry file
doesn't by itself bring back the security or performance reviewers. The
pairs stay merged below High.

**`--delta` mode:** round 1 uses the self-review lens table, with the "When"
column applied to the delta (`lenses.md`, "`--delta` mode").

**pr-review** (other people's PRs): the protocol in `REVIEW.md` §2.

| `REVIEW.md` review | Kit lens |
|---|---|
| Review 1: architecture, YAGNI, naming, comments, description | design (also covers style-description) |
| Review 2: correctness, error integrity, Linux parity, tests | correctness (also covers tests) |
| Review 3: performance, benchmarking, concurrency | performance (also covers concurrency) |
| Review 4: security and isolation boundaries | security (also covers hardening) |
| unanchored catch-all | catch-all |

Pass each lens as the table names it, for example `Lens: design (also covers
style-description): <objective>`, so that the reviewer reads the sections of
both. Run all five at every tier. The tier sets the depth (for Low, the security
lens only confirms that no isolation boundary is affected). Add **docs** when
the change alters behavior that the documentation describes.

Context override for pr-review: the design lens gets the PR description and
commit messages, because Review 1 checks them.

## Severity

Map upstream labels to ours. In draft PR comments, use the upstream labels.

| Ours | Upstream |
|---|---|
| BLOCKER, RED FLAG | `Blocking` (an upstream `Blocking` floor means BLOCKER) |
| MINOR | `Minor` |
| NIT | `Nit` |
| QUESTION | ask as a question, no label |

When `REVIEW.md` gives a label for a kind of problem, that label is the floor.
For example: ignored errors, a `panic()` that untrusted input can reach,
regex or substring parsing of structured data, and tests that pass without
the fix are at least BLOCKER. Claims about safety or scale that nothing
enforces, abstractions with one implementation, options nobody asked for,
nested error checks that fall through, names tied to the diff, and comments
that only make sense next to the diff are at least MINOR. These are not style
nits.

## Security (in addition to `REVIEW.md` Review 4)

- **Attacker and impact:** label every security finding with the attacker
  prerequisite and the impact category (both lists are in `REVIEW.md`
  Review 4 and `SECURITY.md`).
- **Compromised Sentry:** can a compromised Sentry do more after the change
  than before it?
- **Host syscalls and seccomp:** a new host syscall or a wider seccomp filter
  is at least a RED FLAG until it is justified.

## Concurrency (in addition to `REVIEW.md` Review 3)

- Trace the lock order across callers and callbacks. Look for inversions with
  existing orders (for example `Inotify.mu` → `Watches.mu` → `Inotify.evMu`).

## Linux parity

- The evidence for Linux behavior is a syscall test that passes on `native` (or
  packetimpact or packetdrill for wire behavior). Don't read or cite Linux
  source or man pages (`.agents/skills/gvisor-kernel-development/SKILL.md`; for
  Linux behavior it wins over `.gemini/styleguide.md` and over `REVIEW.md`
  Review 2, which allow public documentation). A claim with no syscall test
  behind it stays at level 1 on the evidence ladder.
- Cite RFC sections for protocol behavior.
- **Code comments** may cite Linux UAPI or ABI definitions and RFC
  sections. They must not cite Linux source functions (`AGENTS.md`:
  references to Linux source are limited to ABI). The in-tree files disagree
  on man pages: the `REVIEW.md` keep-list allows "public Linux
  documentation", and the kernel skill says not to "refer to" man pages. This
  overlay follows the stricter kernel skill, so ask authors to remove
  man-page references too.

## Tests (in addition to `REVIEW.md` Review 2)

- Gate 4 targets: list the syscall test targets
  (`//test/syscalls:<name>_test_native` and `..._test_runsc_ptrace`) and the
  Go test targets. Only `*_runsc_*` targets and Go tests must fail with the
  production change reverted. `_test_native` targets run on host Linux, so
  they must pass both with and without the change: they show that the test
  matches Linux.
- Gate 4 test files: `*_test.go`, everything under `test/`, and `BUILD`
  files count as tests (don't revert them). If a `BUILD` file also changes a
  production rule, revert that hunk too.

## Performance claims

Check the 7 benchmark questions in `REVIEW.md` Review 3.

## Other checks

- **Compatibility code:** a compatibility fix needs a `COMPATIBILITY:*` tag in
  the commit message or PR description, and a real-world app where the tag
  requires one (`AGENTS.md`).
- **Checkpoint/restore:** check whether old saved state must still load,
  whether the format version must be bumped (`.gemini/styleguide.md`), and
  whether the ordering in save/restore hooks is safe.
- **runsc, shim, or containerd changes:** consider each runtime setup
  separately: k8s with the systemd or cgroupfs cgroup driver, Docker,
  standalone runsc, cgroup v1 and v2, rootless. Bugs often hide in the setup the
  author didn't test.

## Build and test commands

The coordinator runs these (in Gate 4, through the `fail-first-checker`
agent). The reviewer's sandbox has no Docker, no network, and no writable
bazel output root, so a reviewer puts the targets in its `GATE4` plan
instead of running them.

- `bazel test //path/to:target`, or `make test TARGETS=//path/to:target` (Docker
  wrapper).
- Syscall tests: `bazel test //test/syscalls:<name>_test_native` and
  `<name>_test_runsc_ptrace`, or `make syscall-tests TARGETS=...`.
- **Worktree cleanup:** run `make bazel-shutdown` in a worktree before you
  delete it (Gate 4 worktrees, pr-review worktrees).

## pr-review report conventions

- Reports go to `~/workspace/reviews/pr-<n>.md` (re-reviews:
  `pr-<n>-rev<k>.md`). Older reports may be at `~/workspace/gvisor-pr-<n>-review.md`.
- Follow `REVIEW.md` §4 for the top-level comment. For Medium- and High-tier
  PRs, add a 1–4 sentence `**Security:**` summary of the boundary and impact
  assessment.
- Write the "Review comments" section in ASD-STE100 Simplified Technical English:
  short sentences, one instruction per sentence, active voice, no idioms.
