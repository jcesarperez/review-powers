#!/usr/bin/env bash
# PR 203 without CONTRIBUTING.md, the only place the bot's trigger is written.
set -euo pipefail
NO_MAIN_FILES=1 "$(dirname "${BASH_SOURCE[0]}")/../../_fixtures/setup-pr.sh" 203 author
