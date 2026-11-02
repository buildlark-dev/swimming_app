/// Garantías P19, P26 a P32 — la cola del entrenador.
///
/// El borrador **no existe hasta que él abre la petición**: se genera en su
/// dispositivo, en ese momento. Eso es lo que convierte «el nadador no ve el
/// borrador antes de la firma» en un hecho y no en una promesa de la
/// interfaz.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:natacion_app/datos/memoria/repositorios_memoria.dart';
import 'package:natacion_app/dominio/entidades/nadador.dart';
import 'package:natacion_app/dominio/peticiones/molestias_enlazadas.dart';
import 'package:natacion_app/dominio/metodologia/categorias.dart';
import 'package:natacion_app/dominio/metodologia/estilos.dart';
import 'package:natacion_app/dominio/peticiones/peticion.dart';
import 'package:natacion_app/dominio/repositorios/repositorios.dart';
import 'package:natacion_app/ui/hub/cola_del_entrenador.dart';

import 'ayuda_hub.dart';

void main() {
  final hoy = DateTime(2026, 11, 2);

  PeticionDePlan peticionDe(
    String nadadorId, {
    EstadoDePeticion estado = EstadoDePeticion.esperando,
    int? competenciaEnDias = 24,
    String? motivo,
    String? planId,
    DateTime? respondidaEn,
  }) => PeticionDePlan(
    nadadorId: nadadorId,
    enviadaEn: hoy,
    estado: estado,
    motivoDelRechazo: motivo,
    planId: planId,
    respondidaEn: respondidaEn,
    respuestas: RespuestasDePeticion(
      estiloObjetivo: Estilo.libre,
      pruebaObjetivo: '200 Libre',
      fechaDeCompetencia: competenciaEnDias == null
          ? null
          : hoy.add(Duration(days: competenciaEnDias)),
      diasDisponibles: [
        for (var i = 1; i <= 3; i++) hoy.add(Duration(days: i * 2)),
      ],
      duracionSesionMinutos: 90,
      longitudPiscina: 25,
    ),
  );

  Future<_Cola> montarCola(
    WidgetTester tester, {
    List<PeticionDePlan> peticiones = const [],
    List<MolestiaEnlazada> molestias = const [],
    bool sinConexion = false,
  }) async {
    tester.view.physicalSize = const Size(900, 2800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final nadadores = RepositorioNadadoresMemoria();
    await nadadores.guardar(
      const Nadador(
        id: 'n-ana',
        nombre: 'Ana María Restrepo',
        categoria: Categoria.precompetitivo,
        estiloObjetivo: Estilo.libre,
        pruebaObjetivo: '200 Libre',
      ),
    );

    final repo = _ColaSembrada(peticiones, falla: sinConexion);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ColaDelEntrenador(
            peticiones: repo,
            nadadores: nadadores,
            molestias: _MolestiasSembradas(molestias),
            biblioteca: bibliotecaDePrueba(),
            versionMetodologia: '3.6.0',
            hoyParaPruebas: hoy,
            alCerrar: repo.cerrar,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    return _Cola(repo);
  }

  group('P27 — lo que el entrenador ve de cada petición', () {
    testWidgets('quién la pidió, cuándo y qué respondió', (tester) async {
      await montarCola(tester, peticiones: [peticionDe('n-ana')]);

      expect(find.text('Ana María Restrepo'), findsWidgets);
      expect(find.textContaining('200 Libre'), findsWidgets);
    });

    testWidgets('sin ninguna, lo dice en lugar de quedarse en blanco', (
      tester,
    ) async {
      await montarCola(tester);

      expect(find.byKey(const Key('cola-vacia')), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('FR-024 — separa lo que espera de lo ya respondido', (
      tester,
    ) async {
      await montarCola(
        tester,
        peticiones: [
          peticionDe('n-ana'),
          peticionDe(
            'n-juan',
            estado: EstadoDePeticion.rechazada,
            motivo: 'Ya te entregué uno esta semana.',
            respondidaEn: hoy,
          ),
        ],
      );

      expect(find.byKey(const Key('cola-esperando')), findsOneWidget);
      expect(find.byKey(const Key('cola-respondidas')), findsOneWidget);
    });
  });

  group('P32 — sin conexión se dice, no se enseña una cola vacía', () {
    testWidgets('una cola que no se pudo leer no parece una cola sin nada', (
      tester,
    ) async {
      // Es el defecto que este proyecto ya cometió dos veces: un fallo de
      // lectura que se lee como «no hay nada».
      await montarCola(tester, sinConexion: true);

      expect(find.byKey(const Key('cola-no-se-pudo-leer')), findsOneWidget);
      expect(find.byKey(const Key('cola-vacia')), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });
  });

  group('P15 y P26 — el borrador aparece al abrirla, con su fase', () {
    testWidgets('antes de abrirla no hay borrador en pantalla', (tester) async {
      await montarCola(tester, peticiones: [peticionDe('n-ana')]);

      expect(find.byKey(const Key('borrador-de-la-peticion')), findsNothing);
    });

    testWidgets('al abrirla, se genera y se ve la fase con su razón', (
      tester,
    ) async {
      final cola = await montarCola(tester, peticiones: [peticionDe('n-ana')]);

      await tester.tap(find.byKey(const Key('abrir-peticion-n-ana')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('borrador-de-la-peticion')), findsOneWidget);
      expect(find.byKey(const Key('fase-derivada')), findsOneWidget);
      expect(find.textContaining('24'), findsWidgets);
      expect(
        cola.repo.abiertas,
        contains('n-ana'),
        reason: 'Abrirla la pasa a «en revisión», y lo mueve él',
      );
    });

    testWidgets('P24 — sin fecha no hay borrador, y se pide la fase', (
      tester,
    ) async {
      await montarCola(
        tester,
        peticiones: [peticionDe('n-ana', competenciaEnDias: null)],
      );

      await tester.tap(find.byKey(const Key('abrir-peticion-n-ana')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('falta-la-fase')), findsOneWidget);
      expect(find.byKey(const Key('borrador-de-la-peticion')), findsNothing);
    });

    testWidgets('y poniendo él la fase, el borrador aparece', (tester) async {
      await montarCola(
        tester,
        peticiones: [peticionDe('n-ana', competenciaEnDias: null)],
      );

      await tester.tap(find.byKey(const Key('abrir-peticion-n-ana')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('fase-acumulacion')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('borrador-de-la-peticion')), findsOneWidget);
    });
  });

  group('P29 y P30 — un rechazo sin motivo es imposible', () {
    testWidgets('el botón de rechazar no manda nada con el motivo vacío', (
      tester,
    ) async {
      final cola = await montarCola(tester, peticiones: [peticionDe('n-ana')]);

      await tester.tap(find.byKey(const Key('abrir-peticion-n-ana')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('rechazar-peticion')));
      await tester.pumpAndSettle();

      expect(cola.repo.cerradas, isEmpty);
      expect(find.byKey(const Key('falta-el-motivo')), findsOneWidget);
    });

    testWidgets('con motivo, se cierra y el motivo viaja tal cual', (
      tester,
    ) async {
      final cola = await montarCola(tester, peticiones: [peticionDe('n-ana')]);

      await tester.tap(find.byKey(const Key('abrir-peticion-n-ana')));
      await tester.pumpAndSettle();

      const loQueEscribio =
          'Pediste tres días y está bien, pero el 200 lo dejamos para marzo.';
      await tester.enterText(
        find.byKey(const Key('motivo-del-rechazo')),
        loQueEscribio,
      );
      await tester.tap(find.byKey(const Key('rechazar-peticion')));
      await tester.pumpAndSettle();

      expect(cola.repo.cerradas.single.motivo, loQueEscribio);
      expect(cola.repo.cerradas.single.decision, 'rechazada');
    });
  });

  group('P19 — la misma auditoría que sus propios planes', () {
    testWidgets('el borrador muestra qué criterios cumple y cuáles no', (
      tester,
    ) async {
      await montarCola(tester, peticiones: [peticionDe('n-ana')]);

      await tester.tap(find.byKey(const Key('abrir-peticion-n-ana')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('auditoria-del-borrador')), findsOneWidget);
    });
  });

  group('P33 y P34 — las molestias se enseñan, con su fecha', () {
    testWidgets('las recientes aparecen, y se ve de cuándo son', (
      tester,
    ) async {
      await montarCola(
        tester,
        peticiones: [peticionDe('n-ana')],
        molestias: [
          MolestiaEnlazada(
            fecha: hoy.subtract(const Duration(days: 3)),
            zonaDelCuerpo: 'Hombro derecho',
            descripcion: 'Me molesta al sacar el brazo',
          ),
        ],
      );

      await tester.tap(find.byKey(const Key('abrir-peticion-n-ana')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('molestias-enlazadas')), findsOneWidget);
      expect(find.textContaining('Hombro derecho'), findsWidgets);
    });

    testWidgets('**sin ninguna reciente, lo dice**', (tester) async {
      // Un hueco en blanco se lee como «no le duele nada», y eso es una
      // afirmación que esta app no puede hacer.
      await montarCola(tester, peticiones: [peticionDe('n-ana')]);

      await tester.tap(find.byKey(const Key('abrir-peticion-n-ana')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('sin-molestias-recientes')), findsOneWidget);
    });

    testWidgets('una molestia vieja no cuenta como reciente', (tester) async {
      await montarCola(
        tester,
        peticiones: [peticionDe('n-ana')],
        molestias: [
          MolestiaEnlazada(
            fecha: hoy.subtract(const Duration(days: 60)),
            zonaDelCuerpo: 'Rodilla',
            descripcion: 'Me crujía',
          ),
        ],
      );

      await tester.tap(find.byKey(const Key('abrir-peticion-n-ana')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('sin-molestias-recientes')), findsOneWidget);
      expect(find.textContaining('Rodilla'), findsNothing);
    });
  });
}

class _Cola {
  const _Cola(this.repo);
  final _ColaSembrada repo;
}

class _CierreRegistrado {
  const _CierreRegistrado(this.nadadorId, this.decision, this.motivo);
  final String nadadorId;
  final String decision;
  final String? motivo;
}

class _ColaSembrada implements RepositorioPeticiones {
  _ColaSembrada(this._peticiones, {this.falla = false});

  final List<PeticionDePlan> _peticiones;
  final bool falla;

  final List<String> abiertas = [];
  final List<_CierreRegistrado> cerradas = [];

  @override
  Future<List<PeticionDePlan>> cola() async {
    if (falla) throw StateError('sin conexión');
    return _peticiones;
  }

  @override
  Future<PeticionDePlan?> miPeticion(String nadadorId) async => null;

  @override
  Future<void> enviar({
    required String nadadorId,
    required RespuestasDePeticion respuestas,
  }) async {}

  @override
  Future<void> marcarEnRevision(String nadadorId) async {
    abiertas.add(nadadorId);
  }

  Future<void> cerrar({
    required String nadadorId,
    required String decision,
    String? planId,
    String? motivo,
  }) async {
    cerradas.add(_CierreRegistrado(nadadorId, decision, motivo));
  }
}

class _MolestiasSembradas implements LectorDeMolestias {
  const _MolestiasSembradas(this._molestias);

  final List<MolestiaEnlazada> _molestias;

  @override
  Future<List<MolestiaEnlazada>> recientesDe(
    String nadadorId, {
    required DateTime desde,
  }) async =>
      // El filtro por fecha lo hace quien lee de verdad; aquí se respeta para
      // que la prueba de «una molestia vieja no cuenta» mida algo.
      _molestias.where((m) => m.fecha.isAfter(desde)).toList();
}
