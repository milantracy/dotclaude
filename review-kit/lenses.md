# Review lenses

A lens is the objective of one `code-reviewer` instance. The self-review and
pr-review skills start several reviewers in parallel, one per lens (a lens
set can give two or more lenses to one reviewer; see "Merged reviewers"). The
coordinator merges their findings (see `coordinator.md`).

Every reviewer is a full agent run that reads the diff again, so the sets
below stay small: a lens gets its own reviewer only where the tier pays for
it.

A project overlay can replace the risk tiers, the lens sets, the context
table, and the lens objectives. The lens names in the catalog stay the shared
vocabulary. Where the overlay is silent, this file applies.

## Lens catalog

Pass the name and the objective in the reviewer's `Lens:` field. Use the
overlay's objective if it gives one, else the objective here.

- **correctness**: the change does what it must do. Look for logic bugs,
  missed cases, code that doesn't match its comments, error paths that leave
  state behind, and a root cause that the fix only hides.
- **tests**: missing test cases. Each new branch and each term of a new
  condition needs a test that fails without it. Tests must check real
  behavior, not mocks. List the tests that should fail without the change
  (for Gate 4).
- **security**: ways to break or bypass the security of the change: untrusted
  inputs, permission checks, races, and new powers for a compromised component.
- **hardening**: ways to make the change more secure: safer APIs and flags,
  narrower privileges, tighter filters.
- **performance**: regressions on hot paths (allocations, extra syscalls or
  round trips, startup work, binary size, lock contention) and real
  optimizations the change misses.
- **concurrency**: lock order, locks held across blocking calls, unprotected
  fields, lost wakeups, and defer or cleanup order.
- **design**: the shape of the change. Look for abstractions with only one
  implementation, options nobody asked for, duplicate mechanisms, dead code,
  hard-to-follow control flow, names tied to the diff, a smaller fix, and a
  change that should be split.
- **style-description**: project conventions that tools don't enforce
  (comments, naming, references) and whether the commit message or PR
  description is accurate, motivated, and names every secondary change.
- **docs**: existing documentation that the change makes wrong. Report only
  documentation that is now wrong. Don't propose new caveats.
- **catch-all**: no special objective. Review the change in general with the
  full method. It also gets the list of the round's lenses (`Lenses this
  round:`) and can name a lens that is missing from it, in a `PROPOSED
  LENSES:` block (one line each: name, objective, reason), not in the
  findings. It proposes a lens only for a risk it can point to in the diff.

## Risk tiers

The coordinator classifies the change before it starts the reviewers:

- **Low**: docs, comments, tests, build rules, static-analysis annotations
  that don't change behavior, or small internal fixes that don't change
  behavior that users or other components can see.
- **Medium**: normal behavior changes or resource management changes.
- **High**: security boundaries, privilege, parsing of untrusted data, unsafe
  code, or the architecture of a hot path.

## Default lens sets

Both skills use these sets, unless the overlay gives its own.

| Tier | Lenses |
|---|---|
| Low | correctness, `catch-all` (catch-all + style-description) |
| Medium | correctness, tests, `design` (design + style-description), catch-all, `performance` (performance + concurrency; only if the change touches a hot path, locks, threads, or async tasks) |
| High | correctness, tests, design, style-description, catch-all, security, hardening, performance (if it touches a hot path), concurrency (if it touches locks, threads, or async tasks) |

A backticked label is one merged reviewer (see "Merged reviewers"). That is
2 reviewers at Low, 4 or 5 at Medium, and 7 to 9 at High (10 with docs).

When the change alters behavior that the documentation describes, add the
**docs** objective to the reviewer that has style-description. At High,
docs is a reviewer of its own.

## Follow-up set

self-review uses this set, not the full set, for every round after the
first, and for every round of a `--delta` review. The full set ran in
round 1 (for a `--delta` review, in the earlier review), and a reviewer that replied CLOSED to a fix has checked it. The
bullets cover what that leaves out.

- One `correctness` (correctness + catch-all) reviewer, always. It runs a
  single pass: no `Stage: blind` line, and the blind brief and the reveal
  text together in its brief, as claims to verify. Exception: when the
  round before ended with the root cause DIFFERS, or the fixes changed the
  approach, start correctness and catch-all as two reviewers, as in round
  1 of a full review (correctness blind, then the reveal). This is the
  only place that says which form a round uses; the skill follows it.
- Each lens whose area the fixes touch. The fixes are the changes between
  the two rounds (`git diff <T of the round before> <T of this round>`; in
  series mode, the commit that each of the two rounds ended at), without the
  NIT fixes. Judge the
  area by what the fixes do, not by the files they are in. For example:
  security when a fix changes a check on untrusted input, concurrency when
  it touches a lock, tests when it adds a branch or changes test logic,
  style-description when a fix changes comments or names, or when the
  description changes in more than wording.
- Each lens with a finding above NIT from the round before that ended
  DISPUTED, or whose fix its reviewer did not check (a fix that the user
  decided, or a fix for a finding with no reviewer, such as a `gate4` or
  built-in one: use the lens that covers the finding).
- Each lens that this review started and whose reviewer has not completed
  a round (it failed twice; `coordinator.md`, "Reviewers").
- At the High tier, each lens that had a BLOCKER or RED FLAG in the round
  before.

Classify the tier again when the fixes change what the change touches (for
example, a fix adds parsing of untrusted data). If the tier rises, give the
new tier in the briefs, use it for the rules above and for the
merged groups, and add each lens of the new tier's full set that has not run
yet.

Lenses that shared a reviewer in round 1 share one again when the fixes
touch more than one of them; leave the untouched lenses of the group out.
A lens that round 1 merged into catch-all joins the `correctness` reviewer.

List the lenses left out, as for any lens not run. An overlay can change
this set.

## `--delta` mode

A `--delta` review (self-review called by /shipme) covers changes made after
the last review, which no reviewer has read. Treat the delta as a change of
its own: classify its tier, and start the follow-up set in every round, with the delta in
the place of "the fixes" (in round 1, `git diff <delta tree> <T1>`). The
delta is usually small, and the full set already read the rest of the
change. The earlier review's tier and reviewer groups are not recorded,
so group the lenses as the delta's own tier does, and in round 1 don't
apply the tier-rise rule or the blind-pass exception of the follow-up
set. Instead: if the delta alone classifies as High, changes the
approach of the change, or is larger than the change the stamp covers
(`git diff --shortstat` of each), tell the user and run self-review
without `--delta`, on the whole change from the merge-base.

## Merged reviewers

A lens set (here or in an overlay) can give two or more lenses to one
reviewer. Pass them all in the `Lens:` field (`Lens: <label> (<lens 1> +
<lens 2>): <objective 1>; <objective 2>`), give the reviewer the context of
each lens, and use the label in the ledger.

## Context per lens

Reviewers anchor on what they are told, so give each reviewer as little
context as it needs.

| Lens | self-review | pr-review |
|---|---|---|
| correctness | round 1 of a full review: the blind brief (all fields in self-review section 2), then the reveal. Follow-up set: both in the brief | the PR description, commit messages, and linked issue, as claims to verify |
| style-description | the draft commit message | the PR description and commit messages |
| catch-all | `Lenses this round: <labels>` | `Lenses this round: <labels>` |
| all others | nothing beyond the base brief | nothing beyond the base brief |

The base brief is `Repo`, `Diff`, `Overlay`, `Lens`, `Tier`, and `Checkout`
(`matches` when the repo's checkout is the diff end, else `differs`). `Tier` is
the risk tier that the coordinator chose; reviewers don't classify it again.
Give more context only while arguing about a finding (for example, to explain
scope).
