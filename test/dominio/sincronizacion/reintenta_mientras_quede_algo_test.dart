/// Mientras quede algo por enviar, **se vuelve a intentar sola** (FR-001).
///
/// Es la promesa que la feature 003 escribió y nunca cumplió. Su contrato
/// nombra tres disparadores —al guardar, al volver la red y al abrir la app— y
/// el segundo no se cableó nunca: `alVolverLaRed` existía, estaba probado, y
/// nadie en `lib/` lo escuchaba. Y no habría disparado igualmente, porque el
/// sondeo detrás preguntaba «¿se inicializó Firestore?», cierto con el avión
/// puesto y para siempre.
///
/// Lo que lo sustituye entrega lo mismo: **ella no toca nada y lo suyo sale**.
/// Lo que cambia es que la app lo descubre intentando, en vez de esperar a que
/// alguien le avise (decisión D1).
///
/// Y el techo de la espera baja de cinco minutos a uno (D2): con cinco, un
/// registro que ya falló unas cuantas veces se quedaría esperando hasta cinco
/// minutos **después** de que volviera la red, con todo el mecanismo puesto y
/// la promesa igual de rota.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:natacion_app/dominio/entidades/envio_pendiente.dart';
import 'package:natacion_app/dominio/sincronizacion/bandeja_salida.dart';

import 'dobles_de_sincronizacion.dart';

void main() {
  late BandejaDeMentira bandeja;
  late TransporteMudo transporte;
  late RelojDeMentira reloj;
  late Sincronizador sincronizador;

  setUp(() {
    bandeja = BandejaDeMentira();
    transporte = TransporteMudo()..lanza = true; // falla rápido y vuelve
    reloj = RelojDeMentira();
    sincronizador = Sincronizador(
      registros: RegistrosDeMentiraLocales(),
      bandeja: bandeja,
      red: RedDeMentira(),
      transporte: transporte,
      reloj: () => reloj.ahora,
      despertador: reloj,
    );
  });

  test('guardar deja programado el siguiente intento', () async {
    await sincronizador.guardar(unRegistro());

    expect(
      reloj.hayAlgoProgramado,
      isTrue,
      reason: 'hay algo esperando: la app tiene que volver a mirarlo sola',
    );
  });

  test('se reintenta sin que nadie llame a sincronizar', () async {
    await sincronizador.guardar(unRegistro());
    final trasGuardar = transporte.intentos;

    await reloj.avanzar(const Duration(minutes: 10));

    expect(
      transporte.intentos,
      greaterThan(trasGuardar),
      reason:
          'esto es la garantía entera: una nadadora que anota, guarda el '
          'teléfono y no vuelve a abrir la app hasta mañana',
    );
  });

  test('la espera crece: 1, 2, 4, 8…', () {
    Duration tras(int intentos) =>
        EnvioPendiente(registroId: 'r', intentos: intentos)
            .esperaHastaElSiguiente;

    expect(tras(1), const Duration(seconds: 1));
    expect(tras(2), const Duration(seconds: 2));
    expect(tras(3), const Duration(seconds: 4));
    expect(tras(4), const Duration(seconds: 8));
  });

  test('y se detiene en un minuto, no en cinco', () {
    Duration tras(int intentos) =>
        EnvioPendiente(registroId: 'r', intentos: intentos)
            .esperaHastaElSiguiente;

    expect(tras(10), const Duration(seconds: 60));
    expect(
      tras(50),
      const Duration(seconds: 60),
      reason:
          'con el techo en cinco minutos, SC-001 falla con todo el mecanismo '
          'puesto: el registro espera su turno después de que vuelva la red',
    );
  });

  test('y no se desborda por muchos intentos que lleve', () {
    Duration tras(int intentos) =>
        EnvioPendiente(registroId: 'r', intentos: intentos)
            .esperaHastaElSiguiente;

    // **Esto no es defensa preventiva: pasó.** `1 << 64` vuelve a cero, así
    // que la espera se hacía cero y la bandeja entraba en bucle apretado. Lo
    // destapó esta feature al dejar que algo reintentara solo durante una
    // hora simulada; antes nadie llegaba a estos números porque nadie
    // reintentaba sin que la nadadora abriera la app.
    for (final intentos in [63, 64, 65, 100, 1000]) {
      expect(
        tras(intentos),
        const Duration(seconds: 60),
        reason:
            'con $intentos intentos la espera salió '
            '${tras(intentos).inSeconds} s. Cero segundos es el bucle '
            'apretado que esta clase existe para evitar',
      );
    }
  });

  test('un minuto basta para que salga cuando el servidor vuelve', () async {
    await sincronizador.guardar(unRegistro());

    // Que falle lo suficiente para llegar al techo.
    await reloj.avanzar(const Duration(minutes: 30));
    expect(await sincronizador.hayPendientes(), isTrue);

    transporte
      ..lanza = false
      ..contesta = true;

    await reloj.avanzar(const Duration(seconds: 60));

    expect(
      await sincronizador.hayPendientes(),
      isFalse,
      reason: 'SC-001: dentro del minuto desde que el servidor contesta',
    );
  });

  test('no es un bucle apretado', () async {
    await sincronizador.guardar(unRegistro());
    await reloj.avanzar(const Duration(hours: 1));

    expect(
      transporte.intentos,
      lessThanOrEqualTo(66),
      reason:
          'seis rápidos mientras la espera crece y luego uno por minuto. El '
          'techo de un minuto es lo que separa «reintentar» de «machacar el '
          'teléfono de alguien que está nadando»',
    );
  });
}
