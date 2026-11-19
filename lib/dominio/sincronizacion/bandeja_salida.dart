/// La bandeja de salida: lo que sostiene la promesa de que nada se pierde.
///
/// Contrato: `specs/003-consumo-del-nadador/contracts/sincronizacion.md`.
///
/// > **Ningún dato escrito sin conexión se pierde en silencio.**
///
/// Está en Dart puro y **no sabe qué hay debajo**: ni Firestore, ni cómo se
/// detecta la red, ni dónde se guarda lo pendiente. Esa es la razón principal
/// por la que la escritura no se delegó en la cola interna de Firestore
/// (decisión D1): así las ocho garantías se prueban con la red y el reloj
/// simulados, sin emulador y sin probar Firebase.
library;

import 'dart:async';

import 'package:natacion_app/dominio/consentimiento/puerta.dart';
import 'package:natacion_app/dominio/entidades/envio_pendiente.dart';
import 'package:natacion_app/dominio/entidades/registro_sesion.dart';
import 'package:natacion_app/dominio/repositorios/repositorios.dart';
import 'package:natacion_app/dominio/sincronizacion/despertador.dart';

/// Resultado de intentar vaciar la bandeja.
class ResultadoDeSincronizacion {
  const ResultadoDeSincronizacion({
    this.enviados = const [],
    this.siguenPendientes = const [],
    this.sinRed = false,
  });

  final List<String> enviados;
  final List<String> siguenPendientes;

  /// Verdadero si ni se intentó porque no había conexión. **No es un error**:
  /// es el caso normal a pie de piscina.
  final bool sinRed;

  bool get todoEnviado => siguenPendientes.isEmpty && !sinRed;
}

class Sincronizador {
  Sincronizador({
    required this.registros,
    required this.bandeja,
    required this.red,
    required this.transporte,
    this.puerta = const PuertaAbierta(),
    this.esperaAlEnvio = loQueSeEsperaAlEnvio,
    DateTime Function()? reloj,
    Despertador? despertador,
    this.alIntentar,
  }) : // El reloj se inyecta para poder probar los reintentos sin esperar
       // minutos reales. Por omisión es el del sistema.
       _ahora = reloj ?? DateTime.now,
       // Y el despertar, por lo mismo (feature 011, D6). **Por omisión no
       // despierta**: el único sitio de producción lo pone a la vista, y una
       // prueba vigila que lo siga poniendo. Ver [DespertadorQuieto].
       _despertador = despertador ?? const DespertadorQuieto();

  /// Quién avisa de que toca volver a intentarlo. Ver [Despertador].
  final Despertador _despertador;

  /// A quién contarle cómo fue el intento, si a alguien le interesa.
  ///
  /// **La bandeja informa; quién escuche es asunto de quien la construye.**
  /// Con el intento como sondeo (feature 011, D1), lo que pasa aquí es la
  /// única noticia verdadera sobre la red, y `RedSegunElUltimoIntento` es
  /// quien la recoge en producción.
  ///
  /// Es un parámetro y no un método más de `EstadoDeRed` a propósito: once
  /// dobles de las pruebas implementan esa interfaz, y hacerles escribir un
  /// método que ignoran sería ruido en once archivos para no decir nada en
  /// ninguno. Y en Dart `implements` obliga a implementarlo aunque traiga
  /// cuerpo, así que no había forma de añadirlo sin tocarlos.
  final void Function({required bool llego})? alIntentar;

  final RepositorioRegistros registros;
  final BandejaDeSalida bandeja;
  final EstadoDeRed red;

  /// Quién lleva el registro a su destino. Se llama transporte y no «envío»
  /// para no confundirlo con `EnvioPendiente`, que es una entrada de la cola.
  final EnvioDeRegistros transporte;

  /// Si lo de este nadador puede salir del dispositivo (feature 004).
  ///
  /// **No se añadió ningún estado a `EstadoDeEnvio`** (decisión D6): un
  /// registro retenido por falta de consentimiento *es* un registro pendiente,
  /// y ya existía la forma de representarlo. Modelarlo como algo distinto
  /// duplicaría el mecanismo que ya funciona y ya está probado.
  final PuertaDeConsentimiento puerta;

  /// Lo que se le da al servidor para confirmar un envío antes de darlo por
  /// no llegado.
  ///
  /// **Un envío que no vuelve no es un envío que llegó.** Lo encontró el
  /// recorrido en el Pixel 7: con el avión puesto, el SDK de Firestore acepta
  /// la escritura en su cola local y deja el Future abierto, sin lanzar nada.
  /// `marcar como realizada` se quedaba girando para siempre.
  ///
  /// Y es, además, lo que `estado_de_red.dart` dice desde la feature 003 que
  /// tiene que ser la detección de red: «se intenta una escritura y se ve si
  /// llega». Hasta ahora no había forma de ver que no llegaba.
  ///
  /// Agotado el plazo se trata como fallo normal (garantía G3): vuelve a
  /// pendiente, con su contador, y se reintenta. El identificador del registro
  /// es determinista, así que si la escritura acababa llegando por su cuenta,
  /// el reintento la pisa con lo mismo.
  static const Duration loQueSeEsperaAlEnvio = Duration(seconds: 10);

  /// Lo que espera esta instancia. Las pruebas la acortan.
  final Duration esperaAlEnvio;

  final DateTime Function() _ahora;

  /// Guarda un registro y lo deja encolado.
  ///
  /// **Garantía G1**: escribe en local y encola. No consulta la red y no puede
  /// fallar por su causa. Devuelve con éxito tanto con red como sin ella.
  ///
  /// **Garantía S8**: un fallo al escribir *en local* sí se propaga, porque ahí
  /// el dato sí se perdería. Es la única forma de fallo que el nadador debe
  /// conocer.
  Future<void> guardar(RegistroDeSesion registro) async {
    await registros.guardar(registro);
    await bandeja.encolar(registro.id);

    // Y queda programado el siguiente intento. **Esto es el segundo
    // disparador del contrato**, el que nunca tuvo mecanismo: ella anota,
    // guarda el teléfono y no vuelve a abrir la app, y lo suyo sale igual.
    await _replantearElDespertar();
  }

  /// Deja programado el siguiente vistazo a la bandeja, o ninguno.
  ///
  /// **Con la bandeja vacía no se programa nada** (FR-003): no hay nada que
  /// averiguar, y un despertar que no averigua nada es batería de alguien que
  /// está nadando.
  ///
  /// Solo hay un despertar vivo, el del registro al que le toque antes.
  /// Acumularlos sería el bucle apretado que el contrato prohíbe.
  Future<void> _replantearElDespertar() async {
    if (_parado) return;

    final pendientes = await bandeja.pendientes();
    if (pendientes.isEmpty) {
      _despertador.cancelar();
      return;
    }

    final ahora = _ahora();
    var falta = const Duration(days: 1);
    for (final enCola in pendientes) {
      final ultimo = enCola.ultimoIntento;
      final cuando = ultimo == null
          ? ahora
          : ultimo.add(enCola.esperaHastaElSiguiente);
      final queda = cuando.isBefore(ahora)
          ? Duration.zero
          : cuando.difference(ahora);
      if (queda < falta) falta = queda;
    }

    _despertador.programar(falta, () async {
      await sincronizar();
    });
  }

  bool _parado = false;

  /// Deja de mirar la bandeja sola.
  ///
  /// Lo llama la pantalla del nadador al cerrarse. Un despertar que sobreviva
  /// al cierre de sesión seguiría moviendo la cola de una nadadora bajo la
  /// cuenta de su hermano, que es el escenario C7 de la feature 004.
  void parar() {
    _parado = true;
    _despertador.cancelar();
  }

  /// Vuelve a mirarla, después de un [parar].
  Future<void> empezar() async {
    _parado = false;
    await _replantearElDespertar();
  }

  /// Intenta enviar lo pendiente.
  ///
  /// Sin conexión devuelve `sinRed` y **no toca los contadores**: no haber
  /// podido intentarlo no es haber fallado, y contarlo como intento alargaría
  /// la espera del siguiente reintento sin motivo.
  /// Lo que hay en marcha ahora mismo, si hay algo.
  ///
  /// **Una a la vez, y no es cosmético.** El contrato tiene tres
  /// disparadores —al guardar, al volver la red y al abrir la app— y nada
  /// impedía que dos coincidieran. Dos sincronizaciones solapadas leen la
  /// bandeja antes de que ninguna llegue a marcar «enviando», así que las
  /// dos ven el mismo registro pendiente y las dos lo mandan.
  ///
  /// Con un identificador determinista el servidor no acaba con dos copias,
  /// así que no se perdía ni se duplicaba nada: lo que había era un envío de
  /// más por cada coincidencia, a costa del teléfono y de su plan de datos.
  /// Lo sacó a la luz quitar el `await` de `responder`, que es lo que hizo
  /// posible el solape de verdad.
  ///
  /// Quien llega segundo se engancha a la que ya va en lugar de abrir otra.
  Future<ResultadoDeSincronizacion>? _enMarcha;

  Future<ResultadoDeSincronizacion> sincronizar() =>
      _enMarcha ??= _vaciarLaBandeja().whenComplete(() => _enMarcha = null);

  Future<ResultadoDeSincronizacion> _vaciarLaBandeja() async {
    final pendientes = await bandeja.pendientes();
    if (pendientes.isEmpty) {
      _despertador.cancelar();
      return const ResultadoDeSincronizacion();
    }

    // **Aquí ya no se pregunta si hay red** (feature 011, D1).
    //
    // Había una puerta: `if (!await red.hayConexion()) return sinRed`. Con el
    // intento como sondeo esa puerta se cierra sobre sí misma — un fallo deja
    // la red en falso, la puerta bloquea el siguiente intento, y entonces
    // nunca vuelve a saberse nada—. Y una puerta delante de lo único que
    // puede contestar la pregunta es, literalmente, el defecto que esta
    // feature arregla.
    //
    // Lo que se pierde es la distinción «no se intentó porque no había red»,
    // que no era conocible por adelantado. `sinRed` sigue existiendo, pero
    // ahora es lo que se **supo** después: se intentó y no llegó nada.

    final enviados = <String>[];
    final siguenPendientes = <String>[];
    final seSaltaron = <EnvioPendiente>[];
    var alguienLlego = false;
    var alguienLoIntento = false;

    for (final enCola in pendientes) {
      // Los registros se envían de forma independiente (garantía G5): que uno
      // falle no detiene a los demás, y no hay transacción entre varios.
      if (!enCola.tocaReintentar(_ahora())) {
        seSaltaron.add(enCola);
        siguenPendientes.add(enCola.registroId);
        continue;
      }

      alguienLoIntento = true;
      final enviado = await _intentar(enCola);
      if (enviado) alguienLlego = true;
      (enviado ? enviados : siguenPendientes).add(enCola.registroId);
    }

    // **Una segunda pasada, y solo si algo llegó** (FR-005).
    //
    // La espera creciente protege a un servidor que no contesta. En cuanto uno
    // de los envíos llega, eso es la prueba de que sí contesta, así que a los
    // demás no les queda nada de lo que protegerse: se intentan ya.
    //
    // Va en una segunda pasada y no dentro del bucle porque el que llega puede
    // ser el último de la lista, y entonces los anteriores ya se habrían
    // saltado. Sin esto, una nadadora que anotó cinco sesiones sin señal las
    // ve salir a goteo, una espera larga cada una, con todo el mecanismo
    // puesto.
    if (alguienLlego && seSaltaron.isNotEmpty) {
      for (final enCola in seSaltaron) {
        final enviado = await _intentar(enCola);
        if (enviado) {
          enviados.add(enCola.registroId);
          siguenPendientes.remove(enCola.registroId);
        }
      }
    }

    // Lo que el último intento dijo sobre la red (D1).
    if (alguienLoIntento) alIntentar?.call(llego: alguienLlego);

    await _replantearElDespertar();

    return ResultadoDeSincronizacion(
      enviados: enviados,
      siguenPendientes: siguenPendientes,
      // Se intentó y no llegó nada: eso es lo que hoy se sabe de la red.
      sinRed: alguienLoIntento && !alguienLlego,
    );
  }

  Future<bool> _intentar(EnvioPendiente enCola) async {
    final registro = await registros.obtener(enCola.registroId);

    if (registro == null) {
      // El registro desapareció del almacén local. No se puede enviar y no
      // tiene sentido reintentarlo eternamente: se marca enviado para sacarlo
      // de la cola. Es el único caso en que una entrada sale sin haber viajado,
      // y ocurre solo si algo externo borró el registro.
      await bandeja.actualizar(enCola.marcandoEnviado());
      return false;
    }

    // La puerta, justo antes de enviar y no antes de encolar. Encolar siempre
    // ocurre: lo que el nadador escribe se guarda pase lo que pase (garantía
    // G1). Lo que la puerta decide es si **sale**.
    if (!await puerta.puedeSalir(registro.nadadorId)) {
      // **No cuenta como intento fallido**, igual que no cuenta estar sin
      // conexión. No es un error: es una condición que todavía no se cumple.
      // Si contara, un consentimiento que tarda una semana dejaría el envío
      // esperando cinco minutos entre intentos por algo que no falló.
      return false;
    }

    await bandeja.actualizar(enCola.marcandoEnviando(_ahora()));

    // **El envío se guarda aparte del `await`**, para poder honrar un éxito
    // que llegue tarde. Ver `_honrarSiLlegaTarde`.
    final enVuelo = transporte.enviar(registro);

    try {
      final recibidoEn = await enVuelo.timeout(esperaAlEnvio);

      // La hora del servidor vuelve al registro local: es lo que permite
      // detectar un reloj desajustado (decisión D3).
      await registros.guardar(registro.copiarCon(recibidoEn: recibidoEn));
      await bandeja.actualizar(enCola.marcandoEnviado());
      return true;
    } on TimeoutException {
      // Un envío que no contesta cuenta como fallido, igual que uno que
      // falla. Lo que no puede es dejar el bucle —y la pantalla— esperando.
      await bandeja.actualizar(
        enCola.marcandoFallido('el servidor no confirmó el envío', _ahora()),
      );

      // **Pero no se abandona** (feature 011, D3). `Future.timeout` no cancela
      // lo que envuelve: solo deja de esperarlo *aquí*. La escritura sigue en
      // la cola interna del SDK y aterriza cuando vuelve la señal, y entonces
      // el servidor tiene el registro mientras nuestra bandeja lo sigue
      // contando pendiente — con el aviso en su pantalla después de haber
      // dejado de ser cierto. Esa respuesta llega gratis; solo hay que
      // escucharla.
      _honrarSiLlegaTarde(enVuelo, registro, enCola);
      return false;
    } on Exception catch (e) {
      // **Garantía G3**: vuelve a pendiente con el contador incrementado.
      // Nunca se descarta, por muchos intentos que lleve.
      await bandeja.actualizar(enCola.marcandoFallido('$e', _ahora()));
      return false;
    }
  }

  /// Lo que se dejó de esperar, por si acaba llegando.
  ///
  /// Si llega, el registro queda enviado y el aviso se apaga **porque llegó**,
  /// nunca porque dejáramos de mirar (FR-016). No se le pregunta nada a nadie
  /// para averiguarlo: preguntar costaría una lectura, y sin conexión esa
  /// lectura se contesta desde la caché, que diría que sí de algo que nunca
  /// salió del teléfono.
  void _honrarSiLlegaTarde(
    Future<DateTime> enVuelo,
    RegistroDeSesion registro,
    EnvioPendiente enCola,
  ) {
    unawaited(
      enVuelo
          .then((recibidoEn) async {
            // Pudo haberse reintentado y haber salido por otra vía mientras
            // tanto: con el identificador determinista es el mismo registro,
            // y marcarlo enviado dos veces no cambia nada.
            await registros.guardar(registro.copiarCon(recibidoEn: recibidoEn));
            await bandeja.actualizar(enCola.marcandoEnviado());
            alIntentar?.call(llego: true);
            await _replantearElDespertar();
          })
          // **Un fallo que llega cuando ya no escucha nadie se traga.** Que
          // una escritura abandonada tumbe la app en una esquina de la calle
          // sería el peor final posible para una garantía que existe para que
          // nada se pierda.
          .catchError((Object _) {}),
    );
  }

  /// Si hay algo esperando, para pintar el aviso al nadador.
  Future<bool> hayPendientes() async {
    final pendientes = await bandeja.pendientes();
    return pendientes.any((p) => p.esperaEnvio);
  }

  // **`alVolverLaRed` se retiró aquí** (feature 011, T018).
  //
  // Era el segundo de los tres disparadores del contrato, y tenía prueba y no
  // tenía oyente: nadie en `lib/` lo escuchaba, y no habría disparado
  // igualmente porque el sondeo detrás no sondeaba nada.
  //
  // No se cableó: se sustituyó. Con el intento como sondeo (D1) no hay un
  // «volvió la red» separado que escuchar — el propio intento es el
  // descubrimiento—, así que un stream que avisara de ello sería una segunda
  // forma de decir lo mismo, y una segunda vía capaz de enviar. Lo que el
  // nadador tenía prometido se cumple igual: ella no toca nada y lo suyo sale.
  //
  // Dejar aquí un miembro probado y sin oyente habría sido repetir, dentro de
  // la feature que lo arregla, el defecto que vino a arreglar.
}

/// El texto que el nadador ve. Vive aquí y no en la interfaz porque es una
/// regla de producto: FR-017 lo exige literalmente.
const String avisoProgresoGuardado =
    'Guardado el progreso, se enviará cuando tengas acceso a internet';
