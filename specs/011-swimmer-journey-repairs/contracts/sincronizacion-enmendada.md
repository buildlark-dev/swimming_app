# Contrato de sincronización, enmendado

Enmienda de `specs/003-consumo-del-nadador/contracts/sincronizacion.md`. **La promesa al
nadador no cambia** y las ocho garantías siguen en pie, palabra por palabra. Lo que
cambia es cómo se cumple el segundo disparador, que nunca tuvo mecanismo.

---

## Lo que no se toca

- **G1** — escribir nunca falla por falta de red.
- **G2** — lo pendiente sobrevive al cierre de la app.
- **G3** — un envío fallido vuelve a pendiente, y nunca se descarta.
- **G4** — reenviar no duplica, porque el identificador es determinista.
- **G5** — el orden no importa, y uno que falla no detiene a los demás.
- **S8** — un fallo al escribir **en local** sí sube.
- **FR-017** — la frase que ve el nadador, al pie de la letra.
- Lo que el nadador **no** ve: ni un error de red, ni un código, ni un contador de
  intentos, ni un botón de reintentar.

---

## Cuándo se intenta enviar — enmendado

| Disparador | Por qué | Estado |
|---|---|---|
| Al guardar un registro | El caso normal: hay red y llega al momento | Sin cambios |
| **Mientras quede algo por enviar** | Sustituye a «al volver la red» | **Nuevo mecanismo** |
| Al abrir la app | Recoge lo que quedó de una sesión anterior | Sin cambios |

### Por qué «al volver la red» deja de nombrarse así

Porque no se puede saber que la red volvió sin intentarlo. El disparador original suponía
un detector —algo que avisara— y lo que se construyó fue un sondeo que preguntaba si
Firestore se había inicializado, verdadero con el avión puesto y para siempre. Nunca
emitió, y nadie lo escuchaba.

Lo que el nadador tenía prometido se cumple igual, y por eso la promesa no se enmienda:
**ella no toca nada y lo suyo sale cuando hay red**. Lo que cambia es que la app lo
descubre intentando, en vez de esperar a que alguien le avise.

Es, además, lo que `estado_de_red.dart` dice desde la feature 003: «se intenta una
escritura y se ve si llega». Solo fue posible cuando el envío pasó a tener plazo: antes,
un intento que no volvía no era una respuesta.

---

## Reglas del nuevo disparador

1. **Con la bandeja vacía no se intenta nada.** Ni temporizadores, ni sockets, ni
   despertares. No hay nada que descubrir.
2. **Mientras quede algo, se reintenta** con la espera creciente que ya existe —1, 2, 4,
   8…— **con techo de un minuto**. El techo baja de cinco minutos a uno; la razón
   original —no reintentar en bucle apretado, que el teléfono es de alguien que está
   nadando— se sostiene igual con un intento por minuto.
3. **Un intento a la vez por registro, y una sincronización a la vez.** Dos
   sincronizaciones solapadas leen la bandeja antes de que ninguna marque «enviando» y
   mandan lo mismo dos veces.
4. **Todo intento lleva plazo.** Uno que no contesta cuenta como *no llegó*, nunca como
   *llegó* y nunca como *seguimos esperando*.
5. **Un intento que llega tarde se honra.** Si el plazo venció pero la escritura acaba
   llegando por su cuenta, el registro queda enviado y el aviso se apaga. El aviso se
   apaga porque **llegó**, nunca porque dejáramos de mirar.
6. **El estado de la red es el resultado del último intento.** No se le pregunta al
   sistema operativo: «hay wifi» y «el servidor responde» son cosas distintas, y una
   piscina con wifi que no sale a internet es el caso normal.

---

## Lo que esto cuesta

Con un registro en la bandeja y sin red, en régimen estable: **60 intentos por hora como
máximo**, cada uno una escritura acotada que no llega a ningún servidor. **Cero
lecturas.** Cero operaciones facturables, porque un intento que no llega no es una
operación que nadie cobre.

Con la bandeja vacía: **cero de todo**.

---

## Lo que el dominio sigue sin saber

Ni qué es Firestore, ni cómo se detecta nada, ni dónde se guarda lo pendiente. El
`Sincronizador` recibe un transporte que puede fallar o tardar, y un reloj. Lo nuevo que
recibe es **cuándo despertarse**, y también se inyecta, para que las ocho garantías se
sigan probando sin esperar un solo segundo de reloj real.

---

## Escenarios de verificación

Lo que se puede comprobar aquí, en Dart puro y con el tiempo simulado:

- Con la bandeja vacía no se programa ningún despertar.
- Con algo pendiente se reintenta, y la espera crece y se detiene en un minuto.
- Un registro que ya falló varias veces se manda en cuanto el transporte vuelve a
  responder, sin servir el resto de su espera.
- Un transporte que acepta y no contesta no cuelga nada, cuenta como fallo, y si contesta
  más tarde el registro queda enviado.
- Dos sincronizaciones a la vez no mandan lo mismo dos veces.
- Al parar, no queda ningún despertar programado.

Lo que **no** se cierra aquí: C1 y C2 de la feature 003, en un dispositivo real con el
modo avión puesto. Se caminan después de la feature 013, por decisión del entrenador.
