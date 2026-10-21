/// El color de cada zona de intensidad.
///
/// Aquí vive la traducción entre lo que dice la metodología y lo que se ve en
/// pantalla. **El dominio no sabe de colores** (principio II): `Zona` conoce su
/// banda de frecuencia, su ritmo y su RPE, y nada más. Es la interfaz la que
/// decide que A1 se pinte claro y Exp oscuro.
///
/// La rampa va por **claridad y no por tono** (decisión D4). Una rampa de
/// tonos —azul, verde, amarillo, naranja, rojo— se convierte en siete grises
/// casi iguales para quien no distingue colores, que es alrededor del 8% de los
/// hombres; entre un grupo de nadadores es cuestión de tiempo. Variando la
/// claridad, la escala sobrevive al gris y al daltonismo, **y además el orden
/// visual coincide con el de intensidad sin que nadie tenga que aprendérselo**:
/// más intenso, más fuerte.
///
/// Lo vigilan las garantías V8 y V9 en `test/ui/tema/escala_de_zonas_test.dart`.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:natacion_app/dominio/metodologia/zonas.dart';
import 'package:natacion_app/ui/tema/avisos.dart';

abstract final class EscalaDeZonas {
  /// El color de fondo de una zona, en el modo que toque.
  static Color fondoDe(BuildContext context, Zona zona) =>
      context.colores.deZona(zona.index);

  /// El color del texto que va **encima** de esa zona.
  ///
  /// Se elige el que más contraste dé, no uno fijo por umbral. Un umbral fijo
  /// deja un hueco justo en mitad de la rampa, donde acaba escogiendo el peor
  /// de los dos: es lo que hizo fallar a la zona AT con 2.93 la primera vez que
  /// se midió esto, en la fase 3.
  static Color textoSobre(BuildContext context, Zona zona) {
    final fondo = fondoDe(context, zona);
    final esquema = Theme.of(context).colorScheme;

    return _contraste(esquema.onSurface, fondo) >=
            _contraste(esquema.surface, fondo)
        ? esquema.onSurface
        : esquema.surface;
  }

  static double _contraste(Color a, Color b) {
    final la = _luminancia(a);
    final lb = _luminancia(b);
    return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
  }

  static double _luminancia(Color c) {
    double canal(double v) =>
        v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4) as double;

    return 0.2126 * canal(c.r) + 0.7152 * canal(c.g) + 0.0722 * canal(c.b);
  }
}
