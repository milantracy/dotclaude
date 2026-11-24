# Review lenses

A lens is the objective of one `code-reviewer` instance. The self-review and
pr-review skills start several reviewers in parallel, one per lens. The
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

**`--delta` mode** (self-review called by /shipme): run correctness and
catch-all, each lens that the overlay marks as always required, and each lens
whose area the delta touches.

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
