/// Garantía V7 — la app aguanta el texto al 200%.
///
/// **No es un caso extremo.** Hay quien lleva el teléfono así siempre, porque
/// de otro modo no lee; y el sistema operativo lo ofrece precisamente para eso.
/// Una app que se rompe cuando el usuario agranda la letra está diciéndole que
/// use otra cosa.
///
/// Lo que se mide es el desbordamiento: un `Row` que no cabe, una `Column` que
/// se sale de su caja. Flutter lo grita en tiempo de pintado, y en una prueba
/// de widget ese grito es una excepción que se puede atrapar. Es exactamente lo
/// que cazó los 27 píxeles de los desplegables en la fase 2.
///
/// Se mide en un teléfono **pequeño**, 360 por 640, que es donde duele. Si cabe
/// ahí, cabe en todo lo demás.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:natacion_app/ui/tema/tema.dart';

import 'ayuda_pantallas.dart';

void main() {
  /// Un teléfono barato, que es el que hay.
  const telefono = Size(360, 640);

  Widget enTelefono(Widget pantalla, {required double escala, required ThemeData tema}) {
    return MediaQuery(
      data: MediaQueryData(
        size: telefono,
        textScaler: TextScaler.linear(escala),
      ),
      child: MaterialApp(
        theme: tema,
        home: pantalla,
      ),
    );
  }

  Future<void> montar(
    WidgetTester tester,
    PantallaMedible pantalla, {
    required double escala,
    required ThemeData tema,
  }) async {
    tester.view.physicalSize = telefono;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      enTelefono(pantalla.construir(), escala: escala, tema: tema),
    );
    // Dos bombeos: el primero pinta, el segundo deja asentar lo que carga de
    // un repositorio. Las pantallas que listan algo llegan vacías al primero.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  group('V7 — al 200%, nada se desborda', () {
    for (final pantalla in pantallasDeLaApp()) {
      testWidgets('${pantalla.nombre}, en claro', (tester) async {
        await montar(tester, pantalla, escala: 2.0, tema: Tema.claro());

        expect(
          tester.takeException(),
          isNull,
          reason: 'La pantalla «${pantalla.nombre}» se rompe con la letra al '
              '200%. No se arregla encogiendo el texto: se arregla dejando '
              'que lo que no cabe en una línea baje a la siguiente',
        );
      });
    }
  });

  group('V7 — y al 130%, que es lo que de verdad usa la gente', () {
    for (final pantalla in pantallasDeLaApp()) {
      testWidgets(pantalla.nombre, (tester) async {
        await montar(tester, pantalla, escala: 1.3, tema: Tema.claro());

        expect(tester.takeException(), isNull);
      });
    }
  });

  group('la prueba no pasa por vacía', () {
    testWidgets('el desbordamiento sí se detecta', (tester) async {
      // Si esto no fallara, todo lo de arriba sería decorativo: una prueba que
      // no sabe reconocer un desbordamiento aprueba cualquier cosa.
      tester.view.physicalSize = telefono;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        const MediaQuery(
          data: MediaQueryData(size: telefono),
          child: MaterialApp(
            home: Scaffold(
              body: Row(
                children: [
                  SizedBox(width: 500, height: 10),
                  SizedBox(width: 500, height: 10),
                ],
              ),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNotNull);
    });

    test('se mide algo, y son todas las pantallas', () {
      expect(pantallasDeLaApp().length, greaterThanOrEqualTo(7));
    });
  });
}
