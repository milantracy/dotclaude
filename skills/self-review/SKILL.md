---
name: self-review
description: Review the changes we made, using an independent reviewer subagent that has no context. The reviewer first forms its own view from the problem alone (blind), then sees our reasoning and checks it. Runs up to 3 review rounds (reviewer finds, we fix or rebut, reviewer re-checks) and asks the user to decide anything still disputed. Records an approval stamp that /ship checks. Use when a change is done ("review my changes", "self-review", "check this before shipping"). Not for other people's PRs; use pr-review for those.
argument-hint: "[base-ref | commit | range] [--delta <tree>] [--with-builtin]"
---

# Self-review

You are the **author**. You fix things or argue with evidence. The **reviewer**
is a fresh `code-reviewer` subagent that knows nothing about this conversation.
Kit: `~/.claude/review-kit/` (read its `README.md` for overlay detection).

## 1. Set up

- **Diff range:**
  - Default: from `git merge-base HEAD <upstream default branch>` to the current
    working tree, including uncommitted and untracked files.
  - With an argument: use that base, commit, or range. For a numbered series,
    review one commit at a time (`<sha>~1..<sha>`).
  - With `--delta <tree>` (passed by /ship): diff from that tree to the current
    working tree.
- **Snapshot:** record `T0=$(~/.claude/review-kit/bin/review-stamp tree)`. The
  reviewer diffs against tree hashes (`git diff <base> <T0>`), so later edits
  don't shift the ground under it.
- **Overlay:** detect it from the kit README. Collect absolute paths to
  `projects/<name>/review.md`.
- **Context:** write the context block (section 2) from the conversation, the
  issue, and the commits. Ask the user only for parts you really can't fill in.

## 2. Round 1a: blind pass

Spawn the reviewer: Agent tool, `subagent_type: "code-reviewer"`. Give it:

```
Repo: <abs path>
Diff: git diff <base> <T0>        (<n> files, +A/-D)
Overlay: <abs path(s), or "none: use in-repo AGENTS.md/CONTRIBUTING.md">
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
Affected setups: <where this code runs, e.g. runsc + k8s systemd driver, cgroup v2>
Tests: <tests added or changed, and the commands to run them>
```

Leave a field out if it doesn't apply. Don't invent content.

**Share the problem, not the solution, in this pass.** The reviewer forms its own
view first: its root cause, the approach it expects, and its findings. Don't
include:
- The design, or why you chose this approach over others.
- Your root-cause analysis. Give symptoms and evidence.
- Arguments for correctness ("safe because...", "no lock needed since...").
- The history of the change, earlier attempts, or the conversation.

If a context field can only be written by explaining the fix, leave it out. It
goes in the reveal.

**Scope is not a shield.** "Left for later" tells the reviewer not to ask for
those features. It doesn't stop the reviewer from flagging breakage this change
causes.

With `--with-builtin`, also run the built-in reviewer (Skill tool,
`code-review`, args `high`). Add its findings to the list. They go to the
`code-reviewer` subagent for a decision in round 2.

Wait for the reviewer's blind findings. Don't respond to them yet.

## 3. Round 1b: reveal

Continue **the same reviewer** with SendMessage (load it with ToolSearch
`select:SendMessage` if needed). Send your reasoning, honestly and completely:

```
Reveal.
Root cause: <your root-cause analysis, with evidence>
Design: <how the change works and why this approach>
Claims the code relies on: <invariants, ordering, "never concurrent", Linux
          behavior, etc.>
Alternatives rejected: <alternative>: <reason>   (one per line)
Draft commit message / PR description:
<full text. If none exists yet, draft it now; /ship reuses it. Keep issue
IDs (`#123`, `Fixes #123`, `Updates #123`) out of the commit message; the user
tags the issue in the PR body.>
```

Don't hold back weak points. A claim you leave out can't be verified, and the
reveal exists so that the reasoning gets reviewed too.

The reviewer replies with: root cause MATCH or DIFFERS, a check of each claim,
a check of each rejected alternative, findings it withdraws (only those that a
verified claim answers), problems in the description, and an `OPEN:` line.

- **Root cause DIFFERS:** treat this as the most important finding. Don't
  rebut it until you have re-examined the evidence. One of you is wrong about
  why the bug happens.

The blind pass and the reveal count as **round 1** together.

## 4. Respond to each finding

For each finding, decide honestly:
- **FIXED:** fix it in the code and run the affected tests.
- **REBUTTAL:** only with checkable evidence (a test that passes, a code
  reference, a source citation) that refutes the reviewer's scenario. If your
  rebuttal is "I don't think so", fix it instead.

Keep a ledger: `F<n> | severity | FIXED / REBUTTAL | one-line note`.

## 5. Rounds 2 and 3

Take a new snapshot `T1` and continue **the same reviewer** with SendMessage:

```
Round <k>. New diff: git diff <T_prev> <T_k>   (full: git diff <base> <T_k>)
F1 FIXED: <what changed, where>
F2 REBUTTAL: <evidence>
...
```

The reviewer answers each finding with CLOSED or OPEN, reviews the delta, and
ends with an `OPEN:` line.

**Stop when** no BLOCKER, RED FLAG, or QUESTION is open. Open MINOR and NIT
findings don't block; list them for the user.

**Cap:** at most 3 rounds (round 1 = blind pass + reveal, then 2 follow-ups). Then stop.

## 6. Escalate disagreements

If a BLOCKER, RED FLAG, or QUESTION is still open after round 3, ask the user
with AskUserQuestion. Ask one question per disputed finding, each standing on
its own:
- The finding (file:line, scenario).
- The reviewer's position and evidence.
- Your position and evidence.
- Options: "Fix as the reviewer suggests", "Keep as is (author is right)", or
  "Other approach".

Apply the decision. Treat the user's decision as final. Don't send it back to the
reviewer.

## 7. Stamp and report

- When nothing blocking remains open (or the user decided), run
  `~/.claude/review-kit/bin/review-stamp write <base>`.
- Report to the user:
  - Result: approved after k rounds, or approved with your decisions.
  - Root cause: matched, or differed and how it was resolved.
  - Ledger table: finding, severity, outcome (fixed / rebutted-accepted /
    user-decided / open minor).
  - Tests run, with their results.
  - The final commit message / PR description draft (after reviewer fixes).
  - Next step: `/ship`.

Don't commit or push. That is /ship's job.
