/// M2, M3, M5, M6, M7 y C1 a C3, C6, C7 — la pantalla de la confirmación.
///
/// Es la pantalla donde la enmienda de la constitución v2.0.0 se cumple o no
/// se cumple. Las pruebas de aquí son las que distinguen «una propuesta» de
/// «una decisión con un botón»:
///
/// - cada parte del esqueleto se puede cambiar (M3); si alguna estuviera fija,
///   la app habría decidido la forma de una temporada;
/// - cada bloque dice **por qué** salió así (M2);
/// - lo que se sale de lo publicado avisa y **no impide generar** (M5);
/// - con la ficha incompleta se dice qué falta en lugar de proponer sobre
///   huecos (M7).
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:natacion_app/dominio/entidades/nadador.dart';
import 'package:natacion_app/dominio/metodologia/categorias.dart';
import 'package:natacion_app/dominio/metodologia/estilos.dart';

import 'ayuda_macrociclo.dart';

void main() {
  late RepositoriosDelMacrociclo repos;

  setUp(() {
    repos = RepositoriosDelMacrociclo();
  });

  Future<void> abrir(
    WidgetTester tester, {
    Nadador ficha = fichaCompleta,
  }) async {
    conPantallaAlta(tester);
    await tester.pumpWidget(montarEstructura(repos: repos, ficha: ficha));
    await tester.pumpAndSettle();
  }

  group('C1 — el esqueleto se propone, con su razón', () {
    testWidgets('con la fecha puesta salen tres bloques', (tester) async {
      await abrir(tester);
      await elegirLaFecha(tester);

      expect(find.byKey(const Key('por-que-bloque-0')), findsOneWidget);
      expect(find.byKey(const Key('por-que-bloque-1')), findsOneWidget);
      expect(find.byKey(const Key('por-que-bloque-2')), findsOneWidget);
    });

    testWidgets('y cada uno dice por qué, en semanas', (tester) async {
      await abrir(tester);
      await elegirLaFecha(tester);

      for (var i = 0; i < 3; i++) {
        final razon = tester
            .widget<Text>(find.byKey(Key('por-que-bloque-$i')))
            .data!;
        expect(razon, contains('semana'));
      }
    });

    testWidgets('sin fecha no hay esqueleto, y se dice', (tester) async {
      // No es una pantalla en blanco: la razón explica que la fecha es el
      // ancla y que va primero.
      await abrir(tester);

      final porQue = tester
          .widget<Text>(find.byKey(const Key('por-que-el-esqueleto')))
          .data!;
      expect(porQue, contains('fecha'));
      expect(find.byKey(const Key('por-que-bloque-0')), findsNothing);
    });

    testWidgets('no es un plan terminado: no hay nada que firmar', (
      tester,
    ) async {
      await abrir(tester);
      await elegirLaFecha(tester);

      expect(find.text('Firmar el macrociclo'), findsNothing);
    });
  });

  group('C2 — y es editable (M3)', () {
    testWidgets('se puede cambiar las semanas de un bloque', (tester) async {
      await abrir(tester);
      await elegirLaFecha(tester);

      final antes = tester
          .widget<Text>(find.byKey(const Key('por-que-bloque-2')))
          .data!;

      // El último bloque: Realización, dos semanas. Se pone a cuatro.
      await tester.ensureVisible(find.byKey(const Key('por-que-bloque-2')));
      await tester.tap(find.text('2 semanas').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('4 semanas').last);
      await tester.pumpAndSettle();

      final despues = tester
          .widget<Text>(find.byKey(const Key('por-que-bloque-2')))
          .data!;

      expect(despues, isNot(antes));
      expect(despues, contains('4 semanas'));
    });

    testWidgets('la razón pasa a decir que las puso él', (tester) async {
      // Si siguiera diciendo «las últimas 2 semanas antes de la competencia»
      // con cuatro semanas puestas por él, la app se estaría atribuyendo una
      // decisión suya.
      await abrir(tester);
      await elegirLaFecha(tester);

      await tester.ensureVisible(find.byKey(const Key('por-que-bloque-2')));
      await tester.tap(find.text('2 semanas').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('4 semanas').last);
      await tester.pumpAndSettle();

      expect(
        tester.widget<Text>(find.byKey(const Key('por-que-bloque-2'))).data!,
        contains('entrenador'),
      );
    });

    testWidgets('se puede quitar un bloque', (tester) async {
      await abrir(tester);
      await elegirLaFecha(tester);

      await tester.ensureVisible(find.byKey(const Key('quitar-bloque-0')));
      await tester.tap(find.byKey(const Key('quitar-bloque-0')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('por-que-bloque-2')), findsNothing);
      expect(find.byKey(const Key('por-que-bloque-1')), findsOneWidget);
    });

    testWidgets('se puede añadir uno', (tester) async {
      await abrir(tester);
      await elegirLaFecha(tester);

      await tester.ensureVisible(find.byKey(const Key('anadir-bloque')));
      await tester.tap(find.byKey(const Key('anadir-bloque')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('por-que-bloque-3')), findsOneWidget);
    });

    testWidgets('con un solo bloque ya no se puede quitar más', (
      tester,
    ) async {
      // Un macrociclo de cero bloques no es nada, y la pantalla no ofrece
      // llegar ahí en lugar de dejar llegar y fallar al confirmar.
      await abrir(tester);
      await elegirLaFecha(tester);

      for (var i = 0; i < 2; i++) {
        await tester.ensureVisible(find.byKey(const Key('quitar-bloque-0')));
        await tester.tap(find.byKey(const Key('quitar-bloque-0')));
        await tester.pumpAndSettle();
      }

      expect(find.byKey(const Key('por-que-bloque-0')), findsOneWidget);
      expect(find.byKey(const Key('quitar-bloque-0')), findsNothing);
    });
  });

  group('C3 — los dos modelos son suyos', () {
    testWidgets('lo que él anotó en la ficha viene de vuelta', (tester) async {
      await abrir(tester);
      await elegirLaFecha(tester);

      expect(find.textContaining('200 Libre'), findsWidgets);
      expect(find.textContaining('pierde el agarre'), findsWidgets);
    });

    testWidgets('y nada más: ni edad, ni categoría, ni tolerancia', (
      tester,
    ) async {
      // **La mitad que se rompe en silencio.** Si la tolerancia a la fatiga o
      // la motivación llegaran pre-escritas, la app habría derivado lo único
      // que la enmienda le reservó a él, y la pantalla se vería igual de bien.
      await abrir(tester);
      await elegirLaFecha(tester);

      final campos = tester
          .widgetList<TextField>(find.byType(TextField))
          .map((c) => c.controller?.text ?? '')
          .join('\n')
          .toLowerCase();

      expect(campos, isNot(contains('toleran')));
      expect(campos, isNot(contains('motiva')));
      expect(campos, isNot(contains('precompetitivo')));
      expect(campos, isNot(contains('años')));
    });

    testWidgets('con una ficha sin anotaciones llegan vacíos', (tester) async {
      // Un campo vacío es mejor que uno inventado: se ve que falta.
      await abrir(
        tester,
        ficha: const Nadador(
          id: 'n-leo',
          nombre: 'Leonardo Mesa',
          categoria: Categoria.precompetitivo,
          estiloObjetivo: Estilo.libre,
          pruebaObjetivo: '100 Libre',
        ),
      );
      await elegirLaFecha(tester);

      expect(find.textContaining('pierde el agarre'), findsNothing);
    });
  });

  group('C6 — una categoría sin ATR', () {
    testWidgets('sale un bloque sin fase, y se explica', (tester) async {
      await abrir(
        tester,
        ficha: const Nadador(
          id: 'n-leo',
          nombre: 'Leonardo Mesa',
          categoria: Categoria.iniciacion,
          estiloObjetivo: Estilo.libre,
          pruebaObjetivo: '25 Libre',
        ),
      );
      await elegirLaFecha(tester);

      expect(find.byKey(const Key('sin-fase-0')), findsOneWidget);
      expect(
        tester.widget<Text>(find.byKey(const Key('sin-fase-0'))).data!,
        contains('ATR'),
      );
      // Y no se le ofrece elegir una fase que el motor prohíbe.
      expect(find.text('Fase'), findsNothing);
    });
  });

  group('C7 — fuera de lo publicado avisa, no suspende (M5)', () {
    testWidgets('una Realización de cuatro semanas avisa', (tester) async {
      await abrir(tester);
      await elegirLaFecha(tester);

      await tester.ensureVisible(find.byKey(const Key('por-que-bloque-2')));
      await tester.tap(find.text('2 semanas').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('4 semanas').last);
      await tester.pumpAndSettle();

      expect(find.textContaining('Issurin'), findsWidgets);
    });

    testWidgets('y el botón de confirmar sigue activo', (tester) async {
      // **Esta es la mitad que importa.** Un aviso que además deshabilitara
      // el botón sería un bloqueo con otro nombre, y la sección 12 dice que
      // la natación usa fases más largas que la literatura general.
      await abrir(tester);
      await elegirLaFecha(tester);

      await tester.ensureVisible(find.byKey(const Key('por-que-bloque-2')));
      await tester.tap(find.text('2 semanas').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('4 semanas').last);
      await tester.pumpAndSettle();

      await tester.ensureVisible(
        find.byKey(const Key('confirmar-la-estructura')),
      );
      final boton = tester.widget<FilledButton>(
        find.byKey(const Key('confirmar-la-estructura')),
      );
      expect(boton.onPressed, isNotNull);
    });
  });

  group('M7 — con la ficha incompleta se dice qué falta', () {
    testWidgets('sin categoría no se propone nada', (tester) async {
      await abrir(
        tester,
        ficha: const Nadador(
          id: 'n-sin',
          nombre: 'Alguien nuevo',
          estiloObjetivo: Estilo.libre,
          pruebaObjetivo: '50 Libre',
        ),
      );

      expect(find.textContaining('Falta la categoría'), findsOneWidget);
      expect(find.byKey(const Key('elegir-la-fecha')), findsNothing);
    });

    testWidgets('sin prueba objetivo tampoco', (tester) async {
      await abrir(
        tester,
        ficha: const Nadador(
          id: 'n-sin',
          nombre: 'Alguien nuevo',
          categoria: Categoria.precompetitivo,
          estiloObjetivo: Estilo.libre,
        ),
      );

      expect(find.textContaining('Falta la prueba objetivo'), findsOneWidget);
    });

    testWidgets('se dice en palabras, no con un código', (tester) async {
      await abrir(
        tester,
        ficha: const Nadador(id: 'n-sin', nombre: 'Alguien nuevo'),
      );

      expect(find.textContaining('Falta'), findsWidgets);
      expect(find.textContaining('FR-00'), findsNothing);
      expect(find.textContaining('null'), findsNothing);
    });
  });

  group('C4 — nada se ha guardado todavía', () {
    testWidgets('después de proponer y editar, los almacenes están vacíos', (
      tester,
    ) async {
      // La mitad barata de M10. La cerrada está en
      // `test/dominio/macrociclo/nada_se_guarda_antes_test.dart`, sobre los
      // repositorios: esta comprueba que **esta pantalla** tampoco guarda, que
      // es donde una vista previa cómoda lo rompería.
      await abrir(tester);
      await elegirLaFecha(tester);

      await tester.ensureVisible(find.byKey(const Key('por-que-bloque-2')));
      await tester.tap(find.text('2 semanas').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('4 semanas').last);
      await tester.pumpAndSettle();

      expect(await repos.planes.listar(), isEmpty);
      expect(repos.macrociclos.cuantosHay, 0);
    });
  });

  group('C5 — una confirmación y todo derivado', () {
    testWidgets('al confirmar se guarda el macrociclo entero', (tester) async {
      MacrocicloGuardadoDePrueba? recibido;

      conPantallaAlta(tester);
      await tester.pumpWidget(
        montarEstructura(
          repos: repos,
          alConfirmar: (guardado) => recibido = MacrocicloGuardadoDePrueba(
            mesociclos: guardado.mesociclos.length,
            sesiones: guardado.mesociclos.fold(
              0,
              (total, m) => total + m.sesiones.length,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await elegirLaFecha(tester);

      await tester.ensureVisible(
        find.byKey(const Key('confirmar-la-estructura')),
      );
      await tester.tap(find.byKey(const Key('confirmar-la-estructura')));
      await tester.pumpAndSettle();

      expect(recibido, isNotNull);
      expect(recibido!.mesociclos, 3);
      expect(recibido!.sesiones, greaterThan(30));
      expect(repos.macrociclos.cuantosHay, 1);
      expect(await repos.planes.listar(), hasLength(3));
    });

    testWidgets('y no se pide ninguna confirmación más', (tester) async {
      // M8, FR-003: con un motor determinista no queda criterio que delegar
      // por debajo de la estructura. Si apareciera un segundo diálogo entre
      // niveles, la enmienda se habría leído mal.
      await abrir(tester);
      await elegirLaFecha(tester);

      await tester.ensureVisible(
        find.byKey(const Key('confirmar-la-estructura')),
      );
      await tester.tap(find.byKey(const Key('confirmar-la-estructura')));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byType(Dialog), findsNothing);
    });
  });
}

/// Lo que la prueba necesita saber de lo guardado, sin arrastrar el objeto.
class MacrocicloGuardadoDePrueba {
  const MacrocicloGuardadoDePrueba({
    required this.mesociclos,
    required this.sesiones,
  });

  final int mesociclos;
  final int sesiones;
}
