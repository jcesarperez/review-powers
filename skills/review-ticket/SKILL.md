---
name: review-ticket
disable-model-invocation: true
argument-hint: "<JIRA-KEY or URL>"
allowed-tools: Bash(${CLAUDE_SKILL_DIR}/scripts/* *)
description: "Review a completed Jira ticket as a whole — all its subtasks and merged PRs, across repos — for a human: contracts, deploy risk, design calls, simplifications. Files the chosen improvements as one follow-up Task."
---

# Review ticket

If no ticket was given, ask which one.

Every PR here was reviewed and merged; don't redo that. This review is for
what no PR-level pass could see: the ticket as one change. Each PR can be
right while the whole is wrong — a contract that drifted between backend and
frontend, a helper built twice, scaffolding a later PR made obsolete, a deploy
order nobody wrote down. It's already merged, so a finding is the case for a
follow-up worth its cost, not a blocker.

## Gather before judging

The request names only the ticket; what you need is spread across Jira,
GitHub and several repos. Run
`${CLAUDE_SKILL_DIR}/scripts/gather.sh [--owner <owner>] [--repos-dir <dir>] <KEY> <scratchpad>/gather`.
It writes the ticket, every subtask, every PR whose title or branch names a
key, each PR's comment feeds, and per repo the code at its default branch,
then prints an index of what it found, missed and failed. Don't ask the user
for the options: pass `--owner` when the context already names the GitHub
user or org (a CLAUDE.md, the repo you're in), and `--repos-dir` when it says
where their clones live. Without `--owner` the script searches everything the
user can see and the index says which owners it found.

Read from the index outward — review feeds make PR folders long. Look broadly:

- **Jira** — the ticket, every subtask, their descriptions, ACs, comments,
  links and parent. If the script can't read the ticket, try any Jira tool
  the environment has; if that fails too, stop. Descriptions record
  decisions — approach, split, scope cuts — so treat them as claims to check,
  not as the yardstick.
- **PRs** — the index lists keys with no PR and PRs that only mention a key
  in their body; decide which belong. If a subtask has none, say so.
- **Review threads** — what reviewers deferred ("follow-up", "later", "out
  of scope") or accepted as a trade-off, and whether it ever landed.
- **Repo docs** — design docs, ADRs, `docs/` the change touched or should have.

An unread feed and a clean one look identical in a report; say which you read.

## Read each repo with its own rules

You are not running inside these repos, so their AI context (CLAUDE.md,
AGENTS.md, rules) won't load on its own, and it's what separates a deviation
from the convention. For each repo the index points at a `context.md`: the
files that apply to what the PRs touched, each with why, and the rules that
don't. Read them before judging that repo's code, and follow what they point
to when it bears on the change. Where two disagree, the one nearest the code
wins. A repo the index marks FAILED has unread code and context; say so.

The code trees are detached worktrees of the user's clones (or fresh clones)
in the scratchpad; never read the user's working tree. Remove them when the
review ends with `gather.sh --cleanup <dir>`. Read the code yourself rather
than through subagents: they start cold and re-read what you already have,
and so far that has doubled the cost without making a run faster or its
findings sharper.

## The questions

Heaviest first. Most tickets answer a few; say which you looked at and found
empty, as distinct from unexamined.

- **Does the whole deliver what was asked?** Map each AC to the code and test
  that satisfy it. Gaps live at the seams between subtasks.
- **Were the ticket's own decisions right?** The approach, the subtask split,
  the scope cuts, the trade-offs accepted in review. With everything merged
  you can see what the author couldn't: an approach that forced workarounds,
  a split that put one concern in two places. Bring the evidence; the call is
  the user's.
- **Is there a real bug?** Especially across PRs — a state one side produces
  that the other doesn't handle. Show the path.
- **Do contracts hold end to end?** What the backend sends versus what the
  frontend reads; naming, nullability, enums that drifted; anything consumers
  relied on.
- **What happened at deploy, and what's still owed?** Migrations unsafe
  while the old version served, cross-repo merge order, feature flags
  awaiting rollout or cleanup.
- **Which design calls should the user check by hand?** Data shape,
  contracts, new abstractions, permissions, labels: anything that works as
  built where the question is whether it should. Say where your judgment ends.
- **Can it be simpler now that it's whole?** Duplication, leftover
  scaffolding, single-use abstractions, things the codebase already had.
- **Does it follow the patterns here** — each repo's rules, and its own
  consistency across subtasks?
- **Are the ACs covered by tests at the right level?**
- **What was left behind?** Deferred items, TODOs, dead code, stale docs,
  comment abuse.

## Explain it to someone who doesn't know the code

The user decides from the report and rarely opens the code. Skip preambles
and keep prose brief and plain: what goes wrong and why, in everyday words.
Names in backticks point at the code; they don't explain it. A term they
would have to look up gets a few words or stays out.

**Lead each finding with one concrete case**, then why it happens.
An abstract point needs numbers: "3 shirts in M + 1 in L, merged by
product → the warehouse ships 4 in M". A finding that is already one input
and one wrong result is its own case, and a sentence is enough.

Add a view only where prose would leave the reader rebuilding a shape or a
flow. Pick the smallest one that makes the point, next to the sentence it
supports:

- What changes in something that already exists, a shape (route, fields with
  type and nullability, table columns) or the fix you propose, as a `diff`,
  never raw JSON:

  ```diff
   GET /api/v1/orders/{orderId}
     response Order
       id: uuid
  +    shipments: Shipment[]  (required)
  -    legacyTotal: decimal?
  ```

- Changed control flow as a call tree or pseudocode in `text`, the new step
  marked.
- An interaction across services as a `mermaid` sequenceDiagram, when prose
  would need more than two sentences.
- Which files changed as a shallow file tree, only when that matters.

Usually one kind of view, sometimes two. Use your judgement and don't
overwhelm the user.

Carry the case into the follow-up Task: it doubles as the check that the
change is done.

## The gate

Plain conversation text, not a dialog. In order:

1. **What it is**: linked title, then who uses it and what they can now do,
   in a user's words, then how it shipped (PRs per repo, last merge, flag
   state).
   ```text
   # [ABC-123](https://example.atlassian.net/browse/ABC-123): <title>
   When a guest picks a rate, the booking page shows what it includes (e.g. breakfast) and adds its price to the total.
   5 PRs in hotel-api and 2 in web, last merged 11-06, no feature flag.
   ```
2. **Verdict**: your view of the ticket and what you covered — which feeds
   and which repos' context you read.
3. **Findings**, numbered: only work to file (bugs, contract drift, AC gaps,
   simplifications, leftovers). Each with evidence (`file:line` on the
   default branch, PR) and value against cost.
4. **Owed, not code**: DEV checks, QA evidence, ACs to rewrite, sign-offs. No
   PR carries them, so a code Task closes without them.
5. **Design calls**, unnumbered: the call and its concrete case.

Order findings by what ignoring each would cost, worst first: the user may
stop reading anywhere. Start each with a tag for what it is about: Bug,
Product, Tests, Design, Docs, Security, Deploy, Conventions, Localization,
Scope, Nit, or a better word when none fits. One tag; when two fit, pick by what
goes wrong if it's ignored.

Every item gets a recommendation; close with what you'd file. Trace each
recommendation through every layer it crosses: can the frontend read that
response, does it race with a worker or an in-flight request, does removing X
change the result. Untraced, say so. A reframed premise means rerunning the
reasoning. Do nothing until the user chooses. Never comment on PRs.

## File the follow-up

One Task, unassigned:

- **Project and parent**: the ticket's (no parent: ask).
- **Title**: `Review <KEY>: <ticket title>`.
- **Description**: the whole review as the user shaped it, for an agent with
  none of this conversation. What was left out stays visible, so the next
  review doesn't raise it again. Sections, empty ones left out:
  - **What it is**, **Verdict**: from the gate.
  - **To do**: per chosen finding, where (repo, `file:line`, PR), the problem
    as an observable case, and "done when". A fix is a candidate naming its
    assumption; the implementer chooses.
  - **Owed, not code**: one `- [ ]` each.
  - **Discarded**: each with one line of why.
  - **Design calls**: what was decided.

Show the Markdown draft. On confirmation, convert it to ADF (checkboxes need
it), create, link, and report the key, URL and failures. `md2adf.sh` handles
headings, lists, checkboxes, code blocks, `code`, **bold** and links; write
the draft in those.

```bash
${CLAUDE_SKILL_DIR}/scripts/md2adf.sh task.md task.json
acli jira workitem create -p <PROJECT> -t Task -s "<title>" --parent <PARENT> --description-file task.json --json
acli jira workitem link create --out <NEW> --in <KEY> --type Relates --yes
```

`<NEW>` is the `key` of the create output.
