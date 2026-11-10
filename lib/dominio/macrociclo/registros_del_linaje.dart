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

  // **Se camina por identificadores, no por documentos.**
  //
  // Los registros son del nadador y los puede leer siempre; el documento del
  // plan viejo, no. `firmarYEntregarElReajuste` retira la asignación de la
  // versión anterior —trabaja con una, y eso está bien— y la regla de planes
  // se apoya en la asignación para dejar leer. Así que la versión vieja deja
  // de ser legible justo cuando hace falta para el historial.
  //
  // Pedir el plan primero y leer sus registros después hacía que una
  // negativa tapara la pantalla entera: en el Pixel 7, «No se pudo cargar tu
  // plan: The caller does not have permission…» en lugar de su camino. Ahora
  // los registros de cada versión se leen por su identificador, y el plan se
  // pide **solo para saber cuál es la siguiente hacia atrás**. Si no se puede,
  // se devuelve lo reunido.
  //
  // Queda un límite, y es honesto decirlo aquí: con dos reajustes encadenados
  // la generación más vieja se pierde de vista, porque llegar a ella pediría
  // un plan intermedio que tampoco es suyo. Quitarlo es una decisión de
  // diseño —no retirar la asignación, o ensanchar la regla— y no se toma
  // desde aquí.
  String? id = mesociclo.id;
  Plan? actual = mesociclo;
  var vueltas = 0;

  while (id != null && vueltas < versionesQueSeMiranHaciaAtras) {
    vueltas++;

    if (!vistos.add(id)) break;

    for (final registro in await registros.obtenerDePlan(nadadorId, id)) {
      porSesion.putIfAbsent(registro.sesionId, () => registro);
    }

    // El salto hacia atrás. `actual` puede ser nulo si el plan de esta vuelta
    // no se pudo leer: entonces no hay forma de saber qué hubo antes.
    final anterior = actual?.versionAnteriorId;
    if (anterior == null) break;

    try {
      actual = await planes.obtener(anterior);
    } on FalloDeDatos {
      // Ya no es suyo. Lo que anotó en él sí: se lee en la vuelta siguiente
      // por su identificador, y ahí se para.
      actual = null;
    }
    id = anterior;
  }

  return List.unmodifiable(porSesion.values);
}
