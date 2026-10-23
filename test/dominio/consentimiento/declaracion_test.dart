/// Garantía A12 — el correo del acudiente no puede ser el del menor.
///
/// Y, sobre todo, **lo que esta garantía no dice**: que el correo sea de verdad
/// de un acudiente. Eso no lo puede saber la app.
///
/// Tapa el caso ingenuo —el niño que pone el suyo— y nada más. Un adolescente
/// decidido usa una segunda dirección y tarda dos minutos. Pretender lo
/// contrario sería peor que no comprobar nada, porque daría una seguridad que
/// no existe.
///
/// Donde está la garantía de verdad es en el formulario de la feature 004: el
/// acudiente se identifica, declara en qué calidad actúa y confirma que **ha
/// oído al menor** (Decreto 1377 de 2013).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:natacion_app/dominio/consentimiento/declaracion.dart';

void main() {
  const cuenta = 'nadadora@ejemplo.com';

  MotivoDeCorreoInvalido? revisar(String correo) =>
      DeclaracionDeAcudiente.revisarCorreo(correo, correoDeLaCuenta: cuenta);

  group('A12 — el correo del menor no sirve como acudiente', () {
    test('el mismo correo, rechazado', () {
      expect(
        revisar(cuenta),
        MotivoDeCorreoInvalido.esElDelPropioNadador,
      );
    });

    test('el mismo correo con otras mayúsculas, también', () {
      // Quien lo intente no va a escribirlo igual.
      expect(
        revisar('Nadadora@Ejemplo.COM'),
        MotivoDeCorreoInvalido.esElDelPropioNadador,
      );
    });

    test('el mismo correo con espacios, también', () {
      expect(
        revisar('  nadadora@ejemplo.com  '),
        MotivoDeCorreoInvalido.esElDelPropioNadador,
      );
    });

    test('el de su madre, aceptado', () {
      expect(revisar('madre@ejemplo.com'), isNull);
    });

    test('el mensaje dice qué hacer, no solo que está mal', () {
      expect(
        MotivoDeCorreoInvalido.esElDelPropioNadador.mensaje,
        contains('acudiente'),
      );
    });
  });

  group('lo que se admite como correo', () {
    test('vacío, no', () {
      expect(revisar(''), MotivoDeCorreoInvalido.vacio);
      expect(revisar('   '), MotivoDeCorreoInvalido.vacio);
    });

    test('sin arroba ni punto, no', () {
      expect(revisar('madre'), MotivoDeCorreoInvalido.sinForma);
      expect(revisar('madre@ejemplo'), MotivoDeCorreoInvalido.sinForma);
      expect(revisar('@ejemplo.com'), MotivoDeCorreoInvalido.sinForma);
    });

    test('direcciones raras pero legítimas, sí', () {
      // La validación es laxa a propósito. Una validación estricta rechaza
      // direcciones de verdad, que es peor que dejar pasar una mal escrita:
      // esa se corrige sola cuando no llega el mensaje.
      expect(revisar('maria.jose+natacion@correo.com.co'), isNull);
      expect(revisar("o'brien@ejemplo.org"), isNull);
    });
  });

  group('el origen se graba y no se cambia', () {
    test('los dos caminos existen y se distinguen', () {
      expect(OrigenDeLaDeclaracion.values, hasLength(2));
      expect(
        OrigenDeLaDeclaracion.declaradoPorElNadador.descripcion,
        isNot(OrigenDeLaDeclaracion.matriculaDelEntrenador.descripcion),
      );
    });

    test('la descripción está en español, lista para enseñarla', () {
      for (final origen in OrigenDeLaDeclaracion.values) {
        expect(origen.descripcion, isNotEmpty);
        expect(origen.descripcion, isNot(origen.name));
      }
    });

    test('una declaración guarda de dónde vino', () {
      final declarada = DeclaracionDeAcudiente(
        nadadorId: 'n1',
        correo: 'madre@ejemplo.com',
        origen: OrigenDeLaDeclaracion.declaradoPorElNadador,
        declaradaEn: DateTime(2026, 10, 21),
      );

      expect(declarada.origen, OrigenDeLaDeclaracion.declaradoPorElNadador);
    });

    test('dos declaraciones iguales salvo el origen son distintas', () {
      // Si fueran iguales, el origen no estaría significando nada.
      final fecha = DateTime(2026, 10, 21);
      final porElNadador = DeclaracionDeAcudiente(
        nadadorId: 'n1',
        correo: 'madre@ejemplo.com',
        origen: OrigenDeLaDeclaracion.declaradoPorElNadador,
        declaradaEn: fecha,
      );
      final porLaMatricula = DeclaracionDeAcudiente(
        nadadorId: 'n1',
        correo: 'madre@ejemplo.com',
        origen: OrigenDeLaDeclaracion.matriculaDelEntrenador,
        declaradaEn: fecha,
      );

      expect(porElNadador, isNot(porLaMatricula));
    });
  });
}
