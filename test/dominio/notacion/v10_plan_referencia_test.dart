import 'package:flutter_test/flutter_test.dart';
import 'package:natacion_app/dominio/notacion/analizador.dart';

import 'ayuda_pruebas.dart';

/// Escenario V10 de `quickstart.md` — criterio SC-001.
///
/// Reconstruye sesiones reales del `Macrociclo - Precompetitivo Agosto`, tal
/// como están escritas en la hoja "Sem 04-08 Ago", y comprueba que los metros
/// coinciden con los que el documento declara.
///
/// **Es la prueba de fuego de la feature**: si la app no reproduce lo que el
/// entrenador ya hizo, la app está mal.
void main() {
  late Analizador analizador;

  setUpAll(() {
    analizador = crearAnalizador();
  });

  // Texto LITERAL de la sesión S2 (martes 04/08), inicial de Espalda, copiado
  // de la hoja "Sem 04-08 Ago" sin simplificar: con el signo ×, la flecha del
  // desglose de drills, los separadores ·, las etiquetas "Pre-set" y
  // "Principal", las zonas escritas entre paréntesis y las notas del
  // entrenador.
  const inicialS2 =
      '300 Nado Libre (A1)\n'
      '8×50 TEC E / 20"  →  2×ROLIDO (Espalda) · 2×ROLIDO CON 1 BRAZO '
      '(Espalda) · 2×MANO AL CIELO · 2×TOCANDO FRENTE\n'
      '100 Nado Espalda continuo (A1)';

  const centralS2 =
      'Pre-set: 4×50 ROZAR SUPERFICIE (Libre) / 20"\n'
      'Principal: 6×100 Nado Libre A2 / 1\'40" (foco rolido y respiración)'
      '  +  2×50 Nado Espalda A1';

  const finalS2 = '200 Nado Libre REC';

  group('sesión S2 del 04/08, que el documento declara en 1.900 m', () {
    test('la parte inicial suma 800 m', () {
      final resultado = analizador.analizar(inicialS2);
      expect(
        resultado.metros,
        800,
        reason:
            'Interpretado: '
            '${resultado.series.map((s) => s.toString()).join(' | ')}',
      );
    });

    test('la parte central suma 900 m', () {
      final resultado = analizador.analizar(centralS2);
      expect(
        resultado.metros,
        900,
        reason:
            'Interpretado: '
            '${resultado.series.map((s) => s.toString()).join(' | ')}',
      );
    });

    test('la parte final suma 200 m', () {
      expect(analizador.analizar(finalS2).metros, 200);
    });

    test('la sesión completa suma 1.900 m', () {
      final total =
          analizador.analizar(inicialS2).metros +
          analizador.analizar(centralS2).metros +
          analizador.analizar(finalS2).metros;

      expect(
        total,
        1900,
        reason:
            'Es el total que declara el documento del entrenador para la '
            'sesión S2 del 04/08',
      );
    });
  });

  group('la semana completa, que el documento declara en 5.700 m', () {
    test('tres sesiones de 1.900 m suman 5.700 m', () {
      final porSesion =
          analizador.analizar(inicialS2).metros +
          analizador.analizar(centralS2).metros +
          analizador.analizar(finalS2).metros;

      expect(porSesion * 3, 5700);
    });
  });

  group('el texto literal no deja nada sin interpretar', () {
    // Esta es la comprobación que destapó dos defectos reales:
    //   1. Una línea que empieza con etiqueta ("Pre-set: 4×50 ...") se
    //      descartaba en silencio y la parte central daba 100 m en vez de 900.
    //   2. Las zonas escritas por el entrenador ("A1", "A2") se tomaban por
    //      ejercicios inexistentes.

    test('la parte inicial no deja fragmentos pendientes', () {
      final resultado = analizador.analizar(inicialS2);
      expect(
        resultado.pendientes,
        isEmpty,
        reason: resultado.pendientes.map((p) => p.toString()).join(' | '),
      );
    });

    test('la parte central no deja fragmentos pendientes', () {
      final resultado = analizador.analizar(centralS2);
      expect(
        resultado.pendientes,
        isEmpty,
        reason: resultado.pendientes.map((p) => p.toString()).join(' | '),
      );
    });

    test('una línea con etiqueta no pierde su serie', () {
      final conEtiqueta = analizador.analizar('Pre-set: 4×50 N / 20"');
      expect(
        conEtiqueta.metros,
        200,
        reason: 'La etiqueta no puede hacer desaparecer la serie',
      );
    });

    test('recoge la zona cuando el entrenador la escribe', () {
      final resultado = analizador.analizar('6×100 Nado Libre A2');
      expect(resultado.series.first.zona?.abreviatura, 'A2');
    });

    test('pero no la inventa cuando no está escrita', () {
      final resultado = analizador.analizar('6×100 Nado Libre');
      expect(
        resultado.series.first.zona,
        isNull,
        reason: 'FR-011: la zona la asigna el entrenador',
      );
    });
  });

  group('el signo × del documento se lee igual que la x', () {
    test('8×50 y 8x50 dan lo mismo', () {
      expect(
        analizador.analizar('8×50 N').metros,
        analizador.analizar('8x50 N').metros,
      );
    });

    test('6×100 son 600 m', () {
      expect(analizador.analizar('6×100 Nado Libre').metros, 600);
    });
  });

  group('ejercicios reales del documento', () {
    const usados = [
      'ROZAR SUPERFICIE (Libre)',
      'ROLIDO (Espalda)',
      'ROLIDO CON 1 BRAZO (Espalda)',
      'PUNTO MUERTO',
      'DXS',
      'FLECHA (Pecho)',
      'FLECHA (Mariposa)',
    ];

    for (final nombre in usados) {
      test('"$nombre" está en la Biblioteca Oficial', () {
        final resultado = analizador.analizar('200 $nombre');
        expect(
          resultado.pendientes,
          isEmpty,
          reason:
              'El documento lo usa, así que debe estar en la sección 19. '
              'Pendientes: '
              '${resultado.pendientes.map((p) => p.toString()).join(', ')}',
        );
      });
    }
  });
}
