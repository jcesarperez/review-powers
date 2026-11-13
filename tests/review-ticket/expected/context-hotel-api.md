# AI context for acme/hotel-api (main @ <sha>)

Code: <tmp>/out/repos/acme-hotel-api/tree (worktree of <tmp>/workspace/hotel-api). Files the PRs touched: 3 (touched.txt).

Paths are relative to the tree; where two disagree, the one nearest the code wins.

Always read: the root files and the ones scoped to the touched code (22 lines):

- CLAUDE.md (9 lines) — root
- AGENTS.md (1 line) — root
- src/rates/AGENTS.md (1 line) — covers src/rates/ (2 touched files)
- .claude/rules/api.md (6 lines) — rule paths: src/rates/**/*.{ts,tsx} matches src/rates/price.ts
- .claude/rules/inline.md (4 lines) — rule paths: src/util/*.ts matches src/util/x.ts
- docs/conventions.md (1 line) — imported by AGENTS.md

Broad: rules for a file type or for every file; read them when judging whether the code follows this repo's conventions (7 lines):

- .claude/rules/general.md (1 line) — rule without paths: applies to every file
- .claude/rules/stub.md (5 lines) — rule paths: *.ts matches src/rates/price.ts
- .agents/rules/stub.md (1 line) — imported by .claude/rules/stub.md (resolved from the repo root)

Not applicable to these changes:

- .claude/rules/root-only.md (5 lines) — rule paths: /*.ts match no touched file
- .claude/rules/web.md (5 lines) — rule paths: web/** match no touched file
