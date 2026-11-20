/// Quiénes son los suyos (feature 012).
///
/// Es la pieza que cinco consultas del entrenador necesitaban y no tenían.
/// Antes de esta feature todas leían la colección entera: la lista de
/// nadadores, quiénes han respondido algo, quién tiene macrociclo, la cola de
/// peticiones y las asignaciones. Ninguna llevaba filtro porque ninguna lo
/// necesitaba — la regla decía `esEntrenador()`, sin más.
///
/// Ahora la regla pregunta de quién es cada documento, y **las reglas no
/// filtran**: o la consulta se demuestra entera por sus filtros o Firestore la
/// rechaza entera. Así que cada una de las cinco tiene que llevar en sus
/// filtros la lista de los suyos, y de ahí sale esta clase.
///
/// ## Lo que cuesta
///
/// Una consulta más por llamada, y **sin memoria**. Guardar la lista unos
/// segundos ahorraría tres consultas por refresco del HUB, y a cambio el
/// entrenador que acaba de aceptar a alguien podría refrescar y no verla. Es un
/// precio malo: la pertenencia es justo lo que esta feature hace cambiar a
/// mano, y el proyecto ya aceptó una lectura por escritura en la puerta de
/// consentimiento de la feature 004 por la misma razón escrita allí — a esta
/// escala, decenas de nadadores, es irrelevante.
///
/// ## Los lotes
///
/// `whereIn` de Firestore admite 30 valores. Con más nadadores la consulta se
/// parte en lotes, y por eso lo que se devuelve es una lista de listas: quien
/// consulta sabe que va a hacer varias y cuántas.
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:natacion_app/datos/firestore/lo_que_haya.dart';
import 'package:natacion_app/dominio/repositorios/repositorios.dart';

/// El tope de `whereIn` en Firestore.
const int tamanoDeLote = 30;

class MisNadadores {
  const MisNadadores({required this.db, required this.comunidadId});

  final FirebaseFirestore db;

  /// La comunidad de quien pregunta. Es su propio identificador de cuenta:
  /// «una comunidad por entrenador» es un hecho de la clave.
  final String comunidadId;

  /// Los identificadores de los suyos, en una consulta filtrada.
  Future<List<String>> ids() async {
    try {
      final instantanea = await db
          .collection('nadadores')
          .where('comunidadId', isEqualTo: comunidadId)
          .leerLoQueHaya();
      return [for (final d in instantanea.docs) d.id];
    } on FirebaseException catch (e) {
      throw FalloDeDatos('No se pudo saber quiénes son tus nadadores: '
          '${e.message}');
    }
  }

  /// Los mismos, repartidos en lotes de [tamanoDeLote].
  ///
  /// Vacío cuando no tiene a nadie, y **eso no es un error**: es el entrenador
  /// que acaba de empezar, y lo correcto es no consultar nada en lugar de
  /// consultarlo todo.
  Future<List<List<String>>> enLotes() async {
    final todos = await ids();
    return lotesDe(todos);
  }
}

/// Parte una lista en trozos que `whereIn` admite.
///
/// Fuera de la clase para que se pueda probar sin servidor.
List<List<String>> lotesDe(List<String> ids) {
  final lotes = <List<String>>[];
  for (var i = 0; i < ids.length; i += tamanoDeLote) {
    lotes.add(
      ids.sublist(i, i + tamanoDeLote > ids.length ? ids.length : i + tamanoDeLote),
    );
  }
  return lotes;
}
