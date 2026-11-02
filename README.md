# claude-config

This repository contains my personal Claude Code configuration.

## Install

```sh
git clone <this repo> ~/claude-config
~/claude-config/install.sh
```

The script links each item into `~/.claude`. If a target exists and is not a
link, the script moves it to a backup file first. You can run the script again
at any time.

## Contents

- `skills/self-review/`: reviews our own changes with an independent reviewer.
- `skills/ship/`: runs the checks and commits a reviewed change.
- `skills/pr-review/`: reviews pull requests from other persons.
- `skills/benchmark/`: measures the performance effect of a change (A/B).
- `agents/code-reviewer.md`: the independent reviewer agent.
- `review-kit/`: shared parts and project overlays. See `review-kit/README.md`.
