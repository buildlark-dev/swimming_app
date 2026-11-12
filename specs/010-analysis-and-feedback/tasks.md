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
- [X] T030 [US1] Walk C1 and C2 of [quickstart.md](./quickstart.md) on the Pixel 7, checking the records in the emulator rather than on the screen

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
- [X] T038 [US2] Walk C3 of [quickstart.md](./quickstart.md) on the Pixel 7

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
- [X] T044 [US3] Walk C4 of [quickstart.md](./quickstart.md) on the Pixel 7, scanning for any derived number

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
- [X] T068 [US4] Walk C6, C7, C8 and C9 of [quickstart.md](./quickstart.md) on the Pixel 7, checking `vistaEn` and `pregunta` in the emulator — if marking seen changed her question, the update rule is not doing its job

  **C8's second half is pending**: that she can tell he saw it, on her side of
  the phone. The coach's half is walked and checked in the emulator; hers is
  covered by `el_entrenador_lo_vio_test.dart` and by the merge rule that takes
  `vistaEn` from the server, and needs one more sign-in to see on the device.

**Checkpoint**: all four stories work, each demonstrable on its own.

---

## Phase 7: Polish & Cross-Cutting

- [X] T069 Walk C5 of [quickstart.md](./quickstart.md): an answer survives a readjustment on the coach's side. Feature 009 found this twice on the swimmer's side; confirm rather than assume that his side is simpler

  **Walked, and his side is simpler.** Block 1 was readjusted and delivered on
  the Pixel 7's emulators: a new published plan `UJvobHiAWLpx840dG8W5` with
  `versionAnteriorId` pointing at `o7N0NyD1TDI3enPrgwDD`, and the macrocycle now
  listing the new id. Her reading, reopened: adherence still 2 of 39, and both
  answers still beside the sessions she swam — 09/11 "La hizo · esfuerzo
  percibido 7 de 10 / Me costo arrancar, despues fue bien" and 12/11 with RPE 8.
  Her question and its seen mark came through the readjustment too.

  What covered it meanwhile, and still does:
  `el_linaje_tambien_para_el_entrenador_test` fixes that an answer written
  against a replaced version is still found and still counted, with its negative
  control run — swapping `registrosDelLinaje` for a direct read turns two of its
  three cases red. The walk added the half a Dart test cannot reach: that the
  readjustment's real write, with the real rules, leaves the old version's
  records readable.
- [X] T070 Walk C10 of [quickstart.md](./quickstart.md): the server boundaries, as rules tests
- [ ] T071 [P] Mark feature 010 on the roadmap in `docs/ROADMAP.md` once the PR merges
- [X] T072 [P] Record in `docs/ROADMAP.md` that the coach→swimmer link is still missing and which feature should close it, the way feature 003's identity gap was recorded until 004 closed it
- [X] T073 Run the four gates and write the numbers in `specs/010-analysis-and-feedback/tasks.md` next to T001's baseline. The difference is the locks this feature needed

**After, 2026-11-12, with the code built and the walk run:**

| Gate | Before | After | Added |
|---|---|---|---|
| `flutter analyze` | No issues | No issues | — |
| `flutter test` | 1963 | 2133 | **+170** |
| `npm --prefix firebase test` | 146 | 174 | **+28** |
| `npm --prefix firebase/functions test` | 45 | 45 | — |

198 tests added. 53 of them are the walk: the locks the eight defects the two
walks found needed, each written before its fix, each with its negative control
run. The rules suites carry their own, and their numbers are recorded in
them: against a collection with no rule, `reglas_analisis` went 5 of 10 and
`reglas_peticiones_feedback` 12 of 18, and in both cases every single failure
was an `assertSucceeds`. That sentence is worth more than the 28 tests.

The functions suite is unchanged on purpose: this feature adds no server
function. The consent scope it needed was already written by feature 004 and the
gate went into the rules, where it can be proven without deploying anything.
- [X] T074 Close the deferred manual checks this feature was blocking — C1 and C2 of `specs/003-consumo-del-nadador/quickstart.md`, T088 and T089 of `specs/004-cuentas-y-consentimiento/tasks.md` — on a real device, per SC-010, and tick them there

  **C1 of feature 003 is closed, and it was failing.** Airplane mode, app closed
  and reopened: `Ver Plan` spun forever. The fix and its locks are in
  `fix(003): what hangs on the network now has a deadline`. After it: today's
  session with its technical and physiological objectives and the three parts —
  800 initial, 1000 central, 200 final — in about five seconds.

  **C2 is closed through step 4 and open at 5 and 6.** Marking offline returns
  at once, the record is kept, and the FR-017 sentence is there, byte for byte,
  in her `Análisis`, surviving a cold restart. What does not happen is the rest
  of step 5: "restore the network and wait without touching anything". The
  record does arrive and the notice does go — but only when the app is next
  opened, which is the contract's third trigger, not its second.

  The second trigger was never wired. `Sincronizador.alVolverLaRed` exists and
  is tested, and **nothing in `lib/` listens to it**; and it could not fire
  anyway, because `main.dart` passes `sondear: () async => datos != null`, which
  asks "did Firestore initialise?" and is true with the airplane on. The stream
  only emits on a change, so the value never changes and the event never comes.

  Fixing it is a change of its own with a decision inside it — what to probe,
  how often, and what that costs — so it is recorded here rather than bolted on.
  `estado_de_red.dart` already says what the probe should be: "a write is
  attempted and one sees whether it arrives". That is now possible, because the
  send has a deadline.

  **T089 of feature 004 stays open**: siblings on one phone, and a session that
  expires poolside. It needs two swimmer accounts with consent and a forced
  expiry, which is its own setup, and its own spec says a desktop browser does
  not count.

  Two more things the walk saw, neither fixed here:

  - `Mi progreso` says **"Todavía no tienes un plan asignado"** for the twenty
    seconds its plan takes to load offline. It is an empty state shown before
    the data has had its chance, and what it says is false while it says it.
  - The notice can outlive the send. Firestore's own queue delivers the write
    when the signal returns, so the server has the record while the outbox still
    counts it pending — our deadline abandoned the Future that would have
    confirmed it. Nothing is lost or duplicated, the id is deterministic, but
    the sentence stays on screen after it has stopped being true.
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

**Recorded first, then fixed** — because it turned out to block this feature's
own walk. Her `Análisis` is driven by the same choice, and that is where 010
puts "ask your coach": with a February mesocycle selected she had no session to
ask about, so C6, C7 and C8 could not be walked at all. The coach changed the
decision once that was clear.

Fixed in `lib/dominio/calculo/el_plan_de_ahora.dart`, shared by both places that
chose "the last": `planDe`, which the coach uses to open the app as one of his
swimmers, and the swimmer's own path through the hub.

### "Te quedó una sesión por marcar" about a session she marked

**Found**: 2026-11-11, Pixel 7, walking C1 as Ana.

**What she sees**: she marks the 9/11 session as *"No pude hacerla"*, the record
reaches Firestore with `realizada: false`, and the notice still says **"Te quedó
una sesión por marcar — La del 9/11"**. The app is telling her to do something
she just did.

**Why**: `ProgresoEnElMacrociclo.pendientes` excludes only `hechas`. A session
she answered with "I did not do it" lands in `dijoQueNo`, not in `hechas`, so it
stays on the pending list.

**And the class forbids exactly this, in its own words.** The doc on `dijoQueNo`
says: *"No es lo mismo que no haber contestado… «No la hice» es un dato: el
nadador estuvo ahí y dijo lo que pasó. «No contestó» es la ausencia de un dato…
Mezclarlas le enseñaría al entrenador un hueco donde hay una respuesta, o una
respuesta donde hay un hueco."* `sinContestar` keeps the two apart correctly;
`pendientes` does not, and `pendientes` is what the swimmer reads.

**Not a defect of this feature**: `ProgresoEnElMacrociclo` is feature 009's, and
the `Análisis` reads `adherencia`, which counts `hechas` and is right.

**Recorded and not fixed**, and unlike the Home finding above this one stayed
recorded: it blocks nothing here. The fix is one condition, but it changes a
tested behaviour of feature 009, so it belongs with that feature rather than
inside this one.

---

## The walk, as it went

Pixel 7 against the emulators, 2026-11-11 and 12. **Five defects before C1 was
through, and not one of them was reachable from a Dart test.** Three were this
feature's and are fixed; two belonged to earlier features and one of those was
fixed because it blocked this walk.

| | What it looked like | Where it was |
|---|---|---|
| 1 | The list said she reported a discomfort; opening her said she had no macrocycle and showed nothing | 010 — the reading went through the macrocycle only |
| 2 | Her discomfort vanished from the reading while the list kept marking her | 010 — an answer whose session is not in the plan was dropped in silence (and a typo in the seed) |
| 3 | She marks a session, it reaches Firestore with her effort, and her screen still says "0 de 39" | 010 — **every record that had reached the server was unreadable**, and the exception escaped the read |
| 4 | Her Home and her `Análisis` showed a mesocycle from February | 007/009 — "the last assigned plan" stopped meaning "her plan" when 009 made every mesocycle one. Fixed: it blocked C6, C7 and C8 |
| 5 | She asks with no signal and the screen says nothing | 010 — **asking waited on the network**: Firestore accepts the write and leaves the Future open, and my double threw where the real thing hangs |

Defect 3 is the one worth remembering: the coach's `Análisis` reads through the
same repository, so it would have broken **the moment any swimmer answered
anything for real**. It worked during the walk only because seeded records carry
no `recibidoEn`.

Defect 5 taught the old lesson one turn further. This project knew the double
must refuse what the server refuses. It must also **return where the server
would hang**: a double that throws is kinder than one that never answers.


### And then feature 003's own walk, which found three more

C1 and C2 were deferred since feature 003 for want of a device. Walking them
here found three defects, all the same shape as defect 5 above and all of them
the shape this project keeps meeting: **the Firestore SDK does not throw when
there is no network, it leaves the Future open.**

| | What it looked like | Where it was |
|---|---|---|
| 6 | Airplane mode, app reopened: `Ver Plan` spins forever. No error, no content, no session — with the cache on the device and persistence on | 003/009 — every read was unbounded. A `catch` cannot catch a Future that never completes |
| 7 | She marks the session and the button spins **for ever**, with the record already saved and no way for her to know it | 003 — the outbox's send was unbounded, and the screen waited on it |
| 8 | Two syncs at once send the same record twice | 003 — both read the queue before either marks "sending". It only became reachable once the screen stopped waiting |

Defect 6 needed two fixes, not one. The deadline alone left `Ver Plan` loading
in twenty-odd seconds, because it chains macrocycle → plan → sessions and each
read paid its own five. Correct and useless. A short memory of a server that
did not answer takes the second and third reads straight to the cache.

And defect 7 explains why nothing ever retried: the outbox asks
`red.hayConexion()` before sending, and the probe behind it was
`() async => datos != null` — "did Firestore initialise?", which is true with
the airplane on. So it always tried, and always hung. Now that the send has a
deadline, the probe `estado_de_red.dart` always described — "a write is
attempted and one sees whether it arrives" — is finally possible.

The walk's own lesson, a third time: **a double that throws is kinder than the
server it stands for.** One of the new locks had to be fixed before it was a
lock at all — its negative control showed it asked `obtener` for an id the
device already had, so it returned early and never reached the server.

### What each check showed

- **C1** — he reads her answers from his own device, with the records written on
  hers. Adherence 1 of 39, labelled; methodology 3.6.0 off the plan.
- **C2** — a swimmer with nothing delivered gets a sentence and a next step.
- **C3** — only she is marked on the list, the mark does not reorder it, and
  inside, the discomfort is apart, in the `cuidado` tone, with her words
  verbatim. Nothing proposes anything.
- **C4** — "2000 m · 50% técnico · RPE previsto 2" and "La hizo · esfuerzo
  percibido 7 de 10", each named, and no third figure anywhere on the screen.
- **C5** — block 1 readjusted and delivered, then her reading reopened:
  adherence still 2 of 39 and both answers still beside the sessions she swam,
  under a plan id that no longer exists in the macrocycle. His side is simpler,
  as hoped, and now confirmed rather than assumed.
- **C6** — asked with airplane mode on. "Guardada. Se la mandaremos cuando
  tengas internet.", and it reached the server when the signal came back, under
  the deterministic id, with `video` **absent** rather than null.
- **C7** — the boundary is visible: 18/11 and later offer nothing, 09/11 and
  06/11 offer it. Not offered and disabled — not offered at all.
- **C8** — he marks it seen; in the emulator `vistaEn` is set and `pregunta` is
  byte-for-byte hers, with no key added to the document. And **her half**: on
  the session she asked about, "Tu entrenador la vio", in green, with no written
  answer arriving. That is the whole of what Q2 promised.
- **C9** — walked as both roles. Video is not named anywhere, and a test over
  every file in `lib/ui` keeps it that way.
- **C10** — 28 rules tests with their negative controls, in
  `reglas_peticiones_feedback.test.js` and `reglas_analisis.test.js`.

---

## Deployed

2026-11-12, to `swimming-app-ab45f`, from this branch before merging — the same
order feature 009 used.

1. **Rules and indexes first**, so `peticionesDeFeedback` and the scoped-consent
   helper are standing before any client that uses them arrives.
2. **Functions**: ten updated, none added. This feature adds no server function;
   the consent scope it needed was already written by feature 004 and the gate
   went into the rules, where it can be proven without deploying anything.
3. **Hosting**, from a release web build with no `--dart-define`, since
   `USAR_EMULADORES` is false by default.

Checked on what is **served**, not on what was built: `/`, `/main.dart.js` and
`/version.json` all 200, the bundle names `swimming-app-ab45f`, and it contains
no `demo-natacion` and no `10.0.2.2`. That last check exists because an APK
built without the flag once talked to the real project and signing in failed
with "El correo o la contraseña no coinciden" — the mirror of the same mistake.
