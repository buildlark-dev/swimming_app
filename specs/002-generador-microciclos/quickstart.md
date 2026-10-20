# Guía de Arranque y Validación — Feature 002

Cómo comprobar que el generador hace lo que promete. El entorno es el mismo de la feature 001
y no hace falta instalar nada nuevo: esta feature no añade dependencias.

## Arrancar

```bash
flutter run -d chrome
```

Con emuladores, en dos terminales:

```bash
firebase emulators:start --project demo-natacion
```

```bash
flutter run -d chrome --dart-define=USAR_EMULADORES=true
```

## Ejecutar las pruebas

```bash
flutter test
```

```bash
flutter analyze
```

## Escenarios de validación

Los detalles de precedencia y redondeo están en
[contracts/generacion.md](./contracts/generacion.md); los del texto, en
[contracts/renderizado.md](./contracts/renderizado.md).

### G1 — La semana sale cuadrada

**Es el escenario que justifica la feature.**

1. Generar con: Precompetitivo, estilo objetivo Libre, prueba 100 Libre, fase Acumulación,
   componente acentuado «técnica de eficiencia», tres días disponibles, piscina 25 m, sesión
   de 90 minutos.
2. Comprobar: **tres sesiones**, cada una de **2.000 m**, microciclo de **6.000 m**.
3. Comprobar la distribución: A1 3.300 · A2 1.375 · A3 600 · AT 300 · Máx 425 m. Agrupada
   en el modelo de tres zonas da **Z1 77,9% · Z2 15,0% · Z3 7,1%**, dentro del envolvente
   piramidal de Acumulación (60-81 / 12-30 / 6-10). *Actualizado en la metodología 3.5.*
4. Comprobar el trabajo técnico: **50%** del volumen, el prescrito para Acumulación.
5. Comprobar el reparto de estilos: Libre entre 80 y 85%, Espalda entre 15 y 20%.

**Falla si** algún total se desvía, aunque sea en 25 m.

### G2 — Pasa la auditoría sin que nadie la toque

1. Abrir la auditoría del microciclo recién generado.
2. Comprobar que los **once criterios** están en verde, o que los que no lo están son
   justificables y no bloqueantes.
3. Comprobar que **ningún criterio bloqueante** está en rojo.

**Es la prueba del principio III en su versión 1.1.0**: lo generado cumple por construcción,
no por casualidad.

### G3 — Determinismo

1. Generar dos veces con exactamente los mismos datos.
2. Comparar los dos microciclos: deben ser idénticos, serie por serie.
3. Cambiar **solo** el componente acentuado y generar de nuevo.
4. Comprobar que el microciclo es distinto y que su nombre refleja el componente nuevo.

### G4 — Las treinta combinaciones

Para cada categoría (cinco), cada fase que su categoría admita, y cada longitud de piscina
(dos), comprobar que el reparto cierra exacto, el volumen cae dentro del rango y ninguna zona
se desvía más que la tolerancia.

Son las treinta combinaciones que se verificaron numéricamente antes de escribir el plan.
Ahora se verifican sobre el código real.

### G5 — El viaje redondo del texto

1. Generar un microciclo.
2. Leer el texto que el editor muestra para cada parte.
3. Comprobar que el analizador, releyendo ese texto, arroja **los mismos metros, las mismas
   zonas y los mismos ejercicios** que el generador calculó.
4. Comprobar que **no queda ningún fragmento pendiente**.

**Si esto falla**, el defecto está en el renderizador o en el analizador, nunca en el plan:
significaría que el entrenador ve una cosa y la auditoría evalúa otra.

### G6 — No genera con datos que faltan

1. Intentar generar sin categoría. Comprobar que nombra el dato y no genera.
2. Intentar generar sin componente acentuado. Igual.
3. Comprobar que los impedimentos se muestran **todos a la vez**, no de uno en uno.

### G7 — No genera con datos que se contradicen

1. Precompetitivo, que pide tres sesiones, con **dos** días disponibles. Debe explicar la
   contradicción entre frecuencia y días, y no generar.
2. Iniciación con una fase ATR declarada. Debe impedirlo y explicar que esa categoría no usa
   ATR.
3. Precompetitivo con sesión de 20 minutos. Debe reportar que 2.000 m no caben en ese tiempo.
4. Tras cada intento fallido, comprobar que **no quedó ningún plan guardado**.

### G8 — La regla de Tecnificación

1. Generar para Tecnificación, dos días disponibles.
2. Comprobar que la primera sesión es de **Pecho** y la segunda de **Mariposa**.
3. Comprobar que no se le asignó fase ATR.

### G9 — Selección de ejercicios por diagnóstico

1. Generar con el diagnóstico «falta de agarre del agua».
2. Comprobar que entre los ejercicios elegidos hay alguno cuyo error corregido corresponde,
   como `VADEO`.
3. Generar con un diagnóstico que la Biblioteca no cubra.
4. Comprobar que el vacío se **reporta** y que no se eligió otro ejercicio en su lugar.
5. Generar **sin** diagnóstico y comprobar que se sigue la progresión técnica estándar sin
   inventar errores.

### G10 — Lesiones: avisan, no modifican

1. Generar declarando una lesión.
2. Comprobar que aparece como **aviso** al entrenador.
3. Comprobar que el plan generado es **el mismo** que sin la lesión declarada.

Es deliberado: la Biblioteca dice qué corrige cada ejercicio, no qué está contraindicado.
Adaptar el plan a una lesión es criterio clínico y el principio IV prohíbe simularlo.

### G11 — Revisar y ajustar

1. Abrir el microciclo generado en el editor.
2. Cambiar una distancia. Comprobar que los metros y la auditoría se recalculan.
3. Comprobar que la serie queda marcada como corregida a mano.
4. Guardar y comprobar que el plan **sigue marcado como de origen automático**.

### G12 — Aprobar lo generado

1. Aprobar un microciclo generado limpio.
2. Comprobar que quedan estampadas la versión de metodología y la fecha, y que conserva la
   marca de origen automático.
3. Editarlo hasta romper un criterio bloqueante e intentar aprobarlo: no debe dejar.

### G13 — Sin conexión

1. Detener los emuladores y desconectar la red.
2. Generar un microciclo. **Debe generar igual.**

El generador no consulta ningún servicio externo. Si esto falla, algo se colgó de la red que
no debía.

### G14 — Contra un microciclo real del entrenador (SC-009)

1. Pedir al entrenador que señale una de sus semanas como patrón, con su categoría y fase.
2. Generar con esos mismos datos.
3. Comparar **rangos, no contenido**: volumen por sesión, distribución de zonas y porcentaje
   técnico deben caer en los mismos márgenes que los suyos.

No se espera que la app reproduzca sus ejercicios: se espera que no se salga de donde él se
mueve. Si el generado queda fuera de sus márgenes habituales, o el generador está mal o la
tolerancia está mal calibrada — y esa segunda posibilidad es la tarea que sigue pendiente
desde la feature 001.

## Orden sugerido

G1 → G2 → G3 (genera, cumple y es reproducible) → G4 → G5 (el reparto y el texto aguantan
todos los casos) → G6 → G7 (no genera lo que no debe) → G8 → G9 → G10 (las reglas
particulares) → G11 → G12 (revisar y aprobar) → G13 → G14 (sin red, y contra la realidad).
