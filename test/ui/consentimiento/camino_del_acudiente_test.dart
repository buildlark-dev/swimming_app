/// El camino completo del acudiente, de principio a fin.
///
/// **Esta prueba existe porque el camino no existía.** La feature 004 construyó
/// el formulario, el mecanismo de solicitud y la puerta que retiene los datos,
/// y los tres nunca se tocaron entre sí fuera de las pruebas: no había ruta que
/// entendiera el enlace, así que el correo que un acudiente recibiera no
/// llevaba a ninguna parte.
///
/// No se notó porque cada pieza tenía su prueba de unidad y ninguna montaba el
/// camino entero. Es el mismo patrón que la feature 005 encontró dos veces: un
/// banco solo mide los caminos que monta.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:natacion_app/datos/recursos/textos_legales.dart';
import 'package:natacion_app/datos/servidor/operaciones.dart';
import 'package:natacion_app/dominio/consentimiento/consentimiento.dart';
import 'package:natacion_app/ui/consentimiento/enlace_del_acudiente.dart';
import 'package:natacion_app/ui/consentimiento/pagina_del_acudiente.dart';
import 'package:natacion_app/ui/tema/tema.dart';

void main() {
  group('el enlace se entiende', () {
    test('un enlace con token', () {
      expect(
        tokenDelEnlace(Uri.parse('https://app.example/consentimiento?t=abc123')),
        'abc123',
      );
    });

    test('servido desde una subcarpeta', () {
      expect(
        tokenDelEnlace(Uri.parse('https://x/app/consentimiento?t=abc')),
        'abc',
      );
    });

    test('con barra final', () {
      expect(
        tokenDelEnlace(Uri.parse('https://x/consentimiento/?t=abc')),
        'abc',
      );
    });

    test('cualquier otra ruta no es asunto suyo', () {
      // Si esto devolviera algo, abrir la app normalmente llevaría al
      // formulario del acudiente, que sería bastante peor que no tener ruta.
      expect(tokenDelEnlace(Uri.parse('https://x/')), isNull);
      expect(tokenDelEnlace(Uri.parse('https://x/planes?t=abc')), isNull);
    });

    test('la ruta correcta sin token tampoco sirve', () {
      expect(tokenDelEnlace(Uri.parse('https://x/consentimiento')), isNull);
      expect(tokenDelEnlace(Uri.parse('https://x/consentimiento?t=')), isNull);
      expect(
        tokenDelEnlace(Uri.parse('https://x/consentimiento?t=%20%20')),
        isNull,
      );
    });
  });

  group('la página lleva al formulario', () {
    Future<void> abrir(
      WidgetTester tester, {
      OperacionesDelServidor? operaciones,
      Future<String> Function(String)? texto,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: Tema.claro(),
          home: PaginaDelAcudiente(
            token: 'un-token',
            operaciones: operaciones,
            textos: CargadorTextosLegales(
              cargar: texto ?? (_) async => 'Texto informativo de prueba',
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
    }

    testWidgets('con el texto cargado, enseña el formulario', (tester) async {
      await abrir(tester, operaciones: _ServidorQueAcepta());

      expect(find.byKey(const Key('texto-informativo')), findsOneWidget);
      expect(find.text('Texto informativo de prueba'), findsOneWidget);
      expect(find.byKey(const Key('boton-confirmar')), findsOneWidget);
    });

    testWidgets('sin servidor, lo dice y no enseña formulario',
        (tester) async {
      // Enseñar un formulario que no va a funcionar sería peor que no
      // enseñarlo: el acudiente lo rellenaría y no pasaría nada.
      await abrir(tester, operaciones: null);

      expect(find.byKey(const Key('boton-confirmar')), findsNothing);
      expect(find.textContaining('No se pudo conectar'), findsOneWidget);
    });

    testWidgets('sin el texto informativo, tampoco', (tester) async {
      // **Autorizar sin leer qué se autoriza no es consentimiento informado.**
      // Enseñar el formulario sin el texto sería fingir que sí lo es.
      await abrir(
        tester,
        operaciones: _ServidorQueAcepta(),
        texto: (_) async => throw Exception('no está el recurso'),
      );

      expect(find.byKey(const Key('boton-confirmar')), findsNothing);
      expect(find.textContaining('antes de autorizar'), findsOneWidget);
    });
  });

  group('el ciclo cierra', () {
    Future<void> rellenarYConfirmar(WidgetTester tester) async {
      await tester.enterText(
        find.byKey(const Key('campo-nombre')),
        'María Restrepo',
      );
      await tester.enterText(
        find.byKey(const Key('campo-documento')),
        '43218765',
      );
      await tester.enterText(find.byKey(const Key('campo-calidad')), 'madre');
      await tester.pump();
      await tester.tap(find.byKey(const Key('casilla-representante')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('casilla-menor-oido')));
      await tester.pump();

      // El formulario no cabe entero: hay que llegar al botón, como llega un
      // acudiente con el dedo.
      await tester.ensureVisible(find.byKey(const Key('boton-confirmar')));
      await tester.pump();

      await tester.tap(find.byKey(const Key('boton-confirmar')));
      await tester.pump();
      await tester.pump();
    }

    testWidgets('al autorizar, el token llega al servidor', (tester) async {
      final servidor = _ServidorQueAcepta();

      await tester.pumpWidget(
        MaterialApp(
          theme: Tema.claro(),
          home: PaginaDelAcudiente(
            token: 'el-token-del-enlace',
            operaciones: servidor,
            textos: CargadorTextosLegales(
              cargar: (_) async => 'Texto informativo de prueba',
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      await rellenarYConfirmar(tester);

      expect(
        servidor.canjeados,
        ['el-token-del-enlace'],
        reason: 'Es el camino entero: el enlace trae un token, el formulario '
            'lo rellena un acudiente, y el servidor lo canjea',
      );
      expect(find.textContaining('Queda registrada'), findsOneWidget);
    });

    testWidgets('un enlace que ya no sirve lo dice sin decir por qué',
        (tester) async {
      // El servidor no distingue cuál de los tres motivos fue, y aquí tampoco:
      // distinguirlos le diría a quien prueba enlaces cuáles existieron.
      await tester.pumpWidget(
        MaterialApp(
          theme: Tema.claro(),
          home: PaginaDelAcudiente(
            token: 'uno-viejo',
            operaciones: _ServidorQueRechaza(),
            textos: CargadorTextosLegales(
              cargar: (_) async => 'Texto informativo de prueba',
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      await rellenarYConfirmar(tester);

      expect(find.byKey(const Key('error-de-confirmacion')), findsOneWidget);
      expect(find.textContaining('Queda registrada'), findsNothing);
    });
  });
}

// ---------------------------------------------------------------------------

class _ServidorQueAcepta implements OperacionesDelServidor {
  final canjeados = <String>[];

  @override
  Future<void> canjear({
    required String token,
    required String nombre,
    required String documento,
    required String calidad,
    required bool esRepresentanteLegal,
    required bool menorFueOido,
    required String versionDelTexto,
  }) async {
    canjeados.add(token);
  }

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
  }) async {}
}

class _ServidorQueRechaza extends _ServidorQueAcepta {
  @override
  Future<void> canjear({
    required String token,
    required String nombre,
    required String documento,
    required String calidad,
    required bool esRepresentanteLegal,
    required bool menorFueOido,
    required String versionDelTexto,
  }) async {
    throw const FalloDelServidor('Este enlace ya no sirve.');
  }
}
