# review-powers

Review PRs faster. Focus on what matters. Make the call.

The bottleneck has moved from writing code to reviewing it. If AI writes code better than we do, AI can also review code better than we do.

So a while ago I stopped reviewing code and started reviewing the reviews the AI does. That's where I decide what changes and what doesn't. On my teammates' PRs, and on the feedback they leave on mine.

These are the two skills I use every day to do that.

## The skills

| Skill | When | What you get |
|---|---|---|
| `review-pr` | You have to review someone's PR | What could break at deploy, real bugs, design calls you should check yourself, tests, simplicity. Then a numbered list of findings with a recommendation for each. |
| `review-pr-feedback` | You got review comments on your PR | A verdict per comment: is it right, and is it worth doing? Then it fixes what you pick and replies to every comment. |

Both stop and wait for you. Nothing gets commented, committed or pushed until you decide.

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

### Manual

Copy the folders in `skills/` into `.claude/skills/` (project) or `~/.claude/skills/` (global), or into your agent's skills folder.

## Use

```
/review-pr https://github.com/acme/shop/pull/1234
/review-pr-feedback https://github.com/acme/shop/pull/1234
```

With the plugin they are `/review-powers:review-pr` and `/review-powers:review-pr-feedback`.

They only run when you call them. The agent never loads them on its own, so they cost no context until you need them. This is set with `disable-model-invocation: true`, which is confirmed in Claude Code. Other agents may ignore it.

## Requirements

- [GitHub CLI](https://cli.github.com) (`gh`), logged in. The skills read PRs, diffs, CI and comments through it.

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

## Coming next

`review-ticket`.

## License

MIT
