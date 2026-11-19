/// Con la bandeja vacía **no se sondea nada** (FR-003).
///
/// El cerrojo más barato de la feature y el que más falta va a hacer, porque
/// todo cambio futuro va a querer añadir «solo un sondeo más».
///
/// La razón no es el dinero: un intento que no llega no lo cobra nadie. Es la
/// batería y el plan de datos de alguien que está nadando, y el principio de
/// que una app que no tiene nada que decir no habla.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:natacion_app/dominio/sincronizacion/bandeja_salida.dart';

import 'dobles_de_sincronizacion.dart';

void main() {
  late RegistrosDeMentiraLocales registros;
  late BandejaDeMentira bandeja;
  late TransporteMudo transporte;
  late RelojDeMentira reloj;
  late Sincronizador sincronizador;

  setUp(() {
    registros = RegistrosDeMentiraLocales();
    bandeja = BandejaDeMentira();
    transporte = TransporteMudo();
    reloj = RelojDeMentira();
    sincronizador = Sincronizador(
      registros: registros,
      bandeja: bandeja,
      red: RedDeMentira(),
      transporte: transporte,
      reloj: () => reloj.ahora,
      despertador: reloj,
      // **Corto, y en tiempo de verdad.** `Future.timeout` no sabe del reloj
      // simulado: si el plazo fuera el de producción, cada intento contra un
      // transporte mudo pararía la suite diez segundos reales.
      esperaAlEnvio: const Duration(milliseconds: 20),
    );
  });

  test('recién construido no hay nada programado', () {
    expect(reloj.hayAlgoProgramado, isFalse);
    expect(reloj.programaciones, 0);
  });

  test('sincronizar con la bandeja vacía no programa ni toca el transporte', () async {
    await sincronizador.sincronizar();

    expect(
      reloj.programaciones,
      0,
      reason:
          'no hay nada que enviar: programar un despertar sería gastarle la '
          'batería a alguien que está nadando para no averiguar nada',
    );
    expect(transporte.intentos, 0);
  });

  test('una hora entera con la bandeja vacía: cero de todo', () async {
    await sincronizador.sincronizar();
    await reloj.avanzar(const Duration(hours: 1));

    expect(reloj.programaciones, 0);
    expect(transporte.intentos, 0);
    expect(reloj.hayAlgoProgramado, isFalse);
  });

  test('cuando la bandeja se vacía, deja de haber despertares', () async {
    // Con algo pendiente sí se programa: es la otra mitad, y sin ella esta
    // prueba pasaría con una bandeja que no programa nunca.
    transporte.contesta = false;
    await sincronizador.guardar(unRegistro());
    await sincronizador.sincronizar();
    expect(
      reloj.hayAlgoProgramado,
      isTrue,
      reason: 'con algo pendiente sí se vuelve a mirar',
    );

    // Y cuando sale, se apaga.
    transporte.contesta = true;
    await reloj.avanzar(const Duration(minutes: 2));

    expect(await sincronizador.hayPendientes(), isFalse);
    expect(
      reloj.hayAlgoProgramado,
      isFalse,
      reason: 'la bandeja quedó vacía: no hay nada que volver a mirar',
    );
  });
}
