/// Si hay red, para saber cuándo reintentar.
///
/// Implementa `EstadoDeRed` del dominio, que la bandeja de salida usa sin saber
/// cómo se detecta nada (principio II).
///
/// **La detección es deliberadamente tonta**: se intenta una escritura y se ve
/// si llega. No se consulta ningún servicio de conectividad del sistema, porque
/// «el teléfono dice que hay wifi» y «el servidor responde» son cosas distintas,
/// y a pie de piscina la segunda es la que importa. Una piscina con wifi que no
/// sale a internet es el caso normal, no el raro.
///
/// ## Lo que decía y lo que hacía (feature 011, decisión D1)
///
/// El párrafo de arriba está aquí desde la feature 003. Lo que se cableó
/// debajo, en `main.dart`, fue esto:
///
/// ```dart
/// red: RedPorSondeo(sondear: () async => datos != null),
/// ```
///
/// Que pregunta si Firestore se inicializó. Es cierto con el modo avión puesto,
/// y es cierto para siempre, así que el valor no cambiaba nunca, así que
/// `cambios` no emitía nunca, así que el disparador «al volver la red» no podía
/// saltar — y encima nadie lo escuchaba. Dos fallos independientes, cualquiera
/// de los dos bastaba para romper la promesa.
///
/// Ahora hace lo que el párrafo dice: **la red es lo que dijo el último
/// intento**. No hay sondeo aparte porque no hace falta ninguno; el intento de
/// enviar, que ya ocurre y que desde la feature 010 tiene plazo, es la única
/// respuesta verdadera a la pregunta, y además prueba el camino entero hasta el
/// servidor en vez del primer salto fuera del teléfono.
library;

import 'dart:async';

import 'package:natacion_app/dominio/repositorios/repositorios.dart';

class RedSegunElUltimoIntento implements EstadoDeRed {
  final StreamController<bool> _cambios = StreamController<bool>.broadcast();

  /// Nulo mientras nadie haya intentado nada todavía.
  bool? _ultimoConocido;

  /// **Optimista antes del primer intento.**
  ///
  /// Un pesimista no dejaría salir el primer envío, y el primer envío es lo
  /// único capaz de contestar la pregunta. Empezar diciendo «no hay red» sería
  /// garantizar que nunca se averigua si la hay.
  @override
  Future<bool> hayConexion() async => _ultimoConocido ?? true;

  @override
  Stream<bool> get cambios => _cambios.stream;

  /// Lo que pasó al intentar enviar algo. Lo llama la bandeja de salida.
  ///
  /// No está en la interfaz del dominio a propósito: la bandeja recibe esto
  /// como un `alIntentar` que puede ser nulo, y así los once dobles de las
  /// pruebas que implementan `EstadoDeRed` no tienen que escribir un método
  /// que ignoran. En Dart, `implements` obliga a implementar un miembro
  /// aunque traiga cuerpo, así que no había forma de añadirlo sin tocarlos.
  void anotarIntento({required bool llego}) {
    // Emite **solo cuando cambia**: tres fallos seguidos son una sola noticia,
    // no tres.
    if (_ultimoConocido == llego) return;
    _ultimoConocido = llego;
    if (!_cambios.isClosed) _cambios.add(llego);
  }

  /// Cierra el stream. La interfaz del dominio no lo declara porque esto es un
  /// detalle de esta implementación.
  Future<void> cerrar() async {
    if (!_cambios.isClosed) await _cambios.close();
  }
}
