# Specification Quality Checklist: The swimmer's request

**Purpose**: Validate specification completeness and quality before proceeding to planning
**Created**: 2026-11-02
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

Las dos aclaraciones quedaron cerradas el 2026-11-02 y están escritas en la sección
`Clarifications` del spec, con sus consecuencias:

- **La fase ATR se deriva** de la fecha de competencia, con las duraciones de bloque que la
  sección 12 cita. Trajo una pregunta más al nadador —cuándo compite— y la obligación de que
  la fase derivada sea **visible y corregible**: una regla que decide metodología y no se
  puede ver sería criterio delegado por la puerta de atrás.
- **Las molestias no se preguntan**: se enlazan desde las sesiones de la feature 003. Trajo
  la obligación de decir de qué fechas salen y de decirlo explícitamente cuando no hay
  ninguna, porque un hueco en blanco se lee como «no le duele nada».

Lo que el prompt maestro o la constitución ya respondían, y por eso no se preguntó: de dónde
sale la categoría (la ficha), qué se hace sin diagnóstico técnico (progresión estándar, sin
inventar errores), y si una molestia modifica el plan (no).

Dos cosas para vigilar en `/speckit-plan`, porque son donde esta feature puede hacerse daño:

1. **La derivación de la fase es una regla de entrenamiento**, así que cae bajo el principio
   III: prueba antes que implementación, con control negativo. Las fronteras de 8-15 días y
   2-4 semanas son rangos, no líneas, y el plan tiene que decidir qué pasa en el solape.
2. **FR-038 dice que la solicitud no copia las molestias.** Es fácil de incumplir sin querer
   al construir la cola del entrenador, y el incumplimiento es un dato de salud duplicado.
