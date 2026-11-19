/// Lo que un entrenador llama a su grupo.
///
/// **Es el letrero, no la lista.** Una comunidad tiene un nombre que el
/// entrenador elige y que una nadadora ve **antes** de pertenecer a nada: es lo
/// único que ella tiene para reconocerlo. Quién está dentro no se guarda aquí,
/// y eso es deliberado — ver el letrero no puede contar quién hay detrás.
///
/// Una por entrenador. En el almacén, el identificador de la comunidad **es** el
/// de su entrenador, así que «una» es un hecho de la clave y no una regla que
/// alguien tenga que recordar.
///
/// Dominio puro: ni Flutter ni Firebase (principio II).
library;

/// Lo máximo que puede medir el nombre.
///
/// Sesenta caracteres caben en la pantalla de una nadadora sin partirse, que es
/// la única medida que importa: el nombre existe para que ella lo reconozca.
const int largoMaximoDelNombre = 60;

class NombreDeComunidadInvalido implements Exception {
  const NombreDeComunidadInvalido(this.porQue);

  final String porQue;

  @override
  String toString() => 'Nombre de comunidad inválido: $porQue';
}

class Comunidad {
  /// Rechaza en el constructor lo que no puede representar, como el resto de
  /// las entidades de este proyecto. Un nombre en blanco no es un nombre.
  Comunidad({
    required this.id,
    required this.entrenadorId,
    required String nombre,
    this.creadaEn,
  }) : nombre = nombre.trim() {
    if (this.nombre.isEmpty) {
      throw const NombreDeComunidadInvalido('no puede estar en blanco');
    }
    if (this.nombre.length > largoMaximoDelNombre) {
      throw const NombreDeComunidadInvalido(
        'no puede pasar de $largoMaximoDelNombre caracteres',
      );
    }
  }

  final String id;

  /// De quién es. **No se cambia nunca**: una comunidad que pudiera cambiar de
  /// manos es otro producto, y uno con preguntas que este no se ha hecho —qué
  /// pasa con lo que el anterior leyó, y con lo que las familias consintieron.
  final String entrenadorId;

  /// Lo que ella ve.
  final String nombre;

  final DateTime? creadaEn;

  /// Cambiarle el nombre **no mueve a nadie** (FR-003). El nombre vive aquí y
  /// la pertenencia vive en el perfil de cada nadadora, justo para que esto
  /// sea cierto sin que nadie tenga que acordarse.
  Comunidad renombrada(String otro) => Comunidad(
    id: id,
    entrenadorId: entrenadorId,
    nombre: otro,
    creadaEn: creadaEn,
  );

  @override
  bool operator ==(Object other) =>
      other is Comunidad &&
      other.id == id &&
      other.entrenadorId == entrenadorId &&
      other.nombre == nombre;

  @override
  int get hashCode => Object.hash(id, entrenadorId, nombre);

  @override
  String toString() => 'Comunidad($id, $nombre)';
}
