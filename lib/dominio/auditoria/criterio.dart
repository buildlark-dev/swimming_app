/// Criterios de auditoría metodológica.
///
/// Contrato: `specs/001-editor-planes-auditoria/contracts/auditoria.md`.
///
/// La severidad quedó fijada por el entrenador en la sesión de aclaración:
/// bloquean la no invención, la nomenclatura, la notación, las zonas mal
/// asignadas y los datos obligatorios faltantes; admiten justificación escrita
/// el volumen fuera de rango por afinación y las desviaciones de distribución.
library;

import 'package:natacion_app/dominio/entidades/plan.dart';

enum Severidad {
  /// Impide la aprobación. Ninguna justificación lo habilita.
  bloqueante('Bloqueante'),

  /// Admite justificación escrita del entrenador.
  justificable('Justificable');

  const Severidad(this.nombre);

  final String nombre;
}

/// Veredicto de un criterio sobre un plan.
class CriterioEvaluado {
  const CriterioEvaluado({
    required this.id,
    required this.nombre,
    required this.severidad,
    required this.cumple,
    required this.observacion,
    this.ubicacion = '',
  });

  final String id;
  final String nombre;
  final Severidad severidad;
  final bool cumple;

  /// Siempre con números concretos: valor real, esperado y diferencia.
  final String observacion;

  /// Dónde ocurre: sesión, parte o serie.
  final String ubicacion;

  bool get bloqueaAprobacion => !cumple && severidad == Severidad.bloqueante;

  @override
  String toString() =>
      '[$id] $nombre: ${cumple ? 'cumple' : 'NO cumple'} — $observacion';
}

/// Un criterio evaluable.
abstract class Criterio {
  const Criterio();

  String get id;
  String get nombre;
  Severidad get severidad;

  /// Evalúa el plan. Un criterio que no puede evaluarse por falta de datos
  /// **no cumple**, indicando qué falta: nunca se da por cumplido por omisión.
  CriterioEvaluado evaluar(Plan plan);

  CriterioEvaluado cumpliendo(String observacion, {String ubicacion = ''}) =>
      CriterioEvaluado(
        id: id,
        nombre: nombre,
        severidad: severidad,
        cumple: true,
        observacion: observacion,
        ubicacion: ubicacion,
      );

  CriterioEvaluado fallando(String observacion, {String ubicacion = ''}) =>
      CriterioEvaluado(
        id: id,
        nombre: nombre,
        severidad: severidad,
        cumple: false,
        observacion: observacion,
        ubicacion: ubicacion,
      );
}
