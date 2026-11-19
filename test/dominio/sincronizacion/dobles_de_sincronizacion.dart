/// Los dobles de la bandeja de salida, **y uno de ellos es el que importa**.
///
/// `TransporteMudo` **acepta y no contesta**, que es lo que de verdad hace el
/// SDK de Firestore sin red: mete la escritura en su cola local y deja el
/// Future abierto, sin lanzar nada.
///
/// Esto no es un detalle de implementación de una prueba. Es la lección que
/// este proyecto ha pagado tres veces, en tres recorridos distintos:
///
/// - Feature 010: preguntarle algo al entrenador sin señal — la pantalla muda.
/// - Feature 003, C1: `Ver Plan` girando para siempre con el plan en la caché
///   del propio teléfono.
/// - Feature 003, C2: «Marcar como realizada» girando para siempre con el
///   registro ya guardado.
///
/// Las tres veces la suite estaba en verde, y las tres veces fue por lo mismo:
/// **el doble lanzaba donde el servidor se queda colgado**. Un `throw` es más
/// amable que el servidor al que sustituye, y esa amabilidad es exactamente lo
/// que esconde el defecto.
///
/// `dobles_de_sincronizacion_test.dart` afirma que este doble sigue colgándose,
/// para que nadie lo «arregle» más adelante.
library;

import 'dart:async';

import 'package:natacion_app/dominio/entidades/envio_pendiente.dart';
import 'package:natacion_app/dominio/entidades/registro_sesion.dart';
import 'package:natacion_app/dominio/repositorios/repositorios.dart';
import 'package:natacion_app/dominio/sincronizacion/despertador.dart';

/// Un transporte que **acepta y no contesta**, como Firestore sin red.
class TransporteMudo implements EnvioDeRegistros {
  /// Cuántas veces se le ha pedido que envíe algo.
  int intentos = 0;

  /// Qué se le pidió enviar, en orden.
  final pedidos = <RegistroDeSesion>[];

  /// Cuando es verdadero, contesta en lugar de colgarse.
  bool contesta = false;

  /// Cuando es verdadero, lanza. **Es el control negativo**: con esto puesto,
  /// una prueba que dependa de que el servidor se cuelgue deja de probar nada.
  bool lanza = false;

  DateTime horaDelServidor = DateTime(2026, 11, 18, 18);

  final _colgados = <Completer<DateTime>>[];

  /// Cuántas respuestas hay en el aire, sin contestar.
  int get colgados => _colgados.where((c) => !c.isCompleted).length;

  /// Contesta a todo lo que quedó colgado, como cuando la escritura acaba
  /// llegando por la cola interna del SDK.
  void contestaLoQueQuedoColgado() {
    for (final completer in _colgados) {
      if (!completer.isCompleted) completer.complete(horaDelServidor);
    }
  }

  /// Y lo contrario: lo colgado acaba fallando, cuando ya no lo espera nadie.
  void fallaLoQueQuedoColgado() {
    for (final completer in _colgados) {
      if (!completer.isCompleted) {
        completer.completeError(Exception('nunca llegó'));
      }
    }
  }

  @override
  Future<DateTime> enviar(RegistroDeSesion registro) {
    intentos++;
    pedidos.add(registro);

    if (lanza) return Future.error(Exception('sin conexión con el servidor'));
    if (contesta) return Future.value(horaDelServidor);

    final completer = Completer<DateTime>();
    _colgados.add(completer);
    return completer.future;
  }
}

/// El reloj y el despertador a la vez, porque son el mismo tiempo.
///
/// Programar «dentro de un minuto» y después mover el reloj un minuto tiene que
/// disparar lo programado; con dos objetos distintos eso se desincroniza y las
/// pruebas empiezan a pasar por casualidad.
class RelojDeMentira implements Despertador {
  RelojDeMentira([DateTime? desde])
    : ahora = desde ?? DateTime(2026, 11, 18, 18);

  DateTime ahora;

  /// Cuántas veces se ha programado un despertar. Una prueba comprueba que con
  /// la bandeja vacía esto se queda en cero.
  int programaciones = 0;

  DateTime? _cuando;
  Future<void> Function()? _queHacer;

  /// Si hay un despertar vivo ahora mismo.
  bool get hayAlgoProgramado => _cuando != null;

  /// Para cuándo está el despertar vivo, si lo hay.
  DateTime? get proximoDespertar => _cuando;

  @override
  void programar(Duration dentroDe, Future<void> Function() queHacer) {
    programaciones++;
    _cuando = ahora.add(dentroDe);
    _queHacer = queHacer;
  }

  @override
  void cancelar() {
    _cuando = null;
    _queHacer = null;
  }

  /// Mueve el reloj y dispara lo que toque por el camino, en orden.
  ///
  /// Espera a cada despertar antes de seguir, para que la prueba no tenga que
  /// adivinar cuántos microtasks hacen falta.
  Future<void> avanzar(Duration cuanto) async {
    final meta = ahora.add(cuanto);

    while (_cuando != null && !_cuando!.isAfter(meta)) {
      ahora = _cuando!;
      final queHacer = _queHacer!;
      _cuando = null;
      _queHacer = null;
      await queHacer();
    }

    ahora = meta;
  }
}

/// La red, simulada, para las pruebas que no son de la propia detección.
class RedDeMentira implements EstadoDeRed {
  RedDeMentira({this.hayConexionAhora = true});

  bool hayConexionAhora;
  int vecesConsultada = 0;

  final _controlador = StreamController<bool>.broadcast();

  void emitir(bool hay) => _controlador.add(hay);

  @override
  Future<bool> hayConexion() async {
    vecesConsultada++;
    return hayConexionAhora;
  }

  /// Lo anotado por la bandeja, en orden. Feature 011, D1.
  final anotados = <bool>[];

  @override
  void anotarIntento({required bool llego}) {
    anotados.add(llego);
    if (hayConexionAhora != llego) {
      hayConexionAhora = llego;
      _controlador.add(llego);
    }
  }

  @override
  Stream<bool> get cambios => _controlador.stream;
}

/// Los registros, en memoria.
class RegistrosDeMentiraLocales implements RepositorioRegistros {
  final Map<String, RegistroDeSesion> guardados = {};

  @override
  Future<RegistroDeSesion?> obtener(String id) async => guardados[id];

  @override
  Future<List<RegistroDeSesion>> obtenerDePlan(String n, String p) async =>
      guardados.values.where((r) => r.nadadorId == n && r.planId == p).toList();

  @override
  Future<void> guardar(RegistroDeSesion registro) async =>
      guardados[registro.id] = registro;

  @override
  Future<Map<String, dynamic>> exportar(String nadadorId) async => const {};

  @override
  Future<void> eliminarDe(String nadadorId) async =>
      guardados.removeWhere((_, r) => r.nadadorId == nadadorId);

  @override
  Future<Set<String>> nadadoresConRegistros() async =>
      guardados.values.map((r) => r.nadadorId).toSet();
}

/// La bandeja, en memoria.
class BandejaDeMentira implements BandejaDeSalida {
  final Map<String, EnvioPendiente> envios = {};

  @override
  Future<void> encolar(String registroId) async =>
      envios[registroId] = EnvioPendiente(registroId: registroId);

  @override
  Future<List<EnvioPendiente>> pendientes() async =>
      envios.values.where((e) => e.esperaEnvio).toList();

  @override
  Future<EnvioPendiente?> estadoDe(String registroId) async =>
      envios[registroId];

  @override
  Future<void> actualizar(EnvioPendiente envio) async =>
      envios[envio.registroId] = envio;
}

/// Un registro cualquiera, para no repetirlo en cada prueba.
RegistroDeSesion unRegistro({
  String sesionId = 's1',
  String nadadorId = 'n-ana',
  String planId = 'p1',
  bool realizada = true,
  int? rpe = 7,
  DateTime? cuando,
}) => RegistroDeSesion(
  nadadorId: nadadorId,
  planId: planId,
  sesionId: sesionId,
  versionDePlan: '1',
  realizada: realizada,
  registradoEn: cuando ?? DateTime(2026, 11, 18, 18),
  rpePercibido: rpe,
);
