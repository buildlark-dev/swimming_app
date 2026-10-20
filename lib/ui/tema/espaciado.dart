/// Separaciones, radios y medidas mínimas.
///
/// Una escala corta a propósito. Si hay dieciséis separaciones posibles, cada
/// pantalla elige una distinta y el ritmo se pierde; con seis, el ritmo es uno.
library;

abstract final class Espaciado {
  /// Entre elementos muy pegados: un icono y su texto.
  static const double minimo = 4;

  /// Entre líneas de un mismo bloque.
  static const double corto = 8;

  /// El de siempre. Entre elementos de una lista, dentro de una tarjeta.
  static const double normal = 12;

  /// Margen de pantalla, y entre bloques distintos.
  static const double amplio = 16;

  /// Entre secciones.
  static const double seccion = 24;

  /// Separación grande: antes de una acción final, o en un estado vacío.
  static const double generoso = 32;

  // --- Radios ---------------------------------------------------------

  static const double radioCorto = 8;
  static const double radioNormal = 12;
  static const double radioAmplio = 16;

  // --- Lo que se toca --------------------------------------------------

  /// Tamaño mínimo de un área pulsable.
  ///
  /// Vive aquí porque es una medida, y es **48 y no 44** por quién usa esto:
  /// un dedo mojado al borde de la piscina, y a veces el de un niño de nueve
  /// años con un teléfono pequeño. El icono puede ser más chico; el área que
  /// responde, no (FR-006).
  static const double areaPulsableMinima = 48;

  /// Altura mínima de un campo de formulario.
  static const double alturaCampoMinima = 52;
}
