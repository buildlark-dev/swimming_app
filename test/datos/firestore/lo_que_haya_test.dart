/// `loQueHaya` acota lo que cuelga de la red **y nada más**.
///
/// Las tres mitades —que son tres— importan por igual:
///
/// - Si el servidor calla, se lee el dispositivo. Sin esto, `Ver Plan` gira
///   para siempre con el avión puesto (C1 de la feature 003).
/// - Si el servidor **rechaza**, el fallo sube. Sin esto, un
///   `permission-denied` se taparía con la caché, que no pasa por las reglas,
///   y una regla mal escrita pasaría desapercibida. El recorrido de la 009
///   encontró una de esas justo porque falló a la vista.
/// - Y si acaba de no contestar, **no se le espera otra vez**. Esto lo enseñó
///   el dispositivo y no la prueba: con el plazo puesto, `Ver Plan` cargaba
///   entera sin conexión —correcta, con su sesión de hoy— a los veintitantos
///   segundos, porque encadena tres lecturas y cada una esperaba lo suyo.
library;

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:natacion_app/datos/firestore/lo_que_haya.dart';

/// Lo que de verdad hace Firestore sin red: acepta y no contesta.
Future<String> _nuncaContesta() => Completer<String>().future;

void main() {
  const corto = Duration(milliseconds: 50);

  // Propio de cada prueba: el de la app es uno solo y se contagiarían.
  late ElServidorNoEstaba recuerdo;

  setUp(() => recuerdo = ElServidorNoEstaba());

  test('si el servidor contesta, se usa lo del servidor', () async {
    final loLeido = await loQueHaya(
      delServidor: () async => 'del servidor',
      deLaCache: () async => 'de la cache',
      espera: corto,
      recuerdo: recuerdo,
    );

    expect(loLeido, 'del servidor');
  });

  test('si el servidor calla, se lee el dispositivo', () async {
    var seMiroLaCache = false;

    // **Sin `timeout` esta prueba se colgaría**, igual que se colgó la
    // pantalla. Con él, una regresión falla en lugar de parar la suite.
    final loLeido =
        await loQueHaya(
          delServidor: _nuncaContesta,
          deLaCache: () async {
            seMiroLaCache = true;
            return 'de la cache';
          },
          espera: corto,
          recuerdo: recuerdo,
        ).timeout(
          const Duration(seconds: 2),
          onTimeout: () => fail(
            'se esperó al servidor sin fin: eso es la pantalla de una nadadora '
            'sin señal girando para siempre, que es lo que la feature 003 '
            'promete que no pasa',
          ),
        );

    expect(loLeido, 'de la cache');
    expect(seMiroLaCache, isTrue);
  });

  test('un rechazo del servidor sube y no se tapa con la caché', () async {
    // El control negativo de la mitad de arriba. Si esto cayera a la caché,
    // una regla mal escrita daría una pantalla que funciona.
    var seMiroLaCache = false;

    await expectLater(
      loQueHaya<String>(
        delServidor: () async => throw StateError('permission-denied'),
        deLaCache: () async {
          seMiroLaCache = true;
          return 'de la cache';
        },
        espera: corto,
        recuerdo: recuerdo,
      ),
      throwsStateError,
    );

    expect(
      seMiroLaCache,
      isFalse,
      reason: 'la caché no pasa por las reglas: no puede contestar un rechazo',
    );
  });

  test('lo que tarde pero llegue a tiempo no cae a la caché', () async {
    final loLeido = await loQueHaya(
      delServidor: () async {
        await Future<void>.delayed(const Duration(milliseconds: 10));
        return 'del servidor, con calma';
      },
      deLaCache: () async => fail('no se mira la caché si el servidor llega'),
      espera: corto,
      recuerdo: recuerdo,
    );

    expect(loLeido, 'del servidor, con calma');
  });

  group('cuando el servidor acaba de no contestar', () {
    test('la siguiente lectura no vuelve a esperarle', () async {
      var veces = 0;

      Future<String> leer() => loQueHaya(
        delServidor: () {
          veces++;
          return _nuncaContesta();
        },
        deLaCache: () async => 'de la cache',
        espera: corto,
        recuerdo: recuerdo,
      );

      // La primera paga el plazo. Las dos siguientes, no.
      await leer();
      final empezo = DateTime.now();
      await leer();
      await leer();
      final tardaron = DateTime.now().difference(empezo);

      expect(veces, 1, reason: 'solo la primera le preguntó');
      expect(
        tardaron,
        lessThan(corto),
        reason:
            'esto es lo que hacía que `Ver Plan` tardara medio minuto sin '
            'conexión: tres lecturas encadenadas, un plazo cada una',
      );
    });

    test('pasado el rato se le vuelve a dar su oportunidad', () async {
      var cuando = DateTime(2026, 11, 12, 6);
      final conReloj = ElServidorNoEstaba(
        cuantoSeRecuerda: const Duration(seconds: 10),
        ahora: () => cuando,
      );

      await loQueHaya(
        delServidor: _nuncaContesta,
        deLaCache: () async => 'de la cache',
        espera: corto,
        recuerdo: conReloj,
      );
      expect(conReloj.reciente, isTrue);

      cuando = cuando.add(const Duration(seconds: 11));

      expect(
        conReloj.reciente,
        isFalse,
        reason: 'volver la señal no avisa: se reintenta por sí solo',
      );
    });

    test('una respuesta del servidor borra la constancia', () async {
      await loQueHaya(
        delServidor: _nuncaContesta,
        deLaCache: () async => 'de la cache',
        espera: corto,
        recuerdo: recuerdo,
      );
      expect(recuerdo.reciente, isTrue);

      // Vuelve la señal dentro del rato: lo que manda es que contestó.
      recuerdo.olvidar();
      final loLeido = await loQueHaya(
        delServidor: () async => 'del servidor',
        deLaCache: () async => fail('contestó: no se mira la caché'),
        espera: corto,
        recuerdo: recuerdo,
      );

      expect(loLeido, 'del servidor');
      expect(recuerdo.reciente, isFalse);
    });
  });
}
