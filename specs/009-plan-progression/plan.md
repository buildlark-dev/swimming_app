# Implementation Plan: Ver Plan and progression

**Branch**: `009-plan-progression` | **Date**: 2026-11-04 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/009-plan-progression/spec.md`

## Summary

The plan stops being a loose week. The coach confirms the macrocycle's structure once — the
event model and the swimmer model, with an editable skeleton the app proposes — and everything
below derives in one go. The swimmer gets it whole from day one, folded, opening at today.
Marking is about the date, not the order. Readjustment versions mesocycles.

**The finding that shapes the whole feature is that a `Plan` is already a mesocycle.** One ATR
phase, several microcycles, its own lifecycle, audit, version lineage and methodology stamp.
The project has been building mesocycles since feature 001 and calling them plans. So the only
new level is the one above, and FR-031 — the mesocycle is what gets versioned — lands on the
type that already has versioning, tested.

This is also the first feature under **constitution v2.0.0**, so it carries an obligation the
others did not: it has to be able to point at the single confirmation. If it cannot, the
amendment was used to skip a rule rather than restate it.

## Technical Context

**Language/Version**: Dart 3.12.2 / Flutter 3.44.2. Server: TypeScript on Node 22.

**Primary Dependencies**: no new ones. The feature 002 engine, the feature 001 lifecycle and
audit, and the feature 003 records are all in place.

**Storage**: Firestore. One new collection, `macrociclos`. Two new nullable fields on `planes`.
Nothing else changes.

**Testing**: `flutter test` for domain and widgets, `@firebase/rules-unit-testing` against the
emulator for the access rules. **No new server call**, so no source-level wire contract this
time — the thing that can go wrong silently here is a write that happens too early, and a
record that gets orphaned.

**Target Platform**: Flutter web (PWA) and Android.

**Performance Goals**: a fourteen-week macrocycle is fourteen generator calls. They are pure,
but they run on the coach's phone, not in a test. If the derivation blocks the UI it will be
visible there first.

**Constraints**: nothing is stored before the confirmation. No language model takes part in any
field. A swimmer's existing records survive a readjustment.

**Scale/Scope**: one coach, a few dozen swimmers, macrocycles of 14-15 weeks (section 12's own
figure). One new entity, three new domain types, two new screens, no new server call.

## Constitution Check

*GATE: must pass before Phase 0 research. Re-checked after Phase 1 design.*

Checked against **v2.0.0**, amended 2026-11-04.

| Principle | Check | Verdict |
|---|---|---|
| **I. The coach's methodology is the norm** | The skeleton's boundaries come from the block durations section 12 cites, not from numbers chosen by hand. The sessions come from the feature 002 engine, which draws on the Official Library. Phases outside the published ranges warn rather than block, as section 12 says | **Pass** |
| **II. Pure, verifiable Dart domain** | `Macrociclo`, `EstructuraConfirmada`, `BloqueConfirmado`, `ProgresoEnElMacrociclo` and the two pure functions — the skeleton proposal and the marking rule — are pure Dart | **Pass** |
| **III. Tests of the rules that reach the swimmer (NON-NEGOTIABLE)** | The skeleton proposal is a training rule: test first, boundaries, negative control. The marking rule likewise. The determinism test derives twice. The record-survival test checks reachability, not write success | **Pass**, and it is the heaviest part of `tasks.md` by design |
| **IV. The coach's judgement is not delegated** | **This is the feature that has to prove the amendment was honest.** One confirmation, on the structure. The skeleton is editable and shows its reason. The models are never derived from a formula. Nothing is stored before he confirms. Nothing reaches a swimmer without his signature, and the app never readjusts on its own | **Pass** — and the plan treats M10 and M3 as the two that make it true rather than claimed |
| **V. Athletes' data: minimal, protected, portable** | No new personal data. Progress is computed from the feature 003 records, never copied. A swimmer reads only their own macrocycle | **Pass** |
| **VI. Honest freemium** | Nothing gated or charged | **Not applicable** |
| **VII. Vertical slices and simplicity** | No new dependency, no new server call, no new destination. `Plan` is reused as the mesocycle rather than a parallel type being built, which is the single largest simplification available here | **Pass** |
| **VIII. Internal load control** | RPE and discomfort keep working as feature 003 built them; this feature places them inside a hierarchy and changes nothing about how they are recorded | **Pass** |

**Re-check after Phase 1**: no violations introduced. The two worth watching are both about
silence: M10, because nothing failing is exactly what a premature write looks like, and M34,
because an orphaned record leaves a swimmer's history blank without an error.

## Project Structure

### Documentation (this feature)

```text
specs/009-plan-progression/
├── plan.md              # This file
├── spec.md
├── research.md          # Phase 0 — D1 to D10
├── data-model.md        # Phase 1
├── quickstart.md        # Phase 1 — C1 to C13
├── contracts/
│   └── macrociclo_y_progresion.md   # Phase 1 — M1 to M35
├── checklists/
│   └── requirements.md
└── tasks.md             # Phase 2 — created by /speckit-tasks
```

### Source Code (repository root)

```text
lib/
├── dominio/
│   ├── macrociclo/
│   │   ├── macrociclo.dart              # Macrociclo, EstructuraConfirmada, BloqueConfirmado
│   │   ├── esqueleto_propuesto.dart     # the proposal, a total function (D2)
│   │   ├── derivar_macrociclo.dart      # drives the feature 002 engine per microcycle (D4)
│   │   ├── progreso_en_el_macrociclo.dart  # computed, never stored (D7)
│   │   └── puede_marcarse.dart          # the date rule (D6)
│   ├── entidades/plan.dart              # + macrocicloId, ordenEnElMacrociclo
│   └── repositorios/repositorios.dart   # + RepositorioMacrociclos
├── datos/
│   └── firestore/macrociclos_firestore.dart
└── ui/
    ├── macrociclo/
    │   ├── estructura.dart              # the skeleton, editable, with its reason
    │   └── revisar_macrociclo.dart      # what the coach reviews before signing
    └── nadador/
        └── mi_macrociclo.dart           # folded, opening at today

test/
├── dominio/macrociclo/                  # the two rules, with their boundaries
├── ui/macrociclo/
├── ui/nadador/mi_macrociclo_test.dart
└── ui/tema/ayuda_pantallas.dart         # + the new screens in the bench

firebase/
├── firestore.rules                      # + macrociclos, with negative controls
└── test/                                # rules tests
```

**Structure Decision**: the layout the previous eight features established. Two placements are
worth saying out loud:

- **The skeleton proposal and the marking rule go in the domain**, not next to the screens.
  Both are rules that reach a swimmer, and principle III wants them tested with no
  infrastructure at all.
- **`Plan` gains two nullable fields and nothing else.** Making the mesocycle a new type would
  mean rebuilding the lifecycle, audit, assignment, immutability and version lineage for the
  unit that already has all five. See research D1.

## Build order

Two places where the order is not negotiable, and both are about not writing something before
the thing that guards it exists.

1. **The two pure rules first**, with their tests before them: the skeleton proposal (boundary
   weeks, category without ATR, phases outside the published ranges) and the marking rule
   (today, tomorrow, yesterday, no date). Each with a negative control.
2. **The storage lock (M10) before the structure screen.** A test that asserts the repositories
   are empty after proposing and before confirming. Written first, because the screen is where
   a convenient preview would save a draft, and nothing would fail.
3. Then the entities, the repository interface and the Firestore implementation.
4. Then the derivation, with its determinism test deriving twice.
5. Then the coach's structure and review screens.
6. Then the swimmer's folded view, and into the feature 005 bench with it.
7. Then readjustment, **with the record-survival test written before it** — see below.
8. The seed last, because it needs the shapes to exist.

## Complexity Tracking

> No constitution violations to justify. This section stays empty on purpose.

One thing that looks like a shortcut and is not: **reusing `Plan` as the mesocycle**. It reads
like avoiding work, and it is — but the work avoided is rebuilding a lifecycle, an audit, an
assignment path, an immutability rule and a version lineage that are already tested, for the
exact unit that needs all five. The cost is one sentence of vocabulary, written into the data
model so the next feature does not rediscover it.

## What to watch

- **M10 — nothing exists before the confirmation.** Trivially true today, which is the danger.
  The lock looks at storage, not at the screen; feature 008 learned twice that a thing not
  being shown says nothing about whether it exists.
- **M34 — a readjustment must not orphan the swimmer's records.** Records are keyed by
  `sesionId`. If a new version of a mesocycle gives its sessions new ids, the history goes
  blank and nothing fails. The test checks the records are still **reachable**, not that the
  write succeeded. This is the quiet one.
- **M12 — determinism.** Derive twice and compare. A stored fixture would hide an input read
  from the clock, which is the trap feature 008 wrote down.
- **Fourteen generator calls on a phone.** If the derivation is slow it will be slow where the
  coach is, and the browser will flatter it.
- **Feature 008's locks stay green untouched.** The request's draft is still a standalone plan
  with `macrocicloId == null`, and nothing about `peticionesDePlan` changes.
