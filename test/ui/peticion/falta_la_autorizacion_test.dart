/// Garantía P9 — la app dice que falta la autorización, y **no finge** que la
/// solicitud se envió.
///
/// Las dos mitades cuentan. Decirlo es la primera; no decir lo contrario es la
/// segunda, y es la que se escapa: una pantalla que pone «¡Enviada!» sobre
/// algo que sigue en el teléfono enseña a no creerle a la app.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:natacion_app/dominio/metodologia/estilos.dart';
import 'package:natacion_app/dominio/peticiones/peticion.dart';
import 'package:natacion_app/ui/peticion/estado_de_mi_peticion.dart';

void main() {
  final hoy = DateTime(2026, 11, 2);

  PeticionDePlan retenida() => PeticionDePlan(
    nadadorId: 'n-ana',
    enviadaEn: hoy,
    estado: EstadoDePeticion.esperando,
    respuestas: RespuestasDePeticion(
      estiloObjetivo: Estilo.libre,
      pruebaObjetivo: '200 Libre',
      fechaDeCompetencia: hoy.add(const Duration(days: 24)),
      diasDisponibles: [hoy.add(const Duration(days: 1))],
      duracionSesionMinutos: 90,
      longitudPiscina: 25,
    ),
  );

  Future<void> montar(
    WidgetTester tester, {
    required bool esperandoAutorizacion,
  }) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EstadoDeMiPeticion(
            peticion: retenida(),
            esperandoAutorizacion: esperandoAutorizacion,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('retenida por falta de consentimiento', () {
    testWidgets('se dice que falta la autorización del acudiente', (
      tester,
    ) async {
      await montar(tester, esperandoAutorizacion: true);

      expect(find.byKey(const Key('falta-la-autorizacion')), findsOneWidget);
      expect(find.textContaining('acudiente'), findsWidgets);
    });

    testWidgets('**en ninguna parte dice que se envió**', (tester) async {
      await montar(tester, esperandoAutorizacion: true);

      for (final mentira in [
        'Le llegó',
        'le llegó',
        'Enviada',
        'enviada',
        'Esperando a tu entrenador',
      ]) {
        expect(
          find.textContaining(mentira),
          findsNothing,
          reason:
              '«$mentira» le diría a quien la mandó que salió del teléfono, y '
              'no salió',
        );
      }
    });

    testWidgets('y se le dice que no tiene que volver a escribirlo', (
      tester,
    ) async {
      await montar(tester, esperandoAutorizacion: true);

      expect(find.textContaining('no tienes que'), findsWidgets);
    });

    testWidgets('lo que respondió sigue a la vista', (tester) async {
      // Retenida no es perdida. Que vea sus respuestas es la prueba.
      await montar(tester, esperandoAutorizacion: true);

      expect(find.textContaining('200 Libre'), findsWidgets);
    });
  });

  group('**control negativo**: cuando sí salió', () {
    testWidgets('dice que le llegó, y no habla de autorización', (
      tester,
    ) async {
      await montar(tester, esperandoAutorizacion: false);

      expect(find.byKey(const Key('falta-la-autorizacion')), findsNothing);
      expect(
        find.text(EstadoDePeticion.esperando.comoLoLeeElNadador),
        findsOneWidget,
      );
    });
  });
}
