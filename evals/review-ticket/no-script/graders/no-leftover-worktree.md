---
type: file_exists
# A linked worktree keeps its bookkeeping under .git/worktrees/<name>;
# `worktree remove` deletes it, so a hit means one was left behind.
path: ".git/worktrees/**"
exists: false
---
