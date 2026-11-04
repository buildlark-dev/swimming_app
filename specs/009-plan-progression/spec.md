# Feature Specification: Ver Plan and progression

**Feature Branch**: `009-plan-progression`

**Created**: 2026-11-04

**Status**: Draft

**Input**: User description (translated from the coach's Spanish): "Ver Plan and progression. The plan stops being a loose week: the macrocycle and the mesocycle appear, which do not exist in the domain today. The coach confirms **once** the macrocycle's general structure — modelling the event and modelling the swimmer, which the methodology does not let a formula derive — and, with that structure fixed, the app derives mesocycles, microcycles and sessions in one go. The macrocycle is delivered to the swimmer complete from day one: they see the whole path, and are told it may change depending on how they respond. As they advance they annotate their own things on it. They cannot mark a session done whose date has not arrived, and that is explained; they can mark a past one even if they skipped an earlier one, and the app tells them which one is outstanding instead of blocking them. When the coach readjusts after seeing how they responded, what changes gets a new version and the swimmer sees that their coach adjusted that part. Every level records the methodology version it was built under. The visible vocabulary stays in Spanish."

> **A note on language.** This specification is written in English because everything
> published to GitHub is. The **visible vocabulary of the app stays in Spanish** and in the
> coach's own notation (`Ver Plan`, `Generar`, AL, PN, RPE). Where this document quotes what
> a person sees on screen, it quotes it in Spanish.

## What makes this feature different

Two things, and both are bigger than the screen work.

**The domain has `Microciclo` and nothing above it.** There is no `Macrociclo` and no
`Mesociclo`. The feature 002 engine produces one squared week; this feature introduces the
hierarchy the methodology has always assumed.

**It is the first feature built under constitution v2.0.0.** The amendment of 2026-11-04
restated principle IV: what the constitution requires is the decision point, not the number
of phases. Section 18's six confirmations exist because a language model's accuracy degrades
over a long output; a deterministic engine does not degrade. So **one** confirmation remains
— the macrocycle's general structure, which is steps 2 and 3 of section 4, modelling the
event and modelling the swimmer — and the rest derives by construction.

This spec has to show where that single confirmation lives. If it cannot be pointed at, the
amendment has been used to skip a rule rather than to restate it.

## Clarifications

### Session 2026-11-04

- **Q: What does the coach actually confirm — the whole structure from scratch, or one the
  app proposes?**
  → **A: the work is split where the methodology splits it.** The app proposes the **temporal
  skeleton** — how many blocks, which ATR phase each one is, how long, counted back from the
  competition date — because that is arithmetic over the block durations section 12 cites. The
  coach supplies what no formula derives: **the event model and the swimmer model**, steps 2
  and 3 of section 4.

  Two consequences, written down so they are not discovered later:

  1. **A proposal he cannot change is not a proposal.** The skeleton arrives editable — number
     of blocks, their phases, their lengths — and it shows **why** it came out that way, in
     weeks until the competition, the same way feature 008's derived phase shows its reason. A
     skeleton that could not be seen or corrected would be the software deciding the shape of
     a season.
  2. **The models may be pre-filled from his own record of the swimmer, never from a formula.**
     The technical diagnosis, the target event and the marks are observations he already made,
     so offering them back is showing him his own work. Deriving a swimmer's fatigue tolerance
     or motivation from category and age would be the app inventing the one thing the
     amendment reserved for him.

- **Q: On a phone, what does "sees the whole path" mean for a macrocycle of sixty-odd
  sessions?**
  → **A: everything visible, folded.** The structure is open — mesocycles, their names, their
  objectives, their dates — and any session expands on a tap, including one six weeks out.
  Nothing is hidden and nothing is dumped on a nine-year-old at once.

  The cost, stated plainly: this is more interface work than either alternative, and **a
  folded list of seventy sessions is still long**. So the view opens positioned at today
  rather than at week one, and the folding has to be measured at 200% font and in tappable
  areas like every other screen since feature 005 — a disclosure control too small to hit is
  worse than no disclosure at all.

- **Q: When the coach readjusts, what gets a new version?**
  → **A: the mesocycle.** It is where the ATR phase lives, so it is the unit that actually
  gets readjusted, and the history stays readable: «ajustó el mesociclo 2».

  What follows from it: a readjustment that moves the structure — the competition changed
  date, say — touches several mesocycles at once. That is **one act for the coach** even
  though it versions more than one mesocycle, and the swimmer is told once, not four times.
  And «which plan is this swimmer on» is answered by the macrocycle plus the current version
  of each of its mesocycles, which the app has to be able to state without him working it out.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - The coach confirms the structure, once (Priority: P1)

The coach starts a macrocycle for a swimmer. The app asks him for what only he knows: the
target event's demands and this swimmer's model — dominant stroke, observed technical errors,
pace, fatigue tolerance, recovery. He confirms it. From there the app derives the mesocycles,
their ATR phases, the microcycles and every session, in one go, and shows him the whole thing
to review.

**Why this priority**: it is the decision point the constitution protects. Without it the
feature would be the software deciding how a swimmer's season is shaped.

**Independent Test**: fully testable with a coach account: start a macrocycle, confirm the
structure, and check that a complete hierarchy comes back and that nothing was derived before
the confirmation.

**Acceptance Scenarios**:

1. **Given** a swimmer with a complete record, **When** the coach starts a macrocycle,
   **Then** he is asked for the event model and the swimmer model, and nothing is generated
   until he confirms
2. **Given** a confirmed structure, **When** the app derives, **Then** mesocycles, microcycles
   and sessions all appear at once, with no further confirmation asked
3. **Given** a derived macrocycle, **When** the coach reviews it, **Then** every level shows
   which methodology version it was built under
4. **Given** a macrocycle whose phase durations fall outside the published block ranges,
   **When** it is derived, **Then** the app **warns and does not block** — the methodology
   says swimming uses longer phases than the general literature
5. **Given** an incomplete swimmer record, **When** the coach starts a macrocycle, **Then** he
   is told what is missing rather than being given a structure built on gaps

---

### User Story 2 - The swimmer sees the whole path from day one (Priority: P1)

The delivered macrocycle arrives whole. The swimmer sees where they are inside it, which
mesocycle they are working, and what comes after — and they are told, in their own words, that
it can change depending on how they respond.

**Why this priority**: it is the half of the feature the swimmer lives in, and it is what the
coach chose over a progressive reveal: seeing the whole road is worth more than the suspense
of unlocking it.

**Independent Test**: with a delivered macrocycle, the swimmer opens `Ver Plan` and can walk
from today to the last week without anything being hidden.

**Acceptance Scenarios**:

1. **Given** a delivered macrocycle, **When** the swimmer opens `Ver Plan`, **Then** they see
   the whole structure and where today falls inside it
2. **Given** that view, **When** they look at it, **Then** they are told it may change
   according to how they respond, in Spanish and without jargon
3. **Given** a macrocycle of fourteen weeks, **When** the swimmer looks at it on a phone,
   **Then** they can find today's session without scrolling through the whole season
4. **Given** a swimmer with no macrocycle, **When** they open `Ver Plan`, **Then** they see
   what feature 003 already gives them and are not shown an empty hierarchy

---

### User Story 3 - Marking what was done, honestly (Priority: P1)

The swimmer marks sessions as they do them. A session whose date has not arrived cannot be
marked, and the app says why. A past session can be marked even if an earlier one was skipped
— and the app says which one is outstanding, instead of blocking it.

**Why this priority**: the adherence data this produces is what the coach's readjustment runs
on (section 4, step 8). A rule that makes the app lie about what happened corrupts the one
input that readjustment needs.

**Independent Test**: with a delivered macrocycle, try to mark a future session, then mark a
past one while skipping the one before it.

**Acceptance Scenarios**:

1. **Given** a session dated tomorrow, **When** the swimmer tries to mark it done, **Then**
   they cannot, and the app explains that the day has not arrived
2. **Given** Tuesday skipped and Thursday done, **When** the swimmer marks Thursday, **Then**
   it is marked, and the app tells them Tuesday is outstanding
3. **Given** that outstanding session, **When** the swimmer looks at it later, **Then** they
   can still mark it: a skipped day is not a closed door
4. **Given** a marked session, **When** the coach looks at adherence, **Then** what he sees is
   what the swimmer actually did, with the skip visible as a skip

---

### User Story 4 - The coach readjusts, and the swimmer is told (Priority: P2)

After seeing how the swimmer responded, the coach adjusts what is left. What changes gets a
new version, and the swimmer sees that their coach adjusted that part — the path does not
change under their feet in silence.

**Why this priority**: it is section 4's step 8, *controlar y reajustar*, which is what makes
the plan a model rather than a calendar. It comes after the first three because the macrocycle
has to exist and be lived in before there is anything to readjust.

**Independent Test**: readjust a delivered macrocycle and check that the swimmer sees what
changed and that the previous version is still traceable.

**Acceptance Scenarios**:

1. **Given** a delivered macrocycle and some sessions done, **When** the coach readjusts,
   **Then** what changes gets a new version and the previous one stays traceable
2. **Given** that readjustment, **When** the swimmer opens their plan, **Then** they see that
   their coach adjusted that part, without having to compare it themselves
3. **Given** sessions already marked done, **When** a readjustment lands, **Then** what the
   swimmer already recorded is not altered or lost
4. **Given** a readjustment, **When** it is saved, **Then** it passes the section 16 audit
   like any other content that reaches a swimmer

---

### Edge Cases

- **The competition moves.** The structure was built counting back from a date that changed.
  The coach readjusts; the app does not silently re-derive a season because a date moved.
- **A macrocycle of 60 sessions on a phone.** Showing every series of every session at once is
  unreadable. What "the whole path" means on a small screen is clarification Q2.
- **The swimmer already has a one-off microcycle** from a feature 008 request. The two
  coexist: the macrocycle does not retroactively swallow a plan that was signed on its own.
- **A session is marked done and then the swimmer realises it was the wrong one.** Out of
  scope here; feature 003's record is what it is, and correcting it is its own question.
- **The macrocycle ends.** The swimmer reaches the last session. They are told the cycle
  finished and that the next one is their coach's to prepare — not left on an empty screen.
- **A phase falls outside the published block durations.** The methodology says to warn, not to
  suspend: swimming uses longer phases than the general literature.
- **The coach never confirms the structure.** Nothing is derived and nothing is delivered.
  There is no partial macrocycle sitting anywhere.

## Requirements *(mandatory)*

### Functional Requirements

**The single confirmation**

- **FR-001**: The app MUST ask the coach to model the target event and model the swimmer
  before any part of a macrocycle is derived
- **FR-002**: The app MUST NOT derive any mesocycle, microcycle or session before that
  confirmation
- **FR-003**: The app MUST NOT ask for a second confirmation between derived levels: with a
  deterministic engine there is no judgement left to delegate below the structure
  (constitution v2.0.0, principle IV)
- **FR-004**: The app MUST propose a **temporal skeleton** — how many blocks, each one's ATR
  phase, each one's length — counted back from the competition date using the block durations
  section 12 cites
- **FR-005**: The proposed skeleton MUST be editable by the coach: number of blocks, phases
  and lengths
- **FR-006**: The proposed skeleton MUST show **why it came out that way**, in weeks until the
  competition
- **FR-007**: The coach MUST supply the event model and the swimmer model, and the app MUST
  NOT derive them from any formula
- **FR-008**: The app MAY pre-fill the models from the swimmer's own record — technical
  diagnosis, target event, marks — because those are observations the coach already made
- **FR-009**: The app MUST tell the coach what is missing, rather than deriving on gaps, when
  the swimmer's record is incomplete (rule R3)

**What gets derived**

- **FR-010**: From the confirmed structure the app MUST derive mesocycles, microcycles and
  sessions in one operation
- **FR-011**: Every derived level MUST record the methodology version it was built under
- **FR-012**: Mesocycle ATR phases MUST follow the block durations section 12 cites, and the
  app MUST **warn without blocking** when a phase falls outside them
- **FR-013**: The derivation MUST be deterministic: the same structure and the same record
  produce the same macrocycle
- **FR-014**: No language model MUST take part in deriving any level
- **FR-015**: The derived macrocycle MUST be born in state `borrador` and pass the section 16
  audit before it can be approved, like any other automated output

**What the swimmer sees**

- **FR-016**: A delivered macrocycle MUST be visible to the swimmer whole, from the first day
- **FR-017**: The swimmer MUST see where today falls inside the macrocycle and which mesocycle
  they are working
- **FR-018**: The app MUST tell the swimmer that the plan can change according to how they
  respond
- **FR-019**: The swimmer MUST be able to reach today's session without walking the whole
  season
- **FR-020**: The structure MUST be visible unfolded — mesocycles, names, objectives, dates —
  and **any** session MUST expand on a tap, including one six weeks out. Nothing is hidden
- **FR-021**: The view MUST open positioned at today, not at the first week
- **FR-022**: The folding controls MUST be measured at 200% font and in tappable areas, like
  every screen since feature 005: a disclosure control too small to hit is worse than none
- **FR-023**: The visible vocabulary MUST stay in Spanish and in the coach's notation

**Marking what was done**

- **FR-024**: The swimmer MUST NOT be able to mark done a session whose date has not arrived,
  and the app MUST explain why
- **FR-025**: The swimmer MUST be able to mark a past session done even if an earlier one was
  skipped
- **FR-026**: When a session is marked with earlier ones outstanding, the app MUST say which
  ones are outstanding
- **FR-027**: An outstanding session MUST remain markable later: a skipped day is not a closed
  door
- **FR-028**: What the coach sees as adherence MUST be what the swimmer recorded, with skips
  visible as skips and not as absences of data

**Readjustment**

- **FR-029**: The coach MUST be able to readjust a delivered macrocycle after seeing how the
  swimmer responded
- **FR-030**: A readjustment MUST produce a new version of what changed, and the previous
  version MUST stay traceable
- **FR-031**: The unit that gets a new version MUST be the **mesocycle**: it is where the ATR
  phase lives, so it is what actually gets readjusted
- **FR-032**: A readjustment that touches several mesocycles MUST be **one act** for the
  coach, and the swimmer MUST be told once rather than once per mesocycle
- **FR-033**: The app MUST be able to state which version of each mesocycle a swimmer is
  currently on, without the coach working it out
- **FR-034**: The swimmer MUST see that their coach adjusted that part, without having to
  compare versions themselves
- **FR-035**: A readjustment MUST NOT alter or lose what the swimmer already recorded
- **FR-036**: A readjustment MUST pass the section 16 audit before it reaches the swimmer
- **FR-037**: Only the coach MUST be able to readjust, and the readjustment MUST NOT reach the
  swimmer without his signature

### Key Entities

- **Macrociclo**: a whole preparation towards a target event. Carries the structure the coach
  confirmed, its mesocycles, the methodology version, its state and its version lineage
- **Mesociclo**: a block inside the macrocycle with one ATR phase and its microcycles. It is
  where the phase lives, which is what makes it the natural unit of readjustment
- **Microciclo**: already exists. Gains its place inside a mesocycle, and keeps being named by
  its accentuated component rather than its position
- **Estructura confirmada**: what the coach decided — the event model and the swimmer model.
  It is kept because it is the input the derivation is reproducible from, and because it is
  the record of what he actually decided
- **Progreso del nadador**: where they are inside the macrocycle, which sessions are done and
  which are outstanding. Built from the feature 003 records; **not a second copy of them**

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A coach produces a full macrocycle from one confirmation, with no further
  prompts between levels
- **SC-002**: 100% of derived levels record the methodology version they were built under
- **SC-003**: The same structure and record derive the same macrocycle, verified by deriving
  twice and comparing rather than against a stored fixture
- **SC-004**: No macrocycle reaches a swimmer without the coach's signature — verifiable in
  100% of cases, including one that passes the audit first time
- **SC-005**: A nine-year-old finds today's session inside a fourteen-week macrocycle in under
  thirty seconds, on a phone
- **SC-006**: No session with a future date can be marked done, by any path
- **SC-007**: A swimmer who skipped a session can still mark the next one, and both the skip
  and the completion are visible to the coach
- **SC-008**: After a readjustment, what the swimmer had already recorded is unchanged in 100%
  of cases
- **SC-009**: A readjustment is visible to the swimmer without them comparing anything
- **SC-010**: No part of a macrocycle exists anywhere before the coach confirms the structure

## Assumptions

- **Delivery stays one act.** Approving the macrocycle signs it; delivering it is the separate
  act `Ver Plan` already has since feature 007. Firmar no es entregar, here as elsewhere
- **The macrocycle is delivered whole**, not mesocycle by mesocycle. That is the coach's
  decision of 2026-11-04: the swimmer seeing the whole road is worth more than the coach
  keeping the option to revise what has not been shown yet
- **A one-off microcycle and a macrocycle coexist.** A plan signed on its own — from a feature
  008 request, or generated by hand — is not swallowed by a macrocycle that arrives later
- **Progress is derived from feature 003's records**, not stored again. A second copy would be
  a second thing that can disagree with the first
- **The macrocycle's length comes from the competition date**, the same source feature 008's
  phase derivation uses. The methodology's own figure for context: macrocycles of 14-15 weeks
  are associated with peak performance
- **Readjustment is the coach's, always.** The app never readjusts on its own, however clear
  the adherence data looks. Section 4 step 8 is his judgement, not a trigger
- **Phase durations warn rather than block**, as section 12 says: swimming uses longer phases
  than the general literature, and the app does not know better than the coach

## Dependencies

- **Feature 002** (deterministic engine) — produces each microcycle. The derivation drives it
  once per microcycle rather than reimplementing it
- **Feature 001** (lifecycle and audit) — the macrocycle is born, audited, approved and
  versioned with what already exists
- **Feature 003** (the swimmer consumes the plan) — marking done, RPE and observations already
  work per session; this feature puts them inside a hierarchy
- **Feature 007** (the HUB) — `Ver Plan` for both roles, and delivery

## Out of Scope

- The detailed analysis of how the swimmer responded: that is feature 010
- Video, and the feedback request that goes with it
- Automatic readjustment of any kind
- Macrocycles for a group rather than one swimmer
- Importing an existing macrocycle written outside the app
