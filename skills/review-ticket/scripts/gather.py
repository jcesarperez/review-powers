#!/usr/bin/env python3
"""Gather everything a ticket review starts from into a scratch dir.

The Jira ticket and its subtasks, every PR whose title or branch names one of
their keys, each PR's comment feeds, and, per repo, the code at its default
branch plus the AI context files (CLAUDE.md, AGENTS.md, rules) that apply to
what the PRs touched. Prints an index (paths, counts, failures), never content.

Usage: gather.py [--owner <gh owner>] [--repos-dir <dir>]... <KEY | Jira URL> [out-dir]
       gather.py --cleanup <out-dir>      remove the code trees; safe to repeat
       gather.py context <tree> <files>   the AI context that applies to <files>
                                          (one repo-relative path per line) in <tree>

  --owner      search PRs only in this GitHub user or org; default: every repo
               you can see, keeping PRs whose title or branch names the key
  --repos-dir  where local clones live (repeatable); the parent of the current
               repo and the current dir are always searched. A repo with no
               local clone is shallow-cloned into the out dir.
  out dir default: ${REVIEW_POWERS_SCRATCH:-${TMPDIR:-/tmp}/review-powers}/review-ticket/<KEY>

Writes: index.md (what it prints), jira/<KEY>.md, prs/<repo>-<n>/{pr.md,
  pr.json, feeds.md, inline.json, conversation.json, reviews.json},
  repos/<owner>-<repo>/{tree/, context.tsv, context.md, touched.txt}.
Failures are listed in the index instead of aborting, so a partial gather is
still usable; only an unreadable ticket stops it. Progress goes to stderr.
Needs: gh, git, acli (Atlassian CLI, logged in). Python 3.8+, stdlib only.
"""

import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import time
from collections import Counter
from functools import lru_cache
from pathlib import Path

NO_WAIT = bool(os.environ.get("REVIEW_TICKET_NO_WAIT"))
ERRORS = []


def die(msg):
    print(f"error: {msg}", file=sys.stderr)
    sys.exit(1)


def progress(msg):
    print(f"[gather] {msg}", file=sys.stderr, flush=True)


def nap(s):
    if not NO_WAIT:
        time.sleep(s)


def first_line(s):
    s = (s or "").strip()[:300]
    return s.splitlines()[0] if s else "(no message)"


class CmdError(Exception):
    pass


def run(args, cwd=None, timeout=600):
    """Run a command; return stdout, raise CmdError with the first stderr line."""
    try:
        p = subprocess.run(args, cwd=cwd, capture_output=True, text=True, timeout=timeout)
    except subprocess.TimeoutExpired:
        raise CmdError(f"timed out after {timeout}s")
    except FileNotFoundError:
        raise CmdError(f"{args[0]} not found")
    if p.returncode != 0:
        raise CmdError(first_line(p.stderr or p.stdout))
    return p.stdout


RATE = re.compile(r"rate limit|secondary rate|abuse detection|http 403|http 429", re.I)


def gh(*args, timeout=300):
    """gh, retried with backoff when rate-limited."""
    for d in (5, 10, 20, 25, 0):
        try:
            return run(["gh", *args], timeout=timeout)
        except CmdError as e:
            if d == 0 or not RATE.search(str(e)):
                raise
            nap(d)


def gh_json(*args):
    return json.loads(gh(*args) or "null")


def gh_paged(path):
    """Every page of a REST list endpoint as one list."""
    out = gh("api", "--paginate", f"{path}?per_page=100", "--jq", ".[]")
    return [json.loads(l) for l in out.splitlines() if l.strip()]


def has_key(text, key):
    """The text names the key as a whole key (ABC-12 is not named by ABC-123)."""
    return re.search(rf"(^|[^A-Z0-9]){re.escape(key)}([^0-9]|$)", (text or "").upper()) is not None


def tidy(s):
    s = re.sub(r"\n[ \t]+(?=\n)", "\n", s)
    s = re.sub(r"\n{3,}", "\n\n", s)
    return s.strip()


def strip_html_comments(s):
    s = re.sub(r"<!--[\s\S]*?-->", "", s or "")
    return re.sub(r"\n{3,}", "\n\n", s).strip()


# --- ADF to Markdown ---------------------------------------------------------

def adf(node):
    if node is None:
        return ""
    if isinstance(node, str):
        return node
    if isinstance(node, list):
        return "".join(adf(n) for n in node)
    a = node.get("attrs") or {}
    t = node.get("type")
    kids = node.get("content") or []
    inner = "".join(adf(n) for n in kids)
    if t == "text":
        return node.get("text") or ""
    if t == "hardBreak":
        return "\n"
    if t in ("mention", "emoji"):
        return a.get("text") or a.get("shortName") or ""
    if t in ("inlineCard", "blockCard", "embedCard"):
        return a.get("url") or ""
    if t == "heading":
        return "#" * (a.get("level") or 2) + " " + inner + "\n\n"
    if t == "codeBlock":
        return "```\n" + inner + "\n```\n\n"
    if t == "listItem":
        body = re.sub(r"\n\n+", "\n", inner).rstrip().replace("\n", "\n  ")
        return "- " + body + "\n"
    if t == "taskItem":
        mark = "x" if a.get("state") == "DONE" else " "
        return f"- [{mark}] " + inner.rstrip().replace("\n", "\n  ") + "\n"
    if t in ("bulletList", "orderedList", "taskList"):
        return inner + "\n"
    if t in ("paragraph", "blockquote", "panel"):
        return inner + "\n\n"
    if t == "tableRow":
        return "| " + " | ".join(tidy(adf(c)) for c in kids) + " |\n"
    if t == "rule":
        return "---\n\n"
    return inner


# --- AI context --------------------------------------------------------------

def expand_braces(p):
    m = re.search(r"\{([^{}]*)\}", p)
    if not m:
        return [p]
    out = []
    for alt in m.group(1).split(","):
        out += expand_braces(p[: m.start()] + alt + p[m.end():])
    return out


@lru_cache(maxsize=None)
def glob_regex(g):
    """Rule `paths:` as Claude Code documents them (gitignore-style): `**/` may
    be no directory, `**` crosses `/`, `*` and `?` don't, `[..]` is a bracket
    expression. A pattern with no `/` matches at any depth (`*.md`); a leading
    `/` anchors to the repo root (`/*.md`); a trailing `/` means everything under."""
    out = []
    if g.endswith("/"):
        g += "**"
    if g.startswith("/"):
        g = g[1:]
    elif "/" not in g:
        out.append("(?:.*/)?")
    i = 0
    while i < len(g):
        if g[i] == "[":
            j = g.find("]", i + 2)
            if j == -1:
                return re.compile(r"(?!)")  # an unclosed `[` makes the pattern match nothing
            body = g[i + 1:j]
            if body[0] in "!^":
                body = "^" + body[1:]
            out.append("[" + body.replace("\\", "\\\\") + "]"); i = j + 1
        elif g.startswith("**/", i):
            out.append("(?:.*/)?"); i += 3
        elif g.startswith("**", i):
            out.append(".*"); i += 2
        elif g[i] == "*":
            out.append("[^/]*"); i += 1
        elif g[i] == "?":
            out.append("[^/]"); i += 1
        else:
            out.append(re.escape(g[i])); i += 1
    return re.compile("".join(out) + r"\Z")


def glob_match(path, glob):
    return any(glob_regex(g).match(path) for g in expand_braces(glob))


def unquote(s):
    return s.strip().strip("\"'")


def split_inline(v):
    v = re.sub(r"^\s*\[|\]\s*$", "", v)
    out, cur, depth = [], "", 0
    for c in v:
        depth += c == "{"
        depth -= c == "}"
        if c == "," and depth == 0:
            out.append(cur); cur = ""
        else:
            cur += c
    out.append(cur)
    return [unquote(x) for x in out if unquote(x)]


def rule_paths(text):
    """Frontmatter `paths:` globs; [] when there are none."""
    lines = text.splitlines()
    if not lines or lines[0].strip() != "---":
        return []
    out, inp = [], False
    for line in lines[1:]:
        if line.strip() == "---":
            break
        if line.startswith("paths:"):
            v = line[len("paths:"):].strip()
            if v:
                out += split_inline(v); inp = False
            else:
                inp = True
        elif inp and re.match(r"\s*-", line):
            v = unquote(re.sub(r"^\s*-\s*", "", line))
            if v:
                out.append(v)
        elif inp and re.match(r"\S", line):
            inp = False
    return out


def imports_of(text):
    """@path imports (Claude Code syntax), outside code blocks and spans."""
    out, in_code = [], False
    for line in text.splitlines():
        if re.match(r"\s*```", line):
            in_code = not in_code
            continue
        if in_code:
            continue
        line = re.sub(r"`[^`]*`", "", line)
        for w in line.split():
            if re.match(r"@[^@\s]", w):
                out.append(re.sub(r"[.,;:)]+$", "", w[1:]))
    return out


def resolve_context(tree, touched):
    """Lines (read|skip, path, reason), paths relative to the tree."""
    t = Path(tree).resolve()
    touched = sorted(set(f for f in touched if f))
    acc, skips = [], []

    for name in ("CLAUDE.md", "AGENTS.md", ".claude/CLAUDE.md"):
        if (t / name).is_file():
            acc.append(("read", name, "root"))

    nested = Counter()
    for f in touched:
        d = os.path.dirname(f)
        while d not in ("", ".", "/"):
            for name in ("CLAUDE.md", "AGENTS.md"):
                if (t / d / name).is_file():
                    nested[(f"{d}/{name}", d)] += 1
            d = os.path.dirname(d)
    for (rel, d), n in sorted(nested.items()):
        acc.append(("read", rel, f"covers {d}/ ({n} touched file{'s' if n > 1 else ''})"))

    rules = t / ".claude" / "rules"
    if rules.is_dir():
        for p in sorted(rules.rglob("*.md"), key=lambda x: str(x)):
            rel = str(p.relative_to(t))
            globs = rule_paths(p.read_text(errors="replace"))
            if not globs:
                acc.append(("read", rel, "rule without paths: applies to every file"))
                continue
            hit = next((f"rule paths: {g} matches {f}" for g in globs for f in touched if glob_match(f, g)), None)
            if hit:
                acc.append(("read", rel, hit))
            else:
                skips.append(("skip", rel, f"rule paths: {' '.join(globs)} match no touched file"))

    # Imports, transitively. Claude Code resolves them against the importing
    # file; rules often import `@.agents/...` meaning the repo root, which
    # Claude Code would not find. Those still hold the team's rules, so they are
    # listed, marked as resolved from the root.
    i = 0
    while i < len(acc):
        rel = acc[i][1]
        src = t / rel
        if src.is_file():
            for p in imports_of(src.read_text(errors="replace")):
                if not p or p.startswith(("~", "/")):
                    continue
                if (src.parent / p).is_file():
                    cand, why = (src.parent / p).resolve(), f"imported by {rel}"
                elif (t / p).is_file():
                    cand, why = (t / p).resolve(), f"imported by {rel} (resolved from the repo root)"
                else:
                    continue
                try:
                    target = str(cand.relative_to(t))
                except ValueError:
                    continue
                if target not in {a[1] for a in acc}:
                    acc.append(("read", target, why))
        i += 1
    return acc + skips


# --- Jira --------------------------------------------------------------------

def fetch_issue(key):
    try:
        raw = json.loads(run(["acli", "jira", "workitem", "view", key, "--fields", "*all", "--json"], timeout=120))
    except (CmdError, json.JSONDecodeError) as e:
        ERRORS.append(f"acli jira workitem view {key}: {e}")
        return None
    if not isinstance(raw, dict) or not raw.get("fields"):
        ERRORS.append(f"acli jira workitem view {key}: no fields in its output")
        return None
    return raw["fields"]


def name_of(obj, field="name"):
    return (obj or {}).get(field) or "-"


def write_issue(key, f, out):
    L = [f"# {key} — {f.get('summary') or ''}",
         f"type: {name_of(f.get('issuetype'))} · status: {name_of(f.get('status'))} · "
         f"assignee: {name_of(f.get('assignee'), 'displayName')}"]
    par = f.get("parent")
    if par:
        pf = par.get("fields") or {}
        L.append(f"parent: {par.get('key')} ({name_of(pf.get('issuetype'))}) — {pf.get('summary') or ''}")
    for ln in f.get("issuelinks") or []:
        if ln.get("outwardIssue"):
            rel, o = ln["type"]["outward"], ln["outwardIssue"]
        else:
            rel, o = ln["type"]["inward"], ln.get("inwardIssue") or {}
        L.append(f"link: {rel} {o.get('key')} — {(o.get('fields') or {}).get('summary') or ''}")
    subs = f.get("subtasks") or []
    if subs:
        L.append("subtasks: " + ", ".join(f"{s['key']} [{name_of(s['fields'].get('status'))}]" for s in subs))
    desc = tidy(adf(f.get("description")))
    L += ["", "## Description", "", desc or "(empty)", ""]
    comments = (f.get("comment") or {}).get("comments") or []
    L += [f"## Comments ({len(comments)})", ""]
    for c in comments:
        L += [f"### {name_of(c.get('author'), 'displayName')} · {(c.get('created') or '')[:10]}", "",
              tidy(adf(c.get("body"))), ""]
    (out / "jira" / f"{key}.md").write_text("\n".join(L) + "\n")


# --- PRs and feeds -----------------------------------------------------------

THREADS_Q = ("query($owner:String!,$name:String!,$number:Int!,$endCursor:String){repository(owner:$owner,name:$name)"
             "{pullRequest(number:$number){reviewThreads(first:100,after:$endCursor){pageInfo{hasNextPage endCursor}"
             " nodes{id isResolved isOutdated comments(first:100){nodes{databaseId}}}}}}}")


def is_bot(c):
    u = c.get("user") or {}
    return u.get("type") == "Bot" or (u.get("login") or "").endswith("[bot]")


def bot_tag(c):
    return " [bot]" if c["is_bot"] and not (c["author"] or "").endswith("[bot]") else ""


# Bot comments with no review content: one line each in feeds.md (the full
# text stays in the .json). Matched only on bot authors; a bot's findings,
# security scans and plans are kept whole.
NOTICES = (
    ("coverage report", re.compile(r"coverage date:|line coverage|code coverage", re.I)),
    ("review-started notice", re.compile(r"^\W*an? (?:new |re-)?review of this (?:pr|pull request) has started", re.I)),
)


def notice(c):
    """The kind of content-free bot comment c is, or None."""
    if not c["is_bot"]:
        return None
    return next((kind for kind, rx in NOTICES if rx.search(c["body"] or "")), None)


def collapsed(c, kind):
    return f"(collapsed: {kind}, {len(c['body']) // 1024 or 1} KB; full text in the .json)"


def indent(s):
    return "  " + s.replace("\n", "\n  ")


def feeds_fetch(owner, repo, n, out):
    api = f"repos/{owner}/{repo}"
    inline_raw = gh_paged(f"{api}/pulls/{n}/comments")
    conv_raw = gh_paged(f"{api}/issues/{n}/comments")
    reviews_raw = gh_paged(f"{api}/pulls/{n}/reviews")
    warn = ""
    try:
        txt = gh("api", "graphql", "--paginate", "-f", f"query={THREADS_Q}", "-f", f"owner={owner}",
                 "-f", f"name={repo}", "-F", f"number={n}", "--jq", ".data.repository.pullRequest.reviewThreads.nodes[]")
        threads = [json.loads(l) for l in txt.splitlines() if l.strip()]
    except CmdError as e:
        warn, threads = f"thread state (resolved/outdated) unavailable: {e}", []
    state = {}
    for th in threads:
        for c in th["comments"]["nodes"]:
            state[c["databaseId"]] = {"thread_id": th["id"], "is_resolved": th["isResolved"], "outdated": th["isOutdated"]}

    inline = [{"id": c["id"], **state.get(c["id"], {"thread_id": None, "is_resolved": None, "outdated": None}),
               "in_reply_to": c.get("in_reply_to_id"), "path": c.get("path"),
               "line": c.get("line") or c.get("original_line"), "author": (c.get("user") or {}).get("login"),
               "is_bot": is_bot(c), "created_at": c.get("created_at"), "url": c.get("html_url"),
               "body": strip_html_comments(c.get("body"))} for c in inline_raw]
    conv = [{"id": c["id"], "author": (c.get("user") or {}).get("login"), "is_bot": is_bot(c),
             "created_at": c.get("created_at"), "url": c.get("html_url"), "body": strip_html_comments(c.get("body"))}
            for c in conv_raw]
    reviews = [{"id": c["id"], "author": (c.get("user") or {}).get("login"), "is_bot": is_bot(c), "state": c.get("state"),
                "submitted_at": c.get("submitted_at"), "url": c.get("html_url"), "body": strip_html_comments(c.get("body"))}
               for c in reviews_raw]
    for name, data in (("inline", inline), ("conversation", conv), ("reviews", reviews)):
        (out / f"{name}.json").write_text(json.dumps(data, indent=2))

    roots = [c for c in inline if c["in_reply_to"] is None]
    resolved = sum(1 for c in roots if c["is_resolved"] is True)
    outdated = sum(1 for c in roots if c["outdated"] is True)
    with_body = sum(1 for r in reviews if r["body"])
    L = [f"# Feeds for {owner}/{repo}#{n}", "",
         f"## Inline review comments ({len(inline)} in {len(roots)} threads: {len(roots) - resolved} open, "
         f"{resolved} resolved, {outdated} outdated)", ""]
    for r in roots:
        st = {True: "resolved", False: "open"}.get(r["is_resolved"], "state unknown")
        L.append(f"### thread {r['thread_id'] or '?'} · {r['path']}:{r['line'] or '?'} · {st}"
                 + (" · outdated" if r["outdated"] else ""))
        for c in sorted((c for c in inline if c["id"] == r["id"] or c["in_reply_to"] == r["id"]),
                        key=lambda c: c["created_at"] or ""):
            L.append(f"- id {c['id']} · {c['author']}{bot_tag(c)}{' (reply)' if c['in_reply_to'] else ''}:\n"
                     + indent(c["body"]))
        L.append("")
    n_conv_notes = sum(1 for c in conv if notice(c))
    n_rev_notes = sum(1 for r in reviews if r["body"] and notice(r))
    L += [f"## Conversation comments ({len(conv)}" + (f"; {n_conv_notes} bot notice{'s' * (n_conv_notes > 1)} collapsed" if n_conv_notes else "")
          + ")", ""]
    for c in conv:
        kind = notice(c)
        L.append(f"- id {c['id']} · {c['author']}{bot_tag(c)}: " + collapsed(c, kind) if kind
                 else f"- id {c['id']} · {c['author']}{bot_tag(c)}:\n" + indent(c["body"]))
    L += ["", f"## Review bodies ({len(reviews)} reviews, {with_body} with a body"
          + (f"; {n_rev_notes} bot notice{'s' * (n_rev_notes > 1)} collapsed" if n_rev_notes else "") + ")", ""]
    for r in reviews:
        head = f"- id {r['id']} · {r['author']}{bot_tag(r)} · {r['state']}"
        if not r["body"]:
            L.append(head + " (no body; see inline)")
        elif notice(r):
            L.append(head + ": " + collapsed(r, notice(r)))
        else:
            L.append(head + ":\n" + indent(r["body"]))
    (out / "feeds.md").write_text("\n".join(L) + "\n")
    notes = n_conv_notes + n_rev_notes
    return (f"review threads: {len(roots)} ({len(roots) - resolved} open), conversation: {len(conv)}, "
            f"review bodies: {with_body}" + (f", bot notices collapsed: {notes}" if notes else "")
            + (f"; {warn}" if warn else ""))


def search_prs(key, owner, hits):
    """Appends (key, slug, n, state, own|mention, title) to hits; returns a status line or None."""
    args = ["search", "prs", f'"{key}"', "--limit", "50", "--json", "repository,number,title,state"]
    if owner:
        args += ["--owner", owner]
    try:
        found = gh_json(*args) or []
    except (CmdError, json.JSONDecodeError) as e:
        ERRORS.append(f"gh search prs {key}: {e}")
        return f"  {key}: search FAILED ({e}) — not checked"
    failed = ""
    for h in found:
        slug, n, title = h["repository"]["nameWithOwner"], h["number"], h["title"]
        if has_key(title, key):
            kind = "own"
        else:
            try:
                head = gh("pr", "view", str(n), "-R", slug, "--json", "headRefName", "-q", ".headRefName").strip()
                kind = "own" if has_key(head, key) else "mention"
            except CmdError as e:
                ERRORS.append(f"gh pr view {slug}#{n}: {e}")
                failed, kind = f"branch lookup failed for {slug}#{n}", "mention"
        hits.append((key, slug, n, h["state"], kind, title))
    if failed:
        return f"  {key}: search PARTIALLY failed ({failed}) — list may be incomplete"
    if not any(k == key and kind == "own" for k, _, _, _, kind, _ in hits):
        return f"  {key}: none found"
    return None


def fetch_pr(slug, n, key, out, touched, repos):
    d = out / "prs" / f"{slug.split('/')[1]}-{n}"
    d.mkdir(parents=True, exist_ok=True)
    try:
        pr = gh_json("pr", "view", str(n), "-R", slug, "--json",
                     "number,title,url,state,mergedAt,baseRefName,headRefName,body,files,author")
    except (CmdError, json.JSONDecodeError) as e:
        ERRORS.append(f"gh pr view {slug}#{n}: {e}")
        return [f"  {key}  {slug}#{n} -> FAILED"]
    (d / "pr.json").write_text(json.dumps(pr, indent=2))
    body = tidy(re.sub(r"<!--[\s\S]*?-->", "", pr.get("body") or ""))
    files = pr.get("files") or []
    L = [f"# {slug}#{pr['number']} — {pr['title']}", pr["url"],
         f"state: {pr['state']} · merged: {pr.get('mergedAt') or '-'} · {pr['headRefName']} → {pr['baseRefName']} · "
         f"author: {(pr.get('author') or {}).get('login') or '-'}",
         "", "## Description", "", body or "(empty)", "", f"## Files ({len(files)})", ""]
    L += [f"- {f['path']} (+{f['additions']}/-{f['deletions']})" for f in files]
    L += ["", "Review comments and thread state: feeds.md"]
    (d / "pr.md").write_text("\n".join(L) + "\n")
    touched.setdefault(slug, set()).update(f["path"] for f in files)
    repos.add(slug)
    head = f"  {key}  {slug}#{n} [{pr['state']}] {pr['title']}"
    try:
        o, r = slug.split("/")
        counts = feeds_fetch(o, r, n, d)
        return [head, f"      {d}  ({counts})"]
    except (CmdError, json.JSONDecodeError) as e:
        ERRORS.append(f"feeds of {slug}#{n}: {e}")
        return [head, f"      {d}  (feeds FAILED; description and files only)"]


# --- repos -------------------------------------------------------------------

def norm_remote(url):
    u = re.sub(r"\.git/?$", "", url.strip()).rstrip("/")
    m = re.search(r"[:/]([^/:]+/[^/:]+)$", u)
    return (m.group(1) if m else u).lower()


def find_clone(slug, repos_dirs):
    want = slug.lower()
    dirs = list(repos_dirs)
    try:
        top = run(["git", "rev-parse", "--show-toplevel"], timeout=30).strip()
        dirs.append(os.path.dirname(top))
    except CmdError:
        pass
    dirs.append(os.getcwd())
    for d in dirs:
        d = Path(d).expanduser()
        if not d.is_dir():
            continue
        for c in [d, *sorted(d.iterdir())]:
            if not (c / ".git").exists():
                continue
            try:
                cfg = run(["git", "-C", str(c), "config", "--get-regexp", r"^remote\..*\.url$"], timeout=30)
            except CmdError:
                continue
            for line in cfg.splitlines():
                k, _, url = line.partition(" ")
                if norm_remote(url) == want:
                    return c, k[len("remote."):-len(".url")]
    return None


def remove_tree(rdir):
    src = rdir / "source"
    clone = src.read_text().strip() if src.is_file() else ""
    if clone and Path(clone).is_dir():
        subprocess.run(["git", "-C", clone, "worktree", "remove", "--force", str(rdir / "tree")], capture_output=True)
        subprocess.run(["git", "-C", clone, "worktree", "prune"], capture_output=True)
    shutil.rmtree(rdir / "tree", ignore_errors=True)


def setup_repo(slug, out, touched, repos_dirs):
    owner, repo = slug.split("/")
    d = out / "repos" / f"{owner}-{repo}"
    d.mkdir(parents=True, exist_ok=True)
    files = sorted(touched.get(slug, ()))
    (d / "touched.txt").write_text("".join(f + "\n" for f in files))
    try:
        branch = gh("repo", "view", slug, "--json", "defaultBranchRef", "--jq", ".defaultBranchRef.name").strip()
    except CmdError as e:
        ERRORS.append(f"gh repo view {slug}: {e}")
        return [f"  {slug}: FAILED (default branch unknown; no code, no context)"]

    remove_tree(d)  # a tree from an earlier run would make the checkout fail
    (d / "source").write_text("")
    found = find_clone(slug, repos_dirs)
    tree = d / "tree"
    if found:
        clone, remote = found
        progress(f"{slug}: fetching {branch} in {clone}")
        try:
            run(["git", "-C", str(clone), "fetch", "-q", remote, branch], timeout=900)
        except CmdError as e:
            ERRORS.append(f"git fetch {remote} {branch} in {clone}: {e}")
            return [f"  {slug}: FAILED (cannot fetch {branch} in {clone})"]
        progress(f"{slug}: checking out a worktree")
        try:
            run(["git", "-C", str(clone), "worktree", "add", "-q", "--detach", str(tree), "FETCH_HEAD"], timeout=900)
        except CmdError as e:
            ERRORS.append(f"git worktree add in {clone}: {e}")
            return [f"  {slug}: FAILED (cannot create a worktree of {clone})"]
        (d / "source").write_text(f"{clone}\n")
        how = f"worktree of {clone}"
    else:
        progress(f"{slug}: no local clone, shallow-cloning")
        try:
            gh("repo", "clone", slug, str(tree), "--", "-q", "--depth", "1", "--branch", branch, timeout=1800)
        except CmdError as e:
            ERRORS.append(f"gh repo clone {slug}: {e}")
            return [f"  {slug}: FAILED (no local clone, and cloning failed)"]
        how = "fresh shallow clone"
    sha = run(["git", "-C", str(tree), "rev-parse", "--short", "HEAD"]).strip()

    progress(f"{slug}: resolving AI context")
    ctx = resolve_context(tree, files)
    (d / "context.tsv").write_text("".join("\t".join(r) + "\n" for r in ctx))
    reads = [r for r in ctx if r[0] == "read"]
    skips = [r for r in ctx if r[0] == "skip"]
    L = [f"# AI context for {slug} ({branch} @ {sha})", "",
         f"Code: {tree} ({how}). Files the PRs touched: {len(files)} (touched.txt).", "",
         "Read these before judging this repo's code. Paths are relative to the tree; "
         "where two disagree, the one nearest the code wins.", ""]
    L += [f"- {p} — {why}" for _, p, why in reads] or ["- (none: this repo has no CLAUDE.md, AGENTS.md or rules)"]
    if skips:
        L += ["", "Not applicable to these changes:", ""] + [f"- {p} — {why}" for _, p, why in skips]
    (d / "context.md").write_text("\n".join(L) + "\n")
    return [f"  {slug}  {branch} @ {sha}  ({how})", f"      code:    {tree}",
            f"      context: {d / 'context.md'} ({len(reads)} to read, {len(skips)} not applicable)"]


# --- main --------------------------------------------------------------------

def parse_args(argv):
    owner, repos_dirs, cleanup, pos = "", [], False, []
    i = 0
    while i < len(argv):
        a = argv[i]
        if a in ("--owner", "--repos-dir"):
            if i + 1 >= len(argv):
                die(f"{a} needs a value")
            if a == "--owner":
                owner = argv[i + 1]
            else:
                repos_dirs.append(argv[i + 1])
            i += 1
        elif a == "--cleanup":
            cleanup = True
        elif a in ("-h", "--help"):
            print(__doc__)
            sys.exit(0)
        elif a.startswith("-"):
            die(f"unknown option: {a}")
        else:
            pos.append(a)
        i += 1
    return owner, repos_dirs, cleanup, pos


def main(argv):
    if argv[:1] == ["context"]:
        if len(argv) != 3 or not Path(argv[1]).is_dir() or not Path(argv[2]).is_file():
            die("usage: gather.py context <tree> <files>")
        for r in resolve_context(argv[1], Path(argv[2]).read_text().splitlines()):
            print("\t".join(r))
        return

    owner, repos_dirs, cleanup, pos = parse_args(argv)

    if cleanup:
        if not pos or not Path(pos[0]).is_dir():
            die("usage: gather.py --cleanup <out-dir>")
        for src in sorted(Path(pos[0]).glob("repos/*/source")):
            remove_tree(src.parent)
            print(f"removed {src.parent / 'tree'}")
        return

    if not pos:
        die("missing ticket: pass a key like ABC-123 or a ticket URL")
    # The last key-like match: in a URL the host can look like one.
    keys = re.findall(r"[A-Z][A-Z0-9]+-[0-9]+", pos[0].upper())
    if not keys:
        die(f"no Jira key in '{pos[0]}': pass a key like ABC-123 or a ticket URL")
    key = keys[-1]
    for tool, url in (("gh", "https://cli.github.com"), ("acli", "https://developer.atlassian.com/cloud/acli"),
                      ("git", "https://git-scm.com")):
        if not shutil.which(tool):
            die(f"{tool} is not installed ({url})")

    if len(pos) > 1:
        out = Path(pos[1])
    else:
        root = os.environ.get("REVIEW_POWERS_SCRATCH") or os.path.join(tempfile.gettempdir(), "review-powers")
        out = Path(root) / "review-ticket" / key
    for sub in ("jira", "prs", "repos"):
        (out / sub).mkdir(parents=True, exist_ok=True)
    out = out.resolve()
    index = []

    # index.md is rewritten after every step, so a run in the background can be
    # read as it fills, and a killed run still says how far it got.
    def flush(tail=(), done=False):
        lines = index + list(tail)
        if not done:
            lines += ["", "(still gathering: this index is incomplete. If the gather has ended, "
                          "it was killed, and every PENDING line above is a failure.)"]
        tmp = out / "index.md.tmp"
        tmp.write_text("\n".join(lines) + "\n")
        tmp.replace(out / "index.md")
        return "\n".join(lines) + "\n"

    # Jira
    progress(f"reading {key}")
    top = fetch_issue(key)
    if top is None:
        die(f"cannot read the ticket {key}: {ERRORS[-1]}")
    keys = [key] + [s["key"] for s in top.get("subtasks") or []]
    index += [f"Ticket {key}: {top.get('summary')} [{name_of(top.get('status'))}]", "", "Jira:"]
    for k in keys:
        f = top if k == key else fetch_issue(k)
        if f is None:
            index.append(f"  {k}: FAILED (see Failed)")
            continue
        write_issue(k, f, out)
        index.append(f"  {out / 'jira' / (k + '.md')}  [{name_of(f.get('status'))}] {f.get('summary')}")
    flush()

    # PRs
    index += ["", "PRs (key in title or branch):"]
    hits = []
    for i, k in enumerate(keys):
        if i:
            nap(2.5)  # GitHub search allows 30 requests a minute
        progress(f"searching PRs for {k}")
        line = search_prs(k, owner, hits)
        if line:
            index.append(line)
        flush()
    seen, own = set(), []
    for h in hits:
        if h[4] == "own" and (h[1], h[2]) not in seen:
            seen.add((h[1], h[2]))
            own.append(h)
    own.sort(key=lambda h: (h[1], h[2]))
    touched, repos = {}, set()
    for k, slug, n, *_ in own:
        progress(f"fetching {slug}#{n}")
        index += fetch_pr(slug, n, k, out, touched, repos)
        flush()

    # Mentions from an owner with no PR of the ticket are noise from other projects.
    own_owners = {h[1].split("/")[0] for h in own}
    mentions, dropped, mseen = [], 0, set()
    for h in hits:
        if h[4] != "mention" or (h[1], h[2]) in seen or (h[1], h[2]) in mseen:
            continue
        mseen.add((h[1], h[2]))
        if own and h[1].split("/")[0] not in own_owners:
            dropped += 1
            continue
        mentions.append(h)
    if mentions:
        index += ["", "Only mentioned in a PR body (not fetched; may or may not belong):"]
        index += [f"  {k}  {slug}#{n} [{state}] {title}" for k, slug, n, state, _, title in mentions]
    if dropped:
        index += ["", f"Dropped {dropped} search hits from owners with no PR of this ticket."]
    if not owner:
        per = Counter(h[1].split("/")[0] for h in own)
        if len(per) > 1:
            index += ["", "PRs per owner: " + ", ".join(f"{o}: {c}" for o, c in per.most_common())
                      + ". Rerun with --owner if some don't belong."]

    # Repos
    index += ["", "Repos (code at the default branch; read each one's context before its code):"]
    if repos:
        blocks = {slug: [f"  {slug}: PENDING (code and context not ready yet)"] for slug in sorted(repos)}
        for slug in blocks:
            flush([l for b in blocks.values() for l in b])
            try:
                blocks[slug] = setup_repo(slug, out, touched, repos_dirs)
            except Exception as e:  # one broken repo must not cost the others
                ERRORS.append(f"repo {slug}: {type(e).__name__}: {e}")
                blocks[slug] = [f"  {slug}: FAILED (see Failed)"]
        index += [l for b in blocks.values() for l in b]
    else:
        index.append("  none (no PR found)")
    if ERRORS:
        index += ["", "Failed (gather these by hand):"] + [f"  {e}" for e in ERRORS]
    index += ["", f"Remove the code trees when done: {Path(__file__).resolve()} --cleanup {out}"]

    print(flush(done=True), end="")


if __name__ == "__main__":
    main(sys.argv[1:])
