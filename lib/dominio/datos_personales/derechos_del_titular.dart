/// Los derechos que la Ley 1581 de 2012 reconoce al titular.
///
/// Saber qué hay, llevárselo y pedir que se elimine. Están aquí, en el
/// dominio y en Dart puro, porque son **reglas del producto** y no un detalle
/// de la base de datos: si viven dentro de una consulta a Firestore dejan de
/// ser revisables.
///
/// Lo que esta pieza orquesta es lo que ya existe. No inventa un formato de
/// exportación —reutiliza el de la feature 001— ni una forma de borrar: usa
/// `RepositorioRegistros.eliminarDe`, que la 003 escribió precisamente para
/// que el borrado no exigiera rediseñar nada (FR-038).
library;

import 'package:natacion_app/dominio/entidades/asignacion.dart';
import 'package:natacion_app/dominio/entidades/registro_sesion.dart';
import 'package:natacion_app/dominio/repositorios/repositorios.dart';

/// Lo que la app guarda sobre un nadador, dicho para que lo entienda alguien.
///
/// **No es un volcado técnico** (FR-036). Un acudiente tiene derecho a saber
/// qué hay sobre su hijo, y «qué hay» no se responde con un JSON.
class QueSeGuarda {
  const QueSeGuarda({
    required this.nombre,
    required this.constaFechaDeNacimiento,
    required this.planesEntregados,
    required this.sesionesRespondidas,
    required this.conReporteDeMolestia,
    required this.marcasRegistradas,
  });

  final String nombre;
  final bool constaFechaDeNacimiento;
  final int planesEntregados;
  final int sesionesRespondidas;
  final int conReporteDeMolestia;
  final int marcasRegistradas;

  /// En frases, no en campos.
  List<String> get enPalabras => [
        'Su nombre: $nombre.',
        if (constaFechaDeNacimiento)
          'Su fecha de nacimiento.'
        else
          'No consta su fecha de nacimiento.',
        if (marcasRegistradas > 0)
          'Sus marcas en competencia: $marcasRegistradas.'
        else
          'No hay marcas registradas.',
        'Planes de entrenamiento que se le han entregado: $planesEntregados.',
        'Sesiones sobre las que ha respondido: $sesionesRespondidas. '
            'De cada una, si la hizo, cuánto esfuerzo sintió y lo que quiso '
            'escribir.',
        if (conReporteDeMolestia > 0)
          'De esas, $conReporteDeMolestia con un reporte de molestia o dolor.',
        'Nada más. No hay fotos, ni videos, ni datos de salud fuera de lo que '
            'él mismo escribió.',
      ];
}

/// Qué se borró y qué no, para poder decírselo a quien lo pidió.
class ResultadoDeEliminacion {
  const ResultadoDeEliminacion({
    required this.registrosEliminados,
    required this.asignacionesRetiradas,
    required this.perfilEliminado,
  });

  final int registrosEliminados;
  final int asignacionesRetiradas;
  final bool perfilEliminado;

  /// Lo que **no** se borra, y por qué.
  ///
  /// El registro del consentimiento sobrevive: es la prueba de que el
  /// tratamiento anterior estuvo amparado, y destruirla al borrar dejaría al
  /// entrenador sin poder demostrar que actuó con autorización (garantía C8).
  /// Lo que sí hace falta es revocarlo, y eso lo hace el servidor.
  static const String loQueSobrevive =
      'Queda el registro de que hubo consentimiento, con su fecha. Es la '
      'prueba de que lo anterior estuvo autorizado, y por eso no se borra con '
      'el resto.';
}

class DerechosDelTitular {
  const DerechosDelTitular({
    required this.nadadores,
    required this.registros,
    required this.asignaciones,
  });

  final RepositorioNadadores nadadores;
  final RepositorioRegistros registros;
  final RepositorioAsignaciones asignaciones;

  /// FR-036 — qué se guarda sobre este nadador.
  Future<QueSeGuarda?> queSeGuardaDe(String nadadorId) async {
    final nadador = await nadadores.obtener(nadadorId);
    if (nadador == null) return null;

    final sus = await _registrosDe(nadadorId);
    final suyas = await asignaciones.deNadador(nadadorId);

    return QueSeGuarda(
      nombre: nadador.nombre,
      constaFechaDeNacimiento: nadador.fechaNacimiento != null,
      planesEntregados: suyas.length,
      sesionesRespondidas: sus.length,
      conReporteDeMolestia: sus.where((r) => r.tieneMolestia).length,
      marcasRegistradas: nadador.marcas.length,
    );
  }

  /// FR-037 — llevárselo en algo que se lea fuera de la app.
  ///
  /// Reutiliza la exportación que ya existe. Un formato propio para esto
  /// sería un segundo formato que mantener, y el principio VII pide no
  /// añadirlo sin un problema que lo justifique.
  Future<Map<String, dynamic>> exportar(String nadadorId) async {
    final nadador = await nadadores.obtener(nadadorId);
    if (nadador == null) {
      throw FalloDeDatos('No existe el nadador $nadadorId');
    }

    return <String, dynamic>{
      ...await nadadores.exportar(nadadorId),
      ...await registros.exportar(nadadorId),
    };
  }

  /// FR-038 — eliminar sus datos personales.
  ///
  /// **No destruye el trabajo del entrenador** (FR-039, SC-014). Los planes
  /// son su obra profesional y no contienen datos de nadie: desde que la
  /// asignación es un documento aparte, un plan no sabe siquiera de quién
  /// fue. Lo que se retira es la asignación, no el plan.
  Future<ResultadoDeEliminacion> eliminar(String nadadorId) async {
    final sus = await _registrosDe(nadadorId);
    await registros.eliminarDe(nadadorId);

    final suyas = await asignaciones.deNadador(nadadorId);
    for (final asignacion in suyas) {
      await asignaciones.retirar(asignacion.planId, nadadorId);
    }

    final existia = await nadadores.obtener(nadadorId) != null;
    if (existia) await nadadores.eliminar(nadadorId);

    return ResultadoDeEliminacion(
      registrosEliminados: sus.length,
      asignacionesRetiradas: suyas.length,
      perfilEliminado: existia,
    );
  }

  Future<List<RegistroDeSesion>> _registrosDe(String nadadorId) async {
    final suyas = await asignaciones.deNadador(nadadorId);
    final encontrados = <RegistroDeSesion>[];

    for (final Asignacion asignacion in suyas) {
      encontrados.addAll(
        await registros.obtenerDePlan(nadadorId, asignacion.planId),
      );
    }

    return encontrados;
  }
}
