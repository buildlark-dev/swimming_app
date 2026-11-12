/// Lo que el entrenador lee de una nadadora: sus sesiones y lo que contestó.
///
/// Dos cosas que esta prueba fija y que son el motivo de la feature:
///
/// 1. **Cada respuesta al lado de la sesión que la produjo.** Un RPE de 8 sin
///    saber sobre qué no dice nada; sobre 2000 metros en A2 dice bastante.
/// 2. **«No la hice» se lee como «no la hizo»**, y no como un hueco. Es un
///    dato: la nadadora estuvo ahí y dijo lo que pasó. Mezclarlo con la
///    ausencia de respuesta le enseñaría al entrenador un hueco donde hay una
///    respuesta (spec US1, escenario 2).
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'ayuda_analisis.dart';

void main() {
  late ReposDeAnalisis repos;

  setUp(() => repos = ReposDeAnalisis());

  testWidgets('sus respuestas, cada una junto a su sesión', (tester) async {
    conPantallaAlta(tester);

    final macrocicloId = await repos.sembrarMacrociclo();

    repos.registros
      ..sembrar(
        registroDe(
          sesionId: 's1',
          planId: 'plan-1',
          rpe: 8,
          observaciones: 'Me costó el último 200',
        ),
      )
      ..sembrar(registroDe(sesionId: 's2', planId: 'plan-1', realizada: false));

    await tester.pumpWidget(
      montarLectura(repos: repos, macrocicloId: macrocicloId),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('lectura-de-n-ana')), findsOneWidget);

    // Lo que contestó de s1, junto a su sesión.
    final contestadoEnS1 = tester
        .widget<Text>(find.byKey(const Key('lo-que-contesto-s1')))
        .data!;
    expect(contestadoEnS1, contains('8'));
    expect(find.text('Me costó el último 200'), findsOneWidget);

    // Y lo programado de esa misma sesión, aparte.
    final programadoEnS1 = tester
        .widget<Text>(find.byKey(const Key('lo-programado-s1')))
        .data!;
    expect(programadoEnS1, contains('2000'));
  });

  testWidgets('«no la hizo» no se lee como un hueco', (tester) async {
    conPantallaAlta(tester);

    final macrocicloId = await repos.sembrarMacrociclo();

    // s2 contestada diciendo que no; s3 sin contestar.
    repos.registros.sembrar(
      registroDe(sesionId: 's2', planId: 'plan-1', realizada: false),
    );

    await tester.pumpWidget(
      montarLectura(repos: repos, macrocicloId: macrocicloId),
    );
    await tester.pumpAndSettle();

    final dijoQueNo = tester
        .widget<Text>(find.byKey(const Key('lo-que-contesto-s2')))
        .data!;
    final sinContestar = tester
        .widget<Text>(find.byKey(const Key('lo-que-contesto-s3')))
        .data!;

    expect(
      dijoQueNo,
      isNot(sinContestar),
      reason:
          '«dijo que no la hizo» y «no contestó» no pueden leerse igual: uno '
          'es un dato y el otro su ausencia',
    );
    expect(dijoQueNo.toLowerCase(), contains('no la hizo'));
    expect(sinContestar.toLowerCase(), contains('sin respuesta'));
  });

  testWidgets('las sesiones van de la más reciente a la más antigua', (
    tester,
  ) async {
    conPantallaAlta(tester);

    final macrocicloId = await repos.sembrarMacrociclo();

    await tester.pumpWidget(
      montarLectura(repos: repos, macrocicloId: macrocicloId),
    );
    await tester.pumpAndSettle();

    // Por posición vertical, que es lo que el entrenador ve.
    double arribaDe(String sesionId) =>
        tester.getTopLeft(find.byKey(Key('sesion-y-respuesta-$sesionId'))).dy;

    expect(arribaDe('s3'), lessThan(arribaDe('s2')));
    expect(arribaDe('s2'), lessThan(arribaDe('s1')));
  });

  testWidgets('la adherencia se lee como adherencia y sale del progreso', (
    tester,
  ) async {
    conPantallaAlta(tester);

    final macrocicloId = await repos.sembrarMacrociclo();

    repos.registros
      ..sembrar(registroDe(sesionId: 's1', planId: 'plan-1'))
      ..sembrar(registroDe(sesionId: 's2', planId: 'plan-1', realizada: false));

    await tester.pumpWidget(
      montarLectura(repos: repos, macrocicloId: macrocicloId),
    );
    await tester.pumpAndSettle();

    final adherencia = tester
        .widget<Text>(find.byKey(const Key('adherencia-de-n-ana')))
        .data!;

    expect(adherencia, contains('1 de 3'));
  });

  testWidgets('dice bajo qué versión de metodología se construyó', (
    tester,
  ) async {
    conPantallaAlta(tester);

    final macrocicloId = await repos.sembrarMacrociclo();

    await tester.pumpWidget(
      montarLectura(repos: repos, macrocicloId: macrocicloId),
    );
    await tester.pumpAndSettle();

    final sello = tester
        .widget<Text>(find.byKey(const Key('version-de-metodologia')))
        .data!;

    expect(
      sello,
      contains('3.6.0'),
      reason:
          'FR-004: cada lectura dice bajo qué versión se construyó lo que '
          'muestra, leída del plan y no de una constante',
    );
  });
}
