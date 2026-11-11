/// Las dos cargas en la pantalla: **las dos con nombre, y ninguna tercera**.
///
/// El principio VIII dice que la carga externa y la interna se almacenan y se
/// muestran por separado y que **no se combinan en un mismo indicador**. El
/// tipo ya lo garantiza —`RespuestaASesion` no tiene ningún miembro que mire a
/// los dos, y hay una prueba leyendo su fuente—, así que lo que puede romperse
/// aquí es lo único que queda: que alguien escriba la multiplicación en el
/// widget.
///
/// Por eso esta prueba hace dos cosas distintas:
///
/// 1. comprueba que los dos bloques existen y están **etiquetados** —un número
///    sin nombre al lado de otro número es una invitación a leerlos juntos—;
/// 2. busca en lo pintado cualquier cifra que solo pueda salir de combinarlos.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'ayuda_analisis.dart';

void main() {
  late ReposDeAnalisis repos;

  setUp(() => repos = ReposDeAnalisis());

  testWidgets('2000 m programados y un esfuerzo de 7: los dos, con nombre', (
    tester,
  ) async {
    conPantallaAlta(tester);

    final macrocicloId = await repos.sembrarMacrociclo();
    repos.registros.sembrar(
      registroDe(sesionId: 's1', planId: 'plan-1', rpe: 7),
    );

    await tester.pumpWidget(
      montarLectura(repos: repos, macrocicloId: macrocicloId),
    );
    await tester.pumpAndSettle();

    final programado = tester
        .widget<Text>(find.byKey(const Key('lo-programado-s1')))
        .data!;
    final contestado = tester
        .widget<Text>(find.byKey(const Key('lo-que-contesto-s1')))
        .data!;

    expect(programado, contains('2000'));
    expect(contestado, contains('7'));

    // **Etiquetadas.** Que cada bloque diga qué es, porque la mitad del
    // principio VIII es que se muestren por separado y la otra mitad es que
    // quien las lee sepa cuál es cuál.
    expect(find.text('Lo programado'), findsWidgets);
    expect(find.text('Lo que contestó'), findsWidgets);
  });

  testWidgets('no aparece ninguna cifra sacada de las dos', (tester) async {
    conPantallaAlta(tester);

    // 2000 m y RPE 7. El producto es 14000, la media 1003,5, el cociente
    // 285,71. Si alguno sale en la pantalla, alguien combinó las dos cargas.
    final macrocicloId = await repos.sembrarMacrociclo();
    repos.registros.sembrar(
      registroDe(sesionId: 's1', planId: 'plan-1', rpe: 7),
    );

    await tester.pumpWidget(
      montarLectura(repos: repos, macrocicloId: macrocicloId),
    );
    await tester.pumpAndSettle();

    final pintado = tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data ?? '')
        .join(' | ');

    for (final derivado in <String>['14000', '14.000', '285', '1003', '1004']) {
      expect(
        pintado,
        isNot(contains(derivado)),
        reason:
            '$derivado solo puede salir de combinar 2000 m con un RPE de 7, y '
            'eso es exactamente lo que el principio VIII prohíbe',
      );
    }

    for (final palabra in <String>[
      'carga de la sesión',
      'carga total',
      'índice de carga',
      'tss',
      'trimp',
    ]) {
      expect(pintado.toLowerCase(), isNot(contains(palabra)));
    }
  });

  testWidgets('lo programado se lee aunque ella no haya contestado', (
    tester,
  ) async {
    conPantallaAlta(tester);

    final macrocicloId = await repos.sembrarMacrociclo();

    await tester.pumpWidget(
      montarLectura(repos: repos, macrocicloId: macrocicloId),
    );
    await tester.pumpAndSettle();

    // Las dos mitades son independientes: la externa está en el plan y existe
    // sin ella. Que falte una no borra la otra.
    expect(
      tester.widget<Text>(find.byKey(const Key('lo-programado-s1'))).data,
      contains('2000'),
    );
    expect(
      tester.widget<Text>(find.byKey(const Key('lo-que-contesto-s1'))).data,
      'Sin respuesta',
    );
  });
}
