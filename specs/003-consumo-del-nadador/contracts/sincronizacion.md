# Contrato: sincronización y bandeja de salida

**Feature**: 003 — el nadador consume su plan
**Decisiones**: [D1, D2, D3 de research.md](../research.md)

Este contrato define lo que la bandeja de salida garantiza. Es el corazón de la feature:
todo lo demás es pantallas.

---

## La promesa

> **Ningún dato escrito sin conexión se pierde en silencio.**

De ahí salen cinco garantías comprobables.

### G1 — Escribir nunca falla por falta de red

`guardar(registro)` escribe en el almacenamiento local y encola el envío. **No consulta la
red y no puede fallar por su causa.** Devuelve con éxito tanto con red como sin ella.

Un fallo de escritura local sí es un fallo, y se reporta: ahí sí se perdería el dato.

### G2 — Lo pendiente sobrevive al cierre de la app

La bandeja de salida se persiste en el dispositivo. Cerrar la app, apagar el teléfono o
quedarse sin batería no la vacía.

### G3 — Un envío fallido vuelve a pendiente

No existe estado terminal de fallo. Un error de red, un tiempo agotado o un rechazo
temporal del servidor devuelven el registro a `pendiente` con el contador de intentos
incrementado.

**Qué no se hace**: descartar el registro, por ninguna razón y por muchos intentos que
lleve. Un registro que lleva cuarenta intentos es un problema que hay que mirar, no un
registro que haya que tirar.

### G4 — Reenviar no duplica

El identificador del registro es determinista (D2): deriva de `nadadorId`, `planId`,
`sesionId` y `versionDePlan`. Enviar dos veces el mismo registro escribe dos veces el mismo
documento, con el mismo contenido. **La duplicación es imposible por construcción**, no por
una comprobación que alguien pueda olvidar.

### G5 — El orden no importa

Los registros se envían de forma independiente. Que el de la sesión del martes llegue
después del de la del jueves no afecta a nada: cada uno es un documento completo que apunta
a su sesión.

**Qué no se garantiza, y conviene decirlo**: no hay transacción entre varios registros. Si
hay tres pendientes y solo llegan dos, el estado es correcto —dos enviados, uno pendiente—,
no inconsistente.

---

## Qué ve el nadador

| Situación | Lo que se muestra |
|---|---|
| Sin registros pendientes | Nada. El estado de sincronización no ocupa pantalla cuando no hace falta |
| Uno o más pendientes | **«Guardado el progreso, se enviará cuando tengas acceso a internet»** |
| Enviando | Lo mismo. No se le cuenta al nadador el detalle del transporte |
| Recién enviado todo | El aviso desaparece |

**Lo que nunca se le muestra**: un error de red, un código de estado, un contador de
reintentos o un botón de «reintentar». El reintento es trabajo de la app, no del nadador, y
alguien mojado al borde de una piscina no está para diagnosticar conectividad.

**Lo que sí se le muestra además**: cuándo se sincronizó por última vez, para que sepa si
lo que lee está al día (D1).

---

## Cuándo se intenta enviar

| Disparador | Por qué |
|---|---|
| Al guardar un registro | El caso normal: hay red y llega al momento |
| Al volver la red | Es la razón de ser de la bandeja (FR-018) |
| Al abrir la app | Recoge lo que quedó de una sesión anterior |

Los reintentos se espacian de forma creciente. **No se reintenta en bucle apretado**: un
teléfono al borde de una piscina tiene batería limitada y es de alguien que está nadando.

> **Enmendado por la feature 011.** El segundo disparador nunca tuvo mecanismo:
> `alVolverLaRed` existía y estaba probado, y nadie lo escuchaba; y el sondeo detrás
> preguntaba si Firestore se había inicializado, cierto con el avión puesto y para
> siempre. La promesa al nadador no cambia —él no toca nada y lo suyo sale— pero la forma
> de cumplirla sí: **el intento es el sondeo**, y mientras quede algo en la bandeja se
> vuelve a intentar solo. El techo de la espera baja de cinco minutos a uno.
>
> Las ocho garantías siguen intactas. Lo que cambia está en
> [`specs/011-swimmer-journey-repairs/contracts/sincronizacion-enmendada.md`](../../011-swimmer-journey-repairs/contracts/sincronizacion-enmendada.md),
> y este documento se deja como está porque es el registro de lo que se prometió.

---

## Lo que el dominio no sabe

El dominio declara `BandejaDeSalida` como interfaz y **no sabe** qué hay debajo: ni
Firestore, ni el mecanismo de detección de red, ni dónde se guarda lo pendiente. El
principio II lo exige y la prueba de frontera lo vigila.

En consecuencia, **toda la lógica de la bandeja se prueba en Dart puro**, con la red y el
reloj simulados. Esa es la razón principal por la que no se delegó en la cola interna de
Firestore (D1): aquello no se podría probar sin probar Firebase.

---

## Escenarios de verificación

| | Escenario | Resultado esperado |
|---|---|---|
| **S1** | Guardar sin red | Éxito, registro en local, estado `pendiente`, aviso visible |
| **S2** | Vuelve la red con un pendiente | Se envía solo, estado `enviado`, aviso desaparece |
| **S3** | Cerrar y reabrir con pendientes | Siguen ahí, el aviso vuelve a mostrarse |
| **S4** | El envío falla tres veces y luego funciona | Tres incrementos de `intentos`, un solo documento en destino |
| **S5** | Enviar dos veces el mismo registro | Un solo documento, mismo contenido |
| **S6** | Tres pendientes, llegan dos | Dos `enviado`, uno `pendiente`. Ningún estado intermedio raro |
| **S7** | Guardar con red disponible | Llega directo, el nadador nunca ve el aviso |
| **S8** | Fallo al escribir en local | **Sí se reporta**: ahí el dato sí se perdería |
