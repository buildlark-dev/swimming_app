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

  testWidgets('y sin nadie a quien reintentar, no revienta', (tester) async {
    await montarPeticion(tester, nadadorId: null, ficha: null);

    expect(find.byKey(const Key('peticion-sin-ficha')), findsOneWidget);
  });
}
