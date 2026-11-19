/// Un envío que llega **tarde** sigue siendo un envío que llegó (FR-015).
///
/// El cuarto defecto del recorrido, y el único que no es culpa de nadie: la
/// cola interna del SDK de Firestore entrega la escritura que nuestro plazo
/// dejó de esperar. Entonces el servidor tiene el registro mientras la bandeja
/// lo sigue contando pendiente, y la frase «se enviará cuando tengas acceso a
/// internet» se queda en su pantalla después de dejar de ser cierta.
///
/// La respuesta llega gratis: `Future.timeout` no cancela lo que envuelve,
/// solo deja de esperarlo *aquí*. Basta con escucharla (decisión D3).
///
/// Y lo que **no** se hace: preguntarle al servidor si ya lo tiene. Eso cuesta
/// una lectura por registro y por ciclo, y sin conexión esa lectura se contesta
/// desde la caché, que diría que sí de algo que nunca salió del teléfono.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:natacion_app/dominio/entidades/envio_pendiente.dart';
import 'package:natacion_app/dominio/sincronizacion/bandeja_salida.dart';

import 'dobles_de_sincronizacion.dart';

void main() {
  late BandejaDeMentira bandeja;
  late RegistrosDeMentiraLocales registros;
  late TransporteMudo transporte;
  late RelojDeMentira reloj;
  late Sincronizador sincronizador;

  setUp(() {
    bandeja = BandejaDeMentira();
    registros = RegistrosDeMentiraLocales();
    // Acepta y no contesta: el SDK sin red, tal cual.
    transporte = TransporteMudo();
    reloj = RelojDeMentira();
    sincronizador = Sincronizador(
      registros: registros,
      bandeja: bandeja,
      red: RedDeMentira(),
      transporte: transporte,
      reloj: () => reloj.ahora,
      despertador: reloj,
      esperaAlEnvio: const Duration(milliseconds: 20),
    );
  });

  test('lo que llega después del plazo deja el registro enviado', () async {
    final registro = unRegistro();
    await sincronizador.guardar(registro);
    await sincronizador.sincronizar();

    // El plazo venció: para la bandeja, no llegó.
    expect(await sincronizador.hayPendientes(), isTrue);
    expect((await bandeja.estadoDe(registro.id))!.intentos, greaterThan(0));

    // Y entonces la escritura aterriza sola, como hace la cola del SDK
    // cuando vuelve la señal.
    transporte.contestaLoQueQuedoColgado();
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    expect(
      await sincronizador.hayPendientes(),
      isFalse,
      reason:
          'el servidor lo tiene: dejarlo contado como pendiente es dejarle a '
          'ella una frase en pantalla que ya no es verdad',
    );
    expect(
      (await bandeja.estadoDe(registro.id))!.estado,
      EstadoDeEnvio.enviado,
    );
  });

  test('y la hora del servidor vuelve al registro', () async {
    final registro = unRegistro();
    transporte.horaDelServidor = DateTime(2026, 11, 18, 19, 30);

    await sincronizador.guardar(registro);
    await sincronizador.sincronizar();
    transporte.contestaLoQueQuedoColgado();
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    expect(
      (await registros.obtener(registro.id))!.recibidoEn,
      DateTime(2026, 11, 18, 19, 30),
      reason:
          'es lo que permite detectar un reloj desajustado (decisión D3 de la '
          'feature 003), y llegar tarde no lo hace menos cierto',
    );
  });

  test('no se le pregunta nada a nadie para enterarse', () async {
    await sincronizador.guardar(unRegistro());
    await sincronizador.sincronizar();

    final intentosAntes = transporte.intentos;
    transporte.contestaLoQueQuedoColgado();
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    expect(
      transporte.intentos,
      intentosAntes,
      reason:
          'preguntar costaría una lectura por registro y por ciclo, y sin '
          'conexión la contestaría la caché: diría que sí de algo que nunca '
          'salió del teléfono',
    );
  });

  test('un fallo que llega tarde no tumba nada', () async {
    // Lo contrario del éxito tardío, y tiene que ser inofensivo: una
    // excepción que aterriza cuando ya no la espera nadie no puede acabar en
    // la app cayéndose en una esquina de la calle.
    await sincronizador.guardar(unRegistro());
    await sincronizador.sincronizar();

    transporte.fallaLoQueQuedoColgado();
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    expect(await sincronizador.hayPendientes(), isTrue);
  });
}
