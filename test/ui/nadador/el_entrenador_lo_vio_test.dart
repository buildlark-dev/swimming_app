/// Ella puede saber que él lo vio, **y no llega ninguna respuesta escrita**
/// (FR-019, SC-008).
///
/// Eso fue la aclaración Q2 y es todo lo que la app promete aquí: una marca de
/// «visto», y la conversación en la piscina. No hay campo de respuesta, no hay
/// hilo y no hay notificación.
///
/// El motivo, dicho sin rodeos: un canal de mensajes prometido es un canal que
/// alguien tiene que atender, y nadie va a atenderlo a las once de la noche.
/// Un canal prometido y desatendido es peor que no tenerlo, porque ella se
/// queda esperando.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:natacion_app/dominio/analisis/peticion_de_feedback.dart';
import 'package:natacion_app/dominio/entidades/nadador.dart';

import 'ayuda_pedir_feedback.dart';

void main() {
  late BancoDelNadador banco;

  setUp(() {
    banco = BancoDelNadador();
    banco.estado.abrirComo(
      const Nadador(id: 'n1', nombre: 'Ana'),
      plan: banco.planCon([
        banco.sesion(
          id: 's1',
          fecha: banco.hoy.subtract(const Duration(days: 2)),
        ),
      ]),
    );
  });

  PeticionDeFeedback laSuya({DateTime? vistaEn}) => PeticionDeFeedback(
    nadadorId: 'n1',
    planId: 'p1',
    sesionId: 's1',
    pregunta: '¿El viraje del tercer 50 lo hice bien?',
    pedidaEn: banco.hoy.subtract(const Duration(days: 1)),
    vistaEn: vistaEn,
  );

  testWidgets('mientras no la ha visto, se dice que está esperando', (
    tester,
  ) async {
    await banco.peticiones.guardar(laSuya());
    await banco.estado.recargarPeticiones();

    await tester.pumpWidget(banco.app());
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('esperando-que-la-vea-s1')), findsOneWidget);
    expect(find.byKey(const Key('ya-la-vio-s1')), findsNothing);
  });

  testWidgets('cuando la marca vista, ella lo ve', (tester) async {
    await banco.peticiones.guardar(laSuya());

    // El entrenador, desde su lado.
    await banco.peticionesDelServidor.marcarVista(
      'n1|p1|s1',
      banco.hoy.subtract(const Duration(hours: 2)),
    );
    await banco.estado.recargarPeticiones();

    await tester.pumpWidget(banco.app());
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('ya-la-vio-s1')), findsOneWidget);
    expect(find.byKey(const Key('esperando-que-la-vea-s1')), findsNothing);
  });

  testWidgets('el «visto» del servidor gana sobre la copia local', (
    tester,
  ) async {
    // Su teléfono guardó la petición sin `vistaEn`, porque cuando preguntó
    // nadie la había visto. El `vistaEn` solo existe en el servidor: es lo
    // único de este documento que ella no escribe.
    await banco.peticiones.guardar(laSuya());
    expect(banco.peticionesLocales.guardadas.values.single.laVio, isFalse);

    await banco.peticionesDelServidor.marcarVista('n1|p1|s1', banco.hoy);
    await banco.estado.recargarPeticiones();

    await tester.pumpWidget(banco.app());
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('ya-la-vio-s1')),
      findsOneWidget,
      reason:
          'si ganara lo local, él podría marcarla vista cien veces y ella no '
          'se enteraría nunca',
    );
  });

  testWidgets('no llega ninguna respuesta escrita, ni un sitio para una', (
    tester,
  ) async {
    await banco.peticiones.guardar(laSuya());
    await banco.peticionesDelServidor.marcarVista('n1|p1|s1', banco.hoy);
    await banco.estado.recargarPeticiones();

    await tester.pumpWidget(banco.app());
    await tester.pumpAndSettle();

    final pintado = tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => (t.data ?? '').toLowerCase())
        .join(' | ');

    for (final palabra in <String>[
      'te respondió',
      'respuesta de tu entrenador',
      'mensaje',
      'responder',
      'contestó:',
    ]) {
      expect(
        pintado,
        isNot(contains(palabra)),
        reason:
            '«$palabra» promete un canal que nadie va a atender a las once de '
            'la noche (Q2)',
      );
    }
  });

  testWidgets('su pregunta sigue siendo la que escribió', (tester) async {
    const suya = '¿El viraje del tercer 50 lo hice bien?';

    await banco.peticiones.guardar(laSuya());
    await banco.peticionesDelServidor.marcarVista('n1|p1|s1', banco.hoy);
    await banco.estado.recargarPeticiones();

    await tester.pumpWidget(banco.app());
    await tester.pumpAndSettle();

    expect(find.text(suya), findsWidgets);
  });
}
