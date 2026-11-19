---
description: Task list for feature 011 — Repairs to the swimmer's journey
---

# Tasks: Repairs to the swimmer's journey

**Input**: Design documents from `/specs/011-swimmer-journey-repairs/`

**Prerequisites**: [plan.md](./plan.md), [spec.md](./spec.md), [research.md](./research.md), [data-model.md](./data-model.md), [contracts/sincronizacion-enmendada.md](./contracts/sincronizacion-enmendada.md), [quickstart.md](./quickstart.md)

## Format: `[ID] [P?] [Story] Description`

- **[P]**: can run in parallel — different files, no dependency on an unfinished task
- **[US1]**…**[US4]**: the user story in [spec.md](./spec.md) the task serves

## Tests are not optional here

Principle III is non-negotiable in this project: **the lock goes in before the thing it
guards, and every lock gets its negative control run**. That is not ceremony for this
feature in particular — all four of these defects walked past a green suite, and three of
them did it because a test double was kinder than the server it stood for.

So every repair below is: lock → see it red → control → fix → see it green.

**The rule for every double in this feature**: it must be able to **accept and never
answer**. A double that throws hides exactly the defect we are fixing. Every lock wraps
its call in a deadline with a failing message, so a regression fails the test rather than
stopping the suite.

## Path Conventions

Flutter app at the repository root. Domain in `lib/dominio/` (pure Dart, no Flutter),
data in `lib/datos/`, interface in `lib/ui/`, tests mirroring under `test/`.

---

## Phase 1: Setup

- [ ] T001 Record the baseline in `specs/011-swimmer-journey-repairs/tasks.md` beside this line: run the four gates on `011-swimmer-journey-repairs` before any change and write the numbers here — `flutter analyze`, `flutter test`, `npm --prefix firebase test`, `npm --prefix firebase/functions test`. Feature 010 could say "the 53 tests added are the locks its walks needed" only because it had this number

**Before, 2026-11-18:**

| Gate | Result |
|---|---|
| `flutter analyze` | _to fill_ |
| `flutter test` | _to fill_ |
| `npm --prefix firebase test` | _to fill_ |
| `npm --prefix firebase/functions test` | _to fill_ |

**The rules number is a gate, not a note.** This feature adds no rule and touches no
document. If `npm --prefix firebase test` ends on a different number than it started on,
something grew that was not meant to, and that is worth finding out before merging.

---

## Phase 2: Foundational (blocking prerequisites)

**Purpose**: the one thing both US1 and US4 need before either can be locked — a double
that behaves like the real SDK instead of like a polite stub.

- [ ] T002 Create the shared sync doubles in `test/dominio/sincronizacion/dobles_de_sincronizacion.dart`: an in-memory record store, an in-memory outbox, and `_TransporteMudo`, a transport that **accepts and never answers** (returns `Completer<DateTime>().future`), with a switch to make it answer and a count of attempts
- [ ] T003 Lock the double itself in `test/dominio/sincronizacion/dobles_de_sincronizacion_test.dart`: assert that the mute transport's future is **still incomplete** after a pump, so nobody later "fixes" it into throwing. The whole feature rests on this double telling the truth

**Checkpoint**: the doubles exist and are proven to hang. Stories can start.

---

## Phase 3: User Story 1 — What she wrote leaves by itself when the signal comes back (Priority: P1) 🎯 MVP

**Goal**: she annotates with no signal, puts the phone away, and what she wrote reaches
her coach without her opening the app or touching anything.

**Independent test**: with no network, annotate; restore the network; without touching
the app, the record reaches the server and the notice goes. In simulated time for the
suite; on a phone after feature 013.

### Locks for User Story 1 ⚠️ write first, see red

- [ ] T004 [P] [US1] Lock FR-003 in `test/dominio/sincronizacion/sin_cola_no_se_sondea_test.dart`: with an empty outbox, **no wake-up is ever scheduled and the transport is never touched** — assert the injected scheduler received zero requests and the transport's attempt count is zero
- [ ] T005 [P] [US1] Lock the schedule in `test/dominio/sincronizacion/reintenta_mientras_quede_algo_test.dart`: with one record queued and a transport that refuses, advancing the injected clock produces retries spaced 1, 2, 4, 8… seconds, **and the spacing stops growing at 60 seconds** (FR-006, D2)
- [ ] T006 [P] [US1] Lock SC-004 in `test/dominio/sincronizacion/lo_que_cuesta_sondear_test.dart`: over one simulated hour with one record queued and no network, the transport is attempted **at most 60 times**, and with an empty queue **zero times**
- [ ] T007 [P] [US1] Lock FR-005 in `test/dominio/sincronizacion/un_envio_logrado_suelta_la_cola_test.dart`: with records A and B both in long delays, when A's attempt succeeds **B is attempted at once** instead of serving out its own delay. Its negative control is the single-record case, which has no cut-short by design (research D2) and must still arrive inside the minute
- [ ] T008 [P] [US1] Lock FR-004 in `test/dominio/sincronizacion/el_sondeo_tambien_lleva_plazo_test.dart`: a transport that accepts and never answers leaves nothing hanging — `sincronizar()` returns, the record stays queued, and the attempt counts as failed (G3)
- [ ] T009 [P] [US1] Lock FR-002 and D1 in `test/datos/red/la_red_es_el_ultimo_intento_test.dart`: `hayConexion()` reports the outcome of the last attempt, is **optimistic before any attempt has happened**, and `cambios` emits when that outcome changes
- [ ] T010 [P] [US1] Lock FR-008 in `test/ui/nadador/nada_de_la_red_le_llega_test.dart`: a test over every file under `lib/ui/` that the swimmer can reach, asserting none of them contains a network error, a status code, a count of attempts, or a control that says retry. Model it on feature 010's test over `lib/ui` for video
- [ ] T011 [US1] Run the negative control for T004–T010 and record each result in `specs/011-swimmer-journey-repairs/tasks.md`: remove the schedule and T005/T006 go red; restore the 300-second cap and T005 goes red; remove the cut-short and T007 goes red; make the mute transport throw instead of hang and say which locks stop proving anything. **A lock whose control does not go red is not a lock** — feature 010 shipped one of those and caught it only by running the control

### Implementation for User Story 1

- [ ] T012 [P] [US1] Lower the retry delay's cap from 300 to 60 seconds in `lib/dominio/entidades/envio_pendiente.dart`, and rewrite the doc comment to carry the new reason: the old cap predates anything retrying on a schedule, and one attempt a minute is still not the tight loop it was guarding against
- [ ] T013 [US1] Add the injected wake-up seam to `lib/dominio/sincronizacion/bandeja_salida.dart` — a `Despertador` the constructor takes, defaulting to a real timer — so the eight guarantees keep being proven without a second of real time elapsing (principle II, D6)
- [ ] T014 [US1] Implement "keep the queue moving" in `lib/dominio/sincronizacion/bandeja_salida.dart`: while the outbox is non-empty, keep a wake-up scheduled on the soonest record's delay; **schedule nothing while it is empty**; stop cleanly on request (depends on T013)
- [ ] T015 [US1] Implement FR-005 in `lib/dominio/sincronizacion/bandeja_salida.dart`: when one attempt succeeds, clear the remaining records' retry delays so the next pass tries them at once (depends on T014)
- [ ] T016 [US1] Rewrite `lib/datos/red/estado_de_red.dart` so the network is the outcome of the last attempt (D1): drop the injected `sondear`, add a way for the outbox to report an attempt's result, keep `cambios` emitting only on change, and keep the file's original paragraph about pool wifi — it was right all along
- [ ] T017 [US1] Remove the probe that never probed from `lib/main.dart` (`sondear: () async => datos != null`) and wire whatever D1 replaces it with. Leave a comment naming what happened: the line sat directly beneath a comment describing the opposite behaviour, and nobody noticed for seven features
- [ ] T018 [US1] Decide `Sincronizador.alVolverLaRed` in `lib/dominio/sincronizacion/bandeja_salida.dart`: with the schedule in place it has no caller and no distinct meaning, so either wire it or **retire it with the reason written where it used to be**. Do not leave a tested member with no listener — that is one of the two defects this feature exists to fix
- [ ] T019 [US1] Start the schedule when the swimmer's journey opens and stop it in `dispose()` in `lib/ui/nadador/estado_nadador.dart`, which the HUB already calls (D6). A schedule that outlives sign-out would keep one swimmer's queue working under her brother's account, which is feature 004's C7
- [ ] T020 [US1] Update `specs/003-consumo-del-nadador/contracts/sincronizacion.md` to point at [the amendment](./contracts/sincronizacion-enmendada.md), without rewriting it: the eight guarantees are unchanged and the original is the record of what was promised

**Checkpoint**: US1 is independently demonstrable — annotate with a refusing transport,
make it answer, and the record goes with nothing else called.

---

## Phase 4: User Story 2 — A session she said she did not do stops being counted (Priority: P2)

**Goal**: "I did not do it" is an answer, and stops appearing among the sessions she has
left to mark — on her screen and on his.

**Independent test**: answer a past session with "no pude hacerla" and confirm it leaves
the pending list while an unanswered past session stays in it.

### Locks for User Story 2 ⚠️ write first, see red

- [ ] T021 [P] [US2] Lock FR-010 and FR-011 in `test/dominio/macrociclo/lo_que_contesto_no_esta_pendiente_test.dart`: a past session answered "I did not do it" is **not** pending; a past session with no answer **is**; one marked done is not; today's unanswered is not; one with no date is not
- [ ] T022 [P] [US2] Lock FR-012 in `test/ui/nadador/una_regla_dos_pantallas_test.dart`: the count the swimmer reads and the count the coach reads come from the same rule and are equal for the same sessions
- [ ] T023 [US2] Run the negative control for T021–T022 and record it in `specs/011-swimmer-journey-repairs/tasks.md`: restore `pendientes` to excluding only `hechas` and confirm T021 goes red on the "I did not do it" case specifically

### Implementation for User Story 2

- [ ] T024 [US2] Change `pendientes` to derive from `sinContestar` in `lib/dominio/macrociclo/progreso_en_el_macrociclo.dart`, and add the sentence that explains why this getter existed beside a correct one and used the wrong set
- [ ] T025 [US2] Check every caller still reads what it means to: `lib/ui/nadador/mi_macrociclo.dart` (the swimmer's list) and the coach's reading in `lib/ui/analisis/`. Nothing should need changing — confirm that by reading, not by assuming

**Checkpoint**: US2 is independently demonstrable and touches no file US1 touched.

---

## Phase 5: User Story 3 — No screen tells her something is missing while it is still looking (Priority: P2)

**Goal**: "still reading", "there is nothing" and "it could not be read" stop being the
same sentence.

**Independent test**: with no network and a cold start, the progress screen says it is
loading and never says she has no plan.

### Locks for User Story 3 ⚠️ write first, see red

- [ ] T026 [P] [US3] Lock the type in `test/dominio/lectura/lectura_test.dart`: `Cargando`, `Hay`, `NoHay` and `NoSePudo` are exhaustive at the point of use, and a `switch` that omits one does not compile — the whole reason for a sealed type over a flag
- [ ] T027 [P] [US3] Lock FR-013 for the progress screen in `test/ui/nadador/no_dice_que_falta_mientras_busca_test.dart`: while the reading is in flight the screen shows that it is loading and **the empty state's words appear nowhere**; once finished with nothing, they appear; once failed, it says it could not be read
- [ ] T028 [P] [US3] Lock FR-014 in `test/ui/nadador/las_palabras_del_vacio_no_cambian_test.dart`: the sentence «Todavía no tienes un plan asignado» and its explanation are byte-for-byte what they are today, and reachable only from `NoHay`
- [ ] T029 [US3] Run the negative control for T026–T028 and record it in `specs/011-swimmer-journey-repairs/tasks.md`: make the screen treat `Cargando` as `NoHay` and confirm T027 goes red

### Implementation for User Story 3

- [ ] T030 [P] [US3] Create the sealed `Lectura<T>` in `lib/dominio/lectura/lectura.dart` with `Cargando`, `Hay(valor)`, `NoHay` and `NoSePudo(motivo)` — no Flutter import, and no words for the swimmer: the screen owns the phrasing (data-model.md)
- [ ] T031 [US3] Expose the swimmer's plan and progress as a `Lectura` instead of a nullable in `lib/ui/nadador/estado_nadador.dart`, so the two meanings of `null` stop sharing one value (depends on T030)
- [ ] T032 [US3] Handle the four cases in `lib/ui/nadador/pantalla_mi_progreso.dart`, keeping `EstadoVacio` and its existing words for `NoHay` only (depends on T031)
- [ ] T033 [US3] Do the same in `lib/ui/nadador/pantalla_sesion_del_dia.dart`, which carries the identical sentence. Fixing one and leaving the other is how this defect survives to the next walk

**Checkpoint**: US3 is independently demonstrable; both of her screens tell the four
states apart.

---

## Phase 6: User Story 4 — The notice stops outliving the sending (Priority: P3)

**Goal**: the notice is on screen if and only if something is genuinely not yet on the
server.

**Independent test**: an attempt that exceeds its deadline and completes later marks the
record sent and clears the notice, with no extra request made.

**Note on ordering**: this story edits the same method as T014 and T015, so it is
sequential with US1 rather than parallel to it.

### Locks for User Story 4 ⚠️ write first, see red

- [ ] T034 [P] [US4] Lock FR-015 in `test/dominio/sincronizacion/el_exito_tardio_cuenta_test.dart`: an attempt that exceeds its deadline and **then completes** leaves the record sent and the outbox empty, and no additional call is made to the transport or to any reader to find that out
- [ ] T035 [P] [US4] Lock FR-016 in `test/dominio/sincronizacion/el_aviso_solo_se_apaga_si_llego_test.dart`: a record the transport never confirms stays queued and the notice stays, however many cycles pass
- [ ] T036 [US4] Run the negative control for T034–T035 and record it in `specs/011-swimmer-journey-repairs/tasks.md`: drop the late-success handling and confirm T034 goes red; clear the notice optimistically on timeout and confirm T035 goes red

### Implementation for User Story 4

- [ ] T037 [US4] Keep the timed-out attempt's future in `lib/dominio/sincronizacion/bandeja_salida.dart` and honour a late completion by marking the record sent, without issuing any new request (D3). `Future.timeout` does not cancel what it wraps, so the answer arrives for free (depends on T014)
- [ ] T038 [US4] Make sure a late completion cannot raise an unhandled error after the attempt was abandoned, in `lib/dominio/sincronizacion/bandeja_salida.dart` — a failure arriving after nobody is listening must be swallowed, not crash the app on a street corner (depends on T037)

**Checkpoint**: all four stories independently functional.

---

## Phase 7: Polish & Cross-Cutting

- [ ] T039 Run the four gates and write the numbers in `specs/011-swimmer-journey-repairs/tasks.md` beside T001's baseline. The difference is the locks this feature needed
- [ ] T040 Confirm `npm --prefix firebase test` ends on **exactly** the number it started on, and that `git diff` shows no change under `firebase/`. This feature adds no rule; a moved number means something grew
- [ ] T041 Confirm `git diff pubspec.yaml pubspec.lock` is empty. Principle VII's gate for this feature was refusing a connectivity dependency, and this is how that refusal is checked rather than remembered
- [ ] T042 [P] Rewrite the 011 paragraphs in `docs/ROADMAP.md` to say what was actually built, the way features 009 and 010 did — including that the attempt is the probe, and what it costs per hour
- [ ] T043 [P] Record in `specs/011-swimmer-journey-repairs/tasks.md` what is left for the post-013 walk: C1 and C2 of feature 003 and C7 and C8 of feature 004, tasks T071, T088 and T089, with what this feature proved about each in simulated time and what only a phone can add
- [ ] T044 Re-read the Constitution Check table in [plan.md](./plan.md) against what was actually built and correct it if anything drifted. A gate that is only true at planning time is not a gate
- [ ] T045 Run [quickstart.md](./quickstart.md) V1 to V9 and record what each showed, in this file
- [ ] T046 [P] Mark feature 011 on the roadmap in `docs/ROADMAP.md` once the PR merges

---

## Dependencies & Execution Order

### Phase dependencies

- **Phase 1 (Setup)**: no dependencies — T001 first, because a baseline taken afterwards is not a baseline
- **Phase 2 (Foundational)**: blocks US1 and US4, which both need the mute double. US2 and US3 do not need it and could start earlier
- **Phase 3 (US1)**: after Phase 2
- **Phase 4 (US2)** and **Phase 5 (US3)**: after Phase 1. They share no file with each other or with US1
- **Phase 6 (US4)**: after T014 of US1 — same method, so sequential, not parallel
- **Phase 7 (Polish)**: after every story meant to ship

### Within each story

Lock → see it red → negative control → implement → see it green. Not negotiable
(principle III), and the reason is this feature's own history: all four defects passed a
green suite.

### Parallel opportunities

- **US2 and US3 are genuinely independent** of US1 and of each other: different files,
  different tests, different screens. Either can be done first, and either alone is a
  shippable improvement.
- Within US1, the locks T004–T010 are all different files and can be written together.
- Within US3, T026 and T030 are the type and its lock; T027, T028 and the two screen
  tasks follow.
- **US1 and US4 are not parallel.** Both edit `_intentar` in `bandeja_salida.dart`.

---

## Parallel Example: User Story 1's locks

```bash
# All seven locks are separate files and can be written together:
Task: "Lock FR-003 in test/dominio/sincronizacion/sin_cola_no_se_sondea_test.dart"
Task: "Lock the schedule in test/dominio/sincronizacion/reintenta_mientras_quede_algo_test.dart"
Task: "Lock SC-004 in test/dominio/sincronizacion/lo_que_cuesta_sondear_test.dart"
Task: "Lock FR-005 in test/dominio/sincronizacion/un_envio_logrado_suelta_la_cola_test.dart"
Task: "Lock FR-004 in test/dominio/sincronizacion/el_sondeo_tambien_lleva_plazo_test.dart"
Task: "Lock FR-002 in test/datos/red/la_red_es_el_ultimo_intento_test.dart"
Task: "Lock FR-008 in test/ui/nadador/nada_de_la_red_le_llega_test.dart"
```

---

## Implementation Strategy

### MVP: User Story 1 alone

1. Phase 1 — the baseline
2. Phase 2 — the double that hangs
3. Phase 3 — US1
4. **Stop and check**: annotate against a refusing transport, make it answer, and the
   record goes with nothing else called. That is the promise feature 003 made and has
   never kept, and it is worth stopping on

### Incremental

US2 and US3 can land in either order after that, each on its own. US4 goes last because
US1 makes it rare, and because it edits the same method.

### What to resist

- **Adding a connectivity package.** It answers "is there an interface"; the question is
  "does the server answer". Research D1 has the long version
- **Polling anything when the queue is empty.** The cheapest check in the whole feature
  (T004) exists because every later change will want to add "just one more poll"
- **Writing a double that throws.** It is more convenient and it is how three of these
  four defects stayed hidden. The double must be able to accept and never answer
- **Widening the scope to the device walk.** The coach decided those are walked together
  after feature 013; this feature proves everything a test can and says what is left
