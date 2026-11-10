#!/usr/bin/env bash
# Convert the Markdown of a follow-up Task to Atlassian Document Format (ADF),
# for `acli jira workitem create --description-file`. Jira needs ADF for real
# checkboxes.
#
# Usage: md2adf.sh <in.md> [out.json]     (out default: stdout)
#
# Handles the subset a Task uses: headings, paragraphs, bullet and numbered
# lists (nested by indentation), checkboxes `- [ ]` / `- [x]`, fenced code
# blocks, `---` rules, and inline `code`, **bold**, [links](url) and bare URLs.
# Anything else (tables, quotes) passes through as paragraph text.
# ADF can't nest a list inside a checkbox: such lines join the checkbox text.
# Needs: jq.

set -euo pipefail
command -v jq >/dev/null 2>&1 || { echo "error: jq is not installed" >&2; exit 1; }
[ -f "${1:-}" ] || { echo "usage: md2adf.sh <in.md> [out.json]" >&2; exit 2; }

PROGRAM='
def inline:
  . as $s
  | [match("`([^`]+)`|\\*\\*(.+?)\\*\\*|\\[([^\\]]+)\\]\\(([^)\\s]+)\\)|<?(https?://[^\\s<>()]*[^\\s<>().,;:!?\u0027\"])>?"; "g")] as $ms
  | (reduce $ms[] as $m ({pos: 0, out: []};
      .out += [{type: "text", text: $s[.pos:$m.offset]}]
      | .out += [$m.captures as $c
          | if $c[0].string != null then {type: "text", text: $c[0].string, marks: [{type: "code"}]}
            elif $c[1].string != null then {type: "text", text: $c[1].string, marks: [{type: "strong"}]}
            elif $c[2].string != null then {type: "text", text: $c[2].string, marks: [{type: "link", attrs: {href: $c[3].string}}]}
            else {type: "text", text: $c[4].string, marks: [{type: "link", attrs: {href: $c[4].string}}]} end]
      | .pos = $m.offset + $m.length)) as $r
  | ($r.out + [{type: "text", text: $s[$r.pos:]}]) | map(select(.text != ""));

def trim: sub("^\\s+"; "") | sub("\\s+$"; "");
def para($lines): {type: "paragraph", content: ($lines | join(" ") | inline)};

# Flat list items [{indent, kind, done, text}] -> ADF list nodes.
def lists:
  def entries:
    (.[0].indent) as $lvl
    | reduce .[] as $it ([];
        if length == 0 or $it.indent <= $lvl then . + [{item: $it, children: []}]
        else .[length - 1].children += [$it] end);
  def listitem:
    {type: "listItem",
     content: ([para([.item.text])]
       + (if (.children | length) > 0
          then .children | map(if .kind == "task" then .kind = "bullet" | .text = "[\(if .done then "x" else " " end)] \(.text)" else . end) | lists
          else [] end))};
  def taskitems:
    (.children | map(select(.kind != "task")) | map(.text)) as $notes
    | [{type: "taskItem", attrs: {state: (if .item.done then "DONE" else "TODO" end)},
        content: (([.item.text] + $notes) | join(" — ") | inline)}]
      + (.children | map(select(.kind == "task")) | if length > 0 then lists else [] end);
  entries
  | reduce .[] as $e ([];
      if length > 0 and .[length - 1].kind == $e.item.kind then .[length - 1].entries += [$e]
      else . + [{kind: $e.item.kind, entries: [$e]}] end)
  | map(if .kind == "task" then {type: "taskList", attrs: {}, content: [.entries[] | taskitems[]]}
        else {type: (if .kind == "ordered" then "orderedList" else "bulletList" end), content: [.entries[] | listitem]} end);

def flush_para: if (.para | length) > 0 then .blocks += [para(.para)] | .para = [] else . end;
def flush_items: if (.items | length) > 0 then .blocks += (.items | lists) | .items = [] else . end;
def flush: flush_para | flush_items;
def code_block: {type: "codeBlock", attrs: (if .code.lang != "" then {language: .code.lang} else {} end),
                 content: (.code.lines | join("\n") | if . == "" then [] else [{type: "text", text: .}] end)};

split("\n")
| reduce .[] as $l ({blocks: [], para: [], items: [], code: null};
    if .code != null then
      (if ($l | test("^\\s*```")) then .blocks += [code_block] | .code = null else .code.lines += [$l] end)
    elif ($l | test("^\\s*```")) then flush | .code = {lang: ($l | sub("^\\s*```"; "") | trim), lines: []}
    elif ($l | test("^\\s*$")) then flush_para
    elif ($l | test("^#{1,6}\\s")) then flush
      | ($l | capture("^(?<h>#{1,6})\\s+(?<t>.*)$")) as $h
      | .blocks += [{type: "heading", attrs: {level: ($h.h | length)}, content: ($h.t | trim | inline)}]
    elif ($l | test("^\\s*(-{3,}|\\*{3,}|_{3,})\\s*$")) then flush | .blocks += [{type: "rule"}]
    elif ($l | test("^\\s*([-*+]|[0-9]+[.)])\\s+")) then flush_para
      | ($l | capture("^(?<sp>\\s*)(?<m>[-*+]|[0-9]+[.)])\\s+(?<box>\\[[ xX]\\]\\s+)?(?<t>.*)$")) as $c
      | .items += [{indent: ($c.sp | gsub("\t"; "  ") | length),
                    kind: (if $c.box != null then "task" elif ($c.m | test("[0-9]")) then "ordered" else "bullet" end),
                    done: ($c.box != null and ($c.box | test("[xX]"))),
                    text: ($c.t | trim)}]
    elif (.items | length) > 0 and ($l | test("^\\s+\\S")) then .items[(.items | length) - 1].text += " " + ($l | trim)
    else flush_items | .para += [$l | trim] end)
| (if .code != null then .blocks += [code_block] else . end)
| flush
| {type: "doc", version: 1, content: .blocks}
# Every taskList and taskItem needs a localId.
| reduce ([paths(type == "object" and (.type == "taskList" or .type == "taskItem"))] | to_entries[]) as $e (.;
    setpath($e.value + ["attrs", "localId"]; "task-\($e.key + 1)"))
'

if [ -n "${2:-}" ]; then jq -R -s "$PROGRAM" "$1" >"$2"; else jq -R -s "$PROGRAM" "$1"; fi
