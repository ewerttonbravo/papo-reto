---
name: task
description: Runs a Papo Reto task end to end, from elucidation to PR. Use only when the user invokes /task, optionally with the number of a row in ../papo-reto-docs/roadmap.md.
argument-hint: "[task-number]"
disable-model-invocation: true
---

# Task

Which task: **$ARGUMENTS** if a number was given; otherwise the next in sequence, i.e. the first row of the task table in `../papo-reto-docs/roadmap.md`, in table order, without a `../papo-reto-docs/tasks/NN-*.md` marked `Status: fechada`. Say in 1 line which task was picked and why.

Deliver that task from `../papo-reto-docs/roadmap.md`: the smallest solution that delivers the behavior, test first, small PR. The rules in `CLAUDE.md` apply in full. Each phase ends at a gate; if the gate fails, the task stops: fix or ask, never skip.

## Phase 0: Elucidate (before any code)
1. State: read `../papo-reto-docs/estado.md` and the task's row in the roadmap. Check that git is on `main`, clean and in sync (`git fetch`), and that `gh pr list` shows no open PR from another task.
2. What binds the task: ADRs involved, performance budget rows and related trade-offs.
3. Prerequisites: list external data and tools (model, sherpa libs, reference WAVs, permissions, toolchain). Check that they exist; anything missing becomes a question before installing anything.
4. Gaps that change the outcome become closed questions (`AskUserQuestion`, named options, recommended first).
5. Cycles: at most ~3, each = 1 TDD cycle named after a behavior.
6. Size gate: 1 observable behavior and diff ≤ ~200 lines with tests. If it goes over, propose the split to Mr. Bravo; the roadmap only changes with his approval.
7. Write `../papo-reto-docs/tasks/NN-name.md` (in PT-BR, like the rest of the docs repo) with `Status: plano` and: context, cycles, tests (behavior and guard against false positives), manual checklist for the adapters touched and Given/When/Then criteria. Commit and push in the docs repo.

**Gate:** no open question that changes the outcome; Mr. Bravo approves the plan (`EnterPlanMode` → `ExitPlanMode`).

## Phase 1: Build with TDD
1. Branch `task/NN-name` from `main`.
2. For each cycle: write the test and run only it (`make test FILTER=<Test>`) → `test:` commit (red) → make it pass → `feat:` commit → refactor on green → `refactor:` commit.
3. A test that passes on the first run is a characterization test: say so in the commit body.
4. Never weaken, skip or delete a test to get to green.
5. `make test` only at milestones: end of the cycles or a change to `Package.swift`, the Makefile or scripts.
6. A deviation from the plan that changes the outcome: stop and ask. Any other deviation: record it in the commit body.

**Gate:** all cycles committed in red/green order and `make test` green.

## Phase 2: Tests that matter (check against the diff)
- One behavior per test, named after the rule. Would the test fail if the covered line were deleted or inverted?
- Explicit boundaries: 299/300/301 ms in the `Fn` gesture, 399/400 ms in the double tap, 0.4 s of audio, silence threshold.
- Core: pure unit tests, in-memory fakes, injected clock, no sleep.
- Adapter: no wiring tests and no tests of Apple APIs. What is ours in the adapter goes into the manual checklist.

**Gate:** no weak or superfluous test in the diff.

## Phase 3: Closing
1. `make test` (100% line coverage on the Core). If the task touched audio or the model: `make bench`, with before/after numbers.
2. Manual checklist for the adapters touched, run by Mr. Bravo or with him, with the result recorded.
3. `/code-review high` on the branch diff. `/security-review` when touching permissions, download, event tap or pasteboard. Each finding is fixed test first or justified in the PR.
4. Plan × delivered consistency: list what was asked for and not delivered.
5. New decision → ADR; new accepted cost → row in the trade-off table (`../papo-reto-docs/README.md`).
6. `README.md`: update only if how to install, run or use changed.
7. Push and open a PR against `main` with the body below. Wait for green CI.
8. Report to Mr. Bravo: PR link, evidence per criterion and deviations. Merge (merge commit) only with his explicit OK.
9. After the merge: overwrite `../papo-reto-docs/estado.md`, record the closing in `tasks/NN-name.md` and set it to `Status: fechada` (this is what picks the next task), commit and push in the docs repo. Write `../papo-reto-docs/notes/linkedin/NN-name.md` in the format of the README there and index it (outside git).

**Gate:** green CI, every criterion with evidence, every finding handled, LinkedIn note written.

## PR body
```markdown
## Task NN: <name>
<What the user can do or measure now, in 1-2 sentences.>

### Acceptance criteria
| # | Criterion | Evidence (test/command/checklist) |

### Commit trail
Red commits and what each one proved by failing; characterizations.

### Performance
`make bench` before/after (or "not applicable").

### Review
`/code-review high` (and `/security-review`): findings and how they were handled.

### Deviations from the plan
<Each one and why, or "None".>

Plan: ../papo-reto-docs/tasks/NN-name.md

🤖 Generated with [Claude Code](https://claude.com/claude-code)
```

## Inherited lessons (wallet-service, e-pix)
- PRs of 1,200 to 2,500 lines in wallet-service and of ~400 in e-pix: hence the ~200 ceiling.
- Full builds at every step cost time: targeted runs between milestones.
- A library's main branch is not its release: confirm the behavior in the pinned version, published ≥ 2 weeks ago.
- A tool prerequisite is not guaranteed (the Command Line Tools once came broken): check in Phase 0 and ask before installing.
- A number goes into CLAUDE.md only after it is measured: the premise "Whisper small works on Intel" fell in the benchmark.
