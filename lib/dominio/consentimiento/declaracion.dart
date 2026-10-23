/// El correo del acudiente que alguien declaró, y de dónde salió.
///
/// Es **una dirección, no una persona**. Hasta que el acudiente abre el enlace
/// y rellena el formulario de la feature 004 —donde se identifica, declara en
/// qué calidad actúa y confirma que ha oído al menor— no hay nadie
/// identificado al otro lado.
///
/// ## Por qué el nadador puede declararlo
///
/// La feature 004 solo dejaba al entrenador aportar el canal, y lo escribió
/// así: «lo aporta el entrenador desde su matrícula, nunca el nadador». Era
/// correcto para lo que se tenía en la cabeza: un club cerrado, con una
/// matrícula de la que sacar el contacto de las familias.
///
/// **Esta app no es eso.** La usa cualquier persona, a nivel nacional e
/// internacional, y la mayoría no tendrá entrenador dentro de la app. Una
/// nadadora de catorce años que se la descarga en otro país no tiene a nadie
/// que aporte nada. Exigirlo no haría el consentimiento más seguro: haría que
/// **no existiera ninguno**, que es el estado de hoy y el peor de todos.
///
/// La garantía está en el formulario, que es donde la ley la pone (Decreto
/// 1377 de 2013). El correo es solo el camino hasta él.
///
/// Decisión D1 de `specs/006-alta-de-cuenta/research.md`.
library;

/// De dónde salió la dirección del acudiente.
///
/// Se graba porque cuesta un campo y contesta por escrito una pregunta que
/// alguien hará algún día: **cómo llegó este consentimiento**. Al entrenador
/// que sí tenga un grupo le sirve para distinguir los suyos.
enum OrigenDeLaDeclaracion {
  /// El camino normal: lo escribió quien se registró.
  declaradoPorElNadador('Declarado por el nadador'),

  /// Un entrenador con su grupo, desde sus registros.
  matriculaDelEntrenador('De la matrícula del entrenador');

  const OrigenDeLaDeclaracion(this.descripcion);

  /// En español, para enseñarlo tal cual.
  final String descripcion;
}

/// Por qué una dirección no sirve como acudiente.
enum MotivoDeCorreoInvalido {
  vacio('Escribe un correo'),
  sinForma('Ese correo no parece un correo'),

  /// El caso ingenuo, y el único que la app puede detectar.
  esElDelPropioNadador(
    'Ese es tu propio correo. Hace falta el de tu padre, madre o acudiente',
  );

  const MotivoDeCorreoInvalido(this.mensaje);

  /// En español y dirigido a quien lo lee.
  final String mensaje;
}

class DeclaracionDeAcudiente {
  const DeclaracionDeAcudiente({
    required this.nadadorId,
    required this.correo,
    required this.origen,
    required this.declaradaEn,
  });

  final String nadadorId;
  final String correo;

  /// **No se puede cambiar después** (garantía A9). Una declaración no se
  /// convierte en verificada porque alguien la mire.
  final OrigenDeLaDeclaracion origen;

  final DateTime declaradaEn;

  /// Si esta dirección sirve como acudiente del nadador cuyo correo es
  /// [correoDeLaCuenta].
  ///
  /// **Lo que esto NO comprueba**: que la dirección sea de verdad de un
  /// acudiente. Eso no lo puede saber la app, y pretender lo contrario sería
  /// peor que no comprobar nada. Tapa el caso ingenuo —el niño que pone el
  /// suyo— y para lo demás está el formulario.
  static MotivoDeCorreoInvalido? revisarCorreo(
    String correo, {
    required String correoDeLaCuenta,
  }) {
    final limpio = correo.trim().toLowerCase();

    if (limpio.isEmpty) return MotivoDeCorreoInvalido.vacio;

    // Deliberadamente laxo. Validar correos con precisión es imposible, y una
    // validación estricta rechaza direcciones legítimas, que es peor que dejar
    // pasar una mal escrita: esa se corrige cuando no llega el mensaje.
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(limpio)) {
      return MotivoDeCorreoInvalido.sinForma;
    }

    if (limpio == correoDeLaCuenta.trim().toLowerCase()) {
      return MotivoDeCorreoInvalido.esElDelPropioNadador;
    }

    return null;
  }

  @override
  bool operator ==(Object other) =>
      other is DeclaracionDeAcudiente &&
      other.nadadorId == nadadorId &&
      other.correo == correo &&
      other.origen == origen &&
      other.declaradaEn == declaradaEn;

  @override
  int get hashCode => Object.hash(nadadorId, correo, origen, declaradaEn);
}
