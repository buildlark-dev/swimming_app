# Contrato: la frontera entre entrenadores

Lo que el servidor garantiza sobre quién lee a quién, y lo que ninguna pantalla puede
saltarse.

---

## La promesa

> **Un entrenador lee a los suyos. A nadie más, por ninguna vía.**

«Por ninguna vía» significa lo mismo que significó en la feature 009 cuando se dijo de
marcar una sesión: no que una pantalla esconda un botón, sino que **la consulta no se
pueda hacer**. Una regla que dependa de que el cliente filtre bien no es una frontera; es
una costumbre.

---

## Las garantías

### F1 — Pertenecer es un hecho con un solo sitio

Una nadadora pertenece a una comunidad o no pertenece a ninguna, y eso se lee de su
propio perfil. No hay copia en ningún otro documento, así que **terminar una pertenencia
surte efecto de inmediato y en todas partes**.

### F2 — Una consulta se demuestra por sus filtros

Toda consulta que hace el entrenador lleva en sus filtros lo que la regla exige. Las
reglas no filtran: o la consulta se puede demostrar entera, o Firestore la rechaza entera.

**Esto se prueba corriendo las consultas que hace la app**, no leyendo documentos sueltos
por su identificador. Una suite que solo hace `get` por id da verde sobre una regla que la
app no puede usar — es la lección que la 009 pagó dos veces.

### F3 — Antes de aceptar, nada

Mientras una solicitud espera, el entrenador no lee **nada** de ella más allá de lo que la
propia solicitud lleva: ni respuestas, ni molestias, ni adherencia, ni peticiones de
feedback. Aceptar es lo único que abre esa puerta.

### F4 — Después de aceptar, todo lo suyo

Lo que ella escribió **antes** de que él aceptara queda legible para él. Siempre fue suyo;
la pertenencia dice quién puede leerlo, no desde cuándo existe.

### F5 — Aceptar es un acto suyo, y del servidor

Nadie acepta automáticamente. Y aceptar escribe la pertenencia y cierra la solicitud en
**un solo acto del servidor**: media aceptación es una nadadora que no pertenece a nadie y
que ya no tiene solicitud que enseñar.

### F6 — El cliente no escribe la pertenencia

`comunidadId` solo lo escribe el servidor. Ni el entrenador desde su pantalla, ni la
nadadora desde la suya. Una regla que dejara a un entrenador escribir en el perfil de otra
persona tendría que vigilar después todos los demás campos de ese perfil, y la primera que
se olvide es un agujero.

### F7 — Terminar es simétrico y no borra nada

Ella puede irse; él puede sacarla. En los dos casos él deja de leerla desde ese momento, y
**nada de lo que ella escribió se toca**. Irse de una comunidad no es borrarse.

### F8 — El consentimiento no se sustituye, se compone

La puerta de la feature 004 sigue igual: decide si los datos de una menor pueden salir del
dispositivo. La pertenencia decide quién puede leerlos. **Las dos tienen que cumplirse**,
y ninguna sustituye a la otra.

---

## Lo que ve cada uno

| | Antes de aceptar | Después | Tras terminar |
|---|---|---|---|
| El entrenador, sobre ella | solo la solicitud | todo lo suyo, incluido lo anterior | nada |
| Ella, sobre lo suyo | todo | todo | todo |
| Otro entrenador | nada | nada | nada |

---

## El acto del servidor

Una sola llamada por cada cosa que puede pasarle a una pertenencia:

| Acto | Quién | Qué hace |
|---|---|---|
| Aceptar | el entrenador de esa comunidad | escribe la pertenencia y cierra la solicitud |
| Rechazar | el mismo | cierra la solicitud, sin motivo escrito |
| Sacar | el mismo | quita la pertenencia |
| Irse | la nadadora | quita la suya |

**Cada uno comprueba quién llama antes de hacer nada**, y rechaza lo que no es suyo: un
entrenador no resuelve solicitudes de otra comunidad, y una nadadora no se saca a sí misma
de una comunidad a la que no pertenece.

---

## Lo que esto cuesta

La regla consulta el perfil de la nadadora para saber de quién es. Es **una lectura por
documento leído**, el mismo precio que la puerta de consentimiento acepta desde la feature
004 y por la misma razón escrita allí: a esta escala —decenas de nadadores— es
irrelevante, y ahorrárselo copiando el dato crearía la posibilidad de que diga dos cosas
distintas en dos sitios.

La consulta que la feature 007 hizo única a propósito —saber quiénes han respondido, en
una sola lectura— pasa a ser unas pocas, acotadas por la lista de sus nadadores. **El
número se escribe en el quickstart**, no se recuerda.

---

## Escenarios de verificación

Contra los emuladores, con las consultas que hace la app:

- Un segundo entrenador no lee nada de la nadadora del primero: ni un registro, ni un
  plan, ni una molestia, ni una petición. Y **no por filtrado**: la consulta se rechaza.
- El primero sí lee a la suya, y esa es la afirmación que mantiene vivo el control
  negativo de la suite (FR-018).
- Con la solicitud esperando, él no lee nada de ella.
- Aceptada, lee también lo que ella escribió antes.
- Terminada la pertenencia, deja de leer en la siguiente consulta.
- Y el control negativo de la suite, corrido otra vez, con sus números nuevos escritos.
