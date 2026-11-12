/// Lo que ella preguntó, **donde él ya está leyendo** (FR-017), y la única
/// escritura que él hace aquí: «la vi» (FR-018).
///
/// No hay bandeja aparte. Una pregunta sobre una sesión se entiende al lado de
/// la sesión, y una bandeja sería un sitio más que hay que acordarse de abrir.
/// Lo que sí va arriba es **cuántas esperan**: una pregunta visible solo dentro
/// de su tarjeta, entre cuarenta y dos, está enterrada igual que lo estaría una
/// molestia.
///
/// Y no hay campo de respuesta. Eso fue la aclaración Q2.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:natacion_app/datos/memoria/repositorios_memoria.dart';
import 'package:natacion_app/dominio/analisis/peticion_de_feedback.dart';

import 'ayuda_analisis.dart';

void main() {
  late ReposDeAnalisis repos;
  late RepositorioPeticionesDeFeedbackMemoria peticiones;

  setUp(() {
    repos = ReposDeAnalisis();
    peticiones = RepositorioPeticionesDeFeedbackMemoria();
  });

  PeticionDeFeedback laDeAna({String sesionId = 's1', DateTime? vistaEn}) =>
      PeticionDeFeedback(
        nadadorId: 'n-ana',
        planId: 'plan-1',
        sesionId: sesionId,
        pregunta: '¿El viraje del tercer 50 lo hice bien?',
        pedidaEn: DateTime(2026, 11, 3),
        vistaEn: vistaEn,
      );

  testWidgets('la pregunta sale junto a su sesión', (tester) async {
    conPantallaAlta(tester);

    final macrocicloId = await repos.sembrarMacrociclo();
    await peticiones.guardar(laDeAna());

    await tester.pumpWidget(
      montarLectura(
        repos: repos,
        macrocicloId: macrocicloId,
        peticiones: peticiones,
      ),
    );
    await tester.pumpAndSettle();

    expect(
      tester.widget<Text>(find.byKey(const Key('pregunto-en-s1'))).data,
      '¿El viraje del tercer 50 lo hice bien?',
    );

    // Y en ninguna otra: cada pregunta es de su sesión.
    expect(find.byKey(const Key('pregunto-en-s2')), findsNothing);
  });

  testWidgets('arriba se dice cuántas esperan', (tester) async {
    conPantallaAlta(tester);

    final macrocicloId = await repos.sembrarMacrociclo();
    await peticiones.guardar(laDeAna(sesionId: 's1'));
    await peticiones.guardar(laDeAna(sesionId: 's3'));

    await tester.pumpWidget(
      montarLectura(
        repos: repos,
        macrocicloId: macrocicloId,
        peticiones: peticiones,
      ),
    );
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<Text>(find.byKey(const Key('esperan-que-las-mire-n-ana')))
          .data,
      contains('2 sesiones'),
    );
  });

  testWidgets('la marca vista, y se queda marcada', (tester) async {
    conPantallaAlta(tester);

    final macrocicloId = await repos.sembrarMacrociclo();
    await peticiones.guardar(laDeAna());

    await tester.pumpWidget(
      montarLectura(
        repos: repos,
        macrocicloId: macrocicloId,
        peticiones: peticiones,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('marcar-vista-s1')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('ya-la-vi-s1')), findsOneWidget);
    expect(find.byKey(const Key('marcar-vista-s1')), findsNothing);

    final guardada = (await peticiones.deNadador('n-ana')).single;
    expect(guardada.laVio, isTrue);
  });

  testWidgets('marcarla vista no le cambia la pregunta', (tester) async {
    conPantallaAlta(tester);

    const suya = '¿El viraje del tercer 50 lo hice bien?';

    final macrocicloId = await repos.sembrarMacrociclo();
    await peticiones.guardar(laDeAna());

    await tester.pumpWidget(
      montarLectura(
        repos: repos,
        macrocicloId: macrocicloId,
        peticiones: peticiones,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('marcar-vista-s1')));
    await tester.pumpAndSettle();

    expect((await peticiones.deNadador('n-ana')).single.pregunta, suya);
    expect(find.text(suya), findsWidgets);
  });

  testWidgets('una ya vista no se vuelve a ofrecer', (tester) async {
    conPantallaAlta(tester);

    final macrocicloId = await repos.sembrarMacrociclo();
    await peticiones.guardar(laDeAna(vistaEn: DateTime(2026, 11, 4)));

    await tester.pumpWidget(
      montarLectura(
        repos: repos,
        macrocicloId: macrocicloId,
        peticiones: peticiones,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('marcar-vista-s1')), findsNothing);
    expect(find.byKey(const Key('ya-la-vi-s1')), findsOneWidget);
    expect(
      find.byKey(const Key('esperan-que-las-mire-n-ana')),
      findsNothing,
      reason: 'ya no espera nada',
    );
  });

  testWidgets('sin repositorio no se ofrece marcarla vista', (tester) async {
    conPantallaAlta(tester);

    final macrocicloId = await repos.sembrarMacrociclo();

    await tester.pumpWidget(
      montarLectura(repos: repos, macrocicloId: macrocicloId),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('marcar-vista-s1')), findsNothing);
    expect(find.byKey(const Key('pregunto-en-s1')), findsNothing);
  });

  testWidgets('no hay ningún sitio para escribirle una respuesta', (
    tester,
  ) async {
    conPantallaAlta(tester);

    final macrocicloId = await repos.sembrarMacrociclo();
    await peticiones.guardar(laDeAna());

    await tester.pumpWidget(
      montarLectura(
        repos: repos,
        macrocicloId: macrocicloId,
        peticiones: peticiones,
      ),
    );
    await tester.pumpAndSettle();

    // Ni un campo de texto en toda la pantalla. Contesta en la piscina (Q2).
    expect(find.byType(TextField), findsNothing);
    expect(find.byType(TextFormField), findsNothing);
  });
}
