/// Cuándo volver a intentarlo.
///
/// **Se inyecta por la misma razón que el reloj.** Las ocho garantías del
/// contrato de sincronización se prueban en Dart puro, sin emulador y sin que
/// pase un segundo de reloj real; una feature que trata de esperar no puede
/// hacer esperar a la suite.
///
/// Es una interfaz de una sola cosa a propósito: programar un despertar y
/// cancelarlo. La bandeja no sabe si debajo hay un `Timer`, un plan de trabajo
/// del sistema o una prueba moviendo el reloj a mano, y no tiene por qué.
///
/// Feature 011, decisión D6.
library;

import 'dart:async';

abstract class Despertador {
  /// Despierta dentro de [dentroDe] y ejecuta [queHacer].
  ///
  /// **Sustituye a lo que hubiera programado antes.** Solo hay un despertar
  /// vivo: el de la siguiente vez que toque mirar la bandeja. Acumularlos sería
  /// el bucle apretado que el contrato prohíbe.
  void programar(Duration dentroDe, Future<void> Function() queHacer);

  /// Cancela lo programado, si había algo. Idempotente.
  void cancelar();
}

/// El que no despierta a nadie, y es **el de por omisión**.
///
/// Parece al revés y no lo es. Hay un solo sitio en producción que construye
/// un `Sincronizador` —`hub.dart`— y dieciséis en las pruebas. Si el de verdad
/// fuera el de por omisión, cada una de esas dieciséis arrancaría un `Timer`
/// real que se reprograma solo y la suite no terminaría nunca; lo comprobamos
/// por las malas al escribir esto.
///
/// Y dejarlo por omisión tampoco haría la feature más segura: lo que la hace
/// segura es que `hub.dart` lo ponga a la vista, con una prueba que lo vigila
/// —`el_despertar_esta_cableado_test.dart`—, porque «construido, probado y
/// nunca conectado» es exactamente el defecto que esta feature vino a
/// arreglar y no es cosa de repetirlo aquí dentro.
class DespertadorQuieto implements Despertador {
  const DespertadorQuieto();

  @override
  void programar(Duration dentroDe, Future<void> Function() queHacer) {}

  @override
  void cancelar() {}
}

/// El de verdad: un `Timer`.
class DespertadorDeReloj implements Despertador {
  Timer? _timer;

  @override
  void programar(Duration dentroDe, Future<void> Function() queHacer) {
    _timer?.cancel();
    // **No se espera a `queHacer`.** Es la misma regla que en toda esta parte
    // del producto: lo que cuelga de la red no bloquea a nadie, y aquí no hay
    // nadie a quien bloquear porque esto ocurre solo.
    _timer = Timer(dentroDe, () => unawaited(queHacer()));
  }

  @override
  void cancelar() {
    _timer?.cancel();
    _timer = null;
  }
}
