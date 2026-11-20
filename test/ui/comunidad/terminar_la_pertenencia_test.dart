/// FR-025, FR-026 — irse y ser sacada, y que no cueste nada de lo suyo.
///
/// **Las dos direcciones, y simétricas a propósito** (garantía F7). Él puede
/// sacarla; ella puede irse. Una salida que dependiera de que el entrenador la
/// acepte sería una puerta con cerrojo por fuera, y pertenecer a un grupo es
/// algo que a ella le pasa.
///
/// Lo que estas pruebas fijan de cada lado:
///
/// - **Se pregunta antes.** Desde su lado no se deshace —tendría que volver a
///   pedir entrar y él volver a aceptar—, así que un toque no basta.
/// - **Se dice lo que cuesta y lo que no**, con todas las letras: deja de ver
///   lo suyo, y no se borra nada.
/// - **Si el servidor no contesta, no parece hecho.** Es el mismo cerrojo que
///   la cola de ingresos, y por el mismo motivo.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:natacion_app/dominio/entidades/nadador.dart';
import 'package:natacion_app/dominio/metodologia/categorias.dart';
import 'package:natacion_app/dominio/metodologia/estilos.dart';
import 'package:natacion_app/dominio/repositorios/repositorios.dart';
import 'package:natacion_app/ui/comunidad/terminar_la_pertenencia.dart';

void main() {
  const ella = Nadador(
    id: 'n-ana',
    nombre: 'Ana María Restrepo',
    categoria: Categoria.precompetitivo,
    estiloObjetivo: Estilo.libre,
    pruebaObjetivo: '200 Libre',
  );

  Future<List<String>> montar(
    WidgetTester tester, {
    required bool esElEntrenador,
    bool falla = false,
  }) async {
    final hechas = <String>[];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TerminarLaPertenencia(
            quien: esElEntrenador ? ella : null,
            alTerminar: () async {
              if (falla) throw const FalloDeDatos('el servidor no contestó');
              hechas.add('terminada');
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    return hechas;
  }

  group('FR-025 — él la saca de su comunidad', () {
    testWidgets('pregunta antes, y no lo hace solo por tocar', (tester) async {
      final hechas = await montar(tester, esElEntrenador: true);

      await tester.tap(find.byKey(const Key('terminar-pertenencia')));
      await tester.pumpAndSettle();

      expect(hechas, isEmpty, reason: 'lo hizo sin preguntar');
      expect(find.byKey(const Key('confirmar-terminar')), findsOneWidget);
    });

    testWidgets('la pregunta dice su nombre y qué pasa', (tester) async {
      await montar(tester, esElEntrenador: true);
      await tester.tap(find.byKey(const Key('terminar-pertenencia')));
      await tester.pumpAndSettle();

      expect(find.textContaining('Ana María Restrepo'), findsWidgets);
      // **Las dos mitades.** Lo que pierde y lo que no, porque «sacar a
      // alguien» suena a borrarlo y no lo es.
      expect(find.textContaining('Dejarás de ver'), findsOneWidget);
      expect(find.textContaining('No se borra nada'), findsOneWidget);
    });

    testWidgets('confirmando, se hace', (tester) async {
      final hechas = await montar(tester, esElEntrenador: true);

      await tester.tap(find.byKey(const Key('terminar-pertenencia')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('confirmar-terminar')));
      await tester.pumpAndSettle();

      expect(hechas, ['terminada']);
    });

    testWidgets('cancelando, no', (tester) async {
      final hechas = await montar(tester, esElEntrenador: true);

      await tester.tap(find.byKey(const Key('terminar-pertenencia')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('cancelar-terminar')));
      await tester.pumpAndSettle();

      expect(hechas, isEmpty);
    });
  });

  group('FR-025 — ella se va de la suya', () {
    testWidgets('el mismo control, con sus propias palabras', (tester) async {
      await montar(tester, esElEntrenador: false);
      await tester.tap(find.byKey(const Key('terminar-pertenencia')));
      await tester.pumpAndSettle();

      // Desde su lado no habla de «sacar» a nadie: habla de salir.
      expect(find.textContaining('Dejarás de recibir'), findsOneWidget);
      expect(find.textContaining('No se borra nada'), findsOneWidget);
      // Y de que puede volver: no es una puerta de una sola dirección.
      expect(find.textContaining('volver a pedir'), findsOneWidget);
    });

    testWidgets('y también pregunta antes', (tester) async {
      final hechas = await montar(tester, esElEntrenador: false);

      await tester.tap(find.byKey(const Key('terminar-pertenencia')));
      await tester.pumpAndSettle();

      expect(hechas, isEmpty);
    });
  });

  group('si el servidor no contesta', () {
    testWidgets('no parece hecho, y se dice', (tester) async {
      await montar(tester, esElEntrenador: true, falla: true);

      await tester.tap(find.byKey(const Key('terminar-pertenencia')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('confirmar-terminar')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('terminar-no-se-pudo')), findsOneWidget);
      // Y el control sigue ahí, para volver a intentarlo.
      expect(find.byKey(const Key('terminar-pertenencia')), findsOneWidget);
    });
  });
}
