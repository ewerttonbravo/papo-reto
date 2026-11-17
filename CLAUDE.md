# Papo Reto — CLAUDE.md

## Produto
Ditado por voz para macOS, focado em PT-BR, 100% local e open-source (MIT). Segura `Fn`, fala, solta: o texto aparece no cursor. Alternativa gratuita ao Wispr Flow, inspirada no [Arara](https://github.com/davimatosms/Arara-voice), mas nativa e leve.

MVP: menu bar (sem Dock nem janela), ícone por estado (carregando / pronto / gravando / transcrevendo), menu com microfones e "Sair". Fora de escopo sem pedido explícito: Windows/Linux, nuvem, troca de modelo, histórico, dicionário, temas, preview ao vivo, auto-update, onboarding, atalho configurável.

## Princípios
1. **Brutalmente simples.** Feature nova precisa justificar a existência. Na dúvida, não entra.
2. **Leve onde dá.** O modelo fica residente (ADR-003); fora isso, ~0% de CPU ocioso, sem timer de polling, microfone desligado fora da gravação.
3. **Local.** Áudio e texto nunca saem da máquina; a única rede é o download do modelo (ADR-002).
4. **Configuração mínima.** O único ajuste é o microfone.
5. **Intel primeiro.** Mac de referência: i5-1038NG7 (4 núcleos, AVX-512, 16 GB, macOS 26). Medir nele antes de Apple Silicon.

## Dois repos (ADR-007)
- `papo-reto` (este): código, `README.md` e ferramentas do agente (`CLAUDE.md`, `.claude/`, `scripts/`). O PR de task não leva doc além do README.
- `../papo-reto-docs`: [estado](../papo-reto-docs/estado.md), [roadmap de tasks](../papo-reto-docs/roadmap.md), [ADRs e trade-offs](../papo-reto-docs/README.md), planos de task (`tasks/NN-nome.md`), `notes/linkedin/` (fora do git). Push direto na `main`.
- Ler `../papo-reto-docs/estado.md` no início de cada sessão.

## Curadoria da memória
- ADR novo em `../papo-reto-docs/decisions/` quando houver escolha entre ≥ 2 alternativas reais, algo testado e descartado, ou decisão do Mr. Bravo que restringe escopo ou rumo. Formato: Status/data · Contexto · Decisão · Alternativas descartadas · Custo aceito · Consequências · Evidência. ≤ ~30 linhas.
- ADR é imutável: mudar uma decisão = ADR novo "substitui ADR-00X", e o antigo vira "substituído". Atualizar o índice e a tabela de trade-offs em `../papo-reto-docs/README.md`.
- Todo custo aceito vira uma linha na tabela de trade-offs (tipo Design ou Restrição, porquê, caminho futuro).
- `estado.md` é sobrescrito ao fim de cada bloco de trabalho; nunca vira log.
- Ao fechar cada task ou sessão relevante: nota em `../papo-reto-docs/notes/linkedin/NN-nome.md` no formato do README de lá, com só fatos verificados.
- Memory guarda só preferência de colaboração; fato do projeto vai para os repos. Commit a cada marco, com o porquê.
- Avisar em 1 linha ao registrar ("Registrei ADR-009: ..."). Este arquivo ≤ 110 linhas; o excesso desce para `../papo-reto-docs`.
- Automático via `.claude/hooks/curadoria.sh`: injeta o estado no início da sessão e força a checagem ao fim de turno com mudanças não commitadas (no máximo 1x a cada 30 min).

## Stack
Swift 6 · AppKit · SwiftPM (sem Xcode project, sem SwiftUI, sem dependências Swift de terceiros) · Swift Testing · sherpa-onnx (C API, libs pré-compiladas fixadas por SHA-256) · Parakeet TDT 0.6B v3 int8 (ADR-003) · macOS 13+ · release por arquitetura (ADR-006).

## Arquitetura
| Target | Conteúdo | Pode importar |
|---|---|---|
| `PapoRetoCore` | Lógica pura: máquina de estados, gesto do `Fn` (relógio injetado), descarte de silêncio, verificação de SHA-256, texto final, portas (protocolos) | só Foundation |
| `PapoReto` | App + adapters finos: `StatusMenu`, `FnKeyMonitor` (CGEventTap), `AudioRecorder` (AVAudioEngine), `AudioDevices` (Core Audio), `Transcriber` (sherpa), `ModelStore` (download), `Paster` | qualquer coisa + Core |
| `CSherpaOnnx` | module map para `c-api.h` | — |

O compilador impede o Core de importar o app. Todas as transições de estado passam pela máquina de estados do Core; adapter nenhum muda estado por conta própria.

## Armadilhas conhecidas
- **Modelo:** carrega uma vez em background ao abrir o app; reusar o `OfflineRecognizer` e criar um stream por transcrição; `num_threads` = `hw.physicalcpu`. Um `Fn` antes do load terminar grava normalmente e transcreve quando o modelo fica pronto.
- **Áudio:** o engine só roda durante a gravação. O microfone é escolhido com `kAudioOutputUnitProperty_CurrentDevice` e persistido pelo UID, caindo no padrão se o dispositivo sumir. Converter para 16 kHz mono Float32 em memória, nunca em disco. Medir o mãos-livres com 2 min de fala antes de decidir por VAD.
- **Fn:** CGEventTap em `flagsChanged` + `keyDown` (`.maskSecondaryFn`). Gravar já no keydown e descartar se for toque curto. Fn+tecla cancela. Reativar após `tapDisabledByTimeout`. Orientar o usuário: "Pressionar tecla 🌐 para" → "Não fazer nada".
- **Colar:** salvar o pasteboard inteiro, escrever com `org.nspasteboard.TransientType`, enviar Cmd+V via CGEvent e restaurar em ~250 ms.
- **Permissões:** o TCC amarra a permissão à assinatura. Ad-hoc reseta a cada build, então o dev usa o certificado autoassinado "Papo Reto Dev" (ADR-006).
- **Idioma:** o v3 detecta o idioma sozinho e foi treinado com mais português europeu; vigiar frase curta saindo em espanhol.

## Orçamento de performance (medir no Mac de referência)
| Métrica | Alvo |
|---|---|
| RAM residente com o modelo, ocioso | < 800 MB (provisório; a T01 fixa o número nativo) |
| CPU ociosa | ~0% |
| Soltar `Fn` → texto colado, 10 s de fala | < 1,5 s (sherpa medido: 0,8 s) |
| Load do modelo na abertura | < 5 s, em background, sem travar a menu bar |
| `.app` por arquitetura, sem modelo | < 45 MB |

## Processo (ADR-008)
- **Tasks**: roadmap em `../papo-reto-docs/roadmap.md`; cada task roda pelo skill `/task NN` (elucidar → TDD → PR). 1 comportamento observável, diff ≤ ~200 linhas com testes.
- **TDD**: red → green → refactor, um ciclo por comportamento, teste sempre primeiro.
- **KISS/DRY**: a solução mínima que passa no teste; abstração só no 2º uso real.
- Testes do Core: Swift Testing, unitários puros, fakes em memória, nome do teste = regra (`fnHeldOver300msStartsPushToTalk`). Sem sleep: relógio injetado.
- Adapters: sem teste de wiring. Validação por checklist manual no plano da task e por `make bench`.

## Gates
- `make test`: `swift test` + 100% de cobertura de linha no `PapoRetoCore` (llvm-cov), quebrando o build abaixo disso.
- `make bench` (task que mexe em áudio ou modelo): texto, latência e RAM dos WAVs de referência contra o orçamento.
- CI (GitHub Actions, macOS): `make test`.

## Comandos
`make test` · `make test FILTER=<Teste>` (um teste, sem cobertura; nas CLT o `swift test` puro não acha o Swift Testing) · `make app` (monta e assina o `.app`) · `make run`. A criar: `make bench` (T01), `make install` (T09), `make release` (T10).

## Convenções
- Código e nomes em inglês; UI, README, commits e docs em PT-BR.
- `os.Logger` com subsistema `papo-reto`; nunca logar o texto transcrito.
- Dependência nova só com discussão: cada uma custa RAM, tamanho e superfície de quebra.
- Mudança que afeta o orçamento traz a medição antes/depois no PR.
