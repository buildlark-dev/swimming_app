/// El perfil de cuenta y cuándo está completo.
///
/// Lo que importa de verdad aquí es que **un perfil sin fecha de nacimiento
/// está incompleto**: es un perfil del que no se sabe si necesita
/// consentimiento, y hay cuentas así en producción ahora mismo.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:natacion_app/dominio/cuentas/perfil.dart';

void main() {
  final hoy = DateTime(2026, 10, 21);

  AceptacionDeTerminos aceptados() =>
      AceptacionDeTerminos(version: 'v1', aceptadaEn: hoy);

  Perfil completo() => Perfil(
        nombre: 'Juan Esteban Restrepo',
        fechaNacimiento: DateTime(1995, 4, 12),
        pais: 'CO',
        terminos: aceptados(),
      );

  group('cuándo un perfil está completo', () {
    test('con nombre, fecha y términos, lo está', () {
      expect(completo().estaCompleto, isTrue);
      expect(completo().faltas, isEmpty);
    });

    test('**el país no cuenta**: sin él sigue completo', () {
      // Decirlo es opcional (FR-009). Un dato que solo informa no bloquea a
      // nadie.
      final sinPais = Perfil(
        nombre: 'Juan',
        fechaNacimiento: DateTime(1995, 4, 12),
        terminos: aceptados(),
      );

      expect(sinPais.estaCompleto, isTrue);
    });

    test('sin nombre, no', () {
      expect(completo().copiarCon(nombre: '   ').estaCompleto, isFalse);
    });

    test('sin fecha de nacimiento, no', () {
      // Es el caso que importa: sin fecha no se sabe si hace falta
      // consentimiento.
      final sinFecha = Perfil(nombre: 'Juan', terminos: aceptados());

      expect(sinFecha.estaCompleto, isFalse);
      expect(
        sinFecha.faltas.map((f) => f.campo),
        contains('fechaNacimiento'),
      );
    });

    test('sin aceptar los términos, no', () {
      final sinTerminos = Perfil(
        nombre: 'Juan',
        fechaNacimiento: DateTime(1995, 4, 12),
      );

      expect(sinTerminos.estaCompleto, isFalse);
    });

    test('un perfil vacío es el de las cuentas de antes de esta feature', () {
      const vacio = Perfil();

      expect(vacio.estaCompleto, isFalse);
      expect(vacio.faltas, hasLength(3));
    });
  });

  group('las fechas que no pueden ser', () {
    test('una fecha futura', () {
      final futura = completo().copiarCon(
        fechaNacimiento: DateTime.now().add(const Duration(days: 1)),
      );

      expect(futura.estaCompleto, isFalse);
    });

    test('anterior a 1900', () {
      final antigua = completo().copiarCon(
        fechaNacimiento: DateTime(1880, 1, 1),
      );

      expect(antigua.estaCompleto, isFalse);
    });

    test('una fecha rara pero posible se acepta', () {
      // 1901 es improbable y no es asunto nuestro. Una fecha rara es un error
      // de quien escribe, no un ataque, y rechazarla con sermón no ayuda.
      final rara = completo().copiarCon(fechaNacimiento: DateTime(1901, 1, 1));

      expect(rara.estaCompleto, isTrue);
    });
  });

  group('el nombre se recorta pero no se juzga', () {
    test('con espacios alrededor, cuenta', () {
      expect(completo().copiarCon(nombre: '  Ana  ').estaCompleto, isTrue);
    });

    test('un nombre de una letra vale', () {
      // Los hay. No somos quién para decidir cuáles valen.
      expect(completo().copiarCon(nombre: 'Ñ').estaCompleto, isTrue);
    });
  });

  group('el perfil no calcula la edad por su cuenta', () {
    test('pregunta, y contesta lo mismo que el único sitio que decide', () {
      final menor = completo().copiarCon(fechaNacimiento: DateTime(2014, 3, 1));

      expect(menor.necesitaAcudienteEn(hoy), isTrue);
      expect(completo().necesitaAcudienteEn(hoy), isFalse);
    });

    test('un perfil vacío necesita acudiente', () {
      // Ante la duda, menor (A5).
      expect(const Perfil().necesitaAcudienteEn(hoy), isTrue);
    });
  });

  group('los términos se guardan con su versión', () {
    test('qué se aceptó y cuándo', () {
      final perfil = completo();

      expect(perfil.terminos!.version, 'v1');
      expect(perfil.terminos!.aceptadaEn, hoy);
    });

    test('dos versiones distintas no son lo mismo', () {
      expect(
        AceptacionDeTerminos(version: 'v1', aceptadaEn: hoy),
        isNot(AceptacionDeTerminos(version: 'v2', aceptadaEn: hoy)),
      );
    });
  });
}
