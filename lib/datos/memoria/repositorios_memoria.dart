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
import 'package:natacion_app/dominio/metodologia/categorias.dart';
import 'package:natacion_app/dominio/repositorios/repositorios.dart';

class RepositorioPlanesMemoria implements RepositorioPlanes {
  final Map<String, Plan> _planes = {};
  final Map<String, Map<String, dynamic>> _auditorias = {};
  int _siguienteId = 1;

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
    _planes[id] = plan.copiarCon(id: id);
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
    _planes[id] = plan;
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
      id: 'plan-${_siguienteId++}',
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

    _planes[nueva.id!] = nueva;
    return nueva;
  }

  @override
  Future<Map<String, dynamic>> exportar(String id) async {
    final plan = _planes[id];
    if (plan == null) throw FalloDeDatos('No existe el plan $id');
    return planAJson(plan, conSesiones: true);
  }
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
