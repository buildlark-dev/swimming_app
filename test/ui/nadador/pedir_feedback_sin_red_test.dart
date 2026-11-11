/// Pedir feedback **sin red** (FR-016, garantía G1).
///
/// «Escribir no espera a la red» es la promesa que la feature 003 montó con la
/// bandeja de salida, y no es una comodidad: es un nadador al borde de la
/// piscina, en un sitio sin señal, con el teléfono en la mano. Si la petición
/// esperara al servidor, el único momento en que querría preguntar es el
/// momento en que no podría.
///
/// Así que se escribe primero en el dispositivo y el envío se intenta después.
/// Lo que esta prueba fija es esa **secuencia**, no solo el resultado: que la
/// escritura local ocurra aunque el servidor falle, y que se reintente cuando
/// vuelva la señal.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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

  testWidgets('con el servidor caído la petición se acepta y se guarda', (
    tester,
  ) async {
    banco.peticionesDelServidor.falla = true;

    await tester.pumpWidget(banco.app());
    await tester.pumpAndSettle();

    await banco.pedir(tester, 's1', '¿El viraje del tercer 50 lo hice bien?');

    expect(
      banco.peticionesLocales.guardadas,
      hasLength(1),
      reason: 'lo que escribió está a salvo en su dispositivo',
    );
    expect(banco.peticionesDelServidor.guardadas, isEmpty);
  });

  testWidgets('y la pantalla lo dice, en lugar de quedarse quieta', (
    tester,
  ) async {
    banco.peticionesDelServidor.falla = true;

    await tester.pumpWidget(banco.app());
    await tester.pumpAndSettle();

    await banco.pedir(tester, 's1', '¿El viraje?');

    expect(find.byKey(const Key('pregunta-guardada')), findsOneWidget);
  });

  testWidgets('cuando vuelve la señal, la petición sube', (tester) async {
    banco.peticionesDelServidor.falla = true;

    await tester.pumpWidget(banco.app());
    await tester.pumpAndSettle();

    await banco.pedir(tester, 's1', '¿El viraje?');
    expect(banco.peticionesDelServidor.guardadas, isEmpty);

    // Vuelve la señal y se sincroniza, como cuando la app vuelve a primer
    // plano.
    banco.peticionesDelServidor.falla = false;
    await banco.estado.sincronizar();

    expect(
      banco.peticionesDelServidor.guardadas,
      hasLength(1),
      reason:
          'una petición que se queda en el teléfono para siempre es una '
          'pregunta que el entrenador no va a leer nunca',
    );
  });

  testWidgets('lo que ya subió no se vuelve a subir', (tester) async {
    await tester.pumpWidget(banco.app());
    await tester.pumpAndSettle();

    await banco.pedir(tester, 's1', '¿El viraje?');
    final escriturasTrasPedir = banco.peticionesDelServidor.escrituras;

    await banco.estado.sincronizar();
    await banco.estado.sincronizar();

    expect(
      banco.peticionesDelServidor.escrituras,
      escriturasTrasPedir,
      reason:
          'reenviar lo ya enviado borraría el «la vi» del entrenador, porque '
          'la copia local no lo lleva',
    );
  });

  test('guardar no pregunta por la red: solo escribe y lo intenta', () async {
    // Sin pantalla. La petición entra por el repositorio directamente, que es
    // donde vive la garantía: no hay ninguna consulta de conectividad antes de
    // escribir en el dispositivo.
    banco.peticionesDelServidor.falla = true;

    final resultado = await banco.estado.pedirFeedback(
      sesion: banco.sesion(
        id: 's1',
        fecha: banco.hoy.subtract(const Duration(days: 2)),
      ),
      pregunta: '¿El viraje?',
    );

    expect(resultado.si, isTrue);
    expect(banco.peticionesLocales.guardadas, hasLength(1));
  });
}
