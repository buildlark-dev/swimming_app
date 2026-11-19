/// El estado de algo que se está leyendo.
///
/// **«Todavía no sé» no es «no hay».** Esa confusión es el tercer defecto que
/// el recorrido de la feature 010 encontró: `Mi progreso` le decía a la
/// nadadora «Todavía no tienes un plan asignado» durante los veinte segundos
/// que tardaba en cargar el plan que sí tiene, y que estaba en el teléfono que
/// ella tenía en la mano.
///
/// La causa era un `null` con dos significados —«todavía no ha llegado» y «no
/// hay»— y una pantalla que, ante la duda, elegía el más contundente de los
/// dos. Con un tipo sellado los cuatro casos son exhaustivos donde se usan, y
/// una pantalla no puede atender tres y olvidarse del cuarto sin que el
/// compilador lo diga.
///
/// El cuarto caso, además, antes no existía: **no se podía decir «no se pudo
/// leer»**. Un fallo y una ausencia se le veían igual.
///
/// Sigue la forma que este código ya usa para «una de varias cosas»:
/// `ResultadoBusqueda`, `ResultadoTransicion`, `ResultadoGeneracion`,
/// `ResultadoDerivacion`. Añade una palabra a un vocabulario que ya existía,
/// no un patrón nuevo.
///
/// **No trae palabras para el nadador.** `NoSePudo` lleva un motivo para que
/// la pantalla lo redacte; las frases son de la pantalla, y las del caso
/// `NoHay` siguen siendo exactamente las de siempre.
///
/// Dominio puro: ni Flutter ni Firebase (principio II).
library;

sealed class Lectura<T> {
  const Lectura();

  /// Lo leído, si lo hay. Pensado para los sitios que solo quieren pintar.
  T? get valor => switch (this) {
    Hay<T>(:final valor) => valor,
    _ => null,
  };

  /// Si todavía se está buscando. **Lo contrario de «no hay».**
  bool get cargando => this is Cargando<T>;
}

/// Todavía no ha llegado. No dice nada sobre si habrá algo.
class Cargando<T> extends Lectura<T> {
  const Cargando();
}

/// Llegó, y hay algo.
class Hay<T> extends Lectura<T> {
  const Hay(this.valor);

  @override
  final T valor;
}

/// Llegó, y no hay nada. **Esta es la única que merece el estado vacío.**
class NoHay<T> extends Lectura<T> {
  const NoHay();
}

/// No se pudo leer. Ni hay ni deja de haber: no se sabe.
class NoSePudo<T> extends Lectura<T> {
  const NoSePudo(this.motivo);

  /// Para que la pantalla lo redacte. Al nadador no se le enseña tal cual:
  /// nunca un error de red, ni un código, ni un contador de reintentos.
  final String motivo;
}
