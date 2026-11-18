# Specification Quality Checklist: Repairs to the swimmer's journey

**Purpose**: Validate specification completeness and quality before proceeding to planning
**Created**: 2026-11-18
**Feature**: [spec.md](../spec.md)

## Content Quality

- [X] No implementation details (languages, frameworks, APIs)
- [X] Focused on user value and business needs
- [X] Written for non-technical stakeholders
- [X] All mandatory sections completed

## Requirement Completeness

- [X] No [NEEDS CLARIFICATION] markers remain
- [X] Requirements are testable and unambiguous
- [X] Success criteria are measurable
- [X] Success criteria are technology-agnostic (no implementation details)
- [X] All acceptance scenarios are defined
- [X] Edge cases are identified
- [X] Scope is clearly bounded
- [X] Dependencies and assumptions identified

## Feature Readiness

- [X] All functional requirements have clear acceptance criteria
- [X] User scenarios cover primary flows
- [X] Feature meets measurable outcomes defined in Success Criteria
- [X] No implementation details leak into specification

## Notes

Two things were checked harder than the rest, because this is a repair feature and
repair features drift into naming the repair instead of the promise.

**Implementation detail.** The input named classes, files and a line of code. The spec
names none of them: the requirements say what must be true for the swimmer — that what
she wrote leaves by itself, that the app never asks her to retry, that a screen does not
claim an absence it has not established. The one place the spec comes close is FR-002,
"attempting to send and seeing whether it arrives, not asking the device whether it has
a network interface", and it stays because it is a **product** decision with a reason a
coach understands: a pool with wifi that does not reach the internet is the normal case.
Which component does that, and how, is the plan's business.

**No clarification markers, deliberately.** Three candidates were considered and all
three had a defensible default already present in the product:

- *How often to probe, and what it costs.* Defaulted to: only while something is queued
  (FR-003), on the delay that already exists, capped. SC-004 forces the number to be
  written down rather than left vague, which is the part that was actually missing.
- *How long the swimmer may wait after the signal returns.* Defaulted to one minute
  (SC-001), which is what the existing delay allows and is well inside "she walked out of
  the building".
- *Whether returning connectivity should cut the retry delay short.* Defaulted to yes
  (FR-005), because the delay's own documented reason — not hammering a server that is
  not answering — stops applying the moment it answers. Without this, a working probe
  would still leave a record waiting up to five minutes, and SC-001 would fail with every
  mechanism in place. This was found while reading the backoff, not from the input.

**Scope boundary worth re-reading before planning**: the device walk is deferred to after
feature 013 by the coach's decision, so this feature cannot claim to close T071, T088 or
T089. The roadmap currently says 011 closes T071 and T088 and needs correcting.
