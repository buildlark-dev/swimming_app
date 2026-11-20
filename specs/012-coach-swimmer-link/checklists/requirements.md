# Specification Quality Checklist: The coach → swimmer relation

**Purpose**: Validate specification completeness and quality before proceeding to planning
**Created**: 2026-11-19
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

**The brief asked the spec to decide what the relation *is* — and it deliberately does
not.** "An owner field on `Nadador`, a separate collection of links, or the macrocycle as
proof of the link" is a storage question, and storage is the plan's. What the spec owes
the plan is the **shape**, and that is decided: one community per swimmer at a time, one
coach per community, a membership that is a fact with a start, and a request that only
the coach's acceptance turns into one. Those constrain the storage choice without making
it, which is the right division. FR-017 adds the one constraint that matters in this
product: the boundary is proven by **the queries the app makes**, because in this system
a query is proven by its filters and not document by document — a lesson feature 009 paid
for twice.

**One thing the brief did not know, and it changed the spec.** Today the coach creates
swimmer profiles himself, from his own screen — `Nuevo perfil`. So there are two ways a
swimmer comes to exist, and the relation is born differently in each: a profile he
creates is his from the moment he creates it (FR-013), and only a swimmer who signs up on
her own has to ask. It also settles what happens to everyone who already exists (FR-027):
he created every one of them, so linking them to him is a statement of fact rather than a
migration guess. That removed the sharpest clarification question before it was asked.

**Zero clarification markers, and the candidates are recorded rather than hidden.** Four
were considered:

- *What happens to swimmers who already exist* — settled by the fact above.
- *Whether the guardian's consent must name the coach* — defaulted to naming the
  community in the request when there is one (FR-028). It is strictly more information
  for the guardian and changes nothing about what the consent permits, so it needs no
  decision from anyone.
- *Whether a swimmer can belong to more than one community* — defaulted to one, which is
  what the constitution's "a community led by *a* coach" describes.
- *Whether a decline carries a reason* — defaulted to no, since a free-text message
  reaching someone who is not your swimmer is a liability with no upside.

**The one requirement that is really a warning**: FR-018. Inverting the second-coach test
removes one of the five `assertSucceeds` that made that suite's negative control
meaningful — against a collection with no rule, 5 of 10 passed, and the only failures
were the five that assert a success. After the inversion, the control must be re-run and
its new numbers recorded, because the suite's ability to catch a missing rule changes.
A spec that said only "invert the test" would have quietly weakened the thing that proves
the tests work.
