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
    required this.todos,
    required this.idsEsperandoAprobacion,
    required this.idsPorCorregir,
    required this.idsAprobadosSinAsignar,
    required this.idsEnUso,
    this.planesSinId = 0,
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
    final listo =
        listoParaFirmar ??
        (Plan plan) => auditoria.impedimentosPara(plan).isEmpty;

    final asignados = <String, Set<String>>{};
    for (final asignacion in asignaciones) {
      asignados
          .putIfAbsent(asignacion.planId, () => <String>{})
          .add(asignacion.nadadorId);
    }

    final esperando = <String>{};
    final porCorregir = <String>{};
    final sinAsignar = <String>{};
    final enUso = <String>{};
    final todos = <String>{};

    for (final plan in planes) {
      final id = plan.id;
      if (id == null) continue;
      todos.add(id);

      final deEste = asignados[id] ?? const <String>{};

      switch (plan.estado) {
        case EstadoPlan.borrador:
          // Un borrador con bloqueos no espera su firma: espera corrección.
          // **Y por eso se cuenta aparte**: con solo el primer número, un
          // borrador bloqueado no aparecía en ninguna parte y parecía no
          // existir.
          if (listo(plan)) {
            esperando.add(id);
          } else {
            porCorregir.add(id);
          }

        case EstadoPlan.aprobado:
          if (deEste.isEmpty) sinAsignar.add(id);

        case EstadoPlan.publicado:
          // Las tres condiciones, y las tres hacen falta: entregado, a alguien,
          // y ese alguien ha respondido algo. Se cuenta **el plan**, una vez,
          // aunque lo usen varios nadadores.
          if (deEste.any(nadadoresConRegistros.contains)) enUso.add(id);
      }
    }

    return ResumenDelEntrenador(
      todos: todos,
      idsEsperandoAprobacion: esperando,
      idsPorCorregir: porCorregir,
      idsAprobadosSinAsignar: sinAsignar,
      idsEnUso: enUso,
      planesSinId: planes.length - todos.length,
    );
  }

  /// Los identificadores de cada grupo, **no solo cuántos son**.
  ///
  /// Así el número que se enseña y la lista que se abre al tocarlo salen del
  /// mismo sitio: tocar «esperando tu firma» no puede llevar a otra cosa que a
  /// esos planes.
  final Set<String> todos;
  final Set<String> idsEsperandoAprobacion;
  final Set<String> idsPorCorregir;
  final Set<String> idsAprobadosSinAsignar;
  final Set<String> idsEnUso;

  /// Planes sin identificador. No se pueden abrir, pero existen y se cuentan.
  final int planesSinId;

  /// Todos los que existen, en cualquier estado.
  int get planesGenerados => todos.length + planesSinId;

  /// En `borrador` y sin nada que impida firmarlos.
  int get esperandoAprobacion => idsEsperandoAprobacion.length;

  /// En `borrador` y con algo que la auditoría bloquea.
  int get porCorregir => idsPorCorregir.length;

  /// Firmados y sin entregar a nadie.
  int get aprobadosSinAsignar => idsAprobadosSinAsignar.length;

  /// Publicados, asignados, y con algún registro de un nadador asignado.
  int get enUso => idsEnUso.length;

  /// Si no hay ni un plan todavía. La pantalla lo dice y señala por dónde
  /// empezar, en lugar de enseñar cuatro ceros sin más.
  bool get sinNadaTodavia => planesGenerados == 0;

  /// Qué planes mirar para un grupo.
  Set<String>? idsDe(QueMirar que) => switch (que) {
    QueMirar.todos => null,
    QueMirar.enUso => idsEnUso,
    QueMirar.esperandoFirma => idsEsperandoAprobacion,
    QueMirar.porCorregir => idsPorCorregir,
    QueMirar.aprobadosSinAsignar => idsAprobadosSinAsignar,
  };
}

/// Qué grupo de planes se está mirando en `Ver Plan`.
///
/// Es lo que un número de la portada abre al tocarlo: contar sin poder ir a
/// verlos deja al entrenador buscándolos a mano.
enum QueMirar {
  todos('Todos'),
  enUso('En uso'),
  esperandoFirma('Esperando tu firma'),
  porCorregir('Con algo que corregir'),
  aprobadosSinAsignar('Aprobados sin entregar');

  const QueMirar(this.etiqueta);

  final String etiqueta;
}
