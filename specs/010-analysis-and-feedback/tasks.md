---

description: "Task list for feature 010 — Análisis and feedback"
---

# Tasks: Análisis and feedback

**Input**: Design documents from `/specs/010-analysis-and-feedback/`

**Prerequisites**: [plan.md](./plan.md), [spec.md](./spec.md), [research.md](./research.md),
[data-model.md](./data-model.md), [contracts/](./contracts/), [quickstart.md](./quickstart.md)

**Tests**: **Not optional.** Constitution principle III is non-negotiable, and this project's
practice is stricter than the template's default: the lock is written **before** the thing it
guards, and each one is verified with a negative control — break the thing, watch the test go
red. Feature 008 learned why with 18 of 24 rules tests passing against a collection that had no
rule at all; feature 009 learned it again when a source-level test matched a helper's definition
instead of its call.

**Organization**: by user story, so each can be built, tested and demonstrated alone.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: can run in parallel — different files, no dependency on unfinished work
- **[Story]**: US1…US4, mapping to the spec's user stories
- Every task names the file it touches

---

## Phase 1: Setup

**Purpose**: know where we start, so the end can be compared to it

- [X] T001 Record the baseline in `specs/010-analysis-and-feedback/tasks.md` beside this line: run the four gates on `010-analysis-and-feedback` before any change and write the numbers here — `flutter analyze`, `flutter test`, `npm --prefix firebase test`, `npm --prefix firebase/functions test`. Feature 009 could say "the 34 tests added are the locks its defects needed" only because it had this number

**Baseline, 2026-11-11, before any change on `010-analysis-and-feedback`:**

| Gate | Result |
|---|---|
| `flutter analyze` | No issues found |
| `flutter test` | 1963 passed, 0 failed |
| `npm --prefix firebase test` | 146 passed, 0 failed |
| `npm --prefix firebase/functions test` | 45 passed, 0 failed |

T073 runs them again. The difference is the locks this feature needed.
- [X] T002 [P] Create `lib/dominio/analisis/` and `lib/ui/analisis/` with no files yet, per the structure in plan.md
- [X] T003 [P] Create `test/dominio/analisis/` and `test/ui/analisis/`

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: the reading itself. US1, US2 and US3 are three ways of looking at it, so none of
them can start until it exists.

**⚠️ CRITICAL**: no user story work begins until this phase is done

### The two loads, kept apart by construction

- [X] T004 Write the lock in `test/dominio/analisis/las_dos_cargas_no_se_juntan_test.dart`: a `RespuestaASesion` exposes the session and the record separately, and the type has **no member returning a figure derived from both**. Assert over the type's own source that no getter mentions both `sesion` and `registro` in one expression. Must be red first
- [X] T005 Verify T004's negative control: add a getter to `lib/dominio/analisis/respuesta_a_sesion.dart` that multiplies metres by RPE, confirm `test/dominio/analisis/las_dos_cargas_no_se_juntan_test.dart` goes red, remove it
- [X] T006 [US-shared] Create `RespuestaASesion` in `lib/dominio/analisis/respuesta_a_sesion.dart` with `sesion` (`Sesion`), `registro` (`RegistroDeSesion?`, null when unanswered) and `peticion` (`PeticionDeFeedback?`, null until Phase 6 exists — leave the field out until T045 lands and add it then)

### Reading a swimmer

- [X] T007 Write the lock in `test/dominio/analisis/lectura_del_nadador_test.dart`: a swimmer with no records yields an empty `respuestas` and **not** an error; a swimmer with records yields one `RespuestaASesion` per session, answered or not. Must be red first
- [X] T008 Write the lock in `test/dominio/analisis/el_linaje_tambien_para_el_entrenador_test.dart`: an answer written against a plan version later replaced is still found, attached to the session she swam. Seed two versions with `versionAnteriorId` and records on the old one
- [X] T009 Verify T008's negative control: in `lib/dominio/analisis/lectura_del_nadador.dart` swap `registrosDelLinaje` for a direct `obtenerDePlan` over the current plans, confirm `test/dominio/analisis/el_linaje_tambien_para_el_entrenador_test.dart` goes red, restore. This is exactly the defect feature 009 shipped (`b7a5120`)
- [X] T010 Write the lock in `test/dominio/analisis/la_adherencia_no_se_recalcula_test.dart`: the reading's adherence equals `ProgresoEnElMacrociclo.adherencia` for the same inputs, and `lectura_del_nadador.dart` contains no arithmetic over `hechas`/`pendientes`. A second calculation is a second methodology (principle I)
- [X] T011 Write the lock in `test/dominio/analisis/un_fallo_no_es_una_lectura_vacia_test.dart`: when the records repository throws `FalloDeDatos`, `leerAlNadador` propagates it and does **not** return an empty reading. An empty reading and an unreadable one say opposite things to a coach deciding what to programme next
- [X] T012 Create `LecturaDelNadador` in `lib/dominio/analisis/lectura_del_nadador.dart` with `nadador`, `mesociclos`, `respuestas`, `progreso` and `conMolestia`, per data-model.md
- [X] T013 Implement `leerAlNadador(...)` in the same file, per the contract in `contracts/lectura_y_peticion.md` §2: records through `registrosDelLinaje`, adherence from `ProgresoEnElMacrociclo`, failures propagated
- [X] T014 Confirm the domain boundary: run `flutter test test/dominio/arquitectura_test.dart`. `lib/dominio/analisis/` must import neither Flutter nor Firebase (principle II)

### Reaching the records as the coach

- [X] T015 Expose the coach's reader in `lib/ui/hub/repositorios_del_hub.dart`: a getter that resolves to `registrosDelServidor`, with a comment saying why it is **not** `RegistrosDeLasDosPartes` — his device never wrote her answers, so "local wins" has nothing to win with (research D3)
- [X] T016 Write the lock in `test/ui/hub/de_donde_lee_el_entrenador_test.dart`: with a server present the coach's reader is the server one; without a server it falls back to local rather than failing on every read

**Checkpoint**: the reading exists and is covered. The three reading stories can now start.

---

## Phase 3: User Story 1 — The coach reads what his swimmers answered (Priority: P1) 🎯 MVP

**Goal**: he opens `Análisis`, picks a swimmer, and reads her answers beside the sessions that
produced them.

**Independent Test**: sign in as the coach on a device that never saw her answers, open
`Análisis`, read them. Delivers the control step with nothing else from this feature built.

### Tests for User Story 1 ⚠️ write first, watch them fail

- [X] T017 [P] [US1] Write the widget lock in `test/ui/analisis/pantalla_analisis_test.dart`: the coach's `Análisis` lists his swimmers and is no longer a "todavía no" placeholder
- [X] T018 [P] [US1] Write the widget lock in `test/ui/analisis/lectura_de_un_nadador_test.dart`: her sessions appear newest first, each with her answer beside it, and a session she marked not done reads as **not done** rather than as missing (spec US1 scenario 2)
- [X] T019 [P] [US1] Write the widget lock in `test/ui/analisis/sin_respuestas_se_dice_test.dart`: a swimmer who has answered nothing produces a sentence, not an empty frame (FR-007)
- [X] T020 [P] [US1] Write the widget lock in `test/ui/analisis/un_fallo_se_dice_test.dart`: when the read fails the screen says it could not be read, and does not show a partial reading as complete (FR-008)
- [X] T021 [P] [US1] Write the rules lock in `firebase/test/reglas_analisis.test.js`: the coach reads a swimmer's records; a swimmer cannot read another swimmer's. **Each denial needs its positive counterpart in the same file** — feature 008's suite went 18 of 24 green against a collection with no rule because deny-by-default passes every negation
- [X] T022 [US1] Write the boundary statement in `firebase/test/reglas_analisis.test.js`, required by FR-025: a **second** coach account reads the first coach's swimmer and **succeeds**. Assert the success and say in the test's own text why — there is no coach→swimmer link, the product has one coach, and this test is what must change first when that stops being true (research D1)
- [X] T023 [US1] Verify the negative control for T021: point the suite at a collection name with no rule and confirm the positives go red. Record the numbers in a comment, as `reglas_macrociclos.test.js` does

### Implementation for User Story 1

- [X] T024 [US1] Replace the coach's `TodaviaNo(feature: '010')` with the new content in `lib/dominio/hub/destino.dart`, and add the content value it returns
- [X] T025 [US1] Build `lib/ui/analisis/pantalla_analisis.dart`: his swimmers, each reachable
- [X] T026 [US1] Build `lib/ui/analisis/lectura_de_un_nadador.dart`: her sessions newest first with her answers beside them
- [X] T027 [US1] Wire both into `lib/ui/hub/contenidos.dart` and `lib/ui/hub/hub.dart`, passing the coach's reader from T015
- [X] T028 [US1] Add the methodology stamp to every reading shown in `lib/ui/analisis/lectura_de_un_nadador.dart`, per FR-004, reading `versionMetodologia` off the plan rather than a constant
- [X] T029 [US1] Check the new screens at 130% and 200% text size by adding them to the feature 005 bench in `test/ui/tema/tamano_de_letra_test.dart`. `CabeceraSeccion` lost a `Flexible` for four features before feature 009 found it
- [ ] T030 [US1] Walk C1 and C2 of [quickstart.md](./quickstart.md) on the Pixel 7, checking the records in the emulator rather than on the screen

**Checkpoint**: the coach reads what his swimmers answered. The constitution's "un registro que
nadie lee no es control" is satisfied, and the feature could ship here.

---

## Phase 4: User Story 2 — Discomfort stands apart (Priority: P1)

**Goal**: a pain report is visible without going looking for it, and the app proposes nothing
about it.

**Independent Test**: a swimmer reports discomfort; the coach can tell which swimmer it was
without opening any of them, and what he reads suggests nothing.

### Tests for User Story 2 ⚠️ write first, watch them fail

- [X] T031 [P] [US2] Write the lock in `test/ui/analisis/la_molestia_va_aparte_test.dart`: a session carrying a discomfort report is distinguishable from one carrying only observations **before** it is expanded (FR-009)
- [X] T032 [P] [US2] Write the lock in `test/ui/analisis/quien_reporto_molestia_test.dart`: with ten swimmers and one reporting discomfort, the list identifies her without any being opened (FR-010, SC-004)
- [X] T033 [P] [US2] Write the lock in `test/ui/analisis/la_app_no_opina_de_la_molestia_test.dart`: the discomfort view contains no severity, no score, no suggested action and no control that changes a plan (FR-011). Assert over the rendered text and over the source of the widget

### Implementation for User Story 2

- [X] T034 [US2] Compute `conMolestia` in `lib/dominio/analisis/lectura_del_nadador.dart` from `RegistroDeSesion.tieneMolestia`, which already exists
- [X] T035 [US2] Mark swimmers with discomfort in `lib/ui/analisis/pantalla_analisis.dart`, using the informative tone of feature 005 and not an error tone — a report is information, not a failure
- [X] T036 [US2] Mark the session in `lib/ui/analisis/lectura_de_un_nadador.dart` and show what she wrote, verbatim
- [X] T037 [US2] Confirm no suggestion leaks into `lib/ui/analisis/pantalla_analisis.dart` or `lib/ui/analisis/lectura_de_un_nadador.dart`: re-read both against FR-011 and the constitution's principle IV
- [ ] T038 [US2] Walk C3 of [quickstart.md](./quickstart.md) on the Pixel 7

**Checkpoint**: a pain report cannot be buried, and the app says nothing about what to do with it.

---

## Phase 5: User Story 3 — The two loads side by side, never merged (Priority: P2)

**Goal**: what was programmed and what she answered, both named, with nothing derived from the
pair.

**Independent Test**: open one session and confirm both readings are present and no third number
exists.

### Tests for User Story 3 ⚠️ write first, watch them fail

- [X] T039 [P] [US3] Write the lock in `test/ui/analisis/sesion_y_respuesta_test.dart`: a session with 2000 m programmed and an effort of 7 shows both, each named, and the widget renders no third figure derived from them (FR-012, FR-013)
- [X] T040 [P] [US3] Write the lock in `test/ui/analisis/la_adherencia_se_lee_como_adherencia_test.dart`: the figure is presented as adherence and never as a training-load score (spec US3 scenario 2)

### Implementation for User Story 3

- [X] T041 [US3] Build `lib/ui/analisis/sesion_y_respuesta.dart`: the programmed work and her answer as two labelled blocks

  **Built during US1**, not here. `lectura_de_un_nadador.dart` needs the
  session-and-answer pair rendered to show anything at all, so writing it twice
  would have been churn. What US3 adds is what US3 is actually about: the
  labels, and the lock that no third figure exists (T039, T040).
- [X] T042 [US3] Use it from `lib/ui/analisis/lectura_de_un_nadador.dart`
- [X] T043 [US3] Show adherence from `progreso`, labelled, in `lib/ui/analisis/lectura_de_un_nadador.dart`
- [ ] T044 [US3] Walk C4 of [quickstart.md](./quickstart.md) on the Pixel 7, scanning for any derived number

**Checkpoint**: principle VIII's separation holds in the type and on the screen.

---

## Phase 6: User Story 4 — The swimmer asks for feedback (Priority: P3)

**Goal**: she asks about one session she already swam; he finds it where he already reads, and
marks it seen.

**Independent Test**: ask as her, find it as him, mark it seen, and see as her that he looked.

### The entity and its invariants ⚠️ write first, watch them fail

- [X] T045 [P] [US4] Write the lock in `test/dominio/analisis/peticion_de_feedback_test.dart`: a blank `pregunta` is refused — "Required, non-empty after trimming"; `vistaEn` once set cannot be unset; a non-null `video` is refused in this feature
- [X] T046 [US4] Create `PeticionDeFeedback` in `lib/dominio/analisis/peticion_de_feedback.dart` with `id` (deterministic, `nadadorId|planId|sesionId`), `nadadorId`, `planId`, `sesionId`, `pregunta`, `pedidaEn`, `vistaEn` (nullable) and `video` (nullable, always null here), per data-model.md
- [X] T047 [US4] Create `ReferenciaDeVideo` in `lib/dominio/analisis/peticion_de_feedback.dart` with `ruta` and `subidoEn`, defined and serialised so a later feature needs no re-consent, and refused by the constructor today (research D2)
- [X] T048 [US4] Add `peticion` to `RespuestaASesion` in `lib/dominio/analisis/respuesta_a_sesion.dart`, deferred from T006

### The repository, both implementations ⚠️ write first

- [X] T049 [P] [US4] Write the contract lock in `test/datos/la_peticion_se_guarda_igual_test.dart`, running **the same battery over both implementations** — memory and a Firestore-shaped double — as `el_plan_se_guarda_con_sus_sesiones_test.dart` does. Six of feature 009's seven defects were a double kinder than the server
- [X] T050 [US4] Add `RepositorioPeticionesDeFeedback` to `lib/dominio/repositorios/repositorios.dart` with `deNadador`, `deNadadorEnPlan`, `guardar` and `marcarVista`, per contract §1
- [X] T051 [US4] Implement `RepositorioPeticionesDeFeedbackMemoria` in `lib/datos/memoria/repositorios_memoria.dart`, refusing a blank question, a non-null video, and a `marcarVista` that touches anything else — **the double refuses what Firestore refuses**
- [X] T052 [US4] Implement `PeticionesFeedbackFirestore` in `lib/datos/firestore/peticiones_feedback_firestore.dart`. `deNadadorEnPlan` filters on **both** `nadadorId` and `planId`: a query is proven by its filters, which is the defect feature 009 shipped as `75a765f`
- [X] T053 [US4] Add the request to `lib/datos/serializacion.dart`, with `video` absent rather than null when empty
- [X] T054 [US4] Write the source-level lock in `test/datos/firestore/la_peticion_filtra_por_los_dos_test.dart`: `deNadadorEnPlan` contains both `where` clauses. `cloud_firestore` cannot run under `flutter test`, so the property is fixed over the source, as `el_plan_firestore_guarda_sus_sesiones_test.dart` does

### The rules ⚠️ write first

- [X] T055 [P] [US4] Write `firebase/test/reglas_peticiones_feedback.test.js` covering the table in contract §3: she creates her own with consent current; she cannot create one for another swimmer; she reads hers and not another's; she queries filtering by **both** swimmer and plan, and by plan alone is refused; the coach reads hers and cannot write her question; he sets `vistaEn`; setting `vistaEn` **and** `pregunta` together is refused; with consent revoked she cannot create; a request carrying `video` is refused; nobody deletes one
- [X] T056 [US4] Add `tieneConsentimientoDeAlcance(nadadorId, alcance)` to `firebase/firestore.rules`: current **and** scoped, reading `alcances` off the consent document. Asking only `vigente` would let a family who agreed to training data authorise video they never agreed to (research D2)
- [X] T057 [US4] Add the `peticionesDeFeedback` block to `firebase/firestore.rules` per contract §3, with the update restricted to `hasOnly(['vistaEn'])` — the shape feature 009 used for delivering a plan
- [X] T058 [US4] Verify the negative control for T055: in `firebase/test/reglas_peticiones_feedback.test.js` point `COLECCION` at a name with no rule and confirm every `assertSucceeds` goes red. Record the counts in a comment
- [X] T059 [US4] Add the indexes `deNadadorEnPlan` needs to `firebase/firestore.indexes.json`, if the emulator asks for them

  **No asked for.** `deNadadorEnPlan` is two equality filters, which Firestore
  serves by merging single-field indexes; the emulator ran the whole suite
  without a single index hint. `firestore.indexes.json` stays empty, as it is
  for the `registros` query that filters on the same two fields.

### Asking, and seeing that he looked ⚠️ write first

- [X] T060 [P] [US4] Write the lock in `test/ui/nadador/pedir_feedback_test.dart`: asking is offered on a session already swum and **not offered at all** on one whose day has not arrived — not offered and disabled, which feature 007 forbade as a lure (FR-015, H12)
- [X] T061 [P] [US4] Write the lock in `test/ui/nadador/pedir_feedback_sin_red_test.dart`: with no network the request is accepted and queued, and `guardar` never touches the server (FR-016, G1)
- [X] T062 [P] [US4] Write the lock in `test/ui/nadador/el_entrenador_lo_vio_test.dart`: once `vistaEn` is set she can tell he saw it, with no written answer existing (FR-019, SC-008)
- [X] T063 [US4] Add asking to `lib/ui/nadador/mi_progreso.dart`, routed through the outbox exactly as a record is
- [X] T064 [US4] Show "he saw it" in `lib/ui/nadador/mi_progreso.dart`, from `vistaEn`
- [X] T065 [US4] Show pending requests on the session in `lib/ui/analisis/lectura_de_un_nadador.dart`, and the control to mark one seen (FR-017)
- [X] T066 [US4] Confirm the interface mentions video nowhere, in either role, per FR-023. Grep `lib/ui/analisis/` and `lib/ui/nadador/mi_progreso.dart` for the word and expect nothing
- [X] T067 [US4] Wire the repository into `lib/ui/hub/repositorios_del_hub.dart` and `lib/ui/hub/hub.dart`
- [ ] T068 [US4] Walk C6, C7, C8 and C9 of [quickstart.md](./quickstart.md) on the Pixel 7, checking `vistaEn` and `pregunta` in the emulator — if marking seen changed her question, the update rule is not doing its job

**Checkpoint**: all four stories work, each demonstrable on its own.

---

## Phase 7: Polish & Cross-Cutting

- [ ] T069 Walk C5 of [quickstart.md](./quickstart.md): an answer survives a readjustment on the coach's side. Feature 009 found this twice on the swimmer's side; confirm rather than assume that his side is simpler
- [X] T070 Walk C10 of [quickstart.md](./quickstart.md): the server boundaries, as rules tests
- [ ] T071 [P] Mark feature 010 on the roadmap in `docs/ROADMAP.md` once the PR merges
- [X] T072 [P] Record in `docs/ROADMAP.md` that the coach→swimmer link is still missing and which feature should close it, the way feature 003's identity gap was recorded until 004 closed it
- [X] T073 Run the four gates and write the numbers in `specs/010-analysis-and-feedback/tasks.md` next to T001's baseline. The difference is the locks this feature needed

**After, 2026-11-11, with the four phases of code built (the Pixel 7 walk is
still pending):**

| Gate | Before | After | Added |
|---|---|---|---|
| `flutter analyze` | No issues | No issues | — |
| `flutter test` | 1963 | 2080 | **+117** |
| `npm --prefix firebase test` | 146 | 174 | **+28** |
| `npm --prefix firebase/functions test` | 45 | 45 | — |

145 tests added. Two negative controls were run and their numbers are recorded in
the suites themselves: against a collection with no rule, `reglas_analisis` went
5 of 10 and `reglas_peticiones_feedback` 12 of 18, and in both cases every single
failure was an `assertSucceeds`. That sentence is worth more than the 28 tests.

The functions suite is unchanged on purpose: this feature adds no server
function. The consent scope it needed was already written by feature 004 and the
gate went into the rules, where it can be proven without deploying anything.
- [ ] T074 Close the deferred manual checks this feature was blocking — C1 and C2 of `specs/003-consumo-del-nadador/quickstart.md`, T088 and T089 of `specs/004-cuentas-y-consentimiento/tasks.md` — on a real device, per SC-010, and tick them there
- [X] T075 Confirm no name, mark or identifier reaches logs or analytics from `lib/dominio/analisis/`, `lib/datos/firestore/peticiones_feedback_firestore.dart` and `lib/ui/analisis/` (FR-029), by reading them rather than by trusting the absence
- [X] T076 Re-read the Constitution Check table in [plan.md](./plan.md) against what was actually built, and correct it if anything drifted. A gate that is only true at planning time is not a gate

---

## Dependencies & Execution Order

### Phase dependencies

- **Setup (1)**: nothing
- **Foundational (2)**: after Setup — **blocks every story**
- **US1 (3)**: after Foundational
- **US2 (4)**: after Foundational. Reads the same reading as US1 but renders a different part of
  it, so it can be built in parallel with US1 by a second person
- **US3 (5)**: after Foundational. Touches `lectura_de_un_nadador.dart`, which US1 also touches —
  **not** parallel with US1 for one person; sequence it after
- **US4 (6)**: after Foundational. The only story that is genuinely independent: its own entity,
  its own repository, its own rules, its own screens
- **Polish (7)**: after the stories that are wanted

### Within a story

- Locks first, red first, negative control where one is possible
- Domain before data, data before UI
- The Pixel 7 walk last, and it is part of done — not a nicety. Feature 009's walk found seven
  defects in eight days and not one was reachable from a Dart test

### Parallel opportunities

- T002 and T003 together
- T017 to T021 together: five different test files
- T031 to T033 together
- T039 and T040 together
- T045, T049, T055, T060, T061, T062 together: entity, repository, rules and three screens, all
  different files
- **US1+US2 and US4 can run in parallel with two people.** US3 shares a file with US1 and should
  follow it

---

## Parallel Example: User Story 4

```bash
# The four locks that touch nothing of each other:
Task: "Entity invariants in test/dominio/analisis/peticion_de_feedback_test.dart"
Task: "Repository contract in test/datos/la_peticion_se_guarda_igual_test.dart"
Task: "Server rules in firebase/test/reglas_peticiones_feedback.test.js"
Task: "Asking offline in test/ui/nadador/pedir_feedback_sin_red_test.dart"
```

---

## Implementation Strategy

### MVP: User Story 1 alone

1. Phase 1 — Setup
2. Phase 2 — Foundational
3. Phase 3 — US1
4. **Stop and walk C1 and C2 on the phone**
5. The coach reads what his swimmers answered. The constitution's missing step is no longer
   missing, and the feature is worth shipping here

### Incremental

1. Setup + Foundational → the reading exists
2. **US1 → MVP**, the control step closed
3. US2 → a pain report can no longer be buried
4. US3 → the two loads side by side on screen as well as in the type
5. US4 → she can ask, and know he looked

### What to resist

- **Building the coach→swimmer link** because FR-024 feels wrong. It is a feature; this one
  declares the gap and tests it (research D1)
- **Making video work** because the field is there. The field and the gate are the whole scope;
  the interface says nothing (research D2, FR-023)
- **Adding a reply** because marking seen feels thin. That was Q2, answered: he replies at the
  poolside

---

## Notes

- `[P]` means different files and no unfinished dependency
- Verify each lock fails before writing the thing it guards
- Where a negative control is possible, do it and record what it showed. `reglas_macrociclos.test.js`
  carries "13 of 20 passed against a collection with no rule" in a comment, and that sentence is
  worth more than the twenty tests
- Commit per task or per coherent group
- The in-memory double refuses what Firestore refuses. This is the lesson this project keeps
  paying for

---

## Found by the walk, outside this feature

### The swimmer's Home shows an arbitrary mesocycle of her macrocycle

**Found**: 2026-11-11, Pixel 7, walking C1 as Ana.

**What she sees**: "Hoy no hay sesión" on a day her plan has a session, and
"Sesiones cumplidas: 0 de 6" over a macrocycle of 39.

**Why**: the HUB picks the swimmer's plan as *the last of her published
assignments* — `planDe` in `lib/ui/nadador/perfil_activo.dart:157`, and the same
rule inline in `lib/ui/hub/hub.dart:230`. Before feature 009 that meant "the plan
she was given". Since macrocycles exist, **each mesocycle is an assigned plan**,
so "the last" is whichever the query returns last:

```
6ltkjcKAYMBV2al8Unug | Mesociclo 1: Acumulación    | 21 sessions
INoiEbjccJDmA7TQjhGc | Mesociclo 2: Transformación | 12 sessions
p-publicado          | Microciclo de base aeróbica |  3 sessions
rMv6QpTh04y8GUtKZ0og | Mesociclo 3: Realización    |  6 sessions  ← wins
```

Mesocycle 3 starts 3/2/2027, which is exactly why her Home says there is no
session today and counts out of 6. **Which one wins depends on Firestore's
document-id ordering**, so it is not merely the wrong plan — it is arbitrary.

**Not a defect of this feature.** `Análisis` reads the macrocycle and its
lineage; `Ver Plan` reads the macrocycle whole and is correct. It was born in
feature 007, made wrong by feature 009, and found by feature 010's walk.

**The fix already exists, written and unconnected**:
`ProgresoEnElMacrociclo.mesocicloActual` returns the mesocycle containing today
and is deliberately null before, after and in a gap. Connecting it is the same
shape as feature 009 connecting `registrosDelLinaje` — something built, tested
and never called.

Recorded here by the coach's decision rather than fixed inside 010, so this
feature closes on what its spec promised. It is the first thing to pick up next.
