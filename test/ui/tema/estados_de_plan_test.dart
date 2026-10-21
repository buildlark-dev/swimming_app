/// SC-007 — los tres estados se reconocen sin leer la etiqueta y sin color.
///
/// Un plan pasa por borrador, aprobado y publicado, y **aprobar no es
/// entregar**. Si los dos últimos se parecen, el entrenador puede creer que
/// entregó un plan que ningún nadador ha recibido, y el nadador se queda sin
/// entrenamiento sin que nadie se entere. Es la distinción que el principio IV
/// protege.
///
/// Por eso aquí se comprueban las tres señales por separado: que el color sea
/// distinto, que el icono sea distinto, y que lo que significa esté escrito.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:natacion_app/dominio/entidades/plan.dart';
import 'package:natacion_app/ui/componentes/etiqueta_de_estado.dart';
import 'package:natacion_app/ui/tema/dominio/estados_de_plan.dart';
import 'package:natacion_app/ui/tema/tema.dart';

void main() {
  Future<void> montar(
    WidgetTester tester,
    Widget hijo, {
    bool oscuro = false,
  }) async {
    // Árbol limpio: `MaterialApp` anima el cambio de tema y un solo bombeo
    // devolvería el color anterior.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(
      MaterialApp(
        theme: oscuro ? Tema.oscuro() : Tema.claro(),
        home: Scaffold(body: hijo),
      ),
    );
    await tester.pump();
  }

  group('cada estado tiene su propio icono', () {
    test('los tres son distintos', () {
      final iconos =
          EstadoPlan.values.map(EstadosDePlan.iconoDe).toSet();

      expect(
        iconos,
        hasLength(EstadoPlan.values.length),
        reason: 'Dos estados con el mismo icono se distinguirían solo por el '
            'color, y en escala de grises no se distinguirían en absoluto',
      );
    });

    test('aprobado y publicado no comparten icono', () {
      // Es el par que de verdad importa. El borrador se reconoce solo.
      expect(
        EstadosDePlan.iconoDe(EstadoPlan.aprobado),
        isNot(EstadosDePlan.iconoDe(EstadoPlan.publicado)),
      );
    });
  });

  group('cada estado tiene su propio color, en los dos modos', () {
    for (final oscuro in [false, true]) {
      testWidgets(oscuro ? 'en oscuro' : 'en claro', (tester) async {
        final colores = <EstadoPlan, Color>{};

        for (final estado in EstadoPlan.values) {
          late Color color;
          await montar(
            tester,
            Builder(
              builder: (context) {
                color = EstadosDePlan.colorDe(context, estado);
                return const SizedBox.shrink();
              },
            ),
            oscuro: oscuro,
          );
          colores[estado] = color;
        }

        expect(colores.values.toSet(), hasLength(EstadoPlan.values.length));
      });
    }
  });

  group('lo que significa está escrito, no solo pintado', () {
    test('los tres explican qué son', () {
      for (final estado in EstadoPlan.values) {
        expect(EstadosDePlan.explicacionDe(estado), isNotEmpty);
      }
    });

    test('aprobado dice que todavía no se ha entregado', () {
      // Sin esto, «aprobado» suena a terminado. La palabra que falta es la que
      // evita que el entrenador dé por hecho que el nadador ya lo tiene.
      expect(
        EstadosDePlan.explicacionDe(EstadoPlan.aprobado).toLowerCase(),
        contains('entregar'),
      );
    });

    test('las tres explicaciones son distintas', () {
      expect(
        EstadoPlan.values.map(EstadosDePlan.explicacionDe).toSet(),
        hasLength(EstadoPlan.values.length),
      );
    });
  });

  group('la etiqueta enseña las tres señales', () {
    testWidgets('el nombre, el icono y el color', (tester) async {
      await montar(
        tester,
        const EtiquetaDeEstado(estado: EstadoPlan.aprobado),
      );

      expect(find.text(EstadoPlan.aprobado.nombre), findsOneWidget);
      expect(
        tester.widget<Icon>(find.byType(Icon)).icon,
        EstadosDePlan.iconoDe(EstadoPlan.aprobado),
      );
    });

    testWidgets('con explicación, dice qué significa', (tester) async {
      await montar(
        tester,
        const EtiquetaDeEstado(
          estado: EstadoPlan.aprobado,
          conExplicacion: true,
        ),
      );

      expect(
        find.text(EstadosDePlan.explicacionDe(EstadoPlan.aprobado)),
        findsOneWidget,
      );
    });

    testWidgets('los tres estados se montan sin romperse', (tester) async {
      for (final estado in EstadoPlan.values) {
        for (final oscuro in [false, true]) {
          await montar(
            tester,
            EtiquetaDeEstado(estado: estado, conExplicacion: true),
            oscuro: oscuro,
          );
          expect(tester.takeException(), isNull);
        }
      }
    });
  });

  group('la prueba no pasa por vacía', () {
    test('hay exactamente tres estados', () {
      // Si la metodología añadiera uno, esto se entera antes que la pantalla.
      expect(EstadoPlan.values, hasLength(3));
      expect(
        EstadoPlan.values.map((e) => e.nombre).toList(),
        ['Borrador', 'Aprobado', 'Publicado'],
      );
    });
  });
}
