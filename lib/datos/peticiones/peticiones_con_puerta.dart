/// Las peticiones, pasando por la puerta de consentimiento.
///
/// **No es un tercer camino para salir del dispositivo.** Es el mismo que la
/// feature 003 montó para los registros del nadador: se pregunta a la puerta
/// de la feature 004 y, si no puede salir, se retiene en el almacén local
/// hasta que pueda. Montar otro mecanismo para esto duplicaría uno que ya
/// funciona y ya está probado (principio VII).
///
/// **Lo retenido no es un estado nuevo.** Fue la decisión D6 de la feature
/// 003: una petición retenida por falta de consentimiento *es* una petición
/// pendiente. Lo que se guarda aquí es lo que el nadador respondió, tal cual,
/// para que al autorizarse salga **sin volver a escribirlo** (FR-031).
///
/// Vive en la capa de datos y no en el dominio porque compone tres cosas de
/// esta capa —el repositorio del servidor, la puerta y el almacén— y no añade
/// ninguna regla de entrenamiento.
library;

import 'package:natacion_app/datos/local/almacen_local.dart';
import 'package:natacion_app/dominio/consentimiento/puerta.dart';
import 'package:natacion_app/dominio/peticiones/peticion.dart';
import 'package:natacion_app/dominio/repositorios/repositorios.dart';

/// Dónde se retiene lo que no pudo salir.
const String coleccionDeLoRetenido = 'peticionRetenida';

class PeticionesConPuerta implements RepositorioPeticiones {
  PeticionesConPuerta({
    required this.servidor,
    required this.puerta,
    required this.almacen,
    DateTime Function()? ahora,
  }) : _ahora = ahora ?? DateTime.now;

  final RepositorioPeticiones servidor;
  final PuertaDeConsentimiento puerta;
  final AlmacenLocal almacen;

  final DateTime Function() _ahora;

  @override
  Future<void> enviar({
    required String nadadorId,
    required RespuestasDePeticion respuestas,
  }) async {
    // Se guarda **antes** de intentar mandarla. Si el envío sale bien se
    // borra; si no, ya está a salvo. Al revés habría una ventana en la que lo
    // respondido no está ni aquí ni allá.
    await _retener(nadadorId, respuestas);

    if (!await puerta.puedeSalir(nadadorId)) return;

    try {
      await servidor.enviar(nadadorId: nadadorId, respuestas: respuestas);
      await almacen.borrar(coleccionDeLoRetenido, nadadorId);
    } catch (_) {
      // Lo que no salió por la red se queda retenido igual que lo que no salió
      // por la puerta. La bandeja no distingue: lo que no salió, no salió.
    }
  }

  /// Intenta mandar lo retenido. Se llama cuando algo pudo cambiar: al volver
  /// a abrir la pantalla, o cuando el acudiente autoriza.
  Future<void> reintentarLoRetenido(String nadadorId) async {
    final retenida = await _loRetenido(nadadorId);
    if (retenida == null) return;

    if (!await puerta.puedeSalir(nadadorId)) return;

    try {
      await servidor.enviar(nadadorId: nadadorId, respuestas: retenida);
      await almacen.borrar(coleccionDeLoRetenido, nadadorId);
    } catch (_) {
      // Sigue retenida. No se pierde.
    }
  }

  /// Si hay algo esperando a poder salir, para poder decirlo.
  Future<bool> estaRetenida(String nadadorId) async =>
      await _loRetenido(nadadorId) != null;

  @override
  Future<PeticionDePlan?> miPeticion(String nadadorId) async {
    // **Lo del servidor manda.** Si allí ya hay una petición, es la que lleva
    // el estado y la respuesta del entrenador; lo retenido sería una copia
    // vieja de lo mismo.
    try {
      final delServidor = await servidor.miPeticion(nadadorId);
      if (delServidor != null) return delServidor;
    } catch (_) {
      // Sin red se mira lo que hay en el dispositivo, que es lo que esta app
      // hace en todas partes.
    }

    final retenida = await _loRetenido(nadadorId);
    if (retenida == null) return null;

    // Se presenta como lo que es: una petición esperando. Para quien la mandó,
    // «esperando a tu entrenador» y «esperando a que tu acudiente autorice»
    // son dos cosas distintas, y la pantalla lo dice; el estado no.
    return PeticionDePlan(
      nadadorId: nadadorId,
      enviadaEn: _ahora(),
      respuestas: retenida,
      estado: EstadoDePeticion.esperando,
    );
  }

  @override
  Future<List<PeticionDePlan>> cola() => servidor.cola();

  @override
  Future<void> marcarEnRevision(String nadadorId) =>
      servidor.marcarEnRevision(nadadorId);

  Future<void> _retener(String nadadorId, RespuestasDePeticion respuestas) =>
      almacen.escribir(coleccionDeLoRetenido, nadadorId, respuestas.toJson());

  Future<RespuestasDePeticion?> _loRetenido(String nadadorId) async {
    try {
      final guardado = await almacen.leer(coleccionDeLoRetenido, nadadorId);
      return guardado == null
          ? null
          : RespuestasDePeticion.desdeJson(guardado);
    } catch (_) {
      // Un almacén que no se puede leer no es una petición retenida.
      return null;
    }
  }
}
