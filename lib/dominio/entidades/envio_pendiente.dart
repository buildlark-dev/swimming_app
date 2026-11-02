/// Estado de envío de un registro.
///
/// Contrato: `specs/003-consumo-del-nadador/contracts/sincronizacion.md`.
///
/// Es una entidad aparte del registro **a propósito**: lo que el nadador
/// escribió y si eso llegó al servidor son cosas distintas. Acoplarlas obligaría
/// a reescribir el registro cada vez que cambia el estado de la red, y el
/// contenido de una respuesta no debería cambiar porque haya señal.
library;

/// Los **tres** estados por los que pasa un envío.
///
/// **No existe un estado terminal de fallo, y es deliberado.** Un registro que
/// pudiera quedarse en «fallido» sería exactamente la forma en que los datos se
/// pierden en silencio, y FR-019 lo prohíbe. Un envío que falla vuelve a
/// `pendiente` y se reintenta, por muchos intentos que lleve.
///
/// Un registro con cuarenta intentos es un problema que hay que mirar, no un
/// registro que haya que tirar.
enum EstadoDeEnvio {
  pendiente('Pendiente de envío'),
  enviando('Enviando'),
  enviado('Enviado');

  const EstadoDeEnvio(this.descripcion);

  final String descripcion;

  /// Si el nadador debe ver el aviso de progreso guardado.
  ///
  /// `enviando` también lo muestra: al nadador no se le cuenta el detalle del
  /// transporte, solo si su progreso está a salvo y si ya viajó.
  bool get avisaAlNadador => this != EstadoDeEnvio.enviado;
}

class EnvioPendiente {
  const EnvioPendiente({
    required this.registroId,
    this.estado = EstadoDeEnvio.pendiente,
    this.intentos = 0,
    this.ultimoIntento,
    this.ultimoError,
  });

  final String registroId;
  final EstadoDeEnvio estado;
  final int intentos;
  final DateTime? ultimoIntento;

  /// Qué falló la última vez. Para diagnosticar, **no para enseñárselo al
  /// nadador**: alguien mojado al borde de una piscina no está para leer un
  /// error de red.
  final String? ultimoError;

  bool get esperaEnvio => estado != EstadoDeEnvio.enviado;

  /// Cuánto hay que esperar antes del siguiente intento.
  ///
  /// Crece con los intentos y se detiene en cinco minutos. **No se reintenta en
  /// bucle apretado**: el teléfono tiene batería limitada y es de alguien que
  /// está nadando.
  Duration get esperaHastaElSiguiente {
    if (intentos <= 0) return Duration.zero;
    final segundos = 1 << (intentos - 1); // 1, 2, 4, 8, 16...
    const techoEnSegundos = 300;
    return Duration(
      seconds: segundos > techoEnSegundos ? techoEnSegundos : segundos,
    );
  }

  /// Si toca reintentar, dado [ahora].
  bool tocaReintentar(DateTime ahora) {
    if (!esperaEnvio) return false;

    final ultimo = ultimoIntento;
    if (ultimo == null) return true;

    return !ahora.isBefore(ultimo.add(esperaHastaElSiguiente));
  }

  EnvioPendiente marcandoEnviando(DateTime ahora) => EnvioPendiente(
    registroId: registroId,
    estado: EstadoDeEnvio.enviando,
    intentos: intentos,
    ultimoIntento: ahora,
    ultimoError: ultimoError,
  );

  EnvioPendiente marcandoEnviado() => EnvioPendiente(
    registroId: registroId,
    estado: EstadoDeEnvio.enviado,
    intentos: intentos,
    ultimoIntento: ultimoIntento,
  );

  /// Vuelve a `pendiente` e incrementa el contador.
  ///
  /// **Nunca descarta el registro.** No hay número de intentos que lo convierta
  /// en desechable.
  EnvioPendiente marcandoFallido(String error, DateTime ahora) =>
      EnvioPendiente(
        registroId: registroId,
        estado: EstadoDeEnvio.pendiente,
        intentos: intentos + 1,
        ultimoIntento: ahora,
        ultimoError: error,
      );

  @override
  bool operator ==(Object other) =>
      other is EnvioPendiente &&
      other.registroId == registroId &&
      other.estado == estado &&
      other.intentos == intentos;

  @override
  int get hashCode => Object.hash(registroId, estado, intentos);

  @override
  String toString() =>
      'EnvioPendiente($registroId, ${estado.name}, intentos: $intentos)';
}
