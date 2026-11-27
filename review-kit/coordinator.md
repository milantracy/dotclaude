# Coordinator rules

The self-review and pr-review skills both use these rules. The main session is
the coordinator. It starts the reviewers, merges their findings, verifies them,
and argues with the reviewers. Each skill states only how it differs.

## Reviewers

- Start all reviewers of a round **in one message**, so that they run in
  parallel.
- **Don't edit the checkout** until every reviewer of the round has returned,
  including the second batch and the reveal reply. If you must, give
  `Checkout: differs` to any reviewer that you start or message after the
  edit.
- If a reviewer fails, start it again once. If it fails again, list it as not
  run, with the reason.
- **free-range** proposals are not findings. They come in the reviewer's
  `PROPOSED LENSES:` block. Start the proposed lenses that you agree with as a
  second batch in the same round, and wait for them before Gate 4. Write each
  proposal that you decline, and why, in the ledger.
- Give each reviewer only the context in the `lenses.md` table, or in the
  overlay's version of that table. **Don't give reviewers earlier findings**,
  so that they don't anchor on them. The only exception is self-review's
  `Already settled` line (see that skill).
- A reviewer that asks for a benchmark (a QUESTION finding) gets an answer from
  the user, not from you: ask whether to run the `benchmark` skill. Don't start
  a benchmark without permission.

## Ledger

Give every finding a global ID, `r<round>.<lens>.F<n>` (for example
`r2.security.F2`; pr-review has one round, `r1`). If a finding repeats one from
an earlier round, link it to the earlier ID. When two reviewers share a lens,
give each a distinct label (for example `performance-regression`) and use the
label instead of the lens name. A finding with no reviewer uses its source in
place of the lens (`r1.gate4.F1`, `r1.threads.F1`, `r1.builtin.F1`). Merge
duplicates across lenses into one entry, but keep every source, so that you can
answer each reviewer.

Columns: `ID | lens(es) | severity | outcome | one-line note`. Outcomes:
- FIXED.
- REJECTED: the reviewer agreed that the finding doesn't hold.
- DISPUTED: still open after the exchange limit, at any severity.
- LEFT: a MINOR or NIT that was not fixed, and its reviewer agreed that it
  can stay for now (CLOSED). Without that agreement it is DISPUTED. List it
  for the user.
- DROPPED: a finding with no reviewer subagent behind it (for example, from
  the built-in reviewer) that failed your check. Give the reason.
- DUPLICATE (pr-review): the finding repeats feedback that is already on the
  PR.
- REPORTED (pr-review): the finding is verified and goes into the report.

A finding counts as settled when it is REJECTED, DISPUTED, or LEFT.

## Four gates

Apply them to every finding. An overlay can change the wording (for example,
list the project's untrusted boundaries for Gate 1).

- **Gate 1, evidence:** the finding cites a `file:line` that the change adds or
  modifies, or is about the whole change. A finding on an untouched line also
  passes when its scenario names the changed line that makes the problem
  reachable or worse. A "redundant check" finding fails this gate when the check
  guards untrusted input or does required cleanup.
- **Gate 2, test doubles:** a flagged mock is really empty or excessive, not a
  needed seam around the network, elevated privileges, or behavior that isn't
  deterministic.
- **Gate 3, precedent:** check sibling files and callers. A flagged pattern must
  break local conventions, not follow them. A proposed split must leave slices
  that each build and pass tests.
- **Gate 4, tests with and without the change:** see below.

A finding that fails Gate 1, 2, or 3 isn't dropped silently. Argue it with its
reviewer (see "Arguing").

## Gate 4

Reviewers are read-only, so the coordinator runs Gate 4, once per round,
through the `fail-first-checker` agent. The agent runs the targets in a
worktree with the change and with the production files reverted, and
returns one verdict per target; the test logs stay in its context. Don't run
it while a benchmark runs.

Inputs:
- `<fork>`: what the change starts from. The skill gives it.
- `<end>`: what is under review. A commit (pr-review head, or one commit of a
  series), or a tree hash from `review-stamp tree`.
- `<targets>`: the union of the `must-fail` and `must-pass-both` lists in
  the `GATE4` plans, each with the finding or lens it came from (`overlay`
  for a target the overlay requires). Use a `fallback` (the build or lint)
  only when the change has no tests and touches no tested code (for
  example, docs only), and say so.

Start the agent (Agent tool, `subagent_type: "fail-first-checker"`) with
the brief below (the agent's Inputs section defines each field), and wait
for its report before you edit the checkout or message a reviewer (it may
revert a worktree they read):

```
Action: run
Repo: <abs path of the user's repository>
Fork: <fork>
End: <end>
Worktree: create | <$W from an earlier round> | given <path>
Overlay: <abs path(s), or "none">
Test command: <the overlay's, else the repo's usual one>
Production files: compute   (or a list, only to fix a plan problem)
Revert hunks: <file>: <which hunks or lines>   (from the plans, if any)
Targets:
  must-fail: <target> (<source>) ...
  must-pass-both: <target> (<source>) ...
  fallback: <build or lint command>   (only instead of the two lists)
```

- **Worktree:** `create` on the first run; the report gives `$W`. Pass that
  path in later rounds, so they reuse the build output. pr-review gives its
  head worktree as `given <path>` (the reviewers read it too). If that
  worktree is at the wrong commit (pr-review after a force-push), move it
  to `<end>` first with `git -C <path> checkout --detach --force <end>`.
- **Plan problems:** the report lists them (a failed revert, a missing
  target, mixed test and production hunks it couldn't split, an unrelated
  failure). Fix the plan (for example with `Revert hunks:`, which can name
  hunks or lines, or a given `Production files:` list) and start the agent
  again.
- **Restore:** run the agent's step-3 restore yourself (`git -C $W reset
  --hard && git -C $W clean -fd && rm -rf $W.gate4`) before you message a
  reviewer or start the agent again, if any of these happens: the report
  says `Restore: FAILED`, the agent died before it reported, or it found a
  given worktree dirty.
- **Cleanup:** when the review ends, start the agent with `Action:
  cleanup`, `Repo`, `Overlay`, and `Worktree: <$W from the last report>`
  (not for a given worktree). If a run died before it reported `$W`, look
  for its worktree in `git -C <repo> worktree list` (a path containing
  `review-gate4-`, created during this review; macOS lists it under
  `/private/tmp`) and clean it up the same way. If another review may be
  running in the same repo, ask the user before you remove it.
- If the agent fails twice, follow its steps
  (`~/.claude/agents/fail-first-checker.md`) yourself and say so in the
  report.

The agent defines what each verdict means. Map them to the ledger:
- `OK` for every target: Gate 4 passes. For each must-fail row that ran
  without the change (not `skipped`), check that its failure excerpt
  matches what its finding expects; if not, treat the row as `PLAN`. Copy
  the agent's notes (such as "uses a new symbol") into the ledger.
- `FAILS-WITH-CHANGE` or `PASSES-WITHOUT`: a BLOCKER, source `gate4`.
- `BROKE-WITHOUT`: a RED FLAG at least, source `gate4`. Send it to the
  reviewer whose plan named the target; for an `overlay` target, check it
  yourself.
- `PLAN`: fix the plan and run it again, with only the `PLAN` targets and
  the ones the fix affects. A target with the note "same build unit as a
  new test" can't run without the change: drop a must-pass-both one from
  the plan and say so in the ledger; record a must-fail one as unproven
  (below). If no plan fix applies (for example the target is flaky or
  broken at the fork), don't rerun: record the row as unproven in the
  ledger, and give it to the target's reviewer, or to the user for an
  `overlay` target.

## Arguing

- Send each reviewer only its own findings, with SendMessage, with your
  evidence or the fix.
- A finding from a reviewer subagent is rejected only when its reviewer
  agrees (CLOSED).
- Argue at most three exchanges per finding. If the finding is still OPEN, the
  skill decides what happens next.
- If a finding is out of scope, give its reviewer more of the scope and intent.
- If a finding repeats one that an earlier round settled, give the reviewer the
  earlier arguments and ask whether they still hold.
