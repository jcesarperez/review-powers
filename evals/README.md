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
- LLM graders ask a checkable question (is the problem stated? is there a
  case with real values?). Rubrics that score style ("is it plain?") flipped
  between votes and were removed; how plain a report reads is judged on real
  PRs.
- `--tag explain` runs only the explanation cases; `--tag review-pr-feedback`
  only that skill's. `--runs 1 --ablation none`
  makes a cheap smoke run. A full run is about $0.30 per case run.

## How the fixtures work

`_fixtures/setup-pr.sh <n>` is called from each case's `scaffold.sh`. It builds
a small TypeScript hotel API in the workspace (`_fixtures/hotel-api/base/`),
with PR `<n>` (`_fixtures/hotel-api/prs/<n>/`) on a local origin, then puts a
fake `gh` (`_fixtures/bin/gh`) and a fake issue tracker (`_fixtures/bin/tracker`)
first on the agent's PATH through the shell profiles of the run's temporary
home.

`setup-pr.sh <n> author` is for `review-pr-feedback`, where the user wrote the
PR: the workspace is on the PR branch, tracking origin, and `gh` is logged in
as the PR's author.

The fake `gh` serves the PR from `prs/<n>/*.json` and logs every call to
`.git/gh-calls.log`. Reads are answered. Writes (comments, replies, reviews,
edits, review requests, `resolveReviewThread`) are logged as `WRITE` and faked,
so the `gate-no-writes` grader can check that nothing was posted before the user
decided. The comment files feed the REST endpoints, `gh pr view --json
comments,reviews` and GraphQL alike.

Each `WRITE` is followed by a `POSTED` line for graders:
`POSTED<TAB><kind><TAB><target><TAB><body>`, the body on one line with `\n` for
newlines. Kinds: `reply` (target: the comment or thread id), `conversation-comment`,
`review`, `rereview` (target: the logins, from REST `requested_reviewers` or
`gh pr edit --add-reviewer`), `unrequest`, `resolve` (target: the thread id),
`description`, `other`. A posted conversation comment or inline reply is added
to the served comment files, so a later read shows it. The PR head is read from
the local origin, so a push moves it, as on GitHub.

It answers every call the skills' scripts make: `pr view --json`, `pr diff`,
`pr checks --json`, `repo view` (default branch), the three comment feeds
(paginated or not), the GraphQL `reviewThreads` query, the replies, issue
comment and `PATCH` pull endpoints, and the PR head's `.gitattributes`
(`contents/.gitattributes`, from the PR's own `files/.gitattributes`). A
resolved thread is remembered in `$GH_FIXTURE_DIR/resolved.txt`, so a later
`reviewThreads` query shows it resolved. `setup-pr.sh` adds `headRefOid` and the
size fields to the served `pr.json`. Anything else is logged `UNSUPPORTED`.

PR 104 is not used by a case: a stacked draft with a ticket key, a lockfile, an
OpenAPI spec, a generated client and a `linguist-generated` SDK, for trying
`fetch-pr.sh` by hand. Scaffold it in a temp dir with
`HOME=$tmp/home evals/_fixtures/setup-pr.sh 104` run from an empty directory,
then put `$HOME/.bin` first on `PATH` and set `GH_FIXTURE_DIR=$HOME/.gh-fixture`.

The skills' scripts share `scripts/lib/feeds.sh`, identical in both skill
folders. Check it with
`cmp skills/review-pr/scripts/lib/feeds.sh skills/review-pr-feedback/scripts/lib/feeds.sh`.

`skills/review-pr/scripts/checkout-pr.sh 104` (same setup, run from the
scaffolded repo) makes the detached worktree under `$REVIEW_POWERS_SCRATCH`;
`... 104 --cleanup` removes it.

The fake `tracker` stands in for whatever issue-tracker tool a user has. The
skill names no tracker; the agent learns of it as it would in a real repo,
from the fixture repo's `README.md` ("read tickets with the `tracker` CLI")
and `tracker --help`. It serves `prs/<n>/tickets/<KEY>.json` (`key`, `type`,
`status`, `summary`, `description`, `parent`, `assignee`, `comments`) through
`tracker view <KEY> [--fields <list>] [--json]` and `tracker comments <KEY>
[--json]`, and logs every call to `.git/tracker-calls.log`. Like common
tracker CLIs, `view` shows no comments and leaves `parent` out of its default
fields. A PR without tickets answers "not found".

To add a PR: create `prs/<n>/pr.json` (the `gh pr view --json` shape) and
`prs/<n>/files/` (files that differ from `base/`). Optional
`review_comments.json`, `issue_comments.json` and `reviews.json` use the REST
API shapes; optional `tickets/` holds the tickets the PR's chain reaches;
optional `main/` holds files on `main` that the PR doesn't touch (PR 203's
`CONTRIBUTING.md`). `NO_MAIN_FILES=1 setup-pr.sh <n> author` leaves `main/` out.
Commits get fixed dates, so commit ids are the same on every scaffold.

## Two-turn cases

`claude plugin eval` runs one prompt per case. A case with
`context.history_file` resumes a recorded session and sends `prompt.md` as the
next turn; the scaffold still builds a fresh workspace. The `close-the-loop`
cases use this: `history.jsonl` is the first turn of the matching `-gate` case
(the report, stopped at the gate), and the prompt is the user's go-ahead. The
first turn's gate graders live in the `-gate` case, since a resumed run only
sees the second turn's calls.

The recording holds the skill text of the run that made it, so re-record after
changing `review-pr-feedback`: run the `-gate` case with `--keep-temp`, copy
`<tmp>/config/projects/*/*.jsonl` over `history.jsonl`, and drop the request
cache and the user's email:

```bash
jq -c 'select((.type | tostring | test("^api-request")) | not)' session.jsonl \
  | sed 's/you@example\.com/ana-dev@acme.test/g' > history.jsonl
```

It also holds the absolute path of the plugin it ran from (the skill's script
paths). From another checkout those paths miss and the agent finds its own way
to post; the graders read the fake `gh` log either way.

## Cases

| Case | PR | Checks |
|---|---|---|
| `review-pr/explain-contract-change` | 101: endpoint shape changes; invoicing, outside the diff, breaks | Shape shown as a well-formed `diff`, not JSON; the broken invoice shown with a case |
| `review-pr/explain-with-example` | 102: merging PMS blocks loses stay lengths | Abstract bug explained with a worked example |
| `review-pr/explain-concrete-finding` | 103: unknown discount code → 500 | Concrete finding: a case, fix as a small `diff`, no other block |
| `review-pr/explain-control-flow` | 106: deposit taken before holding rooms; sold out → deposit kept (`main/` has the old flow) | Changed flow as a call tree in `text`, no diagram |
| `review-pr/explain-cross-service` | 107: async PMS blocks; the webhook can beat the stored block id and is dropped (`main/docs/pms.md` documents the webhook) | The race as a `mermaid` sequence diagram |
| `review-pr/ticket-chain` | 105: breakfast per room line; the subtask is satisfied, its parent story decided one meal plan per quote (in a comment) | The finding cites the parent's decision, with a case, the parent's comments were read, and the coverage line says the ticket chain was read |

| `review-pr-feedback/verdict-per-comment` | 201: cancel quotes; four inline comments | One right comment (shown with a case), one wrong (reviewer misreads the SQL), one right but out of scope, one trivial but cheap → do it |
| `review-pr-feedback/all-feeds` | 202: quotes expire after 14 days; comments inline, in the conversation and in a bot review body | Every comment gets a verdict, `>=` answered with real dates, and the reply says which feeds it read |
| `review-pr-feedback/close-the-loop-gate` | 203: group discount for 10+ rooms; a human and a bot each with one right and one wrong finding; `CONTRIBUTING.md` documents the bot's trigger, `/acme-review rerun` | Right verdicts, and the gate's plan names resolving the fixed threads, re-requesting `maria-k` and the bot's trigger |
| `review-pr-feedback/close-the-loop` | 203, second turn: "Go ahead with your recommendations." | `maria-k` re-requested, `/acme-review rerun` posted, fixed threads resolved, rejected ones answered and left open |
| `review-pr-feedback/close-the-loop-no-trigger-gate` | 203 without `CONTRIBUTING.md` | The plan says the bot's trigger isn't documented instead of guessing one |
| `review-pr-feedback/close-the-loop-no-trigger` | 203 without `CONTRIBUTING.md`, second turn | Nothing invented posted to the bot, the reply says its trigger is unknown, `maria-k` still re-requested |

Every `review-pr` case also checks the repo afterwards, with file graders
(there are no command graders): `.git/HEAD` still says `main`, and `file_exists`
finds no branch under `.git/refs/heads` and no worktree under `.git/worktrees`
created during the run. They fail when a PR checkout leaves a `pr-<n>` branch or
a worktree behind.

Every first-turn case also checks that nothing was written to GitHub and there
is no preamble. The `explain` cases also check `finds-the-problem`: the reply
states the PR's real problem, in any words. `concrete-example`, in the cases
that have it, checks that one named problem is shown with a case with real
values, not only in the abstract. The `review-pr-feedback` first-turn
cases also check the gate: no
`Edit`/`Write`, the tempting cheap fix still undone, no new commits and no
`AskUserQuestion`.
