---
name: pr-review
description: Review someone else's PR and write a markdown report with a verdict, ranked findings, and draft review comments. Uses the independent code-reviewer subagent plus project overlays, and tracks earlier reviews of the same PR. Use for "review PR 14905" or "re-review after the force-push". For our own changes, use self-review.
argument-hint: "<PR number | URL> [--post]"
---

# PR review (external)

Kit: `~/.claude/review-kit/`. The review method is in the `code-reviewer`
agent. Overlays are in `review-kit/projects/<name>/review.md`.

## 1. Resolve the PR

- `gh pr view <n> --json title,body,author,baseRefName,headRefOid,files,commits,comments,reviews`
- Check out the head in a new worktree, so builds and tests don't disturb the
  user's checkout. Record the base and head SHAs.
- Detect the overlay (kit README).

## 2. Check for earlier reviews

Find earlier reports (overlay location; default `~/workspace/reviews/pr-<n>*.md`).
If one exists:
- Run `git range-diff` between the old head and the new head.
- Extract the earlier BLOCKERs and RED FLAGs to give to the reviewer.
- Write the new report as `pr-<n>-rev<k>.md`. Never overwrite an earlier report.

## 3. Run the reviewer

Spawn `code-reviewer` (Agent tool) with:

```
Repo: <worktree path>
Diff: git diff <base> <head>
Intent: <one sentence from the PR description>
PR description and linked issue: <text>   (external PR: the author's claims are
                                         things to verify, not context to trust)
Overlay: <abs path(s)>
Earlier findings to re-check: <list, or "none">  (status for each: fixed /
                                         partly fixed / not addressed / no longer applies)
```

## 4. Verify the findings

You are the editor now. For each finding, open the cited file:line and check the
scenario. If one looks wrong, ask the reviewer once (SendMessage) with your
counter-evidence. Drop findings that don't survive. Mark doubtful ones as
questions. No author is in the loop, so one follow-up exchange is enough.

## 5. Write the report

Save it to the overlay's report directory (default `~/workspace/reviews/`):

```
# Review: <repo>#<n> (rev k) — <title>
PR head `<sha>` (<author>). Base `<sha>`. <files>, +A/−D.
Earlier review: <path or "none">.
Build/test: <command> — <result>.

## Contents
## 1. Verdict          Approve / Approve with nits / Request changes, in 1–3 short paragraphs.
                       What to land as-is and what blocks.
## 2. What changed since rev k-1   (re-reviews only; table of earlier findings → status)
## 3. Context          Only what a reader needs to follow the findings.
## N. BLOCKER k: <claim as a sentence>
## N. Red flag: <claim>
## N. Minor: <claim>
## N. Tests
## N. Nits
## N. Review comments  Draft comment for each finding, anchored at file:line.
## N. File/line index  Every file:line referenced, linked to its finding.
```

Each finding has: what is wrong, the scenario, evidence, and the suggested fix.

## 6. Finish

Tell the user the verdict, the blocker titles, and the report path. Post to
GitHub only with `--post` or an explicit request. Show the comments first and
post only after the user confirms. Remove the worktree when done, unless the
user wants to keep it.
