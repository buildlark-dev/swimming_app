# Phase 1 — Data model: Repairs to the swimmer's journey

**No new stored data.** No collection, no document, no field, nothing written to the
device that was not written before. This feature changes what existing types *say* and
when they say it.

That is worth stating plainly, because it is also a privacy answer: there is nothing here
for principle V to weigh. Nothing new about a minor is collected, kept or sent.

---

## What changes in types that already exist

### `EnvioPendiente` — the queued send

Unchanged in shape: it still carries which record it is, its state, how many attempts it
has taken and when the last one was.

| | Before | After |
|---|---|---|
| `esperaHastaElSiguiente` | grows 1, 2, 4, 8… seconds, capped at **300** | same growth, capped at **60** |

**Why the cap moves**: SC-001 promises the record arrives within a minute of the signal
returning. With a five-minute cap, a record that had already failed a few times would sit
out up to five minutes after the network was back — the mechanism in place and the
promise still broken. The cap's original reason, written in the file, was to avoid a
tight retry loop on the phone of someone who is swimming. One attempt a minute is not a
tight loop, so that reason survives the change.

**Invariant kept**: the delay is still a pure function of the number of attempts. Nothing
about elapsed real time enters it, so the retry logic stays testable with a fake clock.

---

### `Sincronizador` — the outbox

Gains the schedule, and nothing else.

| | Before | After |
|---|---|---|
| Triggers | on save, on app open, and a stream nobody listened to | on save, on app open, and **a wake-up kept while the queue is non-empty** |
| Collaborators | records, queue, network, transport, consent gate, clock | the same, **plus an injected scheduler** |
| Attempt outcome | a failure or a success | a failure, a success, or **a success that arrives after its deadline** |

**The scheduler is injected** for the same reason the clock is: the eight guarantees are
proven in pure Dart with no real time elapsing, and a feature about waiting must not
make the suite wait.

**State the schedule may not reach into**: it never decides what to send. It wakes the
same `sincronizar()` the other two triggers call, and that one decides. A second path
that could send would be a second set of rules about G3, G4 and G5.

---

### `EstadoDeRed` — what the app believes about the network

The interface is unchanged. What changes is where the answer comes from.

| | Before | After |
|---|---|---|
| `hayConexion()` | asks a probe; the probe asks whether Firestore initialised | reports **the outcome of the last send attempt** |
| `cambios` | emits when that value changes; it never changed | emits when the last attempt's outcome changes, which it now does |
| Before any attempt | `true`, always and for ever | optimistic: assume reachable, because the first attempt is the probe |

**Why optimistic at the start**: a pessimistic default would withhold the first attempt,
and the first attempt is the only thing that can establish the answer.

---

### `ProgresoEnElMacrociclo` — where the swimmer is

No new member. One getter changes which of the three sets it reads.

| | Before | After |
|---|---|---|
| `pendientes` | past, dated sessions not in `hechas` | past, dated sessions in **`sinContestar`** |
| `hechas` | unchanged | unchanged |
| `dijoQueNo` | unchanged — and still unused by `pendientes`'s old rule | unchanged |
| `sinContestar` | **exists, tested, called by nothing in `lib/`** | the rule the pending list uses |

**The partition is the invariant**, and it is already asserted by the existing tests:
for the past, dated sessions, `hechas`, `dijoQueNo` and `sinContestar` are disjoint and
together they are all of them. After this change, `pendientes` is `sinContestar` — so the
invariant the tests already guard is the one the screens now depend on.

---

## What is new: one type

### `Lectura<T>` — the state of something being read

A sealed type in `lib/dominio/lectura/`, four cases:

| Case | Means | What the swimmer sees |
|---|---|---|
| `Cargando` | the reading has not finished | that it is loading |
| `Hay(valor)` | it finished and there is something | the thing |
| `NoHay` | it finished and there is genuinely nothing | the existing empty state, with its existing words |
| `NoSePudo(motivo)` | it finished and failed | that it could not be read |

**Why a type and not a flag**: two fields that can disagree is how this defect happened.
`estado.progreso` was `null` for both "not loaded yet" and "no plan", and the screen chose
the louder meaning. A sealed type makes the four cases exhaustive at the point of use, so
a screen cannot quietly handle three of them.

**Why in the domain**: two screens use it and it belongs to neither. It holds no Flutter,
which keeps principle II intact, and it follows the idiom this codebase already uses for
one-of-several outcomes — `ResultadoBusqueda`, `ResultadoTransicion`,
`ResultadoGeneracion`, `ResultadoDerivacion`.

**What it does not do**: it carries no retry, no network state and no message for the
swimmer. `NoSePudo` carries a reason for the screen to phrase; the screen owns the words,
and the words for `NoHay` stay exactly as they are today.

---

## Relationships, in one line each

- A **queued send** points at one **record** by its deterministic id, and that is why a
  late success and a retry cannot produce two of anything.
- The **network state** is derived from the last **attempt**, and from nothing else.
- The **pending list** is derived from the **sessions** and the **records**, never stored,
  so it cannot drift from what the swimmer wrote.
- A **`Lectura`** wraps whatever a screen is waiting for and owns none of it.
