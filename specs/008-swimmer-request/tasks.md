---

description: "Task list for feature 008 — The swimmer's request"
---

# Tasks: The swimmer's request

**Input**: Design documents from `/specs/008-swimmer-request/`

**Prerequisites**: [plan.md](./plan.md), [spec.md](./spec.md), [research.md](./research.md),
[data-model.md](./data-model.md), [contracts/peticion_de_plan.md](./contracts/peticion_de_plan.md)

**Tests**: **required, and not as an afterthought.** Principle III of the constitution is
non-negotiable: every new or changed domain rule arrives with tests covering the typical case
and at least one boundary, and the Firestore rules are tested against the emulator including
negative cases. This feature adds one training rule — the ATR phase derivation — and one new
path off a minor's device, so **every lock is written before the thing it guards and verified
with a negative control**: see it fail first, or it is not a lock.

**Organization**: grouped by user story so each can be implemented and tested on its own.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: can run in parallel (different files, no dependencies)
- **[Story]**: which user story the task belongs to (US1, US2, US3, US4)
- Exact file paths in every description

## Path Conventions

Flutter app at the repository root, as the previous seven features: pure domain in
`lib/dominio/`, Firebase in `lib/datos/`, screens in `lib/ui/`, tests mirroring under `test/`.
Server in `firebase/functions/`, access rules in `firebase/firestore.rules`.

---

## Phase 1: Setup

**Purpose**: the places the new code will live, and nothing else

- [X] T001 Create `lib/dominio/peticiones/` and `test/dominio/peticiones/`, empty, so the pure domain has its folder before anything reaches for it
- [X] T002 [P] Create `lib/ui/peticion/` and `test/ui/peticion/`
- [X] T003 [P] Add the four-week window as a named constant `ventanaDeMolestias` in `lib/dominio/peticiones/peticion.dart`, with the comment that the number is declared by the spec and not fixed by the methodology, so that changing it is one edit and one test

**Checkpoint**: folders exist. No behaviour yet.

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: the training rule, the types, and **the access rules** — everything a user story
would otherwise be built on top of before it is guarded

**⚠️ CRITICAL**: no user story work begins until this phase is complete. Two of these tasks
exist specifically so that no screen that writes is built before the rule that stops it writing
in someone else's name.

### The derivation, test first

- [X] T004 Write `test/dominio/peticiones/fase_por_fecha_test.dart` **before any implementation**, covering: 15 days → `realizacion`, 16 → `transformacion`, 43 → `transformacion`, 44 → `acumulacion`, 1 → `realizacion`, a date today → no phase, a date in the past → no phase, null → no phase, and a category with `usaAtr == false` → no phase whatever the date (P21, P22, P23)
- [X] T005 Run T004 and **see every case fail**. A lock that was never red is not a lock; record in the commit that it was seen failing
- [X] T006 Implement `lib/dominio/peticiones/fase_por_fecha.dart` as a total function of (competition date, today, `Categoria`) returning `FaseDerivada`, with the boundaries from research D3: 1-15 → Realización, 16-43 → Transformación, 44+ → Acumulación, and no phase for 0, past, null, or `usaAtr == false`
- [X] T007 [P] Write `test/dominio/peticiones/componente_por_fase_test.dart` asserting that the component derived from each phase **passes `ValidacionPeticion`'s coherence check** — in particular that Acumulación never yields a speed component, which that check rejects (P25). Negative control: hand it a speed component in Acumulación and see the check reject it
- [X] T008 Implement `lib/dominio/peticiones/componente_por_fase.dart` drawing each component from `FaseAtr.objetivos`, and from the category's emphasis when there is no phase
- [X] T009 Add `FaseDerivada` to `lib/dominio/peticiones/peticion.dart` with `fase`, `diasHastaLaCompetencia` and a `porQue` that is **always present and always readable** — «Transformación, porque tu competencia es en 24 días» or «Sin fase: no hay fecha de competencia» (data-model.md)

### The types

- [X] T010 [P] Write `test/dominio/peticiones/peticion_test.dart` for the invariants of `PeticionDePlan`: `rechazada` without a non-empty reason is not constructible, `aprobada` implies `planId != null`, and `esperando` implies `respondidaEn == null` and `motivoDelRechazo == null`. Each with a negative control that constructs the forbidden state and expects the throw
- [X] T011 Implement `PeticionDePlan` and `EstadoDePeticion` in `lib/dominio/peticiones/peticion.dart` with the four states `esperando` → `enRevision` → `aprobada` | `rechazada`, their Spanish wording from data-model.md, and the invariants from T010
- [X] T012 [P] Write `test/dominio/peticiones/respuestas_test.dart` for `RespuestasDePeticion`, quoting the constraints verbatim from data-model.md: `pruebaObjetivo` non-empty after trimming, `diasDisponibles` at least one and **no duplicate days**, `duracionSesionMinutos` between 30 and 180, `longitudPiscina` exactly 25 or 50, `fechaDeCompetencia` nullable because «no lo sé» is a valid answer
- [X] T013 Implement `RespuestasDePeticion` in `lib/dominio/peticiones/peticion.dart` with those constraints
- [X] T014 Add a `RepositorioPeticiones` interface to `lib/dominio/repositorios/repositorios.dart` — read mine, read the coach's queue, send, close — expressed in domain types only, with no Firestore vocabulary (principle II)
- [X] T015 Add a nullable `peticionId` to `Plan` in `lib/dominio/entidades/plan.dart`, leaving `OrigenPlan` untouched (research D5), and extend the existing plan tests to assert that a draft with `peticionId == null` behaves exactly as it does today

### The access rules, before anything writes

- [X] T016 Write the rules tests in `firebase/test/` for `peticionesDePlan` **before touching `firestore.rules`**: a swimmer creates their own and **cannot** create one named after another swimmer (P11); a swimmer with an open request **cannot** create a second (P12); no client can write `enviadaEn`, `estado`, `respondidaEn` or `planId`, field by field (P13); the coach reads any, writes none; a swimmer reads only their own
- [X] T017 Run T016 and see it fail — with no rule for the collection, Firestore denies by default, so **assert the specific denials and the one permitted create**, otherwise the test passes for the wrong reason
- [X] T018 Add `match /peticionesDePlan/{nadadorId}` to `firebase/firestore.rules`, with the document id equal to the swimmer id (research D6) so the one-at-a-time limit is enforced by the rule and not by the screen, plus `match /historial/{peticionId}` as server-write-only
- [X] T019 Verify that nothing in the new rules widens `registros`: the coach already reads his community's records (`firebase/firestore.rules` line 222) and this feature needs no more than that (research D7)

### The HUB slot

- [X] T020 Change the swimmer's `Generar` branch in `reparto` in `lib/dominio/hub/destino.dart` from `TodaviaNo` to a content value, and update `test/dominio/hub/` so the total-function test covers the new pair. The five destinations and their labels do not change — feature 007's label-fitting lock must stay green untouched

**Checkpoint**: the rule is derived and tested, the types hold their invariants, and **no client
can write a request it should not**. User stories can begin.

---

## Phase 3: User Story 1 — The swimmer asks, and what comes out is a draft (Priority: P1) 🎯 MVP

**Goal**: a swimmer answers six questions and a request arrives. No plan appears anywhere.

**Independent Test**: with a swimmer account, answer the list, send, and check the request is
recorded while no new plan and no new session appear on any of the swimmer's five destinations.

### Tests for User Story 1 ⚠️

> Written first, seen failing first.

- [X] T021 [P] [US1] Write `test/ui/peticion/lista_de_preguntas_test.dart`: the list asks exactly six things and no more (P1), stroke and event arrive pre-filled from the record (P2), **nothing requires free text** (P3), «No lo sé» is a valid date answer and does not block sending (P4), and the app never asks for category, ATR phase, accentuated component, technical diagnosis or discomfort — five absences, each asserted by searching the screen for the question (P6)
- [X] T022 [P] [US1] Write `test/ui/peticion/sin_ficha_test.dart`: a swimmer with no record, or whose record lacks a category or a target event, is told their coach has to complete it and is **not** shown a list that cannot lead to a draft (P7)
- [X] T023 [P] [US1] Write `test/dominio/peticiones/nada_llega_al_nadador_test.dart`: sending a request produces no assignment, no session and no plan visible to the swimmer (P18, FR-012), asserted over the repositories rather than over a screen
- [X] T024 [US1] Run T021-T023 and record that they fail

### Implementation for User Story 1

- [X] T025 [P] [US1] Implement `lib/datos/firestore/peticiones_firestore.dart` against `RepositorioPeticiones`, writing only the fields the client is allowed to write and letting the server set the rest (P13)
- [X] T026 [P] [US1] Store the half-answered list through the existing `AlmacenLocal` in `lib/datos/local/repositorios_locales.dart`, so the list is answerable offline and survives closing the app (P5)
- [X] T027 [US1] Implement `lib/ui/peticion/lista_de_preguntas.dart` with the six questions in the order of research D10 — stroke, event, competition date, days, duration, pool — all answerable by tapping, with the stroke and event pre-filled from the record
- [X] T028 [US1] Wire the swimmer's `Generar` destination to the list in `lib/ui/hub/contenidos.dart`, replacing the "todavía no" content
- [X] T029 [US1] Make the app refuse to send while an input the engine needs is missing, saying **which** one (FR-004), without using the error colour — feature 005's FR-016 lock allows it in two screens only
- [X] T030 [US1] Add `hub — nadador con petición` to the screen bench in `test/ui/tema/ayuda_pantallas.dart` so the new screens are measured at 200%, in tappable areas and in dark, like every other screen (feature 005's A15 lock)

**Checkpoint**: a swimmer can ask. Nothing of theirs changed except that they asked.

---

## Phase 4: User Story 2 — The coach's queue (Priority: P1)

**Goal**: the coach sees what was asked, the draft appears when he opens it, and he corrects,
rejects with a reason, or approves.

**Independent Test**: with a seeded request, the coach opens it, rejects it with a reason, and
the swimmer reads that reason.

### Tests for User Story 2 ⚠️

- [X] T031 [P] [US2] Write `test/ui/hub/cola_del_entrenador_test.dart`: the queue shows who asked, when, the six answers and the draft (P27); it distinguishes what awaits an answer from what has been answered (FR-024); and with no connection it shows the cache **and says the latest may be missing**, rather than an empty queue that reads as "no requests" (P32)
- [X] T032 [P] [US2] Write `test/dominio/peticiones/generacion_desde_peticion_test.dart`: the draft is born `borrador`, carries `OrigenPlan.automatico`, the request id and the methodology version (P17); and **generating twice from the same stored request produces the same draft** — generated twice and compared, never compared against a fixture, because a fixture would hide an input read from the clock (P20)
- [X] T033 [P] [US2] Write `test/dominio/peticiones/sin_fecha_no_hay_borrador_test.dart`: with no usable competition date and a category that uses ATR, **no draft is generated** and the request reaches the queue with the phase pending (P24, FR-018)
- [X] T034 [P] [US2] Write `test/ui/hub/rechazo_con_motivo_test.dart`: rejecting with an empty reason is **impossible, not discouraged** (P29), and the reason the coach wrote is what the swimmer reads, as written (P30)
- [X] T035 [P] [US2] Write `test/ui/hub/auditoria_antes_de_firmar_test.dart`: a draft that fails the section 16 audit cannot be approved, and the coach sees which criteria are missing — **the same audit as his own plans, not a lighter one** (P19)
- [X] T036 [US2] Run T031-T035 and record that they fail

### Implementation for User Story 2

- [X] T037 [US2] Implement the generation from a request in `lib/dominio/peticiones/`: build a `PeticionGeneracion` from the stored answers, the swimmer's record (category, technical diagnosis) and the derived phase and component, and call the existing deterministic engine — **no language model touches any field** (P14)
- [X] T038 [US2] Implement `lib/ui/hub/cola_del_entrenador.dart` inside the coach's existing `Generar`, generating the draft **when he opens the request** (research D1) so it never exists on the swimmer's device
- [X] T039 [US2] Show the derived phase with its reason in days, and let the coach change it in one tap, regenerating the draft from the changed phase (P26, FR-017)
- [X] T040 [US2] Show the linked discomfort **with its dates**, read from `registros` through `lib/datos/firestore/registros_firestore.dart`, and say explicitly when the window holds none (P33, P34)
- [X] T041 [US2] Open the draft in the existing editor with the existing audit, so correcting a request's draft is the same act as correcting his own plan (P28)
- [X] T042 [US2] Make `enRevision` the state once he opens it, moved by him and by nothing else — no elapsed time, no other automatic rule (P31, FR-023)

**Checkpoint**: the coach can work the queue. Nothing has reached a swimmer.

---

## Phase 5: User Story 4 — The minor's gate, here too (Priority: P1)

**Goal**: a minor without valid consent sends nothing off the phone, and the app says so instead
of pretending it was sent.

**Independent Test**: with a swimmer who has no valid consent, answer the list and send, then
check **against the server** that nothing arrived, and that the app said why.

### Tests for User Story 4 ⚠️

- [X] T043 [P] [US4] Write `test/dominio/peticiones/puerta_del_menor_test.dart`: with the consent gate closed, a request does not leave; with it open, what was held leaves **without being written again** (P9, P10). Negative control: a gate that always opens, and see the held case fail
- [X] T044 [P] [US4] Write `test/ui/peticion/falta_la_autorizacion_test.dart`: the app says the guardian's authorisation is missing and **nowhere says the request was sent** — asserted by searching the screen for any wording that claims it was
- [X] T045 [US4] Run T043-T044 and record that they fail

### Implementation for User Story 4

- [X] T046 [US4] Send through the existing outbox and consent gate — `BandejaDeSalida` plus `PuertaDeConsentimiento`, which `Sincronizador` already consults — and **create no third path off the device** (P8, research D8)
- [X] T047 [US4] Decide in code, with a comment that says why, whether `Sincronizador` is generalised beyond session records or mirrored for requests, and keep the decision in one file so it can be reversed. Do not add a state to `EstadoDeEnvio`: a request held for lack of consent **is** a pending request, exactly as feature 003's decision D6 concluded for records
- [X] T048 [US4] Make erasure take the requests with it in `firebase/functions/src/datos_personales.ts`, including the `historial` subcollection, with its test in `firebase/functions/test/datos_personales.test.js` (P37, FR-033)

**Checkpoint**: the new path off the device is as guarded as the one that already existed.

---

## Phase 6: User Story 3 — The swimmer sees where theirs stands (Priority: P2)

**Goal**: the swimmer reads the state of what they asked for, with no promised dates.

**Independent Test**: move a request through its four states and check the swimmer reads each
one, with no invented dates.

### Tests for User Story 3 ⚠️

- [X] T049 [P] [US3] Write `test/ui/peticion/estado_de_mi_peticion_test.dart`: each of the four states reads in Spanish without jargon (FR-025), a rejection shows the coach's reason (FR-026), and **no answer date is promised in any state** — asserted by searching for date-like wording, not by eye (FR-027)
- [X] T050 [P] [US3] Write `test/ui/peticion/el_borrador_no_se_asoma_test.dart`: in no state before approval does any part of the draft's content appear on the swimmer's screens (P16)
- [X] T051 [US3] Run T049-T050 and record that they fail

### Implementation for User Story 3

- [X] T052 [US3] Implement `lib/ui/peticion/estado_de_mi_peticion.dart` with the four states and the rejection reason
- [X] T053 [US3] Show, when a request is waiting, that another cannot be sent yet and why (FR-032), as information rather than as an error

**Checkpoint**: all four stories work independently.

---

## Phase 7: The server call

**Purpose**: closing a request is the server's write, because a client that can write its own
state can approve its own request

- [X] T054 Write `test/datos/servidor/contrato_de_peticiones_test.dart` **before the call exists**: a Dart test that reads the TypeScript source of `cerrarPeticion` and compares its field names against the body written in `contracts/peticion_de_plan.md` — flat, with `decision` exactly `"aprobada"` or `"rechazada"` (P39). This test exists because of feature 006: ten green tests of the guardian path, and the client sent flat what the server read nested
- [X] T055 Write `firebase/functions/test/peticiones.test.js` against the emulator: the call refuses anyone who is not the coach, refuses a `rechazada` with no reason, requires `planId` on `aprobada`, and archives the answered request to `historial` — each with a negative control (P38)
- [X] T056 Run T054-T055 and see them fail
- [X] T057 Implement `cerrarPeticion` in `firebase/functions/src/peticiones.ts` with the exact body from the contract, and export it from `firebase/functions/src/index.ts`
- [X] T058 Add `cerrarPeticion` to `lib/datos/servidor/operaciones.dart` — the only file in the project that may import `cloud_functions`, as its boundary test enforces

---

## Phase 8: Polish & Cross-Cutting Concerns

- [X] T059 [P] Extend `firebase/functions/tools/sembrar-emulador.js` with what the quickstart needs: a swimmer **without valid consent**, a swimmer in a category **without ATR**, and three requests with competition dates at 15, 16 and 44 days out so C8 can be walked without arithmetic by hand
- [X] T060 [P] Document the new collection and the derivation in `docs/DEVELOPMENT.md`, including that `peticionesDePlan` is deliberately not called `solicitudes` and why (research D2)
- [X] T061 Run the four gates and require all green: `flutter analyze`, `flutter test`, `npm --prefix firebase test`, `npm --prefix firebase/functions test`. **The Dart test count does not go down.** A test from an earlier feature that fails means this feature changed a behaviour it had no business changing: fix this feature, not that test
- [ ] T062 Walk C1 to C12 of [quickstart.md](./quickstart.md) in the browser against the emulators, with both accounts
- [ ] T063 Walk C12 on the Android emulator as well — it is the one that protects a minor, and feature 007 proved that four defects out of eight were only visible on a phone
- [ ] T064 [P] Mark feature 008 as merged in `docs/ROADMAP.md` once it is

---

## The coach's decisions

These are not implementation choices. Each one is the coach's judgement, written down because
principle IV says software does not make them.

- [X] T065 **Coach's confirmation**: the derivation boundaries. The app will read 1-15 days as Realización, 16-43 as Transformación, 44+ as Acumulación, taking the **upper bound** of each range Issurin gives, so a swimmer only falls into the earlier phase when past every published window for the later one. The alternative — lower bounds — would put a swimmer ten days out in Transformación, inside the published taper window. **Blocks T006**
- [X] T066 **Coach's judgement**: the four-week window for "recent discomfort". It covers one microcycle plus the previous one, and the methodology does not fix a number. Longer shows more and may show what is already resolved; shorter risks missing what matters. **Blocks T040**
- [X] T067 **Coach's criterion**: the exact Spanish wording of the four states, seen on a phone with his own swimmers' requests in front of him. The draft wording is «Esperando a tu entrenador», «Tu entrenador la está viendo», «Aprobada», «Tu entrenador respondió». If anything there sounds like a promise, it goes

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: no dependencies
- **Foundational (Phase 2)**: depends on Setup — **blocks every user story**. T016-T018 in
  particular block anything that writes
- **US1 (Phase 3)**: after Phase 2
- **US2 (Phase 4)**: after Phase 2. Reads what US1 writes, but is testable on a seeded request
- **US4 (Phase 5)**: after Phase 2 and the sending path of US1
- **US3 (Phase 6)**: after Phase 2. Testable against a seeded request in each state
- **Server call (Phase 7)**: after US2, which is what calls it
- **Polish (Phase 8)**: after everything it checks

### Two orders that are not negotiable

1. **T004 before T006, T016 before T018, and every other test before its implementation.** Each
   lock is run and **seen failing** first (T005, T017, T024, T036, T045, T051, T056). A lock
   that was never red proves nothing.
2. **The access rules (T016-T018) before any screen that sends (T027, T046).** P11, P12 and
   P13 are what stop one swimmer writing another's request and stop any client writing its own
   state. Building the screen first would mean a window where the only thing stopping it is the
   interface.

### Parallel Opportunities

- T002 and T003 in Setup
- T007 and T010 and T012 within Foundational, once T006 exists
- All of T021-T023, T031-T035, T043-T044 and T049-T050 — they are different test files
- T025 and T026 — different files, no shared state
- T059 and T060 and T064 in Polish

---

## Parallel Example: User Story 2

```bash
# The five locks of the coach's queue, written together:
Task: "cola_del_entrenador_test.dart — what the queue shows, and what it says when stale"
Task: "generacion_desde_peticion_test.dart — born borrador, and the same draft twice"
Task: "sin_fecha_no_hay_borrador_test.dart — no date, no draft, phase pending"
Task: "rechazo_con_motivo_test.dart — a rejection with no reason is impossible"
Task: "auditoria_antes_de_firmar_test.dart — the same audit as his own plans"
```

---

## Implementation Strategy

### MVP First (US1 only)

1. Phase 1: Setup
2. Phase 2: Foundational — **critical, and where most of the testing lives**
3. Phase 3: US1
4. **Stop and validate**: a swimmer can ask, and nothing of theirs changed
5. A request that nobody can answer yet is a smaller thing than it sounds: it already proves the
   gate, the rules and the list

### Incremental Delivery

1. Setup + Foundational → the rule is derived and the writes are guarded
2. US1 → a swimmer asks (MVP)
3. US2 → the coach answers. **The feature is useful from here**
4. US4 → the minor's gate. Walked against the server, not the screen
5. US3 → the swimmer sees where theirs stands
6. Phase 7 and 8 → the server's write, and the walk

### What to watch

- **Generating on demand must read only the stored answers and the record.** Any default read
  from the clock breaks P20 and SC-004 at once, and the determinism test is the only thing that
  would catch it
- **FR-038 is easy to break by accident** while building the queue: a convenience that copies
  the discomfort into the request duplicates a minor's health data. T040 reads; it does not
  write
- **Feature 007's locks stay green untouched**: the five destinations, the labels at 320 px,
  the screen bench, and the error colour in two screens only. If one of them goes red, this
  feature moved something it had no business moving

---

## Notes

- [P] = different files, no dependencies
- Every lock is seen failing before its implementation is written. That is not a ritual: in
  feature 007 the negative control is what proved four of the locks were watching the wrong
  thing
- `flutter test` green before any task is reported done (principle III)
- Commit after each task or logical group
