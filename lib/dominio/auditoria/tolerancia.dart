/// Tolerancia admitida en las desviaciones de distribución.
///
/// La metodología no especifica una tolerancia: exigir el 60,00% exacto de A1
/// sería inaplicable. Este valor lo eligió quien escribió el plan, no el
/// documento normativo.
///
/// **Calibración**: si las planificaciones históricas del propio entrenador
/// fallan criterios con esta tolerancia, la tolerancia está mal puesta, no sus
/// planes. Es la tarea T092.
///
/// Vive en un solo lugar a propósito, para poder recalibrarlo de una vez.
library;

class Tolerancia {
  const Tolerancia(this.puntosPorcentuales);

  /// Valor inicial propuesto: ±3 puntos porcentuales.
  static const Tolerancia predeterminada = Tolerancia(3);

  final double puntosPorcentuales;

  /// Verdadero si la diferencia cabe dentro de la tolerancia.
  bool admite(double diferencia) => diferencia.abs() <= puntosPorcentuales;

  @override
  String toString() => '±$puntosPorcentuales puntos porcentuales';
}
