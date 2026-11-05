/// Repositorios en memoria.
///
/// Sirven para probar el dominio sin Firestore y para trabajar en local antes
/// de levantar los emuladores. Implementan exactamente las mismas interfaces,
/// así que lo que funciona aquí funciona allí.
library;

import 'package:natacion_app/datos/serializacion.dart';
import 'package:natacion_app/dominio/entidades/nadador.dart';
import 'package:natacion_app/dominio/entidades/asignacion.dart';
import 'package:natacion_app/dominio/entidades/plan.dart';
import 'package:natacion_app/dominio/entidades/sesion.dart';
import 'package:natacion_app/dominio/macrociclo/macrociclo.dart';
import 'package:natacion_app/dominio/metodologia/categorias.dart';
import 'package:natacion_app/dominio/repositorios/repositorios.dart';

class RepositorioPlanesMemoria implements RepositorioPlanes {
  /// Las sesiones van por un repositorio aparte, **como en Firestore**.
  ///
  /// Antes no: este repositorio guardaba el objeto `Plan` entero en un mapa,
  /// sesiones incluidas, y con eso pasaban todas las pruebas Dart mientras
  /// Firestore perdía las sesiones de cualquier plan guardado por código. El
  /// doble era más cómodo que el colaborador real, y eso no hace la prueba más
  /// fácil: la hace deshonesta.
  ///
  /// Se puede inyectar el mismo que use el resto de la app, para que lo que se
  /// guarde por aquí se lea por allá. Si no se inyecta, se crea uno propio: lo
  /// que no puede pasar es que las sesiones no tengan identificador, porque es
  /// lo que los registros del nadador referencian.
  RepositorioPlanesMemoria({RepositorioSesiones? sesiones})
    : _sesiones = sesiones ?? RepositorioSesionesMemoria();

  final RepositorioSesiones _sesiones;

  final Map<String, Plan> _planes = {};
  final Map<String, Map<String, dynamic>> _auditorias = {};
  int _siguienteId = 1;

  /// Escribe las sesiones del plan y devuelve las que quedaron, con su
  /// identificador.
  Future<List<Sesion>> _guardarLasSesiones(String planId, Plan plan) async {
    final conId = <Sesion>[];
    for (final sesion in plan.sesiones) {
      final id = await _sesiones.guardar(planId, sesion);
      conId.add(sesion.copiarCon(id: id));
    }
    return conId;
  }

  @override
  Future<Plan?> obtener(String id) async => _planes[id];

  @override
  Future<List<Plan>> listar({Categoria? categoria, EstadoPlan? estado}) async {
    return _planes.values.where((plan) {
      if (categoria != null && plan.categoria != categoria) return false;
      if (estado != null && plan.estado != estado) return false;
      return true;
    }).toList();
  }

  @override
  Future<String> guardarBorrador(Plan plan) async {
    if (plan.estado.esInmutable) {
      throw const FalloDeDatos(
        'Un plan aprobado o publicado no se puede sobrescribir: '
        'editarlo crea una versión nueva',
      );
    }

    final id = plan.id ?? 'plan-${_siguienteId++}';
    final conSesiones = await _guardarLasSesiones(id, plan);
    _planes[id] = plan.copiarCon(id: id, sesiones: conSesiones);
    return id;
  }

  @override
  Future<void> guardarAprobado(
    Plan plan,
    Map<String, dynamic> auditoria,
  ) async {
    final id = plan.id;
    if (id == null) {
      throw const FalloDeDatos('Un plan aprobado debe tener identificador');
    }
    final conSesiones = await _guardarLasSesiones(id, plan);
    _planes[id] = plan.copiarCon(sesiones: conSesiones);
    _auditorias[id] = auditoria;
  }

  Map<String, dynamic>? auditoriaDe(String id) => _auditorias[id];

  @override
  Future<Plan> crearVersionDesde(String idAprobado) async {
    final aprobado = _planes[idAprobado];
    if (aprobado == null) {
      throw FalloDeDatos('No existe el plan $idAprobado');
    }
    if (aprobado.estado == EstadoPlan.borrador) {
      throw const FalloDeDatos(
        'Solo se crean versiones a partir de un plan aprobado',
      );
    }

    final nueva = Plan(
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
      // Una versión nueva de un plan generado sigue siendo generada (FR-026).
      origen: aprobado.origen,
      justificaciones: aprobado.justificaciones,
      versionAnteriorId: idAprobado,
    );

    // Por `guardarBorrador` y no escribiendo el mapa a mano: así las sesiones
    // de la versión nueva quedan guardadas donde se leen, **con el mismo
    // identificador que tenían**, igual que en Firestore. Escribir el mapa
    // directamente dejaba las sesiones sin registrar y hacía que esta
    // implementación y la real no coincidieran.
    final id = await guardarBorrador(nueva);
    return (await obtener(id))!;
  }

  @override
  Future<Map<String, dynamic>> exportar(String id) async {
    final plan = _planes[id];
    if (plan == null) throw FalloDeDatos('No existe el plan $id');
    return planAJson(plan, conSesiones: true);
  }
}

class RepositorioMacrociclosMemoria implements RepositorioMacrociclos {
  final Map<String, Macrociclo> _macrociclos = {};
  final Map<String, Map<String, dynamic>> _auditorias = {};
  int _siguienteId = 1;

  @override
  Future<Macrociclo?> obtener(String id) async => _macrociclos[id];

  @override
  Future<List<Macrociclo>> deNadador(String nadadorId) async {
    // **Una copia, no la lista guardada.** La feature 008 tuvo un doble de la
    // cola que devolvía siempre la misma instancia, y una prueba pasaba por
    // eso: la pantalla mutaba lo que el repositorio tenía dentro y las dos
    // coincidían siempre. Un doble más cómodo que el colaborador real no hace
    // la prueba más fácil, la hace deshonesta.
    return _macrociclos.values
        .where((m) => m.nadadorId == nadadorId)
        .toList(growable: false)
        .reversed
        .toList();
  }

  @override
  Future<String> guardarBorrador(Macrociclo macrociclo) async {
    if (macrociclo.estado.esInmutable) {
      throw const FalloDeDatos(
        'Un macrociclo aprobado o publicado no se sobrescribe: '
        'reajustarlo versiona sus mesociclos',
      );
    }

    final id = macrociclo.id ?? 'macro-${_siguienteId++}';
    _macrociclos[id] = macrociclo.copiarCon(id: id);
    return id;
  }

  @override
  Future<void> guardarAprobado(
    Macrociclo macrociclo,
    Map<String, dynamic> auditoria,
  ) async {
    final id = macrociclo.id;
    if (id == null) {
      throw const FalloDeDatos(
        'Un macrociclo aprobado debe tener identificador',
      );
    }
    _macrociclos[id] = macrociclo;
    _auditorias[id] = auditoria;
  }

  Map<String, dynamic>? auditoriaDe(String id) => _auditorias[id];

  @override
  Future<void> publicar(String id) async {
    final macrociclo = _macrociclos[id];
    if (macrociclo == null) throw FalloDeDatos('No existe el macrociclo $id');
    if (macrociclo.estado != EstadoPlan.aprobado) {
      throw const FalloDeDatos(
        'Solo se entrega un macrociclo firmado: firmar no es entregar',
      );
    }
    _macrociclos[id] = macrociclo.copiarCon(estado: EstadoPlan.publicado);
  }

  @override
  Future<void> anunciarElReajuste(
    String id, {
    required List<String> mesociclos,
    required ReajusteAnunciado aviso,
  }) async {
    final macrociclo = _macrociclos[id];
    if (macrociclo == null) throw FalloDeDatos('No existe el macrociclo $id');
    if (macrociclo.estado != EstadoPlan.publicado) {
      throw const FalloDeDatos(
        'Solo se reajusta un macrociclo que ya se entregó: lo que no ha '
        'llegado al nadador se cambia antes de firmarlo',
      );
    }
    _macrociclos[id] = macrociclo.copiarCon(
      mesociclos: mesociclos,
      ultimoReajuste: aviso,
    );
  }

  @override
  Future<Map<String, dynamic>> exportar(String id) async {
    final macrociclo = _macrociclos[id];
    if (macrociclo == null) throw FalloDeDatos('No existe el macrociclo $id');
    return macrocicloAJson(macrociclo);
  }

  /// Cuántos hay guardados. Lo usa el cerrojo M10, que comprueba que **no hay
  /// ninguno** antes de que el entrenador confirme.
  int get cuantosHay => _macrociclos.length;
}

class RepositorioSesionesMemoria implements RepositorioSesiones {
  final Map<String, Map<String, Sesion>> _porPlan = {};
  int _siguienteId = 1;

  @override
  Future<List<Sesion>> obtenerDePlan(String planId) async =>
      (_porPlan[planId] ?? const {}).values.toList();

  @override
  Future<String> guardar(String planId, Sesion sesion) async {
    final id = sesion.id ?? 'sesion-${_siguienteId++}';
    _porPlan.putIfAbsent(planId, () => {})[id] = sesion.copiarCon(id: id);
    return id;
  }

  @override
  Future<void> eliminar(String planId, String sesionId) async {
    _porPlan[planId]?.remove(sesionId);
  }
}

class RepositorioNadadoresMemoria implements RepositorioNadadores {
  final Map<String, Nadador> _nadadores = {};
  int _siguienteId = 1;

  @override
  Future<Nadador?> obtener(String id) async => _nadadores[id];

  @override
  Future<List<Nadador>> listar() async => _nadadores.values.toList();

  @override
  Future<String> guardar(Nadador nadador) async {
    final id = nadador.id ?? 'nadador-${_siguienteId++}';
    _nadadores[id] = nadador.copiarCon(id: id);
    return id;
  }

  @override
  Future<void> eliminar(String id) async {
    _nadadores.remove(id);
  }

  @override
  Future<Map<String, dynamic>> exportar(String id) async {
    final nadador = _nadadores[id];
    if (nadador == null) throw FalloDeDatos('No existe el nadador $id');
    return nadadorAJson(nadador);
  }
}

/// Asignaciones en memoria, para el modo local y para las pruebas.
///
/// **No comprueba el consentimiento**, y no puede: sin servidor no hay
/// consentimiento registrado. Por eso el modo local va rotulado y solo admite
/// datos de prueba.
class RepositorioAsignacionesMemoria implements RepositorioAsignaciones {
  final _asignaciones = <String, Asignacion>{};

  @override
  Future<List<Asignacion>> listar() async => _asignaciones.values.toList();

  @override
  Future<List<Asignacion>> deNadador(String nadadorId) async =>
      _asignaciones.values.where((a) => a.nadadorId == nadadorId).toList();

  @override
  Future<List<Asignacion>> dePlan(String planId) async =>
      _asignaciones.values.where((a) => a.planId == planId).toList();

  @override
  Future<void> asignar(Asignacion asignacion) async {
    _asignaciones[asignacion.id] = asignacion;
  }

  @override
  Future<void> retirar(String planId, String nadadorId) async {
    _asignaciones.remove(
      Asignacion.idDeterminista(planId: planId, nadadorId: nadadorId),
    );
  }
}
