/// Sesión de entrenamiento.
///
/// Fuente normativa: sección 14 de `docs/metodologia/PROMPT_MAESTRO_V3.4.md`.
/// Toda sesión tiene objetivo técnico, objetivo fisiológico y tres partes.
library;

import 'package:natacion_app/dominio/entidades/parte.dart';
import 'package:natacion_app/dominio/entidades/serie.dart';
import 'package:natacion_app/dominio/metodologia/estilos.dart';

/// Razón por la que una sesión no puede darse por completa.
class FaltaEnSesion {
  const FaltaEnSesion(this.campo, this.descripcion);

  final String campo;
  final String descripcion;

  @override
  String toString() => descripcion;
}

class Sesion {
  Sesion({
    this.id,
    this.microcicloId,
    this.fecha,
    this.objetivoTecnico = '',
    this.objetivoFisiologico = '',
    this.rpePrevisto,
    this.variablesMonitoreo = const <String>[],
    List<Parte>? partes,
  }) : partes =
           partes ??
           const [
             Parte(tipo: TipoParte.inicial),
             Parte(tipo: TipoParte.central),
             Parte(tipo: TipoParte.cierre),
           ];

  final String? id;
  final String? microcicloId;
  final DateTime? fecha;

  /// Obligatorio para dar la sesión por completa (sección 14).
  final String objetivoTecnico;

  /// Obligatorio para dar la sesión por completa (sección 14).
  final String objetivoFisiologico;

  /// Escala de Borg, de 0 a 10. Control de carga interna (sección 9).
  final int? rpePrevisto;

  /// Cuenta de brazadas, splits parejos, técnica bajo fatiga.
  final List<String> variablesMonitoreo;

  final List<Parte> partes;

  Parte parteDe(TipoParte tipo) =>
      partes.firstWhere((parte) => parte.tipo == tipo);

  /// Metros totales: suma de las tres partes.
  int get metros => partes.fold(0, (total, parte) => total + parte.metros);

  int get metrosTecnicos =>
      partes.fold(0, (total, parte) => total + parte.metrosTecnicos);

  /// Porcentaje de trabajo técnico sobre el volumen total de la sesión.
  double get porcentajeTecnico =>
      metros == 0 ? 0 : (metrosTecnicos * 100) / metros;

  List<Serie> get todasLasSeries =>
      partes.expand((parte) => parte.series).toList();

  List<FragmentoPendiente> get todosLosPendientes =>
      partes.expand((parte) => parte.fragmentosPendientes).toList();

  /// Porcentaje real que representa una parte sobre el total de la sesión.
  double porcentajeDe(TipoParte tipo) =>
      metros == 0 ? 0 : (parteDe(tipo).metros * 100) / metros;

  /// Qué impide dar la sesión por completa. Lista vacía significa completa.
  List<FaltaEnSesion> get faltas {
    final faltas = <FaltaEnSesion>[];

    if (objetivoTecnico.trim().isEmpty) {
      faltas.add(
        const FaltaEnSesion(
          'objetivoTecnico',
          'Falta el objetivo técnico de la sesión',
        ),
      );
    }
    if (objetivoFisiologico.trim().isEmpty) {
      faltas.add(
        const FaltaEnSesion(
          'objetivoFisiologico',
          'Falta el objetivo fisiológico de la sesión',
        ),
      );
    }
    if (partes.length != 3) {
      faltas.add(
        FaltaEnSesion(
          'partes',
          'La sesión debe tener tres partes y tiene ${partes.length}',
        ),
      );
    }
    if (metros == 0) {
      faltas.add(const FaltaEnSesion('series', 'La sesión no tiene series'));
    }

    final pendientes = todosLosPendientes;
    if (pendientes.isNotEmpty) {
      faltas.add(
        FaltaEnSesion(
          'pendientes',
          'Quedan ${pendientes.length} fragmentos sin interpretar',
        ),
      );
    }

    return faltas;
  }

  /// Una sesión con fragmentos pendientes nunca está completa (FR-036).
  bool get estaCompleta => faltas.isEmpty;

  Sesion copiarCon({
    String? id,
    String? microcicloId,
    DateTime? fecha,
    String? objetivoTecnico,
    String? objetivoFisiologico,
    int? rpePrevisto,
    List<String>? variablesMonitoreo,
    List<Parte>? partes,
  }) {
    return Sesion(
      id: id ?? this.id,
      microcicloId: microcicloId ?? this.microcicloId,
      fecha: fecha ?? this.fecha,
      objetivoTecnico: objetivoTecnico ?? this.objetivoTecnico,
      objetivoFisiologico: objetivoFisiologico ?? this.objetivoFisiologico,
      rpePrevisto: rpePrevisto ?? this.rpePrevisto,
      variablesMonitoreo: variablesMonitoreo ?? this.variablesMonitoreo,
      partes: partes ?? this.partes,
    );
  }

  /// Reemplaza una parte conservando el resto de la sesión.
  Sesion conParte(Parte nueva) {
    final actualizadas = partes
        .map((parte) => parte.tipo == nueva.tipo ? nueva : parte)
        .toList();
    return copiarCon(partes: actualizadas);
  }

  @override
  String toString() =>
      'Sesión de $metros m '
      '(${porcentajeTecnico.toStringAsFixed(1)}% técnico)';
}
