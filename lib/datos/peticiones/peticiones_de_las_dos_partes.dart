/// Las peticiones de feedback, **del dispositivo y del servidor**.
///
/// Es la misma forma que `RegistrosDeLasDosPartes` de la feature 009, con una
/// diferencia que importa: aquí **no gana todo lo local**.
///
/// La pregunta la escribe ella y vive primero en su teléfono. El `vistaEn` lo
/// escribe el entrenador y vive **solo en el servidor**: es el único campo de
/// este documento que ella no escribe. Así que al juntar las dos copias, la
/// pregunta sale de la local y el «la vi» del servidor. Si ganara lo local, él
/// podría marcarla vista cien veces y ella no se enteraría nunca.
///
/// Y el envío:
///
/// - `guardar` escribe **primero en el dispositivo** y después intenta el
///   servidor. Un fallo de red no sube: la petición queda apuntada como
///   pendiente y se reintenta (garantía G1, FR-016). Un fallo de **escritura
///   local** sí sube, porque ahí el dato se perdería (garantía S8).
/// - `reenviarPendientes` sube lo que no llegó. Solo lo pendiente, y no todo
///   lo local: reenviar una petición que el entrenador ya vio **le borraría el
///   `vistaEn`**, porque la copia del teléfono no lo lleva. Esa es la razón de
///   que haya una lista de pendientes en lugar de un reenvío de todo.
///
/// `marcarVista` va **solo al servidor**: es la escritura del entrenador y su
/// dispositivo no tiene copia local de las peticiones de ella.
library;

import 'package:flutter/foundation.dart';

import 'package:natacion_app/dominio/analisis/peticion_de_feedback.dart';
import 'package:natacion_app/dominio/repositorios/repositorios.dart';

class PeticionesDeLasDosPartes implements RepositorioPeticionesDeFeedback {
  PeticionesDeLasDosPartes({
    required this.local,
    required this.servidor,
    Duration? esperaAlServidor,
  }) : esperaAlServidor = esperaAlServidor ?? loQueSeEsperaAlServidor;

  /// Donde ella escribe. Siempre primero.
  final RepositorioPeticionesDeFeedback local;

  /// Donde el entrenador lee. Puede no estar alcanzable.
  final RepositorioPeticionesDeFeedback servidor;

  /// Lo que no ha llegado al servidor todavía, por identificador.
  final _pendientes = <String>{};

  /// Cuáles están esperando subir. Para que la pantalla pueda decirlo.
  Set<String> get pendientes => Set.unmodifiable(_pendientes);

  /// Lo que el servidor tarde en contestar antes de que se lea el teléfono.
  ///
  /// Sin esto, una lectura se cuelga igual que se colgaba la escritura: el SDK
  /// de Firestore no lanza cuando no hay red, se queda esperando. Y su
  /// historial está entero en el teléfono, así que esperar indefinidamente por
  /// el `vistaEn` —lo único que el servidor añade— sería cambiar su pantalla
  /// por un campo.
  static const Duration loQueSeEsperaAlServidor = Duration(seconds: 5);

  /// Lo que espera esta instancia. Las pruebas la acortan.
  final Duration esperaAlServidor;

  /// Pide al servidor **sin colgarse**: lo que no llegue a tiempo se da por no
  /// llegado y se lee el teléfono.
  Future<List<PeticionDeFeedback>?> _siContesta(
    Future<List<PeticionDeFeedback>> Function() pedir,
  ) async {
    try {
      return await pedir().timeout(esperaAlServidor);
    } on Object {
      return null;
    }
  }

  @override
  Future<List<PeticionDeFeedback>> deNadador(String nadadorId) async {
    final suyas = await local.deNadador(nadadorId);

    // Sin servidor se lee lo que hay en el teléfono. **Lo que no se puede
    // hacer es dejarla sin su propia pregunta porque no haya señal.**
    final delServidor = await _siContesta(() => servidor.deNadador(nadadorId));
    if (delServidor == null) return suyas;

    return _juntar(locales: suyas, remotas: delServidor);
  }

  @override
  Future<List<PeticionDeFeedback>> deNadadorEnPlan(
    String nadadorId,
    String planId,
  ) async {
    final suyas = await local.deNadadorEnPlan(nadadorId, planId);

    final delServidor = await _siContesta(
      () => servidor.deNadadorEnPlan(nadadorId, planId),
    );
    if (delServidor == null) return suyas;

    return _juntar(locales: suyas, remotas: delServidor);
  }

  @override
  Future<void> guardar(PeticionDeFeedback peticion) async {
    // Primero el dispositivo, y un fallo aquí sí se propaga.
    await local.guardar(peticion);

    _pendientes.add(peticion.id);

    // **Y el intento no se espera.** Es la garantía G1 y el defecto que el
    // recorrido de la 010 encontró en el Pixel 7 con el avión activado: el SDK
    // de Firestore acepta el `set()` en su cola y **no completa el Future
    // hasta que el servidor confirme**, sin lanzar nada. Esperarlo dejaba
    // `pedirFeedback` sin volver y la pantalla muda, que para ella es que la
    // app no hizo nada.
    //
    // La prueba no lo vio porque el doble lanzaba donde Firestore se cuelga.
    // La lección vieja con una vuelta más: el doble tiene que **volver donde
    // el servidor se quedaría colgado**, no solo rechazar lo que rechaza.
    _intentar(peticion);
  }

  @override
  Future<void> marcarVista(String peticionId, DateTime cuando) =>
      servidor.marcarVista(peticionId, cuando);

  /// Sube lo que quedó pendiente. Se llama al sincronizar.
  ///
  /// Tampoco espera: lanza los intentos y vuelve.
  Future<void> reenviarPendientes(String nadadorId) async {
    if (_pendientes.isEmpty) return;

    final suyas = await local.deNadador(nadadorId);

    for (final peticion in suyas) {
      if (_pendientes.contains(peticion.id)) _intentar(peticion);
    }
  }

  /// Los que están subiendo ahora mismo.
  ///
  /// Sin esto, cada sincronización apilaría otra escritura esperando sobre la
  /// misma petición. Con el identificador determinista no duplicaría nada en
  /// el servidor, pero el teléfono acabaría con una pila de Futures abiertos
  /// que no sirven de nada.
  final _subiendo = <String, Future<void>>{};

  /// Lo que está subiendo ahora mismo, para que una prueba pueda esperarlo.
  ///
  /// La pantalla no lo necesita: lo que ella ve es su copia local, y la marca
  /// de pendiente. Esto existe porque un envío que no se espera no se puede
  /// comprobar de otra manera que esperándolo a propósito.
  @visibleForTesting
  Future<void> cuandoTerminenLosEnvios() =>
      Future.wait(_subiendo.values.toList());
  void _intentar(PeticionDeFeedback peticion) {
    if (_subiendo.containsKey(peticion.id)) return;

    _subiendo[peticion.id] = servidor
        .guardar(peticion)
        .then(
          (_) => _pendientes.remove(peticion.id),
          // Se queda pendiente. No es un fallo que ella tenga que resolver.
          onError: (_) {},
        )
        .whenComplete(() => _subiendo.remove(peticion.id));
  }

  /// La pregunta de la copia local; el «la vi», del servidor.
  List<PeticionDeFeedback> _juntar({
    required List<PeticionDeFeedback> locales,
    required List<PeticionDeFeedback> remotas,
  }) {
    final vistoEn = <String, DateTime>{
      for (final remota in remotas)
        if (remota.vistaEn != null) remota.id: remota.vistaEn!,
    };

    final juntas = <String, PeticionDeFeedback>{
      // Las que solo están en el servidor también son suyas: cambió de
      // teléfono, o reinstaló.
      for (final remota in remotas) remota.id: remota,
    };

    for (final suya in locales) {
      final cuando = vistoEn[suya.id];
      juntas[suya.id] = cuando == null ? suya : suya.vistaPor(cuando);
    }

    return List.unmodifiable(juntas.values);
  }
}
