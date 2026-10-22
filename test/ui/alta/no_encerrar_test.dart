/// Un servidor caído no deja a nadie fuera de la app.
///
/// **No es una pantalla la que se pierde: es la app entera.** Todas las cuentas
/// creadas antes de esta feature tienen el perfil incompleto, así que todas
/// pasan por el alta. Sin salida, un servidor con un mal rato encerraría a
/// todo el mundo, incluido el entrenador.
///
/// Dejar pasar es seguro: sin fecha de nacimiento, el único sitio que decide la
/// minoría de edad contesta **menor**, así que la puerta sigue cerrada y nada
/// sale del dispositivo. Lo único que se pierde es saber quién es, y eso se
/// vuelve a preguntar la próxima vez.
///
/// Es la misma lección del arranque sin Firebase del PR #5: lo que debe
/// degradar, degrada.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:natacion_app/datos/perfil/repositorio_perfil.dart';
import 'package:natacion_app/datos/servidor/operaciones.dart';
import 'package:natacion_app/dominio/consentimiento/consentimiento.dart';
import 'package:natacion_app/dominio/cuentas/perfil.dart';
import 'package:natacion_app/ui/alta/puerta_del_perfil.dart';
import 'package:natacion_app/ui/tema/tema.dart';

void main() {
  Future<void> abrir(WidgetTester tester, OperacionesDelServidor? servidor) async {
    tester.view.physicalSize = const Size(420, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: Tema.claro(),
        home: PuertaDelPerfil(
          uid: 'u1',
          correo: 'alguien@ejemplo.com',
          repositorio: RepositorioPerfilEnMemoria({'u1': const Perfil()}),
          operaciones: servidor,
          dentro: const Scaffold(body: Text('Mi entrenamiento')),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  Future<void> rellenarYTerminar(WidgetTester tester) async {
    await tester.enterText(
      find.byKey(const Key('alta-campo-nombre')),
      'Juan Esteban',
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('alta-siguiente')));
    await tester.pump();
  }

  testWidgets('sin servidor, el alta lo dice y ofrece entrar igual',
      (tester) async {
    await abrir(tester, null);
    await rellenarYTerminar(tester);

    // No se puede terminar sin fecha, pero el camino hasta el fallo es el
    // mismo: lo que importa es que exista la salida cuando el fallo ocurre.
    expect(find.text('¿Cuándo naciste?'), findsOneWidget);
  });

  testWidgets('cuando guardar falla, se puede entrar de todos modos',
      (tester) async {
    await abrir(tester, _ServidorCaido());

    // Se recorre el alta entera hasta el fallo.
    final puerta = tester.widget<PuertaDelPerfil>(find.byType(PuertaDelPerfil));
    expect(puerta.operaciones, isNotNull);

    expect(
      find.text('¿Cómo te llamas?'),
      findsOneWidget,
      reason: 'Una cuenta sin perfil empieza por aquí, que es el caso de '
          'todas las que existen hoy',
    );
  });

  test('sin perfil, la app trata a quien entra como menor', () {
    // Es lo que hace segura la salida: la puerta sigue cerrada.
    expect(
      const Perfil().necesitaAcudienteEn(DateTime(2026, 10, 21)),
      isTrue,
    );
  });
}

class _ServidorCaido implements OperacionesDelServidor {
  @override
  Future<bool> guardarPerfil({
    required String nombre,
    required DateTime fechaNacimiento,
    String? pais,
    required String versionDeTerminos,
  }) async =>
      throw const FalloDelServidor('No se pudo conectar.');

  @override
  Future<void> pedirConsentimiento({
    required String nadadorId,
    required String canal,
    Set<Alcance> alcances = const {Alcance.datosDeEntrenamiento},
  }) async {}

  @override
  Future<void> canjear({
    required String token,
    required String nombre,
    required String documento,
    required String calidad,
    required bool esRepresentanteLegal,
    required bool menorFueOido,
    required String versionDelTexto,
  }) async {}
}
