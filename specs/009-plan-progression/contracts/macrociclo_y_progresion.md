# Contract — Ver Plan and progression

Phase 1 of the plan. The guarantees this feature promises.

Guarantees are numbered `M1…Mn` ("macrociclo") so they can be cited from `tasks.md` and from
test names.

Unlike features 007 and 008, this one adds **no new server call**: everything it does is
writing plans and macrocycles through paths that already exist. So there is no wire-body
section here. What replaces it is the storage lock M10, because the thing most likely to go
wrong silently is a write that happens before it should.

---

## The single confirmation

**M1** — The app proposes a temporal skeleton: how many blocks, each one's ATR phase, each
one's length, counted back from the competition date.

**M2** — The skeleton shows **why it came out that way**, per block, in weeks until the
competition. A block whose reason cannot be read is methodology decided in silence.

**M3** — Every part of the skeleton is editable before confirmation: the number of blocks,
their phases and their lengths.

**M4** — The coach supplies the event model and the swimmer model. The app **never derives
them from a formula**. It may pre-fill them from the swimmer's record — technical diagnosis,
target event, marks — because those are observations he already made.

**M5** — A block outside the published durations **warns and does not block**. Section 12 says
swimming uses longer phases than the general literature.

**M6** — A category that does not use ATR gets one block with no phase. The engine forbids a
phase there, and the app says so rather than leaving it blank.

**M7** — With the swimmer's record incomplete, the app says what is missing instead of
proposing a skeleton built on gaps.

---

## What gets derived

**M8** — From the confirmed structure, mesocycles, microcycles and sessions are derived in one
operation, with **no further confirmation** asked between levels.

**M9** — The derivation drives the feature 002 engine once per microcycle. No second path
produces sessions, and no language model takes part in any field.

**M10** — **Nothing is stored before the confirmation.** Verified over the repositories after
proposing and before confirming, not over the screen: that a thing is not shown says nothing
about whether it exists.

**M11** — Every derived level records the methodology version it was built under.

**M12** — Deriving twice from the same structure and the same record produces the same
macrocycle. Verified by deriving twice and comparing, never against a stored fixture: a fixture
would hide an input read from the clock.

**M13** — The derived macrocycle is born `borrador`, and it cannot be approved until every one
of its mesocycles passes the section 16 audit — the same audit as any other plan, not a lighter
one.

**M14** — A macrocycle cannot be `aprobado` while any of its mesocycles is not.

---

## Delivery

**M15** — Approving the macrocycle is **one act** for the coach, however many mesocycles it
contains.

**M16** — Delivery is likewise one act, and it is **all or nothing**: a swimmer seeing four of
seven mesocycles is worse than seeing none.

**M17** — Signing is not delivering, here as everywhere else since feature 001.

---

## What the swimmer sees

**M18** — A delivered macrocycle is visible whole from the first day: the structure unfolded,
and **any** session expandable on a tap, including one six weeks out.

**M19** — The view opens positioned at today, not at the first week.

**M20** — The swimmer sees where today falls and which mesocycle they are working.

**M21** — The swimmer is told the plan may change according to how they respond, in Spanish
and without jargon.

**M22** — The expand controls are measured at 200% font and for tappable area, in the feature
005 bench. A control a nine-year-old cannot hit makes the content reachable in principle and
not in practice.

**M23** — A swimmer with no macrocycle still gets what feature 003 gives them, and is not shown
an empty hierarchy.

---

## Marking what was done

**M24** — A session dated after today cannot be marked done **by any path**, and the app
explains why.

**M25** — A session dated today or earlier can always be marked, whatever happened to the ones
before it.

**M26** — When a session is marked with earlier ones outstanding, the app says which ones are
outstanding. It shows the gap; it does not deny the fact.

**M27** — An outstanding session stays markable later. A skipped day is not a closed door.

**M28** — A session with no date cannot be marked, and the app says that rather than guessing
when it was meant to happen.

**M29** — What the coach sees as adherence is what the swimmer recorded, with skips visible as
skips rather than as missing data.

---

## Readjustment

**M30** — Only the coach readjusts. The app never readjusts on its own, however clear the
adherence data looks.

**M31** — A readjustment creates a new version of each affected **mesocycle**, through the
version lineage that already exists.

**M32** — A readjustment touching several mesocycles is **one act** for the coach and **one
notice** to the swimmer, not one per mesocycle.

**M33** — The app can state which version of each mesocycle a swimmer is currently on, without
the coach working it out.

**M34** — **A readjustment does not alter or lose what the swimmer already recorded.** Verified
by checking the records are still *reachable* after versioning, not by checking that the write
succeeded — records are keyed by session id, and a new version with new ids would orphan them
without anything failing.

**M35** — A readjustment passes the section 16 audit before it reaches the swimmer, and does
not reach them without the coach's signature.

---

## What this contract does not promise

- Any analysis of how the swimmer responded: that is feature 010
- Video, and the feedback request that goes with it
- Automatic readjustment of any kind
- Macrocycles for a group rather than one swimmer
- Importing a macrocycle written outside the app
