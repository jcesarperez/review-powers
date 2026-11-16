# What a gather leaves

`gather.py` writes this; without it, write the same by hand so the review reads
it the same way. Everything goes under `<scratchpad>/gather/`. A missing piece
is listed in the index, not left out silently.

## index.md

The map, read first. Plain text:

- First line: `Ticket <KEY>: <title> [<status>]`.
- **Jira:** the path of each file in `jira/`, with status and title.
- **PRs:** per key, each PR found (`owner/repo#n [STATE] title`) with its
  folder and how many review threads (and how many open), conversation
  comments and review bodies it has; a key with no PR says so. PRs that only
  mention a key in their body go in a list of their own, not fetched.
- **Repos:** per repo, the default branch and commit, the code path and the
  `context.md` path; a repo whose code or context couldn't be read is marked
  `FAILED` with what is missing.
- **Failed:** each thing that couldn't be gathered, and why.

While gathering, say so at the top and mark unfinished repos `PENDING`.

## jira/\<KEY\>.md

One per ticket and subtask: `# <KEY> — <title>`, then type, status, assignee,
links, parent and subtasks; the description and acceptance criteria as
written; every comment with author and date.

## prs/\<repo\>-\<n\>/

- `pr.md`: `# owner/repo#n — title`, URL, state, merge date, branches, author,
  the description, and the changed files with lines added and removed.
- `feeds.md`: inline review threads (path, line, resolved or open, outdated),
  conversation comments and review bodies, each comment with id and author,
  and a count per feed, zero included.
- `diff.patch`: the PR's diff, when there is no code tree to read it from.

## repos/\<owner\>-\<repo\>/

- `tree/`: the code at the default branch, as a detached worktree of the
  user's clone or a fresh clone. Never the user's own working tree.
- `context.md`: the AI context files that apply to what the PRs touched, each
  with why it applies and its length in lines. Those are `CLAUDE.md` and
  `AGENTS.md` at the root and in any folder above a touched file,
  `.claude/rules` whose `paths:` match a touched file or that have no
  `paths:`, and what they import with `@`. Two groups: **always read** (root,
  nested and folder-scoped files) and **broad** (rules for a file type or
  every file); then the rules that don't apply.
