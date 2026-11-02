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
import 'package:natacion_app/dominio/consentimiento/constancia.dart';
import 'package:natacion_app/dominio/consentimiento/puerta.dart';

const String coleccionConsentimientos = 'consentimientos';

class PuertaFirestore implements PuertaDeConsentimiento {
  PuertaFirestore(
    this.firestore, {
    this.alcance = Alcance.datosDeEntrenamiento,
  });

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

/// Lee la constancia para mostrarla en `Ajustes` (feature 007).
///
/// Aparte de [PuertaFirestore] a propósito: esa decide si algo **sale**, y
/// ante la duda retiene. Esta solo cuenta lo que hay, y si no hay nada lo dice.
/// Juntarlas haría que una pantalla informativa compartiera camino con la
/// puerta que protege los datos de un menor.
class ConstanciasFirestore implements LectorDeConstancias {
  const ConstanciasFirestore(this.firestore);

  final FirebaseFirestore firestore;

  @override
  Future<ConstanciaDeConsentimiento?> de(String nadadorId) async {
    if (nadadorId.trim().isEmpty) return null;

    try {
      final documento = await firestore
          .collection(coleccionConsentimientos)
          .doc(nadadorId)
          .get();

      final datos = documento.data();
      if (datos == null) return null;

      return constanciaDesde(datos);
    } on FirebaseException {
      // Sin red ni caché no se sabe. **Se dice que no se sabe** en lugar de
      // decir que no hay consentimiento, que es una afirmación distinta.
      return null;
    }
  }
}

/// Arma la constancia con lo que traiga el documento.
///
/// **Aparte y sin Firestore a propósito**, porque esto es lo que se rompió y
/// lo que hay que poder probar. En el emulador de Android, `Ajustes` de una
/// nadadora se quedaba girando para siempre: el documento tenía la fecha
/// guardada como texto, `as Timestamp?` lanzaba un `TypeError` —que es un
/// `Error` y no una `Exception`, así que ningún `catch` por tipo lo paraba— y
/// la pantalla nunca terminaba de cargar. Con el entrenador no pasaba porque
/// su cuenta no tiene constancia que leer.
///
/// Aquí cada campo se lee por separado y **lo que no se entienda se queda
/// fuera**, no se inventa: una fecha de consentimiento es un dato legal, y
/// entre no tenerla y ponerle una aproximada no hay duda. Lo que no se pierde
/// es el resto de la constancia.
ConstanciaDeConsentimiento constanciaDesde(Map<String, dynamic> datos) =>
    ConstanciaDeConsentimiento(
      vigente: datos['vigente'] == true,
      alcances: (datos['alcances'] is List ? datos['alcances'] as List : const [])
          .map((a) => Alcance.porClave(a is String ? a : null))
          .nonNulls
          .toSet(),
      versionDelTexto: datos['versionDelTexto'] is String
          ? datos['versionDelTexto'] as String
          : null,
      otorgadoEn: _fecha(datos['otorgadoEn']),
      revocadoEn: _fecha(datos['revocadoEn']),
    );

/// Una fecha, venga como venga. Si no se entiende, no hay fecha.
///
/// El servidor escribe marcas de tiempo; una herramienta o una versión vieja
/// pueden haber dejado texto. Ninguna de las dos formas debería costar una
/// pantalla.
DateTime? _fecha(Object? valor) => switch (valor) {
  final Timestamp marca => marca.toDate(),
  final DateTime fecha => fecha,
  final String texto => DateTime.tryParse(texto),
  _ => null,
};
