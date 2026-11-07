# Contributing

## Pull requests

- One ticket per PR. The branch and title carry the ticket key (see the README).
- Keep a PR small enough to review in one sitting.
- `npm test` passes before you ask for review.

## Reviews

Every PR is reviewed by a teammate and by `acme-review-bot`, our automated
reviewer.

The bot reviews a PR once, when it opens. It does not watch new pushes, and it
ignores mentions and GitHub review requests. To have it review the latest
commit, post this as a PR conversation comment, on a line of its own:

    /acme-review rerun
