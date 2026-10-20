# Guía de Arranque y Validación — Feature 001

Cómo levantar el entorno, ejecutar las pruebas y comprobar que la feature hace lo que
promete. No contiene código de implementación: eso vive en `tasks.md` y en el código.

## Requisitos

Ya verificados en el equipo del entrenador el 2026-09-25:

| Herramienta | Versión mínima | Detectada |
|---|---|---|
| Flutter | 3.44 | 3.44.2 |
| Dart | 3.12 | 3.12.2 |
| Node | 20 | 22.23.1 |
| Firebase CLI | 14 | 15.29.0 |
| Java | 17 | 21.0.12 |

No hace falta instalar nada más, ni crear un proyecto en la nube: todo corre en local.

## Levantar el entorno

Los emuladores primero, en su propia terminal:

```bash
firebase emulators:start --project demo-natacion
```

`demo-natacion` es un identificador de proyecto ficticio. Los emuladores lo aceptan sin
que exista nada en la nube, y así no hay riesgo de escribir en un proyecto real por
descuido.

Después, la app apuntando a los emuladores:

```bash
flutter run -d chrome --dart-define=USAR_EMULADORES=true
```

## Ejecutar las pruebas

Dominio, interfaz y frontera de arquitectura:

```bash
flutter test
```

Análisis estático, que debe salir limpio según el principio VII:

```bash
flutter analyze
```

Reglas de acceso, con los emuladores levantados:

```bash
npm --prefix firebase test
```

## Escenarios de validación

Cada escenario prueba que una parte de la feature funciona de punta a punta. Los detalles
de los criterios están en [contracts/auditoria.md](./contracts/auditoria.md) y la forma de
los datos en [data-model.md](./data-model.md).

### V1 — El analizador reproduce una sesión conocida

**Por qué importa**: ancla todo el sistema a un resultado que el entrenador ya conoce.

1. Crear una sesión y pegar en sus tres partes el ejemplo de la sección 14 del documento
   normativo (el miércoles 14, de técnica de espalda).
2. Comprobar que la app muestra: inicial 1.800 m, central 1.500 m, final 300 m, total
   **3.600 m**.
3. Comprobar que cada serie aparece desglosada en campos editables y que no queda ningún
   fragmento pendiente.

**Falla si** algún total difiere, aunque sea en 25 m.

### V2 — Un ejercicio inventado no pasa

1. Escribir en una serie un nombre que no está en la Biblioteca.
2. Comprobar que queda marcado como fragmento pendiente con motivo
   `ejercicio_fuera_de_biblioteca`, que la sesión no puede darse por completa, y que la app
   **no sugiere** ningún nombre parecido.
3. Comprobar que se ofrece registrarlo como propuesta pendiente, y que hacerlo no lo
   incorpora al plan.

### V3 — La ambigüedad de estilo se resuelve, no se adivina

1. Escribir `FLECHA` sin indicar estilo.
2. Comprobar que queda pendiente con motivo `ambiguo`.
3. Indicar el estilo y comprobar que se guarda como `FLECHA (Espalda)`.

### V4 — La corrección manual manda

1. Forzar una interpretación equivocada y corregir el campo a mano.
2. Modificar otra parte del texto para que se reinterprete.
3. Comprobar que el campo corregido **no** se sobrescribe y que la serie figura como
   `corregido a mano`.

### V5 — El volumen fuera de rango pide justificación, no bloquea

1. Crear un plan Precompetitivo (rango 1800 – 2200 m) con una sesión de 1.400 m en fase de
   Realización.
2. Intentar aprobar: la app pide justificación de afinación.
3. Intentar aprobar con la justificación vacía: no deja.
4. Escribir la justificación y aprobar: queda guardada junto al plan.

### V6 — El ejercicio ajeno a la biblioteca sí bloquea

1. Dejar en el plan una serie con ejercicio fuera de la Biblioteca.
2. Intentar aprobar, incluso escribiendo una justificación.
3. Comprobar que **no se puede aprobar** y que el mensaje nombra el ejercicio y la sesión.

### V7 — El plan aprobado es inmutable

1. Aprobar un plan limpio.
2. Comprobar que quedan estampadas la versión de metodología y la fecha.
3. Intentar editarlo: la app crea un plan nuevo en borrador con `versionAnteriorId`
   apuntando al aprobado, y el aprobado queda intacto.

### V8 — La categoría sin ATR no admite fase

1. Crear un plan de Iniciación o Tecnificación.
2. Intentar asignarle una fase ATR: la app lo impide y explica por qué.

### V9 — Las reglas de acceso deniegan por defecto

```bash
npm --prefix firebase test
```

Todos los casos negativos deben pasar. Una regla que permite lo que no debería es un fallo
de la misma gravedad que un cálculo equivocado.

### V10 — El plan de referencia cuadra (criterio SC-001)

**Es la prueba de fuego de la feature.**

1. Reconstruir en la app el `Macrociclo - Precompetitivo Agosto`.
2. Comparar contra el documento original: metros por sesión y por microciclo deben coincidir
   con **diferencia de 0 m**.
3. Comparar la distribución de zonas y el porcentaje técnico calculados con los del
   documento.

**Si no cuadra**, antes de tocar el código hay que determinar cuál de las dos fuentes está
equivocada. Es posible que el documento original contenga un error aritmético: en ese caso
el hallazgo es valioso y debe registrarse, no corregirse silenciosamente en la app.

## Frontera del dominio

```bash
flutter test test/dominio/arquitectura_test.dart
```

Falla si algún archivo de `lib/dominio/` importa Flutter o Firebase. Es la comprobación
automática del principio II.

## Orden sugerido de validación

V1 → V2 → V3 → V4 (el analizador funciona) → V5 → V6 → V7 → V8 (la auditoría y la
aprobación funcionan) → V9 (el acceso está cerrado) → V10 (el conjunto reproduce la
realidad del entrenador).
