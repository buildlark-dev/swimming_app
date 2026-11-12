/// M24, M28, SC-006 — «por cualquier vía» significa esto.
///
/// **No se prueba por la pantalla.** Que un widget esconda el botón no impide
/// nada: la feature 009 añade dos caminos nuevos a la misma sesión —el
/// macrociclo del nadador y la lista de pendientes—, y un cerrojo que viviera
/// en un widget sería un cerrojo en una puerta de tres.
///
/// Lo que se comprueba es que **el registro de una sesión futura no llegue a
/// existir**: ni en el dispositivo, ni en la bandeja de salida. Y la otra
/// mitad, la que le da sentido: que el de hoy sí se guarde.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:natacion_app/dominio/entidades/envio_pendiente.dart';
import 'package:natacion_app/dominio/entidades/nadador.dart';
import 'package:natacion_app/dominio/entidades/plan.dart';
import 'package:natacion_app/dominio/entidades/registro_sesion.dart';
import 'package:natacion_app/dominio/entidades/sesion.dart';
import 'package:natacion_app/dominio/macrociclo/puede_marcarse.dart';
import 'package:natacion_app/dominio/metodologia/categorias.dart';
import 'package:natacion_app/dominio/metodologia/estilos.dart';
import 'package:natacion_app/dominio/repositorios/repositorios.dart';
import 'package:natacion_app/dominio/sincronizacion/bandeja_salida.dart';
import 'package:natacion_app/ui/nadador/estado_nadador.dart';

void main() {
  final hoy = DateTime(2026, 11, 18, 7);

  late _RegistrosEnMemoria registros;
  late _BandejaEnMemoria bandeja;
  late EstadoNadador estado;

  Sesion sesion(String id, DateTime? fecha) =>
      Sesion(id: id, microcicloId: 'm1', fecha: fecha);

  Plan plan(List<Sesion> sesiones) => Plan(
    id: 'p1',
    nombre: 'Mesociclo 1: Acumulación',
    categoria: Categoria.precompetitivo,
    estiloObjetivo: Estilo.libre,
    estado: EstadoPlan.publicado,
    versionMetodologia: '3.6.0',
    sesiones: sesiones,
  );

  setUp(() {
    registros = _RegistrosEnMemoria();
    bandeja = _BandejaEnMemoria();

    estado = EstadoNadador(
      sincronizador: Sincronizador(
        registros: registros,
        bandeja: bandeja,
        red: _SinRed(),
        transporte: _TransporteQuieto(),
        reloj: () => hoy,
      ),
      reloj: () => hoy,
    );
  });

  void abrirCon(List<Sesion> sesiones) => estado.abrirComo(
    const Nadador(id: 'n1', nombre: 'Ana María Restrepo'),
    plan: plan(sesiones),
  );

  group('la sesión de mañana no se registra por ninguna vía', () {
    test('responder devuelve «todavía no» y explica por qué', () async {
      abrirCon([sesion('s1', DateTime(2026, 11, 19))]);

      final resultado = await estado.responder(
        sesion: sesion('s1', DateTime(2026, 11, 19)),
        realizada: true,
      );

      expect(resultado, isA<TodaviaNo>());
      expect(resultado.comoSeLeExplica, 'Todavía no llega ese día');
    });

    test('y no queda nada guardado en el dispositivo', () async {
      abrirCon([sesion('s1', DateTime(2026, 11, 19))]);

      await estado.responder(
        sesion: sesion('s1', DateTime(2026, 11, 19)),
        realizada: true,
      );

      expect(registros.cuantosHay, 0);
      expect(estado.registros, isEmpty);
    });

    test('ni encolado para enviar (T063)', () async {
      // **La bandeja no puede llevar lo que la regla prohíbe.** Si el registro
      // se encolara y el servidor lo rechazara, la bandeja lo reintentaría
      // para siempre: un rechazo permanente en una cola de reintentos es peor
      // que lo que se quería evitar.
      abrirCon([sesion('s1', DateTime(2026, 11, 19))]);

      await estado.responder(
        sesion: sesion('s1', DateTime(2026, 11, 19)),
        realizada: true,
      );

      expect(await bandeja.pendientes(), isEmpty);
    });

    test('decir «no la hice» de mañana tampoco se registra', () {
      // Hablar de un día que no ha pasado es hablar de un día que no ha
      // pasado, diga lo que diga.
      abrirCon([sesion('s1', DateTime(2026, 11, 19))]);

      expect(
        estado
            .responder(
              sesion: sesion('s1', DateTime(2026, 11, 19)),
              realizada: false,
            )
            .then((r) => r.si),
        completion(isFalse),
      );
    });
  });

  group('la sesión sin día no se registra, y se dice (M28)', () {
    test('responder devuelve «sin fecha»', () async {
      abrirCon([sesion('s1', null)]);

      final resultado = await estado.responder(
        sesion: sesion('s1', null),
        realizada: true,
      );

      expect(resultado, isA<SinFecha>());
      expect(resultado.comoSeLeExplica, 'Esta sesión no tiene día asignado');
      expect(registros.cuantosHay, 0);
    });
  });

  group('la otra mitad: lo que sí se registra', () {
    test('la de hoy se guarda y se encola', () async {
      // **Sin esto, todo lo de arriba pasaría con un `responder` que no
      // hiciera nada.**
      abrirCon([sesion('s1', DateTime(2026, 11, 18))]);

      final resultado = await estado.responder(
        sesion: sesion('s1', DateTime(2026, 11, 18)),
        realizada: true,
        rpePercibido: 7,
      );

      expect(resultado.si, isTrue);
      expect(registros.cuantosHay, 1);
      expect(await bandeja.pendientes(), hasLength(1));
    });

    test('la de hoy por la tarde, abriendo la app por la mañana', () async {
      // La sesión está fechada a las 19:00 y el nadador abre a las 07:00.
      // Comparando instantes esto sería «todavía no llega», y es la misma
      // sesión de hoy.
      abrirCon([sesion('s1', DateTime(2026, 11, 18, 19))]);

      final resultado = await estado.responder(
        sesion: sesion('s1', DateTime(2026, 11, 18, 19)),
        realizada: true,
      );

      expect(resultado.si, isTrue);
      expect(registros.cuantosHay, 1);
    });

    test('una pasada se guarda aunque se haya saltado la anterior', () async {
      // M25, M27, FR-025: un día saltado no es una puerta cerrada. El martes
      // queda sin marcar y el jueves se marca igual.
      final martes = sesion('s-martes', DateTime(2026, 11, 10));
      final jueves = sesion('s-jueves', DateTime(2026, 11, 12));
      abrirCon([martes, jueves]);

      expect(
        (await estado.responder(sesion: jueves, realizada: true)).si,
        isTrue,
      );
      expect(registros.cuantosHay, 1);

      // Y el martes sigue abierto: se puede marcar después.
      expect(
        (await estado.responder(sesion: martes, realizada: true)).si,
        isTrue,
      );
      expect(registros.cuantosHay, 2);
    });
  });
}

class _RegistrosEnMemoria implements RepositorioRegistros {
  final Map<String, RegistroDeSesion> _guardados = {};

  int get cuantosHay => _guardados.length;

  @override
  Future<void> guardar(RegistroDeSesion registro) async =>
      _guardados[registro.id] = registro;

  @override
  Future<RegistroDeSesion?> obtener(String id) async => _guardados[id];

  @override
  Future<List<RegistroDeSesion>> obtenerDePlan(String n, String p) async =>
      _guardados.values.where((r) => r.planId == p).toList();

  @override
  Future<Map<String, dynamic>> exportar(String nadadorId) async => {};

  @override
  Future<void> eliminarDe(String nadadorId) async => _guardados.clear();

  @override
  Future<Set<String>> nadadoresConRegistros() async =>
      _guardados.values.map((r) => r.nadadorId).toSet();
}

class _BandejaEnMemoria implements BandejaDeSalida {
  final Map<String, EnvioPendiente> _cola = {};

  @override
  Future<void> encolar(String registroId) async =>
      _cola[registroId] = EnvioPendiente(registroId: registroId);

  @override
  Future<List<EnvioPendiente>> pendientes() async =>
      _cola.values.where((e) => e.estado != EstadoDeEnvio.enviado).toList();

  @override
  Future<EnvioPendiente?> estadoDe(String registroId) async =>
      _cola[registroId];

  @override
  Future<void> actualizar(EnvioPendiente envio) async =>
      _cola[envio.registroId] = envio;
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
