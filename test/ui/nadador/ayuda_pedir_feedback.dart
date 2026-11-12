/// El banco para las pruebas de pedir feedback (feature 010, US4).
///
/// Monta `PantallaMiProgreso` con un `EstadoNadador` real, un repositorio de
/// peticiones con las dos partes —dispositivo y servidor— y una red que se
/// puede tumbar, que es lo que hace falta para medir la garantía G1.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:natacion_app/datos/peticiones/peticiones_de_las_dos_partes.dart';
import 'package:natacion_app/dominio/analisis/peticion_de_feedback.dart';
import 'package:natacion_app/dominio/entidades/envio_pendiente.dart';
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
import 'package:provider/provider.dart';

class BancoDelNadador {
  BancoDelNadador({bool conPeticiones = true}) {
    peticionesLocales = PeticionesEnMemoria();
    peticionesDelServidor = PeticionesEnMemoria();

    peticiones = PeticionesDeLasDosPartes(
      local: peticionesLocales,
      servidor: peticionesDelServidor,
      // Corta, para que una lectura sin servidor no deje la prueba esperando
      // los cinco segundos de produccion.
      esperaAlServidor: const Duration(milliseconds: 50),
    );

    estado = EstadoNadador(
      sincronizador: Sincronizador(
        registros: _RegistrosEnMemoria(),
        bandeja: _BandejaEnMemoria(),
        red: red,
        transporte: _TransporteQuieto(),
        reloj: () => hoy,
      ),
      reloj: () => hoy,
      peticiones: conPeticiones ? peticiones : null,
    );
  }

  final DateTime hoy = DateTime(2026, 11, 20, 7);

  final red = RedSimulada();

  late final PeticionesEnMemoria peticionesLocales;
  late final PeticionesEnMemoria peticionesDelServidor;
  late final PeticionesDeLasDosPartes peticiones;
  late final EstadoNadador estado;

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
    versionMetodologia: '3.6.0',
    microciclos: const [
      Microciclo(id: 'm1', nombre: 'Semana 1', orden: 1, objetivo: 'Economía'),
    ],
    sesiones: sesiones,
  );

  Widget app() => MaterialApp(
    home: ChangeNotifierProvider<EstadoNadador>.value(
      value: estado,
      child: const PantallaMiProgreso(),
    ),
  );

  /// Abre el formulario de una sesión, escribe la pregunta y la manda.
  Future<void> pedir(
    WidgetTester tester,
    String sesionId,
    String pregunta,
  ) async {
    await tester.tap(find.byKey(Key('pedir-feedback-$sesionId')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('campo-de-la-pregunta')),
      pregunta,
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('mandar-la-pregunta')));
    await tester.pumpAndSettle();
  }
}

/// Peticiones en memoria, con las mismas negativas que el servidor.
class PeticionesEnMemoria implements RepositorioPeticionesDeFeedback {
  final guardadas = <String, PeticionDeFeedback>{};

  /// Cuántas veces se escribió aquí, para distinguir «no se intentó» de
  /// «se intentó y no había red».
  int escrituras = 0;

  /// Si esta copia es la del servidor y la red está caída.
  bool falla = false;

  @override
  Future<List<PeticionDeFeedback>> deNadador(String nadadorId) async {
    if (falla) throw const FalloDeDatos('sin red');
    return [
      for (final p in guardadas.values)
        if (p.nadadorId == nadadorId) p,
    ];
  }

  @override
  Future<List<PeticionDeFeedback>> deNadadorEnPlan(
    String nadadorId,
    String planId,
  ) async {
    if (falla) throw const FalloDeDatos('sin red');
    return [
      for (final p in guardadas.values)
        if (p.nadadorId == nadadorId && p.planId == planId) p,
    ];
  }

  @override
  Future<void> guardar(PeticionDeFeedback peticion) async {
    if (falla) throw const FalloDeDatos('sin red');
    escrituras++;
    guardadas[peticion.id] = peticion;
  }

  @override
  Future<void> marcarVista(String peticionId, DateTime cuando) async {
    if (falla) throw const FalloDeDatos('sin red');
    final peticion = guardadas[peticionId];
    if (peticion == null) throw const FalloDeDatos('no existe');
    guardadas[peticionId] = peticion.vistaPor(cuando);
  }
}

class RedSimulada implements EstadoDeRed {
  bool hayConexionAhora = true;

  @override
  Future<bool> hayConexion() async => hayConexionAhora;

  @override
  Stream<bool> get cambios => const Stream.empty();
}

class _RegistrosEnMemoria implements RepositorioRegistros {
  final _guardados = <String, RegistroDeSesion>{};

  @override
  Future<RegistroDeSesion?> obtener(String id) async => _guardados[id];

  @override
  Future<List<RegistroDeSesion>> obtenerDePlan(String n, String p) async => [
    for (final r in _guardados.values)
      if (r.nadadorId == n && r.planId == p) r,
  ];

  @override
  Future<void> guardar(RegistroDeSesion registro) async =>
      _guardados[registro.id] = registro;

  @override
  Future<Map<String, dynamic>> exportar(String nadadorId) async => const {};

  @override
  Future<void> eliminarDe(String nadadorId) async {}

  @override
  Future<Set<String>> nadadoresConRegistros() async =>
      _guardados.values.map((r) => r.nadadorId).toSet();
}

class _BandejaEnMemoria implements BandejaDeSalida {
  final _envios = <String, EnvioPendiente>{};

  @override
  Future<void> encolar(String registroId) async =>
      _envios[registroId] = EnvioPendiente(registroId: registroId);

  @override
  Future<List<EnvioPendiente>> pendientes() async =>
      _envios.values.where((e) => e.estado != EstadoDeEnvio.enviado).toList();

  @override
  Future<EnvioPendiente?> estadoDe(String registroId) async =>
      _envios[registroId];

  @override
  Future<void> actualizar(EnvioPendiente envio) async =>
      _envios[envio.registroId] = envio;
}

class _TransporteQuieto implements EnvioDeRegistros {
  @override
  Future<DateTime> enviar(RegistroDeSesion registro) async =>
      throw const FalloDeDatos('sin red');
}
