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

Reviewers are read-only, so the coordinator runs Gate 4, once per round. Don't
run it while a benchmark runs.

Inputs:
- `<fork>`: what the change starts from. The skill gives it.
- `<end>`: what is under review. A commit (pr-review head, or one commit of a
  series), or a tree hash from `review-stamp tree`.
- `<targets>`: the union of the `must-fail` and `must-pass-both` lists in
  the `GATE4` plans. Fall back to the build or lint only when the change has
  no tests and touches no tested code (for example, docs only), and say so.

Steps (shell state doesn't persist between tool calls: record the literal
values of `C` and `W`, and substitute them in later commands):

```
# If <end> is a commit:
C=<end>
# If <end> is a tree (no ref, no index change):
C=$(git commit-tree <end> -p HEAD -m review)
# Worktree: create it on the first run of the review, then reuse it.
W=$(mktemp -d /tmp/review-gate4-XXXXXX)
git worktree add --detach $W $C
#   later rounds: git -C $W checkout --detach --force $C && git -C $W clean -fd
# 1. Run <targets> in $W with the overlay's test command
#    (else the repo's usual one).
git -C $W diff --binary --no-renames <fork> $C -- <production files> \
  > $W.patch
git -C $W apply -R $W.patch              # must succeed
git -C $W status --porcelain             # must not be empty
# 2. Run <targets> again.
# 3. Restore $W right away, every round, even if step 2 failed:
git -C $W checkout --detach --force $C && git -C $W clean -fd && rm -f $W.patch
# 4. Once, when the review ends: run the overlay's worktree cleanup in $W,
#    then remove it.
git worktree remove --force $W
```

Production files are the changed files that aren't tests. List them with
`git diff --name-only --no-renames <fork> $C`, so that a renamed file appears
under both its old and its new path. If the overlay says how to tell tests
apart, use that. Pass each path as its own argument (in zsh, an unquoted
variable is one argument).

- **Test-only change** (no production files): skip the revert and step 2;
  with an empty path list the diff would revert the tests too. The targets
  must pass with the change.
- **Failed revert:** if the patch is empty, `apply` fails, or `status` shows no
  change, don't run step 2. Run step 3, then fix the plan.
- **Existing worktree:** a skill can give an existing worktree of `<end>` as
  `$W` (pr-review gives its head worktree, which the reviewers also read). Skip
  `worktree add` and step 4. Don't message reviewers between the revert and
  step 3, so that no one reads the reverted tree.

Reusing one worktree lets later rounds reuse the build output.

Results:
- New and changed tests must fail without the change, for the expected
  reason, and pass with it. Refactors must pass both ways. An overlay can
  name targets that must pass both ways.
- A BLOCKER (source `gate4`): a target that fails with the change, or a new
  test that passes without the production change it claims to test.
- A failure without the change for an unrelated reason (setup, a build error
  in code the change doesn't touch) proves nothing. Fix the plan and run it
  again.
- A build failure because a test uses a symbol that the change adds counts as
  the expected failure. Say so in the ledger.

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
