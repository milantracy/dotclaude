# Global rules

- Before you change files in a git repository, work in a worktree, not in the
  main checkout:
  - If you are already in a linked worktree for this task, or your
    instructions name a worktree to work in, keep working there.
  - Otherwise, fetch, then create a new worktree in a sibling directory
    (outside the repo) on a new branch based on `origin/main`, or on
    `origin/master` if there is no `origin/main`. If neither exists, ask the
    user which base to use.
