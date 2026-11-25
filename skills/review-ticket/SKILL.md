---
name: review-ticket
disable-model-invocation: true
argument-hint: "<JIRA-KEY or URL>"
allowed-tools: Bash(${CLAUDE_SKILL_DIR}/scripts/* *)
description: "Review a completed Jira ticket as a whole — all its subtasks and merged PRs, across repos — for a human: contracts, deploy risk, design calls, simplifications. Files the chosen improvements as one follow-up Task."
---

# Review ticket

Flow: gather → report → discussion, if any → create the Task. If no ticket
was given, ask which one.

Every PR here was reviewed and merged; don't redo that. Review the ticket as
one change, for what no PR-level pass could see: a contract that drifted
between backend and frontend, a helper built twice, scaffolding a later PR made
obsolete, a deploy order nobody wrote down. A finding is the case for a
follow-up worth its cost, not a blocker.

## Gather

Needed: the ticket and every subtask; every PR whose title or branch names a
key, with its changes and review feeds; per repo, the code at its default
branch and its AI context. No ticket or no PR changes: stop and say what's
missing. Anything else missing: name it in what you read.

- **Script**: with Python 3, `gh`, `git` and `acli` logged in, run
  `${CLAUDE_SKILL_DIR}/scripts/gather.py [--owner <owner>] [--repos-dir <dir>] <KEY> <scratchpad>/gather`
  in the background, unpiped, and read `<scratchpad>/gather/index.md` as it
  fills: a foreground run shows nothing and can time out silently. A repo
  still PENDING once the run ended was not gathered: treat it as FAILED.
  Don't ask for the options: `--owner` when the context names the GitHub user
  or org, `--repos-dir` when it says where the clones live.
- **No script**: collect it with your tools and lay it out as
  [layout.md](layout.md) says.
- **Read from the index outward**, broadly:
  - Jira: descriptions, ACs, comments, links, parent. Their decisions
    (approach, split, scope cuts) are claims to check, not the yardstick.
  - PRs: decide which of the index's loose ones belong (keys with no PR, PRs
    naming a key only in their body). A subtask with no PR: say so.
  - Review threads: what was deferred or accepted as a trade-off, and whether
    it landed.
  - Repo docs: design docs, ADRs, `docs/` the change touched or should have.
- **Each repo's rules**: its AI context won't load on its own. Its
  `context.md` lists the files in two groups, because a long flat list goes
  unread:
  - always (root files, those scoped to the touched code): before judging
    that repo's code;
  - broad (per file type, every file): when judging its conventions.

  Follow what they point to when it bears on the change; nearest the code
  wins. A FAILED repo: say its code and context went unread.
- **Code trees** are detached worktrees in the scratchpad; never read the
  user's working tree. Remove them at the end (`gather.py --cleanup <dir>`).
- **No subagents**: they start cold and re-read what you have; so far that
  doubled the cost without sharper findings.

An unread feed and a clean one look identical in a report; say which you read.

## The questions

Heaviest first. Say which came back empty, as distinct from unexamined.

- **Does the whole deliver what was asked?** Each AC to the code and test
  that satisfy it; gaps live at the seams between subtasks.
- **Were the ticket's own decisions right?** Approach, split, scope cuts,
  trade-offs accepted in review, now seen whole: an approach that forced
  workarounds, one concern split in two. Bring evidence; the call is the
  user's.
- **Is there a real bug?** Especially across PRs: a state one side produces
  that the other doesn't handle. Show the path.
- **Do contracts hold end to end?** What the backend sends versus what the
  frontend reads: naming, nullability, enums; what consumers relied on.
- **What happened at deploy, and what's owed?** Migrations unsafe while the
  old version served, cross-repo merge order, flags awaiting rollout or
  cleanup.
- **Which design calls should the user check by hand?** Data shape,
  contracts, abstractions, permissions, labels: it works as built, but should
  it? Say where your judgment ends.
- **Can it be simpler now that it's whole?** Duplication, leftover
  scaffolding, single-use abstractions, what the codebase already had.
- **Does it follow the patterns here?** Each repo's rules, and consistency
  across subtasks.
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
and one wrong result is its own case, and a sentence is enough. A case that unfolds in steps
(a rollout, retries, a race) gets a few lines in `text`:

```text
Old pods still serve while the migration drops `quote.status`.
  during rollout:  old code selects it → 500 on every quote read
  safe:            stop reading it now, drop it next release
```

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

## The report

Plain conversation text, not a dialog. In order:

1. **What it is**: linked title, who uses it and what they can now do in a
   user's words, how it shipped (PRs per repo, last merge, flag state).
   ```text
   # [ABC-123](https://example.atlassian.net/browse/ABC-123): <title>
   When a guest picks a rate, the booking page shows what it includes (e.g. breakfast) and adds its price to the total.
   5 PRs in hotel-api and 2 in web, last merged 11-06, no feature flag.
   ```
   Then one `mermaid` diagram per main action a user or system now does with
   it (calculate a price, create an order, a webhook confirming), trigger to
   answer, under a line naming it:
   - one each, even when they run one after another, or the reader can't
     tell where one ends;
   - `sequenceDiagram`, or `stateDiagram-v2` for a lifecycle;
   - an `erDiagram` of the changed stored data as it is now, only with three
     entities or more;
   - only the pieces needed to follow it, in the user's words, no PR numbers;
     none when it stays inside one component.
2. **What I read**: the feeds and repos' context, and what's missing.
3. **Findings**, numbered: only work to file (bugs, contract drift, AC gaps,
   simplifications, leftovers), each with evidence (`file:line` on the
   default branch, PR) and value against cost.
4. **Owed, not code**: DEV checks, QA evidence, ACs to rewrite, sign-offs. No
   PR carries them, so a code Task closes without them.
5. **Design calls**, unnumbered: the call and its concrete case.

Order findings by what ignoring each would cost, worst first: the user may
stop reading anywhere. Start each with a tag for what it is about: Bug,
Product, Tests, Design, Docs, Security, Deploy, Conventions, Localization,
Scope, Nit, or a better word when none fits. One tag; when two fit, pick by what
goes wrong if it's ignored.

Every item ends with what you'd do (`→ file`, `→ skip`). Trace each through every layer it crosses
(can the frontend read that response, does it race with a worker, does
removing X change the result); untraced, say so. Never comment on PRs.

Close with **What I'd do**: your verdict in one sentence and what you'd file.
A question still open goes there, not after it. Then the next step, in this
order:

1. Create the Task.
2. Generate the HTML report: `review-<KEY>.html` in the current directory,
   not the scratchpad; the whole report in its order and tags,
   self-contained except Mermaid from a CDN at a pinned version, light and
   dark. Give its path, then offer 1 and 3 again.
3. See the draft first.

Then stop. File nothing until the user answers.

## Discussion

Optional. The user may question findings or change what gets filed. A
reframed premise means rerunning the reasoning. Answer, then offer the next
step again.

## Create the Task

When the user says to create it, create it: no draft, no second confirmation.
Show the draft only if asked.

One Task, unassigned:

- **Project and parent**: the ticket's (no parent: ask).
- **Title**: `Review <KEY>: <ticket title>`.
- **Description**: the review as the user shaped it, for an agent with none
  of this conversation. Sections, empty ones left out:
  - **What it is**, **Verdict** (its sentence in What I'd do): from the
    report, each diagram as a `mermaid` code block.
  - **To do**: per chosen finding, where (repo, `file:line`, PR), its case
    from the report, which doubles as "done when". A fix is a candidate
    naming its assumption; the implementer chooses.
  - **Owed, not code**: one `- [ ]` each.
  - **Discarded**: each with one line of why, so the next review doesn't
    raise it again.
  - **Design calls**: what was decided.

Write it in what `md2adf.sh` handles (headings, lists, checkboxes, code
blocks, `code`, **bold**, links), then:

```bash
${CLAUDE_SKILL_DIR}/scripts/md2adf.sh task.md task.json
acli jira workitem create -p <PROJECT> -t Task -s "<title>" --parent <PARENT> --description-file task.json --json
acli jira workitem link create --out <NEW> --in <KEY> --type Relates --yes
```

`<NEW>` is the create output's `key`. Without `acli`, any Jira tool for the
same Task and link. Report the key, URL and failures.
