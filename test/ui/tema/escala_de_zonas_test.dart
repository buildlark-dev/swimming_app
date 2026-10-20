import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:natacion_app/dominio/metodologia/zonas.dart';
import 'package:natacion_app/ui/tema/paleta.dart';

/// Garantías V8 y V9 — las zonas se distinguen sin color, y en su orden.
///
/// Alrededor del 8% de los hombres no distingue algunos colores. Entre un
/// grupo de nadadores es cuestión de tiempo, así que una rampa que solo cambia
/// de tono se convierte para ellos en siete grises casi iguales.
///
/// Por eso la rampa varía en **claridad** (decisión D4). Y por eso esta prueba
/// mide luminancia y no tono.
void main() {
  double luminancia(Color c) {
    double canal(double v) =>
        v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4) as double;

    return 0.2126 * canal(c.r) + 0.7152 * canal(c.g) + 0.0722 * canal(c.b);
  }

  group('V9 — el orden visual es el orden de intensidad', () {
    test('en claro, la rampa oscurece sin volver atrás ni una vez', () {
      final luces = Paleta.zonas.map(luminancia).toList();

      for (var i = 1; i < luces.length; i++) {
        expect(
          luces[i],
          lessThan(luces[i - 1]),
          reason: 'La zona $i no es más oscura que la ${i - 1}. Enseñar otro '
              'orden sería enseñar una ordenación que la metodología no hace',
        );
      }
    });

    test('en oscuro, aclara sin volver atrás ni una vez', () {
      final luces = Paleta.zonasOscuro.map(luminancia).toList();

      for (var i = 1; i < luces.length; i++) {
        expect(luces[i], greaterThan(luces[i - 1]));
      }
    });

    test('más intenso es más fuerte, sin que nadie se lo aprenda', () {
      // A1 es la más suave y Exp la más intensa. Que el extremo intenso sea
      // el extremo visual hace que la escala se entienda sin leyenda.
      final luces = Paleta.zonas.map(luminancia).toList();
      expect(luces.first, greaterThan(luces.last));
    });
  });

  group('V8 — las siete se distinguen en escala de grises', () {
    /// Claridad perceptual, la L* del espacio CIELAB.
    ///
    /// **La luminancia cruda no sirve para medir esto**, y lo descubrimos
    /// midiendo: la rampa oscura daba saltos de 0.026 en el extremo oscuro y
    /// de 0.171 en el claro, y parecía mal repartida. No lo estaba. El ojo no
    /// percibe la luminancia de forma lineal, así que un salto pequeño abajo
    /// se ve tan grande como uno mucho mayor arriba.
    ///
    /// En L*, esa misma rampa salta 8, 9, 9, 10, 11, 11: casi perfecta. La
    /// paleta estaba bien y la regla estaba mal.
    double claridad(Color c) {
      final y = luminancia(c);
      return y > 0.008856
          ? 116 * math.pow(y, 1 / 3) - 16
          : 903.3 * y;
    }

    /// Dos pasos consecutivos tienen que separarse lo suficiente para que no
    /// se confundan al verlos juntos. En L*, que va de 0 a 100.
    const separacionMinima = 6.0;

    test('en claro, ningún par consecutivo se confunde', () {
      final luces = Paleta.zonas.map(claridad).toList();

      for (var i = 1; i < luces.length; i++) {
        final separacion = (luces[i - 1] - luces[i]).abs();
        expect(
          separacion,
          greaterThanOrEqualTo(separacionMinima),
          reason: 'Las zonas ${i - 1} y $i se separan solo '
              '${separacion.toStringAsFixed(3)} en luminancia. Quien no '
              'distinga colores las verá iguales',
        );
      }
    });

    test('en oscuro, tampoco', () {
      final luces = Paleta.zonasOscuro.map(claridad).toList();

      for (var i = 1; i < luces.length; i++) {
        final separacion = (luces[i - 1] - luces[i]).abs();
        expect(
          separacion,
          greaterThanOrEqualTo(separacionMinima),
          reason: 'Las zonas ${i - 1} y $i se separan solo '
              '${separacion.toStringAsFixed(3)} en luminancia.\n'
              'Luminancias: '
              '${luces.map((l) => l.toStringAsFixed(3)).join(', ')}',
        );
      }
    });

    test('los extremos se separan de verdad, no por poco', () {
      // En L*, de 0 a 100: el recorrido tiene que ser amplio de verdad.
      final luces = Paleta.zonas.map(claridad).toList();
      expect(luces.first - luces.last, greaterThan(50));
    });
  });

  group('la escala cubre la metodología y nada más', () {
    test('hay exactamente una entrada por zona de la sección 9', () {
      expect(
        Paleta.zonas,
        hasLength(Zona.values.length),
        reason: 'Si la metodología añadiera o quitara una zona, esta prueba se '
            'entera antes que la pantalla',
      );
      expect(Paleta.zonasOscuro, hasLength(Zona.values.length));
    });

    test('son siete, en el orden A1, A2, A3, AT, Máx, Velocidad, Exp', () {
      expect(
        Zona.values.map((z) => z.abreviatura).toList(),
        ['A1', 'A2', 'A3', 'AT', 'Máx', 'Velocidad', 'Exp'],
      );
    });

    test('ninguna zona repite color: no se agrupan', () {
      // La metodología las define como bandas contiguas y sin solapamiento.
      // Pintar dos iguales sugeriría una equivalencia que no existe.
      expect(Paleta.zonas.toSet(), hasLength(7));
      expect(Paleta.zonasOscuro.toSet(), hasLength(7));
    });
  });
}
