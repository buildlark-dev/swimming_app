/// La puerta: si lo de este nadador puede salir del dispositivo.
///
/// Una sola pregunta, y a propósito. Lo que esta interfaz permite es que la
/// retención se pruebe **entera en Dart puro**, con un doble, igual que ya se
/// hace con el reloj y con la red.
///
/// **Esta no es la puerta que protege.** Quien la hace cumplir son las reglas
/// de acceso de Firestore, en el servidor (decisión D1). Esta existe para no
/// enviar lo que va a rebotar y para poder explicárselo al nadador: una puerta
/// que solo comprueba el cliente no es una puerta.
library;

abstract class PuertaDeConsentimiento {
  /// Si los datos de este nadador pueden salir hacia el entrenador.
  ///
  /// **Tiene que poder responder sin red.** Un nadador a pie de piscina no
  /// puede quedarse sin poder anotar porque no se sepa si consintió; la
  /// implementación se apoya en la caché, y ante la duda retiene en lugar de
  /// enviar.
  Future<bool> puedeSalir(String nadadorId);
}

/// Una puerta que siempre deja pasar.
///
/// Para el modo local sin servidor, donde no hay consentimiento que consultar
/// porque tampoco hay adónde enviar nada. **No se usa con un servidor
/// detrás**: ahí la puerta de verdad son las reglas, y ésta solo haría que la
/// app intentara envíos que el servidor va a rechazar.
class PuertaAbierta implements PuertaDeConsentimiento {
  const PuertaAbierta();

  @override
  Future<bool> puedeSalir(String nadadorId) async => true;
}
