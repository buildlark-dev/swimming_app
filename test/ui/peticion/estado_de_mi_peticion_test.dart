/// Garantías FR-025 a FR-027 — lo que el nadador lee de su solicitud.
///
/// Las tres cosas que esta pantalla tiene que hacer bien son decir en cuál de
/// los cuatro estados está, enseñar el motivo tal como lo escribió el
/// entrenador, y **no prometer ninguna fecha**. Lo tercero es lo que se
/// escapa: una app que dice «en 24 horas» y no cumple enseña a no creerle, y
/// quien espera puede tener nueve años.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:natacion_app/dominio/metodologia/estilos.dart';
import 'package:natacion_app/dominio/peticiones/peticion.dart';
import 'package:natacion_app/ui/peticion/estado_de_mi_peticion.dart';

void main() {
  final hoy = DateTime(2026, 11, 3);

  PeticionDePlan enEstado(
    EstadoDePeticion estado, {
    String? motivo,
    String? planId,
  }) => PeticionDePlan(
    nadadorId: 'n-ana',
    enviadaEn: hoy.subtract(const Duration(days: 1)),
    estado: estado,
    motivoDelRechazo: motivo,
    planId: planId,
    respondidaEn: estado.estaAbierta ? null : hoy,
    respuestas: RespuestasDePeticion(
      estiloObjetivo: Estilo.libre,
      pruebaObjetivo: '200 Libre',
      fechaDeCompetencia: hoy.add(const Duration(days: 24)),
      diasDisponibles: [
        hoy.add(const Duration(days: 1)),
        hoy.add(const Duration(days: 3)),
      ],
      duracionSesionMinutos: 90,
      longitudPiscina: 25,
    ),
  );

  PeticionDePlan deCadaEstado(EstadoDePeticion estado) => switch (estado) {
    EstadoDePeticion.rechazada => enEstado(
      estado,
      motivo: 'Pediste cinco días y en Precompetitivo son tres.',
    ),
    EstadoDePeticion.aprobada => enEstado(estado, planId: 'p-1'),
    _ => enEstado(estado),
  };

  Future<void> montar(WidgetTester tester, PeticionDePlan peticion) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: EstadoDeMiPeticion(peticion: peticion)),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('FR-025 — los cuatro estados se leen', () {
    testWidgets('cada uno enseña su frase, en español y sin jerga', (
      tester,
    ) async {
      for (final estado in EstadoDePeticion.values) {
        await montar(tester, deCadaEstado(estado));

        expect(
          find.text(estado.comoLoLeeElNadador),
          findsOneWidget,
          reason: 'El estado ${estado.name} no se lee en ninguna parte',
        );
      }
    });

    testWidgets('y ninguno enseña jerga del código', (tester) async {
      for (final estado in EstadoDePeticion.values) {
        await montar(tester, deCadaEstado(estado));

        for (final jerga in [
          'enRevision',
          'esperando',
          'aprobada',
          'rechazada',
          'null',
          'borrador',
        ]) {
          expect(
            find.textContaining(jerga),
            findsNothing,
            reason: '«$jerga» es vocabulario del código, no del nadador',
          );
        }
      }
    });
  });

  group('FR-026 — el motivo, tal como él lo escribió', () {
    testWidgets('se lee entero y sin recortar', (tester) async {
      const loQueEscribio =
          'Pediste cinco días y en Precompetitivo son tres. Te armo uno de '
          'tres y lo subimos cuando veamos cómo te sienta.';

      await montar(
        tester,
        enEstado(EstadoDePeticion.rechazada, motivo: loQueEscribio),
      );

      expect(find.text(loQueEscribio), findsOneWidget);
    });

    testWidgets('en los demás estados no hay tarjeta de motivo', (
      tester,
    ) async {
      for (final estado in EstadoDePeticion.values.where(
        (e) => e != EstadoDePeticion.rechazada,
      )) {
        await montar(tester, deCadaEstado(estado));

        expect(find.byKey(const Key('motivo-del-rechazo')), findsNothing);
      }
    });
  });

  group('FR-027 — no se le promete ninguna fecha', () {
    testWidgets('en ninguno de los cuatro estados', (tester) async {
      // Se busca en **todo el texto de la pantalla**, no en una frase
      // concreta: una promesa puede colarse en cualquier sitio.
      for (final estado in EstadoDePeticion.values) {
        await montar(tester, deCadaEstado(estado));

        final todoElTexto = tester
            .widgetList<Text>(find.byType(Text))
            .map((t) => t.data ?? '')
            .join(' ')
            .toLowerCase();

        for (final promesa in [
          'mañana',
          '24 horas',
          '48 horas',
          'en unos minutos',
          'en breve',
          'enseguida',
          'esta semana',
          'pronto',
        ]) {
          expect(
            todoElTexto,
            isNot(contains(promesa)),
            reason:
                '«$promesa» en el estado ${estado.name} es una promesa que '
                'esta app no puede cumplir',
          );
        }
      }
    });
  });

  group('FR-032 — con una abierta, no se manda otra, y se dice por qué', () {
    testWidgets('esperando y en revisión lo explican', (tester) async {
      for (final estado in [
        EstadoDePeticion.esperando,
        EstadoDePeticion.enRevision,
      ]) {
        await montar(tester, deCadaEstado(estado));

        expect(find.byKey(const Key('una-a-la-vez')), findsOneWidget);
        expect(find.byKey(const Key('pedir-de-nuevo')), findsNothing);
      }
    });

    testWidgets('**control negativo**: cerrada, no lo dice', (tester) async {
      for (final estado in [
        EstadoDePeticion.aprobada,
        EstadoDePeticion.rechazada,
      ]) {
        await montar(tester, deCadaEstado(estado));

        expect(find.byKey(const Key('una-a-la-vez')), findsNothing);
      }
    });
  });

  group('lo que pidió sigue a la vista en los cuatro estados', () {
    testWidgets('para que no tenga que acordarse', (tester) async {
      for (final estado in EstadoDePeticion.values) {
        await montar(tester, deCadaEstado(estado));

        expect(find.textContaining('200 Libre'), findsWidgets);
      }
    });
  });
}
