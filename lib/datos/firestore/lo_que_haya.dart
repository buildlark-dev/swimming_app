/// Leer de Firestore **sin quedarse esperando para siempre**.
///
/// Hallazgo del recorrido en el Pixel 7, cerrando el escenario C1 de la
/// feature 003 —«el que justifica la feature»—: con el avión puesto y la app
/// cerrada del todo, `Ver Plan` se queda girando. Ni error, ni contenido, ni
/// la sesión de hoy.
///
/// Y la caché estaba: el fichero de persistencia existe en el dispositivo y
/// `persistenceEnabled` va activado también contra los emuladores, a
/// propósito, desde la feature 003. El dato estaba ahí y la pantalla no lo
/// alcanzaba.
///
/// **La causa es la misma que este proyecto ya conocía, del lado de leer.** El
/// SDK de Firestore no lanza cuando no hay red: deja el Future abierto. Un
/// `catch` no atrapa un Future que no termina, así que ni traducir todos los
/// fallos a [FalloDeDatos] servía de nada. Lo que cuelga de la red se acota.
///
/// ## Por qué solo el plazo, y no cualquier fallo
///
/// Esto cae a la caché **únicamente cuando se agota el plazo**. Un
/// `permission-denied` sigue subiendo, y es deliberado: la caché no pasa por
/// las reglas, así que caer a ella ante cualquier fallo convertiría un error
/// de permisos en una pantalla que funciona. El recorrido de la 009 ya pagó
/// uno de esos —la consulta de macrociclos a la que le faltaba un filtro—, y
/// se encontró porque falló a la vista.
///
/// Firestore ya cae a la caché por su cuenta cuando *sabe* que está sin red.
/// Lo que le falta es un plazo para cuando no lo sabe, que es lo que pasa
/// cuando el host no contesta: reintenta el stream sin rendirse. Eso es todo
/// lo que se añade aquí.
///
/// ## Lo que se queda fuera a propósito
///
/// - **Los consentimientos** (`consentimientos.dart`). Si esa lectura no
///   vuelve, la puerta se queda cerrada y los datos del menor se quedan en el
///   dispositivo, que es el lado correcto por el que fallar (principio V).
///   Abrirla desde una caché es una decisión del entrenador, no mía.
/// - **La bandeja de salida** (`envio_registros.dart`). Lee para no enviar dos
///   veces lo mismo, y para eso necesita lo que tiene **el servidor**. Una
///   respuesta de la caché ahí no dice nada.
library;

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

/// Lo que se le da al servidor antes de leer lo que haya en el dispositivo.
///
/// El mismo plazo que `RegistrosDeLasDosPartes` y `PeticionesDeLasDosPartes`,
/// y por la misma razón. Que sea el mismo número en los tres sitios no es
/// casualidad: es una sola regla.
const Duration laEsperaAlServidor = Duration(seconds: 5);

/// Cuánto se recuerda que el servidor no contestó. Ver [ElServidorNoEstaba].
const Duration loQueSeRecuerda = Duration(seconds: 10);

/// **Que no se lo pregunten una vez por cada pieza de la misma pantalla.**
///
/// El plazo solo no bastaba, y lo enseñó el dispositivo: `Ver Plan` encadena
/// macrociclo → plan → sesiones, y con el avión puesto cada una esperaba sus
/// cinco segundos. La pantalla acababa cargando entera, con su sesión de hoy
/// y todo, **a los veintitantos segundos**. Correcto y aun así inservible: a
/// pie de piscina eso es una app rota.
///
/// Así que la primera lectura que se queda sin respuesta deja constancia, y
/// durante un rato las demás van derechas a la caché. Cualquier respuesta del
/// servidor lo borra, porque entonces sí está.
///
/// Es la misma idea que `_subiendo` en `PeticionesDeLasDosPartes`: un trozo de
/// memoria chiquito para no repetir una espera que ya se sabe cómo acaba.
class ElServidorNoEstaba {
  ElServidorNoEstaba({
    this.cuantoSeRecuerda = loQueSeRecuerda,
    DateTime Function()? ahora,
  }) : _ahora = ahora ?? DateTime.now;

  final Duration cuantoSeRecuerda;
  final DateTime Function() _ahora;

  DateTime? _desdeCuando;

  /// Si hace poco no contestó, no se le vuelve a esperar.
  bool get reciente {
    final desde = _desdeCuando;
    if (desde == null) return false;
    if (_ahora().difference(desde) < cuantoSeRecuerda) return true;

    // Pasado el rato se le vuelve a dar su oportunidad.
    _desdeCuando = null;
    return false;
  }

  void apuntar() => _desdeCuando = _ahora();

  void olvidar() => _desdeCuando = null;
}

/// El que usan las lecturas de la app. Uno solo, porque el servidor es uno.
final ElServidorNoEstaba elServidorNoEstaba = ElServidorNoEstaba();

/// El servidor si contesta a tiempo; si no, lo que el dispositivo guarde.
///
/// Está separado de Firestore —dos funciones y un plazo— para que se pueda
/// probar sin red, sin emulador y sin dobles de `DocumentReference`.
Future<T> loQueHaya<T>({
  required Future<T> Function() delServidor,
  required Future<T> Function() deLaCache,
  Duration espera = laEsperaAlServidor,
  ElServidorNoEstaba? recuerdo,
}) async {
  final memoria = recuerdo ?? elServidorNoEstaba;

  if (memoria.reciente) return deLaCache();

  try {
    final suyo = await delServidor().timeout(espera);
    memoria.olvidar();
    return suyo;
  } on TimeoutException {
    memoria.apuntar();
    return deLaCache();
  }
}

/// `.leerLoQueHaya()` en lugar de `.get()`, para un documento.
extension LeerUnDocumentoSinColgarse
    on DocumentReference<Map<String, dynamic>> {
  Future<DocumentSnapshot<Map<String, dynamic>>> leerLoQueHaya({
    Duration espera = laEsperaAlServidor,
  }) => loQueHaya(
    delServidor: get,
    deLaCache: () => get(const GetOptions(source: Source.cache)),
    espera: espera,
  );
}

/// `.leerLoQueHaya()` en lugar de `.get()`, para una consulta.
///
/// Vale también para una colección entera: `CollectionReference` es una
/// `Query`.
extension LeerUnaConsultaSinColgarse on Query<Map<String, dynamic>> {
  Future<QuerySnapshot<Map<String, dynamic>>> leerLoQueHaya({
    Duration espera = laEsperaAlServidor,
  }) => loQueHaya(
    delServidor: get,
    deLaCache: () => get(const GetOptions(source: Source.cache)),
    espera: espera,
  );
}
