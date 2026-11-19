/// Lo que cuesta volver a intentarlo, **en un número** (SC-004).
///
/// El criterio de éxito no pide que sea barato: pide que esté escrito. Un coste
/// que nadie midió es el que crece sin que nadie se entere, y esto corre sobre
/// el teléfono de alguien que está nadando.
///
/// La cifra: con un registro en la bandeja y sin red, **60 intentos por hora**
/// como mucho en régimen estable. Cero lecturas. Cero operaciones facturables,
/// porque un intento que no llega no es una operación que nadie cobre. Con la
/// bandeja vacía, cero de todo.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:natacion_app/dominio/sincronizacion/bandeja_salida.dart';

import 'dobles_de_sincronizacion.dart';

void main() {
  late TransporteMudo transporte;
  late RelojDeMentira reloj;
  late RegistrosDeMentiraLocales registros;
  late Sincronizador sincronizador;

  setUp(() {
    transporte = TransporteMudo()..lanza = true;
    reloj = RelojDeMentira();
    registros = RegistrosDeMentiraLocales();
    sincronizador = Sincronizador(
      registros: registros,
      bandeja: BandejaDeMentira(),
      red: RedDeMentira(),
      transporte: transporte,
      reloj: () => reloj.ahora,
      despertador: reloj,
    );
  });

  test('un registro y sin red: 66 intentos en la primera hora', () async {
    await sincronizador.guardar(unRegistro());
    await reloj.avanzar(const Duration(hours: 1));

    // **La cuenta, hecha y no redondeada.** La espera crece 1, 2, 4, 8, 16 y
    // 32 segundos —63 segundos y seis intentos— y a partir de ahí va uno por
    // minuto. En una hora: 6 + (3600-63)/60 ≈ 65.
    //
    // El régimen estable es 60 por hora, que es la cifra que SC-004 pide
    // escrita; la primera hora lleva encima la rampa inicial, que es la que
    // hace que un registro salga en segundos cuando solo fue un bache.
    expect(
      transporte.intentos,
      lessThanOrEqualTo(66),
      reason: 'seis rápidos mientras la espera crece, y luego uno por minuto',
    );
    expect(
      transporte.intentos,
      greaterThan(50),
      reason:
          'y no menos: si fueran cuatro, es que dejó de intentarlo y la '
          'promesa está rota por el otro lado',
    );
  });

  test('la bandeja vacía no cuesta nada', () async {
    await sincronizador.sincronizar();
    await reloj.avanzar(const Duration(hours: 1));

    expect(transporte.intentos, 0);
    expect(reloj.programaciones, 0);
  });

  test('no se lee nada para averiguar si hay red', () async {
    await sincronizador.guardar(unRegistro());
    await reloj.avanzar(const Duration(hours: 1));

    // El transporte solo sabe enviar. Que el coste de una hora sean envíos y
    // nada más es lo que dice que no hay un sondeo aparte: **el intento es el
    // sondeo** (decisión D1).
    expect(
      transporte.pedidos.length,
      transporte.intentos,
      reason: 'todo lo que se le pidió fue enviar; no hay sondeo aparte',
    );
    expect(
      registros.guardados.length,
      1,
      reason: 'ni se reescribe el registro una vez por intento',
    );
  });
}
