/// Implementación de los repositorios sobre Firestore.
///
/// Estructura según `contracts/almacenamiento.md`: un documento por plan con
/// los microciclos embebidos, y las sesiones en la subcolección `sesiones`.
///
/// Los errores de Firestore se traducen a [FalloDeDatos]: el dominio no conoce
/// esta librería.
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:natacion_app/datos/serializacion.dart';
import 'package:natacion_app/dominio/biblioteca/biblioteca.dart';
import 'package:natacion_app/dominio/entidades/nadador.dart';
import 'package:natacion_app/dominio/entidades/asignacion.dart';
import 'package:natacion_app/dominio/entidades/plan.dart';
import 'package:natacion_app/dominio/entidades/sesion.dart';
import 'package:natacion_app/dominio/metodologia/categorias.dart';
import 'package:natacion_app/dominio/repositorios/repositorios.dart';

const String coleccionPlanes = 'planes';
const String coleccionSesiones = 'sesiones';
const String coleccionNadadores = 'nadadores';

class RepositorioPlanesFirestore implements RepositorioPlanes {
  RepositorioPlanesFirestore(this._db, this._biblioteca, this._sesiones);

  final FirebaseFirestore _db;
  final Biblioteca _biblioteca;
  final RepositorioSesiones _sesiones;

  CollectionReference<Map<String, dynamic>> get _planes =>
      _db.collection(coleccionPlanes);

  @override
  Future<Plan?> obtener(String id) async {
    try {
      final documento = await _planes.doc(id).get();
      final datos = documento.data();
      if (datos == null) return null;

      final sesiones = await _sesiones.obtenerDePlan(id);
      return planDesdeJson(datos, _biblioteca, id: id, sesiones: sesiones);
    } on FirebaseException catch (e) {
      throw FalloDeDatos('No se pudo leer el plan $id: ${e.message}');
    }
  }

  @override
  Future<List<Plan>> listar({Categoria? categoria, EstadoPlan? estado}) async {
    try {
      Query<Map<String, dynamic>> consulta = _planes;
      if (categoria != null) {
        consulta = consulta.where('categoria', isEqualTo: categoria.nombre);
      }
      if (estado != null) {
        consulta = consulta.where('estado', isEqualTo: estado.name);
      }

      final instantanea = await consulta.get();
      return instantanea.docs
          .map((d) => planDesdeJson(d.data(), _biblioteca, id: d.id))
          .toList();
    } on FirebaseException catch (e) {
      throw FalloDeDatos('No se pudieron listar los planes: ${e.message}');
    }
  }

  @override
  Future<String> guardarBorrador(Plan plan) async {
    if (plan.estado.esInmutable) {
      throw const FalloDeDatos(
        'Un plan aprobado o publicado no se puede sobrescribir: '
        'editarlo crea una versión nueva',
      );
    }

    try {
      final datos = planAJson(plan);
      final id = plan.id;

      if (id == null) {
        final referencia = await _planes.add(datos);
        return referencia.id;
      }

      await _planes.doc(id).set(datos);
      return id;
    } on FirebaseException catch (e) {
      throw FalloDeDatos('No se pudo guardar el plan: ${e.message}');
    }
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

    try {
      await _planes.doc(id).set(<String, dynamic>{
        ...planAJson(plan),
        'auditoriaAlAprobar': auditoria,
      });
    } on FirebaseException catch (e) {
      throw FalloDeDatos('No se pudo aprobar el plan: ${e.message}');
    }
  }

  @override
  Future<Plan> crearVersionDesde(String idAprobado) async {
    final aprobado = await obtener(idAprobado);
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
      // Una versión nueva de un plan generado sigue siendo generada (FR-026).
      origen: aprobado.origen,
      justificaciones: aprobado.justificaciones,
      versionAnteriorId: idAprobado,
    );

    final idNuevo = await guardarBorrador(nueva);

    // Las sesiones se copian a la subcolección del plan nuevo.
    for (final sesion in aprobado.sesiones) {
      await _sesiones.guardar(idNuevo, sesion.copiarCon(id: null));
    }

    return nueva.copiarCon(id: idNuevo, sesiones: aprobado.sesiones);
  }

  @override
  Future<Map<String, dynamic>> exportar(String id) async {
    final plan = await obtener(id);
    if (plan == null) throw FalloDeDatos('No existe el plan $id');
    return planAJson(plan, conSesiones: true);
  }
}

class RepositorioSesionesFirestore implements RepositorioSesiones {
  RepositorioSesionesFirestore(this._db, this._biblioteca);

  final FirebaseFirestore _db;
  final Biblioteca _biblioteca;

  CollectionReference<Map<String, dynamic>> _sesionesDe(String planId) =>
      _db.collection(coleccionPlanes).doc(planId).collection(coleccionSesiones);

  @override
  Future<List<Sesion>> obtenerDePlan(String planId) async {
    try {
      final instantanea = await _sesionesDe(planId).get();
      return instantanea.docs
          .map((d) => sesionDesdeJson(d.data(), _biblioteca, id: d.id))
          .toList();
    } on FirebaseException catch (e) {
      throw FalloDeDatos(
        'No se pudieron leer las sesiones del plan $planId: ${e.message}',
      );
    }
  }

  @override
  Future<String> guardar(String planId, Sesion sesion) async {
    try {
      final datos = sesionAJson(sesion);
      final id = sesion.id;

      if (id == null) {
        final referencia = await _sesionesDe(planId).add(datos);
        return referencia.id;
      }

      await _sesionesDe(planId).doc(id).set(datos);
      return id;
    } on FirebaseException catch (e) {
      throw FalloDeDatos('No se pudo guardar la sesión: ${e.message}');
    }
  }

  @override
  Future<void> eliminar(String planId, String sesionId) async {
    try {
      await _sesionesDe(planId).doc(sesionId).delete();
    } on FirebaseException catch (e) {
      throw FalloDeDatos('No se pudo eliminar la sesión: ${e.message}');
    }
  }
}

class RepositorioNadadoresFirestore implements RepositorioNadadores {
  RepositorioNadadoresFirestore(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _nadadores =>
      _db.collection(coleccionNadadores);

  @override
  Future<Nadador?> obtener(String id) async {
    try {
      final documento = await _nadadores.doc(id).get();
      final datos = documento.data();
      return datos == null ? null : nadadorDesdeJson(datos, id: id);
    } on FirebaseException catch (e) {
      throw FalloDeDatos('No se pudo leer el nadador $id: ${e.message}');
    }
  }

  @override
  Future<List<Nadador>> listar() async {
    try {
      final instantanea = await _nadadores.get();
      return instantanea.docs
          .map((d) => nadadorDesdeJson(d.data(), id: d.id))
          .toList();
    } on FirebaseException catch (e) {
      throw FalloDeDatos('No se pudieron listar los nadadores: ${e.message}');
    }
  }

  @override
  Future<String> guardar(Nadador nadador) async {
    try {
      final datos = nadadorAJson(nadador);
      final id = nadador.id;

      if (id == null) {
        final referencia = await _nadadores.add(datos);
        return referencia.id;
      }

      await _nadadores.doc(id).set(datos);
      return id;
    } on FirebaseException catch (e) {
      throw FalloDeDatos('No se pudo guardar el nadador: ${e.message}');
    }
  }

  @override
  Future<void> eliminar(String id) async {
    try {
      await _nadadores.doc(id).delete();
    } on FirebaseException catch (e) {
      throw FalloDeDatos('No se pudo eliminar el nadador: ${e.message}');
    }
  }

  @override
  Future<Map<String, dynamic>> exportar(String id) async {
    final nadador = await obtener(id);
    if (nadador == null) throw FalloDeDatos('No existe el nadador $id');
    return nadadorAJson(nadador);
  }
}

/// Asignaciones en Firestore (feature 004).
///
/// El identificador del documento es el determinista `planId|nadadorId`:
/// entregar dos veces el mismo plan a la misma persona escribe el mismo
/// documento. No duplica por construcción, no por una comprobación que alguien
/// pueda olvidar.
class RepositorioAsignacionesFirestore implements RepositorioAsignaciones {
  RepositorioAsignacionesFirestore(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _coleccion =>
      _db.collection('asignaciones');

  Asignacion _desde(Map<String, dynamic> json) => Asignacion(
        planId: json['planId'] as String,
        nadadorId: json['nadadorId'] as String,
        asignadaEn:
            DateTime.tryParse(json['asignadaEn'] as String? ?? '') ??
                DateTime.fromMillisecondsSinceEpoch(0),
      );

  @override
  Future<List<Asignacion>> listar() async {
    final instantanea = await _coleccion.get();
    return instantanea.docs.map((d) => _desde(d.data())).toList();
  }

  @override
  Future<List<Asignacion>> deNadador(String nadadorId) async {
    final instantanea =
        await _coleccion.where('nadadorId', isEqualTo: nadadorId).get();
    return instantanea.docs.map((d) => _desde(d.data())).toList();
  }

  @override
  Future<List<Asignacion>> dePlan(String planId) async {
    final instantanea =
        await _coleccion.where('planId', isEqualTo: planId).get();
    return instantanea.docs.map((d) => _desde(d.data())).toList();
  }

  @override
  Future<void> asignar(Asignacion asignacion) async {
    try {
      await _coleccion.doc(asignacion.id).set({
        'planId': asignacion.planId,
        'nadadorId': asignacion.nadadorId,
        'asignadaEn': asignacion.asignadaEn.toIso8601String(),
      });
    } on FirebaseException catch (e) {
      // El caso esperado es que el servidor lo deniegue por falta de
      // consentimiento. Se traduce al dominio para que la pantalla pueda
      // decir qué falta en lugar de enseñar un código de Firebase.
      throw FalloDeDatos(
        e.code == 'permission-denied'
            ? 'No se puede entregar el plan: ese nadador no tiene '
                'consentimiento vigente de su acudiente.'
            : 'No se pudo entregar el plan: ${e.message}',
      );
    }
  }

  @override
  Future<void> retirar(String planId, String nadadorId) async {
    await _coleccion
        .doc(Asignacion.idDeterminista(planId: planId, nadadorId: nadadorId))
        .delete();
  }
}
