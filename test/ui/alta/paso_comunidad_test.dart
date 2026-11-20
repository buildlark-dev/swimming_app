/// Donde ella pide entrar, mientras crea su cuenta (feature 012, US2).
///
/// Tres cosas, y la segunda es la que más fácil se pierde al implementar:
///
/// 1. La comunidad se ofrece **por su nombre**, que es lo único que ella tiene
///    para reconocer a su entrenador.
/// 2. **Se puede saltar**, y «todavía no» es una opción con nombre en la
///    pantalla, no un botón que se deja sin tocar. Una decisión que no se
///    ofrece es una decisión que ella no sabe que puede tomar.
/// 3. Sin ninguna comunidad que ofrecer, se le dice en palabras y sigue
///    adelante. Una lista en blanco es un callejón sin salida disfrazado de
///    pantalla (FR-006).
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:natacion_app/dominio/comunidad/comunidad.dart';
import 'package:natacion_app/dominio/comunidad/solicitud_de_ingreso.dart';
import 'package:natacion_app/dominio/repositorios/repositorios.dart';
import 'package:natacion_app/ui/alta/estado_alta.dart';
import 'package:natacion_app/ui/alta/paso_comunidad.dart';
import 'package:provider/provider.dart';

void main() {
  late _Comunidades comunidades;
  late _Solicitudes solicitudes;

  setUp(() {
    comunidades = _Comunidades();
    solicitudes = _Solicitudes();
  });

  EstadoAlta estadoCon({bool conServidor = true}) => EstadoAlta(
    operaciones: null,
    correoDeLaCuenta: 'ana@ejemplo.test',
    comunidades: conServidor ? comunidades : null,
    solicitudes: conServidor ? solicitudes : null,
  );

  Future<void> montar(WidgetTester tester, EstadoAlta estado) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChangeNotifierProvider<EstadoAlta>.value(
            value: estado,
            child: const SingleChildScrollView(child: PasoComunidad()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  test('sin servidor el paso ni siquiera aparece en la lista', () {
    // Un paso que no puede terminar lo que empieza es peor que ningún paso.
    expect(
      estadoCon(conServidor: false).pasos,
      isNot(contains(PasoDelAlta.comunidad)),
    );
    expect(estadoCon().pasos, contains(PasoDelAlta.comunidad));
  });

  testWidgets('ofrece las comunidades por su nombre', (tester) async {
    comunidades.hay = [
      Comunidad(id: 'e1', entrenadorId: 'e1', nombre: 'Club Acuático'),
      Comunidad(id: 'e2', entrenadorId: 'e2', nombre: 'Escuela Ribera'),
    ];

    await montar(tester, estadoCon());

    expect(find.text('Club Acuático'), findsOneWidget);
    expect(find.text('Escuela Ribera'), findsOneWidget);
  });

  testWidgets('«todavía no» es una opción con nombre', (tester) async {
    comunidades.hay = [
      Comunidad(id: 'e1', entrenadorId: 'e1', nombre: 'Club Acuático'),
    ];

    await montar(tester, estadoCon());

    expect(find.byKey(const Key('comunidad-ninguna')), findsOneWidget);
    expect(find.text('Todavía no'), findsOneWidget);
  });

  testWidgets('y es lo que está elegido de entrada', (tester) async {
    comunidades.hay = [
      Comunidad(id: 'e1', entrenadorId: 'e1', nombre: 'Club Acuático'),
    ];
    final estado = estadoCon();

    await montar(tester, estado);

    expect(
      estado.comunidadElegida,
      isNull,
      reason: 'elegir por ella a quién pedirle entrar sería elegir por ella',
    );
  });

  testWidgets('elegir una la deja elegida, y el paso se da por bueno', (
    tester,
  ) async {
    comunidades.hay = [
      Comunidad(id: 'e1', entrenadorId: 'e1', nombre: 'Club Acuático'),
    ];
    final estado = estadoCon();
    await montar(tester, estado);

    await tester.tap(find.byKey(const Key('comunidad-e1')));
    await tester.pumpAndSettle();

    expect(estado.comunidadElegida, 'e1');
  });

  test('estando en ese paso, se puede seguir con o sin elegir', () {
    // **Puesta de verdad en ese paso**, no suponiéndolo: `elPasoEstaListo`
    // habla del paso que se está mirando, y un estado recién construido está
    // mirando el primero.
    final estado = estadoCon()
      ..escribirNombre('Ana María Restrepo')
      ..escribirNacimiento(DateTime(2001, 5, 20))
      ..escribirPais('CO')
      ..aceptarTerminos(aceptados: true);

    while (estado.pasoActual != PasoDelAlta.comunidad) {
      estado.avanzar();
    }

    expect(
      estado.elPasoEstaListo,
      isTrue,
      reason: 'sin elegir nada: «todavía no» es una respuesta (FR-005)',
    );

    estado.elegirComunidad('e1');
    expect(estado.elPasoEstaListo, isTrue);
  });

  testWidgets('sin ninguna comunidad, se lo dice y sigue', (tester) async {
    comunidades.hay = const [];

    final estado = estadoCon();
    await montar(tester, estado);

    expect(find.byKey(const Key('sin-comunidades')), findsOneWidget);
  });

  testWidgets('si la lista no se puede leer, tampoco la encierra', (
    tester,
  ) async {
    comunidades.falla = true;

    final estado = estadoCon();
    await montar(tester, estado);

    expect(find.byKey(const Key('sin-comunidades')), findsOneWidget);
  });
}

class _Comunidades implements RepositorioComunidades {
  List<Comunidad> hay = const [];
  bool falla = false;

  @override
  Future<List<Comunidad>> lasQueSePuedenOfrecer() async {
    if (falla) throw const FalloDeDatos('no se pudo leer');
    return hay;
  }

  @override
  Future<Comunidad?> deEntrenador(String entrenadorId) async => null;

  @override
  Future<Comunidad?> obtener(String comunidadId) async => null;

  @override
  Future<void> guardar(Comunidad comunidad) async {}
}

class _Solicitudes implements RepositorioSolicitudes {
  final pedidas = <SolicitudDeIngreso>[];

  @override
  Future<SolicitudDeIngreso?> laMia(String nadadorId) async =>
      pedidas.isEmpty ? null : pedidas.last;

  @override
  Future<List<SolicitudDeIngreso>> lasQueEsperanEn(String comunidadId) async =>
      pedidas;

  @override
  Future<void> pedir(SolicitudDeIngreso solicitud) async =>
      pedidas.add(solicitud);

  @override
  Future<void> retirar(String nadadorId, String comunidadId) async =>
      pedidas.removeWhere(
        (s) => s.nadadorId == nadadorId && s.comunidadId == comunidadId,
      );
}
