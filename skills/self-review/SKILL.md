---
name: self-review
description: Review the changes we made with several independent reviewer subagents that start with no context, each with one lens (correctness, security, tests, design, ...), scaled to the risk of the change. The correctness reviewer first forms its own view from the problem alone (blind), then sees our reasoning and checks it. We act as coordinator. We merge findings, verify them through four gates (including running the tests with and without the change), fix or argue each one, and start fresh reviewers each round until the skill's stop rule is met (at most 5 rounds). Asks the user to decide disputed blockers, red flags, and questions. Records an approval stamp that /shipme checks. Use when a change is done ("review my changes", "self-review", "check this before shipping"). Not for other people's PRs; use pr-review for those.
argument-hint: "[base-ref | commit | range] [--delta <tree>] [--with-builtin]"
---

# Self-review

You are the **author** and the **coordinator**. You fix things or argue with
evidence. The **reviewers** are fresh `code-reviewer` subagents that know
nothing about this conversation, one per lens. Kit: `~/.claude/review-kit/`.
Read these kit files first:
- `README.md`: overlay detection.
- `lenses.md`: the lens catalog, risk tiers, lens sets, and context per lens.
- `coordinator.md`: the ledger, the four gates, how to run Gate 4, and the
  rules for arguing.

## 1. Set up

- **Diff range:**
  - Default: from `git merge-base HEAD <upstream default branch>` to the current
    working tree, including uncommitted and untracked files.
  - With an argument: use that base, commit, or range. For a numbered series,
    review one commit at a time; see "Series mode" below.
  - With `--delta <tree>` (passed by /shipme): diff from that tree to the
    current working tree.
- **Series mode** (`<sha>~1..<sha>`):
  1. The end of each round is that commit, not a tree snapshot.
  2. Ask the user once before the first history rewrite. Require a clean
     working tree (or stash only with the user's consent).
  3. Fold fixes into the commit. If it is not HEAD, stop at it first:
     `GIT_SEQUENCE_EDITOR="sed -i -E '1s/^(pick|p) /edit /'" git rebase -i
     <sha>~1`, then check that `git rev-parse HEAD` equals `<sha>`; if not,
     abort the rebase.
     Make the fixes, then amend without the user's sign-off (a plain
     `--amend` can keep the old message silently when `GIT_EDITOR` is set):
     ```
     git add -u; git add -- <new files of the fix>
     git status --porcelain    # must show only the files you meant to change
     me="Signed-off-by: $(git config user.name) <$(git config user.email)>"
     git log -1 --format=%B | grep -vxF "$me" | git commit --amend -F -
     git rev-parse HEAD    # record: this is the next round's end
     ```
     Then `git rebase --continue` if you started a rebase. On a rebase
     conflict, abort the rebase, give the user the recorded commit (it
     stays in the reflog), and ask how to proceed.
  4. This follows /shipme's "No sign-off" rule (`skills/shipme/SKILL.md`). List
     the commit in the report as needing the user's sign-off.
  5. The recorded commit is the next round's end (after `--continue`, HEAD
     is the series tip, not this commit).
- **Snapshots:** take `T=$(~/.claude/review-kit/bin/review-stamp tree)` at the
  start of each round (`T1`, `T2`, ...) and after each set of fixes (`T_next`).
  `T_prev` is the tree that the reviewer last read. Reviewers diff against tree
  hashes (`git diff <base> <T_k>`), so later edits don't shift the ground under
  them.
- **Overlay:** detect it from the kit README. Collect absolute paths to
  `projects/<name>/review.md`.
- **Risk tier and lenses:** classify the change and pick the lens set (overlay,
  else `lenses.md`; for `--delta`, see `lenses.md`). Write down each lens you
  will **not** run and why; the report needs it.
- **Context:** write the blind brief (section 2) from the conversation, the
  issue, and the commits. Ask the user only for parts you really can't fill in.
- **Commit message:** if no draft exists yet, draft it now. The
  style-description lens and the reveal need it; /shipme reuses it. Keep issue
  IDs (`#123`, `Fixes #123`, `Updates #123`) out of it; the user tags the issue
  in the PR body.

## 2. Round 1: parallel blind pass

Spawn all reviewers in one message (Agent tool, `subagent_type:
"code-reviewer"`, one call per lens). Each gets the base brief:

```
Repo: <abs path>
Diff: git diff <base> <T_k>        (<n> files, +A/-D)
Overlay: <abs path(s), or "none: use in-repo AGENTS.md/CONTRIBUTING.md">
Lens: <name>: <objective from the overlay, else from the lens catalog>
Tier: <Low | Medium | High>
Checkout: <matches | differs>
```

Add only what the context table in `lenses.md` (or the overlay) gives each lens.
The **correctness** reviewer also gets:

```
Stage: blind

Intent: <one or two sentences: what the change must achieve>
Problem: <what is wrong or missing today, as observed: symptoms, error text,
          failing test, user report>
Evidence: <issue/bug link, repro steps or command, relevant log or stack
          trace excerpts>
Expected behavior: <what must be true after the change; acceptance criteria>
Scope: <what this change covers; what is deliberately left for later>
Constraints: <compatibility, performance, platforms or runtime setups that
          must keep working, APIs or formats that must not change>
Affected setups: <where this code runs: platforms, OS or kernel versions,
          deployment modes, configurations>
Tests: <tests added or changed, and the commands to run them>
```

Leave a field out if it doesn't apply. Don't invent content.

**Share the problem, not the solution, in the blind brief.** The correctness
reviewer forms its own view first: its root cause, the approach it expects,
and its findings. Don't include:
- The design, or why you chose this approach over others.
- Your root-cause analysis. Give symptoms and evidence.
- Arguments for correctness ("safe because...", "no lock needed since...").
- The history of the change, earlier attempts, or the conversation.

If a context field can only be written by explaining the fix, leave it out. It
goes in the reveal.

**Scope is not a shield.** "Left for later" tells the reviewer not to ask for
those features. It doesn't stop the reviewer from flagging breakage this change
causes.

With `--with-builtin`, also run the built-in reviewer each round (Skill tool,
`code-review`, args `high`). No reviewer subagent owns its findings, so verify
them yourself through the gates. Fix the ones that hold. Mark the others
DROPPED, with the reason.

Wait for all reviewers. Don't respond to findings yet.

## 3. Round 1: reveal (correctness only)

Continue **the correctness reviewer** with SendMessage (load it with
ToolSearch `select:SendMessage` if needed). Send your reasoning, honestly and
completely:

```
Reveal.
Root cause: <your root-cause analysis, with evidence>
Design: <how the change works and why this approach>
Claims the code relies on: <invariants, ordering, "never concurrent",
          behavior of external systems or specs, etc.>
Alternatives rejected: <alternative>: <reason>   (one per line)
Draft commit message / PR description:
<full text>
```

Don't hold back weak points. A claim you leave out can't be verified, and the
reveal exists so that the reasoning gets reviewed too.

The reviewer replies with: root cause MATCH or DIFFERS, a check of each claim,
a check of each rejected alternative, findings it withdraws (only those that a
verified claim answers), problems in the description, and an `OPEN:` line.

- **Root cause DIFFERS:** treat this as the most important finding. Don't
  rebut it until you have re-examined the evidence. One of you is wrong about
  why the bug happens.

## 4. Merge and verify

Follow `coordinator.md`: build the ledger, handle free-range proposals, apply
the four gates, and run Gate 4 with `<end>` = `T_k` (or the commit under
review) and `<fork>` = the review base. In `--delta` mode, `<fork>` is the
delta tree: the earlier full review's Gate 4 covers the rest of the change, so
judge only the tests that the delta adds or changes.

## 5. Respond to each finding

For each finding, decide honestly:
- **FIXED:** fix it in the code and run the affected tests.
- **REBUTTAL:** only with checkable evidence (a test that passes, a code
  reference, a source citation) that refutes the reviewer's scenario. If your
  rebuttal is "I don't think so", fix it instead.
- **LEAVE** (MINOR or NIT only): ask the reviewer to agree that it can stay
  for now, with your reason. If it agrees, the outcome is LEFT; if not,
  DISPUTED.

Send each reviewer its own findings (rules in `coordinator.md`, "Arguing"):

```
New diff: git diff <T_prev> <T_next>   (full: git diff <base> <T_next>)
F1 FIXED: <what changed, where>        (the reviewer's own numbering)
F2 REBUTTAL: <evidence>
F3 LEAVE: <why this MINOR or NIT can stay for now>
```

A finding that stays OPEN after the exchange limit is DISPUTED. "Escalate
disagreements" says what happens next.

After fixes, rerun the affected build, tests, and lint. If a fix can change
performance on a hot path, say that /shipme's benchmark gate applies.

## 6. Rounds 2 to 5

Start a **fresh** set of reviewers (the lens selection redone for what the
change now touches) on the **full** diff `git diff <base> <T_k>`, with the
same minimal context as round 1. Fresh reviewers don't anchor on the earlier
rounds.

- The correctness reviewer gets the blind brief and then the reveal again,
  with the updated reasoning.
- Don't tell reviewers about earlier findings. Exception: if the same finding
  came up in two rounds in a row and was settled (REJECTED, DISPUTED, or LEFT),
  add one line to that lens's brief: `Already settled: <claim>: <why>`.
- Then repeat sections 4 and 5.

**Start another round when** you changed code or tests after the round's
reviewers read them (not counting NIT fixes), or when a new finding above NIT
ended DISPUTED. Findings that repeat settled ones, NITs, and free-range
proposals don't count. Otherwise stop, and list open MINOR and NIT findings for
the user.

**Cap:** 5 rounds. If round 5 still leads to code or test changes, stop and
ask the user how to proceed.

## 7. Escalate disagreements

List disputed MINOR and NIT findings in the report. Ask the user about each
disputed BLOCKER, RED FLAG, or QUESTION with AskUserQuestion, one question per
finding, each standing on its own:
- The finding (file:line, scenario).
- The reviewer's position and evidence.
- Your position and evidence.
- Options: "Fix as the reviewer suggests", "Keep as is (author is right)", or
  "Other approach".

Apply the decision. Treat the user's decision as final. Don't send it back to
the reviewer. If the decision changes code, run Gate 4 and the affected
build and tests, and start one more round if the cap allows. If it doesn't,
say in the report that the decided fix had no fresh review.

## 8. Stamp and report

- When nothing blocking remains open (or the user decided), run
  `~/.claude/review-kit/bin/review-stamp write <base>`. In `--delta` mode,
  `<base>` is `git merge-base HEAD <upstream default branch>`, not the delta
  tree. The stamp covers the whole working tree, so in series mode write it
  only after every commit of the series has been reviewed.
- Report to the user:
  - Result: approved after k rounds, or approved with your decisions.
  - Risk tier. Lenses run each round; lenses **not** run and why (including
    reviewers that failed twice and declined free-range proposals).
  - Root cause: matched, or differed and how it was resolved.
  - Ledger, by outcome (`coordinator.md`):
    - FIXED, and why.
    - REJECTED (the reviewer agreed), and why.
    - DISPUTED BLOCKER, RED FLAG, and QUESTION findings, and how the user
      decided.
    - DISPUTED or LEFT MINOR and NIT findings.
    - DROPPED built-in findings, with the reason.
  - Gate 4 and other tests run, with their results.
  - The final commit message / PR description draft (after reviewer fixes).
  - Next step: `/shipme`.

Don't create new commits or push. That is /shipme's job. The one exception is
series mode, where you amend the commit under review (section 1).
