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

import 'package:natacion_app/dominio/consentimiento/puerta.dart';
import 'package:natacion_app/dominio/entidades/envio_pendiente.dart';
import 'package:natacion_app/dominio/entidades/registro_sesion.dart';
import 'package:natacion_app/dominio/repositorios/repositorios.dart';

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
    DateTime Function()? reloj,
  })  :
        // El reloj se inyecta para poder probar los reintentos sin esperar
        // minutos reales. Por omisión es el del sistema.
        _ahora = reloj ?? DateTime.now;

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
  }

  /// Intenta enviar lo pendiente.
  ///
  /// Sin conexión devuelve `sinRed` y **no toca los contadores**: no haber
  /// podido intentarlo no es haber fallado, y contarlo como intento alargaría
  /// la espera del siguiente reintento sin motivo.
  Future<ResultadoDeSincronizacion> sincronizar() async {
    final pendientes = await bandeja.pendientes();
    if (pendientes.isEmpty) {
      return const ResultadoDeSincronizacion();
    }

    if (!await red.hayConexion()) {
      return ResultadoDeSincronizacion(
        siguenPendientes: pendientes.map((p) => p.registroId).toList(),
        sinRed: true,
      );
    }

    final enviados = <String>[];
    final siguenPendientes = <String>[];

    for (final enCola in pendientes) {
      // Los registros se envían de forma independiente (garantía G5): que uno
      // falle no detiene a los demás, y no hay transacción entre varios.
      if (!enCola.tocaReintentar(_ahora())) {
        siguenPendientes.add(enCola.registroId);
        continue;
      }

      final enviado = await _intentar(enCola);
      (enviado ? enviados : siguenPendientes).add(enCola.registroId);
    }

    return ResultadoDeSincronizacion(
      enviados: enviados,
      siguenPendientes: siguenPendientes,
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

    try {
      final recibidoEn = await transporte.enviar(registro);

      // La hora del servidor vuelve al registro local: es lo que permite
      // detectar un reloj desajustado (decisión D3).
      await registros.guardar(registro.copiarCon(recibidoEn: recibidoEn));
      await bandeja.actualizar(enCola.marcandoEnviado());
      return true;
    } on Exception catch (e) {
      // **Garantía G3**: vuelve a pendiente con el contador incrementado.
      // Nunca se descarta, por muchos intentos que lleve.
      await bandeja.actualizar(enCola.marcandoFallido('$e', _ahora()));
      return false;
    }
  }

  /// Si hay algo esperando, para pintar el aviso al nadador.
  Future<bool> hayPendientes() async {
    final pendientes = await bandeja.pendientes();
    return pendientes.any((p) => p.esperaEnvio);
  }

  /// Vigila la red y sincroniza cuando vuelve.
  ///
  /// Es uno de los tres disparadores del contrato: al guardar, al volver la red
  /// y al abrir la app.
  Stream<ResultadoDeSincronizacion> get alVolverLaRed =>
      red.cambios.asyncMap((hayConexion) async {
        if (!hayConexion) return const ResultadoDeSincronizacion(sinRed: true);
        return sincronizar();
      });
}

/// El texto que el nadador ve. Vive aquí y no en la interfaz porque es una
/// regla de producto: FR-017 lo exige literalmente.
const String avisoProgresoGuardado =
    'Guardado el progreso, se enviará cuando tengas acceso a internet';
