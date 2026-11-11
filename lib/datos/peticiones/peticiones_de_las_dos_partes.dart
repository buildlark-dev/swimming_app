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

import 'package:natacion_app/dominio/analisis/peticion_de_feedback.dart';
import 'package:natacion_app/dominio/repositorios/repositorios.dart';

class PeticionesDeLasDosPartes implements RepositorioPeticionesDeFeedback {
  PeticionesDeLasDosPartes({required this.local, required this.servidor});

  /// Donde ella escribe. Siempre primero.
  final RepositorioPeticionesDeFeedback local;

  /// Donde el entrenador lee. Puede no estar alcanzable.
  final RepositorioPeticionesDeFeedback servidor;

  /// Lo que no ha llegado al servidor todavía, por identificador.
  final _pendientes = <String>{};

  /// Cuáles están esperando subir. Para que la pantalla pueda decirlo.
  Set<String> get pendientes => Set.unmodifiable(_pendientes);

  @override
  Future<List<PeticionDeFeedback>> deNadador(String nadadorId) async {
    final suyas = await local.deNadador(nadadorId);

    List<PeticionDeFeedback> delServidor;
    try {
      delServidor = await servidor.deNadador(nadadorId);
    } on Object {
      // Sin servidor se lee lo que hay en el teléfono. **Lo que no se puede
      // hacer es dejarla sin su propia pregunta porque no haya señal.**
      return suyas;
    }

    return _juntar(locales: suyas, remotas: delServidor);
  }

  @override
  Future<List<PeticionDeFeedback>> deNadadorEnPlan(
    String nadadorId,
    String planId,
  ) async {
    final suyas = await local.deNadadorEnPlan(nadadorId, planId);

    List<PeticionDeFeedback> delServidor;
    try {
      delServidor = await servidor.deNadadorEnPlan(nadadorId, planId);
    } on Object {
      return suyas;
    }

    return _juntar(locales: suyas, remotas: delServidor);
  }

  @override
  Future<void> guardar(PeticionDeFeedback peticion) async {
    // Primero el dispositivo, y un fallo aquí sí se propaga.
    await local.guardar(peticion);

    _pendientes.add(peticion.id);
    await _intentar(peticion);
  }

  @override
  Future<void> marcarVista(String peticionId, DateTime cuando) =>
      servidor.marcarVista(peticionId, cuando);

  /// Sube lo que quedó pendiente. Se llama al sincronizar.
  Future<void> reenviarPendientes(String nadadorId) async {
    if (_pendientes.isEmpty) return;

    final suyas = await local.deNadador(nadadorId);

    for (final peticion in suyas) {
      if (_pendientes.contains(peticion.id)) await _intentar(peticion);
    }
  }

  Future<void> _intentar(PeticionDeFeedback peticion) async {
    try {
      await servidor.guardar(peticion);
      _pendientes.remove(peticion.id);
    } on Object {
      // Se queda pendiente. No es un fallo que ella tenga que resolver.
    }
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
