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
- [X] T020 [P] [US2] Lock FR-008 in `test/dominio/comunidad/una_sola_solicitud_test.dart`: a swimmer has at most one waiting request, and asking elsewhere withdraws the first
- [X] T021 [US2] Run the negative control for T017–T020 and record it in `specs/012-coach-swimmer-link/tasks.md`

### Implementation for User Story 2

- [X] T022 [US2] Add the `solicitudesDeIngreso` rules to `firebase/firestore.rules`
- [X] T023 [P] [US2] Create `lib/datos/firestore/solicitudes_firestore.dart`: raise, withdraw, read mine, read the ones for a community
- [X] T024 [US2] Create the joining step in `lib/ui/alta/paso_comunidad.dart` and place it in the flow in `lib/ui/alta/pantalla_alta.dart`, **without adding a step she cannot skip** (FR-004, FR-005)
- [X] T025 [US2] Let her see and withdraw what she asked, in `lib/ui/alta/estado_alta.dart` and wherever she looks afterwards (FR-007)
- [X] T026 [US2] Name the community in the guardian's consent request when there is one, in `firebase/functions/src/consentimiento.ts` and its mail body in `firebase/functions/src/correo.ts` (FR-028). It is strictly more information for the guardian and changes nothing about what the consent permits

**Checkpoint**: a request reaches the coach's data. He cannot act on it yet.

---

## Phase 5: User Story 3 — He accepts, and only then does he read her (Priority: P1)

**Goal**: the boundary. The reason the feature exists.

**Independent test**: with a request waiting, accept it and confirm she becomes readable —
and that before accepting, nothing of hers was.

**Depends on**: US1 and US2. **This is the biggest phase by a wide margin**, and most of
it is not the accepting — it is the five queries that cannot survive the tightened rules.

### Locks for the boundary ⚠️ write first, see red

- [X] T027 [P] [US3] Lock F3 in `firebase/test/reglas_frontera.test.js`: with a request waiting, the coach reads **nothing** of hers — not a record, not a macrocycle, not a plan, not a feedback request, not her profile beyond what the request carries
- [X] T028 [P] [US3] Lock F4 in `firebase/test/reglas_frontera.test.js`: once accepted, what she wrote **before** he accepted is readable. The membership says who may read it, not since when it exists
- [X] T029 [P] [US3] Lock F2 for `nadadores` in `firebase/test/reglas_frontera.test.js` **using the query the app makes** — filtered by `comunidadId` — and assert that the unfiltered query is **refused**, not filtered
- [X] T030 [P] [US3] Lock F2 for `registros` the same way in `firebase/test/reglas_frontera.test.js`
- [X] T031 [P] [US3] Lock F2 for `macrociclos` the same way in `firebase/test/reglas_frontera.test.js`
- [X] T032 [P] [US3] Lock F2 for `planes` and `asignaciones` the same way in `firebase/test/reglas_frontera.test.js`
- [X] T033 [P] [US3] Lock F2 for `peticiones` (feature 008) and `peticionesDeFeedback` (feature 010) the same way in `firebase/test/reglas_frontera.test.js`
- [X] T034 [P] [US3] Lock F6 in `firebase/test/reglas_frontera.test.js`: **no client writes `comunidadId`** — not the coach on her profile, not the swimmer on her own
- [X] T035 [P] [US3] Lock F8 in `firebase/test/reglas_frontera.test.js`: a minor with a membership and **no valid consent** still has nothing leave the device. The two gates compose; neither replaces the other
- [X] T036 [US3] Run the negative control for T027–T035 and record it in `specs/012-coach-swimmer-link/tasks.md`, with the number that passes against a collection with no rule

**T036 — the negative control for the boundary suite, run on 2026-11-19.** The suite was
pointed at collections with no rule (`nadadores_sin_regla`, `registros_sin_regla` and the
rest, a copy of the file with the names suffixed, deleted afterwards). Result: **11 of 18
passed against collections that had no rule at all.** The 7 failures were every test that
asserts a success, including the two that assert one before doing anything else. So the
suite notices a missing rule, and it notices it through its positive half only — the
eleven refusals pass for free, exactly as the 008 lesson says. The four collections added
later (T031–T033) brought the suite to 26 tests.

**T046 — what the tightening broke, and why that is the point.** With the six collections
tightened, **16 tests in five other suites went red at once**, all of them coach-side
assertions whose seeds never said who the swimmer belonged to — because until today
nothing asked. Fifteen were fixed by seeding the membership (folded into
`sembrarVinculos`, `sembrarMacrociclo` and `darDeAlta` so the next one does not have to
remember). The sixteenth, «el entrenador lista la coleccion entera, para saber quien tiene
uno» in `reglas_macrociclos.test.js`, was **inverted**: it bought feature 008's decision
D10 on purpose and warned in its own text what the day it fell would cost. That day is
today. Final: **223 of 223**.

**What `planes` could not be given, and why.** Five of the six collections are closed by
membership. `planes` is not: a plan carries no owner. It carries `nadadoresIds`, which is
empty in a draft — and a draft is exactly what its author has to be able to read — so the
rule has nothing to ask. Giving a plan an `entrenadorId` would be a new field over
documents that **already exist in production**, which is a migration, and research D5 says
this feature does not write code for a population it cannot test against; unlike swimmers,
real plans do exist. What leaks is the coach's training design, not a fact about her: who
was given which plan lives in `asignaciones`, and that is closed. **Her boundary is
complete; his is half.** The limitation is asserted, not hidden, in
`reglas_frontera.test.js` — «los planes siguen siendo de cualquier entrenador, y esto lo
declara» — and the day a plan has an author, that is the first test that falls.

### FR-018 — the inversion, and what it costs the suite

- [X] T037 [US3] Invert the second-coach test in `firebase/test/reglas_analisis.test.js`: it asserts today that another coach **succeeds** in reading this swimmer, and says in its own text that it is waiting for this day. Rewrite the comment to say what happened rather than deleting the history
- [X] T038 [US3] Re-run that suite's negative control and record the new numbers in `specs/012-coach-swimmer-link/tasks.md`. It used to be **5 of 10 passing against a collection with no rule, every failure an `assertSucceeds`** — and the inverted test was one of those five
- [X] T039 [US3] If T038 shows the suite got worse at noticing a missing rule, add the `assertSucceeds` this feature can honestly make — **a coach reading his own swimmer must succeed** — in `firebase/test/reglas_analisis.test.js`, and record that it was needed

**T038/T039 — the analysis suite's negative control, re-run on 2026-11-19.** It used to be
**5 of 10 passing against a collection with no rule, every failure an `assertSucceeds`**.
It is now **7 of 11, with 4 failures, still every one an `assertSucceeds`**. The suite got
worse at noticing a missing rule, and by two, not one: this feature inverted *two* of
those five — the second coach reading another's swimmer (FR-018) and the whole-collection
read that the boundary makes impossible. T039's compensating assertion was therefore
needed and is in place: «y el suyo SI la lee: la frontera no es que no funcione nada»,
which says something the suite could not say before — that membership **lets him read**,
not only that it stops others. Without it the suite would be down to three.

### The five queries that read everything (research D2)

- [X] T040 [US3] Rewrite the swimmer list in `lib/datos/firestore/repositorios_firestore.dart` to filter by `comunidadId`. This one comes first because the other four are expressed in terms of **his swimmers**, and this is where he gets them
- [X] T041 [US3] Rewrite `nadadoresConRegistros` in `lib/datos/firestore/registros_firestore.dart` to be scoped to his swimmers. **Record how many queries it now costs** with the seeded group: feature 007's decision D10 bought "one query" on purpose, and this trade is made with its eyes open
- [X] T042 [US3] Rewrite `macrocicloPorNadador` in `lib/datos/firestore/macrociclos_firestore.dart` the same way
- [X] T043 [US3] Rewrite the plan requests query in `lib/datos/firestore/peticiones_firestore.dart` the same way
- [X] T044 [US3] Rewrite the assignments query in `lib/datos/firestore/repositorios_firestore.dart` the same way
- [X] T045 [US3] Fix the comment in `lib/datos/firestore/registros_firestore.dart` that already claims «las reglas le dejan leer los registros de su comunidad». It has been describing this feature for two features; make it true rather than aspirational

**T041 — what the five queries now cost.** All five are expressed in terms of his
swimmers, so a new piece answers that once: `lib/datos/firestore/mis_nadadores.dart`, one
query filtered by `comunidadId`, **with no memory on purpose**. Caching the list would
save three queries per HUB refresh and would let a coach who has just accepted someone
refresh and not see her — a bad trade on the one fact this feature makes change by hand.

Per call: **1 query for the list + 1 per batch of 30** (`whereIn` takes 30). With the
seeded group, **two**. With thirty swimmers, two. With sixty, three. Feature 007's
decision D10 bought «one query» to avoid **N**; this is not N, and that is the whole
argument. A HUB refresh makes four such calls, so 8 queries where it used to make 4 — at
this scale the same answer feature 004 gave about the consent gate: irrelevant.

One thing the rules forced: the queue over `peticionesDePlan` filters by the `nadadorId`
**field**, not the document id, because in a `list` the path wildcard is not bound and the
rule died with «Null value error» over the whole queue. `firestore.rules` splits `get` from
`list` there for that reason, and says so.

### The rules and the server

- [X] T046 [US3] Add the membership helper to `firebase/firestore.rules` — "is this swimmer in my community" — and tighten the six collections per [contracts/la-frontera.md](./contracts/la-frontera.md)
- [X] T047 [US3] Add `comunidadId` and `miembroDesde` to `lib/dominio/entidades/nadador.dart` and its serialisation in `lib/datos/serializacion.dart`, absent meaning she belongs to nobody — **no "pending" value**, because pending is a property of the request (data-model.md)
- [X] T048 [US3] Write `aceptar` in `firebase/functions/src/comunidad.ts`: it checks the caller owns that community, writes the membership and closes the request **as one act**. Half an accept is a swimmer who belongs to nobody with no request left to show for it (research D4)
- [X] T049 [P] [US3] Write `rechazar` in `firebase/functions/src/comunidad.ts`: closes the request, carries no written reason, and does not prevent her asking again (FR-012)
- [X] T050 [US3] Export both from `firebase/functions/src/index.ts` and lock them in `firebase/functions/test/comunidad.test.js`: a coach cannot resolve a request for a community that is not his, and resolving one that is no longer waiting does nothing and says so
- [X] T051 [US3] Put the request where things already wait for him, in `lib/ui/hub/cola_del_entrenador.dart`, showing who asked and when (FR-009)
- [X] T052 [US3] Tell her either way in `lib/ui/alta/estado_alta.dart` and the swimmer's screens, and make a declined request not block her from asking again (FR-010, FR-012)

**Checkpoint**: the feature exists. A second coach reads nothing of another's swimmer, and
the rules suite proves it with the queries the app makes.

---

## Phase 6: User Story 4 — While she waits, she is not left in the dark (Priority: P2)

**Goal**: the screen where her plan would be tells her where she stands.

**Independent test**: with a request waiting, open the app as her and confirm she is told.

**Depends on**: US2 for a waiting request to exist.

### Locks for User Story 4 ⚠️ write first, see red

- [X] T053 [P] [US4] Lock the four cases in `test/ui/nadador/donde_estoy_test.dart`: she has a plan; she has none and belongs; she has none and is waiting; she has none and never asked. **Four answers to two independent questions**, and none of them is "no tienes plan" when she is waiting (research D6)
- [X] T054 [P] [US4] Lock that the waiting state is **not** a fifth `Lectura` case, in `test/dominio/lectura/lectura_test.dart`: waiting is a fact about her that explains why the reading found nothing, not a state of the reading. Adding it to that type would repeat feature 011's defect in a new costume
- [X] T055 [US4] Run the negative control for T053–T054 and record it in `specs/012-coach-swimmer-link/tasks.md`: make the screen treat "waiting" as "no plan" and confirm T053 goes red

### Implementation for User Story 4

- [X] T056 [US4] Ask the second question — does she belong to a community, and is she waiting — in `lib/ui/nadador/estado_nadador.dart`, beside the `Lectura` that feature 011 added and **not inside it**
- [X] T057 [P] [US4] Choose the empty state accordingly in `lib/ui/nadador/pantalla_mi_progreso.dart`
- [X] T058 [P] [US4] Do the same in `lib/ui/nadador/pantalla_sesion_del_dia.dart` and `lib/ui/nadador/mi_macrociclo.dart`. Three screens carry this now; fixing two is leaving one for the next walk
- [X] T059 [US4] Make the waiting notice disappear when the membership begins in `lib/ui/nadador/estado_nadador.dart`, without her doing anything to clear it (FR-022)

**T055 — the negative control, run on 2026-11-19.** `SinPlanTodavia` was made to answer
`Esperando` with the generic "todavía no tienes un plan asignado", exactly the bug this
story exists to fix. **3 of the 10 locks went red**, and they were the right three: the
waiting notice in `Mi progreso`, the same in the session of the day, and FR-022's "it goes
away on its own". The other seven stayed green, which is also correct — they are about the
three cases this control did not break. Restored, 10 of 10.

**What US4 cost, and what it did not.** The fix is one widget, `lib/ui/nadador/sin_plan_todavia.dart`,
because the sentence it replaces lived copied in three screens and feature 011 had already
had to fix it in two at once — leaving a note that fixing one and not the other is leaving
it for the next walk. Now there is one place. The third screen, `mi_macrociclo.dart`,
needed no change at all: with no macrocycle it shows the session of the day, so the notice
reaches it through there. That is a property of deciding the empty state in one place
rather than a coincidence, and the comment there says so.

**Checkpoint**: a waiting swimmer is never shown something false.

---

## Phase 7: User Story 5 — Leaving, and being let go (Priority: P3)

**Goal**: a relation that can be ended from either side, with nothing of hers lost.

**Independent test**: end a membership from each side and confirm he stops reading her
while her own history is untouched.

**Depends on**: US3 for a membership to end.

### Locks for User Story 5 ⚠️ write first, see red

- [X] T060 [P] [US5] Lock F7 in `firebase/test/reglas_frontera.test.js`: after either side ends it, the coach's next query returns nothing of hers — **and nothing she wrote is deleted, hidden or altered**
- [X] T061 [P] [US5] Lock the two calls in `firebase/functions/test/comunidad.test.js`: a coach cannot remove a swimmer who is not his, and a swimmer cannot leave a community she does not belong to
- [X] T062 [US5] Run the negative control for T060–T061 and record it in `specs/012-coach-swimmer-link/tasks.md`

### Implementation for User Story 5

- [X] T063 [P] [US5] Write `sacar` and `salir` in `firebase/functions/src/comunidad.ts`, and export them from `firebase/functions/src/index.ts`
- [X] T064 [P] [US5] Give the coach the control in `lib/ui/nadadores/pantalla_perfiles.dart`, asking first, because it is not undoable from his side
- [X] T065 [P] [US5] Give her the control where she governs her own account, in `lib/ui/ajustes/pantalla_ajustes.dart`
- [X] T066 [US5] Tell her when she has been removed (FR-026) in `lib/ui/nadador/estado_nadador.dart` and the screens that read it

**T062 — the negative control for US5, run on 2026-11-19.** The ownership check in
 was removed ( → ). **3 of
the 15 function locks went red**, and exactly the three that assert a refusal: a coach
removing somebody who is not his, leaving a community you do not belong to, and leaving
twice. The twelve that assert something succeeds stayed green, which is the point — the
control proves these three are testing the check and not the happy path. Restored, 15/15.

**What leaving costs, measured.** The lock asserts it field by field: after the membership
ends her profile keeps its name and category, her record keeps its  and her
own , and the only things gone are  and . That
is guarantee F7 as an assertion rather than a sentence.

**One widget for both sides.**  serves the
coach removing somebody and the swimmer leaving, because the decision is symmetric and two
copies would be two places where that can stop being true. Only the words differ: he stops
**seeing**, she stops **receiving**.

**T062 — the negative control for US5, run on 2026-11-19.** The ownership check in
`terminarPertenenciaDe` was removed (`if (esDe !== comunidadId)` → `if (false)`). **3 of
the 15 function locks went red**, and exactly the three that assert a refusal: a coach
removing somebody who is not his, leaving a community you do not belong to, and leaving
twice. The twelve that assert something succeeds stayed green, which is the point — the
control proves those three test the check and not the happy path. Restored, 15/15.

**What leaving costs, measured.** The lock asserts it field by field: after the membership
ends, her profile keeps its name and category, her record keeps its `rpePercibido` and her
own `observaciones`, and the only things gone are `comunidadId` and `miembroDesde`. That is
guarantee F7 as an assertion rather than a sentence.

**One widget for both sides.** `lib/ui/comunidad/terminar_la_pertenencia.dart` serves the
coach removing somebody and the swimmer leaving, because the decision is symmetric and two
copies would be two places where that can stop being true. Only the words differ: he stops
**seeing**, she stops **receiving**.

**And a sixth query that read everything, found on the way.** `quienesReportaron` in
`lib/datos/firestore/molestias_firestore.dart` read all of `registros`, and research D2
counted five because this one lives in another file. It would have been the worst of the
six: its `catch` returns the empty set, so with the boundary tightened it would have
answered "nobody reported any discomfort" **for ever, with nothing failing and nobody
noticing**. It is scoped now, and the comment above it that claimed the coach reads "the
records of his community" — written four features before any community existed — says what
it actually does.

**Checkpoint**: all five stories work.

---

## Phase 8: Polish & Cross-Cutting

- [X] T067 Run the four gates and write the numbers beside T001's baseline in `specs/012-coach-swimmer-link/tasks.md`. **The rules number is the one to look at**: a boundary feature whose rules suite barely grew is a boundary that is not being tested

**After, 2026-11-19:**

| Gate | Before | After | Grew by |
|---|---|---|---|
| `flutter analyze` | No issues | No issues | — |
| `flutter test` | 2202 | **2288** | +86 |
| `npm --prefix firebase test` | 174 | **224** | **+50** |
| `npm --prefix firebase/functions test` | 45 | **66** | +21 |

**The rules number is the one this task said to look at, and it is +50 — a 29% bigger
suite.** That is what a boundary feature should do to it. Of those, 27 are the new
`reglas_frontera.test.js`, which exercises **the queries the app makes** rather than
`get` by id, and the rest are the six collections' existing suites learning to say who a
swimmer belongs to.

What the number does not show, and matters as much: **16 existing tests went red** when the
rules were tightened, and one of them had to be inverted rather than fixed. A suite that
had not noticed would have been the warning sign.

- [X] T068 Confirm `git diff pubspec.yaml pubspec.lock` is empty — principle VII's check, not a memory

**Empty.** No new dependency for any of this: the five rewritten queries, the boundary, the
four server calls and the three screens are built out of what the project already had.
`whereIn` batching is thirty lines of Dart in `mis_nadadores.dart` rather than a package.
- [X] T069 Walk [quickstart.md](./quickstart.md) V0 to V9 on the emulators and record what each showed in `specs/012-coach-swimmer-link/tasks.md`, V5 and V9 above all

**Walked on 2026-11-19. The table of what each step showed is in
[quickstart.md](./quickstart.md).** V5 is the one worth repeating: signed in as the second
coach, `Análisis` lists **one** swimmer, his own, and none of the other coach's eight.

**And the walk found four things the suites did not** — every one of them a screen saying
something false, and none of them a boundary bug:

1. **A fourth screen said «todavía no tienes un plan».** `home_del_nadador.dart` carried
   its own copy with slightly different words, and it is the **first screen she sees**. The
   US4 locks mounted the two screens the spec names. With the waiting notice already wired
   into those two, her HOME was still telling her to wait for a plan from a coach who was
   not hers.
2. **His queue said «Alguien que todavía no tiene perfil».** F3 and FR-009 collide head on:
   he may not read her profile before accepting, and he must see who asked. Both are only
   true if **the request carries her name**, which it now does. Without the walk this ships
   asking him to decide about a stranger.
3. **The sign-up promised a door that did not exist.** Its last step says «puedes pedirlo
   más adelante desde Ajustes», and Settings had nothing for somebody who skipped the step
   or was turned down — so FR-005 and FR-012 had no path at all after sign-up.
4. **Two screens did not notice their own changes.** `Análisis` caches its roster in
   `initState`, so a swimmer just accepted did not appear until restart; and the HUB did
   not rebuild on `dondeEsta`, so after she left, Settings kept saying she belonged.

- [X] T070 [P] Write the 012 paragraphs in `docs/ROADMAP.md` to say what was built, the way 009, 010 and 011 did — including what the five rewritten queries cost
- [X] T071 [P] Record in `specs/012-coach-swimmer-link/tasks.md` what feature 013 now inherits: a membership exists, so "who may watch a swimmer's video" finally has somewhere to get its answer

**What 013 inherits.** "Who may watch a swimmer's video" was a question with no place to
get an answer. Now it has one, and it is a single predicate: `esDeMiComunidad()` in
`firebase/firestore.rules`, the same one the six tightened collections use — so video does
not invent a seventh way of asking.

Three things it no longer has to settle for itself:

- **Membership lives in one place**, so revoking it cuts access to the video on the next
  query instead of needing a sweep over whatever was shared.
- **A query is proved by its filters**, which is now established with six collections' worth
  of evidence: the listing of a swimmer's videos will carry her id or be refused entire.
- **The consent gate composes rather than being replaced.** `Alcance.video` still decides
  whether the file may exist at all; membership decides only who may watch one that may.
  Feature 004 modelled that scope precisely so this day would not mean asking the families
  again, and 012 does not spend it.

What it does **not** inherit: a plan boundary. `planes` stays readable by any coach, for
the reason recorded above, so anything 013 hangs off a plan rather than off a swimmer
inherits that hole.

- [X] T072 Re-read the Constitution Check table in [plan.md](./plan.md) against what was actually built and correct it if anything drifted. A gate that is only true at planning time is not a gate

**Done, in [plan.md](./plan.md).** Every row holds; three got stricter in the building, and
one gate failed and is recorded rather than hidden — `planes` could not be brought inside
the boundary.
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
