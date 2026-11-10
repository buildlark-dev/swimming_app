# Specification Quality Checklist: Ver Plan and progression

**Purpose**: Validate specification completeness and quality before proceeding to planning
**Created**: 2026-11-04
**Feature**: [spec.md](../spec.md)

## Content Quality

- [x] No implementation details (languages, frameworks, APIs)
- [x] Focused on user value and business needs
- [x] Written for non-technical stakeholders
- [x] All mandatory sections completed

## Requirement Completeness

- [x] No [NEEDS CLARIFICATION] markers remain
- [x] Requirements are testable and unambiguous
- [x] Success criteria are measurable
- [x] Success criteria are technology-agnostic (no implementation details)
- [x] All acceptance scenarios are defined
- [x] Edge cases are identified
- [x] Scope is clearly bounded
- [x] Dependencies and assumptions identified

## Feature Readiness

- [x] All functional requirements have clear acceptance criteria
- [x] User scenarios cover primary flows
- [x] Feature meets measurable outcomes defined in Success Criteria
- [x] No implementation details leak into specification

## Notes

All three clarifications were closed on 2026-11-04 and are written into the spec's
`Clarifications` section with what each one brought with it:

- **What the coach confirms** — the work splits where the methodology splits it. The app
  proposes the temporal skeleton, which is arithmetic over section 12's block durations; the
  coach supplies the event model and the swimmer model, which no formula derives. It brought
  two obligations: the skeleton is **editable and shows its reason**, and the models may be
  pre-filled from his own record but **never from a formula**.
- **What the swimmer sees** — everything visible, folded. It brought the view opening at
  today rather than week one, and the folding controls going into the feature 005 bench: a
  disclosure control too small to hit is worse than no disclosure.
- **What gets versioned** — the mesocycle, where the ATR phase lives. It brought the rule that
  a readjustment touching several mesocycles is **one act** and one notice, and that the app
  can state which version of each mesocycle a swimmer is on.

Not marked, because the methodology or the constitution already answered them: whether phases
outside the published ranges block (they warn — section 12), whether the app may readjust on
its own (it may not — principle IV), and whether approval delivers (it does not — feature
001's lifecycle).

Three things for `/speckit-plan` to watch, in order of how quietly they can go wrong:

1. **FR-002 and SC-010 say nothing exists before the confirmation.** Easy to satisfy by
   accident today and easy to break later with a convenient preview. It needs a lock that
   looks at storage, not at the screen.
2. **The skeleton proposal is a training rule**, so principle III applies in full: test before
   implementation, with the block-duration boundaries and a negative control. It is the same
   shape as feature 008's phase derivation, and that one's boundaries were worth getting right.
3. **FR-035 says a readjustment must not alter what the swimmer already recorded.** Versioning
   a mesocycle under a swimmer who has already marked sessions inside it is exactly where that
   can be lost without anything failing.
