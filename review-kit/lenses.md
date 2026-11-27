# Review lenses

A lens is the objective of one `code-reviewer` instance. The self-review and
pr-review skills start several reviewers in parallel, one per lens (an
overlay can give two lenses to one reviewer; see "Merged reviewers"). The
coordinator merges their findings (see `coordinator.md`).

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
- **free-range**: decide which other lenses would be worth running for this
  change, and why. Put them in a `PROPOSED LENSES:` block (one line each:
  name, objective, reason), not in the findings.
- **catch-all**: no special objective. Review the change in general with the
  full method.

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
| Low | correctness, style-description, catch-all |
| Medium | Low + tests, design, concurrency (if the change touches locks, threads, or async tasks), performance (if it touches a hot path) |
| High | Medium + security, hardening, free-range |

Add **docs** when the change alters behavior that the documentation describes.

## Follow-up set

self-review uses this set, not the full set, for rounds 2 to 5 of a review
(a `--delta` review too). The full set ran in round 1, and a reviewer that
replied CLOSED to a fix has checked it. The bullets cover what that leaves
out.

- **correctness** and **catch-all**, always.
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
- Each lens of the full set whose reviewer has not completed a round (it
  failed twice; `coordinator.md`, "Reviewers").
- At the High tier, each lens that had a BLOCKER or RED FLAG in the round
  before.

Classify the tier again when the fixes change what the change touches (for
example, a fix adds parsing of untrusted data). If the tier rises, give the
new tier in the briefs, use it for the rules above and for an overlay's
merged pairs, and add each lens of the new tier's full set that has not run
yet.

List the lenses left out, as for any lens not run. An overlay can change
this set.

## `--delta` mode

A `--delta` review (self-review called by /shipme) covers changes made after
the last review, which no reviewer has read. Treat the delta as a change of
its own: classify its tier, and in round 1 start the full lens set that the
tier table, or the overlay, gives for what the delta touches. Its later
rounds use the follow-up set.

## Merged reviewers

An overlay can give two lenses to one reviewer. Pass both in the `Lens:`
field (`Lens: <label> (<lens 1> + <lens 2>): <objective 1>; <objective
2>`), give the reviewer the context of both lenses, and use the label in
the ledger.

## Context per lens

Reviewers anchor on what they are told, so give each reviewer as little
context as it needs.

| Lens | self-review | pr-review |
|---|---|---|
| correctness | blind brief (all fields in self-review section 2), then the reveal | the PR description, commit messages, and linked issue, as claims to verify |
| style-description | the draft commit message | the PR description and commit messages |
| all others | nothing beyond the base brief | nothing beyond the base brief |

The base brief is `Repo`, `Diff`, `Overlay`, `Lens`, `Tier`, and `Checkout`
(`matches` when the repo's checkout is the diff end, else `differs`). `Tier` is
the risk tier that the coordinator chose; reviewers don't classify it again.
Give more context only while arguing about a finding (for example, to explain
scope).
