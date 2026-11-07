---
type: regex
# Nothing documents the bot's trigger, so no comment may guess one: no line
# starting with a slash command, and no mention of the bot.
target: { source: file, path: .git/gh-calls.log }
pattern: '^POSTED\t[^\t]*\t[^\t]*\t(?:(?:.*?\\n)?[ \t>]*/[a-z]|.*@acme-review)'
flags: m
match: not_contains
---
