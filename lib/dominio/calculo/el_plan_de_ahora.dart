/// Cuál de los planes entregados a un nadador es **el de ahora**.
///
/// **Esto faltaba, y el síntoma no se parecía a la causa.** El HUB elegía el
/// plan del nadador como *el último de sus asignaciones publicadas*. Hasta la
/// feature 009 eso quería decir «el plan que le entregaron», porque tenía uno.
/// Desde que existen los macrociclos, **cada mesociclo es un plan asignado**,
/// así que «el último» pasó a ser el que la consulta devolviera de último.
///
/// En el recorrido de la 010, en el Pixel 7, le tocó el Mesociclo 3: su Home
/// decía «Hoy no hay sesión» un día que sí tenía, «Sesiones cumplidas: 0 de 6»
/// sobre un macrociclo de 39, y su `Análisis` le enseñaba un historial de
/// sesiones de dentro de tres meses — por lo que **no tenía ninguna sesión
/// sobre la que pedirle feedback a su entrenador**.
///
/// Y lo peor no era que estuviera mal: era que dependía del orden de los
/// identificadores en Firestore, así que estaba mal de forma arbitraria.
///
/// La respuesta, en orden, y cada escalón con su motivo:
///
/// 1. **El que contiene hoy.** Es en el que está entrenando. Si dos lo
///    contienen, el que empezó más tarde.
/// 2. **El siguiente que empieza.** En un hueco entre bloques, lo que le toca
///    mirar es lo que viene.
/// 3. **El último que terminó.** Cuando ya acabó todo, lo último que hizo.
/// 4. **El último de la lista**, que es lo que había antes. Un plan de la
///    feature 003 puede no llevar fechas de bloque, y aquí no se adivinan.
///
/// `ProgresoEnElMacrociclo.mesocicloActual` responde lo mismo un nivel más
/// arriba, con los mesociclos de un macrociclo delante. Esta trabaja sobre la
/// lista plana de lo que se le entregó, que es lo que el HUB tiene.
///
/// Dominio puro: ni Flutter ni Firebase (principio II).
library;

import 'package:natacion_app/dominio/entidades/plan.dart';

DateTime _soloLaFecha(DateTime momento) =>
    DateTime(momento.year, momento.month, momento.day);

/// El plan en el que el nadador está ahora, de entre los que se le entregaron.
///
/// Recibe los candidatos ya filtrados —publicados y suyos—, porque quién puede
/// leer qué es una pregunta de otra capa.
Plan? elPlanDeAhora(List<Plan> candidatos, DateTime hoy) {
  if (candidatos.isEmpty) return null;

  final dia = _soloLaFecha(hoy);

  // 1. El que contiene hoy. **Por fecha entera y no por instante**: con
  //    instantes, el bloque que empieza hoy «todavía no habría empezado» para
  //    quien abre la app por la mañana, y la respuesta dependería de la hora.
  Plan? contieneHoy;
  for (final plan in candidatos) {
    final desde = plan.fechaInicio;
    final hasta = plan.fechaFin;
    if (desde == null || hasta == null) continue;

    if (dia.isBefore(_soloLaFecha(desde)) || dia.isAfter(_soloLaFecha(hasta))) {
      continue;
    }

    // Si dos lo contienen, el que empezó más tarde: es el que está trabajando.
    if (contieneHoy == null ||
        _soloLaFecha(desde).isAfter(_soloLaFecha(contieneHoy.fechaInicio!))) {
      contieneHoy = plan;
    }
  }
  if (contieneHoy != null) return contieneHoy;

  // 2. El siguiente que empieza.
  Plan? proximo;
  for (final plan in candidatos) {
    final desde = plan.fechaInicio;
    if (desde == null || !_soloLaFecha(desde).isAfter(dia)) continue;

    if (proximo == null ||
        _soloLaFecha(desde).isBefore(_soloLaFecha(proximo.fechaInicio!))) {
      proximo = plan;
    }
  }
  if (proximo != null) return proximo;

  // 3. El último que terminó.
  Plan? ultimoTerminado;
  for (final plan in candidatos) {
    final hasta = plan.fechaFin;
    if (hasta == null || !_soloLaFecha(hasta).isBefore(dia)) continue;

    if (ultimoTerminado == null ||
        _soloLaFecha(hasta).isAfter(_soloLaFecha(ultimoTerminado.fechaFin!))) {
      ultimoTerminado = plan;
    }
  }
  if (ultimoTerminado != null) return ultimoTerminado;

  // 4. Sin fechas que mirar, lo que había antes.
  return candidatos.last;
}
