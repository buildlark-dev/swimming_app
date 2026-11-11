/// La molestia **va aparte del resto de observaciones** (FR-009).
///
/// El principio VIII lo exige con estas palabras: «un reporte de dolor, lesión
/// o malestar se marca **aparte** del resto de observaciones, llega al
/// entrenador y NO DEBE resolverse de forma automática».
///
/// El modelado ya lo cumple desde la feature 003 —`ReporteDeMolestia` es un
/// objeto propio y no una bandera dentro del texto libre—, así que aquí lo que
/// se fija es la otra mitad: que en la pantalla **se distinga sin abrir nada**.
/// Si viviera en el flujo de observaciones, encontrarla dependería de que
/// alguien leyera todas las observaciones de todas las sesiones.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:natacion_app/dominio/entidades/registro_sesion.dart';

import 'ayuda_analisis.dart';

void main() {
  late ReposDeAnalisis repos;

  setUp(() => repos = ReposDeAnalisis());

  testWidgets('la sesión con molestia se distingue de la que solo tiene '
      'observaciones', (tester) async {
    conPantallaAlta(tester);

    final macrocicloId = await repos.sembrarMacrociclo();

    repos.registros
      // s1: solo observaciones.
      ..sembrar(
        registroDe(
          sesionId: 's1',
          planId: 'plan-1',
          rpe: 7,
          observaciones: 'Me costó el último 200',
        ),
      )
      // s2: una molestia.
      ..sembrar(conMolestia(sesionId: 's2', planId: 'plan-1'));

    await tester.pumpWidget(
      montarLectura(repos: repos, macrocicloId: macrocicloId),
    );
    await tester.pumpAndSettle();

    // Marcada donde está, sin abrir nada: todo se pinta desplegado.
    expect(find.byKey(const Key('molestia-en-s2')), findsOneWidget);
    expect(
      find.byKey(const Key('molestia-en-s1')),
      findsNothing,
      reason:
          'una sesión con observaciones y sin molestia no puede quedar '
          'marcada: la marca dejaría de significar nada',
    );
  });

  testWidgets('también va arriba, junta, para no tener que buscarla', (
    tester,
  ) async {
    conPantallaAlta(tester);

    final macrocicloId = await repos.sembrarMacrociclo();
    repos.registros.sembrar(conMolestia(sesionId: 's2', planId: 'plan-1'));

    await tester.pumpWidget(
      montarLectura(repos: repos, macrocicloId: macrocicloId),
    );
    await tester.pumpAndSettle();

    final arribaDeLaMolestia = tester
        .getTopLeft(find.byKey(const Key('molestias-de-n-ana')))
        .dy;
    final arribaDeLasSesiones = tester
        .getTopLeft(find.byKey(const Key('sesion-y-respuesta-s3')))
        .dy;

    expect(
      arribaDeLaMolestia,
      lessThan(arribaDeLasSesiones),
      reason:
          'si está sólo dentro de su sesión, encontrarla en un macrociclo de '
          'catorce semanas pide recorrer cuarenta y dos tarjetas',
    );
  });

  testWidgets('sin ninguna molestia no hay sección de molestias', (
    tester,
  ) async {
    conPantallaAlta(tester);

    final macrocicloId = await repos.sembrarMacrociclo();
    repos.registros.sembrar(
      registroDe(
        sesionId: 's1',
        planId: 'plan-1',
        rpe: 7,
        observaciones: 'Todo bien',
      ),
    );

    await tester.pumpWidget(
      montarLectura(repos: repos, macrocicloId: macrocicloId),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('molestias-de-n-ana')), findsNothing);
  });

  testWidgets(
    'lo que escribió se enseña tal cual, sin recortar ni reescribir',
    (tester) async {
      conPantallaAlta(tester);

      const suyo =
          'Me molesta el hombro derecho cuando salgo del viraje y aprieto, '
          'sobre todo en el segundo 50';

      final macrocicloId = await repos.sembrarMacrociclo();
      repos.registros.sembrar(
        registroDe(
          sesionId: 's2',
          planId: 'plan-1',
          rpe: 6,
          molestia: const ReporteDeMolestia(
            descripcion: suyo,
            zonaDelCuerpo: 'Hombro derecho',
          ),
        ),
      );

      await tester.pumpWidget(
        montarLectura(repos: repos, macrocicloId: macrocicloId),
      );
      await tester.pumpAndSettle();

      // **Palabra por palabra.** No se resume, no se normaliza y no se traduce
      // al vocabulario del entrenador: es lo que ella dijo.
      expect(
        tester.widget<Text>(find.byKey(const Key('molestia-en-s2'))).data,
        suyo,
      );
      expect(
        tester
            .widget<Text>(find.byKey(const Key('molestia-contada-en-s2')))
            .data,
        suyo,
      );
      expect(find.text('Hombro derecho'), findsWidgets);
    },
  );
}
