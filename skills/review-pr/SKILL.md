---
name: review-pr
disable-model-invocation: true
description: "Review a PR: bugs, deploy risk, important decisions, architecture consistency, tests, simplicity, comment abuse."
---

# Review PR

If no PR was given, ask which one — don't guess from the current branch.

We ship to a high-availability product. The cost of a bad merge is not a
revert, it's a revert under load. Read for that.

## Know what you actually read

`gh pr diff` shows what changed, not what depends on it. A signature that
reads correct in the diff has call sites the diff never mentions, and a
migration reads fine right up until you look at what queries the column.
So read past the boundary whenever the change touches something other code
uses — a worktree checkout of the PR when the diff alone won't settle it.

Account for the feeds, not just the findings. The description (which states
intent, and makes claims worth checking rather than trusting), CI, existing
review comments, and whether this PR is stacked on another are each either
read or unread — and an unread feed and a clean one look identical in a
report. Only one of them is honest.

Someone — or something — has often reviewed this before you, whether an
automated reviewer or a colleague. Don't restate what they already raised,
and don't treat their ground as covered either: their findings are claims to
verify like any other. Your value is in the questions they didn't ask, which
with an automated pass is usually the same two: business logic that is wrong
rather than unsafe, and design calls that need a human.

Establish early whether this is a backend or a frontend PR. It decides which
of the questions below are live and which are silent.

## The questions

These are the reviewer's questions, heaviest first. Not a checklist to fill —
most PRs answer two or three and the rest are genuinely silent. Say which
ones you looked at and found nothing in; that is a different statement from
not having looked.

- **Is there a real bug in the business logic?** Not style, not theory — a
  path that produces the wrong answer, a race, an edge case the rules of the
  domain care about and the code doesn't. Show it: the input or sequence that
  takes the bad path.
- **What happens at deploy?** Breaking changes are the standing risk here.
  An API or event contract consumers already depend on, a migration that
  can't run while the old version is still serving, a config or flag that
  must land in an order nobody wrote down, state that outlives the deploy.
  Ask whether old and new can run side by side, because for a while they will.
- **Are the design calls right — and should the user check any by hand?**
  Database shape, contracts, interfaces with other systems, and whether the
  acceptance tests exercise them the way a consumer actually would. These are
  the findings where your judgment runs out and theirs starts; say so
  explicitly rather than guessing, and name what you'd want them to look at.
- **Can it be simpler?** What should be simplified, refactored, or replaced
  by something the codebase already has. Reuse is the cheapest maintainability
  win and the easiest to miss from inside a diff.
- **Does it follow the patterns already here?** And where it deviates — is
  the deviation argued, or accidental?
- **Can I trust that the change is covered by tests?** Three questions, not
  one: whether the behaviour that matters is covered at all, whether it's
  covered at the right level, and whether what's covered is what the ticket's
  acceptance criteria actually asked for. A unit test standing in for an
  integration concern passes while the thing it claims to protect is broken,
  and a green suite that never touches an AC proves nothing about the feature.
- **Is there comment abuse?** AI-authored code produces a lot of it:
  redundant restatement, archaeology, narrating the change to the reviewer.
  Raise it as a maintainability finding, not a nitpick.

On a frontend PR, the deploy and design questions still apply, they just
point elsewhere: the API contracts this code consumes, state and cache
correctness, what the user sees while a request is in flight or fails, and
whether the change is reachable by keyboard and screen reader.

## Explain it to someone who doesn't know the code

The user often hasn't read this code, so `file:line` citations alone don't
land. Skip preambles and keep prose brief and plain: what goes wrong and why,
in everyday words. Names in backticks point at the code; they don't explain
it. A term they would have to look up gets a few words or stays out.

**Lead each finding with one concrete case**, then the citations as evidence.
An abstract point needs numbers: "3 shirts in M + 1 in L, merged by product →
the warehouse ships 4 in M". A finding that is already one input and one wrong
result is its own case, and a sentence is enough.

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

The inline comment is for the author, who knows the code: keep the case,
drop the explanation.

## The gate

Open with your verdict, then say what you covered — which feeds you read,
and which questions came back empty versus unexamined.

Then a numbered list of findings the user can act on — ignore, or leave as an
inline PR comment — each with your own recommendation, weighed against its
cost to fix, including whether the set warrants a plain comment or a request
for changes. Do nothing until they choose.

Concise, kind and non-pedantic govern how a comment is written, never whether
it is raised. An inline comment's line is part of the comment, so verify where
each one actually landed and tell the user.
