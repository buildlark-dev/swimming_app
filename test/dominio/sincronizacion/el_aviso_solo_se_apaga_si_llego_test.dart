/// El aviso se apaga **porque llegó**, nunca porque dejáramos de mirar
/// (FR-016).
///
/// La frase que ella ve —«Guardado el progreso, se enviará cuando tengas
/// acceso a internet»— es una promesa, y una promesa que se retira sola no es
/// una promesa. Mientras el servidor no tenga su registro, la frase se queda.
///
/// Es la otra mitad de `el_exito_tardio_cuenta_test.dart`. Aquella fija que el
/// aviso **sí** se apaga cuando la escritura acaba llegando; esta, que no se
/// apaga por ninguna otra razón: ni porque se agotara el plazo, ni porque
/// lleve muchos intentos, ni porque pasara el tiempo.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:natacion_app/dominio/sincronizacion/bandeja_salida.dart';

import 'dobles_de_sincronizacion.dart';

void main() {
  late TransporteMudo transporte;
  late RelojDeMentira reloj;
  late Sincronizador sincronizador;

  setUp(() {
    transporte = TransporteMudo();
    reloj = RelojDeMentira();
    sincronizador = Sincronizador(
      registros: RegistrosDeMentiraLocales(),
      bandeja: BandejaDeMentira(),
      red: RedDeMentira(),
      transporte: transporte,
      reloj: () => reloj.ahora,
      despertador: reloj,
      esperaAlEnvio: const Duration(milliseconds: 20),
    );
  });

  test('un plazo vencido no apaga el aviso', () async {
    await sincronizador.guardar(unRegistro());
    await sincronizador.sincronizar();

    expect(
      await sincronizador.hayPendientes(),
      isTrue,
      reason: 'dejar de esperar no es haber llegado',
    );
  });

  test('ni muchos intentos, ni mucho tiempo', () async {
    await sincronizador.guardar(unRegistro());
    await reloj.avanzar(const Duration(hours: 6));

    expect(
      await sincronizador.hayPendientes(),
      isTrue,
      reason:
          'garantía G3: nunca se descarta. Seis horas sin señal son seis '
          'horas sin señal, no una razón para dar algo por enviado',
    );
  });

  test('un fallo tardío tampoco lo apaga', () async {
    await sincronizador.guardar(unRegistro());
    await sincronizador.sincronizar();

    transporte.fallaLoQueQuedoColgado();
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    expect(await sincronizador.hayPendientes(), isTrue);
  });

  test('y se apaga en cuanto llega de verdad', () async {
    // El control de las tres de arriba: si esto no pasara, estarían
    // comprobando una bandeja que no vacía nunca.
    await sincronizador.guardar(unRegistro());
    transporte.contesta = true;
    await reloj.avanzar(const Duration(minutes: 2));

    expect(await sincronizador.hayPendientes(), isFalse);
  });
}
