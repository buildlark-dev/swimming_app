/// Las molestias que el entrenador ve al abrir una petición.
///
/// **No son de la petición.** Son los reportes que el nadador ya escribió en
/// sus sesiones (feature 003), leídos donde ya viven. La petición apunta a
/// ellos; no los copia, y nada de esta feature los escribe (FR-038).
///
/// Por qué importa tanto: son datos de salud de un menor. Una copia es un
/// segundo sitio desde el que pueden filtrarse, un segundo sitio que hay que
/// borrar al ejercer el derecho de supresión, y un segundo sitio que puede
/// discrepar del primero.
///
/// Es una interfaz propia y estrecha, y no un método más en
/// `RepositorioRegistros`, por dos motivos: **no tiene escritura** —el tipo
/// mismo dice que esto solo lee— y no obliga a las diez implementaciones de
/// aquel a crecer por una necesidad que es de esta pantalla.
library;

/// Una molestia, con la fecha de la sesión en la que se contó.
///
/// La fecha va siempre: «le duele el hombro» sin saber de cuándo es no sirve
/// para decidir el entrenamiento de la semana que viene.
class MolestiaEnlazada {
  const MolestiaEnlazada({
    required this.fecha,
    required this.descripcion,
    this.zonaDelCuerpo = '',
  });

  final DateTime fecha;
  final String descripcion;
  final String zonaDelCuerpo;

  /// Cómo se lee: la zona si la dijo, y lo que escribió.
  String get comoSeLee => zonaDelCuerpo.trim().isEmpty
      ? descripcion
      : '${zonaDelCuerpo.trim()}: $descripcion';
}

/// Lee las molestias recientes de un nadador. **Solo lee.**
abstract class LectorDeMolestias {
  /// Las contadas desde [desde], de la más reciente a la más vieja.
  Future<List<MolestiaEnlazada>> recientesDe(
    String nadadorId, {
    required DateTime desde,
  });

  /// Quiénes contaron alguna desde [desde]. **Una consulta, no una por
  /// nadador** (feature 010, FR-010).
  ///
  /// El entrenador tiene que poder ver desde la lista quién reportó algo, sin
  /// abrir a nadie: un reporte de dolor que solo se encuentra entrando en cada
  /// ficha está enterrado, y el principio VIII dice justamente que no puede
  /// estarlo. Preguntar ficha por ficha serían N consultas para pintar una
  /// pantalla, que es la decisión D10 de la feature 008 con otro nombre.
  Future<Set<String>> quienesReportaron({required DateTime desde});
}
