/// Un envío que llega **suelta al resto de la cola** (FR-005).
///
/// La espera creciente protege a un servidor que no contesta. En el momento en
/// que uno de los envíos llega, eso es la prueba de que sí contesta, así que la
/// protección no tiene ya nada que proteger: lo demás se intenta ya.
///
/// **Y por qué para un registro solo no hay nada que acortar.** Con el intento
/// como sondeo (decisión D1), un registro único no tiene un «volvió la red»
/// separado al que reaccionar: su propio siguiente intento *es* el
/// descubrimiento, y el techo de un minuto es lo que lo mantiene dentro de
/// SC-001. El acorte es **entre** registros.
///
/// Sin esto, una nadadora que anotó cinco sesiones sin señal las ve salir a
/// goteo, una espera larga cada una, con todo el mecanismo puesto.
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
    transporte = TransporteMudo()..lanza = true;
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

  test('cuando uno llega, los demás se intentan ya', () async {
    await sincronizador.guardar(unRegistro(sesionId: 's1'));
    await sincronizador.guardar(unRegistro(sesionId: 's2'));
    await sincronizador.guardar(unRegistro(sesionId: 's3'));

    // Que todos lleguen al techo de la espera.
    await reloj.avanzar(const Duration(minutes: 30));
    expect(await sincronizador.hayPendientes(), isTrue);

    transporte
      ..lanza = false
      ..contesta = true;

    // Un solo despertar: en él, el primero llega y eso tiene que soltar a los
    // otros dos **en la misma pasada o en la inmediata**, no en los minutos
    // siguientes uno a uno.
    await reloj.avanzar(const Duration(seconds: 61));

    expect(
      await sincronizador.hayPendientes(),
      isFalse,
      reason:
          'cinco sesiones anotadas sin señal no pueden salir a goteo cuando '
          'ya está demostrado que el servidor contesta',
    );
  });

  test('un registro solo no necesita que nadie lo suelte', () async {
    // El control de la de arriba: aquí no hay nada que acortar, y aun así
    // tiene que salir dentro del minuto.
    await sincronizador.guardar(unRegistro(sesionId: 'solo'));
    await reloj.avanzar(const Duration(minutes: 30));

    transporte
      ..lanza = false
      ..contesta = true;
    await reloj.avanzar(const Duration(seconds: 61));

    expect(await sincronizador.hayPendientes(), isFalse);
  });

  test('soltar la cola no salta la puerta ni descarta nada', () async {
    await sincronizador.guardar(unRegistro(sesionId: 's1'));
    await sincronizador.guardar(unRegistro(sesionId: 's2'));
    await reloj.avanzar(const Duration(minutes: 30));

    // Solo uno va a poder salir: el otro sigue fallando.
    transporte.lanza = false;
    transporte.contesta = true;

    await reloj.avanzar(const Duration(seconds: 61));

    // G3: lo que no salió sigue pendiente y con su cuenta, nunca descartado.
    for (final envio in bandeja.envios.values) {
      expect(
        envio.estado == EstadoDeEnvio.enviado || envio.esperaEnvio,
        isTrue,
        reason: 'o llegó, o sigue esperando. Descartado, nunca',
      );
    }
  });
}
