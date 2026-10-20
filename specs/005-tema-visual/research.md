# Fase 0 — Decisiones técnicas

**Feature**: tema visual y sistema de componentes
**Plan**: [plan.md](plan.md) · **Especificación**: [spec.md](spec.md)

Cinco decisiones. La primera es la que sostiene la feature; las otras cuatro resuelven
exigencias concretas de la especificación.

---

## D1 — La regla «ningún color escrito a mano» se hace cumplir con una prueba

**Decisión**: `lib/ui/tema/paleta.dart` es el **único archivo del proyecto** autorizado a
contener un literal de color. Una prueba recorre `lib/` y falla si encuentra otro.

**Por qué**: hoy esa propiedad ya es cierta —las veintiuna pantallas no tienen ni un color
literal— y **es puro accidente afortunado**. Nada la protege. La siguiente pantalla que
alguien escriba con prisa la rompe, y nadie se entera hasta que la app se ve mal en oscuro.

`flutter analyze` no puede ayudar: no existe un lint de «este widget usa `Color(0xFF...)`
en lugar del tema», y escribir uno propio sería una dependencia y una pieza de
infraestructura para un problema que una prueba de treinta líneas resuelve.

Hay precedente directo en este proyecto: la frontera del dominio del principio II se vigila
exactamente así, leyendo el código fuente, desde la feature 001. Funciona, y ya cazó un
`firebase_auth` que se había colado en `main.dart` en la feature 004.

**Qué detecta**: `Color(0x...)`, `Colors.loQueSea`, y tamaños de letra y espaciados
literales fuera de sus archivos.

**Lo que esta decisión admite**: una prueba que lee texto no entiende Dart. Alguien
determinado puede esquivarla construyendo un color de otra forma. No es un cerrojo contra
un adversario, es una red contra el descuido — que es lo que de verdad pasa.

**Alternativa descartada**: confiar en la revisión del PR. Es lo que ya hacíamos, y el
único motivo de que la propiedad siga siendo cierta es que nadie ha escrito una pantalla con
prisa todavía.

---

## D2 — La tipografía no se descarga: se usa la del sistema

**Decisión**: la escala tipográfica se construye sobre la fuente del sistema. **No se añade
`google_fonts` ni se empaqueta un tipo propio.**

**Por qué, y es dirimente**: `google_fonts` **descarga las fuentes en tiempo de ejecución**
la primera vez. Esta app promete que leer el plan **nunca requiere red**. Una app que
necesita internet para mostrar bien su texto a pie de piscina contradice la restricción que
la feature 003 existe para cumplir.

Empaquetar un tipo propio sí funcionaría sin red, pero añade peso al descargable por una
razón estética, y el principio VII pide un problema concreto antes de añadir nada.

**Lo que esto cuesta**: la app se verá con Roboto en Android y con San Francisco en iOS, así
que no será idéntica en los dos. Es un coste aceptable: lo que la especificación exige es
que **se lea**, no que sea idéntica.

**La exigencia que sí hay que comprobar (FR-008)**: `4x100 / 1'40"` es una instrucción de
entrenamiento, y leer mal una cifra cambia lo que el nadador hace. Las dos fuentes del
sistema distinguen bien cifras y signos; lo que la tarea hará es **fijar tabulación de
cifras** donde se muestran series, para que las columnas no bailen.

---

## D3 — Claro y oscuro siguen al sistema, sin ajuste propio

**Decisión**: se entregan `theme` y `darkTheme`, y el modo lo decide el sistema operativo.
No hay preferencia guardada ni interruptor.

**Por qué**: un interruptor propio exige una pantalla de ajustes y un sitio donde guardar la
preferencia. La pantalla de Ajustes es la **feature 007**, y construirla aquí sería hacer
algo que esa feature va a rehacer.

Seguir al sistema es además lo que la mayoría espera sin pedirlo.

**Consecuencia buena**: esta feature **no persiste nada**. No toca el almacenamiento local
ni Firestore, así que no puede romper nada de la 003 ni de la 004.

---

## D4 — La escala de zonas varía en claridad, no solo en tono

**Decisión**: las siete zonas se distinguen por una rampa de **claridad** creciente que
sigue el orden de intensidad de la sección 9, y cada una lleva además **su etiqueta**, que
ya existe.

**Por qué**: FR-015 exige que el color nunca sea la única señal, y SC-006 pide que las siete
se distingan **en escala de grises**. Una rampa que solo cambia de tono —azul, verde,
amarillo, naranja, rojo— se convierte en siete grises casi iguales para quien no distingue
colores, y son más o menos el 8% de los hombres. Entre un grupo de nadadores, es cuestión de
tiempo.

Variando la claridad, la escala sobrevive al gris **y** al daltonismo, y además el orden
visual coincide con el orden de intensidad sin que haya que aprendérselo: más intenso, más
oscuro.

**La restricción que esto impone**: cada paso de la rampa tiene que seguir cumpliendo el
contraste con el texto que lleve encima, en los dos modos. Es lo que la prueba de contraste
comprueba zona por zona, no de media.

**Alternativa descartada**: una rampa por tono, que es lo que se hace por costumbre. Se
descarta por lo de arriba.

---

## D5 — Cuatro tonos de aviso, porque hoy hay uno

**Decisión**: el sistema define **informativo, éxito, cuidado y error**, y los avisos
repetidos de las pantallas se sustituyen por un componente que recibe cuál es.

**Por qué**: de los cincuenta usos de color semántico que hay hoy, **veintisiete son el de
error**. La app pinta de rojo:

- «Guardado el progreso, se enviará cuando tengas acceso a internet» — que es **una buena
  noticia**: significa que el mecanismo funcionó.
- «Modo local, sin servidor» — que es una advertencia.
- Los avisos de auditoría — que son información para decidir.

Un rojo que sale siempre deja de significar nada, y cuando aparezca uno de verdad nadie lo
mirará.

**El caso que decide el diseño**: el reporte de molestia. Tiene que **encontrarse sin leer
todas las observaciones** (SC-006 de la feature 003) y a la vez **no parecer una alarma
médica**, porque el principio IV prohíbe que la app diagnostique o sugiera conducta. Va con
el tono de cuidado y una marca propia, no con el de error.

---

## Lo que esta fase deja resuelto, y lo que no

**Resuelto**: dónde viven los colores y cómo se impide que se escapen, qué se hace con la
tipografía, cómo se eligen claro y oscuro, cómo se construye la escala de zonas y cuántos
tonos de aviso hacen falta.

**No resuelto aquí, a propósito**:

- **Los valores concretos de la paleta.** Son una decisión del entrenador sobre su propia
  identidad, no una decisión técnica. El plan fija las restricciones —azules marinos,
  contraste comprobado, rampa por claridad— y la tarea propone valores que él aprueba.
- **Iconografía y logotipo**, fuera de alcance.
- **El ajuste manual de claro/oscuro**, que es de la feature 007.

---

## D6 — Inventario de partida (tarea T002)

Medido sobre `lib/` antes de tocar nada, el 2026-10-20. Es la lista contra la que se
comprueba al final que **ninguna pantalla cambió de significado** (garantía V13).

### Uso del esquema de color, por rol

| Rol | Usos |
|---|---|
| `error` | 16 |
| `onErrorContainer` | 13 |
| `errorContainer` | 5 |
| `onSurfaceVariant` | 5 |
| `primary` | 4 |
| `outline` | 4 |
| `surfaceContainerHighest` | 2 |
| `secondaryContainer` | 2 |
| `onSecondaryContainer` | 2 |
| `tertiary` | 1 |

**Treinta y cuatro de cincuenta y cuatro usos son de la familia de error.** No es que la app
falle mucho: es que no tiene otra forma de decir «mira esto».

### Dónde está el rojo

| Usos | Archivo | Qué dice de verdad |
|---|---|---|
| 6 | `ui/planes/respuestas_del_nadador.dart` | Incluye el **reporte de molestia** → cuidado, nunca error (V11) |
| 6 | `ui/generacion/panel_impedimentos.dart` | Impedimentos para generar → cuidado |
| 4 | `ui/planes/panel_distribucion.dart` | Desviaciones de la distribución → cuidado |
| 3 | `ui/planes/pantalla_plan.dart` | Avisos de auditoría → cuidado |
| 3 | `ui/nadadores/pantalla_perfiles.dart` | Perfil incompleto → informativo |
| 3 | `main.dart` | **Modo local** → cuidado |
| 2 | `ui/planes/dialogo_aprobacion.dart` | Lo que impide aprobar → cuidado |
| 2 | `ui/nadador/pantalla_mi_progreso.dart` | Molestias en el historial → cuidado |
| 1 | `ui/editor/panel_avisos.dart` | Avisos del editor → cuidado |
| 1 | `ui/consentimiento/pantalla_confirmacion.dart` | Error de confirmación → **error de verdad** |
| 1 | `ui/consentimiento/panel_estado.dart` | Sin consentimiento → informativo |
| 1 | `ui/acceso/pantalla_acceso.dart` | Fallo al entrar → **error de verdad** |
| 1 | `ui/planes/tabla_auditoria.dart` | Criterio incumplido → cuidado |

**Solo dos de los trece son errores de verdad.** Los demás son cuidado o información, y de
ahí sale FR-016.

### Lo que falta y no aparece aquí

`ui/nadador/aviso_sincronizacion.dart` **no usa el color de error**. El aviso de «guardado,
se enviará cuando tengas internet» ya es neutro, así que lo que la tarea T028 hace con él no
es quitarle el rojo sino **darle el tono de éxito**, que es lo que de verdad significa.
