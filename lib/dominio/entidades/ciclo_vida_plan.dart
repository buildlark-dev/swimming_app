/// Transiciones de estado del plan.
///
/// Principio IV de la constitución: ningún plan llega a un nadador sin
/// aprobación explícita del entrenador, y un plan aprobado es inmutable.
library;

import 'package:natacion_app/dominio/auditoria/auditoria.dart';
import 'package:natacion_app/dominio/entidades/plan.dart';

/// Resultado de intentar una transición.
sealed class ResultadoTransicion {
  const ResultadoTransicion();
}

class TransicionHecha extends ResultadoTransicion {
  const TransicionHecha(this.plan);

  final Plan plan;
}

class TransicionRechazada extends ResultadoTransicion {
  const TransicionRechazada(this.impedimentos);

  final List<ImpedimentoAprobacion> impedimentos;

  String get resumen => impedimentos.map((i) => i.toString()).join('\n');
}

class CicloVidaPlan {
  CicloVidaPlan({
    required this.auditoria,
    required this.versionMetodologia,
    DateTime Function()? ahora,
  }) : _ahora = ahora ?? DateTime.now;

  final Auditoria auditoria;

  /// Versión leída de `docs/metodologia/metodologia.json`.
  final String versionMetodologia;

  final DateTime Function() _ahora;

  /// Aprueba el plan si la auditoría lo permite.
  ///
  /// Al aprobar estampa la versión de metodología y la fecha (FR-026), y el
  /// plan queda bloqueado contra edición.
  ResultadoTransicion aprobar(Plan plan) {
    final impedimentos = auditoria.impedimentosPara(plan);
    if (impedimentos.isNotEmpty) {
      return TransicionRechazada(impedimentos);
    }

    return TransicionHecha(
      plan.copiarCon(
        estado: EstadoPlan.aprobado,
        versionMetodologia: versionMetodologia,
        fechaAprobacion: _ahora(),
      ),
    );
  }

  /// Publica un plan ya aprobado.
  ResultadoTransicion publicar(Plan plan) {
    if (plan.estado != EstadoPlan.aprobado) {
      return TransicionRechazada([
        ImpedimentoAprobacion(
          'Solo se publica lo aprobado',
          'El plan está en estado ${plan.estado.nombre}',
        ),
      ]);
    }

    return TransicionHecha(plan.copiarCon(estado: EstadoPlan.publicado));
  }

  /// Crea una versión nueva en borrador a partir de un plan aprobado.
  ///
  /// El plan original queda intacto (FR-025). El nuevo apunta al anterior y
  /// pierde el sello de aprobación, porque aún no ha sido aprobado.
  Plan crearVersionDesde(Plan aprobado) {
    return Plan(
      nombre: aprobado.nombre,
      categoria: aprobado.categoria,
      estiloObjetivo: aprobado.estiloObjetivo,
      pruebaObjetivo: aprobado.pruebaObjetivo,
      longitudPiscina: aprobado.longitudPiscina,
      fechaInicio: aprobado.fechaInicio,
      fechaFin: aprobado.fechaFin,
      faseAtr: aprobado.faseAtr,
      microciclos: aprobado.microciclos,
      sesiones: aprobado.sesiones,
      estado: EstadoPlan.borrador,
      // Una versión nueva de un plan generado sigue siendo generada (FR-026).
      origen: aprobado.origen,
      justificaciones: aprobado.justificaciones,
      versionAnteriorId: aprobado.id,
    );
  }
}
