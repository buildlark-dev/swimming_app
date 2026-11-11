/// La adherencia se presenta **como adherencia**, nunca como una nota de carga.
///
/// Es la cifra más fácil de malinterpretar de la pantalla, porque un «1 de 3»
/// sin nombre se lee como un rendimiento. Y no lo es: cuenta sesiones
/// cumplidas sobre programadas, y nada más. No pondera por metros ni por RPE
/// —el principio VIII lo prohíbe, y la feature 003 dejó una prueba que lo
/// fija— así que presentarla como «carga» o como «puntuación» sería decir algo
/// que el número no dice.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'ayuda_analisis.dart';

void main() {
  late ReposDeAnalisis repos;

  setUp(() => repos = ReposDeAnalisis());

  testWidgets('la cifra va etiquetada como sesiones cumplidas', (tester) async {
    conPantallaAlta(tester);

    final macrocicloId = await repos.sembrarMacrociclo();
    repos.registros.sembrar(registroDe(sesionId: 's1', planId: 'plan-1'));

    await tester.pumpWidget(
      montarLectura(repos: repos, macrocicloId: macrocicloId),
    );
    await tester.pumpAndSettle();

    expect(
      tester.widget<Text>(find.byKey(const Key('adherencia-de-n-ana'))).data,
      '1 de 3',
    );
    expect(find.textContaining('Adherencia'), findsWidgets);
    expect(find.textContaining('sesiones cumplidas'), findsWidgets);
  });

  testWidgets('nunca se nombra como carga, nota ni puntuación', (tester) async {
    conPantallaAlta(tester);

    final macrocicloId = await repos.sembrarMacrociclo();
    repos.registros.sembrar(
      registroDe(sesionId: 's1', planId: 'plan-1', rpe: 8),
    );

    await tester.pumpWidget(
      montarLectura(repos: repos, macrocicloId: macrocicloId),
    );
    await tester.pumpAndSettle();

    final pintado = tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => (t.data ?? '').toLowerCase())
        .join(' | ');

    for (final palabra in <String>[
      'carga de entrenamiento',
      'nota',
      'puntuación',
      'puntaje',
      'rendimiento',
      'desempeño',
      'calificación',
    ]) {
      expect(
        pintado,
        isNot(contains(palabra)),
        reason:
            '«$palabra» junto a un «1 de 3» le cambia el significado: esa '
            'cifra cuenta sesiones, no mide cómo le fue',
      );
    }
  });

  testWidgets('con cero contestadas sigue siendo adherencia', (tester) async {
    conPantallaAlta(tester);

    final macrocicloId = await repos.sembrarMacrociclo();

    await tester.pumpWidget(
      montarLectura(repos: repos, macrocicloId: macrocicloId),
    );
    await tester.pumpAndSettle();

    expect(
      tester.widget<Text>(find.byKey(const Key('adherencia-de-n-ana'))).data,
      '0 de 3',
      reason:
          '«0 de 3» dice de qué se está hablando; un «0%» a secas parece una '
          'calificación',
    );
  });
}
