# review-powers

Skills that turn AI code reviews into decision reports: the user reviews the review, then decides. The skills are the product; everything else supports them. Pitch and install paths: `README.md`.

## Skills

- **`review-pr`:** reviews someone's PR → numbered findings, each with a recommendation.
- **`review-pr-feedback`:** verdict per review comment on your PR → fixes what the user picks, replies to every comment.

## Editing skills

- **Gate:** stopping for the user's decision is the point of both skills; every change keeps it.
- **Judgement over rules:** a skill is prose that shapes judgement. Prefer a principle with its reason to a new rule.
- **Evidence:** change a skill in response to an observed failure, and say how you'd check it: the eval cases it touches, or a real PR to try it on.
- **Repeated corrections:** when the user corrects the same behaviour twice, it becomes an eval case, written even if not run.
- **Shared parts:** each folder installs on its own, so some things are identical in both skills; edit both. "Explain it to someone who doesn't know the code" and the order-and-tag paragraph of the gate in `SKILL.md`, and `scripts/lib/feeds.sh`, the feed-fetching code that `fetch-pr.sh` and `feeds.sh` source. Check the script with `cmp skills/review-pr/scripts/lib/feeds.sh skills/review-pr-feedback/scripts/lib/feeds.sh`.
- **Scripts:** mechanics (fetching, filtering, replying) live in `skills/<name>/scripts/`; `SKILL.md` says when to run them and keeps the judgement. Bash 3.2, `gh` and `jq` only.

## Workflow

- **Trunk-based:** single author. Commit straight to `main` and push; no branches or PRs. A commit that finishes an issue says `Closes #<n>`.

## Layout

```text
skills/<name>/SKILL.md      the skills
skills/<name>/scripts/      what the skills run: fetch-pr.sh; feeds.sh, reply.sh; lib/feeds.sh in both
.claude-plugin/             plugin + marketplace manifests (version lives in plugin.json)
evals/<skill>/<case>/       eval cases: prompt.md, case.yaml, graders/, scaffold.sh (+ history.jsonl for a second turn)
evals/_fixtures/            fake hotel-api repo, its PRs, and a fake `gh`
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
