---
description: Task list for feature 012 — The coach → swimmer relation
---

# Tasks: The coach → swimmer relation

**Input**: Design documents from `/specs/012-coach-swimmer-link/`

**Prerequisites**: [plan.md](./plan.md), [spec.md](./spec.md), [research.md](./research.md), [data-model.md](./data-model.md), [contracts/la-frontera.md](./contracts/la-frontera.md), [quickstart.md](./quickstart.md)

## Format: `[ID] [P?] [Story] Description`

- **[P]**: can run in parallel — different files, no dependency on an unfinished task
- **[US1]**…**[US5]**: the user story in [spec.md](./spec.md) the task serves

## Tests are not optional, and here they are the feature

Principle III is non-negotiable in this project: the lock goes in before the thing it
guards, and every lock gets its negative control run.

This feature is a **boundary**, and a boundary is worth exactly what its tests are worth.
Two rules apply to every test written here, both paid for already:

1. **Exercise the queries the app makes.** A suite that reads single documents by their
   identifier goes green over a rule the app cannot use. Feature 009 paid for that twice.
2. **A test that asserts a refusal passes for free when nothing is enforced.** Only the
   ones asserting a success tell you the rules are loaded at all — which is why T062
   exists and why FR-018 is a requirement rather than a footnote.

## Path Conventions

Flutter app at the repository root. Domain in `lib/dominio/` (pure Dart), data in
`lib/datos/`, interface in `lib/ui/`, rules and functions in `firebase/`.

---

## Phase 1: Setup

- [X] T001 Record the baseline in `specs/012-coach-swimmer-link/tasks.md` beside this line: run the four gates on `012-coach-swimmer-link` before any change — `flutter analyze`, `flutter test`, `npm --prefix firebase test`, `npm --prefix firebase/functions test`. The rules number is the one that matters this time: a boundary feature whose rules suite barely grows is a boundary that is not being tested

**Before, 2026-11-19:**

| Gate | Result |
|---|---|
| `flutter analyze` | No issues |
| `flutter test` | 2202 passed, 0 failed |
| `npm --prefix firebase test` | 174 passed, 0 failed |
| `npm --prefix firebase/functions test` | 45 passed, 0 failed |

- [X] T002 Build a seed that this feature can be proven against, in `firebase/functions/tools/sembrar-emulador.js`: a community for the seeded coach with the seeded swimmers in it, **a second coach with his own community and his own swimmer**, and **one swimmer who belongs to nobody**. Without the second coach every "he cannot see her" check passes for the wrong reason, and without the unlinked swimmer there is nothing to test the waiting and stranded states against (quickstart V0)

---

## Phase 2: Foundational (blocking prerequisites)

**Purpose**: the three domain types every story speaks in, and the interfaces that let
the data layer be doubled. Pure Dart, no Firebase.

- [X] T003 [P] Create `Comunidad` in `lib/dominio/comunidad/comunidad.dart`: an id, an `entrenadorId` and a `nombre`. The constructor **refuses** a blank name and one over 60 characters, the way every entity in this project refuses what it cannot represent
- [X] T004 [P] Lock `Comunidad` in `test/dominio/comunidad/comunidad_test.dart`: the two refusals, and that `entrenadorId` cannot be changed on a copy — a community that can change hands is a different product (data-model.md)
- [X] T005 [P] Create `Membresia` in `lib/dominio/comunidad/membresia.dart`: which swimmer, which community, since when. A value and not a document — it is what `comunidadId` and `miembroDesde` mean together
- [X] T006 [P] Create `SolicitudDeIngreso` in `lib/dominio/comunidad/solicitud_de_ingreso.dart` with the four states `esperando`, `aceptada`, `rechazada`, `retirada`, and the transitions each side may make
- [X] T007 [P] Lock the transitions in `test/dominio/comunidad/solicitud_de_ingreso_test.dart`: a swimmer's copy may go to `retirada` and **nowhere else** — `aceptada` is a word that belongs to the coach, and the type refuses it rather than trusting a screen to
- [X] T008 Add the three repository interfaces to `lib/dominio/repositorios/repositorios.dart`: communities, join requests, and whatever the membership needs. Interfaces only; no Firestore anywhere near them

**Checkpoint**: the vocabulary exists and is proven. Stories can start.

---


**Control negativo de `reglas_comunidad.test.js`, 2026-11-19** (T012): apuntada a
`comunidades_sin_regla` y `solicitudes_sin_regla`, **8 de las 22 pruebas nuevas pasan
igual** y las 14 que caen son las que afirman un éxito o dependen de leer datos reales.
Es la misma proporción que la feature 008 midió y la 010 repitió: contra una colección
sin reglas, toda negación pasa gratis. Las ocho que sobreviven son `assertFails` y no
prueban nada por sí solas — están por su contraparte positiva, no al revés.
## Phase 3: User Story 1 — The coach names what is his (Priority: P1) 🎯 MVP

**Goal**: he sets a name in his settings, and that is what a swimmer will be offered.

**Independent test**: set the name as the coach, and confirm it is what the joining step
would show. Nothing else in the feature has to exist.

### Locks for User Story 1 ⚠️ write first, see red

- [X] T009 [P] [US1] Lock the rules of `comunidades` in `firebase/test/reglas_comunidad.test.js`: its coach writes it; **any signed-in account reads it**, because a swimmer must see the name before she is anyone's (research D3); nobody else writes it; and `entrenadorId` cannot be changed after creation
- [X] T010 [P] [US1] Lock that one coach has one community in `firebase/test/reglas_comunidad.test.js`: the document id **is** the coach's account id, so "one" is a fact of the key and not a rule somebody has to remember
- [X] T011 [P] [US1] Lock the screen in `test/ui/ajustes/mi_comunidad_test.dart`: the coach finds where to name it among what is already in settings, a blank name is refused with words he can act on, and a swimmer never sees this control
- [X] T012 [US1] Run the negative control for T009–T011 and record it in `specs/012-coach-swimmer-link/tasks.md`: point the rules suite at a collection with no rule and write down how many pass anyway

### Implementation for User Story 1

- [X] T013 [US1] Add the `comunidades` rules to `firebase/firestore.rules` per [contracts/la-frontera.md](./contracts/la-frontera.md)
- [X] T014 [P] [US1] Create `lib/datos/firestore/comunidades_firestore.dart`: read one, read by coach, create and rename
- [X] T015 [US1] Create the settings section in `lib/ui/ajustes/mi_comunidad.dart` and wire it into `lib/ui/ajustes/pantalla_ajustes.dart`, beside apariencia, mis datos, mis derechos, lo que acepté and supresión
- [X] T016 [US1] Make renaming change nothing else (FR-003), and add the case to `test/ui/ajustes/mi_comunidad_test.dart`: a rename with a membership and a waiting request in place moves neither

**Checkpoint**: US1 is demonstrable on its own — a named community, nothing else needed.

---

## Phase 4: User Story 2 — She asks while creating her account (Priority: P1)

**Goal**: joining is offered among the steps that already exist, and asking is optional.

**Independent test**: create an account, choose to join, and confirm a request is waiting.

**Depends on**: US1 — there has to be a community with a name to be offered.

### Locks for User Story 2 ⚠️ write first, see red

- [X] T017 [P] [US2] Lock the rules of `solicitudesDeIngreso` in `firebase/test/reglas_comunidad.test.js`: she creates her own and may withdraw it; she **cannot** write `aceptada`; the coach of that community reads the ones addressed to him **by a query filtered on `comunidadId`**, not by reading the collection; nobody else reads any of it
- [X] T018 [P] [US2] Lock the deterministic id in `firebase/test/reglas_comunidad.test.js`: the id is `nadadorId|comunidadId`, a document whose id disagrees with its fields is refused, and asking twice is the same asking (data-model.md)
- [X] T019 [P] [US2] Lock the sign-up step in `test/ui/alta/paso_comunidad_test.dart`: the community is offered **by name**; skipping finishes the account; with no community named she is told so in plain words and can still finish (FR-006)
- [ ] T020 [P] [US2] Lock FR-008 in `test/dominio/comunidad/una_sola_solicitud_test.dart`: a swimmer has at most one waiting request, and asking elsewhere withdraws the first
- [X] T021 [US2] Run the negative control for T017–T020 and record it in `specs/012-coach-swimmer-link/tasks.md`

### Implementation for User Story 2

- [X] T022 [US2] Add the `solicitudesDeIngreso` rules to `firebase/firestore.rules`
- [X] T023 [P] [US2] Create `lib/datos/firestore/solicitudes_firestore.dart`: raise, withdraw, read mine, read the ones for a community
- [X] T024 [US2] Create the joining step in `lib/ui/alta/paso_comunidad.dart` and place it in the flow in `lib/ui/alta/pantalla_alta.dart`, **without adding a step she cannot skip** (FR-004, FR-005)
- [ ] T025 [US2] Let her see and withdraw what she asked, in `lib/ui/alta/estado_alta.dart` and wherever she looks afterwards (FR-007)
- [ ] T026 [US2] Name the community in the guardian's consent request when there is one, in `firebase/functions/src/consentimiento.ts` and its mail body in `firebase/functions/src/correo.ts` (FR-028). It is strictly more information for the guardian and changes nothing about what the consent permits

**Checkpoint**: a request reaches the coach's data. He cannot act on it yet.

---

## Phase 5: User Story 3 — He accepts, and only then does he read her (Priority: P1)

**Goal**: the boundary. The reason the feature exists.

**Independent test**: with a request waiting, accept it and confirm she becomes readable —
and that before accepting, nothing of hers was.

**Depends on**: US1 and US2. **This is the biggest phase by a wide margin**, and most of
it is not the accepting — it is the five queries that cannot survive the tightened rules.

### Locks for the boundary ⚠️ write first, see red

- [ ] T027 [P] [US3] Lock F3 in `firebase/test/reglas_frontera.test.js`: with a request waiting, the coach reads **nothing** of hers — not a record, not a macrocycle, not a plan, not a feedback request, not her profile beyond what the request carries
- [ ] T028 [P] [US3] Lock F4 in `firebase/test/reglas_frontera.test.js`: once accepted, what she wrote **before** he accepted is readable. The membership says who may read it, not since when it exists
- [ ] T029 [P] [US3] Lock F2 for `nadadores` in `firebase/test/reglas_frontera.test.js` **using the query the app makes** — filtered by `comunidadId` — and assert that the unfiltered query is **refused**, not filtered
- [ ] T030 [P] [US3] Lock F2 for `registros` the same way in `firebase/test/reglas_frontera.test.js`
- [ ] T031 [P] [US3] Lock F2 for `macrociclos` the same way in `firebase/test/reglas_frontera.test.js`
- [ ] T032 [P] [US3] Lock F2 for `planes` and `asignaciones` the same way in `firebase/test/reglas_frontera.test.js`
- [ ] T033 [P] [US3] Lock F2 for `peticiones` (feature 008) and `peticionesDeFeedback` (feature 010) the same way in `firebase/test/reglas_frontera.test.js`
- [ ] T034 [P] [US3] Lock F6 in `firebase/test/reglas_frontera.test.js`: **no client writes `comunidadId`** — not the coach on her profile, not the swimmer on her own
- [ ] T035 [P] [US3] Lock F8 in `firebase/test/reglas_frontera.test.js`: a minor with a membership and **no valid consent** still has nothing leave the device. The two gates compose; neither replaces the other
- [ ] T036 [US3] Run the negative control for T027–T035 and record it in `specs/012-coach-swimmer-link/tasks.md`, with the number that passes against a collection with no rule

### FR-018 — the inversion, and what it costs the suite

- [ ] T037 [US3] Invert the second-coach test in `firebase/test/reglas_analisis.test.js`: it asserts today that another coach **succeeds** in reading this swimmer, and says in its own text that it is waiting for this day. Rewrite the comment to say what happened rather than deleting the history
- [ ] T038 [US3] Re-run that suite's negative control and record the new numbers in `specs/012-coach-swimmer-link/tasks.md`. It used to be **5 of 10 passing against a collection with no rule, every failure an `assertSucceeds`** — and the inverted test was one of those five
- [ ] T039 [US3] If T038 shows the suite got worse at noticing a missing rule, add the `assertSucceeds` this feature can honestly make — **a coach reading his own swimmer must succeed** — in `firebase/test/reglas_analisis.test.js`, and record that it was needed

### The five queries that read everything (research D2)

- [ ] T040 [US3] Rewrite the swimmer list in `lib/datos/firestore/repositorios_firestore.dart` to filter by `comunidadId`. This one comes first because the other four are expressed in terms of **his swimmers**, and this is where he gets them
- [ ] T041 [US3] Rewrite `nadadoresConRegistros` in `lib/datos/firestore/registros_firestore.dart` to be scoped to his swimmers. **Record how many queries it now costs** with the seeded group: feature 007's decision D10 bought "one query" on purpose, and this trade is made with its eyes open
- [ ] T042 [US3] Rewrite `macrocicloPorNadador` in `lib/datos/firestore/macrociclos_firestore.dart` the same way
- [ ] T043 [US3] Rewrite the plan requests query in `lib/datos/firestore/peticiones_firestore.dart` the same way
- [ ] T044 [US3] Rewrite the assignments query in `lib/datos/firestore/repositorios_firestore.dart` the same way
- [ ] T045 [US3] Fix the comment in `lib/datos/firestore/registros_firestore.dart` that already claims «las reglas le dejan leer los registros de su comunidad». It has been describing this feature for two features; make it true rather than aspirational

### The rules and the server

- [ ] T046 [US3] Add the membership helper to `firebase/firestore.rules` — "is this swimmer in my community" — and tighten the six collections per [contracts/la-frontera.md](./contracts/la-frontera.md)
- [ ] T047 [US3] Add `comunidadId` and `miembroDesde` to `lib/dominio/entidades/nadador.dart` and its serialisation in `lib/datos/serializacion.dart`, absent meaning she belongs to nobody — **no "pending" value**, because pending is a property of the request (data-model.md)
- [ ] T048 [US3] Write `aceptar` in `firebase/functions/src/comunidad.ts`: it checks the caller owns that community, writes the membership and closes the request **as one act**. Half an accept is a swimmer who belongs to nobody with no request left to show for it (research D4)
- [ ] T049 [P] [US3] Write `rechazar` in `firebase/functions/src/comunidad.ts`: closes the request, carries no written reason, and does not prevent her asking again (FR-012)
- [ ] T050 [US3] Export both from `firebase/functions/src/index.ts` and lock them in `firebase/functions/test/comunidad.test.js`: a coach cannot resolve a request for a community that is not his, and resolving one that is no longer waiting does nothing and says so
- [ ] T051 [US3] Put the request where things already wait for him, in `lib/ui/hub/cola_del_entrenador.dart`, showing who asked and when (FR-009)
- [ ] T052 [US3] Tell her either way in `lib/ui/alta/estado_alta.dart` and the swimmer's screens, and make a declined request not block her from asking again (FR-010, FR-012)

**Checkpoint**: the feature exists. A second coach reads nothing of another's swimmer, and
the rules suite proves it with the queries the app makes.

---

## Phase 6: User Story 4 — While she waits, she is not left in the dark (Priority: P2)

**Goal**: the screen where her plan would be tells her where she stands.

**Independent test**: with a request waiting, open the app as her and confirm she is told.

**Depends on**: US2 for a waiting request to exist.

### Locks for User Story 4 ⚠️ write first, see red

- [ ] T053 [P] [US4] Lock the four cases in `test/ui/nadador/donde_estoy_test.dart`: she has a plan; she has none and belongs; she has none and is waiting; she has none and never asked. **Four answers to two independent questions**, and none of them is "no tienes plan" when she is waiting (research D6)
- [ ] T054 [P] [US4] Lock that the waiting state is **not** a fifth `Lectura` case, in `test/dominio/lectura/lectura_test.dart`: waiting is a fact about her that explains why the reading found nothing, not a state of the reading. Adding it to that type would repeat feature 011's defect in a new costume
- [ ] T055 [US4] Run the negative control for T053–T054 and record it in `specs/012-coach-swimmer-link/tasks.md`: make the screen treat "waiting" as "no plan" and confirm T053 goes red

### Implementation for User Story 4

- [ ] T056 [US4] Ask the second question — does she belong to a community, and is she waiting — in `lib/ui/nadador/estado_nadador.dart`, beside the `Lectura` that feature 011 added and **not inside it**
- [ ] T057 [P] [US4] Choose the empty state accordingly in `lib/ui/nadador/pantalla_mi_progreso.dart`
- [ ] T058 [P] [US4] Do the same in `lib/ui/nadador/pantalla_sesion_del_dia.dart` and `lib/ui/nadador/mi_macrociclo.dart`. Three screens carry this now; fixing two is leaving one for the next walk
- [ ] T059 [US4] Make the waiting notice disappear when the membership begins in `lib/ui/nadador/estado_nadador.dart`, without her doing anything to clear it (FR-022)

**Checkpoint**: a waiting swimmer is never shown something false.

---

## Phase 7: User Story 5 — Leaving, and being let go (Priority: P3)

**Goal**: a relation that can be ended from either side, with nothing of hers lost.

**Independent test**: end a membership from each side and confirm he stops reading her
while her own history is untouched.

**Depends on**: US3 for a membership to end.

### Locks for User Story 5 ⚠️ write first, see red

- [ ] T060 [P] [US5] Lock F7 in `firebase/test/reglas_frontera.test.js`: after either side ends it, the coach's next query returns nothing of hers — **and nothing she wrote is deleted, hidden or altered**
- [ ] T061 [P] [US5] Lock the two calls in `firebase/functions/test/comunidad.test.js`: a coach cannot remove a swimmer who is not his, and a swimmer cannot leave a community she does not belong to
- [ ] T062 [US5] Run the negative control for T060–T061 and record it in `specs/012-coach-swimmer-link/tasks.md`

### Implementation for User Story 5

- [ ] T063 [P] [US5] Write `sacar` and `salir` in `firebase/functions/src/comunidad.ts`, and export them from `firebase/functions/src/index.ts`
- [ ] T064 [P] [US5] Give the coach the control in `lib/ui/nadadores/pantalla_perfiles.dart`, asking first, because it is not undoable from his side
- [ ] T065 [P] [US5] Give her the control where she governs her own account, in `lib/ui/ajustes/pantalla_ajustes.dart`
- [ ] T066 [US5] Tell her when she has been removed (FR-026) in `lib/ui/nadador/estado_nadador.dart` and the screens that read it

**Checkpoint**: all five stories work.

---

## Phase 8: Polish & Cross-Cutting

- [ ] T067 Run the four gates and write the numbers beside T001's baseline in `specs/012-coach-swimmer-link/tasks.md`. **The rules number is the one to look at**: a boundary feature whose rules suite barely grew is a boundary that is not being tested
- [ ] T068 Confirm `git diff pubspec.yaml pubspec.lock` is empty — principle VII's check, not a memory
- [ ] T069 Walk [quickstart.md](./quickstart.md) V0 to V9 on the emulators and record what each showed in `specs/012-coach-swimmer-link/tasks.md`, V5 and V9 above all
- [ ] T070 [P] Write the 012 paragraphs in `docs/ROADMAP.md` to say what was built, the way 009, 010 and 011 did — including what the five rewritten queries cost
- [ ] T071 [P] Record in `specs/012-coach-swimmer-link/tasks.md` what feature 013 now inherits: a membership exists, so "who may watch a swimmer's video" finally has somewhere to get its answer
- [ ] T072 Re-read the Constitution Check table in [plan.md](./plan.md) against what was actually built and correct it if anything drifted. A gate that is only true at planning time is not a gate
- [ ] T073 [P] Mark feature 012 on the roadmap in `docs/ROADMAP.md` once the PR merges

---

## Dependencies & Execution Order

### Phase dependencies

- **Phase 1 (Setup)**: T001 first, because a baseline taken afterwards is not a baseline. T002 before any boundary test, because without a second coach every refusal passes for the wrong reason
- **Phase 2 (Foundational)**: blocks everything
- **Phase 3 (US1)**: after Phase 2. Independent of everything else
- **Phase 4 (US2)**: after US1 — there must be a community to ask for
- **Phase 5 (US3)**: after US2 for the accepting half. **The boundary half can start as soon as the membership field exists**, since the seed can create memberships directly
- **Phase 6 (US4)**: after US2
- **Phase 7 (US5)**: after US3
- **Phase 8 (Polish)**: after everything meant to ship

### These stories chain, and pretending otherwise would be a lie

Unlike feature 011, where two stories were genuinely independent, **this feature is a
chain**: a name, then a request for it, then an acceptance of that, then the states that
depend on there being one. The honest parallelism is **inside** phases, not across them.

The one real exception: within US3, the **five query rewrites (T040–T044) are independent
of the accepting path (T048–T052)**, and the boundary can be proven against memberships
the seed created before `aceptar` exists at all.

### Within each story

Lock → see it red → negative control → implement → see it green. And for every rules test:
**the query the app makes**, never a `get` by id.

### Parallel opportunities

- Phase 2's five types and locks are five files
- Within US3, the eight boundary locks (T027–T035) are one file but independent cases, and
  T040–T044 are four files
- US5's two server calls and two screens are four files

---

## Parallel Example: the boundary locks

```bash
# The eight cases of F2, F3, F4, F6 and F8 can be written together:
Task: "Lock F3 — nothing readable while the request waits"
Task: "Lock F4 — what she wrote before he accepted is readable after"
Task: "Lock F2 for nadadores, with the query the app makes"
Task: "Lock F2 for registros"
Task: "Lock F2 for macrociclos"
Task: "Lock F2 for planes and asignaciones"
Task: "Lock F2 for peticiones and peticionesDeFeedback"
Task: "Lock F6 — no client writes comunidadId"
Task: "Lock F8 — consent and membership compose"
```

---

## Implementation Strategy

### MVP: User Story 1 alone

A coach can name his community. Nothing else changes, nothing breaks, and it is the one
piece of this feature that ships on its own.

### Then the chain

US2 (she can ask) → US3 (he can accept, and the boundary exists) → US4 (she is told while
she waits) → US5 (either side can end it).

**Stop and look after T046**, when the rules are tightened and the queries rewritten. That
is the moment the feature either works or shows a screen full of nothing, and it is much
easier to find out there than after four more phases.

### What to resist

- **Filtering in the client.** It is the mistake that looks like it works, and the
  documents would already have left the server. A boundary is where the query is refused
- **Copying `comunidadId` onto records to make a query easy.** It is the copy that cannot
  be unmade when a membership ends (research D1)
- **Writing the migration anyway.** There is nobody to migrate; code for a population that
  does not exist cannot be tested against it (research D5)
- **Auto-accepting anything**, however convenient. Principle IV, and FR-011 says it plainly
- **Testing the rules with `get` by id.** Green over a rule the app cannot use is the
  worst outcome available here
