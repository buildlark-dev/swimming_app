/// La escala de texto.
///
/// Construida sobre la fuente del sistema (decisión D2). **No se descarga
/// ninguna**: `google_fonts` baja los tipos en tiempo de ejecución, y esta app
/// promete que leer el plan nunca requiere red. Una app que necesita internet
/// para mostrar bien su texto a pie de piscina contradice justo la restricción
/// que la feature 003 existe para cumplir.
///
/// Cuesta que la app no se vea idéntica en Android y en iOS. Es aceptable: lo
/// que se exige es que **se lea**, no que sea idéntica.
///
/// **Cada nivel lleva declarado para qué es.** Un nivel sin uso declarado es
/// un nivel que alguien usará para otra cosa, y en un mes hay nueve tamaños.
library;

import 'package:flutter/material.dart';

abstract final class Tipografia {
  /// Títulos de pantalla. Uno por pantalla.
  static const double tituloPantalla = 22;

  /// Cabeceras de sección dentro de una pantalla.
  static const double tituloSeccion = 18;

  /// Títulos de tarjeta y de elemento de lista.
  static const double tituloElemento = 16;

  /// El texto normal. Lo que más se lee.
  static const double cuerpo = 15;

  /// Texto secundario: subtítulos, descripciones, ayudas de campo.
  static const double apoyo = 14;

  /// Etiquetas de botón y de pestaña.
  static const double etiqueta = 14;

  /// Lo más pequeño que esta app admite.
  ///
  /// **No baja de aquí.** Los seis `fontSize: 12` y `fontSize: 11` que había
  /// repartidos por las pantallas llegaban a ser incómodos al sol, y algunos
  /// de quienes leen esto tienen nueve años.
  static const double menor = 13;

  /// La escala completa, para el tema.
  ///
  /// `height` generoso a propósito: el texto respira y se lee mejor con la
  /// pantalla mojada y en movimiento.
  static TextTheme escala(ColorScheme esquema) {
    TextStyle estilo(double tamano, FontWeight peso, {double altura = 1.35}) =>
        TextStyle(
          fontSize: tamano,
          fontWeight: peso,
          height: altura,
          color: esquema.onSurface,
        );

    return TextTheme(
      headlineSmall: estilo(tituloPantalla, FontWeight.w600, altura: 1.25),
      titleLarge: estilo(tituloSeccion, FontWeight.w600, altura: 1.3),
      titleMedium: estilo(tituloElemento, FontWeight.w600),
      bodyLarge: estilo(cuerpo, FontWeight.w400, altura: 1.45),
      bodyMedium: estilo(apoyo, FontWeight.w400, altura: 1.45),
      bodySmall: estilo(menor, FontWeight.w400).copyWith(
        color: esquema.onSurfaceVariant,
      ),
      labelLarge: estilo(etiqueta, FontWeight.w600, altura: 1.2),
      labelMedium: estilo(menor, FontWeight.w600, altura: 1.2),
    );
  }

  /// Cifras de ancho fijo, para donde se muestran series.
  ///
  /// `4x100 / 1'40"` es una **instrucción de entrenamiento**. Con cifras de
  /// ancho variable las columnas bailan, y leer mal una cifra cambia lo que el
  /// nadador hace en el agua (FR-008).
  static const List<FontFeature> cifrasTabulares = <FontFeature>[
    FontFeature.tabularFigures(),
  ];

  /// Estilo para notación del entrenador: series, tiempos, distancias.
  static TextStyle notacion(TextStyle base) =>
      base.copyWith(fontFeatures: cifrasTabulares);
}
