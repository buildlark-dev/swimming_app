/// Garantía H9 y SC-003 — el nombre del destino se lee entero, siempre.
///
/// **La promesa de la spec no se podía cumplir, y las cuentas lo dicen.** Cinco
/// destinos en español a 320 px dan 64 px cada uno, y «Ver Plan» necesita 100
/// con la etiqueta de 13 px que la feature 005 fijó como suelo —«no baja de
/// aquí», porque algunos de quienes leen esto tienen nueve años—. Las cinco
/// etiquetas piden 500 px: más de lo que mide cualquier teléfono, que van de
/// 320 a 430.
///
/// Así que lo que cede es la barra, no la palabra: por debajo de ese ancho la
/// barra muestra iconos y el nombre del destino va de título, entero y a tamaño
/// de lectura. Abreviar «Análisis» o encoger la letra sería decidir que el
/// vocabulario cede ante la maquetación, y en esta app es al revés.
library;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:natacion_app/dominio/cuentas/cuenta.dart';
import 'package:natacion_app/dominio/hub/destino.dart';
import 'package:natacion_app/ui/hub/hub.dart';

import 'ayuda_hub.dart';

void main() {
  Future<void> aAncho(WidgetTester tester, double ancho, Rol rol) async {
    tester.view.physicalSize = Size(ancho, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await abrirHub(tester, await montarHub(rol: rol));
  }

  /// Lo que un texto pintado necesitaría sin límites, contra lo que tiene.
  void seLeeEntero(WidgetTester tester, Finder texto, String que) {
    for (final pintado in tester.renderObjectList<RenderParagraph>(texto)) {
      final necesita = pintado.getMaxIntrinsicWidth(double.infinity);
      expect(
        pintado.size.width + 0.5,
        greaterThanOrEqualTo(necesita),
        reason:
            '«$que» necesita ${necesita.toStringAsFixed(1)} px y tiene '
            '${pintado.size.width.toStringAsFixed(1)}',
      );
    }
  }

  group('en un teléfono angosto (320 px)', () {
    for (final rol in Rol.values) {
      testWidgets('el ${rol.name} ve los cinco destinos y sabe dónde está', (
        tester,
      ) async {
        await aAncho(tester, 320, rol);

        // Los cinco siguen estando, con su icono y su tooltip.
        for (final destino in Destino.values) {
          expect(
            find.byKey(Key('destino-${destino.name}')),
            findsOneWidget,
            reason: 'Falta ${destino.etiqueta}',
          );
        }

        // Y el nombre del destino actual se lee **entero**.
        final titulo = find.byKey(Key('titulo-${Destino.home.name}'));
        expect(titulo, findsOneWidget);
        seLeeEntero(tester, titulo, Destino.home.etiqueta);
      });
    }

    testWidgets('el título cambia al cambiar de destino', (tester) async {
      await aAncho(tester, 320, Rol.entrenador);

      await tester.tap(find.byKey(Key('destino-${Destino.ajustes.name}')));
      await tester.pumpAndSettle();

      final titulo = find.byKey(Key('titulo-${Destino.ajustes.name}'));
      expect(titulo, findsOneWidget);
      seLeeEntero(tester, titulo, Destino.ajustes.etiqueta);
    });

    testWidgets('y nada desborda', (tester) async {
      await aAncho(tester, 320, Rol.nadador);
      expect(tester.takeException(), isNull);
    });
  });

  group('donde caben, se muestran', () {
    testWidgets('a $anchoParaLasEtiquetas px las cinco etiquetas, enteras', (
      tester,
    ) async {
      await aAncho(tester, anchoParaLasEtiquetas, Rol.entrenador);

      for (final destino in Destino.values) {
        final etiqueta = find.text(destino.etiqueta);
        expect(
          etiqueta,
          findsWidgets,
          reason:
              '«${destino.etiqueta}» debería caber a '
              '$anchoParaLasEtiquetas px',
        );
        seLeeEntero(tester, etiqueta, destino.etiqueta);
      }
    });

    testWidgets('y entonces el título no se repite', (tester) async {
      await aAncho(tester, anchoParaLasEtiquetas, Rol.entrenador);

      expect(
        find.byKey(Key('titulo-${Destino.home.name}')),
        findsNothing,
        reason:
            'Con la etiqueta a la vista, el título sería lo mismo dicho '
            'dos veces',
      );
    });
  });

  group('la prueba no pasa por vacía', () {
    testWidgets('la pantalla angosta es de verdad de 320 px', (tester) async {
      await aAncho(tester, 320, Rol.nadador);

      expect(tester.view.physicalSize.width, 320);
      expect(tester.getSize(find.byType(NavigationBar)).width, 320);
    });

    testWidgets('el umbral está medido, no elegido', (tester) async {
      // Una etiqueta más larga que «Generar» no caben ni en el umbral, y esta
      // prueba lo demuestra midiendo la de verdad: si alguien subiera el
      // tamaño de la letra de la barra, el umbral dejaría de ser suficiente y
      // la prueba de arriba se enteraría.
      await aAncho(tester, anchoParaLasEtiquetas, Rol.entrenador);

      final masLarga = Destino.values
          .map((d) => d.etiqueta.length)
          .reduce((a, b) => a > b ? a : b);

      expect(masLarga, greaterThanOrEqualTo('Generar'.length));
      expect(anchoParaLasEtiquetas / Destino.values.length, greaterThan(80));
    });
  });
}
