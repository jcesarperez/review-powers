# review-powers

Skills that turn AI code reviews into decision reports: the user reviews the review, then decides. The skills are the product; everything else supports them. Pitch and install paths: `README.md`.

## Skills

- **`review-pr`:** reviews someone's PR → numbered findings, each with a recommendation.
- **`review-pr-feedback`:** verdict per review comment on your PR → fixes what the user picks, replies to every comment.

## Editing skills

- **Gate:** stopping for the user's decision is the point of both skills; every change keeps it.
- **Judgement over rules:** a skill is prose that shapes judgement. Prefer a principle with its reason to a new rule.
- **Evidence:** change a skill in response to an observed failure, and prove the change with an eval.
- **Repeated corrections:** when the user corrects the same behaviour twice, it becomes an eval case.

## Layout

```text
skills/<name>/SKILL.md      the skills
.claude-plugin/             plugin + marketplace manifests (version lives in plugin.json)
evals/<skill>/<case>/       eval cases: prompt.md, case.yaml, graders/, scaffold.sh
evals/_fixtures/            fake hotel-api repo, its PRs, and a fake `gh`
CHANGELOG.md                Keep a Changelog, semver
```

## Evals

- **Run:** `claude plugin eval . --scaffold --allow-tools Bash Edit Write --judge-model sonnet`
- **Smoke:** add `--runs 1 --ablation none`; filter with `--tag` or `--case`.
- **Before and after:** run a skill's evals on both sides of a change.
- **More:** fixtures, graders, the fake `gh` and adding a case → `evals/README.md`.
- **Results:** runs land in `evals/results/<timestamp>/` and are git-ignored. On release, copy the full-suite run's `aggregate-result.json` (no `--tag`) to `evals/results/<version>/` and commit it with the release. Check `suite.plugins[0].version` matches. Never commit `report.html` or timestamped folders.
