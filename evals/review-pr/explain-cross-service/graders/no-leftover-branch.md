---
type: file_exists
# Branches are files under .git/refs/heads; the scaffold's own `main` isn't one
# the agent created, so any hit is a local branch left behind (pr-<n>, ...).
path: ".git/refs/heads/**"
exists: false
---
