# Implementation Plan: The coach → swimmer relation

**Branch**: `012-coach-swimmer-link` | **Date**: 2026-11-19 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/012-coach-swimmer-link/spec.md`

## Summary

A swimmer belongs to one community; a community belongs to one coach; and a coach reads
only the swimmers who belong to his. The membership is born one of two ways — he created
her profile, or she asked at sign-up and he accepted.

**The membership lives in exactly one place**: a `comunidadId` on the swimmer's profile.
Not copied onto her records, her plans or her requests, because ending a membership has
to stop the reading *immediately* (FR-024), and a copy is a thing that can still say the
old answer. That is not a new position in this project — the consent gate's own comment
settled it: *«desnormalizarlo para ahorrarla crearia la posibilidad de que el estado de
la puerta discrepe de si mismo en dos sitios»*.

**And that one sentence is most of the work**, because of the other rule this product
learned the hard way: **a query is proven by its filters, not document by document.** The
coach makes **five whole-collection reads** today — all of `registros`, all of
`nadadores`, all of `macrociclos`, all of `peticiones`, all of `asignaciones`. Every one
of them is allowed only because the rule says `esEntrenador()`, full stop. The moment the
rule asks *which* swimmer, not one of those five can be proven, and Firestore rejects the
whole query rather than filtering it.

So this feature is not "add a field and tighten a rule". It is: add the field, tighten the
rules, and **rewrite every query the coach makes** so that what it is allowed to see is
visible in the query itself. One of those queries exists specifically to avoid being N
queries (decision D10 of feature 007); it becomes a small number of chunked ones, and
that trade is made with its eyes open.

## Technical Context

**Language/Version**: Dart 3.12.2 / Flutter 3.44.2; Cloud Functions on Node 22, TypeScript

**Primary Dependencies**: `provider`, `shared_preferences`, `cloud_firestore`,
`firebase_auth`, `firebase_functions`. No new dependency is expected; principle VII
requires one to be justified by name if it turns out otherwise

**Storage**: Firestore. New: a `comunidades` collection and a `solicitudesDeIngreso`
collection; one new field on `nadadores`. Nothing is removed

**Testing**: `flutter test` for domain and widgets; the Firebase emulators for rules and
functions. **The rules suites are where this feature is actually proven**, and they must
exercise the queries the app makes rather than reads of single documents by id

**Target Platform**: Android and web, offline-first

**Project Type**: mobile-first Flutter app with a pure-Dart domain and a thin server

**Performance Goals**: the coach's screens keep working at the scale this product has —
tens of swimmers, not thousands. Where a single query becomes several, the number must be
stated

**Constraints**: a minor's data may only be read by the coach she belongs to, and the
consent gate of feature 004 is unchanged and composed with this, not replaced. A swimmer
with no community is nobody's, and must not be stranded by that (FR-027). **There is no
population to migrate** — the coach confirmed it — which removes a migration and a deploy
ordering that an earlier draft of this plan carried; see research D5

**Scale/Scope**: five queries rewritten, two collections added, one field added, one
server function added, and the rules of six collections tightened

## Constitution Check

*GATE: before Phase 0, re-checked after Phase 1.*

| Principle | Before design | After design |
|---|---|---|
| **I — Methodology is normative** | Nothing here decides anything about training | **Pass.** No calculation changes. The feature decides who may look, not what is true |
| **II — Pure Dart domain** | At risk: "who belongs to whom" is a rule, and rules drift into repositories | **Pass.** `Comunidad`, `Membresia` and `SolicitudDeIngreso` are domain types with no Firebase import; what belongs to Firestore is the enforcement, which lives in the rules |
| **III — Tests before the thing they guard, each with a negative control (NON-NEGOTIABLE)** | The boundary is the feature. If the tests do not exercise the real queries, they prove nothing | **Pass, with a warning that has its own requirement.** FR-018: inverting the second-coach assertion removes one of the five `assertSucceeds` that made that suite's control meaningful, so the control is re-run and its new numbers recorded |
| **IV — The coach's judgement is not delegated** | At risk: "accept automatically if…" is a tempting convenience | **Pass.** FR-011 makes acceptance his and only his. Nothing auto-accepts, nothing suggests, nothing ranks |
| **V — Minors' data** | **The heart of it.** Today any coach reads any minor's answers | **Pass, and it is the point.** The feature narrows who may read a minor's data from "any coach" to "her coach". The consent gate is unchanged and composed with it: consent says whether her data may leave the device at all, the membership says who may read it, and both must hold |
| **VI — Honest freemium** | Belonging must never be behind payment | **Pass.** Nothing here is gated by payment |
| **VII — Vertical slices and no unjustified dependency** | One area — community — and it is the one the roadmap declared next | **Pass.** No new dependency. Video stays out (feature 013), and so do assistants, transfers, invitations and messaging |
| **VIII — Internal load control** | Not touched | **Pass.** What she writes and how it is shown is unchanged |

### The gate worth re-reading before coding

**Principle III, and what the negative control is for.** This feature's whole value is a
boundary, and a boundary is worth exactly what its tests are worth. The rules suite for
`registros` was measured once against a collection with **no rule at all**: 5 of 10 tests
passed anyway, and every failure was an `assertSucceeds`. One of those five is the
second-coach test this feature inverts.

So after the inversion the control must be re-run, and if the suite's ability to notice a
missing rule has dropped, that is a finding, not a footnote. A test that asserts a refusal
is free to pass for the wrong reason; only the ones that assert a success can tell you the
rules are loaded at all.

### Re-read against what was built, 2026-11-19

A gate that is only true at planning time is not a gate. Every row still holds, with three
corrections and one failure that the work earned:

- **II — Pure Dart domain.** Holds, and got stricter than planned. The "at most one
  waiting request" rule was written inline in the Firestore repository; it moved to
  `laQueHayQueRetirar` in the domain, where it can be checked without a server. Its third
  condition — do not withdraw a request to the *same* community — is the one a retry with
  no signal puts to the test, and it was the one no test could reach.
- **III — Tests before the thing they guard.** Holds, and the warning was right **twice
  over**: the inversion cost the analysis suite not one `assertSucceeds` but two, because
  the whole-collection read had to be inverted as well. So the compensating assertion that
  FR-018 made conditional was genuinely needed. Numbers in `tasks.md`.
- **V — Minors' data.** Holds, and one line of it needed checking rather than asserting:
  the join request now carries the swimmer's **name**, because guarantee F3 and FR-009 are
  only both true if it does. That is one more fact travelling before a coach has accepted
  her — and it is the minimum that lets him decide about a person instead of an
  identifier, it is hers to state about herself, and it is what the contract already
  anticipated with «más allá de lo que la propia solicitud lleva».
- **VII — No unjustified dependency.** Holds: `git diff pubspec.yaml pubspec.lock` is
  empty. The `whereIn` batching is thirty lines of Dart, not a package.

**What did not hold, and is recorded rather than hidden**: `planes` could not be brought
inside the boundary. A plan has no owner — only `nadadoresIds`, empty in a draft, and a
draft is exactly what its author must be able to read — so the rule has nothing to ask,
and giving plans an owner means migrating documents that already exist. Her boundary is
complete; his is half. The limitation is an asserted test in `reglas_frontera.test.js`,
not a silence, which is what feature 010 did with FR-024 and the reason this feature
existed to close it.

## Project Structure

### Documentation (this feature)

```text
specs/012-coach-swimmer-link/
├── plan.md              # This file
├── research.md          # Phase 0: seven decisions, and what was rejected
├── data-model.md        # Phase 1: two collections, one field, and why not more
├── quickstart.md        # Phase 1: how to verify the boundary, and the control
├── contracts/           # Phase 1: the rules contract and the accept function
└── tasks.md             # Phase 2 — /speckit-tasks, not this command
```

### Source Code (repository root)

```text
lib/
├── dominio/
│   ├── comunidad/
│   │   ├── comunidad.dart          # NEW: a named group, one coach
│   │   ├── membresia.dart          # NEW: who belongs, since when
│   │   └── solicitud_de_ingreso.dart  # NEW: asked / accepted / declined / withdrawn
│   └── repositorios/
│       └── repositorios.dart       # the three new interfaces
├── datos/firestore/
│   ├── comunidades_firestore.dart  # NEW
│   ├── solicitudes_firestore.dart  # NEW
│   ├── repositorios_firestore.dart # the swimmer list, filtered by community
│   ├── registros_firestore.dart    # `nadadoresConRegistros` stops reading everything
│   ├── macrociclos_firestore.dart  # same, for `macrocicloPorNadador`
│   ├── peticiones_firestore.dart   # same
│   └── molestias_firestore.dart    # same
├── ui/
│   ├── ajustes/
│   │   └── mi_comunidad.dart       # NEW: he names it (US1)
│   ├── alta/
│   │   └── paso_comunidad.dart     # NEW: she asks, while signing up (US2)
│   ├── hub/
│   │   └── cola_del_entrenador.dart  # the request waits where things wait (US3)
│   └── nadador/
│       └── pantalla_mi_progreso.dart # and the day screen: waiting, not empty (US4)
└── main.dart

firebase/
├── firestore.rules                 # six collections tightened; the boundary lives here
├── functions/src/
│   └── comunidad.ts                # NEW: accept, decline, remove, leave
└── test/
    ├── reglas_comunidad.test.js    # NEW
    └── reglas_analisis.test.js     # FR-018: the inversion, and the control re-run
```

**Structure Decision**: the existing layout. One new domain folder, `lib/dominio/comunidad/`,
because three types belong together and to nothing that exists. Everything else is a file
already there — which is the shape of this feature: little new, much tightened.

## Complexity Tracking

> No Constitution Check violations.

Two judgement calls that could become complexity later, recorded so they stay visible:

| Decision | Why it is not complexity now | What would change that |
|---|---|---|
| The membership is a field on the swimmer, not a collection | One community per swimmer, so a collection would be a second read for no extra fact | The day a swimmer can belong to two, or a community can have two coaches — both out of scope and both named as such |
| `nadadoresConRegistros` becomes chunked queries | Tens of swimmers means one or two chunks | Hundreds of swimmers. Then it wants a counter maintained by the server, which is a different decision with a different cost |
