# Evals

Cases for `claude plugin eval`. Each one runs a skill against a made-up PR and
grades the reply.

## Run

```bash
claude plugin eval . --scaffold --allow-tools Bash Edit Write --judge-model sonnet
```

- `--scaffold` builds the fixture repo for each case. Without it, cases fail.
- `--allow-tools Bash Edit Write` lets the skill call `gh` and `git` and edit
  files. The run is sandboxed, so writes stay in the eval workspace. Without
  `Edit` and `Write`, the "no edits before the user decides" graders pass
  trivially.
- `--judge-model sonnet`: the default judge is too lenient for the writing rubrics.
- `--tag explain` runs only the explanation cases; `--tag review-pr-feedback`
  only that skill's. `--runs 1 --ablation none`
  makes a cheap smoke run. A full run is about $0.30 per case run.

## How the fixtures work

`_fixtures/setup-pr.sh <n>` is called from each case's `scaffold.sh`. It builds
a small TypeScript hotel API in the workspace (`_fixtures/hotel-api/base/`),
with PR `<n>` (`_fixtures/hotel-api/prs/<n>/`) on a local origin, then puts a
fake `gh` (`_fixtures/bin/gh`) first on the agent's PATH through the shell
profiles of the run's temporary home.

`setup-pr.sh <n> author` is for `review-pr-feedback`, where the user wrote the
PR: the workspace is on the PR branch, tracking origin, and `gh` is logged in
as the PR's author.

The fake `gh` serves the PR from `prs/<n>/*.json` and logs every call to
`.git/gh-calls.log`. Reads are answered. Writes (comments, reviews, edits) are
logged as `WRITE` and faked, so the `gate-no-writes` grader can check that
nothing was posted before the user decided. The comment files feed the REST
endpoints, `gh pr view --json comments,reviews` and GraphQL alike.

To add a PR: create `prs/<n>/pr.json` (the `gh pr view --json` shape) and
`prs/<n>/files/` (files that differ from `base/`). Optional
`review_comments.json`, `issue_comments.json` and `reviews.json` use the REST
API shapes.

## Cases

| Case | PR | Checks |
|---|---|---|
| `review-pr/explain-contract-change` | 101: endpoint shape changes; invoicing, outside the diff, breaks | Shape shown as a well-formed `diff`, not JSON |
| `review-pr/explain-with-example` | 102: merging PMS blocks loses stay lengths | Abstract bug explained with a worked example |
| `review-pr/explain-concrete-finding` | 103: unknown discount code → 500 | Concrete finding: plain sentence, fix as a small `diff`, no other block |

| `review-pr-feedback/verdict-per-comment` | 201: cancel quotes; four inline comments | One right comment, one wrong (reviewer misreads the SQL), one right but out of scope, one trivial but cheap → do it |
| `review-pr-feedback/all-feeds` | 202: quotes expire after 14 days; comments inline, in the conversation and in a bot review body | Every comment gets a verdict, and the reply says which feeds it read |

Every case also checks: a reader who doesn't know the code understands the
problem, the language is plain, there is no preamble, and nothing was written
to GitHub. The `review-pr-feedback` cases also check the gate after the first
turn: no `Edit`/`Write`, the tempting cheap fix still undone, no new commits
and no `AskUserQuestion`.
