---
name: review-pr-feedback
disable-model-invocation: true
description: "Work a PR's review feedback end to end, from verdicts to replies."
---

# Review PR feedback

Review feedback is **not a to-do list**. This skill sorts it against the real
code, hands the user a verdict they can argue with, and only then acts.

## Know what you actually read

Feedback hides on more feeds than the one you opened, so account for the feeds,
not just the findings — an unread feed and an empty one look identical in a
report, and only one of them is honest. The same doubt covers the tree you are
standing in: a `file:line` from the wrong commit is fiction.

## Verify, don't believe

A finding is a claim, not a fact. Read the code it points at — and, when it is
about a symbol the diff merely uses, the code *behind* that. Cite `file:line`, or
say **unverified** and what would settle it. Prefer an observation over an
argument: run the test, inspect the artifact, query the database.

Apply this symmetrically. Human and AI reviewers are both wrong sometimes; what
differs is **scope**, not credibility — an agent is likelier to ask for work past
the PR's boundary.

## Correct and worth doing are two questions

Answer them separately for each finding. A correct finding can be too costly, out
of the PR's scope, or too trivial to spend a commit on — and a **cheap** fix
inverts that last one: once fixing costs less than litigating, correctness alone
carries it.

The finding worth most is the one the reviewer **understated** — a real mechanism
whose consequence is worse than the sentence describing it. Verification is how
you find those.

## Explain it to someone who doesn't know the code

The user often hasn't read this code, so `file:line` citations alone don't
land. **Lead each finding with one concrete case** — the input and what goes
wrong, or the code's shape before and after — then the citations as evidence.
A few lines:

```text
Ana adds 10 rooms; the inclusions read gets a 403.
  today:  502 → "something went wrong", no sign-in prompt
  fixed:  401 → sign-in prompt, same as when pricing gets a 403
```

Skip it when the finding is already concrete.

## The gate

Present the verdicts in the conversation and **stop**. Nothing is edited,
committed, pushed, or replied to before the user answers.

Give them the argument, not just the conclusion: the citation, the strongest
counterpoint, a value-versus-cost read, your recommendation. The user's call
on which findings to take is the decision this skill exists to serve — a run that fixes everything the
reviewer asked has skipped its own point.

Their answer can reframe a premise ("we're pre-GA, deleting data is fine") rather
than accept or reject. That is a new fact — rerun the reasoning under it, since
the finding may now hold for a different reason, or stop holding at all.

Present this as normal conversation text, not a dialog/question-tool prompt.
The user's reply may reframe the premise entirely, carry nuance across several
findings, or argue back — none of which a fixed-option dialog can hold.

## Prove each fix the way it would fail

Match the evidence to the failure mode, and prove it where the output actually
lands — which is often somewhere the edit never mentions, like the generated
artifact carrying contract text you changed at the source.

When something fails, find out whether **you** caused it before you own it: a
pre-existing failure is reported, not fixed silently and not treated as a
blocker. Name which part is red, every time you report a run.

A **stacked** child branch is part of this job, not a follow-up: rebase it,
re-run it, and check whether the parent's fix changed something the child
asserts.

## Reply to every finding, including rejected ones

An unanswered finding reads as ignored. Concise, kind, non-pedantic: what you
did and why, pointing at the commit — or, for a rejection, what the code actually
does.

**State every deviation plainly**, to the reviewer and to the user: where you
did something other than what was asked, say so, say why, and invite the
correction. This holds for deviations from the user's instruction too. A
confident summary covering an unproven claim or a quiet deviation is the one
outcome this skill cannot recover from.
