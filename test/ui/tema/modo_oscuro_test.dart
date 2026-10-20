/// El modo oscuro — que un significado no cambie de significado.
///
/// Lo que esta prueba vigila no es que el oscuro «se vea bien»: eso no lo dice
/// ninguna máquina. Vigila algo más concreto y más fácil de romper: que **el
/// verde de éxito siga siendo verde** y el rojo de error siga siendo rojo
/// cuando el teléfono está en oscuro.
///
/// Es un riesgo real. Los valores de oscuro se eligen aclarando los de claro
/// para que contrasten con un fondo negro, y al aclarar a ojo es fácil que un
/// ámbar acabe pareciendo amarillo verdoso, o que dos tonos se junten. Si eso
/// pasa, un nadador que aprendió qué significa cada color de día tiene que
/// volver a aprenderlo de noche.
///
/// El contraste de cada tono en los dos modos lo mide `contraste_test.dart`, y
/// el orden de la rampa de zonas, `escala_de_zonas_test.dart`. Aquí no se
/// repite nada de eso: aquí se compara **claro contra oscuro**.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:natacion_app/main.dart';
import 'package:natacion_app/ui/tema/avisos.dart';
import 'package:natacion_app/ui/tema/tema.dart';

import 'ayuda_pantallas.dart';

void main() {
  final claro = Tema.claro().extension<ColoresDelDominio>()!;
  final oscuro = Tema.oscuro().extension<ColoresDelDominio>()!;

  /// El tono de un color, en grados.
  double matiz(Color c) => HSVColor.fromColor(c).hue;

  /// Distancia entre dos tonos por el camino corto del círculo.
  ///
  /// Sin esto, el rojo a 2° y el rojo a 358° parecerían estar a 356° de
  /// distancia, cuando son el mismo rojo.
  double separacion(Color a, Color b) {
    final d = (matiz(a) - matiz(b)).abs();
    return d > 180 ? 360 - d : d;
  }

  /// Lo que consideramos «la misma familia de color».
  const mismaFamilia = 30.0;

  /// Lo que hace falta para que dos cosas distintas no se confundan.
  const sinConfundirse = 25.0;

  // --- La distancia que de verdad importa -------------------------------
  //
  // El matiz solo no basta, y en este proyecto ya nos pasó: en la fase 2 la
  // rampa de zonas parecía mal repartida medida en luminancia cruda y estaba
  // perfecta medida en L*. **La paleta estaba bien y la métrica estaba mal.**
  //
  // Aquí el matiz dice que «cuidado» y «error» en oscuro están a 29°, que
  // suena justo. Pero no se diferencian solo por el matiz: uno es un ámbar
  // saturado y el otro un rosa pálido, y eso el matiz no lo ve. La distancia
  // en CIELAB sí, porque mide las tres dimensiones a la vez.

  double aLineal(double v) => v <= 0.04045 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4) as double;

  /// El color en CIELAB: claridad, verde-rojo, azul-amarillo.
  (double, double, double) lab(Color c) {
    final r = aLineal(c.r);
    final g = aLineal(c.g);
    final b = aLineal(c.b);

    // A XYZ, con el blanco de referencia D65.
    final x = (0.4124 * r + 0.3576 * g + 0.1805 * b) / 0.95047;
    final y = 0.2126 * r + 0.7152 * g + 0.0722 * b;
    final z = (0.0193 * r + 0.1192 * g + 0.9505 * b) / 1.08883;

    double t(double v) =>
        v > 0.008856 ? math.pow(v, 1 / 3) as double : 7.787 * v + 16 / 116;

    return (116 * t(y) - 16, 500 * (t(x) - t(y)), 200 * (t(y) - t(z)));
  }

  /// Cuánto se diferencian dos colores a la vista.
  ///
  /// Por debajo de 2.3 el ojo no los separa; por encima de 20 son colores
  /// claramente distintos.
  double distancia(Color a, Color b) {
    final (l1, a1, b1) = lab(a);
    final (l2, a2, b2) = lab(b);
    return math.sqrt(
      math.pow(l1 - l2, 2) + math.pow(a1 - a2, 2) + math.pow(b1 - b2, 2),
    );
  }

  /// Lo que pedimos entre dos tonos que dicen cosas distintas.
  ///
  /// 25 es «claramente otro color», no «se pueden distinguir si los pones uno
  /// al lado del otro con buena luz». A pie de piscina, con sol, hay que pedir
  /// lo primero.
  const distanciaMinima = 25.0;

  group('un tono sigue siendo el mismo tono en oscuro', () {
    final tonos = {
      'informativo': (claro.informativo, oscuro.informativo),
      'éxito': (claro.exito, oscuro.exito),
      'cuidado': (claro.cuidado, oscuro.cuidado),
      'error': (claro.error, oscuro.error),
    };

    tonos.forEach((nombre, par) {
      test('$nombre conserva su familia de color', () {
        final medida = separacion(par.$1, par.$2);
        expect(
          medida,
          lessThanOrEqualTo(mismaFamilia),
          reason: 'El $nombre se desvía ${medida.toStringAsFixed(0)}° al pasar '
              'a oscuro. Quien aprendió de día qué significa ese color '
              'tendría que volver a aprenderlo de noche',
        );
      });

      test('$nombre sí cambia de valor: el oscuro no es el claro', () {
        // Si fueran iguales, el modo oscuro no estaría haciendo nada y el
        // contraste contra el fondo negro no se cumpliría.
        expect(par.$1, isNot(par.$2));
      });
    });

    test('el icono de cada tono no depende del modo', () {
      // El icono es el segundo canal (V10). Si cambiara con el modo, el
      // respaldo de quien no distingue colores se movería de sitio.
      for (final tono in TonoDeAviso.values) {
        expect(tono.icono, isNotNull);
      }
      expect(
        TonoDeAviso.values.map((t) => t.icono).toSet(),
        hasLength(TonoDeAviso.values.length),
      );
    });
  });

  group('los cuatro tonos no se confunden entre sí', () {
    void comprobar(String modo, ColoresDelDominio c) {
      final porNombre = {
        'informativo': c.informativo,
        'éxito': c.exito,
        'cuidado': c.cuidado,
        'error': c.error,
      };
      final nombres = porNombre.keys.toList();

      for (var i = 0; i < nombres.length; i++) {
        for (var j = i + 1; j < nombres.length; j++) {
          final a = nombres[i];
          final b = nombres[j];

          final porMatiz = separacion(porNombre[a]!, porNombre[b]!);
          final aLaVista = distancia(porNombre[a]!, porNombre[b]!);

          // Se piden las dos cosas: familias de color distintas **y**
          // distancia perceptual. El matiz solo dejaría pasar dos rojos de
          // distinta claridad; la distancia sola dejaría pasar el mismo ámbar
          // en dos claridades, que a quien no distingue colores le daría igual.
          expect(
            porMatiz,
            greaterThanOrEqualTo(sinConfundirse),
            reason: 'En $modo, $a y $b están a solo '
                '${porMatiz.toStringAsFixed(0)}° de matiz. Dos avisos que '
                'dicen cosas distintas tienen que verse distintos',
          );
          expect(
            aLaVista,
            greaterThanOrEqualTo(distanciaMinima),
            reason: 'En $modo, $a y $b están a '
                '${aLaVista.toStringAsFixed(0)} de distancia a la vista, y '
                'hace falta $distanciaMinima',
          );
        }
      }
    }

    test('en claro', () => comprobar('claro', claro));
    test('en oscuro', () => comprobar('oscuro', oscuro));
  });

  group('aprobado no se confunde con publicado, en ningún modo', () {
    // Aprobar no es entregar. Es la distinción que el principio IV protege, y
    // si los dos estados se parecen, el entrenador puede creer que ya entregó
    // un plan que nadie ha recibido.
    test('en claro', () {
      expect(
        separacion(claro.aprobado, claro.publicado),
        greaterThanOrEqualTo(sinConfundirse),
      );
    });

    test('en oscuro', () {
      expect(
        separacion(oscuro.aprobado, oscuro.publicado),
        greaterThanOrEqualTo(sinConfundirse),
      );
    });

    test('cada estado conserva su familia al pasar a oscuro', () {
      expect(separacion(claro.borrador, oscuro.borrador),
          lessThanOrEqualTo(mismaFamilia));
      expect(separacion(claro.aprobado, oscuro.aprobado),
          lessThanOrEqualTo(mismaFamilia));
      expect(separacion(claro.publicado, oscuro.publicado),
          lessThanOrEqualTo(mismaFamilia));
    });
  });

  group('las pantallas se pintan en oscuro', () {
    // La fase 3 las midió en claro. Si alguna sólo funcionara en claro, esto
    // es lo que lo diría, y es lo único de esta prueba que recorre la app.
    const telefono = Size(360, 640);

    for (final pantalla in pantallasDeLaApp()) {
      testWidgets(pantalla.nombre, (tester) async {
        tester.view.physicalSize = telefono;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          MediaQuery(
            data: const MediaQueryData(size: telefono),
            child: MaterialApp(
              theme: Tema.oscuro(),
              home: pantalla.construir(),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(tester.takeException(), isNull);
      });
    }
  });

  group('la prueba no pasa por vacía', () {
    test('las dos métricas cazan un color mal elegido', () {
      // Si estas dos no fallaran, todo lo de arriba aprobaría cualquier paleta.
      const ambar = Color(0xFFE0B072);
      const ambarUnPocoMasClaro = Color(0xFFE6BC84);

      // Mismo matiz: la separación no los distingue, y así tiene que ser.
      expect(separacion(ambar, ambarUnPocoMasClaro), lessThan(sinConfundirse));

      // Y a la vista también están demasiado juntos.
      expect(distancia(ambar, ambarUnPocoMasClaro), lessThan(distanciaMinima));
    });

    test('la distancia perceptual da lo que se sabe que da', () {
      // El blanco y el negro están a 100 de claridad, que es todo el recorrido.
      expect(
        distancia(const Color(0xFFFFFFFF), const Color(0xFF000000)),
        closeTo(100, 1),
      );
      expect(distancia(const Color(0xFF13395E), const Color(0xFF13395E)), 0);
    });

    test('se comparan los dos temas de verdad, no el mismo dos veces', () {
      expect(claro.exito, isNot(oscuro.exito));
      expect(claro.zonas, isNot(oscuro.zonas));
    });
  });

  group('la app sigue al teléfono y no guarda preferencia', () {
    test('hay un tema claro y uno oscuro, y los dos se construyen', () {
      // Decisión D3: no hay ajuste propio. El interruptor, si llega, será de
      // la pantalla de Ajustes de la feature 007.
      expect(temaSeguro(Tema.claro).brightness, Brightness.light);
      expect(temaSeguro(Tema.oscuro).brightness, Brightness.dark);
    });

    test('los dos traen los colores del dominio', () {
      // Si el oscuro se quedara sin la extensión, cada pantalla caería al
      // respaldo —que son los colores de claro— y el oscuro se vería mal sin
      // que nada fallara.
      expect(temaSeguro(Tema.oscuro).extension<ColoresDelDominio>(),
          isNotNull);
      expect(temaSeguro(Tema.claro).extension<ColoresDelDominio>(), isNotNull);
    });
  });
}
