/// **El despertar está conectado**, y esta prueba existe porque lo contrario
/// es el defecto que la feature 011 vino a arreglar.
///
/// Lo que se arregló fue esto, dos veces:
///
/// - `Sincronizador.alVolverLaRed` tenía prueba y no tenía oyente. Nadie en
///   `lib/` lo escuchaba, durante siete features.
/// - `ProgresoEnElMacrociclo.sinContestar` tenía la regla correcta, tenía
///   pruebas que afirmaban que partía bien las sesiones pasadas, y nada en
///   `lib/` lo llamaba.
///
/// Las dos veces, algo correcto, construido, probado y **nunca conectado**. Y
/// la suite en verde todo ese tiempo, porque una prueba sobre una pieza suelta
/// no dice nada sobre si la pieza está puesta.
///
/// Así que el `Despertador` de verdad **no** es el de por omisión —eso dejaría
/// dieciséis pruebas arrancando temporizadores reales— y hay un solo sitio en
/// producción que lo pone. Esta prueba vigila ese sitio.
///
/// Se lee del fuente y no se ejecuta la pantalla: lo que se quiere fijar es
/// que la línea esté escrita, que es precisamente lo que una prueba de
/// comportamiento sobre el `Sincronizador` no puede ver.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String hub;

  setUpAll(() {
    final archivo = File('lib/ui/hub/hub.dart');
    expect(
      archivo.existsSync(),
      isTrue,
      reason: 'no se encontró lib/ui/hub/hub.dart; ¿cambió la estructura?',
    );
    hub = archivo.readAsStringSync().replaceAll('\r\n', '\n');
  });

  test('el HUB construye el Sincronizador con un despertador de verdad', () {
    expect(
      hub,
      contains('despertador: DespertadorDeReloj()'),
      reason:
          'sin esta línea la bandeja no se mira sola, y lo que ella anota sin '
          'señal solo sale cuando vuelve a abrir la app. Es la promesa de la '
          'feature 003, y estuvo siete features a medias por una línea que '
          'no estaba',
    );
  });

  test('y no con el quieto, que es el de las pruebas', () {
    expect(
      hub,
      isNot(contains('DespertadorQuieto')),
      reason:
          'el quieto existe para que la suite no arranque temporizadores '
          'reales; en producción no despierta a nadie',
    );
  });

  test('la prueba no pasa por vacía: el fuente dice lo que creemos', () {
    // Sin esto, renombrar la clase dejaría los dos `expect` de arriba
    // pasando por casualidad sobre un archivo que ya no construye nada.
    expect(hub, contains('Sincronizador('));
    expect(hub, contains('EstadoNadador('));
  });
}
