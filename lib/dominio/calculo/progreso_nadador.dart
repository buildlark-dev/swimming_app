/// Progreso del nadador: historial de sesiones y adherencia.
///
/// El entrenador eligió el alcance al aclarar la especificación: historial más
/// adherencia **como recuento**, sin gráficas (FR-005a, FR-005b, FR-005c).
///
/// **La adherencia cuenta sesiones. Punto.** No pondera por metros, no pondera
/// por RPE y no se combina con nada. El principio VIII prohíbe combinar carga
/// externa e interna en un mismo indicador, y una adherencia que incorporara
/// intensidad sería exactamente ese indicador.
///
/// Es un indicador deliberadamente aburrido. Hay una prueba que lo fija: el
/// recuento no cambia al variar el RPE ni los metros (SC-011). Parece trivial y
/// no lo es — impide que alguien lo «mejore» más adelante sin notar que está
/// rompiendo un principio.
library;

import 'package:natacion_app/dominio/entidades/plan.dart';
import 'package:natacion_app/dominio/entidades/registro_sesion.dart';
import 'package:natacion_app/dominio/entidades/sesion.dart';

/// Una sesión con la respuesta del nadador, si la hubo.
///
/// La carga externa (la sesión) y la interna (el registro) viajan juntas pero
/// **separadas**: son dos campos, no un resumen de los dos.
class SesionConRegistro {
  const SesionConRegistro({required this.sesion, this.registro});

  /// Carga externa: lo que el entrenador programó.
  final Sesion sesion;

  /// Carga interna: lo que el nadador respondió. Nulo si no respondió.
  final RegistroDeSesion? registro;

  bool get tieneRespuesta => registro != null;

  bool get realizada => registro?.realizada ?? false;

  bool get tieneMolestia => registro?.tieneMolestia ?? false;
}

/// Cuántas de las programadas se completaron.
class Adherencia {
  const Adherencia({required this.realizadas, required this.programadas});

  final int realizadas;
  final int programadas;

  /// Porcentaje, para mostrar. Cero si no hay nada programado.
  double get porcentaje =>
      programadas == 0 ? 0 : (realizadas * 100) / programadas;

  /// Como el entrenador lo lee: «4 de 6».
  String get descripcion => '$realizadas de $programadas';

  @override
  bool operator ==(Object other) =>
      other is Adherencia &&
      other.realizadas == realizadas &&
      other.programadas == programadas;

  @override
  int get hashCode => Object.hash(realizadas, programadas);

  @override
  String toString() => descripcion;
}

class ProgresoDelNadador {
  ProgresoDelNadador({
    required this.plan,
    required List<RegistroDeSesion> registros,
  }) : _porSesion = {for (final r in registros) r.sesionId: r};

  final Plan plan;
  final Map<String, RegistroDeSesion> _porSesion;

  /// Las sesiones con su respuesta, **de la más reciente a la más antigua**
  /// (FR-005a).
  List<SesionConRegistro> get historial {
    final lista = [
      for (final sesion in plan.sesiones)
        SesionConRegistro(sesion: sesion, registro: _porSesion[sesion.id]),
    ];

    lista.sort((a, b) => _fechaDe(b).compareTo(_fechaDe(a)));
    return lista;
  }

  /// Adherencia del plan completo.
  Adherencia get adherenciaDelPlan => Adherencia(
    realizadas: plan.sesiones.where(_fueRealizada).length,
    programadas: plan.sesiones.length,
  );

  /// Adherencia por microciclo, que es la semana del entrenador.
  Map<String, Adherencia> get adherenciaPorSemana {
    final porMicrociclo = <String, Adherencia>{};

    for (final microciclo in plan.microciclos) {
      final sesiones = plan.sesionesDe(microciclo.id);
      porMicrociclo[microciclo.id] = Adherencia(
        realizadas: sesiones.where(_fueRealizada).length,
        programadas: sesiones.length,
      );
    }

    return porMicrociclo;
  }

  /// Las sesiones donde el nadador reportó una molestia.
  ///
  /// Es lo que permite al entrenador encontrarlas **sin leer todas las
  /// observaciones de todas las sesiones** (SC-006).
  List<SesionConRegistro> get conMolestia =>
      historial.where((s) => s.tieneMolestia).toList();

  bool _fueRealizada(Sesion sesion) =>
      _porSesion[sesion.id]?.realizada ?? false;

  /// Fecha por la que se ordena el historial: la prevista de la sesión, y si no
  /// la tiene, la del registro.
  DateTime _fechaDe(SesionConRegistro entrada) =>
      entrada.sesion.fecha ??
      entrada.registro?.registradoEn ??
      DateTime.fromMillisecondsSinceEpoch(0);
}
