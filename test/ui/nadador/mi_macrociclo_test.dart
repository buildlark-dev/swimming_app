/// M18 a M23 y C9 — lo que el nadador ve al abrir `Ver Plan`.
///
/// Las cuatro cosas que esta pantalla promete y que se pueden perder sin que
/// nada falle:
///
/// - **se abre en hoy** y no en la semana uno (M19), porque una lista plegada
///   de cuarenta sesiones sigue siendo larga;
/// - **cualquier** sesión se abre, incluso una de dentro de seis semanas
///   (M18): nada escondido;
/// - se le dice que el plan puede cambiar (M21), en español y sin jerga;
/// - **sin macrociclo ve lo que la feature 003 le dio** (M23), no una
///   jerarquía vacía.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:natacion_app/dominio/entidades/plan.dart';
import 'package:natacion_app/dominio/entidades/registro_sesion.dart';
import 'package:natacion_app/dominio/macrociclo/guardar_macrociclo.dart';
import 'package:natacion_app/dominio/repositorios/repositorios.dart';
import 'package:natacion_app/dominio/entidades/envio_pendiente.dart';
import 'package:natacion_app/dominio/entidades/nadador.dart';
import 'package:natacion_app/dominio/sincronizacion/bandeja_salida.dart';
import 'package:natacion_app/ui/nadador/estado_nadador.dart';
import 'package:natacion_app/dominio/macrociclo/reajuste.dart';
import 'package:natacion_app/ui/nadador/mi_macrociclo.dart';
import 'package:natacion_app/ui/tema/tema.dart';

import '../macrociclo/ayuda_macrociclo.dart';

void main() {
  late RepositoriosDelMacrociclo repos;
  late RepositorioRegistros registros;

  setUp(() {
    repos = RepositoriosDelMacrociclo();
    registros = _RegistrosSembrados();
  });

  /// Entrega el macrociclo, que es lo único que el nadador puede ver.
  Future<MacrocicloGuardado> entregado() async {
    final guardado = await macrocicloGuardado(repos);

    final firmado = await firmarElMacrociclo(
      macrociclo: guardado.macrociclo,
      mesociclos: guardado.mesociclos,
      planes: repos.planes,
      macrociclos: repos.macrociclos,
      hoy: hoyDePrueba,
    );

    return entregarElMacrociclo(
      macrociclo: firmado,
      mesociclos: [
        for (final m in guardado.mesociclos)
          m.copiarCon(estado: EstadoPlan.aprobado),
      ],
      planes: repos.planes,
      asignaciones: repos.asignaciones,
      macrociclos: repos.macrociclos,
      hoy: hoyDePrueba,
    ).then((entregado) async {
      // Lo que quedó guardado, que es lo que la pantalla va a leer.
      final mesociclos = <Plan>[];
      for (final id in entregado.mesociclos) {
        final plan = await repos.planes.obtener(id);
        if (plan != null) mesociclos.add(plan);
      }
      return MacrocicloGuardado(
        macrociclo: entregado,
        mesociclos: mesociclos,
      );
    });
  }

  Future<void> abrir(
    WidgetTester tester, {
    DateTime? cuando,
    bool conMacrociclo = true,
  }) async {
    if (conMacrociclo) await entregado();

    // Un teléfono de verdad: es donde «se abre en hoy» significa algo. En una
    // ventana alta cabría el macrociclo entero y la prueba pasaría sola.
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: Tema.claro(),
        home: Scaffold(
          body: PantallaMiMacrociclo(
            nadadorId: 'n-ana',
            macrociclos: repos.macrociclos,
            planes: repos.planes,
            registros: registros,
            hoy: cuando ?? hoyDePrueba,
            sinMacrociclo: const Text('Tu sesión de hoy (feature 003)'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('C9 — el camino completo, desde el primer día', () {
    testWidgets('se ve el macrociclo y dónde va', (tester) async {
      await abrir(tester);

      expect(find.byKey(const Key('mi-macrociclo')), findsOneWidget);
      expect(
        tester.widget<Text>(find.byKey(const Key('donde-voy'))).data!,
        contains('bloque 1 de 3'),
      );
    });

    testWidgets('el bloque en curso se señala', (tester) async {
      await abrir(tester);
      expect(find.byKey(const Key('aqui-vas')), findsOneWidget);
    });

    testWidgets('los tres mesociclos son alcanzables, no solo el de ahora', (
      tester,
    ) async {
      // M18: nada escondido. **Se comprueba alcanzándolos**, no mirando si
      // están en el árbol: un `ListView` solo construye lo que se ve, así que
      // `findsOneWidget` sobre el tercero fallaría aunque la lista esté
      // completa, y `findsNothing` pasaría aunque faltara de verdad.
      await abrir(tester);

      for (var i = 0; i < 3; i++) {
        await tester.scrollUntilVisible(
          find.byKey(Key('mi-mesociclo-$i')),
          300,
          scrollable: find.byType(Scrollable).first,
        );
        expect(
          find.byKey(Key('mi-mesociclo-$i')),
          findsOneWidget,
          reason: 'no se pudo llegar al mesociclo $i',
        );
      }
    });

    testWidgets('se le dice que el plan puede cambiar (M21)', (tester) async {
      await abrir(tester);

      final aviso = tester
          .widget<Text>(find.byKey(const Key('puede-cambiar')))
          .data!;

      expect(aviso, contains('cambiar'));
      expect(aviso, contains('respondiendo'));
      // En español y sin jerga: ni «macrociclo», ni «mesociclo», ni «ATR».
      expect(aviso, isNot(contains('ATR')));
      expect(aviso.toLowerCase(), isNot(contains('mesociclo')));
      expect(aviso.toLowerCase(), isNot(contains('adherencia')));
    });

    testWidgets('y cuántas lleva cumplidas', (tester) async {
      await abrir(tester);

      expect(
        tester
            .widget<Text>(find.byKey(const Key('cuantas-cumplidas')))
            .data!,
        contains('0 de'),
      );
    });
  });

  group('M19 — la vista se abre en hoy, no en la semana uno', () {
    testWidgets('dentro del tercer mesociclo, hoy está a la vista', (
      tester,
    ) async {
      // Hoy a 91 días: dentro del último bloque, y **un día de entrenamiento**
      // —91 días desde un miércoles son trece semanas justas—. Sin desplazar,
      // lo que se vería es la primera semana de Acumulación, a treinta y seis
      // sesiones de distancia.
      //
      // La primera versión usaba 90 días, que cae en martes: no hay sesión ese
      // día y la prueba fallaba por su propia premisa, no por la pantalla.
      final hoy = hoyDePrueba.add(const Duration(days: 91));
      await abrir(tester, cuando: hoy);

      // La sesión de hoy existe y está dentro de la ventana visible.
      final deHoy = find.textContaining('· hoy');
      expect(deHoy, findsOneWidget, reason: 'no se encontró la sesión de hoy');

      final donde = tester.getRect(deHoy);
      final pantalla = tester.view.physicalSize.height;

      expect(
        donde.top >= 0 && donde.bottom <= pantalla,
        isTrue,
        reason:
            'la sesión de hoy quedó fuera de la pantalla: la vista se abrió '
            'en la semana uno en lugar de en hoy (está en ${donde.top})',
      );
    });

    testWidgets('la portada no está dentro de lo que se desplaza', (
      tester,
    ) async {
      // **Este es el cerrojo de verdad**, y costó encontrarlo.
      //
      // Con la portada dentro de la lista, desplazarse a hoy se la llevaba por
      // delante y con ella «vas por el bloque 1 de 3» y el aviso de que el
      // plan puede cambiar —lo que M20 y M21 prometen—. El control negativo de
      // T045 lo destapó: con la portada fuera, hacer que la pantalla se
      // desplace siempre ya no rompe nada, porque la estructura lo impide.
      //
      // Así que lo que hay que vigilar no es el desplazamiento: es que la
      // portada siga fuera.
      await abrir(tester);

      expect(
        find.descendant(
          of: find.byKey(const Key('el-camino')),
          matching: find.byKey(const Key('donde-voy')),
        ),
        findsNothing,
        reason:
            'la portada volvió dentro del scroll: al abrirse en hoy se la va '
            'a llevar por delante',
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('el-camino')),
          matching: find.byKey(const Key('puede-cambiar')),
        ),
        findsNothing,
      );
      // Y siguen estando, fuera.
      expect(find.byKey(const Key('donde-voy')), findsOneWidget);
      expect(find.byKey(const Key('puede-cambiar')), findsOneWidget);
    });

    testWidgets('el primer día del macrociclo no hace falta desplazar', (
      tester,
    ) async {
      // El control de la prueba de arriba: cuando hoy **es** el principio, la
      // vista se queda arriba y no se va a ninguna parte.
      await abrir(tester);

      expect(find.textContaining('· hoy'), findsOneWidget);
    });
  });

  group('M18 — cualquier sesión se abre, incluso una lejana', () {
    testWidgets('una sesión del último bloque se despliega', (tester) async {
      await abrir(tester);

      final ultimo = await repos.planes.obtener('plan-3');
      final sesion = (ultimo ?? (await repos.planes.listar()).last)
          .sesiones
          .last;

      final tile = find.byKey(Key('sesion-${sesion.id}'));
      await tester.ensureVisible(tile);
      await tester.pumpAndSettle();
      await tester.tap(tile);
      await tester.pumpAndSettle();

      // Al abrirse enseña sus metros: la sesión está ahí entera, no es una
      // etiqueta.
      expect(find.textContaining('metros'), findsWidgets);
    });
  });

  group('M23 — sin macrociclo, lo que la 003 le dio', () {
    testWidgets('se enseña su sesión de hoy', (tester) async {
      await abrir(tester, conMacrociclo: false);

      expect(
        find.byKey(const Key('sin-macrociclo-la-sesion-de-hoy')),
        findsOneWidget,
      );
      expect(find.text('Tu sesión de hoy (feature 003)'), findsOneWidget);
    });

    testWidgets('y no una jerarquía vacía', (tester) async {
      await abrir(tester, conMacrociclo: false);

      expect(find.byKey(const Key('mi-macrociclo')), findsNothing);
      expect(find.byKey(const Key('mi-mesociclo-0')), findsNothing);
      expect(find.textContaining('Tu camino'), findsNothing);
    });

    testWidgets('un macrociclo firmado y sin entregar no cuenta', (
      tester,
    ) async {
      // **Firmar no es entregar** (M17), y aquí es donde se nota: un
      // macrociclo aprobado no es suyo todavía.
      final guardado = await macrocicloGuardado(repos);
      await firmarElMacrociclo(
        macrociclo: guardado.macrociclo,
        mesociclos: guardado.mesociclos,
        planes: repos.planes,
        macrociclos: repos.macrociclos,
        hoy: hoyDePrueba,
      );

      await abrir(tester, conMacrociclo: false);

      expect(
        find.byKey(const Key('sin-macrociclo-la-sesion-de-hoy')),
        findsOneWidget,
      );
    });
  });

  group('M24 a M28 — marcar desde el macrociclo', () {
    /// Monta con un `EstadoNadador` de verdad, para que marcar guarde.
    Future<void> abrirParaMarcar(
      WidgetTester tester, {
      DateTime? cuando,
    }) async {
      await entregado();
      final estado = EstadoNadador(
        sincronizador: Sincronizador(
          registros: registros,
          bandeja: _BandejaQuieta(),
          red: _SinRed(),
          transporte: _TransporteQuieto(),
          reloj: () => cuando ?? hoyDePrueba,
        ),
        reloj: () => cuando ?? hoyDePrueba,
      );
      estado.abrirComo(
        const Nadador(id: 'n-ana', nombre: 'Ana María Restrepo'),
      );

      conPantallaAlta(tester);
      await tester.pumpWidget(
        MaterialApp(
          theme: Tema.claro(),
          home: Scaffold(
            body: PantallaMiMacrociclo(
              nadadorId: 'n-ana',
              macrociclos: repos.macrociclos,
              planes: repos.planes,
              registros: registros,
              hoy: cuando ?? hoyDePrueba,
              estado: estado,
              sinMacrociclo: const Text('Tu sesión de hoy'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('la sesión de hoy ofrece el formulario de la 003', (
      tester,
    ) async {
      // El mismo formulario, no uno más pobre: el nadador da la misma
      // respuesta llegue por donde llegue.
      await abrirParaMarcar(tester);

      final deHoy = (await repos.planes.obtener('plan-1'))!.sesiones.first;
      await tester.ensureVisible(find.byKey(Key('sesion-${deHoy.id}')));
      await tester.tap(find.byKey(Key('sesion-${deHoy.id}')));
      await tester.pumpAndSettle();

      expect(find.byKey(Key('marcar-${deHoy.id}')), findsOneWidget);
      expect(find.text('¿Cómo te fue?'), findsOneWidget);
    });

    testWidgets('una sesión futura no ofrece control, y dice por qué', (
      tester,
    ) async {
      // M24: no es que el botón no haga nada — es que no hay botón, y hay una
      // frase. Un control que no guarda está prohibido desde la 007 (H12).
      await abrirParaMarcar(tester);

      final futura = (await repos.planes.obtener('plan-3'))!.sesiones.last;
      await tester.ensureVisible(find.byKey(Key('sesion-${futura.id}')));
      await tester.tap(find.byKey(Key('sesion-${futura.id}')));
      await tester.pumpAndSettle();

      expect(find.byKey(Key('marcar-${futura.id}')), findsNothing);
      expect(
        tester
            .widget<Text>(find.byKey(Key('todavia-no-${futura.id}')))
            .data!,
        'Todavía no llega ese día',
      );
    });

    testWidgets('marcar la de hoy la deja hecha y suma a lo cumplido', (
      tester,
    ) async {
      await abrirParaMarcar(tester);

      final deHoy = (await repos.planes.obtener('plan-1'))!.sesiones.first;
      await tester.ensureVisible(find.byKey(Key('sesion-${deHoy.id}')));
      await tester.tap(find.byKey(Key('sesion-${deHoy.id}')));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Marcar como realizada'));
      await tester.tap(find.text('Marcar como realizada'));
      await tester.pumpAndSettle();

      // Y el registro apunta **a su mesociclo**, no a otro: con el `planId`
      // equivocado el registro existe y la adherencia de dos mesociclos sale
      // mal, sin que nada falle.
      final guardados = await registros.obtenerDePlan('n-ana', 'plan-1');
      expect(guardados, hasLength(1));
      expect(guardados.single.sesionId, deHoy.id);
      expect(guardados.single.realizada, isTrue);
    });
  });

  group('M26 — lo que quedó pendiente se dice, no se bloquea', () {
    testWidgets('con sesiones atrás sin marcar, se listan', (tester) async {
      // A 20 días hay sesiones pasadas sin marcar: el aviso las nombra.
      await abrir(tester, cuando: hoyDePrueba.add(const Duration(days: 20)));

      expect(
        find.byKey(const Key('lo-que-quedo-pendiente')),
        findsOneWidget,
      );
      expect(find.textContaining('por marcar'), findsWidgets);
    });

    testWidgets('y el aviso no suena a regaño', (tester) async {
      // Decisión D6: se enseña el hueco, no se niega el hecho. Un niño de
      // nueve años lee esto.
      await abrir(tester, cuando: hoyDePrueba.add(const Duration(days: 20)));

      final mensaje = tester
          .widget<Text>(find.byKey(const Key('lo-que-quedo-pendiente')))
          .data!;

      expect(mensaje, contains('No pasa nada'));
      expect(mensaje, contains('cuando quieras'));
    });

    testWidgets('el primer día no hay nada pendiente que decir', (
      tester,
    ) async {
      // El control de las dos de arriba: que no aparezca siempre.
      await abrir(tester);

      expect(find.byKey(const Key('lo-que-quedo-pendiente')), findsNothing);
    });
  });

  group('FR-034 — el nadador ve que su entrenador ajustó esa parte', () {
    testWidgets('sin reajuste no se le dice nada', (tester) async {
      await abrir(tester);
      expect(find.byKey(const Key('tu-entrenador-ajusto')), findsNothing);
    });

    testWidgets('con un reajuste, lo lee en una frase', (tester) async {
      // Sin comparar versiones: lo que lee es qué bloque cambió.
      final macro = await entregado();
      await reajustarElMacrociclo(
        macrociclo: macro.macrociclo,
        mesociclos: macro.mesociclos,
        cualesSeReajustan: {macro.mesociclos[1].id!},
        planes: repos.planes,
        macrociclos_: repos.macrociclos,
        hoy: hoyDePrueba,
      );

      conPantallaAlta(tester);
      await tester.pumpWidget(
        MaterialApp(
          theme: Tema.claro(),
          home: Scaffold(
            body: PantallaMiMacrociclo(
              nadadorId: 'n-ana',
              macrociclos: repos.macrociclos,
              planes: repos.planes,
              registros: registros,
              hoy: hoyDePrueba,
              sinMacrociclo: const Text('Tu sesión de hoy'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<Text>(find.byKey(const Key('tu-entrenador-ajusto')))
            .data!,
        'Tu entrenador ajustó el bloque 2 de tu plan.',
      );
      expect(find.textContaining('sigue ahí'), findsOneWidget);
    });
  });

  group('el final del ciclo', () {
    testWidgets('se le dice que terminó y quién prepara el siguiente', (
      tester,
    ) async {
      // El caso límite de la spec: llega a la última sesión y no se queda en
      // una pantalla en blanco.
      await abrir(tester, cuando: hoyDePrueba.add(const Duration(days: 200)));

      expect(find.byKey(const Key('ya-termino-el-ciclo')), findsOneWidget);
      expect(find.textContaining('lo prepara tu entrenador'), findsOneWidget);
    });
  });
}

/// Registros en memoria, sembrables, que responden por plan como el de verdad.
class _RegistrosSembrados implements RepositorioRegistros {
  final Map<String, RegistroDeSesion> _guardados = {};

  @override
  Future<List<RegistroDeSesion>> obtenerDePlan(
    String nadadorId,
    String planId,
  ) async => _guardados.values
      .where((r) => r.nadadorId == nadadorId && r.planId == planId)
      .toList();

  @override
  Future<RegistroDeSesion?> obtener(String id) async => _guardados[id];

  @override
  Future<void> guardar(RegistroDeSesion registro) async =>
      _guardados[registro.id] = registro;

  @override
  Future<Map<String, dynamic>> exportar(String nadadorId) async => {};

  @override
  Future<void> eliminarDe(String nadadorId) async => _guardados.clear();

  @override
  Future<Set<String>> nadadoresConRegistros() async =>
      _guardados.values.map((r) => r.nadadorId).toSet();
}

class _BandejaQuieta implements BandejaDeSalida {
  @override
  Future<void> encolar(String registroId) async {}

  @override
  Future<List<EnvioPendiente>> pendientes() async => const [];

  @override
  Future<EnvioPendiente?> estadoDe(String registroId) async => null;

  @override
  Future<void> actualizar(EnvioPendiente envio) async {}
}

class _SinRed implements EstadoDeRed {
  @override
  Future<bool> hayConexion() async => false;

  @override
  Stream<bool> get cambios => const Stream.empty();
}

class _TransporteQuieto implements EnvioDeRegistros {
  @override
  Future<DateTime> enviar(RegistroDeSesion registro) async =>
      throw const FalloDeDatos('sin red');
}
