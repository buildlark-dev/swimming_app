/// Lo que devuelve el generador.
///
/// Contrato: `specs/002-generador-microciclos/contracts/generacion.md`.
///
/// **Es una de dos cosas, nunca las dos**: o un microciclo, o los impedimentos
/// que lo hicieron imposible. Nunca un plan a medias.
library;

import 'package:natacion_app/dominio/entidades/plan.dart';
import 'package:natacion_app/dominio/metodologia/estilos.dart';

/// Por qué no se pudo generar.
enum TipoImpedimento {
  datoFaltante('Falta un dato obligatorio'),
  faseNoAdmisible('La categoría no admite fase ATR'),
  frecuenciaImposible('Los días disponibles no alcanzan para la frecuencia'),
  duracionInsuficiente('El volumen no cabe en la duración de sesión'),
  componenteIncoherente('El componente acentuado no encaja con la fase'),
  repartoImposible('No se pudo repartir cumpliendo la metodología');

  const TipoImpedimento(this.descripcion);

  final String descripcion;
}

class Impedimento {
  const Impedimento({
    required this.tipo,
    required this.explicacion,
    this.campo = '',
  });

  final TipoImpedimento tipo;

  /// Con los números concretos de la contradicción.
  final String explicacion;

  /// Qué dato de la petición lo origina, si aplica.
  final String campo;

  @override
  String toString() =>
      '${tipo.descripcion}${campo.isEmpty ? '' : ' ($campo)'}: $explicacion';
}

/// Supuesto que hubo que asumir para poder generar. Se muestra dentro del plan,
/// marcado visiblemente (FR-007).
class Supuesto {
  const Supuesto({required this.descripcion, required this.motivo});

  final String descripcion;
  final String motivo;

  @override
  String toString() => '$descripcion — $motivo';
}

/// Error diagnosticado sin ejercicio en la Biblioteca que lo corrija.
///
/// Se reporta; **no se sustituye** por otro ejercicio (FR-023).
class VacioDeBiblioteca {
  const VacioDeBiblioteca({
    required this.errorDiagnosticado,
    required this.estilo,
  });

  final String errorDiagnosticado;
  final Estilo estilo;

  @override
  String toString() =>
      'No hay ejercicio de ${estilo.nombre} que corrija "$errorDiagnosticado"';
}

/// Resultado de una generación.
sealed class ResultadoGeneracion {
  const ResultadoGeneracion();
}

/// El microciclo se pudo generar.
class MicrocicloGenerado extends ResultadoGeneracion {
  const MicrocicloGenerado({
    required this.plan,
    this.supuestos = const <Supuesto>[],
    this.vaciosDeBiblioteca = const <VacioDeBiblioteca>[],
    this.avisos = const <String>[],
  });

  final Plan plan;
  final List<Supuesto> supuestos;
  final List<VacioDeBiblioteca> vaciosDeBiblioteca;

  /// Lesiones declaradas y cualquier advertencia que no impide generar.
  final List<String> avisos;
}

/// El microciclo no se pudo generar. No queda nada guardado.
class GeneracionImposible extends ResultadoGeneracion {
  const GeneracionImposible(this.impedimentos);

  final List<Impedimento> impedimentos;

  String get resumen => impedimentos.map((i) => i.toString()).join('\n');

  bool tiene(TipoImpedimento tipo) => impedimentos.any((i) => i.tipo == tipo);
}
