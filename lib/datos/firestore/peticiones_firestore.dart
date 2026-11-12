/// Las peticiones de plan, en Firestore.
///
/// **El documento se llama como el nadador.** No es una comodidad: es lo que
/// convierte «una petición abierta a la vez» en algo que las reglas pueden
/// comprobar. Con un identificador aleatorio ninguna regla podría contar las
/// abiertas, y el límite viviría solo en la pantalla.
///
/// Esta clase **escribe muy poco a propósito**: el nadador manda sus
/// respuestas y nada más. El estado, la fecha de envío, el plan y la fecha de
/// respuesta los pone el servidor, y las reglas lo comprueban campo a campo.
/// Un cliente que pudiera escribir su propio estado podría aprobarse su
/// propia petición.
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:natacion_app/datos/firestore/lo_que_haya.dart';
import 'package:natacion_app/dominio/peticiones/peticion.dart';
import 'package:natacion_app/dominio/repositorios/repositorios.dart';

/// **No es `solicitudes`**, que son las del consentimiento de la feature 004.
/// Dos cosas distintas con el mismo nombre en la misma base es como se escribe
/// una regla contra la colección equivocada, y esas reglas guardan datos de un
/// menor (decisión D2).
const String coleccionPeticiones = 'peticionesDePlan';

class PeticionesFirestore implements RepositorioPeticiones {
  const PeticionesFirestore(this.firestore);

  final FirebaseFirestore firestore;

  CollectionReference<Map<String, dynamic>> get _peticiones =>
      firestore.collection(coleccionPeticiones);

  @override
  Future<PeticionDePlan?> miPeticion(String nadadorId) async {
    final documento = await _peticiones.doc(nadadorId).leerLoQueHaya();
    final datos = documento.data();
    return datos == null ? null : peticionDesdeJson(nadadorId, datos);
  }

  @override
  Future<List<PeticionDePlan>> cola() async {
    final consulta = await _peticiones.leerLoQueHaya();

    return [
      for (final documento in consulta.docs)
        peticionDesdeJson(documento.id, documento.data()),
    ];
  }

  @override
  Future<void> enviar({
    required String nadadorId,
    required RespuestasDePeticion respuestas,
  }) async {
    // **Exactamente dos campos.** Las reglas rechazan cualquier otro, así que
    // añadir uno aquí no abriría una puerta: rompería el envío. Está escrito
    // así para que se vea que es deliberado.
    await _peticiones.doc(nadadorId).set({
      'nadadorId': nadadorId,
      'respuestas': respuestas.toJson(),
    });
  }

  @override
  Future<void> marcarEnRevision(String nadadorId) async {
    await _peticiones.doc(nadadorId).update({'estado': 'enRevision'});
  }
}

/// Arma la petición con lo que traiga el documento.
///
/// **Cada campo por separado, y lo que no se entienda se queda fuera.** En la
/// feature 007, un `as Timestamp?` sobre una fecha guardada como texto lanzó
/// un `TypeError` —que es un `Error` y no una `Exception`, así que ningún
/// `catch` por tipo lo paraba— y dejó los `Ajustes` de una nadadora girando
/// para siempre. Lo que se perdía eran sus derechos de la Ley 1581.
PeticionDePlan peticionDesdeJson(String nadadorId, Map<String, dynamic> datos) {
  final respuestas = datos['respuestas'];

  return PeticionDePlan(
    nadadorId: nadadorId,
    // Un documento recién creado todavía no tiene fecha: la pone el
    // disparador del servidor. Mientras tanto se usa la de ahora, que es lo
    // más cerca de la verdad que el cliente puede estar.
    enviadaEn: _fecha(datos['enviadaEn']) ?? DateTime.now(),
    respuestas: RespuestasDePeticion.desdeJson(
      respuestas is Map<String, dynamic> ? respuestas : const {},
    ),
    // Igual con el estado: sin él, la petición acaba de llegar.
    estado: _estado(datos['estado']),
    motivoDelRechazo: datos['motivoDelRechazo'] is String
        ? datos['motivoDelRechazo'] as String
        : null,
    planId: datos['planId'] is String ? datos['planId'] as String : null,
    respondidaEn: _fecha(datos['respondidaEn']),
  );
}

EstadoDePeticion _estado(Object? valor) {
  for (final estado in EstadoDePeticion.values) {
    if (estado.name == valor) return estado;
  }
  return EstadoDePeticion.esperando;
}

/// Una fecha, venga como venga. Si no se entiende, no hay fecha.
DateTime? _fecha(Object? valor) => switch (valor) {
  final Timestamp marca => marca.toDate(),
  final DateTime fecha => fecha,
  final String texto => DateTime.tryParse(texto),
  _ => null,
};
