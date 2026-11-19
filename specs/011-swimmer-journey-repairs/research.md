# Phase 0 — Research: Repairs to the swimmer's journey

Six decisions. The first one carries the other five, and the last two are small enough
that the research is mostly "read what is already there and notice it was never used".

---

## D1 — The attempt is the probe. Nothing else is asked about the network

**Decision**: there is no separate network check. The app learns whether it has a network
by trying to send what is queued and seeing whether it arrives. `EstadoDeRed` stops
asking anything and starts reporting **the outcome of the last attempt**, which is what
its own file has said the detection should be since feature 003.

**Rationale**:

The probe in place today is `sondear: () async => datos != null`, wired in `main.dart`
directly beneath a comment that says the opposite of what the line does:

> La detección de red sondea de verdad en lugar de preguntarle al sistema: «hay wifi» y
> «el servidor responde» son cosas distintas, y a pie de piscina la segunda es la que
> importa.

The line asks whether Firestore initialised. That is true with the airplane on, forever,
so the value never changes, so the stream never emits, so the trigger that listens to it
could never fire — and nothing listens to it anyway. Two independent failures, and
either alone would have been enough.

What makes the repair possible now and not before: feature 010's walk gave the send a
deadline. Before that an attempt that never returned was not an answer, so "try and see"
would have hung instead of reporting. With a bounded attempt, the attempt **is** the
answer, and it is the only one that is true: it tests the whole path to the server rather
than the first hop out of the phone.

It also satisfies FR-003 by construction. There is nothing to attempt when the queue is
empty, so an empty queue costs nothing — no sockets, no timers, no wake-ups.

**Alternatives considered**:

- **Ask the operating system** (`connectivity_plus` or similar). Rejected twice over.
  It adds a dependency, which principle VII requires justifying by the problem it solves
  — and it does not solve this one. It answers "is there an interface", and the question
  is "does the server answer". A pool with wifi that does not reach the internet is the
  normal case in this product, not the rare one. The project wrote that down before it
  had been bitten; being bitten does not make it wrong.
- **A cheap read of a known document as a heartbeat.** Rejected: a read with persistence
  on can be served from the local cache, so a successful probe would prove nothing, and
  forcing it to the server costs a billed read every cycle for information the send is
  about to produce for free.
- **Keep `hayConexion()` as a gate and make it honest.** This is what is being done, but
  the direction is reversed: it stops being a gate consulted *before* deciding whether to
  try, and becomes a report of what trying last produced. A gate in front of the only
  thing that can answer the question is what produced this defect.

---

## D2 — The queue drives a schedule, and the delay's cap drops from five minutes to one

**Decision**: while something is queued, `Sincronizador` keeps a wake-up scheduled and
retries on the per-record delay that already exists — 1, 2, 4, 8… seconds — with its cap
lowered from 300 seconds to **60**. With an empty queue, no wake-up is scheduled at all.

**Rationale**:

The second trigger of the sync contract — "when the network comes back" — has no
mechanism once D1 removes the idea of detecting a return. What replaces it delivers the
same promise to the swimmer: she touches nothing, and it goes. The trigger becomes *keep
trying while something waits*, and the schedule is the backoff the product already has,
already documented, already tested.

**The cap has to move, and this is the one place the feature changes a decision feature
003 wrote down.** `EnvioPendiente.esperaHastaElSiguiente` caps at five minutes, with its
reason stated: *«No se reintenta en bucle apretado: el teléfono tiene batería limitada y
es de alguien que está nadando»*. That reason is still right. But SC-001 promises the
record arrives within a minute of the signal returning, and with a five-minute cap a
record that has already failed a few times would sit for up to five minutes after the
network was back — every mechanism in place and the promise still broken. One attempt a
minute is not a tight loop; the original reason survives the change intact.

**What FR-005 means once the attempt is the probe.** A single queued record has no
separate "the network came back" to react to: its own next attempt *is* the discovery,
and the one-minute cap is what keeps that inside SC-001. The cut-short applies **between**
records — when one attempt succeeds, that is proof the server is answering, so everything
else in the queue is tried at once instead of serving out its own delay. Without it, a
swimmer who annotated five sessions offline would watch them trickle out one slow delay
at a time with every mechanism in place.

**What it costs**, which SC-004 requires in a number: with one record queued and no
network, at most **60 attempts an hour** in the steady state, each a bounded write that
never reaches a server. Zero reads. Zero billed operations, since an attempt that does
not arrive is not an operation anyone charges for. With an empty queue: **zero of
everything**.

**Alternatives considered**:

- **Keep the five-minute cap and relax SC-001 to five minutes.** Rejected: the whole
  defect is a sentence that stays on her screen after it has stopped being true, and five
  minutes of that is the defect in a smaller size.
- **Keep the cap and add a cheap hint** from the OS to cut the wait short. Rejected:
  that is D1's rejected dependency arriving through a side door, and for a wait that one
  attempt a minute already removes.
- **A fixed interval instead of a backoff.** Rejected: the backoff's growth is what keeps
  the first few seconds responsive and the long tail cheap, and it is already tested.

---

## D3 — A late success is honoured, so the notice cannot outlive the sending

**Decision**: when an attempt exceeds its deadline, the underlying send is **not
abandoned**. Its future is kept; if it completes later, the record is marked sent and the
notice clears. No extra request is made to find out.

**Rationale**:

This is the cause of the fourth defect, and it is not a bug in our code so much as a
consequence of how the platform's queue works: a `set()` that we stop waiting for is
still in Firestore's own queue, and it lands when the signal returns. The server then
holds the record while our outbox still counts it waiting — which is why the walk saw the
notice survive a successful send.

`Future.timeout` does not cancel what it wraps; it only stops *us* waiting. So the
information we need already exists and arrives for free. Attaching to it is cheaper, and
truer, than asking the server whether it has the record: that question costs a read, and
offline the read is answered from the cache, which would say yes about something that
never left.

It also keeps FR-016 honest. The notice clears because the record **arrived** — someone
confirmed it — and never because we stopped looking.

**Alternatives considered**:

- **Read the record back on each sync to reconcile.** Rejected: a billed read per queued
  record per cycle, and offline it lies.
- **Trust the deterministic id and clear the notice optimistically.** Rejected outright:
  that makes the notice mean "we sent something once", which is exactly the promise
  feature 003 refuses to make.
- **Cancel the underlying write on timeout.** Not possible with the SDK, and not
  desirable: the write landing by itself is the behaviour that saves the record.

---

## D4 — "Still reading" is a state, not a null

**Decision**: a small sealed type in the domain — `Lectura<T>` with `Cargando`, `Hay`,
`NoHay` and `NoSePudo` — replaces the nullable the swimmer's screens use to decide
whether to show an empty state.

**Rationale**:

`PantallaMiProgreso` reads `estado.progreso`, which is `null` both before anything has
loaded and when there is genuinely no plan. One value, two meanings, and the screen picks
the louder one: *«Todavía no tienes un plan asignado»*, shown for the twenty seconds the
plan takes to arrive. `PantallaSesionDelDia` has the same line and the same flaw.

A sealed type is this project's existing idiom for "one of several outcomes" —
`ResultadoBusqueda`, `ResultadoTransicion`, `ResultadoGeneracion`, `ResultadoDerivacion`
all do it — so this adds a word to a vocabulary that is already there rather than a new
pattern. It also makes the fourth state, *could not be read*, expressible, which the
nullable never was: today a failure and an absence look identical to the swimmer.

The wording stays exactly as it is. `EstadoVacio` keeps its sentence, and it is shown
only for `NoHay`.

**Alternatives considered**:

- **A `bool cargando` beside the nullable.** Rejected: two fields that can disagree, and
  nothing stops a screen reading one and not the other — which is how this defect
  happened in the first place.
- **Show a spinner whenever the value is null.** Rejected: it turns the genuine empty
  state into an endless spinner for a swimmer with no plan, trading a false sentence for
  a screen that never resolves.
- **Fix only `Mi progreso`.** Rejected: the same sentence is in two files, and fixing one
  leaves the other to be rediscovered by the next walk.

---

## D5 — The pending list reads the set that already exists

**Decision**: `ProgresoEnElMacrociclo.pendientes` is derived from `sinContestar` instead
of excluding only `hechas`. No new concept, no new field.

**Rationale**:

The class already computes exactly the right thing and already documents why it matters:

> **No es lo mismo que no haber contestado**… «No la hice» es un dato: el nadador estuvo
> ahí y dijo lo que pasó. «No contestó» es la ausencia de un dato… Mezclarlas le enseñaría
> al entrenador un hueco donde hay una respuesta, o una respuesta donde hay un hueco.

`sinContestar` is tested — one of its tests asserts that done, refused and unanswered
partition the past sessions exactly, with no overlap — and **nothing in `lib/` calls it**.
`pendientes` was written beside it, excluding only `hechas`, and that is the one the
screens use.

So this is the same shape as the first defect: the right thing exists, it is proven, and
it was never connected. The repair is three lines and the risk is close to zero, because
the behaviour it switches to is the behaviour already under test.

FR-011's other two rules come along unchanged: `sinContestar` already requires a date and
already requires the date to be before today.

**Alternatives considered**:

- **Change `hechas` to include the refusals.** Rejected: it would make a set named "the
  ones she did" contain ones she did not, and would break the partition its tests assert.
- **Filter at the screen.** Rejected: two screens read this, and the coach's count must
  equal hers (FR-012). One rule, one place.

---

## D6 — The schedule starts and stops with the swimmer's session

**Decision**: `Sincronizador` owns the scheduling and exposes starting and stopping it.
`EstadoNadador` starts it when a swimmer's journey opens and stops it in `dispose()`,
which the HUB already calls.

**Rationale**:

The HUB creates `EstadoNadador`, holds it for as long as the swimmer is in the app, and
disposes it — `_nadador.dispose()` is already there. That is exactly the lifetime a
retry schedule should have: it should not outlive the session, and it should not be
owned by a screen that comes and goes.

The schedule itself lives in the domain so it can be tested without a widget and without
real time, with the clock already injected and the wake-up injected beside it. A timer
left running past a sign-out is how a swimmer's queue would keep working after her
brother signed in, which is feature 004's C7 — still deferred, and not a scenario to make
worse while it is unwatched.

**Alternatives considered**:

- **A timer inside a widget's `initState`.** Rejected: it dies and restarts with every
  rebuild and every tab change, and it drags domain behaviour into the interface against
  principle II.
- **A single app-wide schedule started in `main`.** Rejected: it has no natural stop, and
  it would run for a signed-out app with somebody else's queue on the device.

---

## What this research did not decide

**Nothing about verifying it on a phone.** Scenarios C1 and C2 of feature 003 and C7 and
C8 of feature 004 are walked together after feature 013, by the coach's decision. Every
decision above is testable without a device, and `quickstart.md` says which part of each
is still waiting for one.
