# Data Model: Ver Plan and progression

**Feature**: 009-plan-progression · **Date**: 2026-11-04

Pure-Dart domain types (principle II): no `package:flutter/*`, no Firebase. The boundary test
in `test/dominio/arquitectura_test.dart` checks it.

> **Read decision D1 first.** A `Plan` is already a mesocycle: one ATR phase, several
> microcycles, its own lifecycle, audit, version lineage and methodology stamp. This feature
> adds the level **above** it, not the level inside it.

---

## `Macrociclo` — the new level

The whole preparation towards a target event. It **holds references, not content**: the
sessions live in its mesocycles, which are `Plan`s.

| Field | Type | Rule |
|---|---|---|
| `id` | `String?` | Null until stored, like `Plan` |
| `nadadorId` | `String` | Required, non-empty. A macrocycle is for one swimmer (groups are out of scope) |
| `nombre` | `String` | Required, non-empty |
| `estructura` | `EstructuraConfirmada` | Required. What the coach decided, kept because the derivation is reproducible from it |
| `mesociclos` | `List<String>` | Plan ids, **in order**. At least one |
| `fechaDeCompetencia` | `DateTime` | Required. The anchor the skeleton counts back from |
| `versionMetodologia` | `String` | Required (FR-013) |
| `estado` | `EstadoPlan` | Reuses the existing lifecycle: `borrador` → `aprobado` → `publicado` |

**Invariants**

- A macrocycle with no mesocycles is not constructible: it would be a name with nothing in it
- Its mesocycle ids are unique and ordered; order is the preparation's order, not an accident
  of storage
- `aprobado` implies every mesocycle it references is `aprobado`: a macrocycle cannot be signed
  while part of it is not

---

## `EstructuraConfirmada` — what the coach decided

Stored, for two reasons: it is the input the derivation reproduces from, and it is the record
of what he actually decided rather than what the app proposed.

| Field | Type | Rule |
|---|---|---|
| `modeloDeLaPrueba` | `String` | Required, non-empty after trimming. The event's real demands (section 4, step 2) |
| `modeloDelNadador` | `String` | Required, non-empty after trimming. Dominant stroke, errors, pace, fatigue tolerance, recovery, motivation (step 3) |
| `bloques` | `List<BloqueConfirmado>` | Required, at least one. The skeleton as he left it |
| `confirmadaEn` | `DateTime` | When he confirmed. The server's clock, not the device's |

**Rules**

- The two models are **the coach's**. The app may pre-fill them from the swimmer's own record —
  `diagnosticoTecnico`, `pruebaObjetivo`, `marcas` — and from nothing else. Deriving them from
  a formula is forbidden (FR-007, FR-008, constitution v2.0.0)
- Nothing is derived and nothing is stored before this exists (FR-002, SC-010)

---

## `BloqueConfirmado` — one block of the skeleton

| Field | Type | Rule |
|---|---|---|
| `fase` | `FaseAtr?` | Null only for categories that do not use ATR |
| `desde`, `hasta` | `DateTime` | `hasta` after `desde`; blocks do not overlap and leave no gaps |
| `porQue` | `String` | Always present, always readable: «Realización, las últimas 2 semanas antes de la competencia» |

**The proposal** (decision D2), a pure function of (competition date, today, category),
counting **backwards** from the competition using the durations section 12 cites:

| Block | Published duration | Placed |
|---|---|---|
| Realización | 8-15 days | Last, ending at the competition |
| Transformación | 2-4 weeks | Before it |
| Acumulación | 2-6 weeks | Filling whatever remains |

- A category with `usaAtr == false` gets **one** block with no phase: the engine forbids a phase
  there
- A block outside the published durations **warns, never blocks** (FR-012). Section 12 says
  swimming uses longer phases than the general literature, and the app does not know better
  than the coach
- Every field of the proposal is editable before confirmation (FR-005). A proposal that cannot
  be changed is a decision

---

## `ProgresoEnElMacrociclo` — computed, never stored

Where the swimmer is, what is done, what is outstanding. Derived at read time from the feature
003 records (decision D7).

| Field | Type | Source |
|---|---|---|
| `mesocicloActual` | `String?` | The mesocycle whose dates contain today |
| `hechas` | `Set<String>` | Session ids with a record marked `realizada` |
| `pendientes` | `List<Sesion>` | Dated before today, not marked. **Outstanding, not forbidden** |
| `proxima` | `Sesion?` | The first session dated today or later |

**Rules**

- Nothing here is written anywhere. A stored copy is a second thing that can disagree with the
  swimmer's own record, and the record is the one they wrote
- `pendientes` is shown, never enforced (decision D6)

---

## `PuedeMarcarse` — the rule about the date

A pure function over a session's date and today. No repository, no screen.

| Result | When | What the swimmer reads |
|---|---|---|
| `si` | The date is today or has passed | — |
| `todaviaNo` | The date is after today | «Todavía no llega ese día» |
| `sinFecha` | The session has no date | «Esta sesión no tiene día asignado» |

**Rules**

- A future session cannot be marked **by any path**, not only by the screen (FR-024, SC-006)
- A past session can always be marked, whatever happened before it (FR-025)
- `Sesion.fecha` is nullable today, so `sinFecha` is a real case: the app does not guess when
  something was meant to happen

---

## Changes to existing entities

### `Plan` — becomes a mesocycle explicitly

| Change | Why |
|---|---|
| New nullable `macrocicloId` | Which macrocycle it belongs to. Null for a plan that stands alone — one from a feature 008 request, or written by hand |
| New nullable `ordenEnElMacrociclo` | Its position. Null when it stands alone |

Nothing else changes. `faseAtr`, `microciclos`, `sesiones`, `estado`, `versionAnteriorId`,
`crearVersionDesde`, `versionMetodologia` and the section 16 audit all keep working as they do,
which is the whole point of D1.

### `Sesion`, `Microciclo`, `RegistroDeSesion`, `Asignacion`

Untouched.

**One thing the plan must decide about `Sesion.id`** (decision D8): records are keyed by
`sesionId`. If a new version of a mesocycle gives its sessions new ids, the swimmer's records
are orphaned — nothing fails, their history just goes blank. FR-035 forbids that, so either ids
are stable across versions or the records are carried explicitly. The test checks the records
are still **reachable**, not that the write succeeded.

---

## Storage shape

| Path | Who writes | Who reads |
|---|---|---|
| `macrociclos/{id}` | The coach | That swimmer, the coach |
| `planes/{id}` | Unchanged from feature 001, plus the two new fields | Unchanged |
| `registros/{id}` | Unchanged from feature 003 | Unchanged |
| `asignaciones/{id}` | Unchanged from feature 007 | Unchanged |

The swimmer reads a macrocycle that is theirs and published. They never write one: a macrocycle
is the coach's work, and nothing about it is theirs to change.
