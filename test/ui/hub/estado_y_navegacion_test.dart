/// Garantías H8 y H10 — el estado que sobrevive, y el botón de atrás.
///
/// Las dos son del HUB y no de ninguna pantalla, así que se comprueban aquí.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:natacion_app/dominio/cuentas/cuenta.dart';
import 'package:natacion_app/dominio/hub/destino.dart';

import 'ayuda_hub.dart';

void main() {
  Future<void> irA(WidgetTester tester, Destino destino) async {
    await tester.tap(find.byKey(Key('destino-${destino.name}')));
    await tester.pumpAndSettle();
  }

  int destinoActual(WidgetTester tester) =>
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex;

  group('H8 — cambiar de destino no borra lo escrito', () {
    testWidgets('la respuesta a medio escribir del nadador sigue ahí', (
      tester,
    ) async {
      await abrirHub(
        tester,
        await montarHub(
          rol: Rol.nadador,
          planes: [planDePrueba()],
          asignaciones: [asignacionDePrueba()],
        ),
      );

      await irA(tester, Destino.verPlan);

      final campos = find.byType(TextField);
      expect(campos, findsWidgets, reason: 'Tiene dónde escribir');

      await tester.enterText(campos.last, 'Me dolió el hombro derecho');
      await tester.pumpAndSettle();

      await irA(tester, Destino.home);
      await irA(tester, Destino.verPlan);

      expect(
        find.text('Me dolió el hombro derecho'),
        findsOneWidget,
        reason:
            'Lo que un nadador escribió a pie de piscina no se pierde '
            'porque tocara otra pestaña',
      );
    });
  });

  group('FR-009 — el editor no es otro destino', () {
    testWidgets('pasar al editor no mueve la barra', (tester) async {
      await abrirHub(tester, await montarHub(rol: Rol.entrenador));

      await irA(tester, Destino.generar);
      expect(destinoActual(tester), Destino.generar.posicion);

      await tester.tap(find.text('Editor'));
      await tester.pumpAndSettle();

      expect(
        destinoActual(tester),
        Destino.generar.posicion,
        reason:
            'El editor vive dentro de «Generar» para que un plan recién '
            'generado se revise sin cambiar de destino',
      );
      expect(find.text('Editor de sesión'), findsWidgets);
    });

    testWidgets('y volver al generador tampoco', (tester) async {
      await abrirHub(tester, await montarHub(rol: Rol.entrenador));

      await irA(tester, Destino.generar);
      await tester.tap(find.text('Editor'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Generador'));
      await tester.pumpAndSettle();

      expect(destinoActual(tester), Destino.generar.posicion);
      expect(find.text('Generar microciclo'), findsWidgets);
    });
  });

  group('H10 — atrás lleva a Home', () {
    testWidgets('desde cualquier otro destino', (tester) async {
      await abrirHub(tester, await montarHub(rol: Rol.entrenador));

      await irA(tester, Destino.ajustes);
      expect(destinoActual(tester), Destino.ajustes.posicion);

      final pagina = tester
          .widgetList(find.byWidgetPredicate((w) => w is PopScope))
          .whereType<PopScope<Object?>>()
          .single;
      expect(
        pagina.canPop,
        isFalse,
        reason: 'Fuera de Home, atrás no sale de la app',
      );

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(destinoActual(tester), Destino.home.posicion);
    });

    testWidgets('y desde Home sí sale de la app', (tester) async {
      await abrirHub(tester, await montarHub(rol: Rol.entrenador));

      expect(destinoActual(tester), Destino.home.posicion);

      final pagina = tester
          .widgetList(find.byWidgetPredicate((w) => w is PopScope))
          .whereType<PopScope<Object?>>()
          .single;
      expect(pagina.canPop, isTrue);
    });
  });
}
