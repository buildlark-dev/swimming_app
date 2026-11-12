# Implementation Plan: Análisis and feedback

**Branch**: `010-analysis-and-feedback` | **Date**: 2026-11-11 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/010-analysis-and-feedback/spec.md`

## Summary

The methodology closes a loop — diagnose, model, programme, **control**, readjust — and
the product has built every step but control. The swimmer has been answering since
feature 003 and her answers have been written to the server ever since. Nobody has ever
read them back to the coach. His `Análisis` tab is a placeholder that promises exactly
this feature by number.

The approach is mostly connection rather than construction. The reader exists
(`RegistrosFirestore`, feature 007). The lineage walk exists (`registrosDelLinaje`,
feature 009). Adherence exists (`ProgresoEnElMacrociclo`, feature 009). Discomfort is
already a separate object rather than a flag. What is missing is a screen that assembles
them for the coach, and one new thing a swimmer can write: a question about a session.

Two findings from reading the code changed what the spec could promise, and both are
recorded rather than worked around: **there is no coach→swimmer link** (D1), and
**`Alcance.video` is invisible to the rules** (D2).

## Technical Context

**Language/Version**: Dart 3.12.2 / Flutter 3.44.2

**Primary Dependencies**: `provider`, `shared_preferences`, `cloud_firestore`,
`firebase_auth`. **No new dependency.** Principle VII requires naming the concrete problem
any addition solves, and nothing here has one.

**Storage**: Firestore for records and the new requests; the device store plus the
existing outbox for anything a swimmer writes.

**Testing**: `flutter test` for domain, data and widgets; rules tests against the
emulator; functions tests. The manual walk on the Pixel 7 is part of the definition of
done, not a nicety — see `quickstart.md`.

**Target Platform**: Android, iOS and web from one codebase.

**Project Type**: Mobile and web app with Firebase as the backend.

**Performance Goals**: A swimmer's reading assembles from one query per block rather than
one per session. Feature 008's decision D10 took the same shape for counting "en uso" and
the reason is unchanged: the number of swimmers grows.

**Constraints**: Writing never waits on the network (G1). A failed server read is
reported, never swallowed into an empty list. No figure may combine internal and external
load.

**Scale/Scope**: One coach, a handful of swimmers, a few hundred records each.

## Constitution Check

*GATE: before Phase 0, re-checked after Phase 1.*

| Principle | Before design | After design |
|---|---|---|
| **I — Methodology is normative** | The feature displays; it decides nothing | **Pass.** Adherence is read from feature 009's calculation, never recomputed (D6). A second calculation would be a second methodology by the back door |
| **II — Pure Dart domain** | At risk: the reading could easily be assembled inside a widget | **Pass.** `LecturaDelNadador` and `RespuestaASesion` are domain types with no Flutter import; the screen renders them |
| **III — Tests of the rules that reach the swimmer (NON-NEGOTIABLE)** | A new collection means new rules | **Pass, and more than planned.** 28 rules tests across two new suites — 18 for `peticionesDeFeedback`, 10 for the records the coach now reads — each with its negative control run and its numbers recorded in the file. The second suite was not planned: the rule it exercises has existed since feature 007 and nothing ever ran against it. One test asserts a boundary that is **not** enforced, and says so (FR-025) |
| **IV — The coach's judgement is not delegated** | At risk: a discomfort report invites a suggestion | **Pass.** FR-011 forbids proposing, scoring, ranking or triaging anything about it. The app shows what she wrote and stops |
| **V — Minors' data** | The heart of the feature: reading a minor's answers | **Pass, with one amendment.** Consent is a gate on creating a request (FR-027) and on exposing records (FR-026). Scope-aware checking arrives (D2). **FR-024 was amended** because "only his own swimmers" is not enforceable — the reason is recorded in the spec, not hidden |
| **VI — Honest freemium** | Reading your own history must never be paywalled | **Pass.** Nothing here is gated by payment |
| **VII — Vertical slices and simplicity** | At risk: video, a reply path and the coach link all beckon | **Pass.** No new dependency. Video is shaped and refused; no reply is built; the coach link is declared missing rather than invented |
| **VIII — Internal load control** | This feature *is* principle VIII | **Pass.** Discomfort apart (FR-009), nothing automatic (FR-011), the two loads side by side with **no type that holds both** (D8) |

### The amendment, stated plainly

FR-024 originally said a coach reads only his own swimmers. There is no such relation in
the product: `Nadador` has no owner and the rule says `esEntrenador()`. The constitution
describes a community led by *a* coach, singular, so the rule is right for what exists —
but the requirement could not be met, and leaving it would have put a promise in the spec
that no test could keep.

It is amended, the reason is in the spec next to it, and FR-025 requires a test that
states the boundary so the day a second coach exists, that test is the first thing that
fails. Feature 003 declared a limitation the same way and feature 004 closed it.

## Project Structure

### Documentation (this feature)

```text
specs/010-analysis-and-feedback/
├── plan.md              # This file
├── research.md          # Phase 0 — eight decisions, two of which changed the spec
├── data-model.md        # Phase 1
├── quickstart.md        # Phase 1 — the walk, on the Pixel 7
├── contracts/
│   └── lectura_y_peticion.md
├── checklists/
│   └── requirements.md
└── tasks.md             # /speckit-tasks, not created here
```

### Source Code (repository root)

```text
lib/
├── dominio/
│   ├── analisis/                      # new
│   │   ├── peticion_de_feedback.dart      # the request, its invariants, SePudoPedir
│   │   ├── lectura_del_nadador.dart       # the reading, assembled
│   │   └── respuesta_a_sesion.dart        # session + record, never merged
│   ├── repositorios/repositorios.dart     # + RepositorioPeticionesDeFeedback
│   ├── peticiones/molestias_enlazadas.dart    # + quienesReportaron (one query)
│   ├── macrociclo/registros_del_linaje.dart   # reused, untouched
│   └── hub/destino.dart                   # the coach's Análisis stops being TodaviaNo
├── datos/
│   ├── firestore/peticiones_feedback_firestore.dart   # new
│   ├── firestore/molestias_firestore.dart             # + quienesReportaron
│   ├── local/peticiones_feedback_locales.dart         # new — device first (G1)
│   ├── peticiones/peticiones_de_las_dos_partes.dart   # new — local + server
│   ├── memoria/repositorios_memoria.dart              # + the double
│   └── serializacion.dart                             # + the request
└── ui/
    ├── analisis/                      # new
    │   ├── pantalla_analisis.dart         # his swimmers, who reported discomfort
    │   ├── lectura_de_un_nadador.dart     # her sessions and answers
    │   └── sesion_y_respuesta.dart        # the two loads, side by side
    ├── nadador/pantalla_mi_progreso.dart  # + asking, + seeing that he looked
    ├── nadador/estado_nadador.dart        # + pedirFeedback, + the retry on sync
    └── hub/                           # wiring only

firebase/
├── firestore.rules                    # + peticionesDeFeedback, + scoped consent helper
├── test/reglas_peticiones_feedback.test.js    # new — 18 tests
└── test/reglas_analisis.test.js               # new — 10, over a rule nobody ran

test/
├── dominio/analisis/                  # the reading, the request, the invariants
├── datos/                             # the repository contract, both implementations
├── ui/analisis/                       # the coach's screens
└── ui/nadador/                        # asking, offline, and seeing that he looked
```

**Three files appeared that the plan did not name**, each for a reason worth
recording:

- `peticiones_de_las_dos_partes.dart` and `peticiones_feedback_locales.dart`,
  because G1 needs a device-first write and a retry. The outbox was **not**
  generalised: `BandejaDeSalida.encolar` takes a `registroId` and its transport
  sends a `RegistroDeSesion`, so making it carry two kinds of thing would have
  put feature 003's guarantees in play for a need a dedicated pending list
  covers. And only what is pending is retried — re-sending a request the coach
  already saw would wipe his `vistaEn`, which the phone's copy does not carry.
- `reglas_analisis.test.js`, because FR-010 needs the coach to see from the list
  who reported a discomfort, and writing that made it obvious that the rule
  letting him read his community's records had never been exercised by a test.
  One query, not one per swimmer — the shape of feature 008's decision D10.

**Structure Decision**: the existing layout, unchanged. Domain stays pure Dart; data holds
both a Firestore implementation and an in-memory double; UI renders domain types. The one
rule the project keeps relearning applies to the double: **it must refuse what Firestore
refuses.** Six of feature 009's seven defects were a double kinder than the server, so
`RepositorioPeticionesDeFeedbackMemoria` rejects a blank question, a non-null video and a
`marcarVista` that touches anything else.

## Complexity Tracking

| Violation | Why Needed | Simpler Alternative Rejected Because |
|---|---|---|
| A `video` field nothing can fill, and a rule nobody can reach | The coach asked for the shape and the gate now, so that attaching later costs no re-consent. The domain comment from feature 004 says why: discovering it later would mean asking every family again | Adding both when video ships. Rejected by the coach's own decision on Q1, and the cost is one field plus three lines of rule against re-asking every family |
| A rules test that asserts something **succeeds** which the spec would rather refuse | It states the coach-to-coach boundary that does not exist, so the day it must change, it fails first | Writing nothing. Rejected: an unwritten limitation is one nobody finds until it matters, which is how feature 003's identity gap survived to 004 |
