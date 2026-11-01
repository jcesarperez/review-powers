# Changelog

## [Unreleased]

### Changed

- `review-pr` and `review-pr-feedback` explain what goes wrong and why in plain words, with code names as pointers rather than the explanation, and a worked example with numbers when the point is abstract.
- A view only where prose would leave the reader rebuilding a shape or a flow, next to the sentence it supports: a `diff` for a changed shape or a proposed fix, a call tree for control flow, a sequence diagram for cross-service interactions.
- Both reports open with the verdict.

## [1.0.0] - 2026-10-23

### Added

- `review-pr`: reviews someone's PR and gives you a numbered list of findings to act on, each with a recommendation.
- `review-pr-feedback`: gives a verdict on each review comment on your PR, fixes what you pick and replies to every comment.
- Install with the skills CLI (project or global), as a Claude Code plugin, or by copying the folders.

[1.0.0]: https://github.com/jcesarperez/review-powers/releases/tag/v1.0.0
