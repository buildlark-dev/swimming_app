# Verificación de extremo a extremo — Feature 003

**Feature**: el nadador consume su plan
**Contratos**: [sincronizacion.md](contracts/sincronizacion.md) · [registro_del_nadador.md](contracts/registro_del_nadador.md)

Escenarios que prueban que la feature funciona. Los numerados **C** son los que no pueden
fallar: si uno de ellos falla, la feature no está hecha, por verdes que estén las pruebas.

## Preparación

```bash
flutter pub get
```

```bash
firebase emulators:start --project demo-natacion
```

```bash
flutter run -d chrome --dart-define=USAR_EMULADORES=true
```

Hace falta un plan **publicado** y asignado a un perfil de prueba. Se consigue generando un
microciclo con la feature 002, aprobándolo y publicándolo.

> **Ningún nadador real participa en esta verificación.** Perfiles de prueba o el entrenador
> como nadador, hasta que exista la feature 004.

---

## C1 — La sesión del día, sin señal

**Es el escenario que justifica la feature.**

1. Con red, abrir la app como el nadador y ver su plan al menos una vez.
2. **Poner el dispositivo en modo avión.**
3. Cerrar la app por completo y volver a abrirla.
4. Comprobar que aparece la sesión de hoy con su objetivo técnico, su objetivo fisiológico
   y las series de las tres partes.

**Falla si** aparece un indicador de carga que no termina, un mensaje de error, o una
pantalla vacía.

---

## C2 — Anotar sin conexión, y que llegue

1. En modo avión, marcar la sesión como realizada.
2. Anotar un RPE de 7 y escribir una observación.
3. Comprobar el aviso: **«Guardado el progreso, se enviará cuando tengas acceso a
   internet»**.
4. **Cerrar la app.** Volver a abrirla, todavía sin red: el aviso sigue ahí.
5. Restablecer la red y esperar sin tocar nada.
6. Comprobar que el aviso desaparece y que el registro está en el servidor.

**Falla si** el nadador tiene que pulsar algo para que se envíe, o si al cerrar la app se
pierde lo escrito.

---

## C3 — El entrenador lo lee donde tiene que leerlo

1. Como entrenador, abrir el plan.
2. Comprobar que sobre la sesión correspondiente aparece lo que el nadador respondió.
3. Comprobar que se distingue **sin ambigüedad** qué programó él y qué respondió el nadador.

**Falla si** hay que ir a otra pantalla a buscarlo, o si en algún sitio aparece un número
que mezcle metros con RPE.

---

## C4 — El plan no se mueve

1. Exportar el plan aprobado y guardar el resultado.
2. Registrar respuestas de nadador sobre tres de sus sesiones.
3. Exportar otra vez y **comparar los dos archivos**.

**Falla si** difieren en un solo byte, salvo la marca de exportación.

---

## C5 — La molestia se ve

1. Registrar en una sesión un reporte de dolor en el hombro.
2. Como entrenador, localizarlo **sin abrir las sesiones una por una**.
3. Comprobar que la app no sugirió nada, no cambió el plan y no ocultó la sesión siguiente.

**Falla si** el reporte está mezclado con las observaciones generales, o si la app propuso
cualquier conducta.

---

## C6 — Reenviar no duplica

1. Con las herramientas del emulador, forzar que el envío de un registro falle tres veces.
2. Dejar que termine por funcionar.
3. Contar los documentos de ese registro en el destino.

**Falla si** hay más de uno.

---

## C7 — Quien no anota, no se bloquea

1. Recorrer todo lo que el nadador puede ver **sin registrar absolutamente nada**.
2. Comprobar que ve su plan, su sesión del día y su progreso.

**Falla si** en algún punto la app exige anotar para seguir.

---

## V8 — Adherencia

1. Con un plan de seis sesiones, marcar cuatro como realizadas.
2. Comprobar que la adherencia dice **4 de 6**, por semana y en el plan.
3. **Cambiar el RPE** de las cuatro, de 3 a 9.
4. Comprobar que la adherencia **sigue diciendo 4 de 6**.

**Falla si** el recuento cambia: estaría mezclando carga externa con interna, que es lo que
el principio VIII prohíbe.

---

## V9 — Las fechas no se fuerzan

1. Marcar como realizada una sesión programada para **otro día**.
2. Comprobar que se acepta, y que el entrenador ve tanto la fecha prevista de la sesión como
   la de registro.

**Falla si** la app lo impide o si machaca una fecha con la otra.

---

## V10 — Las versiones no se confunden

1. Registrar una respuesta sobre una sesión.
2. Como entrenador, crear una versión nueva del plan y publicarla.
3. Comprobar que el registro **sigue apuntando a la versión bajo la que el nadador entrenó**.

**Falla si** el registro parece referirse a series que el nadador nunca hizo.

---

## V11 — Las reglas deniegan

```bash
npm --prefix firebase test
```

Con sus casos negativos: sin rol no se lee ni se escribe en la colección de registros.

---

## V12 — Descarga

1. Descargar el plan como nadador.
2. Comprobar que el archivo se lee sin la app y que su contenido coincide con la pantalla.

---

## Puertas de calidad

En este orden, antes de cerrar la feature:

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

Y la verificación manual de **C1 y C2 en un dispositivo real con el modo avión puesto**. El
emulador de red no es lo mismo que una piscina.
