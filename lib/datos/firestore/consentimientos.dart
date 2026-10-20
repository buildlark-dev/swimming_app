/// La puerta de consentimiento, leída de Firestore.
///
/// **Tiene que poder responder sin red.** Un nadador a pie de piscina no puede
/// quedarse sin poder enviar porque no se sepa si su acudiente consintió, así
/// que la lectura se apoya en la caché que la feature 003 dejó activada.
///
/// Y ante la duda **retiene**. Si no se puede saber, no sale: con datos de un
/// menor, el error de retener de más se arregla solo cuando vuelva la red, y el
/// de enviar de más no se arregla nunca.
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:natacion_app/dominio/consentimiento/consentimiento.dart';
import 'package:natacion_app/dominio/consentimiento/puerta.dart';

const String coleccionConsentimientos = 'consentimientos';

class PuertaFirestore implements PuertaDeConsentimiento {
  PuertaFirestore(this.firestore, {this.alcance = Alcance.datosDeEntrenamiento});

  final FirebaseFirestore firestore;

  /// Qué alcance hace falta para que esto salga. Los registros del nadador van
  /// bajo `datosDeEntrenamiento`; el video, cuando exista, pedirá el suyo.
  final Alcance alcance;

  @override
  Future<bool> puedeSalir(String nadadorId) async {
    if (nadadorId.trim().isEmpty) return false;

    try {
      final documento = await firestore
          .collection(coleccionConsentimientos)
          .doc(nadadorId)
          .get(const GetOptions(source: Source.cache));

      return _loPermite(documento.data());
    } on FirebaseException {
      // No estaba en caché. Se intenta con el servidor, y si tampoco hay, se
      // retiene: las reglas lo rechazarían igual, y preguntar otra vez más
      // tarde no cuesta nada porque el registro sigue en la bandeja.
      return _preguntarAlServidor(nadadorId);
    }
  }

  Future<bool> _preguntarAlServidor(String nadadorId) async {
    try {
      final documento = await firestore
          .collection(coleccionConsentimientos)
          .doc(nadadorId)
          .get();
      return _loPermite(documento.data());
    } on FirebaseException {
      return false;
    }
  }

  bool _loPermite(Map<String, dynamic>? datos) {
    if (datos == null) return false;
    if (datos['vigente'] != true) return false;

    final alcances = (datos['alcances'] as List<dynamic>? ?? const [])
        .map((a) => Alcance.porClave(a as String?))
        .nonNulls
        .toSet();

    // El alcance se comprueba por separado: conceder datos de entrenamiento
    // no concede video, y al revés tampoco (FR-023).
    return alcances.contains(alcance);
  }
}
