/// Garantía P16 — el nadador no ve el borrador antes de la firma.
///
/// Esta prueba comprueba la mitad que se ve. La otra mitad, la que de verdad
/// lo sostiene, es que **el borrador no existe en su dispositivo**: se genera
/// en el del entrenador al abrir la petición (decisión D1). Si lo generara su
/// teléfono, esto sería una promesa de la interfaz y no un hecho, porque el
/// plan estaría guardado ahí.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:natacion_app/dominio/metodologia/estilos.dart';
import 'package:natacion_app/dominio/peticiones/peticion.dart';
import 'package:natacion_app/ui/peticion/estado_de_mi_peticion.dart';

void main() {
  final hoy = DateTime(2026, 11, 3);

  PeticionDePlan enEstado(EstadoDePeticion estado) => PeticionDePlan(
    nadadorId: 'n-ana',
    enviadaEn: hoy.subtract(const Duration(days: 1)),
    estado: estado,
    motivoDelRechazo: estado == EstadoDePeticion.rechazada
        ? 'Esta semana no.'
        : null,
    planId: estado == EstadoDePeticion.aprobada ? 'p-1' : null,
    respondidaEn: estado.estaAbierta ? null : hoy,
    respuestas: RespuestasDePeticion(
      estiloObjetivo: Estilo.libre,
      pruebaObjetivo: '200 Libre',
      fechaDeCompetencia: hoy.add(const Duration(days: 24)),
      diasDisponibles: [hoy.add(const Duration(days: 1))],
      duracionSesionMinutos: 90,
      longitudPiscina: 25,
    ),
  );

  Future<void> montar(WidgetTester tester, EstadoDePeticion estado) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: EstadoDeMiPeticion(peticion: enEstado(estado))),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('en ningún estado se asoma el contenido del plan', () {
    testWidgets('ni series, ni ejercicios, ni metros, ni zonas', (
      tester,
    ) async {
      for (final estado in EstadoDePeticion.values) {
        await montar(tester, estado);

        final todoElTexto = tester
            .widgetList<Text>(find.byType(Text))
            .map((t) => t.data ?? '')
            .join(' ');

        for (final delPlan in [
          'AL',
          'PN',
          'PULL',
          'RPE',
          'A1',
          'A2',
          'AT',
          'Hyp',
          'Microciclo',
          'Sesión 1',
          'Acumulación',
          'Transformación',
          'Realización',
        ]) {
          expect(
            todoElTexto,
            isNot(contains(delPlan)),
            reason:
                '«$delPlan» es contenido del plan, y en ${estado.name} el '
                'nadador todavía no lo puede ver',
          );
        }
      }
    });

    testWidgets('aprobada tampoco lo enseña: firmar no es entregar', (
      tester,
    ) async {
      // Aprobar deja el plan en `aprobado`. Entregarlo es el acto aparte que
      // la feature 007 tiene en `Ver Plan`. Entre los dos, el nadador sabe que
      // su solicitud salió bien y nada más.
      await montar(tester, EstadoDePeticion.aprobada);

      expect(find.textContaining('p-1'), findsNothing);
      expect(find.byKey(const Key('borrador-de-la-peticion')), findsNothing);
    });
  });

  group('la pantalla ni siquiera sabe generar', () {
    test('su fuente no importa el motor ni lo que lo rodea', () {
      // Si esta pantalla pudiera generar, el plan existiría en el teléfono del
      // nadador aunque no se pintara, y P16 pasaría a depender de qué se
      // enseña en lugar de qué existe.
      final fuente = File(
        'lib/ui/peticion/estado_de_mi_peticion.dart',
      ).readAsStringSync();

      for (final prohibido in [
        'generar_desde_peticion',
        'generacion/generador',
        'Generador(',
        'auditoria',
      ]) {
        expect(
          fuente,
          isNot(contains(prohibido)),
          reason:
              '«$prohibido» pondría el borrador en el dispositivo del '
              'nadador',
        );
      }
    });

    test('y la del destino del nadador tampoco', () {
      final fuente = File(
        'lib/ui/peticion/peticion_del_nadador.dart',
      ).readAsStringSync();

      for (final prohibido in [
        'generar_desde_peticion',
        'generacion/generador',
        'Generador(',
      ]) {
        expect(fuente, isNot(contains(prohibido)));
      }
    });
  });
}
