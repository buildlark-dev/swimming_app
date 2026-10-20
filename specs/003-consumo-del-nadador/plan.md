# Plan de implementación: el nadador consume su plan

**Branch**: `003-swimmer-plan-consumption` | **Date**: 2026-10-13 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/003-consumo-del-nadador/spec.md`

## Summary

El entrenador ya genera, revisa y aprueba microciclos. El nadador no tiene por dónde entrar.
Esta feature le da una puerta: ve su sesión del día sin señal, la marca, anota su RPE y sus
observaciones, y eso llega al entrenador junto al plan que lo originó.

El enfoque técnico se decide en [research.md](research.md) y gira sobre una sola cosa: **la
lectura se apoya en la caché de Firestore, la escritura en una bandeja de salida propia en
el dominio.** Ese reparto no es gratuito ni obvio, y la razón es que necesitamos tres cosas
que la cola interna de Firestore no da: poder probarlo en Dart puro, controlar la
idempotencia, y que «pendiente de envío» sea un concepto del dominio y no un reflejo de un
detalle de la base de datos.

## Technical Context

**Language/Version**: Dart 3.12.2, Flutter 3.44.2

**Primary Dependencies**: `cloud_firestore` ^5.5.0, `firebase_core` ^3.8.0, `provider`
^6.1.2. **Una dependencia nueva** para persistir la bandeja de salida en el dispositivo; la
elección concreta se resuelve en la primera tarea, con el criterio de que funcione en web y
móvil y no arrastre un esquema que mantener.

**Storage**: Firestore con persistencia activada para la lectura. Almacenamiento local del
dispositivo para los registros del nadador y la bandeja de salida.

**Testing**: `flutter_test` para dominio e interfaz, `@firebase/rules-unit-testing` sobre
el emulador para las reglas de acceso. La bandeja de salida se prueba **en Dart puro**, con
red y reloj simulados.

**Target Platform**: Web (Firebase Hosting) y móvil. El uso real es **a pie de piscina**,
con el teléfono mojado y sin señal.

**Project Type**: aplicación Flutter con dominio en Dart puro y capa de datos aislada.

**Performance Goals**: abrir la app y ver la sesión del día **sin ningún paso de red**.
Marcar y anotar en **menos de 30 segundos** (SC-002), que es lo que dura la paciencia de
alguien mojado.

**Constraints**:
- Leer plan, sesión del día y progreso **nunca** requiere red.
- Ningún dato escrito sin conexión se pierde en silencio.
- Un plan aprobado es **inmutable**.
- Carga externa e interna **nunca** combinadas en un mismo indicador.
- Sin nombres, marcas ni identificadores de nadador en registros ni analítica.

**Scale/Scope**: los grupos del entrenador. Decenas de nadadores, no miles. Un plan son 1 a
14 microciclos; un microciclo, 1 a 10 sesiones.

## Constitution Check

*GATE: debe pasar antes de la Fase 0 y volver a comprobarse tras la Fase 1.*

| Principio | Cómo lo cumple | Estado |
|---|---|---|
| **I. Metodología como norma** | Las series se muestran con la notación del entrenador y los nombres exactos de la Biblioteca, sin reescribir (FR-004). El RPE usa Borg 0-10, que es lo que declara la sección 9 | ✅ |
| **II. Dominio en Dart puro** | `RegistroDeSesion`, `EnvioPendiente` y el cálculo de adherencia viven en `lib/dominio/`. Las interfaces no mencionan tipos de Firestore. La prueba de frontera lo vigila | ✅ |
| **III. Pruebas de las reglas que llegan al nadador** | La colección de registros se añade denegando por omisión, con casos negativos. La bandeja de salida se prueba entera en Dart puro | ✅ |
| **IV. El criterio del entrenador no se delega** | Un reporte de molestia llega señalado y **no se resuelve solo**: la app no clasifica gravedad ni sugiere conducta. El reajuste automático queda fuera de alcance | ✅ |
| **V. Datos de deportistas** | Sin nombres ni marcas en registros ni analítica (FR-023); exportable y borrable (FR-024); acceso denegado por omisión (FR-025). **Con desviación declarada, ver abajo** | ⚠️ |
| **VI. Freemium honesto** | Registrar el progreso propio pertenece al nivel gratuito, y acceder a lo que uno mismo generó nunca queda tras el muro de pago (FR-026) | ✅ |
| **VII. Rebanadas verticales y simplicidad** | Cuatro historias comprobables por separado; la primera entrega valor sola. Se descarta una base de datos local propia por no justificar su complejidad (D1) | ✅ |
| **VIII. Control de carga interna** | Es la razón de ser de la feature: registro por sesión, que llega al entrenador junto al plan que lo originó, con carga externa e interna separadas y la molestia aparte | ✅ |

### Desviación declarada — Principio V · **CERRADA el 2026-10-15**

> **Ya no es una desviación.** La feature 004 la cerró en su tarea T024: las reglas comparan
> contra `request.auth.uid` y cada nadador lee y escribe únicamente lo suyo.
>
> Se cumplió lo que esta sección prometió. **No hubo que migrar un solo documento**, porque
> cada registro ya llevaba su `nadadorId` desde esta feature. Y dejó de hacer falta la
> contención de más arriba: el consentimiento verificable existe, así que la app ya puede
> usarse con nadadores reales.
>
> Lo que sigue es el texto original, conservado porque un plan describe lo que se decidió
> cuando se decidió, no lo que acabó pasando.

**Qué**: las reglas de acceso de esta feature **no distinguen a un nadador de otro**. La
colección de registros se escribe solo con el rol de entrenador y deniega al resto.

**Por qué**: no hay identidad de nadador hasta la feature 004, y el principio V es explícito
en que mientras no exista el registro de consentimiento **la app se usa únicamente con datos
de prueba o del propio entrenador**. Escribir reglas que comparen contra un identificador
que cualquiera puede declarar daría una falsa sensación de protección.

**Cómo se contiene**:
- Ningún nadador real usa esta feature. Está en la especificación como supuesto bloqueante,
  no como nota al pie.
- Las reglas de la colección nueva **sí se prueban desde ahora** con sus casos negativos: se
  prueba lo que hay, y en 004 se añade lo que falta.
- El modelo de datos ya lleva `nadadorId` en cada registro, así que 004 añade la regla sin
  migrar datos.

**Cuándo deja de ser desviación**: con la feature 004. El grupo de Iniciación Avanzada son
niños de 7 a 10 años, y el consentimiento verificable es puerta de publicación.

## Project Structure

### Documentation (this feature)

```text
specs/003-consumo-del-nadador/
├── plan.md                        # Este archivo
├── spec.md                        # Qué y por qué
├── research.md                    # Las seis decisiones, con sus alternativas
├── data-model.md                  # Entidades, invariantes y almacenamiento
├── quickstart.md                  # Escenarios de verificación de extremo a extremo
├── checklists/requirements.md     # Calidad de la especificación
├── contracts/
│   ├── sincronizacion.md          # Las cinco garantías de la bandeja de salida
│   └── registro_del_nadador.md    # Qué se acepta y qué ve el entrenador
└── tasks.md                       # Lo genera /speckit-tasks
```

### Source Code (repository root)

```text
lib/
├── dominio/
│   ├── entidades/
│   │   ├── registro_sesion.dart        # NUEVO · RegistroDeSesion, ReporteDeMolestia
│   │   └── envio_pendiente.dart        # NUEVO · EnvioPendiente, EstadoDeEnvio
│   ├── calculo/
│   │   └── progreso_nadador.dart       # NUEVO · historial y adherencia
│   ├── sincronizacion/
│   │   └── bandeja_salida.dart         # NUEVO · la lógica, en Dart puro
│   └── repositorios/
│       └── repositorios.dart           # AMPLÍA · RepositorioRegistros, BandejaDeSalida
├── datos/
│   ├── local/
│   │   ├── almacen_local.dart          # NUEVO · persistencia en el dispositivo
│   │   └── bandeja_salida_local.dart   # NUEVO · implementación de la bandeja
│   ├── firestore/
│   │   ├── configuracion.dart          # AMPLÍA · activar persistencia de lectura
│   │   └── repositorio_registros.dart  # NUEVO
│   ├── red/
│   │   └── estado_de_red.dart          # NUEVO · detectar que la red vuelve
│   ├── exportacion.dart                # AMPLÍA · descarga con registros (D5)
│   └── serializacion.dart              # AMPLÍA · registros
└── ui/
    └── nadador/                        # NUEVO · todo lo que ve el nadador
        ├── pantalla_sesion_del_dia.dart
        ├── pantalla_mi_progreso.dart
        ├── formulario_registro.dart
        └── aviso_sincronizacion.dart

test/
├── dominio/
│   ├── entidades/registro_sesion_test.dart
│   ├── calculo/progreso_nadador_test.dart
│   └── sincronizacion/bandeja_salida_test.dart     # Las ocho garantías S1-S8
├── datos/registros_test.dart
└── ui/nadador/                                     # Recorridos sin conexión

firebase/test/reglas.test.js                        # AMPLÍA · casos negativos
```

**Structure Decision**: se conserva la separación de 001 y 002 —`dominio` puro, `datos`
aislada, `ui` encima— y se añade `lib/ui/nadador/` como carpeta propia. El nadador y el
entrenador son dos recorridos distintos sobre el mismo dominio, y mezclarlos en las mismas
pantallas haría que cada cambio para uno arriesgara al otro.

`lib/dominio/sincronizacion/` es carpeta nueva porque la bandeja de salida no es una entidad
ni un cálculo: es una máquina de estados con reglas propias, y merece su sitio.

## Complexity Tracking

| Desviación | Por qué hace falta | Alternativa más simple, y por qué se rechaza |
|---|---|---|
| Bandeja de salida propia en vez de la cola de Firestore | Hacen falta tres cosas que aquella no da: probarlo en Dart puro (principio III), controlar la idempotencia (FR-020) y que el estado pendiente sea dominio y no un detalle de la base de datos (principio II) | Delegar en `hasPendingWrites`. Se rechaza porque probarlo sería probar Firebase, y porque el reintento no garantiza conservar la referencia del documento |
| Una dependencia nueva para persistir en el dispositivo | FR-021 exige que lo pendiente sobreviva al cierre de la app, y eso necesita algo que escriba en disco en web y en móvil | Guardar en memoria. Se rechaza: perdería todo al cerrar, que es exactamente lo que la feature promete que no pasa |
| Carpeta `lib/ui/nadador/` separada | Son dos recorridos distintos sobre el mismo dominio | Reutilizar las pantallas del entrenador. Se rechaza: cada cambio para uno arriesgaría al otro, y lo que el nadador ve y lo que el entrenador edita no se parecen |

**Lo que se rechazó por no justificar su complejidad**: una base de datos local propia
(`drift`, `hive`, `sqflite`) para lectura y escritura. Resolvería todo con un mecanismo,
pero duplicaría una caché que Firestore ya trae, a cambio de un esquema que mantener y
migraciones que escribir. El principio VII pide eliminar la complejidad que no se justifica.

## Re-evaluación tras la Fase 1

Los artefactos de diseño no introdujeron ninguna desviación nueva.

La única que había antes del diseño —las reglas sin identidad de nadador— sigue igual, con
su contención y su fecha de caducidad. El resto de principios se cumple como estaba
previsto, y dos salieron **reforzados** por el diseño:

- **VIII**: `data-model.md` deja el registro sin metros, series ni zonas, lo que hace que
  combinar carga externa e interna no sea un error posible, sino algo que habría que ir a
  buscar a propósito.
- **III**: separar la bandeja de salida del transporte permite probar sus ocho garantías sin
  emulador y sin red.
