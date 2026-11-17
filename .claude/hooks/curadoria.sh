#!/usr/bin/env bash
# Curadoria automática da memória do projeto (protocolo em CLAUDE.md, "Curadoria da memória").
# Olha os dois repos: código (este) e docs (../papo-reto-docs, ADR-007).
#   start: injeta no início da sessão o estado atual, os commits recentes e as mudanças pendentes.
#   stop:  ao fim de um turno com mudanças não commitadas, obriga uma checagem de curadoria,
#          no máximo 1 vez a cada THROTTLE_MIN minutos (custo de tokens limitado).
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
    ctx="Curadoria (hook): $(cat "$DOCS/estado.md" 2>/dev/null)
Últimos commits do código:
$(git log -5 --format='%h %ad %s' --date=short 2>/dev/null || echo '(nenhum)')"
    if [[ -n "$changes" ]]; then
      ctx+="
Mudanças não commitadas no código (sessão anterior pode ter parado sem fechar o marco):
$(echo "$changes" | head -15)"
    fi
    if [[ -n "$docs_changes" ]]; then
      ctx+="
Mudanças não commitadas em ../papo-reto-docs:
$(echo "$docs_changes" | head -15)"
    fi
    if (( lines > MAX_LINES )); then
      ctx+="
CLAUDE.md com $lines linhas (teto $MAX_LINES): descer detalhe para ../papo-reto-docs."
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
    reason="Checagem de curadoria (automática, máx. 1x/${THROTTLE_MIN}min). Mudanças não commitadas:
código: $(echo "$changes" | head -10)
docs: $(echo "$docs_changes" | head -10)
CLAUDE.md: $lines/$MAX_LINES linhas.
Avalie em silêncio e aja só se couber: (1) houve decisão que vira ADR em ../papo-reto-docs/decisions? (2) algum custo aceito falta na tabela de trade-offs do ../papo-reto-docs/README.md? (3) ../papo-reto-docs/estado.md está defasado? (4) task ou sessão relevante fechada sem nota em ../papo-reto-docs/notes/linkedin? (5) marco concluído -> commit com o porquê (docs: push direto na main; código: commit na branch da task). Se nada se aplica, encerre sem comentar."
    jq -n --arg r "$reason" '{decision:"block",reason:$r}'
    ;;
esac
exit 0
