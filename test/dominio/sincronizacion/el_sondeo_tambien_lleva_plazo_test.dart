/// El despertar **no reintroduce una espera sin fin** (FR-004).
///
/// La feature 010 le puso plazo al envío, y es lo que hizo posible todo lo
/// demás: antes, un intento que no volvía no era una respuesta. Esta feature
/// añade un despertar que vuelve a intentarlo solo, y la pregunta que hay que
/// cerrar es si eso deshace aquello.
///
/// Lo que se comprueba aquí no es el plazo —eso ya lo fija
/// `enviar_no_espera_para_siempre_test.dart`, de la feature 010— sino que
/// **el despertar convive con él**: contra un transporte que acepta y no
/// contesta nunca, los intentos no se apilan, nada queda colgado para siempre,
/// y la bandeja sigue contando lo suyo.
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
    // Acepta y no contesta: lo que de verdad hace el SDK sin red.
    transporte = TransporteMudo();
    reloj = RelojDeMentira();
    sincronizador = Sincronizador(
      registros: RegistrosDeMentiraLocales(),
      bandeja: bandeja,
      red: RedDeMentira(),
      transporte: transporte,
      reloj: () => reloj.ahora,
      despertador: reloj,
      // **Corto, y en tiempo de verdad.** `Future.timeout` no sabe del reloj
      // simulado: con el plazo de produccion, cada intento contra un
      // transporte mudo pararia la suite diez segundos reales.
      esperaAlEnvio: const Duration(milliseconds: 20),
    );
  });

  test('con un transporte mudo, avanzar el reloj no cuelga nada', () async {
    await sincronizador.guardar(unRegistro());

    // **El cerrojo**: sin plazo, esto no vuelve nunca y la suite se para.
    await reloj.avanzar(const Duration(minutes: 5)).timeout(
      const Duration(seconds: 5),
      onTimeout: () => fail(
        'algo esperó al servidor sin fin: el despertar deshizo el plazo que '
        'la feature 010 puso, y volvemos al botón girando para siempre',
      ),
    );

    expect(await sincronizador.hayPendientes(), isTrue);
  });

  test('el despertar no convierte el plazo en un bucle apretado', () async {
    await sincronizador.guardar(unRegistro());
    await reloj.avanzar(const Duration(minutes: 5));

    // En cinco minutos la espera crece 1, 2, 4, 8, 16, 32 y luego va de minuto
    // en minuto: unos diez intentos. Si el plazo corto y el despertar se
    // retroalimentaran, aquí habría cientos.
    expect(
      transporte.intentos,
      lessThan(15),
      reason:
          'el plazo del envío no puede volverse la cadencia del reintento: '
          'eso sería machacar el teléfono de alguien que está nadando',
    );

    // **Y los colgados sí se acumulan, a propósito.** Es la decisión D3: un
    // intento vencido no se abandona, porque la escritura sigue en la cola
    // del SDK y puede aterrizar sola. Cada uno espera por si acaso, y el día
    // que llegue, el aviso se apaga **porque llegó**.
    expect(
      transporte.colgados,
      transporte.intentos,
      reason: 'ninguno se tira: cualquiera puede ser el que acabe llegando',
    );
  });

  test('un intento vencido cuenta como fallido, nunca como enviado', () async {
    final registro = unRegistro();
    await sincronizador.guardar(registro);
    await reloj.avanzar(const Duration(seconds: 30));

    final envio = await bandeja.estadoDe(registro.id);
    expect(envio, isNotNull);
    expect(
      envio!.estado,
      isNot(EstadoDeEnvio.enviado),
      reason: 'no contestar no es haber llegado',
    );
    expect(envio.intentos, greaterThan(0), reason: 'garantía G3: se cuenta');
  });
}
