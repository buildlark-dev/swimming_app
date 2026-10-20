/// Garantía V6 — lo que se toca se acierta a la primera.
///
/// Un dedo mojado al borde de la piscina no acierta un objetivo pequeño, y a
/// veces el dedo es el de un niño de nueve años con un teléfono prestado. El
/// icono puede ser chico; **el área que responde, no**.
///
/// No se mide a ojo: Flutter trae la comprobación hecha sobre el árbol de
/// semántica, que es el mismo que usa el sistema operativo para saber dónde
/// se puede tocar. `androidTapTargetGuideline` exige 48 por 48, que es
/// exactamente lo que dice `Espaciado.areaPulsableMinima` y la razón por la que
/// dice 48 y no 44.
library;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:natacion_app/ui/tema/espaciado.dart';
import 'package:natacion_app/ui/tema/tema.dart';

import 'ayuda_pantallas.dart';

void main() {
  const telefono = Size(360, 640);

  Future<void> montar(WidgetTester tester, PantallaMedible pantalla) async {
    tester.view.physicalSize = telefono;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(size: telefono),
        child: MaterialApp(
          theme: Tema.claro(),
          home: pantalla.construir(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  group('V6 — toda área sensible alcanza el mínimo', () {
    for (final pantalla in pantallasDeLaApp()) {
      testWidgets(pantalla.nombre, (tester) async {
        await montar(tester, pantalla);

        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      });
    }
  });

  group('el mínimo lo pone el tema, no cada pantalla', () {
    test('la medida es 48, y vive en un solo sitio', () {
      // Si alguien la baja a 44 porque «es lo que dice la otra norma», esto
      // falla y le cuenta por qué este proyecto pide más.
      expect(
        Espaciado.areaPulsableMinima,
        48,
        reason: 'Un dedo mojado, y a veces el de un niño de nueve años. '
            'La medida de la norma mínima no es la medida de esta app',
      );
    });

    test('los cuatro tipos de botón la llevan fijada desde el tema', () {
      // Fijado una vez aquí para que ninguna pantalla tenga que acordarse. Si
      // uno se queda sin estilo, sus botones vuelven al tamaño de Material.
      for (final tema in [Tema.claro(), Tema.oscuro()]) {
        final minimos = <String, Size?>{
          'relleno': tema.filledButtonTheme.style?.minimumSize?.resolve({}),
          'texto': tema.textButtonTheme.style?.minimumSize?.resolve({}),
          'contorno': tema.outlinedButtonTheme.style?.minimumSize?.resolve({}),
          'icono': tema.iconButtonTheme.style?.minimumSize?.resolve({}),
        };

        minimos.forEach((cual, medida) {
          expect(
            medida?.height,
            Espaciado.areaPulsableMinima,
            reason: 'El botón de $cual no lleva el mínimo del tema',
          );
        });
      }
    });

    test('el relleno de área pulsable está activado', () {
      // Es lo que hace que un icono de 24 siga respondiendo en 48.
      for (final tema in [Tema.claro(), Tema.oscuro()]) {
        expect(tema.materialTapTargetSize, MaterialTapTargetSize.padded);
      }
    });
  });

  group('la prueba no pasa por vacía', () {
    testWidgets('un objetivo pequeño sí se detecta', (tester) async {
      // `meetsGuideline` no devuelve falso: **lanza**. Así que el control
      // negativo no se escribe con `isNot`, se escribe atrapando el fallo. Sin
      // esto, un día la comprobación de arriba deja de medir y nadie lo nota.
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: GestureDetector(
                  onTap: () {},
                  child: const ColoredBox(color: Color(0xFF000000)),
                ),
              ),
            ),
          ),
        ),
      );

      Object? fallo;
      try {
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      } on TestFailure catch (e) {
        fallo = e;
      }

      expect(
        fallo,
        isNotNull,
        reason: 'Un objetivo de 20 por 20 tiene que suspender. Si pasa, la '
            'comprobación de las pantallas no está midiendo nada',
      );
    });

    testWidgets('en las pantallas sí hay algo que tocar', (tester) async {
      // Una pantalla sin nada pulsable aprueba la garantía V6 por vacía. Esto
      // comprueba que en la primera que se mide hay objetivos de verdad.
      final handle = tester.ensureSemantics();
      await montar(tester, pantallasDeLaApp().first);

      var pulsables = 0;
      void contar(SemanticsNode nodo) {
        if (nodo.getSemanticsData().hasAction(SemanticsAction.tap)) {
          pulsables++;
        }
        nodo.visitChildren((hijo) {
          contar(hijo);
          return true;
        });
      }

      contar(tester.binding.rootElement!.renderObject!.debugSemantics!);
      handle.dispose();

      expect(pulsables, greaterThan(0));
    });
  });
}
