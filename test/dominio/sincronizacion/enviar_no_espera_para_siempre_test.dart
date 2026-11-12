/// Enviar **no espera para siempre**, ni cuando el servidor acepta y calla.
///
/// Hallazgo del recorrido en el Pixel 7, cerrando C2 de la feature 003. Con el
/// avión puesto, Ana marca la sesión y el botón **se queda girando**. No cinco
/// segundos: para siempre. La anotación estaba guardada —eso lo garantiza
/// `guardar`, que escribe y encola antes de cualquier intento— pero ella no
/// veía ni el aviso ni el tick, así que para ella la app no había hecho nada.
///
/// ## Por qué las pruebas que ya había no lo vieron
///
/// Dos cosas, y las dos son la misma:
///
/// 1. `_EnvioSimulado` de `bandeja_salida_test.dart` **lanza** donde Firestore
///    **se cuelga**. El SDK acepta el `set()` en su cola local y deja el Future
///    abierto hasta que el servidor confirme. Un doble que lanza es más amable
///    que el servidor de verdad, y eso tapa justo este fallo.
/// 2. El sondeo de red nunca sondeó nada: `main.dart` lo tenía puesto como
///    `() async => datos != null`, que es «¿se inicializó Firestore?» y vale
///    `true` con el avión puesto. Así que la puerta de `sincronizar` —la que
///    debía parar esto— siempre estaba abierta.
///
/// Lo segundo no se arregla cambiando el sondeo: lo arregla **acotar el
/// envío**, que es lo que `estado_de_red.dart` dice desde el principio que
/// tiene que ser la detección —«se intenta una escritura y se ve si llega»—.
/// Un envío que no vuelve no es que haya llegado: es que no hay red.
///
/// Y va en el dominio y no en `EnvioAFirestore` a propósito: protege de
/// **cualquier** transporte que se cuelgue, no solo del que hoy se usa.
library;

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:natacion_app/dominio/entidades/envio_pendiente.dart';
import 'package:natacion_app/dominio/entidades/registro_sesion.dart';
import 'package:natacion_app/dominio/repositorios/repositorios.dart';
import 'package:natacion_app/dominio/sincronizacion/bandeja_salida.dart';

void main() {
  late _Registros registros;
  late _Bandeja bandeja;
  late _TransporteMudo transporte;
  late Sincronizador sincronizador;

  final ahora = DateTime(2026, 11, 12, 18);

  RegistroDeSesion unRegistro({String sesionId = 's1'}) => RegistroDeSesion(
    nadadorId: 'n-ana',
    planId: 'p1',
    sesionId: sesionId,
    versionDePlan: '1',
    realizada: true,
    registradoEn: ahora,
    rpePercibido: 7,
  );

  setUp(() {
    registros = _Registros();
    bandeja = _Bandeja();
    transporte = _TransporteMudo();
    sincronizador = Sincronizador(
      registros: registros,
      bandeja: bandeja,
      // **El sondeo dice que sí**, como en producción con el avión puesto.
      // Esa es justo la situación que hay que sobrevivir.
      red: _RedQueSiempreDiceQueSi(),
      transporte: transporte,
      reloj: () => ahora,
      // Corto, para que la prueba no espere los segundos de producción.
      esperaAlEnvio: const Duration(milliseconds: 50),
    );
  });

  test('sincronizar vuelve aunque el servidor acepte y no conteste', () async {
    await sincronizador.guardar(unRegistro());

    // **Esto es el cerrojo.** Sin él la prueba se colgaría, igual que se colgó
    // el botón de Ana, y la suite entera se quedaría parada.
    await sincronizador.sincronizar().timeout(
      const Duration(seconds: 2),
      onTimeout: () => fail(
        'el envío se esperó sin fin: eso es una nadadora al borde de la '
        'piscina que marca su sesión y ve el botón girando para siempre',
      ),
    );

    expect(transporte.intentos, 1, reason: 'se intenta, no se espera sin fin');
  });

  test('lo que no llegó sigue pendiente y con su aviso', () async {
    await sincronizador.guardar(unRegistro());
    await sincronizador.sincronizar();

    expect(
      await sincronizador.hayPendientes(),
      isTrue,
      reason:
          'garantía G3: nunca se descarta. Y es lo que enciende el aviso que '
          'FR-017 exige al pie de la letra',
    );

    final estado = await bandeja.estadoDe(unRegistro().id);
    expect(estado!.estado, EstadoDeEnvio.pendiente);
    expect(estado.intentos, 1, reason: 'cuenta como intento fallido');
  });

  test('un envío colgado no bloquea a los que vienen detrás', () async {
    // El peor de los casos: si el bucle se quedara en el primero, lo que
    // anotara después no saldría nunca aunque volviera la señal.
    await sincronizador.guardar(unRegistro(sesionId: 's1'));
    await sincronizador.guardar(unRegistro(sesionId: 's2'));

    await sincronizador.sincronizar().timeout(
      const Duration(seconds: 2),
      onTimeout: () => fail('el segundo envío se quedó detrás del primero'),
    );

    expect(transporte.intentos, 2);
  });

  test('si el servidor contesta a tiempo, se envía y ya está', () async {
    // El control negativo: acotar no puede dar por fallido lo que sí llegó.
    transporte.contesta = true;

    await sincronizador.guardar(unRegistro());
    await sincronizador.sincronizar();

    expect(await sincronizador.hayPendientes(), isFalse);
  });

  test('dos sincronizaciones a la vez no mandan el registro dos veces', () {
    // El contrato tiene tres disparadores —al guardar, al volver la red y al
    // abrir la app— y nada impedía que dos coincidieran. Las dos leen la
    // bandeja antes de que ninguna marque «enviando», así que las dos ven el
    // mismo registro pendiente.
    //
    // Lo encontró quitar el `await` de `responder`, que es lo que hizo
    // posible el solape de verdad. Con el identificador determinista el
    // servidor no acaba con dos copias, así que no se perdía nada: lo que
    // había era un envío de más por cada coincidencia, pagado con el plan de
    // datos de una nadadora.
    transporte.contesta = true;

    return () async {
      await sincronizador.guardar(unRegistro());

      await Future.wait([
        sincronizador.sincronizar(),
        sincronizador.sincronizar(),
      ]);

      expect(
        transporte.intentos,
        1,
        reason: 'una a la vez: la segunda se engancha',
      );
    }();
  });
}

/// Acepta y no contesta, como Firestore sin red.
class _TransporteMudo implements EnvioDeRegistros {
  int intentos = 0;
  bool contesta = false;

  @override
  Future<DateTime> enviar(RegistroDeSesion registro) async {
    intentos++;
    if (contesta) return DateTime(2026, 11, 12, 18);
    return Completer<DateTime>().future;
  }
}

/// Lo que `main.dart` tenía de verdad: un sondeo que siempre dice que sí.
class _RedQueSiempreDiceQueSi implements EstadoDeRed {
  @override
  Future<bool> hayConexion() async => true;

  @override
  Stream<bool> get cambios => const Stream.empty();
}

class _Registros implements RepositorioRegistros {
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

class _Bandeja implements BandejaDeSalida {
  final Map<String, EnvioPendiente> _envios = {};

  @override
  Future<void> encolar(String registroId) async =>
      _envios[registroId] = EnvioPendiente(registroId: registroId);

  @override
  Future<List<EnvioPendiente>> pendientes() async =>
      _envios.values.where((e) => e.esperaEnvio).toList();

  @override
  Future<EnvioPendiente?> estadoDe(String registroId) async =>
      _envios[registroId];

  @override
  Future<void> actualizar(EnvioPendiente envio) async =>
      _envios[envio.registroId] = envio;
}
