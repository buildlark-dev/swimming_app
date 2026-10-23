/// El recorrido del alta — escenarios C1, C2 y C4.
///
/// Lo que se comprueba aquí no es que las pantallas se pinten: es que **el
/// recorrido no pierde lo que alguien escribió**. Un alta que obliga a
/// reescribir un campo al volver atrás es un alta que la gente abandona, y
/// quien la abandona no entra a la app.
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

  EstadoAlta estadoCon({OperacionesDelServidor? servidor}) => EstadoAlta(
        operaciones: servidor ?? _ServidorQueAcepta(),
        correoDeLaCuenta: 'nadador@ejemplo.com',
        nadadorId: 'n1',
        reloj: () => hoy,
      );

  Future<void> abrir(
    WidgetTester tester,
    EstadoAlta estado, {
    void Function(ResultadoDelAlta)? alTerminar,
  }) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: Tema.claro(),
        home: ChangeNotifierProvider<EstadoAlta>.value(
          value: estado,
          child: PantallaAlta(alTerminar: alTerminar ?? (_) {}),
        ),
      ),
    );
    await tester.pump();
  }

  Future<void> continuar(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('alta-siguiente')));
    await tester.pump();
  }

  group('C1 — los pasos se recorren', () {
    testWidgets('empieza por el nombre, y dice en qué paso va', (tester) async {
      final estado = estadoCon();
      await abrir(tester, estado);

      expect(find.text('¿Cómo te llamas?'), findsOneWidget);
      expect(find.text('Paso 1 de 4'), findsOneWidget);
    });

    testWidgets('no se puede continuar con el paso a medias', (tester) async {
      // Un botón que se puede pulsar y no hace nada es peor que uno apagado:
      // el segundo dice que falta algo.
      final estado = estadoCon();
      await abrir(tester, estado);

      final boton = tester.widget<FilledButton>(
        find.byKey(const Key('alta-siguiente')),
      );
      expect(boton.onPressed, isNull);
    });

    testWidgets('con el nombre escrito, sí', (tester) async {
      final estado = estadoCon();
      await abrir(tester, estado);

      await tester.enterText(
        find.byKey(const Key('alta-campo-nombre')),
        'Ana María',
      );
      await tester.pump();
      await continuar(tester);

      expect(find.text('¿Cuándo naciste?'), findsOneWidget);
      expect(find.text('Paso 2 de 4'), findsOneWidget);
    });

    testWidgets('el país se puede dejar en blanco', (tester) async {
      // Es opcional (FR-009): un dato que no decide nada no bloquea a nadie.
      final estado = estadoCon();
      estado
        ..escribirNombre('Ana')
        ..escribirNacimiento(DateTime(1995, 4, 12))
        ..avanzar()
        ..avanzar();

      await abrir(tester, estado);

      expect(find.text('¿De dónde eres?'), findsOneWidget);
      final boton = tester.widget<FilledButton>(
        find.byKey(const Key('alta-siguiente')),
      );
      expect(boton.onPressed, isNotNull);
    });
  });

  group('C2 — volver atrás no borra nada', () {
    testWidgets('lo escrito sigue ahí', (tester) async {
      final estado = estadoCon();
      await abrir(tester, estado);

      await tester.enterText(
        find.byKey(const Key('alta-campo-nombre')),
        'Juan Esteban',
      );
      await tester.pump();
      await continuar(tester);

      await tester.tap(find.byKey(const Key('alta-volver')));
      await tester.pump();

      expect(estado.perfil.nombre, 'Juan Esteban');
      expect(find.text('Juan Esteban'), findsOneWidget);
    });

    testWidgets('en el primer paso no hay a dónde volver', (tester) async {
      await abrir(tester, estadoCon());

      expect(find.byKey(const Key('alta-volver')), findsNothing);
    });
  });

  group('C4 — un menor recorre un paso más', () {
    testWidgets('al poner una fecha de menor, aparece el del acudiente',
        (tester) async {
      final estado = estadoCon();
      await abrir(tester, estado);

      expect(estado.totalDePasos, 4);

      estado.escribirNacimiento(DateTime(2014, 3, 10));
      await tester.pump();

      expect(
        estado.totalDePasos,
        5,
        reason: 'El paso del acudiente aparece en cuanto la fecha dice que es '
            'menor, no antes',
      );
      expect(estado.pasos.last, PasoDelAlta.acudiente);
    });

    testWidgets('y se avisa en el mismo paso de la fecha', (tester) async {
      final estado = estadoCon()..escribirNombre('Ana');
      estado.avanzar();
      await abrir(tester, estado);

      estado.escribirNacimiento(DateTime(2014, 3, 10));
      await tester.pump();

      expect(find.byKey(const Key('alta-aviso-menor')), findsOneWidget);
    });

    testWidgets('si corrige la fecha a una de adulto, el paso desaparece',
        (tester) async {
      final estado = estadoCon()
        ..escribirNombre('Ana')
        ..escribirNacimiento(DateTime(2014, 3, 10));

      expect(estado.totalDePasos, 5);

      estado.escribirNacimiento(DateTime(1995, 4, 12));
      expect(estado.totalDePasos, 4);
    });
  });

  group('al terminar', () {
    testWidgets('un adulto queda listo, sin solicitud', (tester) async {
      final servidor = _ServidorQueAcepta();
      final estado = estadoCon(servidor: servidor)
        ..escribirNombre('Juan')
        ..escribirNacimiento(DateTime(1995, 4, 12))
        ..aceptarTerminos(aceptados: true);

      final resultado = await estado.terminar();

      expect(resultado, ResultadoDelAlta.listo);
      expect(servidor.perfilesGuardados, 1);
      expect(
        servidor.solicitudes,
        isEmpty,
        reason: 'A un adulto no se le pide consentimiento de nadie',
      );
    });

    testWidgets('un menor con correo deja la solicitud emitida',
        (tester) async {
      final servidor = _ServidorQueAcepta(esMenor: true);
      final estado = estadoCon(servidor: servidor)
        ..escribirNombre('Ana')
        ..escribirNacimiento(DateTime(2014, 3, 10))
        ..aceptarTerminos(aceptados: true)
        ..escribirCorreoDelAcudiente('madre@ejemplo.com');

      final resultado = await estado.terminar();

      expect(resultado, ResultadoDelAlta.listoConSolicitud);
      expect(servidor.solicitudes, ['madre@ejemplo.com']);
    });

    testWidgets('un menor sin correo entra igual, y consta', (tester) async {
      // **No es un fallo** (FR-019). Lo que toca es decirle qué no podrá
      // hacer, no bloquearla.
      final servidor = _ServidorQueAcepta(esMenor: true);
      final estado = estadoCon(servidor: servidor)
        ..escribirNombre('Ana')
        ..escribirNacimiento(DateTime(2014, 3, 10))
        ..aceptarTerminos(aceptados: true);

      final resultado = await estado.terminar();

      expect(resultado, ResultadoDelAlta.listoSinAcudiente);
      expect(servidor.solicitudes, isEmpty);
    });

    testWidgets('sin servidor lo dice, y no pierde lo escrito',
        (tester) async {
      final estado = EstadoAlta(
        operaciones: null,
        correoDeLaCuenta: 'nadador@ejemplo.com',
        reloj: () => hoy,
      )
        ..escribirNombre('Juan')
        ..escribirNacimiento(DateTime(1995, 4, 12))
        ..aceptarTerminos(aceptados: true);

      final resultado = await estado.terminar();

      expect(resultado, isNull);
      expect(estado.fallo, contains('no se ha perdido'));
      expect(estado.perfil.nombre, 'Juan');
    });
  });

  group('C6 — el correo del acudiente no puede ser el suyo', () {
    test('se avisa en el propio campo', () {
      final estado = estadoCon()
        ..escribirNacimiento(DateTime(2014, 3, 10))
        ..escribirCorreoDelAcudiente('nadador@ejemplo.com');

      expect(estado.problemaDelAcudiente, isNotNull);
      expect(estado.elPasoEstaListo, isFalse);
    });

    test('el de su madre sí vale', () {
      final estado = estadoCon()
        ..escribirNacimiento(DateTime(2014, 3, 10))
        ..escribirCorreoDelAcudiente('madre@ejemplo.com');

      expect(estado.problemaDelAcudiente, isNull);
    });

    test('dejarlo en blanco también deja continuar', () {
      final estado = estadoCon()..escribirNacimiento(DateTime(2014, 3, 10));

      expect(estado.problemaDelAcudiente, isNull);
    });
  });
}

// ---------------------------------------------------------------------------

class _ServidorQueAcepta implements OperacionesDelServidor {
  _ServidorQueAcepta({this.esMenor = false});

  final bool esMenor;
  int perfilesGuardados = 0;
  final solicitudes = <String>[];

  @override
  Future<PerfilGuardado> guardarPerfil({
    required String nombre,
    required DateTime fechaNacimiento,
    String? pais,
    required String versionDeTerminos,
  }) async {
    perfilesGuardados++;
    return PerfilGuardado(esMenor: esMenor, nadadorId: 'n1');
  }

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
