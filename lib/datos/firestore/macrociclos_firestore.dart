/// Los macrociclos sobre Firestore (feature 009).
///
/// Un documento por macrociclo en `macrociclos`, con **referencias y no
/// contenido**: los ids de sus mesociclos, que son planes y viven en `planes`
/// con sus sesiones en la subcolección de cada uno.
///
/// Está en su propio archivo y no dentro de `repositorios_firestore.dart`
/// porque ese ya tiene cuatro repositorios, y porque el macrociclo es el único
/// que un nadador lee sin poder escribir nunca.
///
/// Los errores de Firestore se traducen a [FalloDeDatos]: el dominio no conoce
/// esta librería. Y los del dominio —`MacrocicloInvalido`,
/// `EstructuraInvalida`, que es lo que lanza la deserialización ante un
/// documento corrupto— también, porque quien lee un macrociclo quiere saber
/// que no se pudo leer, no recibir una excepción de otra capa.
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:natacion_app/datos/firestore/repositorios_firestore.dart';
import 'package:natacion_app/datos/serializacion.dart';
import 'package:natacion_app/dominio/entidades/plan.dart';
import 'package:natacion_app/dominio/macrociclo/macrociclo.dart';
import 'package:natacion_app/dominio/repositorios/repositorios.dart';

class RepositorioMacrociclosFirestore implements RepositorioMacrociclos {
  RepositorioMacrociclosFirestore(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _macrociclos =>
      _db.collection(coleccionMacrociclos);

  @override
  Future<Macrociclo?> obtener(String id) async {
    try {
      final documento = await _macrociclos.doc(id).get();
      final datos = documento.data();
      if (datos == null) return null;
      return macrocicloDesdeJson(datos, id: id);
    } on FirebaseException catch (e) {
      throw FalloDeDatos('No se pudo leer el macrociclo $id: ${e.message}');
    } on MacrocicloInvalido catch (e) {
      throw FalloDeDatos('El macrociclo $id no se pudo reconstruir: $e');
    } on EstructuraInvalida catch (e) {
      throw FalloDeDatos('El macrociclo $id no se pudo reconstruir: $e');
    }
  }

  @override
  Future<List<Macrociclo>> deNadador(String nadadorId) async {
    try {
      final instantanea = await _macrociclos
          .where('nadadorId', isEqualTo: nadadorId)
          .get();

      final leidos = <Macrociclo>[];
      for (final documento in instantanea.docs) {
        // **Un documento ilegible no tumba la lista.** Si uno de tres está
        // corrupto, el nadador sigue viendo los otros dos; lo que no pasa es
        // que vuelva a medias, porque la deserialización no construye
        // macrociclos incompletos.
        try {
          leidos.add(macrocicloDesdeJson(documento.data(), id: documento.id));
        } on MacrocicloInvalido {
          continue;
        } on EstructuraInvalida {
          continue;
        }
      }

      leidos.sort(
        (a, b) => b.fechaDeCompetencia.compareTo(a.fechaDeCompetencia),
      );
      return leidos;
    } on FirebaseException catch (e) {
      throw FalloDeDatos(
        'No se pudieron leer los macrociclos de $nadadorId: ${e.message}',
      );
    }
  }

  @override
  Future<String> guardarBorrador(Macrociclo macrociclo) async {
    if (macrociclo.estado.esInmutable) {
      throw const FalloDeDatos(
        'Un macrociclo aprobado o publicado no se sobrescribe: '
        'reajustarlo versiona sus mesociclos',
      );
    }

    try {
      final datos = macrocicloAJson(macrociclo);
      final id = macrociclo.id;

      if (id == null) {
        final referencia = await _macrociclos.add(datos);
        return referencia.id;
      }

      await _macrociclos.doc(id).set(datos);
      return id;
    } on FirebaseException catch (e) {
      throw FalloDeDatos('No se pudo guardar el macrociclo: ${e.message}');
    }
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

    try {
      await _macrociclos.doc(id).set(<String, dynamic>{
        ...macrocicloAJson(macrociclo),
        // La auditoría viaja con lo firmado, igual que en los planes: es parte
        // de lo que se firmó y no un informe aparte que se pueda perder.
        'auditoriaAlAprobar': auditoria,
      });
    } on FirebaseException catch (e) {
      throw FalloDeDatos('No se pudo aprobar el macrociclo: ${e.message}');
    }
  }

  @override
  Future<void> publicar(String id) async {
    try {
      // **Solo el estado.** La regla de Firestore acepta la entrega únicamente
      // cuando el único campo que cambia es `estado`; mandar el documento
      // entero la haría fallar, y con razón: lo firmado es inmutable.
      await _macrociclos.doc(id).update(<String, dynamic>{
        'estado': EstadoPlan.publicado.name,
      });
    } on FirebaseException catch (e) {
      throw FalloDeDatos('No se pudo entregar el macrociclo $id: ${e.message}');
    }
  }

  @override
  Future<Map<String, dynamic>> exportar(String id) async {
    final macrociclo = await obtener(id);
    if (macrociclo == null) {
      throw FalloDeDatos('No existe el macrociclo $id');
    }
    return macrocicloAJson(macrociclo);
  }
}
