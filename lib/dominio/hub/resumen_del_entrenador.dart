/// Los cuatro números del entrenador.
///
/// Son cuentas, no juicios: «cuántos planes esperan aprobación» no dice si
/// están bien, y **ninguno de estos números mueve un plan de estado** (H18).
/// Firmar sigue siendo un acto suyo en la pantalla del plan, que es lo que el
/// principio IV no delega.
///
/// Las definiciones están en `data-model.md` y son literales. La que más se
/// presta a aflojarse es «en uso»: un plan asignado que nadie ha tocado está
/// asignado, no en uso.
library;

import 'package:natacion_app/dominio/auditoria/auditoria.dart';
import 'package:natacion_app/dominio/entidades/asignacion.dart';
import 'package:natacion_app/dominio/entidades/plan.dart';

class ResumenDelEntrenador {
  const ResumenDelEntrenador({
    required this.planesGenerados,
    required this.esperandoAprobacion,
    required this.aprobadosSinAsignar,
    required this.enUso,
  });

  /// Cuenta los cuatro a partir de lo que ya está cargado.
  ///
  /// [nadadoresConRegistros] viene de una sola consulta
  /// —`RepositorioRegistros.nadadoresConRegistros()`— en lugar de una por
  /// nadador (decisión D10).
  ///
  /// [listoParaFirmar] existe para poder probar el recuento sin montar un plan
  /// que cumpla los once criterios. **Por omisión es la auditoría de verdad**,
  /// y hay una prueba que lo comprueba: si alguien lo dejara en `true`, el
  /// número diría que todo espera firma.
  factory ResumenDelEntrenador.de({
    required List<Plan> planes,
    required List<Asignacion> asignaciones,
    required Set<String> nadadoresConRegistros,
    bool Function(Plan)? listoParaFirmar,
  }) {
    final auditoria = Auditoria();
    final listo = listoParaFirmar ??
        (Plan plan) => auditoria.impedimentosPara(plan).isEmpty;

    final asignados = <String, Set<String>>{};
    for (final asignacion in asignaciones) {
      asignados
          .putIfAbsent(asignacion.planId, () => <String>{})
          .add(asignacion.nadadorId);
    }

    var esperando = 0;
    var sinAsignar = 0;
    var enUso = 0;

    for (final plan in planes) {
      final deEste = asignados[plan.id ?? ''] ?? const <String>{};

      switch (plan.estado) {
        case EstadoPlan.borrador:
          // Un borrador con bloqueos no espera su firma: espera corrección.
          if (listo(plan)) esperando++;

        case EstadoPlan.aprobado:
          if (deEste.isEmpty) sinAsignar++;

        case EstadoPlan.publicado:
          // Las tres condiciones, y las tres hacen falta: entregado, a alguien,
          // y ese alguien ha respondido algo. Se cuenta **el plan**, una vez,
          // aunque lo usen varios nadadores.
          if (deEste.any(nadadoresConRegistros.contains)) enUso++;
      }
    }

    return ResumenDelEntrenador(
      planesGenerados: planes.length,
      esperandoAprobacion: esperando,
      aprobadosSinAsignar: sinAsignar,
      enUso: enUso,
    );
  }

  /// Todos los que existen, en cualquier estado.
  final int planesGenerados;

  /// En `borrador` y sin nada que impida firmarlos.
  final int esperandoAprobacion;

  /// Firmados y sin entregar a nadie.
  final int aprobadosSinAsignar;

  /// Publicados, asignados, y con algún registro de un nadador asignado.
  final int enUso;

  /// Si no hay ni un plan todavía. La pantalla lo dice y señala por dónde
  /// empezar, en lugar de enseñar cuatro ceros sin más.
  bool get sinNadaTodavia => planesGenerados == 0;
}
