import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:natacion_app/ui/tema/paleta.dart';

/// Garantías V4 y V5 — el contraste se mide, no se opina.
///
/// La app se usa **a pie de piscina**: sol directo, pantalla mojada, y a veces
/// la lee un niño de nueve años. Un color que queda bonito en el monitor y no
/// se lee al sol no sirve, y la única forma de saberlo sin salir a la calle es
/// calcularlo.
///
/// Umbrales de la norma de accesibilidad para contenido web, que es la
/// referencia que existe: 4.5 para texto normal, 3.0 para texto grande y para
/// elementos que no son texto.
void main() {
  /// Luminancia relativa, según la fórmula de la norma.
  double luminancia(Color c) {
    double canal(double v) {
      final s = v;
      return s <= 0.03928 ? s / 12.92 : math.pow((s + 0.055) / 1.055, 2.4) as double;
    }

    return 0.2126 * canal(c.r) + 0.7152 * canal(c.g) + 0.0722 * canal(c.b);
  }

  /// Relación de contraste entre dos colores. Va de 1 a 21.
  double contraste(Color a, Color b) {
    final la = luminancia(a);
    final lb = luminancia(b);
    final claro = math.max(la, lb);
    final oscuro = math.min(la, lb);
    return (claro + 0.05) / (oscuro + 0.05);
  }

  const blanco = Color(0xFFFFFFFF);
  const negro = Color(0xFF1A1C1E);

  const textoNormal = 4.5;
  const textoGrande = 3.0;

  void exigir(
    String que,
    Color texto,
    Color fondo,
    double minimo,
  ) {
    final medido = contraste(texto, fondo);
    expect(
      medido,
      greaterThanOrEqualTo(minimo),
      reason: '$que: contraste ${medido.toStringAsFixed(2)}, hace falta '
          '$minimo. Si un color bonito no cumple, gana el contraste: la app '
          'se usa al sol',
    );
  }

  group('V4 — los tonos de aviso se leen', () {
    test('en claro, sobre fondo blanco', () {
      exigir('informativo', Paleta.informativo, blanco, textoNormal);
      exigir('éxito', Paleta.exito, blanco, textoNormal);
      exigir('cuidado', Paleta.cuidado, blanco, textoNormal);
      exigir('error', Paleta.error, blanco, textoNormal);
    });

    test('en oscuro, sobre fondo oscuro', () {
      exigir('informativo', Paleta.informativoOscuro, negro, textoNormal);
      exigir('éxito', Paleta.exitoOscuro, negro, textoNormal);
      exigir('cuidado', Paleta.cuidadoOscuro, negro, textoNormal);
      exigir('error', Paleta.errorOscuro, negro, textoNormal);
    });
  });

  group('V4 — la identidad se lee', () {
    test('el marino sobre blanco', () {
      exigir('marino', Paleta.marino, blanco, textoNormal);
    });

    test('el blanco sobre el marino', () {
      exigir('blanco sobre marino', blanco, Paleta.marino, textoNormal);
    });
  });

  group('V4 — los estados del plan se leen', () {
    test('en claro', () {
      exigir('borrador', Paleta.borrador, blanco, textoNormal);
      exigir('aprobado', Paleta.aprobado, blanco, textoNormal);
      exigir('publicado', Paleta.publicado, blanco, textoNormal);
    });

    test('en oscuro', () {
      exigir('borrador', Paleta.borradorOscuro, negro, textoNormal);
      exigir('aprobado', Paleta.aprobadoOscuro, negro, textoNormal);
      exigir('publicado', Paleta.publicadoOscuro, negro, textoNormal);
    });
  });

  group('V5 — las siete zonas, UNA POR UNA', () {
    // No de media, y no «casi todas». Una rampa suele cumplir en los extremos
    // y fallar en medio, y un promedio lo esconde.

    /// Sobre cada zona va el texto que **más contraste** dé, no el que diga un
    /// umbral fijo. Un umbral deja un hueco justo en mitad de la rampa, donde
    /// elige el peor de los dos: es lo que hizo fallar a la zona AT con 2.93
    /// la primera vez que se corrió esto.
    Color mejorTextoSobre(Color fondo) =>
        contraste(negro, fondo) >= contraste(blanco, fondo) ? negro : blanco;

    test('en claro, cada zona lleva texto legible encima', () {
      for (var i = 0; i < Paleta.zonas.length; i++) {
        final fondo = Paleta.zonas[i];
        exigir('zona $i en claro', mejorTextoSobre(fondo), fondo, textoGrande);
      }
    });

    test('en oscuro, cada zona lleva texto legible encima', () {
      for (var i = 0; i < Paleta.zonasOscuro.length; i++) {
        final fondo = Paleta.zonasOscuro[i];
        exigir('zona $i en oscuro', mejorTextoSobre(fondo), fondo, textoGrande);
      }
    });

    test('ninguna zona se confunde con el fondo de su modo', () {
      exigir('A1 contra el fondo claro', Paleta.zonas.first, blanco, 1.2);
      exigir('A1 contra el fondo oscuro', Paleta.zonasOscuro.first, negro, 1.2);
    });
  });

  group('la prueba no pasa por vacía', () {
    test('el cálculo de contraste es el correcto', () {
      // Blanco contra negro puro es 21, el máximo. Si esto falla, la fórmula
      // está mal y todo lo de arriba no significa nada.
      expect(
        contraste(blanco, const Color(0xFF000000)),
        closeTo(21, 0.1),
      );
      expect(contraste(blanco, blanco), closeTo(1, 0.01));
    });

    test('hay siete zonas, que son las de la sección 9', () {
      expect(Paleta.zonas, hasLength(7));
      expect(Paleta.zonasOscuro, hasLength(7));
    });
  });
}
