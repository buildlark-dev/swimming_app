/// A un adulto **no se le menciona nada** de acudientes ni consentimiento.
///
/// Parece una obviedad y no lo es: lo fácil al construir esto es enseñar el
/// paso siempre y deshabilitarlo, o poner una nota explicando que «si fueras
/// menor haría falta...». A un adulto eso le sobra, y lo que sobra confunde.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:natacion_app/dominio/consentimiento/consentimiento.dart';
import 'package:natacion_app/datos/servidor/operaciones.dart';
import 'package:natacion_app/ui/alta/estado_alta.dart';
import 'package:natacion_app/ui/alta/pantalla_alta.dart';
import 'package:natacion_app/ui/tema/tema.dart';
import 'package:provider/provider.dart';

void main() {
  final hoy = DateTime(2026, 10, 21);

  EstadoAlta deAdulto() => EstadoAlta(
        operaciones: _Servidor(),
        correoDeLaCuenta: 'adulto@ejemplo.com',
        reloj: () => hoy,
      )
        ..escribirNombre('Juan Esteban')
        ..escribirNacimiento(DateTime(1990, 4, 12));

  Future<void> abrir(WidgetTester tester, EstadoAlta estado) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: Tema.claro(),
        home: ChangeNotifierProvider<EstadoAlta>.value(
          value: estado,
          child: PantallaAlta(alTerminar: (_) {}),
        ),
      ),
    );
    await tester.pump();
  }

  test('un adulto recorre cuatro pasos, no cinco', () {
    expect(deAdulto().totalDePasos, 4);
    expect(deAdulto().pasos, isNot(contains(PasoDelAlta.acudiente)));
  });

  testWidgets('en el paso de la fecha no se le avisa de nada', (tester) async {
    final estado = deAdulto();
    estado.avanzar();
    await abrir(tester, estado);

    expect(find.byKey(const Key('alta-aviso-menor')), findsNothing);
  });

  testWidgets('la palabra «acudiente» no aparece en ningún paso suyo',
      (tester) async {
    final estado = deAdulto();

    for (var i = 0; i < estado.totalDePasos; i++) {
      // **El paso de los términos se salta, y no es una excusa.** Ese texto es
      // un documento legal: tiene que explicar qué pasa con los menores
      // aunque quien lo lea sea adulto, igual que un contrato de alquiler
      // habla de la fianza aunque tú no vayas a perderla.
      //
      // Lo que esta prueba vigila son **las palabras de la app**, no las del
      // documento que enseña.
      if (estado.pasoActual != PasoDelAlta.terminos) {
        await abrir(tester, estado);
        expect(
          find.textContaining('acudiente'),
          findsNothing,
          reason: 'Paso ${estado.numeroDePaso}: a un adulto le sobra',
        );
        expect(find.textContaining('consentimiento'), findsNothing);
      }

      if (!estado.esElUltimo && estado.elPasoEstaListo) estado.avanzar();
    }
  });

  test('al terminar, no se pide consentimiento a nadie', () async {
    final servidor = _Servidor();
    final estado = EstadoAlta(
      operaciones: servidor,
      correoDeLaCuenta: 'adulto@ejemplo.com',
      reloj: () => hoy,
    )
      ..escribirNombre('Juan')
      ..escribirNacimiento(DateTime(1990, 4, 12))
      ..aceptarTerminos(aceptados: true);

    await estado.terminar();

    expect(servidor.solicitudes, isEmpty);
  });
}

class _Servidor implements OperacionesDelServidor {
  final solicitudes = <String>[];

  @override
  Future<bool> guardarPerfil({
    required String nombre,
    required DateTime fechaNacimiento,
    String? pais,
    required String versionDeTerminos,
  }) async =>
      false;

  @override
  Future<void> pedirConsentimiento({
    required String nadadorId,
    required String canal,
    Set<Alcance> alcances = const {Alcance.datosDeEntrenamiento},
  }) async {
    solicitudes.add(canal);
  }

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
