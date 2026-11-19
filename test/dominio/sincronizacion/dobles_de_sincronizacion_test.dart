/// El cerrojo **sobre el doble**, que es donde empieza todo lo demás.
///
/// Toda esta feature descansa en que `TransporteMudo` se cuelgue de verdad. Si
/// alguien lo «arregla» más adelante para que lance —que es lo cómodo, y lo
/// que hace cualquier doble escrito sin esta cicatriz—, cuatro cerrojos de la
/// feature 011 pasan a verde sin comprobar nada y nadie se entera.
///
/// Ya pasó tres veces en este proyecto, en tres recorridos distintos. Esta
/// prueba es la que impide la cuarta.
library;

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'dobles_de_sincronizacion.dart';

void main() {
  test('el transporte mudo acepta y NO contesta', () async {
    final transporte = TransporteMudo();

    var contesto = false;
    unawaited(transporte.enviar(unRegistro()).then((_) => contesto = true));

    // Varios turnos del bucle de eventos: si fuera a contestar, ya lo habría
    // hecho. Un `await` solo no distingue «tarda» de «no contesta nunca».
    for (var i = 0; i < 5; i++) {
      await Future<void>.delayed(Duration.zero);
    }

    expect(
      contesto,
      isFalse,
      reason:
          'el doble contestó: si el doble contesta o lanza donde Firestore se '
          'cuelga, los cerrojos de esta feature dejan de probar lo único que '
          'tienen que probar',
    );
    expect(transporte.intentos, 1, reason: 'aceptó: lo registró como intento');
    expect(transporte.colgados, 1, reason: 'y lo dejó en el aire');
  });

  test('cuando se le dice, contesta lo que dejó colgado', () async {
    final transporte = TransporteMudo();

    DateTime? cuando;
    unawaited(transporte.enviar(unRegistro()).then((h) => cuando = h));
    await Future<void>.delayed(Duration.zero);
    expect(cuando, isNull);

    transporte.contestaLoQueQuedoColgado();
    await Future<void>.delayed(Duration.zero);

    expect(
      cuando,
      isNotNull,
      reason: 'es el éxito tardío: la escritura que el plazo dejó de esperar',
    );
    expect(transporte.colgados, 0);
  });

  test('con `lanza` puesto deja de colgarse: es el control negativo', () async {
    // Esta es la forma cómoda y equivocada. Existe aquí para poder encenderla
    // a propósito y ver qué cerrojos dejan de probar algo.
    final transporte = TransporteMudo()..lanza = true;

    await expectLater(transporte.enviar(unRegistro()), throwsException);
    expect(transporte.colgados, 0);
  });

  group('el reloj y el despertador son el mismo tiempo', () {
    test('no dispara nada antes de que toque', () async {
      final reloj = RelojDeMentira();
      var despertares = 0;

      reloj.programar(const Duration(seconds: 60), () async => despertares++);
      await reloj.avanzar(const Duration(seconds: 59));

      expect(despertares, 0);
      expect(reloj.hayAlgoProgramado, isTrue);
    });

    test('dispara al llegar, y se espera a que termine', () async {
      final reloj = RelojDeMentira();
      var despertares = 0;

      reloj.programar(const Duration(seconds: 60), () async {
        await Future<void>.delayed(Duration.zero);
        despertares++;
      });
      await reloj.avanzar(const Duration(seconds: 60));

      expect(despertares, 1, reason: 'avanzar espera: la prueba no adivina');
      expect(reloj.hayAlgoProgramado, isFalse);
    });

    test('dispara varios por el camino, en orden', () async {
      final reloj = RelojDeMentira();
      final momentos = <DateTime>[];

      void volverAProgramar() {
        reloj.programar(const Duration(seconds: 10), () async {
          momentos.add(reloj.ahora);
          volverAProgramar();
        });
      }

      volverAProgramar();
      await reloj.avanzar(const Duration(seconds: 35));

      expect(momentos, hasLength(3), reason: '10, 20 y 30 segundos');
      expect(momentos.first.isBefore(momentos.last), isTrue);
    });

    test('programar sustituye lo anterior: solo hay un despertar vivo', () {
      final reloj = RelojDeMentira();

      reloj.programar(const Duration(seconds: 60), () async {});
      final primero = reloj.proximoDespertar;
      reloj.programar(const Duration(seconds: 5), () async {});

      expect(reloj.proximoDespertar, isNot(primero));
      expect(
        reloj.proximoDespertar,
        reloj.ahora.add(const Duration(seconds: 5)),
        reason: 'acumularlos sería el bucle apretado que el contrato prohíbe',
      );
    });

    test('cancelar deja el tiempo sin nada programado', () async {
      final reloj = RelojDeMentira();
      var despertares = 0;

      reloj.programar(const Duration(seconds: 1), () async => despertares++);
      reloj.cancelar();
      await reloj.avanzar(const Duration(hours: 1));

      expect(despertares, 0);
      expect(reloj.hayAlgoProgramado, isFalse);
    });
  });
}
