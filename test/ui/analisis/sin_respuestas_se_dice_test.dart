/// Una nadadora que no ha contestado nada **se dice con una frase** (FR-007).
///
/// No un marco vacío, y no un indicador que gira para siempre. Las dos cosas
/// dejan al entrenador sin saber si el problema es de ella, del plan o de la
/// app, y es sobre eso sobre lo que va a decidir qué programar.
///
/// La feature 005 dejó `EstadoVacio` con `queHacer` **obligatorio** justo por
/// esto: un cartel de «no hay nada» no dice si falta algo suyo o del nadador.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'ayuda_analisis.dart';

void main() {
  late ReposDeAnalisis repos;

  setUp(() => repos = ReposDeAnalisis());

  testWidgets('sin ninguna respuesta, una frase y no un marco vacío', (
    tester,
  ) async {
    conPantallaAlta(tester);

    final macrocicloId = await repos.sembrarMacrociclo();

    await tester.pumpWidget(
      montarLectura(repos: repos, macrocicloId: macrocicloId),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('no-ha-contestado-nada')), findsOneWidget);

    // Y no es un indicador girando: la pantalla acabó de cargar.
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('con una sola respuesta la frase desaparece', (tester) async {
    conPantallaAlta(tester);

    final macrocicloId = await repos.sembrarMacrociclo();
    repos.registros.sembrar(
      registroDe(sesionId: 's1', planId: 'plan-1', rpe: 7),
    );

    await tester.pumpWidget(
      montarLectura(repos: repos, macrocicloId: macrocicloId),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('no-ha-contestado-nada')), findsNothing);
  });

  testWidgets('sin respuestas sigue enseñando sus sesiones', (tester) async {
    conPantallaAlta(tester);

    final macrocicloId = await repos.sembrarMacrociclo();

    await tester.pumpWidget(
      montarLectura(repos: repos, macrocicloId: macrocicloId),
    );
    await tester.pumpAndSettle();

    // **La frase no sustituye al plan.** Que no haya contestado no quiere
    // decir que no haya nada que leer: lo programado está, y es la mitad de
    // la conversación.
    expect(find.byKey(const Key('sesion-y-respuesta-s1')), findsOneWidget);
    expect(find.byKey(const Key('sesion-y-respuesta-s3')), findsOneWidget);
  });

  testWidgets('una nadadora sin macrociclo tampoco deja un marco vacío', (
    tester,
  ) async {
    conPantallaAlta(tester);

    await tester.pumpWidget(montarLectura(repos: repos, macrocicloId: ''));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('sin-macrociclo-que-leer')), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });
}
