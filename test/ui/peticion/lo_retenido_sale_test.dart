/// Garantía P10 y FR-031 — lo retenido sale en cuanto se puede.
///
/// **Lo encontró el recorrido del quickstart.** `reintentarLoRetenido` estaba
/// escrito y probado en `PeticionesConPuerta`, y **nadie lo llamaba**: el
/// acudiente autorizaba y la solicitud se quedaba en el teléfono para
/// siempre. Un requisito implementado y desconectado es un requisito
/// incumplido, y este protege a un menor.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'ayuda_peticion.dart';

void main() {
  testWidgets('al abrir la pantalla se reintenta lo que quedó retenido', (
    tester,
  ) async {
    final reintentos = <String>[];

    await montarPeticion(tester, reintentos: reintentos);

    expect(
      reintentos,
      contains('n-ana'),
      reason:
          'Abrir la pantalla es el momento en que algo pudo cambiar: puede '
          'que el acudiente ya haya autorizado',
    );
  });

  testWidgets('y el nadador puede pedir que se intente, sin esperar', (
    tester,
  ) async {
    // **Lo encontró el Pixel 7.** En el navegador bastaba recargar la página;
    // en un teléfono no hay recarga, y ni cambiar de destino ni reiniciar la
    // app soltaban lo retenido: la puerta lee el consentimiento de la caché
    // de Firestore, que sigue diciendo que no hay, y retiene —como debe—. El
    // aviso prometía «en cuanto autorice, sale sola» y no se cumplía.
    final reintentos = <String>[];

    await montarPeticion(tester, retenida: true, reintentos: reintentos);

    await tester.tap(find.byKey(const Key('enviar-peticion')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('falta-la-autorizacion')), findsOneWidget);

    reintentos.clear();
    await tester.tap(find.byKey(const Key('ya-autorizo-mi-acudiente')));
    await tester.pumpAndSettle();

    expect(reintentos, contains('n-ana'));
  });

  testWidgets('y sin nadie a quien reintentar, no revienta', (tester) async {
    await montarPeticion(tester, nadadorId: null, ficha: null);

    expect(find.byKey(const Key('peticion-sin-ficha')), findsOneWidget);
  });
}
