/// FR-008 — las cifras de la notación no bailan.
///
/// `4x100 / 1'40"` es una **instrucción de entrenamiento**, no decoración. Con
/// cifras de ancho variable el 1 ocupa menos que el 8, las columnas se desplazan
/// de línea a línea, y leer mal una cifra cambia lo que el nadador hace en el
/// agua.
///
/// Esta prueba existe porque la tabulación es invisible: nadie se da cuenta de
/// que falta hasta que mira dos series una debajo de otra y nota que algo no
/// cuadra. Una `copyWith` descuidada la quita sin avisar.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:natacion_app/ui/tema/tipografia.dart';

import 'ayuda_pantallas.dart';

void main() {
  bool esTabular(TextStyle? estilo) =>
      estilo?.fontFeatures?.any((f) => f.feature == 'tnum') ?? false;

  group('el estilo de notación', () {
    test('pone las cifras de ancho fijo', () {
      expect(esTabular(Tipografia.notacion(const TextStyle())), isTrue);
    });

    test('conserva lo que traía el estilo base', () {
      // Si `notacion` perdiera el tamaño o el color, aplicarla a una pantalla
      // la dejaría con la letra por omisión y nadie lo notaría hasta verla.
      final base = const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)
          .copyWith(color: const Color(0xFF123456));
      final conCifras = Tipografia.notacion(base);

      expect(conCifras.fontSize, 15);
      expect(conCifras.fontWeight, FontWeight.bold);
      expect(conCifras.color, const Color(0xFF123456));
    });
  });

  group('donde se muestran series, las cifras son tabulares', () {
    testWidgets('la sesión del día del nadador', (tester) async {
      // Es el sitio donde más importa: lo que el nadador lee con el teléfono
      // mojado, antes de meterse al agua.
      final pantalla = pantallasDeLaApp()
          .firstWhere((p) => p.nombre == 'sesión del día');

      await tester.pumpWidget(
        MaterialApp(home: pantalla.construir()),
      );
      await tester.pump();

      final notacion = tester.widgetList<SelectableText>(
        find.byType(SelectableText),
      );

      expect(
        notacion,
        isNotEmpty,
        reason: 'Si no hay notación en pantalla, esta prueba no mide nada',
      );
      for (final texto in notacion) {
        expect(
          esTabular(texto.style),
          isTrue,
          reason: 'La serie «${texto.data}» se muestra sin cifras tabulares',
        );
      }
    });
  });
}
