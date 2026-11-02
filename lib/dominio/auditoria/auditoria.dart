/// Auditoría metodológica completa y regla de aprobación.
///
/// Contrato: `specs/001-editor-planes-auditoria/contracts/auditoria.md`.
library;

import 'package:natacion_app/dominio/auditoria/criterio.dart';
import 'package:natacion_app/dominio/auditoria/criterios.dart';
import 'package:natacion_app/dominio/auditoria/tolerancia.dart';
import 'package:natacion_app/dominio/entidades/plan.dart';

/// Resultado de evaluar los once criterios sobre un plan.
class ResultadoAuditoria {
  const ResultadoAuditoria(this.criterios);

  final List<CriterioEvaluado> criterios;

  List<CriterioEvaluado> get bloqueantesEnRojo =>
      criterios.where((c) => c.bloqueaAprobacion).toList();

  List<CriterioEvaluado> get justificablesEnRojo => criterios
      .where((c) => !c.cumple && c.severidad == Severidad.justificable)
      .toList();

  List<CriterioEvaluado> get enRojo =>
      criterios.where((c) => !c.cumple).toList();

  bool get apruebaSinBloqueos => bloqueantesEnRojo.isEmpty;

  bool get todoEnVerde => enRojo.isEmpty;

  CriterioEvaluado? porId(String id) {
    for (final criterio in criterios) {
      if (criterio.id == id) return criterio;
    }
    return null;
  }
}

/// Por qué un plan no se puede aprobar.
class ImpedimentoAprobacion {
  const ImpedimentoAprobacion(this.motivo, this.detalle);

  final String motivo;
  final String detalle;

  @override
  String toString() => '$motivo: $detalle';
}

class Auditoria {
  Auditoria({
    Tolerancia tolerancia = Tolerancia.predeterminada,
    List<String> diagnostico = const <String>[],
  }) : criterios = <Criterio>[
         // Bloqueantes.
         const CriterioBiblioteca(),
         const CriterioNomenclatura(),
         const CriterioZonas(),
         const CriterioSinAmbiguos(),
         // Justificables.
         CriterioTecnicaPrioritaria(tolerancia: tolerancia),
         CriterioIntensidadesFase(tolerancia: tolerancia),
         CriterioTecnicaFase(tolerancia: tolerancia),
         const CriterioVolumenCategoria(),
         CriterioTransferencia(tolerancia: tolerancia),
         const CriterioModelamiento(),
         CriterioDrillsDiagnostico(diagnostico: diagnostico),
       ];

  final List<Criterio> criterios;

  /// Evalúa los once criterios. Siempre devuelve los once, cumplan o no.
  ResultadoAuditoria evaluar(Plan plan) {
    return ResultadoAuditoria(
      criterios.map((criterio) => criterio.evaluar(plan)).toList(),
    );
  }

  /// Qué impide aprobar el plan. Lista vacía significa que se puede aprobar.
  ///
  /// Regla (FR-022, FR-023):
  ///   - ningún criterio bloqueante en rojo;
  ///   - todo criterio justificable en rojo con justificación no vacía;
  ///   - ninguna sesión incompleta.
  List<ImpedimentoAprobacion> impedimentosPara(Plan plan) {
    final impedimentos = <ImpedimentoAprobacion>[];
    final resultado = evaluar(plan);

    for (final criterio in resultado.bloqueantesEnRojo) {
      impedimentos.add(
        ImpedimentoAprobacion(
          'Incumplimiento no negociable (${criterio.nombre})',
          criterio.observacion,
        ),
      );
    }

    for (final criterio in resultado.justificablesEnRojo) {
      final justificacion = plan.justificacionDe(criterio.id);
      if (justificacion == null || !justificacion.esValida) {
        impedimentos.add(
          ImpedimentoAprobacion(
            'Falta justificación escrita (${criterio.nombre})',
            criterio.observacion,
          ),
        );
      }
    }

    final incompletas = plan.sesionesIncompletas;
    if (incompletas.isNotEmpty) {
      impedimentos.add(
        ImpedimentoAprobacion(
          'Sesiones incompletas',
          '${incompletas.length} de ${plan.sesiones.length} sesiones no están '
              'completas',
        ),
      );
    }

    if (plan.estado.esInmutable) {
      impedimentos.add(
        ImpedimentoAprobacion(
          'El plan ya no es un borrador',
          'Está en estado ${plan.estado.nombre}. Editarlo crea una versión nueva',
        ),
      );
    }

    return impedimentos;
  }

  bool puedeAprobarse(Plan plan) => impedimentosPara(plan).isEmpty;
}
