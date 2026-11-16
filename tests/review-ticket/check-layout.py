#!/usr/bin/env python3
"""Check a gather dir against skills/review-ticket/layout.md.

Whoever wrote it, gather.py or an agent by hand, the review reads it the same
way, so both must leave the same shape. Prints each problem; exits 1 if any.

Usage: check-layout.py <gather-dir>
"""

import re
import sys
from pathlib import Path

out = Path(sys.argv[1]).resolve()
problems = []


def bad(msg):
    problems.append(msg)


def first_line(p):
    try:
        return p.read_text(errors="replace").splitlines()[0]
    except (OSError, IndexError):
        return ""


index = out / "index.md"
if not index.is_file():
    sys.exit("no index.md in %s" % out)
text = index.read_text(errors="replace")

m = re.match(r"Ticket ([A-Z][A-Z0-9]*-\d+): .+ \[[^\]]+\]$", text.splitlines()[0] if text else "")
if not m:
    bad("index.md: first line is not 'Ticket <KEY>: <title> [<status>]'")
elif not (out / "jira" / f"{m.group(1)}.md").is_file():
    bad(f"jira/{m.group(1)}.md: the ticket's own file is missing")
if re.search(r"still gathering|PENDING", text):
    bad("index.md: the gather has not finished (still gathering / PENDING)")

# Every path the index points at under the gather dir exists.
for p in sorted(set(re.findall(re.escape(str(out)) + r"/[^\s()]+", text))):
    if not Path(p).exists():
        bad(f"index.md points at a missing path: {p[len(str(out)) + 1:]}")

for f in sorted((out / "jira").glob("*.md")):
    if not re.match(r"# [A-Z][A-Z0-9]*-\d+ — ", first_line(f)):
        bad(f"jira/{f.name}: first line is not '# <KEY> — <title>'")

for d in sorted(p for p in (out / "prs").glob("*") if p.is_dir()):
    if not re.match(r"# [\w.-]+/[\w.-]+#\d+ — ", first_line(d / "pr.md")):
        bad(f"prs/{d.name}/pr.md: missing, or first line is not '# owner/repo#n — title'")
    if not (d / "feeds.md").is_file():
        bad(f"prs/{d.name}/feeds.md: missing")

# A repo the index marks FAILED has no context to read, and says so.
failed = {f"{o}-{r}" for o, r in re.findall(r"^\s*([\w.-]+)/([\w.-]+): FAILED", text, re.M)}
for d in sorted(p for p in (out / "repos").glob("*") if p.is_dir()):
    if d.name not in failed and not (d / "context.md").is_file():
        bad(f"repos/{d.name}/context.md: missing")

for p in problems:
    print(p)
sys.exit(1 if problems else 0)
