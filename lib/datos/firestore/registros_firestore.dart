/// Los registros del nadador, leídos del servidor.
///
/// **Esto faltaba.** Desde la feature 003 los registros se *escriben* en
/// Firestore —`EnvioAFirestore` los manda— y no había nada que los *leyera*:
/// `RegistrosLocales` lee del almacén del dispositivo, así que el entrenador
/// solo veía las respuestas que su propio teléfono había escrito. Funcionaba
/// porque la feature 003 se probó con el entrenador haciendo de su propio
/// nadador, en un solo dispositivo.
///
/// La feature 007 lo necesita para una cosa concreta: contar los planes «en
/// uso» en el resumen del entrenador. Lo que esta clase **no** hace todavía es
/// darle al entrenador la lectura completa de lo que sus nadadores responden;
/// eso es su `Análisis`, que llega en la feature 010.
///
/// Escribir y borrar no están: las reglas de acceso lo dicen y esta clase lo
/// repite en voz alta en lugar de fallar con un código de Firebase.
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:natacion_app/datos/firestore/lo_que_haya.dart';
import 'package:natacion_app/datos/exportacion.dart';
import 'package:natacion_app/datos/firestore/envio_registros.dart';
import 'package:natacion_app/datos/serializacion.dart';
import 'package:natacion_app/dominio/entidades/registro_sesion.dart';
import 'package:natacion_app/dominio/repositorios/repositorios.dart';

class RegistrosFirestore implements RepositorioRegistros {
  const RegistrosFirestore(this.firestore);

  final FirebaseFirestore firestore;

  CollectionReference<Map<String, dynamic>> get _registros =>
      firestore.collection(coleccionRegistros);

  @override
  Future<RegistroDeSesion?> obtener(String registroId) async {
    try {
      final documento = await _registros.doc(registroId).leerLoQueHaya();
      final datos = documento.data();
      return datos == null
          ? null
          : registroDesdeJson(_conFechasLegibles(datos));
    } on FirebaseException catch (e) {
      throw FalloDeDatos('No se pudo leer el registro: ${e.message}');
    }
  }

  @override
  Future<List<RegistroDeSesion>> obtenerDePlan(
    String nadadorId,
    String planId,
  ) async {
    try {
      final instantanea = await _registros
          .where('nadadorId', isEqualTo: nadadorId)
          .where('planId', isEqualTo: planId)
          .leerLoQueHaya();

      return [
        for (final d in instantanea.docs)
          registroDesdeJson(_conFechasLegibles(d.data())),
      ];
    } on FirebaseException catch (e) {
      throw FalloDeDatos('No se pudieron leer los registros: ${e.message}');
    } on Object catch (e) {
      // Un documento que no se entiende **se reporta**, y en términos del
      // dominio: `repositorios.dart` dice que los errores no suben como
      // excepciones de la librería de datos. Sin esto un `TypeError` atraviesa
      // la pantalla entera, que es justo lo que hizo `recibidoEn`.
      throw FalloDeDatos('No se pudo entender un registro guardado: $e');
    }
  }

  @override
  Future<Set<String>> nadadoresConRegistros() async {
    // Una sola consulta a la colección, que es lo que la decisión D10 compra:
    // contar «en uso» preguntando nadador por nadador serían N consultas, y el
    // número de nadadores crece.
    //
    // Solo el entrenador puede hacerla: las reglas le dejan leer los registros
    // de su comunidad, y a un nadador solo los suyos.
    try {
      final instantanea = await _registros.leerLoQueHaya();
      return instantanea.docs
          .map((d) => d.data()['nadadorId'] as String?)
          .whereType<String>()
          .toSet();
    } on FirebaseException catch (e) {
      throw FalloDeDatos('No se pudo saber quién ha respondido: ${e.message}');
    }
  }

  @override
  Future<Map<String, dynamic>> exportar(String nadadorId) async {
    try {
      final instantanea = await _registros
          .where('nadadorId', isEqualTo: nadadorId)
          .leerLoQueHaya();

      return <String, dynamic>{
        'formato': formatoExportacion,
        'exportadoEl': DateTime.now().toIso8601String(),
        'registros': [for (final d in instantanea.docs) d.data()],
      };
    } on FirebaseException catch (e) {
      throw FalloDeDatos('No se pudieron exportar los registros: ${e.message}');
    }
  }

  @override
  Future<void> guardar(RegistroDeSesion registro) {
    // Lo que el nadador escribe va **primero al dispositivo** y después a la
    // bandeja de salida, que es la garantía G1: escribir a pie de piscina no
    // puede fallar por falta de señal. Guardar directo aquí se la saltaría.
    throw const FalloDeDatos(
      'Los registros no se escriben directo en el servidor: se guardan en el '
      'dispositivo y la bandeja de salida los envía.',
    );
  }

  @override
  Future<void> eliminarDe(String nadadorId) {
    // `firestore.rules`: «un registro no se borra desde el cliente. El derecho
    // al borrado del principio V se ejerce por la vía del servidor, que puede
    // dejar constancia de que se ejerció».
    throw const FalloDeDatos(
      'Borrar registros es cosa del servidor, para que quede constancia de '
      'que el derecho se ejerció.',
    );
  }
}

/// Un registro del servidor, con sus fechas puestas en la forma que
/// `registroDesdeJson` entiende.
///
/// **Esto es lo que faltaba, y costó la pantalla de una nadadora.**
/// `EnvioAFirestore` escribe `recibidoEn` con `FieldValue.serverTimestamp()`,
/// así que vuelve como `Timestamp`; `registroDesdeJson` lo leía con
/// `as String?` y lanzaba un `TypeError` que subía por `registrosDelLinaje`
/// hasta la pantalla. Ana marcaba su sesión, el registro llegaba a Firestore
/// con su esfuerzo y sus palabras, y la pantalla seguía diciendo «Sesiones
/// cumplidas: 0 de 39».
///
/// **Quien sabe de `Timestamp` es este archivo, no la serialización.** Ese otro
/// lo usan el almacén del dispositivo y las pruebas, que no conocen Firestore.
/// Es la misma forma que `MolestiasFirestore` ya usaba para lo mismo.
Map<String, dynamic> _conFechasLegibles(Map<String, dynamic> datos) {
  DateTime? comoFecha(Object? valor) => switch (valor) {
    final Timestamp marca => marca.toDate(),
    final DateTime fecha => fecha,
    final String texto => DateTime.tryParse(texto),
    _ => null,
  };

  final normalizado = Map<String, dynamic>.of(datos);

  for (final campo in const ['registradoEn', 'recibidoEn']) {
    if (!normalizado.containsKey(campo)) continue;

    final fecha = comoFecha(normalizado[campo]);
    if (fecha == null) {
      // No se adivina. Se quita, y `registroDesdeJson` decide el respaldo:
      // una fecha inventada aquí sería peor que un hueco.
      normalizado.remove(campo);
    } else {
      normalizado[campo] = fecha.toIso8601String();
    }
  }

  return normalizado;
}
