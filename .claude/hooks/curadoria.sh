#!/usr/bin/env bash
# Automatic curation of the project memory (protocol in CLAUDE.md, "Memory curation").
# Watches both repos: code (this one) and docs (../papo-reto-docs, ADR-007).
#   start: at session start, injects the current state, recent commits and pending changes.
#   stop:  at the end of a turn with uncommitted changes, forces a curation check,
#          at most once every THROTTLE_MIN minutes (bounded token cost).
set -uo pipefail

ROOT="${CLAUDE_PROJECT_DIR:-$(cd "$(dirname "$0")/../.." && pwd)}"
cd "$ROOT" || exit 0
git rev-parse --git-dir >/dev/null 2>&1 || exit 0
DOCS="$ROOT/../papo-reto-docs"

MAX_LINES=110
THROTTLE_MIN=30
STAMP="$(git rev-parse --git-dir)/curadoria-stamp"
lines=$(wc -l < CLAUDE.md 2>/dev/null | tr -d ' ')
changes=$(git status --porcelain)
docs_changes=$(git -C "$DOCS" status --porcelain 2>/dev/null)

case "${1:-}" in
  start)
    ctx="Curation (hook): $(cat "$DOCS/estado.md" 2>/dev/null)
Latest code commits:
$(git log -5 --format='%h %ad %s' --date=short 2>/dev/null || echo '(none)')"
    if [[ -n "$changes" ]]; then
      ctx+="
Uncommitted changes in the code (the previous session may have stopped before closing the milestone):
$(echo "$changes" | head -15)"
    fi
    if [[ -n "$docs_changes" ]]; then
      ctx+="
Uncommitted changes in ../papo-reto-docs:
$(echo "$docs_changes" | head -15)"
    fi
    if (( lines > MAX_LINES )); then
      ctx+="
CLAUDE.md has $lines lines (cap $MAX_LINES): move detail down to ../papo-reto-docs."
    fi
    jq -n --arg c "$ctx" '{hookSpecificOutput:{hookEventName:"SessionStart",additionalContext:$c}}'
    ;;
  stop)
    input=$(cat)
    [[ "$(jq -r '.stop_hook_active // false' <<<"$input")" == "true" ]] && exit 0
    [[ -z "$changes" ]] && [[ -z "$docs_changes" ]] && (( lines <= MAX_LINES )) && exit 0
    if [[ -f "$STAMP" ]] && [[ -n "$(find "$STAMP" -mmin -"$THROTTLE_MIN" 2>/dev/null)" ]]; then
      exit 0
    fi
    touch "$STAMP"
    reason="Curation check (automatic, max 1x/${THROTTLE_MIN}min). Uncommitted changes:
code: $(echo "$changes" | head -10)
docs: $(echo "$docs_changes" | head -10)
CLAUDE.md: $lines/$MAX_LINES lines.
Evaluate silently and act only if it applies: (1) was there a decision that becomes an ADR in ../papo-reto-docs/decisions? (2) is any accepted cost missing from the trade-off table in ../papo-reto-docs/README.md? (3) is ../papo-reto-docs/estado.md out of date? (4) was a task or relevant session closed without a note in ../papo-reto-docs/notes/linkedin? (5) milestone done -> commit with the why (docs: push straight to main; code: commit on the task branch). If nothing applies, end without comment."
    jq -n --arg r "$reason" '{decision:"block",reason:$r}'
    ;;
esac
exit 0
