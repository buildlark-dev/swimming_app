/// Si una sesión se puede marcar como hecha (decisión D6, M24 a M28).
///
/// **La regla es sobre la fecha y no sobre el orden.** Una sesión cuyo día
/// todavía no llegó no se marca, y se explica; una que ya pasó se marca
/// siempre, pase lo que pase con las anteriores.
///
/// Es la decisión del entrenador del 2026-11-04, y el motivo está en la
/// sección 4, paso 8: el reajuste se hace sobre datos de adherencia. Una regla
/// que impidiera a un nadador registrar una sesión que de verdad nadó haría
/// que la app mintiera sobre lo que pasó, y entonces el reajuste modelaría una
/// ficción. Lo que la app hace es **enseñar el hueco**, no negar el hecho.
///
/// Esta función **no sabe nada del orden**, y es a propósito: si lo supiera,
/// alguien podría hacerla depender de él más adelante sin notar que está
/// rompiendo la decisión. Lo que queda pendiente lo calcula
/// `ProgresoEnElMacrociclo` y se muestra; no se hace cumplir.
///
/// Dominio puro: ni Flutter ni Firebase (principio II).
library;

import 'package:natacion_app/dominio/entidades/sesion.dart';

/// La respuesta, con lo que el nadador lee cuando es «no».
sealed class SePuedeMarcar {
  const SePuedeMarcar();

  bool get si => this is Si;

  /// En español y sin jerga. Vacía cuando sí se puede: no hay nada que
  /// explicar.
  String get comoSeLeExplica => switch (this) {
    Si() => '',
    TodaviaNo() => 'Todavía no llega ese día',
    SinFecha() => 'Esta sesión no tiene día asignado',
  };
}

/// Su día es hoy o ya pasó.
class Si extends SePuedeMarcar {
  const Si();
}

/// Su día es posterior a hoy.
class TodaviaNo extends SePuedeMarcar {
  const TodaviaNo();
}

/// No tiene día asignado.
///
/// **No es lo mismo que «todavía no llega»**, y confundirlos deja al nadador
/// esperando un día que no existe. `Sesion.fecha` es nulo de verdad en el
/// dominio, así que este no es un caso defensivo: es un caso.
class SinFecha extends SePuedeMarcar {
  const SinFecha();
}

/// Días enteros, **por fecha y no por horas transcurridas**.
///
/// Sin esto, a las 23:59 la sesión de mañana estaría a dos minutos y se podría
/// marcar, y la de hoy por la noche «ya habría pasado». La frontera dependería
/// de la hora a la que el nadador abriera la app.
DateTime _soloLaFecha(DateTime momento) =>
    DateTime(momento.year, momento.month, momento.day);

/// **Función total**: para cualquier sesión y cualquier día hay respuesta.
SePuedeMarcar puedeMarcarse({required Sesion sesion, required DateTime hoy}) {
  final fecha = sesion.fecha;
  if (fecha == null) return const SinFecha();

  return _soloLaFecha(fecha).isAfter(_soloLaFecha(hoy))
      ? const TodaviaNo()
      : const Si();
}
