# Verificación de extremo a extremo — Feature 005

**Feature**: tema visual y sistema de componentes
**Contrato**: [sistema_visual.md](contracts/sistema_visual.md)

Cada escenario trae su línea **«Falla si…»**, que es donde está lo útil: dice qué cuenta
como roto, no solo qué mirar.

---

## Recorrido completo (tarea T044)

Corrido el 2026-10-20 sobre la rama `005-visual-theme`.

| Escenario | Qué lo cubre | Estado |
|---|---|---|
| C1 — las pantallas hacen lo mismo | `flutter test` entero: **1130 pruebas**, de las que 1056 son de las features 001 a 004 y **ninguna se modificó** | ✅ |
| C2 — ningún color a mano | `frontera_tema_test.dart`, 4 pruebas. Se comprobó metiendo un `Color(0xFF123456)` y viéndola fallar con archivo y línea | ✅ |
| C3 — el contraste se mide | `contraste_test.dart`, 14 pruebas. Mide contra los **fondos reales** del tema, no contra un blanco supuesto | ✅ |
| C4 — las zonas sin color | `escala_de_zonas_test.dart`, 11 pruebas. Separación en **L\***, no en luminancia cruda | ✅ |
| C5 — la letra al 200% | `tamano_de_letra_test.dart`, 16 pruebas, sobre las siete pantallas en un teléfono de 360×640 | ✅ |
| C6 — «guardado» deja de ser rojo | `avisos_test.dart`, 10 pruebas, incluido el cerrojo de FR-016 | ✅ |
| C7 — la molestia no alarma | `molestia_test.dart`, 6 pruebas, en los dos modos | ✅ |
| C8 — claro y oscuro | `modo_oscuro_test.dart`, 26 pruebas | ✅ |
| C9 — la app abre aunque el tema falle | `arranque_sin_tema_test.dart`, 6 pruebas | ✅ |
| — áreas pulsables | `area_pulsable_test.dart`, 12 pruebas, contra el árbol de semántica | ✅ |
| — los componentes no deciden | `componentes_test.dart`, 18 pruebas | ✅ |
| — los estados del plan | `estados_de_plan_test.dart`, 11 pruebas | ✅ |
| — las cifras no bailan | `cifras_tabulares_test.dart`, 3 pruebas | ✅ |
| **V10 — mirarlo de verdad** | **El entrenador, en un teléfono.** «Se ve muy bien al aire libre con sol y sin sol» (2026-10-21) | ✅ |

**V10 era la única que no podía cerrar ninguna máquina**, y por eso estaba la última. El
contraste calculado es condición necesaria, no suficiente: una pantalla puede cumplir el
número y seguir siendo incómoda al sol. **Los trece escenarios están cubiertos.**

---

## Preparación

```bash
flutter run -d chrome
```

Para ver los dos modos, se cambia el tema del sistema operativo y se vuelve a abrir.

---

## C1 — Las pantallas siguen haciendo lo mismo

**Es el escenario que hace esta feature fusionable.**

```bash
flutter test
```

**Esperado**: las 995 pruebas que ya existían pasan **sin haber modificado ninguna**.

**Falla si** hubo que tocar una sola para que pasara. Eso significaría que el tema cambió un
comportamiento, y el fallo sería de esta feature, no de la prueba.

---

## C2 — Ningún color escrito a mano

```bash
flutter test test/ui/tema/frontera_tema_test.dart
```

**Esperado**: pasa. Y si se añade a propósito un `Color(0xFF123456)` en cualquier pantalla,
**falla nombrando el archivo y la línea**.

**Falla si** pasa con el color metido. Una frontera que no caza nada no es una frontera.

---

## C3 — El contraste se mide

```bash
flutter test test/ui/tema/contraste_test.dart
```

**Esperado**: todos los pares cumplen su mínimo, en claro y en oscuro, **y las siete zonas
una por una**.

**Falla si** algún par queda por debajo, o si la prueba comprueba un promedio en lugar de
cada caso. Una rampa suele cumplir en los extremos y fallar en medio.

---

## C4 — Las zonas se distinguen sin color

```bash
flutter test test/ui/tema/escala_de_zonas_test.dart
```

**Esperado**: las siete tienen luminancias separadas y en el orden de intensidad de la
metodología.

**Falla si** dos zonas se confunden en gris, o si el orden visual no coincide con el de la
sección 9. Lo segundo sería enseñar una ordenación que la metodología no hace.

---

## C5 — El tamaño de letra al 200%

```bash
flutter test test/ui/tema/tamano_de_letra_test.dart
```

**Esperado**: ninguna pantalla recorta, superpone ni oculta texto.

**Falla si** algo desborda. No es un caso extremo: hay personas que llevan el teléfono así
siempre.

---

## C6 — «Guardado» deja de ser rojo

1. Abrir la app sin conexión.
2. Anotar una sesión.

**Esperado**: el aviso de que quedó guardado y se enviará luego usa el tono de **éxito**.

**Falla si** sigue viéndose como un error. Es una buena noticia: significa que la bandeja de
salida de la feature 003 hizo su trabajo.

---

## C7 — La molestia se encuentra, pero no alarma

Con una sesión que lleve reporte de molestia, mirarla desde la pantalla del entrenador.

**Esperado**: se localiza sin leer todas las observaciones, y **no usa el tono de error**.

**Falla si** se ve como una emergencia médica. El principio IV prohíbe que la app
diagnostique o proponga conducta, y pintarla de rojo es una forma de opinar.

---

## C8 — Claro y oscuro

Cambiar el tema del sistema y recorrer las pantallas en los dos modos.

**Esperado**: el oscuro sale solo, sin configurar nada, y todo significa lo mismo en los
dos.

**Falla si** hay que configurarlo, si alguna pantalla se queda en claro, o si un estado se
reconoce en un modo y en el otro no.

---

## C9 — La app abre aunque el tema falle

Con un tema que lanza al construirse.

**Esperado**: la app abre con la apariencia por omisión.

**Falla si** no abre. Ya pasó una vez en este proyecto, con Firebase: un fallo que debía
degradar tumbaba el arranque entero.

---

## V10 — Mirarlo de verdad

Lo que ninguna prueba automática dice: **si se ve bien**.

1. Abrir la app en un teléfono, al aire libre, con sol.
2. Recorrer las pantallas en claro y en oscuro.

**Esperado**: se lee sin acercarse la pantalla a la cara, y parece la misma app en todas
partes.

**Falla si** hay que buscar sombra para leerlo. El contraste calculado es condición
necesaria, no suficiente: una pantalla puede cumplir el número y seguir siendo incómoda al
sol.

---

## Puertas de calidad

Antes de cerrar la feature, en este orden:

```bash
flutter analyze
```

```bash
flutter test
```

```bash
npm --prefix firebase test
```

```bash
dart run tool/verificar_metodologia.dart
```

Y **el despliegue**, que desde la feature 004 ya no es opcional: la app está en uso. Con la
secuencia de `docs/DEVELOPMENT.md` y comprobando el sitio en vivo, no dando por bueno un
«deploy complete».
