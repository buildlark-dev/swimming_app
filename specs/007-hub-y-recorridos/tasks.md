---
description: "Lista de tareas de la feature 007 — El HUB y los dos recorridos"
---

# Tasks: El HUB y los dos recorridos

**Input**: Documentos de diseño en `specs/007-hub-y-recorridos/`
**Prerequisites**: [plan.md](./plan.md), [spec.md](./spec.md), [research.md](./research.md),
[data-model.md](./data-model.md), [contracts/hub_y_ajustes.md](./contracts/hub_y_ajustes.md),
[quickstart.md](./quickstart.md)

**Las pruebas no son opcionales.** El principio III de la constitución es NO NEGOCIABLE, y la
casa tiene una forma de hacerlo: **el cerrojo se escribe antes de lo que protege, y cada uno se
verifica con su control negativo** —se introduce la violación, se ve fallar la prueba, se
deshace—. Una prueba que nunca se vio fallar no es un cerrojo.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: puede ir en paralelo (archivos distintos, sin dependencias pendientes)
- **[US#]**: a qué historia de usuario pertenece
- Toda tarea lleva su ruta de archivo

## Antes de empezar: lo que esta feature toca y lo que no

**Casi todo es mudanza.** Las pantallas de las features 001 a 003 cambian de sitio sin cambiar
de comportamiento. Lo nuevo son dos `Home`, la sección `Ajustes` y dos operaciones de servidor.

**Ninguna tarea autoriza a modificar una prueba de las features 001 a 006 que afirme el
comportamiento de una pantalla.** Si una falla, el HUB cambió algo y se arregla el HUB
(FR-032). Las únicas excepciones son T049 y T050, que actualizan las dos afirmaciones sobre la
navegación anterior y están nombradas una por una.

**Ninguna regla de acceso cambia.** Las dos operaciones nuevas corren con el Admin SDK, que se
las salta, así que lo que las vigila son pruebas de servidor: qué borran y qué dejan.

**Punto de partida, medido**: `flutter test` → 1283 en verde, `flutter analyze` limpio.

---

## Phase 1: Setup

- [X] T001 Extraer `PantallaPrincipal` y `_BarraDeSesion` de `lib/main.dart` (líneas 474–888) a `lib/ui/hub/hub.dart` **sin cambiar una sola etiqueta ni comportamiento**, dejando en `main.dart` el arranque, `RecursosIniciales` y la puerta de acceso (decisión D1)
- [X] T002 Comprobar que tras T001 `flutter test` sigue dando 1283 en verde y `flutter analyze` limpio: la extracción es una mudanza, y si algo falla aquí es que no lo fue

---

## Phase 2: Foundational (Blocking Prerequisites)

**Bloquea todas las historias.** El reparto por rol es la pieza de la que cuelgan los dos
recorridos.

### Los cerrojos primero

- [X] T003 [P] Extender `test/dominio/arquitectura_test.dart` para que `lib/dominio/hub/` no pueda importar Flutter ni Firebase. Control negativo: añadir `import 'package:flutter/material.dart'` en un archivo del directorio y ver fallar la prueba
- [X] T004 [P] Escribir `test/dominio/hub/destinos_test.dart`: hay **exactamente cinco** destinos, en el orden `Generar, Ver Plan, Home, Análisis, Ajustes`, y `Home` ocupa la **posición 2** para los dos roles (H1, H2, H3). Control negativo: mover `Home` de posición y ver fallar
- [X] T005 [P] Escribir `test/dominio/hub/reparto_test.dart`: para cada destino y cada rol hay **exactamente una** respuesta —un contenido o «todavía no»— (H4); **ningún contenido aparece en los dos recorridos salvo `Ajustes`** (H5); los «todavía no» son exactamente dos, `Generar` del nadador y `Análisis` del entrenador (H13). Control negativo: poner el editor también en el recorrido del nadador y ver fallar
- [X] T006 [P] Escribir `test/dominio/hub/resumen_del_entrenador_test.dart` fijando las definiciones literales de data-model.md: «en uso» es `publicado`, con asignación, y cuyo nadador tiene **algún** registro; «esperando aprobación» es `borrador` **sin bloqueos en la auditoría**; «aprobados sin asignar» es `aprobado` sin ninguna asignación. Control negativo: contar como «en uso» un plan asignado y sin tocar, y ver fallar
- [X] T007 [P] Escribir `test/dominio/hub/resumen_del_nadador_test.dart`: cumplidas nunca mayor que entregadas; `hoy` nunca vacío sin explicación; **no hay metas, logros, rachas ni proyecciones** (FR-015, H16). Control negativo: añadir un campo `racha` y ver fallar

### El dominio

- [X] T008 Crear `lib/dominio/hub/destino.dart`: los cinco destinos con `posicion` (0 a 4, sin huecos ni repetidos), `etiqueta` en español e `icono` del juego que la app ya usa, y la **tabla declarativa** destino × rol → contenido o «todavía no» (decisión D2, reemplaza las dos listas paralelas con índice compartido de `main.dart`)
- [X] T009 [P] Crear `lib/dominio/hub/resumen_del_nadador.dart` con `sesionesEntregadas`, `sesionesCumplidas`, `hoy`, `ultimaRespuesta` (puede faltar), `ultimaSincronizacion` (puede faltar) y `hayPendientes`, derivados de lo que `EstadoNadador` ya mantiene (decisión D11, cero consultas nuevas)
- [X] T010 [P] Crear `lib/dominio/hub/resumen_del_entrenador.dart` con `planesGenerados`, `esperandoAprobacion`, `aprobadosSinAsignar` y `enUso`, con las definiciones de T006
- [X] T011 Añadir `nadadoresConRegistros()` al puerto `RepositorioRegistros` en `lib/dominio/repositorios/repositorios.dart` y a sus tres implementaciones —`lib/datos/firestore/repositorios_firestore.dart`, `lib/datos/local/repositorios_locales.dart`, `lib/datos/memoria/repositorios_memoria.dart`— para que «en uso» cueste una consulta y no una por nadador (decisión D10)

---

## Phase 3: User Story 1 — El nadador llega a su sitio (Priority: P1) 🎯 MVP

**Meta**: el nadador abre la app, aterriza en `Home` con su resumen, y su sesión del día está a
un toque. Nada del recorrido del entrenador asoma.

**Prueba independiente**: entrar con una cuenta de nadador, ver el resumen, llegar a la sesión
en un toque, y recorrer los cinco destinos sin encontrar generador, editor ni panel de
nadadores.

### Los cerrojos

- [X] T012 [P] [US1] Escribir `test/ui/hub/recorrido_del_nadador_test.dart`: ve los cinco destinos, y en ninguno aparece el generador, el editor ni el panel de nadadores —**ni deshabilitados, ni con candado, ni nombrados**— (H6). Control negativo: cablear el editor en su `Generar` y ver fallar
- [X] T013 [P] [US1] Escribir `test/ui/hub/home_del_nadador_test.dart`: muestra entregadas, cumplidas, la última respuesta y **de cuándo son los datos**; abre sin conexión con lo que haya en el dispositivo (H14, H15). Control negativo: quitar la línea de la última sincronización y ver fallar
- [X] T014 [P] [US1] Escribir `test/ui/hub/estado_conservado_test.dart`: una respuesta a medio escribir sigue ahí al cambiar de destino y volver (H8). Control negativo: reconstruir el contenido en cada cambio y ver fallar

### Las pantallas

- [X] T015 [US1] Crear `lib/ui/hub/hub.dart` (sobre lo extraído en T001): la barra con los cinco destinos leyendo el orden de `Destino`, el índice conservado, y el rol tomado de `Permisos` y nunca de una condición local (H7)
- [X] T016 [US1] Crear `lib/ui/hub/contenidos.dart`: el cableado destino × rol → widget, consultando la tabla de T008. Es el único sitio del proyecto donde se decide qué contenido le toca a quién
- [X] T017 [P] [US1] Crear `lib/ui/hub/todavia_no.dart`: lo que muestra un destino que espera su feature —una frase y **ningún control pulsable**— usando los componentes de la feature 005
- [X] T018 [US1] Crear `lib/ui/hub/home_del_nadador.dart` con el tema y los componentes de la 005, poniendo **la sesión de hoy como lo primero**, con el camino a `Ver Plan` (decisión D3: compensa el toque que se pierde)
- [X] T019 [US1] Cablear en `contenidos.dart` el recorrido del nadador: `Ver Plan` → `PantallaSesionDelDia` de la feature 003 y `Análisis` → `PantallaMiProgreso` (FR-031), las dos sin cambiarles nada
- [X] T020 [US1] Hacer que la app abra en `Home` para los dos roles (FR-005) en `lib/ui/hub/hub.dart`
- [X] T021 [US1] En `lib/ui/hub/hub.dart`, volver atrás desde un destino que no es `Home` lleva a `Home`; desde `Home`, sale de la app (H10)

---

## Phase 4: User Story 2 — El entrenador encuentra su taller (Priority: P1)

**Meta**: aterriza en `Home` con los cuatro números, genera y edita sin cambiar de destino, y
encuentra el plan de un nadador concreto desde `Ver Plan`.

**Prueba independiente**: generar un microciclo y comprobar que cae en el editor sin salir de
`Generar`; después encontrar ese plan desde `Ver Plan` filtrando por el nadador.

### Los cerrojos

- [X] T022 [P] [US2] Escribir `test/ui/hub/recorrido_del_entrenador_test.dart`: ve los cinco destinos con su reparto, y en ninguno aparece la sesión del día ni «Mi progreso» del nadador (H5, H6)
- [X] T023 [P] [US2] Escribir `test/ui/hub/generar_sin_cambiar_de_destino_test.dart`: un plan recién generado se abre para revisarlo **sin salir de `Generar`** (H8, FR-009). Control negativo: mandarlo a otro destino y ver fallar
- [X] T024 [P] [US2] Escribir `test/ui/hub/home_del_entrenador_test.dart`: los cuatro números, cada uno diciendo de qué es, y con cero planes dicen cero y la pantalla dice por dónde empezar. **Ningún número aprueba, firma ni publica nada** (H18)

### Las pantallas

- [X] T025 [US2] Crear `lib/ui/hub/home_del_entrenador.dart` con los cuatro números de T010
- [X] T026 [US2] Cablear el `Generar` del entrenador en `contenidos.dart`: el generador de la feature 002 y el editor de la 001 en el mismo destino, conservando el paso del plan generado al editor que hoy hace `_abrirGenerado`
- [X] T027 [US2] Cablear en `lib/ui/hub/contenidos.dart` el `Ver Plan` del entrenador: sus planes con **búsqueda y filtro por nadador** (FR-010) y `lib/ui/nadadores/pantalla_perfiles.dart` dentro de este destino, no como un sexto
- [X] T028 [US2] Abrir un plan desde `Ver Plan` —`lib/ui/planes/pantalla_plan.dart`— y ajustarlo con el editor de `lib/ui/editor/pantalla_editor.dart`, **sin construir un segundo editor** (FR-011)
- [X] T029 [US2] Cablear el `Análisis` del entrenador a `todavia_no.dart`, nombrando la feature 010

---

## Phase 5: User Story 3 — Cada quien manda sobre lo suyo (Priority: P1)

**Meta**: `Ajustes`. Es la parte que pesa y la razón de fondo de la feature: los tres derechos
de la Ley 1581 están construidos desde la 004 y hoy son inalcanzables.

**Prueba independiente**: corregir el apellido y comprobar que la constancia de términos no se
movió; recorrer los tres derechos; pedir la supresión en una cuenta de prueba y ver qué
sobrevive.

### Los cerrojos primero — y el primero es el más importante de la feature

- [X] T030 [P] [US3] Escribir `test/datos/servidor/contrato_corregir_perfil_test.dart`, que lee `firebase/functions/src/datos_personales.ts`: el cuerpo del cliente es `{ nombre, fechaNacimiento, pais }`, **no lleva `versionDeTerminos`**, y **la palabra `terminos` no aparece en el cuerpo de esa función** (H21). Control negativo: escribir `terminos` en la función y ver fallar
- [X] T031 [P] [US3] Escribir `test/datos/servidor/contrato_suprimir_test.dart`: el cuerpo es `{ confirmado }`, **no acepta `uid` ni `nadadorId`** —los dos salen del token— y el fuente exige `confirmado === true` (H27). Control negativo: aceptar un `nadadorId` del cliente y ver fallar
- [X] T032 [P] [US3] Escribir `firebase/test/datos_personales.test.ts` contra el emulador: tras suprimir, los registros, las asignaciones, la ficha de nadador y los datos personales de `usuarios/{uid}` dejan de estar, y **el historial de consentimiento sigue ahí con su fecha** (H27, garantía C8 de la 004). Control negativo: borrar también el historial y ver fallar
- [X] T033 [P] [US3] Escribir `test/ui/ajustes/la_constancia_no_se_toca_test.dart`: corregir el nombre deja intactas la versión aceptada y su fecha (H21), y `Ajustes` muestra **el texto de esa versión, no el vigente** (H20)
- [X] T034 [P] [US3] Escribir `test/ui/ajustes/un_solo_nombre_test.dart`: corregir el nombre lo deja igual en `usuarios/{uid}` y en la ficha de `nadadores/{id}` (H22). Control negativo: escribir solo en `usuarios` y ver fallar
- [X] T035 [P] [US3] Escribir `test/ui/ajustes/solo_lo_mio_test.dart`: `Ajustes` no muestra ni permite cambiar datos de otra persona (H19)
- [X] T036 [P] [US3] Escribir `test/ui/ajustes/nada_se_registra_test.dart`: nada de lo exportado pasa por un registro, una traza ni una métrica (H26, garantía A17 de la 006). Control negativo: imprimir el contenido exportado y ver fallar
- [X] T037 [P] [US3] Escribir `test/datos/preferencias/apariencia_sobrevive_test.dart`: la preferencia **no** vive bajo el prefijo `natacion_app/<cuentaId>/` y sobrevive a `vaciar()` (H29, decisión D4). Control negativo: guardarla en `AlmacenLocal` y ver fallar

### El servidor

- [X] T038 [US3] Crear `firebase/functions/src/datos_personales.ts` con `corregirPerfil`: valida `nombre` obligatorio, recortado, máximo 80 caracteres; `fechaNacimiento` obligatoria, `AAAA-MM-DD`, no futura, año no anterior a 1900; `pais` opcional, dos letras mayúsculas o nulo. No toma `uid`. Escribe `usuarios/{uid}` con `{ nombre, fechaNacimiento, pais }` en `merge` y `nadadores/{nadadorId}` con `{ nombre, fechaNacimiento }` en `merge`, y **nunca `terminos`**. Devuelve `{ nombre, esMenor }`, recalculando `esMenor` en el servidor
- [X] T039 [US3] Añadir `suprimirMisDatos` a `datos_personales.ts`, en el orden que `DerechosDelTitular` ya estableció: registros → asignaciones → ficha de nadador → datos personales de `usuarios/{uid}` → revocar el consentimiento **por la vía de `revocar`** sin borrar su historial (decisión D8). Devuelve `{ registrosEliminados, asignacionesRetiradas, perfilEliminado, cuentaEliminada }`
- [X] T040 [US3] Exportar las dos operaciones en `firebase/functions/src/index.ts`
- [X] T041 [US3] **Bloqueada por T065**: añadir en `firebase/functions/src/datos_personales.ts` el borrado de la cuenta de identidad al final de `suprimirMisDatos` (decisión D7). No se escribe hasta que el entrenador lo confirme

### El cliente

- [X] T042 [US3] Añadir `corregirPerfil` y `suprimirMisDatos` a `lib/datos/servidor/operaciones.dart`, cada una con su **función con nombre** que arma el cuerpo, como `cuerpoDeCanje` de la 006, para que la prueba de contrato tenga qué leer
- [X] T043 [P] [US3] Añadir el cambio de contraseña al puerto `Identidad` en `lib/dominio/repositorios/repositorios.dart` e implementarlo en `lib/datos/auth/sesion_firebase.dart` como correo de restablecimiento, que es el único archivo que puede importar `firebase_auth` (decisión D9, H30)
- [X] T044 [P] [US3] Crear `lib/datos/preferencias/apariencia.dart`: `claro | oscuro | delSistema`, por omisión `delSistema`, en `SharedPreferences` bajo una clave **de dispositivo** fuera del prefijo por cuenta. Si no se puede leer, usa `delSistema` y no lo trata como fallo
- [X] T045 [US3] Hacer reactivo el `themeMode` de `MaterialApp` en `lib/main.dart:119`, que hoy está fijo en `ThemeMode.system`

### Las pantallas

- [X] T046 [US3] Crear `lib/ui/ajustes/pantalla_ajustes.dart`: el armazón de la sección, con los componentes de la feature 005
- [X] T047 [P] [US3] Crear `lib/ui/ajustes/mis_datos.dart`: ver y corregir nombre, fecha de nacimiento y país, llamando a `corregirPerfil`
- [X] T048 [P] [US3] Crear `lib/ui/ajustes/lo_que_acepte.dart`: el texto íntegro de la versión que aceptó —de `assets/terminos/` y `assets/consentimiento/`— con su fecha de aceptación
- [X] T049 [P] [US3] Crear `lib/ui/ajustes/mis_derechos.dart`: enchufar `DerechosDelTitular` por primera vez. `QueSeGuarda.enPalabras` en frases (H25) y la exportación a un archivo legible, **en dos toques o menos** (H24)
- [X] T050 [US3] Crear `lib/ui/ajustes/supresion.dart`: dos acciones deliberadas, y la segunda dice qué se borra y **qué sobrevive**, con las palabras de `ResultadoDeEliminacion.loQueSobrevive` y no en letra pequeña (H27). Al terminar, la app arranca de nuevo con el reinicio de la 006
- [X] T051 [P] [US3] Crear `lib/ui/ajustes/apariencia.dart`: claro, oscuro o el del sistema
- [X] T052 [US3] Mover cerrar sesión a `Ajustes` (H23, FR-019) y decidir qué queda de la tira de sesión de `hub.dart`: **el aviso de modo local se queda**, porque avisa de una condición y no de una identidad
- [X] T053 [US3] Añadir en `lib/ui/ajustes/pantalla_ajustes.dart` el conmutador de recorrido **solo en modo local**, guardado con la preferencia de dispositivo de `lib/datos/preferencias/apariencia.dart` (decisión D13), sin quitar el aviso de que no hay servidor

---

## Phase 6: User Story 4 — Una pestaña que todavía no tiene contenido lo dice (Priority: P2)

- [X] T054 [P] [US4] Escribir `test/ui/hub/todavia_no_test.dart`: cada destino sin contenido dice en una frase qué llegará y **tiene cero controles pulsables**, ni deshabilitados como señuelo (H11, H12), comprobado en los dos roles. Control negativo: añadir un botón apagado y ver fallar
- [X] T055 [US4] Escribir los textos de los dos «todavía no» en `lib/ui/hub/todavia_no.dart`, nombrando la feature que trae cada uno: la 008 para el `Generar` del nadador y la 010 para el `Análisis` del entrenador

---

## Phase 7: User Story 5 — Lo que ya funcionaba sigue funcionando (Priority: P1)

**Las dos únicas tareas de toda la feature autorizadas a tocar una prueba anterior**, y lo que
cada una puede cambiar está dicho (FR-033, decisión D12).

- [X] T056 [US5] En `test/widget_test.dart`, cambiar el ayudante `irAlEditor` para que entre por `Generar` en lugar de pulsar `Editor`, **sin tocar ni una aserción** de las cuatro pruebas que lo usan
- [X] T057 [US5] En `test/widget_test.dart`, reescribir «la app tiene las tres pestañas» como «la app tiene los cinco destinos y el reparto por rol»: comprueba más de lo que comprobaba
- [X] T058 [US5] Ejecutar `flutter test` y comprobar que el total **no bajó de 1283** y que las únicas pruebas modificadas son las de T056 y T057

---

## Phase 8: Polish & Cross-Cutting Concerns

- [X] T059 [P] Medir las cinco etiquetas a 320 px de ancho, en claro y en oscuro, con una prueba en `test/ui/hub/etiquetas_caben_test.dart` (H9, SC-003). Si una no cabe, cambia la barra y **no la palabra**
- [X] T060 [P] Extender `test/ui/tema/pantallas_en_el_banco_test.dart` de la feature 005 con las pantallas nuevas: ninguna declara color, medida ni tipografía propios (FR-034)
- [X] T061 Pasar las cuatro puertas: `flutter analyze` limpio, `flutter test` en verde, `npm --prefix firebase test` en verde y `dart run tool/verificar_metodologia.dart` con las huellas coincidiendo
- [X] T062 [P] Actualizar `docs/DEVELOPMENT.md`: añadir el HUB y los dos recorridos, y **poner al día la lista «What is built»**, que se quedó en la feature 003 y no nombra cuentas, consentimiento, tema visual ni alta
- [X] T063 [P] Marcar la feature 007 como fusionada en `docs/ROADMAP.md` cuando lo esté
- [X] T064 Recorrer C1 a C14 de [quickstart.md](./quickstart.md) en el navegador, con las dos cuentas. **C9 y C11 son los que importan**: que corregir un apellido no mueva la constancia, y que la supresión diga qué sobrevive antes del segundo paso

---

## Dos tareas que no dependen de mí

- [X] T065 **Confirmación del entrenador**: ¿la supresión borra también la cuenta de identidad? El plan propone que sí —el correo es un dato personal, y dejar la cuenta viva convierte el derecho en un vaciado que deja a la persona registrada y sin nada— pero es irreversible y afecta a cuentas reales. **Bloquea T041**
- [X] T066 **Criterio del entrenador**: qué muestra el `Home` del entrenador cuando los cuatro números son cero, visto con sus propios datos delante. Si sobra algo, sobra

---

## Dependencies & Execution Order

### Entre fases

```text
Phase 1 (Setup) ─> Phase 2 (Foundational) ─> US1 ─> US2 ─┐
                                              │          ├─> US4 ─> US5 ─> Polish
                                              └─> US3 ───┘
```

- **T001 y T002 primero, y solos.** La extracción es una mudanza con las 1283 pruebas como
  testigo. Mezclarla con cualquier cambio de comportamiento hace imposible saber qué rompió qué.
- **La fase 2 bloquea todo.** `Destino` y la tabla de reparto son la pieza de la que cuelgan los
  dos recorridos.
- **US1 antes de US2** porque el nadador es quien hoy está peor servido, y porque `hub.dart` y
  `contenidos.dart` nacen ahí.
- **US3 no depende de US2.** Solo necesita la fase 2 y el armazón de `hub.dart` de T015.
- **US5 al final**, porque solo tiene sentido cuando ya no se va a mover nada más.

### Lo que puede ir en paralelo

- Los cerrojos de la fase 2: T003 a T007, cinco archivos distintos.
- El dominio: T009 y T010 entre sí, después de T008.
- Los cerrojos de US3: T030 a T037, ocho archivos distintos. Es el bloque más paralelo de la
  feature.
- Las pantallas de `Ajustes`: T047, T048, T049 y T051, después de T046.
- La fase 8: T059, T060, T062 y T063.

### Un orden que no se puede alterar

1. **T030 antes de T038.** El cerrojo de que `terminos` no aparece en `corregirPerfil` se
   escribe antes de escribir la función. Al revés, la función se escribe mirando lo que ya
   funciona y el cerrojo se escribe para pasar.
2. **T032 antes de T039.** Lo mismo con qué sobrevive a la supresión.
3. **T011 antes de T010.** El resumen del entrenador no se puede calcular sin la consulta.
4. **T065 antes de T041.** No se escribe el borrado de la cuenta antes de que el entrenador
   confirme que es lo que quiere.
5. **T056 y T057 antes de T058.** Obvio, y aun así es donde se sabrá si la mudanza rompió algo
   lejano.

---

## Implementation Strategy

### El primer corte con valor

**Fase 1 + Fase 2 + US1.** Al terminar ahí, el nadador —que es quien más usa la app— tiene
cinco destinos, una portada que le dice cómo va, y su sesión a un toque. El entrenador sigue
viendo lo que veía, reubicado. Es entregable y no deja nada a medias.

### Entrega incremental

| Corte | Qué queda usable |
|---|---|
| T001–T011 | Nada visible cambia. La mudanza y el dominio, con sus cerrojos |
| + US1 | El recorrido del nadador, completo |
| + US2 | El taller del entrenador, con su portada |
| + US3 | `Ajustes`: los derechos de la Ley 1581 dejan de ser inalcanzables |
| + US4, US5 | Los dos «todavía no», y la prueba de que nada anterior se rompió |

### Lo que más riesgo tiene

**T038 y T039**, las dos funciones nuevas, por la lección de la 006: los dobles de las pruebas
implementan la interfaz, no el cable, y un cuerpo mal formado pasó diez pruebas en verde. Por
eso T030, T031 y T032 leen el fuente del servidor en lugar de confiar en un doble.

**T052**, mover cerrar sesión. Es la operación que la 006 dejó funcionando con un reinicio
detrás; cambiarla de sitio no puede cambiar lo que hace.

---

## Notes

- 66 tareas. **22 escriben pruebas nuevas**, y todas van antes de lo que protegen. Otras dos
  —T056 y T057— actualizan las dos únicas pruebas anteriores que esta feature puede tocar.
- Cada cerrojo lleva su control negativo dicho en la propia tarea: se introduce la violación,
  se ve fallar, se deshace. Una prueba que nunca se vio fallar no es un cerrojo.
- Cero dependencias nuevas en `pubspec.yaml`. Si alguna tarea parece necesitar una, es que la
  tarea está mal planteada.
- Ninguna regla de `firebase/firestore.rules` cambia en esta feature.

---

## Lo que destapó la mudanza (T001)

Al mover `PantallaPrincipal` a `lib/ui/hub/`, el cerrojo **A15 de la feature 005** —toda
pantalla de `lib/ui/` está en el banco que se mide— la alcanzó por primera vez. Vivía en
`main.dart`, fuera de `lib/ui/`, así que **la pantalla que todo el mundo ve no se había medido
nunca**: ni al 200% de letra, ni en áreas pulsables, ni en oscuro.

Al montarla en el banco salieron dos cosas, **ninguna de la mudanza**:

**1. Con una cuenta real, un nadador no puede llegar a su sesión.** El recorrido del nadador
monta el selector de perfil del entrenador, y `EstadoNadador` solo recibe un perfil cuando
alguien elige un chip de esa lista. Para un nadador, `RepositorioNadadoresFirestore.listar()`
lanza `FalloDeDatos` —las reglas le deniegan leer la colección entera— y el `FutureBuilder` lo
convierte en lista vacía. Lo que ve es «Todavía no hay perfiles. Crea uno en la pestaña
Nadadores», un mensaje escrito para el entrenador, sobre una pestaña que él no tiene. Funciona
en modo local y en las pruebas, donde el selector sí lista perfiles: por eso nadie lo había
visto.

**2. El selector desborda 82 píxeles a 360 puntos.** La fila del encabezado lleva un texto sin
restringir dentro de un `Row`. No se había visto porque la entrada «sesión del día» del banco
se monta **sin** selector: un banco solo mide los caminos que monta, que es justo la lección
que ese cerrojo lleva escrita.

- [X] T067 [US1] En `lib/ui/hub/hub.dart`, abrir el perfil del nadador desde `cuenta.nadadorId` en lugar de esperar a que elija un chip, con su cerrojo escrito antes en `test/ui/hub/el_nadador_llega_a_lo_suyo_test.dart`: un nadador con `nadadorId` ve su sesión **sin tocar nada**, y no ve ningún selector. Control negativo: dejar el selector en su recorrido y ver fallar
- [X] T068 [US1] Dejar `SelectorDePerfil` solo en el recorrido del entrenador y en modo local —es su herramienta para abrir la app como uno de sus nadadores—, y arreglar el desborde de 82 px de la fila del encabezado en `lib/ui/nadador/perfil_activo.dart`
- [X] T069 [US1] Añadir `hub — nadador` al banco de `test/ui/tema/ayuda_pantallas.dart` una vez hechas T067 y T068, para que el recorrido del nadador se mida al 200%, en áreas pulsables y en oscuro

## Y lo que destapó la fase 2 (T011)

Para contar los planes «en uso» hacía falta saber qué nadadores han respondido algo. Al ir a
leerlo apareció que **no existía ningún lector de `registros` en Firestore**: desde la feature
003 los registros se *escriben* en el servidor —`EnvioAFirestore` los manda— y lo único que
los *lee* es `RegistrosLocales`, del almacén del dispositivo.

Así que hoy el entrenador solo ve las respuestas que **su propio teléfono** escribió. La
promesa de la 003 —«el entrenador lo lee junto a la sesión que lo produjo»— se cumple cuando
entrenador y nadador comparten dispositivo, que es exactamente cómo se probó: él haciendo de su
propio nadador.

Esta feature construye el lector porque lo necesita para un número. Lo que **no** resuelve es
darle la lectura completa de lo que sus nadadores responden: eso es su `Análisis`, feature 010.

- [X] T070 Crear `lib/datos/firestore/registros_firestore.dart` con las lecturas que faltaban —`obtener`, `obtenerDePlan`, `exportar` y `nadadoresConRegistros`— y con `guardar` y `eliminarDe` negándose en voz alta, porque las reglas los reservan al dispositivo y al servidor
- [X] T071 Anotar en el `spec.md` de la feature 010 que el `Análisis` del entrenador necesita este lector, y que hasta entonces lo que él ve de sus nadadores sale de su propio dispositivo

---

## Y lo que dijo la app al verla por primera vez

Antes de dar por hecha la feature la abrí en el navegador, contra los emuladores, con una
cuenta de prueba. Salieron dos cosas que **ninguna de las 1414 pruebas podía ver**, y una de
ellas llevaba rota desde la feature 004.

**1. No se podía desarrollar contra los emuladores.** `ConfiguracionDatos` redirige Firestore
al emulador y **nadie redirigía la identidad**: con `--dart-define=USAR_EMULADORES=true`,
entrar salía al proyecto real con las opciones ficticias del emulador y fallaba siempre con
«api-key-not-valid». Desde que existen cuentas —la 004— cualquier cosa con sesión había que
verificarla desplegando. Eso explica el precio de las tres rondas de despliegue de la 006.

**2. Quien acababa de registrarse entraba sin ficha de nadador.** El alta crea la ficha y
escribe el `nadadorId` en el documento de la cuenta, pero la `Cuenta` que estaba en memoria se
construyó antes. Sin releerla: no se le cargaba su plan, y **`Ajustes` le decía que no había
datos suyos que ver ni borrar**, negándole sin querer los tres derechos de la Ley 1581. Se
arreglaba solo al recargar la app, que es la clase de fallo que nadie reporta.

- [X] T072 Conectar la identidad al emulador en `lib/datos/auth/sesion_firebase.dart` —el único archivo que puede importar `firebase_auth`— y llamarlo desde `lib/main.dart` cuando se arranca con emuladores
- [X] T073 Releer la cuenta al terminar el alta: `refrescarCuenta()` en `lib/ui/acceso/estado_sesion.dart`, `alGuardarElPerfil` en `lib/ui/alta/puerta_del_perfil.dart`, y su cerrojo en `test/ui/alta/entrar_despues_del_alta_test.dart` con control negativo

---

## Y lo que dijo el teléfono

C15 y C16 solo se pueden ver en un teléfono, y verlos costó cuatro arreglos que **ninguna
prueba de este proyecto podía encontrar**, porque todas corren en un escritorio sin barra de
estado, sin `google-services.json` y sin la validación de Android.

**1. Contra los emuladores, Android no arrancaba donde debía.** `FirebaseInitProvider`
inicializa la app por omisión con `google-services.json` **antes de que corra una línea de
Dart**: volver a inicializarla daba `duplicate-app` y la app caía en modo local sin decirlo.
Y aceptar la que ya había cambiaba el proyecto al de verdad, con lo que el emulador guardaba
los datos en otra base que la de las herramientas y **todo parecía vacío sin que nada
fallara**. Por eso nunca se había podido probar contra los emuladores en un teléfono.

**2. Las opciones de mentira tenían que tener forma de verdad.** Android comprueba la forma
del identificador de aplicación y la de la clave en cuanto se llama a una API de servidor. El
borrado de datos murió primero con «Please set your Application ID» y después con «Please set
a valid API key». En web ninguna de las dos se mira.

**3. La franja de sesión se pintaba debajo del reloj**, con «Entrenador» encima de la hora. El
`Scaffold` no lo evita solo cuando no hay `AppBar`, y el HUB pone su propio título.

**4. `Ajustes` de un nadador se quedaba girando para siempre.** El documento de consentimiento
tenía la fecha como texto, `as Timestamp?` lanzaba un `TypeError` —un `Error`, no una
`Exception`, así que ningún `catch` por tipo lo paraba—, subía hasta la carga de la pantalla y
la dejaba sin terminar. Con el entrenador no pasaba porque su cuenta no tiene constancia que
leer. Lo que se perdía no era un dato: eran **los tres derechos de la Ley 1581 y el botón de
pedir el borrado**, inalcanzables. Es el mismo patrón que dejó la portada girando, y por eso
se arregla en los dos sitios: lo que falle al leer una cosa no puede llevarse la pantalla.

- [X] T074 Arrancar Firebase contra los emuladores con una **app con nombre propio** en `lib/datos/firestore/configuracion.dart`, y usarla desde `sesion_firebase.dart` y `operaciones.dart`, para no pisar la que Android ya inicializó ni acabar mirando otro proyecto
- [X] T075 Dar a las opciones del emulador un identificador de aplicación y una clave **con forma válida**, que no identifican nada y solo sirven para pasar la comprobación de Android
- [X] T076 `SafeArea(bottom: false)` en el cuerpo del HUB, con su cerrojo en `test/ui/hub/estado_y_navegacion_test.dart`: con 144 px de barra de estado simulada, la franja no empieza por encima. Control negativo: falló antes del arreglo
- [X] T077 Sacar `constanciaDesde` de `ConstanciasFirestore` como función sin Firestore y leer cada campo por separado —marca de tiempo, `DateTime` o texto; lo que no se entienda se queda sin fecha, no se inventa—, con su cerrojo en `test/datos/firestore/consentimientos_test.dart`
- [X] T078 Cargar cada cosa por separado en `PantallaAjustes._cargar()` y **decir qué no se pudo leer** en lugar de girar, con su cerrojo en `test/ui/ajustes/ajustes_test.dart`: sin perfil, los derechos y el borrado siguen alcanzables
- [X] T079 Sembrar también la cuenta de una nadadora y el `historial` del consentimiento en `firebase/functions/tools/sembrar-emulador.js`, con la fecha como marca de tiempo igual que el servidor, y volver a poner los roles al final porque `alCrearseUnaCuenta` los pisa
