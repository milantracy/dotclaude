# Self-review: series mode

Read this when the review target is one commit of a series
(`<sha>~1..<sha>`). The rest of the skill applies unchanged.

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
