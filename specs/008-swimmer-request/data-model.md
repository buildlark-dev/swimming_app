# Data Model: The swimmer's request

**Feature**: 008-swimmer-request · **Date**: 2026-11-02

Pure-Dart domain types (principle II): no `package:flutter/*`, no Firebase. The boundary test
in `test/dominio/arquitectura_test.dart` checks it.

---

## `PeticionDePlan` — what a swimmer asked for

The request itself. It carries the answers and the state; it does **not** carry the plan.

| Field | Type | Rule |
|---|---|---|
| `nadadorId` | `String` | Required, non-empty. It is also the document id (decision D6) |
| `enviadaEn` | `DateTime` | Required. Set by the server on arrival, not by the device |
| `respuestas` | `RespuestasDePeticion` | Required. See below |
| `estado` | `EstadoDePeticion` | Required. Starts at `esperando` |
| `motivoDelRechazo` | `String?` | Required **when and only when** `estado == rechazada`; non-empty after trimming |
| `planId` | `String?` | The draft the coach saved from it, once he saved one. Null until then |
| `respondidaEn` | `DateTime?` | When the coach answered. Null while `esperando` |

**Invariants**

- `rechazada` without a reason is not constructible. The reason is not an optional extra on a
  rejection: FR-021 and FR-026 both depend on it existing
- `aprobada` implies `planId != null`: approving without a plan would be a signature on nothing
- `esperando` implies `respondidaEn == null` and `motivoDelRechazo == null`
- The device never sets `enviadaEn`, `estado`, `respondidaEn` or `planId`

---

## `RespuestasDePeticion` — the five answers and the two confirmations

What the swimmer supplied. This is what makes the request auditable: the draft can be
regenerated from it and come out the same (SC-004).

| Field | Type | Rule |
|---|---|---|
| `estiloObjetivo` | `Estilo` | Required. Starts from the record; the swimmer may change it |
| `pruebaObjetivo` | `String` | Required, non-empty after trimming. Starts from the record |
| `fechaDeCompetencia` | `DateTime?` | Null means "no lo sé" — a valid answer (FR-006) |
| `diasDisponibles` | `List<DateTime>` | Required, at least one. No duplicate days |
| `duracionSesionMinutos` | `int` | Required. Between 30 and 180 |
| `longitudPiscina` | `int` | Required. Exactly 25 or 50 |

**Notably absent**, and each absence is a requirement, not an omission:

- No category — it is the coach's (FR-003)
- No ATR phase and no accentuated component — derived (FR-014, FR-016)
- No technical diagnosis — it is observation by the coach, read from the record
- No discomfort — read from the swimmer's sessions, never copied (FR-034, FR-038)
- No free text of any kind except the event, which comes pre-filled from the record (FR-005)

---

## `EstadoDePeticion` — the four states

```text
esperando ──→ enRevision ──→ aprobada
     │              │
     └──────────────┴──────→ rechazada
```

| State | Visible wording (Spanish, as the swimmer reads it) | Who moves it |
|---|---|---|
| `esperando` | «Esperando a tu entrenador» | — (initial) |
| `enRevision` | «Tu entrenador la está viendo» | The coach, by opening it |
| `aprobada` | «Aprobada» | The coach |
| `rechazada` | «Tu entrenador respondió» | The coach |

**Rules**

- Nothing moves a request by elapsed time or by any other automatic rule (FR-023)
- `aprobada` and `rechazada` are terminal. A swimmer who wants something else sends a new
  request; the old one stays readable
- Only a terminal state frees the swimmer to send another (FR-032, enforced by the rules per
  decision D6)

---

## `FaseDerivada` — the phase and its reason

Not stored on the request. Computed when the draft is generated, and carried into the draft so
the coach sees it and can change it (FR-017). A derived phase with no visible reason would be
judgement delegated through the back door.

| Field | Type | Rule |
|---|---|---|
| `fase` | `FaseAtr?` | Null when the category does not use ATR, or when there is no usable date |
| `diasHastaLaCompetencia` | `int?` | Null when there is no usable date |
| `porQue` | `String` | Always present, always readable: «Transformación, porque tu competencia es en 24 días» or «Sin fase: no hay fecha de competencia» |

**The derivation** (decision D3), a total function of (competition date, today, category):

| Days until | Result |
|---|---|
| 1 to 15 | `realizacion` |
| 16 to 43 | `transformacion` |
| 44 or more | `acumulacion` |
| 0, or in the past, or null | no phase, reason says why |
| Category with `usaAtr == false` | no phase, whatever the date |

---

## `MolestiaEnlazada` — read, never owned

A projection over the session records of feature 003, not a stored entity (decision D7,
FR-038).

| Field | Type | Source |
|---|---|---|
| `fecha` | `DateTime` | The record's own date |
| `reporte` | `ReporteDeMolestia` | `RegistroDeSesion.molestia`, as it already exists |

**Rules**

- Only records inside the recent window — **four weeks**, a named constant (`ventanaDeMolestias`)
- When the window is empty, the absence is stated, not left blank (FR-037). A blank space reads
  as "nothing hurts"
- Nothing here is written anywhere by this feature

---

## Changes to existing entities

### `Plan`

| Change | Why |
|---|---|
| New nullable `peticionId` | FR-010: the draft records which request it came from. `OrigenPlan` stays as it is (decision D5) |

`OrigenPlan.automatico` continues to mean what it means. A draft with `peticionId != null` is
one a swimmer asked for; one with `peticionId == null` is one the coach generated himself.

### Nothing else changes

`Nadador`, `RegistroDeSesion`, `Asignacion`, `EstadoPlan` and the five `Destino` values are
untouched. The swimmer's `Generar` branch in `reparto` changes from `TodaviaNo` to a content
value, which is a one-line change to a total function that was written to accept it.

---

## Storage shape

| Path | Who writes | Who reads |
|---|---|---|
| `peticionesDePlan/{nadadorId}` | The swimmer (create only, their own), the server (state) | That swimmer, the coach |
| `peticionesDePlan/{nadadorId}/historial/{peticionId}` | The server only | That swimmer, the coach |
| `planes/{planId}` | Unchanged from feature 001 | Unchanged |
| `registros/{registroId}` | Unchanged from feature 003 | Unchanged — the coach already reads his community's |

The swimmer never writes `estado`, `respondidaEn`, `planId` or `enviadaEn`. The rules check
this field by field, because a client that can write its own state can approve its own request.
