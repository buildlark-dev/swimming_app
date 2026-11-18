# Implementation Plan: Repairs to the swimmer's journey

**Branch**: `011-swimmer-journey-repairs` | **Date**: 2026-11-18 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/011-swimmer-journey-repairs/spec.md`

## Summary

Four repairs to one journey: the swimmer, her phone, and the promise that nothing she
writes is lost or quietly delayed. No new screen, no new control, no new word.

**The approach, in one line: the attempt is the probe.** The app stops asking anything
whether a network exists and simply keeps trying to send what is queued, on a schedule,
until it arrives. That is what `estado_de_red.dart` has said the detection should be
since feature 003 — "se intenta una escritura y se ve si llega" — and it only became
possible when feature 010's walk gave the send a deadline, because before that an
attempt that never returned was not an answer.

Everything else follows from it. Nothing is probed while the queue is empty, because
there is nothing to attempt. Connectivity is never *reported*, only *discovered*, so it
cannot lie about a pool whose wifi does not reach the internet. And the cost is a failed
socket attempt a minute, with no reads, no writes that reach a server, and nothing at all
when there is nothing waiting.

**Two of the four defects are the same mistake**, and naming it is worth more than either
fix: a correct thing was built, tested, and never connected. `Sincronizador.alVolverLaRed`
has a test and no listener. `ProgresoEnElMacrociclo.sinContestar` has the exact rule the
pending list needs, has tests asserting that done, refused and unanswered partition the
past sessions — and nothing in `lib/` calls it. Neither fix adds a concept. Both wire up
one that was already there and already proven.

## Technical Context

**Language/Version**: Dart 3.12.2 / Flutter 3.44.2

**Primary Dependencies**: `provider`, `shared_preferences`, `cloud_firestore`,
`firebase_auth`. **No new dependency** — see the Constitution Check, where refusing one
is the gate this feature is most likely to fail.

**Storage**: the device's own store for records and the outbox (`shared_preferences`,
partitioned per account); Firestore for what has been sent

**Testing**: `flutter test` for domain and widgets; the Firebase emulators for rules.
This feature adds no rule, so the rules suites should end unchanged — and if they do not,
something has grown that was not meant to

**Target Platform**: Android and web, offline-first

**Project Type**: mobile-first Flutter app with a pure-Dart domain

**Performance Goals**: a record annotated with no signal reaches the coach within one
minute of the signal returning (SC-001), with nothing touched

**Constraints**: the retry must stay bounded and must never become a tight loop — the
phone belongs to someone who is swimming. Guarantees G1, G3 and S8 and the literal
sentence of FR-017 are unchanged

**Scale/Scope**: four repairs across roughly eight files; two screens touched, both the
swimmer's; no change on the coach's side

## Constitution Check

*GATE: before Phase 0, re-checked after Phase 1.*

| Principle | Before design | After design |
|---|---|---|
| **I — Methodology is normative** | Nothing here decides anything about training | **Pass.** No calculation changes except which of three already-computed sets the pending list reads (D5) |
| **II — Pure Dart domain** | At risk: a retry schedule wants a `Timer`, and timers drift towards widgets | **Pass.** The schedule lives in `Sincronizador` with an injected clock and an injected scheduler, so it is tested without waiting. `dart:async` is not Flutter |
| **III — Tests before the thing they guard, each with a negative control (NON-NEGOTIABLE)** | At risk in the worst way: every one of these four defects slipped past a green suite | **Pass, and it is the point.** Every repair gets its lock first, and every lock gets its control run. The doubles must **return where the server would hang**, not throw — the lesson this project has now paid for three times |
| **IV — The coach's judgement is not delegated** | Not touched | **Pass.** Nothing here proposes, scores or decides anything |
| **V — Minors' data** | Not touched | **Pass.** No new data, no new field, no new document. D2 reduces what leaves the device when nothing needs sending |
| **VI — Honest freemium** | Not touched | **Pass.** Nothing here is behind payment |
| **VII — Vertical slices and no unjustified dependency** | **The gate most likely to fail.** "Detect connectivity" is the exact sentence that ends in `connectivity_plus` | **Pass.** No dependency added, and the refusal is reasoned in D1: the OS can only say whether an interface exists, and a pool with wifi that does not reach the internet is the normal case |
| **VIII — Internal load control** | The pending list is a report of internal load | **Pass.** D5 makes it say what the swimmer actually answered. The two loads are still never combined |

### The one gate worth re-reading before coding

**Principle VII, and the dependency this feature wants.** Every instinct says "use a
connectivity package". The project already wrote down why not, in `estado_de_red.dart`,
before any of this was a defect: *«no se consulta ningún servicio de conectividad del
sistema, porque "el teléfono dice que hay wifi" y "el servidor responde" son cosas
distintas, y a pie de piscina la segunda es la que importa»*. That file then shipped
with a probe that asked neither. The repair is to make it do what it always said, not
to add a library that answers a different question well.

## Project Structure

### Documentation (this feature)

```text
specs/011-swimmer-journey-repairs/
├── plan.md              # This file
├── research.md          # Phase 0: the six decisions, and what was rejected
├── data-model.md        # Phase 1: what changes in the types that already exist
├── quickstart.md        # Phase 1: how to verify it, and what cannot be verified here
├── contracts/           # Phase 1: the sync contract, amended
└── tasks.md             # Phase 2 — /speckit-tasks, not this command
```

### Source Code (repository root)

```text
lib/
├── dominio/
│   ├── sincronizacion/
│   │   └── bandeja_salida.dart          # the retry schedule (D2), the late
│   │                                    # success (D3); the contract's second
│   │                                    # trigger finally has a mechanism
│   ├── entidades/
│   │   └── envio_pendiente.dart         # the retry delay's cap (D2)
│   ├── macrociclo/
│   │   └── progreso_en_el_macrociclo.dart  # `pendientes` reads `sinContestar` (D5)
│   └── lectura/
│       └── lectura.dart                 # NEW: still reading / nothing / could
│                                        # not be read (D4)
├── datos/
│   └── red/
│       └── estado_de_red.dart           # the network is what the last attempt
│                                        # said it was (D1)
├── ui/
│   └── nadador/
│       ├── estado_nadador.dart          # starts and stops the schedule (D6);
│       │                                # exposes a `Lectura`, not a nullable
│       ├── pantalla_mi_progreso.dart    # the three states (D4)
│       └── pantalla_sesion_del_dia.dart # same sentence, same fix
└── main.dart                            # the probe that never probed, removed

test/
├── dominio/sincronizacion/   # the schedule, the late success, the cut-short delay
├── dominio/macrociclo/       # the pending list
├── dominio/lectura/          # the three states
└── ui/nadador/               # the screens, and that no network wording reaches her
```

**Structure Decision**: the existing layout, unchanged. One new domain folder,
`lib/dominio/lectura/`, for the three-state type of D4, because it is used by two
screens and belongs to neither. Everything else is a file that already exists.

## Complexity Tracking

> No Constitution Check violations. Nothing in this table.

The one judgement call that could have become complexity, recorded so it is visible:
D2 changes a constant feature 003 documented — the retry delay's cap — from five minutes
to one. It is not a new mechanism and adds no code path. The reason is in research.md,
and the old reason (battery, no tight loop) is still honoured at one attempt a minute.
