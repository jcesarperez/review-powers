# Evals

Cases for `claude plugin eval`. Each one runs a skill against a made-up PR and
grades the reply.

## Run

```bash
claude plugin eval . --scaffold --allow-tools Bash --judge-model sonnet
```

- `--scaffold` builds the fixture repo for each case. Without it, cases fail.
- `--allow-tools Bash` lets the skill call `gh` and `git`. The run is sandboxed,
  so writes stay in the eval workspace.
- `--judge-model sonnet`: the default judge is too lenient for the writing rubrics.
- `--tag explain` runs only the explanation cases. `--runs 1 --ablation none`
  makes a cheap smoke run. A full run is about $0.30 per case run.

## How the fixtures work

`_fixtures/setup-pr.sh <n>` is called from each case's `scaffold.sh`. It builds
a small TypeScript hotel API in the workspace (`_fixtures/hotel-api/base/`),
with PR `<n>` (`_fixtures/hotel-api/prs/<n>/`) on a local origin, then puts a
fake `gh` (`_fixtures/bin/gh`) first on the agent's PATH through the shell
profiles of the run's temporary home.

The fake `gh` serves the PR from `prs/<n>/*.json` and logs every call to
`.git/gh-calls.log`. Reads are answered. Writes (comments, reviews, edits) are
logged as `WRITE` and faked, so the `gate-no-writes` grader can check that
nothing was posted before the user decided.

To add a PR: create `prs/<n>/pr.json` (the `gh pr view --json` shape) and
`prs/<n>/files/` (files that differ from `base/`). Optional
`review_comments.json`, `issue_comments.json` and `reviews.json` use the REST
API shapes.

## Cases

| Case | PR | Checks |
|---|---|---|
| `review-pr/explain-contract-change` | 101: endpoint shape changes; invoicing, outside the diff, breaks | Shape shown as a well-formed `diff`, not JSON |
| `review-pr/explain-with-example` | 102: merging PMS blocks loses stay lengths | Abstract bug explained with a worked example |
| `review-pr/explain-concrete-finding` | 103: unknown discount code → 500 | Concrete finding gets no block |

Every case also checks: a reader who doesn't know the code understands the
problem, the language is plain, there is no preamble, and nothing was written
to GitHub.
