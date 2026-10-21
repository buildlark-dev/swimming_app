# Plan de implementación: tema visual y sistema de componentes

**Branch**: `005-visual-theme` | **Date**: 2026-10-20 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/005-tema-visual/spec.md`

## Summary

La app está desplegada y su aspecto salió de un color semilla puesto en una línea. Esta
feature decide la identidad, y sobre todo **decide dónde vive**, para que las pantallas del
alta de cuenta (006) y del HUB (007) no vuelvan a improvisar.

El enfoque técnico se apoya en una propiedad que ya tenemos y que no hay que construir:
**ninguna de las veintiuna pantallas contiene un color escrito a mano**. Todas leen del
esquema de color. Así que el trabajo no es limpiar: es **definir bien el sistema y cerrar la
puerta** para que siga siendo cierto.

Esa clausura es la decisión principal del plan. `flutter analyze` no sabe decir «este
widget usa un color literal», así que la regla se hace cumplir como se hizo la frontera del
dominio en la feature 001: **con una prueba que lee el código fuente**. Lo que no está
comprobado, se erosiona.

## Technical Context

**Language/Version**: Dart 3.12.2, Flutter 3.44.2

**Primary Dependencies**: ninguna nueva. Material 3 ya está activo (`useMaterial3: true`) y
trae esquema de color, escala tipográfica y temas de componente. El principio VII pide
nombrar el problema que resuelve una dependencia; «queremos otros colores» no lo es.

**Storage**: nada. Esta feature no persiste ni lee nada. El modo claro/oscuro sigue al
sistema, así que no hay preferencia que guardar (decisión D3).

**Testing**: `flutter_test`. Tres clases de prueba, y las tres son automáticas:
contraste calculado sobre la paleta, frontera del tema leyendo el código fuente, y pruebas
de interfaz con el tamaño de letra forzado.

**Target Platform**: web y móvil. El uso real es **a pie de piscina**: sol directo, pantalla
mojada, y un niño de nueve años con un teléfono pequeño.

**Project Type**: aplicación Flutter. Esta feature vive entera en `lib/ui/`.

**Performance Goals**: ninguna propia. La única exigencia es no empeorar el arranque, que es
lo que mide el escenario C1 de la feature 003.

**Constraints**:
- **No cambia lo que hace ninguna pantalla.** Es la condición que hace esto fusionable.
- Contraste mínimo cumplido en claro **y** en oscuro.
- El color **nunca** es la única señal.
- La app abre aunque el tema falle.
- Sin dependencias nuevas.

**Scale/Scope**: 21 pantallas existentes, 7 zonas de intensidad, 3 estados de plan, 4 tonos
de aviso.

## Constitution Check

*GATE: debe pasar antes de la Fase 0 y volver a comprobarse tras la Fase 1.*

| Principio | Cómo lo cumple | Estado |
|---|---|---|
| **I. Metodología como norma** | La escala de zonas respeta el orden de intensidad de la sección 9, y no inventa agrupaciones que la metodología no hace. Los nombres siguen siendo los suyos: el color acompaña a la etiqueta, no la sustituye | ✅ |
| **II. Dominio en Dart puro** | La feature vive entera en `lib/ui/`. **El dominio no sabe de colores**: la correspondencia entre `Zona` y su aspecto se declara en la interfaz, no en la entidad. La prueba de frontera lo vigila | ✅ |
| **III. Pruebas de las reglas que llegan al nadador** | Contraste, frontera y tamaño de letra se comprueban automáticamente. Lo que el nadador ve a pie de piscina es exactamente lo que estas pruebas miden | ✅ |
| **IV. El criterio del entrenador no se delega** | FR-014: un reporte de molestia se encuentra sin leerlo todo y **no se viste de alarma médica**. El principio llega hasta la paleta | ✅ |
| **V. Datos de deportistas** | No toca datos. Ni recoge, ni muestra, ni guarda nada nuevo | ✅ |
| **VI. Freemium honesto** | Nada queda detrás de un muro de pago porque no hay cobro, y el tema no distingue niveles | ✅ |
| **VII. Rebanadas verticales y simplicidad** | **Cero dependencias nuevas.** Cuatro historias comprobables por separado. La tipografía se resuelve sin descargar nada (decisión D2) | ✅ |
| **VIII. Control de carga interna** | No la toca. Lo que sí hace es dejar de pintar de rojo el aviso de «guardado, se enviará luego», que es el mecanismo de la 003 funcionando con normalidad | ✅ |

Sin desviaciones que declarar.

## Project Structure

### Documentation (this feature)

```text
specs/005-tema-visual/
├── plan.md              # Este archivo
├── research.md          # Fase 0: cinco decisiones
├── data-model.md        # Fase 1: los tokens y la escala de zonas
├── quickstart.md        # Fase 1: verificación
├── contracts/
│   └── sistema_visual.md
├── checklists/
│   └── requirements.md
└── tasks.md             # Fase 2: lo produce /speckit-tasks
```

### Source Code (repository root)

```text
lib/ui/tema/
├── tema.dart                 # Los dos ThemeData, claro y oscuro
├── paleta.dart               # Los colores crudos. El ÚNICO archivo con literales
├── tipografia.dart           # Escala de texto
├── espaciado.dart            # Separaciones y radios
├── avisos.dart               # Los cuatro tonos: informativo, éxito, cuidado, error
└── dominio/
    ├── escala_de_zonas.dart  # Las 7 zonas: color + un segundo canal
    └── estados_de_plan.dart  # borrador, aprobado, publicado

lib/ui/componentes/
├── tarjeta.dart
├── campo.dart
├── boton.dart
├── aviso.dart                # Reemplaza los avisos repetidos de hoy
├── cabecera_seccion.dart
└── estado_vacio.dart

test/ui/tema/
├── contraste_test.dart       # Calcula la relación de contraste de cada par
├── frontera_tema_test.dart   # Ningún literal fuera de paleta.dart
├── escala_de_zonas_test.dart # Distinguibles en gris, y en el orden correcto
└── tamano_de_letra_test.dart # Las pantallas al 200%
```

**Structure Decision**: el tema vive en `lib/ui/tema/` y **`paleta.dart` es el único archivo
del proyecto autorizado a contener un literal de color**. Esa frase es la feature entera: si
hay un segundo archivo que pueda, en un mes hay cinco.

La subcarpeta `dominio/` dentro de `lib/ui/tema/` es deliberada y no contradice al principio
II: **traduce** conceptos del dominio a aspecto, y vive en la interfaz. `Zona` no sabe de
qué color es; es la interfaz la que lo decide.

## Complexity Tracking

Sin violaciones que justificar. Esta feature **quita** complejidad: sustituye avisos
reconstruidos en cada pantalla por un componente, y una decisión implícita de color por una
escrita.
