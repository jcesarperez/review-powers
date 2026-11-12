# review-powers

Review PRs faster. Focus on what matters. Make the call.

The bottleneck has moved from writing code to reviewing it. If AI writes code better than we do, AI can also review code better than we do.

So a while ago I stopped reviewing code and started reviewing the reviews the AI does. That's where I decide what changes and what doesn't. On my teammates' PRs, and on the feedback they leave on mine.

These are the skills I use every day to do that.

The third one goes a step further: it reviews a whole story or ticket at once, with all its PRs, even across repos. That's one review instead of many, and it catches what slips through when you look at each PR on its own: a backend and a frontend that disagree on a field, an AC that every PR assumed another one covered, scaffolding a later PR made obsolete.

## The skills

| Skill | When | What you get |
|---|---|---|
| `review-pr` | You have to review someone's PR | What could break at deploy, real bugs, design calls you should check yourself, tests, simplicity. Then a numbered list of findings with a recommendation for each. |
| `review-pr-feedback` | You got review comments on your PR | A verdict per comment: is it right, and is it worth doing? Then it fixes what you pick and replies to every comment. |
| `review-ticket` (beta) | A Jira story or ticket is done: all its PRs merged, maybe across repos | The ticket reviewed as one change. What no single PR review could see: contracts that drifted between repos, ACs nobody covered, leftovers, what's still owed at deploy. Then it files the improvements you pick as one follow-up Task. |

All three stop and wait for you. Nothing gets commented, committed, pushed or filed until you decide.

`review-ticket` is in beta: I use it on real tickets, but its report and the follow-up Task are still changing.

They don't teach your agent how to code. Your code and architecture conventions belong in your own setup (`CLAUDE.md`, `AGENTS.md`...). These skills only decide what lands on your desk and how.

## Install

```bash
npx skills add jcesarperez/review-powers
```

That installs them in the current project. Add `-g` to install them for all your projects.

It works with Claude Code, Codex, Cursor, Copilot, Gemini CLI and other agents that support skills ([skills CLI](https://github.com/vercel-labs/skills)).

### Claude Code plugin

```
/plugin marketplace add jcesarperez/review-powers
/plugin install review-powers@review-powers
```

### Latest development version

`main` is always the latest release. To try what is coming next:

```bash
npx skills add jcesarperez/review-powers#develop
```

### Manual

Copy the folders in `skills/` into `.claude/skills/` (project) or `~/.claude/skills/` (global), or into your agent's skills folder.

## Use

```
/review-pr https://github.com/acme/shop/pull/1234
/review-pr-feedback https://github.com/acme/shop/pull/1234
/review-ticket ABC-123
```

With the plugin they are `/review-powers:review-pr`, `/review-powers:review-pr-feedback` and `/review-powers:review-ticket`.

They only run when you call them. The agent never loads them on its own, so they cost no context until you need them. This is set with `disable-model-invocation: true`, which is confirmed in Claude Code. Other agents may ignore it.

## Requirements

| | `review-pr` | `review-pr-feedback` | `review-ticket` |
|---|:-:|:-:|:-:|
| bash | ✓ | ✓ | ✓ |
| [GitHub CLI](https://cli.github.com) (`gh`), logged in | ✓ | ✓ | ✓ |
| [`jq`](https://jqlang.github.io/jq) | ✓ | ✓ | ✓ |
| `git` | ✓ | ✓ | ✓ |
| [Atlassian CLI](https://developer.atlassian.com/cloud/acli) (`acli`), logged in to your Jira site | | | ✓ |
| Python 3.8+ (standard library only) | | | ✓ |

- **`review-pr`** reads the PR, its diff, CI and comments through `gh`. It uses `git` to check the PR out in a separate worktree when the diff alone isn't enough. It reads the ticket through whatever Jira tool your agent has, if any.
- **`review-pr-feedback`** reads the comments and posts the replies through `gh`. It works in your own checkout of the PR's branch, and uses `git` to check that it's at the PR's latest commit.
- **`review-ticket`** reads Jira through `acli`, and the PRs through `gh`. It reads each repo's code and its own `CLAUDE.md`, `AGENTS.md` and rules from a worktree of your local clone, or a fresh clone when you have none. It also files the follow-up Task through `acli`, after a bash and `jq` script turns the Markdown into Jira's format.

## What a report looks like

Shortened and made-up, but in the shape the skills actually produce.

Every finding leads with a concrete case, so you can judge it without opening the code. Then the evidence, what was verified and what wasn't, and a recommendation weighed against what it costs to fix.

**`review-pr`**

> **My take: safe to merge once one thing is fixed. I'd request changes.**
>
> **What I read:** the description, the full diff, CI (green), two earlier reviews, and every caller of `OrderRepository.Find`. Not stacked on another PR.
>
> **Looked at, nothing found:** business logic, tests, patterns. **Not examined:** frontend (none in this PR).
>
> 1. **The migration drops `orders.status` while old pods still read it.**
>    ```
>    during rollout:  old code selects it → 500 on every order read
>    safe:            stop reading it now, drop it next release
>    ```
>    `migrations/0042_drop_status.sql:3`, `OrderRepository.cs:88`
>    **Recommendation:** request changes. Splitting it in two releases is cheap.
>
> 2. **Design call for you: refunds are now allowed on orders that haven't shipped.**
>    ```
>    before:  refund on a packed order → rejected
>    now:     refunded, and the warehouse still ships it
>    ```
>    The ticket doesn't say which is intended, so this is your call, not mine.
>    **Recommendation:** ask the author before merging. Cheap to check, expensive to get wrong.
>
> 3. **`PriceFormatter` duplicates `Money.Format`.** `PriceFormatter.cs:12`, `Money.cs:40`
>    **Recommendation:** inline comment, not blocking.
>
> Which ones do you want me to post?

**`review-pr-feedback`**

> **2. Removing a row keeps its discount (reviewer, warning): correct, and worse than stated.**
>
> - **Case:** Ana adds a Double and a Suite. One request returns the discounts for both and every row keeps that list. She removes the Suite, and the Double still shows "Suite upgrade -10%". The checkout charges it.
> - **Verified:** by reading `useCartPrices.ts:97`. I didn't run it, and no test covers removal.
> - **Counterpoint:** the reviewer's fix (ask the API which row each discount belongs to) is the right one, but it needs a backend change.
> - **Cost:** refetching on removal is about 20 lines and one test. The backend fix is a separate ticket.
> - **Recommendation:** refetch in this PR, open a ticket for the backend.

**`review-ticket`** (beta)

> **[ABC-123](https://example.atlassian.net/browse/ABC-123): Show what a rate includes**
> When a guest picks a rate, the booking page shows what it includes (e.g. breakfast) and adds its price to the total.
> 4 PRs in hotel-api and 2 in web, last merged 11-06, no feature flag.
>
> **My take: it works for the common case, but backend and frontend disagree on one field, and one AC has no code.** I read the ticket, its 5 subtasks, all 6 PRs with their reviews, and each repo's `CLAUDE.md` and rules.
>
> 1. **Bug: a rate with nothing included breaks the booking page.**
>    ```diff
>     GET /api/v1/rates/{rateId}
>       response Rate
>    -    inclusions: Inclusion[]   (what web expects)
>    +    inclusions: Inclusion[]?  (what hotel-api sends: null when empty)
>    ```
>    A room-only rate sends `null`, and `RateCard.tsx:41` calls `.map` on it, so the page goes blank. Each PR's tests used rates with breakfast, so neither review could see it.
>    `RateDto.cs:18` (hotel-api#212), `RateCard.tsx:41` (web#88)
>    **Recommendation:** send an empty list from the backend. One line and one test.
>
> 2. **Product: AC 3 ("the price shows per night") has no code.** Subtask ABC-125 says ABC-127 covers it, and ABC-127 says the opposite. Today a 3-night stay shows the breakfast price once, and the total charges it 3 times.
>    **Recommendation:** file it. It's the one AC the guest sees wrong.
>
> 3. **Design: the inclusion price is calculated twice,** in hotel-api (`InclusionPricing.cs`) and again in web (`useInclusionTotal.ts`). They agree today, but a change to one will make them drift.
>    **Recommendation:** use the backend's total in web and delete the hook. About 40 lines removed.
>
> **Owed, not code:**
> - The ticket asks for QA evidence on mobile; none is attached.
>
> **Design calls:**
> - Inclusions are per rate, not per room: two rooms on the same rate can't differ. That matches the ticket, but check it's what product wants.
>
> **What I'd file:** 1 and 2, plus the QA check. 3 can wait.
>
> Which ones go in the follow-up Task?

## License

MIT
