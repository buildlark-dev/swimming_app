/// Garantía P39 — que el cliente y el servidor hablen de lo mismo al cerrar
/// una petición.
///
/// Mismo método que los contratos de las features 006 y 007, y por la misma
/// razón: **los dobles implementan la interfaz de Dart, no el cable**. Diez
/// pruebas del camino del acudiente pasaban en verde mientras el cuerpo iba
/// mal formado, porque el doble aceptaba lo que el servidor rechazaba.
///
/// Esta prueba lee el fuente de TypeScript y compara los nombres de campo con
/// los que el cliente escribe. No prueba que el servidor haga lo correcto
/// —eso es `firebase/functions/test/peticiones.test.js`, contra el emulador—:
/// prueba que los dos estén hablando el mismo idioma.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:natacion_app/datos/servidor/operaciones.dart';

void main() {
  final ruta = File('firebase/functions/src/peticiones.ts');

  group('la prueba no pasa por vacía', () {
    test('el fuente del servidor existe', () {
      expect(
        ruta.existsSync(),
        isTrue,
        reason:
            'Sin este archivo no hay nada que comprobar, y el contrato '
            'pasaría en verde sin servidor',
      );
    });
  });

  final servidor = ruta.existsSync() ? ruta.readAsStringSync() : '';

  group('cerrarPeticion — el cuerpo que se manda es el que se lee', () {
    final aprobacion = cuerpoDeCierre(
      nadadorId: 'n-ana',
      decision: 'aprobada',
      planId: 'p-1',
    );

    final rechazo = cuerpoDeCierre(
      nadadorId: 'n-ana',
      decision: 'rechazada',
      motivo: 'Pediste cinco días y en Precompetitivo son tres.',
    );

    test('el cuerpo es plano, sin anidar', () {
      // El fallo exacto de la feature 006: el cliente mandaba plano y el
      // servidor desempaquetaba anidado.
      for (final cuerpo in [aprobacion, rechazo]) {
        for (final valor in cuerpo.values) {
          expect(
            valor,
            isNot(isA<Map<String, dynamic>>()),
            reason: 'Ningún campo de este cuerpo es un objeto anidado',
          );
        }
      }
    });

    test('cada campo que manda el cliente lo lee el servidor', () {
      for (final campo in {...aprobacion.keys, ...rechazo.keys}) {
        expect(
          servidor,
          contains("'$campo'"),
          reason:
              'El cliente manda «$campo» y el servidor no lo nombra en '
              'ninguna parte',
        );
      }
    });

    test('la aprobación lleva el plan y ningún motivo', () {
      expect(aprobacion['planId'], 'p-1');
      expect(
        aprobacion.containsKey('motivo') ? aprobacion['motivo'] : null,
        isNull,
        reason: 'Una aprobación con motivo de rechazo no tiene sentido',
      );
    });

    test('el rechazo lleva el motivo y ningún plan', () {
      expect(rechazo['motivo'], isNotEmpty);
      expect(
        rechazo.containsKey('planId') ? rechazo['planId'] : null,
        isNull,
      );
    });

    test('la decisión es exactamente «aprobada» o «rechazada»', () {
      // Si el cliente mandara «aprobado» en masculino o «approved», el
      // servidor lo rechazaría y la petición se quedaría abierta para siempre.
      expect(aprobacion['decision'], 'aprobada');
      expect(rechazo['decision'], 'rechazada');

      for (final valor in ['aprobada', 'rechazada']) {
        expect(
          servidor,
          contains("'$valor'"),
          reason: 'El servidor tiene que reconocer «$valor» tal cual',
        );
      }
    });
  });

  group('lo que el servidor escribe, y el cliente no', () {
    test('el estado, la fecha de respuesta y el archivado son suyos', () {
      // P13: un cliente que puede escribir su propio estado puede aprobarse su
      // propia petición. Estos tres campos no salen nunca del dispositivo.
      final cuerpo = cuerpoDeCierre(
        nadadorId: 'n-ana',
        decision: 'aprobada',
        planId: 'p-1',
      );

      for (final delServidor in ['estado', 'respondidaEn', 'enviadaEn']) {
        expect(
          cuerpo.keys,
          isNot(contains(delServidor)),
          reason: '«$delServidor» lo pone el servidor, no el cliente',
        );
      }
    });

    test('y el servidor sí los nombra', () {
      for (final delServidor in ['estado', 'respondidaEn', 'historial']) {
        expect(servidor, contains(delServidor));
      }
    });
  });

  group('el disparador escribe lo que el dispositivo no puede', () {
    // **Lo encontró el recorrido del quickstart, no una prueba.** El documento
    // de una petición recién mandada tenía solo `nadadorId` y `respuestas`:
    // las reglas impiden que el cliente escriba nada más, y no había nadie
    // poniendo el estado ni la fecha. La app funcionaba —el lector da
    // `esperando` por omisión y la fecha de ahora—, y por eso nadie lo habría
    // visto: la cola habría enseñado «ahora» para algo mandado hace tres días.
    test('hay un disparador para las peticiones nuevas', () {
      expect(servidor, contains('onDocumentCreated'));
      expect(servidor, contains('alLlegarUnaPeticion'));
    });

    test('y estampa la fecha con el reloj del servidor', () {
      expect(
        servidor,
        contains('serverTimestamp'),
        reason:
            'El reloj de un teléfono es lo que su dueño haya puesto, y cuándo '
            'se mandó una petición es un hecho',
      );
    });
  });

  group('la llamada se llama igual en los dos lados', () {
    test('cerrarPeticion está exportada en el servidor', () {
      expect(servidor, contains('cerrarPeticion'));
    });

    test('y el índice la publica', () {
      final indice = File('firebase/functions/src/index.ts');
      expect(indice.readAsStringSync(), contains('cerrarPeticion'));
    });
  });
}
