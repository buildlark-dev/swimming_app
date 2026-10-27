/// Garantías H5, H6, H8, H17 y H18 — el recorrido del entrenador.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:natacion_app/dominio/cuentas/cuenta.dart';
import 'package:natacion_app/dominio/entidades/plan.dart';
import 'package:natacion_app/dominio/hub/destino.dart';

import 'ayuda_hub.dart';

void main() {
  group('la barra', () {
    testWidgets('H1 — ve los cinco destinos, en el mismo orden', (
      tester,
    ) async {
      await abrirHub(tester, await montarHub(rol: Rol.entrenador));

      for (final destino in Destino.values) {
        expect(find.text(destino.etiqueta), findsWidgets);
      }
    });

    testWidgets('H3 — y aterriza en Home, igual que el nadador', (
      tester,
    ) async {
      await abrirHub(tester, await montarHub(rol: Rol.entrenador));

      expect(find.byKey(const Key('home-entrenador')), findsOneWidget);
    });
  });

  group('H6 — nada del recorrido del nadador', () {
    testWidgets('ni su sesión del día, ni su progreso', (tester) async {
      await abrirHub(
        tester,
        await montarHub(
          rol: Rol.entrenador,
          planes: [planDePrueba()],
          asignaciones: [asignacionDePrueba()],
        ),
      );

      for (final destino in Destino.values) {
        await tester.tap(find.text(destino.etiqueta).last);
        await tester.pumpAndSettle();

        for (final delNadador in [
          '¿Cómo te sentiste?',
          'Marcar como hecha',
          'Mi progreso',
        ]) {
          expect(
            find.text(delNadador),
            findsNothing,
            reason:
                '«$delNadador» apareció en ${destino.etiqueta}, y es del '
                'nadador',
          );
        }
      }
    });
  });

  group('H17 — los cuatro números', () {
    testWidgets('cada uno dice de qué es', (tester) async {
      await abrirHub(
        tester,
        await montarHub(
          rol: Rol.entrenador,
          planes: [
            planDePrueba(),
            planDePrueba(id: 'p2', estado: EstadoPlan.aprobado),
          ],
          asignaciones: [asignacionDePrueba()],
          registros: [registroDePrueba(sesionId: 's0', realizada: true)],
        ),
      );

      expect(find.byKey(const Key('numero-planes')), findsOneWidget);
      expect(find.byKey(const Key('numero-en-uso')), findsOneWidget);
      expect(find.byKey(const Key('numero-esperando')), findsOneWidget);
      expect(find.byKey(const Key('numero-sin-asignar')), findsOneWidget);
    });

    testWidgets('«en uso» cuenta el plano que alguien tocó', (tester) async {
      await abrirHub(
        tester,
        await montarHub(
          rol: Rol.entrenador,
          planes: [planDePrueba()],
          asignaciones: [asignacionDePrueba()],
          registros: [registroDePrueba(sesionId: 's0', realizada: true)],
        ),
      );

      expect(
        tester.widget<Text>(find.byKey(const Key('numero-en-uso'))).data,
        '1',
      );
    });

    testWidgets('y no cuenta el asignado que nadie ha tocado', (tester) async {
      await abrirHub(
        tester,
        await montarHub(
          rol: Rol.entrenador,
          planes: [planDePrueba()],
          asignaciones: [asignacionDePrueba()],
        ),
      );

      expect(
        tester.widget<Text>(find.byKey(const Key('numero-en-uso'))).data,
        '0',
      );
    });

    testWidgets('sin ningún plan, dice por dónde empezar', (tester) async {
      await abrirHub(tester, await montarHub(rol: Rol.entrenador));

      expect(find.byKey(const Key('home-sin-nada')), findsOneWidget);
    });
  });

  group('H18 — contar no es aprobar', () {
    testWidgets('en Home no hay nada que firme ni publique', (tester) async {
      await abrirHub(
        tester,
        await montarHub(
          rol: Rol.entrenador,
          planes: [planDePrueba(id: 'p2', estado: EstadoPlan.aprobado)],
        ),
      );

      for (final accion in ['Aprobar', 'Firmar', 'Publicar', 'Entregar']) {
        expect(
          find.text(accion),
          findsNothing,
          reason: '$accion no va en Home',
        );
      }
    });
  });

  group('H9 — su Generar lleva el generador y el editor', () {
    testWidgets('los dos, en el mismo destino', (tester) async {
      await abrirHub(tester, await montarHub(rol: Rol.entrenador));

      await tester.tap(find.text(Destino.generar.etiqueta).last);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('generar-del-entrenador')), findsOneWidget);
    });
  });

  group('H11 — su Análisis todavía no', () {
    testWidgets('dice qué llegará, y sin controles', (tester) async {
      await abrirHub(tester, await montarHub(rol: Rol.entrenador));

      await tester.tap(find.text(Destino.analisis.etiqueta).last);
      await tester.pumpAndSettle();

      final vacio = find.byKey(const Key('todavia-no'));
      expect(vacio, findsOneWidget);
      expect(find.textContaining('tus nadadores'), findsWidgets);
      expect(
        find.descendant(of: vacio, matching: find.byType(FilledButton)),
        findsNothing,
      );
    });
  });

  group('H8 — el estado sobrevive al cambio de destino', () {
    testWidgets('lo escrito en el editor sigue ahí al volver', (tester) async {
      await abrirHub(tester, await montarHub(rol: Rol.entrenador));

      await tester.tap(find.text(Destino.generar.etiqueta).last);
      await tester.pumpAndSettle();

      final campos = find.byType(TextField);
      expect(campos, findsWidgets, reason: 'El editor tiene campos');

      await tester.enterText(campos.first, "4x100 AL SNK PN / 2'");
      await tester.pumpAndSettle();

      await tester.tap(find.text(Destino.home.etiqueta).last);
      await tester.pumpAndSettle();
      await tester.tap(find.text(Destino.generar.etiqueta).last);
      await tester.pumpAndSettle();

      expect(find.text("4x100 AL SNK PN / 2'"), findsWidgets);
    });
  });
}
