---
name: self-review
description: Review the changes we made with several independent reviewer subagents that start with no context, each with its own lens (correctness, security, tests, design, ...), scaled to the risk of the change. The correctness reviewer first forms its own view from the problem alone (blind), then sees our reasoning and checks it. We act as coordinator. We merge findings, verify them through four gates (including running the tests with and without the change), fix or argue each one (nits are settled without arguing), and start a small set of fresh reviewers for another round only when the fixes need one (at most 3 rounds). Asks the user to decide disputed blockers, red flags, and questions. Records an approval stamp that /shipme checks. Use when a change is done ("review my changes", "self-review", "check this before shipping"). Not for other people's PRs; use pr-review for those.
argument-hint: "[base-ref | commit | range] [--delta <tree>] [--with-builtin]"
---

# Self-review

You are the **author** and the **coordinator**. You fix things or argue with
evidence. The **reviewers** are fresh `code-reviewer` subagents that know
nothing about this conversation, one per lens (or per merged group of
lenses). Kit: `~/.claude/review-kit/`.
Read these kit files first:
- `overlays.md`: overlay detection.
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
- **Series mode** (`<sha>~1..<sha>`, one commit of a series): read
  `~/.claude/skills/self-review/series.md` first. The end of each round is
  that commit, not a tree snapshot, and you fold the fixes into it.
- **Snapshots:** take `T=$(~/.claude/review-kit/bin/review-stamp tree)` at the
  start of each round (`T1`, `T2`, ...) and after each set of fixes (`T_next`).
  `T_prev` is the tree that the reviewer last read. Reviewers diff against tree
  hashes (`git diff <base> <T_k>`), so later edits don't shift the ground under
  them.
- **Overlay:** detect it from `overlays.md`. Collect absolute paths to
  `projects/<name>/review.md`.
- **Risk tier and lenses:** classify the change and pick the lens set (overlay,
  else `lenses.md`; for `--delta`, see "`--delta` mode" in `lenses.md`).
  Write down each lens you will **not** run and why; the report needs it.
- **Context:** write the blind brief (section 2) from the conversation, the
  issue, and the commits. Ask the user only for parts you really can't fill in.
- **Commit message:** if no draft exists yet, draft it now. The
  style-description lens and the reveal need it; /shipme reuses it. Keep issue
  IDs (`#123`, `Fixes #123`, `Updates #123`) out of it; the user tags the issue
  in the PR body.

## 2. Round 1: parallel blind pass

Spawn all reviewers in one message (Agent tool, `subagent_type:
"code-reviewer"`, one call per lens, or per merged group; its
`Lens:` form is in `lenses.md`, "Merged reviewers"). Each gets the base
brief:

```
Repo: <abs path>
Diff: git diff <base> <T_k>        (<n> files, +A/-D)
Overlay: <abs path(s), or "none: use in-repo AGENTS.md/CONTRIBUTING.md">
Lens: <name>: <objective from the overlay, else from the lens catalog>
Tier: <Low | Medium | High>
Checkout: <matches | differs>
```

Add only what the context table in `lenses.md` (or the overlay) gives each lens
(catch-all gets `Lenses this round: <labels>`).

The rest of this section and section 3 describe round 1 of a full review.
In a `--delta` review, round 1 uses the follow-up set (`lenses.md`): its
correctness reviewer gets the fields below without the `Stage: blind`
line, and the reveal text of section 3, in one brief, and you skip the
reveal message. (`lenses.md`, "`--delta` mode" says when a delta needs a
full review instead.)

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

Wait for all reviewers. Don't respond to findings yet. Then do these in
one message, so they run at the same time: the reveal (section 3, when the
correctness reviewer ran blind), Gate 4 (section 4), and any proposed lens
you start (`coordinator.md`).

## 3. Round 1: reveal (correctness only)

Continue **the correctness reviewer** with SendMessage. Send your reasoning,
honestly and completely:

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

Follow `coordinator.md`: build the ledger, handle lens proposals, apply
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
- **LEAVE** (MINOR only): ask the reviewer to agree that it can stay for
  now, with your reason. If it agrees, the outcome is LEFT; if not,
  DISPUTED.
- **NIT:** settle it yourself: FIXED, LEFT, or DROPPED when it fails your
  check (`coordinator.md`). Don't send NITs to the reviewer. No reviewer
  checks a NIT fix, so keep it to names, comments, and wording. If the fix
  would change behavior, treat the finding as a MINOR and say so in the
  message to its reviewer (`F3 (NIT, now MINOR) FIXED: ...`).

Send each reviewer its own findings above NIT (rules in `coordinator.md`,
"Arguing"). A reviewer with only NITs gets no message:

```
New diff: git diff <T_prev> <T_next>   (full: git diff <base> <T_next>)
F1 FIXED: <what changed, where>        (the reviewer's own numbering)
F2 REBUTTAL: <evidence>
F3 LEAVE: <why this MINOR can stay for now>
```

A finding that stays OPEN after the exchange limit is DISPUTED. "Escalate
disagreements" says what happens next.

After fixes, rerun the affected build, tests, and lint. If a fix can change
performance on a hot path, say that /shipme's benchmark gate applies.

## 6. Later rounds

Most reviews end after round 1: the reviewer that found a problem checks
its fix (CLOSED), and that is the fix's review.

**Start another round only when** one of these holds:
- A fix changed code or tests and no reviewer checked it: a fix that the
  user decided, a fix for a finding with no reviewer (`gate4`, built-in),
  or one whose reviewer failed. NIT fixes don't count.
- The fixes go beyond the findings they answer: together they change the
  approach, an interface or format, a lock, or a check on untrusted input,
  or `git diff <T_k> <T_next>` changes more than about 50 lines outside
  tests.
- The fixes raise the risk tier (`lenses.md`, "Follow-up set").
- The tier is High and the round fixed a BLOCKER or RED FLAG.

If none holds, stop: findings that repeat settled ones, DISPUTED findings,
NITs, and lens proposals don't start a round. If the fixes changed a test
or the code that a Gate 4 target covers, run Gate 4 once more on the final
tree first. List the DISPUTED and LEFT findings for the user.

In a new round, start **fresh** reviewers on the **full** diff `git diff
<base> <T_k>`. Fresh reviewers don't anchor on the earlier rounds. Start
only the **follow-up set** (defined in `lenses.md`, or the overlay's
version), not the full set again.

- The correctness reviewer runs a single pass with the updated reasoning in
  its brief, so the round has no reveal. `lenses.md`, "Follow-up set" has
  the one exception (a blind pass and a reveal, as in sections 2 and 3).
- Don't tell reviewers about earlier findings. Exception: if the same finding
  came up in two rounds in a row and was settled (REJECTED, DISPUTED, or LEFT;
  for a NIT, also DROPPED), add one line to that lens's brief:
  `Already settled: <claim>: <why>`.
- Then repeat sections 4 and 5.

**Cap:** 3 rounds. If round 3 still calls for another round, stop and ask
the user how to proceed.

## 7. Escalate disagreements

List disputed MINOR findings in the report. Ask the user about each
disputed BLOCKER, RED FLAG, or QUESTION with AskUserQuestion, one question per
finding, each standing on its own:
- The finding (file:line, scenario).
- The reviewer's position and evidence.
- Your position and evidence.
- Options: "Fix as the reviewer suggests", "Keep as is (author is right)", or
  "Other approach".

Apply the decision. Treat the user's decision as final. Don't send it back to
the reviewer. If the decision changes code, run Gate 4 and the affected
build and tests, and start one more round if section 6 calls for one and
the cap allows. If the cap doesn't, say in the report that the decided fix
had no fresh review.

## 8. Stamp and report

- When nothing blocking remains open (or the user decided), run
  `~/.claude/review-kit/bin/review-stamp write <base>`. In `--delta` mode,
  `<base>` is `git merge-base HEAD <upstream default branch>`, not the delta
  tree. The stamp covers the whole working tree, so in series mode write it
  only after every commit of the series has been reviewed.
- Report to the user:
  - Result: approved after k rounds, or approved with your decisions.
  - Risk tier. Lenses run each round; lenses **not** run and why (including
    reviewers that failed twice and declined lens proposals).
  - Root cause: matched, or differed and how it was resolved.
  - Ledger, by outcome (`coordinator.md`):
    - FIXED, and why. Mark the NIT fixes: no reviewer checked them.
    - REJECTED (the reviewer agreed), and why.
    - DISPUTED BLOCKER, RED FLAG, and QUESTION findings, and how the user
      decided.
    - DISPUTED MINOR findings, and LEFT MINOR and NIT findings.
    - DROPPED built-in findings and NITs, with the reason.
  - Gate 4 and other tests run, with their results.
  - The final commit message / PR description draft (after reviewer fixes).
  - Next step: `/shipme`.

Don't create new commits or push. That is /shipme's job. The one exception is
series mode, where you amend the commit under review (`series.md`).
