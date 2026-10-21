---

description: "Lista de tareas de la feature 005 — tema visual y sistema de componentes"
---

# Tasks: Tema visual y sistema de componentes

**Input**: documentos de diseño de `specs/005-tema-visual/`

**Prerequisites**: [plan.md](plan.md), [spec.md](spec.md), [research.md](research.md),
[data-model.md](data-model.md), [contracts/](contracts/)

**Tests**: **sí, y no son opcionales.** El principio III es «NO NEGOCIABLE» para lo que
llega al nadador, y lo que esta feature cambia es exactamente lo que el nadador ve a pie de
piscina. Además, la decisión D1 —que ningún color se escriba a mano— **solo existe si una
prueba la vigila**: sin ella es una buena intención.

**Organization**: las tareas se agrupan por historia de usuario.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: se puede hacer en paralelo (archivos distintos, sin dependencias pendientes)
- **[Story]**: a qué historia de `spec.md` pertenece (US1 a US4)

---

## Antes de empezar: la condición que ordena todo

Esta feature se fusiona sobre una app **desplegada y en uso**. La garantía V13 dice que
**ninguna pantalla cambia lo que hace**, y su prueba no es una prueba nueva: es que **las
995 que ya existen pasen sin tocarlas**.

Por eso ninguna tarea de esta lista autoriza a modificar una prueba de las features 001 a
004. Si una falla, el tema cambió un comportamiento y hay que arreglar el tema, no la
prueba.

El orden de las fases coincide esta vez con el de prioridades, con un matiz: **la paleta
incluye los valores de oscuro desde la fase 2**, aunque el modo oscuro no se enchufe hasta
la fase 5. Así la prueba de contraste puede medir los dos juegos desde el principio, en
lugar de medir medio sistema y volver después.

---

## Phase 1: Setup

**Purpose**: dejar el terreno listo. Nada de esto se ve en la app.

- [X] T001 [P] Crear las carpetas con un archivo `library;` de marcador: `lib/ui/tema/`, `lib/ui/tema/dominio/`, `lib/ui/componentes/`, `test/ui/tema/`
- [X] T002 Inventariar en `specs/005-tema-visual/research.md`, como decisión D6, **todos los sitios donde hoy se lee del esquema de color**, con archivo y rol usado. Es la lista contra la que se comprueba al final que ninguna pantalla cambió de significado. Hoy son 50 usos, 27 de ellos del color de error

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: los tokens y, sobre todo, **el cerrojo**. Sin esto no empieza ninguna historia.

**⚠️ CRITICAL**: ninguna historia puede empezar hasta que esta fase esté completa.

### El cerrojo primero

- [X] T003 Escribir en `test/ui/tema/frontera_tema_test.dart` la garantía V1 **antes de que exista la paleta**: recorre `lib/` leyendo el código fuente y falla si encuentra `Color(0x...)` o `Colors.loQueSea` fuera de `lib/ui/tema/paleta.dart`, nombrando archivo y línea. Escribirla antes importa: después se escribiría para que pase con lo que ya hay
- [X] T004 Comprobar que T003 **caza de verdad**: meter un `Color(0xFF123456)` en una pantalla cualquiera, ver fallar la prueba con el archivo y la línea correctos, y quitarlo. Una frontera que no caza nada no es una frontera
- [X] T005 [P] Ampliar `test/ui/tema/frontera_tema_test.dart` con la garantía V2: tamaños de letra y espaciados literales fuera de `tipografia.dart` y `espaciado.dart`

### Los tokens

- [X] T006 Crear `lib/ui/tema/paleta.dart` con los colores crudos, **en claro y en oscuro desde ya** (decisión D3 y nota de arriba). Es el único archivo del proyecto autorizado a contener literales de color. Grupos según `data-model.md`: marca, superficies, avisos, zonas, estados de plan
- [X] T007 **Proponer al entrenador los valores concretos de la paleta** y esperar su aprobación antes de seguir. `research.md` lo dejó fuera a propósito: son azules marinos y su identidad, no una decisión técnica. Las restricciones que la propuesta debe cumplir ya están fijadas: azules marinos, contraste comprobado, y la rampa de zonas por claridad
- [X] T008 [P] Crear `lib/ui/tema/tipografia.dart` con la escala sobre la fuente del sistema (decisión D2), **con el uso de cada nivel declarado**. Un nivel sin uso declarado es un nivel que alguien usará para otra cosa
- [X] T009 [P] Crear `lib/ui/tema/espaciado.dart` con separaciones, radios y **el tamaño mínimo de área pulsable** (FR-006), que vive aquí porque es una medida
- [X] T010 [P] Crear `lib/ui/tema/avisos.dart` con los cuatro tonos —informativo, éxito, cuidado, error— según la tabla de `data-model.md`
- [X] T011 Crear `lib/ui/tema/tema.dart` que arme los dos `ThemeData` a partir de los tokens, y enchufar el claro en `lib/main.dart` sustituyendo el `colorSchemeSeed` de una línea
- [X] T012 Hacer que `lib/main.dart` arranque con la apariencia por omisión si el tema no se pudiera construir (garantía V14). Ya hubo un caso en este proyecto —el arranque sin Firebase del PR #5— donde un fallo que debía degradar tumbaba el arranque entero
- [X] T013 [P] Escribir en `test/ui/tema/arranque_sin_tema_test.dart` la garantía V14, con un doble que lanza al construir el tema, comprobando que la app sigue en pie

**Checkpoint**: hay tokens y hay cerrojo. La app ya se ve distinta en claro.

---

## Phase 3: User Story 1 — La app se lee a pie de piscina (Priority: P1)

**Goal**: que el nadador lea lo que le toca con el teléfono mojado y el sol encima, y acierte
el toque a la primera.

**Independent Test**: abrir la app en un teléfono al aire libre y recorrer la sesión del día
sin ampliar el texto ni fallar un toque (escenario V10 del quickstart).

### Las pruebas que miden

- [X] T014 [P] [US1] Escribir en `test/ui/tema/contraste_test.dart` el cálculo de la relación de contraste y la garantía V4: **cada par declarado** de texto y fondo cumple su mínimo, en claro y en oscuro, fallando con el par y el valor obtenido. Se mide, no se opina
- [X] T015 [P] [US1] Añadir la garantía V5: las siete zonas cumplen el contraste **una por una**, nunca de media. Una rampa suele cumplir en los extremos y fallar en medio, y un promedio lo esconde
- [X] T016 [P] [US1] Escribir en `test/ui/tema/tamano_de_letra_test.dart` la garantía V7: abrir las pantallas con el factor de escala al **200%** y fallar ante cualquier desbordamiento. No es un caso extremo: hay personas que llevan el teléfono así siempre
- [X] T017 [P] [US1] Escribir en `test/ui/tema/area_pulsable_test.dart` la garantía V6: toda área sensible alcanza el mínimo, aunque su icono sea más pequeño

### Lo que hace que pasen

- [X] T018 [US1] Ajustar los valores de `paleta.dart` hasta que T014 y T015 pasen en los dos modos. **Si un color bonito no cumple, gana el contraste**: la app se usa al sol
- [X] T019 [US1] Fijar en `lib/ui/tema/tema.dart` los tamaños mínimos de los controles para que T017 pase sin que cada pantalla lo repita
- [X] T020 [US1] Fijar **tabulación de cifras** en los niveles tipográficos donde se muestran series (FR-008). `4x100 / 1'40"` es una instrucción de entrenamiento: si las columnas bailan, se lee mal, y leer mal una cifra cambia lo que el nadador hace
- [X] T021 [US1] Corregir en las pantallas existentes lo que T016 destape, **sin cambiar lo que dicen ni lo que hacen**

**Checkpoint**: se lee. Medido, no opinado.

### Lo que destapó esta fase

T016 encontró **siete sitios que se desbordaban**, y ninguno lo había causado el tema:

| Sitio | Qué pasaba |
|---|---|
| `pantalla_editor.dart` barra superior | Los totales en vivo se salían 49 px al 200%. Bajaron a la cabecera de la sesión |
| `pantalla_sesion_del_dia.dart` barra superior | «Al día hasta el 20/10 a las 07:00» se salía 279 px. Bajó al cuerpo, junto al aviso del que habla |
| `_SelectorRpe` del editor | Etiqueta y deslizador en una fila: 402 px fuera. Ahora la etiqueta va encima |
| `_CampoParte` del editor | Cabecera de parte, 6 desbordes. `Wrap` en lugar de `Row` |
| Desplegable de categoría del editor | El séptimo que faltaba de los seis de la fase 2: `isExpanded` |
| `_ParteVista` del nadador y `formulario_registro.dart` | Cabeceras de dos piezas que no caben juntas con la letra grande |
| `_FilaReparto` de `panel_distribucion.dart` | **Se salía 50 px en un teléfono de 360 puntos con la letra normal.** Los anchos fijos sumaban 354 sobre 304 disponibles, y no se veía porque las pruebas de widget miden en una ventana de 800 |

El último no es un problema de accesibilidad: es un fallo que el entrenador ya estaba
viendo en su teléfono y que ninguna prueba contaba. **Medir al 200% en una pantalla de 360
encontró un fallo del 100%.**

T020 añadió `test/ui/tema/cifras_tabulares_test.dart`, que `tasks.md` no había previsto: la
tabulación es invisible, y una `copyWith` descuidada la quita sin que nada falle.

---

## Phase 4: User Story 2 — Todas las pantallas parecen la misma app (Priority: P1)

**Goal**: que los elementos repetidos sean el mismo componente, no seis parecidos.

**Independent Test**: recorrer las pantallas existentes y comprobar que tarjetas, campos,
botones y avisos se ven y se comportan igual (escenario C1 del quickstart).

- [X] T022 [P] [US2] Crear `lib/ui/componentes/aviso.dart`, que recibe **cuál de los cuatro tonos** es. Es el componente que más se repite hoy y el que peor está: casi todos los avisos de la app son rojos
- [X] T023 [P] [US2] Crear `lib/ui/componentes/tarjeta.dart`
- [X] T024 [P] [US2] Crear `lib/ui/componentes/campo.dart`
- [X] T025 [P] [US2] Crear `lib/ui/componentes/boton.dart`
- [X] T026 [P] [US2] Crear `lib/ui/componentes/cabecera_seccion.dart`
- [X] T027 [P] [US2] Crear `lib/ui/componentes/estado_vacio.dart`, para «Todavía no tienes un plan asignado» y sus hermanos
- [X] T028 [US2] Sustituir por `Aviso` los avisos de `lib/ui/nadador/aviso_sincronizacion.dart`, `lib/main.dart` (modo local y barra de sesión) y `lib/ui/editor/panel_avisos.dart`, **asignando a cada uno su tono correcto**. El de sincronización pasa a éxito: ver T031
- [X] T029 [US2] Sustituir por los componentes nuevos los elementos repetidos del resto de pantallas de `lib/ui/`, sin cambiar lo que hacen
- [X] T030 [P] [US2] Escribir en `test/ui/tema/componentes_test.dart` la garantía V3: un componente no contiene valores propios, los toma de los tokens. Si uno necesita un valor que no está, **falta un token**, y no se añade el valor al componente

**Checkpoint**: lo repetido está decidido una vez.

### Dos desviaciones del plan, a propósito

**No hay `BotonSecundario`.** Se escribió y se quitó: la app no tiene hoy **ni un solo
`OutlinedButton`**, así que era un componente para un sitio que no existe. Cuando el HUB de
la feature 007 necesite una acción secundaria de verdad, se añade con su primer uso al lado.
Es la misma disciplina que la de los tokens, al revés: no se añade por si acaso.

**`Tarjeta` no sustituyó las quince tarjetas de la app, sino tres.** El proyecto no está
formateado con `dart format` —73 de 96 archivos difieren—, así que quitar un nivel de
anidamiento exige reindentar a mano el método entero. Se hizo donde el panel es
autocontenido (`tabla_auditoria`, `respuestas_del_nadador`, y dentro de `EstadoVacio`) y se
dejó en las pantallas grandes, que se tocarán de todos modos en las features 007 a 010. Lo
que decide la tarjeta —borde, radio, color, margen— ya lo pone `cardTheme` una vez; lo único
que quedaba repetido es el relleno de dentro.

### Lo que cazó la garantía V7, otra vez

`BotonPrincipal` con icono se salía **64 píxeles** del botón al 200%: `FilledButton.icon` de
Material envuelve su etiqueta en un `Flexible` y al escribir esa fila a mano se quedó fuera.
Lo encontró el banco de pantallas de la fase 3 **en el mismo commit en que se introdujo**.

También cazó una prueba de la feature 004: poner la clave en el envoltorio en lugar del
`FilledButton` de dentro rompió `confirmacion_test.dart`, que busca el botón por clave para
preguntarle si está habilitado. Se arregló el componente, no la prueba.

---

## Phase 5: User Story 3 — Claro y oscuro (Priority: P2)

**Goal**: que la app respete el modo del teléfono y se vea bien en los dos.

**Independent Test**: cambiar el tema del sistema y recorrer las pantallas en los dos modos
(escenario C8 del quickstart).

- [X] T031 [US3] Enchufar `darkTheme` en `lib/main.dart` con `ThemeMode.system`, sin ajuste propio ni preferencia guardada (decisión D3). El interruptor pertenece a la pantalla de Ajustes de la feature 007
- [X] T032 [P] [US3] Escribir en `test/ui/tema/modo_oscuro_test.dart` la garantía V11: un mismo significado se reconoce igual en los dos modos
- [X] T033 [US3] Recorrer las pantallas en oscuro y corregir lo que se vea mal, **sin cambiar comportamiento**

**Checkpoint**: la app deja de ser un rectángulo blanco de noche.

### T033 no encontró nada que arreglar, y eso significa algo

Se recorrieron las siete pantallas en oscuro, pintadas a imagen con una fuente real para
poder mirarlas de verdad. **No hubo que corregir una sola.**

No es suerte: es la garantía V1. Al prohibir los literales de color, toda la app quedó
leyendo del tema, y el modo oscuro salió bien **por construcción**. El inventario lo
confirma: de los colores que usa `lib/ui/`, ninguno está escrito a mano y todos vienen del
esquema o de `ColoresDelDominio`.

Lo que sí se ve raro en oscuro —el reporte de molestia en rojo, la pastilla del estado del
plan sin color propio— es trabajo de la fase 6, no de esta.

### Dos hallazgos de medición

**La prueba de contraste medía contra un blanco que no existe.** Usaba `#FFFFFF` y un negro
escrito a mano; los fondos de verdad que Material deriva de la semilla marina son `#F8F9FF`
y `#111418`. Ahora se miden los reales. El supuesto era conservador en oscuro y optimista en
claro.

**La zona A1 se diluía en la página.** Contra blanco puro cumplía; contra el fondo de verdad
daba 1.177 donde hacen falta 1.2. Pasó de `#DCE9F2` a `#D8E6F0`, que es **el único valor que
cumple a la vez** el contraste contra el fondo (1.211) y el salto de claridad hasta A2 (6.9,
donde se exigen 6). El extremo claro de la rampa va apretado entre esas dos exigencias.

**Y un agujero que abrió la fase 4**: el `Aviso` se pinta sobre `surfaceContainerHighest`,
no sobre el fondo de la pantalla, y ahí el tono de éxito baja de 4.79 a 3.89. Basta para un
icono o un borde, no para un párrafo. Es exactamente por eso que el componente escribe su
texto en el color normal de la superficie. Ahora ese par está medido.

---

## Phase 6: User Story 4 — Lo que la metodología distingue, la app lo distingue (Priority: P2)

**Goal**: que las zonas, los estados y las molestias se reconozcan de un vistazo, y también
sin color.

**Independent Test**: mostrar las siete zonas juntas, un plan en cada estado y una sesión con
molestia, y distinguirlos sin leer la etiqueta **y** en escala de grises (escenarios C4 y C7).

- [X] T034 [P] [US4] Escribir en `test/ui/tema/escala_de_zonas_test.dart` las garantías V8 y V9: las siete tienen luminancias separadas, y su orden es **monótono en el orden de intensidad de la sección 9**. Enseñar otro orden sería enseñar una ordenación que la metodología no hace
- [X] T035 [US4] Crear `lib/ui/tema/dominio/escala_de_zonas.dart` con la rampa **por claridad, no por tono** (decisión D4), hasta que T034 y T015 pasen. Una rampa por tono se convierte en siete grises casi iguales para quien no distingue colores
- [X] T036 [P] [US4] Crear `lib/ui/tema/dominio/estados_de_plan.dart` para `borrador`, `aprobado` y `publicado`. `aprobado` **no puede verse como `publicado`**: aprobar no es entregar, y confundirlos borraría la distinción que el principio IV protege
- [X] T037 [P] [US4] Escribir en `test/ui/tema/estados_de_plan_test.dart` la garantía SC-007: los tres se reconocen sin leer la etiqueta y sin depender solo del color
- [X] T038 [US4] Aplicar la escala de zonas donde se muestran series y distribuciones, **conservando siempre la etiqueta**. El color acompaña al nombre, no lo sustituye: la notación es del entrenador
- [X] T039 [US4] Dar al reporte de molestia el tono de **cuidado** en `lib/ui/planes/respuestas_del_nadador.dart`, nunca el de error
- [X] T040 [P] [US4] Escribir en `test/ui/tema/molestia_test.dart` la garantía V11 del contrato: el reporte de molestia se encuentra sin leerlo todo y **no usa el tono de error**. El principio IV prohíbe que la app diagnostique, y pintarlo como una emergencia es una forma de opinar
- [X] T041 [P] [US4] Escribir en `test/ui/tema/avisos_test.dart` la garantía V12: el aviso de «guardado, se enviará cuando tengas internet» usa el tono de **éxito**. Hoy es rojo, y es una buena noticia: significa que la bandeja de salida de la feature 003 hizo su trabajo

**Checkpoint**: la app habla el idioma de la metodología.

### Un hueco de medición que esta fase destapó

El banco de pantallas de la fase 3 montaba un plan **sin fase ATR**, y
`repartoPorZona` devuelve una lista vacía cuando no hay fase. Resultado: las siete filas de
zonas —justo lo que esta fase pinta— no se pintaban en ninguna prueba, y tampoco el modelo
de la fase ni sus tres bandas TID.

Al añadir la fase al banco, la garantía V7 encontró **dos sitios más con la misma enfermedad
de anchos fijos** que `_FilaReparto` tenía en la fase 3: `_FilaTid` se salía 71 píxeles con
la letra normal y 316 al 200%, y la cabecera del modelo otros 118. Llevaban ahí desde la
feature 002 sin que nadie los viera, porque solo se pintan cuando el plan tiene fase ATR.

La lección no es sobre layout: **un banco de pruebas solo mide los caminos que monta**. Un
dato por omisión que apaga media pantalla apaga también media medición.

### Dónde no se aplicó la escala, y por qué

En la **pantalla del nadador** la sesión se muestra como un bloque de notación renderizada,
con las zonas dentro del texto: `4×100 Nado Libre (A1)`. Colorear ahí obligaría a trocear
esa cadena para pintar cada zona, y la notación es del entrenador: partirla para decorarla
es justo lo que FR-004 prohíbe. La escala se aplicó donde las zonas son elementos propios —
el desplegable del editor y el reparto del plan— y la notación se quedó intacta.

---

## Phase 7: Polish & Cross-Cutting Concerns

- [X] T042 Comprobar la garantía V13 recorriendo el inventario de T002: **ninguna pantalla cambió lo que hace ni lo que dice**
- [X] T043 [P] Documentar en `docs/DEVELOPMENT.md`, **en inglés**, dónde vive el tema y la regla de que `paleta.dart` es el único archivo con literales de color
- [X] T044 Recorrer entero [quickstart.md](quickstart.md) y marcar cada escenario con lo que lo cubre
- [X] T045 Pasar las cuatro puertas de calidad en orden: `flutter analyze`, `flutter test`, `npm --prefix firebase test` y `dart run tool/verificar_metodologia.dart`
- [ ] T046 Desplegar con la secuencia de `docs/DEVELOPMENT.md` y **comprobar el sitio en vivo**, no dar por bueno un «deploy complete». La app está en uso, y la feature 004 enseñó que un despliegue correcto puede servir un bundle viejo
- [ ] T047 Verificar el escenario V10 **en un teléfono, al aire libre y con sol**. Es lo único que ninguna prueba automática dice: si de verdad se lee. El contraste calculado es condición necesaria, no suficiente

---

## Dependencies & Execution Order

### Entre fases

- **Fase 1 (Setup)**: sin dependencias.
- **Fase 2 (Foundational)**: depende de la 1. **Bloquea todo lo demás.** Y dentro de ella,
  T003 y T004 —el cerrojo— van **antes** que T006, la paleta.
- **Fase 3 (US1)**: depende de la 2. Es la que fija los valores definitivos de color.
- **Fase 4 (US2)**: depende de la 2. Puede ir en paralelo con la 3, salvo T028, que usa los
  tonos de aviso.
- **Fase 5 (US3)**: depende de la 2, porque la paleta ya trae los valores de oscuro.
- **Fase 6 (US4)**: depende de la 3, porque la rampa de zonas tiene que cumplir el contraste
  que la 3 comprueba.
- **Fase 7 (Polish)**: al final. T046 y T047 exigen desplegar.

### Lo que puede ir en paralelo

- Dentro de la fase 2: T005, T008, T009, T010 y T013 tocan archivos distintos.
- **Las fases 3 y 4 casi enteras**, entre sí.
- Todas las pruebas marcadas `[P]`: son archivos distintos y no dependen entre sí.

### Un orden que no se puede alterar

**T003 y T004 antes que T006.** Si la paleta existe antes que el cerrojo, el cerrojo se
escribe para que pase con lo que ya hay. Escrito antes, dice lo que queremos; escrito
después, describe lo que salió.

---

## Implementation Strategy

### El primer corte con valor

**Fases 1, 2 y 3.** Ahí la app ya se ve distinta, se lee al sol y el cerrojo está puesto. Es
desplegable por sí solo.

### Entrega incremental

1. Fases 1 y 2 → hay tokens y hay cerrojo.
2. Fase 3 → se lee a pie de piscina. **Desplegable.**
3. Fase 4, en paralelo → lo repetido está decidido una vez.
4. Fase 5 → claro y oscuro.
5. Fase 6 → el idioma de la metodología.
6. Fase 7 → despliegue y la comprobación que ninguna máquina hace.

### Una tarea que no depende de mí

**T007**: los valores concretos de la paleta los aprueba el entrenador. Es su identidad, no
una decisión técnica. Lo que el plan fija son las restricciones; lo que él decide es cómo se
ve su app.

---

## Notes

- `[P]` significa archivos distintos y sin dependencias pendientes.
- **Ninguna tarea autoriza a modificar una prueba de las features 001 a 004.** Si una falla,
  el tema cambió un comportamiento y se arregla el tema.
- Las pruebas de garantías se escriben antes y tienen que fallar.
- Ninguna tarea se marca `[X]` sin que su prueba exista y pase. En la feature 003 ocurrió dos
  veces, y en la 004 el despliegue destapó cinco fallos que las pruebas no veían.
- **Si un color bonito no cumple el contraste, gana el contraste.** La app se usa al sol, con
  la pantalla mojada, y a veces la lee un niño de nueve años.
