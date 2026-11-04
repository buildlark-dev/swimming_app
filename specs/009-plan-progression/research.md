# Research: Ver Plan and progression

**Feature**: 009-plan-progression · **Date**: 2026-11-04

Everything here was resolved by reading what the repository and the methodology already say.
The first finding is the one that decides the shape of the feature, so it goes first.

---

## D1 — A `Plan` is already a mesocycle in everything but its name

**Decision**: `Mesociclo` is **not a new type**. The existing `Plan` is it. The only genuinely
new entity is `Macrociclo`, a container of `Plan`s plus the structure the coach confirmed.

**Rationale**: read `lib/dominio/entidades/plan.dart` and the mapping is already there:

| What `Plan` has today | What a mesocycle is |
|---|---|
| **one** `faseAtr` | a block with one ATR phase |
| several `microciclos` | the weeks inside the block |
| several `sesiones` | their sessions |
| `fechaInicio`, `fechaFin` | the block's dates |
| `estado`: `borrador` → `aprobado` → `publicado` | content that reaches a swimmer only when signed |
| `versionAnteriorId`, `crearVersionDesde` | the versioning the readjustment needs |
| `versionMetodologia`, `justificaciones` | what FR-013 asks every level to record |

A plan with one ATR phase and several microcycles **is** a mesocycle. The project has been
building mesocycles since feature 001 and calling them plans.

This matters more than naming, because of FR-031: **the mesocycle is the unit that gets a new
version**. Making it a new type would mean rebuilding the lifecycle, the section 16 audit, the
assignment, the immutability rule and the version lineage for the exact unit that already has
all five, tested since feature 001. Principle VII is explicit that this project cannot afford
that: one person maintains it, and he also coaches.

**Alternatives considered**:

- *A new `Mesociclo` type holding `Plan`s* — rejected. It would make a mesocycle a container of
  one-ATR-phase plans, which is the same thing one level down, and would duplicate the
  lifecycle.
- *`Plan` becomes the macrocycle, with a new `Mesociclo` inside* — rejected and worth saying
  why: `Plan.faseAtr` is a single value. A macrocycle spans three phases. Either the field
  becomes a list, which breaks every audit criterion that reads it, or it goes unused at the
  top, which leaves a field that means nothing on the most important entity.

**What this costs**: the word "plan" now means a mesocycle in the code and something looser in
conversation. The visible vocabulary is unaffected — the swimmer sees `Ver Plan` and reads
mesocycle names — but the data model needs this written down, which is why it leads.

---

## D2 — The temporal skeleton: proposed, editable, and showing its reason

**Decision**: a pure domain function takes the competition date, today and the category, and
returns a proposed list of blocks — phase, start, end, weeks — **with the reason written out**.
The coach can change the count, the phases and the lengths before confirming.

**Rationale**: it is the same shape as feature 008's `faseParaCompetencia`, and for the same
reason: deriving methodology without showing why would be judgement delegated silently. The
boundaries come from the durations section 12 cites (Issurin 2010): Realización 8-15 days,
Transformación 2-4 weeks, Acumulación 2-6 weeks, and section 12's own note that swimming uses
longer phases, which is why FR-012 says **warn, never block**.

The skeleton is laid out backwards from the competition — Realización last, then Transformación,
then Acumulación filling whatever remains — because that is the order the model is defined in
and because the taper is the part whose position is least negotiable.

**Alternatives considered**: deriving forward from today — rejected: it makes the competition
date a consequence of the plan's length rather than its anchor.

**Risk**: this is a training rule, so principle III applies in full. The boundary weeks need
tests before the implementation, with a negative control, exactly as feature 008's derivation
did — and that one's boundaries took two attempts to get right.

---

## D3 — What the coach confirms, and what he may be shown

**Decision**: `EstructuraConfirmada` holds the event model and the swimmer model, plus the
skeleton as he left it. It is **stored**, because it is the input the derivation is reproducible
from and the record of what he actually decided.

The models may be pre-filled from the swimmer's record — `diagnosticoTecnico`, `pruebaObjetivo`,
`marcas` — and **from nothing else**. Those are observations the coach already made, so offering
them back is showing him his own work.

**Rationale**: constitution v2.0.0 reserves exactly this to him. Pre-filling fatigue tolerance
or motivation from age and category would be the app inventing the one thing the amendment
protected. Clarification Q1 says so and the spec repeats it; this is where it becomes a type.

---

## D4 — Deriving the macrocycle drives the existing engine, once per microcycle

**Decision**: the derivation builds one `PeticionGeneracion` per microcycle and calls the
feature 002 generator, then groups the results into mesocycle `Plan`s.

**Rationale**: the engine is the methodology. A second path that produced sessions some other
way would be a second methodology, which is what principle I forbids in substance. The
accentuated component per microcycle comes from `componenteParaFase`, which feature 008 already
built and which passes the engine's own coherence check by construction.

**Consequence worth stating**: a fourteen-week macrocycle is fourteen generator calls. They are
pure and fast, but the determinism test must generate **twice and compare**, never against a
stored fixture — a fixture would hide an input read from the clock, which is exactly the trap
feature 008 wrote down.

---

## D5 — Delivery is one act for the coach and several writes underneath

**Decision**: approving the macrocycle approves its mesocycles; delivering it publishes and
assigns each of them. One act, one confirmation, several documents.

**Rationale**: the spec's assumption, and feature 007's `Ver Plan` already has the delivery
act. What this feature must not do is make the coach press deliver fourteen times.

**Open for the plan**: whether a partially failed delivery leaves a macrocycle half delivered.
It must not — the swimmer seeing four of seven mesocycles is worse than seeing none.

---

## D6 — Marking what was done: the rule is about the date, not the order

**Decision**: a session whose date is after today cannot be marked. A session whose date has
passed can always be marked, whatever happened to the ones before it, and what is outstanding
is **shown, not enforced**.

**Rationale**: it is the coach's decision of 2026-11-04, and the reason is in section 4, step 8.
Readjustment runs on adherence data. A rule that stops a swimmer recording a session they
actually swam makes the app lie about what happened, and then the readjustment is modelling a
fiction. The honest version shows the gap instead of denying the fact.

**Where it lives**: a pure function over the session's date and today — no repository, no
screen. `Sesion.fecha` is nullable, so a session with no date is treated as not-yet-dated and
cannot be marked: the app does not guess when something was meant to happen.

---

## D7 — Progress is computed, never stored

**Decision**: where the swimmer is inside the macrocycle, what is done and what is outstanding
are derived from the feature 003 records at read time.

**Rationale**: `ProgresoNadador` already does this for one plan — `SesionConRegistro` pairs the
programmed session with the swimmer's answer. Extending it upward is arithmetic. Storing it
would create a second thing that can disagree with the first, and the first is the one the
swimmer wrote.

---

## D8 — Readjustment versions mesocycles, and tells the swimmer once

**Decision**: readjusting creates a new version of each affected mesocycle through the existing
`crearVersionDesde`, in one act, with one notice to the swimmer however many mesocycles moved.

**Rationale**: FR-031 and FR-032. `crearVersionDesde` already refuses to version a draft and
already carries the origin forward, which is the behaviour this needs.

**The risk to watch**, and it is the quiet one: a mesocycle being versioned may contain sessions
the swimmer has already marked. FR-035 says that must not be altered or lost. Records are keyed
by `sesionId`, so a new version whose sessions get new ids would orphan them silently — nothing
would fail, the swimmer's history would just go blank. The plan has to decide whether session
ids are stable across versions, and the test has to check the records are still reachable
afterwards rather than checking that the write succeeded.

---

## D9 — The folded view, and what it owes the bench

**Decision**: the structure renders unfolded; every session is expandable, including distant
ones; the list opens scrolled to today.

**Rationale**: clarification Q2. Nothing hidden, nothing dumped.

**What it owes**: the expand controls go into the feature 005 screen bench, measured at 200%
font and for tappable area. A disclosure control a nine-year-old cannot hit is worse than no
disclosure, because the content is formally reachable and practically is not.

---

## D10 — Nothing exists before the confirmation

**Decision**: no mesocycle, no microcycle, no session and no macrocycle document is written
until the coach confirms. The proposed skeleton lives in memory until then.

**Rationale**: FR-002 and SC-010. It is trivially true today because nothing is built yet, and
that is exactly the danger: the first convenient preview that saves a draft breaks it without
anything failing.

**How it is locked**: a test that asserts the repositories are empty after proposing and before
confirming — **over storage, not over the screen**. Feature 008 learned this twice: that a
thing is not shown says nothing about whether it exists.

---

## Risks this feature carries

- **The skeleton proposal is methodology decided by software.** Mitigated as feature 008's
  phase was: editable, with its reason visible, and tested at the boundaries with a negative
  control.
- **A readjustment can silently orphan a swimmer's records** (D8). This is the one that would
  not announce itself.
- **Fourteen generator calls and sixty sessions** make the derivation the heaviest thing the
  app does. If it is slow it will be slow on the coach's phone, not in a test.
- **"Plan" now means mesocycle in the code.** Written into the data model so the next feature
  does not rediscover it.
