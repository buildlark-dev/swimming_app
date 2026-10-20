# Swimming App

[![CI](https://github.com/buildlark-dev/swimming_app/actions/workflows/ci.yml/badge.svg)](https://github.com/buildlark-dev/swimming_app/actions/workflows/ci.yml)

A swimming training-plan app built on a coach's documented methodology, with Flutter + Firebase. The app does not interpret the methodology, it enforces it.

## Problem
Building periodized training plans by hand is slow and error-prone, and generic AI tools ignore a coach's category volumes, ATR distributions and approved exercise library.

## Solution
A deterministic microcycle generator: the coach declares category, ATR phase, target stroke, days and pool, and the app returns a fully squared week (volume within range, phase zone distribution, technical %, stroke split) using only exercises from the official Library. 
Same inputs, same plan. Offline and free: composition comes from coded rules, not a language model. If data is missing or contradictory, it explains why and generates nothing.

## Key features
- Deterministic plan generator + 11-criterion audit engine
- Hybrid session editor that parses the coach's own notation
- Plan lifecycle: draft -> approved -> published (approved plans are immutable)
- Swimmer profiles, and delivery as a record of its own
- Offline-first for the swimmer: reading and writing never require a network
- Accounts and roles, with every permission enforced in the security rules
- Verifiable guardian consent, which gates a swimmer's data ever leaving their device

## Tech stack
- Flutter/Dart - Firebase - Cloud Functions (TypeScript) - Web + mobile

## Architecture highlights
Pure domain layer (lib/dominio/) with no Flutter or Firebase; a test enforces the boundary.

Firestore access rules with their own negative-case test suite. The rules and the
client-side permission table read **the same list of cases**, so a rule changed
without its counterpart fails the other side the same day.

The consent gate lives in the rules, not in a screen. A swimmer with no consent on
file is never blocked from using the app — what is held back is their data reaching
the coach, waiting in the outbox until a guardian authorises it.

The server does four things and never a fifth; which four, and what is forbidden from
ever entering it, is written down in
[the feature's research notes](specs/004-cuentas-y-consentimiento/research.md).

**Status**
In active development. Not deployed, and not yet used by any real swimmer: the
informative consent text still needs legal review. See
[docs/DEVELOPMENT.md](docs/DEVELOPMENT.md).

## Demo
Live demo / video: Not published yet.

Screenshots: Soon.

### For local setup and deployment, see [docs/DEVELOPMENT.md](docs/DEVELOPMENT.md).
