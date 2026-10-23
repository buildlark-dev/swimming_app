---

description: "Lista de tareas de la feature 006 — alta de cuenta y consentimiento en el registro"
---

# Tasks: Alta de cuenta y consentimiento en el registro

**Input**: documentos de diseño de `specs/006-alta-de-cuenta/`

**Prerequisites**: [plan.md](plan.md), [spec.md](spec.md), [research.md](research.md),
[data-model.md](data-model.md), [contracts/](contracts/)

**Tests**: **sí, y no son opcionales.** El principio III es «NO NEGOCIABLE» para lo que llega
al nadador, y lo que esta feature decide es **si a alguien se le pide consentimiento o no**.
Equivocarse ahí no es un fallo de interfaz.

**Organization**: por historia de usuario.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: se puede hacer en paralelo (archivos distintos, sin dependencias pendientes)
- **[Story]**: a qué historia de `spec.md` pertenece (US1 a US4)

---

## Antes de empezar: lo que esta feature toca y lo que no

Esta feature se fusiona sobre una app **desplegada y en uso**, y a diferencia de la 005, que
solo cambiaba cómo se veía, esta **cambia lo que la app pregunta y lo que guarda**.

Dos condiciones que ordenan todo lo demás:

1. **Las 1132 pruebas de las features 001 a 005 pasan sin tocarlas** (garantía A18). Si una
   falla, se arregla el código nuevo, no la prueba vieja.
2. **El mecanismo de consentimiento de la 004 no se redefine.** Token, resumen, canje,
   vencimiento: se reutiliza entero. Lo único que gana es un campo `origen`.

Y un orden que no se puede alterar, aprendido en la 005: **las pruebas de frontera se
escriben antes que lo que vigilan**. Escritas después describen lo que salió; escritas antes,
dicen lo que queremos.

---

## Phase 1: Setup

**Purpose**: dejar el terreno listo. Nada de esto se ve en la app.

- [X] T001 [P] Crear las carpetas con un archivo `library;` de marcador: `lib/ui/alta/`, `lib/datos/perfil/`, `test/ui/alta/`, `test/dominio/cuentas/`
- [X] T002 Inventariar en `research.md`, como decisión D8, **dónde se decide hoy si alguien es menor**: cada sitio que lee `declaraSerMayorDeEdad`, `fechaNacimiento` o `necesitaAcudienteEn`, con archivo y línea. Es la lista contra la que se comprueba al final que quedó **un solo sitio** (garantía A4)

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: los cerrojos y el dominio. Sin esto no empieza ninguna historia.

**⚠️ CRITICAL**: ninguna historia puede empezar hasta que esta fase esté completa.

### Los cerrojos primero

- [X] T003 Escribir en `test/dominio/frontera_edad_test.dart` la garantía A7 **antes de que exista el perfil**: recorre `lib/` y falla si la edad o la fecha de nacimiento se leen dentro de `dominio/generacion/`, `dominio/metodologia/` o en cualquier cálculo de categoría, nombrando archivo y línea
- [X] T004 Comprobar que T003 **caza de verdad**: meter una lectura de la edad en el generador, ver fallar la prueba con el archivo y la línea correctos, y quitarla. Una frontera que no caza nada no es una frontera
- [X] T005 [P] Escribir en `test/dominio/frontera_pais_test.dart` la garantía A16: el país no aparece en `lib/` fuera de mostrarlo o guardarlo. Comprobar también que caza
- [X] T006 [P] Escribir en `test/ui/tema/pantallas_en_el_banco_test.dart` la garantía A15: toda pantalla de `lib/ui/` está en `test/ui/tema/ayuda_pantallas.dart`. **La 005 lo aprendió dos veces**: una pantalla que no está en el banco no se mide al 200% ni en áreas pulsables

### El dominio

- [X] T007 Crear `lib/dominio/cuentas/edad.dart` con **el único sitio que decide si alguien es menor**, en el orden de `data-model.md`: fecha de nacimiento, si no declaración, si no **menor**
- [X] T008 [P] Escribir en `test/dominio/cuentas/edad_test.dart` las garantías A5 y A6: ante la duda menor, y el mismo perfil da respuestas distintas el día antes y el día después de cumplir 18 **sin que nadie escriba nada**
- [X] T009 Crear `lib/dominio/cuentas/perfil.dart`: nombre, fecha de nacimiento, país opcional, aceptación de términos, y `estaCompleto`. El país **nulo es legítimo**, no un perfil incompleto
- [X] T010 [P] Escribir en `test/dominio/cuentas/perfil_test.dart` las reglas de `data-model.md`: nombre recortado y no vacío, fecha ni futura ni anterior a 1900, y que el país no cuenta para `estaCompleto`
- [X] T011 Crear `lib/dominio/consentimiento/declaracion.dart` con la declaración de acudiente y su `origen`, que **no se puede cambiar después**
- [X] T012 [P] Escribir en `test/dominio/consentimiento/declaracion_test.dart` la garantía A12 en el dominio: el correo del acudiente no puede ser el de la cuenta del menor
- [X] T013 Reducir el papel de `declaraSerMayorDeEdad` a respaldo (decisión D2), **sin borrarlo**: hay cuentas en producción que solo tienen eso, y borrarlo rompería pruebas de la 004
- [X] T014 Comprobar contra el inventario de T002 que **queda un solo sitio** que decide la minoría de edad, y escribir en `test/dominio/cuentas/un_solo_sitio_test.dart` la garantía A4

**Checkpoint**: el dominio sabe quién es menor, y tres cerrojos vigilan que no se tuerza.

---

## Phase 3: User Story 1 — Un adulto se da de alta (Priority: P1) 🎯 MVP

**Goal**: que la app sepa quién entra.

**Independent Test**: crear una cuenta de alguien mayor de edad y comprobar que al entrar la
app le saluda por su nombre y no vuelve a preguntarle nada (escenario C1).

### El servidor

- [X] T015 [US1] Crear `firebase/functions/src/perfil.ts` con `guardarPerfil`, que escribe `usuarios/{uid}` **solo para el propio llamante**. Las reglas siguen en `write: if false` para el cliente (decisión D3)
- [X] T016 [P] [US1] Escribir en `firebase/test/perfil.test.js` la garantía A3: el cliente intenta escribir su perfil directamente y es **rechazado**; la operación del servidor sí puede
- [X] T017 [US1] Comprobar que `guardarPerfil` rechaza escribir el perfil **de otro**, no solo que exige autenticación

### Lo que se escribe

- [X] T018 [P] [US1] Escribir `assets/terminos/texto_v1.md`, **marcado como borrador pendiente de revisión legal**, igual que el texto de consentimiento de la 004
- [X] T019 [P] [US1] Crear `lib/datos/perfil/repositorio_perfil.dart` para **leer** si el perfil está completo. La escritura ya la hace `OperacionesDelServidor`; lo que falta es la lectura, y de ella depende T026 y toda la historia 3

### Las pantallas

- [X] T020 [US1] Crear `lib/ui/alta/estado_alta.dart`: el recorrido por pasos y lo que lleva escrito, **guardado en el dispositivo** hasta el envío final (decisión D6)
- [X] T021 [US1] Crear `lib/ui/alta/pantalla_alta.dart`, el contenedor con el avance visible y el botón de volver
- [X] T022 [P] [US1] Crear `lib/ui/alta/paso_nombre.dart` con `Campo` de la feature 005
- [X] T023 [P] [US1] Crear `lib/ui/alta/paso_nacimiento.dart`
- [X] T024 [P] [US1] Crear `lib/ui/alta/paso_pais.dart` con `CampoDeOpciones`, y **la opción de no decirlo** (FR-009)
- [X] T025 [US1] Crear `lib/ui/alta/paso_terminos.dart` con el texto **delante, legible en la pantalla, no detrás de un enlace** (FR-005). Es la misma regla que la 004 aplicó al consentimiento
- [X] T026 [US1] Enganchar el alta **al arranque, no al botón**: tras entrar, si el perfil está incompleto se recorren los pasos. Así la historia 1 y la 3 son el mismo camino, que es lo que pide T040. Depende de T019
- [X] T027 [US1] Añadir las pantallas del alta a `test/ui/tema/ayuda_pantallas.dart`, **con contenido realista**. Si no, T006 falla, que es justo para lo que está

### Las pruebas que miden

- [X] T028 [P] [US1] Escribir en `test/ui/alta/recorrido_test.dart` los escenarios C1 y C2: los pasos se recorren, y **volver atrás no borra nada**
- [X] T029 [P] [US1] Escribir en `test/ui/alta/interrupcion_test.dart` la garantía A2 y el escenario C3: se cierra a mitad, se vuelve, sigue donde estaba, y **en el servidor no hay nada escrito**
- [X] T030 [P] [US1] Escribir en `test/ui/alta/sin_consentimiento_test.dart` que a un adulto **nunca se le menciona** acudiente ni consentimiento

**Checkpoint**: la app sabe el nombre de quien entra. Es desplegable por sí solo.

---

## Phase 4: User Story 2 — Un menor se da de alta (Priority: P1)

**Goal**: que exista, por fin, un momento en que se pida el consentimiento.

**Independent Test**: crear una cuenta con fecha de hace doce años y comprobar que se pide el
correo del acudiente, que la nadadora **entra igual**, y que queda una solicitud pendiente
(escenario C4).

- [X] T031 [US2] Añadir `origen` a la solicitud en `firebase/functions/src/consentimiento.ts` y permitir emitirla **desde una declaración del propio nadador**, no solo desde el entrenador
- [X] T032 [US2] Escribir en `firebase/test/origen.test.js` la garantía A9: se emite por los dos caminos, el origen queda grabado, y **no se puede cambiar después**
- [X] T033 [US2] Hacer que el servidor rechace como acudiente el correo de la propia cuenta (garantía A12, lado servidor). El cliente también lo comprueba, pero el cliente no es la frontera
- [X] T034 [US2] Crear `lib/ui/alta/paso_acudiente.dart`, que aparece **solo si es menor** y que **explica para qué es** en esa misma pantalla (FR-014)
- [X] T035 [US2] Hacer que terminar el alta de un menor emita la solicitud, y que terminarla **sin correo** deje constancia de que se ofreció y no se quiso (garantía A8)
- [X] T036 [US2] Decir en palabras, a quien no da el correo, **qué no podrá hacer hasta que lo dé** (FR-019)
- [X] T037 [P] [US2] Escribir en `test/ui/alta/menor_test.dart` los escenarios C4, C5 y C6
- [X] T038 [P] [US2] Escribir en `test/ui/alta/nada_bloquea_test.dart` la garantía A10: una cuenta de menor con el consentimiento pendiente **entra, ve su plan y responde sin una sola traba**, y lo que responde **no sale del dispositivo**
- [X] T039 [US2] Corregir el correo del acudiente **dentro del alta**: se vuelve atrás y se reescribe, sin rehacer nada. Después del alta, quien lo cambia es el entrenador desde su panel, que ya puede volver a pedirlo. **Una pantalla del nadador para esto pertenece a Ajustes (feature 007)**, y construirla aquí sería hacer algo que esa feature va a rehacer — el mismo razonamiento que la 005 aplicó al interruptor de modo oscuro

**Checkpoint**: la puerta de la 004 por fin tiene quien le pida la llave.

---

## Phase 5: User Story 3 — Una cuenta que ya existe completa su perfil (Priority: P2)

**Goal**: cerrar el hueco de las cuentas que ya están en uso.

**Independent Test**: entrar con una cuenta creada antes de esta feature y comprobar que se
piden los datos que faltan, y que a la siguiente vez no se pregunta (escenario C9).

⚠️ **Es la única parte de esta feature que toca cuentas en producción.**

- [X] T040 [US3] Detectar al entrar que el perfil está incompleto y llevar a los mismos pasos del alta, **sin crear una segunda pantalla parecida**
- [X] T041 [US3] Garantizar que completar el perfil **no toca el rol** (FR-024). Una cuenta de entrenador sigue siéndolo
- [X] T042 [US3] Hacer que, si al completarlo resulta ser de un menor, se pida el correo del acudiente y se emita la solicitud **igual que en un alta nueva** (FR-023)
- [X] T043 [P] [US3] Escribir en `test/ui/alta/perfil_incompleto_test.dart` los escenarios C9 y C10, incluido que **no se pregunta dos veces**
- [X] T044 [P] [US3] Escribir en `test/ui/alta/perfil_no_toca_el_rol_test.dart` que una cuenta de entrenador que completa su perfil **sigue siendo entrenador**. Es el fallo que más caro saldría

**Checkpoint**: ninguna cuenta de la app queda sin nombre, y ningún menor ya registrado se
queda sin que se le pida el consentimiento.

---

## Phase 6: User Story 4 — El acudiente autoriza (Priority: P2)

**Goal**: cerrar el ciclo. El formulario ya existe; lo que falta es que el camino lleve a él.

**Independent Test**: seguir el enlace de una solicitud emitida en el alta y comprobar que
lleva al formulario correcto (escenario C7).

- [X] T045 [US4] **Construir** el camino hasta el formulario de la 004: una ruta que entienda `/consentimiento?t=…`, que la abra sin exigir haber entrado —el acudiente no tiene cuenta— y que llame a `canjear`. **No estaba construido**: ver decisión D10
- [X] T046 [P] [US4] La garantía A11 **ya estaba probada** en `test/dominio/sincronizacion/puerta_test.dart` desde la feature 003: «sin que el nadador repita nada» y «todo lo acumulado, no solo lo último». La mitad de arriba la cubre `camino_del_acudiente_test.dart`. Escribir un tercer archivo sería probar lo mismo por tercera vez
- [X] T047 [US4] Enseñar el `origen` en la pantalla de consentimientos del entrenador, y dejarle volver a pedirlo desde su matrícula (escenario C8)
- [X] T048 [P] [US4] Escribir en `test/ui/alta/enlace_vencido_test.dart` que un enlace **vencido o ya usado** lo dice en palabras y explica cómo pedir otro, sin revelar cuál de las tres condiciones falló

**Checkpoint**: la cadena entera funciona, de la primera pantalla del alta al consentimiento
registrado.

---

## Phase 7: Polish & Cross-Cutting Concerns

- [X] T049 Comprobar la garantía A17 recorriendo el código: **nada** de lo que esta feature introduce llega a registros ni analítica. Ni nombres, ni fechas, ni países, ni correos
- [X] T050 [P] Documentar en `docs/DEVELOPMENT.md`, **en inglés**, dónde se decide la minoría de edad y por qué hay un solo sitio
- [X] T051 Recorrer entero [quickstart.md](quickstart.md) y marcar cada escenario con lo que lo cubre
- [X] T052 Pasar las cuatro puertas de calidad en orden: `flutter analyze`, `flutter test`, `npm --prefix firebase test` y `dart run tool/verificar_metodologia.dart`
- [X] T053 Desplegar con la secuencia de `docs/DEVELOPMENT.md` y **comprobar el sitio en vivo**. Esta vez el despliegue cambia reglas y servidor, no solo hosting: la secuencia es reglas y funciones **antes** que hosting
- [ ] T054 Probar la historia 3 **contra una cuenta de verdad** antes de darla por buena. Es lo único de esta feature que afecta a gente que ya está usando la app
- [X] T055 Verificar que un nadador de nueve años completa el alta **sin preguntarle a nadie qué significa un campo** (SC-002). Eso se prueba sentándose al lado de uno

---

## Dependencies & Execution Order

### Entre fases

- **Fase 1 (Setup)**: sin dependencias.
- **Fase 2 (Foundational)**: depende de la 1. **Bloquea todo lo demás.** Y dentro de ella,
  T003 a T006 —los cerrojos— van **antes** que T007, el dominio.
- **Fase 3 (US1)**: depende de la 2. Es el primer corte con valor.
- **Fase 4 (US2)**: depende de la 3, porque el paso del acudiente vive dentro del mismo
  recorrido del alta.
- **Fase 5 (US3)**: depende de la 3 y de la 4: reutiliza los pasos y puede acabar pidiendo
  acudiente.
- **Fase 6 (US4)**: depende de la 4, que es la que emite las solicitudes.
- **Fase 7 (Polish)**: al final. T053 y T054 exigen desplegar.

### Lo que puede ir en paralelo

- Dentro de la fase 2: T005, T006, T008, T010 y T012 tocan archivos distintos.
- Dentro de la fase 3: T022, T023 y T024 son pasos independientes; T028, T029 y T030 son
  pruebas de archivos distintos.
- Todas las pruebas marcadas `[P]`.

### Un orden que no se puede alterar

**T003 a T006 antes que T007.** Si el dominio existe antes que los cerrojos, los cerrojos se
escriben para que pasen con lo que ya hay. La 005 lo comprobó: la frontera del tema, escrita
antes, cazó tamaños de letra que nadie había buscado.

**T002 antes que T014.** Sin el inventario de dónde se decide hoy la minoría de edad, la
comprobación de que queda un solo sitio no tiene contra qué compararse.

---

## Implementation Strategy

### El primer corte con valor

**Fases 1, 2 y 3.** La app sabe quién entra, hay perfil y hay cerrojos. Es desplegable por sí
solo, y no cambia nada de lo que hoy funciona.

### Entrega incremental

1. Fases 1 y 2 → el dominio sabe quién es menor, y tres pruebas lo vigilan.
2. Fase 3 → la app sabe el nombre de quien entra. **Desplegable.**
3. Fase 4 → por fin se pide el consentimiento. **Es la razón de ser de la feature.**
4. Fase 5 → las cuentas que ya existen quedan al día. **La más delicada: toca producción.**
5. Fase 6 → el ciclo cierra.
6. Fase 7 → despliegue y lo que ninguna máquina dice.

### Dos tareas que no dependen de mí

- **T055**: que el alta se entienda solo lo dice un nadador de nueve años completándola.
- **La revisión legal de los términos**, que no es una tarea de esta lista porque no la hace
  nadie de este repositorio. La feature se construye con un borrador; **no se cierra con él**,
  igual que el texto de consentimiento de la 004 sigue pendiente.

---

## Notes

- `[P]` significa archivos distintos y sin dependencias pendientes.
- **Ninguna tarea autoriza a modificar una prueba de las features 001 a 005.** Si una falla,
  el código nuevo cambió un comportamiento y se arregla el código.
- Las pruebas de garantías se escriben antes y tienen que fallar.
- Ninguna tarea se marca `[X]` sin que su prueba exista y pase.
- **El mecanismo de consentimiento de la 004 no se redefine**: se reutiliza entero y solo gana
  el campo `origen`.
- Ante la duda sobre si alguien es menor, **menor**. El error de pedir un consentimiento que
  no hacía falta se arregla; el de no pedirlo, no.
