/// FR-009 — la solicitud espera donde él ya mira.
///
/// **No es un sexto destino.** La feature 008 ya decidió que lo que los
/// nadadores piden llega a la cola del entrenador, dentro de `Generar`, y
/// montó la forma entera: él abre, decide, y nada sale sin su firma. Pedir
/// entrar es otra cosa que alguien le pide, así que va al mismo sitio en lugar
/// de inventar otro — que es lo que la spec de esta feature dijo que convenía
/// hacer, y lo que los cinco destinos del HUB (y el cerrojo de la 007 que mide
/// si sus cinco etiquetas caben a 320 px) agradecen.
///
/// Lo que estas pruebas fijan:
///
/// - **Quién pidió y cuándo**, no un identificador. Una lista de `n-ana|e-uno`
///   no es una cola: es un volcado.
/// - **Las dos respuestas, y ninguna automática** (principio IV, FR-011).
/// - **Que decir que no no la borra de la vista en silencio**: él tiene que
///   ver que pasó algo.
/// - Y el control negativo de todo esto: sin solicitudes, la sección **no
///   está**. Una pantalla que enseña un encabezado vacío no se distingue de
///   una que no leyó nada.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:natacion_app/dominio/comunidad/solicitud_de_ingreso.dart';
import 'package:natacion_app/dominio/entidades/nadador.dart';
import 'package:natacion_app/dominio/metodologia/categorias.dart';
import 'package:natacion_app/dominio/metodologia/estilos.dart';
import 'package:natacion_app/dominio/peticiones/molestias_enlazadas.dart';
import 'package:natacion_app/dominio/peticiones/peticion.dart';
import 'package:natacion_app/dominio/repositorios/repositorios.dart';
import 'package:natacion_app/datos/memoria/repositorios_memoria.dart';
import 'package:natacion_app/ui/hub/cola_del_entrenador.dart';

import 'ayuda_hub.dart';

void main() {
  final hoy = DateTime(2026, 11, 19, 10);

  Future<_Solicitudes> montar(
    WidgetTester tester, {
    required List<SolicitudDeIngreso> solicitudes,
    bool falla = false,
    bool alResolverFalla = false,
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

    final repo = _Solicitudes(solicitudes, falla: falla);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ColaDelEntrenador(
            peticiones: _SinPeticiones(),
            nadadores: nadadores,
            molestias: _SinMolestias(),
            planes: null,
            biblioteca: bibliotecaDePrueba(),
            versionMetodologia: '3.6.0',
            hoyParaPruebas: hoy,
            solicitudes: repo,
            miComunidad: 'e-uno',
            alResolverIngreso: alResolverFalla
                ? (({required String nadadorId, required bool acepto}) async {
                    throw const FalloDeDatos('el servidor no contestó');
                  })
                : repo.resolver,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    return repo;
  }

  SolicitudDeIngreso pedida(
    String nadadorId, {
    DateTime? cuando,
    String nombre = 'Ana María Restrepo',
  }) => SolicitudDeIngreso(
    nadadorId: nadadorId,
    comunidadId: 'e-uno',
    pedidaEn: cuando ?? DateTime(2026, 11, 17, 9),
    nombre: nombre,
  );

  group('FR-009 — lo que ve de quien quiere entrar', () {
    testWidgets('su nombre, no su identificador', (tester) async {
      await montar(tester, solicitudes: [pedida('n-ana')]);

      expect(find.text('Quieren entrar en tu comunidad'), findsOneWidget);
      expect(find.text('Ana María Restrepo'), findsOneWidget);
      expect(find.textContaining('n-ana|e-uno'), findsNothing);
    });

    testWidgets('y desde cuándo espera', (tester) async {
      // Una solicitud de hace dos días y una de hace diez minutos se atienden
      // distinto. Es la misma razón por la que FR-019 puso la fecha en las
      // peticiones de plan.
      await montar(tester, solicitudes: [pedida('n-ana')]);

      expect(find.textContaining('17/11/2026'), findsOneWidget);
    });

    testWidgets('sin solicitudes, la sección NO está', (tester) async {
      // **El control negativo.** Una pantalla que siempre pinta el encabezado
      // da verde aunque no lea nada.
      await montar(tester, solicitudes: const []);

      expect(find.text('Quieren entrar en tu comunidad'), findsNothing);
    });

    testWidgets('el nombre sale de la solicitud, NO de su ficha', (
      tester,
    ) async {
      // **Y tiene que salir de ahí.** Su ficha él no la puede leer hasta
      // aceptarla —garantía F3—, así que la solicitud lo lleva dentro. Esto
      // leía la ficha, y el recorrido del quickstart lo vio decir «Alguien que
      // todavía no tiene perfil» y pedirle que decidiera sobre una
      // desconocida.
      //
      // `n-desconocida` no tiene ficha en esta prueba, que es exactamente el
      // caso de verdad.
      await montar(
        tester,
        solicitudes: [pedida('n-desconocida', nombre: 'Valentina Ocampo')],
      );

      expect(find.text('Quieren entrar en tu comunidad'), findsOneWidget);
      expect(find.byKey(const Key('ingreso-n-desconocida')), findsOneWidget);
      expect(find.text('Valentina Ocampo'), findsOneWidget);
    });

    testWidgets('y sin nombre tampoco la esconde', (tester) async {
      // Una solicitud sin nombre legible sigue siendo una decisión que él
      // tiene que poder tomar. Esconderla la dejaría esperando para siempre.
      await montar(
        tester,
        solicitudes: [pedida('n-desconocida', nombre: '')],
      );

      expect(find.byKey(const Key('ingreso-n-desconocida')), findsOneWidget);
      expect(find.text('Alguien sin nombre'), findsOneWidget);
    });
  });

  group('FR-011 — decide él, y las dos respuestas están', () {
    testWidgets('aceptar llama al servidor con quién', (tester) async {
      final repo = await montar(tester, solicitudes: [pedida('n-ana')]);

      await tester.tap(find.byKey(const Key('aceptar-n-ana')));
      await tester.pumpAndSettle();

      expect(repo.resueltas, [('n-ana', true)]);
    });

    testWidgets('y decir que no también', (tester) async {
      final repo = await montar(tester, solicitudes: [pedida('n-ana')]);

      await tester.tap(find.byKey(const Key('rechazar-n-ana')));
      await tester.pumpAndSettle();

      expect(repo.resueltas, [('n-ana', false)]);
    });

    testWidgets('nada se acepta solo al abrir la pantalla', (tester) async {
      // Principio IV. Lo dice FR-011 y lo repite esto, porque «aceptar al
      // abrir» es exactamente el atajo que un día parece cómodo.
      final repo = await montar(tester, solicitudes: [pedida('n-ana')]);

      expect(repo.resueltas, isEmpty);
    });

    testWidgets('resuelta, desaparece de la lista', (tester) async {
      final repo = await montar(tester, solicitudes: [pedida('n-ana')]);

      await tester.tap(find.byKey(const Key('aceptar-n-ana')));
      await tester.pumpAndSettle();

      expect(repo.resueltas.length, 1);
      expect(find.text('Quieren entrar en tu comunidad'), findsNothing);
    });

    testWidgets('si el servidor no contesta, se dice y NO desaparece', (
      tester,
    ) async {
      // **Una decisión que no llegó no puede parecer tomada.** Quitarla de la
      // lista y callarse dejaría a la nadadora esperando para siempre y a él
      // convencido de que ya la metió.
      await montar(
        tester,
        solicitudes: [pedida('n-ana')],
        alResolverFalla: true,
      );

      await tester.tap(find.byKey(const Key('aceptar-n-ana')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('ingreso-no-se-pudo')), findsOneWidget);
      expect(find.byKey(const Key('ingreso-n-ana')), findsOneWidget);
    });
  });

  group('lo que no se pudo leer', () {
    testWidgets('no se enseña como «nadie quiere entrar»', (tester) async {
      // El mismo defecto que la cola de peticiones ya tuvo dos veces: una
      // lista que no se pudo leer no es una lista vacía.
      await montar(tester, solicitudes: const [], falla: true);

      expect(find.byKey(const Key('ingresos-no-se-pudieron-leer')), findsOneWidget);
    });
  });
}

class _Solicitudes implements RepositorioSolicitudes {
  _Solicitudes(this._esperando, {this.falla = false});

  List<SolicitudDeIngreso> _esperando;
  final bool falla;

  final resueltas = <(String, bool)>[];

  Future<void> resolver({
    required String nadadorId,
    required bool acepto,
  }) async {
    resueltas.add((nadadorId, acepto));
    _esperando = _esperando.where((s) => s.nadadorId != nadadorId).toList();
  }

  @override
  Future<List<SolicitudDeIngreso>> lasQueEsperanEn(String comunidadId) async {
    if (falla) throw const FalloDeDatos('no se pudo leer');
    return _esperando.where((s) => s.comunidadId == comunidadId).toList();
  }

  @override
  Future<SolicitudDeIngreso?> laMia(String nadadorId) async => null;

  @override
  Future<void> pedir(SolicitudDeIngreso solicitud) async {}

  @override
  Future<void> retirar(String nadadorId, String comunidadId) async {}
}

class _SinPeticiones implements RepositorioPeticiones {
  @override
  Future<List<PeticionDePlan>> cola() async => const [];

  @override
  Future<PeticionDePlan?> miPeticion(String nadadorId) async => null;

  @override
  Future<void> enviar({
    required String nadadorId,
    required RespuestasDePeticion respuestas,
  }) async {}

  @override
  Future<void> marcarEnRevision(String nadadorId) async {}

}

class _SinMolestias implements LectorDeMolestias {
  @override
  Future<List<MolestiaEnlazada>> recientesDe(
    String nadadorId, {
    required DateTime desde,
  }) async => const [];

  @override
  Future<Set<String>> quienesReportaron({required DateTime desde}) async =>
      const <String>{};
}
