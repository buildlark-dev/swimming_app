/// Los registros del nadador, leídos **de su teléfono y del servidor**.
///
/// **Esto faltaba, y lo encontró el recorrido de la feature 009.** La pantalla
/// del macrociclo recibía `RegistrosLocales`, así que lo que el nadador ve
/// —«Sesiones cumplidas: 2 de 10»— salía solo del almacén de ese dispositivo.
/// El servidor lo tenía: desde la feature 003 los registros se envían y
/// `RegistrosFirestore` sabe leerlos. Nadie los leía para él.
///
/// Se notaba en el sitio peor: cambiar de móvil o reinstalar dejaba su cuenta
/// en cero, con el dato a salvo en el servidor, justo debajo de una frase que
/// le dice «Lo que ya habías anotado sigue ahí».
///
/// **Escribir no cambia.** Anotar sigue yendo al dispositivo y encolándose
/// después (garantía G1 de la feature 003): a pie de piscina no se espera a la
/// red, y eso no se toca. Lo que cambia es leer.
library;

import 'package:natacion_app/dominio/entidades/registro_sesion.dart';
import 'package:natacion_app/dominio/repositorios/repositorios.dart';

class RegistrosDeLasDosPartes implements RepositorioRegistros {
  const RegistrosDeLasDosPartes({
    required this.local,
    required this.servidor,
    this.esperaAlServidor = loQueSeEsperaAlServidor,
  });

  /// Lo que se le da al servidor para contestar antes de leer el teléfono.
  ///
  /// **Un fallo se atrapa; un Future que no vuelve, no.** El SDK de Firestore
  /// no lanza cuando no hay red: deja la lectura abierta. Con el avión puesto y
  /// la app recién abierta, `Ver Plan` se quedaba girando para siempre — ni
  /// error ni contenido— y eso es exactamente lo que el escenario C1 de la
  /// feature 003, «el que justifica la feature», dice que no puede pasar.
  ///
  /// Cinco segundos y lo del teléfono, que está entero.
  static const Duration loQueSeEsperaAlServidor = Duration(seconds: 5);

  /// El almacén de este teléfono. **Manda.**
  final RepositorioRegistros local;

  /// Lo que el servidor guarda de él, de este y de cualquier otro aparato.
  final RepositorioRegistros servidor;

  /// Lo que espera esta instancia. Las pruebas la acortan.
  final Duration esperaAlServidor;

  /// Lo que el servidor tenga, **sin que un fallo cueste la pantalla**.
  ///
  /// Sin red se devuelve lo local y no se nota. Lo contrario sería dejarle sin
  /// su plan por un problema de cobertura, que es justo lo que la garantía A8
  /// de la feature 003 prohíbe.
  ///
  /// **Cualquier fallo, no solo `FalloDeDatos`.** Esto atrapaba únicamente ese,
  /// y el recorrido de la 010 encontró por qué importa: un `TypeError` al
  /// deserializar un documento se escapaba, la lectura no terminaba nunca, y la
  /// pantalla de la nadadora se quedaba diciendo «0 de 39» con su respuesta ya
  /// en el servidor. Una frase que dice «sin que un fallo cueste la pantalla»
  /// tiene que cubrir los fallos que nadie previó, que son los que la cuestan.
  ///
  /// Aquí se puede, y en la lectura del entrenador no: lo suyo es lo local, que
  /// es su última palabra y está entero. Él no tiene copia local de lo de ella,
  /// así que su `Análisis` **sí** hace subir el fallo (FR-008).
  /// **Y acotado**, que es la otra mitad. Ver `esperaAlServidor`.
  Future<List<RegistroDeSesion>> _delServidor(
    Future<List<RegistroDeSesion>> Function() pedir,
  ) async {
    try {
      return await pedir().timeout(esperaAlServidor);
    } on Object {
      return const [];
    }
  }

  @override
  Future<RegistroDeSesion?> obtener(String registroId) async {
    // Lo local primero: si está, es su última palabra.
    final suyo = await local.obtener(registroId);
    if (suyo != null) return suyo;

    try {
      return await servidor.obtener(registroId).timeout(esperaAlServidor);
    } on Object {
      // Acotado y para cualquier fallo, por lo mismo que `_delServidor`: sin
      // red el SDK no lanza, se queda esperando.
      return null;
    }
  }

  @override
  Future<List<RegistroDeSesion>> obtenerDePlan(
    String nadadorId,
    String planId,
  ) async {
    final delServidor = await _delServidor(
      () => servidor.obtenerDePlan(nadadorId, planId),
    );
    final deAqui = await local.obtenerDePlan(nadadorId, planId);

    // **Gana lo local, y por eso se pone después.** Lo que todavía no se ha
    // enviado es lo más reciente que él escribió; si mandara el servidor,
    // vería cómo una respuesta recién puesta vuelve atrás sola.
    final porId = <String, RegistroDeSesion>{
      for (final registro in delServidor) registro.id: registro,
      for (final registro in deAqui) registro.id: registro,
    };

    return List.unmodifiable(porId.values);
  }

  /// **Al dispositivo y a nadie más** (garantía G1).
  ///
  /// Mandar al servidor desde aquí haría que anotar dependiera de la red. De
  /// eso se encarga la bandeja de salida, después y por su cuenta.
  @override
  Future<void> guardar(RegistroDeSesion registro) => local.guardar(registro);

  @override
  Future<Map<String, dynamic>> exportar(String nadadorId) =>
      local.exportar(nadadorId);

  /// **Solo el dispositivo, y es deliberado.**
  ///
  /// `firestore.rules`: «un registro no se borra desde el cliente. El derecho
  /// al borrado del principio V se ejerce por la vía del servidor, que puede
  /// dejar constancia de que se ejerció». Juntar las dos lecturas no puede
  /// abrir esa puerta por la espalda.
  @override
  Future<void> eliminarDe(String nadadorId) => local.eliminarDe(nadadorId);

  @override
  Future<Set<String>> nadadoresConRegistros() => local.nadadoresConRegistros();
}
