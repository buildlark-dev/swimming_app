/// El tema de la app, en claro y en oscuro.
///
/// Arma los dos `ThemeData` a partir de los tokens. Ninguna pantalla decide
/// nada: todas leen de aquí.
///
/// El esquema se **deriva** de una semilla marina en lugar de escribirse color
/// a color. Material calcula entonces las treinta y tantas variantes de forma
/// armónica, y lo que queda escrito a mano son solo los colores que él no
/// tiene: los cuatro tonos de aviso, las siete zonas y los tres estados.
library;

import 'package:flutter/material.dart';
import 'package:natacion_app/ui/tema/avisos.dart';
import 'package:natacion_app/ui/tema/espaciado.dart';
import 'package:natacion_app/ui/tema/paleta.dart';
import 'package:natacion_app/ui/tema/tipografia.dart';

abstract final class Tema {
  static ThemeData claro() => _construir(Brightness.light);

  static ThemeData oscuro() => _construir(Brightness.dark);

  static ThemeData _construir(Brightness brillo) {
    final esClaro = brillo == Brightness.light;

    final esquema = ColorScheme.fromSeed(
      seedColor: Paleta.marino,
      brightness: brillo,
      // El rojo de error sale de la paleta, no de lo que Material derive: es
      // uno de los cuatro tonos y tiene que ser el mismo en los dos sitios.
      error: esClaro ? Paleta.error : Paleta.errorOscuro,
    );

    final texto = Tipografia.escala(esquema);

    return ThemeData(
      useMaterial3: true,
      colorScheme: esquema,
      textTheme: texto,

      // Los colores que Material no tiene y esta app sí necesita.
      extensions: <ThemeExtension<dynamic>>[
        esClaro ? ColoresDelDominio.claro() : ColoresDelDominio.oscuro(),
      ],

      // --- Lo que se toca ---------------------------------------------
      //
      // Los tamaños mínimos se fijan aquí para que ninguna pantalla tenga que
      // acordarse. Un dedo mojado no acierta un objetivo pequeño.
      materialTapTargetSize: MaterialTapTargetSize.padded,

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, Espaciado.areaPulsableMinima),
          textStyle: texto.labelLarge,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Espaciado.radioNormal),
          ),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(0, Espaciado.areaPulsableMinima),
          textStyle: texto.labelLarge,
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, Espaciado.areaPulsableMinima),
          textStyle: texto.labelLarge,
        ),
      ),

      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size(
            Espaciado.areaPulsableMinima,
            Espaciado.areaPulsableMinima,
          ),
        ),
      ),

      // --- Superficies -------------------------------------------------

      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: esquema.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Espaciado.radioAmplio),
          side: BorderSide(color: esquema.outlineVariant),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: esquema.surfaceContainerLowest,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Espaciado.radioNormal),
        ),
        // **Sin `contentPadding` propio, y sin `constraints` de altura.**
        //
        // Ponerlos hacía desbordar los desplegables por 27 píxeles: un campo
        // con relleno extra deja menos sitio a su contenido, y el texto de
        // una categoría más su flecha ya no cabían. Lo cazaron ocho pruebas de
        // las features anteriores, que es justo para lo que está la garantía
        // V13.
        //
        // La altura cómoda de un campo la da el relleno por omisión de
        // Material, que ya supera el mínimo que pide `Espaciado`.
      ),

      listTileTheme: const ListTileThemeData(
        minVerticalPadding: Espaciado.normal,
      ),

      dividerTheme: DividerThemeData(
        color: esquema.outlineVariant,
        space: Espaciado.amplio,
      ),

      appBarTheme: AppBarTheme(
        centerTitle: false,
        backgroundColor: esquema.surface,
        foregroundColor: esquema.onSurface,
        titleTextStyle: texto.titleLarge,
      ),

      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: esquema.surfaceContainer,
        labelTextStyle: WidgetStatePropertyAll(texto.labelMedium),
      ),

      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Espaciado.radioNormal),
        ),
      ),
    );
  }
}
