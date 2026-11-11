/// Cuando la lectura falla, **la pantalla lo dice** (FR-008).
///
/// Es el defecto que la feature 009 entregó dos veces: un `catch` que devuelve
/// `const []` y una pantalla que se pinta perfecta y miente. «No ha contestado
/// nada» y «no se pudo leer lo que contestó» le dicen cosas opuestas a un
/// entrenador que está decidiendo qué programar, y la peor versión del fallo
/// es la que no se ve.
///
/// Así que aquí hay dos cerrojos: que el aviso aparezca, y que **no aparezca
/// la frase de «no ha contestado nada»**, que es la mentira concreta.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'ayuda_analisis.dart';

void main() {
  late ReposDeAnalisis repos;

  setUp(() => repos = ReposDeAnalisis());

  testWidgets('si no se pueden leer los registros, se dice', (tester) async {
    conPantallaAlta(tester);

    final macrocicloId = await repos.sembrarMacrociclo();

    await tester.pumpWidget(
      montarLectura(
        repos: repos,
        macrocicloId: macrocicloId,
        registros: const RegistrosQueFallan(
          'No se pudieron leer los registros: permiso denegado',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('no-se-pudo-leer-su-analisis')),
      findsOneWidget,
    );
  });

  testWidgets('un fallo no se lee como «no ha contestado nada»', (
    tester,
  ) async {
    conPantallaAlta(tester);

    final macrocicloId = await repos.sembrarMacrociclo();

    await tester.pumpWidget(
      montarLectura(
        repos: repos,
        macrocicloId: macrocicloId,
        registros: const RegistrosQueFallan(),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('no-ha-contestado-nada')),
      findsNothing,
      reason:
          'esto es la mentira exacta: un servidor ilegible leído como una '
          'nadadora que no respondió',
    );
  });

  testWidgets('un fallo no enseña una lectura parcial como completa', (
    tester,
  ) async {
    conPantallaAlta(tester);

    final macrocicloId = await repos.sembrarMacrociclo();

    await tester.pumpWidget(
      montarLectura(
        repos: repos,
        macrocicloId: macrocicloId,
        registros: const RegistrosQueFallan(),
      ),
    );
    await tester.pumpAndSettle();

    // Ni adherencia ni sesiones: un número calculado sobre registros que no se
    // pudieron leer es un número inventado.
    expect(find.byKey(const Key('adherencia-de-n-ana')), findsNothing);
    expect(find.byKey(const Key('sesion-y-respuesta-s1')), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });
}
