#!/usr/bin/env bash
# PR 105's tickets and PR, with no acli: gather.py can't run, so the review
# has to gather by hand (the fake tracker for Jira, the fake gh for the PR).
set -euo pipefail
"$(dirname "${BASH_SOURCE[0]}")/../../_fixtures/setup-pr.sh" 105
# Shadow any real acli on the machine, so nothing reaches a real Jira.
printf '#!/bin/sh\necho "acli: command not found" >&2\nexit 127\n' > "$HOME/.bin/acli"
chmod +x "$HOME/.bin/acli"
