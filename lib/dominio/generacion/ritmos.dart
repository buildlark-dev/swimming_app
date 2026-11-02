/// Estimación de cuánto tiempo lleva nadar un volumen.
///
/// **Esto es un supuesto nuestro, no una regla del entrenador.** Su metodología
/// no declara ritmos medios por categoría, y para saber si 2.000 m caben en 60
/// minutos hace falta alguno. Vive en un solo lugar a propósito, para que él
/// pueda corregirlo de una vez cuando lo contraste con la realidad de su grupo.
///
/// Decisión D8 de `research.md`. Cuando un plan se genera apoyándose en esta
/// estimación, el hecho queda marcado como supuesto dentro del plan.
library;

import 'package:natacion_app/dominio/metodologia/categorias.dart';

/// Ritmo medio estimado, en metros por minuto, incluyendo pausas.
///
/// Son valores conservadores: es peor generar un plan que no cabe en la sesión
/// que rechazar uno que sí habría cabido, porque lo primero el entrenador lo
/// descubre en la piscina y lo segundo en la pantalla.
const Map<Categoria, int> ritmoMedioMetrosPorMinuto = {
  Categoria.iniciacion: 15,
  Categoria.tecnificacion: 18,
  Categoria.precompetitivo: 25,
  Categoria.competitivo: 33,
  Categoria.altoRendimiento: 40,
};

/// Descripción del supuesto, para mostrarla junto al plan.
const String descripcionDelSupuesto =
    'La comprobación de que el volumen cabe en la duración de sesión usa un '
    'ritmo medio estimado por categoría. No es una regla de la metodología: es '
    'una estimación conservadora nuestra, revisable en un solo lugar.';

class EstimacionDuracion {
  const EstimacionDuracion(this.categoria);

  final Categoria categoria;

  int get ritmoMetrosPorMinuto => ritmoMedioMetrosPorMinuto[categoria] ?? 25;

  /// Minutos estimados para nadar [metros].
  int minutosPara(int metros) => (metros / ritmoMetrosPorMinuto).ceil();

  /// Metros que caben, como máximo, en [minutos].
  int metrosEn(int minutos) => minutos * ritmoMetrosPorMinuto;

  bool cabe(int metros, int minutos) => minutosPara(metros) <= minutos;
}
