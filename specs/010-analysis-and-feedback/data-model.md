# Data Model: Análisis and feedback

**Feature**: 010 · **Date**: 2026-11-11

Two entities are new. Everything else this feature shows already exists and is read, not
redefined.

---

## What already exists and is only read

| Entity | Where it lives | What this feature does with it |
|---|---|---|
| `RegistroDeSesion` | `lib/dominio/entidades/registro_sesion.dart` | Reads it. Carries `realizada`, `rpePercibido`, `observaciones` and `molestia` already. **No field is added.** |
| `ReporteDeMolestia` | same file | Reads it. It is already a separate object rather than a flag on observations, which is why FR-009 costs presentation work and no modelling. |
| `Plan` / `Sesion` | `lib/dominio/entidades/` | Reads them, for the programmed side of each session. |
| `ProgresoEnElMacrociclo` | `lib/dominio/macrociclo/` | Reads adherence from it. Never recomputed (D6). |
| `Consentimiento` / `Alcance` | `lib/dominio/consentimiento/` | Reads the scopes. `Alcance.video` becomes reachable by a rule for the first time (D2). |

---

## New: `PeticionDeFeedback`

A swimmer asking her coach to look at one session she already swam.

| Field | Type | Rules |
|---|---|---|
| `id` | `String` | Deterministic, `nadadorId\|planId\|sesionId`. Asking twice about the same session rewrites one document instead of making two. |
| `nadadorId` | `String` | Required. Who asked. |
| `planId` | `String` | Required. The plan version she was on when she asked. |
| `sesionId` | `String` | Required. Survives a readjustment, because feature 009 keeps session identifiers across versions (FR-018). |
| `pregunta` | `String` | Required, non-empty after trimming. Her words. A request with nothing in it is not a request. |
| `pedidaEn` | `DateTime` | Required. |
| `vistaEn` | `DateTime?` | Null until the coach marks it seen. Its presence is the whole of FR-019. |
| `video` | `ReferenciaDeVideo?` | **Always null in this feature.** See below. |

### Invariants

- `pregunta` is not blank. Enforced in the constructor, like `porQue` on
  `BloqueConfirmado`.
- `vistaEn`, once set, is not unset. A coach cannot un-see something.
- `video` is null. The constructor rejects a non-null value in this feature, so the field
  exists without the capability existing.

### Why the id is deterministic

The same decision feature 003 took for records, and for the same reason: a resend must
rewrite rather than duplicate. If she asks, loses connection, and asks again, the coach
gets one request.

---

## New: `ReferenciaDeVideo`

**Nothing in this feature produces one.** It exists so the request has a shape to grow
into, and so the gate in front of it can be written and proven now (D2).

| Field | Type | Notes |
|---|---|---|
| `ruta` | `String` | Where the video would live. No storage is configured. |
| `subidoEn` | `DateTime` | — |

The type is defined, serialised and refused. A later feature removes the refusal; nothing
else about it has to change, and no family has to be asked for consent again.

---

## New, derived, stored nowhere: `LecturaDelNadador`

What the coach needs about one swimmer, assembled for reading.

| Field | Type | Source |
|---|---|---|
| `nadador` | `Nadador` | read |
| `mesociclos` | `List<Plan>` | read |
| `respuestas` | `List<RespuestaASesion>` | assembled |
| `progreso` | `ProgresoEnElMacrociclo` | computed by feature 009's code |
| `conMolestia` | `List<RespuestaASesion>` | filtered, for FR-010 |

### `RespuestaASesion`

One session and what she said about it, **side by side and never combined** (D8, FR-013).

| Field | Type | Notes |
|---|---|---|
| `sesion` | `Sesion` | the external load: metres, parts, zones |
| `registro` | `RegistroDeSesion?` | the internal load: done, effort, observations, discomfort. Null when she has not answered |
| `peticion` | `PeticionDeFeedback?` | her question about this session, if any |

**There is deliberately no field combining the two.** Adding one would mean writing a new
type, which makes breaking principle VIII an act rather than an accident. `RespuestaASesion`
exposes `sesion` and `registro` and nothing that multiplies, averages or scores across them.

---

## Firestore shapes

### `peticionesDeFeedback/{nadadorId|planId|sesionId}`

```
nadadorId: string
planId: string
sesionId: string
pregunta: string
pedidaEn: string          (ISO 8601)
vistaEn: string | absent
video: absent             (always, in this feature)
```

### Access rules

| Who | Read | Create | Update | Delete |
|---|---|---|---|---|
| The swimmer herself | her own | hers, with current `datosDeEntrenamiento` consent, no `video` field | — | never |
| The coach | any | never | only to set `vistaEn` | never |
| Anyone else | never | never | never | never |

Three things this table encodes:

- **The coach cannot write her question.** Same reasoning as records since feature 004:
  what the swimmer says is hers, and the coach's only write is "I saw it".
- **Marking seen is a `hasOnly(['vistaEn'])` update**, the shape feature 009 used for
  delivering a plan. Anything else is rejected, so "seen" cannot smuggle an edit.
- **A create carrying `video` is refused**, with the scope-aware consent check in front of
  it. Nothing can pass it today; the test proves it is standing (D2).

### A new rule helper

```
function tieneConsentimientoDeAlcance(nadadorId, alcance)
```

Current **and** scoped. The existing `tieneConsentimientoVigente` checks only the first,
which would let a family who agreed to training data authorise video they never agreed to.

---

## What is not modelled

- **No reply.** The coach answers at the poolside (Q2). There is no `respuesta` field and
  no collection for one.
- **No read/unread state beyond `vistaEn`.** One timestamp answers "did he see it".
- **No coach→swimmer link.** It does not exist and this feature does not invent it (D1).
- **No stored reading.** `LecturaDelNadador` is assembled per view. Storing it would be a
  second copy of data the server already holds, and it would go stale the moment she
  answers again.
