# claude-config

This repository contains my personal Claude Code configuration.

## Install

```sh
git clone <this repo> ~/claude-config
~/claude-config/install.sh
```

The script links each item into `~/.claude`. If a target exists and is not a
link, the script moves it to a backup file first. It also removes links under
`~/.claude/skills` and `~/.claude/agents` that point into this repo but no
longer resolve, such as those left by a renamed skill. You can run the script
again at any time.

## Contents

- `skills/self-review/`: reviews our own changes with several independent
  reviewers, one per lens.
- `skills/shipme/`: runs the checks and commits a reviewed change.
- `skills/pr-review/`: reviews pull requests from other persons.
- `skills/benchmark/`: measures the performance effect of a change (A/B).
- `agents/code-reviewer.md`: the independent reviewer agent.
- `agents/fail-first-checker.md`: the Gate 4 agent of the review skills
  (it checks that a change's tests fail without it and pass with it).
- `review-kit/`: shared parts and project overlays. See `review-kit/README.md`.
