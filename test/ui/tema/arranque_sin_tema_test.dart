import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:natacion_app/main.dart';
import 'package:natacion_app/ui/tema/tema.dart';

/// Garantía V14 — la app abre aunque el tema falle.
///
/// Quedarse sin abrir por un asunto de aspecto no es aceptable. No es una
/// precaución teórica: en este proyecto ya ocurrió una vez, con Firebase. Un
/// fallo que debía degradar —arrancar sin servidor— tumbaba el arranque
/// entero, y solo se descubrió al desplegar.
///
/// La lección fue que estas cosas se escriben **antes** de necesitarlas.
void main() {
  group('V14 — el tema no puede impedir que la app abra', () {
    test('si construir el tema lanza, se usa la apariencia por omisión', () {
      final tema = temaSeguro(() => throw StateError('paleta rota'));

      expect(tema, isA<ThemeData>());
      expect(tema.useMaterial3, isTrue);
    });

    test('se atrapa cualquier fallo, no solo las excepciones', () {
      // Un error al construir una escala de color es un `Error`, no una
      // `Exception`. Atrapar solo excepciones fue exactamente lo que se nos
      // escapó con el arranque sin Firebase del PR #5.
      final tema = temaSeguro(() => throw UnsupportedError('sin soporte'));

      expect(tema, isA<ThemeData>());
    });

    test('cuando el tema sí se construye, se usa ese', () {
      final tema = temaSeguro(Tema.claro);

      expect(
        tema.extensions,
        isNotEmpty,
        reason: 'El tema bueno trae los colores del dominio; el de emergencia '
            'no. Si esto falla, la app estaría usando el de emergencia sin que '
            'nadie se entere',
      );
    });

    test('el claro y el oscuro son distintos', () {
      expect(Tema.claro().brightness, Brightness.light);
      expect(Tema.oscuro().brightness, Brightness.dark);
    });
  });

  group('los dos temas traen lo que las pantallas necesitan', () {
    test('cada uno con sus colores del dominio', () {
      for (final tema in [Tema.claro(), Tema.oscuro()]) {
        expect(tema.extensions, isNotEmpty);
      }
    });

    test('las áreas pulsables llevan su mínimo fijado desde el tema', () {
      // Fijado una vez aquí para que ninguna pantalla tenga que acordarse.
      final boton = Tema.claro().filledButtonTheme.style;
      expect(boton, isNotNull);
      expect(boton!.minimumSize, isNotNull);
    });
  });
}
