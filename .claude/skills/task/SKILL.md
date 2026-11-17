---
name: task
description: Executa uma task do Papo Reto de ponta a ponta, da elucidação ao PR. Usar só quando o usuário invocar /task com o número de uma linha de ../papo-reto-docs/roadmap.md.
argument-hint: <numero-da-task>
disable-model-invocation: true
---

# Task $ARGUMENTS

Entregar a task **$ARGUMENTS** do `../papo-reto-docs/roadmap.md`: a menor solução que entrega o comportamento, com teste primeiro e PR pequeno. As regras do `CLAUDE.md` valem integralmente. Cada fase termina num gate; se o gate falha, a task para: corrigir ou perguntar, nunca pular.

## Fase 0: Elucidar (antes de qualquer código)
1. Estado: ler `../papo-reto-docs/estado.md` e a linha $ARGUMENTS do roadmap. Conferir que o git está na `main`, limpo e sincronizado (`git fetch`), e que `gh pr list` não mostra PR aberto de outra task.
2. O que amarra a task: ADRs envolvidos, linhas do orçamento de performance e trade-offs relacionados.
3. Pré-requisitos: listar dados e ferramentas externos (modelo, libs do sherpa, WAVs de referência, permissões, toolchain). Checar se existem; o que faltar vira pergunta antes de instalar qualquer coisa.
4. Lacunas que mudam o resultado viram perguntas fechadas (`AskUserQuestion`, opções nomeadas, a recomendada primeiro).
5. Ciclos: no máximo ~3, cada um = 1 ciclo TDD com nome de comportamento.
6. Size gate: 1 comportamento observável e diff ≤ ~200 linhas com testes. Se passar disso, propor a divisão ao Mr. Bravo; o roadmap só muda com a aprovação dele.
7. Gravar `../papo-reto-docs/tasks/NN-nome.md` com: contexto, ciclos, testes (comportamento e guarda contra falso positivo), checklist manual dos adapters tocados e critérios Given/When/Then. Commit e push no repo de docs.

**Gate:** nenhuma pergunta aberta que mude o resultado; Mr. Bravo aprova o plano (`EnterPlanMode` → `ExitPlanMode`).

## Fase 1: Construir com TDD
1. Branch `task/NN-nome` a partir da `main`.
2. Para cada ciclo: escrever o teste e rodar só ele (`swift test --filter <Teste>`) → commit `test:` (red) → fazer passar → commit `feat:` → refatorar no verde → commit `refactor:`.
3. Teste que passa de primeira é teste de caracterização: dizer isso no corpo do commit.
4. Nunca enfraquecer, pular ou apagar teste para chegar ao verde.
5. `make test` só nos marcos: fim dos ciclos ou mudança em `Package.swift`, Makefile ou scripts.
6. Desvio do plano que muda o resultado: parar e perguntar. Outro desvio: registrar no corpo do commit.

**Gate:** todos os ciclos commitados na ordem red/green e `make test` verde.

## Fase 2: Testes que importam (checar contra o diff)
- Um comportamento por teste, nomeado pela regra. O teste falharia se a linha coberta fosse apagada ou invertida?
- Fronteiras explícitas: 299/300/301 ms no gesto do `Fn`, 399/400 ms no duplo toque, 0,4 s de áudio, limiar de silêncio.
- Core: unitário puro, fakes em memória, relógio injetado, sem sleep.
- Adapter: sem teste de wiring nem de API da Apple. O que é nosso no adapter cabe no checklist manual.

**Gate:** nenhum teste fraco ou supérfluo no diff.

## Fase 3: Fechamento
1. `make test` (100% de linha no Core). Se a task mexeu em áudio ou modelo: `make bench`, com os números antes/depois.
2. Checklist manual dos adapters tocados, executado pelo Mr. Bravo ou com ele, com o resultado anotado.
3. `/code-review high` no diff da branch. `/security-review` quando tocar permissões, download, event tap ou pasteboard. Cada achado é corrigido com teste primeiro ou justificado no PR.
4. Coerência plano × entregue: listar o que foi pedido e não entregue.
5. Decisão nova → ADR; custo aceito novo → linha na tabela de trade-offs (`../papo-reto-docs/README.md`).
6. `README.md`: atualizar só se mudou como instalar, rodar ou usar.
7. Push e PR contra a `main` com o corpo abaixo. Esperar o CI verde.
8. Reportar ao Mr. Bravo: link do PR, evidência por critério e desvios. Merge (merge commit) só com o OK explícito dele.
9. Depois do merge: sobrescrever `../papo-reto-docs/estado.md`, registrar o fechamento em `tasks/NN-nome.md`, commit e push no repo de docs. Escrever `../papo-reto-docs/notes/linkedin/NN-nome.md` no formato do README de lá e indexar (fora do git).

**Gate:** CI verde, todo critério com evidência, todo achado tratado, nota de LinkedIn escrita.

## Corpo do PR
```markdown
## Task NN: <nome>
<O que o usuário consegue fazer ou medir agora, em 1-2 frases.>

### Critérios de aceite
| # | Critério | Evidência (teste/comando/checklist) |

### Trilha de commits
Commits red e o que cada um provou falhando; caracterizações.

### Performance
`make bench` antes/depois (ou "não se aplica").

### Revisão
`/code-review high` (e `/security-review`): achados e tratamento.

### Desvios do plano
<Cada um e o porquê, ou "Nenhum".>

Plano: ../papo-reto-docs/tasks/NN-nome.md

🤖 Generated with [Claude Code](https://claude.com/claude-code)
```

## Lições herdadas (wallet-service, e-pix)
- PRs de 1.200 a 2.500 linhas no wallet-service e de ~400 no e-pix: por isso o teto de ~200.
- Builds completos a cada passo custam tempo: execução direcionada entre marcos.
- A branch main de uma biblioteca não é o release dela: confirmar o comportamento na versão fixada, publicada há ≥ 2 semanas.
- Pré-requisito de ferramenta não é garantido (as Command Line Tools já vieram quebradas): checar na Fase 0 e perguntar antes de instalar.
- Número no CLAUDE.md só depois de medido: a premissa "Whisper small serve no Intel" caiu no benchmark.
