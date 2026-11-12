# AI context for acme/hotel-api (main @ <sha>)

Code: <tmp>/out/repos/acme-hotel-api/tree (worktree of <tmp>/workspace/hotel-api). Files the PRs touched: 3 (touched.txt).

Read these before judging this repo's code. Paths are relative to the tree; where two disagree, the one nearest the code wins.

- CLAUDE.md — root
- AGENTS.md — root
- src/rates/AGENTS.md — covers src/rates/ (2 touched files)
- .claude/rules/api.md — rule paths: src/rates/**/*.{ts,tsx} matches src/rates/price.ts
- .claude/rules/general.md — rule without paths: applies to every file
- .claude/rules/inline.md — rule paths: src/util/*.ts matches src/util/x.ts
- .claude/rules/stub.md — rule paths: *.ts matches src/rates/price.ts
- docs/conventions.md — imported by AGENTS.md
- .agents/rules/stub.md — imported by .claude/rules/stub.md (resolved from the repo root)

Not applicable to these changes:

- .claude/rules/root-only.md — rule paths: /*.ts match no touched file
- .claude/rules/web.md — rule paths: web/** match no touched file
