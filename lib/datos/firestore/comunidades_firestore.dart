/// Las comunidades sobre Firestore (feature 012).
///
/// Un documento por comunidad, y **su identificador es el del entrenador**:
/// así «una comunidad por entrenador» es un hecho de la clave y no una regla
/// que alguien tenga que recordar.
///
/// Lo que se guarda aquí es el letrero —el nombre que una nadadora ve antes de
/// pertenecer a nada— y de quién es. Quién está dentro no: eso vive en la ficha
/// de cada nadadora, en un solo sitio, para que terminar una pertenencia corte
/// la lectura de inmediato (research D1).
///
/// Los errores de Firestore se traducen a [FalloDeDatos]: el dominio no conoce
/// esta librería.
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:natacion_app/datos/firestore/lo_que_haya.dart';
import 'package:natacion_app/dominio/comunidad/comunidad.dart';
import 'package:natacion_app/dominio/repositorios/repositorios.dart';

const String coleccionComunidades = 'comunidades';

class RepositorioComunidadesFirestore implements RepositorioComunidades {
  RepositorioComunidadesFirestore(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _comunidades =>
      _db.collection(coleccionComunidades);

  @override
  Future<Comunidad?> deEntrenador(String entrenadorId) =>
      // Es la misma cosa: el identificador de la comunidad es el suyo.
      obtener(entrenadorId);

  @override
  Future<Comunidad?> obtener(String comunidadId) async {
    try {
      final documento = await _comunidades.doc(comunidadId).leerLoQueHaya();
      final datos = documento.data();
      if (datos == null) return null;
      return _desde(datos, comunidadId);
    } on FirebaseException catch (e) {
      throw FalloDeDatos('No se pudo leer la comunidad: ${e.message}');
    } on NombreDeComunidadInvalido catch (e) {
      throw FalloDeDatos('La comunidad guardada no se pudo reconstruir: $e');
    }
  }

  @override
  Future<List<Comunidad>> lasQueSePuedenOfrecer() async {
    try {
      final instantanea = await _comunidades.leerLoQueHaya();

      final leidas = <Comunidad>[];
      for (final documento in instantanea.docs) {
        // **Una comunidad ilegible no tumba la lista.** Si una de tres está
        // corrupta, a quien se está dando de alta le salen las otras dos.
        try {
          leidas.add(_desde(documento.data(), documento.id));
        } on NombreDeComunidadInvalido {
          continue;
        }
      }

      leidas.sort((a, b) => a.nombre.compareTo(b.nombre));
      return List.unmodifiable(leidas);
    } on FirebaseException catch (e) {
      throw FalloDeDatos('No se pudieron leer las comunidades: ${e.message}');
    }
  }

  @override
  Future<void> guardar(Comunidad comunidad) async {
    try {
      await _comunidades.doc(comunidad.id).set({
        'entrenadorId': comunidad.entrenadorId,
        'nombre': comunidad.nombre,
      }, SetOptions(merge: true));
    } on FirebaseException catch (e) {
      throw FalloDeDatos('No se pudo guardar la comunidad: ${e.message}');
    }
  }

  Comunidad _desde(Map<String, dynamic> datos, String id) => Comunidad(
    id: id,
    entrenadorId: datos['entrenadorId'] as String? ?? '',
    nombre: datos['nombre'] as String? ?? '',
  );
}
