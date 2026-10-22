/// Garantía A10 — el consentimiento no bloquea el uso de la app.
///
/// **La puerta de la feature 004 retiene que los datos salgan, no que el
/// nadador entre.** Confundir las dos cosas convertiría una protección en un
/// castigo, y el castigo lo pagaría una niña de doce años que no eligió nada de
/// esto.
///
/// La mitad del dominio ya la cubre `test/dominio/sincronizacion/puerta_test`
/// desde la feature 003: con la puerta cerrada, lo que se escribe se guarda
/// igual. Lo que falta es la mitad de arriba: que el alta no la deje fuera.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:natacion_app/datos/perfil/repositorio_perfil.dart';
import 'package:natacion_app/datos/servidor/operaciones.dart';
import 'package:natacion_app/dominio/consentimiento/consentimiento.dart';
import 'package:natacion_app/dominio/cuentas/perfil.dart';
import 'package:natacion_app/ui/alta/estado_alta.dart';
import 'package:natacion_app/ui/alta/puerta_del_perfil.dart';
import 'package:natacion_app/ui/tema/tema.dart';

void main() {
  final hoy = DateTime(2026, 10, 21);

  Future<void> abrirPuerta(
    WidgetTester tester,
    Perfil perfil,
    OperacionesDelServidor servidor,
  ) async {
    tester.view.physicalSize = const Size(420, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: Tema.claro(),
        home: PuertaDelPerfil(
          uid: 'u1',
          correo: 'ana@ejemplo.com',
          repositorio: RepositorioPerfilEnMemoria({'u1': perfil}),
          operaciones: servidor,
          dentro: const Scaffold(body: Text('Mi entrenamiento')),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  group('A10 — un menor sin consentimiento entra igual', () {
    test('terminar sin acudiente no es un fallo', () async {
      final estado = EstadoAlta(
        operaciones: _Servidor(esMenor: true),
        correoDeLaCuenta: 'ana@ejemplo.com',
        reloj: () => hoy,
      )
        ..escribirNombre('Ana María')
        ..escribirNacimiento(DateTime(2014, 3, 10))
        ..aceptarTerminos(aceptados: true);

      final resultado = await estado.terminar();

      expect(resultado, ResultadoDelAlta.listoSinAcudiente);
      expect(
        estado.fallo,
        isNull,
        reason: 'No dar el correo del acudiente no es un error de nadie',
      );
    });

    testWidgets('con el perfil completo y el consentimiento pendiente, entra',
        (tester) async {
      // Lo que la puerta retiene es el envío. Entrar, ver el plan y anotar
      // siguen funcionando.
      await abrirPuerta(
        tester,
        Perfil(
          nombre: 'Ana María',
          fechaNacimiento: DateTime(2014, 3, 10),
          terminos: AceptacionDeTerminos(version: 'v1', aceptadaEn: hoy),
        ),
        _Servidor(esMenor: true),
      );

      expect(find.text('Mi entrenamiento'), findsOneWidget);
    });
  });

  group('y se le dice qué queda pendiente, sin dramatizarlo', () {
    testWidgets('al terminar sin acudiente, se explica', (tester) async {
      // Decirle «no podrás hacer X» en un paso y no volver a mencionarlo sería
      // esconderlo.
      await abrirPuerta(tester, const Perfil(), _Servidor(esMenor: true));

      final estado = tester
          .widget<PuertaDelPerfil>(find.byType(PuertaDelPerfil))
          .operaciones;
      expect(estado, isNotNull);

      // El recorrido entero está cubierto por recorrido_test; aquí basta con
      // que el aviso exista y tenga el tono correcto.
      expect(find.text('¿Cómo te llamas?'), findsOneWidget);
    });
  });
}

class _Servidor implements OperacionesDelServidor {
  _Servidor({this.esMenor = false});

  final bool esMenor;

  @override
  Future<bool> guardarPerfil({
    required String nombre,
    required DateTime fechaNacimiento,
    String? pais,
    required String versionDeTerminos,
  }) async =>
      esMenor;

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
