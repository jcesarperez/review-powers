# review-powers

Skills that turn AI code reviews into decision reports: the user reviews the review, then decides. The skills are the product; everything else supports them. Pitch and install paths: `README.md`.

## Skills

- **`review-pr`:** reviews someone's PR → numbered findings, each with a recommendation.
- **`review-pr-feedback`:** verdict per review comment on your PR → fixes what the user picks, replies to every comment.
- **`review-ticket`:** a finished Jira ticket as one change, across its subtasks, PRs and repos → findings, what's owed, design calls; files the chosen ones as one follow-up Task.

## Editing skills

- **Gate:** stopping for the user's decision is the point of every skill; every change keeps it.
- **Judgement over rules:** a skill is prose that shapes judgement. Prefer a principle with its reason to a new rule.
- **Evidence:** change a skill in response to an observed failure, and say how you'd check it: the eval cases it touches, or a real PR (or ticket) to try it on.
- **Repeated corrections:** when the user corrects the same behaviour twice, it becomes an eval case, written even if not run.
- **Shared parts:** each folder installs on its own, so some things are identical across skills; edit all of them. "Explain it to someone who doesn't know the code" up to "don't overwhelm the user" (all three); the order-and-tag paragraph of the gate (`review-pr` and `review-ticket` word for word; `review-pr-feedback` adds "not in the reviewer's order"); and `scripts/lib/feeds.sh`, the feed-fetching code that `fetch-pr.sh` and `feeds.sh` source (`review-pr` and `review-pr-feedback`; check with `cmp skills/review-pr/scripts/lib/feeds.sh skills/review-pr-feedback/scripts/lib/feeds.sh`). `review-ticket`'s `gather.py` has its own port of it: a change to how feeds are fetched or written belongs in both, or say why not.
- **Scripts:** mechanics (fetching, filtering, replying) live in `skills/<name>/scripts/`; `SKILL.md` says when to run them and keeps the judgement. Bash 3.2, `gh` and `jq` only, except `review-ticket`: `gather.py` is Python 3 (stdlib only), with `gh`, `git` and `acli`, because bash 3.2 crashed (SIGBUS) resolving a large repo's context (#13); its `md2adf.sh` stays bash.
- **Tests:** `review-ticket`'s scripts have deterministic tests: `tests/review-ticket/run.sh` (free, seconds, no network). Run them (CI does too) after changing `gather.py` or `md2adf.sh`. `--update` rewrites the goldens in `expected/`; read that diff before committing, since the goldens are the spec. A new `gh` or `acli` call needs a fixture in `tests/review-ticket/fixtures/`, or the fake fails loudly.

## Workflow

- **Two branches:** single author, no PRs. `main` is the default branch and holds only the latest release: everything users install (`/plugin`, `npx skills add`, manual copy) clones it. Work happens on `develop`: commit straight to it and push. A commit that finishes an issue says `Closes #<n>`.
- **Release:** bump `version` in `.claude-plugin/plugin.json`, move `[Unreleased]` in `CHANGELOG.md` under `## [X.Y.Z] - <date>`, push `develop`, wait for CI, then `scripts/release.sh X.Y.Z` (`--dry-run` first). It fast-forwards `main` to `develop`, tags `vX.Y.Z` and creates the GitHub Release. Never push to `main` by hand, never release unasked.
- **Local use:** `~/.claude/skills/<name>` symlinks to `skills/<name>` in this checkout, which stays on `develop`; the release script never checks out another branch. Don't also install the plugin on this machine, or skills appear twice.
- **CI:** `.github/workflows/ci.yml` runs on `develop`, `main` and PRs: manifests, skill names, the two `lib/feeds.sh` copies, `review-ticket` tests. On `main` it also checks that `plugin.json`, `CHANGELOG.md` and the tag agree.

## Layout

```text
skills/<name>/SKILL.md      the skills
skills/<name>/scripts/      what the skills run: fetch-pr.sh; feeds.sh, reply.sh (lib/feeds.sh in both); gather.py, md2adf.sh
.claude-plugin/             plugin + marketplace manifests (version lives in plugin.json)
evals/<skill>/<case>/       eval cases: prompt.md, case.yaml, graders/, scaffold.sh (+ history.jsonl for a second turn)
evals/_fixtures/            fake hotel-api repo, its PRs, and a fake `gh`
tests/review-ticket/        run.sh, fake gh + acli (bin/), fixtures/, goldens (expected/)
CHANGELOG.md                Keep a Changelog, semver
```

## Evals

- **Optional:** run evals only when the user asks. Each agent run costs ~$0.30 and ~1 min, so the full suite is ~$10. You may suggest the cases a change touches, with their cost, and wait for a yes.
- **Run:** `claude plugin eval . --scaffold --allow-tools Bash Edit Write --judge-model sonnet -j 4`; without `-j` runs go one at a time. Without `--ablation none` it also runs every case without the plugin, as a baseline, which doubles the cost.
  Without a terminal (an agent's shell), add `--trust-plugin`.
- **Targeted:** `--case <name>` (the `name:` in `case.yaml`; one per run, a second `--case` replaces the first) for the cases a change touches, as a smoke run (`--runs 1 --ablation none`); 3 runs only when a result looks borderline.
- **Graders:** an LLM grader asks a checkable question (is the problem stated? is there a case with real values?), never a style score.
- **More:** fixtures, graders, the fake `gh` and adding a case → `evals/README.md`.
- **Results:** runs land in `evals/results/<timestamp>/` and are git-ignored. When the user asks for a full-suite run (no `--tag`) for a release, copy its `aggregate-result.json` to `evals/results/<version>/` and commit it with the release; check `suite.plugins[0].version` matches. Never commit `report.html` or timestamped folders.
