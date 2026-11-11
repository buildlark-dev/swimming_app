/// Un nadador pidiéndole a su entrenador que mire una sesión que ya nadó.
///
/// Es lo único nuevo que un nadador puede escribir en esta feature, y es poco
/// a propósito: una pregunta sobre **una** sesión concreta, que ya pasó. No un
/// mensaje, no un hilo y no una conversación.
///
/// **No hay respuesta escrita** (aclaración Q2). El entrenador la marca vista
/// y contesta en la piscina, que es donde ya se habla. Una app que ofreciera
/// un campo de respuesta prometería un canal que nadie va a atender a las once
/// de la noche, y un canal prometido y desatendido es peor que no tenerlo.
///
/// Dominio puro: ni Flutter ni Firebase (principio II).
library;

/// La pregunta estaba en blanco.
///
/// Una petición sin nada dentro no es una petición: al entrenador le llegaría
/// un aviso que no dice qué mirar.
class PreguntaVacia implements Exception {
  const PreguntaVacia();

  @override
  String toString() => 'Una petición de feedback necesita una pregunta';
}

/// Llegó un vídeo y esta feature no los acepta.
class VideoTodaviaNo implements Exception {
  const VideoTodaviaNo();

  @override
  String toString() =>
      'Esta versión no adjunta vídeo: el campo existe para que la puerta del '
      'servidor esté escrita y probada, no para usarse todavía';
}

/// Dónde viviría un vídeo. **Nada en esta feature produce uno.**
///
/// Existe para que la petición tenga una forma en la que crecer y para que la
/// puerta que lo frena se pueda escribir y probar **hoy** (decisión D2). El
/// motivo está en el comentario que la feature 004 dejó sobre los alcances:
/// descubrirlo más tarde significaría volver a pedirle consentimiento a cada
/// familia.
///
/// Una feature posterior quita el rechazo del constructor y la negación de la
/// regla. Nada más de esto tiene que cambiar.
class ReferenciaDeVideo {
  const ReferenciaDeVideo({required this.ruta, required this.subidoEn});

  /// Dónde estaría. No hay almacenamiento configurado.
  final String ruta;

  final DateTime subidoEn;

  @override
  bool operator ==(Object other) =>
      other is ReferenciaDeVideo &&
      other.ruta == ruta &&
      other.subidoEn == subidoEn;

  @override
  int get hashCode => Object.hash(ruta, subidoEn);
}

class PeticionDeFeedback {
  /// Construye la petición, validando lo que no puede entrar.
  ///
  /// Lanza [PreguntaVacia] si no hay pregunta y [VideoTodaviaNo] si llega un
  /// vídeo. No se recorta al valor más cercano ni se ignora el campo de más:
  /// la regla R3 dice preguntar, no suponer.
  factory PeticionDeFeedback({
    required String nadadorId,
    required String planId,
    required String sesionId,
    required String pregunta,
    required DateTime pedidaEn,
    DateTime? vistaEn,
    ReferenciaDeVideo? video,
  }) {
    final limpia = pregunta.trim();
    if (limpia.isEmpty) throw const PreguntaVacia();
    if (video != null) throw const VideoTodaviaNo();

    return PeticionDeFeedback._(
      id: idDeterminista(
        nadadorId: nadadorId,
        planId: planId,
        sesionId: sesionId,
      ),
      nadadorId: nadadorId,
      planId: planId,
      sesionId: sesionId,
      pregunta: limpia,
      pedidaEn: pedidaEn,
      vistaEn: vistaEn,
    );
  }

  const PeticionDeFeedback._({
    required this.id,
    required this.nadadorId,
    required this.planId,
    required this.sesionId,
    required this.pregunta,
    required this.pedidaEn,
    required this.vistaEn,
  });

  /// Identificador **determinista**: a quién, a qué plan y a qué sesión.
  ///
  /// La misma decisión que la feature 003 tomó para los registros y por lo
  /// mismo: si pierde la conexión y vuelve a preguntar, se reescribe un
  /// documento en lugar de crearse dos, y el entrenador recibe una petición.
  /// La duplicación se vuelve imposible por construcción, no por una
  /// comprobación que alguien pueda olvidar.
  ///
  /// **No lleva la versión del plan**, al contrario que el registro. Un
  /// reajuste conserva los identificadores de sesión, así que la pregunta
  /// «¿miras este viraje?» sigue siendo la misma pregunta sobre la misma
  /// sesión aunque el mesociclo se haya versionado por debajo.
  static String idDeterminista({
    required String nadadorId,
    required String planId,
    required String sesionId,
  }) => '$nadadorId|$planId|$sesionId';

  final String id;
  final String nadadorId;

  /// La versión del plan en la que estaba cuando preguntó.
  final String planId;

  final String sesionId;

  /// Sus palabras. Se recortan los extremos —un accidente del teclado— y lo
  /// de dentro se guarda **tal cual**: no se analiza, no se corrige y no se
  /// traduce al vocabulario del entrenador.
  final String pregunta;

  final DateTime pedidaEn;

  /// Cuándo la vio el entrenador. Nula mientras no la haya visto, y **es toda
  /// la respuesta que esta feature promete** (FR-019).
  final DateTime? vistaEn;

  /// El vídeo. **Siempre nulo en esta feature**; el constructor lo rechaza.
  ReferenciaDeVideo? get video => null;

  bool get laVio => vistaEn != null;

  /// El entrenador la marca vista.
  ///
  /// **Si ya estaba vista, no se mueve.** Un entrenador no puede des-ver algo
  /// ni volver a verlo por primera vez, así que esto no es un `copiarCon` con
  /// una fecha: es un paso que solo va en una dirección.
  PeticionDeFeedback vistaPor(DateTime cuando) => laVio
      ? this
      : PeticionDeFeedback._(
          id: id,
          nadadorId: nadadorId,
          planId: planId,
          sesionId: sesionId,
          pregunta: pregunta,
          pedidaEn: pedidaEn,
          vistaEn: cuando,
        );

  @override
  bool operator ==(Object other) =>
      other is PeticionDeFeedback && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'PeticionDeFeedback($id, vista: $laVio)';
}

/// Qué pasó al intentar pedir feedback.
///
/// Es un tipo propio y no un `bool` por la misma razón que `SePuedeMarcar` lo
/// es: la pantalla tiene que **decir por qué** en lugar de quedarse quieta.
/// Un `false` deja al nadador tocando un botón que no responde.
sealed class SePudoPedir {
  const SePudoPedir();

  bool get si => this is SePidio;

  /// En español y sin jerga. Vacía cuando sí se pudo.
  String get comoSeLeExplica => switch (this) {
    SePidio() => '',
    SinPregunta() => 'Escribe tu pregunta antes de mandarla',
    EsaSesionNoHaPasado() =>
      'Todavía no puedes preguntar por esta sesión: su día no ha llegado',
    NoHayDondeGuardarla() =>
      'No se pudo guardar tu pregunta. Vuelve a intentarlo',
  };
}

/// Se guardó. **Guardada no es enviada**: puede estar esperando señal, y eso
/// es justamente lo que la garantía G1 compra.
class SePidio extends SePudoPedir {
  const SePidio();
}

class SinPregunta extends SePudoPedir {
  const SinPregunta();
}

/// Su día es posterior a hoy. El mismo criterio que para marcarla (M24).
class EsaSesionNoHaPasado extends SePudoPedir {
  const EsaSesionNoHaPasado();
}

/// No hay repositorio: sin servidor, nada de esto existe.
class NoHayDondeGuardarla extends SePudoPedir {
  const NoHayDondeGuardarla();
}
