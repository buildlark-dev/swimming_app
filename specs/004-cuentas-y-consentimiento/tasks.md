---

description: "Lista de tareas de la feature 004 — cuentas, roles y consentimiento verificable"
---

# Tasks: Cuentas, roles y consentimiento verificable

**Input**: documentos de diseño de `specs/004-cuentas-y-consentimiento/`

**Prerequisites**: [plan.md](plan.md), [spec.md](spec.md), [research.md](research.md),
[data-model.md](data-model.md), [contracts/](contracts/)

**Tests**: **sí, y no son opcionales.** El principio III es «NO NEGOCIABLE» para las reglas
que llegan al nadador, y en esta feature las reglas **son** la feature: la puerta de
consentimiento vive en ellas (decisión D1). Las puertas de calidad exigen `flutter test` en
verde y las pruebas de reglas sobre el emulador antes de cerrar.

**Organization**: las tareas se agrupan por historia de usuario.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: se puede hacer en paralelo (archivos distintos, sin dependencias pendientes)
- **[Story]**: a qué historia de `spec.md` pertenece (US1 a US6)

---

## Una advertencia sobre el orden, antes de empezar

Las fases **no van en el orden de numeración de las historias**, y conviene saber por qué.

Las cuatro historias P1 de esta feature están acopladas de verdad, porque son una sola puerta
legal vista desde cuatro sitios. **US1 —que los datos no salgan sin consentimiento— no se
puede entregar primero**: sin cuentas no hay a quién atribuir un dato, y sin registro de
consentimiento no hay nada contra qué comprobar. Entregarla antes sería marcar una casilla
sin respaldo, que es exactamente el error que esta lista aprendió a no cometer en la 003.

El orden real de construcción es: **cuentas (US3) → consentimiento (US2) → la puerta (US1) →
persistencia (US4)**. Las etiquetas `[USn]` siguen apuntando a la historia de `spec.md` que
cada tarea sirve, para que la trazabilidad no se pierda.

El **primer punto de corte con valor real** es el final de la fase 5: ahí la puerta existe y
se puede desplegar sin incumplir el principio V. Antes de eso no hay nada que enseñar a un
nadador de verdad.

---

## Phase 1: Setup

**Purpose**: dejar el terreno listo. Nada de esto se ve en la app.

- [X] T001 Añadir `firebase_auth` a `pubspec.yaml` y comprobar que `flutter build web --release` sigue compilando y que `flutter analyze` sigue limpio
- [X] T002 [P] Crear las carpetas nuevas del dominio con un archivo `library;` de marcador: `lib/dominio/cuentas/`, `lib/dominio/consentimiento/`, `lib/datos/auth/`, `lib/ui/acceso/`, `lib/ui/consentimiento/`
- [X] T003 Crear el esqueleto del servidor en `firebase/functions/` con `package.json`, `tsconfig.json` y `src/index.ts` vacío, fijando las versiones de `firebase-admin` y `firebase-functions`. Decisión D3: Cloud Functions de 2ª generación en TypeScript
- [X] T004 Añadir los emuladores de **Auth** y **Functions** a `firebase/firebase.json`, junto al de Firestore que ya está. Sin ellos no se puede probar ni una sola garantía de esta feature
- [X] T005 [P] Añadir al CI de `.github/workflows/ci.yml` la ejecución de las pruebas de las funciones, en el mismo trabajo que ya corre las de reglas. Una superficie de servidor sin pruebas en CI es una superficie que se rompe sin avisar
- [X] T006 [P] Documentar en `docs/DEVELOPMENT.md`, **en inglés**, cómo levantar los tres emuladores y cómo correr las pruebas de funciones

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: la identidad y los permisos, que toda historia necesita.

**⚠️ CRITICAL**: ninguna historia puede empezar hasta que esta fase esté completa.

- [X] T007 Crear `Rol` y `Cuenta` en `lib/dominio/cuentas/cuenta.dart`, en Dart puro. `Rol` es una enumeración cerrada de dos valores —`entrenador` y `nadador`— y **no un `String`**, para que añadir un rol obligue a revisar dónde se decide
- [X] T008 [P] Escribir en `test/dominio/cuentas/cuenta_test.dart` las invariantes de `data-model.md`: una cuenta de entrenador **nunca** tiene `nadadorId`; una cuenta de nadador sin `nadadorId` es válida y puede entrar, pero no tiene plan ni registros
- [X] T009 Implementar la tabla de permisos en `lib/dominio/cuentas/permisos.dart`, en Dart puro: quién aprueba, quién publica, quién lee los registros de quién, quién los escribe
- [X] T010 [P] Escribir en `test/dominio/cuentas/permisos_test.dart` la **lista de casos compartida** con las pruebas de reglas (garantía A10). Es la lista que luego recorren las dos suites; si una regla cambia y el dominio no, una de las dos falla
- [X] T011 Declarar la interfaz `Identidad` en `lib/dominio/repositorios/repositorios.dart` según [contracts/cuentas_y_roles.md](contracts/cuentas_y_roles.md): `actual()`, `cambios` y `cerrarSesion()`. **Ninguna firma menciona Firebase**
- [X] T012 Implementar `Identidad` en `lib/datos/auth/sesion_firebase.dart`. Es el **único archivo del proyecto** que puede importar `firebase_auth`
- [X] T013 [P] Ampliar la prueba de frontera de arquitectura para que falle si `lib/dominio/` importa `firebase_auth`, igual que ya falla con `cloud_firestore` y con Flutter
- [X] T014 Implementar en `firebase/functions/src/roles.ts` el disparador que asigna el claim `rol: 'nadador'` al crearse una cuenta. **Toda cuenta nace como nadador** (garantía A2)
- [X] T015 Implementar en `firebase/functions/src/roles.ts` la operación administrativa `asignarRol(uid, rol)`, **no llamable desde la app**, que es la única vía para conceder `entrenador`
- [X] T016 Resolver el arranque del primer entrenador y **documentarlo** en `docs/DEVELOPMENT.md`: nadie puede concederse el claim a sí mismo, así que hace falta un procedimiento explícito. Registrarlo como decisión D7 en `research.md`
- [X] T017 [P] Escribir en `firebase/functions/test/roles.test.js` las pruebas sobre el emulador: una cuenta nueva trae `rol: 'nadador'`; escribir `rol: 'entrenador'` en el propio documento de usuario **no** cambia el token (garantía A1)
- [X] T018 Particionar `lib/datos/local/almacen_local.dart` **por cuenta**, de modo que dos cuentas en el mismo dispositivo no compartan ni una clave, tampoco en la bandeja de salida
- [X] T019 [P] Escribir en `test/datos/local/particion_por_cuenta_test.dart` la garantía A9: dos cuentas escriben sin red en el mismo dispositivo y cada bandeja contiene lo suyo y nada más

**Checkpoint**: hay identidad, hay roles y el almacenamiento local no mezcla personas.

---

## Phase 3: User Story 3 — Cada quien entra a lo suyo (Priority: P1)

**Goal**: el entrenador entra con su cuenta y ve su comunidad; el nadador entra con la suya y
ve lo suyo. Ninguno ve lo del otro.

**Independent Test**: con dos cuentas de nadador y una de entrenador, comprobar desde cada una
qué se ve y qué no, incluidos los intentos de acceso directo a lo ajeno (escenario C6 del
quickstart).

### Pruebas de reglas — se escriben primero y tienen que fallar

- [X] T020 [P] [US3] Escribir en `firebase/test/reglas.test.js` los casos negativos de la garantía A4, uno por uno: leer el plan de otro, leer el registro de otro, escribir un registro con el `nadadorId` de otro, leer un plan en `borrador`, leer uno `aprobado` sin publicar, leer uno publicado sin asignar
- [X] T021 [P] [US3] Escribir los casos de la garantía A3: con cuenta de nadador, intentar escribir `estado: 'aprobado'` y `estado: 'publicado'` sobre un plan. Las dos se deniegan
- [X] T022 [P] [US3] Escribir el caso de la garantía A5: **con la cuenta del entrenador, escribir un registro se deniega**. Es un cambio respecto de la feature 003, donde era lo único permitido
- [X] T023 [P] [US3] Escribir los casos de la garantía A6: sin autenticar, leer **cada** colección del esquema. Todas deniegan

### Implementación

- [X] T024 [US3] Reescribir `firebase/firestore.rules` para que compare contra `request.auth.uid`: un nadador lee y escribe solo sus registros, y lee solo los planes `publicado` que le están asignados. Retirar el comentario de limitación conocida que la feature 003 dejó escrito
- [X] T025 [US3] Añadir a `firebase/firestore.rules` la colección `usuarios/{uid}` con el vínculo cuenta ↔ `nadadorId`, legible por su dueño y por el entrenador de su comunidad, y **no escribible por el cliente**
- [X] T026 [US3] Crear `lib/ui/acceso/estado_sesion.dart`, que expone la cuenta activa a la interfaz y reacciona a `Identidad.cambios`
- [X] T027 [US3] Crear `lib/ui/acceso/pantalla_acceso.dart`: entrar con una cuenta propia. **Ningún campo de esta pantalla, ni ninguna prueba, contiene una credencial real**
- [X] T028 [US3] Hacer que `lib/main.dart` arranque según haya sesión o no, conservando la propiedad de que la app arranca aunque Firebase no esté configurado (la que se arregló en el PR #5)
- [X] T029 [US3] Implementar el cierre de sesión en `lib/datos/auth/sesion_firebase.dart`, limpiando **la caché de Firestore y el almacenamiento local** del nadador anterior (garantía A7)
- [X] T030 [P] [US3] Escribir en `test/ui/acceso/cierre_sesion_test.dart` la garantía A7: tras cerrar sesión no queda plan, registro ni perfil del anterior. Es el caso de los hermanos que comparten teléfono
- [X] T031 [US3] Hacer que la caducidad de sesión **no** impida leer el plan ya descargado ni anotar (garantía A8). Lo que queda retenido es el envío
- [X] T032 [P] [US3] Escribir en `test/ui/acceso/caducidad_test.dart` la garantía A8: con la sesión caducada y sin red, abrir la app, leer la sesión del día y anotar. Las tres funcionan
- [X] T033 [US3] Esconder de la interfaz del nadador todo lo que su rol no permite, apoyándose en `permisos.dart` y no en condiciones repartidas por las pantallas

**Checkpoint**: hay cuentas y cada quien ve lo suyo. **Todavía no hay consentimiento, así que
sigue sin poder usarse con un nadador real.**

---

## Phase 4: User Story 2 — El acudiente confirma (Priority: P1)

**Goal**: el entrenador pide el consentimiento al canal que él aporta; el acudiente lo otorga
desde un enlace propio y queda constancia de qué, quién, cuándo y bajo qué texto.

**Independent Test**: emitir una solicitud, confirmarla desde el enlace y comprobar que el
registro responde a las cinco preguntas sin interpretar nada (SC-005).

### Entidades del dominio y sus pruebas

- [X] T034 [P] [US2] Crear `Consentimiento`, `Otorgante` y `Alcance` en `lib/dominio/consentimiento/consentimiento.dart`. `vigente` **se deriva** de `revocadoEn == null` y no es un campo que se escriba, para que no pueda contradecir a la fecha
- [X] T035 [P] [US2] Crear `SolicitudDeConsentimiento` en `lib/dominio/consentimiento/solicitud.dart`, con `resumenDelToken` y **sin ningún campo para el token en claro** (decisión D4)
- [X] T036 [P] [US2] Escribir en `test/dominio/consentimiento/consentimiento_test.dart` las invariantes de `data-model.md`: un consentimiento con `alcances` vacío **no se construye**; revocar no borra `otorgadoEn` ni `otorgadoPor`; `datosDeEntrenamiento` y `video` son alcances distintos y conceder uno no concede el otro
- [X] T037 [P] [US2] Escribir en `test/dominio/consentimiento/solicitud_test.dart` que `utilizable` exige las tres condiciones a la vez: no canjeada, no vencida, y token que coincide con el resumen

### El servidor

- [X] T038 [US2] Implementar `emitirSolicitud(nadadorId, canal, alcances)` en `firebase/functions/src/consentimiento.ts`, **llamable solo por el entrenador**: genera un token aleatorio criptográficamente seguro, guarda solo su resumen SHA-256, con fecha de servidor y vencimiento
- [X] T039 [US2] Definir el puerto `EnviadorDeAvisos` en `firebase/functions/src/consentimiento.ts`, de modo que la función **no sepa** si detrás hay correo o mensajería. Qué canal concreto se usa se decide al implementar y nada más depende de ello (research.md, «lo que no se resuelve aquí»)
- [X] T040 [US2] Implementar `canjear(token, declaracion)`, pública porque la abre el acudiente, que no tiene cuenta. Rechaza sin decir **cuál** de las tres condiciones falló: no existe, venció o ya se canjeó
- [X] T041 [US2] Exigir en el canje la declaración completa —nombre, documento, calidad, ser el representante legal y **que el menor fue oído**— y escribir el consentimiento con la **fecha del servidor** (FR-017, FR-021)
- [X] T042 [US2] Implementar el aviso de vuelta al mismo canal tras un canje (garantía C9). No impide un enlace mal dirigido; lo hace **descubrible por el acudiente**
- [X] T043 [US2] Implementar `revocar`, accesible **desde el canal del acudiente sin cuenta de entrenador** (garantía C10), registrando `revocadoEn` con fecha de servidor
- [X] T044 [US2] Añadir a `firebase/firestore.rules` las colecciones `consentimientos/{nadadorId}`, su subcolección `historial/` y `solicitudes/{solicitudId}`: **ninguna escritura del cliente**, solo lectura según la tabla de `data-model.md`

### Pruebas del servidor y de las reglas

- [X] T045 [P] [US2] Escribir en `firebase/functions/test/consentimiento.test.js` la garantía C1: con cuenta de nadador, emitir una solicitud y cambiar el canal de una existente. **Las dos se deniegan.** Es la garantía que cierra el agujero de que un niño ponga un correo suyo
- [X] T046 [P] [US2] Escribir la garantía C2: canjear dos veces el mismo token deja **exactamente un** consentimiento y el segundo intento se rechaza
- [X] T047 [P] [US2] Escribir la garantía C3: con el reloj adelantado más allá del vencimiento, el canje se rechaza
- [X] T048 [P] [US2] Escribir la garantía C4: tras emitir, el documento **no contiene el token** y lo que hay no permite reconstruirlo
- [X] T049 [P] [US2] Escribir la garantía C5: canjear con el reloj del cliente adelantado un año registra **la fecha del servidor**
- [X] T050 [P] [US2] Escribir la garantía C7: canjear sin la constancia de que el menor fue oído se rechaza
- [X] T051 [P] [US2] Escribir la garantía C8: tras revocar, el historial conserva quién otorgó y cuándo, y `vigente` pasa a falso
- [X] T052 [P] [US2] Escribir en `firebase/test/reglas.test.js` que ninguna cuenta —ni la del entrenador— puede escribir en `consentimientos` ni en `solicitudes`

### La interfaz

- [X] T053 [US2] Crear `lib/ui/consentimiento/pantalla_confirmacion.dart`: la ruta que abre el acudiente, **en español**, con el texto informativo versionado, la declaración y la casilla de que el menor fue oído
- [X] T054 [US2] Crear el primer texto informativo versionado en `assets/consentimiento/texto_v1.md`, marcado como **pendiente de revisión jurídica**, con su versión registrada en cada consentimiento que se otorgue bajo él
- [X] T055 [US2] Crear `lib/ui/consentimiento/panel_estado.dart`: lo que el entrenador ve de cada nadador —sin consentimiento, solicitud enviada, vigente, revocado— y desde donde emite la solicitud con el canal de su matrícula

**Checkpoint**: se puede pedir y registrar un consentimiento. **La puerta todavía no está
puesta**, así que esto aún no protege nada por sí solo.

---

## Phase 5: User Story 1 — Sin consentimiento, los datos no salen (Priority: P1) 🎯

**Goal**: lo que el nadador escribe se queda en su dispositivo hasta que haya consentimiento,
y cuando lo hay sale solo. Nadie queda bloqueado en ningún momento.

**Independent Test**: anotar desde la cuenta de un nadador sin consentimiento, comprobar que
el entrenador no recibe nada **y que la escritura directa contra el emulador se deniega**;
otorgar el consentimiento y comprobar que lo retenido sale sin tocar nada (escenarios C1, C2 y
C3 del quickstart).

### Las pruebas de la puerta

- [X] T056 [P] [US1] Escribir en `firebase/test/reglas.test.js` la garantía P1: con la cuenta **correcta** del nadador y saltándose la app, escribir un registro sin consentimiento vigente se deniega. Se prueba así y no por la interfaz, porque una puerta probada solo a través de su propia pantalla no está probada
- [X] T057 [P] [US1] Escribir la garantía P6: con consentimiento vigente se envía; se revoca; el siguiente se deniega
- [X] T058 [P] [US1] Escribir la garantía P5: publicar un plan a un nadador sin consentimiento vigente se deniega en la regla

### Implementación

- [X] T059 [US1] Declarar `PuertaDeConsentimiento` en `lib/dominio/consentimiento/puerta.dart`, con una sola pregunta: `Future<bool> puedeSalir(String nadadorId)`
- [X] T060 [US1] Añadir la condición de la puerta a `firebase/firestore.rules` en `registros/{registroId}`, con `get()` del documento de consentimiento del nadador y `vigente == true` (decisión D1). Acepta el coste de una lectura por escritura, que a esta escala es irrelevante
- [X] T061 [US1] Inyectar la puerta en el `Sincronizador` de `lib/dominio/sincronizacion/bandeja_salida.dart`. **No se añade ningún estado a `EstadoDeEnvio`** (decisión D6): un registro retenido es un registro pendiente, y ya existe cómo representarlo
- [X] T062 [US1] Hacer que estar sin consentimiento **no incremente `intentos`** ni dispare la espera exponencial, igual que ya ocurre al estar sin conexión
- [X] T063 [P] [US1] Escribir en `test/dominio/sincronizacion/puerta_test.dart` la garantía P4, **en Dart puro con un doble de la puerta**: muchos ciclos del sincronizador con la puerta cerrada dejan `intentos` en cero
- [X] T064 [P] [US1] Escribir la garantía P3: se anota sin consentimiento, se otorga, y el registro llega **con su contenido intacto y sin intervención**
- [X] T065 [US1] Implementar `lib/datos/firestore/consentimientos.dart`, que implementa la puerta leyendo el documento del nadador y **funciona desde la caché sin red**, porque el nadador no puede quedarse sin poder anotar por no tener señal
- [X] T066 [US1] Impedir la publicación de un plan a un nadador sin consentimiento vigente en `lib/ui/planes/pantalla_plan.dart`, diciendo **exactamente qué falta** en lugar de un error genérico
- [X] T067 [US1] Mostrar al nadador sin consentimiento, sin bloquearlo, por qué lo suyo está esperando. Reutiliza `lib/ui/nadador/aviso_sincronizacion.dart`, que ya sabe decir que algo quedó guardado
- [X] T068 [P] [US1] Escribir en `test/ui/nadador/sin_consentimiento_test.dart` la garantía P2 y SC-002: recorrer la app entera con un nadador sin consentimiento y comprobar que **no hay un solo punto** que exija consentimiento para continuar

**Checkpoint**: 🎯 **aquí la feature empieza a valer.** La puerta existe y la hace cumplir el
servidor. A partir de este punto se puede desplegar sin incumplir el principio V.

---

## Phase 6: User Story 4 — El trabajo del entrenador deja de perderse (Priority: P1)

**Goal**: los planes sobreviven al cierre de la app, con su estado, su versión sellada y sus
asignaciones.

**Independent Test**: generar y aprobar un plan, cerrar la app por completo, volver y
comprobar que está igual, byte a byte (escenario V13).

> **Esto es menos trabajo del que parece.** `lib/datos/firestore/repositorios_firestore.dart`
> se escribió entero en la feature 001 y `lib/main.dart` sencillamente nunca lo usó: tiene un
> `List<Plan>` en memoria y un `RepositorioNadadoresMemoria`. Es, sobre todo, cableado.

- [X] T069 [US4] Sustituir en `lib/main.dart` el `List<Plan> _planes` en memoria por `RepositorioPlanesFirestore`, que ya existe y ya implementa todo el contrato
- [X] T070 [US4] Sustituir `RepositorioNadadoresMemoria` por `RepositorioNadadoresFirestore` en `lib/main.dart`, conservando el camino de perfiles de prueba para desarrollo
- [X] T071 [US4] Añadir `declaraSerMayorDeEdad` a `lib/dominio/entidades/nadador.dart` como `bool?`, donde `null` significa «todavía no lo declaró», que **no es lo mismo que menor**. Mantener `fechaNacimiento` opcional (minimización, FR-008)
- [X] T072 [US4] Serializar el campo nuevo en `lib/datos/serializacion.dart` sin romper los documentos ya guardados
- [X] T073 [P] [US4] Escribir en `test/datos/persistencia_plan_test.dart` que guardar y recuperar un plan aprobado **no altera un byte**, y que un borrador guardado sigue siendo borrador (FR-032, FR-033)
- [X] T074 [P] [US4] Escribir en `test/dominio/metodologia/categoria_sin_edad_test.dart` el criterio SC-016: la categoría de un nadador **no cambia** al añadirle, quitarle o cambiarle la fecha de nacimiento, ni se sugiere a partir de ella (sección 11.1 de la metodología 3.6.0)
- [X] T075 [US4] Comprobar que la lectura de los planes propios sigue funcionando **sin red**, apoyada en la caché de Firestore que la feature 003 dejó activada (FR-034)

**Checkpoint**: el trabajo del entrenador sobrevive. Con esto y la fase 5, la feature es
desplegable.

---

## Phase 7: User Story 5 — El acudiente ve, se lleva y borra (Priority: P2)

**Goal**: los derechos de la Ley 1581 dejan de ser una promesa del documento y se pueden
ejercer.

**Independent Test**: consultar lo almacenado de un nadador, exportarlo y eliminarlo,
comprobando que lo exportado es legible y que **los planes del entrenador siguen ahí**
(escenario V14).

- [X] T076 [US5] Implementar la consulta de qué se guarda sobre un nadador, **en términos comprensibles para un acudiente** y no como un volcado técnico (FR-036)
- [X] T077 [US5] Conectar la exportación de los datos del nadador reutilizando `lib/datos/exportacion.dart`, que la feature 001 ya construyó (FR-037)
- [X] T078 [US5] Implementar la eliminación de los datos personales de un nadador, apoyándose en `RepositorioRegistros.eliminarDe` que ya existe desde la 003 (FR-038). **Ojo con las subcolecciones**: en Firestore no se borran con su documento padre, se quedan huérfanas pero legibles. Apareció al escribir las pruebas de consentimiento, donde el historial sobrevivía a la limpieza. Borrar el consentimiento de un nadador sin recorrer su `historial/` dejaría en pie justo lo que hay que borrar
- [X] T079 [P] [US5] Escribir en `test/datos/borrado_sin_destruir_test.dart` el criterio SC-014: eliminados los datos personales de un nadador, **los planes del entrenador siguen siendo consultables**

---

## Phase 8: User Story 6 — El entrenador trabaja antes de tener el grupo (Priority: P3)

**Goal**: la puerta de publicación no se convierte en una puerta de trabajo.

**Independent Test**: generar, auditar y aprobar un plan sin ningún nadador con
consentimiento, y comprobar que lo único bloqueado es la entrega.

- [X] T080 [US6] Comprobar que generar, auditar, aprobar y guardar un plan **no consulta la puerta en ningún punto**: el trabajo del entrenador es su obra profesional y no son datos personales de nadie
- [X] T081 [P] [US6] Escribir en `test/ui/planes/trabajar_sin_consentimientos_test.dart` el recorrido completo sin un solo nadador con consentimiento, terminando en el intento de publicar, que es el único que se deniega

---

## Phase 9: Polish & Cross-Cutting Concerns

- [X] T082 **Retirar `lib/ui/nadadores/aviso_consentimiento.dart`** y sus usos. Lleva escrito en su propia documentación: «debe retirarse cuando la feature de cuentas implemente el consentimiento verificable, **no antes**». Ahora es antes
- [X] T083 Retirar de `specs/003-consumo-del-nadador/plan.md` la desviación declarada del principio V, dejando constancia de en qué tarea de esta feature se cerró
- [X] T084 [P] Actualizar `README.md` y `docs/DEVELOPMENT.md`, **en inglés**, con las cuentas, los roles y la superficie de servidor
- [X] T085 [P] Revisar que ningún archivo del repositorio contenga credenciales, claves ni tokens, incluidos los de prueba de las funciones
- [X] T086 Recorrer entero [quickstart.md](quickstart.md) y marcar cada escenario con lo que lo cubre
- [X] T087 Desplegar en Firebase Hosting. **Hecho el 2026-10-19 en el proyecto `swimming-app-ab45f`**: reglas, servidor y sitio, en ese orden, para que la puerta estuviera puesta antes de que existiera una app capaz de escribir a través de ella. Vivo en https://swimming-app-ab45f.web.app, con el entrenador entrando con su cuenta. El camino no fue limpio: ver «Lo que el despliegue destapó» más abajo
- [ ] T088 **Cerrar T071 de la feature 003**: verificar los escenarios C1 y C2 en un dispositivo real con el modo avión puesto. Lleva pendiente desde que no había dónde desplegar
- [ ] T089 Verificar C7 y C8 de esta feature **en un dispositivo real**: hermanos compartiendo teléfono y sesión caducada al borde de la piscina. No se pueden comprobar de verdad en un navegador de escritorio
- [X] T090 Pasar las cuatro puertas de calidad en orden: `flutter analyze`, `flutter test`, `npm --prefix firebase test` y `dart run tool/verificar_metodologia.dart`

---

## Dependencies & Execution Order

### Entre fases

- **Fase 1 (Setup)**: sin dependencias.
- **Fase 2 (Foundational)**: depende de la 1. **Bloquea todo lo demás.**
- **Fase 3 (US3, cuentas)**: depende de la 2. Es la base de las otras tres historias P1.
- **Fase 4 (US2, consentimiento)**: depende de la 3, porque emitir una solicitud exige saber
  quién es el entrenador.
- **Fase 5 (US1, la puerta)**: depende de la 4, porque la puerta comprueba un registro que la
  fase 4 crea. **Primer punto de corte con valor real.**
- **Fase 6 (US4, persistencia)**: depende de la 3, porque las reglas exigen un token con rol.
  Es independiente de las fases 4 y 5 y puede hacerse en paralelo con ellas.
- **Fase 7 (US5)** y **Fase 8 (US6)**: dependen de la 5.
- **Fase 9 (Polish)**: al final, y T087 a T089 exigen el despliegue.

### Lo que puede ir en paralelo

- Dentro de la fase 2: T008, T010, T013, T017 y T019 tocan archivos distintos.
- **La fase 6 completa**, en paralelo con las fases 4 y 5. Es la única historia P1 que no está
  en la cadena de la puerta.
- Todas las pruebas de garantías marcadas `[P]` dentro de cada fase: son archivos distintos y
  no dependen entre sí.
- Las fases 7 y 8 entre sí.

---

## Implementation Strategy

### El primer corte que vale algo

No es una historia suelta: es **Setup + Foundational + fases 3, 4 y 5**. Ahí existe la puerta
y la hace cumplir el servidor, y recién ahí se puede desplegar sin incumplir el principio V.

Cortar antes deja casillas marcadas sin nada que proteja a nadie, que es justo lo que esta
lista aprendió a no hacer cuando T006 de la 003 estuvo marcada sin estarlo.

### Entrega incremental

1. Fases 1 y 2 → hay identidad y roles.
2. Fase 3 → cada quien ve lo suyo. **Todavía sin nadadores reales.**
3. Fases 4 y 5 → la puerta existe. 🎯 **Desplegable.**
4. Fase 6, en paralelo → el trabajo del entrenador sobrevive.
5. Fases 7 y 8 → derechos ejercitables y el entrenador no queda bloqueado.
6. Fase 9 → despliegue, dispositivo real y se cierra T071 de la 003.

---

## Notes

- `[P]` significa archivos distintos y sin dependencias pendientes.
- Las pruebas de garantías se escriben **antes** y tienen que fallar.
- Ninguna tarea se marca `[X]` sin que su prueba exista y pase. En la feature 003 ocurrió dos
  veces y las dos quedaron anotadas.
- **Las reglas son la feature.** Una garantía de la puerta probada solo a través de la
  interfaz no está probada: se prueba contra el emulador, con la cuenta correcta y saltándose
  la app.
- El texto informativo del consentimiento queda marcado como **pendiente de revisión
  jurídica** hasta que un abogado lo mire. Está anotado también en el checklist.

---

## Lo que el despliegue destapó

Cinco fallos. **Ninguno lo encontraron las pruebas**: los encontró el entrenador usando
la app desplegada. Quedan escritos porque el patrón importa más que cada uno por separado.

| # | Qué fallaba | Por qué no salió antes |
|---|---|---|
| 1 | Las funciones no compilaban al desplegar | Los proyectos nuevos de Google Cloud ya no conceden a la cuenta de Cloud Build el rol que necesita. No es del código |
| 2 | `firebase_auth` no se registraba en release, y **nadie podía entrar** | `firebase_auth` entró en `pubspec.yaml` después de compilaciones web anteriores, y la build incremental reutilizó un registrant de plugins cacheado. Debug lo regenera; solo release estaba roto |
| 3 | La corrección desplegada no surtía efecto | Los puntos de entrada de Flutter web no llevan hash en el nombre, y Hosting cachea una hora. El navegador seguía con el bundle roto |
| 4 | Una cuenta nueva volvía al login | El disparador que asigna el rol falló por permisos, **y** el cliente trataba «con sesión, sin rol todavía» igual que «sin sesión» |
| 5 | «Preparando tu cuenta» giraba sin fin | Comprobar el rol refresca el token a la fuerza; cada refresco hacía emitir al flujo de cambios, que reiniciaba la espera |

### Lo que esto dice de las pruebas

Las 995 pruebas pasaban con los cinco fallos presentes, porque **ninguna recorría el camino
real contra Firebase**: dos eran de empaquetado, uno de caché HTTP, y los otros dos vivían
en la frontera entre el reloj del servidor y el estado del cliente, que es justo donde los
dobles no llegan.

Los fallos 4 y 5 sí tienen prueba ahora —`test/ui/acceso/sesion_test.dart` cubre el rebote
al login y el bucle infinito—, y se comprobó que fallan contra el código anterior. Los
otros tres no son cubribles con pruebas unitarias; se contienen con lo que se dejó en el
repositorio: `Cache-Control: no-cache` en los puntos de entrada, y el procedimiento de
despliegue escrito en `docs/DEVELOPMENT.md`.

**La conclusión que importa:** esta feature no tiene ni una prueba automática del recorrido
completo contra un Firebase de verdad. Es la misma carencia que T071 de la feature 003
viene arrastrando, y sigue abierta.

### Una corrección a mitad de diagnóstico

Durante el fallo 3 concluí que la causa eran las cabeceras de seguridad, porque al quitarlas
en un canal de vista previa funcionó. Era falso: un segundo canal **con** las cabeceras
también funcionó, y lo que arreglaba era que un dominio nuevo tiene la caché vacía. Las
cabeceras se quedaron. Queda anotado porque estuve a punto de retirar tres cabeceras de
seguridad por un diagnóstico mal hecho.

### El rol hubo que asignarlo dos veces

La primera asignación no quedó. Se comprobó con `ver-rol`, que se escribió justamente
porque «el rol ya está asignado» se había dado por bueno dos veces sin mirarlo, y los
*custom claims* no se ven en la consola de Firebase.
