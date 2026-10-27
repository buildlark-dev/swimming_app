/// Qué sesión le toca hoy al nadador.
///
/// FR-002: se muestra la sesión que corresponde a la fecha actual y, cuando no
/// haya, **cuál es la siguiente y cuándo**. Nunca una pantalla vacía: decirle a
/// alguien que llegó a la piscina que no hay nada, sin más, es dejarlo sin saber
/// si descansa hoy o si algo falló.
library;

import 'package:natacion_app/dominio/entidades/plan.dart';
import 'package:natacion_app/dominio/entidades/sesion.dart';

/// Lo que el nadador encuentra al abrir la app.
sealed class QueTocaHoy {
  const QueTocaHoy();
}

/// Hay sesión hoy.
class SesionDeHoy extends QueTocaHoy {
  const SesionDeHoy(this.sesion);

  final Sesion sesion;
}

/// Hoy no, pero la siguiente es esta.
class SinSesionHoy extends QueTocaHoy {
  const SinSesionHoy({required this.siguiente, required this.cuando});

  final Sesion siguiente;
  final DateTime cuando;

  /// Cuántos días faltan, contando desde hoy.
  int diasDesde(DateTime hoy) =>
      _soloFecha(cuando).difference(_soloFecha(hoy)).inDays;
}

/// El plan terminó, o no tiene sesiones con fecha.
class SinSesionesPorDelante extends QueTocaHoy {
  const SinSesionesPorDelante();
}

/// Resuelve qué le toca al nadador en [hoy].
///
/// Las sesiones **sin fecha** no entran: no se puede decir que tocan hoy ni que
/// tocan mañana, y suponerlo sería inventar (regla R3).
QueTocaHoy queTocaHoy(Plan plan, DateTime hoy) {
  final conFecha = plan.sesiones.where((s) => s.fecha != null).toList()
    ..sort((a, b) => a.fecha!.compareTo(b.fecha!));

  if (conFecha.isEmpty) return const SinSesionesPorDelante();

  final dia = _soloFecha(hoy);

  for (final sesion in conFecha) {
    if (_soloFecha(sesion.fecha!) == dia) return SesionDeHoy(sesion);
  }

  for (final sesion in conFecha) {
    if (_soloFecha(sesion.fecha!).isAfter(dia)) {
      return SinSesionHoy(siguiente: sesion, cuando: sesion.fecha!);
    }
  }

  return const SinSesionesPorDelante();
}

/// Descarta la hora: dos sesiones del mismo día son del mismo día aunque una
/// diga las 6:00 y otra las 18:00.
DateTime _soloFecha(DateTime fecha) =>
    DateTime(fecha.year, fecha.month, fecha.day);
