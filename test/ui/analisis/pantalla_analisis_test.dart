/// El `Análisis` del entrenador deja de ser una promesa.
///
/// Estaba en el HUB desde la feature 007 con un `TodaviaNo(feature: '010')`
/// —una promesa acotada, con el número de la feature que la trae escrito
/// dentro— y esta es esa feature. Lo que vigila esta prueba es que el destino
/// tenga contenido y que ese contenido sean **sus nadadores, cada uno
/// alcanzable**.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:natacion_app/dominio/cuentas/cuenta.dart';
import 'package:natacion_app/dominio/entidades/nadador.dart';
import 'package:natacion_app/dominio/hub/destino.dart';
import 'package:natacion_app/dominio/metodologia/categorias.dart';
import 'package:natacion_app/dominio/metodologia/estilos.dart';

import 'ayuda_analisis.dart';

void main() {
  late ReposDeAnalisis repos;

  setUp(() => repos = ReposDeAnalisis());

  test('el Análisis del entrenador ya no es un «todavía no»', () {
    final queHay = reparto(Destino.analisis, Rol.entrenador);

    expect(
      queHay,
      isA<Contiene>(),
      reason:
          'la pestaña llevaba un TodaviaNo con feature: 010 escrito dentro, y '
          'esta es la 010',
    );
    expect((queHay as Contiene).contenido, Contenido.analisisDelEntrenador);
  });

  testWidgets('lista a sus nadadores, cada uno alcanzable', (tester) async {
    conPantallaAlta(tester);

    await repos.nadadores.guardar(ana());
    await repos.nadadores.guardar(
      const Nadador(
        id: 'n-juan',
        nombre: 'Juan Esteban',
        categoria: Categoria.precompetitivo,
        estiloObjetivo: Estilo.espalda,
      ),
    );
    await repos.sembrarMacrociclo();

    await tester.pumpWidget(montarAnalisis(repos: repos));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('analisis-del-entrenador')), findsOneWidget);
    expect(find.text('Ana'), findsOneWidget);
    expect(find.text('Juan Esteban'), findsOneWidget);

    expect(find.byKey(const Key('abrir-lectura-n-ana')), findsOneWidget);
    expect(find.byKey(const Key('abrir-lectura-n-juan')), findsOneWidget);
  });

  testWidgets('sin nadadores lo dice en una frase, no en un marco vacío', (
    tester,
  ) async {
    conPantallaAlta(tester);

    await tester.pumpWidget(montarAnalisis(repos: repos));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('sin-nadadores-en-analisis')), findsOneWidget);
  });

  testWidgets('abrir un nadador lleva a su lectura', (tester) async {
    conPantallaAlta(tester);

    await repos.nadadores.guardar(ana());
    await repos.sembrarMacrociclo();
    repos.registros.sembrar(
      registroDe(sesionId: 's1', planId: 'plan-1', rpe: 7),
    );

    await tester.pumpWidget(montarAnalisis(repos: repos));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('abrir-lectura-n-ana')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('lectura-de-n-ana')), findsOneWidget);
  });

  testWidgets('un nadador sin macrociclo es alcanzable y se dice', (
    tester,
  ) async {
    conPantallaAlta(tester);

    await repos.nadadores.guardar(ana());

    await tester.pumpWidget(montarAnalisis(repos: repos));
    await tester.pumpAndSettle();

    // **Alcanzable igual.** Un nadador sin macrociclo no desaparece de la
    // lista: el entrenador tiene que poder ver que no tiene ninguno, que es
    // justamente lo que le dice qué hacer con él.
    expect(find.text('Ana'), findsOneWidget);
    expect(find.byKey(const Key('sin-macrociclo-n-ana')), findsOneWidget);
  });
}
