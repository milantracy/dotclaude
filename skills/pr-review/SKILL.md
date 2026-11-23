---
name: pr-review
description: Review someone else's PR and write a markdown report with a verdict, ranked findings, and draft review comments. Starts several independent code-reviewer subagents in parallel, one per lens (scaled to the PR's risk tier), with the project overlay; merges and verifies their findings through four gates (including running the tests with and without the change), skips feedback already on the PR, and tracks earlier reviews of the same PR. Use for "review PR 14905" or "re-review after the force-push". For our own changes, use self-review.
argument-hint: "<PR number | URL> [--post]"
---

# PR review (external)

You are the **coordinator**: you start the reviewers, merge and verify their
findings, and write the report. Kit: `~/.claude/review-kit/`. Read these kit
files first:
- `README.md`: overlay detection.
- `lenses.md`: the lens catalog, risk tiers, lens sets, and context per lens.
- `coordinator.md`: the ledger, the four gates, Gate 4 steps, and the rules
  for arguing.

The review method is in the `code-reviewer` agent. Overlays are in
`review-kit/projects/<name>/review.md`.

## 1. Resolve the PR

- `gh pr view <n> --json title,body,author,baseRefName,headRefOid,files,commits,comments,reviews`
- Base commit: `gh api repos/<owner>/<repo>/pulls/<n> --jq .base.sha`
  (`baseRefOid` isn't a `--json` field in older gh versions).
- Inline review threads, with their resolved state, aren't in that output.
  Get them with GraphQL (the REST comments endpoint has no resolved state):
  `gh api graphql -f query='query($o:String!,$r:String!,$n:Int!){repository(owner:$o,name:$r){pullRequest(number:$n){reviewThreads(first:100){pageInfo{hasNextPage} nodes{isResolved isOutdated path line originalLine comments(first:50){nodes{author{login} body originalCommit{oid}}}}}}}}' -f o=<owner> -f r=<repo> -F n=<n>`.
  If `hasNextPage` is true, say in the report that only the first 100
  threads were checked. For an outdated thread (`line` is null), fetch its
  `originalCommit` and map `originalLine` to the head with
  `git diff <originalCommit> <head>` (or `git range-diff` if the history was
  rewritten).
- Fetch the head and the base commit from the PR's repository, not
  necessarily `origin` (which can be a fork):
  `git fetch https://github.com/<owner>/<repo> <base sha> pull/<n>/head`.
  Add a worktree for the head (`git worktree add --detach <path>
  <headRefOid>`; `FETCH_HEAD` points at the base here), so builds and tests
  don't disturb the user's checkout.
- **Base:** `git merge-base <base sha> <headRefOid>`, never the base branch
  tip. The tip diff also contains every base-branch change since the fork.
- Detect the overlay (kit README).
- **Risk tier and lenses:** classify the PR and pick the pr-review lens set
  (overlay, else `lenses.md`). Write down each lens you will not run and why.

## 2. Check earlier feedback

**Existing PR threads** (from step 1, any author, every time): a thread that
claims a fix ("Done", or resolved with no explanation) while its cited lines
have no real fix is a BLOCKER. A *why* or *how* question needs a technical
answer, not a bare "Done".

**Our earlier reports** (overlay location; default
`~/workspace/reviews/pr-<n>*.md`). If one exists:
- Run `git range-diff` between the old head and the new head (`git diff` for
  added commits).
- Re-check each earlier finding yourself, at every severity: fixed, partly
  fixed, not addressed, declined with a sound technical reason, or no longer
  applies. Never drop an unresolved one silently. Don't give them to the
  reviewers (`coordinator.md`, "Reviewers").
- Write the new report as `pr-<n>-rev<k>.md`. Never overwrite an earlier
  report.

## 3. Run the reviewers

Spawn one `code-reviewer` per lens (Agent tool), all in one message. Base
brief:

```
Repo: <worktree path>
Diff: git diff <base> <head>
Overlay: <abs path(s)>
Lens: <name>: <objective from the overlay, else from the lens catalog>
Tier: <Low | Medium | High>
Checkout: <matches | differs>
```

Add only what the context table in `lenses.md` (or the overlay) gives each
lens. The PR description and commit messages are the author's claims, to
verify, not context to trust.

## 4. Verify the findings

Follow `coordinator.md`: build the ledger, handle free-range proposals, apply
the four gates, and run Gate 4 with `<fork>` = the base from step 1,
`<end>` = the head commit, and `$W` = the head worktree from step 1. Also:

- **Feedback already on the PR:** mark a finding that repeats it DUPLICATE
  and leave it out of the report, unless that feedback is still unaddressed.
  Then mark it REPORTED and report it as unaddressed, not as new.
- A finding that survives verification is REPORTED.
- **Check each finding:** open each cited file:line and check the scenario.
  If a finding looks wrong, unclear, or conflicts with another reviewer's,
  argue with its reviewer. A finding that the reviewer agrees doesn't hold is
  REJECTED.
  Report a DISPUTED finding (still open after the exchange limit) as a
  question in the report.

## 5. Write the report

Save it to the overlay's report directory (default `~/workspace/reviews/`):

```
# Review: <repo>#<n> (rev k) — <title>
PR head `<sha>` (<author>). Base `<merge-base sha>`. <files>, +A/−D.
Risk tier: <Low/Medium/High>. Lenses: <run>; not run: <lens: why>.
Earlier review: <path or "none">.
Build/test: <command> — <result>. Gate 4: <targets, with/without results>.

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
## N. Review comments  Draft top-level comment, then one draft comment per finding.
## N. File/line index  Every file:line referenced, linked to its finding.
```

Each finding has: what is wrong, the scenario, evidence, the suggested fix,
and the lens(es) that found it.

**Review comments** (unless the overlay says otherwise):
- **Top-level comment:** a short approval note when the PR is clean, or at
  most about 5 numbered points. Don't repeat description feedback twice.
- **Inline comments:** anchor each on the added or changed lines. Order them
  by severity. 1–3 sentences each: what the code does, the consequence when
  it isn't obvious, and the exact fix. No praise, no filler.
- If nothing survived verification (or only one trivial nit), draft a clean
  approval with no nit comments.
- Use the overlay's severity labels if it has them.

## 6. Finish

Tell the user the verdict, the blocker titles, and the report path. Post to
GitHub only with `--post` or an explicit request. Show the comments first and
post only after the user confirms. Remove the worktree when done (run the
overlay's worktree cleanup first), unless the user wants to keep it.
