/// Ejercicio de la Biblioteca Oficial.
///
/// Fuente normativa: sección 19 de `docs/metodologia/PROMPT_MAESTRO_V3.4.md`.
/// Es la **única** fuente válida de ejercicios (regla R2, no invención).
library;

import 'package:natacion_app/dominio/metodologia/estilos.dart';

class Ejercicio {
  const Ejercicio({
    required this.nombre,
    required this.nombreBase,
    required this.estilo,
    required this.descripcion,
    required this.errorQueCorrige,
    required this.requiereDesambiguacion,
  });

  /// Nombre exacto como aparece en la sección 19, con el estilo entre
  /// paréntesis cuando el documento lo incluye: `FLECHA (Espalda)`.
  final String nombre;

  /// Nombre sin el estilo entre paréntesis. Es lo que el entrenador teclea.
  final String nombreBase;

  final Estilo estilo;
  final String descripcion;

  /// Error o objetivo técnico que corrige. Permite elegir el ejercicio a
  /// partir del diagnóstico en lugar de a partir del catálogo (sección 15).
  final String errorQueCorrige;

  /// Verdadero cuando el mismo nombre base existe en más de un estilo. En ese
  /// caso usarlo sin indicar el estilo es ambiguo y no se acepta.
  final bool requiereDesambiguacion;

  /// Forma con la que debe escribirse en un plan.
  String get nombreParaPlan =>
      requiereDesambiguacion ? '$nombreBase (${estilo.nombre})' : nombreBase;

  factory Ejercicio.desdeJson(Map<String, dynamic> json) {
    final nombre = json['nombre'] as String;
    return Ejercicio(
      nombre: nombre,
      nombreBase: (json['nombreBase'] as String?) ?? nombre,
      estilo:
          Estilo.porNombre(json['estilo'] as String? ?? '') ?? Estilo.general,
      descripcion: json['descripcion'] as String? ?? '',
      errorQueCorrige: json['errorQueCorrige'] as String? ?? '',
      requiereDesambiguacion: json['requiereDesambiguacion'] as bool? ?? false,
    );
  }

  @override
  String toString() => nombreParaPlan;
}
