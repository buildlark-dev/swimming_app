/// M13 a M17 y C8 — lo que el entrenador revisa, firma y entrega.
///
/// La pantalla tiene que mantener separados dos actos que es tentador juntar en
/// un botón, porque juntarlos borraría la distinción que la feature 001
/// estableció: **firmar no es entregar**. Y tiene que hacer cada uno de ellos
/// **una sola vez** por muchos mesociclos que haya (M15, M16).
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:natacion_app/dominio/entidades/plan.dart';

import 'ayuda_macrociclo.dart';

void main() {
  late RepositoriosDelMacrociclo repos;

  setUp(() {
    repos = RepositoriosDelMacrociclo();
  });

  Future<void> abrir(WidgetTester tester, {VoidCallback? alEntregar}) async {
    conPantallaAlta(tester);
    final guardado = await macrocicloGuardado(repos);
    await tester.pumpWidget(
      montarRevision(
        repos: repos,
        guardado: guardado,
        alEntregar: alEntregar,
      ),
    );
    await tester.pumpAndSettle();
  }

  group('lo que se le enseña antes de firmar', () {
    testWidgets('el macrociclo entero, contado', (tester) async {
      await abrir(tester);

      final resumen = tester
          .widget<Text>(find.byKey(const Key('resumen-del-macrociclo')))
          .data!;

      expect(resumen, contains('3 mesociclos'));
      expect(resumen, contains('14 microciclos'));
      expect(resumen, contains('sesiones'));
    });

    testWidgets('lo que él confirmó, tal como lo escribió', (tester) async {
      // Se le enseña su propio texto y no un resumen: es el registro de lo que
      // decidió, y va a firmar sobre eso.
      await abrir(tester);

      expect(
        tester
            .widget<Text>(find.byKey(const Key('modelo-de-la-prueba')))
            .data!,
        contains('umbral alto'),
      );
      expect(
        tester
            .widget<Text>(find.byKey(const Key('modelo-del-nadador')))
            .data!,
        contains('agarre'),
      );
    });

    testWidgets('la versión de metodología de cada nivel (FR-013)', (
      tester,
    ) async {
      // El 100% de los niveles la registra, y se puede ver sin abrir la base
      // de datos: si solo estuviera guardada, nadie comprobaría SC-002.
      await abrir(tester);

      expect(
        tester
            .widget<Text>(find.byKey(const Key('version-del-macrociclo')))
            .data!,
        contains('3.6.0'),
      );
      for (var i = 0; i < 3; i++) {
        expect(
          tester.widget<Text>(find.byKey(Key('version-mesociclo-$i'))).data!,
          contains('3.6.0'),
          reason: 'el mesociclo $i no enseña su versión de metodología',
        );
      }
    });

    testWidgets('cada mesociclo con sus números y su auditoría', (
      tester,
    ) async {
      await abrir(tester);

      for (var i = 0; i < 3; i++) {
        expect(find.byKey(Key('resumen-mesociclo-$i')), findsOneWidget);
        expect(find.byKey(Key('auditoria-mesociclo-$i')), findsOneWidget);
      }
    });

    testWidgets('la auditoría se puede abrir y es la de la sección 16', (
      tester,
    ) async {
      await abrir(tester);

      await tester.tap(find.byKey(const Key('auditoria-mesociclo-0')));
      await tester.pumpAndSettle();

      expect(find.textContaining('Auditoría de la sección 16'), findsWidgets);
    });
  });

  group('firmar es un acto (M15)', () {
    testWidgets('un botón, y los tres mesociclos quedan firmados', (
      tester,
    ) async {
      await abrir(tester);

      await tester.ensureVisible(
        find.byKey(const Key('firmar-el-macrociclo')),
      );
      await tester.tap(find.byKey(const Key('firmar-el-macrociclo')));
      await tester.pumpAndSettle();

      for (final mesociclo in await repos.planes.listar()) {
        expect(mesociclo.estado, EstadoPlan.aprobado);
      }
    });

    testWidgets('no hay un segundo botón de firmar por mesociclo', (
      tester,
    ) async {
      // Si hubiera uno por mesociclo, la enmienda de la constitución v2.0.0 se
      // habría cumplido en la letra —una confirmación de estructura— y no en
      // el fondo.
      await abrir(tester);

      expect(find.byKey(const Key('firmar-el-macrociclo')), findsOneWidget);
      // Un solo botón en toda la pantalla. El texto «Firmar» aparece dos
      // veces a propósito —en el botón y en la frase que explica qué hace—,
      // así que lo que se cuenta son botones, no palabras.
      expect(find.byType(FilledButton), findsOneWidget);
    });
  });

  group('firmar no es entregar (M17)', () {
    testWidgets('antes de firmar no se ofrece entregar', (tester) async {
      await abrir(tester);

      expect(find.byKey(const Key('entregar-el-macrociclo')), findsNothing);
    });

    testWidgets('al firmar, el nadador todavía no tiene nada', (tester) async {
      await abrir(tester);

      await tester.ensureVisible(
        find.byKey(const Key('firmar-el-macrociclo')),
      );
      await tester.tap(find.byKey(const Key('firmar-el-macrociclo')));
      await tester.pumpAndSettle();

      expect(await repos.asignaciones.deNadador('n-ana'), isEmpty);
      // Y ahora sí se ofrece el segundo acto.
      expect(find.byKey(const Key('entregar-el-macrociclo')), findsOneWidget);
    });

    testWidgets('y la pantalla lo dice antes de que lo descubra', (
      tester,
    ) async {
      await abrir(tester);

      expect(find.textContaining('Firmar no es entregar'), findsOneWidget);
    });
  });

  group('entregar es un acto y es todo (M16)', () {
    testWidgets('entregar asigna los tres mesociclos', (tester) async {
      var aviso = 0;
      await abrir(tester, alEntregar: () => aviso++);

      await tester.ensureVisible(
        find.byKey(const Key('firmar-el-macrociclo')),
      );
      await tester.tap(find.byKey(const Key('firmar-el-macrociclo')));
      await tester.pumpAndSettle();

      await tester.ensureVisible(
        find.byKey(const Key('entregar-el-macrociclo')),
      );
      await tester.tap(find.byKey(const Key('entregar-el-macrociclo')));
      await tester.pumpAndSettle();

      expect(await repos.asignaciones.deNadador('n-ana'), hasLength(3));
      for (final mesociclo in await repos.planes.listar()) {
        expect(mesociclo.estado, EstadoPlan.publicado);
      }
      expect(aviso, 1, reason: 'se avisó más de una vez de una sola entrega');
    });

    testWidgets('y al terminar se dice que ya lo ve', (tester) async {
      await abrir(tester);

      await tester.ensureVisible(
        find.byKey(const Key('firmar-el-macrociclo')),
      );
      await tester.tap(find.byKey(const Key('firmar-el-macrociclo')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const Key('entregar-el-macrociclo')),
      );
      await tester.tap(find.byKey(const Key('entregar-el-macrociclo')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('ya-entregado')), findsOneWidget);
      expect(find.byKey(const Key('entregar-el-macrociclo')), findsNothing);
    });
  });
}
