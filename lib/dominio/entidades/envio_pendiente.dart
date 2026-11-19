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
  /// Crece con los intentos y **se detiene en un minuto**. No se reintenta en
  /// bucle apretado: el teléfono tiene batería limitada y es de alguien que
  /// está nadando.
  ///
  /// ## El techo bajó de cinco minutos a uno (feature 011, decisión D2)
  ///
  /// La razón de aquel techo sigue siendo buena, y es la de arriba. Lo que
  /// cambió es que **ahora hay algo que reintenta solo**: cuando se escribió,
  /// nada despertaba a la bandeja, así que el techo solo decía cada cuánto
  /// podía intentarlo quien ya estuviera mirando.
  ///
  /// Con el despertar en marcha, cinco minutos son cinco minutos **después de
  /// que vuelva la red** en los que el registro sigue sin salir, con todo el
  /// mecanismo puesto y la promesa igual de rota. SC-001 dice un minuto, y un
  /// intento por minuto sigue sin ser el bucle apretado que esto evita.
  /// ## Y el tope se comprueba **antes** de desplazar
  ///
  /// `1 << (intentos - 1)` desborda. `1 << 63` cabe en un entero de Dart;
  /// `1 << 64` vuelve a **cero**, y una espera de cero segundos es justo el
  /// bucle apretado que esto existe para evitar: la bandeja se despierta, no
  /// espera nada, se vuelve a despertar.
  ///
  /// No es teórico y no se encontró razonando: lo encontró esta misma feature
  /// al dejar que algo reintentara solo. Una nadadora sin señal unas horas
  /// pasa de sesenta intentos sin despeinarse. Antes de la 011 nadie
  /// reintentaba tantas veces porque nadie reintentaba sin que ella abriera la
  /// app, así que el desbordamiento estaba ahí, inalcanzable, desde la 003.
  Duration get esperaHastaElSiguiente {
    if (intentos <= 0) return Duration.zero;

    const techoEnSegundos = 60;
    // 1 << 6 son 64, que ya pasa del techo: de ahí en adelante no hace falta
    // desplazar nada, y desplazar es lo que rompe.
    if (intentos > 6) return const Duration(seconds: techoEnSegundos);

    final segundos = 1 << (intentos - 1); // 1, 2, 4, 8, 16, 32
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
