import 'package:flutter_test/flutter_test.dart';
import 'package:natacion_app/dominio/consentimiento/puerta.dart';
import 'package:natacion_app/dominio/entidades/envio_pendiente.dart';
import 'package:natacion_app/dominio/entidades/registro_sesion.dart';
import 'package:natacion_app/dominio/repositorios/repositorios.dart';
import 'package:natacion_app/dominio/sincronizacion/bandeja_salida.dart';

/// Garantías P3 y P4 — la retención por falta de consentimiento.
///
/// Es la pieza que hace que el principio V se cumpla **sin bloquear a nadie**.
/// El nadador escribe, lo escrito se guarda, y lo que espera es la salida.
///
/// Todo en Dart puro, con dobles del reloj, de la red y de la puerta. Lo que
/// se prueba aquí es la decisión, no Firestore.
void main() {
  final cuando = DateTime(2026, 10, 15, 7, 30);

  RegistroDeSesion registro({
    String nadadorId = 'n1',
    String sesionId = 's1',
  }) => RegistroDeSesion(
    nadadorId: nadadorId,
    planId: 'p1',
    sesionId: sesionId,
    versionDePlan: '3.6.0',
    realizada: true,
    registradoEn: cuando,
    rpePercibido: 7,
  );

  group('P2 — guardar nunca depende de la puerta', () {
    test('con la puerta cerrada, lo escrito se guarda igual', () async {
      final taller = _Taller(puertaAbierta: false);

      await taller.sincronizador.guardar(registro());

      expect(
        await taller.registros.obtener(registro().id),
        isNotNull,
        reason:
            'Garantía G1: escribir no consulta la red ni la puerta. Lo '
            'que el nadador anota se guarda pase lo que pase',
      );
      expect(await taller.bandeja.pendientes(), hasLength(1));
    });
  });

  group('P1 — con la puerta cerrada no sale nada', () {
    test('el registro no llega al destino', () async {
      final taller = _Taller(puertaAbierta: false);
      await taller.sincronizador.guardar(registro());

      await taller.sincronizador.sincronizar();

      expect(taller.transporte.enviados, isEmpty);
    });

    test('y sigue pendiente, no se pierde', () async {
      final taller = _Taller(puertaAbierta: false);
      await taller.sincronizador.guardar(registro());

      final resultado = await taller.sincronizador.sincronizar();

      expect(resultado.enviados, isEmpty);
      expect(resultado.siguenPendientes, [registro().id]);
      expect(await taller.sincronizador.hayPendientes(), isTrue);
    });
  });

  group('P4 — esperar consentimiento no es fallar', () {
    test(
      'muchos ciclos con la puerta cerrada dejan los intentos en cero',
      () async {
        final taller = _Taller(puertaAbierta: false);
        await taller.sincronizador.guardar(registro());

        for (var i = 0; i < 25; i++) {
          await taller.sincronizador.sincronizar();
        }

        final enCola = await taller.bandeja.estadoDe(registro().id);
        expect(
          enCola!.intentos,
          0,
          reason:
              'Si contara como fallo, un consentimiento que tarda una semana '
              'dejaría el envío esperando cinco minutos entre intentos por una '
              'condición que todavía no se cumple, no por un error',
        );
      },
    );

    test('el estado sigue siendo pendiente, sin inventar uno nuevo', () async {
      // Decisión D6: no se añadió ningún estado a EstadoDeEnvio. Un registro
      // retenido **es** un registro pendiente.
      final taller = _Taller(puertaAbierta: false);
      await taller.sincronizador.guardar(registro());
      await taller.sincronizador.sincronizar();

      final enCola = await taller.bandeja.estadoDe(registro().id);
      expect(enCola!.estado, EstadoDeEnvio.pendiente);
      expect(EstadoDeEnvio.values, hasLength(3));
    });

    test(
      'no se marca como enviando, que sería mentir sobre lo que pasó',
      () async {
        final taller = _Taller(puertaAbierta: false);
        await taller.sincronizador.guardar(registro());
        await taller.sincronizador.sincronizar();

        final enCola = await taller.bandeja.estadoDe(registro().id);
        expect(enCola!.estado, isNot(EstadoDeEnvio.enviando));
      },
    );
  });

  group('P3 — otorgado el consentimiento, lo retenido sale solo', () {
    test('sin que el nadador repita nada', () async {
      final taller = _Taller(puertaAbierta: false);
      await taller.sincronizador.guardar(registro());
      await taller.sincronizador.sincronizar();
      expect(taller.transporte.enviados, isEmpty);

      // El acudiente consiente. Nadie toca el teléfono del nadador.
      taller.puerta.abierta = true;
      await taller.sincronizador.sincronizar();

      expect(taller.transporte.enviados, hasLength(1));
      expect(await taller.sincronizador.hayPendientes(), isFalse);
    });

    test('con su contenido intacto', () async {
      final taller = _Taller(puertaAbierta: false);
      await taller.sincronizador.guardar(registro());
      await taller.sincronizador.sincronizar();

      taller.puerta.abierta = true;
      await taller.sincronizador.sincronizar();

      final llegado = taller.transporte.enviados.single;
      expect(llegado.rpePercibido, 7);
      expect(llegado.registradoEn, cuando);
      expect(
        llegado.sesionId,
        's1',
        reason: 'Esperar no puede alterar lo que el nadador escribió',
      );
    });

    test('todo lo acumulado, no solo lo último', () async {
      final taller = _Taller(puertaAbierta: false);
      for (final s in ['s1', 's2', 's3']) {
        await taller.sincronizador.guardar(registro(sesionId: s));
      }
      await taller.sincronizador.sincronizar();

      taller.puerta.abierta = true;
      await taller.sincronizador.sincronizar();

      expect(taller.transporte.enviados, hasLength(3));
    });
  });

  group('P6 — revocado, deja de salir', () {
    test('lo que se escriba después se queda', () async {
      final taller = _Taller(puertaAbierta: true);
      await taller.sincronizador.guardar(registro(sesionId: 's1'));
      await taller.sincronizador.sincronizar();
      expect(taller.transporte.enviados, hasLength(1));

      taller.puerta.abierta = false;
      await taller.sincronizador.guardar(registro(sesionId: 's2'));
      await taller.sincronizador.sincronizar();

      expect(taller.transporte.enviados, hasLength(1));
      expect(await taller.sincronizador.hayPendientes(), isTrue);
    });
  });

  group('la puerta se consulta por nadador', () {
    test('un nadador con consentimiento no desbloquea a otro sin él', () async {
      final taller = _Taller(puertaAbierta: false)..puerta.permitidos = {'n1'};

      await taller.sincronizador.guardar(registro(nadadorId: 'n1'));
      await taller.sincronizador.guardar(registro(nadadorId: 'n2'));
      await taller.sincronizador.sincronizar();

      expect(taller.transporte.enviados.map((r) => r.nadadorId), ['n1']);
    });
  });

  group('la puerta se consulta antes de cada intento', () {
    // **Esta prueba decía otra cosa hasta la feature 011.** Decía «sin red, la
    // puerta ni se consulta», y fijaba un atajo: había una puerta de red
    // delante de todo, y sin red no se llegaba ni a preguntar por el
    // consentimiento.
    //
    // Esa puerta de red se quitó (feature 011, D1): con el intento como
    // sondeo, preguntar antes es lo que impedía enterarse. Y entonces lo que
    // hay que fijar aquí es lo contrario, y es más importante: **ahora que se
    // intenta siempre, el consentimiento se comprueba siempre**, antes de
    // cada salida, y no se cuela un dato de una menor por el hueco que dejó
    // un atajo de conectividad (principio V).
    test('aunque no haya red, el consentimiento se comprueba igual', () async {
      final taller = _Taller(puertaAbierta: true, hayRed: false);
      await taller.sincronizador.guardar(registro());

      await taller.sincronizador.sincronizar();

      expect(
        taller.puerta.consultas,
        greaterThan(0),
        reason:
            'lo que sale del teléfono pasa por la puerta, haya red o no la '
            'haya. El atajo de antes dependía de una puerta de red que ya no '
            'existe, y un atajo delante del consentimiento es el peor sitio '
            'posible para un atajo',
      );
    });

    test('y si está cerrada, no sale nada', () async {
      final taller = _Taller(puertaAbierta: false, hayRed: false);
      await taller.sincronizador.guardar(registro());

      await taller.sincronizador.sincronizar();

      expect(taller.transporte.enviados, isEmpty);
    });
  });
}

/// Todo lo que hace falta para mover un registro, con dobles.
class _Taller {
  _Taller({required bool puertaAbierta, bool hayRed = true})
    : puerta = _PuertaFalsa(puertaAbierta),
      red = _RedFalsa(hayRed) {
    sincronizador = Sincronizador(
      registros: registros,
      bandeja: bandeja,
      red: red,
      transporte: transporte,
      puerta: puerta,
      reloj: () => DateTime(2026, 10, 15, 8),
    );
  }

  final registros = _RegistrosEnMemoria();
  final bandeja = _BandejaEnMemoria();
  final transporte = _TransporteQueAnota();
  final _PuertaFalsa puerta;
  final _RedFalsa red;

  late final Sincronizador sincronizador;
}

class _PuertaFalsa implements PuertaDeConsentimiento {
  _PuertaFalsa(this.abierta);

  bool abierta;

  /// Si se fija, solo estos nadadores pasan, sin mirar [abierta].
  Set<String>? permitidos;

  int consultas = 0;

  @override
  Future<bool> puedeSalir(String nadadorId) async {
    consultas++;
    final lista = permitidos;
    if (lista != null) return lista.contains(nadadorId);
    return abierta;
  }
}

class _RedFalsa implements EstadoDeRed {
  _RedFalsa(this.hay);

  final bool hay;

  @override
  Future<bool> hayConexion() async => hay;

  @override
  Stream<bool> get cambios => const Stream<bool>.empty();
}

class _TransporteQueAnota implements EnvioDeRegistros {
  final enviados = <RegistroDeSesion>[];

  @override
  Future<DateTime> enviar(RegistroDeSesion registro) async {
    enviados.add(registro);
    return DateTime(2026, 10, 15, 8, 1);
  }
}

class _RegistrosEnMemoria implements RepositorioRegistros {
  @override
  Future<Set<String>> nadadoresConRegistros() async =>
      _guardados.values.map((r) => r.nadadorId).toSet();

  final _guardados = <String, RegistroDeSesion>{};

  @override
  Future<RegistroDeSesion?> obtener(String registroId) async =>
      _guardados[registroId];

  @override
  Future<List<RegistroDeSesion>> obtenerDePlan(
    String nadadorId,
    String planId,
  ) async => _guardados.values
      .where((r) => r.nadadorId == nadadorId && r.planId == planId)
      .toList();

  @override
  Future<void> guardar(RegistroDeSesion registro) async {
    _guardados[registro.id] = registro;
  }

  @override
  Future<Map<String, dynamic>> exportar(String nadadorId) async => {};

  @override
  Future<void> eliminarDe(String nadadorId) async {
    _guardados.removeWhere((_, r) => r.nadadorId == nadadorId);
  }
}

class _BandejaEnMemoria implements BandejaDeSalida {
  final _cola = <String, EnvioPendiente>{};

  @override
  Future<void> encolar(String registroId) async {
    _cola[registroId] = EnvioPendiente(registroId: registroId);
  }

  @override
  Future<List<EnvioPendiente>> pendientes() async =>
      _cola.values.where((e) => e.esperaEnvio).toList();

  @override
  Future<EnvioPendiente?> estadoDe(String registroId) async =>
      _cola[registroId];

  @override
  Future<void> actualizar(EnvioPendiente envio) async {
    _cola[envio.registroId] = envio;
  }
}
