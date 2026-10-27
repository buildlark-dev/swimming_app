import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:natacion_app/dominio/entidades/envio_pendiente.dart';
import 'package:natacion_app/dominio/entidades/nadador.dart';
import 'package:natacion_app/dominio/entidades/parte.dart';
import 'package:natacion_app/dominio/entidades/plan.dart';
import 'package:natacion_app/dominio/entidades/registro_sesion.dart';
import 'package:natacion_app/dominio/entidades/serie.dart';
import 'package:natacion_app/dominio/entidades/sesion.dart';
import 'package:natacion_app/dominio/metodologia/categorias.dart';
import 'package:natacion_app/dominio/metodologia/estilos.dart';
import 'package:natacion_app/dominio/metodologia/zonas.dart';
import 'package:natacion_app/dominio/repositorios/repositorios.dart';
import 'package:natacion_app/dominio/sincronizacion/bandeja_salida.dart';
import 'package:natacion_app/ui/nadador/estado_nadador.dart';
import 'package:natacion_app/ui/nadador/pantalla_mi_progreso.dart';
import 'package:natacion_app/ui/nadador/pantalla_sesion_del_dia.dart';
import 'package:provider/provider.dart';

/// El recorrido del nadador, **con la red caída**.
///
/// Escenarios C1, C2 y C7 de `quickstart.md`. La verificación en un dispositivo
/// real sigue siendo obligatoria (tarea T071): un emulador de red no es una
/// piscina. Esto comprueba lo que sí se puede comprobar aquí.
void main() {
  late _RegistrosEnMemoria registros;
  late _BandejaEnMemoria bandeja;
  late _RedSimulada red;
  late _TransporteSimulado transporte;
  late EstadoNadador estado;

  final hoy = DateTime(2026, 10, 14, 7);

  Sesion sesion({required String id, required DateTime fecha}) => Sesion(
    id: id,
    microcicloId: 'm1',
    fecha: fecha,
    objetivoTecnico: 'Técnica de eficiencia en Libre',
    objetivoFisiologico: 'Base aeróbica',
    partes: [
      Parte(
        tipo: TipoParte.inicial,
        series: [
          const Serie(
            repeticiones: 4,
            distancia: 100,
            zona: Zona.a1,
            estilo: Estilo.libre,
          ),
        ],
      ),
      const Parte(tipo: TipoParte.central),
      const Parte(tipo: TipoParte.cierre),
    ],
  );

  Plan planCon(List<Sesion> sesiones) => Plan(
    id: 'p1',
    nombre: 'Microciclo de base',
    categoria: Categoria.precompetitivo,
    estiloObjetivo: Estilo.libre,
    pruebaObjetivo: '800 Libre',
    estado: EstadoPlan.publicado,
    versionMetodologia: '3.5.0',
    microciclos: const [
      Microciclo(
        id: 'm1',
        nombre: 'Semana 1',
        orden: 1,
        objetivo: 'Economía de nado',
      ),
    ],
    sesiones: sesiones,
  );

  setUp(() {
    registros = _RegistrosEnMemoria();
    bandeja = _BandejaEnMemoria();
    red = _RedSimulada(hayConexion: true);
    transporte = _TransporteSimulado();

    estado = EstadoNadador(
      sincronizador: Sincronizador(
        registros: registros,
        bandeja: bandeja,
        red: red,
        transporte: transporte,
        reloj: () => hoy,
      ),
      reloj: () => hoy,
    );
  });

  Widget app(Widget pantalla) => MaterialApp(
    home: ChangeNotifierProvider<EstadoNadador>.value(
      value: estado,
      child: pantalla,
    ),
  );

  group('C1 — la sesión del día, sin señal', () {
    testWidgets('aparece completa con la red caída', (tester) async {
      red.hayConexionAhora = false;
      estado.abrirComo(
        const Nadador(id: 'n1', nombre: 'Perfil de prueba'),
        plan: planCon([sesion(id: 's1', fecha: hoy)]),
      );

      await tester.pumpWidget(app(const PantallaSesionDelDia()));
      await tester.pump();

      expect(find.text('Técnica de eficiencia en Libre'), findsOneWidget);
      expect(find.text('Base aeróbica'), findsOneWidget);
    });

    testWidgets('las series van con la notación del entrenador', (
      tester,
    ) async {
      red.hayConexionAhora = false;
      estado.abrirComo(
        const Nadador(id: 'n1', nombre: 'Perfil de prueba'),
        plan: planCon([sesion(id: 's1', fecha: hoy)]),
      );

      await tester.pumpWidget(app(const PantallaSesionDelDia()));
      await tester.pump();

      // FR-004: sin abreviar, reescribir ni corregir.
      expect(find.textContaining('4×100'), findsOneWidget);
    });

    testWidgets('sin sesión hoy dice cuál es la siguiente', (tester) async {
      estado.abrirComo(
        const Nadador(id: 'n1', nombre: 'Perfil de prueba'),
        plan: planCon([
          sesion(id: 's1', fecha: hoy.add(const Duration(days: 2))),
        ]),
      );

      await tester.pumpWidget(app(const PantallaSesionDelDia()));
      await tester.pump();

      expect(find.text('Hoy descansas'), findsOneWidget);
      expect(find.textContaining('16/10'), findsOneWidget);
    });

    testWidgets('sin plan asignado lo dice, no da error', (tester) async {
      estado.abrirComo(const Nadador(id: 'n1', nombre: 'Perfil de prueba'));

      await tester.pumpWidget(app(const PantallaSesionDelDia()));
      await tester.pump();

      expect(find.textContaining('no tienes un plan'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('C2 — anotar sin conexión', () {
    testWidgets('guardar sin red muestra el aviso exacto de FR-017', (
      tester,
    ) async {
      red.hayConexionAhora = false;
      final plan = planCon([sesion(id: 's1', fecha: hoy)]);
      estado.abrirComo(
        const Nadador(id: 'n1', nombre: 'Perfil de prueba'),
        plan: plan,
      );

      await tester.pumpWidget(app(const PantallaSesionDelDia()));
      await tester.pump();

      // Antes de responder, el aviso no ocupa pantalla.
      expect(find.text(avisoProgresoGuardado), findsNothing);

      await estado.responder(sesion: plan.sesiones.first, realizada: true);
      await tester.pump();

      expect(
        find.text(avisoProgresoGuardado),
        findsOneWidget,
        reason:
            'FR-017 exige ese texto literal, y aparece solo cuando hay algo '
            'esperando: el estado de sincronización no estorba cuando no hace '
            'falta',
      );
    });

    testWidgets('el botón de marcar está en la pantalla', (tester) async {
      estado.abrirComo(
        const Nadador(id: 'n1', nombre: 'Perfil de prueba'),
        plan: planCon([sesion(id: 's1', fecha: hoy)]),
      );

      await tester.pumpWidget(app(const PantallaSesionDelDia()));
      await tester.pump();

      await tester.dragUntilVisible(
        find.text('Marcar como realizada'),
        find.byType(ListView),
        const Offset(0, -200),
      );

      expect(find.text('Marcar como realizada'), findsOneWidget);
    });

    testWidgets('el registro queda guardado aunque no haya red', (
      tester,
    ) async {
      red.hayConexionAhora = false;
      estado.abrirComo(
        const Nadador(id: 'n1', nombre: 'Perfil de prueba'),
        plan: planCon([sesion(id: 's1', fecha: hoy)]),
      );

      await estado.responder(
        sesion: sesion(id: 's1', fecha: hoy),
        realizada: true,
        rpePercibido: 7,
        observaciones: 'Me costó la tercera',
      );

      expect(registros.guardados, hasLength(1));
      expect(registros.guardados.values.first.rpePercibido, 7);
      expect(estado.hayPendientes, isTrue);
    });

    testWidgets('al volver la red el aviso desaparece', (tester) async {
      red.hayConexionAhora = false;
      estado.abrirComo(
        const Nadador(id: 'n1', nombre: 'Perfil de prueba'),
        plan: planCon([sesion(id: 's1', fecha: hoy)]),
      );

      await estado.responder(
        sesion: sesion(id: 's1', fecha: hoy),
        realizada: true,
      );
      expect(estado.hayPendientes, isTrue);

      red.hayConexionAhora = true;
      await estado.sincronizar();

      expect(estado.hayPendientes, isFalse);
      expect(transporte.enviados, hasLength(1));
    });

    testWidgets('nunca se le muestra un error de red al nadador', (
      tester,
    ) async {
      red.hayConexionAhora = false;
      estado.abrirComo(
        const Nadador(id: 'n1', nombre: 'Perfil de prueba'),
        plan: planCon([sesion(id: 's1', fecha: hoy)]),
      );

      await estado.responder(
        sesion: sesion(id: 's1', fecha: hoy),
        realizada: true,
      );

      await tester.pumpWidget(app(const PantallaSesionDelDia()));
      await tester.pump();

      // Ni código de estado, ni contador de reintentos, ni botón de reintentar.
      expect(find.textContaining('error'), findsNothing);
      expect(find.textContaining('Reintentar'), findsNothing);
      expect(find.textContaining('intentos'), findsNothing);
    });
  });

  group('C7 — quien no anota, no se bloquea', () {
    testWidgets('se puede marcar la sesión sin escribir nada', (tester) async {
      estado.abrirComo(
        const Nadador(id: 'n1', nombre: 'Perfil de prueba'),
        plan: planCon([sesion(id: 's1', fecha: hoy)]),
      );

      await estado.responder(
        sesion: sesion(id: 's1', fecha: hoy),
        realizada: true,
      );

      final guardado = registros.guardados.values.first;
      expect(guardado.soloMarcada, isTrue);
      expect(guardado.realizada, isTrue);
    });

    testWidgets('el formulario dice que anotar es opcional', (tester) async {
      estado.abrirComo(
        const Nadador(id: 'n1', nombre: 'Perfil de prueba'),
        plan: planCon([sesion(id: 's1', fecha: hoy)]),
      );

      await tester.pumpWidget(app(const PantallaSesionDelDia()));
      await tester.pump();

      await tester.dragUntilVisible(
        find.textContaining('Anotar es opcional'),
        find.byType(ListView),
        const Offset(0, -200),
      );

      expect(find.textContaining('Anotar es opcional'), findsOneWidget);
    });

    testWidgets('«no pude hacerla» también se registra', (tester) async {
      estado.abrirComo(
        const Nadador(id: 'n1', nombre: 'Perfil de prueba'),
        plan: planCon([sesion(id: 's1', fecha: hoy)]),
      );

      await estado.responder(
        sesion: sesion(id: 's1', fecha: hoy),
        realizada: false,
        observaciones: 'Tenía examen',
      );

      expect(registros.guardados.values.first.realizada, isFalse);
      expect(registros.guardados.values.first.observaciones, 'Tenía examen');
    });
  });

  group('mi progreso', () {
    testWidgets('muestra la adherencia como recuento, sin gráficas', (
      tester,
    ) async {
      estado.abrirComo(
        const Nadador(id: 'n1', nombre: 'Perfil de prueba'),
        plan: planCon([
          sesion(id: 's1', fecha: hoy.subtract(const Duration(days: 2))),
          sesion(id: 's2', fecha: hoy),
        ]),
        registros: [
          RegistroDeSesion(
            nadadorId: 'n1',
            planId: 'p1',
            sesionId: 's1',
            versionDePlan: '3.5.0',
            realizada: true,
            registradoEn: hoy,
            rpePercibido: 6,
          ),
        ],
      );

      await tester.pumpWidget(app(const PantallaMiProgreso()));
      await tester.pump();

      expect(find.text('1 de 2'), findsAtLeastNWidgets(1));
    });

    testWidgets('la molestia se ve señalada', (tester) async {
      estado.abrirComo(
        const Nadador(id: 'n1', nombre: 'Perfil de prueba'),
        plan: planCon([sesion(id: 's1', fecha: hoy)]),
        registros: [
          RegistroDeSesion(
            nadadorId: 'n1',
            planId: 'p1',
            sesionId: 's1',
            versionDePlan: '3.5.0',
            realizada: true,
            registradoEn: hoy,
            molestia: const ReporteDeMolestia(
              descripcion: 'Pinchazo en el hombro',
              zonaDelCuerpo: 'hombro derecho',
            ),
          ),
        ],
      );

      await tester.pumpWidget(app(const PantallaMiProgreso()));
      await tester.pump();

      expect(find.text('Pinchazo en el hombro'), findsOneWidget);
    });
  });

  group('el plan no se toca', () {
    testWidgets('responder no modifica el plan publicado', (tester) async {
      final plan = planCon([sesion(id: 's1', fecha: hoy)]);
      final antes = plan.sesiones.first.metros;

      estado.abrirComo(
        const Nadador(id: 'n1', nombre: 'Perfil de prueba'),
        plan: plan,
      );

      await estado.responder(
        sesion: plan.sesiones.first,
        realizada: true,
        rpePercibido: 9,
      );

      expect(estado.plan!.sesiones.first.metros, antes);
      expect(estado.plan!.estado, EstadoPlan.publicado);
    });
  });
}

// ---------------------------------------------------------------------------
// Dobles de prueba
// ---------------------------------------------------------------------------

class _RegistrosEnMemoria implements RepositorioRegistros {
  @override
  Future<Set<String>> nadadoresConRegistros() async =>
      guardados.values.map((r) => r.nadadorId).toSet();

  final Map<String, RegistroDeSesion> guardados = {};

  @override
  Future<RegistroDeSesion?> obtener(String id) async => guardados[id];

  @override
  Future<List<RegistroDeSesion>> obtenerDePlan(String n, String p) async =>
      guardados.values.toList();

  @override
  Future<void> guardar(RegistroDeSesion registro) async =>
      guardados[registro.id] = registro;

  @override
  Future<Map<String, dynamic>> exportar(String nadadorId) async => {};

  @override
  Future<void> eliminarDe(String nadadorId) async => guardados.clear();
}

class _BandejaEnMemoria implements BandejaDeSalida {
  final Map<String, EnvioPendiente> _envios = {};

  @override
  Future<void> encolar(String id) async =>
      _envios[id] = EnvioPendiente(registroId: id);

  @override
  Future<List<EnvioPendiente>> pendientes() async =>
      _envios.values.where((e) => e.esperaEnvio).toList();

  @override
  Future<EnvioPendiente?> estadoDe(String id) async => _envios[id];

  @override
  Future<void> actualizar(EnvioPendiente envio) async =>
      _envios[envio.registroId] = envio;
}

class _RedSimulada implements EstadoDeRed {
  _RedSimulada({required bool hayConexion}) : hayConexionAhora = hayConexion;

  bool hayConexionAhora;

  @override
  Future<bool> hayConexion() async => hayConexionAhora;

  @override
  Stream<bool> get cambios => const Stream<bool>.empty();
}

class _TransporteSimulado implements EnvioDeRegistros {
  final List<RegistroDeSesion> enviados = [];

  @override
  Future<DateTime> enviar(RegistroDeSesion registro) async {
    enviados.add(registro);
    return DateTime(2026, 10, 14, 7);
  }
}
