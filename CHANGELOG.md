# Changelog

## [Unreleased]

## [1.1.0] - 2026-11-07

### Added

- `review-pr` runs `fetch-pr.sh` first: one call saves the description, CI per check, every comment feed (inline, conversation, review bodies), whether the PR is stacked, ticket keys, and the diff without generated files (lockfiles, generated clients, OpenAPI specs, anything marked `linguist-generated`). It prints counts and paths; the left-out files are listed with their size and kept in a separate patch.
- `review-pr-feedback` runs `feeds.sh` first: every feed with thread state (resolved, outdated, replies, bot or human), bot markup stripped, a count per feed including zero, and a check that your checkout is the PR's head commit.
- `review-pr-feedback` posts through `reply.sh`: inline replies, conversation comments, resolving threads and updating the PR description.
- `review-pr` reads a PR's code in a detached worktree in its scratch directory, made by `checkout-pr.sh` and removed with `--cleanup` when the reading is done. Your own branch and checkout stay as they are, and no `pr-<n>` branch or stray `<repo>-pr<n>` folder is left behind.
- `review-pr-feedback` closes the loop after replying: it resolves the threads your pushed fixes settle, leaves rejected findings open for the reviewer to answer, and asks each reviewer whose findings it acted on to review again. A person gets GitHub's re-request (`reply.sh rereview`); an automated reviewer gets the trigger your repo documents, and if none is documented the run says so instead of guessing. The plan at the gate names these steps, so one go-ahead covers them.
- `review-pr` reads the ticket chain: the PR's ticket, its parent, each with its comments, and any sibling the ticket references, through whatever issue-tracker tool your environment has. A PR that satisfies its subtask but breaks a decision recorded on the parent story is flagged, and the report says whether the tickets were read.

### Changed

- `review-pr` and `review-pr-feedback` explain what goes wrong and why in plain words, leading each finding with a concrete case (with numbers when the point is abstract) and then why it happens. `file:line` stays where it places an inline comment, not in the explanation.
- A view only where prose would leave the reader rebuilding a shape or a flow, next to the sentence it supports: a `diff` for a changed shape or a proposed fix, a call tree for control flow, a sequence diagram for cross-service interactions.
- Both reports open with the verdict.

## [1.0.0] - 2026-10-23

### Added

- `review-pr`: reviews someone's PR and gives you a numbered list of findings to act on, each with a recommendation.
- `review-pr-feedback`: gives a verdict on each review comment on your PR, fixes what you pick and replies to every comment.
- Install with the skills CLI (project or global), as a Claude Code plugin, or by copying the folders.

[1.1.0]: https://github.com/jcesarperez/review-powers/releases/tag/v1.1.0
[1.0.0]: https://github.com/jcesarperez/review-powers/releases/tag/v1.0.0
