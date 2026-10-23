/// Reproduce el segundo hallazgo: **la segunda cuenta entra sin pasar por el
/// alta**.
///
/// Cerrar sesión y crear otra cuenta sin cerrar la PWA dejaba entrar directo.
/// Lo que se comprueba aquí es que al cambiar de cuenta **el estado de la
/// puerta se tira entero**: si sobreviviera el «entré de todos modos» del
/// anterior, el siguiente heredaría su permiso.
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
  final hoy = DateTime(2026, 10, 22);

  Widget app(String uid, RepositorioPerfil repositorio) => MaterialApp(
        theme: Tema.claro(),
        home: PuertaDelPerfil(
          key: ValueKey(uid),
          uid: uid,
          correo: '$uid@ejemplo.com',
          repositorio: repositorio,
          operaciones: _Servidor(),
          dentro: const Scaffold(body: Text('Mi entrenamiento')),
        ),
      );

  testWidgets('al cambiar de cuenta, la nueva pasa por el alta',
      (tester) async {
    tester.view.physicalSize = const Size(420, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final repositorio = RepositorioPerfilEnMemoria({
      // La primera ya tiene perfil: entra directa.
      'u1': Perfil(
        nombre: 'Juan',
        fechaNacimiento: DateTime(1990, 1, 1),
        terminos: AceptacionDeTerminos(version: 'v1', aceptadaEn: hoy),
      ),
      // La segunda es nueva: tiene que recorrer el alta.
    });

    await tester.pumpWidget(app('u1', repositorio));
    await tester.pump();
    await tester.pump();

    expect(find.text('Mi entrenamiento'), findsOneWidget);

    // Cierra sesión y entra otra cuenta, **sin recrear la app**.
    await tester.pumpWidget(app('u2', repositorio));
    await tester.pump();
    await tester.pump();

    expect(
      find.text('¿Cómo te llamas?'),
      findsOneWidget,
      reason: 'La segunda cuenta no tiene perfil: tiene que pasar por el alta, '
          'no heredar el permiso de la anterior',
    );
    expect(find.text('Mi entrenamiento'), findsNothing);
  });
}

class _Servidor implements OperacionesDelServidor {
  @override
  Future<PerfilGuardado> guardarPerfil({
    required String nombre,
    required DateTime fechaNacimiento,
    String? pais,
    required String versionDeTerminos,
  }) async =>
      const PerfilGuardado(esMenor: false, nadadorId: 'n1');

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
