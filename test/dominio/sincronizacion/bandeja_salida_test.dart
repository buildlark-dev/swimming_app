import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:natacion_app/dominio/entidades/envio_pendiente.dart';
import 'package:natacion_app/dominio/entidades/registro_sesion.dart';
import 'package:natacion_app/dominio/repositorios/repositorios.dart';
import 'package:natacion_app/dominio/sincronizacion/bandeja_salida.dart';

/// Las ocho garantías del contrato de sincronización.
///
/// `specs/003-consumo-del-nadador/contracts/sincronizacion.md`.
///
/// **Todo esto corre en Dart puro**, con la red y el reloj simulados. Es la
/// razón por la que la escritura no se delegó en la cola interna de Firestore:
/// aquello no se podría probar sin probar Firebase.
void main() {
  late _RegistrosEnMemoria registros;
  late _BandejaEnMemoria bandeja;
  late _RedSimulada red;
  late _EnvioSimulado envio;
  late DateTime ahora;
  late Sincronizador sincronizador;

  RegistroDeSesion unRegistro({
    String sesionId = 's1',
    bool realizada = true,
    int? rpe = 7,
  }) => RegistroDeSesion(
    nadadorId: 'n1',
    planId: 'p1',
    sesionId: sesionId,
    versionDePlan: '1',
    realizada: realizada,
    registradoEn: ahora,
    rpePercibido: rpe,
  );

  setUp(() {
    ahora = DateTime(2026, 10, 14, 7, 30);
    registros = _RegistrosEnMemoria();
    bandeja = _BandejaEnMemoria();
    red = _RedSimulada(hayConexion: true);
    envio = _EnvioSimulado();
    sincronizador = Sincronizador(
      registros: registros,
      bandeja: bandeja,
      red: red,
      transporte: envio,
      reloj: () => ahora,
    );
  });

  group('S1 — guardar sin red da éxito y deja pendiente', () {
    test('no falla por falta de conexión', () async {
      red.hayConexionAhora = false;

      await sincronizador.guardar(unRegistro());

      expect(registros.guardados, hasLength(1));
    });

    test('el registro queda en estado pendiente', () async {
      red.hayConexionAhora = false;

      final registro = unRegistro();
      await sincronizador.guardar(registro);

      final estado = await bandeja.estadoDe(registro.id);
      expect(estado!.estado, EstadoDeEnvio.pendiente);
    });

    test('el aviso al nadador se muestra', () async {
      red.hayConexionAhora = false;
      await sincronizador.guardar(unRegistro());

      expect(await sincronizador.hayPendientes(), isTrue);
    });

    test('guardar nunca consulta la red', () async {
      red.hayConexionAhora = false;
      await sincronizador.guardar(unRegistro());

      expect(
        red.vecesConsultada,
        0,
        reason:
            'Garantía G1: escribir no puede fallar por culpa de la red, '
            'así que ni siquiera la mira',
      );
    });
  });

  group('S2 — vuelve la red y se envía solo', () {
    test('sin intervención del nadador', () async {
      red.hayConexionAhora = false;
      await sincronizador.guardar(unRegistro());

      red.hayConexionAhora = true;
      final resultado = await sincronizador.sincronizar();

      expect(resultado.enviados, hasLength(1));
      expect(resultado.todoEnviado, isTrue);
    });

    test('el aviso desaparece', () async {
      red.hayConexionAhora = false;
      await sincronizador.guardar(unRegistro());

      red.hayConexionAhora = true;
      await sincronizador.sincronizar();

      expect(await sincronizador.hayPendientes(), isFalse);
    });

    test('sin red se intenta, y lo que se sabe sale del intento', () async {
      // **Esta prueba decía lo contrario hasta la feature 011**, y decía:
      // «sin red no se intenta, y no cuenta como intento». Había una puerta
      // —`if (!await red.hayConexion()) return sinRed`— y esto la fijaba.
      //
      // La puerta se quitó (decisión D1). Con el intento como sondeo se
      // cierra sobre sí misma: un fallo deja la red en falso, la puerta
      // bloquea el siguiente intento, y entonces no vuelve a saberse nada
      // nunca. Y una puerta delante de lo único que puede contestar la
      // pregunta es, literalmente, el defecto que la 011 arregla.
      //
      // Lo que se gana: `sinRed` pasa de ser una suposición de antes a ser
      // una conclusión de después. Lo que se pierde: la distinción «no se
      // intentó porque no había red», que nunca fue conocible por adelantado.
      envio.fallaLasProximas = 1;
      final registro = unRegistro();
      await sincronizador.guardar(registro);

      final resultado = await sincronizador.sincronizar();

      expect(
        resultado.sinRed,
        isTrue,
        reason: 'se intentó y no llegó: eso es lo que hoy se sabe de la red',
      );
      expect(envio.enviados, isEmpty);
      expect(
        (await bandeja.estadoDe(registro.id))!.intentos,
        greaterThan(0),
        reason:
            'y ahora sí cuenta: el intento es el sondeo, así que sondear '
            'cuesta un intento. Es lo que paga poder enterarse',
      );
    });

    // **La prueba de `alVolverLaRed` se retiró aquí** (feature 011, T018).
    //
    // Decía: «el flujo de cambios de red dispara la sincronización», y era
    // cierta. Lo que no era cierto es que sirviera para algo: nadie en `lib/`
    // escuchaba ese flujo, y el sondeo detrás —`() async => datos != null`—
    // preguntaba si Firestore se había inicializado, cierto con el avión
    // puesto y para siempre, así que no emitía nunca.
    //
    // Una prueba en verde sobre una pieza que no estaba montada. Siete
    // features.
    //
    // El disparador no se cableó: se sustituyó. Con el intento como sondeo no
    // hay un «volvió la red» separado que escuchar, porque el propio intento
    // es el descubrimiento. Lo que la nadadora tenía prometido se cumple
    // igual, y ahora de verdad: ella no toca nada y lo suyo sale.
    //
    // Lo prueban, en su sitio:
    // `reintenta_mientras_quede_algo_test.dart` (que sale sola),
    // `sin_cola_no_se_sondea_test.dart` (que no cuesta nada si no hay nada) y
    // `el_despertar_esta_cableado_test.dart` (que está **conectado**, que es
    // lo que aquí faltaba).
  });

  group('S3 — lo pendiente sobrevive al cierre de la app', () {
    test(
      'un sincronizador nuevo sobre el mismo almacén lo encuentra',
      () async {
        red.hayConexionAhora = false;
        await sincronizador.guardar(unRegistro());

        // Simula cerrar y reabrir: instancias nuevas, mismo almacenamiento.
        final otro = Sincronizador(
          registros: registros,
          bandeja: bandeja,
          red: red,
          transporte: envio,
          reloj: () => ahora,
        );

        expect(await otro.hayPendientes(), isTrue);

        red.hayConexionAhora = true;
        expect((await otro.sincronizar()).enviados, hasLength(1));
      },
    );
  });

  group('S4 — tres fallos y luego éxito', () {
    test('un solo documento en destino y tres intentos contados', () async {
      final registro = unRegistro();
      await sincronizador.guardar(registro);

      envio.fallaLasProximas = 3;

      for (var i = 0; i < 3; i++) {
        await sincronizador.sincronizar();
        // El reloj avanza lo suficiente para que toque el siguiente reintento.
        ahora = ahora.add(const Duration(minutes: 10));
      }

      final resultado = await sincronizador.sincronizar();

      expect(resultado.enviados, hasLength(1));
      expect(
        envio.enviados.where((r) => r.id == registro.id),
        hasLength(1),
        reason: 'Los fallos no llegaron a destino; solo el éxito cuenta',
      );
      expect((await bandeja.estadoDe(registro.id))!.intentos, 3);
    });

    test('entre reintentos se espera, no se martillea', () async {
      await sincronizador.guardar(unRegistro());
      envio.fallaLasProximas = 1;

      await sincronizador.sincronizar();
      final intentosTrasElFallo = envio.intentosDeEnvio;

      // Sin avanzar el reloj, el siguiente ciclo no debe reintentar.
      await sincronizador.sincronizar();

      expect(
        envio.intentosDeEnvio,
        intentosTrasElFallo,
        reason:
            'El teléfono es de alguien que está nadando y tiene batería '
            'limitada: no se reintenta en bucle apretado',
      );
    });
  });

  group('S5 — reenviar no duplica', () {
    test('el mismo registro enviado dos veces es un solo documento', () async {
      final registro = unRegistro();

      await sincronizador.guardar(registro);
      await sincronizador.sincronizar();

      // Vuelve a guardarse y a enviarse: mismos datos, misma sesión.
      await sincronizador.guardar(registro);
      await sincronizador.sincronizar();

      expect(envio.destino.keys.where((id) => id == registro.id), hasLength(1));
    });

    test('el identificador es determinista, que es lo que lo garantiza', () {
      final a = unRegistro();
      final b = unRegistro(rpe: 2);

      expect(
        a.id,
        b.id,
        reason:
            'Mismo nadador, plan, sesión y versión: mismo identificador, '
            'aunque el contenido cambie. La duplicación es imposible por '
            'construcción, no por una comprobación que alguien pueda olvidar',
      );
    });

    test('cambiar de sesión cambia el identificador', () {
      expect(
        unRegistro(sesionId: 's1').id,
        isNot(unRegistro(sesionId: 's2').id),
      );
    });
  });

  group('S6 — de tres pendientes llegan dos', () {
    test(
      'dos enviados y uno pendiente, sin estados intermedios raros',
      () async {
        await sincronizador.guardar(unRegistro(sesionId: 's1'));
        await sincronizador.guardar(unRegistro(sesionId: 's2'));
        await sincronizador.guardar(unRegistro(sesionId: 's3'));

        envio.fallaPara = {'n1|p1|s2|1'};

        final resultado = await sincronizador.sincronizar();

        expect(resultado.enviados, hasLength(2));
        expect(resultado.siguenPendientes, ['n1|p1|s2|1']);
        expect(
          resultado.todoEnviado,
          isFalse,
          reason:
              'El estado es correcto, no inconsistente: no hay transacción '
              'entre varios registros',
        );
      },
    );

    test('que uno falle no detiene a los demás', () async {
      await sincronizador.guardar(unRegistro(sesionId: 's1'));
      await sincronizador.guardar(unRegistro(sesionId: 's2'));

      envio.fallaPara = {'n1|p1|s1|1'};
      await sincronizador.sincronizar();

      expect(envio.enviados.map((r) => r.sesionId), contains('s2'));
    });
  });

  group('S7 — con red el aviso nunca aparece', () {
    test('el registro llega directo al sincronizar', () async {
      await sincronizador.guardar(unRegistro());
      await sincronizador.sincronizar();

      expect(await sincronizador.hayPendientes(), isFalse);
    });
  });

  group('S8 — un fallo al escribir en local sí se reporta', () {
    test('se propaga, porque ahí el dato sí se perdería', () async {
      registros.fallaAlGuardar = true;

      expect(
        () => sincronizador.guardar(unRegistro()),
        throwsA(isA<Exception>()),
        reason:
            'Un fallo de red deja pendiente y reintenta; un fallo de '
            'escritura local significa que el dato se pierde, y el nadador '
            'tiene que saberlo',
      );
    });
  });

  group('no existe estado terminal de fallo', () {
    test('cuarenta intentos y el registro sigue pendiente', () async {
      final registro = unRegistro();
      await sincronizador.guardar(registro);

      envio.fallaLasProximas = 40;

      for (var i = 0; i < 40; i++) {
        await sincronizador.sincronizar();
        ahora = ahora.add(const Duration(minutes: 10));
      }

      final estado = await bandeja.estadoDe(registro.id);

      expect(estado!.estado, EstadoDeEnvio.pendiente);
      expect(estado.intentos, 40);
      expect(
        EstadoDeEnvio.values.map((e) => e.name),
        isNot(contains('fallido')),
        reason:
            'Un estado terminal de fallo sería la forma en que los datos '
            'se pierden en silencio (FR-019)',
      );
    });

    test('la espera entre reintentos tiene techo', () {
      // **El techo bajó de cinco minutos a uno** en la feature 011 (D2). La
      // razón de aquel techo sigue valiendo —no machacar el teléfono de
      // alguien que está nadando— y un intento por minuto la respeta. Lo que
      // cambió es que ahora hay algo que reintenta solo: con cinco minutos,
      // el registro se quedaría hasta cinco minutos sin salir **después** de
      // que volviera la red.
      const muchos = EnvioPendiente(registroId: 'r', intentos: 30);
      expect(muchos.esperaHastaElSiguiente, const Duration(minutes: 1));
    });
  });

  group('la hora del servidor vuelve al registro', () {
    test('para poder detectar un reloj desajustado', () async {
      final registro = unRegistro();
      await sincronizador.guardar(registro);

      envio.horaDelServidor = ahora.add(const Duration(hours: 3));
      await sincronizador.sincronizar();

      final guardado = await registros.obtener(registro.id);

      expect(guardado!.recibidoEn, isNotNull);
      expect(guardado.desfaseDeReloj, const Duration(hours: 3));
    });
  });

  group('el texto del aviso es el que exige FR-017', () {
    test('literal, porque es una regla de producto', () {
      expect(
        avisoProgresoGuardado,
        'Guardado el progreso, se enviará cuando tengas acceso a internet',
      );
    });
  });
}

// ---------------------------------------------------------------------------
// Dobles de prueba. Todo en memoria: sin red, sin emulador, sin Firebase.
// ---------------------------------------------------------------------------

class _RegistrosEnMemoria implements RepositorioRegistros {
  @override
  Future<Set<String>> nadadoresConRegistros() async =>
      guardados.values.map((r) => r.nadadorId).toSet();

  final Map<String, RegistroDeSesion> guardados = {};
  bool fallaAlGuardar = false;

  @override
  Future<RegistroDeSesion?> obtener(String registroId) async =>
      guardados[registroId];

  @override
  Future<List<RegistroDeSesion>> obtenerDePlan(
    String nadadorId,
    String planId,
  ) async => guardados.values
      .where((r) => r.nadadorId == nadadorId && r.planId == planId)
      .toList();

  @override
  Future<void> guardar(RegistroDeSesion registro) async {
    if (fallaAlGuardar) {
      throw Exception('el dispositivo rechazó la escritura');
    }
    guardados[registro.id] = registro;
  }

  @override
  Future<Map<String, dynamic>> exportar(String nadadorId) async => {};

  @override
  Future<void> eliminarDe(String nadadorId) async =>
      guardados.removeWhere((_, r) => r.nadadorId == nadadorId);
}

class _BandejaEnMemoria implements BandejaDeSalida {
  final Map<String, EnvioPendiente> _envios = {};

  @override
  Future<void> encolar(String registroId) async {
    _envios[registroId] = EnvioPendiente(registroId: registroId);
  }

  @override
  Future<List<EnvioPendiente>> pendientes() async =>
      _envios.values.where((e) => e.esperaEnvio).toList();

  @override
  Future<EnvioPendiente?> estadoDe(String registroId) async =>
      _envios[registroId];

  @override
  Future<void> actualizar(EnvioPendiente envio) async {
    _envios[envio.registroId] = envio;
  }
}

class _RedSimulada implements EstadoDeRed {
  _RedSimulada({required bool hayConexion}) : hayConexionAhora = hayConexion;

  bool hayConexionAhora;
  int vecesConsultada = 0;

  final StreamController<bool> _controlador =
      StreamController<bool>.broadcast();

  void emitir(bool hayConexion) => _controlador.add(hayConexion);

  @override
  Future<bool> hayConexion() async {
    vecesConsultada++;
    return hayConexionAhora;
  }

  @override
  Stream<bool> get cambios => _controlador.stream;

  /// Lo que la bandeja anota de cada intento. No esta en la interfaz del
  /// dominio: la bandeja lo recibe como un `alIntentar` (feature 011, D1).
  final anotados = <bool>[];

  void anotarIntento({required bool llego}) => anotados.add(llego);
}

class _EnvioSimulado implements EnvioDeRegistros {
  final List<RegistroDeSesion> enviados = [];
  final Map<String, RegistroDeSesion> destino = {};

  int fallaLasProximas = 0;
  Set<String> fallaPara = {};
  int intentosDeEnvio = 0;
  DateTime? horaDelServidor;

  @override
  Future<DateTime> enviar(RegistroDeSesion registro) async {
    intentosDeEnvio++;

    if (fallaLasProximas > 0) {
      fallaLasProximas--;
      throw Exception('sin conexión con el servidor');
    }

    if (fallaPara.contains(registro.id)) {
      throw Exception('rechazado');
    }

    enviados.add(registro);
    destino[registro.id] = registro;
    return horaDelServidor ?? DateTime(2026, 10, 14, 7, 30);
  }
}
