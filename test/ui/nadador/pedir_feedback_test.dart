/// Pedir feedback **solo de una sesión que ya pasó** (FR-015, H12).
///
/// Y cuando no se puede, el control **no se ofrece en absoluto**: no se ofrece
/// deshabilitado. La feature 007 lo prohibió con estas palabras —un control que
/// no lleva a ninguna parte es un señuelo— y aquí la razón es más concreta
/// todavía: preguntar «¿cómo me salió?» de una sesión que no ha ocurrido no es
/// una operación que falle, es una frase sin sentido.
///
/// El cerrojo de verdad está en el dominio, donde se construye la petición:
/// `puedeMarcarse` es el mismo que la feature 009 puso para marcar, y por el
/// mismo motivo (M24). Esto comprueba que la pantalla no ofrece lo que el
/// dominio va a rechazar.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:natacion_app/dominio/entidades/nadador.dart';

import 'ayuda_pedir_feedback.dart';

void main() {
  late BancoDelNadador banco;

  setUp(() => banco = BancoDelNadador());

  testWidgets('se ofrece en una sesión que ya nadó', (tester) async {
    banco.estado.abrirComo(
      const Nadador(id: 'n1', nombre: 'Ana'),
      plan: banco.planCon([
        banco.sesion(
          id: 's1',
          fecha: banco.hoy.subtract(const Duration(days: 2)),
        ),
      ]),
    );

    await tester.pumpWidget(banco.app());
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('pedir-feedback-s1')), findsOneWidget);
  });

  testWidgets('no se ofrece en una sesión cuyo día no ha llegado', (
    tester,
  ) async {
    banco.estado.abrirComo(
      const Nadador(id: 'n1', nombre: 'Ana'),
      plan: banco.planCon([
        banco.sesion(id: 's9', fecha: banco.hoy.add(const Duration(days: 3))),
      ]),
    );

    await tester.pumpWidget(banco.app());
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('pedir-feedback-s9')),
      findsNothing,
      reason:
          'ni ofrecido ni deshabilitado: un control que no lleva a ninguna '
          'parte es un señuelo (H12)',
    );
  });

  testWidgets('sin repositorio de peticiones no se ofrece nada', (
    tester,
  ) async {
    // Sin servidor no hay a quién pedirle nada ni dónde guardarlo. La pantalla
    // calla en lugar de ofrecer un botón que no puede terminar lo que empieza.
    banco = BancoDelNadador(conPeticiones: false);
    banco.estado.abrirComo(
      const Nadador(id: 'n1', nombre: 'Ana'),
      plan: banco.planCon([
        banco.sesion(
          id: 's1',
          fecha: banco.hoy.subtract(const Duration(days: 2)),
        ),
      ]),
    );

    await tester.pumpWidget(banco.app());
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('pedir-feedback-s1')), findsNothing);
  });

  testWidgets('escribir la pregunta y mandarla', (tester) async {
    banco.estado.abrirComo(
      const Nadador(id: 'n1', nombre: 'Ana'),
      plan: banco.planCon([
        banco.sesion(
          id: 's1',
          fecha: banco.hoy.subtract(const Duration(days: 2)),
        ),
      ]),
    );

    await tester.pumpWidget(banco.app());
    await tester.pumpAndSettle();

    await banco.pedir(tester, 's1', '¿El viraje del tercer 50 lo hice bien?');

    final suyas = await banco.peticiones.deNadador('n1');
    expect(suyas, hasLength(1));
    expect(suyas.single.pregunta, '¿El viraje del tercer 50 lo hice bien?');
    expect(suyas.single.sesionId, 's1');
    expect(suyas.single.planId, 'p1');
  });

  testWidgets('una pregunta en blanco no se manda', (tester) async {
    banco.estado.abrirComo(
      const Nadador(id: 'n1', nombre: 'Ana'),
      plan: banco.planCon([
        banco.sesion(
          id: 's1',
          fecha: banco.hoy.subtract(const Duration(days: 2)),
        ),
      ]),
    );

    await tester.pumpWidget(banco.app());
    await tester.pumpAndSettle();

    await banco.pedir(tester, 's1', '   ');

    expect(
      await banco.peticiones.deNadador('n1'),
      isEmpty,
      reason: 'una petición sin nada dentro no dice qué mirar',
    );
  });

  testWidgets('preguntar dos veces de la misma sesión deja una petición', (
    tester,
  ) async {
    banco.estado.abrirComo(
      const Nadador(id: 'n1', nombre: 'Ana'),
      plan: banco.planCon([
        banco.sesion(
          id: 's1',
          fecha: banco.hoy.subtract(const Duration(days: 2)),
        ),
      ]),
    );

    await tester.pumpWidget(banco.app());
    await tester.pumpAndSettle();

    await banco.pedir(tester, 's1', '¿El viraje?');
    await banco.pedir(tester, 's1', '¿Y el viraje, lo hice bien?');

    final suyas = await banco.peticiones.deNadador('n1');
    expect(suyas, hasLength(1));
    expect(suyas.single.pregunta, '¿Y el viraje, lo hice bien?');
  });
}
