/// Garantía A9, del lado del entrenador — ver de dónde vino cada uno.
///
/// Es la contrapartida de haberle dejado al nadador declarar el correo de su
/// acudiente. La app no juzga si ese canal es de fiar: **lo marca, y el
/// entrenador decide**. Es el principio IV aplicado a algo que no es
/// metodología.
///
/// Y por eso se puede volver a pedir **aunque ya esté vigente**: si el canal lo
/// declaró un niño de doce años y el entrenador quiere pedirlo desde su propia
/// matrícula, ese es exactamente el caso para el que existe el campo.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:natacion_app/dominio/consentimiento/consentimiento.dart';
import 'package:natacion_app/dominio/consentimiento/declaracion.dart';
import 'package:natacion_app/ui/consentimiento/panel_estado.dart';
import 'package:natacion_app/ui/tema/tema.dart';

void main() {
  Future<void> abrir(
    WidgetTester tester,
    List<EstadoDelNadador> nadadores, {
    List<String>? pedidos,
  }) async {
    tester.view.physicalSize = const Size(420, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: Tema.claro(),
        home: Scaffold(
          body: PanelEstadoConsentimiento(
            nadadores: nadadores,
            alPedir: (id, canal) async => pedidos?.add('$id:$canal'),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  EstadoDelNadador conOrigen(OrigenDeLaDeclaracion? origen) => EstadoDelNadador(
        nadadorId: 'n1',
        nombre: 'Ana María Restrepo',
        estado: EstadoDeConsentimiento.vigente,
        alcances: const {Alcance.datosDeEntrenamiento},
        origen: origen,
      );

  group('A9 — el origen se ve', () {
    testWidgets('uno declarado por el nadador lo dice', (tester) async {
      await abrir(
        tester,
        [conOrigen(OrigenDeLaDeclaracion.declaradoPorElNadador)],
      );

      expect(find.byKey(const Key('origen-n1')), findsOneWidget);
      expect(find.text('Declarado por el nadador'), findsOneWidget);
    });

    testWidgets('uno de la matrícula del entrenador, también', (tester) async {
      await abrir(
        tester,
        [conOrigen(OrigenDeLaDeclaracion.matriculaDelEntrenador)],
      );

      expect(find.text('De la matrícula del entrenador'), findsOneWidget);
    });

    testWidgets('los dos se distinguen en pantalla', (tester) async {
      // Si se leyeran igual, el campo sería decorativo.
      await abrir(tester, [
        const EstadoDelNadador(
          nadadorId: 'n1',
          nombre: 'Ana',
          estado: EstadoDeConsentimiento.vigente,
          origen: OrigenDeLaDeclaracion.declaradoPorElNadador,
        ),
        const EstadoDelNadador(
          nadadorId: 'n2',
          nombre: 'Juan',
          estado: EstadoDeConsentimiento.vigente,
          origen: OrigenDeLaDeclaracion.matriculaDelEntrenador,
        ),
      ]);

      final uno = tester.widget<Text>(find.byKey(const Key('origen-n1')));
      final otro = tester.widget<Text>(find.byKey(const Key('origen-n2')));

      expect(uno.data, isNot(otro.data));
    });

    testWidgets('sin haber pedido nada, no se inventa un origen',
        (tester) async {
      await abrir(tester, [
        const EstadoDelNadador(
          nadadorId: 'n1',
          nombre: 'Ana',
          estado: EstadoDeConsentimiento.sinPedir,
        ),
      ]);

      expect(find.byKey(const Key('origen-n1')), findsNothing);
    });
  });

  group('se puede volver a pedir', () {
    testWidgets('aunque el consentimiento ya esté vigente', (tester) async {
      // Es la salida que el entrenador tiene si no se fía del canal que
      // declaró el nadador.
      await abrir(
        tester,
        [conOrigen(OrigenDeLaDeclaracion.declaradoPorElNadador)],
      );

      expect(find.text('Volver a pedir'), findsOneWidget);
    });

    testWidgets('y si no hay ninguno, el botón dice «Pedir»', (tester) async {
      await abrir(tester, [
        const EstadoDelNadador(
          nadadorId: 'n1',
          nombre: 'Ana',
          estado: EstadoDeConsentimiento.sinPedir,
        ),
      ]);

      expect(find.text('Pedir'), findsOneWidget);
    });
  });
}
