---

description: "Task list for feature 009 — Ver Plan and progression"
---

# Tasks: Ver Plan and progression

**Input**: design documents from `specs/009-plan-progression/`

**Prerequisites**: [plan.md](./plan.md), [spec.md](./spec.md), [research.md](./research.md),
[data-model.md](./data-model.md), [contracts/macrociclo_y_progresion.md](./contracts/macrociclo_y_progresion.md),
[quickstart.md](./quickstart.md)

**Tests**: included, and not as an option. Principle III of the constitution is
NON-NEGOTIABLE for rules that reach a swimmer, and it asks for two things this list obeys
literally: **the lock is written before the thing it guards**, and **each lock is verified
with a negative control** — break what it protects, watch it go red, restore it. Feature 008
found three tests that passed for the wrong reason, every one of them because a fake was more
convenient than the real collaborator.

**Organization**: by user story. US1, US2 and US3 are all P1; US4 is P2.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: can run in parallel (different files, no dependency on an unfinished task)
- **[Story]**: US1 to US4, mapped to the user stories in `spec.md`
- Guarantee ids `M1…M35` cite `contracts/macrociclo_y_progresion.md`; `C1…C13` cite
  `quickstart.md`; `D1…D10` cite `research.md`

## Path conventions

Flutter project at the repository root. `lib/dominio` is pure Dart (principle II, enforced by
`test/dominio/arquitectura_test.dart`), `lib/datos` is the only place that may know about
Firebase, `lib/ui` is the screens. Rules and their tests live under `firebase/`.

---

## What this feature already knows will go wrong

Three things, written here because a task list is where they get acted on rather than admired.

1. **M10 — nothing exists before the confirmation.** True today only because nothing is built
   yet. The lock looks at the **repositories**, not at the screen (T027).
2. **M34 — a readjustment can orphan the swimmer's records.** Not a risk: a **defect that is
   already in the code**. `RepositorioPlanesFirestore.crearVersionDesde` copies every session
   with `copiarCon(id: null)`, and records are keyed by `sesionId`. Versioning a mesocycle
   today would blank a swimmer's history with nothing failing (T068, T069).
3. **M12 — determinism** is verified by deriving **twice and comparing**, never against a
   stored fixture, which would hide an input read from the clock (T029).

---

## Phase 1: Setup

**Purpose**: a baseline, and the one sentence of vocabulary that decision D1 costs.

- [X] T001 Run the four gates before touching anything and record the Dart test count in this
      file's Notes section: `flutter analyze`, `flutter test`, `npm --prefix firebase test`,
      `npm --prefix firebase/functions test`. A red test later is then this feature's, not a
      mystery.
- [X] T002 [P] Write decision D1 into the library doc comment of
      `lib/dominio/entidades/plan.dart`: a `Plan` with one `faseAtr` and several `microciclos`
      **is** a mesocycle, `Macrociclo` is the level above it, and that is why FR-031 lands on
      a type that already has a lifecycle, an audit and a version lineage. Without this the
      next feature rediscovers it.
- [X] T003 [P] Add `const String coleccionMacrociclos = 'macrociclos';` beside the existing
      collection constants in `lib/datos/firestore/repositorios_firestore.dart` (lines 20-22).

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: the new entity, the two new `Plan` fields, their storage and their access rules.

**⚠️ CRITICAL**: no user story work begins until this phase is complete — all four need the
`Macrociclo` type and its repository.

- [X] T004 Write the invariant tests FIRST in `test/dominio/macrociclo/macrociclo_test.dart`,
      and watch them fail because the file they test does not exist: a `Macrociclo` with an
      empty `mesociclos` list is **not constructible** ("it would be a name with nothing in
      it"); its mesocycle ids are **unique and ordered** ("order is the preparation's order,
      not an accident of storage"); `estado == EstadoPlan.aprobado` is impossible while any
      referenced mesocycle is not `aprobado` (M14); an `EstructuraConfirmada` whose
      `modeloDeLaPrueba` or `modeloDelNadador` is empty after trimming is rejected; a
      `BloqueConfirmado` with `hasta` not after `desde` is rejected, and consecutive blocks
      "do not overlap and leave no gaps"; a `BloqueConfirmado` with an empty `porQue` is
      rejected.
- [X] T005 Create `lib/dominio/macrociclo/macrociclo.dart` with the three pure-Dart types, each
      field carrying its constraint from `data-model.md` verbatim in the doc comment:
      `Macrociclo` — `id` `String?` "Null until stored, like `Plan`"; `nadadorId` `String`
      "Required, non-empty. A macrocycle is for one swimmer (groups are out of scope)";
      `nombre` `String` "Required, non-empty"; `estructura` `EstructuraConfirmada` "Required";
      `mesociclos` `List<String>` "Plan ids, **in order**. At least one";
      `fechaDeCompetencia` `DateTime` "Required. The anchor the skeleton counts back from";
      `versionMetodologia` `String` "Required (FR-013)"; `estado` `EstadoPlan` reusing the
      existing `borrador → aprobado → publicado`. `EstructuraConfirmada` —
      `modeloDeLaPrueba` and `modeloDelNadador` `String` "Required, non-empty after
      trimming"; `bloques` `List<BloqueConfirmado>` "Required, at least one"; `confirmadaEn`
      `DateTime` "When he confirmed. The server's clock, not the device's".
      `BloqueConfirmado` — `fase` `FaseAtr?` "Null only for categories that do not use ATR";
      `desde`, `hasta` `DateTime` "`hasta` after `desde`"; `porQue` `String` "Always present,
      always readable".
- [X] T006 Negative control for T004, one invariant at a time: remove the guard, confirm the
      matching test goes red, restore it. Record in the test file's doc comment which four
      guards were checked this way. A green invariant test that was never seen red is a
      decoration.
- [X] T007 [P] Confirm `test/dominio/arquitectura_test.dart` already walks
      `lib/dominio/macrociclo/` for the Flutter and Firebase import ban; if it enumerates
      folders by name rather than walking, add the new one and say so in its doc comment.
- [X] T008 Add the two nullable fields to `Plan` in `lib/dominio/entidades/plan.dart` and to
      `copiarCon`: `macrocicloId` `String?` "Which macrocycle it belongs to. Null for a plan
      that stands alone — one from a feature 008 request, or written by hand", and
      `ordenEnElMacrociclo` `int?` "Its position. Null when it stands alone". Nothing else on
      `Plan` changes — that is the whole point of D1.
- [X] T009 Test in `test/dominio/entidades/plan_mesociclo_test.dart`: a draft built by
      `generarDesdePeticion` has `macrocicloId == null` and `ordenEnElMacrociclo == null`, and
      feature 008's locks still pass untouched (run
      `test/dominio/peticiones/nada_llega_al_nadador_test.dart` and
      `test/dominio/entidades/plan_inmutable_test.dart` in the same gate).
- [X] T010 Carry the two new fields through `planAJson` and `planDesdeJson` in
      `lib/datos/serializacion.dart`, with a round-trip test in
      `test/datos/serializacion_test.dart` that a plan with both set survives and one with
      both null comes back null rather than zero.
- [X] T011 Add `macrocicloAJson` and `macrocicloDesdeJson` to `lib/datos/serializacion.dart`,
      with a round-trip test covering a macrocycle with a block that has `fase == null`.
- [X] T012 Declare `RepositorioMacrociclos` in `lib/dominio/repositorios/repositorios.dart`:
      `obtener(String id)`, `deNadador(String nadadorId)`, `guardarBorrador(Macrociclo)`
      returning the assigned id, `guardarAprobado(Macrociclo, Map<String, dynamic> auditoria)`,
      and `exportar(String id)`. No signature mentions a Firestore type (the file's own rule).
- [X] T013 [P] Implement `RepositorioMacrociclosMemoria` in
      `lib/datos/memoria/repositorios_memoria.dart`, **returning a snapshot and not the stored
      list instance** — feature 008 had a queue fake that handed back the same list and a test
      passed for it.
- [X] T014 [P] Implement `lib/datos/firestore/macrociclos_firestore.dart` against
      `coleccionMacrociclos`, following `RepositorioPlanesFirestore`'s shape.
- [X] T015 Add `match /macrociclos/{macrocicloId}` to `firebase/firestore.rules`: the coach
      creates, and only in `borrador`; the state only advances `borrador → aprobado →
      publicado` and never skips a step, reusing the existing `cambiaElEstado`,
      `esLaAprobacion` and `esLaEntrega` helpers; a swimmer **reads only their own** and writes
      nothing, ever; `allow delete` only for the coach and only on a draft.
- [X] T016 Rules tests in `firebase/test/reglas_macrociclos.test.js`, and **write the
      `assertSucceeds` cases as well as the denials**: the coach creating a draft, approving,
      delivering, and the owning swimmer reading a published one must all succeed. Feature 008
      shipped 18 of 24 green against a collection that had no rule at all, because
      default-deny makes every denial pass.
- [X] T017 Negative control for T016: point the suite at a collection name that has no rule and
      confirm the six `assertSucceeds` cases fail. Then point it back. This is the only way to
      know the suite is testing the rule and not the default.
- [X] T018 Wire `macrociclos` into `RepositoriosDelHub` in `lib/ui/hub/repositorios_del_hub.dart`
      and its `.de` factory — Firestore when there is a database, memory when there is not —
      and make it seedable from a test, like the others.

**Checkpoint**: the macrocycle exists, persists, and is reachable by exactly the people it
should be. User story work can begin.

---

## Phase 3: User Story 1 — The coach confirms the structure, once (Priority: P1) 🎯 MVP

**Goal**: one confirmation — the event model and the swimmer model, over an editable skeleton
the app proposes — and from it the whole hierarchy derives in one go.

**Independent Test**: with a coach account, start a macrocycle for a swimmer whose competition
is 14 weeks away, confirm, and check that a complete hierarchy comes back, that nothing was
stored before the confirmation, and that no second confirmation was asked between levels.

**Why this is the MVP**: it is the decision point the constitution protects. This is also the
feature that has to prove the v2.0.0 amendment was honest — if the single confirmation cannot
be pointed at, the amendment was used to skip a rule rather than restate it.

### Tests for User Story 1 — written first

- [X] T019 [US1] `test/dominio/macrociclo/esqueleto_propuesto_test.dart`, before the function
      exists: a competition 14 weeks out gives three blocks counted **backwards** —
      Realización last and ending at the competition, Transformación before it, Acumulación
      filling what remains; a competition 15 days out gives Realización only;
      `ultimoDiaDeRealizacion` and `ultimoDiaDeTransformacion` from
      `lib/dominio/peticiones/fase_por_fecha.dart` are the boundaries, tested on both sides of
      each; a category with `usaAtr == false` gives **one** block with `fase == null`; a
      competition today or in the past gives no skeleton and says why; every block's `porQue`
      is non-empty and reads like the data model's example, «Realización, las últimas 2 semanas
      antes de la competencia».
- [X] T020 [US1] Negative control for T019: shift one boundary by a day and confirm the
      boundary tests go red. Feature 008's phase derivation took two attempts to get its
      boundaries right; they were the part worth checking twice.
- [X] T021 [P] [US1] `test/dominio/macrociclo/esqueleto_avisa_test.dart`: a block outside
      `FaseAtr.semanasSegunIssurin` produces a warning **and the skeleton is still returned**
      (M5, FR-012). Section 12 says swimming uses longer phases than the general literature,
      so a four-week Realización warns and generates.
- [X] T022 [P] [US1] `test/dominio/macrociclo/falta_en_la_ficha_test.dart`: with a `Nadador`
      whose `faltas` is non-empty, the app returns what is missing and **no skeleton** (M7,
      rule R3). Deriving on gaps would put the coach's signature on a guess.
- [X] T023 [US1] `test/dominio/macrociclo/los_modelos_no_se_derivan_test.dart`: the event model
      and the swimmer model are never produced from `categoria`, `edad` or any other field.
      The test asserts the proposal function has no way to fill them — it does not return them
      at all (M4, FR-007, constitution v2.0.0).

### Implementation for User Story 1

- [X] T024 [US1] Implement `lib/dominio/macrociclo/esqueleto_propuesto.dart`: a **total**
      function of (`fechaDeCompetencia`, `hoy`, `categoria`) returning the proposed blocks with
      their reasons and any warnings, counting backwards from the competition using
      `FaseAtr.semanasSegunIssurin`. Same shape as `faseParaCompetencia`, and for the same
      reason: methodology decided without the coach present must carry its reason with it.
      Count **whole dates**, as `_diasEnteros` does, so the time of day cannot change a block.
- [X] T025 [US1] Pre-fill the models in the proposal's input only from the swimmer's own record
      — `diagnosticoTecnico`, `pruebaObjetivo`, `marcas` — **and from nothing else** (M4,
      FR-008). Those are observations the coach already made; offering them back is showing him
      his own work.
- [X] T026 [US1] Build the structure confirmation: `EstructuraConfirmada` is assembled from
      what the coach typed and the skeleton as he left it, with `confirmadaEn` from the
      server's clock and not the device's (data model).
- [X] T027 [US1] **The storage lock, written before the screen that would break it.**
      `test/dominio/macrociclo/nada_se_guarda_antes_test.dart`: propose a skeleton, then assert
      the macrocycle, plan **and** session repositories are all empty — over the repositories,
      not over the screen. Feature 008 learned twice that a thing not being shown says nothing
      about whether it exists (M10, SC-010, D10).
- [X] T028 [US1] Negative control for T027: make the proposal save a draft, confirm the test
      goes red, revert. Written down in the test's doc comment, because this is the lock most
      likely to be broken later by a convenient preview.
- [X] T029 [US1] `test/dominio/macrociclo/derivacion_determinista_test.dart`: derive **twice**
      from the same structure and the same record and compare the two results field by field.
      **Never against a stored fixture** — a fixture would hide an input read from the clock,
      which is the trap feature 008 wrote down (M12, SC-003).
- [X] T030 [US1] Implement `lib/dominio/macrociclo/derivar_macrociclo.dart`: one
      `PeticionGeneracion` per microcycle through the feature 002 `Generador`, with
      `componenteParaFase` supplying the accentuated component so the engine's own coherence
      check passes **by construction**; group the results into mesocycle `Plan`s, each with one
      `faseAtr`, its `macrocicloId` and its `ordenEnElMacrociclo` (M8, M9, D4).
- [X] T031 [US1] Stamp `versionMetodologia` on the macrocycle and on every mesocycle from
      `CargadorVersionMetodologia` (`lib/datos/recursos/version_metodologia.dart`), with a test
      that no level is left with `versionDesconocida` when the manifest is present (M11,
      FR-011, SC-002).
- [X] T032 [US1] Test and implement: the derived macrocycle and every one of its mesocycles are
      born `EstadoPlan.borrador` (M13, FR-015), and no further confirmation is asked between
      levels (M8, FR-003, SC-001) — the test counts the confirmations the flow requires and
      expects exactly one.
- [X] T033 [US1] Test in `test/dominio/macrociclo/aprobar_el_macrociclo_test.dart` using
      `test/dominio/auditoria/ayuda_planes.dart`: a mesocycle that fails the section 16 audit
      blocks approval of the whole macrocycle, and the audit is **the same one** every other
      plan passes, not a lighter one (M13, M14).
- [X] T034 [US1] Implement approval as **one act** for the coach however many mesocycles there
      are (M15), driving the existing `CicloVidaPlan.aprobar` per mesocycle, with the macrocycle
      moving only once all of them did.
- [X] T035 [US1] Test: delivery is **all or nothing** (M16). A swimmer seeing four of seven
      mesocycles is worse than seeing none, so the test interrupts delivery midway and asserts
      the swimmer has nothing rather than part.
- [X] T036 [US1] Implement delivery — publish and assign each mesocycle in one act (D5) — and
      test that **signing is not delivering** (M17, FR-037): an approved macrocycle leaves the
      swimmer with nothing new.
- [X] T037 [US1] `lib/ui/macrociclo/estructura.dart`: the proposed skeleton, every part of it
      editable — number of blocks, their phases, their lengths — each block showing **why** it
      came out that way, and the two model fields for the coach to fill.
- [X] T038 [US1] `lib/ui/macrociclo/revisar_macrociclo.dart`: what he reviews before signing —
      the mesocycles, their phases, their dates, their methodology version, and the audit
      table that `lib/ui/planes/tabla_auditoria.dart` already renders.
- [X] T039 [US1] Widget test `test/ui/macrociclo/estructura_editable_test.dart`: change the
      number of blocks, then a phase, then a length, and all three take effect (M3, C2). If any
      part is fixed, the proposal is a decision.
- [X] T040 [US1] Widget test `test/ui/macrociclo/los_modelos_son_suyos_test.dart`: what the
      coach already wrote on the swimmer's record is offered back, and **nothing else is
      filled in** (M4, C3). If fatigue tolerance or motivation arrives pre-written, the app
      derived what the constitution reserves to him.
- [X] T041 [US1] Widget test: a block outside the published ranges shows its warning and the
      generate control **stays enabled** (M5, C7).
- [X] T042 [US1] Add `PantallaEstructura` and `PantallaRevisarMacrociclo` to the bench in
      `test/ui/tema/ayuda_pantallas.dart`, mounted with a realistic three-block skeleton — not
      an empty one. `test/ui/tema/pantallas_en_el_banco_test.dart` will fail until they are
      listed, and the feature 005 lesson is that a bench only measures the paths it mounts.
- [X] T043 [US1] Wire the entry point into `lib/ui/hub/planes_del_entrenador.dart`: start a
      macrocycle for a swimmer, from where his plans already are.

**Checkpoint**: a coach can produce, review, sign and deliver a whole macrocycle from one
confirmation. C1 to C8 of the quickstart are walkable.

---

## Phase 4: User Story 2 — The swimmer sees the whole path from day one (Priority: P1)

**Goal**: the delivered macrocycle arrives whole, folded, opening at today, and the swimmer is
told it may change according to how they respond.

**Independent Test**: seed a delivered macrocycle through the memory repositories and open
`Ver Plan` as the swimmer — no coach flow needed. Walk from today to the last week with
nothing hidden.

### Tests for User Story 2 — written first

- [X] T044 [US2] `test/dominio/macrociclo/progreso_en_el_macrociclo_test.dart`:
      `mesocicloActual` is the mesocycle whose dates contain today and null when none does;
      `hechas` holds the session ids with a record marked `realizada`; `pendientes` holds
      sessions dated before today and not marked, **in date order**; `proxima` is the first
      session dated today or later. And the one that matters: **nothing is written anywhere** —
      the test asserts the repositories are untouched after reading progress (D7).
- [X] T045 [US2] Negative control for T044: have the computation cache its result to the
      repository, confirm the no-write assertion goes red, revert. A stored copy is a second
      thing that can disagree with the swimmer's own record, and the record is the one they
      wrote.

### Implementation for User Story 2

- [X] T046 [US2] Implement `lib/dominio/macrociclo/progreso_en_el_macrociclo.dart` —
      `ProgresoEnElMacrociclo`, computed at read time from the feature 003 records, extending
      upward what `ProgresoDelNadador` already does for one plan (D7). Pure Dart.
- [X] T047 [US2] Add `Contenido.miMacrociclo` to `lib/dominio/hub/destino.dart` and point
      `reparto(Destino.verPlan, Rol.nadador)` at it. **`Contenido.sesionDelDia` stays
      reachable** as the screen's own fallback (M23), so no feature 003 behaviour is lost;
      update `test/dominio/hub/reparto_test.dart` (lines 82 and 147) and
      `test/dominio/hub/destinos_test.dart` to match, keeping the property that no content of
      the other role appears in a route.
- [X] T048 [US2] `lib/ui/nadador/mi_macrociclo.dart`: the structure rendered **unfolded** —
      mesocycles, names, objectives, dates — with **any** session expandable on a tap,
      including one six weeks out (M18, FR-020).
- [X] T049 [US2] Widget test `test/ui/nadador/mi_macrociclo_test.dart`: the view opens
      positioned at **today**, not at week one (M19, FR-021, C9). Fourteen weeks of folded
      sessions is still a long list.
- [X] T050 [P] [US2] Widget test: a session six weeks out expands on a tap and shows its parts
      (M18). Nothing is hidden.
- [X] T051 [P] [US2] Widget test: the swimmer is told the plan may change according to how they
      respond, in Spanish and without jargon (M21, FR-018), and sees which mesocycle they are
      working and where today falls (M20, FR-017).
- [X] T052 [P] [US2] Widget test: a swimmer with **no** macrocycle gets what feature 003 gives
      them — the session of the day — and is **not** shown an empty hierarchy (M23, FR-004 of
      US2's scenarios).
- [X] T053 [P] [US2] Widget test: a swimmer who reaches the last session is told the cycle
      finished and that the next one is their coach's to prepare, rather than being left on an
      empty screen (spec edge case).
- [X] T054 [US2] Add `PantallaMiMacrociclo` to `test/ui/tema/ayuda_pantallas.dart` mounted with
      a fourteen-week macrocycle, and confirm the expand controls pass
      `test/ui/tema/tamano_de_letra_test.dart` at 200% and
      `test/ui/tema/area_pulsable_test.dart` (M22, FR-022). A disclosure control a nine-year-old
      cannot hit makes the content reachable in principle and not in practice.
- [X] T055 [US2] Wire `Contenido.miMacrociclo` into `lib/ui/hub/contenidos.dart` beside the
      existing swimmer content, reusing the `EstadoNadador` provider the other swimmer screens
      get.

**Checkpoint**: the swimmer sees the whole path. C9 is walkable, and US1 and US2 both work
independently.

---

## Phase 5: User Story 3 — Marking what was done, honestly (Priority: P1)

**Goal**: a future session cannot be marked and the app says why; a past one can always be
marked, and what is outstanding is **shown, not enforced**.

**Independent Test**: with a delivered macrocycle, try to mark tomorrow's session, then skip
Tuesday and mark Thursday, then come back and mark Tuesday.

**Why it is P1**: the adherence data this produces is what the coach's readjustment runs on
(section 4, step 8). A rule that stops a swimmer recording a session they actually swam makes
the app lie, and then the readjustment is modelling a fiction.

### Tests for User Story 3 — written first

- [ ] T056 [US3] `test/dominio/macrociclo/puede_marcarse_test.dart`, before the function
      exists: a session dated today → `si`; dated tomorrow → `todaviaNo` with «Todavía no llega
      ese día»; dated yesterday → `si`; with `fecha == null` → `sinFecha` with «Esta sesión no
      tiene día asignado». `Sesion.fecha` is nullable, so `sinFecha` is a real case and not a
      defensive branch: the app does not guess when something was meant to happen (M28).
- [ ] T057 [US3] Negative control for T056: make the comparison use `isAfter` on the full
      `DateTime` instead of whole dates, and confirm a session dated today at 23:00 breaks the
      `si` case. The same trap `_diasEnteros` exists to avoid.
- [ ] T058 [US3] `test/dominio/macrociclo/marcar_por_cualquier_via_test.dart`: the lock is
      exercised **through the record-saving path and not through the screen** (M24, SC-006) —
      build a `RegistroDeSesion` with `realizada: true` for a future session and assert the
      save path refuses it. A lock that only lives in a widget is a lock on one door of three.

### Implementation for User Story 3

- [ ] T059 [US3] Implement `lib/dominio/macrociclo/puede_marcarse.dart`: a pure function over
      the session's date and today, returning `si` / `todaviaNo` / `sinFecha` with the exact
      Spanish the swimmer reads. No repository, no screen (D6).
- [ ] T060 [US3] Apply the check where the record is built, in
      `lib/ui/nadador/estado_nadador.dart` and `lib/ui/nadador/formulario_registro.dart`, so a
      future-dated record is never constructed — not merely never submitted.
- [ ] T061 [US3] Server backstop in `firebase/firestore.rules`: deny create and update on
      `registros` when the session's `fecha` is after `request.time`, via
      `get(/databases/$(database)/documents/planes/$(planId)/sesiones/$(sesionId))`. First
      confirm `sesionAJson` actually stores `fecha` in that document; if it does not, say so in
      the task notes rather than writing a rule that reads a field that is not there.
- [ ] T062 [US3] Rules test for T061 in `firebase/test/reglas_macrociclos.test.js`, **with an
      `assertSucceeds` for a past-dated session** alongside the denial for a future one.
      Without the success case the test would pass against a rule that denied everything.
- [ ] T063 [US3] Test in `test/dominio/sincronizacion/`: the outbox never carries a
      future-dated record, so T061 is a backstop and not a retry loop. A permanently rejected
      write that the outbox retries for ever is worse than the thing it was guarding against.
- [ ] T064 [P] [US3] Test: a session dated today or earlier can **always** be marked, whatever
      happened to the ones before it (M25, FR-025). This is the coach's decision of 2026-11-04
      and the test is its record.
- [ ] T065 [P] [US3] Test: marking a session while earlier ones are outstanding reports **which
      ones** are outstanding (M26, FR-026). It shows the gap; it does not deny the fact.
- [ ] T066 [P] [US3] Test: an outstanding session stays markable later (M27, FR-027). A skipped
      day is not a closed door.
- [ ] T067 [US3] Surface the three messages in `lib/ui/nadador/mi_macrociclo.dart`, with a
      widget test for each: the refusal with its reason, the outstanding list, and the
      undated-session case.
- [ ] T068 [US3] Test in `test/dominio/calculo/`: what the coach reads as adherence shows the
      skip **as a skip** and not as missing data (M29, FR-028). The difference is what his
      readjustment will be reading, and `Adherencia` counts sessions and nothing else
      (principle VIII).

**Checkpoint**: C10 and C11 are walkable. All three P1 stories work independently.

---

## Phase 6: User Story 4 — The coach readjusts, and the swimmer is told (Priority: P2)

**Goal**: readjusting versions each affected mesocycle, in one act, with one notice — and
without touching what the swimmer already recorded.

**Independent Test**: readjust a delivered macrocycle with sessions already marked, and check
both that the swimmer sees what changed and that their records are still reachable.

**⚠️ Start with T069. It fails today, against code that is already in `main`.**

### Tests for User Story 4 — written first

- [ ] T069 [US4] **The quiet one.** `test/dominio/macrociclo/el_reajuste_no_se_come_el_historial_test.dart`:
      with `RegistroDeSesion` records for several of a mesocycle's sessions, version that
      mesocycle, then assert every record is still **reachable** from the new version's
      sessions. The assertion is on **reachability, not on the write succeeding** — records are
      keyed by `sesionId`, and a new version with new ids orphans them while every write
      returns fine (M34, FR-035, SC-008, D8).
- [ ] T070 [US4] **Fix the defect T069 exposes.** `RepositorioPlanesFirestore.crearVersionDesde`
      in `lib/datos/firestore/repositorios_firestore.dart:143` copies every session with
      `sesion.copiarCon(id: null)`, so each new version assigns new session ids and blanks the
      swimmer's history with nothing failing. Decide per D8 — stable session ids across
      versions, or carrying the records explicitly — implement it, and write the reason in the
      method's doc comment so the next person does not restore the old line as a tidy-up.
- [ ] T071 [US4] Negative control for T069: restore `copiarCon(id: null)`, confirm the test
      goes red, apply the fix again. This is the one lock in the feature whose absence produces
      no error message at all.
- [ ] T072 [US4] Test that `CicloVidaPlan.crearVersionDesde`
      (`lib/dominio/entidades/ciclo_vida_plan.dart:80`) agrees with the Firestore path on
      session identity. Two version paths that disagree means the defect comes back through
      whichever one the test does not use.

### Implementation for User Story 4

- [ ] T073 [US4] Implement `lib/dominio/macrociclo/reajuste.dart`: a readjustment creates a new
      version of each affected mesocycle through the existing `crearVersionDesde` lineage (M31,
      FR-030, FR-031), carrying `macrocicloId` and `ordenEnElMacrociclo` forward.
- [ ] T074 [US4] Test and implement: a readjustment touching several mesocycles is **one act**
      for the coach and **one notice** to the swimmer, not one per mesocycle (M32, FR-032,
      C13).
- [ ] T075 [US4] Test and implement: the app states which version of each mesocycle the swimmer
      is currently on, without the coach working it out (M33, FR-033).
- [ ] T076 [US4] Test: **only the coach readjusts**, and the app never readjusts on its own,
      however clear the adherence data looks (M30, FR-029). Section 4 step 8 is his judgement,
      not a trigger.
- [ ] T077 [US4] Test: a readjustment passes the section 16 audit before it reaches the swimmer
      and does not reach them without his signature (M35, FR-036, FR-037), using the same audit
      path as T033.
- [ ] T078 [US4] Widget test: the swimmer opens their plan and sees that their coach adjusted
      that part, **without comparing versions themselves** (FR-034), and the readjustment
      notice reads in Spanish without jargon.
- [ ] T079 [US4] Rules: a swimmer cannot create a macrocycle version or move one between
      states, with its test and its `assertSucceeds` counterpart in
      `firebase/test/reglas_macrociclos.test.js`.

**Checkpoint**: C12 and C13 are walkable — the two the walk exists for.

---

## Phase 7: Polish & Cross-Cutting Concerns

- [ ] T080 Extend `firebase/functions/tools/sembrar-emulador.js`: a swimmer with a **complete
      record and a competition 14 weeks away** for a three-phase skeleton, and one in a
      category **without ATR** for C6. Re-set the role claims at the end, as the existing seed
      does — `alCrearseUnaCuenta` overwrites them.
- [ ] T081 Seed a delivered macrocycle with some sessions already marked, so C12 has something
      to readjust that has history in it.
- [ ] T082 [P] Add a "The macrocycle and the mesocycle" section to `docs/DEVELOPMENT.md`,
      leading with D1: a `Plan` is a mesocycle, `Macrociclo` is the level above. Edit the file
      with the editing tools, not a `perl -i` pass — one mangled the non-ASCII lines in feature
      008 and had to be reverted.
- [ ] T083 [P] Mark feature 009 on the roadmap in `docs/ROADMAP.md` once the PR merges.
- [ ] T084 Run the four gates: `flutter analyze`, `flutter test`,
      `npm --prefix firebase test`, `npm --prefix firebase/functions test`. All green, and the
      Dart count **not below** T001's baseline. A test from an earlier feature that fails means
      this feature changed a behaviour it had no business changing.
- [ ] T085 Walk C1 to C8 as the coach against the emulator, checking C4 in the emulator's own
      data and not on the screen.
- [ ] T086 Walk C9 to C11 as the swimmer.
- [ ] T087 Walk **C12 and C13 last and carefully**, checking the records against the emulator
      rather than the screen. Feature 008 found six defects by walking, five of them invisible
      because the app kept working.
- [ ] T088 Walk C9 again on the Android Pixel 7 emulator. Feature 008's sixth defect was only
      visible on a phone, and folding controls are exactly what a browser flatters.
- [ ] T089 Measure the derivation where the coach is: fourteen generator calls on the Android
      emulator, not in a test. If it blocks the UI it will block it there first.
- [ ] T090 Confirm the constitution v2.0.0 obligation can be met in one sentence: point at the
      single confirmation, in the code and on the screen. If it cannot be pointed at, the
      amendment was used to skip a rule rather than to restate it — and that is a finding for
      the PR, not a detail.

---

## Dependencies & Execution Order

### Phase dependencies

- **Setup (Phase 1)**: no dependencies.
- **Foundational (Phase 2)**: needs Setup. **Blocks all four stories** — every one of them
  needs the `Macrociclo` type and its repository.
- **US1 (Phase 3)**: needs Phase 2. No dependency on another story.
- **US2 (Phase 4)**: needs Phase 2. Buildable and testable against a seeded macrocycle in the
  memory repositories, so it does not wait for US1 — but the **quickstart walk** of C9 does,
  because there has to be a delivered macrocycle to open.
- **US3 (Phase 5)**: needs Phase 2, and in practice US2's screen for T067's three messages.
  The domain rule (T056, T059) is independent of both.
- **US4 (Phase 6)**: needs Phase 2. T069 and T070 are independent of every other story and
  could be done first — the defect is in `main` today. The rest reads better after US2, since
  the swimmer has to see the notice somewhere.
- **Polish (Phase 7)**: needs whichever stories are being shipped.

### The order that is not negotiable

Three places, all of them about not writing something before the thing that guards it exists:

1. **T004 before T005**, **T019 before T024**, **T056 before T059** — the lock precedes the
   rule it guards, and each has its negative control (T006, T020, T057).
2. **T027 before T037.** The storage lock before the structure screen, because the screen is
   where a convenient preview would save a draft and nothing would fail.
3. **T069 before T070, and before any other readjustment work.** The record-survival test
   before the readjustment, against a defect that already exists.

### Parallel opportunities

- T002 and T003 in Setup.
- T013 and T014 (memory and Firestore implementations of the same interface, different files).
- T021, T022 and T023 — three independent US1 test files.
- T050, T051, T052 and T053 — four independent US2 widget tests.
- T064, T065 and T066 — three independent US3 tests.
- T082 and T083 in Polish.

Not parallel, however much they look it: anything touching
`lib/dominio/macrociclo/macrociclo.dart`, `firebase/firestore.rules`,
`lib/datos/serializacion.dart` or `test/ui/tema/ayuda_pantallas.dart` — four files that several
tasks each edit.

---

## Implementation Strategy

### MVP: User Story 1 alone

Phase 1 → Phase 2 → Phase 3. Stop there and walk C1 to C8. At that point a coach can produce,
sign and deliver a whole macrocycle from one confirmation, and the constitution v2.0.0 question
has an answer. Nothing reaches a swimmer yet, which is a complete state and not a broken one.

### Incremental delivery

1. Setup + Foundational → the macrocycle exists and is reachable by the right people.
2. **US1** → the coach's half. Walk C1 to C8. This is the MVP.
3. **US2** → the swimmer sees the path. Walk C9.
4. **US3** → marking, honestly. Walk C10 and C11.
5. **US4** → readjustment. Walk C12 and C13, carefully.

Each step leaves the app working. US1 without US2 is a coach who can plan a season; US1 plus
US2 without US3 is a swimmer who can read it; the order is the order the value arrives in.

One exception to the order, worth taking: **T069 and T070 can be done at any point**, including
first. They fix a defect that is in `main` now, and fixing it early means the readjustment is
built on top of a version path that keeps the swimmer's history rather than on one that loses
it.

---

## Notes

- Total: **90 tasks**. US1 25, US2 12, US3 13, US4 11; 15 foundational, 3 setup, 11 polish.
- **Baseline test counts (T001)**, taken on 2026-11-04 before any other task:
  `flutter analyze` → no issues. `flutter test` → **1595 passing**. The two npm suites
  (`npm --prefix firebase test`, `npm --prefix firebase/functions test`) need the emulator
  running and are measured at T084 instead; they were green at feature 008's merge.
- `[P]` means different files and no unfinished dependency.
- Commit per task or per logical group, and stop at the checkpoints to walk what exists.
- **Found while building T026's save path, and out of this feature's scope** (recorded here
  because it has no other home yet): saving a plan **never writes its sessions to Firestore**.
  `RepositorioPlanesFirestore.guardarBorrador` and `guardarAprobado` persist only
  `planAJson(plan)`, which excludes `sesiones`; the `sesiones` subcollection is written
  exclusively by `RepositorioSesionesFirestore.guardar`, whose only caller is the editor
  (`lib/ui/editor/estado_editor.dart:171`), one session at a time by hand. So a plan the engine
  generated and code saved lands in Firestore with no sessions — most visibly feature 008's
  coach queue (`lib/ui/hub/cola_del_entrenador.dart:456` and `:474`), where an approved plan
  from a swimmer's request is stored with its microcycles and not one session. Nothing throws,
  because `RepositorioPlanesMemoria` keeps the whole object in memory and every Dart test
  passes. Feature 009 writes its sessions explicitly in `guardarElMacrociclo`, so it is not
  affected; feature 008 is, and the two implementations disagree about what "save a plan"
  means, which is the kind of gap that produces exactly this.
- **One design mistake worth recording**, because the test caught it and the shape recurs:
  `impedimentosParaAprobar` originally answered two questions at once — "do I have everything
  this macrocycle names?" and "is the stored state coherent?" Used before signing, it reported
  all three freshly derived mesocycles as impediments for being in `borrador`, which is exactly
  what they are at that point. Split into `mesociclosQueFaltan` (presence, checked before
  signing) and `impedimentosParaAprobar` (state, M14).
- **Every fake must behave like the real collaborator.** Feature 008 had three tests pass for
  the wrong reason, and each went red only once the fake stopped being convenient: a
  `pumpWidget` that reused the same `State`, a queue fake that returned the same list instance
  instead of a snapshot, and a gate fake that reported "held" from the first load instead of
  only after a send. A fake that is more convenient than the real thing does not make a test
  easier; it makes it dishonest.
