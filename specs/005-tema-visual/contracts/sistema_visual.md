# Contrato — el sistema visual

**Feature**: 005 · **Modelo**: [data-model.md](../data-model.md) ·
**Decisiones**: [research.md](../research.md)

Garantías comprobables. Cada una lleva su identificador para que una prueba pueda citarla y
para que, si alguien la rompe, se sepa qué prometimos.

**Lo que este contrato promete por encima de todo**: que esta feature **no cambia lo que
hace ninguna pantalla**. Es lo que la hace segura de fusionar sobre una app desplegada y en
uso.

---

## Un solo sitio

### V1 — `paleta.dart` es el único archivo con literales de color

Ningún otro archivo de `lib/` contiene `Color(0x...)` ni `Colors.loQueSea`.

**Se comprueba**: una prueba recorre `lib/` leyendo el código fuente y falla nombrando el
archivo y la línea infractora.

**Por qué así y no con un lint**: no existe uno que lo diga, y escribirlo sería una
dependencia y una pieza de infraestructura para lo que una prueba resuelve. Hay precedente:
la frontera del dominio del principio II se vigila igual desde la feature 001, y ya cazó un
`firebase_auth` colado en `main.dart`.

**Lo que esta garantía admite**: una prueba que lee texto no entiende Dart. No es un cerrojo
contra alguien determinado; es una red contra el descuido, que es lo que de verdad ocurre.

### V2 — Los tamaños de letra y los espaciados tampoco se escriben a mano

Igual que V1, para `tipografia.dart` y `espaciado.dart`.

**Se comprueba**: la misma prueba, con los patrones correspondientes.

### V3 — Un componente no decide, toma

Los componentes de `lib/ui/componentes/` no contienen valores propios: leen de los tokens.

**Se comprueba**: V1 y V2 los cubren, porque son archivos de `lib/`.

**La consecuencia que importa**: si un componente necesita un valor que no está en los
tokens, **falta un token**. No se añade el valor al componente.

---

## Que se lea

### V4 — Todo el texto cumple el contraste, en los dos modos

Cada par de color de texto y su fondo alcanza la relación mínima que le corresponde por
tamaño, en claro y en oscuro.

**Se comprueba**: una prueba calcula la relación de contraste de cada par declarado y falla
nombrando el par y el valor obtenido. No se opina: se mide.

### V5 — Las siete zonas cumplen el contraste **una por una**

No de media, y no «casi todas».

**Se comprueba**: la prueba recorre las siete.

**Por qué se dice aparte**: una rampa suele cumplir en los extremos y fallar en medio, y un
promedio lo esconde.

### V6 — Toda área pulsable alcanza el tamaño mínimo

Aunque su icono sea más pequeño.

**Se comprueba**: el tema fija los tamaños mínimos de los controles, y una prueba de
interfaz mide las áreas sensibles de las pantallas existentes.

**Por qué**: un dedo mojado, y a veces el de un niño de nueve años.

### V7 — Con el tamaño de letra al 200%, nada se corta

Ninguna pantalla recorta, superpone ni oculta texto.

**Se comprueba**: pruebas de interfaz que abren las pantallas con el factor de escala
forzado y fallan ante un desbordamiento.

**Por qué 200%**: hay personas que lo llevan así siempre, y no es un caso extremo.

---

## El lenguaje del dominio

### V8 — Las siete zonas se distinguen en escala de grises

Convertida la escala a gris, los siete pasos siguen siendo siete valores distintos y
separados.

**Se comprueba**: la prueba calcula la luminancia de cada paso y exige una separación
mínima entre consecutivos.

**Por qué**: alrededor del 8% de los hombres no distingue algunos colores. Entre un grupo de
nadadores, es cuestión de tiempo. Y una rampa por tono se vuelve siete grises casi iguales.

### V9 — El orden visual es el orden de intensidad

El paso de A1 al más intenso avanza en una sola dirección.

**Se comprueba**: la prueba exige que la luminancia sea monótona en el orden de la
metodología.

**Por qué**: enseñar otro orden sería enseñar una ordenación que la metodología no hace.

### V10 — El color nunca es la única señal

Toda distinción —zona, estado de plan, tono de aviso— se reconoce también sin color.

**Se comprueba**: V8 para las zonas; para lo demás, que cada distinción lleve un segundo
canal además del color.

### V11 — Un reporte de molestia no se viste de alarma

Se encuentra sin leer todas las observaciones, y **no usa el tono de error**.

**Se comprueba**: la prueba verifica que el componente que lo muestra usa el tono de
cuidado.

**Por qué**: el principio IV prohíbe que la app diagnostique o proponga conducta. Pintarlo
como una emergencia médica es una forma de opinar.

---

## Los avisos

### V12 — Hay cuatro tonos, y «guardado» no es uno de error

«Guardado el progreso, se enviará cuando tengas acceso a internet» usa el tono de éxito.

**Se comprueba**: la prueba verifica el tono de ese aviso concreto.

**Por qué este caso y no otro**: hoy es rojo. Es **una buena noticia** —significa que la
bandeja de salida de la feature 003 hizo su trabajo— y verla como alarma enseña al nadador
a ignorar el color. Cuando aparezca un rojo de verdad, no lo mirará.

---

## Lo que no se rompe

### V13 — Ninguna pantalla cambia lo que hace

**Se comprueba**: **las pruebas de las features 001 a 004 pasan sin modificarse.**

Es la garantía más importante de este contrato y la única que no tiene prueba propia: la
prueba es que las novecientas noventa y cinco que ya hay sigan pasando tal cual.

Si una tuviera que cambiar para pasar, el tema cambió un comportamiento, y eso es un fallo
de esta feature, no de la prueba.

### V14 — La app abre aunque el tema falle

Si el tema no se pudiera construir, la app arranca con la apariencia por omisión.

**Se comprueba**: igual que se comprobó el arranque sin Firebase en el PR #5 — con un doble
que falla, verificando que la app sigue en pie.

**Por qué**: quedarse sin abrir por un asunto de aspecto no es aceptable. Ya hubo un caso
en este proyecto donde un fallo que debía degradar tumbaba el arranque entero.
