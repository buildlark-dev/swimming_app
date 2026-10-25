# Verificación de extremo a extremo — Feature 007

Cómo se comprueba que el HUB funciona. Los casos C1 a C14 se recorren en la app; las puertas de
calidad son comandos; y al final está lo que ninguna máquina puede decir.

Esta feature **mueve pantallas de sitio**. Es la clase de cambio que rompe algo lejano sin que
nadie lo note hasta que un nadador se queda sin su sesión, así que C13 y C14 no son opcionales.

## Preparación

Con el servidor local:

```bash
firebase emulators:start --project swimming-app-ab45f --config firebase/firebase.json
```

Y la app, en otra terminal:

```bash
flutter run -d chrome
```

Hacen falta dos cuentas: la de entrenador y una de nadador. Las dos existen desde la
feature 006; si no, se crean con el alta.

---

## C1 — El nadador aterriza en Home

Entrar con la cuenta de nadador.

**Se espera**: aterriza en `Home`, que está al centro de la barra. Ve cuántas sesiones le han
entregado, cuántas ha cumplido, qué respondió la última vez, y de cuándo son los datos. Lo
primero de la pantalla es su sesión de hoy, con el camino a `Ver Plan`.

## C2 — Su sesión sigue estando a un toque

Desde `Home`, tocar `Ver Plan`.

**Se espera**: la sesión del día, exactamente como la dejó la feature 003. Marcar cumplida,
esfuerzo percibido, observaciones, y el reporte de molestia **en su campo aparte**. Ni un paso
nuevo, ni uno menos.

## C3 — El nadador no ve nada del entrenador

Recorrer los cinco destinos con la cuenta de nadador.

**Se espera**: en ninguno aparece el generador, el editor ni el panel de nadadores. Tampoco
deshabilitados, ni con candado, ni nombrados. La app no le cuenta que existen.

## C4 — El entrenador aterriza en sus números

Entrar con la cuenta de entrenador.

**Se espera**: `Home` con los cuatro números —planes, en uso, esperando aprobación, aprobados
sin asignar— y cada uno diciendo de qué es. Con cero planes, dicen cero y la pantalla dice por
dónde empezar.

## C5 — Generar y editar no cambian de pestaña

En `Generar`, generar un microciclo.

**Se espera**: el plan generado se abre para revisarlo **sin salir de `Generar`**. El editor
calcula los metros igual, la auditoría audita igual.

## C6 — El trabajo a medias sobrevive al cambio de pestaña

Con una sesión a medio editar, irse a `Home`, a `Ajustes`, y volver a `Generar`.

**Se espera**: la sesión está como se dejó. Lo mismo con una búsqueda hecha en `Ver Plan` y con
una respuesta a medio escribir en el recorrido del nadador.

## C7 — Buscar un plan por nadador

En `Ver Plan` como entrenador, con varios planes y varios nadadores, buscar y filtrar.

**Se espera**: encuentra los de ese nadador y puede abrir uno para ajustarlo. El panel de
nadadores está aquí, no en una sexta pestaña.

## C8 — Los destinos que esperan su feature

Tocar `Generar` como nadador y `Análisis` como entrenador.

**Se espera**: una frase que dice qué llegará ahí. **Ni un control pulsable.** Y `Análisis`
como nadador **sí** tiene contenido: su recorrido, el que la 003 entregó como «Mi progreso».

## C9 — Mis datos, y la constancia que no se toca

En `Ajustes`, corregir el apellido. Después abrir los términos aceptados.

**Se espera**: el nombre cambia. La versión aceptada y su fecha **siguen siendo las mismas**, y
el texto que se muestra es el de esa versión, no el vigente. Si la fecha de aceptación cambió a
hoy, está roto el cierre más importante de la feature.

Y en el panel de nadadores del entrenador, el nombre nuevo. No dos nombres en dos pantallas.

## C10 — Los tres derechos

En `Ajustes`, pedir saber qué se guarda, y después llevárselo.

**Se espera**: frases comprensibles, no un volcado técnico. Y un archivo legible fuera de la
app. Dos toques como máximo para llegar a cada uno.

## C11 — La supresión, los dos pasos

Pedir la supresión con una cuenta de prueba —**nunca con una real**—.

**Se espera**: un primer paso que la ofrece y un segundo que la confirma, y el segundo dice qué
se borra y **qué sobrevive**: el registro de que hubo consentimiento, con su fecha. Al
terminar, la app arranca de nuevo y los datos ya no están. El historial de consentimiento sí.

## C12 — La apariencia sobrevive a salir

Poner la app en oscuro, cerrar sesión, y volver a entrar.

**Se espera**: sigue oscura. Si volvió a la del sistema, la preferencia se guardó en el sitio
que `cerrarSesion()` vacía.

## C13 — Nada de las features anteriores cambia

```bash
flutter test
```

**Se espera**: pasan todas. Las únicas modificadas son las pruebas de navegación de
`test/widget_test.dart`, y su número no baja. Cualquier otra que falle significa que el HUB
cambió un comportamiento: se arregla el HUB.

## C14 — Las cinco etiquetas, a 320 px

```bash
flutter test test/ui/hub/
```

Y a ojo, en el navegador, estrechando la ventana a 320 px.

**Se espera**: las cinco se leen completas, sin truncar ni abreviar, en claro y en oscuro. Si
una no cabe, lo que cambia es la barra, no la palabra.

---

## Puertas de calidad

```bash
flutter analyze
```

```bash
flutter test
```

```bash
npm --prefix firebase test
```

```bash
dart run tool/verificar_metodologia.dart
```

Las cuatro en verde antes de cerrar la feature. La tercera incluye las pruebas nuevas de
servidor: qué borra la supresión y qué deja.

## Orden sugerido

1. **C13 primero, antes de tocar nada.** Es la foto de partida: 1283 pruebas en verde.
2. C1 a C8: la barra y los dos recorridos, que es la rebanada usable.
3. C9 a C12: `Ajustes`, que es la parte que pesa.
4. C13 y C14 otra vez al final.

## Lo que ninguna máquina dice

**Si `Home` contesta la pregunta que uno se hace al abrir.** Los números pueden estar bien y la
pantalla no servir de nada. Esto lo mira el entrenador con sus propios datos, y si sobra algo,
sobra.

**Si el nadador echa de menos el toque que perdió.** Hoy abre y está en su sesión; con `Home`
hay un toque en medio. Está declarado en el plan como concesión, pero la última palabra es de
quien la usa a pie de piscina.

**Si los textos de `Ajustes` que hablan de derechos se entienden.** Los escribe el plan y los
valida la revisión legal que sigue pendiente. Que una familia real los lea antes de esa
revisión es lo único que no debería pasar.
