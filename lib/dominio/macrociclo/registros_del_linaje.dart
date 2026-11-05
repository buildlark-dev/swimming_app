/// Lo que el nadador anotó, siguiendo el linaje de versiones (M34, FR-035).
///
/// **Es lo que hace que un reajuste no le deje el historial en blanco.**
///
/// Un reajuste crea una versión nueva del mesociclo, que es un plan nuevo con
/// identificador nuevo. Los `RegistroDeSesion` que el nadador escribió apuntan
/// al plan en el que los escribió, así que un lector que solo mire el plan
/// actual encuentra cero: todas las escrituras salieron bien, la pantalla se
/// pinta, y las sesiones que nadó aparecen sin marcar. No falla nada.
///
/// Lo que se hace aquí es **leer hacia atrás**, por `versionAnteriorId`. Los
/// registros no se tocan, no se copian y no se renombran:
///
/// - copiarlos al plan nuevo los duplicaría, y el entrenador leería adherencia
///   sobre el doble;
/// - reescribirlos sería alterar lo que el nadador escribió, que es justo lo
///   que FR-035 prohíbe.
///
/// La otra mitad del arreglo está en `crearVersionDesde`: una versión nueva
/// **conserva los identificadores de sesión**. Sin eso, leer el linaje traería
/// los registros y no habría forma de emparejarlos con las sesiones que el
/// nadador tiene delante.
///
/// Dominio puro: ni Flutter ni Firebase (principio II).
library;

import 'package:natacion_app/dominio/entidades/plan.dart';
import 'package:natacion_app/dominio/entidades/registro_sesion.dart';
import 'package:natacion_app/dominio/repositorios/repositorios.dart';

/// Hasta dónde se mira hacia atrás.
///
/// Una temporada no tiene cien versiones del mismo mesociclo; esto es un
/// seguro contra datos corruptos, no un límite de diseño.
const int versionesQueSeMiranHaciaAtras = 50;

/// Los registros de este mesociclo y de sus versiones anteriores.
///
/// **Lo respondido en la versión más nueva manda**: si el nadador volvió a
/// contestar la misma sesión, esa es su última palabra.
Future<List<RegistroDeSesion>> registrosDelLinaje({
  required Plan mesociclo,
  required String nadadorId,
  required RepositorioRegistros registros,
  required RepositorioPlanes planes,
}) async {
  // Por sesión, de la versión más nueva a la más vieja: el primero que entra
  // se queda.
  final porSesion = <String, RegistroDeSesion>{};

  // Un `versionAnteriorId` que apunte a sí mismo, o un ciclo entre dos, es un
  // dato corrupto. Lo que no puede hacer es dejar la pantalla del nadador
  // girando para siempre.
  final vistos = <String>{};

  Plan? actual = mesociclo;
  var vueltas = 0;

  while (actual != null && vueltas < versionesQueSeMiranHaciaAtras) {
    vueltas++;

    final id = actual.id;
    if (id == null || !vistos.add(id)) break;

    for (final registro in await registros.obtenerDePlan(nadadorId, id)) {
      porSesion.putIfAbsent(registro.sesionId, () => registro);
    }

    final anterior = actual.versionAnteriorId;
    actual = anterior == null ? null : await planes.obtener(anterior);
  }

  return List.unmodifiable(porSesion.values);
}
