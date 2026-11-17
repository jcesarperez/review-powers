#!/usr/bin/env bash
# PR 107 and its tickets: two flows (confirming a quote, the PMS webhook) and a
# new table. With no acli the review gathers by hand, as in no-script.
set -euo pipefail
"$(dirname "${BASH_SOURCE[0]}")/../../_fixtures/setup-pr.sh" 107
# Shadow any real acli on the machine, so nothing reaches a real Jira.
printf '#!/bin/sh\necho "acli: command not found" >&2\nexit 127\n' > "$HOME/.bin/acli"
chmod +x "$HOME/.bin/acli"
